import std/unittest

import std/os
import std/strutils

const
  PanicOverrideFile = currentSourcePath().parentDir / ".." / "src" /
    "niminpkg" / "panicoverride.nim"
  PanicOverrideSrc = staticRead(PanicOverrideFile)

suite "niminpkg/panicoverride — minimal runtime shim":

  test "bundled panicoverride module exists":
    check fileExists(PanicOverrideFile)

  test "declares both procs required by system.nim standalone include":
    check "proc panic(" in PanicOverrideSrc
    check "proc rawoutput(" in PanicOverrideSrc

  test "uses only raw C FFI (no stdlib formatting/allocations)":
    check "import std/" notin PanicOverrideSrc
    check "importc" in PanicOverrideSrc
    check "c_fputs" in PanicOverrideSrc
    check "c_abort" in PanicOverrideSrc
    check "echo" notin PanicOverrideSrc
    check "&" notin PanicOverrideSrc