# Jeffy eval: rust-itertools/itertools

The extra iterator adaptors, methods and macros that most of the Rust
ecosystem reaches for once the standard library runs out - combinations,
permutations, powerset, grouping, merging, chunking, cartesian products
and the tuple and array helpers around them. Run 2026-09-01 as wave 9 of
the campaign (COHORT-WAVE9.md). **1 run, 8 iterations, converged** in
round 1 at `4eed79bee4d05a9320d9c11f1acdab5a5a9942d6`, within a
**pre-registered budget of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `eee067339d3a` (v0.15.0) |
| Findings closed | **4** - 1 Medium, 3 Low |
| Shipped-code change | 7 files, **+50 / -28** |
| Surface inventory | **22 of 22 rows swept** |
| Ledger at convergence | 0 open, 0 blocked, no Low carried |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | green through the verify gate, 22 batteries at 849 of 849 checks, each seen to redden under a discriminating mutation |

## What the loop found

No correctness defect survived the probes. The known-answer battery came
back 179 of 180 on its first pass, with the single mismatch being the
probe's own wrong expectation, and the invariant battery came back 330 of
330. What the run did find sits around the crate rather than inside its
adaptors: what ships, what runs, and what the project's own gates say.

- **`IT-1` (Medium)** - `Cargo.toml` declared no `exclude`, and a Cargo
  package defaults to shipping the whole tree, so **the published .crate
  carried the loop's own state files down to every consumer**. By the time
  the task was worked, `cargo package --list --allow-dirty` listed the
  three state files plus 67 files under `.jeffy/`. The fix was proven
  against the tarball a consumer downloads, not only the file list cargo
  prints: `tar tzf target/package/itertools-0.15.0.crate` finds no state
  file, and the packaged file count is 91.
- **`IT-2` (Low)** - `[lib] test = false` meant **the 6 unit tests inside
  `src/` were compiled by nobody and run by nobody**, under the Verify
  command or in CI. The one-line removal was not the whole fix: two test
  assets use `catch_unwind` and `vec!`, so dropping the flag broke the lib
  build under reduced feature sets until both were gated at the narrowest
  scope that keeps them running wherever std exists. The lib target was
  then measured across all four feature configurations, 6 tests with std
  and 4 without, every one exit 0.
- **`IT-3` (Low)** - CI's clippy gate was red on current stable, so **a
  contributor running the project's own gate met four errors before
  writing a line**. Fixing those four `clippy::question_mark` errors
  exposed four more in the lib test target IT-2 had just enabled, because
  `--all-targets` now built code the linter had never seen. All eight were
  fixed and all four CI feature configurations exit 0. The four `?`
  conversions were argued to identity: in `fold_ok` the `From::from` on E
  into E is the reflexive impl, `fold_options` propagates `None` directly,
  and the two adaptor sites return `None` from the same `next()` call.
- **`IT-4` (Low)** - `EitherOrBoth::insert_both` is public API carrying
  `unsafe { unreachable_unchecked() }`, and **nothing in the shipped suite
  drove it** - no test under `tests/` and, unlike its two siblings, no doc
  example. The first doc example written to close it was rejected by its
  own mutation check: skipping the write when `self` is already `Both`
  left the doc suite green. A third case covering an existing `Both`
  receiver made the same mutation fail at exit 101, and the doc suite went
  to 211 passed.

## Evaluator

The gate passed on its single invocation. One fresh-context sub-agent
re-derived the base premises instead of accepting them, ran the 22-battery
differential itself and got byte-identical output on the base tree and
HEAD at 849 of 849, and proved the instrument falsifiable by deleting a
line from base multipeek and watching a battery redden. It confirmed the
Verify command exits 0 with 662 tests across 15 targets, that all four
acceptance checks pass at HEAD exactly as filed, and that each
reproduction fails at base: IT-1's prints 70 paths at exit 0 and flips to
exit 1 when HEAD's `Cargo.toml` alone is swapped in, base clippy exits 101
with the four errors IT-3 named, and the greps for `Running unittests` and
`insert_both` both return 0. It re-scored every closed task and agreed
with each severity, testing specifically whether IT-3's Low hid a
user-facing consequence given the fix touched three shipped source files,
and found the identical differential says it does not. It recorded five
observations, every one Low and none a REJECT reason; they were left
unfixed, because a fix after a PASS invalidates that PASS, and carried to
the next run.

## Upstream

Nothing was filed. The run closed one Medium and three Lows, and none of
them meets the bar for an upstream PR: a genuine High with an external
oracle. IT-1 is a packaging change that only matters while the loop's own
files sit in the tree, and IT-2, IT-3 and IT-4 are project hygiene a
maintainer is better placed to sequence than a stranger.
