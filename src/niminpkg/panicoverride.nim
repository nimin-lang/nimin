# panicoverride.nim — nimin's zero-baggage panic handler.
#
# Included by system.nim when compiling with `--os:standalone`. Bypasses all
# standard-library formatting tables, stack unwinders and exit machinery:
# prints the raw message and aborts.

proc c_fputs(s: cstring; stream: pointer): cint {.importc: "fputs", header: "stdio.h".}
proc c_abort(): void {.importc: "abort", header: "stdlib.h".}
var c_stderr {.importc: "stderr", header: "stdio.h".}: pointer

{.push stack_trace: off, profiler: off.}

proc rawoutput(s: string) {.nimcall.} =
  discard c_fputs(s.cstring, c_stderr)

proc panic(s: string) {.noreturn.} =
  discard c_fputs(s.cstring, c_stderr)
  c_abort()

{.pop.}