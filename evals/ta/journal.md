# Journal - bukosabino/ta audit

An audit under Jeffy's method, not a /jeffy loop run: no iteration budget, no BACKLOG.md, no convergence gate. What Jeffy contributed is the discipline - the operating envelope fixes severity, the evidence rule forbids a finding without a reproduction, and the class rule forbids patching an instance when the idiom has other sites.

Everything below happened in a scratch clone. `C:\jeffy` was untouched until the artifacts were written at the end.

## Setup

Cloned `bukosabino/ta` at `a890410710a6e483c9ba08da7f3dd5089e4b9dff` (2026-03-18, "Update README.md"). Two venvs on CPython 3.13.8: pandas 3.0.5 / numpy 2.5.1, and pandas 2.2.3 for the version comparison. Two working copies of the source - `head/`, a pristine `git archive` of the HEAD tree, and `repo/`, the tree that received the fixes - so every before/after claim is a measurement, not a memory.

Facts checked before repeating any of them:

- 5,129 stars, MIT, not archived (`gh api repos/bukosabino/ta`).
- 155 open issues *including* pull requests; the honest split is **122 open issues and 33 open PRs** (`search/issues`).
- Last commit touching `ta/`: `9c70287`, 2023-11-02. Last commit touching any `.py`: `5654782`, same day. PyPI `ta` 0.11.0, uploaded 2023-11-02.
- GitHub Actions: `actions/workflows` and `actions/runs` both `total_count: 0`. Never any Actions workflow.
- **The brief's "zero CI, ever" is half wrong.** `.circleci/config.yml` exists and CircleCI runs. On HEAD, the commit-status API reports overall `failure` with three statuses, all `failure`, all 2026-03-18: `test_py36`, `doc`, `coverage`. Corrected in the report rather than repeated.

## Baseline

`python -m unittest discover` at HEAD: **134 tests, 2 errors**, identically on pandas 3.0.5 and 2.2.3. Both errors are `TypeError: assert_series_equal() got an unexpected keyword argument 'check_less_precise'` at `test/unit/momentum.py:338` and `:348` - the argument was removed in pandas 2.0. So the suite has been partly broken on every pandas a user can actually install since April 2022. Coverage at HEAD: 98 percent statements, 28 missed.

## The primary lead

`ta/trend.py:1030` writes `self._psar[i] = high2` next to `ta/trend.py:1032` writing `self._psar.iloc[i] = high1`, on a Series that inherits the caller's index (`self._psar = self._close.copy()`, `:977`).

First probe, synthetic 300-bar path, RangeIndex vs DatetimeIndex on pandas 3.0.5: output length 300 vs **306**, index dtype degraded to `object`, 94 of 300 rows differing, max relative error 5.09 percent. The write did not land on row `i` at all - it appended a new row labelled with the integer `i`. Six appended rows, one per time the `high2` branch fired.

Then the version split, which is the part worth stating carefully. On pandas 2.2.3 the same DatetimeIndex call is **correct**, emitting exactly the `FutureWarning` of issue #348. The deprecation completed in pandas 3, and completing it turned a loud warning into silent corruption. Issue #348 was the last audible signal.

Then the case nobody filed. `ta.utils.dropna` - which the README's quickstart tells you to call - leaves a *gapped integer* index. There the label reading is unambiguous, so pandas never warned, on any version. Ran the README quickstart verbatim on the library's own `test/data/datas.csv`, 46,306 bars:

- gapped integer index: `psar()` returns **46,465 rows**, 9,408 rows wrong, max absolute error **3,410.89** (2,132.6 percent). Same on pandas 2.2.3 as on 3.0.5.
- DatetimeIndex on pandas 3.0.5: 47,455 rows, 8,601 wrong, max 284.48.
- `psar_up`/`psar_down`, which is what `add_all_ta_features` writes into the frame, keep their length and are wrong on 3,133 and 6,353 rows.

48 of 50 synthetic seeds diverge. High, comfortably.

## Beyond the leads

Three mechanical sweeps over every public indicator function - 80 of them, discovered by reflection rather than by hand, so the enumeration cannot go stale:

1. **Index-agnosticism.** Same input, four index types. Two failures at HEAD, both PSAR. That is the whole class, measured rather than asserted.
2. **No dependence on future rows.** Compute on 300 bars, compute on the first 200, compare the overlap. Two failures: `kst` and `kst_sig`. This one was not in the brief. `ta/trend.py` passes `fill_value=self._close.mean()` to KST's four ROC shifts, substituting a whole-sample average for the missing warm-up. Row 14 reads -73.49 with the full series and -16.02 with the truncation. And the rows should not exist: the first defined KST bar is row 44, so 30 rows are fabricated. Lookahead bias in a trend oscillator, in a feature-engineering library. Second High.
3. **Shortest accepted input.** Every function at every length 1 to 59. Four fail, in two classes: ADX and ATR, both dying inside numpy with messages naming neither the indicator nor the parameter.

Then the class enumeration by hand, because the sweeps find symptoms and the class rule wants sites. `fill_value=<whole-series aggregate>` has **14 sites**, all in `ta/trend.py`: TRIX, Ichimoku, KST, DPO, Vortex. Tested one by one: only the 8 KST sites leak. The other 6 are latent, masked by a NaN that happens to sit downstream - and Ichimoku's is inert only because `visual` defaults to False. Removed all 14 rather than the 8 that bite.

The integer-subscript class: 43 sites in loop bodies, 39 on numpy arrays (safe by construction), 4 on a pandas Series by label. Three of those four are guarded by an explicit `reset_index(drop=True)` two lines above and are correct. The fourth is `:1030`.

## What did not reproduce

The Bollinger `ddof` lead. Issue #307 says `ddof=0` "is not the standard calculation". The project ships StockCharts' own worked example as `test/data/cs-bbands.csv`, with a published `20-day Standard Deviation` column. Measured: `ddof=0` reproduces it to **4.893e-07**; `ddof=1` misses by **5.824e-02**. The library is right and the issue is wrong. Adopting `ddof=1` would inflate every band half-width by `sqrt(20/19)` = 2.5978 percent and break the project's own reference. Recorded as a Low documentation finding - the docstring never stated the convention, which is why the question keeps getting asked - and pinned with a test asserting both directions so it stops recurring.

`psar_down_indicator` at `ta/trend.py:1086` reads `_psar_up` where it means `_psar_down`. Looked like a second correctness bug; measured, it is not. The two series are disjoint by construction (0 overlapping non-null rows over 400 bars), so the expression yields NaN exactly where the condition holds and the following `.where(indicator == 0, 1)` maps that NaN to 1. Correct by accident. Filed Low, fixed anyway, output verified byte-identical.

## The prior partial patch

Read `partial/ta/fixes.patch` and kept nothing on trust. Its `_check_length` idea was right and independently re-derived; its ADX threshold of `2 * window` on `_run` was **too strict** - measured, `_run` only needs `window + 1`, and `2 * window` is a constraint of `adx()` alone, so `+DI`/`-DI` would have been withdrawn from inputs that can compute them. Split accordingly. Its Bollinger conclusion (ddof=0 is correct, document it) matched what the reference file independently showed. Its `others.py`/`volume.py` length guards were dropped: the sweep showed those functions accept a single row without error, so the guards were solving a problem that was not there.

## Fixes and verification

Boundary fix for PSAR: the recursion moved off pandas entirely onto numpy buffers, with the three Series built once at the end. Not a one-character `.iloc` patch - the class rule wants the site closed so it cannot recur, and this also deletes twelve `.iloc` calls from a hot loop.

The check that mattered most: recomputed **all 80 public indicator functions at HEAD and after the patch** on identical input. **76 are bit-identical.** The 4 that move are exactly the 4 findings - `adx_pos` and `adx_neg` at row 14, `kst` at rows 14-43, `kst_sig` at rows 14-51. Nothing changed that the report does not name.

Patch applies cleanly to a fresh `git archive` of HEAD. There: **147 tests, OK** on pandas 3.0.5 and on pandas 2.2.3. `repro.py`: 12/12 pass, against 10 failures at HEAD on pandas 3.0.5 and 8 on pandas 2.2.3. Coverage 98 to 99 percent, missed statements 28 to 7.

One self-inflicted mistake worth recording: running `black` across `ta/` and `test/` reformatted `ta/volume.py` and `test/unit/volume.py`, neither of which this audit touched - HEAD is not clean under black 23.10.1, the version the project itself pins. Reverted both, so the diff contains only intended change. Checking the formatter's blast radius before accepting its output is cheaper than explaining churn in a receipt.

## Left alone

The CI matrix, the `requirements-core.txt` / `setup.py` pin gap, and the two observable behaviour changes (KST's warm-up going NaN, `adx()` raising below `2 * window`) all went under Proposed. They are maintainer decisions about a supported range and a release note, not an auditor's to make. The committed Coveralls token was removed but never exercised - a credential in a public repo is the finding; abusing it to prove the point would not have been.
