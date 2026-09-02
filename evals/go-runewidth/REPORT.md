# Jeffy eval: mattn/go-runewidth

The width library most Go terminal programs depend on - how many cells a
rune or a string occupies, East Asian ambiguity, the emoji and combining
tables, and the truncate, fill and wrap helpers built on them. Run
2026-09-01 as wave 10 of the campaign (COHORT-WAVE9.md, which covers
waves 9 and 10). **2 runs, 20 iterations, converged** in round 2 at
`a38684e9078c4e6472e021a3c88d7d32f8d87954`, within a **pre-registered
budget of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `554428cf553d` |
| Findings closed | **13** - 2 High, 7 Medium, 4 Low (including 2 filed by the gate and 1 by a closing audit, each closed in the same run) |
| Shipped-code change | 4 files, **+772 / -24** |
| Surface inventory | **10 of 10 rows swept** |
| Ledger at convergence | 11 Lows carried |
| Evaluator | **3 invocations: REJECT, REJECT, PASS** |
| Suite at convergence | green through the verify gate, 10 batteries each observed failing before it was trusted |

## What the loop found

- **`RW-01` (High)** - `Wrap(s, 0)` divided by the width in the capacity
  hint `len(s) + len(s)/w + 1`, so **a zero width panicked with
  "runtime error: integer divide by zero"** instead of behaving like the
  negative widths the same function already accepted. The guard covers
  the hint alone: `strings.Builder.Grow` sets capacity without touching
  content, so no output at any positive width can differ, and
  `Wrap(s, 0)` now returns what `Wrap(s, -1)` always returned.
- **`RW-21` (High)** - the package-level `CreateLUT` returned early
  whenever a table already existed, so the sequence the docs prescribe -
  change a `DefaultCondition` flag, then call `CreateLUT()` - never
  rebuilt and **every package-level width stayed silently stale**. The
  fix is a deletion: the function becomes a thin delegation like every
  other package-level entry point, and the `handleEnv` truncation goes
  with it, since that line existed only to defeat the guard. Reproduced
  from a consumer module: 138370 runes disagree with a freshly built
  `Condition` in each direction. The suite's strongest assertion,
  `TestDefaultLUT`'s whole-plane checksums, was green only because that
  truncation smuggled the rebuild past the guard.
- **`RW-02` / `RW-03` (Medium)** - `Wrap` measured and cut per rune
  while `StringWidth` and the truncation family measure per grapheme
  cluster, so **it split ZWJ sequences and flag pairs and disagreed with
  the package's own width function**, and the rune loop behind it
  **re-encoded every undecodable byte as U+FFFD**. One root cause, two
  filed symptoms, closed by the same change: `Wrap` now dispatches to a
  cluster walk, with an ASCII fast path because segmentation costs about
  2.4x on ASCII. The differential between the two paths found a CRLF
  divergence on its first run.
- **`RW-04` (Medium)** - the README's only usage example asserted
  `StringWidth` of a mixed CJK and ASCII string as 12, which is the East
  Asian answer, so **the documented example returned 11 on every locale
  that is not CJK**. Both snippets are now executed in the exact form
  they are published.
- **`RW-05` (Medium)** - `StrictEmojiNeutral` was documented with no
  restriction stated, but **the flag does nothing at all while
  `EastAsianWidth` is false**, which is the default outside a CJK
  locale. Measured over all 0x110000 runes: zero changes in the
  non-East-Asian path, 1620 in the East Asian one, against 1652 emoji
  runes the flag would move if it applied there. Documented rather than
  altered, because making it effective would move a large block of emoji
  widths for every caller who sets it.
- **`RW-11` (Medium)** - the Go module zip is built from the whole
  repository tree, so **the loop's own state files would reach every
  consumer of the next tagged release**. `.jeffy/` now carries its own
  `go.mod`, verified by building the real zip with
  `golang.org/x/mod/zip`. The iteration also falsified its own premise:
  Go does have a mechanism to exclude a root file, since a symlinked
  root file is omitted from the zip as "not a regular file".
- **`RW-17` (Medium)** - filed by the gate. `wrapClusters` reset the
  column only when a cluster was exactly a newline or a CRLF, on the
  strength of a comment asserting no other cluster can hold a break, so
  **wrapping a newline followed by a truncated multi-byte sequence
  returned a blank line the input never contained**. All 54 lead bytes
  0xC2 to 0xF7 triggered it.
- **`RW-20` (Medium)** - filed by the gate. A cluster can also carry
  content before its break, so **a four-column line came back on a
  budget of three**. Fixed structurally rather than as a third special
  case: each cluster is split at every newline and every piece measured
  the same way.
- **`RW-22` (Medium)** - filed by the closing audit. `FillRight`'s doc
  comment said "filled in left", word for word what `FillLeft` says, so
  **the documentation described one of the two functions wrongly and
  gave a caller no way to tell them apart**. A first fix was rejected in
  the same iteration because `go doc` collapses runs of spaces when it
  re-wraps, so the corrected example still rendered as a lie.
- Four Lows closed. `RW-14`: assigning to the package variable
  `EastAsianWidth` changes nothing the package-level functions return,
  now stated across the whole class of flag variables `NewCondition`
  copies. `RW-16`: `Truncate` returns a string wider than its budget
  whenever the tail alone does not fit, now documented for the two
  truncators whose `w` is a budget, with `TruncateLeft` deliberately
  excluded. `RW-13`: `IsNeutralWidth` answers from listed ranges only,
  checked against the `@missing` line in EastAsianWidth-17.0.0.txt,
  which corrected an overstatement two files in the tree had inherited.
  `RW-07`: the two `CreateLUT` doc comments disagreed on the table size,
  557056 against 557055, and the figure is now pinned against the real
  allocation.

## What the gate caught

Run 1 ended blocked after two REJECTs, and both were regressions the
loop's own `Wrap` rewrite introduced. At invocation 1 the gate filed
`RW-17`: the run had shipped a comment claiming no grapheme cluster
other than a bare newline can contain a line break, which is a prose
claim over a set that was never enumerated, and the segmenter falsifies
it for every truncated lead byte after a newline. 19535 of 1000000 fuzz
samples diverged from a newline-resetting reference. Neither the suite
nor the battery could see it: the byte-preservation test strips newlines
from both sides, the two differentials use only valid UTF-8 and ASCII,
and the battery's invariant catches a line that is too long while this
defect made one too short. The fix landed at iteration 10, and
invocation 2 rejected again on the same function with `RW-20`, a cluster
carrying content before its break, 24 over-budget lines across the bytes
0x80 to 0xFF and 4340 over-budget lines across 1.8 million randomised
samples at HEAD against zero at base. That second REJECT exhausted the
invocation cap, so the run entered gate salvage, closed `RW-20`
structurally, and ended blocked without declaring. Run 2 re-audited from
scratch, closed the second High and six more findings, and passed at
invocation 1. The difference was procedural: every standing claim was
brought current before the invocation rather than after, and each of the
two earlier invocations had been partly spent on a claim the run had
itself outdated.

## Upstream

Two PRs, each verified on a fresh clone at upstream HEAD `554428c` with
the project's own workflow commands: `go generate` with no resulting
diff, `go vet`, `go test`, `go test -bench`, and `gofmt`.

[PR #106](https://github.com/mattn/go-runewidth/pull/106) is `RW-01`.
`Wrap(s, 0)` panicked with an integer divide by zero in the capacity
hint `len(s)/w`; the fix guards the hint only, so width 0 behaves like
every other non-positive width rather than acquiring a contract of its
own. A prior PR, #101 by another contributor, addressed the same panic
by returning `s` unchanged and was withdrawn by its author the same day.

[PR #107](https://github.com/mattn/go-runewidth/pull/107) is `RW-21`.
The package-level `CreateLUT` returned early whenever a table existed,
so a `DefaultCondition` flag change followed by `CreateLUT()` as the
docs instruct never rebuilt and every package-level width stayed stale.
The fix removes the early return and the `handleEnv` truncation
workaround that existed only to defeat it.

Both are open.
