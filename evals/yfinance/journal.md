# Journal

Append-only. One primary entry per iteration; SALVAGE and ROTATION entries are additional. Never rewrite past entries (filling the current entry's Checkpoint field is completion, not a rewrite).

Heading grammar, exactly:
## iter <i>/<N> | <run-id> | <YYYY-MM-DD> | <task-id or AUDIT or RATCHET or WRAPUP or SALVAGE or ROTATION> | <done|blocked|audit|converged|salvage|rotation>

SALVAGE entries take status salvage; ROTATION entries take status rotation.

run-id is the first 8 characters of the session id, a hyphen, then the HHMMSS of started_at from the loop state frontmatter, so two runs in one session are told apart. Body fields, in order: Task, Changed, Checkpoint (the jeffy checkpoint commit hash, or none with the reason), Verification, Learnings, Next.

The closing entry that declares convergence carries the evaluator verdict in its Verification field: `Evaluator: PASS - <one-line summary>`, or `Evaluator: unavailable (<reason>)`.

Closed tasks are recorded here as one line each (ID, title, closing evidence), because BACKLOG.md deletes them. Rotation: when this file exceeds 500 lines, move all but the last 10 entries to the end of JOURNAL-archive.md, appending to whatever that file already holds and never overwriting it, because the archive accumulates across every rotation and every run; create it only when it does not already exist, and record the rotation as a ROTATION entry.

## iter 1/10 | 6a492976-154916 | 2026-07-29 | AUDIT | audit
Task: First audit - fill Operating envelope, Surface inventory (25 rows), and Verify command; breadth-first shallow probes.
Changed: PLAN.md (envelope surfaces, 25 inventory rows, verify command, lessons), BACKLOG.md untouched (no findings filed), bootstrap of state files and .gitignore entry.
Checkpoint: 454104d. Stall note: audit iteration; changed state files plus .gitignore, no backlog items exist yet - expected for a first audit, not a stall.
Verification: Verify command exits 0 (37 passed, 1 xfailed, 1.63s). Known-answer probes all pass: utils date/interval family (parse_user_dt x4 input types, interval_to_timedelta x7, period format x6), utils adjust/parse family (auto_adjust/back_adjust hand-computed ratio 0.5, parse_quotes, parse_actions 4:1 split), screener nested query dict. Live invariant probes pass: download AAPL 5d (High>=Low/Open/Close, price sanity band), fast_info vs history cross-check, Search, MSFT info/income_stmt (Net Income in 5e10..2e11 band)/balance_sheet/holders/dividends/splits (>=9)/Sector/Lookup/earnings_dates. Tree verified byte-identical to upstream yfinance 1.5.2 sdist via pip download + diff -r --strip-trailing-cr (only pycache, packaging-excluded test fixtures, yahoo-keys.txt differ). Scores claim ONLY the 7 swept rows of 25: correctness None, security None, dependency hygiene None (minimum-version pins, CVE-aware curl_cffi>=0.15), testing None on swept rows. 18 rows remain unswept - these scores are not the whole project; later audits sweep the remainder (price repair math, history params, fundamentals freqs, live WebSocket, config/data/auth, domain, funds, analysis).
Learnings: Offline test subset is the only viable per-iteration gate; live endpoints work here and are needed for scraper sweeps. Pip-diff against the published sdist is a cheap integrity probe for vendored upstream code.
Next: BACKLOG.md empty, so iteration 2 runs a replenishing audit sweeping the cheapest unswept rows first: price repair math via fixture CSVs (known-answer pairs), utils merge/fix family, const/exceptions/shared, config.py.

## iter 2/10 | 6a492976-154916 | 2026-07-29 | AUDIT | audit
Task: Replenishing audit - sweep price repair math, utils merge/fix/tz family, config.py, static modules.
Changed: PLAN.md (4 rows flipped to swept, new sys.path lesson), BACKLOG.md (T1 Medium filed in Next, T2 Low filed in Later).
Checkpoint: 53e8512
Verification: Verify command green (37 passed, 1 xfailed). Price repair: TestPriceRepair 11/12 live incl. every fixture known-answer pair; the 1 failure (test_repair_zeroes_daily) reproduced and root-caused to test brittleness - corrupted day 2026-07-14 for BBIL.L had zero volume and no intraday candles, so _fix_zeroes correctly has nothing to reconstruct from; leaving NaN is honest behavior, filed T2 Low. Merge/fix family: 34 known-answer probes all pass (safe_merge_dfs on/oor/sum/product, live-row merge, prepost drop, dst shift, tz set, interval containment both sides, format_history_metadata). Config: round-trip and defaults pass; unknown option names silently no-op - filed T1 Medium. Static modules pass incl. version 1.5.2. Evidence integrity note: initial probe runs imported pip site-packages yfinance 1.4.1 because script-path invocation shadows cwd on sys.path; both probe suites re-run with PYTHONPATH pinned to the local tree and all results confirmed against local code. Scores claim only the 11 swept rows of 25: correctness None, testing Low (T2), error handling Medium (T1). 14 rows remain unswept; these scores are not the whole project.
Learnings: Script-path invocation shadows cwd - pin PYTHONPATH for probe scripts (added to Lessons). Fixture CSV pairs make price repair the best-tested computation in the project.
Next: 3+ open tasks not yet true (2 open) but iteration 3 executes top task T1 (Medium) per ledger order; replenishment audit follows when fewer than 3 remain after execution.

## iter 3/10 | 6a492976-154916 | 2026-07-29 | T1 | done
Task: T1 (Medium, error-handling) - config silently accepts unknown option names.
Changed: yfinance/config.py (validation boundary: _VALID_OPTIONS table, NestedConfig._validate raises AttributeError on unknown option get/set, ConfigMgr.__getattr__ raises on unknown section), yfinance/multi.py (removed dead backup/toggle of YfConfig.network.hide_exceptions at former lines 275-276/299 plus now-unused import - the key lives under debug, so the toggle wrote a dead key and provably never changed behavior in 1.5.2; deletion preserves shipped behavior exactly and avoids activating a cross-thread global toggle race), doc/source/advanced/config.rst (documented that unknown names raise).
Checkpoint: cb48be6
Verification: Acceptance check passes: yf.config.network.proxies raises AttributeError naming valid options (get and set), bad section raises listing valid sections, all six documented keys round-trip, repr intact; check failed on unfixed code (returned None silently, established iter 2). Verify command green (37 passed, 1 xfailed). Live smoke after multi.py change: download(['AAPL','MSFT'], 5d) returns data, bad ticker returns empty df with error logged (the 1.5.2 contract - errors go to a per-call ctx and the logger, not legacy shared._ERRORS). Contract preserved: every documented config key behaves identically; only formerly-silent invalid accesses now raise, and the enumeration grep found no such access left in the tree. T1 closed: config.py validation + dead-code deletion + doc update. Second instance of the class (multi.py dead key) recorded under Settled classes.
Learnings: The dead multi.py toggle is exactly the failure mode T1 guards against - the class fix caught a real latent bug during enumeration.
Next: config.py inventory row flipped stale by this fix; open tasks below 3, so iteration 4 re-sweeps config.py and replenishes via partial audit of unswept rows (base.py/ticker.py properties, fundamentals freqs, domain, search/lookup params).

## iter 4/10 | 6a492976-154916 | 2026-07-29 | AUDIT | audit
Task: Replenishing partial audit - sweep the 14 remaining unswept rows except history() params, using the live upstream suites as parameter sweeps plus targeted probes.
Changed: PLAN.md (14 rows flipped to swept at 8055a6c incl. config re-sweep), BACKLOG.md (T3 High filed in Now).
Checkpoint: 160b063
Verification: Verify command green (37 passed, 1 xfailed). Live suites: test_search/test_lookup/test_market/test_sector_region/test_data all pass (42), test_live/test_multi/test_download_concurrency pass (6), test_ticker 94 passed 1 failed. The failure is a genuine in-envelope defect filed as T3 High: PriceHistory action caches init to None (history.py:28-30) and only a successful fetch sets them, so Ticker('DJI').dividends returns None and .empty crashes - the shipped contract test test_badTicker pins Series and fails on unmodified upstream 1.5.2. Targeted probes: download() param sweep with output-changing assertions (group_by/auto_adjust/ignore_tz/actions/rounding), live WebSocket subscribe received a real tick in under 25s, Tickers batch surface, live screener size 5 vs 10 and predefined day_gainers invariant, config post-T1 re-sweep. No inert documented parameter found. Scores over the 24 swept rows of 25: correctness High (T3), testing Low (T2), error handling None post-T1; only scrapers/history.py history() fetch params row remains unswept - scores exclude it.
Learnings: The upstream test suite doubles as a rigorous parameter sweep for scraper surfaces; running it live is cheaper and stronger than reinventing probes.
Next: Iteration 5 executes T3 (High). History params row sweeps after, via tests/test_prices.py subset.

## iter 5/10 | 6a492976-154916 | 2026-07-29 | T3 | done
Task: T3 (High, correctness) - Ticker.dividends/splits/capital_gains return None instead of empty Series when the price fetch fails.
Changed: yfinance/scrapers/history.py (_get_history_cache coalesces the None sentinel to an empty pd.Series when storing the per-key cache - single boundary all three getters read through; matches the success path's existing empty-Series convention for no-events fetches).
Checkpoint: 02d9038
Verification: Acceptance passes: tests/test_ticker.py now 95 passed 0 failed live (test_badTicker was the failure, established failing on unfixed code iter 4); direct probe confirms Ticker('DJI').dividends/splits/capital_gains are empty pd.Series and .actions is a DataFrame, while MSFT dividends unchanged (50+ positive entries). Verify command green (37 passed, 1 xfailed). Contract preserved: successful fetches are untouched (caches already Series there); only the failure path changes from leaking None through a -> pd.Series annotated API to returning the same empty Series a no-events fetch returns. Callers read via get_dividends/get_capital_gains/get_splits/get_actions (base.py:479-489) and get_actions guards were already None-safe. The base.py+ticker.py inventory row re-swept by the full suite at this iteration's checkpoint. Price-repair row certification stands: the change is outside the repair function family.
Learnings: none beyond iter-4 entry.
Next: Ledger has T2 (Low) only - under 3 open tasks, but the sole unswept row (history fetch params) still needs its sweep; iteration 6 runs the final partial audit: tests/test_prices.py subset for history params, completing the inventory.

## iter 6/10 | 6a492976-154916 | 2026-07-29 | AUDIT | audit
Task: Closing full audit - sweep the last unswept row (history fetch params) and rescore every applicable dimension with fresh evidence.
Changed: PLAN.md (final row flipped; inventory complete at 25/25), BACKLOG.md untouched (no new findings).
Checkpoint: f7aec5c
Verification: Verify command green (37 passed, 1 xfailed). Final sweep: tests/test_prices.py 22 passed live (1 skip and 1 xfail both upstream-annotated, not findings) plus history param probe - interval, period, start/end, prepost, back_adjust, keepna each exercised at 2+ values that changed output (keepna needed an illiquid ticker: BBIL.L 1m has 2272 NaN candles kept vs 7 rows without). Full rescore over the complete 25/25 swept inventory, all evidence from this run at recorded commits: correctness None (T3 fixed, all known-answer/fixture/live suites green), security None (HTTPS endpoints, CVE-aware pins, no injection surface evidenced), testing Low (T2 open - brittle live test), error handling None (post-T1), performance None (no evidenced defect; caching and lazy loading exercised), documentation None (config docs updated with T1; no misleading docs evidenced), dependency hygiene None (minimum pins current), observability None (logger plus debug mode exercised), architecture and code quality None (no High/Medium evidence), UX/accessibility skipped (library, no user-facing UI). Zero High, zero Medium in-envelope on a full fresh-evidence audit: CLOSEOUT BEGINS - no further audits or replenishment this run; remaining work is the ledger (T2 Low) then convergence.
Learnings: keepna requires illiquid-ticker data to demonstrate effect; liquid tickers return no NaN candles - a documented-conditional no-op, not an inert parameter.
Next: Iteration 7 executes T2 (Low, testing), the only open task. Then convergence via evaluator gate.

## iter 7/10 | 6a492976-154916 | 2026-07-29 | T2 | done
Task: T2 (Low, testing) - test_repair_zeroes_daily fails spuriously when the blindly-chosen corrupted row is an untraded day.
Changed: tests/test_price_repair.py (test_repair_zeroes_daily now picks the middle row among Volume>0 days, with a comment explaining why untraded days cannot be reconstructed).
Checkpoint: 77e5744
Verification: Acceptance passes: pytest tests/test_price_repair.py::TestPriceRepair::test_repair_zeroes_daily passes live (1 passed, 1.32s); the unmodified test reproduced the failure in iter 2. Verify command green (37 passed, 1 xfailed). Contract note: test-only change; library code untouched, so no inventory row goes stale (the price-repair row's implementing code is the repair functions in scrapers/history.py, unchanged).
Learnings: none new.
Next: Ledger empty (Now/Next/Later all clear), closeout active, inventory 25/25. Iteration 8 attempts convergence through the adversarial evaluator gate.

## iter 8/10 | 6a492976-154916 | 2026-07-29 | WRAPUP | converged
Task: Convergence declaration via the Definition of done path.
Changed: BACKLOG.md (Converged line appended naming 5b1ff114c095356fe89b51689a6205a95e3ccf32, the final code checkpoint).
Checkpoint: 4c2359a
Verification: Evaluator: PASS - fresh-context sub-agent re-ran the Verify command (37 passed, 1 xfailed, exit 0) and all three closed tasks' acceptance checks (T1 config validation probes, T3 test_badTicker 1 passed live plus DJI/MSFT direct probes, T2 repair test 1 passed live), confirmed the diff against beac22d matches the declared scope, probed the touched code adversarially (deepcopy-of-config-section crash judged pre-existing, out-of-usage and Low; empty-Series dtype cosmetic Low) and found no in-envelope High or Medium. Convergence conditions: closing full audit iter 6 scored zero High zero Medium over the complete 25/25 inventory; Now/Next/Later empty with no [b] tasks and nothing silently dropped (T1 Medium, T2 Low, T3 High all completed); commits since the clean audit are exactly the T2 fix plus state-file bookkeeping; Verify green this iteration (37 passed, 1 xfailed).
Learnings: none new.
Next: Run ends converged. Future runs ratchet from the Converged line unless code changes or a focus directive arrives.

## iter 9/10 | 6a492976-154916 | 2026-07-29 | RATCHET | converged
Task: Re-declare convergence after stop-hook rejection - the Verify Command line in PLAN.md carried a trailing parenthetical annotation the hook executed verbatim, which is a shell syntax error (exit 2); the command itself was and is green.
Changed: PLAN.md only (Command line made purely runnable, annotation moved to a Note line below it, lesson recorded).
Checkpoint: 706fb71
Verification: Verify command green run exactly as now written (37 passed, 1 xfailed, exit 0); reproduced the rejection cause (bare shell parenthetical exits 2). Ratchet verification: latest Converged line names 5b1ff114c095356fe89b51689a6205a95e3ccf32, Now/Next/Later empty, no focus directive, and git diff --name-only plus git status against that hash show only PLAN.md, BACKLOG.md, JOURNAL.md changed. Evaluator not invoked (ratchet path; the iter-8 PASS stands).
Learnings: The Verify Command line is executed verbatim by the stop hook - keep it a pure runnable command (added to Lessons).
Next: Run ends converged via ratchet.
