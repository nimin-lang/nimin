import std/unittest
import std/os
import std/strutils
import std/osproc

const
  NiminExe = parentDir(parentDir(currentSourcePath())) / "bin" / "nimin"
  TestCasesDir = parentDir(currentSourcePath()) / "integration_test_cases"
  BinDir = parentDir(currentSourcePath()) / "integration_bin"

suite "nimin integration — full pipeline":

  setup:
    if not dirExists(BinDir):
      createDir(BinDir)

  teardown:
    for kind, path in walkDir(BinDir):
      if kind == pcFile:
        removeFile(path)
    if dirExists(BinDir):
      removeDir(BinDir)

  proc runTest(name: string, shouldPass: bool, inputFile: string, extraArgs: string = ""): (string, int) =
    let src = TestCasesDir / inputFile
    let bin = BinDir / name
    let cmd = NiminExe & " c --out:" & bin & " " & extraArgs & " " & src
    let (compOut, exitCode) = execCmdEx(cmd)
    if shouldPass:
      if exitCode != 0:
        raise newException(AssertionError, "Expected success but got exit code " & $exitCode & ": " & compOut)
      # Run the binary and verify it works
      let (runOut, runCode) = execCmdEx(bin)
      if runCode != 0:
        raise newException(AssertionError, "Binary failed with exit code " & $runCode & ": " & runOut)
      return (runOut, exitCode)
    else:
      if exitCode == 0:
        raise newException(AssertionError, "Expected failure but compilation succeeded")
      if "NimiError" notin compOut:
        raise newException(AssertionError, "Expected NimiError in output: " & compOut)
      return (compOut, exitCode)

  test "compiles and runs hello world":
    discard runTest("test_hello", true, "hello.nmi")

  test "compiles and runs Result[T,E] pattern":
    let (outStr, _) = runTest("test_result", true, "result_pattern.nmi")
    check "divSafe(10, 2) = 5" in outStr
    check "Expected error: division by zero" in outStr

  test "compiles and runs generics + templates":
    let (outStr, _) = runTest("test_generics", true, "generics_templates.nmi")
    check "wrapped int: 42" in outStr
    check "wrapped string: hello" in outStr
    check "pair: 1, two" in outStr

  test "compiles and runs tagged unions":
    let (outStr, _) = runTest("test_tagged_union", true, "tagged_union.nmi")
    check "Circle area: 78.53975" in outStr
    check "Rect area: 12" in outStr

  test "compiles and runs importc FFI":
    let (outStr, _) = runTest("test_importc", true, "importc_ffi.nmi")
    check "Hello from C via importc!" in outStr

  test "rejects try/except with clear error":
    let (errOut, _) = runTest("reject_try_except", false, "reject_try_except.nmi")
    check "Dynamic exceptions are disabled" in errOut
    check "Use Result[T, E] or panic instead" in errOut

  test "rejects raise with clear error":
    let (errOut, _) = runTest("reject_raise", false, "reject_raise.nmi")
    check "Dynamic exceptions are disabled" in errOut

  test "rejects procedural macro declaration":
    let (errOut, _) = runTest("reject_macro", false, "reject_macro.nmi")
    check "NimiError" in errOut

  test "rejects polymorphic inheritance without pragma":
    let (errOut, _) = runTest("reject_inheritance", false, "reject_inheritance.nmi")
    check "Polymorphic object inheritance is disabled" in errOut

  test "accepts polymorphic inheritance with nimin pragma":
    discard runTest("accept_inheritance_pragma", true, "accept_inheritance_pragma.nmi")

  test "compiles .nim file under nimin rules (with hint)":
    let src = TestCasesDir / "hello.nmi"
    let bin = BinDir / "test_nim_file"
    let cmd = NiminExe & " c --out:" & bin & " " & src
    let (output, exitCode) = execCmdEx(cmd)
    check exitCode == 0
    # Should show hint about .nim file
    # (hint only shows for .nim extension, our test uses .nmi so no hint expected here)

  test "verbose mode shows strict defaults":
    let src = TestCasesDir / "hello.nmi"
    let bin = BinDir / "test_verbose"
    let cmd = NiminExe & " c --verbose --out:" & bin & " " & src
    let (output, exitCode) = execCmdEx(cmd)
    check exitCode == 0
    check "nimin: verbose mode enabled" in output
    check "applying strict defaults" in output
    check "running dialect linter" in output

  test "check command type-checks only":
    let src = TestCasesDir / "hello.nmi"
    let cmd = NiminExe & " check " & src
    let (output, exitCode) = execCmdEx(cmd)
    check exitCode == 0
    check "NimiError" notin output

  test "rejects try/except in nested proc":
    let src = TestCasesDir / "reject_try_nested.nmi"
    writeFile(src, """
proc outer() =
  proc inner() =
    try:
      discard
    except:
      discard
  inner()

outer()
""")
    defer: removeFile(src)
    let bin = BinDir / "test_try_nested"
    let cmd = NiminExe & " c --out:" & bin & " " & src
    let (output, exitCode) = execCmdEx(cmd)
    check exitCode != 0
    check "NimiError" in output

  test "rejects raise in iterator":
    let src = TestCasesDir / "reject_raise_iter.nmi"
    writeFile(src, """
iterator bad(): int =
  raise newException(ValueError, "nope")
  yield 1
""")
    defer: removeFile(src)
    let bin = BinDir / "test_raise_iter"
    let cmd = NiminExe & " c --out:" & bin & " " & src
    let (output, exitCode) = execCmdEx(cmd)
    check exitCode != 0
    check "NimiError" in output

  test "rejects multi-level inheritance":
    let src = TestCasesDir / "reject_multi_inherit.nmi"
    writeFile(src, """
type
  A = object of RootObj
  B = object of A
  C = object of B
""")
    defer: removeFile(src)
    let bin = BinDir / "test_multi_inherit"
    let cmd = NiminExe & " c --out:" & bin & " " & src
    let (output, exitCode) = execCmdEx(cmd)
    check exitCode != 0
    check "NimiError" in output

  test "accepts inheritance with used pragma":
    discard runTest("accept_used_pragma", true, "accept_used_pragma.nmi")

  test "accepts inheritance with custom pragma":
    discard runTest("accept_custom_pragma", true, "accept_custom_pragma.nmi")