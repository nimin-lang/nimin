# Changelog

All notable changes to nimin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-08-20

### Added

#### Core Driver
- `nimin` CLI binary — drives the Nim compiler as a library with strict defaults
- Commands: `nimin c`, `nimin check`, `nimin --version`, `nimin --help`, `nimin --verbose`
- Mirrors `nim` command interface for zero learning curve
- Automatic provisioning of `panicoverride.nim` for standalone targets

#### Strict Compilation Defaults (injected automatically)
- Memory: `--mm:arc -d:useMalloc` (ARC + system malloc, no GC)
- Error handling: `--panics:on --exceptions:quirky -d:danger` (panic-only, no dynamic exceptions)
- Optimization: `--opt:size` (size-optimized codegen)
- C compiler flags: `-Os -flto -ffunction-sections -fdata-sections -Wl,--gc-sections`
- User flags override defaults when explicitly provided

#### Dialect Linter (semantic guardrails)
- Rejects dynamic exceptions: `try/except/finally`, `raise` — with clear `NimiError` diagnostics
- Rejects procedural `macro` declarations — suggests templates/generics/`importc`
- Rejects polymorphic object inheritance without explicit pragma — suggests tagged unions or pragma opt-in
- Accepts inheritance with any explicit pragma (e.g., `{.used.}`, `{.exportc.}`)
- Two-pass design: type-section linting (parsed AST) + routine-body linting (`strongSemCheck` hook)

#### Micro-stdlib (zero-heap, no libc buffering)
- **`nimin/span`** — `Span[T]` non-owning views over existing memory
  - Construction: `toSpan`, `initSpan`, `empty`
  - Slicing: `subspan`, `advance`
  - Comparison: `==`, `startsWith`, `contains`, `find`
  - Iteration: `items`, `pairs` (lent references, zero allocation)
  - Escape hatch: `toString()` for explicit heap copy
- **`nimin/io`** — raw POSIX `write(2)` console I/O
  - `print`, `printErr` — string/byte span + newline to stdout/stderr
  - `printInt` — integer formatting into caller's stack buffer (24 bytes, handles `int.low`)
  - `writeRaw`, `writeNewline` — low-level primitives
  - No libc buffering, no allocation in hot paths
- **`nimin/cli`** — zero-allocation argc/argv parser
  - `CliParser` — stateful parser over `Span[string]`
  - Flag handling: `nextFlag`, `nextShortFlag`, `isFlag`, `isShortFlag`
  - Positional handling: `nextArg`, `skip`, `peek`
  - Inspection: `flagName`, `flagValue`, `argAt`
  - Results borrow from original argv — zero allocation

#### Panic Override for Standalone
- Bundled `panicoverride.nim` with minimal `panic` and `rawoutput` procs
- Raw C FFI only (`c_fputs`, `c_abort`) — no stdlib, no allocation
- Auto-provisioned to project dir when `--os:standalone` detected

#### Test Suite
- 42 unit tests covering config, driver, panicoverride, linter, span, io, cli
- 19 integration tests covering full pipeline (compile + run + verify output/rejection)
- Total: 61 tests passing

#### Benchmarks
- 3 benchmark programs: hello, cli, json
- Binary size comparison: nimin vs standard Nim (~70-80% reduction)
- `nimble bench` runs comparison

### Changed
- N/A (initial release)

### Deprecated
- N/A (initial release)

### Removed
- N/A (initial release)

### Fixed
- N/A (initial release)

### Security
- N/A (initial release)

## Known Limitations (v0.1.0)

See [README.md#limitations] for comprehensive list. Summary:

- **No dynamic exceptions** — use `Result[T, E]` or `panic`
- **No procedural macros** — use templates/generics/`importc`
- **No polymorphic inheritance without pragma** — use tagged unions
- **No GC** — ARC only; reference cycles leak
- **No standard library** — no `seq`, `Table`, `unicode`, `async`, `threads`, `httpclient`, file I/O
- **Micro-stdlib scope** — only `span`, `io`, `cli` (designed for nimin's own needs)
- **No package manager** for nimin packages
- **No automated migration tool** — existing Nim code requires manual rewrite
- **No LSP/IDE integration** — dialect errors only at compile time
- **Windows untested** — POSIX-only micro-stdlib

---

[0.1.0]: https://github.com/nimin-lang/nimin/releases/tag/v0.1.0