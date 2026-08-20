<p align="center">
  <img src="assets/images/nimin-logo.png" alt="nimin logo" width="66%">
</p>

# nimin

The symmetrical, zero-baggage dialect of Nim for tiny binaries and constrained runtimes.

## Vision

nimin is a compilation dialect that transforms standard Nim code into minimal, predictable binaries optimized for size and constrained environments. It maintains Nim's expressive syntax while stripping away runtime overhead that isn't needed for embedded systems, command-line tools, and resource-constrained applications.

## What nimin Can Do

### Binary Size Optimization
- **70-80% smaller binaries** than standard Nim for simple programs
- **Automatic size optimization** with `-Os` and LTO flags
- **Dead code elimination** via `--gc-sections` linking
- **Stripped runtime checks** - removes array bounds and integer overflow checks
- **Minimal exception handling** - uses "quirky exceptions" without dynamic allocation

### Memory Management
- **ARC (Automatic Reference Counting)** for predictable, low-overhead memory handling
- **No garbage collector pauses** - deterministic memory management
- **Standalone target support** - works on bare-metal or minimal OS environments

### Error Handling
- **Panic-only error model** - errors abort immediately instead of unwinding stacks
- **Auto-provisioned panic handler** - minimal C FFI-based panic handler for standalone builds
- **Enforced predictable error paths** - linter rejects dynamic exceptions, forces `Result[T, E]` patterns

### Development Experience
- **Drop-in replacement for `nim c`** - use `nimin c file.nim` with zero configuration
- **Standard Nim syntax** - no new language to learn
- **Meaningful error messages** - "NimiError" diagnostics explain rejected code
- **Support for both .nim and .nmi files** - compile standard Nim with warnings or dialect-specific files

### Platform Support
- **Portable C code generation** - outputs standard C for any platform with a C compiler
- **Embedded system targeting** - `--os:standalone` for bare-metal environments
- **Cross-compilation ready** - works with any C cross-compiler

### Performance
- **Rapid compilation times** - stripped features enable faster builds
- **Optimized for size over speed** - ideal for storage-constrained environments
- **Minimal runtime overhead** - no unnecessary initialization or cleanup code

### Code Quality
- **Dialect linter** - validates code against nimin's strict rules
- **Enforced coding patterns** - rejects dynamic exceptions, macros, and unchecked polymorphic inheritance
- **Predictable behavior** - no hidden runtime costs or surprises

### Micro-stdlib
- **Zero-heap Span[T]** - non-owning views with slice, search, and iteration
- **Zero-heap I/O** - raw POSIX write with no libc buffering, no allocation
- **Zero-heap CLI parser** - stateful argc/argv scanning with pure pointer arithmetic
- **Caller-allocates** - all buffers provided by the caller, never malloc internally

## Current Status

nimin is in active development toward v0.1.0. Current working features:

- ✅ Driver pipeline with strict compilation defaults
- ✅ Benchmark harness showing significant size reductions
- ✅ Panic override for standalone builds
- ✅ Dialect linter — rejects exceptions, macros, unchecked inheritance
- ✅ Micro-stdlib modules: `nimin/span`, `nimin/io`, `nimin/cli`
- ✅ Packaging for nimble install

## Limitations

nimin achieves its size and predictability goals by **removing Nim runtime features**. These are not bugs — they are the point of the dialect. Be aware before you start:

### Language Features Removed
- **No dynamic exceptions** — `try/except/finally` and `raise` are rejected by the linter. Use `Result[T, E]` or `panic`.
- **No procedural `macro` declarations** — rejected. Use templates, generics, or `importc` for metaprogramming.
- **No polymorphic object inheritance without explicit pragma** — `type Derived = object of Base` is rejected unless the derived type carries any pragma (e.g., `{.used.}`, `{.exportc.}`). Use tagged unions instead.
- **No garbage collector** — `--mm:arc -d:useMalloc` only. Reference cycles leak; break them manually or use weak references.
- **No runtime bounds checks in release** — `-d:danger` strips `doAssert` checks. Your code must be correct.

### Standard Library Not Available
- **No `seq`, `Table`, `HashSet`, `Array`** — these allocate. Use `Span[T]` over fixed-size arrays or caller-allocated buffers.
- **No `unicode` module** — no UTF-8 iteration, rune navigation, or case folding. `nimin/span` operates on bytes only.
- **No `streams`, `asyncdispatch`, `threads`** — no async, no thread pool, no channels.
- **No `httpclient`, `json` (partial), `strutils` (partial), `os` (partial)** — most stdlib modules transitively depend on GC, exceptions, or allocation.
- **No file I/O in micro-stdlib** — `nimin/io` only does raw POSIX `write(2)` to stdout/stderr. No `readFile`, `open`, `walkDir`.

### Platform Constraints
- **Standalone target is minimal** — `--os:standalone --gc:none` works but provides only `panic` and `rawoutput`. No `exitprocs`, no signals, no terminal control.
- **Windows support untested** — primary target is POSIX (Linux, macOS, *BSD). Windows may work but is not validated.
- **No Windows micro-stdlib** — `nimin/cli` and `nimin/io` use POSIX APIs only.

### Ecosystem Gaps
- **No package manager for nimin packages** — `nimble` installs nimin itself, but nimin-compiled packages don't have a registry.
- **No automated migration tool** — existing Nim code must be manually rewritten to comply with the dialect.
- **No LSP/IDE integration** — dialect errors only appear at compile time via `nimin c`.
- **No standard test framework** — `std/unittest` uses exceptions/macros and may not compile under nimin.

### Micro-stdlib Scope
The micro-stdlib (`span`, `io`, `cli`) is **designed for nimin's own needs**, not as a general-purpose replacement. It covers:
- `Span[T]` — non-owning views, slicing, search, iteration
- `print`/`printInt`/`printErr` — raw POSIX output, stack-only integer formatting
- `CliParser` — zero-allocation argc/argv scanning

It does **not** cover: string manipulation, parsing, sorting, hashing, file I/O, terminal control, containers, or time/date handling.

## Appropriate Targets

nimin is **not a drop-in replacement for general Nim development**. It fits these project profiles:

- **Tiny CLI tools** — single-purpose utilities where binary size matters (10-50 KB target)
- **Embedded firmware** — bare-metal or RTOS targets with `--os:standalone --gc:none`
- **WASM modules** — size-constrained WebAssembly where every KB counts
- **Container sidecars / init processes** — minimal binaries in distroless/scratch images
- **Bootloaders / installers / recovery tools** — standalone, no runtime dependencies
- **Signal processing / DSP kernels** — tight loops with fixed buffers, no allocation
- **Cryptographic primitives** — deterministic memory, no GC pauses, panic on error
- **Protocol parsers / serializers** — bounded input, explicit error handling via `Result`

### Not Suitable For
- **GUI/TUI applications** — no terminal input, no event loop, no Unicode text handling
- **Web servers / HTTP services** — no `async`, no `httpclient`, no `json` (usable but limited)
- **Data processing pipelines** — no `seq`, `Table`, `streams`, `strutils` richness
- **Scripting / rapid prototyping** — strict linter slows iteration; use standard Nim
- **Large existing codebases** — migration is manual rewrite, not mechanical translation
- **Anything needing dynamic data structures** — no growable collections, no hash tables

## Quick Start

```bash
# Compile a Nim file with nimin
nimin c hello.nim

# Show detailed build diagnostics
nimin c --verbose hello.nim

# Compare binary sizes
ls -la hello  # nimin-compiled
nim c -d:release hello.nim  # standard Nim
ls -la hello  # standard-compiled
```

## Architecture

```
nimin/
  src/nimin.nim          # CLI binary — drives Nim compiler as a library
  src/niminpkg/          # Internal: config, driver, linter, panic override
  lib/nimin/             # Micro-stdlib — user-importable modules
    span.nim             #   Span[T]: non-owning, zero-heap views
    io.nim               #   Zero-heap console I/O via raw POSIX
    cli.nim              #   Zero-heap argc/argv parser
```

**`src/`** builds the `nimin` executable. It imports Nim compiler modules to drive the compilation pipeline, inject strict defaults, run the linter, and produce a C file that GCC/Clang compiles into a tiny binary.

**`lib/`** is what nimin-compiled programs import (`import nimin/span`). It ships with the package via nimble's `installDirs`. The modules follow the dialect's core constraint: caller-allocates buffers, never malloc internally.

**Why one repo:** the stdlib is tightly coupled to nimin's constraints — heap-free, POSIX-only, panic-only error model. Linter or driver changes may require coordinated stdlib updates. The codebase is small enough that separate repos add coordination overhead without benefit. If the stdlib becomes useful outside nimin, it can be split out then.

## Benchmark Results

| Program | Standard Nim | nimin | Reduction |
|---------|--------------|-------|-----------|
| hello   | 77 KB        | 17.6 KB | 77%     |
| cli     | 76 KB        | 17.9 KB | 76%     |
| json    | 144 KB       | 46 KB   | 68%     |

## Micro-stdlib Usage

nimin provides zero-heap alternative modules for common tasks:

```nim
# nimin/span — non-owning views, no allocation
import nimin/span

let text = "hello world"
let view = toSpan(text)
let sub = view.subspan(6, 5)  # "world"
echo sub  # prints "world"

# nimin/io — zero-heap I/O, raw POSIX write
import nimin/io

print("hello\n")          # raw write, no buffering
printInt(42)               # integer format + newline
printErr("error\n")        # stderr

# nimin/cli — zero-heap argument parsing
import nimin/cli

var p = initCli(["--verbose", "input.txt", "-o", "output.txt"])
while p.hasMore():
  if p.hasFlag():
    let f = p.nextFlag()
    let name = f.flagName()
    # parse flag name...
  else:
    let arg = p.nextArg()
    # process positional...
```

## Philosophy

nimin believes in:
- **Zero baggage** - include only what you need
- **Predictable behavior** - no hidden runtime costs
- **Explicit error handling** - no silent failures
- **Minimal footprints** - optimized for constrained environments
- **Standard syntax** - no new language to learn

## License

[MIT](LICENSE)

## Contributing

See the project repository for architecture decisions, development guidelines, and implementation details.

## License

MIT License - Copyright (c) 2026 Antonio Ognio

Made with ❤️ from 🇵🇪. El Perú es clave 🔑.