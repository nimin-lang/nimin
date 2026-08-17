import std/strutils

## Nimin compiler configuration: the strict, zero-baggage defaults.
##
## This module is intentionally free of compiler-module imports so it can be
## unit-tested quickly and reused by the driver and CLI.

const
  NiminGC* = "--mm:arc"
  NiminUseMalloc* = "-d:useMalloc"
  NiminPanics* = "--panics:on"
  NiminExceptions* = "--exceptions:quirky"
  NiminDanger* = "-d:danger"
  NiminOpt* = "--opt:size"

  NiminCCFlags* = @["-Os", "-flto", "-ffunction-sections", "-fdata-sections"]
  NiminLinkFlags* = @["-Wl,--gc-sections"]

proc strictSwitches*(): seq[string] =
  ## The minimal, deterministic flag set for zero-baggage compilation.
  result = @[
    NiminGC,
    NiminUseMalloc,
    NiminPanics,
    NiminExceptions,
    NiminDanger,
    NiminOpt,
  ]
  # C-compiler flags must be passed through `--passc:`/`--passl:` so the
  # nim compiler forwards them to gcc/clang rather than parsing them itself.
  for f in NiminCCFlags:
    result.add "--passc:" & f
  for f in NiminLinkFlags:
    result.add "--passl:" & f

proc niminMarkers*(): seq[string] =
  ## Compile-time defines that mark the output as a nimin build.
  @["nimin"]

proc niminCmdLine*(userArgs: openArray[string]): string =
  ## Build the full command line: nimin strict defaults first, then the
  ## user's arguments. Later switches override earlier ones, so the user
  ## can always override defaults explicitly.
  ## Nimin-only flags (--verbose, -V) are stripped before reaching the compiler.
  result = strictSwitches().join(" ")
  if userArgs.len > 0:
    var filtered: seq[string]
    for arg in userArgs:
      if arg != "--verbose" and arg != "-V":
        filtered.add arg
    if filtered.len > 0:
      result.add " " & filtered.join(" ")