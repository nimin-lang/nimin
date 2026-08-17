## nimin/cli — zero-heap argc/argv parser.
##
## A stateful argument parser that scans raw `argc`/`argv` pointers
## using pure pointer arithmetic. Zero allocation, zero copying —
## all results are `string` values borrowed from the original argv
## strings (or empty strings when exhausted).
##
## This module is designed for command-line tools that run on
## constrained runtimes where `std/parseopt` or `std/parsecfg`
## would pull in unwanted allocation or exception machinery.
##
## **Design rules:**
##
## - The parser is a lightweight value type (`CliParser`) that
##   wraps a `Span[string]` and a position cursor.
## - `nextFlag` and `nextShortFlag` only consume arguments that
##   look like flags; they leave positional arguments in place.
##   Use `nextArg` or `skip` to move past non-flag arguments.
## - `flagName` and `flagValue` are pure functions — they inspect
##   a single string without touching the parser state.
##
## **Quick example:**
##
## .. code-block:: nim
##
##   import nimin/cli
##
##   var p = initCli(["--verbose", "input.txt", "-o", "out.txt"])
##   while p.hasMore():
##     if p.hasFlag():
##       let f = p.nextFlag()
##       echo f.flagName()   # "verbose"
##     else:
##       let arg = p.nextArg()  # "input.txt"
##       processInput(arg)

{.push raises: [].}

import span

type
  CliParser* = object
    ## Stateful parser over argc/argv.
    ##
    ## Construct with `initCli`, then consume arguments using the
    ## `next*` and `skip` procs. The parser does not own the
    ## underlying argument strings — it borrows them via a span.
    args: Span[string]
    pos: int

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

proc initCli*(args: openArray[string]): CliParser =
  ## Create a parser over an argument list.
  ##
  ## This is the primary constructor. It works with any `openArray`
  ## — including `seq[string]`, `array[N, string]`, and the
  ## implicit openArray from `commandLineParams()`.
  result.args = toSpan(args)
  result.pos = 0

proc initCli*(argc: int, argv: cstringArray): CliParser =
  ## Create a parser directly from C argc/argv.
  ##
  ## Builds a `Span[string]` view over the C-style argument array.
  ## Each `cstring` is converted to a Nim `string` (this does
  ## allocate, but it happens once at construction — the parser
  ## itself never allocates).
  var spanArgs: seq[string]
  spanArgs.setLen(argc)
  for i in 0..<argc:
    spanArgs[i] = $argv[i]
  result.args = toSpan(spanArgs)
  result.pos = 0

# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

proc hasMore*(p: CliParser): bool {.inline.} =
  ## True if there are unprocessed arguments.
  ##
  ## Use this as your main loop condition:
  ##
  ## .. code-block:: nim
  ##
  ##   while p.hasMore():
  ##     let arg = p.nextArg()
  p.pos < p.args.len

proc remaining*(p: CliParser): int {.inline.} =
  ## Number of unprocessed arguments.
  p.args.len - p.pos

proc peek*(p: CliParser): string =
  ## Look at the next argument without consuming it.
  ##
  ## Returns empty string if no more args are available.
  ## Useful for deciding how to handle the next argument
  ## before committing to consuming it.
  if p.pos < p.args.len:
    p.args[p.pos]
  else:
    ""

proc peekSpan*(p: CliParser): Span[string] =
  ## Look at the next argument as a `Span[string]` without
  ## consuming it. Returns an empty span if exhausted.
  if p.pos < p.args.len:
    p.args.subspan(p.pos, 1)
  else:
    empty[string]()

# ---------------------------------------------------------------------------
# Consumption
# ---------------------------------------------------------------------------

proc nextArg*(p: var CliParser): string =
  ## Consume and return the next positional argument.
  ##
  ## Returns empty string if no more args are available.
  ## Advances the cursor by one position regardless.
  if p.pos < p.args.len:
    result = p.args[p.pos]
    inc p.pos
  else:
    result = ""

proc nextSpan*(p: var CliParser): Span[string] =
  ## Consume and return the next argument as a `Span[string]`.
  ##
  ## Same as `nextArg` but returns a span instead of a string.
  ## Useful when you want to avoid the string copy.
  if p.pos < p.args.len:
    result = p.args.subspan(p.pos, 1)
    inc p.pos
  else:
    result = empty[string]()

proc skip*(p: var CliParser, n: int = 1) =
  ## Skip the next `n` arguments.
  ##
  ## Use this when you encounter a flag whose value you don't
  ## care about, or to skip over a known number of positional
  ## arguments.
  p.pos = min(p.pos + n, p.args.len)

# ---------------------------------------------------------------------------
# Flag detection
# ---------------------------------------------------------------------------

proc isFlag*(arg: string): bool =
  ## True if the argument looks like a long flag (`--long`).
  ##
  ## Requires at least 3 characters (`--x`). Bare `--` is not
  ## considered a flag — it's the standard end-of-flags marker.
  arg.len >= 3 and arg[0] == '-' and arg[1] == '-'

proc isShortFlag*(arg: string): bool =
  ## True if the argument looks like a short flag (`-x`).
  ##
  ## Requires at least 2 characters. Single `-` is not a flag.
  arg.len >= 2 and arg[0] == '-' and arg[1] != '-'

proc nextFlag*(p: var CliParser): string =
  ## Consume the next argument if it looks like a long flag.
  ##
  ## Returns the flag string (e.g. `"--verbose"`) if consumed,
  ## or empty string if the next argument is not a flag. Does
  ## **not** advance the cursor when it returns empty — the
  ## argument is left for `nextArg` or `skip` to handle.
  if p.pos < p.args.len and isFlag(p.args[p.pos]):
    result = p.args[p.pos]
    inc p.pos
  else:
    result = ""

proc nextShortFlag*(p: var CliParser): string =
  ## Consume the next argument if it looks like a short flag.
  ##
  ## Returns the flag string (e.g. `"-v"`) if consumed, or
  ## empty string if not. Does not advance on miss.
  if p.pos < p.args.len and isShortFlag(p.args[p.pos]):
    result = p.args[p.pos]
    inc p.pos
  else:
    result = ""

# ---------------------------------------------------------------------------
# Argument inspection
# ---------------------------------------------------------------------------

proc argAt*(p: CliParser, i: int): string =
  ## Get argument at absolute index (not relative to cursor).
  ##
  ## Returns empty string if the index is out of bounds.
  ## Does not advance the cursor.
  if i >= 0 and i < p.args.len:
    p.args[i]
  else:
    ""

proc flagValue*(flag, prefix: string): string =
  ## Extract the value portion of a flag after a prefix.
  ##
  ## Commonly used with `"--name="` or `"-o"` prefixes:
  ##
  ## .. code-block:: nim
  ##
  ##   flagValue("--output=file", "--output=")  # → "file"
  ##   flagValue("-ofile", "-o")                # → "file"
  ##   flagValue("--verbose", "--output=")      # → ""
  ##
  ## Returns empty string if the flag doesn't start with `prefix`.
  if flag.len >= prefix.len and flag[0..<prefix.len] == prefix:
    flag[prefix.len..^1]
  else:
    ""

proc flagName*(flag: string): string =
  ## Extract the flag name, stripping leading dashes and any
  ## value after `=`.
  ##
  ## .. code-block:: nim
  ##
  ##   flagName("--verbose")      # → "verbose"
  ##   flagName("-v")             # → "v"
  ##   flagName("--output=file")  # → "output"
  ##   flagName("-o=file")        # → "o"
  var start = 0
  if flag.len >= 2 and flag[0] == '-' and flag[1] == '-':
    start = 2
  elif flag.len >= 2 and flag[0] == '-':
    start = 1
  let eqPos = flag.find('=')
  if eqPos >= 0:
    flag[start..<eqPos]
  else:
    flag[start..^1]
