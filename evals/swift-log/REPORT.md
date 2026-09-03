# Jeffy eval: apple/swift-log

The 4,045-star Swift logging API, the `Logger` type behind Vapor, Hummingbird,
gRPC Swift and the rest of the server-side Swift ecosystem. Run 2026-09-02 as
wave 13 (COHORT-WAVE13.md). **2 runs, 16 iterations, converged** in round 2 at
`2369870d11e1c4ef09e2a5bbbb4cdf748d17fe0a`, within a **pre-registered budget
of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `47a917767fde0cd7f5b5dfdabbec733d2cb2dd95` (main, at v1.15.0) |
| Findings closed | **9** - 2 High, 4 Medium, 3 Low (one Low fixed, two moved to Declined with a measured reason) |
| Shipped-code change | 12 files, **+199 / -28** (two lines of it are loop housekeeping, see below) |
| Surface inventory | **20 of 20 rows swept** |
| Ledger at convergence | empty, nothing carried; one Proposed item left for the maintainers (see below) |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | `swift test`: `Test run with 168 tests passed` (164 at base) |
| Upstream | [#503](https://github.com/apple/swift-log/pull/503) (SL-001), [#504](https://github.com/apple/swift-log/pull/504) (SL-002), filed 2026-09-02 |

## What the loop found

- **`SL-001` (High, correctness)** - the two deprecated `LogHandler`
  defaults forwarded to each other. A handler implementing only
  `log(event:)`, which is what the protocol documentation asks for,
  recursed until the stack overflowed as soon as any caller used the
  SwiftLog 1.0 entry point `log(level:message:metadata:file:function:line:)`.
  The 1.0 default now builds a `LogEvent` and calls `log(event:)`
  directly; no default was removed, so nothing is source-breaking. Issue
  [#248](https://github.com/apple/swift-log/issues/248) (2023) reported the
  same symptom for a handler implementing no log method at all, and its PR
  was closed as a source break; this is the documented handler shape.
- **`SL-002` (High, correctness)** - `Logger.MetadataValue.attributes`
  documented "For `.dictionary` and `.array` cases the setter is a no-op"
  and then called `assertionFailure` in those cases, so an intermediate
  handler assigning attributes across a metadata dictionary trapped in
  every debug build whose metadata held a collection while release did the
  documented thing. The trap is gone.
- **`SL-003` (Medium, error handling)** - `MultiplexLogHandler` guarded its
  "must not be empty" precondition with `assert`, compiled out in release,
  then died in the `metadata` getter on `handlers.first!` with an unrelated
  nil-unwrap message. The force unwrap was a capacity hint; the handler is
  now inert rather than fatal when its list is empty.
- **`SL-008` (Medium, correctness)** - `MultiplexLogHandler.metadata`
  resolved a conflicting key to the last handler while `[metadataKey:]` on
  the same instance returned the first, and the doc comment said the first
  wins. The getter now follows the subscript and the documentation, with
  provider metadata keeping its documented last-wins rule as a second
  pass. Two existing test expectations that pinned the last-wins value
  were changed. Open upstream PR
  [#488](https://github.com/apple/swift-log/pull/488) takes the other
  route, changing the documentation to match the code; the maintainers'
  choice, and the reason this Medium is not filed.
- **`SL-004`, `SL-010` (Medium, docs)** - two published examples that do
  not compile: the `InMemoryLogHandler` usage example read `entries` off
  the `Logger`, and the `Logger.MetadataValue` "user selected colors"
  example never closed its `.array([`. Closed as a class: the loop's
  battery extracts every fenced Swift block from the README, the doc
  comments and the Snippets target and compiles each one.
- **`SL-005` (Medium, packaging)** - the loop's own state paths were not
  excluded from the project's license-header check. A finding the run
  created for itself; the `.licenseignore` line is disclosed below.
- **`SL-007` (Low, build)** - both test targets excluded a
  `CMakeLists.txt` that does not exist, so every `swift build` opened with
  two `Invalid Exclude` warnings.

Two Lows were declined rather than fixed, each with a measured reason in
the journal: `SL-009` (the deprecated source-carrying entry point drops an
explicit `source` when the handler implements only `log(event:)`; over
three mutually-defaulted methods the loss can be moved but not removed,
and the alternative arrangement loses it on the path `Logger` itself
uses) and `SL-006` (the suite exercises no `MaxLogLevel` trait; the real
fix touches 124 call sites in 12 files).

One item is left as **Proposed** rather than filed: `StreamLogHandler`
renders message and metadata text without escaping newlines, so a value
containing `\n` forges a second log line. The loop reproduced it and
routed it to the maintainers because the handler's own documentation
positions it as a development diagnostic sink.

## What the loop got wrong

Nothing that reached the product's behaviour. Two lines in `fixes.patch`
are loop housekeeping and are counted in the numbers above: `.gitignore`
gained the loop's state file, and `.licenseignore` gained `.jeffy/*`
(`SL-005`, a Medium the run filed against the mess it made itself, and
one the evaluator observed is capped at Low by the rubric once the
unfixable half is set aside). The declaration stands on the other seven
findings.

## Upstream

`SL-001` is [#503](https://github.com/apple/swift-log/pull/503) and
`SL-002` is [#504](https://github.com/apple/swift-log/pull/504), each
verified on a fresh clone at upstream HEAD: the tests-only patch fails
(SIGSEGV; fatal error), the full patch passes `swift test` under the CI
flags (`-Xswiftc -warnings-as-errors --explicit-target-dependency-import-check
error -Xswiftc -require-explicit-sendable`) on Swift 6.1.2, and
`swift-format lint --strict` is clean on the changed files. macOS,
Windows and the nightly toolchains run in the project's CI only.
Disclosure: the first CI run on #503 failed its five Windows jobs. The
new tests passed `#filePath` and asserted the module the 1.0 method
derives from it, which is `n/a` on Windows because the path has no
forward slash. Amended 2026-09-03 to pass a fixed POSIX path; the
Android, macOS simulator and Wasm jobs fail the same way on `main`.

## Files

- [journal.md](journal.md) - the full loop journal, every iteration of both rounds
- [fixes.patch](fixes.patch) - the product diff, base to converged HEAD, loop state excluded
