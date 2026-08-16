import std/[os, strutils, osproc]

## Binary-size benchmark: nimin vs standard nim.
## Compares size of the resulting binary for each baseline program.

const
  BenchDir = "bench/programs"
  NiminBin = "bin/nimin"

type Program = object
  name: string
  src: string

const Programs = [
  Program(name: "hello", src: "hello.nmi"),
  Program(name: "cli",   src: "cli.nmi"),
  Program(name: "json",  src: "json.nmi"),
]

proc size(path: string): int =
  if fileExists(path): int(getFileSize(path)) else: -1

proc buildWith(compiler: string; src, outp, work: string) =
  if not dirExists(work): createDir(work)
  let res = execCmdEx(compiler & " c --out:" & outp & " " & src)
  if res.exitCode != 0:
    echo "  build failed: ", res.output
    quit(1)

proc main() =
  echo "nimin vs nim binary-size benchmark\n"
  echo "  program    | nimin      | nim (release, stripped)"
  echo "  -----------+------------+------------------------"
  for p in Programs:
    let work = BenchDir / p.name
    let src = BenchDir / p.name & "/" & p.src
    let outNimin = work & "/out_nimin"
    let outNim = work & "/out_nim"
    buildWith(NiminBin, src, outNimin, work)
    buildWith("nim -d:release", src, outNim, work)
    let sNimin = size(outNimin)
    let sNim = size(outNim)
    let pct = if sNim > 0: (100 - (sNimin * 100 div sNim)) else: 0
    echo "  " & p.name.alignLeft(10) & " | " & ($sNimin).align(10) &
         " | " & ($sNim).align(10) & "  (" & $pct & "% smaller)"

main()