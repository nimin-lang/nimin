# Package

version       = "0.1.0"
author        = "nimin contributors"
description   = "The symmetrical, zero-baggage dialect of Nim for tiny binaries and constrained runtimes."
license       = "MIT"

srcDir        = "src"
bin           = @["nimin"]
binDir        = "bin"
installDirs   = @["lib"]

# Building nimin itself requires the Nim compiler modules and defines.
switch("path", "$nim")
switch("define", "nimcore")
switch("path", "lib")

task test, "Run the nimin test suite":
  exec "nim c -r --path:src tests/test_config.nim"
  exec "nim c -r --path:src tests/test_driver_assembly.nim"
  exec "nim c -r --path:src tests/test_panicoverride.nim"
  exec "nim c -r --path:src --path:lib tests/test_linter.nim"
  exec "nim c -r --path:src --path:lib tests/test_span.nim"
  exec "nim c -r --path:src --path:lib tests/test_io.nim"
  exec "nim c -r --path:src --path:lib tests/test_cli.nim"

task bench, "Compare nimin vs standard nim binary sizes":
  exec "nim c -o:bench/bench bench/bench.nim"
  exec "./bench/bench"