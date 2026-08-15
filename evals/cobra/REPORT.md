# Jeffy eval: spf13/cobra

The CLI framework behind kubectl, Hugo, GitHub CLI and most of the Go tooling
ecosystem. **4 runs, 32 iterations, converged** at
`60fe4443e962af250ac848f06ad4851b3f3d79da`, against a **pre-registered budget of
4 runs of 10 iterations** written to the cohort file before the first iteration.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | tag `v1.10.2`, `88b30ab89da2d0d0abb153818746c5a2d30eccec` |
| Upstream CI on the base | 40 check-runs, all green |
| Findings closed | **19 - 13 Medium, 6 Low, zero High** |
| Shipped-code change | 22 files, **+1,173 / -129** |
| Surface inventory | **25 of 25 rows swept** |
| Ledger at convergence | **empty** |
| Evaluator | 3 invocations: REJECT, REJECT (run 2), **PASS** (run 4) |

One severity is inferred rather than read: `M13` was filed by the gate during
salvage and its entry records no severity label. It is counted Medium on this
run's own `M`-prefix convention, which holds for `M1` through `M15`. The
alternative would be to drop it from the breakdown, which would publish 18
findings for a run that closed 19.

## What the loop found

No High, and the receipt says so plainly - this is a mature, heavily reviewed
library and the findings are correspondingly narrow. Three are worth naming
because they are the kind a test suite does not catch.

**`SOURCE_DATE_EPOCH` was read into a local-zone time.** The whole purpose of
that variable is byte-reproducible output, and `fillHeader` resolved it in the
host's zone, so the same source generated different man-page headers on two
machines in different zones. A reproducibility feature that is not reproducible.

**Persistent flags accumulated and were never removed.** `mergePersistentFlags`
copies an ancestor's persistent flags into the command's own set and nothing
ever took them back out, so a command whose parent link changed kept reporting
the old parent's flags through `InheritedFlags`. Two further findings, `M8` and
`M10`, are the same root cause reached from the parser and the completion
builder.

**The generators mutated the caller's own data.** The completion and doc
generators sorted slices reachable from the caller's `Command` in place, so
generating documentation reordered the user's command tree as a side effect.

## The gate rejected twice before it passed

Run 2 spent both its invocations on rejections and ended without declaring. Run
4 passed on its first invocation, from a board of 25 of 25 rows swept and an
empty ledger. The two rejections are in `journal.md` under run `ea04503e`; the
passing verdict is committed at `.jeffy/evaluator/dea180db-175303-1.md` in the
target clone.

Run 3 ended after 4 iterations without declaring, and its own journal says why:
the run reached its final iteration with work it could not finish, so it tidied
the ledger and wrote a handoff rather than starting a task that would be cut in
half. Run 3 is also the round that a Claude session limit truncated - see the
disclosure below.

## Declared limits, repeated from the pre-registration

- **`go test ./...` grades exactly two packages**, `cobra` and `cobra/doc`.
  Upstream CI runs a matrix across Go versions and Windows; this host graded
  **Go 1.26.2 on Linux only**. No entry claims the matrix green.
- **The verify command carries `-count=1` deliberately.** Go caches test results
  by input hash, so a plain `go test ./...` can print `ok` for every package
  without executing a single test - a verify command able to report success
  without running is the exact class this project exists to catch. The suite
  runs in under two seconds either way.
- The oracle is 473 `RUN` lines across the two packages, and `shellcheck` was
  present on this host, which matters because `TestBashCompletions` silently
  skips its shellcheck assertion when the binary is absent.

## Disclosure: a session limit truncated run 3

Run 3 was cut off mid-iteration by a Claude session limit rather than by a
stopping rule. It had produced four committed iterations at that point. Under
the accounting this cohort applied to every target, **a round killed by an
external interruption counts as spent**, so run 3 consumed one of the four
budgeted runs and the convergence came in run 4 with nothing left over. The
alternative reading - that an interrupted round never happened - quietly buys
extra iterations, and it is not taken.

The work in flight when the limit hit was committed as an explicit salvage
commit rather than discarded, and is visible in `journal.md`.

## Nothing was sent upstream

No issue and no pull request. The findings are real but narrow, every one of
them rests on tests this loop wrote, and cobra's maintainers receive a high
volume of contributions already. The bar this project applies is that a finding
goes upstream when its evidence sits outside the loop's own judgement - an
external corpus, a reference implementation, or the project's own contradictory
documentation. None of these nineteen clears it.
