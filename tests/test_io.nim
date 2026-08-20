import std/unittest
import std/posix

import nimin/span
import nimin/io

suite "nimin/io — zero-heap console I/O":

  test "formatIntLen zero":
    check formatIntLen(0) == 1

  test "formatIntLen positive":
    check formatIntLen(42) == 2
    check formatIntLen(100) == 3
    check formatIntLen(123456789) == 9

  test "formatIntLen negative":
    check formatIntLen(-1) == 2
    check formatIntLen(-42) == 3
    check formatIntLen(-1000) == 5

  test "formatInt zero":
    var buf: array[24, byte]
    let span = initSpan(addr buf[0], buf.len)
    let result = span.formatInt(0)
    check result.len == 1
    check result[0] == byte('0')

  test "formatInt positive":
    var buf: array[24, byte]
    let span = initSpan(addr buf[0], buf.len)
    let result = span.formatInt(42)
    check result.toString() == "42"

  test "formatInt negative":
    var buf: array[24, byte]
    let span = initSpan(addr buf[0], buf.len)
    let result = span.formatInt(-42)
    check result.toString() == "-42"

  test "formatInt large positive":
    var buf: array[24, byte]
    let span = initSpan(addr buf[0], buf.len)
    let result = span.formatInt(123456789)
    check result.toString() == "123456789"

  test "formatInt large negative":
    var buf: array[24, byte]
    let span = initSpan(addr buf[0], buf.len)
    let result = span.formatInt(-123456789)
    check result.toString() == "-123456789"

  test "printInt to stdout (smoke)":
    printInt(42)

  test "printInt to stderr (smoke)":
    printInt(-99, getOsFileHandle(stderr))

  test "print string to stdout (smoke)":
    print("io-test-ok")

  test "printErr string to stderr (smoke)":
    printErr("io-err-ok")
