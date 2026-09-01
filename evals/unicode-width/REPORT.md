# Jeffy eval: unicode-rs/unicode-width

The UAX #11 display-width implementation for Rust: how many terminal
columns a string occupies, the question every CLI layout depends on.
Sibling of unicode-segmentation, which converged in wave 6 and produced
[PR #181](https://github.com/unicode-rs/unicode-segmentation/pull/181).
Run 2026-09-01 as wave 8 (COHORT-WAVE8.md). **1 run, 6 iterations,
converged** in round 1 at `07ce6756cc0b16cd5ad4f464398622c789293e37`,
within a **pre-registered budget of 5 rounds of 10** - the shortest
convergence in the corpus.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `832f7ca447375ff969f850dab9362a0c2ce1eefb` (v0.2.2) |
| Findings closed | **2** - both Medium |
| Shipped-code change | 2 files, **+10 / -8** |
| Surface inventory | **14 of 14 rows swept** |
| Ledger at convergence | 6 Lows carried |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | `verify totals: 78 passed`, `check-claims` 15 checked / 0 mismatched |

## What the loop found

- **`UW-001` (Medium)** - the published crate did not carry
  `tests/emoji-test.txt`, the Unicode conformance corpus its own test
  suite opens. Packaging the crate at HEAD, extracting it and running
  `cargo test` in the extracted tree **exited 101**: `emoji_test_file`
  panicked on `File::open`, because the extracted `tests/` directory
  held only `tests.rs`. Anyone verifying the crate from its published
  tarball, which is what a distribution packager does, got a failing
  suite. Fixed as a class covering any test data file, with the
  enumerating command recorded.
- **`UW-005` (Medium)** - closed earlier in the run and pinned by the
  same packaging battery.

Six Lows are carried, three of them the gate's own observations filed
rather than fixed (a fix after a PASS invalidates the PASS): a README
changelog stopping at 0.2.0 while the crate ships 0.2.2, hardcoded
table geometry in a generator comment where every surrounding
expression derives it, benchmarks that silently read an empty corpus on
a fresh checkout, and three about the run's own instruments.

## Why so few findings

unicode-width is 312 stars of extremely narrow surface: a generated
lookup table, a width function, and the script that regenerates them.
Fourteen rows swept, every battery observed failing under a
discriminating mutation, and what remained after the sweep was one real
packaging defect and a handful of documentation Lows. A converged run
on a small mature library is a measurement, not a disappointment: the
loop found the one thing that would bite a packager and correctly
declined to inflate the rest.
