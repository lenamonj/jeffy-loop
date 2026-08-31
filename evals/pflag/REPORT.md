# Jeffy eval: spf13/pflag

The POSIX/GNU-style flag package under Cobra, and therefore under most of
the Go CLI ecosystem. Run 2026-08-31 in wave 3 of the merged-PR campaign
(COHORT-WAVE3.md). **1 run, 11 iterations, converged** at
`ae42abbf0451db5223c95dd05a217bec83242ea3`, in round 1 of a
**pre-registered budget of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `4f8e9056816a26ecbac9fe26cde50968eb3626f8` (master; upstream CI 7 success on this exact commit) |
| Findings closed | **3** - 2 High, 1 Medium |
| Shipped-code change | 7 files, **+129 / -5** |
| Surface inventory | **15 of 15 rows swept** |
| Ledger at convergence | 2 carried, 2 blocked with reasons recorded |
| Evaluator | **2 invocations: PASS, PASS** |
| Suite at convergence | `go test -count=1 ./...` green (~1 s) |

## What the loop found

- **`P-001` (High)** - `StringToString` with a nil default map panicked
  `assignment to entry in nil map` the first time the flag was set. **Not
  taken upstream**: the duplicate check found open PR
  [spf13/pflag#506](https://github.com/spf13/pflag/pull/506) already
  carrying the identical fix, so nothing was filed.
- **`P-002` (High)** - `getUnknownFlagsHandling` tested the deprecated
  `ParseErrorsWhitelist.UnknownFlagsHandling` and then returned the
  `ParseErrorsAllowlist` field, which is `ErrorOnUnknownFlag` whenever that
  branch is reached - so setting the deprecated option did nothing at all.
  One identifier. Filed upstream as
  [spf13/pflag#507](https://github.com/spf13/pflag/pull/507) with a
  regression test following the project's own `BackwardsCompat` naming
  pattern; the test was proven red against upstream HEAD before filing.
- **`P-003` (Medium)** - `countValue.Set` assigned the `ParseInt` result
  before checking the error, so an invalid value clobbered the caller's
  counter to zero, and it surfaced raw stdlib text where every sibling
  scalar returns a short message.

## Carried and blocked, with reasons

- **`P-007` (Medium, blocked)** - `ipValue.Set` accepts an empty value
  without touching the address. Investigated and **not fixed**: the
  behaviour turned out to be a deliberate public contract rather than an
  oversight, and the receipt records that rather than changing it.
- **`P-004` (Medium, blocked)** - the published Go module zip carries the
  loop's state files. Partly fixed, then blocked on the part Go's module
  proxy offers no mechanism for - an honest partial, not a silent pass.

## Environment

WSL2 linux/amd64, go 1.26.2. Engine 1.20.0 on Claude Code 2.1.232, model
`opus[1m]`. Oracle sabotage-proven before launch: `FlagSet.Set` made to
discard the value turned the suite red, green restored on revert.

Full iteration record: [journal.md](journal.md). Complete shipped diff:
[fixes.patch](fixes.patch).
