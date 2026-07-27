# Jeffy run journal: bukosabino/ta

Six /jeffy runs, 64 iterations, three sessions, converged at b961193 on 2026-07-27.
Entries are as the loop wrote them. Eighteen entries from the first three runs were
destroyed by the rotation defect this run exposed; that loss is recorded, not hidden.

# Journal archive

Rotated out of JOURNAL.md when it passed 500 lines. Oldest first; never rewritten.

## iter 10/10 | c6d195f0 | 2026-07-27 | WRAPUP | done

Task: Final iteration of the budget. Tidied BACKLOG.md and wrote the handoff rather than starting a task that could not finish.

Changed: BACKLOG.md (T-024 moved from Next to Later, where its Low severity belongs), JOURNAL.md (this entry).

Checkpoint: ed2f041df7d7f8c73212714d13a7e0fef3a63f0f - stall check: this iteration changed only BACKLOG.md and JOURNAL.md, but a BACKLOG.md item changed state, so this is not a stalled iteration.

Verification: Verify command runs 163 tests OK, against 146 at the start of this run and 134 with 2 errors when the project was first audited. The run is NOT converged and none was claimed: seven items remain, so the Definition of done is unmet, the evaluator gate was not invoked because it belongs only to the convergence path, and no Converged line was appended. Sections now match the Method's placement rule - Now empty, Next holding only the blocked T-007 at Medium, Later holding six Low items. Six of the seven are unblocked and independent, so any order works; T-007 alone waits on a decision.

Closed: nothing this iteration; the ledger change is bookkeeping rather than a task.

Learnings: This run closed nine tasks against the previous run's eight, on smaller items, and the reason is worth recording: every task this run had already been reproduced and scoped by an earlier audit, so no iteration was spent discovering what was wrong. The corollary is that the audit's cost is front-loaded and its value is spread across later runs, which argues for auditing once and then running several short budgets rather than re-auditing.

Next: T-016 heads the remaining work, all Low. T-007 needs a user decision before it can move, and T-024 is a typing project rather than a defect.

## iter 1/10 | c6d195f0 | 2026-07-27 | T-016 | done

Task: T-016 (Low, correctness) - ADX loops `range(1, len(x) - 1)`, leaving the final `_trs`/`_dip`/`_din` slot at 0.0, filed as a value that is dead but wrong.

Changed: BACKLOG.md (T-016 moved from Later to Declined with its evidence), JOURNAL.md (this entry). No source change: the finding was refuted.

Checkpoint: 2da9b5526b925c8f4ae2c355fb5d9bde099b2c3e

Verification: The acceptance asked for the final slot to hold the smoothed value, and that is not achievable. Slot i of the recurrence consumes directional movement at bar `window + i`, so with `_trs` sized `n - window + 1` the last slot would need bar n on a series whose last bar is n-1. Extending the loop exactly as the task asked was tried and raises `KeyError: 120` on a 120-bar series at window 14. The arrays are one longer than the recurrence can fill, and that extra slot is load-bearing rather than accidental: `adx()` concatenates `_trs_initial` with an array of `len(_trs)`, giving 13 + 107 = 120, which is what makes the returned series match its index. Shrinking the arrays to the computable length would return 119 values against a 120-element index. The mutation was reverted, the tree is clean, and the Verify command runs 163 tests OK.

Closed: T-016 (Low, correctness) - declined; the premise was wrong, the slot is padding the length arithmetic requires, and the residual 0.0-versus-NaN concern is already T-007.

Learnings: The audit read `range(1, len(x) - 1)` as an off-by-one because that pattern usually is one. It read the bound without reading what the body indexes, and the bound was compensating for an array deliberately sized one longer than its own recurrence. Before filing a loop-bound finding, check what the body reads at the extreme index; a suspicious bound is sometimes the only thing holding a suspicious size together.

Next: T-017, `_get_min_max` discarding the caller's index.

## iter 2/10 | c6d195f0 | 2026-07-27 | T-017 | done

Task: T-017 (Low, code quality) - `_get_min_max` returned `pd.Series(output)` with a fresh RangeIndex, silently discarding the caller's index.

Changed: ta/utils.py (the helper keeps `series1.index`, the docstring describes series rather than lists, and the ValueError names the real parameter instead of a variable "f" that does not exist), test/unit/utils.py (new TestGetMinMax, four cases), test/__init__.py (registers it), BACKLOG.md (T-017 deleted), JOURNAL.md (this entry).

Checkpoint: 99d283ba15571bee6b86bf91f7d4b85befbed0c0

Verification: The premise was checked before the edit, since the previous iteration's finding turned out to rest on a wrong one. There is exactly one caller, ADXIndicator._run, which invokes the helper twice and immediately reduces the pair to a difference it then resets, so the discarded index never reached anything - the defect was latent, exactly as filed. Equivalence was then measured rather than argued: 36 ADX series captured before and after across three series lengths, both RangeIndex and DatetimeIndex inputs, both fillna settings and all three outputs, every one identical. The helper now returns a DatetimeIndex unchanged when given one. Verify command: 167 tests OK, up from 163. The CI lint gate was also re-run because this run made it real: isort and both prospector invocations still exit 0.

Closed: T-017 (Low, code quality) - `_get_min_max` carries the caller's index; ADX output identical over 36 captured series.

Learnings: The helper had no test of its own, which is why the index loss survived; the four new cases pin both orderings, NaN propagation and the rejection of an unknown function name. Its error message referred to a variable "f" that no longer exists in the signature, a rename that never reached the string it was describing - the kind of drift only a test that asserts on the message catches.

Next: T-018, the redundant index argument in bollinger_hband_indicator.

## iter 3/10 | c6d195f0 | 2026-07-27 | T-018 | done

Task: T-018 (Low, code quality) - `bollinger_hband_indicator` passed `index=self._close.index` to a Series that already carried it, unlike its lband sibling.

Changed: ta/volatility.py and ta/trend.py (three redundant `index=` arguments removed), BACKLOG.md (T-018 deleted, the class recorded under Settled classes), JOURNAL.md (this entry).

Checkpoint: b5a235a2691e979c045f7366239784be02637d71

Verification: The task named one site; enumerating `return pd.Series(.*index=)` across ta/ found five, of which three are the same defect - bollinger_hband_indicator plus both PSAR indicators, each re-wrapping a Series that already carries the close index. That is the three-strike threshold, so the class was closed rather than the single instance. The remaining two sites keep the argument because they genuinely need it: one constructs from the scalar np.nan, the other from an ndarray. Redundancy was confirmed before editing, by checking that the inner Series index already equals the close index in both the Bollinger and PSAR paths. Equivalence was then measured across 32 captured series - two lengths, RangeIndex and DatetimeIndex, both fillna settings, all four affected outputs - comparing values, series name and index labels, and nothing changed. Verify command: 167 tests OK; prospector on ta/ still exits 0.

Closed: T-018 (Low, code quality) - redundant index arguments removed at all three sites; output, name and index identical over 32 series.

Learnings: `pd.Series(existing, index=idx)` reindexes rather than relabels, so it is a no-op only while the two indexes agree; it would silently drop rows if they ever diverged. That makes the redundant form worth removing rather than tolerating, even though no current call can hit the divergent case.

Next: T-019, the stale MANIFEST left behind by distutils.

## iter 4/10 | c6d195f0 | 2026-07-27 | T-019 | done

Task: T-019 (Low, dependency hygiene) - MANIFEST was a distutils-generated artifact checked into the repo, listing files including a setup.py that no longer exists.

Changed: MANIFEST (deleted), BACKLOG.md (T-019 deleted), JOURNAL.md (this entry).

Checkpoint: 1eeb2776275c837069aa41273f54d61e3029454b

Verification: An sdist was built before the deletion and again after, and the two are identical - 20 entries each, nothing added or removed, all eight ta/ modules present along with LICENSE, README.md and pyproject.toml. The comparison also settled what the file was doing: MANIFEST does not appear in either sdist, so it was never shipped and modern setuptools ignores it entirely. It was a stale output file, not an input. The resulting sdist was then installed into a clean venv and `import ta, ta.trend` succeeds. Verify command: 167 tests OK; both prospector invocations exit 0.

Closed: T-019 (Low, dependency hygiene) - MANIFEST deleted; sdist contents byte-for-byte the same set, and the built sdist installs and imports.

Learnings: MANIFEST and MANIFEST.in are easy to confuse and behave oppositely - the .in file is an input that adds files to a distribution, while the bare MANIFEST is an output distutils wrote to record what it had packaged. No replacement was needed because nothing was ever reading it; the acceptance offered a MANIFEST.in as an alternative, and building the sdist showed that adding one would have been cargo cult rather than a fix.

Next: T-020, Aroon resolving ties to the earliest bar rather than the most recent.

## iter 5/10 | c6d195f0 | 2026-07-27 | T-020 | done

Task: T-020 (filed Low, corrected to Medium, correctness) - Aroon used np.argmax and np.argmin, which resolve ties to the earliest bar, so an extreme matched again today was reported as days old.

Changed: ta/trend.py (a helper locates the extreme in the reversed window, so ties resolve to the most recent bar), test/unit/definitions.py (two tests, one for a tie at the final bar and one for an extreme that ages normally), BACKLOG.md (T-020 deleted), JOURNAL.md (this entry).

Checkpoint: 94dad7b1b258b4666baf19a95044a54eec66014e

Verification: Reproduced first on a 7-bar series whose final bar equals the window high and whose final low equals the window low: both readings were 80.0 where the definition gives 100.0, because np.argmax returned the earlier of the two tied positions. After the fix both are 100.0, an extreme that is not matched again still ages to 0.0 across a 5-day window, and aroon_indicator still equals up minus down. Verify command: 169 tests OK, up from 167; both prospector invocations exit 0.

Behaviour change, measured rather than asserted, as the Constraints require. On 19975 rows of the shipped BTC OHLCV data at window 25, the tie rule changes aroon_up on 4255 rows, 21.30 per cent, with a maximum change of 100 percentage points, and the new value is never lower than the old. That is not the size of a regression, it is the size of the defect: ties are common in real price data at round numbers and through flat stretches, and the old rule reported the extreme as older than it was every time one occurred. The conventional definition, that Aroon Up is 100 when the period high is today, is what both StockCharts and Investopedia state.

The severity was also wrong and is corrected here. This was filed Low as a tie-breaking nicety on the strength of reading the code; measuring it on real data shows it altering a fifth of all readings, which is Medium by the rubric - a plausible in-envelope case producing wrong output.

Closed: T-020 (Medium, correctness) - Aroon ties resolve to the most recent bar; reproduced at 80.0 before and 100.0 after.

Learnings: Severity assigned from reading code underrates anything whose frequency depends on the data. The defect looked like an edge case because exact ties look rare in the abstract, and floating-point OHLCV from a real exchange turns out to tie on a fifth of windows. When a finding's impact scales with how often some condition holds, measure the condition on real data before scoring it.

Next: T-024 is the only unblocked item left, a typing project rather than a defect; after it the backlog holds nothing but the blocked T-007.

## iter 6/10 | c6d195f0 | 2026-07-27 | T-024 | done

Task: T-024 (Low, code quality) - the library carried no type annotations, which is why prospector's veryhigh strictness produced over a thousand mypy messages and why the profile sits at medium.

Changed: all eight ta/*.py modules (annotations throughout, three explicit float conversions, one Callable import each in trend.py and volatility.py), BACKLOG.md (T-024 replaced by T-026 for the remaining half), JOURNAL.md (this entry).

Checkpoint: 2d165613d082604008ebd1bb986f0994b4acf854

Verification: ta/ went from 195 messages at veryhigh to 0, with `prospector --no-autodetect ta/` exiting 0 and all eight tools still running. The Verify command runs 169 tests OK at every step, so none of the 548 changed lines altered behaviour. isort, black --check and prospector at the committed medium profile all exit 0.

The task was too large for one iteration and was split rather than half-finished. Annotating ta/ is the valuable, self-contained half; making test/ pass mypy's strict mode is 996 further messages, 471 of them attr-defined from attributes assigned in setUpClass, and annotating 525 test methods is activity rather than impact. That half is now T-026, which also carries the strictness raise, so the profile stays at medium and this iteration claims no more than it delivered.

Two mistakes were made and caught. The first automated pass located the return-annotation insertion point with `rfind(":")` over everything preceding the function body, which found the colon inside a comment and wrote `# Note -> None: window-size ...` into ta/trend.py; the whole pass was reverted with `git checkout -- ta/` rather than patched, and rewritten to locate the header colon with tokenize at paren-depth zero. The second was subtler and survived into the second pass: the return-type heuristic treated `.sum()` and `np.mean()` as Series-producing, so `_weighted_average` and `_mad` were annotated `-> pd.Series` when they return scalars. An audit of every nested annotation caught both, and they are now `-> float`.

Closed: T-024 (Low, code quality) - ta/*.py fully annotated; veryhigh on ta/ goes 195 to 0 with the suite green throughout.

Learnings: A mechanical edit across 548 lines needs a mechanical check afterwards, not a reading. The test suite proved behaviour was intact but could not have caught a mangled comment, and mypy could not have caught a wrong-but-plausible annotation on a function whose callers are untyped; enumerating every annotation the pass produced and reading them back is what found the two errors. Also, black is not optional after such a pass: adding annotations to parameters that carry defaults produced 418 E252 violations, which the project's own formatter cleared in one run.

Next: the backlog now holds only T-026 and the blocked T-007, so the next iteration is close to the point where a fresh audit is due.

## iter 7/10 | c6d195f0 | 2026-07-27 | T-026 | done

Task: T-026 (Low, code quality) - ta/ was annotated and clean at veryhigh but test/ still reported 996 mypy messages, so .prospector.yaml stayed pinned at medium.

Changed: pyproject.toml ([tool.mypy] with a test.* override), 6 test modules (98 class-attribute declarations, dict and tuple types parameterised), .prospector.yaml (strictness raised to veryhigh, stale comment replaced), BACKLOG.md (T-026 closed, the class recorded under Settled classes), JOURNAL.md (this entry).

Checkpoint: ae26f7c02aedaeba5aa551172c8752b3c2babb01

Verification: Acceptance met in full. `prospector --no-autodetect ta/` and `prospector --no-autodetect test/` both exit 0 with 0 messages and all eight tools running - bandit, dodgy, mccabe, mypy, profile-validator, pycodestyle, pyflakes, pylint - with .prospector.yaml now committed at veryhigh. The Verify command runs 169 tests OK, and isort and black --check both exit 0. The count came down in measured stages: 996 to 471 once mypy's two disallow-untyped rules were scoped away from the test tree, 471 to 34 once the attributes setUpClass assigns were declared on their classes, 34 to 2 once the params dicts were parameterised, and 2 to 0 once the two tuple attributes were.

The task offered a choice, annotate the test tree or scope the strict rules to the library, and the answer turned out to be both in different proportions. Only the two disallow-untyped rules are relaxed for test.*, because a test method's signature is not a contract anyone consumes; every other mypy check still applies there, which is what kept the 471 attr-defined messages in play. Those were worth fixing rather than suppressing: they were mypy correctly observing that `cls._df`, `cls._params` and `cls._indicator` are assigned in setUpClass but declared nowhere, and each class now says what its fixture produces.

Closed: T-026 (Low, code quality) - strictness raised to veryhigh with both trees exiting 0; typing class recorded as settled.

Learnings: Reaching for the config switch first would have hidden a real readability gap. Scoping the disallow-untyped rules was legitimate and took 996 to 471, but the remaining 471 were a genuine signal, and disabling attr-defined as well would have been the difference between scoping a rule that does not apply and silencing one that does.

Next: only the blocked T-007 remains, so the next iteration has no unblocked task and a fresh audit is due.

## iter 8/10 | c6d195f0 | 2026-07-27 | AUDIT | audit

Task: BACKLOG.md held no unblocked task, so a full Improvement-mode audit was run against the Method and Operating envelope, with fresh evidence.

Changed: BACKLOG.md (T-027, T-028 and T-029 filed), JOURNAL.md (this entry).

Checkpoint: d53d8511de2fb00837f105a7bc329fb89ee86d4d

Verification: The audit probed in-envelope shapes rather than re-reading settled code. Across an 80-bar frame it exercised normal data, negative prices, a flat market, all-zero volume, a single zero-volume bar, a mid-series NaN gap, and one- and two-row frames, at both fillna settings, plus a DatetimeIndex through the whole wrapper. Verify command: 169 tests OK. Coverage, measured with the project's own .coveragerc: 97 per cent of 1387 statements. prospector at veryhigh exits 0 on both trees with all eight tools running, so bandit and dodgy are clean.

Dimension scores: correctness High - T-027, `volume_em` returns inf at a zero-volume bar, the only one of 91 columns that ever does, reproduced at 1 inf for a single such bar and 79 for an all-zero volume series; testing Medium - T-028, seven of 86 public functions are called by no test, and five of them are the per-category wrappers exported in ta/__init__.py; dependency hygiene Low - T-029, coverage and coveralls still pinned at 2019 releases that do install and run. error handling None, since short, gapped, flat, negative and one-row inputs all came back clean. security None in-tree, bandit clean and no adversarial surface; the credential rotation remains the maintainer's and is tracked under Proposed. code quality None and architecture None, prospector veryhigh reporting zero. documentation None - the docs build, the version derives from package metadata, the README's count of 43 still matches the code, and nothing references setup.py, MANIFEST or .coveralls.yml. developer experience None, since every command in the Makefile lint and test targets now exits 0. performance skipped, no measurement was taken and the recursive loops are already Declined. observability skipped, a pure numerical library with no process or I/O. UX and accessibility skipped, no user-facing surface.

One candidate was refuted before filing rather than after. A single NaN close appeared to destroy trend_kst, trend_kst_sig, trend_kst_diff and trend_stc entirely, but that was the 60-bar probe being too short for KST to recover: at 200 and 400 bars the same NaN leaves 135 of 200 and 335 of 400 values intact, which is ordinary warm-up plus rolling propagation. T-027 was also checked against the settled divide-by-zero class before filing and is outside it: that class covers band ratios where 0/0 gives NaN, whereas this is a non-zero numerator over zero giving inf, Ease of Movement was never among its sites, and T-006 changed whether zero-volume rows reach the indicator at all.

Learnings: The audit found a regression this run introduced. Making dropna keep zero-volume bars was correct on its own terms, and it moved a class of input from "discarded before it reached any indicator" to "flows through all of them", which is exactly where Ease of Movement divides by volume. A change that widens what reaches downstream code needs the downstream code re-probed against the newly admitted inputs, not just the changed function tested.

Next: T-027, the inf that a zero-volume bar produces in volume_em.

## iter 9/10 | c6d195f0 | 2026-07-27 | T-027 | done

Task: T-027 (High, correctness) - a zero-volume bar made `volume_em` infinite, because EaseOfMovementIndicator divides by that bar's own volume and dropna stopped discarding such bars under T-006.

Changed: ta/volume.py (EoM drops a zero denominator), ta/volatility.py (keltner_channel_pband guarded as Bollinger already was), test/unit/volume.py (zero-volume EoM test), test/integration/wrapper.py (no-column-is-infinite invariant at both fillna settings), BACKLOG.md (T-027 closed, the divide-by-zero settled class corrected), JOURNAL.md (this entry).

Checkpoint: b1795b02f230dbef6efc9901a572ebbb89c37869

Verification: On 3000 rows of the shipped BTC data with a zero-volume bar injected, no column of the 91 is infinite at either fillna setting; before the fix `volume_em` was inf at that bar and `volatility_kcp` at two others. Verify command: 171 tests OK, up from 169. Both prospector invocations still exit 0 at veryhigh.

The second site was found by the new test, not by the audit that filed the task. The wrapper invariant was written to cover EoM, ran against real data rather than the synthetic 80-bar probe, and immediately failed on volatility_kcp. That exposed an error in this run's own Settled classes entry: divide-by-zero in the band ratios had been declined after probing a flat series where numerator and denominator vanish together, so every case it produced was 0/0, which pandas resolves to NaN. The case that matters is a non-zero numerator over zero. Keltner is the one band that can reach it, because its width is 2 * SMA(high - low), zero across a run of flat bars, while its centre is an SMA of (2*low + close)/3 that the close need not sit on; measured on real data the width was 0.0 while close minus the centre was 0.531. Donchian, Bollinger, Stochastic and Williams %R were re-probed on the same 3000 rows and produce no inf, because their numerators do vanish with their denominators. The settled entry has been rewritten to say all of this rather than left to mislead a later audit.

Closed: T-027 (High, correctness) - both zero-denominator sites guarded; no infinite column on 3000 real rows at either fillna setting.

Learnings: A settled class is only as good as the input that settled it, and a synthetic flat series is the worst possible probe for a divide-by-zero class because it makes numerator and denominator vanish together and hides the one case that produces inf. Probing real data would have caught it at settlement time. Correcting a wrong settled entry matters more than the fix, since the entry's purpose is to stop future audits looking there.

Next: iteration 10 is the final one, so it takes a WRAPUP entry and the handoff.

## iter 10/10 | c6d195f0 | 2026-07-27 | ROTATION | rotation

Task: JOURNAL.md reached 504 lines, past the 500-line threshold, so the older entries were moved out.

Changed: JOURNAL.md (20 oldest entries removed, 10 kept), JOURNAL-archive.md (new, holding those 20).

Checkpoint: 37d0ab9264379469191838c1cdea26857d6ba573

Verification: 30 entries before the rotation, 20 archived and 10 retained; JOURNAL.md is now 178 lines and JOURNAL-archive.md is 330. The retained window starts at the WRAPUP of the previous run, so the whole of this run remains in JOURNAL.md. No entry text was edited in either file.

Learnings: none; this is bookkeeping the loop prescribes.

Next: the WRAPUP entry for this iteration.

## iter 10/10 | c6d195f0 | 2026-07-27 | WRAPUP | done

Task: Final iteration of the budget. Confirmed the ledger, ran every gate, and wrote the handoff rather than starting a task that could not finish.

Changed: JOURNAL.md (this entry and the ROTATION entry above), JOURNAL-archive.md (created by the rotation).

Checkpoint: 37d0ab9264379469191838c1cdea26857d6ba573 - stall check: this iteration changed only JOURNAL.md and the new JOURNAL-archive.md, and no BACKLOG.md item changed state, so it made no task progress; that is the expected shape of a wrapup and the previous primary entry closed T-027, so it is not a second consecutive no-progress iteration.

Verification: Verify command runs 171 tests OK, against 169 at the start of this run and 134 with 2 errors when the project was first audited. isort, black --check and both prospector invocations at veryhigh all exit 0. The run is NOT converged and none was claimed: three items remain, so the Definition of done is unmet, the evaluator gate was not invoked because it belongs only to the convergence path, and no Converged line was appended. BACKLOG.md needed no tidying - Now is empty because no High is open, Next holds T-028 with the blocked T-007 last, and Later holds T-029, which is the placement the Method prescribes.

Closed: nothing this iteration; the rotation and this entry are bookkeeping.

Learnings: This run inverted the usual ratio, spending five of nine working iterations on Low items and still surfacing a High. T-020 was filed Low and measured Medium, T-016's premise was refuted outright, and the T-027 fix exposed a wrong entry in this run's own Settled classes. The pattern across three runs is consistent: the cheapest way to be wrong is to score or settle a finding from reading rather than from running it against real data.

Next: T-028 heads the remaining work. T-007 needs a user decision, and the Coveralls token still needs rotating by the maintainer.

## iter 1/20 | c6d195f0 | 2026-07-27 | T-028 | done

Task: T-028 (Medium, testing) - the five per-category wrappers exported in ta.__all__ were reached by no test, along with two StochRSI delegates; only add_all_ta_features was exercised.

Changed: test/integration/wrapper.py (four tests covering the five wrappers, their partition of add_all_ta_features, the vectorized flag and colprefix), test/unit/momentum.py (stochrsi_k and stochrsi_d against the class), test/unit/definitions.py (awesome_oscillator against its class), BACKLOG.md (T-028 closed, T-029 strengthened), JOURNAL.md (this entry).

Checkpoint: f444ed57d84000ad92f0488e0ffca6b90d1226b3

Verification: Eight module-level functions are now called from tests, the seven the task named plus awesome_oscillator, which coverage exposed and the task's own scan had missed. Verify command: 177 tests OK, up from 171; isort, black and both prospector invocations at veryhigh all exit 0. The strongest of the new assertions is that the five wrappers partition add_all_ta_features exactly - 10 volume, 21 volatility, 34 trend, 18 momentum and 3 others columns, whose union equals the 86 features the combined call produces - so a wrapper that silently stops emitting a column now fails a test.

The acceptance also asked that `coverage report -m` show no uncovered line in ta/wrapper.py, and evaluating that clause turned into its own investigation. The pinned coverage 4.5.4 reported one missed statement in wrapper.py while its own `coverage annotate` marked nothing missing in that file, and the same contradiction appeared in momentum.py, utils.py, volatility.py and __init__.py. coverage 7.15.2, run over the identical suite, scores all five at 100 per cent. The acceptance holds; the pinned tool was miscounting. That evidence has been folded into T-029, which now records a tool that reports wrong numbers rather than merely an old pin.

Closed: T-028 (Medium, testing) - eight previously untested public functions covered; ta/wrapper.py at 100 per cent under a coverage that can measure Python 3.13.

Learnings: A coverage number is a measurement, and a measuring tool six major versions behind the interpreter can be wrong in the direction that hides work rather than invents it. When a tool contradicts itself, as report and annotate did here, believe neither until a second implementation adjudicates. The same run that used coverage to find an untested function then had to check coverage itself.

Next: T-029, replacing the coverage and coveralls pins, which the evidence above now makes a correctness matter for the measurement rather than housekeeping.

## iter 2/20 | c6d195f0 | 2026-07-27 | T-029 | done

Task: T-029 (Low, dependency hygiene) - requirements-coverage.txt pinned coverage==4.5.4 and coveralls==1.8.2 from 2019, and the coverage pin miscounted on Python 3.13 rather than merely being old.

Changed: requirements-coverage.txt (coverage>=7.6, coveralls>=4.0, with the reason recorded in the file), BACKLOG.md (T-029 closed), JOURNAL.md (this entry).

Checkpoint: af6627b5867b998819b455efa84abe59a6be2203

Verification: Installed as CI would, from requirements-coverage.txt into a clean Python 3.13 venv: coverage 7.15.2 and coveralls 4.1.0, exit 0. `coverage run -m unittest discover` then `coverage report -m` both succeed, reporting 98 per cent of 1380 statements, and the five files the old pin claimed a phantom miss in - wrapper.py, momentum.py, utils.py, volatility.py and __init__.py - now read 100 per cent. requirements.txt, the union that `make init` installs, still resolves. Verify command: 177 tests OK; both prospector invocations exit 0.

The third acceptance clause, that the reported misses agree with `coverage annotate`, needed its comparison defined before it could be judged. A naive set equality fails on a working tool, because annotate marks every physical line of a multi-line statement while the report lists only the line the statement starts on; trend.py reports 16 misses against 80 marks for that reason alone. The property that actually distinguishes a sound tool is that every reported miss is marked, and that holds for all eight files. The only two marks not explained as continuations are ta/trend.py:829 and :855, both `else:` headers whose bodies at 830 and 856 are themselves reported, so annotate is marking the unexecuted branch keyword. Under the old pin the same property failed outright: a miss reported in wrapper.py was marked nowhere.

Closed: T-029 (Low, dependency hygiene) - coverage and coveralls raised to supported releases; report and annotate now agree, and the phantom misses are gone.

Learnings: An acceptance that compares two tool outputs has to say what agreement means, or it fails on a correct implementation. This one was written from the shape of the bug - annotate marking nothing where report claimed a miss - and reading it as strict set equality would have rejected the fix. The clause held once stated as a subset property, which is what the bug actually violated.

Next: no unblocked task remains and only the blocked T-007 is open, so the next iteration is due a fresh audit; with the Definition of done otherwise close, convergence is now in reach.

## iter 3/20 | c6d195f0 | 2026-07-27 | AUDIT | audit

Task: BACKLOG.md held no unblocked task, so a full Improvement-mode audit was run against the Method and Operating envelope with fresh evidence.

Changed: BACKLOG.md (T-030 and T-031 filed), JOURNAL.md (this entry).

Checkpoint: f270f31b17b37e5560c077dd3a078dc65862b2eb

Verification: This audit deliberately probed the API surface rather than indicator arithmetic, since the arithmetic has been probed three times and the surface never had been. It exercised dtype variation across the price and volume columns, caller-frame mutation, descending time order, colprefix collision, and re-application of the wrapper to its own output. Verify command: 177 tests OK; both prospector invocations exit 0 at veryhigh; coverage 98 per cent under coverage 7.15.2.

Dimension scores: error handling High - T-030, PSARIndicator copies the close column and inherits its dtype, so integer prices raise TypeError on the first float assignment and pandas nullable dtypes raise on an ambiguous NA comparison, reproduced at int64, int32, Int64 and Float64 against float64 and float32 passing, and either takes the whole wrapper down. documentation Medium - T-031, the wrappers mutate the caller's frame and return the same object, turning a 5-column input into a 91-column one, which no docstring mentions. correctness None, since descending order, re-application and integer volume all behave. testing None, at 98 per cent with the entry points now covered. security None, bandit clean and no adversarial surface. dependency hygiene None, every pin now current and installable. code quality and architecture None, prospector veryhigh reporting zero. developer experience None, every Makefile command exits 0. performance skipped, no measurement taken and the recursive loops are Declined. observability and UX skipped as before.

The colprefix collision was examined and not filed: writing a column name that already exists overwrites it, which is ordinary DataFrame assignment rather than a defect, and no documented behaviour promises otherwise.

Learnings: Three prior audits scored this project on indicator arithmetic and found the surface clean; the first audit to vary the input dtype found a crash on the first try. An envelope that says "real feed output is the contract" covers how the data is represented as much as what it contains, and integer ticks or cents are as ordinary as zero-volume bars. Convergence was in reach at the start of this iteration and is not now, which is the audit doing its job rather than a setback.

Next: T-030, the dtype crash in PSAR.

## iter 4/20 | c6d195f0 | 2026-07-27 | T-030 | done

Task: T-030 (High, error handling) - integer price columns raised TypeError on a float assignment and pandas nullable dtypes raised on an ambiguous NA comparison, either of which took add_all_ta_features down.

Changed: ta/utils.py (`_to_float` helper), all five indicator modules (85 constructor assignments across 43 classes now coerce, one import line each), test/integration/wrapper.py (dtype test over six dtypes), BACKLOG.md (T-030 closed, the class recorded under Settled classes), JOURNAL.md (this entry).

Checkpoint: f3fe26a9af1bd97ff161fdc84dd10559880cddec

Verification: add_all_ta_features returns 91 columns for price columns of dtype float64, float32, int64, int32, Int64 and Float64, and for volume of int64 and Int64, against int64, int32, Int64 and Float64 all raising before. Verify command: 178 tests OK, up from 177; both prospector invocations report 0 messages at veryhigh; isort and black clean.

The first attempt fixed the wrong scope and was reverted. Coercing high, low and close inside PSARIndicator._run cleared the integer cases but not the nullable ones, because the next failure was in OnBalanceVolumeIndicator, where `np.where` meets a nullable boolean mask holding pd.NA. Two sites in different modules sharing one root cause is what the envelope's binding rules address: the remedy for input robustness is one validation boundary where the input enters, never scattered per-site guards. The PSAR edit was reverted with `git checkout -- ta/trend.py` and replaced by `_to_float` applied at every constructor, which an AST pass found to be exactly 85 assignments in four shapes across 43 classes.

Closed: T-030 (High, error handling) - dtype coercion centralised in `_to_float`; six price dtypes and two volume dtypes all yield 91 columns.

Learnings: A crash traced to one indicator is evidence about that indicator, not about the class. Fixing PSAR and re-running found the second site immediately, and had the acceptance named only integer prices the fix would have shipped with the nullable case still broken. Write the acceptance to enumerate the input space, not the site that happened to fail first.

Next: T-031, the wrappers mutating the caller's DataFrame without saying so.

## iter 5/20 | c6d195f0 | 2026-07-27 | T-031 | done

Task: T-031 (Medium, documentation) - the six wrappers added their columns to the caller's DataFrame and returned that same object, turning a 5-column input into a 91-column one, which no docstring mentioned.

Changed: ta/wrapper.py (each of the six copies its input, and the shared docstring line now states the frame is not modified), test/integration/wrapper.py (test pinning the contract for all six), BACKLOG.md (T-031 closed), JOURNAL.md (this entry).

Checkpoint: 9c76506a9b302b2eb307219340a55569ab082ce8

Verification: All six wrappers leave the caller's frame at its original 8 columns and return a different object, checked individually. Output values are unchanged: 93 float columns compared tail-to-tail before and after the change, none differ. Verify command: 179 tests OK, up from 178; both prospector invocations report 0 messages at veryhigh; isort and black clean. This is a public behaviour change, recorded here as the Constraints require - code that called a wrapper for its side effect and ignored the return value will now see nothing happen, though the README's documented `df = add_all_ta_features(df, ...)` form is unaffected.

The acceptance allowed either documenting the mutation or copying, and the choice was measured rather than argued. Copying costs about 44 ms against a 1.83 second call on a 20000-row frame, roughly 2.4 per cent, because the chain copies only the columns present at each step while the call allocates 86 new ones regardless. At that price the surprising contract is not worth keeping: a function that returns a DataFrame should not also mutate its argument.

Learnings: My first measurement of that cost reported a negative percentage, because the loop reassigned the same variable the baseline was held in. The absolute numbers were sound and the ratio was nonsense; reporting the milliseconds and recomputing by hand was what made the decision, and a derived statistic that comes out impossible is a signal to distrust the derivation rather than the measurement.

Next: no unblocked task remains, so the next iteration is due a fresh audit, which is also what decides whether this run can converge.
## iter 6/20 | c6d195f0 | 2026-07-27 | AUDIT | audit

Task: BACKLOG.md held no unblocked task, so a full Improvement-mode audit was run against the Method and Operating envelope with fresh evidence. This audit also decided whether the run could converge.

Changed: BACKLOG.md (T-032 filed), JOURNAL.md (this entry).

Checkpoint: 3f779a9b5ba6502d186290c1158deca576d57b39

Verification: Having found a High last time by varying dtype, this audit went after index shapes, magnitude, and invocation patterns, none of which had been exercised. add_all_ta_features returns 91 columns with the index preserved for a RangeIndex, a DatetimeIndex, a timezone-aware DatetimeIndex, a non-monotonic index, a string index, a MultiIndex and a float index; it tolerates an unrelated object column and integer column labels; and indicator instances are repeatable, with psar_up and bollinger_pband returning equal series on a second call. Prices were swept across 23 orders of magnitude, from 1e-8 to 1e15, with no infinity and no all-NaN column at any scale. Verify command: 179 tests OK; both prospector invocations report 0 messages at veryhigh; coverage 98 per cent of 1390 statements under coverage 7.15.2.

Dimension scores: testing Medium - T-032, 17 module-level delegates are documented public API with no test, and three further paths are unexercised, namely VolumePriceTrendIndicator's dropnans option, ADXIndicator's window=0 ValueError and the flat-market else branches in adx_pos and adx_neg. Everything else None. correctness, since every index shape, magnitude and repeat call behaved; error handling, since the dtype boundary now absorbs integer and nullable columns; security, bandit clean with no adversarial surface; dependency hygiene, every pin current; code quality and architecture, prospector veryhigh at zero; documentation, the wrapper contract now stated and the docs building; developer experience, every Makefile command exiting 0. performance skipped, no measurement taken beyond the copy cost recorded under T-031. observability and UX skipped as before.

The three unexercised option paths were run by hand rather than merely counted, because untested code is where defects hide and a coverage number says nothing about behaviour. All three are correct: dropnans=True returns 59 values for a 60-bar input with a shortened index, which is what its docstring promises and which pandas realigns on assignment; smoothing_factor=5 first reports at row 5; and window=0 raises ValueError as intended. They are filed as a testing gap, not a correctness one.

Learnings: This is the second consecutive audit to defer convergence, and both were right to. The temptation at this point is to score the remaining gap Low so the run can close; the rubric puts missing tests on a path whose failure would matter at Medium, and 17 documented public functions with no coverage is that, on the same reading that made T-028 a Medium two iterations ago. Consistency in severity across a run matters more than reaching a tidy ending.

Next: T-032, pinning the delegates and the three option paths.

## iter 7/20 | c6d195f0 | 2026-07-27 | T-032 | done

Task: T-032 (Medium, testing) - module-level delegate functions were documented public API with no test, alongside three unexercised option and error paths.

Changed: test/unit/delegates.py (new, TestModuleDelegates and TestUnexercisedOptions), test/__init__.py (registers both), BACKLOG.md (T-032 closed), JOURNAL.md (this entry).

Checkpoint: 9936eff17c05d4f53d11f6a6d5a03286f0b4b498

Verification: ta/ now reports 100 per cent coverage under coverage 7.15.2 - 1390 statements, 106 branches, zero missed and zero partial - against 98 per cent with 22 missed statements before. Verify command: 184 tests OK, up from 179; isort, black and both prospector invocations at veryhigh all exit 0. Each delegate is asserted equal, with assert_series_equal rather than a value spot-check, to the class method it wraps, so a wrong keyword or a swapped accessor in any three-line pass-through now fails. The three previously unreachable paths have tests: VolumePriceTrendIndicator's dropnans option returns 119 values for a 120-bar input with no NaN, its smoothing_factor delays the first value to row 5, ADXIndicator raises ValueError for window=0, and a flat market drives adx_pos and adx_neg through the branch that avoids dividing by a zero true range.

The audit's count was one short: it said 17 delegates and there are 18, the miscount being in trend.py. The test asserts the pair count explicitly so the number cannot drift again unnoticed.

Closed: T-032 (Medium, testing) - 18 delegates and three option paths pinned; ta/ at 100 per cent statement and branch coverage.

Learnings: Branch coverage was the part worth chasing. Statement coverage reached 100 per cent while BrPart still showed partial branches, and the flat-market case that closed them is a genuine market condition rather than a contrivance, so the test earns its place beyond the coverage number. A coverage target met by exercising real conditions is worth having; one met by contriving inputs to touch lines is not.

Next: no unblocked task remains, so the next iteration audits again, and that audit decides convergence.

## iter 8/20 | c6d195f0 | 2026-07-27 | AUDIT | audit

Task: BACKLOG.md held no unblocked task, so a full Improvement-mode audit was run against the Method and Operating envelope with fresh evidence.

Changed: BACKLOG.md (T-033 and T-034 filed), JOURNAL.md (this entry).

Checkpoint: b91a02d037c2d7ff84ff7aa973f89e6fb4c7c80c

Verification: Arithmetic, lookahead, dtypes, index shapes and magnitudes have each been probed in earlier audits, so this one went after documented contracts, which had never been checked against behaviour. Two systematic sweeps were run over every indicator class discovered by reflection. The first instantiated each with fillna=True and called every public accessor, checking for NaN or infinity: zero violations, so that contract holds throughout. The second compared each class docstring's promised fill value against the value its code passes to _check_fillna, and found one disagreement. Verify command: 184 tests OK; both prospector invocations report 0 messages at veryhigh; coverage 100 per cent of 1390 statements and 106 branches under coverage 7.15.2.

Dimension scores: documentation Medium - T-033, AwesomeOscillatorIndicator and its module function both promise a fill of -50 while the code fills with 0, confirmed by calling it. code quality Low - T-034, SMAIndicator alone among 43 classes requires its window, undocumented and at odds with both EMAIndicator and its own delegate. Everything else None. correctness, error handling, testing, security, dependency hygiene, architecture and developer experience all held under the checks above and the gates. performance skipped, no measurement beyond the copy cost under T-031. observability and UX skipped as before.

The -50 has a traceable origin rather than being arbitrary: Williams %R runs from 0 to -100, so -50 is its midpoint and its own docstring is correct, while Awesome Oscillator oscillates about zero and its code is correct. The documentation was copied between neighbours, which is why the wrong number reads plausibly.

Learnings: A docstring is a claim about behaviour and can be tested like any other. Comparing every fillna promise against the value the code passes took one reflective sweep and found a defect that four previous audits, all reading code rather than cross-checking documentation against it, had walked past. Where documentation states a specific value, that is a checkable assertion, not prose.

Next: T-033, correcting the two docstrings and pinning the fill values by test.

## iter 9/20 | c6d195f0 | 2026-07-27 | T-033 | done

Task: T-033 (Medium, documentation) - AwesomeOscillatorIndicator's class docstring and the awesome_oscillator delegate both promised a fill of -50 while the code fills 0.

Changed: ta/momentum.py (both Awesome Oscillator docstrings now state 0), test/unit/documentation.py (new, TestDocumentedFillValues), test/__init__.py (registers it), BACKLOG.md (T-033 closed, T-035 filed), PLAN.md (two Lessons), JOURNAL.md (this entry).

Checkpoint: 5ec5000cbbf27c39690852ea5385fe38318051c9

Verification: Verify command 187 tests OK, up from 184; both prospector invocations 0 messages at veryhigh; black and isort clean; coverage still 100 per cent of 1390 statements and 106 branches. The fix is two docstring lines, and the diff against ta/ is exactly 2 insertions and 2 deletions. Sensitivity was checked rather than assumed: restoring -50 in the class docstring fails 2 of the 3 new tests, the constant check and the delegate-consistency check, and the failure names the two values.

The backlog line located the delegate docstring at ta/momentum.py:990. That line is williams_r, whose -50 is correct; the Awesome Oscillator delegate is at :1037. Both Awesome Oscillator sites, :443 and :1037, were the ones changed, and the four remaining named fill values in the tree are now 50 for Ultimate Oscillator at :151 and :854, -50 for Williams %R at :515 and :990, 0 for Awesome Oscillator, and 1000 for Negative Volume Index at ta/volume.py:323 and :732.

The audit's finding was confirmed by forcing the fill to engage instead of reading the constant: with the opening bars blank, Awesome Oscillator returns 0 there and Ultimate Oscillator and Williams %R return the values they document. Two things emerged that shaped the test. First, on complete data the fill never engages for any of the four, because fillna=True sets min_periods=0 and a rolling sum over an all-NaN window returns 0.0 rather than NaN, so Ultimate Oscillator's warm-up row is a computed zero and its documented 50 is untouched; that is not a defect, since its constant does match its claim. Second, Williams %R returns exactly -50 at row 0 on the synthetic bars used throughout this run, purely because high is close plus 1 and low is close minus 1; on asymmetric bars it returns -75. A behavioural warm-up assertion written the obvious way would have passed for the wrong reason.

So the test asserts the invariant that actually holds. The static check compares every class docstring's named value against the literal its code passes to _check_fillna, discovered by reflection over all five indicator modules, and pins the census of four so a newly documented value cannot escape it. A second check holds each delegate's docstring to its class. The behavioural check blanks the opening bars to make the fill engage and asserts the documented value lands there, covering three of the four; Negative Volume Index is excluded in the code with its reason, because its 1000 is the seed its first row is built from and no input drives it to NaN.

Closed: T-033 (Medium, documentation) - both Awesome Oscillator docstrings corrected, and every documented fill value now pinned by test.

Filed: T-035 (Low, developer experience) - pylintrc:44 enables `useless-supression` with a single s, so pylint answers W0012 unknown-option-value and the intended check has never run. Surfaced while re-running the linters, and it prints only on the test/ invocation, which is why nine iterations of lint runs never showed it.

Learnings: The lint tooling was gone. black, isort and prospector are in neither .venv nor the system interpreter, and the scratch venvs that once held them no longer do, so the previous iterations' lint claims could not have been reproduced without rebuilding from requirements-test.txt. A gate that is reported every iteration must be re-run every iteration, not carried forward. Separately, the difference between checking a constant and checking behaviour decided this task twice over: reading the constant found the defect but would have mis-scored Ultimate Oscillator, and asserting behaviour naively would have passed Williams %R for a reason unrelated to the fill.

Next: T-034, the SMAIndicator window default.

## iter 10/20 | c6d195f0 | 2026-07-27 | T-035 | done

Task: T-035 (Low, developer experience) - pylintrc:44 enabled `useless-supression` with a single s, so pylint answered W0012 unknown-option-value and the intended check had never run.

Changed: pylintrc (the enabled symbol corrected to `useless-suppression`), BACKLOG.md (T-035 closed, T-036 filed), PLAN.md (one Lesson), JOURNAL.md (this entry).

Checkpoint: 3784da8c71beff7405ccbbc10b37ca509ea2db21

Verification: The symbol was checked against `pylint --list-msgs` before editing, which lists useless-suppression as I0021, and the tree was searched for `pylint: disable` comments first: there are none in ta/ or test/, so arming the check could not change today's message count. After the fix both prospector invocations print zero unknown-option-value lines and still report Messages Found: 0, which is the acceptance. Verify command: 187 tests OK.

A green run would not have distinguished a working config from a dead one, so the check was shown to fire rather than assumed to. A useless `# pylint: disable=unused-import` was planted in ta/utils.py: with the corrected symbol prospector reports `useless-suppression / Useless suppression of 'unused-import'`, Messages Found 1; with the typo put back it reports Messages Found 0. The planted line and the typo were then both reverted. That is the before-and-after that proves the option was inert, not merely cosmetic.

Closing T-035 left fewer than three open items, so a replenishment probe was run over the degenerate end of the user-error surface: every one of the 43 indicator classes was instantiated reflectively against frames of 0, 1 and 2 rows and every public accessor called. One-row and two-row frames are handled by all 43. An empty frame crashes 3 of them with an opaque pandas IndexError while the other 40 return empty output, and the path is reachable without hand-built input, since `dropna` returns an empty frame when every row is unusable and `add_all_ta_features` on that result raises `IndexError: iloc cannot enlarge its target object`. Filed as T-036. Replenishment audits do not count toward convergence.

Closed: T-035 (Low, developer experience) - the pylint check is now armed and demonstrated to fire.

Filed: T-036 (Low, error handling) - empty-frame crashes at ta/volume.py:340, ta/trend.py:976-977 and ta/others.py:85.

Learnings: A configuration option is not validated by the run being green. The misspelled enable produced one W0012 line on the test/ invocation and nothing at all on the ta/ one, so nine iterations of clean lint runs went past it, and the option silently did nothing the whole time. A config change has to be verified the way a test is: plant the violation it is supposed to catch, confirm it is reported, then take the plant away.

Next: T-034, the SMAIndicator window default, then T-036.

## iter 11/20 | c6d195f0 | 2026-07-27 | T-036 | done

Task: T-036 (Low, error handling) - an empty but correctly-columned frame crashed 3 of 43 indicator classes with an opaque pandas IndexError, and add_all_ta_features inherited the crash.

Changed: ta/others.py, ta/trend.py, ta/volume.py (empty guards), test/unit/empty_input.py (new, TestEmptyInput), test/__init__.py (registers it), BACKLOG.md (T-036 closed, settled class recorded), JOURNAL.md (this entry).

Checkpoint: cb09aa80840429c234c206447dba3382b1458b77

Verification: Verify command 190 tests OK, up from 187; both prospector invocations 0 messages at veryhigh; black and isort clean; coverage 100 per cent of 1397 statements and 112 branches, so the three new guards are themselves covered. Each guard returns the empty result the other 40 classes already produced rather than raising a new error, because an empty input has a natural empty answer and 40 precedents in the same package.

The fix was shown able to fail before being trusted. Removing the three guards and re-running the new tests errors by name on CumulativeReturnIndicator, PSARIndicator and NegativeVolumeIndexIndicator through the reflective subTest, and on add_all_ta_features with `IndexError: iloc cannot enlarge its target object`.

PSAR needed three statements reordered, its output series now built before the guard, so the change is not purely additive and a fixture pass alone would not prove it harmless. Outputs were captured from the pre-fix package and the fixed one over 3000 real rows of test/data/datas.csv and compared: psar, psar_up, psar_down, psar_up_indicator, psar_down_indicator, nvi and cumulative_return are identical in all 3000 values across all seven series. The first attempt at that comparison was invalid and the guard caught it: both runs printed the same ta.__file__ under the scratch directory, because sys.path[0] is the script's own directory, so the "fixed" run had loaded the pre-fix package. Re-run with the interpreter's -c form from the repository root, the two runs load from different paths, which the output records.

A second replenishment probe was run, since closing this left fewer than three open items: every class was driven with a window of 1 and with a window of 200 against 20 rows, with RuntimeWarning promoted to an error to catch silent numeric degeneracy. Zero of 43 raise in either case. That is a negative result and no task came of it.

Closed: T-036 (Low, error handling) - all 43 classes and the wrapper handle a zero-row frame.

Settled: degenerate row counts crashing an indicator's seed or recurrence, fixed class-complete with a reflective check over all 43 classes rather than three regression cases.

Learnings: The reordering, not the guard, was the risky part of this fix, and the test suite could not have distinguished a subtle PSAR change because the fixtures pin only what they cover. Comparing full output between the old and new package over real data is what settles a refactor, and that comparison is worthless unless each run proves which package it loaded.

Next: T-034, the SMAIndicator window default, the last unblocked item.

## iter 12/20 | c6d195f0 | 2026-07-27 | T-034 | done

Task: T-034 (Low, code quality) - SMAIndicator alone among 43 classes required its window. Enumerating the relation turned it into the third instance of one root cause, so under the three-strike rule it became a single structural task covering every delegate whose defaults had drifted from its class.

Changed: ta/trend.py (SMAIndicator defaults window to 12), ta/volatility.py (donchian_channel_mband, wband and pband default window 10 to 20), test/unit/defaults.py (new, TestDelegateDefaults), test/__init__.py (registers it), BACKLOG.md (T-034 closed, Proposed and Settled entries), PLAN.md (two Lessons), JOURNAL.md (this entry).

Checkpoint: 30326b0b7d07c0bc33c18a7d08300729464b6a1e

Verification: Verify command 193 tests OK, up from 190; both prospector invocations 0 messages at veryhigh; black and isort clean. Comparing every module-level delegate's parameter defaults against the class it constructs found five drifted parameters across three indicators, not the one SMAIndicator quirk the task named: ema_indicator 12 against EMAIndicator 14, sma_indicator 12 against a required window, and the three Donchian delegates at 10 against a class and two sibling delegates at 20.

The Donchian case is the one with a consequence rather than an inconsistency. Called with their own defaults, donchian_channel_hband and lband use a 20-bar window while mband uses 10, so the middle band is not the midpoint of the channel the same call produces: on a 60-bar series the last row gives hband 122.919 and lband 104.690, whose midpoint is 113.804, while mband returns 120.240. The class returns 113.804. The three delegates now use 20 and the middle band sits where the name says it does.

Both defects predate this run. The `git log -S` search first pointed at this run's own iteration 6 commit, which would have made them look like regressions from the annotation pass; reading `git show a890410:ta/trend.py` and the volatility equivalent shows ema_indicator at window=12 against a class at 14, and the Donchian delegates at 10 against a class at 20, in the upstream tree this run started from.

All three new tests were shown able to fail: against the pre-fix code, the drift check, the required-parameter check and the Donchian composition check all fail, the last with "Series are different". add_all_ta_features is unchanged, its 94-column output over 1500 real rows hashing to f51b37061dd0b2e4 both before and after, because the wrapper passes every window explicitly; the two runs were confirmed to load different packages by printing ta.__file__.

EMA was not decided here. Its class says 14 and its delegate says 12, both conventional periods, and aligning them either way changes published output with no correctness argument for either. That is a user decision, so it is recorded under Proposed and pinned in the test as the single accepted drift, which keeps it visible and stops anything new joining it.

Closed: T-034 (Low, code quality), executed as the structural task the three-strike rule requires.

Settled: delegate defaults drifting from the class they wrap, fixed class-complete but for the recorded EMA exception.

Learnings: The task named one instance and the relation held three. Enumerating every delegate against its class cost one reflective sweep and found a Donchian middle band that fell outside its own channel, which is a materially worse defect than the SMAIndicator signature that prompted the search. Equally, a defect's age has to be established before it is scored: the -S search surfaced this run's own reformatting commit, and only reading the file at the run's starting commit showed both defects were upstream.

Next: no unblocked task remains, so the next iteration audits, and that audit decides convergence.

## iter 13/20 | c6d195f0 | 2026-07-27 | AUDIT | audit

Task: BACKLOG.md held no unblocked task, so a full Improvement-mode audit was run against the Method and Operating envelope with fresh evidence. It does not converge: it found one in-envelope Medium.

Changed: BACKLOG.md (T-037 and T-038 filed), JOURNAL.md (this entry).

Checkpoint: fe9c0dd94d29f79daae8823c53e1a194d2a90429

Verification: Gates all green - Verify command 193 tests OK, both prospector invocations 0 messages at veryhigh with bandit among the tools run, black and isort clean, coverage 100 per cent of 1397 statements and 112 branches. Earlier audits swept arithmetic, lookahead, dtypes, index shapes, magnitudes, documented fill values, degenerate row counts and delegate defaults, so this one went at argument validation and at the paths that are supposed to agree with each other.

Dimension scores: error handling Medium - T-037. documentation Low - T-038. correctness, testing, security, dependency hygiene, architecture, code quality and developer experience None. performance skipped, no measurement taken beyond the copy cost under T-031. observability and UX skipped: a computation library with no process to observe and no user-facing surface.

The Medium is argument validation, and its consequence is worse than an unhelpful error. A zero window leaves 21 of the 35 windowed classes returning an all-NaN series with no complaint. A negative window is worse than NaN twice over: AverageTrueRange(window=-5) returns plausible finite numbers, 1890.43, 2268.11 and 2721.33 at the tail of a 60-bar series, which a caller has no way to distinguish from a real ATR; and ROCIndicator(window=-5) reads forward, because shift(-5) pulls bars that have not happened. That was reproduced rather than reasoned about: perturbing bar 20 of a 40-bar series changes the value at row 15. This is not a re-file inside the settled lookahead class, whose implementing code is unchanged and whose subject was warm-up seeding; the root cause here is an unvalidated argument, and the lookahead is one of its three symptoms. ADXIndicator already raises ValueError: window may not be 0, so the intended contract exists in the codebase and only its coverage is missing, and the envelope's binding rule makes the remedy a single validation boundary rather than 35 guards.

What came back clean is worth recording, since convergence turns on it. The README is accurate: all 43 indicator classes and all 80 module-level functions appear in it, and its own "43 indicators" claim matches the count. add_all_ta_features produces no duplicate column name and no entirely-NaN column. Running the full suite with FutureWarning and DeprecationWarning promoted to errors passes, so nothing in the library relies on behaviour pandas 3.0.5 has deprecated. The Donchian offset parameter is exactly a shift of the unoffset series. The vectorized flag's two code paths agree exactly on all 76 columns they share, which is what turned that finding into documentation rather than correctness.

Learnings: Two code paths that are meant to agree are a cheap and strong probe, and the result decides the severity rather than the reverse: the vectorized comparison could have been a correctness defect and the exact agreement on 76 shared columns is what made it a documentation one. Equally, an argument that is merely wrong is not always a loud failure - a negative window produced lookahead here, which is a different and worse symptom than the NaN a zero window produces, and only trying both values surfaced it.

Next: T-037, one validation boundary for window arguments, then T-038.

## iter 14/20 | c6d195f0 | 2026-07-27 | T-037 | done

Task: T-037 (Medium, error handling) - no constructor validated its lookback period, so a wrong value was absorbed rather than reported.

Changed: ta/utils.py (_check_window), ta/momentum.py, ta/trend.py, ta/volume.py, ta/volatility.py (67 period arguments guarded, ADX's ad-hoc check removed), test/unit/windows.py (new, TestWindowValidation), test/__init__.py (registers it), BACKLOG.md (T-037 closed, settled class), PLAN.md (one Lesson), JOURNAL.md (this entry).

Checkpoint: de56b429921f0c326156d1aee6d65b93b4b994c1

Verification: Verify command 196 tests OK, up from 193; both prospector invocations 0 messages at veryhigh; black and isort clean; coverage 100 per cent of 1399 statements and 112 branches. The two headline cases now report themselves: AverageTrueRange(window=-5) and ROCIndicator(window=-5) both raise ValueError: window must be at least 1, got -5, where before one returned plausible ATR-shaped numbers and the other returned values read from future bars.

The guard is one helper, as the envelope's binding rule requires, and ADXIndicator's own `if self._window == 0: raise ValueError` was deleted in favour of it, so validation is not in two places. Its existing test still passes, because the helper raises the same exception type.

Which arguments count as periods was decided by enumerating every constructor parameter across the 43 classes rather than by pattern-matching names. Sixty-seven are periods. Seven are not and are deliberately left alone: window_dev is a count of standard deviations for the Bollinger bands, multiplier scales the Keltner bands, offset is a shift whose own default is 0, and constant, step, max_step and weight1 to weight3 are float coefficients. smoothing_factor needed its own handling, since None is the documented way to ask for no smoothing while ta/volume.py:297 tests it for truthiness, which silently conflated 0 with None; None still means no smoothing and 0 is now rejected.

The mechanical pass missed four sites and the check I wrote to catch that missed them too. Both were keyed on the attribute name, and KSTIndicator stores roc1 to roc4 as _r1 to _r4, so a pattern requiring the attribute and parameter to match skipped them and a re-grep for that same pattern reported all clear. Re-verifying per constructor parameter by AST found the four, and those are the periods that reach shift, which is where the forward-reading behaviour comes from. All 67 now pass through the helper.

Fixed values are untouched: add_all_ta_features over 1500 real rows hashes to f51b37061dd0b2e4 before and after, the two runs confirmed to load different packages. Against the pre-fix code the new test fails with "ValueError not raised".

Closed: T-037 (Medium, error handling) - one validation boundary, all 67 period arguments covered.

Settled: lookback periods accepted without validation, fixed class-complete at one boundary.

Learnings: A mechanical edit and the check that confirms it must not share an assumption. Both of mine keyed on the attribute name, so both were blind to the same four sites, and the pass looked complete because its verifier asked the same question it did. Verify by the thing the change was meant to cover - here the constructor parameter, read from the signature - not by re-grepping the pattern the edit itself used.

Next: T-038, the vectorized flag's docstring, the last unblocked item.

## iter 15/20 | c6d195f0 | 2026-07-27 | T-038 | done

Task: T-038 (Low, documentation) - the vectorized flag read "if True, use only vectorized functions indicators", which is ungrammatical and silent about what the flag costs.

Changed: ta/wrapper.py (five docstrings rewritten), test/unit/vectorized.py (new, TestVectorizedSubset), test/__init__.py (registers it), BACKLOG.md (T-038 closed), PLAN.md (one Lesson), JOURNAL.md (this entry).

Checkpoint: ba5526357aab01e6c258f322eba6bc20d02e818f

Verification: Verify command 198 tests OK, up from 196; both prospector invocations 0 messages at veryhigh; black and isort clean; coverage 100 per cent of 1399 statements and 112 branches.

Each wrapper was measured rather than described from the one number the audit had: add_volume_ta omits 2 of 10, add_volatility_ta 2 of 21, add_trend_ta 13 of 34, add_momentum_ta 1 of 18, and add_all_ta_features 18 of 86, which is the four combined. Every docstring now names its own pair of numbers, so each is a claim about that function rather than a general remark, and the test reads the numbers back out of the docstring with a regex and compares them to what the wrapper actually produces. A count that drifts from the code now fails. The test also asserts the flag changes only which indicators run: all 68 columns present under both settings are compared with assert_series_equal.

The sensitivity check produced a false failure and diagnosing it mattered more than the task. Changing 13 to 12 in the docstring made the test fail as intended, but after changing it back the suite still failed, and the file on disk plainly read 13 while add_trend_ta.__doc__ read 12. The cause is that Python validates a cached .pyc against the source's mtime and size alone: "12" and "13" are the same size, and the edit landed in the same second as the compile from the previous run, so the stale bytecode was still considered valid. Clearing __pycache__ restored agreement and the suite went green with no code change. Had this been read as a real regression the obvious response would have been to change working code to satisfy a stale test.

Closed: T-038 (Low, documentation) - the vectorized flag's cost is stated per wrapper and pinned by test.

Learnings: A test failure that contradicts the file in front of you is evidence about the toolchain, not the code. Python's .pyc validation compares only source mtime and size, so a same-size edit within a one-second window is invisible to it; clear __pycache__ before trusting any result that disagrees with what the source says.

Next: no unblocked task remains. The next iteration audits, and that audit decides convergence.

## iter 15/20 | c6d195f0 | 2026-07-27 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines after this iteration's primary entry, at 512.

Changed: JOURNAL.md (17 oldest entries removed, preamble restored), JOURNAL-archive.md (new, holds those 17).

Checkpoint: ba5526357aab01e6c258f322eba6bc20d02e818f

Verification: 27 entries were present. The 17 oldest, from iter 10/10 of the previous run through iter 5/20 of this one, moved to JOURNAL-archive.md oldest first; the last 10 remain here, iter 6/20 through iter 15/20. JOURNAL.md is now 230 lines and the archive 295, which together exceed the original 512 only by the two files' headers. No entry text was altered.

The preamble had been truncated at some earlier point: everything after "Heading grammar, exactly:" was missing, so the file no longer documented its own heading grammar, body field order, evaluator line or rotation rule, and a real entry sat where the example belongs. It has been restored from the skill's journal-default.md. That is the preamble, not an entry, so nothing append-only was rewritten.

Learnings: Splitting this file on its heading pattern is not safe without care, because the preamble's own grammar example begins with the same "## iter " prefix as a real heading. The rotation therefore rebuilt the preamble from the template rather than treating the text before the first heading as authoritative.

Next: the primary entry for this iteration records it - no unblocked task remains, so the next iteration audits.

## iter 16/20 | c6d195f0 | 2026-07-27 | AUDIT | audit

Task: BACKLOG.md held no unblocked task, so a full Improvement-mode audit was run with fresh evidence. It does not converge: it found an in-envelope High, and that High is a regression introduced by this run.

Changed: BACKLOG.md (T-039 and T-040 filed), PLAN.md (two Lessons), JOURNAL.md (this entry).

Checkpoint: 051b85d015625321f0b555040e52da4c651f64ce

Verification: Gates green - Verify command 198 tests OK, both prospector invocations 0 messages at veryhigh, coverage 100 per cent. None of that caught the defect, which is the point worth recording.

Dimension scores: correctness High - T-039. code quality Low - T-040. testing, error handling, documentation, security, dependency hygiene, architecture and developer experience None. performance skipped, no measurement taken. observability and UX skipped, no process to observe and no user-facing surface.

The probe was a property no earlier audit had asserted: flipping fillna should change only the warm-up rows, never the settled values. Sixteen accessors moved. Eight of them - MACD, TSI, KST, TRIX, MassIndex, PPO, PVO and STC - are EMA seeding transients that decay to exactly zero by mid-series, so they are not defects, and measuring the decay rather than the maximum is what separated them from the real one.

KAMA does not decay. With fillna=True it returns a constant: add_all_ta_features(fillna=True) produces a momentum_kama column holding a single distinct value across 400 rows, and the raw _kama array has 1 non-NaN entry of 600. The chain is that min_periods=0 makes the row-0 rolling sum of an all-NaN window evaluate to 0.0, the same pandas rule recorded at iteration 9; `.where(er_den != 0, 0.0)` then reads a not-yet-computable denominator as a genuine zero market, sets the efficiency ratio to 0, and makes row 0 the first usable smoothing constant. The recurrence seeds there while rows 1 to 9 are still NaN, the NaN propagates through every later row, and _check_fillna's ffill spreads the row-0 seed across the whole series.

It is mine. At a890410 the two fillna paths converged - 188 of 591 rows differed and the difference was 0 at the last row - and iteration 6's seeding change turned that into a permanent divergence and then a constant. The fixture test for KAMA exercises fillna=False only, so it passed throughout.

Three green signals covered this defect. Coverage is 100 per cent, because the lines all execute. The suite passes, because no test asserts a KAMA value with fillna=True. And iteration 8's sweep, which instantiated every class with fillna=True and checked every accessor for NaN and inf, passed it: a constant 6.0 has neither.

The rest of the audit was clean, with fresh evidence. All 43 classes preserve a DatetimeIndex exactly across every accessor, every accessor is deterministic across repeated calls, and 81 distinct series names are returned, of which three are shared between BollingerBands and KeltnerChannel and are filed as T-040.

Learnings: A contract worth asserting has to be strong enough to fail. "No NaN and no inf" is satisfied by a constant, so the sweep that was meant to prove the fillna path sound proved only that it was finite. The stronger property - that the filled series varies and agrees with the unfilled one outside warm-up - is the one that found this in a single pass. Related: a fix verified against a fixture is verified only on the settings that fixture uses, and cs-kama.csv uses fillna=False.

Next: T-039, the KAMA fillna regression, then T-040.


# Journal

Append-only. One primary entry per iteration; SALVAGE and ROTATION entries are additional. Never rewrite past entries (filling the current entry's Checkpoint field is completion, not a rewrite).

Heading grammar, exactly:
## iter <i>/<N> | <run-id> | <YYYY-MM-DD> | <task-id or AUDIT or RATCHET or WRAPUP or SALVAGE or ROTATION> | <done|blocked|audit|converged|salvage|rotation>

SALVAGE entries take status salvage; ROTATION entries take status rotation.

run-id is the first 8 characters of the session id. Body fields, in order: Task, Changed, Checkpoint (the jeffy checkpoint commit hash, or none with the reason), Verification, Learnings, Next.

The closing entry that declares convergence carries the evaluator verdict in its Verification field: `Evaluator: PASS - <one-line summary>`, or `Evaluator: unavailable (<reason>)`.

Closed tasks are recorded here as one line each (ID, title, closing evidence), because BACKLOG.md deletes them. Rotation: when this file exceeds 500 lines, move all but the last 10 entries to JOURNAL-archive.md and record the rotation as a ROTATION entry.

## iter 17/20 | c6d195f0 | 2026-07-27 | T-039 | done

Task: T-039 (High, correctness) - KAMAIndicator returned a constant series under fillna=True, a regression from this run's iteration 6.

Changed: ta/momentum.py (the efficiency ratio's zero-denominator branch), test/unit/fillna.py (new, TestFillnaDoesNotFlatten), test/__init__.py (registers it), BACKLOG.md (T-039 closed, settled class), JOURNAL.md (this entry).

Checkpoint: 9871ef52c501c9509b6190ff005d06eecd32924d

Verification: Verify command 201 tests OK, up from 198; both prospector invocations 0 messages at veryhigh; black and isort clean; coverage 100 per cent of 1400 statements and 112 branches.

The fix is one condition. `.where(er_den != 0, 0.0)` treated any zero denominator as a flat market, but under fillna=True the row-0 denominator is a rolling sum over an all-NaN window, which pandas evaluates to 0.0 and which means not computable yet. Substituting 0.0 only where the numerator is also defined leaves the warm-up rows undefined, so the recurrence seeds where it did before the flag was set.

Measured on 600 real rows: the raw _kama array holds 591 non-NaN entries where it held 1, kama() has 599 distinct values where it had 1, and the fillna=True and fillna=False series are now equal on all 591 rows the unfilled one defines, with the warm-up rows filled rather than NaN. Against the broken code all three new tests fail, with "1 != 591", "1 not greater than 1" and "Series are different".

The fillna=False path is untouched by construction, since the new condition can only differ where the numerator is NaN, and that is confirmed: add_all_ta_features over 1500 real rows hashes to f51b37061dd0b2e4 before and after, the two runs loading from different paths.

The permanent test is the property, not the instance. All 84 accessors are computed under both settings and none may collapse to a constant while its unfilled twin varies; that is the check that would have caught this in iteration 6, where a fixture on fillna=False and a sweep for NaN and inf both passed. The one private access, to assert the recurrence rather than the filled output, is justified because the fill is exactly what hid the defect; prospector reports it as a needed suppression rather than a useless one, which is the useless-suppression check armed in iteration 10 doing its job.

Replenishment probe, since closing this leaves fewer than three open items: every non-fillna boolean option was driven both ways - Ichimoku's visual, VolumePriceTrend's dropnans and KeltnerChannel's original_version. All change their output as intended and all produce finite, defined series. No task came of it.

Closed: T-039 (High, correctness) - KAMA's two fillna paths agree again, and the collapse class is pinned across all 84 accessors.

Settled: a filled series collapsing to a repeated seed, fixed class-complete.

Learnings: The fix was one line; finding it needed a property the earlier checks did not state. Both guards that should have caught this were satisfied by the broken output - the fixture because it pins only fillna=False, the sweep because a constant contains no NaN and no inf - so the regression sat behind 100 per cent coverage and a green suite for eleven iterations.

Next: T-040, the Keltner series names, the last unblocked item.

## iter 18/20 | c6d195f0 | 2026-07-27 | T-040 | done

Task: T-040 (Low, code quality) - KeltnerChannel accessors returned series labelled with other indicators' names.

Changed: ta/volatility.py (five series names), test/unit/naming.py (new, TestSeriesNames), test/__init__.py (registers it), BACKLOG.md (T-040 closed, settled class), JOURNAL.md (this entry).

Checkpoint: 53871ec7b164cd5925700d99056706915063d6b0

Verification: Verify command 203 tests OK, up from 201; both prospector invocations 0 messages at veryhigh; black and isort clean; coverage 100 per cent of 1400 statements and 112 branches.

The audit had found three names, and mapping every name to its owning class found five. Three collided outright with the Bollinger accessors that own them - mavg, bbiwband and bbipband - and two more, dcihband and dcilband, carry Donchian's prefix on Keltner's band indicators and had escaped the audit only because no Donchian accessor happens to return those exact strings. All five now use the kc_ prefix that keltner_channel_hband and keltner_channel_lband already used, so the class labels its own seven accessors consistently. The same enumeration was run over momentum, trend, volume and others, which are clean.

This changes observable behaviour, so the rationale is recorded here as the Constraints require: the names are the `name` attribute of returned Series, a caller concatenating accessors into a frame got columns labelled as Bollinger or Donchian output, and three of them collided so two different indicators produced identically named columns. Nothing depends on the old strings - no test, no README entry and no docs page references them - and add_all_ta_features is unaffected because the wrapper assigns its own column names, confirmed by the 94-column output hashing to f51b37061dd0b2e4 before and after.

Against the pre-rename code the new test fails on the five accessors by name.

Closed: T-040 (Low, code quality) - Keltner labels its own bands, and no two of the 84 accessors share a series name.

Settled: a returned series carrying another indicator's name, fixed class-complete with an enumeration over all 84 accessors.

Learnings: The audit reported the symptom it could see, which was collision, and collision is a weaker property than correctness: two of the five wrong names were unique and so invisible to that check. Mapping each name to the class that returns it, rather than counting duplicates, is what found the rest.

Next: no unblocked task remains, so iteration 19 audits, and that audit decides convergence.

## iter 19/20 | c6d195f0 | 2026-07-27 | AUDIT | audit

Task: BACKLOG.md held no unblocked task, so a full Improvement-mode audit was run with fresh evidence. It does not converge: it found an in-envelope High in code no run has touched.

Changed: BACKLOG.md (T-041 filed), PLAN.md (one Lesson), JOURNAL.md (this entry).

Checkpoint: 41b7ee8a55069f41119ec2a318f997275f68a90a

Verification: Gates green - Verify command 203 tests OK, both prospector invocations 0 messages at veryhigh, coverage 100 per cent of 1400 statements and 112 branches.

Dimension scores: correctness High - T-041. architecture, code quality, testing, error handling, documentation, security, dependency hygiene and developer experience None. performance skipped, no measurement taken. observability and UX skipped, no process to observe and no user-facing surface.

The High is On-Balance Volume. `np.where(close < close.shift(1), -volume, volume)` is a two-way split with no branch for an unchanged close, so a flat bar adds volume where both references the project itself cites - Wikipedia in the class docstring, StockCharts in the test module - leave the running total alone. It also adds volume at row 0, where the shifted close is NaN and the comparison is False. On 400 real rows 85 of 399 bars are flat, 21.2 per cent, and the final value reads 1631.93 against 533.44 computed from the cited rule: an error of 205.9 per cent of the correct value, and monotone, because every flat bar adds volume that should add nothing. It is upstream, unchanged since a890410, and untested at the point that matters: test/data/cs-obv.csv has no flat bar in its 30 rows, so the fixture passes either way.

It was found by computing each indicator independently from its definition rather than trusting the fixtures. SMA, EMA, ROC and the Bollinger upper band match a direct pandas computation to zero or 1e-13. RSI differs by 14.63 at its first defined row but decays to 5.07e-12 by the last, which is a one-bar warm-up convention - the library counts the undefined first change as zero and so defines RSI from row 13 rather than 14 - and not a defect.

The rest of the audit is clean on fresh evidence. No indicator mutates a caller's Series: all 43 were driven under both fillna settings with their inputs hashed before and after. The property that caught the previous High now passes everywhere - no accessor still diverges between fillna settings in the second half of the series, so every remaining difference is a decaying warm-up transient. This run's whole diff against 146fea4 was read: every change in ta/ is accounted for as _to_float coercion, _check_window guards, the SMA default, the KAMA efficiency-ratio fix, the Keltner renames, the empty-input guards, or the wrapper copies and docstrings, with nothing unintended.

One correction to iteration 16's entry, which is left standing as written: it called the KAMA seeding change "this run's iteration 6". It was commit 0562c6f, iter 6/10 T-005, an earlier run in this same session, and it predates this run's first checkpoint. The defect was still mine and it survived two later runs.

Learnings: A fixture proves the rows it contains. cs-obv.csv holds 30 rows and not one flat bar, so a 21-per-cent-of-rows departure from the definition the library cites sat behind a passing test, 100 per cent coverage and every property sweep run so far. Recomputing an indicator from its cited definition is a different question from asking whether it still matches its recorded output, and only the first one can find this class of defect.

Next: iteration 20 is the last of the budget. T-041 is a one-branch fix whose acceptance leaves cs-obv.csv untouched, so it is finishable, and closing a High is worth more than a handoff that only describes it.

## iter 20/20 | c6d195f0 | 2026-07-27 | T-041 | done

Task: T-041 (High, correctness) - On-Balance Volume added a bar's volume on an unchanged close, where the definition it cites leaves the running total alone. Final iteration of the budget; the task was executed rather than handed off because its acceptance was reachable within the iteration and it closes a High.

Changed: ta/volume.py (three-way OBV), test/unit/definitions.py (two OBV tests on the already-registered TestVolumeDefinitions), BACKLOG.md (T-041 closed, settled class), JOURNAL.md (this entry).

Checkpoint: e4a2c3501d29453153e2581ee449711178e3ce7a

Verification: Verify command 205 tests OK, up from 203; both prospector invocations 0 messages at veryhigh; black and isort clean; coverage 100 per cent of 1401 statements and 112 branches.

The fix replaces a two-way np.where with three branches and computes the change once. On 400 real rows the series now equals a from-scratch implementation of the cited rule exactly, none of the 85 flat bars moves the total, and the final value is 533.44 where it read 1631.93. The first bar contributes nothing rather than adding its own volume against a NaN comparison.

The reference fixture passes unmodified, as the acceptance required: test/data/cs-obv.csv has no flat bar and the test compares only its tail, and the NaN volume on its seed row was already skipped by cumsum. The two new tests sit on TestVolumeDefinitions, which test/__init__.py already registers, and both fail against the two-way code.

This changes published values, so the rationale is recorded here as the Constraints require. OBV was wrong against both references the library itself cites, by 205.9 per cent of the correct value at the last of 400 rows, and the error is monotone in the number of flat bars, so any series with a repeated close was affected. add_all_ta_features moves from f51b37061dd0b2e4 to 99e9951f192519c3 over 1500 rows, and volume_obv is the only column that differs.

Closed: T-041 (High, correctness) - OBV matches its cited definition and the flat-bar branch is tested.

Settled: an indicator departing from the definition its own docstring cites, fixed for OBV and checked by recomputing SMA, EMA, ROC, the Bollinger upper band and RSI independently.

Learnings: The budget ended with a High closed rather than a handoff written, which was the right trade only because the acceptance had been stated precisely enough in the audit to be executed without re-deciding anything. An audit that names the failing branch, the reference, the affected row count and the fixture's blind spot leaves a task that a single iteration can finish.

Next: the run ends here on the iteration budget, not on convergence. BACKLOG.md carries T-007 blocked on a user decision and three Proposed items; the next run should start with an audit, since the last one filed a High in untouched upstream code and the same recompute-from-definition sweep has covered only six indicators so far.

## iter 1/10 | ed214ec6 | 2026-07-27 | AUDIT | audit

Task: BACKLOG.md held no unblocked task, so a full Improvement-mode audit was run with fresh evidence. It does not converge: it found an in-envelope High in a file no audit had ever opened.

Changed: BACKLOG.md (T-042 filed), PLAN.md (one Lesson), JOURNAL.md (this entry).

Checkpoint: e783137d1b2d599dcb4cbfd4f2abcf894c864ae0

Verification: Verify command 205 tests OK, exit 0, and still OK with FutureWarning and DeprecationWarning escalated to errors under the installed pandas 3.0.5. ta/ and test/ are byte-identical to e4a2c35, where prospector last ran clean at veryhigh, so no lint result is being re-asserted as freshly run; the lint gate itself was not re-executed this iteration and that is recorded rather than claimed.

Dimension scores: dependency hygiene High - T-042. correctness, documentation, testing, error handling, security and developer experience None. architecture and code quality None on an artifact unchanged since the last clean prospector run, with the limitation named above. performance skipped, no measurement taken. observability and UX skipped, no process to observe and no user-facing surface.

The High is requirements-play.txt. `pip install -r requirements-play.txt` exits 1 and installs nothing, because matplotlib==3.1.1 dates from July 2019, ships no wheel for any interpreter the project supports, and fails while building its sdist. README.md:191 gives that command as the whole of "Deploy and develop (for developers)", and because the file pulls requirements.txt it carries the entire test, coverage and doc toolchain with it, so pip's atomic resolution leaves a would-be contributor with nothing installed. `pip install -r requirements.txt` resolves clean at exit 0, and enumerating all six requirements files shows five resolving and only this one failing, so the defect is one pin and the fix is one line.

It was filed as a class rather than a pin edit because it is the third instance of one root cause. T-029 raised coverage 4.5.4 and coveralls 1.8.2, both 2019 pins; the prospector and Sphinx floors were lifted because releases below them import pkg_resources, which a 3.12+ venv no longer ships. That is the three-strike threshold, so T-042's acceptance enumerates every requirements file instead of naming the one that failed first.

The rest of the audit is clean on fresh evidence. The recompute-from-definition sweep the last run began with six indicators was extended to 62 accessor comparisons covering 41 of the 43 classes, each recomputed from the definition the class docstring cites using pandas primitives rather than read out of ta/. Every one agrees with the library to floating-point precision over the last 300 of 1500 real rows. Six accessors differ only across an opening prefix - ATR to row 255, ADX +DI to 265, TSI to 154, TRIX to 179, MACD signal and PPO signal to 103, Mass Index to 105 - and are exactly zero thereafter, which is EMA and Wilder seeding convention, the same class as the RSI warm-up settled in iteration 19, not defect. PSAR and STC are path-dependent and were not recomputed; they were instead held to their documented invariants, which pass.

Two apparent mismatches were my probe's fault, not the library's, and are recorded so they are not re-filed. Aroon disagreed by up to 72 per cent until a tie-free control series brought the difference to exactly 0.0: numpy argmax resolves a tied extreme to the oldest bar, the library to the most recent, and the library is right, since an extreme equalled again today happened zero days ago. That is deliberate and documented at ta/trend.py:51-56, and 7.2 per cent of real 26-bar windows carry a tied high. vortex_indicator_diff disagreed because I took an absolute value and the library returns the signed difference, which is correct for a directional oscillator and negative on 696 of 1486 rows.

Documented ranges hold across 3000 rows for RSI, StochRSI, Stochastic, Williams %R, MFI, Ultimate Oscillator, STC, Aroon, ADX and Chaikin Money Flow, with no out-of-range value and no inf anywhere. PSAR never defines psar_up and psar_down on the same row, never raises both reversal flags together, and its psar is finite throughout. All 80 README links into the published docs resolve to real module functions, and no public delegate is missing from the table.

ADX alone returns no NaN at all over 3000 rows where every other windowed indicator has a warm-up prefix. That is T-007, already filed and blocked on the user decision recorded under Proposed, not a new finding.

Learnings: Five consecutive audits recorded dependency hygiene as None with the words "every pin current" or "every pin now current and installable" while a 2019 matplotlib pin sat in requirements-play.txt. The claim was about every pin; the check only ever covered the files that iteration had already been editing, and requirements-play.txt is the one file no run has ever opened. A dimension scored on the files that happen to be in hand is scored on a sample, and the sample was never stated.

Next: T-042 is a one-line pin change whose acceptance is a six-file enumeration, so iteration 2 executes it.

## iter 2/10 | ed214ec6 | 2026-07-27 | T-042 | done

Task: T-042 (High, dependency hygiene) - requirements-play.txt could not be installed on any supported interpreter, so the README's only documented developer setup installed nothing at all.

Changed: requirements-play.txt (the matplotlib pin and its reason), .circleci/config.yml (a lint step resolving every requirements file), BACKLOG.md (T-042 closed, settled class), JOURNAL.md (this entry).

Checkpoint: 98965dbbb5085155e342efb82bf01ea8e3afc59d

Verification: Verify command 205 tests OK, exit 0. All six requirements files resolve, where before only five did. matplotlib>=3.9.2 installs for real into a clean target, imports, and renders a figure through the Agg backend; the floor version itself was installed exactly, not merely the newest release satisfying it, because a floor nobody has executed is a guess. Every exact pin across all requirements files is available on 3.10, 3.11, 3.12 and 3.13, and matplotlib==3.1.1 fails that same probe on all four, so the check is shown able to fail rather than merely observed to pass. The new CI step's command was executed locally over all six files at exit 0, and planting the old pin back makes it exit non-zero and name the offending file.

The floor was chosen by measurement rather than by what looked current. matplotlib 3.9.1.post1 has no wheel for 3.13 and 3.9.2 is the first release that covers all of 3.10 to 3.13, so 3.9.2 is the floor; picking 3.10.0 because it reads like a rounder number would have excluded working releases for no reason.

The fix is one line, but it was filed and closed as a class because it is the third instance of one root cause, after T-029's coverage and coveralls pins and the prospector and Sphinx releases that import pkg_resources. The three-strike rule forbids patching a fourth, so the close is structural: CircleCI now resolves every requirements*.txt on every build. That is the boundary that was missing - requirements-play.txt survived five audits precisely because no CI job installs it, so nothing but a hand audit could ever have caught it, and hand audits had already missed it five times.

jupyterlab>=1.2.21 in the same file was examined and deliberately left alone. It is a floor rather than an exact pin, so pip resolves it to a current release and no failure can be reproduced; changing it would be cosmetic churn against the evidence rule, and the Constraints forbid that.

Learnings: pip refuses --python-version unless --only-binary=:all: or --no-deps is also set, and it reports that refusal per invocation, so a loop that only checks the exit status reads it as every package being unavailable. My second probe said all four exact pins failed on every interpreter while the first said they passed; the disagreement, not either result, is what was informative. Always run a probe against a specimen known to fail - here the 3.1.1 pin - before believing what it says about the specimens expected to pass.

Next: BACKLOG.md has no open unblocked task again, so iteration 3 audits; the dimensions least recently examined with fresh evidence are performance, which no run has ever measured, and the lint gate, which was not re-executed in iteration 1.

## iter 3/10 | ed214ec6 | 2026-07-27 | AUDIT | audit

Task: BACKLOG.md held no unblocked task, so a full Improvement-mode audit was run with fresh evidence, deliberately aimed at the two dimensions carrying the weakest evidence: performance, which no run has ever measured, and the lint gate, which iteration 1 recorded as not re-executed. Both produced findings or first measurements, and the run does not converge.

Changed: BACKLOG.md (T-043 and T-044 filed), PLAN.md (two Lessons), JOURNAL.md (this entry).

Checkpoint: f0cc77252d42d32e1963e2c5534898942c51671b

Verification: Verify command 205 tests OK, exit 0. The lint gate was rebuilt and genuinely re-run this iteration rather than carried forward: a fresh venv from requirements-test.txt gives prospector 0 messages on ta/ and 0 on test/ at veryhigh with all eight tools running including bandit, isort --check-only clean, and black --check reporting 25 files unchanged.

Dimension scores: correctness Medium - T-043. performance Medium - T-044, and this is the first measurement any run has taken of it. architecture, code quality, security, testing, documentation, dependency hygiene and error handling None. observability and UX skipped, no process to observe and no user-facing surface.

Performance was measured rather than skipped for the first time. add_all_ta_features costs 6.9 s on 50000 rows, and three classes account for 6.5 s of the 8.0 s spent constructing all 43: PSAR at 3.26 s, WMA at 2.12 s and NVI at 1.13 s. PSAR, NVI, ATR, ADX and KAMA are already Declined as genuinely recursive, and that reason still holds, though the Declined line's second clause - that no measurement showed them to be a bottleneck - is now false for PSAR, which is the single largest cost. WMA is not recursive and is not on that list. It multiplies a pandas Series of weights by the window ndarray inside a rolling callback, so it builds a Series 50000 times; making the weights an ndarray takes it from 1376 ms to 53.5 ms with bit-identical output, and a convolution takes it to 0.4 ms at a cost of 9e-13. MFI is the same idiom without the Series, at 283.6 ms against 2.5 ms vectorized. Two instances is below the three-strike threshold, so T-044 is filed as one task over the enumerated `.apply(` sites rather than as a class or as two symptoms.

The correctness finding is PSAR, and it came from finishing the recompute sweep iteration 1 left open. STC agrees with an independent Schaff implementation to zero in the tail. PSAR did not: only 76.5 per cent of rows matched a from-scratch Wilder implementation, and that figure was identical under three different seeds, so it was not the seeding artifact a path-dependent indicator usually produces.

Reading the code found an if/elif where a minimum belongs. In an uptrend the clamp tests low2 first and assigns it whenever it is below the computed SAR, never comparing low1; Wilder requires SAR to sit beyond both prior bars. My first probe for this signature returned zero occurrences and was wrong, because it tested the post-clamp value against the bar it had just been assigned from, a comparison that can never fire. Tracing the four suspect rows directly showed it plainly: at row 274 SAR is 1341.33, exactly low2, while low1 is 1341.22, so SAR sits above a low the market already traded, and rows 170, 796 and 1079 are the same shape.

The fix was validated before filing. A standalone reimplementation reproduces the library's output exactly, to 0.0, so the model is faithful; changing only the clamp to a minimum alters 4 of 3000 rows by up to 17.92, flips no trend state, and removes exactly the four non-reversal invariant violations. Nine rows violate the invariant before the fix and five after, and those five are reversal bars, where Wilder sets SAR to the prior extreme point without clamping, so they are correct. test/data/cs-psar.csv is unaffected: the fix changes none of its 30 rows, which is the earlier lesson about that fixture never entering the branch holding its bug, confirmed again.

It is scored Medium, not High, and the comparison is recorded so the call is auditable. OBV was High at 21.2 per cent of bars with a 205.9 per cent error. This is 0.13 per cent of rows, under 1 per cent of price, and no change to the up or down signal on 3000 real rows, which is a failure on a plausible in-envelope edge case rather than systematic wrongness. It is filed despite the settled class for indicators departing from their cited definition, because that settlement names the indicators it verified - OBV, SMA, EMA, ROC, the Bollinger upper band and RSI - and iteration 1 explicitly recorded PSAR and STC as outside the sweep, so this is a gap the settlement left open rather than a re-file inside it.

Learnings: A probe that reads a value after the code has already assigned it cannot detect how it was assigned. Mine compared the published SAR against the bar it had just been set to and reported zero occurrences of exactly the defect that was there; tracing four concrete rows found it in one step. When checking whether a branch chose correctly, reconstruct the inputs it chose between, never the output it produced.

Next: T-043 heads the backlog and is a two-line change with a test that must fail against current code, so iteration 4 executes it.

## iter 4/10 | ed214ec6 | 2026-07-27 | T-043 | done

Task: T-043 (Medium, correctness) - PSAR clamped SAR against the prior two bars with an if/elif that took the older bar without ever comparing the nearer one, publishing a stop on the wrong side of a price already traded.

Changed: ta/trend.py (both clamps become a minimum and a maximum), test/unit/trend.py (test_psar_clears_both_prior_bars on the already-registered TestPSARIndicator), BACKLOG.md (T-043 closed, settled class extended), JOURNAL.md (this entry).

Checkpoint: a3b536564f5cfad3728d438a08a8b7328555cc00

Verification: Verify command 206 tests OK, up from 205, exit 0. All 12 PSAR tests pass, including the four fixture comparisons and their delegate variants, with test/data/cs-psar.csv unmodified. The new test was shown able to fail: reverting only the two clamps makes it fail naming rows 170, 274, 796 and 1079 with the same values the audit traced by hand, and the loaded module path was asserted as the project's own trend.py before trusting that result, with __pycache__ cleared on both sides of the swap.

The fix is two lines. `min(self._psar.iloc[i], low1, low2)` replaces the uptrend if/elif at ta/trend.py:1013 and `max(self._psar.iloc[i], high1, high2)` the downtrend one at 1035. A standalone reimplementation of the old logic reproduces the pre-fix library exactly and the library now equals the fixed variant exactly, both to 0.0, so the change is precisely the clamp and nothing else.

This changes published values, so the rationale is recorded as the Constraints require. Over 3000 real rows 4 rows move, 0.13 per cent, by at most 17.92, which is 0.731 per cent of mean price. No trend state flips, so psar_up and psar_down keep the same runs and the up and down indicator flags are unchanged; psar_up and psar_down are still never both defined on a row. The old values were not defensible: on those rows SAR sat above a low, or below a high, that the prior two bars had already traded, which is the one thing the clamp exists to prevent, and because the recurrence feeds SAR forward the error did not stay local.

The shipped fixture could not have caught this. cs-psar.csv holds 30 rows and the fix changes none of them, which is the second distinct PSAR defect that fixture has been blind to; the test therefore asserts the invariant on 3000 rows of real data rather than adding another fixture comparison, and it skips reversal bars, where Wilder deliberately sets SAR to the prior extreme point unclamped and the invariant does not apply.

Closed: T-043 (Medium, correctness) - PSAR clears both prior bars on every non-reversal row, pinned on real data.

Learnings: Reverting the fix and rerunning is what turned this from a plausible reading of the code into evidence, and it named the same four rows the audit had traced independently. Two routes to the same row numbers, one by tracing inputs and one by mutation, is a stronger result than either alone, and cheap once the test exists.

Next: T-044 is the only open task, the performance work over the enumerated `.apply(` sites, so iteration 5 executes it.

## iter 5/10 | ed214ec6 | 2026-07-27 | T-044 | done

Task: T-044 (Medium, performance) - rolling().apply() with a per-window Python callback stood in for a vectorized expression at several sites, and WMA additionally rebuilt a pandas Series of weights on every window.

Changed: ta/trend.py (WMA weights as an ndarray), ta/volatility.py (Ulcer as a rolling mean of squares, and the now-unused Callable import removed), ta/volume.py (MFI masks once and rolls the sum), BACKLOG.md (T-044 closed, settled class), JOURNAL.md (this entry).

Checkpoint: f713ef7247e13262fa2c8867bd71ebe84d56ddbc

Verification: Verify command 206 tests OK, exit 0. prospector 0 messages on ta/ and on test/ at veryhigh, isort clean, black 25 files unchanged after one reformat it asked for. Output was compared by materialising the pre-fix package from git into a separate directory and running both under subprocesses that assert which ta/__init__.py they loaded, so the two series come from two real packages rather than from memory. On 20000 real rows: WMA 581.3 ms to 21.0 ms at 27.7x with a maximum difference of exactly 0.0; UlcerIndex 39.4 ms to 1.5 ms at 26.4x, 6.7e-14 absolute and 4.1e-15 relative; MFI 114.8 ms to 2.0 ms at 57.4x, 3.4e-13 absolute and 3.4e-15 relative. Every NaN mask is unchanged. CCI and Aroon are byte-identical and unchanged in time, as intended, since they were not touched.

Four of the seven sites were declined rather than fixed, and the reason is memory rather than difficulty. CCI's mean absolute deviation centres each window on its own mean and Aroon's callbacks locate an extreme within the window, so neither has a cumulative-sum form. A sliding-window view does vectorize both exactly - 251.7 ms to 6.0 ms for CCI and 71.1 ms to 3.6 ms for Aroon, both at a difference of 0.0 - but it materialises an n-by-window array, which was measured at a 320 MB peak for CCI and 216 MB for Aroon on a million rows. Trading a third of a gigabyte for 42x in a library whose envelope is market-data frames of arbitrary length is the wrong side of the trade, so they stay as they are with that measurement recorded.

The end-to-end number is smaller than the per-indicator ones and is reported as measured rather than as the headline: add_all_ta_features on 50000 rows goes from 4.556 s to 4.016 s, 1.13x, removing 11.9 per cent of the time. The wrapper is now dominated by PSAR at roughly 3.2 s, whose Python loop is genuinely recursive and already Declined, so the remaining cost is in the one place this task was never going to reach.

WMA's fix is worth naming precisely because it is the cheapest kind. The weights were a pandas Series multiplied by the raw ndarray of each window, so every one of 50000 windows constructed a Series and went through pandas alignment. Making the weights an ndarray leaves the arithmetic identical - the comparison returns exactly 0.0 - and removes 96 per cent of the time. A convolution would have been another 130x on top, but it reorders the summation and shifts the result by 9e-13, so it was not taken: bit-identical output was worth more than speed the library does not need.

Closed: T-044 (Medium, performance) - three sites vectorized, four declined with measured cause, all seven enumerated.

Settled: a per-window Python callback standing in for a vectorized expression, closed by enumeration over all seven `.apply(` sites.

Learnings: A vectorization that is faster and exactly equal can still be the wrong change. CCI and Aroon vectorized to 0.0 difference at 42x and 20x, and the only reason to refuse them was a memory measurement that took one command to make. Speed comparisons that do not also measure allocation are half a comparison.

Next: BACKLOG.md has no open unblocked task, so iteration 6 audits. Three iterations this run have changed ta/, so that audit is the one that decides whether the run can converge.

## iter 6/10 | ed214ec6 | 2026-07-27 | AUDIT | audit

Task: BACKLOG.md held no unblocked task, so a full Improvement-mode audit was run with fresh evidence, aimed hardest at the three modules this run changed. It does not converge: it found a regression this run introduced two iterations ago.

Changed: BACKLOG.md (T-045 filed), PLAN.md (one Lesson), JOURNAL.md (this entry and the rotation below).

Checkpoint: 1e5fe8278afac6d583cae494c84b3d3f197ed7fe

Verification: Verify command 206 tests OK, exit 0. prospector 0 messages on ta/ and on test/ at veryhigh with all eight tools, isort clean, black 25 files unchanged. Coverage re-measured after this run's edits: 100 per cent of 1388 statements and 104 branches, every module at 100, the totals lower than the 1401 and 112 of the last run because the vectorization deleted code rather than because anything stopped being covered.

Dimension scores: correctness Medium - T-045. architecture, code quality, security, testing, error handling, documentation, dependency hygiene, performance and developer experience None. observability and UX skipped, no process to observe and no user-facing surface. Performance is None rather than skipped for the second run in a row, now that it is measured: what remains is PSAR's recursion, which is Declined.

The regression is mine, from iteration 5. Replacing a rolling.apply callback with a pandas rolling aggregation is only equivalent when the mask preserves NaN, and `mfr.where(mfr >= 0.0, 0.0)` does not: `NaN >= 0.0` is False, so a missing bar becomes 0.0 before pandas ever counts it, min_periods is then satisfied by a window that is actually short, and MFI reports a money flow computed as though the gap carried none. On 400 real rows with four bars blanked it returns 13 NaN where the pre-fix package returns 43, so 30 rows changed from an honest refusal to a plausible-looking number. `clip(lower=0.0)` preserves NaN and is the fix.

The other two sites from that iteration are clean, and this was checked rather than assumed. UlcerIndex squares before it rolls, so NaN survives into the mean and the mask is identical. WMA still uses rolling.apply and its mask is identical with a difference of 0.0. PSAR's new min and max were the other candidate, because Python's min is order-dependent around NaN, but on gapped input every PSAR accessor matches the pre-fix package exactly, mask and values, so the clamp rewrite is safe there.

The exposure is MFI alone and not a class. All 43 classes were constructed against a frame with bars 50 and 120 to 122 blanked, with RuntimeWarning raised as an error: none crashed and no accessor returned an all-NaN series. The rest of the audit is clean on fresh evidence. Both recompute sweeps were re-run against the changed code and all 62 accessors still agree with their cited definitions in the tail, the only flags being the two probe artifacts iteration 1 already settled, Aroon's tie policy and the signed Vortex difference.

Two green gates hid this. The suite passed because no test anywhere feeds gapped input, and coverage stayed at 100 per cent because the defect is a change of meaning on a line that is fully executed. Gaps are named in-envelope in the Operating envelope, so this is in scope rather than an exotic shape.

Learnings: A vectorization is only equivalent if the mask preserves what the aggregation counts. `where` fills the condition's false branch, and NaN makes every comparison false, so `where(x >= 0, 0)` silently converts missing to zero while `clip(lower=0)` leaves it missing; min_periods then sees a full window that is not one. Compare the NaN mask, not only the values, whenever a rolling.apply becomes a rolling aggregation.

Next: T-045 is a two-line change with a test that must fail against the `where` form, so iteration 7 executes it. The run cannot converge before that, and the audit that follows must be a fresh one.

## iter 6/10 | ed214ec6 | 2026-07-27 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines at 516, so all but the last 10 entries were moved to JOURNAL-archive.md.

Changed: JOURNAL.md (13 entries removed, preamble repaired), JOURNAL-archive.md (12 entries appended).

Checkpoint: 1e5fe8278afac6d583cae494c84b3d3f197ed7fe

Verification: 39 real entries before and 39 after, none lost and none duplicated by the move; JOURNAL.md holds the last 10, from iter 17/20 to this run's iter 6/10, and the archive ends at iter 16/20 immediately before them. JOURNAL.md is 258 lines and the archive 553. The two identical iter 10/10 WRAPUP headings in the archive are pre-existing, present twice in the committed file and twice after, from two runs that shared a session id.

The first attempt at the move damaged both files and the damage is recorded rather than hidden. Splitting on a line beginning "## iter " also matches the preamble's own heading-grammar example, so the split treated the tail of the preamble as an entry: JOURNAL.md lost everything after "Heading grammar, exactly:" and the archive gained that text as a spurious entry. Both were repaired by taking the preamble from the committed file, reinserting it, and deleting the single copy that had been appended to the archive, with the entry counts above checked afterwards. The archive itself records the same preamble being truncated in an earlier run, so this is the second time this file's example line has been mistaken for content.

Learnings: A journal whose preamble documents its own heading grammar contains a line that every naive entry-splitter will match. Split on the real grammar, `^## iter <digit>`, or skip the preamble explicitly, and check the entry count before and after a move rather than trusting the split.

Next: unchanged by the rotation - T-045 is the open task and iteration 7 executes it.

## iter 7/10 | ed214ec6 | 2026-07-27 | T-045 | done

Task: T-045 (Medium, correctness) - the MFI vectorization from iteration 5 masked with `where`, which turns a missing bar into a real zero, so windows containing a gap reported a money flow instead of declining to.

Changed: ta/volume.py (both masks use clip), test/unit/gaps.py (new, TestGappedInput), test/__init__.py (registers it), BACKLOG.md (T-045 closed, settled class extended), JOURNAL.md (this entry).

Checkpoint: bf309762b5762136c15593a6554a171393449f35

Verification: Verify command 208 tests OK, up from 206, exit 0. prospector 0 messages on ta/ and on test/ at veryhigh, isort clean, black 26 files unchanged after reformatting the new file, coverage 100 per cent of 1388 statements and 104 branches. Parity is restored exactly: against the pre-vectorization package materialised from git, with bars 50 and 120 to 122 blanked on 400 real rows, money_flow_index now returns 43 NaN as it did before rather than 13, its mask is equal under both fillna settings, and UlcerIndex and WMA remain equal as they already were. The new tests fail against the `where` form and pass against `clip`, with the loaded module path asserted and __pycache__ cleared on both sides.

The fix is `clip(lower=0.0)` and `clip(upper=0.0)` in place of `where(mfr >= 0.0, 0.0)` and `where(mfr < 0.0, 0.0)`. clip leaves NaN as NaN, so pandas still counts the bar as absent and min_periods refuses the short window; where filled it with zero and the window looked complete.

Writing the test corrected my model of the defect, which is the part worth recording. I first asserted that a gap disturbs exactly the `window` rows whose window contains it, and that held for UlcerIndex and WMA but failed for MFI at row 214 of a gap at 200. The cause is not the mask: MFI's direction term compares each bar with the one before, so a missing bar leaves the next bar's direction indeterminate, that bar contributes a real zero, and the window covering it differs too. A gap therefore reaches window+1 rows for MFI and window for the other two. That behaviour is inherent to the definition and predates the rewrite - the pre-vectorization package does the same, which the parity check confirms - so the test now encodes the true reach per accessor with the reason, rather than a tidier claim that is false.

Closed: T-045 (Medium, correctness) - MFI treats a gapped bar as missing again, and the NaN reach of a gap is pinned for all three rewritten accessors.

Learnings: The first version of a test is a hypothesis about the code, and a failing assertion is as likely to be wrong about the contract as the code is to be wrong about the behaviour. Mine was, and measuring where the clean and gapped series actually diverge distinguished a real defect I had fixed from an inherent property I had misdescribed; asserting the tidier claim would have pinned a falsehood.

Next: BACKLOG.md has no open unblocked task, so iteration 8 audits. That audit decides convergence, and it must be a fresh full pass because ta/ changed again this iteration.

## iter 8/10 | ed214ec6 | 2026-07-27 | AUDIT | converged

Task: BACKLOG.md held no unblocked task, so a full Improvement-mode audit was run with fresh evidence across every applicable dimension. It scores clean, and the run converges.

Changed: PLAN.md (one Lesson), BACKLOG.md (Converged line), JOURNAL.md (this entry). No code changed this iteration.

Checkpoint: d8fbefbdcae43eee502b528012f2077313abb0ea

Verification: Verify command 208 tests OK, exit 0, and still OK with FutureWarning and DeprecationWarning escalated to errors under pandas 3.0.5. prospector 0 messages on ta/ and 0 on test/ at veryhigh with all eight tools running, bandit among them; isort clean; black 26 files unchanged; coverage 100 per cent of 1388 statements and 104 branches with every module at 100. All six requirements files resolve. Evaluator: unavailable (this session carries a standing instruction not to spawn sub-agents, so the independent adversarial review the gate calls for was not run; recorded here and in the run report rather than worked around).

Dimension scores: correctness, architecture, code quality, security, testing, error handling, documentation, dependency hygiene, performance and developer experience all None. observability and UX skipped, no process to observe and no user-facing surface. No High, Medium or Low finding survived this pass.

The evidence, gathered fresh this iteration. Both recompute sweeps were re-run against the current code: 62 accessor comparisons across 41 of the 43 classes, each recomputed from the definition its docstring cites, and the only three flags are the two probe artifacts iteration 1 settled - numpy argmax resolving an Aroon tie to the oldest bar where the library correctly takes the most recent, and my taking an absolute value where vortex_indicator_diff is properly signed. The two path-dependent holdouts are covered separately: STC agrees with an independent Schaff implementation in the tail, and PSAR was corrected and pinned under T-043.

Properties: 168 accessor calls across all 43 classes under both fillna settings leave the caller's input Series byte-identical. Row counts of 0, 1, 2 and 3 across all 43 classes raise nothing with RuntimeWarning fatal. add_all_ta_features returns 94 columns and 86 finite features for prices of dtype float64, float32, int64, int32, Int64 and Float64. Documented ranges hold over 3000 rows for RSI, StochRSI, Stochastic, Williams %R, MFI, Ultimate Oscillator, STC, Aroon, ADX, Chaikin Money Flow and Ulcer, with no out-of-range value and no inf. All 80 README links into the published docs resolve. add_all_ta_features costs 4.221 s on 50000 rows.

Three of this audit's own probes reported failures that were the probe's fault and not the library's, and each was chased down rather than filed. An awk filter keyed on the second whitespace field silently passed every two-word indicator name, briefly making both recompute sweeps look flawless. `astype('Int64')` raised on prices carrying decimals, which is pandas refusing an unsafe cast in the setup line, not an indicator rejecting a dtype. `np.isfinite` raised over nullable columns in the reporting line, not in the code under test. Rerun cleanly, all six dtypes pass, which is the settled class holding rather than breaking.

T-007 remains the single backlog item, marked [b], because its fix changes published ATR and ADX warm-up values and needs the user decision recorded under Proposed. The Definition of done admits a blocked item whose reason is recorded and named in the run report, so it does not prevent convergence; it is named there.

Learnings: An audit that finds nothing has to earn that, and most of this iteration's effort went into distrusting its own instruments rather than the code. Three probes failed and none of the failures were real; the discipline that mattered was reproducing each in isolation before letting it near the backlog, because any of the three, written up as found, would have been a fabricated finding with a plausible traceback attached.

Next: the run ends here on convergence, at iteration 8 of a budget of 10, with the run report below.

## iter 8/10 | ed214ec6 | 2026-07-27 | AUDIT | converged

Task: Correction appended to the convergence iteration, not a rewrite of it. A stray zero-byte file named "=7.6" was found in the repository root while assembling the run report, after the Converged line had been written.

Changed: deleted the file "=7.6". No other change.

Checkpoint: ea9fa4f8411e6a391e8a8a92a1689128f6d10064

Verification: The file was empty, 0 bytes, and entered history at 1e5fe82, iteration 6's checkpoint. It is my own shell error, not project content: `pip install -q coverage>=7.6` was written unquoted, so the shell read `>=7.6` as a redirection and created the file, and that iteration's `git add -A` committed it. Verify command 208 tests OK, exit 0, after the deletion; the working tree is clean and `git ls-files` no longer lists it.

It is recorded here rather than quietly dropped because it changes what the convergence commit contains. The Definition of done asks that the only commits after the clean audit be fixes for what that audit filed plus loop state edits, and this is neither; it is the removal of an artifact that should never have been committed and that the audit itself should have noticed. The convergence claim rests on the audit's findings about the library, which are unaffected: no test, import, package manifest or requirements file ever referenced the file, and deleting it changes no output.

Learnings: `git add -A` commits whatever the iteration happened to leave behind, including files created by a mistyped shell redirect, and a diffstat over the whole run is what surfaced it - no per-iteration check did. Read the run's own diffstat before declaring a run finished, and quote any version specifier containing `>` or `<` passed to a shell.

Next: the run ends here on convergence, with the run report below.

## iter 9/10 | ed214ec6 | 2026-07-27 | AUDIT | converged

Task: The stop hook rejected iteration 8's convergence, reporting that the Verify command exited 2. The suite was green; the Verify command as PLAN.md defined it was not runnable. Fixed that definition and re-declared.

Changed: PLAN.md (the Verify command line, and the prose moved off it), BACKLOG.md (Converged line), JOURNAL.md (this entry). No code changed.

Checkpoint: aad8a305f7fccaf8527e88b97c02362c73c13437

Verification: The command itself was never failing. `.venv/Scripts/python.exe -m unittest discover` gives 208 tests OK at exit 0, as it has all run. What failed was the line the gate executes: PLAN.md read "Command: `...` run from the project root (the suite ...)", so whatever ran it received the command followed by prose. Reproduced rather than assumed - executing that line verbatim gives "run: command not found" at exit 127 in this shell, the same class of shell syntax failure the hook reported as exit 2. The Command: line now carries the command and nothing else, and extracting it the way a gate would, `grep -m1 '^Command: ' PLAN.md` with the backticks stripped, then running it, gives 208 tests OK at exit 0. Evaluator: unavailable (this session carries a standing instruction not to spawn sub-agents, so the gate's independent adversarial review did not run; recorded here and in the run report rather than worked around).

Convergence still holds on the substance. ta/ and test/ are byte-identical to d8fbefb, the commit of the clean full audit: `git diff --stat d8fbefb HEAD -- ta/ test/` is empty. Everything changed since that audit is state files plus the deletion of the stray zero-byte "=7.6", so the library this run declares converged is exactly the one iteration 8 examined against every dimension.

Stall check, as the rules require it be stated: this iteration changed only PLAN.md, BACKLOG.md and JOURNAL.md, and no BACKLOG.md item changed state. It is not a no-progress iteration - it repaired the gate that was blocking the run - but it touched no code, and iteration 8's entry does not carry the same note, so this is not a second consecutive one.

That the defect survived eight iterations is the point worth recording. Every iteration ran the Verify command by hand, saw it pass, and wrote that down; none ever ran it the way the gate does, by extracting it from PLAN.md. A command that is correct when a human runs it and broken when the harness runs it will pass every manual check for as long as anyone cares to repeat them.

Learnings: A machine-read field must be machine-readable, and the way to know is to read it the way the machine does. PLAN.md's Verify command carried helpful prose on the same line for eight iterations, and the helpfulness is what broke it. Test a configured command by extracting and executing it from its own configuration, never by typing what you believe it says.

Next: the run ends here on convergence, with the run report below.

## iter 10/10 | ed214ec6 | 2026-07-27 | T-007 | done

Task: Maintainer-directed work, not a loop iteration - the run had already converged and the loop state file was gone. The user asked for a decision on all three Proposed items and for the fixes to be made, which is the explicit approval those items required. It uses the tenth slot of the budget the run did not spend.

Changed: ta/trend.py (ADX warm-up arrays, EMAIndicator default window), ta/volatility.py (ATR warm-up array), test/unit/trend.py and test/unit/volatility.py (warm-up contracts), test/unit/delegates.py (the zero-true-range test sharpened), test/unit/defaults.py (accepted drift now empty), BACKLOG.md (T-007 closed, two settled classes, one declined, Proposed reduced to the one maintainer action), JOURNAL.md (this entry).

Checkpoint: 910508d7dc2b148b998b84a3e140e0ae9df8ad67

Verification: Verify command 210 tests OK, up from 208, exit 0. prospector 0 messages on ta/ and on test/ at veryhigh, isort clean, black 26 files unchanged, coverage 100 per cent of 1388 statements and 104 branches. All three new or rewritten tests fail against the pre-fix code, checked by restoring ta/trend.py and ta/volatility.py from HEAD with the loaded module path asserted and __pycache__ cleared either side.

T-007, decided as fix rather than freeze. A warm-up 0.0 is indistinguishable from a flat market's genuine 0, and every other indicator in the library emits NaN there, so there was no consistent published contract to protect - the project's own fixtures disagree, cs-adx.csv leaving warm-up blank where cs-atr.csv writes 0.0. Measured against the pre-fix package over 3000 real rows: every row defined by both is identical to 0.0, and the only change is 0.0 becoming NaN across exactly the warm-up spans, 13 rows for ATR at window-1, 15 for each directional indicator at window+1, and 27 for ADX at 2*window-1. fillna=True still fills all of them. add_all_ta_features keeps its 94 columns and trend_ema_fast is unchanged.

test/data/cs-atr.csv was deliberately left byte-identical, which departs from the acceptance line asking that fixtures agree with the implementation. Its 0.0 warm-up is the source spreadsheet writing empty cells as zero, and editing reference data so it agrees with a change I just made would destroy the independence that makes it evidence. The value tests compare the tail, so no computed row is affected, and the new test pins the warm-up the fixture does not. The discrepancy is recorded rather than papered over.

The Coveralls history rewrite, declined. Rotating the credential revokes it and leaves the string in history inert, so the rewrite adds no security; it needs a force push, which breaks every clone and which the constraints forbid. Rotation remains a maintainer action and stays under Proposed as the one item there.

The EMA drift, resolved toward 12. Neither period is more correct, so the decision rests on consistency, and the precedent was already set in this project: SMAIndicator was resolved by moving the class to its delegate's 12. EMAIndicator now does the same, so SMA and EMA share one default across class and delegate. EMAIndicator() with no window changes for 2973 of 3000 rows and now equals window=12 exactly; explicit windows and the wrapper are untouched, since the wrapper passes 12 and 26 by name.

One existing test failed and was sharpened rather than relaxed. test_adx_directional_indicators_are_zero_without_true_range asserted a flat market gives 0.0 across the whole series, which was only true because warm-up was also zero. It now asserts the warm-up is NaN and the defined rows are 0.0, so it distinguishes the two cases the fix exists to separate, and it still covers the zero-true-range branch it was written for.

Closed: T-007 (Medium, correctness) - ATR and all three ADX outputs report warm-up as undefined, with computed values unchanged.

Settled: a warm-up row published as a real zero, fixed class-complete; and the delegate-default class's last exception closed.

Declined: rewriting history to purge the Coveralls token, with the reason recorded.

Learnings: An acceptance line written months earlier can be wrong about the right thing to do. This one asked that the fixtures agree with the implementation, which taken literally meant editing a vendor reference sheet to match my own change. Satisfying the intent - no computed value moved, and the warm-up is now pinned by a test - was worth more than satisfying the letter, and the departure belongs in the record rather than in a quietly edited CSV.

Next: nothing open. BACKLOG.md carries no task in Now, Next or Later, and Proposed holds only the credential rotation, which is a maintainer action and never counted against convergence.

## iter 1/10 | 5364200a | 2026-07-27 | AUDIT | audit

Task: BACKLOG.md held no open task, so a full Improvement-mode audit ran against every applicable dimension. The ratchet was checked first and does not apply: `git diff --name-only aad8a30..HEAD` lists ta/trend.py, ta/volatility.py and four test files, so code has changed since the last Converged line and the cheap re-declaration is correctly denied. That change is iteration 10's maintainer-directed T-007 work, which no audit has yet examined, so this pass weighted its evidence toward it.

Changed: BACKLOG.md (T-046 and T-047 filed under Next), PLAN.md (one Lesson), JOURNAL.md (this entry). No code changed.

Checkpoint: 8caf2f041ed713186cd99760586033400961de7b

Verification: Verify command `.venv/Scripts/python.exe -m unittest discover` gives 210 tests OK, exit 0. prospector 0 messages on ta/ and 0 on test/ at veryhigh with all eight tools running, bandit among them; isort clean; black 26 files unchanged, and the Makefile's own `black --target-version py36 ta test` was run directly rather than assumed, exiting 0. coverage 100 per cent of 1388 statements and 104 branches, every module at 100. All six requirements files resolve at exit 0. add_all_ta_features costs 4.440 s on 50000 rows against 4.221 s recorded previously.

Dimension scores: documentation Medium (T-046) and testing Medium (T-047). correctness, architecture, code quality, security, error handling, performance, dependency hygiene and developer experience all None. observability and UX skipped - no process to observe, no user-facing surface.

The changed code was audited by materialising the pre-T-007 package from aad8a30 into its own directory and comparing 267 series across all 43 classes under both fillna settings on 3000 real rows, with each subprocess asserting the `__file__` it loaded. Everything that moved is accounted for. Under fillna=False the only changes are leading NaN runs of exactly the documented lengths: 13 rows for ATR at window-1, 15 for each directional indicator at window+1, 27 for ADX at 2*window-1, and 9 for the wrapper's volatility_atr at its window of 10. Under fillna=True the ADX family shifted from 0.0 to 20 on those same rows, which is `_check_fillna`'s designated ADX fill finally engaging on rows that used to hold a real zero and so never qualified for filling; it is the fix working, not a defect. EMAIndicator moved on 2987 of 2987 shared rows by up to 6.4 per cent, the intended consequence of the default window moving 14 to 12, and the class and its delegate now both report 12, as do SMAIndicator and sma_indicator, so the new docstring claim is true.

T-047 comes out of the one thing that comparison caught which the change itself did not record. KeltnerChannel with original_version=False builds an ATR internally at ta/volatility.py:258, so the new NaN warm-up propagates into its bands - but not at the default window=20 and window_atr=10, where ATR's 9-row warm-up hides entirely inside the centreline's 19-row one. At window=10 and window_atr=20 it is plain: rows 9 to 18 previously published hband == mband == lband with a width of exactly 0.0, a zero-width channel presented as three real values, and they are NaN now. The change fixed a latent defect in a downstream consumer, silently and with no test standing over it. keltner_channel_pband did not move, because its zero-denominator guard already returned NaN where the bands coincided.

T-046 is the record rather than the code. README.md:227 points users at RELEASE.md as the project changelog; RELEASE.md's newest row is 0.11.0 from 2023, `git log -- RELEASE.md` shows no commit from any run here, and the file is named in no journal entry across JOURNAL.md and JOURNAL-archive.md. Meanwhile the published surface has moved repeatedly - five renamed KeltnerChannel series, three changed default windows, OBV's rule, the warm-up NaN, and a ValueError now raised for a non-positive period. A user upgrading from 0.11.0 gets different numbers and different exceptions with no notice from the one document the README sends them to.

Findings the audit declined to file, recorded so the reasoning is auditable. Four series carry non-leading NaN on clean data: PSAR's up and down alternate by trend, keltner_channel_pband's guard fires on flat bars, and UltimateOscillator has interior NaN at rows 291 and 292 where seven consecutive bars at 4.29 give a zero true-range sum over the 7-bar window, which is the 0/0 case the zero-denominator class settled as NaN rather than inf. Row 27 looked like a fourth until traced: the true range needs a previous close, so the 28-bar sum is first defined at row 28 and the leading run is 28 rows, not 27. My reconstruction of true range disagreed with the library at row 0 only because pandas max skips NaN, which is the probe's artifact and not the library's. The Makefile's `--target-version py36` is stale against requires-python >=3.10 but produces byte-identical formatting today, and the Makefile is unchanged since the convergence commit, so under the ratchet rule it is neither a reproduced High nor a regression and is not filed.

Learnings: A change to a primitive that other indicators consume has to be re-probed at parameters chosen to expose the interaction, because the defaults can hide it completely. ATR's warm-up change is invisible through KeltnerChannel at the shipped defaults and obvious one parameter away, so a regression probe run only at defaults would have reported no change and been wrong. Recorded as a Lesson in PLAN.md.

Next: execute T-046 and T-047, worst-first by the order filed, then re-audit for convergence.

## iter 2/10 | 5364200a | 2026-07-27 | T-046 | done

Task: T-046 (Medium, documentation) - RELEASE.md, which README.md:227 presents to users as the project changelog, recorded nothing after its 0.11.0 row while the library's published behavior changed repeatedly.

Changed: RELEASE.md (an Unreleased block of 14 numbered items above the 0.11.0 row), BACKLOG.md (T-046 deleted), JOURNAL.md (this entry). No code changed.

Checkpoint: d4ff56bdae8a03b4c705b10e33ccc00ab6e7450b

Verification: Verify command 210 tests OK, exit 0. The acceptance probe checks all 14 named changes plus the block's placement and numbering, 16 checks, and passes 16 of 16. Run against the upstream package materialised from a890410 into its own directory, with the loaded `ta.__file__` asserted, it fails 13 of 16: the three that still pass are the two RELEASE.md structure checks, which read a file rather than the package, and the PSAR check, which delegates to the project's own test suite and so necessarily exercises the working tree. That is the demonstration that the acceptance discriminates rather than merely agreeing with the code it was written against.

Closed: T-046 (Medium, documentation) - the changelog now records every public behavior change since 0.11.0.

The enumeration was taken from the code, not from this project's own settled-class summaries, and that mattered. Both packages were dumped and compared over 600 real rows: 38 of 166 shared accessor series differ under one or both fillna settings, `SMAIndicator` is newly constructible without a window, and five delegate or class defaults moved. Six further changes are behavioural rather than value-level and were probed on both builds side by side - a period of 0 raises ValueError now against ZeroDivisionError before, an empty frame returns empty output against IndexError, and int64, int32, Int64 and Float64 prices all pass through add_all_ta_features against TypeError before.

Three claims did not survive that check and were corrected before the entry was written, which is the substance of this iteration. Ichimoku's look-ahead fix lives in the `visual=True` constructor path, which the accessor sweep never reaches because it builds every class with default arguments; probed directly, ichimoku_a moves from 25 undefined rows to 51 and ichimoku_b from 0 to 26, while the `visual=False` path is untouched, so the entry names the visual spans specifically. KAMA's collapse to a repeated seed under fillna=True was never a 0.11.0 defect at all: JOURNAL-archive.md records it as "mine", introduced by iteration 6's seeding change and fixed within the same run, and upstream KAMA yields 600 distinct values on this data, so listing it would have told users a bug was fixed that they never had. And the vectorization item claimed more than happened - `grep -n "\.apply(" ta/*.py` still lists WMA at ta/trend.py:252, because WMA kept its callback and merely stopped rebuilding a weights Series inside it, while only Ulcer Index and MFI became rolling aggregations and CCI and Aroon keep theirs on purpose.

The correction that would have been least visible is the KAMA one. It reads exactly like the other entries in the Settled classes list, it is backed by a real fix and a real test, and nothing in the current code contradicts it. Only the archived journal records that the defect was self-inflicted. A changelog is a claim about what users experienced, so a fix for a regression that never shipped does not belong in one, however genuine the fix was.

The block is dated Unreleased with the Version column left for the maintainer. Five of the fourteen items are breaking, including renamed series and moved defaults, so the version to cut is a decision about semantics rather than a bookkeeping step, and pyproject.toml still reads 0.11.0.

Learnings: A changelog entry is a claim about what users experienced, and the project's own records are the wrong source for it - they describe what the work did, which includes fixing regressions the work itself introduced. Diff the shipped package against the last released one and let that decide what is listed. Recorded as a Lesson in PLAN.md.

Next: T-047, the untested KeltnerChannel interaction with window_atr > window.

## iter 3/10 | 5364200a | 2026-07-27 | T-047 | done

Task: T-047 (Medium, testing) - no test covered KeltnerChannel(original_version=False) with window_atr > window, the configuration where T-007's ATR warm-up change altered published output.

Changed: test/unit/volatility.py (test_atr_warm_up_governs_bands_when_longer_than_centreline, a method on the already-registered TestKeltnerChannel), BACKLOG.md (T-047 deleted, settled class extended), JOURNAL.md (this entry). No code changed.

Checkpoint: 10a9d152a3566cc80011df37eb5e5237871fdc19

Verification: Verify command 211 tests OK, up from 210, exit 0. prospector 0 messages on test/ at veryhigh with all eight tools, black 26 files unchanged, isort clean. The test was shown able to fail rather than assumed to be: ta/volatility.py was restored from aad8a30, every __pycache__ directory removed, and the loaded module asserted before the run - `ta.volatility.__file__` reported C:\jeffy-evals\ta\ta\volatility.py and its AverageTrueRange._run source contained `atr = np.zeros(len(self._close))`, so the pre-fix code really was the code under test. Against it the test fails on both bands, "AssertionError: np.False_ is not true" at the isna assertion. The working copy was restored from HEAD by a shell trap that runs whether the check passes or fails, and `git status --porcelain ta/volatility.py` is empty afterwards.

Closed: T-047 (Medium, testing) - the ATR warm-up's effect on the Keltner bands is pinned at the parameters that expose it.

The test drives window=10 and window_atr=20 against the shipped cs-kc.csv, which reverses the default relationship: the centreline is defined from row 9 while the ATR is undefined through row 18. It asserts the centreline's own first valid row first, so a NaN band is attributable to the ATR rather than to the centreline, then that both outer bands are NaN across the ATR warm-up, defined at row 19, and separated by a positive width there. The width assertion is the one that names the defect: the pre-fix ATR filled its warm-up with 0.0, so hband and lband both equalled the centreline and a channel of exactly zero width was published as three real numbers.

Adding a method to TestKeltnerChannel needs no change to test/__init__.py, since the class is already imported there; only a new class would need registering. Stated because the reverse mistake, adding a class and not registering it, silently runs nothing.

Learnings: Nothing new about the loop; this iteration applied rules already recorded rather than discovering one. The two that carried it are the Lesson about clearing __pycache__ and asserting the loaded module path before trusting a fail-check, and the one filed in iteration 1 about probing a changed primitive through its consumers at parameters that expose the interaction. No Lesson added.

Next: BACKLOG.md holds no open task in Now, Next or Later, so iteration 4 runs a full audit, and that audit decides whether the run converges.

## iter 4/10 | 5364200a | 2026-07-27 | AUDIT | converged

Task: BACKLOG.md held no open task, so a full Improvement-mode audit ran with fresh evidence across every applicable dimension. It scores zero High and zero Medium in envelope, and the run converges.

Changed: BACKLOG.md (one Proposed item, Converged line), JOURNAL.md (this entry). No code changed.

Checkpoint: b961193f6a01f12fdd804c6348f98e3b6363bc7a

Verification: Verify command `.venv/Scripts/python.exe -m unittest discover` gives 211 tests OK, exit 0. prospector 0 messages on ta/ and 0 on test/ at veryhigh with all eight tools running, bandit among them; black 26 files unchanged; isort clean. coverage 100 per cent of 1388 statements and 104 branches. All six requirements files resolve at exit 0. add_all_ta_features costs 4.598 s and 4.894 s on 50000 rows. Evaluator: unavailable (this session carries a standing instruction not to spawn sub-agents, so the gate's independent adversarial review did not run; recorded here and in the run report rather than worked around).

Dimension scores: documentation Low, twice, both routed to Proposed for the reason given below. correctness, architecture, code quality, security, testing, error handling, performance, dependency hygiene and developer experience all None. observability and UX skipped - no process to observe, no user-facing surface.

The evidence, gathered this iteration. All 84 accessors across the 43 classes were computed under both fillna settings on 3000 real rows: no inf anywhere, nothing survives fillna=True as NaN, no filled series is constant where its unfilled twin varies, no caller's input Series is mutated, and the documented ranges hold for RSI, StochRSI, Stochastic, Williams %R, MFI, Ultimate Oscillator, STC, Aroon, ADX, Chaikin Money Flow and Ulcer. Row counts of 0, 1, 2 and 3 across all 43 classes raise nothing with RuntimeWarning fatal. add_all_ta_features returns 94 columns for prices of dtype float64, float32, int64, int32, Int64 and Float64. All 123 README links into the published docs resolve to real module attributes. No literal credential appears in any tracked file, and ta/ contains no eval, exec, pickle or subprocess call.

What this audit did that no previous one had: it ran the CI docs job. Four jobs are defined in .circleci/config.yml and the journal shows Sphinx mentioned only ever as a requirements pin, so the doc job's command had never been executed. Built here from a venv installed off requirements-doc.txt, `python -m sphinx -b html docs docs/_build/html` exits 0 and the HTML is produced, so the job is not broken - but it emits two warnings, and those are this audit's only findings. `language = None` at docs/conf.py:73 is a Sphinx 2 idiom that Sphinx 8 rejects outright, warning and falling back to 'en'; `html_static_path = ["_static"]` at line 100 names a directory that does not exist. With that, all four CI jobs have now been run locally: test, lint including the requirements resolution step, coverage, and doc.

Both findings are Low - the build succeeds, the published output is correct, and neither is visible to a reader of the docs - and both sit in docs/conf.py, which `git diff --name-only aad8a30..HEAD -- docs/` shows is unchanged since the convergence commit. PLAN.md's ratchet clause is explicit about that case: a finding in code unchanged since the convergence commit must be a reproduced in-envelope High or a regression traced to the new changes, and anything else is a Proposed item. These are neither, so they go under Proposed with the one-line fix for each named there, and Proposed items never block convergence. Recording the reasoning because the alternative was tempting: they are trivially fixable, and fixing them unasked would have been the rule bending to convenience.

Convergence rests on this pass. ta/ is byte-identical to the iteration 1 audit - `git diff --name-only 8caf2f0..HEAD` lists only BACKLOG.md, JOURNAL.md, PLAN.md, RELEASE.md and test/unit/volatility.py - so the library declared converged here is the one iteration 1 examined, plus two closed findings that touched documentation and tests only and no indicator code at all. The performance spread against earlier measurements, 4.2 to 4.9 s across the run, is machine noise for exactly that reason: no ta/ source changed between the readings, and the first 5.5 s reading was taken while the Sphinx install ran concurrently and was discarded and remeasured rather than reported.

Stall check, stated as the rules require: this iteration changed only BACKLOG.md and JOURNAL.md, and no task changed state, since the Proposed item and the Converged line are not tasks. It is not a no-progress iteration - it is the convergence decision - and iteration 3's entry does not carry the same note, so this is not a second consecutive one.

Learnings: A configuration file can be audited clean many times over and still have never been executed. Eight audits scored documentation None while the docs build had never once been run; reading .circleci/config.yml tells you what the jobs claim to do, and only running each command tells you what they do. Covered by the existing Lesson that a CI or Makefile config cannot be called working from inspection, so no new Lesson is added - the gap was in applying it to every job rather than to the ones an iteration happened to touch.

Next: the run ends here on convergence, with the run report below.
