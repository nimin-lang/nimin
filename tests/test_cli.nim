import std/unittest

import nimin/span
import nimin/cli

suite "nimin/cli — zero-heap argc/argv parser":

  test "initCli from openArray":
    let p = initCli(["--verbose", "file.nim", "-o", "out"])
    check p.remaining() == 4

  test "hasMore":
    var p = initCli(["a", "b"])
    check p.hasMore()
    p.skip()
    check p.hasMore()
    p.skip()
    check not p.hasMore()

  test "peek does not consume":
    var p = initCli(["first", "second"])
    check p.peek() == "first"
    check p.peek() == "first"
    check p.remaining() == 2

  test "nextArg consumes sequentially":
    var p = initCli(["a", "b", "c"])
    check p.nextArg() == "a"
    check p.nextArg() == "b"
    check p.nextArg() == "c"
    check p.nextArg() == ""

  test "nextFlag consumes only flags":
    var p = initCli(["--verbose", "file.nim", "--output=out"])
    check p.nextFlag() == "--verbose"
    check p.nextFlag() == ""  # file.nim is not a flag, not consumed
    p.skip()  # skip file.nim manually
    check p.nextFlag() == "--output=out"

  test "nextShortFlag consumes only short flags":
    var p = initCli(["-v", "file.nim", "-o", "out"])
    check p.nextShortFlag() == "-v"
    check p.nextShortFlag() == ""  # file.nim is not a flag, not consumed
    p.skip()  # skip file.nim
    check p.nextShortFlag() == "-o"
    check p.nextShortFlag() == ""  # "out" is not a flag

  test "skip advances position":
    var p = initCli(["a", "b", "c", "d"])
    p.skip(2)
    check p.nextArg() == "c"
    check p.nextArg() == "d"

  test "isFlag detects --long flags":
    check isFlag("--verbose")
    check isFlag("--output=file")
    check not isFlag("file.nim")
    check not isFlag("-v")
    check not isFlag("--")

  test "isShortFlag detects -x flags":
    check isShortFlag("-v")
    check isShortFlag("-o")
    check not isShortFlag("--verbose")
    check not isShortFlag("file.nim")
    check not isShortFlag("-")

  test "flagValue extracts value after prefix":
    check flagValue("--output=file", "--output=") == "file"
    check flagValue("--name=hello", "--name=") == "hello"
    check flagValue("--verbose", "--output=") == ""

  test "flagName extracts name without dashes":
    check flagName("--verbose") == "verbose"
    check flagName("-v") == "v"
    check flagName("--output=file") == "output"

  test "argAt accesses by index":
    let p = initCli(["first", "second", "third"])
    check p.argAt(0) == "first"
    check p.argAt(2) == "third"
    check p.argAt(5) == ""

  test "mixed flags and positionals":
    var p = initCli(["prog", "--verbose", "input.txt", "-o", "output.txt"])
    check p.nextArg() == "prog"  # program name
    check p.nextFlag() == "--verbose"
    check p.nextArg() == "input.txt"
    check p.nextShortFlag() == "-o"
    check p.nextArg() == "output.txt"
    check not p.hasMore()

  test "empty args":
    var p = initCli([""])
    # Test with no meaningful args
    check p.remaining() == 1
    check p.nextArg() == ""

  test "nextSpan returns Span view":
    var p = initCli(["hello", "world"])
    let s = p.nextSpan()
    check s.len == 1
    check s[0] == "hello"

  test "peekSpan without consuming":
    var p = initCli(["a", "b"])
    let s = p.peekSpan()
    check s.len == 1
    check s[0] == "a"
    check p.remaining() == 2
