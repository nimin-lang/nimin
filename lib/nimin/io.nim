## nimin/io — zero-heap console I/O.
##
## This module replaces Nim's `echo` and `strformat` with allocation-free
## alternatives suitable for constrained runtimes. Two principles govern
## every proc here:
##
## 1. **No libc buffering.** Output goes through raw POSIX `write(2)`,
##    bypassing `stdio` entirely. This avoids hidden `malloc` calls for
##    buffer allocation and gives deterministic write semantics.
## 2. **No internal allocation.** Integer formatting writes into a
##    caller-provided byte buffer (typically a `array[N, byte]` on the
##    stack). The formatted result is a `Span[byte]` pointing into that
##    buffer — no heap touch.
##
## **Quick example:**
##
## .. code-block:: nim
##
##   import nimin/io
##
##   print("hello\n")        # raw write to stdout
##   printInt(42)             # format + write, stack-only
##   printErr("error\n")     # same, but to stderr

{.push raises: [].}

import std/posix
import span

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const
  Newline = byte('\n')
    ## The newline character as a byte literal.

  Minus = byte('-')
    ## The minus sign for negative integer formatting.

  Digits = "0123456789"
    ## Lookup table for ASCII digit characters.

# ---------------------------------------------------------------------------
# Raw output
# ---------------------------------------------------------------------------

proc writeRaw*(fd: FileHandle, s: Span[byte]) {.inline.} =
  ## Write a byte span directly to a file descriptor.
  ##
  ## This is the lowest-level output primitive. It delegates to
  ## `nimin/span`'s `writeBytes`, which calls POSIX `write(2)`.
  ## No buffering, no allocation, no flushing — bytes go straight
  ## to the kernel.
  s.writeBytes(fd)

proc writeNewline*(fd: FileHandle) {.inline.} =
  ## Write a single newline byte (`0x0A`) to `fd`.
  var nl = Newline
  discard posix.write(fd, addr nl, 1)

proc print*(s: Span[byte]) {.inline.} =
  ## Write a byte span + newline to stdout.
  ##
  ## This is the primary output proc for nimin programs. It combines
  ## `writeRaw` and `writeNewline` into a single call.
  stdout.getFileHandle().writeRaw(s)
  stdout.getFileHandle().writeNewline()

proc printErr*(s: Span[byte]) {.inline.} =
  ## Write a byte span + newline to stderr.
  ##
  ## Useful for error messages and diagnostics that must not be
  ## interleaved with normal stdout output.
  stderr.getFileHandle().writeRaw(s)
  stderr.getFileHandle().writeNewline()

proc print*(text: string) {.inline.} =
  ## Write a string + newline to stdout.
  ##
  ## Convenience overload that wraps the string in a `Span[byte]`.
  ## The string itself is not allocated by this proc — it must
  ## already exist on the heap or stack.
  print(toSpan(text))

proc printErr*(text: string) {.inline.} =
  ## Write a string + newline to stderr.
  ##
  ## Convenience overload. Same semantics as the `Span[byte]`
  ## version but accepts a `string` directly.
  printErr(toSpan(text))

# ---------------------------------------------------------------------------
# Integer formatting into caller buffer
# ---------------------------------------------------------------------------

proc formatIntLen*(val: int): int =
  ## How many bytes `formatInt` will write (including optional minus sign).
  ##
  ## Call this first to size your buffer, then call `formatInt` with
  ## a span of at least this length. Example:
  ##
  ## .. code-block:: nim
  ##
  ##   var buf: array[24, byte]
  ##   let needed = formatIntLen(42)   # returns 2
  ##   let span = initSpan(addr buf[0], buf.len)
  ##   let formatted = span.formatInt(42)
  if val == 0:
    return 1
  var v = val
  result = 0
  if v < 0:
    result = 1
    # Handle the int.low edge case where -val would overflow.
    if v == int.low:
      # int.low = -9223372036854775808, which has 19 digits + minus = 20 bytes.
      return 20
    v = -v
  while v > 0:
    inc result
    v = v div 10

proc formatInt*(buf: Span[byte], val: int): Span[byte] =
  ## Format an integer into `buf`, returning a span of the written bytes.
  ##
  ## Caller must ensure `buf.len >= formatIntLen(val)`. The returned
  ## span is a sub-view of `buf` covering exactly the formatted digits.
  ## No heap allocation — this is pure pointer arithmetic into the
  ## caller's buffer.
  ##
  ## Handles zero, positive, negative, and `int.low` (the tricky
  ## edge case where `-int.low` overflows).
  let needed = formatIntLen(val)
  doAssert buf.len >= needed, "formatInt buffer too small"

  var v = val
  var pos = needed - 1

  if v == 0:
    buf.dataPtr[0] = byte('0')
    return buf.subspan(0, 1)

  if v < 0:
    buf.dataPtr[0] = Minus
    if v == int.low:
      # Special case: format the absolute value digit-by-digit
      # int.low = -9223372036854775808
      const lowDigits = "9223372036854775808"
      for i in 0..<lowDigits.len:
        buf.dataPtr[i + 1] = byte(lowDigits[i])
      return buf.subspan(0, needed)
    v = -v

  while v > 0:
    buf.dataPtr[pos] = byte(Digits[v mod 10])
    v = v div 10
    dec pos

  buf.subspan(0, needed)

# ---------------------------------------------------------------------------
# Write helpers that take strings directly
# ---------------------------------------------------------------------------

proc writeRaw*(fd: FileHandle, text: string) {.inline.} =
  ## Write a raw string to a file descriptor.
  ##
  ## Bypasses libc buffering — bytes go directly to the kernel via
  ## POSIX `write(2)`. No allocation, no flushing.
  if text.len > 0:
    discard posix.write(fd, unsafeAddr text[0], text.len)

proc writeRaw*(fd: FileHandle, c: char) {.inline.} =
  ## Write a single character to a file descriptor.
  var ch = byte(c)
  discard posix.write(fd, addr ch, 1)

proc writeNewline*(fd: FileHandle, text: string) =
  ## Write a string + newline to a file descriptor.
  ##
  ## Convenience for combining output with a trailing newline
  ## without needing two separate calls.
  fd.writeRaw(text)
  fd.writeNewline()

# ---------------------------------------------------------------------------
# Convenience integer printing
# ---------------------------------------------------------------------------

proc printInt*(val: int) =
  ## Format and write an integer + newline to stdout.
  ##
  ## Uses a 24-byte stack buffer — enough for any `int64` value
  ## including `int.low`. No heap allocation. The formatting is
  ## done by `formatInt` into the stack buffer, then written via
  ## raw POSIX `write(2)`.
  var stackBuf: array[24, byte] # enough for any int64
  let buf = initSpan(addr stackBuf[0], stackBuf.len)
  let formatted = buf.formatInt(val)
  formatted.writeBytes(stdout.getFileHandle())
  stdout.getFileHandle().writeNewline()

proc printInt*(val: int, fd: FileHandle) =
  ## Format and write an integer + newline to a file descriptor.
  ##
  ## Same as the stdout version but targets an arbitrary file
  ## descriptor. Useful for writing to stderr or custom pipes.
  var stackBuf: array[24, byte]
  let buf = initSpan(addr stackBuf[0], stackBuf.len)
  let formatted = buf.formatInt(val)
  formatted.writeBytes(fd)
  fd.writeNewline()
