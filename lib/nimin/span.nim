## nimin/span — non-allocating string and value views.
##
## `Span[T]` is a pointer-plus-length view into existing memory.
## All operations are zero-allocation: slicing, comparison, and search
## return views into the caller's buffers. The only allocation escape
## hatch is `toString`, which copies out when you explicitly need a
## heap string.

{.push raises: [].}

import std/posix

type
  Span[T] = object
    ## A non-owning view into a contiguous region of `T` values.
    data: pointer
    len: int

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

proc dataPtr[T](s: Span[T]): ptr UncheckedArray[T] {.inline.} =
  cast[ptr UncheckedArray[T]](s.data)

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

proc initSpan*[T](p: pointer, length: int): Span[T] =
  ## Create a span from a raw pointer and length.
  result.data = p
  result.len = length

proc toSpan*[T](a: openArray[T]): Span[T] =
  ## View an openArray (string, array, seq) as a Span. No copy.
  if a.len == 0:
    result.data = nil
    result.len = 0
  else:
    result.data = unsafeAddr a[0]
    result.len = a.len

proc toSpan*(s: string): Span[byte] =
  ## View a string's bytes as a `Span[byte]`. No copy.
  if s.len == 0:
    result.data = nil
    result.len = 0
  else:
    result.data = unsafeAddr s[0]
    result.len = s.len

proc empty*[T](): Span[T] =
  ## A zero-length span with nil data.
  result.data = nil
  result.len = 0

# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

proc len*[T](s: Span[T]): int {.inline.} =
  ## Number of elements in the span.
  s.len

proc isEmpty*[T](s: Span[T]): bool {.inline.} =
  ## True if the span has zero length.
  s.len == 0

proc raw*[T](s: Span[T]): pointer {.inline.} =
  ## Raw pointer to the first element (may be nil).
  s.data

proc `[]`*[T](s: Span[T], i: int): lent T =
  ## Bounds-checked element access.
  doAssert i >= 0 and i < s.len, "Span index out of bounds"
  s.dataPtr[i]

proc `[]=`*[T](s: Span[T], i: int, val: sink T) =
  ## Bounds-checked write through the span.
  doAssert i >= 0 and i < s.len, "Span index out of bounds"
  s.dataPtr[i] = val

# ---------------------------------------------------------------------------
# Slicing
# ---------------------------------------------------------------------------

proc subspan*[T](s: Span[T], start, length: int): Span[T] =
  ## Return a sub-view starting at `start` with `length` elements.
  doAssert start >= 0 and start + length <= s.len, "subspan out of bounds"
  result.data = cast[pointer](cast[int](s.data) +% start * sizeof(T))
  result.len = length

proc subspan*[T](s: Span[T], start: int): Span[T] =
  ## Return a sub-view from `start` to the end.
  subspan(s, start, s.len - start)

proc advance*[T](s: Span[T], n: int): Span[T] =
  ## Skip the first `n` elements.
  subspan(s, n)

# ---------------------------------------------------------------------------
# Copy out (the only allocation path)
# ---------------------------------------------------------------------------

proc toString*(s: Span[byte]): string =
  ## Copy the byte span into a newly allocated string.
  ## This is the explicit escape hatch — all other ops stay zero-alloc.
  if s.len == 0:
    return ""
  result = newString(s.len)
  copyMem(addr result[0], s.data, s.len)

proc copyTo*[T](src: Span[T], dst: pointer) =
  ## Bulk-copy span contents into a caller-provided buffer.
  ## Caller must ensure the buffer has room for `src.len` elements.
  if src.len > 0:
    copyMem(dst, src.data, src.len * sizeof(T))

# ---------------------------------------------------------------------------
# Comparison
# ---------------------------------------------------------------------------

proc `==`*[T](a, b: Span[T]): bool =
  ## Element-wise equality.
  if a.len != b.len:
    return false
  if a.len == 0:
    return true
  equalMem(a.data, b.data, a.len * sizeof(T))

proc `==`*[T](s: Span[T], other: openArray[T]): bool =
  ## Compare span against an openArray.
  s == toSpan(other)

proc startsWith*[T](s, prefix: Span[T]): bool =
  ## True if `s` begins with `prefix`.
  if prefix.len > s.len:
    return false
  if prefix.len == 0:
    return true
  equalMem(s.data, prefix.data, prefix.len * sizeof(T))

proc contains*[T](haystack, needle: Span[T]): bool =
  ## True if `needle` appears anywhere in `haystack`.
  if needle.len == 0:
    return true
  if needle.len > haystack.len:
    return false
  let limit = haystack.len - needle.len
  for i in 0..limit:
    let slice = haystack.subspan(i, needle.len)
    if equalMem(slice.data, needle.data, needle.len * sizeof(T)):
      return true
  false

proc find*[T](haystack, needle: Span[T]): int =
  ## Return the index of the first occurrence of `needle`, or -1.
  if needle.len == 0:
    return 0
  if needle.len > haystack.len:
    return -1
  let limit = haystack.len - needle.len
  for i in 0..limit:
    let slice = haystack.subspan(i, needle.len)
    if equalMem(slice.data, needle.data, needle.len * sizeof(T)):
      return i
  -1

# ---------------------------------------------------------------------------
# Byte-specific helpers (for io module)
# ---------------------------------------------------------------------------

proc writeBytes*(s: Span[byte], fd: FileHandle) {.inline.} =
  ## Write span contents directly to a file descriptor.
  ## Uses raw POSIX write — no buffering, no allocation.
  if s.len > 0:
    discard posix.write(fd, s.data, s.len)

proc byteAt*(s: Span[byte], i: int): byte {.inline.} =
  ## Read a single byte from the span.
  doAssert i >= 0 and i < s.len, "Span byte index out of bounds"
  s.dataPtr[i]

# ---------------------------------------------------------------------------
# Iteration support
# ---------------------------------------------------------------------------

iterator items*[T](s: Span[T]): lent T =
  ## Iterate over span elements.
  for i in 0..<s.len:
    yield s.dataPtr[i]

iterator pairs*[T](s: Span[T]): (int, lent T) =
  ## Iterate with index.
  for i in 0..<s.len:
    yield (i, s.dataPtr[i])

# ---------------------------------------------------------------------------
# Pretty-printing
# ---------------------------------------------------------------------------

proc `$`*[T](s: Span[T]): string =
  ## Human-readable representation.
  result = "Span["
  result.addInt(s.len)
  result.add("](")
  for i, val in s:
    if i > 0:
      result.add(", ")
    result.add($val)
  result.add(")")
