## nimin/span — non-allocating string and value views.
##
## `Span[T]` is a pointer-plus-length view into existing memory, analogous
## to C++ `std::span` or Rust's `&[T]`. It is the foundational type for
## nimin's zero-heap micro-stdlib: every other module (`io`, `cli`) builds
## on spans instead of allocating fresh strings or sequences.
##
## **Design rules:**
##
## - All operations are zero-allocation: slicing, comparison, and search
##   return views into the caller's buffers.
## - The only allocation escape hatch is `toString`, which copies out
##   when you explicitly need a heap string.
## - Bounds checks use `doAssert` (stripped in `-d:danger` builds).
## - The span does not own its memory. The caller must ensure the
##   underlying buffer outlives every `Span` that references it.
##
## **Quick example:**
##
## .. code-block:: nim
##
##   let text = "hello world"
##   let view = toSpan(text)          # Span[byte] pointing into `text`
##   let sub = view.subspan(6, 5)     # "world" — same memory, no copy
##   echo sub.toString()              # "world" — explicit heap copy

{.push raises: [].}

import std/posix

type
  Span*[T] = object
    ## A non-owning view into a contiguous region of `T` values.
    ##
    ## Fields are private — construct via `toSpan`, `initSpan`, or
    ## `empty`. A span carries a raw pointer and a length; it does
    ## **not** track capacity, ownership, or lifetime.
    data: pointer
    len: int

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

proc dataPtr*[T](s: Span[T]): ptr UncheckedArray[T] {.inline.} =
  ## Access the underlying element buffer as an unchecked array.
  ## This is the low-level primitive that `[]`, `items`, and `pairs`
  ## all delegate to. Exported so that `nimin/io` can format integers
  ## directly into a span's backing memory.
  cast[ptr UncheckedArray[T]](s.data)

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

proc initSpan*[T](p: ptr T, length: int): Span[T] =
  ## Create a span from a raw pointer and length.
  ##
  ## Use this when you already have a buffer (e.g. a stack array)
  ## and want to hand a view into it. The pointer may be `nil` when
  ## `length` is zero.
  result.data = p
  result.len = length

proc toSpan*[T](a: openArray[T]): Span[T] =
  ## View an `openArray` (string, array, seq) as a `Span`. No copy.
  ##
  ## This is the primary constructor. It works with any type that
  ## Nim treats as an `openArray` — including `string`, `seq[T]`,
  ## and `array[N, T]`. The span points into the original memory;
  ## mutating the source data will be visible through the span and
  ## vice-versa.
  if a.len == 0:
    result.data = nil
    result.len = 0
  else:
    result.data = unsafeAddr a[0]
    result.len = a.len

proc toSpan*(s: string): Span[byte] =
  ## View a string's bytes as a `Span[byte]`. No copy.
  ##
  ## This overload exists because `string` is not a generic
  ## `openArray` in Nim's type system — it needs its own binding
  ## to produce a byte span.
  if s.len == 0:
    result.data = nil
    result.len = 0
  else:
    result.data = unsafeAddr s[0]
    result.len = s.len

proc empty*[T](): Span[T] =
  ## A zero-length span with nil data.
  ##
  ## Useful as a sentinel or default value when you need to
  ## represent "nothing" without allocating.
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
  ##
  ## Escape hatch for FFI or low-level code that needs the
  ## underlying pointer. Prefer `[]` or `items` for normal access.
  s.data

proc `[]`*[T](s: Span[T], i: int): lent T =
  ## Bounds-checked element access. Returns a lent reference so
  ## no copy is made for non-trivial types.
  doAssert i >= 0 and i < s.len, "Span index out of bounds"
  s.dataPtr[i]

proc `[]=`*[T](s: Span[T], i: int, val: sink T) =
  ## Bounds-checked write through the span.
  ##
  ## This is safe because the span borrows the caller's memory;
  ## writes go directly into the original buffer.
  doAssert i >= 0 and i < s.len, "Span index out of bounds"
  s.dataPtr[i] = val

# ---------------------------------------------------------------------------
# Slicing
# ---------------------------------------------------------------------------

proc subspan*[T](s: Span[T], start, length: int): Span[T] =
  ## Return a sub-view starting at `start` with `length` elements.
  ##
  ## The sub-span shares memory with the original — no copy, no
  ## allocation. Panics (via `doAssert`) if the range exceeds the
  ## parent span's bounds.
  doAssert start >= 0 and start + length <= s.len, "subspan out of bounds"
  result.data = cast[pointer](cast[int](s.data) +% start * sizeof(T))
  result.len = length

proc subspan*[T](s: Span[T], start: int): Span[T] =
  ## Return a sub-view from `start` to the end of the span.
  subspan(s, start, s.len - start)

proc advance*[T](s: Span[T], n: int): Span[T] =
  ## Skip the first `n` elements, returning the remainder.
  ##
  ## Equivalent to `subspan(s, n)` but reads more clearly when
  ## you're consuming a stream of data byte-by-byte.
  subspan(s, n)

# ---------------------------------------------------------------------------
# Copy out (the only allocation path)
# ---------------------------------------------------------------------------

proc toString*(s: Span[byte]): string =
  ## Copy the byte span into a newly allocated string.
  ##
  ## This is the **explicit** allocation escape hatch — every other
  ## operation in this module stays zero-alloc. Call this only when
  ## you genuinely need a heap-owning `string` (e.g. for APIs that
  ## require one).
  if s.len == 0:
    return ""
  result = newString(s.len)
  copyMem(addr result[0], s.data, s.len)

proc copyTo*[T](src: Span[T], dst: pointer) =
  ## Bulk-copy span contents into a caller-provided buffer.
  ##
  ## Caller must ensure `dst` has room for at least `src.len`
  ## elements. No allocation — this is a raw `memcpy`.
  if src.len > 0:
    copyMem(dst, src.data, src.len * sizeof(T))

# ---------------------------------------------------------------------------
# Comparison
# ---------------------------------------------------------------------------

proc `==`*[T](a, b: Span[T]): bool =
  ## Element-wise equality. Two spans are equal if they have the
  ## same length and identical contents. Zero-length spans are
  ## always equal regardless of their data pointer.
  if a.len != b.len:
    return false
  if a.len == 0:
    return true
  equalMem(a.data, b.data, a.len * sizeof(T))

proc `==`*[T](s: Span[T], other: openArray[T]): bool =
  ## Compare span against an openArray. Convenience overload so
  ## you can write `span == @[1, 2, 3]` without converting first.
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
  ##
  ## Uses a linear scan. For repeated searches on the same
  ## haystack, consider building a skip table instead.
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
  ## Return the index of the first occurrence of `needle`, or -1
  ## if not found. Returns 0 for an empty needle.
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
  ##
  ## Uses raw POSIX `write(2)` — no libc buffering, no allocation.
  ## This is the primitive that `nimin/io`'s `print` and `printErr`
  ## delegate to for the actual output.
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
  ##
  ## Yields `lent T` references — no copies, no allocation.
  ## Works naturally with `for` loops:
  ##
  ## .. code-block:: nim
  ##
  ##   for ch in mySpan:
  ##     process(ch)
  for i in 0..<s.len:
    yield s.dataPtr[i]

iterator pairs*[T](s: Span[T]): (int, lent T) =
  ## Iterate with index. Yields `(index, element)` pairs.
  ##
  ## .. code-block:: nim
  ##
  ##   for i, ch in mySpan:
  ##     echo i, ": ", ch
  for i in 0..<s.len:
    yield (i, s.dataPtr[i])

# ---------------------------------------------------------------------------
# Pretty-printing
# ---------------------------------------------------------------------------

proc `$`*[T](s: Span[T]): string =
  ## Human-readable representation: `Span[N](elem0, elem1, ...)`.
  ##
  ## This allocates (it builds a string), so use it only for
  ## logging or debugging — never in hot paths.
  result = "Span["
  result.addInt(s.len)
  result.add("](")
  for i, val in s:
    if i > 0:
      result.add(", ")
    result.add($val)
  result.add(")")
