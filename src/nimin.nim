## nimin — the CLI driver for the nimin dialect of Nim.
##
## This is the main entry point for the `nimin` command. It handles
## top-level flags (`--version`, `--help`, `--verbose`), then delegates
## to the compiler driver (`niminpkg/driver`) which drives the Nim
## compiler as a library with strict zero-baggage defaults.
##
## nimin mirrors the `nim c` interface: `nimin c [options] <file>` compiles
## a file with aggressive size optimizations, panic-only error handling,
## and the dialect linter enabled.

import std/[os, strutils]

import niminpkg/driver

const
  Version = "0.1.0"
    ## The current nimin version. Updated with each release.

  YearStarted = 2026
    ## The year the nimin project was created.

  BuildYear {.intdefine.} = 2026
    ## The year this binary was built. Overridden at compile time
    ## via `-d:BuildYear=YYYY` (the Makefile does this automatically).

  Tagline = "Zero-baggage Nim dialect for tiny binaries on constrained runtimes."
    ## The project tagline, shown in `--version` output.

func copyright(): string =
  ## Build the copyright line for `--version` output.
  ##
  ## Uses a single year when building in the same year as `YearStarted`,
  ## otherwise shows a range (e.g. "2026-2028"). Detects UTF-8 locale
  ## support and uses the proper `©` glyph when available, falling
  ## back to `(c)` otherwise.
  let year = if YearStarted == BuildYear: $YearStarted
             else: $YearStarted & "-" & $BuildYear
  var utf8 = false
  for key in ["LC_ALL", "LC_CTYPE", "LANG"]:
    let val = getEnv(key).toLowerAscii
    if val.contains("utf-8") or val.contains("utf8"):
      utf8 = true
      break
  let symbol = if utf8: "\u00A9" else: "(c)"
  symbol & " " & year & " the Nimin project authors and contributors. Distributed under the MIT license."

const
  Usage = """
nimin — the symmetrical, zero-baggage dialect of Nim for tiny binaries and
constrained runtimes.

Usage:
  nimin c [options] <file.nmi|file.nim>
  nimin --version
  nimin --help

Commands mirror `nim`: `c`, `cpp`, `js`, `check`, `doc`, etc.
nimin compiles with strict zero-baggage defaults: --mm:arc -d:useMalloc,
--panics:on, --exceptions:quirky, -d:danger, --opt:size and aggressive
C-compiler size flags. Explicit options on the command line override defaults.

Options:
  --verbose, -V    Show detailed build information (nimin + compiler internals)
  --version, -v    Show version information
  --help, -h       Show this help message

For full options, run: nimin c --fullhelp
"""

proc isNiminSource(path: string): bool =
  ## True if the file path has the `.nmi` extension (nimin dialect file).
  path.endsWith(".nmi")

proc main(): int =
  ## Main entry point for the nimin CLI.
  ##
  ## Handles top-level flags (`--version`, `--help`, `--verbose`), then
  ## delegates to the compiler driver. Returns 0 on success, nonzero on
  ## compilation error.
  let args = os.commandLineParams()
  if args.len == 0:
    stdout.write Usage
    return 0
  case args[0]
  of "--version", "-v":
    stdout.writeLine "nimin " & Version
    stdout.writeLine Tagline
    stdout.writeLine copyright()
    return 0
  of "--help", "-h", "help":
    stdout.write Usage
    return 0
  else:
    discard

  # Detect --verbose / -V before passing to the compiler pipeline.
  var verbose = false
  for a in args:
    if a == "--verbose" or a == "-V":
      verbose = true
      break

  if verbose:
    stderr.writeLine "nimin: verbose mode enabled"
    stderr.writeLine "nimin: applying strict defaults: --mm:arc -d:useMalloc --panics:on --exceptions:quirky -d:danger --opt:size"
    stderr.writeLine "nimin: running dialect linter"

  # Warn when compiling a plain .nim file under nimin rules.
  for a in args:
    if a.len > 0 and a[0] != '-' and not isNiminSource(a) and a.endsWith(".nim"):
      stderr.writeLine "hint: compiling .nim file under nimin strict defaults (use .nmi for the nimin dialect)"
      break

  result = run(verbose)

when isMainModule:
  quit main()