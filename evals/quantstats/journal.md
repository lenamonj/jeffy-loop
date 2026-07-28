# Journal archive

Rotated entries from JOURNAL.md, oldest first. Append-only and cumulative across every rotation and every run; entries are never rewritten or removed.

## iter <i>/<N> | <run-id> | <YYYY-MM-DD> | <task-id or AUDIT or RATCHET or WRAPUP or SALVAGE or ROTATION> | <done|blocked|audit|converged|salvage|rotation>

SALVAGE entries take status salvage; ROTATION entries take status rotation.

run-id is the first 8 characters of the session id, a hyphen, then the HHMMSS of started_at from the loop state frontmatter, so two runs in one session are told apart. Body fields, in order: Task, Changed, Checkpoint (the jeffy checkpoint commit hash, or none with the reason), Verification, Learnings, Next.

The closing entry that declares convergence carries the evaluator verdict in its Verification field: `Evaluator: PASS - <one-line summary>`, or `Evaluator: unavailable (<reason>)`.

Closed tasks are recorded here as one line each (ID, title, closing evidence), because BACKLOG.md deletes them. Rotation: when this file exceeds 500 lines, move all but the last 10 entries to the end of JOURNAL-archive.md, appending to whatever that file already holds and never overwriting it, because the archive accumulates across every rotation and every run; create it only when it does not already exist, and record the rotation as a ROTATION entry.

## iter 1/10 | 108fe671-023502 | 2026-07-28 | AUDIT | audit

Task: First audit of quantstats in Improvement mode. Filled the Operating envelope, the Surface inventory and the Verify command in PLAN.md, then swept the public surface breadth-first and filed findings.

Changed: PLAN.md (envelope surfaces, 8 inventory rows, Verify command, 3 Lessons), BACKLOG.md (QS-1..QS-5), JOURNAL.md, .gitignore (jeffy loop state).

Checkpoint: 0522e84

Verification: Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0, 125 passed in 17.84s, on the unmodified tree. Sweep evidence: 160 probes across quantstats.stats, plus executed probes of utils, plots, reports, montecarlo and extend_pandas under the Agg backend. QS-1 reproduced deterministically in a fresh process (metrics without benchmark, then metrics with benchmark, raises ValueError at reports.py:1771) and proved causal by clearing utils._PREPARE_RETURNS_CACHE between the two calls, which makes the second call pass; instrumenting _prepare_returns showed cache key 14090705321164089685_0.0_None serving a (756,1) DataFrame to a caller that passed a (756,) Series. QS-2, QS-3, QS-4 each reproduced from a clean cache. QS-5 confirmed against the four functions' docstrings, which specify pd.Series.

Scores, claiming only the 6 swept inventory rows of 8: correctness High (QS-1, QS-2), architecture Medium (process-global mutable cache keyed on an incomplete input set is the root cause of QS-1), testing Medium (125 tests pass while the two-call reports workflow crashes; the gap is closed by the QS-1 and QS-2 acceptance tests, not filed separately), error handling Low (QS-5), security None (no eval, exec, pickle, subprocess or shell use in the package; the only network surface is machine-generated yfinance data and it is unswept), documentation None (README montecarlo example at line 30 executed as written and returned a MonteCarloResult; the four benchmark-relative docstrings match their real contract), dependency hygiene None (declared floors pandas>=1.5.0 and numpy>=1.24.0 resolve to pandas 3.0.5 and numpy 2.5.1 with a green suite), performance not scored (deferred to QS-1, whose fix must decide whether the cache earns its keep). Observability and UX/accessibility do not apply: quantstats is an importable library with no service surface and no interactive UI. Two rows are unswept, _compat/_numpy_compat and the yfinance download path, so these scores are not yet the whole project.

Learnings: The repo venv must be invoked explicitly as .venv/Scripts/python.exe. Probe scripts need matplotlib.use("Agg") before pyplot and must not shadow a stdlib module name. utils._PREPARE_RETURNS_CACHE is process-global, so any cross-call measurement must clear it first or an earlier call silently changes the result. Several first-pass sweep failures were probe errors, not defects: plots.drawdown's second positional is grayscale, not benchmark, and the montecarlo simulation-count argument is sims, not num_simulations.

Next: QS-1, the highest-severity finding and the root cause behind the most user-visible crash.

## iter 2/10 | 108fe671-023502 | 2026-07-28 | QS-1 | done

Task: QS-1 (High, correctness) - utils._prepare_returns returned the wrong container type on a cache hit, so any benchmark-free reports call poisoned the next benchmark call in the same process.

Changed: quantstats/utils.py (deleted _PREPARE_RETURNS_CACHE, _CACHE_MAX_SIZE, _cache_lock, _generate_cache_key, _clear_cache_if_full and the threading import; replaced inspect.stack()[1][3] with inspect.currentframe().f_back.f_code.co_name), quantstats/reports.py (strategy-title column assignment at two sites, single-group MultiIndex collapse in _calc_dd), tests/test_regressions.py (new, 5 tests), PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: f65fcf4

Verification: The 5 new tests in tests/test_regressions.py were run against the unfixed code first and all 5 failed, three with AttributeError: 'DataFrame' object has no attribute 'dtype' and two with ValueError: The truth value of a Series is ambiguous; all 5 pass after the fix. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 130 passed in 19.78s. Differential against the previous checkpoint's utils.py, loaded side by side and driven with a cold cache over 5 input shapes times 3 (rf, nperiods) settings, found 0 differences in 15 comparisons, so the deletion removed only the broken reuse and changed no computation. A/B on reports.metrics(mode="full") over 10 years of daily data: 450.6 ms with the old cached implementation against 361.2 ms without the cache, 19.8% faster, because the work the cache was hiding was a 4 ms inspect.stack() call per invocation (measured: inspect.stack()[1][3] 3936.9 us, inspect.currentframe().f_back.f_code.co_name 0.059 us, the pandas preparation work itself 133.2 us, the cache key 102.6 us) and both frame lookups were confirmed to return the same caller name.

Contract preserved: _prepare_returns keeps its signature, its return values and its caller-name branch for the four functions in unnecessary_function_calls; the only behavioural change is that a repeated call now returns the container type it was given instead of whatever a value-hash collision had stored. The two reports.py repairs are collateral from that fix, not new scope: the test test_html_with_dataframe had been passing only because the cache silently substituted a Series for the caller's one-column DataFrame, so removing the substitution exposed reports.py assigning a bare string to DataFrame.columns and _calc_dd addressing a MultiIndex by its inner label. Both were repaired so the single-column DataFrame path genuinely works rather than appearing to.

Verify gate: the gate went red on the first run of this iteration with test_html_with_dataframe failing, and was brought green within the allowed fix attempts rather than reverted, because the failure was the newly reachable pre-existing defect described above and not a regression in the QS-1 change itself; the differential above is the evidence that the change altered no computed value.

Learnings: A green test can be green because of the bug, not despite it. Removing the container-type confusion turned test_html_with_dataframe red, and the test was right both times: the behaviour it asserts was previously reached by the wrong route. Measure before caching: the cache here existed to hide a 4 ms inspect.stack() call, and deleting it made the library faster, smaller and correct at once.

Next: QS-2, the remaining High, which is the separate single-column DataFrame defect in reports.metrics (UnboundLocalError on blank) and still reproduces.

## iter 3/10 | 108fe671-023502 | 2026-07-28 | QS-2 | done

Task: QS-2 (High, correctness) - reports.metrics raised UnboundLocalError for a single-column DataFrame. Closed as a class rather than an instance, because it was the third finding sharing one root cause.

Changed: quantstats/reports.py (new _strategy_titles boundary helper, five derivation sites routed through it, blank binding, and the two instance patches from iteration 2 simplified away), quantstats/_plotting/wrappers.py (snapshot reduces a one-column frame to a series), tests/test_regressions.py (3 targeted tests plus a 5-way parametrized entry-point test), BACKLOG.md, JOURNAL.md, PLAN.md.

Checkpoint: 7ec226c

Verification: The two new QS-2 tests failed first with UnboundLocalError at reports.py:1313 and pass after a one-line binding fix; the differential test asserts the one-column frame result equals the equivalent Series result cell for cell, which is what makes the check strong enough to fail. The class enumeration then showed the fix was not complete: driving all nine report entry points plus plots.snapshot with a one-column frame left basic, full, plots, html and snapshot failing with TypeError: Index(...) must be called with a collection of some kind, 'Strategy' was passed, or ValueError: Length mismatch: Expected axis has 1 elements, new values have 8 elements, that second one because flatten() over the bare string "Strategy" yields its eight characters. After the structural fix the same probe reports 21 of 21 combinations ok across one-column and two-column frames. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 138 passed in 21.01s, up from 133.

Class closure: the three-strike rule applied. The two collateral repairs in iteration 2 and QS-2 itself were all instances of reports.py branching on "Series, or DataFrame with more than one column" and leaving the one-column case unhandled. Instance patching was therefore replaced by one boundary: reports._strategy_titles normalizes the caller's strategy title once, returning a plain string for a Series and one title per column for any DataFrame, so no consumption site needs to re-test the column count. The enumeration is grep -rn "\.columns = " over quantstats/, which finds 27 assignment sites of which only four carry a strategy title (reports.py:390, reports.py:889, reports.py:1928, _plotting/wrappers.py:183); all four are now covered, and the remaining 23 assign literal lists, maps or comprehensions. Recorded under Settled classes.

Contract preserved: multi-column behaviour is unchanged at every site, since _strategy_titles returns list(returns.columns) for a frame with more than one column exactly as the five inlined blocks did, and Series input still receives the plain string it assigns to Series.name. The only behavioural change is that the one-column DataFrame path now works instead of raising. plots.snapshot additionally reduces a one-column frame to a series, matching what its multi-column path already did and what the rest of that function assumes.

Filed while working: QS-6 (Medium, documentation) - reports.metrics ignores its documented prepare_returns parameter, because the DataFrame it builds at reports.py:1251 is overwritten unconditionally four lines later; confirmed by metrics(prices, prepare_returns=True) and metrics(prices, prepare_returns=False) returning identical tables with zero differing rows.

Learnings: An enumeration is not optional dressing on a class fix. QS-2's own acceptance check passed after a one-line change, and the class was still broken at five other entry points; only the grep plus the entry-point probe revealed that. Normalizing a value once at its boundary removed more code than it added and let two earlier instance patches be deleted.

Next: QS-3, the multi-column DataFrame failure in plots.distribution.

## iter 4/10 | 108fe671-023502 | 2026-07-28 | QS-3 | done

Task: QS-3 (Medium, correctness) - plots.distribution documents "pandas.Series or pandas.DataFrame" but raised ValueError for a multi-column frame.

Changed: quantstats/_plotting/wrappers.py (distribution reduces a multi-strategy frame to its equal-weighted mean, marks the title, and its docstring records the reduction), tests/test_regressions.py (3 tests), BACKLOG.md, JOURNAL.md.

Checkpoint: c65b6f0

Verification: The 3 new tests failed first, the render test with ValueError: Length mismatch: Expected axis has 2 elements, new values have 1 elements raised at _plotting/core.py:1486 where port.columns = ["Daily"] meets a two-column frame, and all 3 pass after the fix. The differential test is the load-bearing one: it reads every Line2D y-value from the rendered axes and asserts they match the figure for frame.mean(axis=1) exactly while differing from the figure for frame["A"], so a fix that silently plotted the first column instead of the equal-weighted mean would fail it. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 141 passed in 20.65s, up from 138.

Contract preserved: Series input is untouched, and its title carries no aggregation marker, which the third test asserts directly. core.plot_distribution keeps its documented single-series contract; the reduction happens in the wrapper, which is the layer that advertises DataFrame support. The convention chosen is the one plots.snapshot already uses in the same module, equal-weighted mean plus a title marker, rather than a new one.

Class enumeration: sweeping all 19 qs.plots wrappers with a one-column and a two-column frame, 38 combinations, leaves 4 failures in 2 wrappers: drawdowns_periods raises KeyError "days" and earnings raises TypeError: type numpy.ndarray doesn't define __round__ method, both for one-column and multi-column frames, both fine for the equivalent Series, and both documenting "pandas.Series or pandas.DataFrame". With distribution they are three findings sharing one root cause, a wrapper advertising frames over a core that takes one series, so the three-strike rule applies and they are filed as the single structural task QS-7 rather than as two more instance fixes. The class is not settled until QS-7 closes.

Learnings: The sweep that closes a finding is also the sweep that finds its siblings; running the whole wrapper surface after fixing one wrapper cost one command and turned two unknown defects into one filed structural task.

Next: QS-4, the silent timezone mutation of the caller's Series in reports.metrics.

## iter 5/10 | 108fe671-023502 | 2026-07-28 | QS-7 | done

Task: QS-7 (Medium, correctness) - plots.drawdowns_periods and plots.earnings raised on any DataFrame input while documenting "pandas.Series or pandas.DataFrame". Taken as the structural task the three-strike rule required, closing the class that QS-3 opened.

Changed: quantstats/_plotting/wrappers.py (new _as_single_series boundary helper, distribution's inline reduction from iteration 4 replaced by it, drawdowns_periods and earnings routed through it, both docstrings updated), tests/test_regressions.py (6 parametrized tests plus two shared helpers), BACKLOG.md, JOURNAL.md.

Checkpoint: 96795e7

Verification: The 6 new parametrized tests were run against the pre-fix wrappers by stashing only quantstats/_plotting/wrappers.py: 4 failed and 2 passed, the 2 passing being the distribution cases already fixed in iteration 4, which is the expected shape for a class whose first instance was closed earlier. All 6 pass after the fix. The class enumeration, a sweep of all 19 qs.plots wrappers against a one-column and a two-column frame, now reports 0 failures across 38 combinations, against 4 failures in 2 wrappers before. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 147 passed in 20.66s, up from 141.

Contract preserved: Series input passes through _as_single_series untouched, so no existing behaviour moves. A one-column frame is unwrapped and produces a figure identical to the equivalent Series, which the first parametrized test asserts by comparing every plotted y-value. A multi-strategy frame is reduced to the equal-weighted mean, matching what plots.snapshot already did, and the title is marked; the second test asserts the drawn values equal the mean series and differ from the first column, so a reduction that silently picked one strategy would fail. Both changed docstrings now state the reduction.

One correction worth recording: the first run after wiring the helper still showed earnings failing, and the cause was the test helper, not the library. Equity curves begin with NaN and numpy.allclose reports False for any NaN unless equal_nan is set, so the comparison was rejecting two identical arrays. Fixed in the helper, then both directions were re-verified.

Learnings: When a differential test compares plotted values, pass equal_nan=True to numpy.allclose, because several quantstats plots begin with NaN and the comparison otherwise fails on identical data. Stashing only the implementation file is a cheap and exact way to prove a new test fails against the unfixed code after the fix is already written.

Next: QS-4, the silent timezone mutation of the caller's Series in reports.metrics.

## iter 6/10 | 108fe671-023502 | 2026-07-28 | QS-4 | done

Task: QS-4 (Medium, correctness) - reports.metrics wrote through to the caller's own returns object, stripping the timezone from its index. Closed as the class "writing through to the caller's returns object" rather than the single site.

Changed: quantstats/reports.py (metrics copies when match_dates=False, the branch where dropna did not already copy), quantstats/_plotting/wrappers.py (snapshot uses rename() instead of assigning .name), tests/test_regressions.py (2 targeted tests plus a 6-way parametrized class check and a _fingerprint helper), BACKLOG.md, JOURNAL.md.

Checkpoint: d842918

Verification: The class was enumerated before any fix, by a probe that fingerprints values, index, index timezone, name and columns of the caller's objects across 16 entry-point calls. It found exactly two offenders: reports.metrics(match_dates=False) altering the index timezone, and plots.snapshot altering the series name. The same probe now reports 0 mutations, under both tz-aware and tz-naive input. The 3 failing tests, confirmed failing first, pass after the fix. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 155 passed in 21.28s, up from 147.

Contract preserved: no return value changes. metrics already worked on a copy whenever match_dates was true, which is the default, so the added copy only covers the match_dates=False branch and no caller sees a different table. snapshot's rename() produces the same renamed series it drew before, it simply stops renaming the caller's object on the way.

One test-design correction worth recording: the first version of the snapshot test passed against the unfixed code, because the shared returns fixture is already named "Strategy" and that is exactly the name snapshot assigns, so the mutation was invisible. Renaming the series to something snapshot would not choose made the check able to fail, and it then did. A check that cannot fail proves nothing, and this one needed the input chosen adversarially rather than conveniently.

Filed while working: QS-8 (High, correctness) - the mutation probe crashed several entry points before it could measure them, which turned out to be a defect rather than probe error. When returns and benchmark are both tz-aware, reports.metrics, basic, full, html and stats.greeks all raise TypeError: Cannot compare dtypes datetime64[us, America/New_York] and datetime64[us] at utils.py:653, because metrics strips the timezone from returns at reports.py:1223 and leaves the benchmark tz-aware, so _prepare_benchmark compares a naive index against an aware one. Tz-aware returns without a benchmark work, and tz-naive input works throughout.

Learnings: Choose fixture values an implementation would not pick by accident. A mutation test whose "before" value matches what the buggy code writes is silently vacuous. A probe that raises where it meant to measure is reporting a second defect, not failing.

Next: QS-8, the new High, which the tz handling in metrics causes directly.

## iter 7/10 | 108fe671-023502 | 2026-07-28 | QS-8 | done

Task: QS-8 (High, correctness) - every benchmark-carrying report raised TypeError when returns and benchmark were both tz-aware.

Changed: quantstats/utils.py (_prepare_benchmark normalizes the benchmark's and the period's timezone before the alignment block instead of after it), quantstats/reports.py (comment recording why metrics keeps the local timestamp), tests/test_regressions.py (4 tests), BACKLOG.md, JOURNAL.md.

Checkpoint: 9fd9b05

Verification: The 4 new tests failed first with TypeError: Cannot compare dtypes datetime64[us, US/Eastern] and datetime64[us] and pass after the fix. The entry-point probe that had 6 of 16 calls raising under tz-aware input now reports all 16 clean, and still reports 0 caller mutations. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 159 passed in 23.87s, up from 155. The load-bearing check is a full-table differential: metrics(mode="full") over tz-aware returns in US/Eastern, Asia/Tokyo, UTC and Europe/London, 75 rows by 4 zones, compared cell by cell against the previous checkpoint, 0 differing cells of 300.

Root cause: _prepare_benchmark normalized the benchmark's timezone after the block that reindexes it onto the strategy's period, so the reindex compared an aware index against the naive one metrics had already produced. Moving the normalization above the alignment, and normalizing the period the same way, fixes it for either argument being the aware one.

A wrong first attempt, corrected by the differential: I first made reports.metrics convert to UTC before dropping the timezone, on the reasoning that 10 of the 12 normalization sites in the package do it that way and metrics was the outlier. The tests went green. The four-zone differential then showed 19 of 300 cells changing, with Asia/Tokyo and Europe/London shifting Start Period, End Period, Max DD dates, YTD, Best Year, Worst Year and the Win Month, Quarter and Year rates, because converting a midnight Tokyo bar to UTC moves it to the previous day. The majority convention was the wrong one to adopt: for daily bars the label is the trading date, and it must not move. The fix was inverted so _prepare_benchmark drops the zone keeping local time, matching metrics, and the differential then showed 0 of 300 cells changed.

Contract preserved: no previously working call changes its output, which is what the 0 of 300 differential states. The change is purely additive in capability, turning six crashing entry points into working ones.

Filed while working: QS-9 (High, correctness) - the two conventions still coexist elsewhere. qs.stats.monthly_returns on an Asia/Tokyo series beginning 2020-01-01 returns rows for 2019, 2020 and 2021, while qs.reports.metrics on the identical data covers 2020 to 2021, because _prepare_returns converts to UTC and moves the first bar to 2019-12-31 15:00. One library disagreeing with itself about which year a return falls in is a defect whichever convention is preferred, and the remedy is one convention at every site, which is why it is filed as a structural task rather than another patch.

Learnings: When a change makes failing tests pass, that is not evidence it changed nothing else. The differential across four timezones is what caught a regression the whole suite plus four new targeted tests had missed. Prefer the convention that preserves the data's own meaning over the one with more occurrences; counting call sites is not an argument about correctness.

Next: QS-9, unifying the timezone convention across the package.

## iter 8/10 | 108fe671-023502 | 2026-07-28 | QS-9 | done

Task: QS-9 (High, correctness) - the package dropped timezones two different ways, so the same dataset reported two ways disagreed about which calendar period a return belonged to. Closed as the structural task the class required.

Changed: quantstats/utils.py (4 sites), quantstats/stats.py (4 sites, and the compare() benchmark branch rewritten), quantstats/_compat.py (1 site), tests/test_regressions.py (10 parametrized tests), BACKLOG.md, JOURNAL.md.

Checkpoint: bb737f4

Verification: 4 of the 10 new tests failed first, all on Asia/Tokyo and Europe/London, and all 10 pass after the fix; the US/Eastern cases passed throughout because a midnight New York bar converted to UTC stays on the same date, which is exactly why the defect had gone unnoticed. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 169 passed in 24.49s, up from 159. The convention is now uniform: grep -rn "tz_convert" over quantstats/ returns nothing. Evidence that nothing else moved: a combined table of metrics(mode="full"), monthly_returns, aggregate_returns and compare over tz-naive data is byte-identical to the previous checkpoint, sha256 6daae8355806e8c5 both sides, and the four-timezone tz-aware metrics table is unchanged from the iteration 6 baseline as well. The intended changes are visible where they should be: for an Asia/Tokyo series starting 2020-01-01, stats.monthly_returns now reports 2020 and 2021 rather than 2019, 2020 and 2021.

Second defect fixed by the same change, with evidence: stats.compare normalized a DataFrame benchmark column by column, assigning a naive-indexed series back into a frame whose index was still tz-aware. Pandas aligned on the index and produced an all-NaN Benchmark column, silently, for every tz-aware DataFrame benchmark. Reproduced before the change (Benchmark column all-NaN True, first row labelled 2019-12-31 15:00:00) and confirmed after (all-NaN False, first row 2020-01-01). Normalizing the whole object's index once removes both the misalignment and the second convention.

Contract preserved: tz-naive input, which is the overwhelmingly common case and everything the existing suite covers, is byte-for-byte unchanged. Only tz-aware input changes, and it changes to agree with the reports path and with the data's own trading dates.

A harness correction worth recording: the first tz-naive differential reported 1202 of 1620 cells differing, which would have meant a serious regression. It was my comparison, not the library: the table mixes stringified frames with NaN padding from concat, and NaN compares unequal to itself. Comparing the two CSV files byte for byte gave the real answer, identical.

Learnings: Compare artifacts by bytes when the content is heterogeneous; cell-wise comparison of a frame containing NaN reports differences that are not there. A defect that only manifests east of Greenwich will pass every test written in a US timezone, so timezone tests must parametrize over zones on both sides of UTC.

Next: QS-6, the documented but inert prepare_returns parameter in reports.metrics.

## iter 9/10 | 108fe671-023502 | 2026-07-28 | QS-6 | done

Task: QS-6 (Medium, documentation) - reports.metrics documented a prepare_returns parameter that did nothing, because the prepared frame was built and then overwritten one line later.

Changed: quantstats/reports.py (prepare the returns series itself rather than a discarded frame), tests/test_regressions.py (3 tests), BACKLOG.md, JOURNAL.md.

Checkpoint: e5681f8

Verification: 2 of the 3 new tests failed first, the third passing by design because it asserts the flag does not disturb already-prepared returns, which was trivially true when the flag did nothing; all 3 pass after the fix. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 172 passed in 24.87s, up from 169. The differential is byte-identical: a combined table of metrics(mode="full"), monthly_returns, aggregate_returns and compare over ordinary tz-naive returns is unchanged from the previous checkpoint, so the common path did not move. The intended change is confirmed where it belongs: metrics(prices) now equals metrics(to_returns(prices)) exactly, and metrics(prices, prepare_returns=False) now differs from metrics(prices, prepare_returns=True), which is the flag having an effect for the first time.

The finding was resolved by honouring the documented promise rather than deleting it, which the acceptance check allowed either way. Honouring it was the better option because the parameter is public, every sibling stats function honours the same flag, and the change is a no-op for returns input while making price input correct instead of subtly wrong.

Contract preserved: preparing the series rather than a throwaway frame also repairs a quieter inconsistency in the same function. The benchmark branch writes returns back into the frame with df["returns"] = returns, so it had been re-injecting raw values over the constructed frame; both now refer to the same prepared series. Preparation returns a new object, so nothing is written through to the caller and the mutation class settled in iteration 6 stays settled, which the parametrized mutation test confirms.

Learnings: A parameter that does nothing can hide a second inconsistency behind it. The dead assignment was easy to spot; the raw-values-over-prepared-frame write in the benchmark branch only became visible once the preparation had somewhere real to go.

Next: the final iteration is a wrapup. The run cannot converge: the Surface inventory lists 8 unswept rows of 8, because _prepare_returns and the report and plot paths were rewritten under them, and QS-5 remains open.

## iter 10/10 | 108fe671-023502 | 2026-07-28 | WRAPUP | done

Task: Final iteration of the budget. Tidied BACKLOG.md and wrote the handoff instead of starting QS-5, which could not have been finished and verified inside the remaining turn.

Changed: JOURNAL.md only. Stall note: this iteration changed no file outside the state files and no BACKLOG.md item changed state, which is the expected shape of a wrapup and not a stall; the previous primary entry closed QS-6 with code changes, so the no-progress rule is not triggered.

Checkpoint: cea4b52

Verification: Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 172 passed in 24.86s, against 125 passed at the start of the run. Working tree clean at the start of this iteration.

The run does not converge, and the reasons are specific rather than a matter of budget alone. The Surface inventory in PLAN.md lists 8 unswept rows of 8: the six that were swept at 8b7916e went stale because utils._prepare_returns, the reports entry points and the plot wrappers were all rewritten beneath them, and the remaining two, the pandas and numpy compatibility shims and the yfinance download path, were never swept at all. QS-5 also remains open. Declaring convergence would require a fresh full audit over a surface that has not been re-examined since the code changed, which is exactly the claim the inventory exists to prevent.

Handoff for the next run, which should start in a new session so the context is clean. Re-sweep the Surface inventory first: the enumerating checks that closed each class are recorded under Settled classes in BACKLOG.md and are cheap to rebuild, the four that matter being the mutation fingerprint probe across the public entry points, the 19-wrapper plot sweep against one-column and two-column frames, the byte-level differential of a combined metrics, monthly_returns, aggregate_returns and compare table against the last checkpoint, and grep -rn "tz_convert" over quantstats/ which must stay empty. Two inventory rows have never been examined and are the likeliest place for the next real finding: the compat shims against the installed pandas 3.0.5 and numpy 2.5.1, and utils.download_returns with safe_yfinance_download, which needs a stubbed yfinance so the sweep stays offline. Then work QS-5, the only open task. The five settled classes must not be re-filed unless their implementing code changed.

Learnings: The Surface inventory is what kept this run honest. Six rows were swept in iteration 1 and every one of them was invalidated by later fixes, so a run that had reported "swept, clean" would have been claiming certainty about code that no longer existed. Recording the enumerating check alongside each settled class is what makes the next run cheap: the checks outlive the session that wrote them, while the scratch scripts do not.

Next: a new session, starting with the inventory re-sweep, then QS-5.

## iter 1/10 | 5d706f1a-035757 | 2026-07-28 | QS-5 | done

Task: QS-5 (Low, error handling) - stats.r_squared, information_ratio, greeks and rolling_greeks document returns as pd.Series but met DataFrame input with opaque numpy and pandas errors. Reproduction showed the backlog line understated it: r_squared with a one-column DataFrame raised nothing and returned an ndarray of shape (n,) where the docs promise a float, a silently wrong result rather than a bad message.

Changed: quantstats/utils.py (validate_input gains name= and require_series= keyword arguments; defaults keep the existing 12 call sites' messages byte-identical), quantstats/stats.py (the four functions route returns through validate_input(name="returns", require_series=True) before any preparation, and their docstrings document the raise), tests/test_stats.py (TestBenchmarkArgValidation, 10 parametrized cases over 5 functions x one- and two-column frames), BACKLOG.md, JOURNAL.md.

Checkpoint: 940b03a

Verification: all 10 new cases failed before the fix with the opaque errors (and, for r_squared one-column, no error at all), and all 10 pass after; tests/test_utils.py::TestValidation still passes, confirming the boundary's existing contract is untouched. Acceptance enumeration executed as written: the AST enumeration finds exactly 7 stats functions taking a benchmark argument - r_squared, information_ratio, greeks, rolling_greeks routed directly; r2 routed by delegation to r_squared; treynor_ratio explicitly handling DataFrame by first-column selection then routed through greeks; compare explicitly supporting DataFrame - and the behavioral spot check shows every rejection message names the returns argument with a remediation hint. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 182 passed, up from 172.

Contract preserved: reports.py and _plotting/core.py both branch on Series vs DataFrame and only ever pass a Series into these four functions, confirmed by reading the call sites at reports.py:1432-1455, reports.py:1680-1716 and core.py:1142-1172, so no internal path changes behavior. Series input follows the same code path as before apart from the added validation, the docstring RangeIndex examples still validate, and the require_series check sits before validate_input's index-conversion block so a rejection happens before any index mutation. treynor_ratio's silent first-column DataFrame selection is pre-existing explicit handling and was left as is, recorded in the enumeration.

Discovered and filed rather than fixed, one task per iteration: validate_input converts a non-datetime, non-range index in place, writing through to the caller's object at every routed call site; filed as QS-10 (Low) with the routing done here making the eventual fix a single-boundary change.

Learnings: The one-column r_squared case returned a wrong-shaped result with no exception, exactly the wrong-numbers-without-complaint failure mode the known-answer sweep rule exists to catch; a liveness probe would have certified it clean.

Next: fewer than 3 open tasks remain and the Surface inventory lists 8 unswept rows of 8, so the next iteration is the replenishing audit, sweeping stale rows first.

## iter 2/10 | 5d706f1a-035757 | 2026-07-28 | AUDIT | audit

Task: Replenishing partial audit - fewer than 3 open tasks remained and the Surface inventory listed 8 unswept rows of 8. Per the Method, swept the least-recently-swept rows first: the two never-swept rows, the _compat/_numpy_compat shims and the yfinance download path.

Changed: PLAN.md (two inventory rows flipped to swept at c3ceee2), BACKLOG.md (QS-11 filed in Next, QS-12 filed in Later), JOURNAL.md. No package code changed.

Checkpoint: 66f2f7a

Verification: 37 known-answer and enumeration probes, all passing, plus one follow-up probe of the set_config proxy branch. The shims are correct and load-bearing on the installed stack (pandas 3.0.5, numpy 2.5.1): raw resample("M") genuinely raises ValueError, the alias map returns ME/QE/YE which pandas accepts, safe_resample reproduces hand-computed monthly sums, means and a compounding callable, safe_concat matches known answers on both axes, and normalize_timezone keeps the local timestamp on an Asia/Tokyo fixture without mutating its caller. The download path was swept offline with a stubbed yfinance: pct_change of a fixed Close path returns the known answer [0, 0.1, 0.1], a tz-aware New York index comes back naive with local dates kept, ticker/auto_adjust/period-vs-start translation is asserted, the proxy reaches yfinance through both the legacy download-kwarg branch and the set_config branch that installed yfinance 1.5.2 actually takes, and a None return from yf.download yields an empty frame instead of a crash.

Findings filed, evidence in hand: QS-11 (Medium, documentation) - normalize_timezone's docstring and comments describe the UTC-convert behavior the QS-9 fix deliberately rejected, while the code does the settled keep-local drop; misleading documentation sitting exactly on the package's most recently fixed High. QS-12 (Low, code quality) - the whole _numpy_compat module has zero importers (AST enumeration over every package file), and 5 _compat functions have zero callers; the dead module includes safe_random_seed, whose documented seeding effect is a demonstrated no-op (np.random.default_rng(seed) created and discarded), a defect rendered harmless only by the code being unreachable.

Scores, claiming only the two swept rows and not the unexamined remainder: correctness None, error handling None, documentation Medium (QS-11), code quality Low (QS-12), security None, dependency hygiene None (the pandas-3 frequency shim is present and correct where the suite depends on it). The other 6 rows - stats, utils, plots, reports, montecarlo, extend_pandas - remain stale and unswept; this audit makes no claim about them, and this partial audit does not count toward convergence.

Learnings: The dead-code enumeration and the no-op seed demonstration took one AST walk and four lines of state comparison; the expensive-looking sweep was cheap because the row was small and self-contained. The frequency-alias probe that first confirms the old alias genuinely fails is what separates certifying a shim from certifying nothing: a shim whose absence changes nothing cannot be certified by any output it produces.

Next: execute QS-11 (Medium, documentation), the top unblocked item.

## iter 3/10 | 5d706f1a-035757 | 2026-07-28 | QS-11 | done

Task: QS-11 (Medium, documentation) - _compat.normalize_timezone's docstring and inline comment described converting to UTC before dropping the timezone, and safe_resample's Returns section repeated the same claim; the code correctly does tz_localize(None), the keep-local convention settled by QS-9. Misleading documentation sitting directly on the package's most recently fixed High.

Changed: quantstats/_compat.py (three documentation sites: normalize_timezone docstring now states the drop-zone-keep-local convention and why UTC-first was rejected, the inline comment matches, safe_resample's Returns section corrected), BACKLOG.md, JOURNAL.md.

Checkpoint: a779c76

Verification: Acceptance run as written: grep -n "UTC" quantstats/_compat.py returns one line, the docstring sentence explaining that converting to UTC first was deliberately rejected - no remaining claim that the code performs a UTC conversion. git diff --stat confirms the change is 13 documentation lines in one file with no executable statement touched, and the full 37-probe compat sweep from iteration 2 re-ran green after the edit, including the Asia/Tokyo keep-local known-answer. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 182 passed.

Contract preserved: documentation-only change; no signature, behavior, or accepted input changed anywhere. The compat inventory row's certification is re-anchored to this iteration's checkpoint by the re-executed sweep, so the row is not left looking stale against a file that changed after its recorded commit.

Learnings: none beyond the finding itself; the fix was exactly the one-boundary documentation correction the task specified.

Next: 2 open tasks remain (QS-10, QS-12), below the replenishment threshold - next iteration is a partial audit sweeping the stale utils and stats rows with known-answer checks per function family.

## iter 4/10 | 5d706f1a-035757 | 2026-07-28 | AUDIT | audit

Task: Replenishing partial audit sweeping the two deepest stale rows, quantstats.stats and quantstats.utils, with known-answer checks per function family on a hand-computable 4-value fixture ([0.10, -0.05, 0.20, -0.10]), scipy/numpy references, and parameter-effect invariants.

Changed: PLAN.md (stats row split into 5 family rows per the inventory sizing rule, 4 flipped swept at 2003f2b plus utils flipped, secondary-ratio family row added as never swept), BACKLOG.md (QS-13 High filed in Now, QS-14 Medium filed in Next), JOURNAL.md. No package code changed.

Checkpoint: b37a330

Verification: roughly 75 checks, all passing except the two filed findings. Passing evidence spans: exact hand answers for comp/compsum/expected_return/ghpr, cagr matching its documented periods-252 convention, volatility with exact sqrt period scaling, sharpe/sortino/adjusted_sortino against hand formulas with rf effects, the hand drawdown curve [0, -0.05, 0, -0.10], parametric VaR equal to scipy norm.ppf with sigma and confidence effects, the full trade-stats family (kelly 0.25, payoff 2, cpc 2, streaks 3/1, exposure 0.5), scipy-referenced skew/kurtosis, benchmark family against numpy cov/corrcoef references, rolling family last-window equality, aggregation hand compounds for 'ME' and 'month', conversions round-trip, _prepare_returns identity/price-detection/tz-keep-local/no-caller-mutation, make_portfolio end values, and make_index 50/50 known-answer through a stubbed yfinance. Two probe errors were caught and corrected before filing, honoring the evidence rule: cvar is empirical-tail-mean by its own docstring (not parametric ES), and cagr's convention is documented in its signature.

Findings, both reproduced: QS-13 (High, correctness) - utils.aggregate_returns's unrecognized-token fallthrough silently returns unaggregated data, and the letter codes 'M', 'Q', 'Y', 'A' documented by stats.compare all take that fallthrough; compare(aggregate='M') returns 5 daily rows where 2 monthly rows belong. The aggregate= parameter reaches this fallthrough from 9 public stats functions at 15 call sites. QS-14 (Medium, correctness) - ulcer_index computes sqrt(sum(dd^2)/(n-1)) while documenting the mean form; 0.064550 against the documented 0.055902 on the fixture, propagating into UPI, serenity and three reports metrics rows.

Scores, claiming only the swept rows (compat, download, utils, and 4 of 5 stats family rows): correctness High (QS-13) and Medium (QS-14), both filed with failing acceptance checks; error handling covered by QS-13, whose root cause is the silent fallthrough; testing gap (a 182-test suite never noticed the no-op) closed by QS-13's acceptance tests rather than filed separately; documentation folded into QS-14's doc-code mismatch; security, performance, dependency hygiene None on swept rows. Unswept and claiming nothing: stats secondary-ratio family, plots, reports, montecarlo, extend_pandas. This partial audit does not count toward convergence.

Learnings: The letter-code no-op was invisible to a liveness probe and to the whole suite because every path returns a well-formed Series; only the row-count against a hand-grouped expectation exposed it. The inventory sizing rule earned its keep: splitting the 80-function stats row into family rows is what made "swept" an honest claim instead of a single checkbox standing for half the package.

Next: execute QS-13 (High), the aggregation fallthrough, as the top unblocked item.

## iter 5/10 | 5d706f1a-035757 | 2026-07-28 | QS-13 | done

Task: QS-13 (High, correctness) - utils.aggregate_returns silently returned unaggregated data for any unrecognized period token, including the letter codes 'M', 'Q', 'Y', 'A' that stats.compare documents. Execution surfaced two more defects at the same boundary, folded in because they share the root cause (matching order and fallthrough at one boundary): the week tokens 'W'/'week'/'eow' crashed with AttributeError because DatetimeIndex.week no longer exists on installed pandas, and the documented non-string custom-grouper branch was unreachable, crashing at the period == "YE" comparison with an ambiguous-truth ValueError before reaching its branch.

Changed: quantstats/utils.py (aggregate_returns matching block rewritten: non-string groupers checked first, letter codes mapped to per-year groupings, week numbers from isocalendar(), explicit 'D' passthrough, unknown tokens raise ValueError naming the token; docstring documents the full token set and the raise), tests/test_regressions.py (TestAggregateTokens, 9 tests), PLAN.md (two rows flipped stale per change discipline, one Lessons line), BACKLOG.md, JOURNAL.md.

Checkpoint: 2a8bf35

Verification: 8 of 9 new tests failed against the unfixed code (silent no-op row counts, AttributeError on week tokens, ambiguous-truth crash on the custom grouper, no raise on 'fortnight'); the ninth deliberately pins the seasonal cross-year semantics of the word tokens 'month'/'quarter', which the fix preserves. All 9 pass after. Differential: 21 sections capturing every previously-working path (ME/QE/YE/month/quarter/year/eoy/eom/eoq both compounded flags, None, compare-ME, compare-None) are identical to the pre-fix baseline, 1064 of 1064 non-empty lines equal in order. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 191 passed, up from 182. Enumeration: the 15 aggregate_returns call sites in stats.py all route through the single fixed boundary.

Contract preserved: every token that produced aggregated output before produces byte-identical output after; the seasonal word tokens keep their historical across-year semantics, deliberately pinned by a test; the letter codes gain the per-year semantics compare documents; tokens that silently no-opd or crashed now either work or raise a clear ValueError. compare's documented aggregate codes ('D', 'W', 'M', 'Q', 'Y') are now true as written.

A verification hazard worth the journal: the first byte-differential reported every section differing, which would have meant a catastrophic regression. It was the harness again, not the library: pandas to_csv emits \r\n on Windows, the text-mode baseline write mangled it to \r\r\n, and reading back produced phantom blank lines. The line-exact comparison with empty lines stripped showed 0 differences in 1064 lines. Recorded as a Lessons line in PLAN.md.

Learnings: A fallthrough that returns its input is the worst kind of default for a dispatch function: every unrecognized token becomes a silent identity operation. The rewrite ends with a raise, so the next stale alias fails loudly instead of fabricating daily data labeled as monthly.

Next: QS-14 (Medium), the ulcer_index denominator, now the top unblocked item.

## iter 6/10 | 5d706f1a-035757 | 2026-07-28 | QS-14 | done

Task: QS-14 (Medium, correctness) - stats.ulcer_index divided the squared-drawdown sum by n-1 while its docstring documents the mean form and the standard Ulcer Index divides by n, inflating every reported value by sqrt(n/(n-1)) and dragging ulcer_performance_index, serenity_index and the three reports metrics rows with it.

Changed: quantstats/stats.py (one line, the ulcer_index denominator, with a comment naming the convention), tests/test_regressions.py (TestUlcerDenominator, 3 tests), PLAN.md (risk family row flipped stale per change discipline), BACKLOG.md, JOURNAL.md.

Checkpoint: 49f1bcd

Verification: the mean-form test failed against the unfixed code (0.064550 against the documented 0.055902) and passes after; the two flow-through identities confirm UPI and serenity consume the corrected value. The value shift is exactly sqrt(n/(n-1)) on both fixtures - 1.1547005383792515 against sqrt(4/3) on the 4-value fixture and 1.0012523486435 against sqrt(400/399) on 400 days - which is the proof the change altered the denominator and nothing else. Docstring already stated the mean form, so no doc change was needed; the code now matches it. No test pinned the old values (grep over tests/ for ulcer and serenity returned nothing before this iteration). Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 194 passed, up from 191.

Contract preserved: signature and container handling unchanged; only the scalar magnitude changes, by a factor bounded by sqrt(n/(n-1)), which is 0.125 percent at one trading year and vanishes with length. UPI and serenity change only through their ulcer_index input; their own formulas are untouched.

Learnings: none new; the iteration went exactly as the backlog line specified.

Next: 2 open tasks remain (QS-10, QS-12), below the replenishment threshold - next iteration is the replenishing audit, which also re-sweeps the three stale rows (utils, stats risk, stats aggregation-comparison) and starts on the never-swept remainder (stats secondary-ratio, plots, reports, montecarlo, extend_pandas).

## iter 7/10 | 5d706f1a-035757 | 2026-07-28 | AUDIT | audit

Task: Replenishing partial audit. Re-certified the three rows staled by this run's fixes and swept the five never-swept rows: stats secondary-ratio, montecarlo, extend_pandas, reports, plots. The whole 12-row inventory is now swept.

Changed: PLAN.md (8 rows flipped to swept at ff2e493), BACKLOG.md (QS-15 and QS-16 Medium filed in Next, QS-17 Low filed in Later, one Declined entry), JOURNAL.md. No package code changed.

Checkpoint: 5893402

Verification: The full iteration-4 known-answer sweep re-ran green against the fixed code, re-certifying utils, stats risk and stats aggregation-comparison, including the checks that failed before QS-13 and QS-14. Sweep A: scipy-referenced probabilistic Sharpe, formula-referenced autocorr penalty with smart_sharpe and smart_sortino identities, hand answers for implied volatility both paths, rar, risk_of_ruin, recovery_factor (sum convention, a corrected probe error), risk_return_ratio, outlier ratios, pct_rank, the two-episode drawdown_details table, montecarlo seed reproducibility, permutation terminal invariance, genuine maxdd spread, bust and goal probabilities in range, and extend_pandas delegation equalities with a no-mutation fingerprint. Sweep B: reports.metrics rows equal their stats counterparts at displayed rounding (comp, CAGR, Sharpe, volatility, max drawdown, beta equal to greeks in the strategy column), the UPI row equal to comp divided by the corrected ulcer_index, html end-to-end writing a 50KB-plus file carrying the title, and 54 of 54 plot wrapper invocations clean across Series, one-column and two-column inputs. Probe errors caught before filing: recovery_factor's sum convention, to_plotly taking a figure argument, and the metrics fraction-scale reading.

Findings: QS-15 (Medium) - montecarlo_sharpe and montecarlo_cagr advertise outcome distributions that the permutation design makes degenerate; cagr std is 1e-15 float noise, and the sharpe spread is a leave-one-out artifact of pct_change dropping a different first row per path. QS-16 (Medium) - probabilistic_ratio(annualize=True) returns 13.7 on a documented 0-1 probability scale. QS-17 (Low) - plots namespace pollution (typing.Any, safe_resample). Declined: metrics(display=False) fraction-under-percent-label, an upstream convention whose change would break existing consumers.

Scores, and for the first time this run they claim the whole 12-row inventory: correctness Medium (QS-15, QS-16), code quality Low (QS-17 and the open QS-12), error handling None (the aggregation boundary now raises, the validate boundary swept clean), documentation None (QS-11 closed; the one quirk found is Declined with reason), security None, performance None, testing None (gaps close through acceptance tests), dependency hygiene None, architecture None. Zero High. This is a replenishing audit and does not count toward convergence; the closing full audit must still rescore fresh in one iteration.

Learnings: Three probe errors in one audit, all caught by reading the implementation before filing - the evidence rule's cost is real but so is its yield: every one of the five filings this run survives adversarial re-checking because the reproduction is in the journal. The montecarlo finding is the known-answer rule's poster child: every liveness probe passes, seeds reproduce, shapes are right, and the advertised distribution is still a point mass.

Next: QS-15 (Medium), the montecarlo bootstrap, as the top unblocked item; QS-16 after it; the remaining budget cannot also absorb the three Lows plus a full closing audit, so the run will end with a wrapup handoff.

# Journal

Append-only. One primary entry per iteration; SALVAGE and ROTATION entries are additional. Never rewrite past entries (filling the current entry's Checkpoint field is completion, not a rewrite).

Heading grammar, exactly:
## iter 8/10 | 5d706f1a-035757 | 2026-07-28 | QS-15 | done

Task: QS-15 (Medium, correctness) - montecarlo_sharpe and montecarlo_cagr advertised distributions of possible outcomes while the permutation design made those statistics invariant: cagr's std was 1e-15 float noise and sharpe's apparent spread was a leave-one-out artifact of pct_change dropping a different first observation per path.

Changed: quantstats/stats.py (both wrappers rewritten to bootstrap the returns with replacement via a seeded default_rng, keeping the dict contract, plus a Note in each docstring and the terminal-invariance caveat in montecarlo's docstring), quantstats/_montecarlo.py (documentation only: the stats property now states terminal values are identical across shuffled paths and points to maxdd and bust/goal as the distributional outputs), tests/test_regressions.py (TestMontecarloDistributions, 4 tests), PLAN.md (montecarlo row flipped stale per change discipline), BACKLOG.md, JOURNAL.md.

Checkpoint: ddd8e43

Verification: 2 of 4 new tests failed against the unfixed code exactly as diagnosed - cagr spread below 1e-9, and sharpe's std 0.066 falling far outside the [0.5, 2.0] band around the asymptotic standard error of an annualized Sharpe ratio, which is about 1.0 for one year of daily data; all 4 pass after. The bootstrap distributions are statistically honest: sharpe mean 1.0978 against analytic 1.0966 with std 1.0805 sitting at the asymptotic SE, cagr mean 0.1757 against analytic 0.1618 with genuine spread 0.1840. The path-based core is untouched: the permutation-invariance pin still holds on montecarlo(), all 20 pre-existing montecarlo tests pass unchanged, and montecarlo_drawdown's seeded std is bit-equal to the pre-fix probe (0.032397). Scoping decision recorded: MonteCarloResult.stats stays permutation-based because the acceptance requires montecarlo() differentially unchanged; its degeneracy is now documented at the property and in montecarlo's docstring instead of implied away. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 198 passed, up from 194.

Contract preserved: both wrappers keep their signatures and dict keys; seeds reproduce; the ddof=1 and rf/periods conventions of the old per-path computation carry over; montecarlo, montecarlo_drawdown and MonteCarloResult are behaviorally untouched, doc edits aside.

Learnings: The asymptotic-SE band is the right acceptance shape for a resampling fix: a point mass fails it, the leave-one-out artifact fails it, and only a genuine sampling distribution passes, so the test cannot be satisfied by cosmetic noise.

Next: QS-16 (Medium), the probabilistic_ratio annualize branch, as the top unblocked item.

## iter 9/10 | 5d706f1a-035757 | 2026-07-28 | QS-16 | done

Task: QS-16 (Medium, correctness) - probabilistic_ratio(annualize=True) multiplied the norm.cdf probability by 252**0.5, returning about 13.7 on the documented 0-1 scale, ignoring periods in that branch; the three probabilistic_* wrappers forwarded the flag.

Changed: quantstats/stats.py (probabilistic_ratio raises ValueError on annualize=True before any computation, with the four docstrings' annualize lines corrected), tests/test_regressions.py (TestProbabilisticRatioScale, 2 tests), PLAN.md (secondary-ratio row flipped stale per change discipline), BACKLOG.md, JOURNAL.md.

Checkpoint: 2c386bb

Verification: the raise test failed against the unfixed code (annualize=True returned 13.697, no raise at any of the four entry points) and passes after; the probability-scale guard passes on all default paths. Differential: the four default-path values are bit-identical to the pre-fix baseline (0.8628594460530028, 0.9468170754152161, 0.8732258544410629, 0.8551869304801321) and the reports Prob. Sharpe row is unchanged at 0.86. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 200 passed, up from 198.

Contract preserved, and the design rationale recorded: removal of the parameter was rejected because reports.py:1348 - and plausibly external callers - pass annualize positionally, so deleting the slot would silently rebind False to smart; keeping the signature and raising on True gives the wrong value a clear failure message, exactly the user-error envelope's prescription, while every positional caller and the default path stay byte-identical.

Learnings: When a public parameter is broken, check how callers BIND it before removing it; a positional caller makes parameter removal a silent re-binding of every later argument, and a loud raise inside the kept slot is the safer surgery.

Next: final iteration - WRAPUP with handoff. Three Lows remain (QS-17, QS-10, QS-12) and the closing full audit plus evaluator cannot fit alongside them in one iteration, so the run ends out of budget, not converged.

## iter 10/10 | 5d706f1a-035757 | 2026-07-28 | WRAPUP | done

Task: Final iteration of the budget. The ledger is tidy, so this entry is the handoff rather than a task that could not have finished alongside the run report.

Changed: JOURNAL.md only. Stall note: this iteration changed no file outside the state files and no BACKLOG.md item changed state, the expected shape of a wrapup; the previous primary entry closed QS-16 with code changes, so the no-progress rule is not triggered.

Checkpoint: c15de7e

Verification: Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 200 passed, against 182 at the start of the run. Working tree clean at the start of this iteration.

The run does not converge, and the reason is budget arithmetic, not doubt: three Lows remain open (QS-17, QS-10, QS-12), and the closing rule requires them worked or declined plus a full fresh-evidence audit and the evaluator gate, which do not fit in one iteration. The position handed off is much stronger than the one received: the run started with 8 of 8 inventory rows stale or unswept and ends with 10 of 12 swept, and the two stale rows (montecarlo, stats secondary-ratio) are stale only because this run fixed defects in them - their re-sweep evidence already sits in the suite as TestMontecarloDistributions and TestProbabilisticRatioScale plus the iteration-7 sweep evidence recorded in the journal.

Handoff for the next run, in a fresh session: (1) flip the two stale rows by re-running their committed suite tests plus the sweep-A checks from the iteration-7 journal entry - both fixes recorded default-path differentials as identical, so the flips are cheap; (2) work or decline the three Lows: QS-17 (underscore-alias the leaked names in _plotting/wrappers.py), QS-10 (stop validate_input converting the caller's index in place; all stats call sites now route through the one boundary), QS-12 (delete _numpy_compat wholesale and the five dead _compat functions plus their tests and PROJECT.md references); (3) run the closing full audit in one iteration - every sweep needed is either in the suite or recorded as a scratch-reproducible check in this journal - and the evaluator gate. Convergence is one clean run away. The five settled classes and the two Declined entries must not be re-filed unless their implementing code changed.

Learnings: The staleness discipline did its job twice this run: both rows that went stale did so because fixes changed the code under a fresh sweep, and both times the fix's own acceptance tests doubled as the re-sweep evidence, making honesty nearly free. The expensive part of auditing was never the probes; it was refusing to let a green liveness result stand in for a known answer.

Next: a new session; flip the two stale rows, close the three Lows, then the closing audit and evaluator.

## iter 1/10 | 91ef5b33-045420 | 2026-07-28 | QS-10 | done

Task: QS-10 (Low, correctness) - utils.validate_input converted a non-datetime, non-range index in place (data.index = _pd.to_datetime(data.index)), so a validator whose return value all 15 stats.py call sites discard was writing through to the caller's own Series or DataFrame, against the no-write-through invariant already settled for the reports and plots entry points.

Changed: quantstats/utils.py (validate_input checks convertibility without assigning; new _normalize_date_index helper, copy-on-write; _prepare_returns and _prepare_prices route their copy through it), quantstats/stats.py (r_squared, information_ratio, greeks, rolling_greeks gain an else branch normalizing returns when prepare_returns=False, because those four pass returns.index to _prepare_benchmark), tests/test_regressions.py (TestStatsEntryPointsDoNotMutateCallerIndex, 44 tests; _fingerprint now renders index dtype and values instead of taking raw bytes), PLAN.md (two Lessons), BACKLOG.md.

Checkpoint: 80c708d

Verification: the acceptance check fails against the unfixed code exactly as required - with the package stashed and the tests kept, 22 of 44 fail, the 21 parametrized mutation cases plus the direct validate_input check; all 44 pass after. The 121-case scratch differential over 15 entry points times string, one-column-frame and integer-index callers, each with documented parameters at two or more values, reports zero result or error divergences against the pre-fix baseline while mutations fall from 65 to 0, and the unparseable-index guard still raises DataValidationError unchanged. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 244 passed, up from 200.

The first differential was wrong and said so only because the probe was strengthened. Its benchmark shared the returns index, so set(period) equalled set(benchmark.index), _prepare_benchmark never entered its alignment branch, and the run reported 0 divergences over 64 cases. Giving the benchmark its own span exposed 4 real divergences on the prepare_returns=False paths - r_squared and greeks raised, information_ratio and rolling_greeks returned different numbers with no error at all - which is what the else branch in those four functions repairs. A weaker probe would have shipped two silent wrong answers under a green suite.

Contract preserved: validate_input keeps its signature and its True return, so tests/test_utils.py's identity assertion holds, and its docstring never advertised the conversion, so no documentation contradicts the new behavior. Every one of the 15 call sites still receives data with a datetime index by the time it computes, now from the _prepare_* boundary that already copies rather than from a mutation of the argument; the 121-case differential is the evidence that no computed value moved. Surface inventory rows are untouched because the prep commits left all 12 already unswept, so there is nothing to flip back.

Learnings: A probe whose fixtures agree by accident certifies the code it was meant to test - the identical-index benchmark skipped the exact branch the change endangered. Both new Lessons lines come from this iteration: offset the benchmark span whenever _prepare_benchmark is in the call path, and fingerprint an index by rendering rather than raw bytes, since a string index carries a StringArray with no tobytes and NaT never equals itself.

Next: QS-17 (Low, code quality), the plots namespace pollution, as the top unblocked item; QS-12 after it. Both Lows, then the closing full audit and the evaluator gate.

## iter 2/10 | 91ef5b33-045420 | 2026-07-28 | QS-17 | done

Task: QS-17 (Low, code quality) - quantstats/plots.py re-exports _plotting.wrappers with "import *", so with no __all__ in that module every bare import it makes arrived as public plotting API. Six non-plot names were exposed, two more than the finding named: typing.Any, typing.TYPE_CHECKING, the __future__ annotations flag, the warnings module, _compat.safe_resample, and the module-local Returns type alias.

Changed: quantstats/_plotting/wrappers.py (__all__ listing the 19 plotting entry points, with a comment recording why it is declared rather than aliased), tests/test_regressions.py (TestPlotsNamespaceIsOnlyPlots, 2 tests), BACKLOG.md (QS-17 closed, one Settled class added, one Declined entry).

Checkpoint: ad62456

Verification: the acceptance check fails against the unfixed code - with wrappers.py stashed, dir(quantstats.plots) lists 25 public names including all six leaks; after the fix it lists exactly 19, and the AST enumeration of functions defined in wrappers.py equals both that set and __all__. The finding's own enumeration also passes: the import lines of wrappers.py and plots.py bind 18 names (Any, MonteCarloResult, TYPE_CHECKING, _Figure, _FuncFormatter, _StrMethodFormatter, _core, _np, _pd, _plt, _rmc, _sns, annotations, plotly, safe_resample, stats, utils, warnings) and none of them is public in quantstats.plots. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 246 passed, up from 244.

Class settled, and its boundary is narrower than it first looked. Checking the sibling namespaces showed the same shape - stats exposes Literal, NDArray, warn, safe_concat, reports exposes Path, StringIO, tempfile, webbrowser, utils exposes inspect - which would be a third instance and so a structural task under the three-strike rule. It is not the same defect: grep -rn "import \*" over quantstats/ returns exactly one site, plots.py, and __init__.py imports the other modules plainly. Those three are ordinary modules whose dir() shows their imports the way every Python module does, __all__ would not change dir() there, and only underscore-aliasing every usage site would, for a cosmetic gain. Recorded as Declined so a later audit does not re-file it.

Contract preserved: __all__ constrains "import *" only, so quantstats._plotting.wrappers keeps every attribute it had - Returns, safe_resample and the rest stay importable for internal use, and the 19 wrappers are unchanged in signature and behavior. No documentation described the leaked names as plotting API, so nothing contradicts the narrower namespace. Surface inventory rows are untouched because all 12 are already unswept.

Replenishment note: two open tasks stood at the start of this iteration, below the threshold of three, and one remains now. No partial audit was run, because convergence needs a full fresh-evidence audit over all 12 unswept rows anyway and a partial one does not count toward it; the ledger draining next iteration puts that full audit in the natural place rather than spending budget on a weaker pass first.

Learnings: none that generalize past this task; the test is written against the AST of wrappers.py rather than a hardcoded list, so a wrapper added without updating __all__ fails it.

Next: QS-12 (Low, code quality), deleting _numpy_compat and the five uncalled _compat functions, as the last open task; then the full fresh-evidence audit of all 12 Surface inventory rows, which is the run's main remaining cost, and the evaluator gate.

## iter 3/10 | 91ef5b33-045420 | 2026-07-28 | QS-12 | done

Task: QS-12 (Low, code quality) - dead compat code: the whole _numpy_compat module and five uncalled _compat functions, plus the tests and documentation that kept them looking alive.

Changed: deleted quantstats/_numpy_compat.py (288 lines); quantstats/_compat.py (158 lines removed, the contiguous block from safe_append through get_string_accessor, leaving 275 lines); tests/test_compat.py (TestSafeAppend and the safe_append import removed, 19 lines); .claude/PROJECT.md (three references to _numpy_compat removed from Conventions, the file tree and the dependency-update steps); .claude/2026-modernization-plan.md (its "review _numpy_compat, may be removable" checkbox closed); PLAN.md (the _compat inventory row no longer names the deleted module); BACKLOG.md.

Checkpoint: 63444be

Verification: the AST enumeration required by the acceptance check reports 0 references to safe_append, safe_frequency_conversion, handle_pandas_warnings, get_datetime_accessor, get_string_accessor, safe_random_seed or the _numpy_compat module anywhere under quantstats/ and tests/, counting Name, Attribute, Import and ImportFrom nodes; quantstats/_numpy_compat.py no longer exists; .claude/PROJECT.md holds 0 references. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 244 passed. A smoke run of the public API after the deletion returns real values - sharpe 1.171104, cagr 0.207885, greeks beta 0.086964 alpha 0.225400, a 39x2 metrics frame and a snapshot Figure - and _compat still exports exactly its five live functions.

Scope checked before cutting rather than taken from the backlog line. The AST usage census over quantstats/ and tests/ scored all 10 _compat functions: safe_resample 30 references, safe_concat 10, get_frequency_alias 7, normalize_timezone 4, safe_yfinance_download 2, all live and kept; safe_append 3, every one of them in its own test file and none in the package; and the other four at 0. get_frequency_alias and normalize_timezone deserve the note because they look dead from the outside - both are reached only from inside safe_resample, at _compat.py:128 and :174 - and deleting either would have broken every resample path with a green-looking grep. The five dead functions turned out to occupy one contiguous span, lines 214 to 371, so the cut was a single block with asserted boundaries.

Tests removed, and why that is not weakening the suite: the 2 deleted tests exercised safe_append, which no longer exists, so they could not be kept; 246 minus those 2 is exactly the 244 now passing, and no other test changed. No test covered _numpy_compat at all, which is part of why 288 lines of unreachable code survived this long, including safe_random_seed whose documented seeding effect was a demonstrated no-op.

Contract preserved: no public interface changed. _numpy_compat was never imported by any package file, and the five deleted _compat functions had zero callers in quantstats/; the imports at the head of _compat.py were re-checked after the cut and none was orphaned. Surface inventory rows stay unswept as they already were; the _compat row's text was corrected because it named a module that no longer exists.

Learnings: none that generalize past this task. The census-before-deletion habit is already covered by the existing enumeration lesson.

Next: the ledger is now empty, so the next iteration generates tasks - the full fresh-evidence audit of all 12 Surface inventory rows under the documented-parameter sweep contract, which is the run's main remaining cost and the gate the Definition of done depends on.

## iter 4/10 | 91ef5b33-045420 | 2026-07-28 | AUDIT | audit

Task: Full fresh-evidence audit in Improvement mode. The ledger was empty and all 12 Surface inventory rows were unswept, having been re-opened before this run because their earlier sweeps predate the documented-parameter contract. Every row was swept under that contract and the whole inventory is now swept.

Changed: PLAN.md (all 12 rows flipped to swept at 917eb28 with what each sweep exercised), BACKLOG.md (QS-18 and QS-19 High in Now, QS-20 Medium in Next, QS-21 Low in Later), JOURNAL.md. No package code changed, which is correct for an audit iteration; BACKLOG items changed state, so the stall check does not apply.

Checkpoint: 3cb172d

Verification: two sweeps ran. The documented-parameter sweep drove all 78 public stats functions, exercising each defaulted parameter at two or more values including boundary and negative sides: 66 functions had a computable baseline, 87 parameter movements were observed, and 59 parameter-function pairs did not move. The known-answer sweep ran 97 closed-form, hand-computed or reference-implementation checks across the 12 rows - not one liveness probe was allowed to flip a row - plus 54 plot wrapper-by-shape renders and a grayscale byte differential at all 18 wrappers that document it. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 244 passed.

The 59 non-moving parameters were triaged rather than filed, and 55 were probe artifacts. prepare_returns dominates the list because the fixture was already returns, where preparation is idempotent by design; re-run on prices, where preparation genuinely converts, it moves everywhere except calmar. compounded looked inert on win_rate because a win rate depends only on the sign of a bucket, which compounding and summing agree on, while avg_return, best, worst, avg_win and avg_loss all moved. omega's periods is correctly inert at required_return=0, since the threshold is (1+0)**(1/p)-1 for any p, and moves once required_return is non-zero. montecarlo's goal looked inert only because both probe goals were trivially reachable; at goal=2.0 the probability drops to 0.0. Four known-answer mismatches were also probe errors, each resolved by reading the implementation rather than by loosening a tolerance: recovery_factor uses returns.sum() not comp(), both outlier ratios take their quantile over all returns rather than the signed subset, the probabilistic ratio uses the package's own pandas-based skew and kurtosis rather than scipy's biased moments, and to_excess_returns deannualizes geometrically rather than dividing by the period count.

Findings, all reproduced before filing. QS-18 (High) - utils._prepare_returns reads its caller's frame name and skips the excess-return conversion for cagr and gain_to_pain_ratio, so both document rf and ignore it: cagr(rf=0.05) returns 0.25761042, exactly its rf=0.0 value, and gain_to_pain_ratio(rf=0.05) returns 0.24089220, likewise, while sharpe moves 1.356 to 1.087 and sortino 2.053 to 1.622 on the same data. reports.py:1340 and reports.py:1527 pass rf into both, so one metrics table at rf=0.05 shows Sharpe and Sortino excess of the risk-free rate beside a Gain/Pain row that is not. QS-19 (High) - utils.make_index contains no .resample( call anywhere, the word appearing only in its docstring, and its two branches compute the same daily-weighted sum, so rebalance=None, "1ME" and "1QE" return an identical series; against a correct buy-and-hold index whose weights drift, the documented never-rebalance case is wrong by 2.14 percentage points over 5 years on a two-asset fixture. QS-20 (Medium) - treynor_ratio documents periods as annualization but spends it on greeks' alpha while reading beta, which is identical at periods 252, 12 and 1, and returns a whole-period compounded return less an annual rate, giving 36.06, 17.56 and 57.04 for the same process at 252, 504 and 1008 observations. QS-21 (Low) - calmar's prepare_returns cannot change its result because cagr and max_drawdown both re-prepare.

Scores, claiming the whole 12-row inventory for the first time under the documented-parameter contract: correctness High (QS-18, QS-19), documentation Medium (QS-20), code quality Low (QS-21), architecture None, error handling None, testing None (the gaps are the paths these four findings sit on and close through their acceptance tests), security None (grep over quantstats/ finds no eval, exec, pickle, subprocess, os.system, shell=True or yaml.load; the unescaped title substitution at reports.py:357 is the report-title surface the envelope classifies user-error for a local analyst tool, so it is not filed), performance None, dependency hygiene None (declared floors pandas>=1.5.0, numpy>=1.24.0, scipy>=1.11.0, matplotlib>=3.7.0, seaborn>=0.13.0, tabulate>=0.9.0, yfinance>=0.2.40 all resolve above floor to pandas 3.0.5, numpy 2.5.1, scipy 1.18.0, matplotlib 3.11.1, seaborn 0.13.2, tabulate 0.10.0, yfinance 1.5.2 with a green suite). Observability and UX/accessibility do not apply: quantstats is an importable library with no service surface and no interactive UI.

Closeout has NOT begun: this audit scored two High and one Medium in-envelope, so the closeout stop does not apply and the run continues working the ledger. The class the sweep exposed is one class - a documented parameter that cannot change the output - and its enumeration is the sweep itself, which covered all 78 stats functions plus utils, plots and reports; the four instances are filed separately because their root causes and fixes differ (a caller-name skip list, an unimplemented resample, a parameter forwarded to the wrong consumer, and a flag made redundant downstream), so the three-strike rule's single structural task does not fit them.

Learnings: A generic inertness harness has a false-positive rate near 90 percent here, and every one of those false positives came from a fixture that made the parameter genuinely irrelevant rather than from code that ignored it. The harness is still worth running - it found two High defects that five previous audits missed - but its output is a candidate list, never a finding list, and the triage step is the actual audit.

Next: QS-18 (High), the rf skip list, as the top unblocked item; then QS-19, QS-20 and QS-21, then the closing convergence check and the evaluator gate.

## iter 5/10 | 91ef5b33-045420 | 2026-07-28 | QS-18 | done

Task: QS-18 (High, correctness) - utils._prepare_returns read its caller's frame name and skipped the excess-return conversion for cagr and gain_to_pain_ratio, so both documented an rf parameter and silently ignored it, while reports.py:1340 and reports.py:1527 passed rf straight into them.

Changed: quantstats/utils.py (the unnecessary_function_calls skip list cut from four names to one, with a comment recording why _prepare_benchmark alone belongs there), quantstats/stats.py (cagr forwards periods to _prepare_returns; gain_to_pain_ratio gains a documented periods parameter and forwards it; rolling_volatility stops passing rolling_period into the rf slot), tests/test_regressions.py (TestRiskFreeRateIsHonoured, 9 tests), PLAN.md (2 Lessons, 4 inventory rows flipped stale), BACKLOG.md (QS-18 closed, QS-22 filed High).

Checkpoint: 399cc27

Verification: 6 of the 9 new tests fail against the unfixed code with the package stashed and the tests kept, and all 9 pass after. The rf=0 default path is bit-identical across 17 captured keys - cagr, gain_to_pain_ratio, sharpe, sortino, omega, recovery_factor, treynor_ratio, rar, six rolling_volatility parameter combinations and the whole rf=0 metrics table - so nothing moved where rf was not asked for. With rf asked for, cagr goes 0.257610 to 0.232970 at 2 percent and 0.197762 at 5 percent, gain_to_pain_ratio 0.240892 to 0.219528 and 0.188909, each equal to running the function on the deannualized excess series, which is the known-answer form the tests assert. In reports.metrics at rf=5 percent three rows now move that did not before: CAGR, Gain/Pain Ratio and Gain/Pain (1M). Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 253 passed, up from 244.

The first attempt at this fix was wrong and the differential caught it. Removing cagr and gain_to_pain_ratio from the skip list alone produced cagr(rf=0.05) = -1.0, because to_excess_returns deannualizes rf only when it is given nperiods and both call sites omitted it, so the entire annual 5 percent came off every daily observation. The correct fix forwards the period count: cagr already documented periods and simply had to pass it, and gain_to_pain_ratio had none, so it gained one as a documented keyword defaulting to 252. That is an additive signature change; reports.py:1527 calls gain_to_pain_ratio(df, rf) with two positional arguments and is unaffected.

Collateral, not new scope: rolling_volatility called _prepare_returns(returns, rolling_period), feeding its 126-period window into the rf slot. It was inert only because rolling_volatility sat in the skip list that voided rf, so shrinking the list would have turned a dormant bug into a live one that deducts a risk-free rate of 126. The call now passes returns alone, its output is unchanged across all six captured parameter combinations, and a known-answer test pins the last window against the closed form.

Contract preserved: cagr, gain_to_pain_ratio and rolling_volatility keep their signatures except for gain_to_pain_ratio's added keyword; every rf=0 result is bit-identical; _prepare_benchmark stays in the skip list because its callers at reports.py and wrappers.py pass rf so the benchmark lines up with the strategy, while the ratio functions downstream subtract rf themselves, and converting in both places would deduct it twice. Documentation updated in the same iteration: gain_to_pain_ratio's docstring now states that rf is annualized and that periods deannualizes it. Four Surface inventory rows flipped back to unswept - core performance, risk, utils and reports - because their implementing code changed.

New finding, filed not worked: QS-22 (High). The same root cause survives at two more sites that were never in the skip list, so they always applied rf and always applied it wrong. rar(returns, rf=0.01) returns -0.899874 and rar(returns, rf=0.05) returns -1.0; utils.to_returns(prices, rf=0.05) moves the daily mean from +0.00098572 to -0.04901428, against a correct deannualized daily rate of 0.00019363, a factor of 258. These are the third and fourth instances of one root cause, so under the three-strike rule QS-22 is written as a single boundary fix where rf enters rather than two more per-site patches.

Learnings: both new Lessons come from this iteration. _prepare_returns and to_excess_returns deannualize rf only when handed the period count, and passing an annual rf without it produces a plausible-looking negative rather than an error, which is why four call sites carried the defect unnoticed. And before removing a name from a skip list, read what that caller passes in the slot the skip protects.

Next: QS-22 (High), the boundary fix for the remaining rf sites, as the top unblocked item; then QS-19, QS-20, QS-21, then the re-sweep of the four stale rows and the evaluator gate.

## iter 6/10 | 91ef5b33-045420 | 2026-07-28 | QS-22 | done

Task: QS-22 (High, correctness) - stats.rar and utils.to_returns handed an annualized rf to _prepare_returns without a period count, so to_excess_returns deducted a whole year of risk-free return from every observation. Written as the structural task the three-strike rule requires after QS-18 fixed the same root cause at two sites.

Changed: quantstats/utils.py (_prepare_returns falls back to 252 periods when rf is non-zero and no period count is given, with the docstring restated to say rf is annualized), quantstats/stats.py (rolling_sharpe and rolling_sortino pass periods_per_year instead of rolling_period), tests/test_regressions.py (TestAnnualisedRiskFreeRateIsDeannualised, 15 tests), PLAN.md (1 Lesson, secondary-ratio row flipped stale), BACKLOG.md (QS-22 closed, the rf class recorded under Settled classes).

Checkpoint: 9cc6506

Verification: 7 of the 15 new tests fail against the unfixed code with the package stashed and the tests kept, including the AST enumeration, which names quantstats.stats:974 and :1125 as the two call sites passing a rolling window; all 15 pass after. The rf=0 and non-rf surfaces are bit-identical across 18 captured keys, including volatility, max_drawdown, calmar, rolling_volatility, comp, to_prices and the whole rf=0 metrics table. At rf=5 percent rar moves from -1.0 to 0.197762, to_returns' last six daily values move from about -0.05 to about +0.005, rolling_sharpe at a 126-day window moves from 0.109479 to 0.389181 and rolling_sortino from 0.149096 to 0.536662, while sharpe, sortino, omega, cagr and gain_to_pain_ratio - the sites that already passed a correct period count - do not move at all. The metrics table at rf=5 percent gains one corrected row, Risk-Adjusted Return, from -1.0 to 0.15 and 0.2. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 268 passed, up from 253.

Scope grew by two sites on evidence, and the class is now closed rather than patched. The task as filed named rar and to_returns, which omit the period count and are fixed by the boundary fallback. Auditing every _prepare_returns call site first showed two more that pass a period count but the wrong one: rolling_sharpe and rolling_sortino hand it rolling_period while annualizing by periods_per_year, so at rf=5 percent the deduction was twice too large at the default window and eight times too large at a 30-day one. The tell is that the size of the rf effect tracked the window - -2.177, -1.125, -0.559 and -0.276 at windows of 30, 60, 126 and 252 - when a risk-free rate has nothing to do with how long the window is. The boundary fallback cannot reach those two because they do pass a value, so closing the class required both changes, which is what the class rule means by every site covered or explicitly settled.

Contract preserved: no signature changed. The fallback is gated on rf > 0, exactly where the existing excess branch was gated, so every default path is untouched, which the 18-key differential confirms. to_excess_returns keeps its documented contract that nperiods is optional and means no conversion when absent, because a caller who already holds a per-period rate legitimately wants the raw subtraction; the fallback lives in _prepare_returns, the internal boundary every one of these callers passes an annualized rate through. One Surface inventory row flipped back to unswept, the secondary-ratio family, because rar changed; core performance, utils and reports were already unswept from the previous iteration and cover the rest of this change.

Learnings: the window-length parametrization is the new Lesson. The rolling defect passed at rolling_period=252 and failed at 30, 60 and 126, because a window equal to periods_per_year makes the two indistinguishable; a test written only at the default window would have certified it. This is the same shape as the earlier lesson about probing a parameter only where it works, but the coincidence here is between two different parameters rather than between a parameter and its default.

Next: QS-19 (High), the make_index rebalance parameter, as the top unblocked item; then QS-20 and QS-21, then the re-sweep of the five stale rows and the evaluator gate.

## iter 7/10 | 91ef5b33-045420 | 2026-07-28 | QS-19 | done

Task: QS-19 (High, correctness) - utils.make_index never used the value of its documented rebalance parameter. The function contained no resampling of any kind and both of its branches summed weight times return every day, so rebalance=None, "1ME" and "1QE" returned one identical daily-rebalanced series and the documented buy-and-hold case was wrong.

Changed: quantstats/utils.py (make_index rewritten to hold target weights inside each rebalance interval and let them drift, with the rebalance argument documented as what it now does, and get_frequency_alias added to the _compat import so legacy aliases keep working), tests/test_regressions.py (TestMakeIndexRebalances, 10 tests), BACKLOG.md.

Checkpoint: 7882359

Verification: 2 of the 10 new tests fail against the unfixed code with the package stashed and the tests kept - the buy-and-hold identity and the interval-distinctness check, the latter reporting all four intervals as the single value 0.038274842715734225 - and all 10 pass after. Three independent identities pin the new implementation: rebalance=None reproduces a hand-computed buy-and-hold value path exactly, rebalance="1D" reproduces the old weighted sum exactly, so the previous behavior is still reachable when it is actually asked for, and a 100 percent weight in one member reproduces that member bit for bit at every interval. On a 5-year two-asset fixture the four intervals now give distinct totals: never +0.016850, daily +0.038275, monthly +0.042009, quarterly +0.047880. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 278 passed, up from 268.

The ordering was checked rather than assumed. Never-rebalancing coming last looked wrong for a book holding the higher-drift asset, so the members' realized paths were read: asset A returned -0.114289 over the span despite the higher nominal drift, while B returned +0.147989, so holding fixed weights lets the loser shrink from a 50 percent start rather than being topped back up, and the rebalanced variants buy it back. The ordering across intervals is path-dependent and no invariant requires monotonicity, so nothing is filed.

A defect in the first version of this fix was caught by its own invariant check, not by the suite. Weights are not required to sum to 1, and computing the period value as the weighted sum of member growth alone made a half-invested book open at 0.5 against a previous value of 1.0, booking a 50 percent loss on the first bar. The uninvested remainder is now carried as cash that neither grows nor shrinks, which restores the old scaling for partial books; the test that catches it asserts the first bar of a 0.25/0.25 index equals the plain weighted return.

Contract preserved: the signature, the default of "1ME", match_dates, the last_day trim and the returned Series length are all unchanged, and the returns-versus-download branch is untouched. What changes is the computed series for every interval except "1D", which is the defect being fixed; the docstring now states that weights reset at each interval and drift in between, so the code and its documentation agree. Legacy pandas aliases still work because rebalance passes through get_frequency_alias, verified by "M" reproducing "1ME" exactly. The utils Surface inventory row is already unswept from iteration 5 and covers this change.

Learnings: none that generalize into a new rule. The habit that paid here is already recorded: check an identity the implementation would fail if it were subtly wrong, in this case the single-member and partial-book cases, rather than only the headline behavior the task named.

Next: QS-20 (Medium), the treynor_ratio periods parameter and its annualization claim, as the top unblocked item; then QS-21 (Low), then the re-sweep of the five stale rows and the evaluator gate.

## iter 7/10 | 91ef5b33-045420 | 2026-07-28 | ROTATION | rotation

Task: JOURNAL.md reached 514 lines, past the 500-line threshold, so all but the last 10 entries were rotated out.

Changed: JOURNAL.md (18 entries removed, 10 kept), JOURNAL-archive.md (created, holding those 18 entries oldest first).

Checkpoint: 7882359

Verification: 28 entries before the rotation, 18 in the archive and 10 left in JOURNAL.md, so the count is conserved and no entry was rewritten. The archive did not previously exist and was created rather than overwritten; from here it only accumulates, which is what the stop hook checks by rejecting an archive whose entry count fell.

Learnings: none.

Next: unchanged by the rotation - QS-20 is the top unblocked item.

## iter 8/10 | 91ef5b33-045420 | 2026-07-28 | QS-20 | done

Task: QS-20 (Medium, documentation) - treynor_ratio documented periods as "Periods per year for annualization" but forwarded it only to greeks, which spends it on alpha while treynor reads beta, so the argument was inert; and the returned figure was the whole-period compounded return less an annual risk-free rate over beta, which grows with the length of the sample.

Changed: quantstats/stats.py (treynor_ratio returns the annualized return less rf over beta, stops forwarding periods to greeks where it cannot reach beta, and its docstring states the convention the code now implements), tests/test_regressions.py (TestTreynorRatioIsAnnualised, 9 tests), BACKLOG.md.

Checkpoint: 98aa714

Verification: 7 of the 9 new tests fail against the unfixed code with the package stashed and the tests kept, and all 9 pass after. The inertness is gone: periods at 252, 52 and 12 now returns 0.209813, 0.039554 and 0.008967, three distinct values where all three were previously 1.208785. The sample-length growth is gone: on four samples the figure ran 0.059210, 0.280845, 1.208785 and 6.590938 before and runs 0.059210, 0.129943, 0.209813 and 0.260382 after, a spread of 111.3x reduced to 4.4x, with the remainder being genuine variation in the realized return rather than in the length. On increasing prefixes of a single realization the old form ran -0.002195, 0.232266, 0.812323 and 6.590938 while the new one runs -0.002195, 0.108661, 0.153452 and 0.260382, each equal to that prefix's cagr over its beta. Beta is unchanged at all four sample sizes, confirming that dropping periods from the greeks call altered nothing it was actually used for. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 287 passed, up from 278.

Observable behavior changed, with the rationale recorded as the Constraints require. The returned figure now differs for any sample that is not exactly one year long, because a whole-period compounded return has been replaced by an annualized one; at exactly 252 observations the two coincide, which is why the n=252 case is bit-identical before and after and serves as a consistency check on the change. The Treynor Ratio row in reports.metrics moves from 1.21 percent to 0.21 percent on the probe fixture for the same reason. This is the defect being fixed rather than a side effect: the previous figure was not comparable between a one-year and a five-year track record, which is the whole purpose of the statistic.

Contract preserved: the signature is unchanged, which matters because reports.py:1694 and reports.py:1728 pass periods and rf positionally as the third and fourth arguments; both keep their meaning and their position. rf remains an annual rate and is still deducted linearly, now from an annual return rather than from a multi-year one, so the two quantities are finally in the same units; a test pins that deducting rf lowers the figure by exactly rf over beta. The pre-existing test in tests/test_stats.py still passes untouched, though it only asserted that the result was finite, which is precisely why this defect survived every previous suite run. The core performance Surface inventory row, which covers treynor_ratio, is already unswept from iteration 5.

Learnings: none that generalize into a new rule. The existing lesson about known-answer rather than liveness checks is exactly what this task illustrates: the shipped test asserted np.isfinite and passed for years over a statistic that grew without bound with sample length.

Next: QS-21 (Low), the calmar prepare_returns flag, as the last open task; then the re-sweep of the five stale rows and the evaluator gate, which will not both fit in the final iteration.

## iter 9/10 | 91ef5b33-045420 | 2026-07-28 | QS-21 | done

Task: QS-21 (Low, code quality) - stats.calmar documented a prepare_returns flag that could not change its result, because cagr and max_drawdown each prepare their own input, so preparing first only added a rounding step.

Changed: quantstats/stats.py (calmar loses the prepare_returns parameter from its signature, its docstring and its body, with a comment recording why no preparation happens there), quantstats/reports.py (the Calmar row at reports.py:1464 no longer passes the removed keyword), tests/test_regressions.py (TestCalmarHasNoInertFlag, 9 tests, and the calmar_unprepared entry removed from the string-index call table since that call no longer exists), BACKLOG.md.

Checkpoint: 6dcaf98

Verification: 2 of the 9 new tests fail against the unfixed code with the package stashed and the tests kept, and all 9 pass after. Removal was chosen over making the flag real, and the enumeration the acceptance names supports it: grep and an AST pass over quantstats/ and tests/ find five calmar call sites and not one binds prepare_returns positionally, so removing it cannot silently rebind a later argument, which is the trap the QS-16 lesson records. The two sites that passed it by keyword, reports.py:1464 and the string-index call table, were updated in this iteration. The value does not move: across six input shapes - returns Series, price Series, one-column frame, two-column frame, a series with NaN and a series with zeros - the two branches agreed exactly on five and to a relative 7.899e-16 on the price Series, which is the rounding step the double preparation added. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 294 passed, which is 287 plus the 9 new tests less the 2 parametrized cases that exercised the removed flag.

Public interface changed, with the rationale recorded as the Constraints require. calmar's signature goes from (returns, prepare_returns, periods) to (returns, periods). An external caller writing calmar(r, prepare_returns=False) now gets a TypeError, which is the failure mode chosen deliberately: a loud immediate error is better than a documented flag that quietly does nothing, and a test pins that the removed keyword raises rather than being swallowed. Making the flag real was rejected because it would have required adding the same flag to cagr and max_drawdown to have anywhere to forward it, which is more surface, not less. periods remains and still moves the result at 252, 52 and 12, and calmar remains cagr over the absolute maximum drawdown, both pinned by tests.

Ledger note: this was the last open task, so BACKLOG.md now lists zero open items in Now, Next and Later. The run still cannot converge: five Surface inventory rows stand unswept because this run's own fixes changed the code under them, and the closing rule requires no unswept row plus an evaluator PASS, which does not fit in the one remaining iteration. Closeout was never entered either, because the only full audit this run scored two High and one Medium.

Learnings: none new. The QS-16 lesson about checking how callers bind a parameter before removing it is exactly what made this removal safe, and it earned its place a second time.

Next: the final iteration, a WRAPUP entry with the handoff and the run report; the next run should re-sweep the five stale rows, whose evidence is already committed as tests, then run the evaluator gate.

## iter 10/10 | 91ef5b33-045420 | 2026-07-28 | WRAPUP | done

Task: Final iteration of the budget. The ledger emptied at iteration 9, so rather than open a task that could not finish, this iteration re-swept the five Surface inventory rows that this run's own fixes had made stale, then wrote the handoff.

Changed: PLAN.md (five rows flipped to swept at 1dbbbde), JOURNAL.md. No package code changed and no BACKLOG.md item changed state, which is the expected shape for a wrapup; the previous primary entry closed QS-21 with code changes, so the no-progress rule is not triggered.

Checkpoint: 1ab2858

Verification: the re-sweep ran 62 known-answer and documented-parameter checks against the current code and reported one failure, which was a probe error and is resolved: reports.metrics returns columns ordered Benchmark then Strategy, so reading column zero compared the benchmark's Sharpe of 1.33 against the strategy's stats.sharpe of 1.58, and both values are individually correct - 1.33 is exactly stats.sharpe on the benchmark series. Every other check passed, including the ones covering this run's changes: cagr's rf equal to the deannualized excess series, gain_to_pain's new periods parameter moving, rolling_sharpe and rolling_sortino proved window-independent at windows of 30 and 126, treynor equal to cagr over beta with periods moving across three values, calmar's periods moving with its inert flag gone, rar correct at rf=0.05 where it previously returned -1.0, to_returns deducting exactly the deannualized daily rate, make_index reproducing a hand-computed buy-and-hold and giving four distinct totals across four intervals, and the metrics CAGR, Gain/Pain, Sharpe and Risk-Adjusted Return rows all responding to rf. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 294 passed, against 244 at the start of this run.

The run does not converge, and the reason is the closing rule rather than doubt about the work. Of its conditions, zero open tasks holds, no unswept inventory row holds at 12 of 12, and the Verify command is green; what fails is the first condition, that a full fresh-evidence audit in this run scored zero High and zero Medium. The only full audit this run, at iteration 4, scored two High and one Medium, and every finding it raised has since been fixed - but no audit has re-scored the project since those fixes landed. Declaring convergence on the strength of my own re-sweep of code I had just changed would be the failure the Definition of done exists to prevent, so it is not declared. Closeout was never entered for the same reason. The evaluator gate was not invoked, because it applies only on the Definition of done path.

Handoff for the next run, in a fresh session. The position is much stronger than the one received: the run started with 12 of 12 inventory rows unswept and an untouched ledger of three Lows, and ends with 12 of 12 swept, an empty ledger, and eight tasks closed including three High. The next run should need only two things: one full fresh-evidence audit in a single iteration, which now starts from a fully swept inventory and can lean on the 62-check re-sweep recorded here plus the 294-test suite, and then the evaluator gate and the Converged line. If that audit comes back with zero High and zero Medium, closeout begins immediately and convergence follows in the same or the next iteration. Two things must not be re-filed: the six Settled classes, now including the annualized-rf class closed at the _prepare_returns boundary and the namespace class closed by __all__, and the three Declined entries. The scratch re-sweep is reproducible from the journal: every check in it is a closed form, a hand-computed case or an identity against an independently constructed reference.

Learnings: none new beyond the five Lessons this run added to PLAN.md. The one worth repeating in the handoff is that the generic documented-parameter harness has a false-positive rate near 90 percent on this codebase and its output is a candidate list, never a finding list; the triage against the implementation is where the two High defects actually came from.

Next: a new session. Run the closing full audit, then the evaluator gate, then declare convergence if both come back clean.

## iter 1/10 | 2f7af8db-104645 | 2026-07-28 | AUDIT | audit

Task: Full fresh-evidence audit, the one thing the previous run's handoff said was missing. The ledger arrived empty, the Converged section is empty so the ratchet does not apply, and all 12 Surface inventory rows were checked for staleness before anything else: the functions stats.py changed after 917eb28 (cagr, calmar, gain_to_pain_ratio, omega, rolling_sharpe, rolling_sortino, rolling_volatility, treynor_ratio) and the two utils.py changed (_prepare_returns, make_index) all belong to rows swept at the later commit 1dbbbde, and git diff --name-only 1dbbbde HEAD lists only PLAN.md and JOURNAL.md, so no row flips back to unswept. The audit therefore ran against a fully swept surface at 12 of 12.

Changed: BACKLOG.md (four findings filed), JOURNAL.md. No package code changed, which is the expected shape for an audit iteration; the previous primary entry was a WRAPUP that also changed no package code, but it moved five inventory rows and this one changed BACKLOG.md state by filing four items, so the run is not stalled.

Checkpoint: cd9629bb20d4365e802cc50e0e3d56f3f7665a69

Verification: 294 passed via .venv/Scripts/python.exe -m pytest tests/ -q before any change, unchanged after, since no package code was touched.

Scores, claiming all 12 of 12 swept rows, so these cover the whole mapped surface rather than a sampled part of it. Correctness High, error handling High, documentation High, testing Medium, code quality Low, architecture None, security None, performance None, dependency hygiene None, developer experience None, observability None, UX and accessibility None. Closeout is not entered: this audit scored two High and one Medium, so the run keeps auditing rights and must work the ledger down.

Evidence, each reproduced before filing. QS-23: sys.stdout.encoding is cp1252 on this machine and qs.reports.metrics(r) with every argument defaulted dies with UnicodeEncodeError on U+FE6A at position 221, after printing the parameter block, so the user sees a half-written report and a traceback; the same three entry points all complete when stdout is a UTF-8 stream, which locates the fault in the labels rather than in the numbers. A codepoint enumeration over quantstats/**/*.py finds exactly five source lines that cp1252 cannot encode, all in reports.py, two codepoints: U+FE6A once at 1340 and U+221A four times at 1365, 1367, 1369 and 1370, of which 1367 and 1370 are commented out, leaving three live labels. QS-24: gain_to_pain_ratio(r, resolution=v) returns 0.295293 for D and 0.899961 for W and 3.372000 for ME, and raises ValueError for M, Q, A and Y, which are the values its own docstring names; stats.py:1521 calls .resample(resolution) directly while 24 sites in the package use safe_resample and utils.make_index uses get_frequency_alias, and the aggregate= parameter of expected_return, best, worst and win_rate accepts M, Q, A and Y correctly through that shim, which is what makes this one site an outlier rather than a class. QS-25: periods returns bit-identical values at 252, 52, 12 and 1 for probabilistic_sharpe_ratio and for probabilistic_ratio at all three bases, because its only consumer is sharpe/sortino/adjusted_sortino called with annualize=False, which ignores periods; the unreachable annualize tail at stats.py:1266 sits after a guard that raises. QS-26: a one-row series raises ZeroDivisionError from probabilistic_sortino_ratio and probabilistic_adjusted_sortino_ratio while probabilistic_sharpe_ratio returns nan on the same input.

What the audit checked and found clean, so the next audit need not re-derive it. Every public stats function, 74 of them, was called against seven realistic in-envelope series - normal, all zero, all gains, all losses, constant, one month, one observation - and produced exactly two exceptions, both QS-26; the many non-finite results in that sweep were triaged and are correct, a Sharpe ratio of an all-zero series being genuinely undefined rather than defective. A documented-parameter harness checked 144 function-parameter pairs and produced 63 candidates, of which 59 were false positives on triage exactly as the Lessons predict: prepare_returns is near-identity on input that is already returns, and compounded only acts inside an aggregation bucket, so both read as inert when probed with defaults. Security found no eval, exec, pickle, os.system, subprocess or __import__ anywhere in the package, and the HTML path writes with encoding utf-8. Dependency hygiene is clean, with pandas 3.0.5, numpy 2.5.1, scipy 1.18.0, matplotlib 3.11.1, seaborn 0.13.2 and yfinance 1.5.2 all current and pip list --outdated naming only pip itself.

Learnings: an internal caller that works around its own public contract is the highest-yield audit signal on this codebase, and both High findings carry that fingerprint - reports.py:1528 passes "ME" where the docstring tells users to pass "M", and the HTML writer names encoding utf-8 while the console path inherits whatever the terminal gives it. A green suite is no defence there, because every test exercises the routed-around path.

Next: QS-23, the console encoding crash, as the top unblocked item; then QS-24, QS-25, QS-26.

## iter 2/10 | 2f7af8db-104645 | 2026-07-28 | QS-23 | done

Task: QS-23 (High, error handling) - reports.metrics, reports.basic and reports.full aborted with UnicodeEncodeError on a console whose encoding cannot represent every character they print, which on this machine means the default call qs.reports.metrics(returns) dying on its own CAGR label.

Changed: quantstats/reports.py (three metric labels ASCII-ised, a _print helper added, all 26 console writes routed through it), tests/test_regressions.py (TestReportOutputSurvivesANarrowConsoleEncoding, 11 tests, plus the ast, contextlib, io and Path imports they need), BACKLOG.md (QS-23 deleted, one Settled classes line added), PLAN.md (the quantstats.reports Surface inventory row flipped back to unswept).

Checkpoint: 727b961ebe3ef4e43b72ee49802f11ccf747b5dd

Verification: all 11 new tests fail against the unfixed code with the package stashed and the tests kept, and all 11 pass after. The acceptance check is met on both halves. On a stream reporting cp1252, metrics, basic and full now complete and their output contains the CAGR row, where before all three raised; a strategy_title of CJK, Greek or Latin-1 text and a CJK benchmark_title all complete, where before they raised. The two enumerations are clean: a codepoint scan over quantstats/**/*.py reports zero source lines that fail encoding to cp1252, down from five, and an AST pass reports zero bare print calls in reports.py outside the helper, down from 26. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 305 passed, up from 294.

The class, not the instance. The labels alone would have satisfied QS-23 as filed, and they would have left the class open: with the labels fixed, a strategy_title of Japanese text still aborted the report, because the caller's own strings reach the same terminal by the same route. Both sources are one root cause - text the stream cannot encode handed to a bare print - so the remedy is the single boundary the Method prescribes. reports._print encodes with errors="replace" only when a plain encode would raise, so output is byte-identical on any stream that can carry it and degrades to replacement characters only where the alternative was a traceback. The caller keeps their numbers, which is what they asked for.

Observable behavior changed, with the rationale recorded as the Constraints require. Three row labels are renamed: CAGR<FE6A> becomes CAGR, Sortino/<221A>2 becomes Sortino/sqrt(2), and Smart Sortino/<221A>2 becomes Smart Sortino/sqrt(2). The CAGR rename also removes a genuine inconsistency rather than only a byte: metrics stores percentage rows with a trailing "%" marker that reports.py:1801 strips and reports.py:1778 uses to append "%" to the values, so every sibling renders as Cumulative Return or Prob. Sharpe Ratio with no glyph, and CAGR alone carried a stray small-percent-sign. A test pins that the CAGR row still ends its value with "%", which is the behavior that marker drives and the thing a careless rename would have silently broken.

Contract preserved, established by differential rather than by assertion. The previous checkpoint's reports.py was loaded side by side as a quantstats submodule per the Lessons and compared across 10 configurations - Series and DataFrame input, basic and full mode, with and without benchmark, rf at 0 and 0.05, periods_per_year at 252 and 52, compounded on and off. With the three renames applied to the old index, all 10 frames are byte-identical, so no number moved; the label count is 75 in both, and the only three differences are the intended ones. The tests that already pinned CAGR match it as a substring, so they were unaffected.

Learnings: metric names in reports.metrics are columns until the transpose at reports.py:1802, and a trailing "%" in that name is a marker, not decoration - reports.py:1778 appends "%" to the values and reports.py:1801 strips the marker's last character - so renaming such a label without keeping the trailing "%" silently drops the percent sign from the rendered values.

Next: QS-24, the gain_to_pain_ratio resolution aliases, as the top unblocked item.

## iter 3/10 | 2f7af8db-104645 | 2026-07-28 | QS-24 | done

Task: QS-24 (High, correctness) - stats.gain_to_pain_ratio called pandas .resample directly on the caller's resolution, so M, Q, A and Y, the spellings its own docstring names, raised ValueError on pandas 2.2+ where those aliases became ME, QE and YE.

Changed: quantstats/stats.py (imports safe_resample and routes the resample through it, with a comment recording why a bare .resample is wrong here), tests/test_regressions.py (TestGainToPainAcceptsItsDocumentedFrequencies, 17 tests), BACKLOG.md (QS-24 deleted, one Settled classes line added), PLAN.md (the stats risk-family Surface inventory row flipped back to unswept).

Checkpoint: 38483b35084219ac53ccd58605f871dd627bc98e

Verification: 10 of the 17 new tests fail against the unfixed code with stats.py stashed and the tests kept, and all 17 pass after. The 7 that pass in both are exactly the cases the old code already handled - D, W, ME, QE, YE, the daily known answer and the reports row - which is the shape a correct fix should produce. All nine documented resolutions now return finite values where four of them raised: on the probe series D gives 0.295293, W 0.899961, M and ME both 3.372000, Q and QE both 23.025429, and A, Y and YE all 37.895719. The parameter genuinely moves the result, five distinct values across D, W, M, Q and Y. Enumeration is clean: an AST pass over quantstats/ finds zero .resample calls on a caller-supplied frequency outside _compat, the four remaining literal sites at stats.py:191-194 all being hardcoded modern aliases. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 322 passed, up from 305.

Contract preserved, established by differential rather than by assertion. safe_resample also normalizes timezone, so the previous checkpoint's stats.py was loaded side by side as a quantstats submodule and compared over 60 cases - four zones either side of UTC including naive, US/Eastern, Asia/Tokyo and Europe/London, crossed with the five resolutions the old code could accept and three rf and periods combinations - with zero mismatches at exact tolerance, plus zero mismatches on the DataFrame branch, which takes the separate Series-of-downside path. So every value the old code could compute is bit-identical, and the change adds only the four spellings that used to raise. A known-answer test pins the default path against sum over the absolute sum of negative returns, so the reroute cannot quietly change what the statistic means, and the two reports rows that pass "ME" and the default positionally still agree with the stats function.

Checked and deliberately not filed: legacy multi-period spellings. 2QE and 6ME resample correctly through the passthrough, while 2Q and 6M raise a pandas ValueError that names the offending token. FREQUENCY_ALIASES maps only the four bare aliases, so extending it to parse multipliers would be new machinery for input the docstring does not name, and the envelope classifies these arguments as user-error, where a wrong value deserves a clear failure message and gets one. W-MON also works unchanged.

Learnings: an acceptance check must assert a property the statistic actually has. The first version of the resolution test asserted that gain-to-pain rises monotonically as buckets coarsen, which sounded plausible and is not true - the seed's series nets negative and the values are not ordered - so the check failed against correct code. Distinctness across resolutions is the real invariant and is what the test now pins.

Next: QS-25, the inert periods parameter on the probabilistic ratio family.

## iter 4/10 | 2f7af8db-104645 | 2026-07-28 | QS-25 | done

Task: QS-25 (Medium, documentation) - probabilistic_ratio and its three wrappers documented periods as "Periods per year for annualization" while it could not move the result, and stats.py carried an unreachable annualize branch after the guard that raises.

Changed: quantstats/stats.py (periods removed from all four signatures, docstrings and forwarding calls; the dead "if annualize: return psr * (252**0.5)" tail deleted; a Note added recording why the argument does not exist and a comment recording why the base ratios are deliberately not annualized), quantstats/reports.py (the live call at reports.py:1370 no longer passes win_year, and the five commented-out sibling calls updated so uncommenting one cannot bind a stale argument), tests/test_regressions.py (TestProbabilisticRatioHasNoInertPeriods, 16 tests, plus the inspect import), BACKLOG.md (QS-25 deleted, QS-27 filed, one Settled classes line added), PLAN.md (the stats secondary-ratio Surface inventory row flipped back to unswept).

Checkpoint: a0a32ca7ad225018c771ba8bb378a8331e8f485e

Verification: 13 of the 16 new tests fail against the unfixed code with stats.py and reports.py stashed and the tests kept, and all 16 pass after. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 338 passed, up from 322.

Removal was chosen over making the argument real, and the reason is the statistic rather than convenience. The probabilistic Sharpe ratio is defined on the per-observation base ratio and the observation count: its standard error carries a 1/(n-1) term and the numerator is the per-observation ratio, so both sides are already in per-observation units and a periods-per-year figure has nothing to scale. Annualizing the base alone would leave numerator and denominator in different units and inflate the probability, which is exactly the defect QS-16 removed when it made annualize=True raise. So the honest fix is that the argument does not exist, matching the QS-21 precedent where calmar's inert prepare_returns was removed rather than wired up.

Public interface changed, with the rationale recorded as the Constraints require. All four entry points lose periods, so an external caller writing probabilistic_sharpe_ratio(r, periods=12) now gets a TypeError, which is the failure mode chosen deliberately and is pinned by a test. The positional hazard the QS-16 lesson records was live here and was checked before the edit: reports.py:1370 passed probabilistic_sharpe_ratio(df, rf, win_year, False), so removing periods without touching that line would have slid 252 into the annualize slot, made it truthy, and turned every full report into a ValueError. That call now reads probabilistic_sharpe_ratio(df, rf) and the five commented-out siblings were updated for the same reason, since uncommenting one would otherwise reintroduce the same misbinding.

Contract preserved, established by differential. The previous checkpoint's stats.py and reports.py were loaded side by side as a quantstats submodule and compared over 63 cases - three sample lengths of 60, 252 and 756, the three wrappers, rf at 0, 0.05 and 0.5, smart on and off, plus probabilistic_ratio at all three bases - calling the old code with its full positional signature including periods and the new code with the shortened one, at exact tolerance with zero mismatches. The reports path was compared separately across five configurations including periods_per_year=52, the very value that used to land in the inert slot, and all five frames are byte-identical, which is the direct evidence that dropping win_year from that call changed nothing. A known-answer test pins the returned value against a normal-cdf reference built from the package's own moments.

Filed while reading the code, not batched into this task: QS-27, High. probabilistic_ratio never hands rf to sharpe or sortino; it subtracts it from the per-observation base ratio, so the argument is the PSR threshold Sharpe of Bailey and Lopez de Prado while the docstring calls it an annualized risk-free rate. The units do not meet: on the 504-day probe the shipped probabilistic_sharpe_ratio(r, 0.05) returns 0.061299 where the PSR of genuinely 5 percent excess returns is 0.196177, and reports.py:1370 passes the report's own rf into that slot, so the Prob. Sharpe Ratio row is wrong for any report run with a non-zero rf. This is outside the settled annualized-rf class, which covers only sites handing rf to utils._prepare_returns.

Learnings: none new. The QS-16 lesson about checking what a caller passes in a slot before removing a parameter earned its place a third time, and it was the difference between a clean removal and turning every full report into a ValueError.

Next: QS-27, the probabilistic rf semantics, as the top unblocked item; then QS-26.

## iter 5/10 | 2f7af8db-104645 | 2026-07-28 | QS-27 | done

Task: QS-27 (High, correctness) - probabilistic_ratio never handed rf to sharpe or sortino. It subtracted rf from the finished per-observation base ratio, so an annual percentage was compared against a daily ratio, and reports.py fed the report's own rf into that slot.

Changed: quantstats/stats.py (rf is now deducted at the _prepare_returns boundary and every moment is taken from that same excess series; periods returns to all four signatures with the real job of deannualizing rf; docstrings updated), quantstats/reports.py (reports.py:1370 passes win_year again, now that it means something), tests/test_regressions.py (TestProbabilisticRatioDeductsARealRiskFreeRate, 16 tests, and three tests in the QS-25 class rewritten to the new contract), BACKLOG.md (QS-27 deleted, QS-28 filed), PLAN.md (two Lessons).

Checkpoint: 2c43d419e545af76239626e0ce11db8696fd6ff6

Verification: 15 of the 16 new tests fail against the unfixed code with stats.py and reports.py stashed and the tests kept, and all 16 pass after. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 354 passed, up from 338.

Of the two remedies the acceptance allowed, the genuine risk-free rate was chosen over renaming the argument to a threshold ratio, because every other ratio in this package deducts rf at the _prepare_returns boundary and reports.metrics(rf=0.05) must mean one thing across its rows. A Prob. Sharpe row reading "probability the raw Sharpe exceeds 0.05 in daily units" sitting directly beneath a Sharpe row computed net of 5 percent is incoherent, and the threshold reading would have left that row insensitive to the rf the caller asked for. The defining invariant is now pinned: charging rf equals handing the function returns that already had rf removed, exact to 1e-12 across three rf and periods combinations for all four entry points, and that invariant is deliberately independent of how the standard error treats kurtosis, so it survives QS-28.

periods returns to the signature, which partly supersedes QS-25 one iteration earlier, and the reason is causal rather than a change of mind. QS-25 removed periods because it was genuinely inert: with rf subtracted from a finished ratio there was nothing to deannualize. Repairing rf gives the argument the same job gain_to_pain_ratio documents, and the alternative - deducting rf through the _prepare_returns fallback of 252 - would silently mis-scale monthly or weekly data, a defect knowingly shipped. The tests now pin both halves of the honest characterization: periods moves the result at rf=0.05 across 252, 52 and 12, and does not move it at rf=0, because with no rate there is nothing to scale.

Observable behavior changed, with the rationale recorded as the Constraints require. Against the previous checkpoint the rf=0 path on a clean series is bit-identical for all three wrappers, so the repair lands only on the broken case. A series containing NaN moves in the seventh decimal, 0.854890129 to 0.854892488 for the Sharpe base, and that is a second small correction rather than a side effect: the old code took skew and kurtosis from the raw series, where pandas skips NaN, while base came from sharpe, which had already filled NaN to zero, and n counted the rows the moments had excluded. Numerator, standard error and count now all come from one prepared series.

Filed while verifying, not batched: QS-28, High. The standard error computes ((kurtosis_no - 3) / 4) while stats.kurtosis returns pandas excess kurtosis, so 3 is subtracted twice. On a 200,000-point normal sample the term reads -0.753 where it should be about 0. It is small for ordinary ratios but scales with the square of the base ratio and turns the variance negative for large ones: at a per-observation ratio of -5.0 the numerator is -6.21 and the function returns nan from a square root of a negative number, where the raw-kurtosis form gives 12.55 and a well-defined answer. This is what made one of this iteration's own tests fail while the code under test was correct.

Learnings: stats.kurtosis returns pandas excess kurtosis, so any formula written from a paper that expects raw kurtosis needs the 3 added back. Separately, probabilistic_ratio takes base as its third positional argument, so a probe calling it with periods positionally silently sets the base metric instead - the failure looks like a wrong number, not a TypeError.

Next: QS-28, the kurtosis convention in the standard error; then QS-26.

## iter 6/10 | 2f7af8db-104645 | 2026-07-28 | QS-28 | done

Task: QS-28 (High, correctness) - the probabilistic ratio standard error computed ((kurtosis_no - 3) / 4) * base**2 while stats.kurtosis returns the pandas value, which is Fisher excess kurtosis and already g4 - 3, so 3 was subtracted twice.

Changed: quantstats/stats.py (the adjustment term is now excess_kurtosis / 4, with the variable renamed to say which convention it holds and a comment deriving the form from the canonical variance), tests/test_regressions.py (TestProbabilisticRatioUsesKurtosisConsistently, 12 tests, plus three formula sites in the QS-25 and QS-27 classes repaired under the verify-gate exception), BACKLOG.md (QS-28 deleted).

Checkpoint: b4bf4116309b323c0c5363316827c21ecc70a118

Verification: 9 of the 12 new tests fail against the unfixed code with stats.py stashed and the tests kept, and all 12 pass after. The algebra was checked before the edit rather than assumed: the quantstats form 1 + 0.5*SR^2 - g3*SR + ((g4-3)/4)*SR^2 is identical to the canonical Bailey and Lopez de Prado numerator 1 - g3*SR + ((g4-1)/4)*SR^2 for every g4 and SR tried, which establishes that the form is right and that it requires raw kurtosis, so the defect is the input convention rather than the expression. The corrected function now equals an independently written reference, built from the definition with raw kurtosis, to 1e-12 on all three bases. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 366 passed, up from 354.

Verify-gate exception applied, and this is the case the rule describes. After the fix, two tests written in iterations 4 and 5 went red: test_value_matches_the_probabilistic_sharpe_definition and test_rf_zero_default_path_is_untouched. Both are known-answer tests that re-implement the standard error, and both spelled the adjustment term (kurt - 3) / 4, so they were green only because they encoded the very defect this task fixes; one of them carries a comment written at the time saying it was deliberately left on the package's convention so that QS-28 would own the question. That is a pre-existing fault newly exposed, not a regression introduced here, so they were repaired in this iteration rather than reverted. A third site in test_rf_is_no_longer_a_threshold_on_the_ratio carried the same stale formula and was passing only because its assertion is an inequality; it was corrected too. The differential evidence the exception requires is below.

Differential against the previous checkpoint. Only the probabilistic ratio family moves, and it moves everywhere it should. On ordinary data the correction is small - the Sharpe base goes from 0.9277126818 to 0.9273942677 on one probe and 0.9941372657 to 0.9940041175 on another, about 1.3e-4 - and on fat-tailed data smaller still. It is decisive where the old form broke down: a series with a per-observation ratio of 2.0844 returned nan and now returns 1, and one at -4.5171 returned nan and now returns 1.76e-200. The threshold is exact and is pinned by a test that states the mechanism rather than the symptom: with near-normal kurtosis the old numerator reduces to 1 - 0.25 * SR^2, so it goes negative for any per-observation ratio past 2 in absolute value, which is where nan came from. The QS-27 rf invariant was re-checked after this change and still holds to 1e-12. The reports metrics table is unchanged at every displayed row across full, full with rf, and benchmarked configurations, because that table rounds to two decimals and the correction is smaller than that on ordinary data; the underlying stats value is what moves, which is the honest statement of the blast radius.

Learnings: none new. The lesson recorded last iteration, that stats.kurtosis is excess kurtosis and a transcribed formula expecting raw kurtosis must add 3 back, is exactly what this task fixed, and it also explains why two known-answer tests had to be repaired rather than trusted: a test that re-implements the implementation cannot detect a defect in the implementation's conventions.

Next: QS-26, the last open item and a Low, then a full fresh-evidence audit in iteration 8 with an empty ledger, which also re-sweeps the three stale Surface inventory rows; that ordering keeps the closing rule satisfiable, because after a clean audit the only commits may be fixes for tasks that audit itself filed.

## iter 7/10 | 2f7af8db-104645 | 2026-07-28 | QS-26 | done

Task: QS-26 (Low, error handling) - probabilistic_sortino_ratio and probabilistic_adjusted_sortino_ratio raised ZeroDivisionError on a one-row series while probabilistic_sharpe_ratio returned nan on identical input.

Changed: quantstats/stats.py (one guard returning nan when the series holds fewer than two observations, with the reason recorded, and the n<2 contract added to the Returns section of all four entry points), tests/test_regressions.py (TestProbabilisticRatioOnTinySamples, 14 tests), BACKLOG.md (QS-26 deleted; the ledger is now empty).

Checkpoint: 0e50993e0f3f73e006b97709a98698839b769c8e

Verification: 4 of the 14 new tests fail against the unfixed code with stats.py stashed and the tests kept, and those 4 are exactly the two functions that raised, under the two tests that exercise a one-row series; all 14 pass after. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 380 passed, up from 366.

The root cause was not the arithmetic but a scalar type. All three base ratios already returned nan for a single observation; sharpe returned np.float64(nan), where nan divided by zero is nan under numpy semantics, while sortino returned a plain Python float, where the same expression raises. So which sibling raised and which returned nan was decided by an incidental return type rather than by the statistic. The guard states the contract once instead: the standard error carries 1/(n - 1), so with one observation there is no dispersion to estimate and the answer is undefined.

Scope checked rather than assumed. Samples of two and three observations also return nan, and that is correct rather than a second defect: pandas needs three points to estimate skewness and four for kurtosis, so the moment-adjusted standard error is genuinely undefined below four, and a test pins that as documented behavior. An empty series still raises a validation error, which the guard deliberately does not swallow, because nothing to compute is a caller mistake and deserves its loud failure. A differential against the previous checkpoint over 72 cases - eight sample sizes from 2 to 756, three entry points, three rf and periods combinations - is identical at exact tolerance, so the guard changed nothing in the working range.

Learnings: none new.

Next: the ledger is empty and the run is not in closeout, so iteration 8 is the full fresh-evidence audit the closing rule requires, which must also re-sweep the three stale Surface inventory rows - quantstats.reports, the stats risk family and the stats secondary-ratio family - all three stale because this run changed the code under them. Clearing QS-26 first was deliberate: the closing rule allows only fixes for tasks the clean audit itself filed, so a pre-existing Low left open would have blocked convergence.

## iter 8/10 | 2f7af8db-104645 | 2026-07-28 | AUDIT | audit

Task: Full fresh-evidence audit against an empty ledger, re-sweeping first the three Surface inventory rows this run made stale - quantstats.reports, the stats risk family and the stats secondary-ratio family - so the scores below claim the whole mapped surface rather than part of it.

Changed: PLAN.md (the three stale rows flipped to swept at a33e827), BACKLOG.md (QS-29 filed). No package code changed, which is the expected shape for an audit; BACKLOG.md changed state by filing an item, and the previous primary entry closed QS-26 with code changes, so the no-progress rule is not triggered.

Checkpoint: 268df5ea6dab3ece18f3441bbf949b9a222417ce

Verification: the re-sweep ran 49 known-answer and documented-parameter checks against the current code and all 49 pass - 16 on the risk family, 22 on the secondary-ratio family, 11 on reports. Three checks failed on the first run and all three were probe errors, corrected and re-run rather than filed: ulcer_index divides by n, which is the standard Ulcer Index and was deliberately fixed to that convention in an earlier run, while my reference used n-1; pct_rank is documented on a 0-100 percentile scale and my check asserted 0-1; and reports.metrics(display=False) returns fractions under percent-suffixed labels, which is the upstream convention already recorded under Declined, so Max Drawdown reads -0.13 rather than -13.48 by design. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 380 passed.

Scores, claiming all 12 of 12 swept rows with no stale row remaining. Correctness None, security None, testing None, dependency hygiene None, architecture None, code quality None, performance None, developer experience None, observability None, UX and accessibility None, error handling Low, documentation Low. Zero High and zero Medium in-envelope.

Closeout has begun. This audit is the full fresh-evidence pass the closing rule requires and it scored zero High and zero Medium, so the run stops auditing for the rest of its budget: no replenishment and no further full audit, however many iterations remain. What is left is to work or decline the single Low on the ledger and then converge through the evaluator gate. This does not suppress anything - a High or Medium noticed while executing the remaining task is still filed and still worked, and both the evaluator gate and the next run's fresh audit remain in force.

Evidence behind the scores. Correctness rests on the 49 known answers above plus the nine rows swept earlier in the run whose implementing code has not changed since; the probabilistic family is now checked against a canonical Bailey and Lopez de Prado reference written from the definition rather than from the implementation, which is what caught QS-28 and is the form a re-implementing test cannot catch. Error handling: the whole public stats surface, 74 functions against seven realistic in-envelope shapes including all-zero, all-gains, all-losses, constant, one month and one observation, produced zero exceptions, down from two at iteration 1; the only remaining gap is QS-29. The documented-parameter harness checked 145 pairs and returned 62 candidates, every one triaged to a documented no-effect case: prepare_returns is near-identity on input that is already returns, compounded acts only inside an aggregation bucket, periods is correctly inert wherever rf defaults to zero because there is nothing to deannualize - the re-sweep separately proves it moves at rf=0.05 for gain_to_pain_ratio and all four probabilistic entry points - and annualize raising is the deliberate QS-16 guard. Security found no eval, exec, pickle, os.system, subprocess or __import__ anywhere in the package and the HTML path writes utf-8. Dependency hygiene is clean, with pip list --outdated naming only pip itself. Testing rests on 380 passing tests, every fix this run pinned by tests confirmed to fail against the unfixed code.

The single finding, QS-29 at Low. probabilistic_ratio promises ValueError for an invalid base metric and delivers it for a wrong string, but a non-string base reaches base.lower() first, so None and an int both raise AttributeError with a message naming neither the parameter nor the accepted values. The envelope classifies these arguments as user-error, where a wrong value deserves a clear failure message; this one is loud but uninformative, which is polish rather than a defect in a result, so Low is the rubric severity.

Learnings: none new. The pattern worth noting is that all three first-run sweep failures were the probe disagreeing with a deliberate convention the code documents, which is the expected failure mode once a codebase has been audited repeatedly, and is why a sweep failure is triaged against the implementation before it is written down as a finding.

Next: QS-29 in iteration 9, then the evaluator gate and the Converged line in iteration 10.

## iter 9/10 | 2f7af8db-104645 | 2026-07-28 | QS-29 | done

Task: QS-29 (Low, error handling) - probabilistic_ratio documents ValueError for an invalid base metric and delivered it for a wrong string, but a non-string base reached base.lower() first and raised AttributeError, a message naming neither the argument nor the values it accepts.

Changed: quantstats/stats.py (the three-branch dispatch replaced by one lookup table guarded by an isinstance test, so every invalid base takes the documented ValueError), tests/test_regressions.py (TestProbabilisticRatioRejectsABadBaseClearly, 13 tests), BACKLOG.md (QS-29 deleted; the ledger is empty), PLAN.md (the stats secondary-ratio Surface inventory row re-swept at this iteration's checkpoint).

Checkpoint: 30e4f604a43cf03947f8e2d689ff76b62c9a3080

Verification: 5 of the 13 new tests fail against the unfixed code with stats.py stashed and the tests kept, and all 13 pass after. The five are None, an int, a float, a list and a bare object; bytes passes in both, because b"sharpe" has a lower method and so already reached the documented error, which is the kind of partial coverage that makes a type-based guard the right shape rather than a longer list of special cases. After the fix every invalid base - wrong string, None, int, float, list, bytes, object - raises ValueError naming the metric and listing all three accepted values, and the unhashable list case works only because the isinstance test short-circuits before the dictionary lookup. Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 393 passed, up from 380.

Contract preserved. The dispatch became a lookup table, which is a simplification rather than a rewrite: base.lower() was being called up to three times and is now called once. Valid input is untouched, established by differential against the previous checkpoint over 36 cases - three sample lengths, four spellings including the mixed-case SHARPE that exercises the case-insensitive path, and three rf, periods and smart combinations - identical at exact tolerance. A test also pins that the three bases still select three different ratios and that each equals its own public wrapper, because collapsing a dispatch onto one metric is the way this refactor could have failed silently.

Surface inventory. This change touched probabilistic_ratio, which sits in the stats secondary-ratio row swept at a33e827, so that row went stale the moment the fix landed. Rather than leave it unswept and block the closing rule, the 49-check sweep was re-run against this iteration's tree and passed 49 of 49 again - 16 risk, 22 secondary-ratio, 11 reports - so the row is recorded as swept at this iteration's checkpoint. The inventory stands at 12 of 12 with no stale row.

Learnings: none new.

Next: iteration 10, the final one. The ledger is empty, the inventory is fully swept, closeout began at iteration 8 with an audit scoring zero High and zero Medium, and the Verify command is green, so what remains is the independent evaluator gate and, on PASS, the Converged line.

## iter 10/10 | 2f7af8db-104645 | 2026-07-28 | WRAPUP | converged

Task: Final iteration. Every condition of the closing rule was already standing at the start of it, so this iteration ran the independent evaluator gate and, on PASS, declared convergence.

Changed: JOURNAL.md and BACKLOG.md (the Converged line). No package code changed and no BACKLOG item changed state, which is the expected shape for a convergence wrapup; the previous primary entry closed QS-29 with code changes, so the no-progress rule is not triggered.

Checkpoint: 4bb3ec3e616f9adb3a350518ebefe22378be08ee

Verification: Verify command .venv/Scripts/python.exe -m pytest tests/ -q exits 0 with 393 passed. Evaluator: PASS - one fresh-context adversarial sub-agent re-ran the Verify command and all seven closed tasks' acceptance checks, reproduced each claim with real output, and additionally reverted quantstats/stats.py and quantstats/reports.py to c083b14 and observed 65 failed and 195 passed, independently confirming the run's tests genuinely fail against the unfixed code rather than merely passing against the fixed code.

Closing rule, condition by condition. The full fresh-evidence audit at iteration 8 scored zero High and zero Medium in-envelope and began closeout. The Surface inventory lists 12 of 12 rows swept with none stale. Now, Next and Later are empty: seven findings were filed this run and all seven completed, none declined and none blocked. The only commits since that clean audit are QS-29's fix, which that audit itself filed, plus bookkeeping. The Verify command is green this iteration. The evaluator returned PASS.

The evaluator's three non-blocking observations, recorded here rather than filed, because the closing rule permits only fixes for tasks the clean audit filed and closeout forbids a further audit in this run. First and most substantive: reports.py:83-85, the LookupError arm of the _print helper written for QS-23, calls text.encode(encoding, errors="replace") inside the handler using the same codec name whose lookup just failed, so that arm re-raises and cannot do its job. The evaluator reproduced it with a fake stdout reporting an invalid codec name. It is unreachable from any classified input surface, because sys.stdout.encoding is always a codec Python itself resolved, so it is out of envelope and Low at most; the honest remedy is deleting LookupError from the except clause, and that belongs to the next run's ledger. Second: stats.py:1344 is a 91-character line, cosmetic only, and E501 is ignored in pyproject.toml. Third: a negative rf is now inert for probabilistic_ratio where it moved the result before. The evaluator checked this against the code and did not file it, because utils._prepare_returns guards on rf > 0, so sharpe and cagr already ignored a negative rf at c083b14; the change made probabilistic_ratio consistent with the rest of the package and removed a dimensionally wrong subtraction. If the owner wants negative policy rates honored, that is a genuine gap in the enumeration of the settled documented-parameter class and a candidate Proposed item for the next run.

Learnings: the evaluator earned its place by running a check this run had not: reverting the package and counting failures across every new test at once, 65 of them, which measures the whole run's test suite for strength in one command rather than task by task. Worth doing inside a run, not only at its gate.

Next: a new session. The next run starts from a converged commit, so the ratchet applies if nothing but state files change; it should first file and fix the dead LookupError arm at reports.py:83-85, and decide the negative-rf question.
