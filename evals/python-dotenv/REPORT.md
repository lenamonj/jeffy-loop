# Jeffy eval: theskumar/python-dotenv

**Target**: [theskumar/python-dotenv](https://github.com/theskumar/python-dotenv) (8,830 stars) at master tip `751f8c14`, Python 3.14 on Linux - run in a local clone; nothing was pushed upstream.

**This receipt is different from the others: the run did not converge.** Four budgeted runs, 38 iterations, **25 findings closed** - and the loop still has not earned the clean closing audit convergence requires, because every full audit it has run has found something new. That is not a failure of the method, and the receipt does not dress it up as a success either. It is what a genuinely defect-rich library looks like when the standard is "one complete audit that files nothing."

**The headline**: 25 findings closed in the library that loads `.env` files for a very large share of the Python ecosystem, including two classes of silent data corruption in its write path. The test suite went from **220 passing to 461**. The product diff is 11 files, +1,178/-75.

## What convergence costs here, stated plainly

The closing rule needs one full fresh-evidence audit that files nothing. Six full audits ran across the four runs. **Every one of them found a High or a Medium.** The run counter tells the story:

| Run | Iterations | Findings closed | Ended because |
|---|---|---|---|
| 1 | 10 | F1-F8 | budget spent; closing audit filed F9 |
| 2 | 10 | F9-F16 | budget spent; two rows stale from its own final fixes |
| 3 | 12 | F17-F23 | budget spent, after the one-time +2 closing extension |
| 4 | 4 | F24 | stopped by the operator; the audit had just filed F25 |

Run 3 is worth noting for a reason beyond its findings: it is the first live firing of the engine's one-time +2 closing extension on a public target. The extension is granted at exact budget exhaustion when the ledger is empty and the inventory is swept, on the premise that only the closing ceremony remains. Here the audit *inside* the extension window filed a new Medium, iteration 12 fixed it, and the evaluator gate was never reached. The +2 bought work rather than ceremony. That is recorded as an engine defect to fix, not as a run that misbehaved.

Run 4 stopped for a different reason: the operator judged the remaining value was in disclosure rather than in another night of convergence chasing, and the receipt exists to say so rather than to imply the run was still in flight.

## The findings

Selected, most severe first. The full record with acceptance checks and red-green evidence for each is in [journal.md](journal.md).

- **F1 (High) - `set_key(quote_mode="never")` silently writes a different value than it reports.** The value is interpolated raw, so `#`, leading or trailing whitespace, a leading quote, or an embedded newline all read back as something else, while the call returns `(True, key, value)`. A 4,000-value fuzz measured **775 round-trip failures in `never` mode against 211 in `always`/`auto`**. The newline case is a `.env` injection primitive: `set_key(p, 'A', 'x\nADMIN=true', quote_mode='never')` produces a file parsing to `{'A': 'x', 'ADMIN': 'true'}`, and reports success.
- **F9 (Medium) - `set_key` validates the value and never the key.** `set_key(p, "a=b", "x")` writes `a=b='x'`, which parses back as `{"a": "b='x'"}` - a different key holding a different value, reported as success. Independent verification found the class is broader than filed: `" a"`, `"a\tb"`, and `"export A"` are also corrupted, while `"a.b"`, `"MY-KEY"`, and `"a'b"` round-trip correctly, so a fix is narrowly targetable.
- **F22 (High) - an undecodable `.env` kills four of five CLI subcommands** with a raw Python traceback rather than a diagnostic.
- **F11 (Medium) - `dotenv list --format=export` and `--format=shell` emit shell syntax a shell cannot evaluate**, because the value went through `shlex.quote` and the key was interpolated raw.
- **F10, F23 (Medium) - the CLI had exception boundaries for read failures and none for writes**, so `-f <directory>` and a read-only parent directory each produced a raw traceback.
- **F5 (Medium) - `get_cli_string` performs no shell quoting** while its docstring calls the result "suitable for running as a shell script". The existing `" " in value` branch shows the function is already attempting to quote and doing it incompletely.
- Plus F2, F3, F4, F6, F7, F8, F12-F21, F24 across correctness, error handling, testing, typing and documentation.

## Independent verification, and one finding this receipt retracts

Four findings were re-verified for this receipt against a clean clone of upstream, by agents that never read the loop's tree, each followed by an adversarial pass whose job was to refute it. All four reproduce. Their disposition is not uniform, and saying so is the point of this section.

- **F9 survived refutation** and is the one disclosed upstream. No prior art in their tracker, no test asserts the behaviour, nothing documents it, it is reachable straight from the CLI, and a strict round-trip check on the key keeps all 220 upstream tests green.
- **F1 is real but was not filed**, because upstream [issue #218](https://github.com/theskumar/python-dotenv/issues/218) is this defect verbatim, reported in 2020 and closed as completed in 2021 after PR #330 deliberately fixed `always`/`auto` and left `never` writing raw. Refiling it re-litigates a decision the maintainer already made. The verification also corrected the loop: embedded quotes round-trip fine; only a *leading* quote breaks.
- **F3's stated premise is withdrawn.** The loop filed it as `${VAR:-default}` contradicting the README's documented precedence. It does not. The README defines `FOO=` as "associated with the empty string", so a bare declaration is a value in the file, the first item of the precedence list legitimately wins, and skipping the default is what the documented order prescribes. The behaviour difference from POSIX shells is real and the maintainer has already declined that argument twice; the *contradiction* claim was wrong and is retracted here rather than quietly dropped.
- **F5 survived refutation** but was not filed: comparable fixes sit unreviewed in their PR queue since 2022.

## The limits

- Not converged. Nothing in this receipt should be read as a certification of the tree; it is a record of 25 defects closed and one audit still finding more.
- F25 is open with evidence and an acceptance check, and it is a defect in F24's own fix rather than a pre-existing one, which is the loop auditing its own work.
- The fixes in [fixes.patch](fixes.patch) are verified by the project's own suite at 461 passing, but only F9's fix has been re-proven independently against pristine upstream.

**Status**: fixes live in this eval's artifacts. F9 was disclosed upstream as [theskumar/python-dotenv#678](https://github.com/theskumar/python-dotenv/pull/678), a 51-line pull request cut independently from upstream `main` rather than lifted from this run's tree: the two added tests, applied alone to unmodified `main`, give 8 failures against the 8 rejection cases and 7 passes against the control keys that already round-trip, and the change takes the suite from 220 to 235 passing with `ruff` and `mypy` clean. Its scope is deliberately the key only; the value-side sibling is upstream #218, closed in 2021, and this run does not reopen it.
