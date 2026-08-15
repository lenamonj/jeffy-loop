# Jeffy eval: go-playground/validator

The struct-validation library under Gin, Echo and a large share of Go web
services. **4 runs, 31 iterations, converged** at
`9a41d00345535f7d8487d40830ec12db4d144259`, against a **pre-registered budget of
4 runs of 10 iterations**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | tag `v10.30.3`, `ac4c1bab0d4aa957466faa1948af28130767e43a` |
| Upstream CI on the base | 9 check-runs, all green |
| Findings closed | **19 - 4 High, 13 Medium, 2 Low** |
| Shipped-code change | 15 files, **+1,007 / -71** |
| Surface inventory | **31 of 31 rows swept** |
| Ledger at convergence | **2 Lows carried, published below** |
| Evaluator | 3 invocations: REJECT, REJECT (run 2), **PASS** (run 4) |
| Runs ending blocked | 1 |

## The four Highs

**A cyclic struct graph killed the process.** Validation recursed until the
goroutine stack was exhausted, and a stack exhaustion in Go is not recoverable -
no `recover`, no error return, the process dies. A web service validating an
attacker-supplied structure with a cycle in it is a denial of service with no
defence available to the caller.

**An unescaped dot made the alpha channel accept anything.** The alpha group in
`rgbaRegexString` and `hslaRegexString` read `(?:0.[1-9]*)|[01]`, where the `.`
is an any-character match rather than a decimal point, so values that are not
colours passed the colour validators.

**The `mimetype` tag could not match its own documented form.** For any media
type the detector reports with a parameter, the tag could never match the
`type/subtype` form the documentation specifies - so a rule that looked correct
rejected valid input in every case.

**`unix_addr` accepted every string**, so a validation the package's own `doc.go`
documents never rejected anything at all. It is the shape this project takes
most seriously: a check that runs, passes, and certifies nothing.

## What the gate caught

Run 2 spent both invocations on rejections and **ended blocked** - the receipt
records that rather than presenting four clean runs. Run 4 passed on its first
invocation, and the verdict is worth quoting for what it re-ran rather than
read: every one of the six closed tasks' acceptance checks exits 0 on the fixed
code **and non-zero against its own unfixed code**, all 28 batteries exit 0
twice leaving the tree unmodified, and every enumeration and count written into
`PLAN.md` and `BACKLOG.md` re-executes to the value claimed.

## Two Lows carried at convergence, named not dropped

Under the severity floor in force since v1.9.0, a declaration requires zero open
High and zero open Medium; Lows are carried, named and published. This run
carried two, both documentation:

- `V-014` - `unix_addr` is the only tag in its address family that accepts a
  non-string field kind.
- `V-005` - three tracked files fail `gofmt`: a trailing blank line in
  `baked_in.go` and in `doc.go`, and struct-tag misalignment.

## Declared limits

- 24 packages are graded, of which 21 are translation packages; the library's
  own logic lives in three.
- **`-count=1` is deliberate**, for the same reason as this cohort's other Go
  target: Go's test-result cache lets a plain `go test ./...` print `ok` without
  executing anything.
- Graded on **Go 1.26.2, Linux only**. Upstream CI runs a version matrix; no
  entry here claims it green.

## Disclosure: a session limit truncated run 3

Run 3 ran two iterations before a Claude session limit ended it. It counts as
one of the four budgeted runs, so convergence arrived on the last one available.
The uncommitted probe batteries it was holding were committed as an explicit
salvage commit rather than discarded.

## Nothing was sent upstream

Four Highs is the largest haul in this cohort and none of them was filed. The
reason is the same bar every receipt here applies: each rests on tests the loop
itself wrote, with no external corpus or reference implementation to arbitrate.
The stack-exhaustion finding is the one most likely to be worth a maintainer's
attention, and it is recorded here rather than sent so that a maintainer who
finds this page can judge it on the evidence.
