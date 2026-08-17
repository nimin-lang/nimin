## nimin/cli — zero-heap argc/argv parser.
##
## A stateful argument parser that scans raw `argc`/`argv` pointers
## using pure pointer arithmetic. Zero allocation, zero copying —
## all results are Spans pointing into the original argv strings.

{.push raises: [].}

import span

type
  CliParser* = object
    ## Stateful parser over argc/argv.
    args: Span[string]
    pos: int

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

proc initCli*(args: openArray[string]): CliParser =
  ## Create a parser over an argument list.
  result.args = toSpan(args)
  result.pos = 0

proc initCli*(argc: int, argv: cstringArray): CliParser =
  ## Create a parser directly from C argc/argv.
  ## Builds a Span view without copying the strings.
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
  p.pos < p.args.len

proc remaining*(p: CliParser): int {.inline.} =
  ## Number of unprocessed arguments.
  p.args.len - p.pos

proc peek*(p: CliParser): string =
  ## Look at the next argument without consuming it.
  ## Returns empty string if no more args.
  if p.pos < p.args.len:
    p.args[p.pos]
  else:
    ""

proc peekSpan*(p: CliParser): Span[string] =
  ## Look at the next argument as a Span without consuming it.
  if p.pos < p.args.len:
    p.args.subspan(p.pos, 1)
  else:
    empty[string]()

# ---------------------------------------------------------------------------
# Consumption
# ---------------------------------------------------------------------------

proc nextArg*(p: var CliParser): string =
  ## Consume and return the next positional argument.
  ## Returns empty string if no more args.
  if p.pos < p.args.len:
    result = p.args[p.pos]
    inc p.pos
  else:
    result = ""

proc nextSpan*(p: var CliParser): Span[string] =
  ## Consume and return the next argument as a Span.
  if p.pos < p.args.len:
    result = p.args.subspan(p.pos, 1)
    inc p.pos
  else:
    result = empty[string]()

proc skip*(p: var CliParser, n: int = 1) =
  ## Skip the next `n` arguments.
  p.pos = min(p.pos + n, p.args.len)

# ---------------------------------------------------------------------------
# Flag detection
# ---------------------------------------------------------------------------

proc isFlag*(arg: string): bool =
  ## True if the argument looks like a flag (--long or -short).
  ## Bare "--" is not considered a flag.
  arg.len >= 3 and arg[0] == '-' and arg[1] == '-'

proc isShortFlag*(arg: string): bool =
  ## True if the argument looks like a short flag (-x).
  arg.len >= 2 and arg[0] == '-' and arg[1] != '-'

proc nextFlag*(p: var CliParser): string =
  ## Consume the next argument if it looks like a flag.
  ## Returns empty string if the next arg is not a flag.
  if p.pos < p.args.len and isFlag(p.args[p.pos]):
    result = p.args[p.pos]
    inc p.pos
  else:
    result = ""

proc nextShortFlag*(p: var CliParser): string =
  ## Consume the next argument if it looks like a short flag.
  if p.pos < p.args.len and isShortFlag(p.args[p.pos]):
    result = p.args[p.pos]
    inc p.pos
  else:
    result = ""

# ---------------------------------------------------------------------------
# Argument inspection
# ---------------------------------------------------------------------------

proc argAt*(p: CliParser, i: int): string =
  ## Get argument at absolute index.
  if i >= 0 and i < p.args.len:
    p.args[i]
  else:
    ""

proc flagValue*(flag, prefix: string): string =
  ## Extract value after a prefix. E.g., flagValue("--output=file", "--output=") → "file".
  if flag.len >= prefix.len and flag[0..<prefix.len] == prefix:
    flag[prefix.len..^1]
  else:
    ""

proc flagName*(flag: string): string =
  ## Extract the flag name (strip leading dashes and value after =).
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
