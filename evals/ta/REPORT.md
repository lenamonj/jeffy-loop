# Jeffy eval: bukosabino/ta

**Target**: [bukosabino/ta](https://github.com/bukosabino/ta) (5,129 stars, verified via `gh api repos/bukosabino/ta` on 2026-07-27) at HEAD `a890410710a6e483c9ba08da7f3dd5089e4b9dff`. The last commit touching any Python is `5654782`, 2023-11-02; the released artifact on PyPI is `ta` 0.11.0 from the same day. Run on CPython 3.13.8 against pandas 3.0.5 / numpy 2.5.1 in a local clone. Nothing was pushed upstream, no issue or PR was opened.

**This is a loop run, not a single-pass audit.** Six `/jeffy` runs across three Claude Code sessions, **64 iterations**, 07:37 to 14:18 on 2026-07-27, ending in a machine-checked convergence at `b961193`. Every iteration ended in a local checkpoint; there are 130 of them. An earlier version of this receipt described an agent audit of the same target under the same method. It has been replaced, and the two are compared at the bottom.

**The frame**: `ta` is consumed programmatically. A trader hands it an OHLC DataFrame and writes the returned Series straight back into that frame. No UI, no network surface, no untrusted input. The only thing that can really hurt a user is a wrong number returned without complaint, so that is what the run went looking for.

**The baseline was red.** `python -m unittest discover` at `a890410` gives **134 tests, 2 errors** - `TypeError: assert_series_equal() got an unexpected keyword argument 'check_less_precise'`, a parameter pandas removed in 2.0. The machine-checked converged stop re-runs the project's own verify command and requires exit 0, so the loop could not declare convergence until it made that green.

It also chose the gate correctly, which was the run's first real risk. `pytest` collects **nothing** in this repo, because the test files are not named `test_*`, so a pytest-based verify command would have reported "no tests ran" and taken a false green all the way to convergence. The opening audit read the Makefile and `.circleci/config.yml` and picked `unittest discover` instead, and recorded the red baseline explicitly with the rule that a failure would only count as a regression once the two errors were fixed.

## Outcome

| | at `a890410` | at convergence |
|---|---|---|
| Test suite | 134 tests, **2 errors** | **211 tests, 0 errors**, exit 0 |
| Statement coverage | not measured by the project | **100 percent** of 1,388 statements, 104 branches |
| `prospector --no-autodetect` at `veryhigh` | not run by the project | **0 messages** on `ta/` and on `test/`, all eight tools including bandit |
| Sphinx docs job | **never once executed** in the project's history | exits 0, HTML produced |

Diff against upstream: 48 files, 4,476 insertions, 697 deletions. **958 of those insertions are source and 2,112 are tests**, across 12 new test modules. The run wrote more than twice as much test code as product code.

Tasks filed across the run: 47. Defect classes closed class-complete: 14. Findings declined: 3. Decisions routed to the user as Proposed rather than seized: 2 open at convergence.

## The two that matter most

**Parabolic SAR mixed label-based and positional writes on the same Series.** At `a890410`, `ta/trend.py:1030` writes `self._psar[i] = high2` while line 1032, the very next branch, writes `self._psar.iloc[i] = high1`. `self._psar` is `self._close.copy()`, so it carries the caller's index, and `i` is a loop counter - a position. Following the README quickstart verbatim on the library's own 46,306-bar dataset, `psar()` returned **46,465 rows for a 46,306-row input**, 9,408 rows wrong, maximum absolute error **3,410.89** price units. On pandas 2 this emitted a `FutureWarning`; on pandas 3 the deprecation has completed and the write silently enlarges the Series instead, so the last audible warning is gone. The label-based write is absent at convergence.

**On-Balance Volume contradicts the definition its own docstring cites.** `np.where(close < close.shift(1), -volume, volume)` is a two-way split with no branch for an unchanged close, so a flat bar adds volume where both references the project itself names - Wikipedia in the class docstring, StockCharts in the test module - leave the running total alone. Reproduced on the library's own `test/data/datas.csv` after the `ta.utils.dropna` call the quickstart prescribes: **85 of 399 bars are flat (21.3 percent)**, the series ends at **1631.93 against 533.44** computed from the cited rule, an error of **205.9 percent of the correct value**, and it is monotone, because every flat bar adds volume that should add nothing. Upstream and unchanged since `a890410`. The fixture never caught it because `test/data/cs-obv.csv` has no flat bar in its 30 rows. Found at iteration 62 of 64.

## Classes closed, not instances patched

Fourteen defect classes were settled class-complete, each with an enumerating check across all 43 indicator classes rather than a patched instance. Among them:

- **Lookahead bias from warm-up values seeded outside the causal window**, closed across TRIX, Ichimoku visual spans, KST, DPO, Vortex and KAMA, with `grep -nE "fill_value=.*mean\(\)|np\.roll"` left empty and all eight outputs pinned under both `fillna` settings by perturbing only the final bar.
- **Non-finite results from a zero denominator**, which **superseded an earlier and wrong settlement of the same class**. That first settlement declined all guards after probing a flat series where numerator and denominator vanish together and 0/0 gives NaN; it never produced the case that matters, a non-zero numerator over zero, which gives `inf`. Two sites did.
- **Indicators assuming a float64 input column**, closed at one boundary in `ta/utils.py` applied at all 85 constructor assignments, verified across six price dtypes and two volume dtypes.
- **Lookback periods accepted without validation**, closed over all 67 period arguments, enumerated by AST per parameter rather than per attribute because `KSTIndicator` stores `roc1` to `roc4` as `_r1` to `_r4`.

Three findings were **declined**, and one is the interesting one. The task asking for the final `_trs`/`_dip`/`_din` slot in ADX to be filled was declined because **the premise was wrong**: those arrays are sized `n - window + 1` while the recurrence can fill only `n - window`, and extending the loop as the task asked raises `KeyError: 120` on a 120-bar series. The loop reproduced the failure before rejecting its own task.

## It broke the library and then caught itself

At iteration 6 of the fourth run, a seeding change the loop had made turned KAMA into a constant under `fillna=True`. `min_periods=0` makes the row-0 rolling sum of an all-NaN window evaluate to `0.0`; the efficiency ratio reads that as a genuine zero market; the recurrence seeds at row 0 while rows 1 to 9 still hold NaN; and `_check_fillna`'s forward fill spreads that single seed across the entire series.

Three of its own green signals passed over it for ten iterations. Coverage was 100 percent, because every line executed. The suite passed, because no test asserted a KAMA value with `fillna=True`. And an earlier sweep built specifically to prove the `fillna` path sound checked every accessor for NaN and infinity, which a constant series has neither of.

The audit at iteration 16 found it and recorded, unprompted, *"It is mine."* The lesson it wrote is now a rule in Jeffy's own Method: an acceptance check has to be strong enough to fail, and a differential assertion beats an absence-of-badness one.

## What it refused to do

The converging audit ran the CI documentation job. Four jobs are defined in `.circleci/config.yml`, and the doc job's command had **never been executed in the project's history**. It exits 0, but emits two warnings: `language = None` at `docs/conf.py:73` is a Sphinx 2 idiom that Sphinx 8 rejects outright, and `html_static_path` names a directory that does not exist.

Both are trivially fixable. The loop fixed neither. `docs/conf.py` was unchanged since the convergence commit, and the ratchet rule says a finding in code unchanged since convergence must be a reproduced in-envelope High or a regression traced to new work. These were neither, so both went to Proposed for the owner to decide, with the one-line fix for each named there. The journal records the reasoning, and why the alternative was tempting: fixing them unasked "would have been the rule bending to convenience."

## Honest caveats

- **The independent evaluator gate did not run.** The converging session carried a standing instruction against spawning sub-agents, so the adversarial review that normally precedes a Converged line was recorded as `Evaluator: unavailable` with its reason, per the documented fallback. Convergence here rests on the machine-checked stop and the verify gate alone. That is a weaker close than the other receipts in this set, and it is the single biggest caveat on this one. The fallback no longer exists: in Jeffy v1.7.0 a run that cannot spawn the evaluator records the reason and ends blocked, and a PASS must be backed by a committed evaluator artifact. This receipt is why that escape was closed, and it is left standing as it converged rather than reclassified.
- **Two Proposed items are open** at convergence: the two Sphinx warnings above, and an `ema_indicator` delegate defaulting `window` to 12 where `EMAIndicator` defaults it to 14, both pre-existing upstream.
- **The run cost 6 hours 41 minutes** across six runs. Anyone told this would take a single run of ten iterations would have quit at run two.
- **Three of the six runs were relaunched inside the session that had just finished a run**, which forfeits the clean context the design assumes. Only the last two used a fresh session. A cleanly sessioned rerun would likely be shorter, and that has not been measured.
- **This run exposed two defects in Jeffy itself**, both fixed in v1.2.1: journal rotation overwrote `JOURNAL-archive.md` instead of appending, destroying 18 entries of this run's own record, and the journal's run-id named the session rather than the run, so six runs stamped identical headings and the record could not separate them. Neither would have surfaced from self-hosting, because both need a run long enough to rotate the journal twice.

## Compared with the single-pass audit

An earlier agent audit of the same target under the same method filed 9 findings, 2 of them High. This loop run filed 47 tasks and settled 14 classes. It independently reached the same conclusions on the audit's headline items - the PSAR indexing corruption, the KST warm-up lookahead, the structurally blind test suite, the committed Coveralls token - and went considerably further, including On-Balance Volume, which the audit never found.

The loop found more than the audit. It also cost 64 iterations against the audit's single pass, and it broke the library once along the way.

**Independently verified**, by the session that wrote this receipt rather than by the loop reporting on itself. `fixes.patch` was applied to a **pristine clone checked out at `a890410`**, where the suite is `Ran 134 tests ... FAILED (errors=2)`; after applying it, the same interpreter gives `Ran 211 tests ... OK`. The OBV finding was reproduced from scratch against the library's own dataset and matches the run's reported figures to the decimal (85 flat bars of 399, 1631.93 against 533.44, 205.9 percent). The PSAR label-write claim was checked against `git show a890410:ta/trend.py`, which carries `self._psar[i] = high2` at line 1030 beside `.iloc[i]` at 1032, and against HEAD, where the label form is gone. The final suite state, `Ran 211 tests ... OK` at exit 0, was re-run directly rather than read out of the journal. The convergence hash `b961193` was confirmed to be a real commit carrying the final `Converged` line, with the ledger empty in Now, Next and Later.

**Convergence standard**: evaluator unavailable, recorded. This run could not spawn the gate and recorded that fact rather than claiming a countersignature; the standard each target met is recorded in [evals/ATTEMPTS.md](../ATTEMPTS.md).

**Status**: the work lives in this eval's `fixes.patch`; nothing was pushed upstream. Findings were not disclosed upstream: the project has been dormant since 2023-11-02 with no GitHub Actions run ever, CircleCI red on HEAD, and no merged pull request in over two years.

**Note for anyone repeating this**: the project's test files are not named `test_*`, so pytest collects nothing and reports "no tests ran". Use `python -m unittest discover -s test -p '*.py'`.
