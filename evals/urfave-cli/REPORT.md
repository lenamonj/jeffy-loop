# Jeffy eval: urfave/cli

The most-depended-on CLI framework in Go outside the stdlib, run 2026-08-30
as one of three targets in wave 1 of the merged-PR campaign (cohort
2026-08-30), alongside `indicatif` and `immer`. **2 runs, 18 iterations,
converged** at `cde0527d6d9d465b8ceefab4d91821af7822a981`, in round 2 of a
**pre-registered budget of 3 rounds of 10**. Run 1 filed the map, closed the
three Highs and swept all 21 surface rows; run 2 closed the remaining
Mediums and Lows and passed the gate on its first invocation.

**Convergence standard**: evaluator countersigned, with an **empty ledger**.

| | |
|---|---|
| Base | `1a4deb4f5a35ee12706602698dc0527d44c14b19` (main, 2026-08-24; upstream CI 13 success, 1 skipped on this exact commit) |
| Findings closed | **10** - 3 High, 4 Medium, 3 Low |
| Shipped-code change | 18 files, **+511 / -92** |
| Surface inventory | **21 of 21 rows swept** |
| Ledger at convergence | empty - nothing carried |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | `go vet ./... && go test ./... -count=1` green |

## What the loop found

- **`P1` (High)** - a lone `-` positional argument ended flag parsing and
  discarded every argument after it: `prog - foo bar` never saw `foo bar`.
  The parse loop appended `-` and then broke out with arguments still
  uncollected.
- **`P2` (High)** - positional arguments were passed through
  `strings.TrimSpace` before being stored, so a filename or search string
  carrying deliberate whitespace was silently rewritten. The parser computed
  a trimmed copy to classify each argument and then stored the copy.
- **`P3` (High)** - with `UseShortOptionHandling`, a value-taking flag that
  was not last in a combined short group was dropped with no value and no
  error. The group-splitting loop had a branch for a bool member and a
  branch for the last member, and nothing correct for a non-bool member in
  the middle.
- **`G1`, `H1`, `P4`, `P5` (Medium)** - `Command.Generic(name)` returned nil
  for a flag that was found and parsed; a root command rendered declared
  positional Arguments as generic `[arguments...]` while the identical
  declaration on a subcommand rendered their names (closed as a class);
  the pkg.go.dev landing comment showed the v2 action signature against a
  `cli.Context` type that does not exist in v3; and `parseArgsFromStdin`
  appended an unterminated quoted token once per non-space rune it
  contained.
- **`L1`, `T1`, `L2` (Low)** - error text split across two output streams;
  a suite that failed under `go test -shuffle=on` (order-dependent global
  state, fixed and then proven across 45 shuffled runs); and a docs module
  whose go.mod/go.sum could not `go build` under readonly mode.

## What the loop declined

Three items are published in the backlog's Proposed section rather than
worked, because each is a maintainer's call, with the evidence attached:
adding `-shuffle=on` to CI (45 green shuffled runs at HEAD against 3 of 5
sampled seeds failing before the T1 fix), removing the dead exported
`Serializer` interface (a public API break), and adopting getopt's
attached-value form for short groups (a behaviour change).

## Run shape

Run 1 (10 iterations): first audit filed the envelope and the map, then P1,
P2, P3 closed back to back, then five sweep iterations took the surface to
21 of 21, closing P5 along the way. Run 2 (8 iterations): G1, H1, P4, a
mid-run audit, then L1, T1 (with a journal rotation), L2 - and the ledger
emptied. The closing audit filed nothing, and the evaluator's single
invocation returned PASS on the same iteration. No run ended blocked.

## Environment

WSL2 linux/amd64, go 1.26.2. Engine 1.20.0 on Claude Code 2.1.232, model
`opus[1m]`. The environment fingerprint in PLAN.md derives its exclusion
list by command: no build constraint excludes any test file on this host;
the `docs/` module (its own go.mod) is not reached by the verify command
and is ungraded - which is exactly where L2 lived, found by the sweep
rather than the suite.

Full iteration record: [journal.md](journal.md). Complete shipped diff:
[fixes.patch](fixes.patch).

## Upstream

[#2423](https://github.com/urfave/cli/pull/2423) (positional arguments keep their whitespace) was filed 2026-08-30 and **merged 2026-09-04** by dearchap, after a reviewer asked how four quoted flag-like inputs behave and got a measured table: unchanged in all four, only a genuine positional now keeps its whitespace.
