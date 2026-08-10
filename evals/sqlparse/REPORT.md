# Jeffy eval: andialbrecht/sqlparse

**Target**: [andialbrecht/sqlparse](https://github.com/andialbrecht/sqlparse) (4,009 stars, verified via `gh api repos/andialbrecht/sqlparse --jq '.stargazers_count'` on 2026-08-08) at `e7d95d494cebc66fd220198ea2eb2cf94a8bb5fe`, upstream master at the time of the run and still unmoved at the time this receipt was written. BSD-3-Clause. Python, in a local clone; the loop's work was never pushed anywhere. sqlparse is the non-validating SQL parser and formatter behind Django's debug toolbar, a large share of Python SQL tooling, and the `sqlformat` command line tool.

**This is a full `/jeffy` loop run that reached machine-checked convergence, in five runs of 47 iterations.** **31 findings filed and closed (7 High, 11 Medium, 13 Low)** with **6 more declined on evidence**, of which the shipped-code change is **12 files, +345/-156** under `sqlparse/`, or **20 files, +1,025/-168** counting tests, docs and the CHANGELOG. Converged at `31e851e6704ffacc99a531f9405eb46c5f2e97fb` on 2026-08-08: empty ledger, all **24 surface-inventory rows swept**, the verify command re-run fresh for this receipt, and the adversarial evaluator's PASS on record after **seven rejections across the five runs**.

It is the third target of the cold cohort whose selection rule is an oracle the loop cannot rewrite into agreement. sqlparse's oracle is a documented invariant rather than an external corpus: it promises to be non-validating and to return the input unmodified, so round-trip fidelity and format-idempotence are checkable on arbitrary SQL text the loop did not choose.

## The budget was fixed at five runs, and it took five

This is the receipt's most important number and the reason it is worth reading.

`ATTEMPTS.md` commits every target from TOML-M onward to a **run budget fixed before the first iteration**. sqlparse was pre-registered at **five runs of ten iterations**, in `COHORT-2026-08-08.md`, written the day the cohort launched and before any outcome was known. The rule it recorded was explicit:

> A target that has not converged in five runs is published in `ATTEMPTS.md` as not converged, with its runs and iterations counted, exactly as libuv is.

Runs 1 through 4 all failed. Two ended **blocked**, out of evaluator invocations with work still on the ledger. After run 4 the honest expectation, written down at the time, was that the target would be published as a non-convergence: the evaluator had rejected four runs in a row, and each rejection came from a *pre-existing* defect its own fresh adversarial hunt had turned up rather than from anything a run had broken.

Run 5 converged at iteration 8 of 10, on the second and final evaluator invocation, with **two iterations of the last budgeted run unspent**.

A stopping rule only carries evidentiary weight when it was genuinely capable of producing the unfavourable outcome. This one was, right up to the last budgeted run. The corpus's other long grinds do not have that property: dotenv took eight runs and dayjs eight, both before pre-registration existed, and both can fairly be read as continuing until the result arrived. This one could not have.

| Run | Iterations | Evaluator | Ended |
|:---|---:|:---|:---|
| `ce480904-142056` | 10 | reject | budget spent |
| `d94c386f-153253` | 10 | reject | budget spent |
| `74432a21-171900` | 9 | reject, reject | **blocked** |
| `56471ef3-194330` | 10 | reject, reject | **blocked** |
| `13b41656-223157` | 8 | reject, **PASS** | **converged** |

Counts derived from the run journals by script, not transcribed: 5 runs, 47 iterations as the sum of per-run maxima, 52 journal entries, **8 evaluator invocations returning 7 rejections and 1 PASS**. Two entries carry more than one verdict and a per-line count misreads both, so they are stated here: run 3's second gate line is one rejection reported across two files, not two rejections, and run 4's single closing entry covers *"both invocations of this run"* and records *"Evaluator: REJECT, twice"*. An earlier draft of this receipt said six rejections and described run 4's second invocation as attested only by the gate artifact and not the journal; the journal's own entry says otherwise in its Task and Verification lines, and the figures here are the corrected ones.

## The loop declined its own finding by running it

The run's second-most important event is a finding it **threw out**.

The run-4 evaluator recorded an observation alongside its rejection: PLAN.md's Verify baseline sentence quoted counts that, in the gate's words, "reproduce at neither commit". The loop filed it as **R3**, a Low documentation defect, and carried it into run 5 as the last open item on the ledger.

Run 5, iteration 4 went to fix it, ran the claim first, and **overturned it**:

> Closed by declining it: the sentence is correct, and the finding was reached by checking commits the sentence does not name.

The sentence reads `Baseline at e7d95d494cebc66fd220198ea2eb2cf94a8bb5fe: 494 passed, 2 xfailed, 1 xpassed`. The loop extracted that exact commit with `git archive` into a scratch directory, never a checkout, ran the Verify command against the extract as written, and got `494 passed, 2 xfailed, 1 xpassed` and `All checks passed!`, both halves exit 0. The gate had measured at `96ae9c5` and at HEAD, neither of which the sentence names.

R3 moved to Declined, emptying the ledger. **The evaluator was wrong and the loop proved it rather than complying.** That is the same shape as the rrule run withdrawing its own High against `python-dateutil`, with the roles reversed: there the oracle overruled the loop, here the loop overruled the gate, and in both cases the disagreement was settled by execution.

Six findings were declined in total, each with the measurement that killed it recorded in the backlog.

## What the loop found

Seven Highs, each reproduced before it was filed:

- **A destination file truncated to zero bytes before the work that could fail** (EV-001). `cli._process_file` opened the output with mode `w` before `validate_options` and `sqlparse.format` ran, so any failure after that point left the user's file empty. Reproduced against a 20-byte victim file. This is the only data-loss finding in the set.
- **`format('(as)', reindent=True)` raising `IndexError`** (R2). `StripWhitespaceFilter._stripws_parenthesis` read `tlist.tokens[1]` and `tlist.tokens[-2]` without checking the group had that many children, and `(as)` groups as a `Parenthesis` holding one `Identifier`. Four ASCII bytes crashed the library, and `python -m sqlparse -r` on a four-byte file exited 1 with a raw traceback and no `[ERROR]` line. It also fired under `strip_whitespace` and `reindent_aligned`, and from `select * from (as)`, `select coalesce(as)`, `update t set a = (as)` and `select a from t group by (as)`.
- **`format('case where end', reindent_aligned=True)` raising `ValueError`** (AU-001) out of `TokenList.token_index`, from a fourteen-character input.
- **`sql.Function.get_window()` raising `AttributeError` on every function with no OVER clause** (R4). The guard tested the tuple `token_next_by` returns, and `(None, None)` is truthy, so `if not result` was dead code. `select foo(a) from t` crashed.
- **`output_format='python'` and `'php'` emitting snippets whose value differs from the input SQL** (JF-001), because the filters escaped the quote character but not the backslash.
- **`output_format='python'` emitting invalid Python** (EV-003) for a raw newline inside a SQL string literal.
- **The same filter emitting invalid Python whenever a statement's leading whitespace held a newline** (JF-006), which is every multi-statement input written one statement per line.

The shape is consistent and worth naming: this is a library that promises to hand your SQL back unchanged, and the Highs are almost all cases where it either changed the text, emitted something that would not parse, or died on input a non-validating parser is supposed to accept without opinion.

## The tests went into the project's own harness

The go-yaml receipt in this corpus had to disclose that all of its regression evidence lived in `.jeffy/probes/`, so a maintainer applying its patch got the fixes with almost none of the tests proving them. This run is the counter-case.

`tests/` went **+506/-7 across five files**, and the project's own suite went from **494 passed, 2 xfailed, 1 xpassed** at the base commit to **663 passed, 1 xfailed, 1 xpassed** at the converged tree. Of the seven deleted lines, four are an `xfail`-marked placeholder and three are the header of a live test renamed in place, discussed below.

Fifteen probe batteries under `.jeffy/probes/` carry the class-completeness enumerations on top of that, each one built to fail against the exact defective tree it indicts. The batteries are the run's own instrument and are not counted as the project's tests.

## The patch applies to pristine upstream, and it is green

Verified for this receipt rather than asserted, on a clone that had never seen the run:

```
git clone https://github.com/andialbrecht/sqlparse.git
git checkout e7d95d494cebc66fd220198ea2eb2cf94a8bb5fe
git apply fixes.patch          # applies clean, 20 files
python -m pytest tests/ -q     # 663 passed, 1 xfailed, 1 xpassed
```

On that patched pristine tree, re-measured independently: **21 calls** across seven parenthesis shapes and three option sets produce **zero** non-`SQLParseError` escapes, and `format('case where end', reindent_aligned=True)` returns without raising. Both headline crashes are dead in the artifact a maintainer would actually apply.

## Honest caveats

**Two of the findings were independently rediscovered, not novel.** Upstream's tracker already carried them, filed three weeks before this run launched by a contributor working entirely separately:

- [#862](https://github.com/andialbrecht/sqlparse/pull/862) and [#864](https://github.com/andialbrecht/sqlparse/pull/864) are the `(as)` crash, R2 here, reported against the trigger `(::)`.
- [#863](https://github.com/andialbrecht/sqlparse/pull/863) is the `case where end` crash, AU-001 here.

All three were opened in July 2026, received no maintainer comment, and were closed unmerged by their own author on 2026-07-28. The run was cold in the sense the cohort rule requires, meaning we had no knowledge of them and never pointed the loop at anything, and the loop reached both by its own reproduction. But "found independently" is the accurate claim and "found first" is not, and two parties hitting the same defects is corroboration rather than embarrassment. **Nothing from this run was filed upstream.** The maintainer merged five pull requests on 2026-07-25 while passing over an equivalent fix to the same function, which makes the odds of a third submission poor, and the honest disposition was to publish the finding rather than add to a queue.

**The patch removes a public option.** JF-003 deleted `sqlparse/filters/right_margin.py` and turned `right_margin` from an accepted option into one that raises `SQLParseError` naming itself. Upstream's own file carried `# FIXME: Doesn't work` with the `keep_together` tuple commented out to empty, and with it empty the filter split `schema_name.table_name.column_name_long` across three lines and changed the parse tree. Four of the seven deleted test lines are that feature's `xfail`-marked placeholder; the other three are the header of `test_format_right_margin_invalid_option`, a live test renamed to `test_format_right_margin_rejected` and widened in place rather than removed. Both are replaced by tests asserting the new contract, plus one pinning `right_margin=None` as a no-op. This is still a breaking API change decided inside a loop run, and reviving the feature properly was filed as a **Proposed** item for the owner rather than settled by the loop. A maintainer who disagrees should read that as the one hunk to drop.

**One `xpassed` was inherited and left alone.** The baseline carried a test marked expected-to-fail that passes; it still does. It was never touched and never mentioned to the loop.

**Two runs ended blocked.** Runs 3 and 4 exhausted their evaluator invocations with work still open. That is two of five, the worst ratio of any converged target in this corpus, and it is what a target resisting the standard looks like from the inside.

## Independently re-verified for this receipt

Everything below was executed against the converged tree or a pristine clone on 2026-08-08, after the run ended, and none of it is taken from the run's own prose:

| Claim | Method | Result |
|:---|:---|:---|
| R2 crash class closed | 7 shapes x 3 option sets on the converged tree | 0 of 21 non-`SQLParseError` escapes |
| CLI no longer tracebacks | `python -m sqlparse -r` on a four-byte `(as)` file | exit 0, prints `(as)` |
| Suite at converged tree | `pytest tests/ -q` | 663 passed, 1 xfailed, 1 xpassed |
| Nothing weakened | `git diff --numstat base..HEAD -- tests/` | +506/-7, the 7 being an `xfail` placeholder (4 lines) and a live test's header renamed in place (3) |
| Ledger empty | `BACKLOG.md` Now / Next / Later | all three empty |
| Inventory swept | `PLAN.md` row states | 24 rows, 24 swept, 0 unswept, 0 unreachable |
| Patch is real | apply to pristine `e7d95d4`, run suite | applies clean, 663 passed |
| Base is upstream | `git fetch origin master` | upstream master identical to base, zero drift |
| Prior art | `gh` search on the tracker | #862, #863, #864 closed unmerged |

Runs, iterations, findings and severities were derived by script from [`journal.md`](journal.md) and the full history of the run's `BACKLOG.md`, rather than read off the run's own summaries. The journal is published here in full, so the run and iteration counts can be recomputed from it directly: run identifiers and iteration numbers are carried in every entry heading.

**Convergence standard**: evaluator countersigned. The adversarial evaluator's verdict for this run is in the narrative above; the standard each target met is recorded in [evals/ATTEMPTS.md](../ATTEMPTS.md).
