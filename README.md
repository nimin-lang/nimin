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
- 🔄 Packaging for nimble install (planned)

## Quick Start

```bash
# Compile a Nim file with nimin
nimin c hello.nim

# Compare binary sizes
ls -la hello  # nimin-compiled
nim c -d:release hello.nim  # standard Nim
ls -la hello  # standard-compiled
```

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

MIT

## Contributing

See the `.development/` directory for project documentation, architecture decisions, and development guidelines.