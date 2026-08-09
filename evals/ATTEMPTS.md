# Every target ever started

The receipts table in the README lists what converged. This file lists
everything that was ever *started*, including what did not finish and what was
abandoned, because a method that only publishes the runs that worked is not
being measured.

Derived from the run journals rather than from prose. The iteration column
reproduces each receipt's own published figure, so this table and the README
agree; where a receipt counts salvage and rotation entries and another counts
per-run maxima, the difference is a counting convention and never a different
run. Runs count distinct run identifiers, except in the four earliest journals
whose heading grammar predates run tokens, where runs are counted by budget-arc
restarts and corroborated against each receipt's own text. One journal (`ta`)
is lossy by its own admission: 18 entries from its first three runs were
destroyed by a rotation defect that run exposed, and the receipt records the
loss rather than hiding it.

## Brownfield

| Target | Runs | Iterations | Outcome | Standard met | Runs that ended blocked |
|---|---:|---:|---|---|---:|
| bat | 1 | 10 | converged | evaluator countersigned | 0 |
| chalk | 2 | 8 | converged | pre-evaluator | 0 |
| dayjs | 8 | 74 | converged | evaluator countersigned | 1 |
| fasthttp | 7 | 58 | converged | evaluator countersigned | 0 |
| go-yaml | 3 | 29 | converged | evaluator countersigned | 0 |
| gson | 1 | 2 | converged | evaluator countersigned | 0 |
| jsoncpp | 1 | 10 | converged | evaluator countersigned | 0 |
| mustache.js | 2 | 11 | converged | pre-evaluator | 0 |
| PyPortfolioOpt | 6 | 58 | converged | evaluator countersigned | 1 |
| python-dotenv | 8 | 73 | converged | evaluator countersigned | 1 |
| quantstats | 4 | 40 | converged | evaluator countersigned | 0 |
| records | 1 | 7 | converged | pre-evaluator | 0 |
| rrule | 4 | 33 | converged | evaluator countersigned | 0 |
| RuboCop | 1 | 7 | converged | evaluator countersigned | 0 |
| sqlparse | 5 | 47 | converged | evaluator countersigned | 2 |
| Spectre.Console | 1 | 8 | converged | evaluator countersigned | 0 |
| speedtest-cli | 1 | 5 | converged | pre-evaluator | 0 |
| ta | 6 | 64 | converged | evaluator **unavailable**, recorded | 0 |
| yfinance | 1 | 9 | converged | evaluator countersigned | 0 |
| PapaParse | audit only | - | audit, not a loop run | n/a | - |
| **libuv** | at least 1 | at least 1 | **abandoned, no receipt** | n/a | - |

## Greenfield

| Target | Runs | Iterations | Outcome | Runs that ended blocked |
|---|---:|---:|---|---:|
| TOML decoder | 1 | 11 | converged | 0 |
| gitignore matcher | 5 | 42 | converged | 3 |
| TOML-M (mutated spec) | 1 | 14 | converged, with a disclosed process violation | 0 |

## The convergence standard is not uniform, and here is the split

The engine tightened over time. Of the 18 brownfield convergences:

- **13** were countersigned by the adversarial evaluator, the current standard.
- **1** (`ta`) records the evaluator as `unavailable` - that session carried a
  standing instruction against sub-agents, and the receipt says so rather than
  working around it.
- **4** (`chalk`, `mustache.js`, `records`, `speedtest-cli`) predate the gate
  entirely and converged under the earlier standard: a clean closing audit and
  an empty backlog.

Every receipt names the standard its own run met. Pooling all 18 as one number
would overstate the earliest four.

## What was started and never published

- **libuv.** A real loop run on a WSL clone, 2026-07-31. At least one full
  iteration completed. It produced two engine lessons that are on the release
  backlog to this day: a pre-flight refusal for `core.autocrlf` on a non-Windows
  tree (the loop caught that its own revert path would have rewritten every
  source file), and a refusal for verify commands ending in a truncating pipe
  (its first suite run reported exit 0 while 13 tests were failing). The run was
  not carried to convergence and has no receipt directory. It is the one
  genuinely abandoned public target.
- **A private project ("tradestudio").** At least three runs, 2026-07-30. It
  produced the lesson that probe batteries must be re-run at close: running
  every battery at that run's wrap-up caught a six-iteration-old regression
  every verify gate had reported green. Not published because the code is
  private.
- **This repository itself.** The loop is run against its own tree
  periodically; the closing sequence of one such run is quoted in the README.
  Its state files are the loop's working memory rather than a receipt, and stay
  out of the published tree.

## Honest reading of these numbers

Convergence here is per-run, and a blocked run is relaunched from written
state with a fresh evaluator budget. Under that protocol, persistence raises
the chance of eventually converging - dotenv took eight runs, dayjs eight,
gitignore five with three terminal rejections along the way. The run counts
above are published precisely so that "18 converged" is read with the cost
attached rather than as a success rate.

Targets from here on carry a **pre-registered run budget** committed before
their first iteration, so the stopping rule is fixed in advance rather than
chosen after seeing the outcome. TOML-M was the first, at five runs; it used
one. `go-yaml` was the second, also at five runs; it used three and the
remaining two were not spent, because a budget is a ceiling rather than a
quota. `rrule` was the third, at five runs; it used four.

`sqlparse` was the fourth, at five runs, and it is the first target where the
budget nearly bound. Four runs failed, two of them ending blocked, and the
expectation written down after run 4 was that it would be published here as a
non-convergence. It converged on the fifth and last budgeted run, at iteration
8 of 10. Six evaluator rejections preceded that PASS. The rule was capable of
producing the unwelcome answer up to the final run, which is the only condition
under which a stopping rule is worth publishing at all.
