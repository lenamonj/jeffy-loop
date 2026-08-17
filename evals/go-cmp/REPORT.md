# Jeffy eval: google/go-cmp

Google's semantic comparison library, imported by a large share of Go test
suites, and at 620KB **the smallest surface any cohort has run** - smaller
than `shopspring/decimal`, which spent four runs without converging. go-cmp
took two. **2 runs, 15 iterations, converged** at
`43c1580defa6132a54b2da8119ec6aad11f12a8a`, against a **pre-registered budget
of 4 runs of 10 iterations**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | tag `v0.7.0`, `9b12f366a942ebc7254abc7f32ca05068b455fb7` |
| Upstream CI on the base | **2 of 2 green** |
| Findings closed | **6** - 3 Medium, 3 Low |
| Shipped-code change | 5 files, **+31 / -13** |
| Surface inventory | **26 of 26 rows swept** |
| Ledger at convergence | **5 Lows carried**, listed below |
| Evaluator | **1 invocation, PASS** |

## What the loop found

A mature, conservatively maintained library, and the findings say so - no
High anywhere, and the three Mediums are all about the project's gates
rather than its comparisons:

- **`C1`** - the CI matrix gated the library on **Go 1.21.x alone**, so no
  current toolchain tested a package the current toolchains all import.
- **`B1`** - the only CI gate pinned `actions/setup-go` v2.2.0 and
  `actions/checkout` v2.7.0, five major versions behind.
- **`D1`** - `cmp.Equal`'s documented option-precedence rule 1 claimed a
  behaviour its own code does not implement; the doc now states the real
  contract.

The two runtime findings are genuine, scored Low with the rationale on
record, and both live in `cleanupSurroundingIdentical` in
`cmp/report_slices.go` - the diff-report grouping pass: **`S1`**, where the
two edge branches deferred an append that a later branch could skip, and
**`S2`**, where the leading and trailing equal runs were counted
independently and a group equal on both ends could be double-counted. Both
are visible only in how a reported diff is grouped, never in whether two
values compare equal, which is why they are Lows and why the project's
4,000-case suite never saw them.

## Five Lows carried at convergence

Published rather than dropped, per the severity floor: `D2` (SortSlices'
transitivity requirement stated in terms that do not define a strict weak
ordering), `D3` (README and package doc disagree about unexported-field
handling), `D4` (a doc comment's worked example gives output the code does
not produce), `T1` (a test-table key-coverage gap), and `T2` (`go vet`
exits 1 with 7 diagnostics, all in test files).

## Declared limits

- Two internal test-fixture packages carry no test files; `go test` lists
  them as `[no test files]`, which is upstream's own state.
- `-count=1` is mandatory in the verify command per `P1-42` - Go caches
  test results by input hash and a plain `go test ./...` can report `ok`
  without executing anything.
- Graded on the Go toolchain under WSL2 Linux x86_64, run headless by
  `claude -p` on **claude-opus-5 (1M context) at xhigh effort**.

## Nothing was sent upstream

Every finding rests on tests this loop wrote; no existing test was deleted,
disabled or weakened. The +31/-13 diff is the smallest of any converged
brownfield target, and that is the result: the loop's grade on a
well-maintained codebase is a small, precise bill rather than an invented
one.
