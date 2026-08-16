import std/[os, parseopt, sequtils]

import compiler/commands
import compiler/options
import compiler/msgs
import compiler/main
import compiler/idents
import compiler/cmdlinehelper
import compiler/modulegraphs
import compiler/condsyms
import compiler/pathutils

import ./config

const
  NimRoot = getCurrentCompilerExe().parentDir.parentDir

proc libPath(): string =
  ## Resolve the Nim standard library path from the compiler that built us.
  ## getCurrentCompilerExe() is baked at build time and points at the real
  ## nim binary (unlike findExe which can hit asdf shims).
  NimRoot / "lib"

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
  if not self.loadConfigsAndProcessCmdLine(cache, conf, graph):
    return conf.errorCounter

  if conf.selectedGC == gcUnselected and
      conf.backend in {backendC, backendCpp, backendObjc}:
    initOrcDefines(conf)

  mainCommand(graph)
  result = conf.errorCounter