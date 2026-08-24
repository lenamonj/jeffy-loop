# Jeffy eval: withoutboats/heck

The case-conversion crate under cargo, serde and most Rust code
generation - snake_case to CamelCase and the six variants between - and
the third of three targets in the 2026-08-23 cohort, the first cohort run
on engine 1.15.2. **2 runs, 17 iterations, converged** at
`e18001132bc18678cf3de529eff9346bf5006d2d`, against a **pre-registered
budget of 2 rounds of 10 iterations declared in the cohort file before
the launch command existed**.

**Convergence standard**: evaluator countersigned. This convergence
carries an asterisk stated up front rather than in a footnote: **one High
is carried at convergence, blocked on an owner decision**, under the
engine's "blocked with its reason recorded" disposition - the reason
established by the gate's own executed probe, not asserted.

| | |
|---|---|
| Base | `252c1906cefefb8d13ecad7fce7b8f27ce6437e0` |
| Upstream CI on the base | **8 of 8 check-runs green** |
| Findings closed | **11** - 7 Medium, 4 Low |
| Shipped-code change | 13 files, **+630 / -67** (all eight case modules, CI workflow, README, CHANGELOG) |
| Surface inventory | **12 of 12 rows swept** |
| Ledger at convergence | **1 High blocked** (NFD-1, below); the decision routed to the owner under Proposed |
| Evaluator | **2 invocations: REJECT, PASS** |

## What the loop found

Seven Mediums in a crate whose one job is Unicode-correct word
segmentation and case mapping:

- **`SIGMA-1` / `SIGMA-2`** - word-final capital sigma was rewritten to
  its final form ignoring Unicode's Final_Sigma precondition, and the
  hand-computed replacement still got the case-ignorable runs wrong; the
  close routed sigma-bearing words through `alloc`'s `str::to_lowercase`,
  which implements the condition, making it right by construction.
- **`TITLE-1` / `TITLE-2`** - `capitalize` uppercased where Unicode
  titlecases: the Latin digraphs and Georgian first, then the Greek
  iota-subscript characters, closing the titlecase class against the two
  tables transcribed from the Unicode Character Database.
- **`FMT-1`** - all eight `As*Case` `Display` impls wrote straight to the
  formatter, silently dropping width, fill, alignment and precision; all
  eight now route through one `pad_with`.
- **`TEST-1`** - the project's own suite pinned no input without
  alphanumeric characters at all.
- **`DOCS-2`** - the published word-boundary rules predicted the wrong
  output for ordinary identifiers like `parseHTTPResponse`; the rewritten
  rules are now executable - the harness reference implements them from
  the prose, and a 3,906-input differential fails if either the code or
  the documentation drifts.

The four Lows: derives on the eight wrapper types (`API-1`), three
wrapper doc headlines naming the wrong conversion (`DOCS-1`), four CI
jobs pinned to `actions/checkout@v2` on the deprecated node12 runtime
(`CI-1`), and `PERF-1` - **the run's own 1.09-1.16x regression from the
sigma fix, caught by benchmarking against the pre-run commit, fixed, and
reported across all eight samples rather than by its best one**.

## The gate found the headline defect

Run 1's REJECT is the reason this receipt exists in its current shape.
The run had swept all 12 rows and built an exhaustive 149,106-code-point
differential - and the gate found a Medium-or-worse the differential was
**structurally blind to**: the reference implementation split words on the
same `!c.is_alphanumeric()` predicate as the code under test, and neither
corpus carried a Latin combining sequence. `"cafe\u{301}"` to snake case
is `"cafe"` - the accent silently deleted; `"na\u{308}ive"` gains a word
boundary mid-word. The same REJECT reversed two severity downgrades
(SIGMA-2 and TITLE-2 filed Low on "exotic input" arguments the envelope
forecloses), citing the run's own first audit scoring the identical
classes Medium.

Run 2 fixed both reversed items and filed the gate's discovery as
**`NFD-1`, High**. The fix needs the Unicode Mark property, and neither
`core` nor `alloc` exposes it. The PASS invocation verified that premise
by executed probe: deriving Case_Ignorable from what `str::to_lowercase`
reveals sweeps in the apostrophe, the full stop and the colon - 1,445
non-alphanumeric scalar values - so a separator predicate built from it
breaks the crate's own documented boundaries. Every remaining route (an
internal table, a dependency, accepting the limitation) trades the
crate's zero-dependency, table-free character, which is the owner's call.
The gate recorded that the run does not hide behind that disposition:
SIGMA-2 and TITLE-2 sat under the identical Proposed decision and were
taken out of it and fixed.

The PASS also verified the crate against the Unicode Character Database
directly, downloaded from unicode.org rather than trusted from the
harness: titlecase, lowercase and uppercase now agree with UCD 17.0 on
**all 149,106 alphanumeric scalar values with zero mismatches** (28
apparent mismatches against 16.0 resolved to code points that gained
mappings in 17.0, the version the installed rustc implements), and the
crate's private `cased` predicate equals the Unicode Cased property
exactly, 4,632 code points in both sets.

## Declared limits

- The carried High means NFD-normalized Latin, Greek and Cyrillic text is
  still mis-segmented at convergence; precomposed forms are unaffected.
  The blocked item and its Proposed decision are published, not netted
  out of the summary line.
- The oracle is the crate's own 154 unit assertions plus 16 doc examples
  behind fmt and clippy gates; the UCD differential is the gate's
  instrument, not the suite's.
- Graded on rustc 1.97.1, x86_64 linux under WSL2, run headless by
  `claude -p` on **claude-opus-5 (1M context)**, driven by
  `jeffy-campaign.sh`.

## Nothing was sent upstream, and the check that settled it

Every finding rests on tests this loop wrote; no existing test was
deleted, disabled or weakened. Before disclosing anything, the upstream
tracker was searched - and the two sharpest findings turn out to be
independent rediscoveries of work already filed there and unmerged since
March 2024: the Final_Sigma fix is open as
[PR #56](https://github.com/withoutboats/heck/pull/56) with the same
route-through-`str::to_lowercase` approach and the same Case_Ignorable
rationale, and the combining-mark deletion behind `NFD-1` is open as
[PR #57](https://github.com/withoutboats/heck/pull/57), which resolves
the table-versus-dependency decision by shipping generated Unicode
tables. Duplicating either would add noise, so nothing was filed. The
independent rediscovery is left here as what it is: two blind
derivations of the same defects, which is evidence the findings are
real.
