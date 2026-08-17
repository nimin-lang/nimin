import std/strutils

## nimin compiler configuration — the strict, zero-baggage defaults.
##
## This module defines the exact set of flags that nimin passes to the
## Nim compiler. It is intentionally free of compiler-module imports
## so it can be unit-tested quickly and reused by both the driver
## and the CLI.
##
## **Flag philosophy:** nimin's defaults are aggressive but predictable.
## Every flag is chosen to minimize binary size and eliminate runtime
## overhead. Users can override any default by passing the opposite
## flag on the command line — later switches win.

const
  NiminGC* = "--mm:arc"
    ## Use ARC (Automatic Reference Counting) for deterministic, low-overhead
    ## memory management. No garbage collector pauses.

  NiminUseMalloc* = "-d:useMalloc"
    ## Route ARC allocations through the system allocator (malloc/free)
    ## instead of Nim's memory pools. Required for standalone targets
    ## and keeps the binary dependency-free.

  NiminPanics* = "--panics:on"
    ## Turn all exceptions into panics (immediate abort). No stack
    ## unwinding, no RTTI, no dynamic exception tables.

  NiminExceptions* = "--exceptions:quirky"
    ## Use "quirky exceptions" — a minimal exception model that avoids
    ## the overhead of full exception handling while still allowing
    ## `Result[T, E]` error patterns.

  NiminDanger* = "-d:danger"
    ## Disable all runtime checks (array bounds, integer overflow,
    ## nil access). Produces the smallest possible binary.

  NiminOpt* = "--opt:size"
    ## Optimize for binary size instead of speed. Uses `-Os` at the
    ## C-compiler level.

  NiminCCFlags* = @["-Os", "-flto", "-ffunction-sections", "-fdata-sections"]
    ## C-compiler flags for maximum size reduction:
    ## - `-Os`: optimize for size
    ## - `-flto`: link-time optimization (dead code elimination across TUs)
    ## - `-ffunction-sections` / `-fdata-sections`: enable per-function
    ##   data sections so `--gc-sections` can discard unused code

  NiminLinkFlags* = @["-Wl,--gc-sections"]
    ## Linker flags. `--gc-sections` discards functions and data that
    ## the linker proves are unreachable — critical for stripping
    ## unused standard library code.

proc strictSwitches*(): seq[string] =
  ## The minimal, deterministic flag set for zero-baggage compilation.
  ##
  ## Returns a sequence of all nimin defaults: GC strategy, runtime
  ## options, optimization level, and C-compiler flags. The sequence
  ## is ordered so that user-provided overrides (which come later on
  ## the command line) take precedence.
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