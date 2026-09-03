# Jeffy eval: console-rs/indicatif

The progress-bar library most Rust CLIs draw with, run 2026-08-30 as one of
three targets in wave 1 of the merged-PR campaign (cohort 2026-08-30),
alongside `urfave/cli` and `immer`. **2 runs, 20 iterations, converged** at
`2296e8a75147f944c53ee7122008a7741e537055`, in round 2 of a
**pre-registered budget of 3 rounds of 10**. Run 1 closed both Highs and
swept the 25-row map; run 2 closed the seven Mediums and passed the gate on
its second invocation, after the first invocation's REJECT re-scored a Low
to Medium and made the loop fix it.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `e4750d26f43a2802f788cd1ccb4de0f459629e5c` (main, 2026-08-26; upstream CI 28 success on this exact commit) |
| Findings closed | **9** - 2 High, 7 Medium |
| Shipped-code change | 9 files, **+826 / -29** |
| Surface inventory | **25 of 25 rows swept** |
| Ledger at convergence | 3 Lows carried, named in the closing entry |
| Evaluator | **2 invocations: REJECT, PASS** |
| Suite at convergence | `cargo test --all-features && cargo test --no-default-features && cargo fmt --check && cargo clippy -D warnings` green |
| Upstream | [#836](https://github.com/console-rs/indicatif/pull/836) (IND-1) **merged** 2026-09-03 by the maintainer |

## What the loop found

- **`IND-1` (High)** - `DrawState::draw_to_term` underflowed its
  trailing-filler subtraction when a line's last visual row was wider than
  the terminal; now `saturating_sub`, with a test driving a terminal at
  width 0 and width 1.
- **`IND-12` (High)** - the rayon adapter driving the producer path
  finished the bar at the end of the first split chunk and then counted
  past its own length; a new producer-side iterator increments per item and
  never finishes early.
- **`IND-8` (Medium)** - **the finding the gate itself filed**, by
  re-scoring it from Low: `MultiProgress::add` documents that re-adding an
  existing member "will have no effect", but each call allocated a fresh
  member and a fresh ordering entry no free path reclaimed, so every later
  positional `insert` landed one row off. The evaluator's REJECT reproduced
  the rendered mis-ordering differentially and ruled the documented-promise
  clause put it at Medium; the loop fixed it and the second invocation
  passed.
- **`IND-2`, `IND-3`, `IND-4`, `IND-9`, `IND-11` (Medium)** - a finished
  bar's rate computed from wall-clock instead of its stored duration; a
  template width above `u16::MAX` panicking instead of returning the
  parser's own error; a guard asserting on the wrong field so its message
  lied; a truncated template parsing Ok and silently discarding the tail;
  and `AtomicPosition::inc`/`dec` wrapping where every sibling counter
  saturates - `dec(1)` at position 0 yielded 18446744073709551615.
- **`IND-5` (Medium)** - the published crate carried the loop's own state
  files: `Cargo.toml` excluded only `screenshots/*`, so `cargo package`
  shipped the audit ledger and probe batteries to every downstream vendor.
  The seventh packaging channel caught in the corpus, this time against the
  loop itself, and now machine-checked from the Stated counts table.

## Carried at convergence

Three Lows, each with its acceptance recorded: zero-width grapheme clusters
reaching a divide-by-zero panic in `progress_chars` (scored Low by the
envelope's exotic-input cap, and the REJECT artifact says why); an
unreachable `(Key, '!')` match arm shadowed by a guard rustc cannot warn
about; and a panic documented on one constructor but shared by three.

## Run shape

Run 1 (10 iterations): audit, IND-1, then six sweep iterations building the
in-crate battery mechanism for the six `pub(crate)` rows no external probe
can reach, IND-12 in the middle, wrapup. Run 2 (10 iterations): six Mediums
closed back to back, the closing audit, gate invocation 1 - REJECT,
re-scoring IND-8 - the IND-8 fix, then gate invocation 2, PASS, and the
declaration in the same iteration. No run ended blocked.

## Upstream

`IND-1` is [#836](https://github.com/console-rs/indicatif/pull/836), the
`draw_to_term` underflow, merged by the maintainer on 2026-09-03 after one
review round. `IND-12` is held: the rayon adapter change is wider than the
bar allows. The Mediums stay in the receipt.

## Environment

WSL2 x86_64, cargo/rustc 1.97.1. Engine 1.20.0 on Claude Code 2.1.232,
model `opus[1m]`. The fingerprint's derived exclusion list names what this
host cannot grade: every `wasm32` branch (upstream CI only cross-builds
them, never cross-tests), the armv5te and MSRV legs, and macOS and Windows
entirely.

Full iteration record: [journal.md](journal.md). Complete shipped diff:
[fixes.patch](fixes.patch).
