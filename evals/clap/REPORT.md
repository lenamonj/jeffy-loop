# Jeffy eval: clap-rs/clap

The argument parser under most of the Rust CLI ecosystem, and **the target this
cohort predicted would fail**. **4 runs, 31 iterations, converged** at
`fc6924c6561dbb080e531a02cdd287508ca86a8d`, against a **pre-registered budget of
4 runs of 10 iterations**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | tag `v4.6.6`, `4a622b4340d5e1fffff60c0ecefdc6882f738159` |
| Upstream CI on the base | 27 of 29 green - **2 legs genuinely red**, see below |
| Findings closed | **13** - 12 with a recorded severity (1 High, 6 Medium, 5 Low) plus `NEG-EXP`, whose filing line records none |
| Shipped-code change | 23 files, **+528 / -74** |
| Surface inventory | **35 of 35 rows swept**, the largest surface in the cohort |
| Ledger at convergence | **6 Lows carried**, listed below |
| Evaluator | **1 invocation, PASS** |

## The prediction this run refutes

The cohort brief, written before any launch, put five targets on one uniform
budget so that surface size would be the variable, and recorded a prediction:
*"cobra, validator and arrow converge inside the budget; Humanizer and clap are
the two at risk of exhausting it."*

clap was named at risk on surface size alone - 35 inventory rows, 119 source
files, 42,075 lines across a 7-crate workspace. For three runs it looked exactly
like that call was right: **after 30 iterations it had swept 20 of 35 rows, its
ledger had grown from 9 open findings to 11, and the evaluator gate had never
once been invoked** - the signature of a run whose budget is absorbed by
findings while the map goes uncleared.

**In run 4 it swept the remaining 15 rows and passed the gate on its first
invocation.** Meanwhile `arrow`, at 19 rows the second-smallest surface in the
cohort, did not converge at all.

Surface size did not predict convergence here, and the prediction was on the
page before the fact. That is the useful result: the coverage problem this
cohort was designed to measure is not a function of how big the surface is.

## What the loop found

The one High, `REPL-EOF`, was filed by run 4's own sweep of the shipped binaries
and closed in the same run - the last thing standing between the run and its
declaration.

Three of the Mediums are worth naming for shape rather than severity:

- **`FISH-TRYGEN`** - `Shell::Fish::try_generate` panics instead of returning
  `Err` when the command has subcommands. A `try_` function whose contract is to
  return a `Result` and which instead aborts the process.
- **`ESCAPE-SUBCMD`** - the dynamic completion engine offers subcommand names
  past the `--` escape, which the same command then rejects. The completion and
  the parser disagreed about what was valid.
- **`CTRL-WIDTH`** - `display_width` treated every ASCII control character as the
  start of an ANSI escape sequence, so help text carrying a tab measured wrong
  and wrapped wrong.

`RANGE-ZERO` is the tidiest: `ValueRange::new` documents that empty ranges panic
in debug builds, and `0..0` and `..0` did not, so `num_args(0..0)` silently
produced a range that could never match.

## Six Lows carried at convergence

Published rather than dropped, per the severity floor: `WRAPHELP-NOCOLOR` (the
`clap_builder` unit tests do not compile with `wrap_help` on and `color` off),
`UNDOC-PANIC`, `ADVANCE-DOC`, `BOOL-DOC`, `ALIAS-EMPTY` and `RESET-NONE`, the
last five all documentation contracts that do not match the code.

## Declared limits

- **Upstream CI is RED on this commit and that is declared, not fixed.** Two of
  29 check-runs fail at the base: `Security audit` and `security_audit`. Those
  are cargo-audit legs that go red when a new RUSTSEC advisory lands against a
  dependency, days or weeks after the commit. They are not test failures and not
  this commit's regression. **No iteration bumped a dependency to turn them
  green** - a manufactured green baseline is worse than a declared red one.
- **`make test-full` is one leg of a six-way feature matrix** (`minimal`,
  `default`, `full`, `next`, `wasm`, `release`). `full` is the broadest and is
  what upstream runs on Linux stable; nothing here claims the other five green.
- **`git describe` at the base returns `clap_mangen-v0.3.2`, not `v4.6.6`** -
  clap tags per crate across a 7-crate workspace, so the nearest tag is whichever
  crate shipped last. Cite the SHA.
- Graded on cargo/rustc 1.97.1, edition 2024, MSRV 1.85, Linux x86_64 under WSL2.

## Disclosure: a session limit truncated run 3

Run 3 ran a single iteration before a Claude session limit ended it, and counts
as one of the four budgeted runs. The work in flight - the `HIDE-NEXTLINE` fix
to `should_show_arg`, its battery rows and a CHANGELOG entry - was committed as
an explicit salvage commit rather than discarded, and is in `fixes.patch`.

## Nothing was sent upstream

Every finding rests on tests this loop wrote. clap's own snapshot corpus
(snapbox/trycmd over rendered help, error, man-page and completion output) is an
oracle the loop cannot quietly edit without it showing in the diff, and it ran
unchanged throughout - but it arbitrates rendering, not the contracts these
findings are about.
