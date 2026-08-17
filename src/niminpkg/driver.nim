import std/[os, parseopt, strutils]

## nimin compiler driver — drives the Nim compiler as a library.
##
## This module is the heart of nimin. It imports the Nim compiler's
## own modules (`compiler/commands`, `compiler/main`, etc.) to drive
## the full compilation pipeline, but injects nimin's strict defaults
## before handing off to the standard code generator.
##
## **Pipeline overview:**
##
## 1. Build the command line: nimin defaults + user argv
## 2. Initialize the compiler config (`ConfigRef`)
## 3. Parse the command line through the compiler's own parser
## 4. Set up the module graph with the linter hook
## 5. Run the type-section linter (before semantic analysis)
## 6. Run the main compilation (`mainCommand`)
##
## The linter (`strongSemCheck`) fires during semantic analysis for
## routine bodies. Type-section linting is done separately because
## `strongSemCheck` does not fire for `nkTypeSection` nodes.

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

proc run*(verbose: bool = false): int =
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

  if verbose:
    rawMessage(conf, hintUser, "nimin: libpath = $1" % $conf.libpath)

  self.processCmdLineAndProjectPath(conf)

  if verbose:
    rawMessage(conf, hintUser, "nimin: projectPath = $1" % $conf.projectPath)
    rawMessage(conf, hintUser, "nimin: backend = $1" % $conf.backend)
    rawMessage(conf, hintUser, "nimin: selectedGC = $1" % $conf.selectedGC)
    rawMessage(conf, hintUser, "nimin: optimizer = $1" % $conf.options)

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
    if verbose:
      rawMessage(conf, hintUser, "nimin: standalone target detected, provisioning panicoverride")
    provisionPanicOverride(conf)

  # Lint type definitions before compilation. This must happen before
  # mainCommand because `strongSemCheck` does not fire for nkTypeSection
  # nodes — only routine bodies trigger it.
  if verbose:
    rawMessage(conf, hintUser, "nimin: running type-section linter")
  lintModuleTypes(conf, graph.cache)

  if verbose:
    rawMessage(conf, hintUser, "nimin: entering main compilation")
  mainCommand(graph)
  result = conf.errorCounter