import std/[os, strutils]

import niminpkg/driver

const
  Version = "0.1.0"
  Tagline = "Zero-baggage Nim dialect for tiny binaries on constrained runtimes."
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

For full options, run: nimin c --fullhelp
"""

proc isNiminSource(path: string): bool =
  path.endsWith(".nmi")

proc main(): int =
  let args = os.commandLineParams()
  if args.len == 0:
    stdout.write Usage
    return 0
  case args[0]
  of "--version", "-v":
    stdout.writeLine "nimin " & Version
    stdout.writeLine Tagline
    return 0
  of "--help", "-h", "help":
    stdout.write Usage
    return 0
  else:
    discard

  # Warn when compiling a plain .nim file under nimin rules.
  for a in args:
    if a.len > 0 and a[0] != '-' and not isNiminSource(a) and a.endsWith(".nim"):
      stderr.writeLine "hint: compiling .nim file under nimin strict defaults (use .nmi for the nimin dialect)"
      break

  result = run()

when isMainModule:
  quit main()