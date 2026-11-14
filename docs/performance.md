# Measuring and profiling

The benchmarks live in `Benchmarks/`, a separate package on
[package-benchmark](https://github.com/ordo-one/package-benchmark), so Urkel's clients never depend on it. Run
everything from the repository root.

## What is measured

| Benchmark | Work |
|---|---|
| `Parse, showcase` | `UrkelParser.parse` on the 24 machines in `Examples/Showcase` |
| `Parse, large` | The same on a synthetic 200-state machine (about 1,000 transitions, guards, actions, hooks, timers, state data, a compound state) |
| `Validate, showcase` / `Validate, large` | `UrkelValidator.validate` on those ASTs |
| `Emit Swift, showcase` / `Emit Swift, large` | `SwiftSyntaxEmitter().emit(file:)`: generating the three Swift files and parsing them back with SwiftParser |
| `Compile, showcase` | Parse, validate and emit, as the build plugin does per file |
| `Format, showcase` | `UrkelParser().format(_:)`: parse and print canonically |

Each reports wall clock, CPU time, mallocs, peak resident memory and retains. The large machine is built by
`Fixtures.largeSource(states:)` in `Benchmarks/Benchmarks/UrkelBenchmarks/UrkelBenchmarks.swift`.

## Measure a change

Save `main`'s numbers before you change code, then compare the same harness after:

```sh
swift package --package-path Benchmarks benchmark --format markdown --no-progress > .build/before.md
# … change the code …
swift package --package-path Benchmarks benchmark --format markdown --no-progress > .build/after.md
swift run --package-path Benchmarks -c release p50 .build/before.md .build/after.md
```

`p50` prints a Markdown table of each benchmark's median wall clock and mallocs, before → after, ready for the pull
request. Malloc and retain counts are deterministic; wall clock moves a few percent between runs, so rerun a benchmark
before trusting a small change.

- `--filter` takes one regular expression per flag and runs the benchmarks that match any of them: repeat the flag
  (`--filter 'Parse.*' --filter 'Validate.*'`) rather than writing `A|B`.
- `benchmark baseline update` / `baseline compare` are package-benchmark's own thresholds and stay available; `p50` is
  for reading the difference at a glance.
- package-benchmark counts mallocs with jemalloc on Swift 6.2 and earlier (`brew install jemalloc`) and with its own
  interposer from Swift 6.3. CI only builds the package, with `BENCHMARK_DISABLE_JEMALLOC=true` so it needs neither.

## Profile a benchmark

```sh
Benchmarks/scripts/profile.sh 'Emit Swift, large' 25
```

It runs that one benchmark under Instruments' Time Profiler and prints:

- **Self**: the functions the samples were in. Standard library entries here say what kind of work dominates
  (`_swift_stdlib_getBinaryProperties` is Unicode property lookups, `_xzm_malloc` allocation, `swift_retain` reference
  counting, `Lexer.Cursor` SwiftParser).
- **Inclusive**: the Urkel, swift-parsing and swift-syntax functions with the most samples under them, which says whose
  work it is.

The trace stays in `Benchmarks/.build/profiles/` to open in Instruments. package-benchmark's ARC and malloc counting
hooks run only while measuring, so the report leaves out samples inside them.

## What has paid off

Measured on an M-series Mac, release build, p50:

| Benchmark | Wall clock p50 (µs) | Mallocs p50 |
|---|---|---|
| Emit Swift, large | 260,000,000 → 762,839 (341× faster) | 39,200,000 → 1,624,417 (0.041×) |
| Emit Swift, showcase | 62,456 → 29,016 (0.46×) | 210,164 → 71,670 (0.34×) |
| Compile, showcase | 99,353 → 28,262 (0.28×) | 216,193 → 76,081 (0.35×) |
| Validate, large | 9,413 → 404 (0.043×) | 90 → 886 (9.8×) |
| Validate, showcase | 310 → 190 (0.61×) | 1,094 → 1,134 (1.04×) |
| Parse, large | 5,222 → 3,162 (0.61×) | 8,268 → 7,359 (0.89×) |
| Parse, showcase | 2,845 → 1,655 (0.58×) | 4,935 → 3,277 (0.66×) |
| Format, showcase | 3,508 → 1,961 (0.56×) | 7,339 → 5,680 (0.77×) |

Retains for `Emit Swift, large` went from 1.1 × 10¹⁰ to 3.5 × 10⁶. Its peak memory (about 700 MB) did not change: it
is the generated source itself, which repeats every closure property in every transition method, and SwiftParser's
tree of it.

- **Derive per-file facts once.** The emitter asked the file the same questions for every method it wrote: every
  closure property the machine stores (each entry rescanning all transitions for guarded siblings), which states run
  timers, a state's hooks and outgoing transitions. That made emission cubic in the number of transitions.
  `SwiftSyntaxEmitter.EmitPlan` answers them once per `emit(file:)`; its members have the names the emitter used to
  read from `UrkelFile`, so the emitting code did not change and the output is byte-identical.
- **Graph searches use an adjacency map.** Reachability scanned every transition for every state it visited. It now
  builds each state's successors once; the extra mallocs are those arrays, and they buy a 23× speed-up.
- **Read ASCII as bytes, not `Character`s.** Grapheme breaking and Unicode property lookups were the parser's largest
  cost, and naming every generated type went through a Foundation `CharacterSet` split. Identifiers, line breaks and
  generated names are scanned as UTF-8 with a fallback to the `Character` path for non-ASCII text, so Unicode
  identifiers behave as before.
- **Emission is now mostly SwiftParser.** About 70% of `Emit Swift, showcase` is parsing the generated files back to
  prove they are valid Swift. That check is the emitter's correctness guarantee, so it stays.
