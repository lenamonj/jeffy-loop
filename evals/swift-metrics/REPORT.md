# Jeffy eval: apple/swift-metrics

The 795-star Swift metrics API, the `Counter`, `Meter`, `Recorder` and
`Timer` facade whose `MetricsFactory` the Prometheus, StatsD and
OpenTelemetry backends implement. Run 2026-09-05 as the first target of the
1.21.1 acceptance cohort (COHORT-ACCEPTANCE-1211.md). **1 run, 12
iterations, converged** in round 1 at
`782ebd9b1ad7e4442173acb1e8a9ac5cff9998f6`, within a **pre-registered
budget of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `0b89fda24f3626156962609f3410c9e550617766` (main, at 2.11.0) |
| Findings closed | **7** - 1 High, 6 Medium (one of the six was filed Low and re-scored Medium by the gate, see below) |
| Shipped-code change | 8 files, **+236 / -62** (13 lines of it are loop housekeeping, see below) |
| Surface inventory | **23 of 23 rows swept** |
| Ledger at convergence | 2 Lows carried (`F-007`, `F-008`); four gate observations recorded for the next run |
| Evaluator | **2 invocations: REJECT, then PASS** |
| Suite at convergence | `swift test`: `Test run with 124 tests passed` (117 at base) |
| Upstream | [#244](https://github.com/apple/swift-metrics/pull/244) (`F-001`) open |

## What the loop found

- **`F-001` (High, correctness)** - `TestMetrics`, the package's own test
  kit, aborted the test process with `Fatal error: Duplicate values for
  key: 'tag'` whenever a metric was created with a repeated dimension
  name, because `TestMetrics.FullKey` hashed and compared its dimensions
  through `Dictionary(uniqueKeysWithValues:)`. The metrics API accepts
  that input and every other factory carries it through. `FullKey` now
  sorts the `(name, value)` pairs for both `hash(into:)` and `==`, so
  identity stays order-insensitive, both read one representation, and
  repeated names are kept. The maintainers had moved this code from
  sorted pairs to a `Dictionary` in
  [#179](https://github.com/apple/swift-metrics/pull/179) for clarity of
  the Hashable contract; the fix keeps that property and says why.
- **`F-002` (Medium, runtime)** - `Timer.recordInterval(since:end:)`
  subtracted two `UInt64` uptimes and trapped on overflow when `end`
  preceded `since`, taking the process down with an unlabelled illegal
  instruction. A reversed pair now records zero; the doc comment records
  the two alternatives rejected (trapping, and dropping the observation
  without a trace).
- **`F-003` (Medium, docs)** - the Swift samples published in the README
  and the DocC index were never compiled and no longer built against the
  current API: `meter.record(100)`, a non-final class conforming to
  `Sendable`, a mutable stored property in a `Sendable` type, and
  `Date.nanoSince1970`. Every published sample compiles now, and a battery
  extracts and compiles each one.
- **`F-004` (Medium, docs)** - the documentation promised that, with no
  global factory bootstrapped, metrics created outside a
  `withMetricsFactory` scope "fail to initialize, providing a safeguard".
  They are created against `NOOPMetricsHandler` and every value they
  record is discarded without a signal. The text now says what the code
  does.
- **`F-005` (Medium, build)** - `Package.swift` declared no `exclude` for
  the `CMakeLists.txt` that
  [#238](https://github.com/apple/swift-metrics/pull/238) added to each
  source directory, so every downstream consumer's `swift build` printed
  three unhandled-file warnings. Excluded.
- **`F-006` (Medium, packaging)** - the loop's own state files reached
  `git archive`, which is the release tarball the auto-release workflow
  publishes. A `.gitattributes` with `export-ignore` lines. A finding the
  run created for itself, disclosed below.
- **`F-009` (Medium, docs; filed Low, re-scored by the gate)** - the
  `ExampleRecorder` in the full backend example, in both published copies,
  initialised its minimum and maximum to zero, so a recorder that saw only
  positive values reported a minimum of zero and one that saw only
  negative values a maximum of zero. The gate ran the example's recorder
  and rejected the Low score; the fix landed and the gate passed.

Two Lows are carried on the ledger with a measured reason: `F-007`
(`TestTimer.displayUnit` is written under the instrument's lock by
`preferDisplayUnit(_:)`, read without it by `valueInPreferredUnit(atIndex:)`,
and publicly assignable from outside the type) and `F-008` (the CMake
install lays down the three libraries and their modules but no package
config, so an installed tree cannot be consumed with
`find_package(SwiftMetrics)`; the build-tree export path the project wires
does work).

## What the loop got wrong

Nothing that reached the product's behaviour, and one score: the loop
filed `F-009` as Low and the evaluator's first invocation rejected the
declaration on that score alone, after running the published recorder
over `[512, 1024, 2048]` and reading a minimum of `0.0`. The re-score is
the gate's, the fix is the loop's, and the second invocation passed.

Thirteen lines in `fixes.patch` are loop housekeeping and are counted in
the numbers above: `.gitattributes` (`F-006`) exists because the loop's
own `PLAN.md`, `BACKLOG.md`, `JOURNAL.md` and `.jeffy/` would otherwise
ship in the release archive. The evaluator recorded that its acceptance is
vacuous at the base commit, where those files do not exist, and that the
attribute closes the `git archive` channel alone: a SwiftPM clone still
carries the state files, which its header discloses. Two further gate
observations, neither a REJECT reason: the fixed `ExampleRecorder` still
reports zero for minimum and maximum with no observations at all, where
any sentinel is arbitrary; and one pre-existing trailing whitespace on a
line of the README copy.

## Upstream

`F-001` is [#244](https://github.com/apple/swift-metrics/pull/244),
verified on a fresh clone at upstream HEAD (`0b89fda`, the base commit):
the test-only patch crashes (`Fatal error: Duplicate values for key:
'tag'`, signal 4), the full patch passes `swift test` under the CI flags
(`-Xswiftc -warnings-as-errors --explicit-target-dependency-import-check
error -Xswiftc -require-explicit-sendable`) on Swift 6.1.2 with 118 tests,
and `swift-format lint --strict` is clean on the two changed files. The
PR carries the fix and one test, 20 lines; the six tests the loop wrote
stay in `fixes.patch`. macOS, the static Linux SDK, release builds, wasm
and the nightly toolchains run in the project's CI only, and a first
contributor's workflow runs on apple repos wait for a maintainer's
approval.

`F-002` and `F-005` carry fixes in `fixes.patch` and are not filed: the
reversed-interval behaviour is a policy choice for the maintainers, and
the manifest `exclude` is a warning rather than a break.

## Files

- [journal.md](journal.md) - the full loop journal, every iteration
- [fixes.patch](fixes.patch) - the product diff, base to converged HEAD, loop state excluded
