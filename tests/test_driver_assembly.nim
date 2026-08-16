import std/unittest

import std/os
import std/strutils

import niminpkg/config

suite "niminpkg/driver — command line assembly":

  test "niminCmdLine prepends strict defaults before user args":
    let line = niminCmdLine(@["c", "hello.nmi"])
    check line.startsWith("--mm:arc")
    check line.contains("-d:useMalloc")
    check line.contains("--panics:on")
    check line.contains("hello.nmi")
    # user args come after all defaults
    let defaults = strictSwitches()
    let dIdx = line.find("--mm:arc")
    check line.find("hello.nmi") > dIdx

  test "strictSwitches entries are each present in the command line":
    for s in strictSwitches():
      check niminCmdLine(@["c", "x.nmi"]).contains(s)