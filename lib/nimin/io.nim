## nimin/io — zero-heap console I/O.
##
## Replaces `echo` and `fmt` with allocation-free alternatives.
## All formatting writes into caller-provided byte buffers.
## Raw output uses POSIX `write()` — no libc buffering, no tables.

{.push raises: [].}

import std/posix
import span

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const
  Newline = byte('\n')
  Minus = byte('-')
  Digits = "0123456789"

# ---------------------------------------------------------------------------
# Raw output
# ---------------------------------------------------------------------------

proc writeRaw*(fd: FileHandle, s: Span[byte]) {.inline.} =
  ## Write a span directly to a file descriptor.
  s.writeBytes(fd)

proc writeNewline*(fd: FileHandle) {.inline.} =
  ## Write a single newline to `fd`.
  var nl = Newline
  discard posix.write(fd, addr nl, 1)

proc print*(s: Span[byte]) {.inline.} =
  ## Write span + newline to stdout.
  stdout.getFileHandle().writeRaw(s)
  stdout.getFileHandle().writeNewline()

proc printErr*(s: Span[byte]) {.inline.} =
  ## Write span + newline to stderr.
  stderr.getFileHandle().writeRaw(s)
  stderr.getFileHandle().writeNewline()

proc print*(text: string) {.inline.} =
  ## Write string + newline to stdout (convenience, allocates the string but not internally).
  print(toSpan(text))

proc printErr*(text: string) {.inline.} =
  ## Write string + newline to stderr.
  printErr(toSpan(text))

# ---------------------------------------------------------------------------
# Integer formatting into caller buffer
# ---------------------------------------------------------------------------

proc formatIntLen*(val: int): int =
  ## How many bytes `formatInt` will write (including optional minus sign).
  if val == 0:
    return 1
  var v = val
  result = 0
  if v < 0:
    result = 1
    # Handle int low edge case
    if v == int.low:
      # int.low = -9223372036854775808, digits = "9223372036854775808" (19 digits)
      return 20
    v = -v
  while v > 0:
    inc result
    v = v div 10

proc formatInt*(buf: Span[byte], val: int): Span[byte] =
  ## Format an integer into `buf`, returning a span of the written bytes.
  ## Caller must ensure `buf.len >= formatIntLen(val)`.
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
  if text.len > 0:
    discard posix.write(fd, unsafeAddr text[0], text.len)

proc writeRaw*(fd: FileHandle, c: char) {.inline.} =
  ## Write a single character to a file descriptor.
  var ch = byte(c)
  discard posix.write(fd, addr ch, 1)

proc writeNewline*(fd: FileHandle, text: string) =
  ## Write text + newline.
  fd.writeRaw(text)
  fd.writeNewline()

# ---------------------------------------------------------------------------
# Convenience integer printing
# ---------------------------------------------------------------------------

proc printInt*(val: int) =
  ## Format and write an integer + newline to stdout.
  ## Uses a small stack buffer — no heap allocation.
  var stackBuf: array[24, byte] # enough for any int64
  let buf = initSpan(addr stackBuf[0], stackBuf.len)
  let formatted = buf.formatInt(val)
  formatted.writeBytes(stdout.getFileHandle())
  stdout.getFileHandle().writeNewline()

proc printInt*(val: int, fd: FileHandle) =
  ## Format and write an integer + newline to a file descriptor.
  var stackBuf: array[24, byte]
  let buf = initSpan(addr stackBuf[0], stackBuf.len)
  let formatted = buf.formatInt(val)
  formatted.writeBytes(fd)
  fd.writeNewline()
