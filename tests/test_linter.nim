import std/unittest
import std/os
import std/strutils
import std/osproc

import niminpkg/config

const
  NiminExe = parentDir(parentDir(currentSourcePath())) / "bin" / "nimin"
  TestDir = parentDir(currentSourcePath()) / "linter_test_files"

suite "nimin linter — semantic guardrails":

  setup:
    # Create test directory if it doesn't exist
    if not dirExists(TestDir):
      createDir(TestDir)

  teardown:
    # Clean up test files
    for kind, path in walkDir(TestDir):
      if kind == pcFile:
        removeFile(path)
    if dirExists(TestDir):
      removeDir(TestDir)

  test "reject dynamic exceptions (try/except)":
    let testFile = TestDir / "test_try_except.nim"
    writeFile(testFile, """
proc safeDiv(a, b: int): int =
  try:
    result = a div b
  except DivByZeroDefect:
    result = 0
""")
    let cmd = NiminExe & " c " & testFile
    let (output, exitCode) = execCmdEx(cmd)
    check exitCode != 0
    check "NimiError" in output
    check "Dynamic exceptions are disabled" in output

  test "reject dynamic exceptions (raise)":
    let testFile = TestDir / "test_raise.nim"
    writeFile(testFile, """
proc fail(msg: string) {.noreturn.} =
  raise newException(ValueError, msg)
""")
    let cmd = NiminExe & " c " & testFile
    let (output, exitCode) = execCmdEx(cmd)
    check exitCode != 0
    check "NimiError" in output
    check "Dynamic exceptions are disabled" in output

  test "reject procedural macro declarations":
    let testFile = TestDir / "test_macro.nim"
    writeFile(testFile, """
macro myMacro(body: untyped): untyped =
  result = body
""")
    let cmd = NiminExe & " c " & testFile
    let (output, exitCode) = execCmdEx(cmd)
    check exitCode != 0
    check "NimiError" in output
    check "Procedural `macro` declarations are disabled" in output

  test "reject polymorphic inheritance without pragma":
    let testFile = TestDir / "test_inheritance.nim"
    writeFile(testFile, """
type
  Base = object of RootObj
  Derived = object of Base
""")
    let cmd = NiminExe & " c " & testFile
    let (output, exitCode) = execCmdEx(cmd)
    check exitCode != 0
    check "NimiError" in output
    check "Polymorphic object inheritance is disabled" in output

  test "allow polymorphic inheritance with pragma":
    let testFile = TestDir / "test_inheritance_with_pragma.nim"
    writeFile(testFile, """
type
  Base = object of RootObj
  Derived {.used.} = object of Base
""")
    let cmd = NiminExe & " c " & testFile
    let (output, exitCode) = execCmdEx(cmd)
    # Should compile successfully (no NimiError about inheritance)
    check exitCode == 0
    check "NimiError" notin output

  test "allow valid code without restricted constructs":
    let testFile = TestDir / "test_valid.nim"
    writeFile(testFile, """
proc add(a, b: int): int =
  a + b

let x = add(1, 2)
""")
    let cmd = NiminExe & " c " & testFile
    let (output, exitCode) = execCmdEx(cmd)
    check exitCode == 0
    check "NimiError" notin output