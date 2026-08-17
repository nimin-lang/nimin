import std/[os, parseopt, strutils]

import compiler/commands
import compiler/options
import compiler/msgs
import compiler/lineinfos
import compiler/main
import compiler/idents
import compiler/cmdlinehelper
import compiler/modulegraphs
import compiler/ast
import compiler/pathutils
import compiler/platform

import ./config
import ./linter

const
  NimRoot = getCurrentCompilerExe().parentDir.parentDir

proc libPath(): string =
  ## Resolve the Nim standard library path from the compiler that built us.
  ## getCurrentCompilerExe() is baked at build time and points at the real
  ## nim binary (unlike findExe which can hit asdf shims).
  NimRoot / "lib"

proc panicOverridePath(): string =
  ## Path to the bundled panicoverride module.
  currentSourcePath().parentDir / "panicoverride.nim"

proc provisionPanicOverride(conf: ConfigRef) =
  ## `--os:standalone` makes system.nim `include "$projectpath/panicoverride"`,
  ## which must physically exist in the project dir. Copy the bundled module
  ## there when missing so the dialect works without user boilerplate.
  let target = conf.projectPath / RelativeFile("panicoverride.nim")
  if not fileExists(target):
    try:
      copyFile(panicOverridePath(), target.string)
      rawMessage(conf, hintUser, "nimin: provisioned $1 with bundled panicoverride" % $target)
    except CatchableError:
      rawMessage(conf, warnUser, "nimin: could not provision panicoverride at $1" % $target)

proc processCmdLine(pass: TCmdLinePass, cmd: string; conf: ConfigRef) =
  ## Parse the full nimin command line. `cmd` is empty (the compiler driver
  ## passes ""), so we build our own string from strict defaults + argv.
  let fullCmd = niminCmdLine(os.commandLineParams())
  var p = parseopt.initOptParser(fullCmd)
  var argsCount = 0
  while true:
    parseopt.next(p)
    case p.kind
    of cmdEnd: break
    of cmdLongOption, cmdShortOption:
      if p.key == "":
        p.key = "-"
        if processArgument(pass, p, argsCount, conf): break
      else:
        processSwitch(pass, p, conf)
    of cmdArgument:
      if processArgument(pass, p, argsCount, conf): break

proc run*(): int =
  ## Drive the Nim compilation pipeline with nimin's strict defaults.
  ## Returns the compiler error counter (0 = success).
  resetLintState()
  let cache = newIdentCache()
  let conf = newConfigRef()
  let self = NimProg(
    supportsStdinFile: true,
    processCmdLine: processCmdLine,
  )
  self.initDefinesProg(conf, "nimin")
  conf.libpath = AbsoluteDir libPath()

  self.processCmdLineAndProjectPath(conf)

  var graph = newModuleGraph(cache, conf)
  # `-d:drnim` activates the compiler's strongSemCheck call sites (the same
  # extension point DrNim uses). It also guards those sites with a
  # `compatibleProps` hook, which must be non-nil or the compiler crashes.
  graph.compatibleProps = proc (graph: ModuleGraph; formal, actual: PType): bool {.nimcall.} =
    true
  graph.strongSemCheck = strongSemCheck
  if not self.loadConfigsAndProcessCmdLine(cache, conf, graph):
    return conf.errorCounter

  if conf.selectedGC == gcUnselected and
      conf.backend in {backendC, backendCpp, backendObjc}:
    initOrcDefines(conf)

  if conf.target.targetOS == osStandalone:
    provisionPanicOverride(conf)

  # Lint type definitions before compilation. This must happen before
  # mainCommand because `strongSemCheck` does not fire for nkTypeSection
  # nodes — only routine bodies trigger it.
  lintModuleTypes(conf, graph.cache)

  mainCommand(graph)
  result = conf.errorCounter