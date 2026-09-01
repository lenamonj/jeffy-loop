# Jeffy eval: unicode-rs/unicode-segmentation

The Rust ecosystem's UAX #29 implementation - grapheme, word and
sentence segmentation for every crate that needs to know where a
user-perceived character ends, `no_std`, zero runtime dependencies. Run
2026-08-31 as wave 6 of the merged-PR campaign (COHORT-WAVE6.md).
**2 runs, 15 iterations, converged** in run 2 at
`ded7a7b787e380f02fef8ec7340718ca9285fc2e`, within a **pre-registered
budget of 5 rounds of 10**. Run 1 was aborted by the environment, not
the engine: the API connection dropped mid-iteration at iteration 6, the
driver's orphan-state guard refused to continue on an unclean tree, and
the campaign relaunched with the remaining declared budget.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `091fb72c5e9cd1f06f4d3df1315ed7011a201084` (master, v1.13.3) |
| Findings closed | **10** - 1 High, 4 Medium, 5 Low |
| Shipped-code change | 11 files, **+387 / -24** |
| Surface inventory | **8 of 8 rows swept** |
| Ledger at convergence | 1 Low carried |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | 52 tests green across lib, integration and doc targets (~1 s) |

## What the loop found

- **`A1` (High)** - `"".split_sentence_bounds().size_hint()` panicked
  with `attempt to subtract with overflow` in debug builds, on all three
  public sentence iterators: the outer hint subtracted 1 from an inner
  lower bound that is 0 for the empty string, on `usize`. In release the
  same call returned a lower bound of 18446744073709551615 against an
  upper bound of 0. The `cmp::max(0, ...)` wrappers around the
  expression were no-ops on `usize` that read as saturation while the
  underflow sat inside them. The evaluator gate confirmed the debug
  panic and narrowed the release-mode reach: standard consumers call
  `next()` first, so only a direct `size_hint()` call sees the wrapped
  bound.
- **`A4` (Medium)** - found by writing A1's regression test in a
  stronger form than its acceptance asked for: the inner
  `SentenceBreaks::size_hint` read the whole string's length and never
  the consumed position, so the hint never shrank and reported a lower
  bound of 1 after the last item - which the `Iterator::size_hint`
  contract forbids. 16 violations measured across 12 inputs and the ten
  public iterators; zero after the fix, re-verified independently over
  1,114 inputs walked position by position in both profiles.
- **`P2-01` / `P1-01` (Medium)** - two packaging defects: the
  `include` allowlist's bare-name entries were unanchored globs, so
  files named README.md at any depth shipped in the published crate; and
  the crate shipped its four criterion bench targets without
  `benches/texts/`, the data they read at runtime, so
  `cargo test --all-targets` inside the extracted tarball exited 101.
- **`P1-02` (Medium)** - README's changelog had no 1.13.3 section
  although the manifest declares 1.13.3; the entry was derived from the
  commit range between the two version-bump commits, both directions
  checked.
- **`P1-03` / `P1-04` (Low)** - the chunked `GraphemeCursor` API - home
  of the crate's two most recent correctness fixes - had no test outside
  its rustdoc examples, and the sentence surface had no concatenation
  property. The new cursor test, run against the tree from before
  PR #172, reproduces exactly the defect that PR fixed while the entire
  existing suite stays green over it.
- **`P1-05` (Low)** - `scripts/unicode.py::fetch` ran `curl -O` with no
  status check, so an HTTP 404 page landed under the expected UCD
  filename and was parsed as Unicode data. Fixed fail-closed.

## Verification depth

The receipts behind the sweep: a differential driver fed
`GraphemeCursor` chunk by chunk at sizes 1-6 in both directions against
the contiguous iterator (44,462 checks, reddened by the real pre-#172
defect rather than an invented mutation); 588 panic probes across 28
edge inputs and 21 public call shapes in both profiles; a size_hint
contract walk over every string up to three characters from a
rule-hardened alphabet; and both UCD generators re-run against
unicode.org with byte-identical output. The gate's own harness found the
sentence segmentation byte-identical either side of the fixes by digest
over 11,111 inputs and zero contract violations over 22,222 of its own.

## Upstream

`A1` was filed as
[PR #181](https://github.com/unicode-rs/unicode-segmentation/pull/181):
the empty-string `size_hint` underflow, a debug panic in the shipped
crate with a two-line `saturating_sub` fix and a regression test that
drives every public iterator. The duplicate check found closed issue
#146 on the same surface - closed as the reporter's misreading of
`min`, but its thread carries an undiagnosed `Vec::with_capacity`
capacity-overflow report that is exactly this underflow's release-mode
signature, which the PR points out. The fix was re-proven red-then-green
on a fresh clone at upstream HEAD before filing, and the PR body
discloses its provenance. A4, the non-shrinking inner hint, is noted in
the PR as an offered follow-up rather than bundled in.
