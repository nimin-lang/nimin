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

## Current Status

nimin is in active development toward v0.1.0. Current working features:

- ✅ Driver pipeline with strict compilation defaults
- ✅ Benchmark harness showing significant size reductions
- ✅ Panic override for standalone builds
- ✅ Dialect linter — rejects exceptions, macros, unchecked inheritance
- 🔄 Micro-stdlib modules (in progress: span, io, cli)
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