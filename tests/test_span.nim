import std/unittest
import std/strutils
import std/posix

import nimin/span

suite "nimin/span — non-allocating views":

  test "toSpan from string creates correct view":
    let s = "hello"
    let sp = toSpan(s)
    check sp.len == 5
    check sp[0] == byte'h'
    check sp[4] == byte'o'

  test "toSpan from openArray":
    let arr = [10, 20, 30]
    let sp = toSpan(arr)
    check sp.len == 3
    check sp[0] == 10
    check sp[2] == 30

  test "empty span":
    let sp = empty[byte]()
    check sp.len == 0
    check sp.isEmpty()

  test "subspan extracts slice":
    let s = "abcdef"
    let sp = toSpan(s)
    let sub = sp.subspan(2, 3)
    check sub.len == 3
    check sub[0] == byte'c'
    check sub[2] == byte'e'

  test "subspan to end":
    let s = "abcdef"
    let sp = toSpan(s)
    let sub = sp.subspan(4)
    check sub.len == 2
    check sub[0] == byte'e'

  test "advance skips elements":
    let s = "abcdef"
    let sp = toSpan(s)
    let adv = sp.advance(3)
    check adv.len == 3
    check adv[0] == byte'd'

  test "equality of identical spans":
    let a = toSpan("abc")
    let b = toSpan("abc")
    check a == b

  test "inequality of different spans":
    let a = toSpan("abc")
    let b = toSpan("abd")
    check not (a == b)

  test "equality with openArray":
    let sp = toSpan("hello")
    check sp == [byte'h', byte'e', byte'l', byte'l', byte'o']

  test "startsWith":
    let sp = toSpan("hello world")
    check sp.startsWith(toSpan("hello"))
    check not sp.startsWith(toSpan("world"))

  test "contains finds substring":
    let sp = toSpan("hello world")
    check sp.contains(toSpan("lo wo"))
    check not sp.contains(toSpan("xyz"))

  test "find returns correct index":
    let sp = toSpan("hello world")
    check sp.find(toSpan("world")) == 6
    check sp.find(toSpan("xyz")) == -1

  test "toString copies out":
    let s = "test string"
    let sp = toSpan(s)
    let copy = sp.toString()
    check copy == "test string"

  test "copyTo writes to buffer":
    var buf: array[3, int]
    let sp = toSpan([100, 200, 300])
    sp.copyTo(addr buf[0])
    check buf[0] == 100
    check buf[1] == 200
    check buf[2] == 300

  test "writeBytes to stdout (smoke)":
    let sp = toSpan("span-ok\n")
    sp.writeBytes(getOsFileHandle(stdout))

  test "iteration covers all elements":
    let sp = toSpan([1, 2, 3, 4, 5])
    var sum = 0
    for val in sp:
      sum += val
    check sum == 15

  test "pairs iteration":
    let sp = toSpan("ab")
    var result = ""
    for i, val in sp:
      result.add($i & ":" & char(val) & " ")
    check result == "0:a 1:b "
