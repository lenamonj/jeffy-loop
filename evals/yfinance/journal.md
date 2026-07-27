# Engineering log - ranaroussi/yfinance price-repair audit

Date: 2026-07-27. Workspace: scratch clone only. Nothing in `C:\jeffy` was touched except writing this eval directory at the end, in one batch. Nothing pushed, no upstream issue or PR.

## Setup
- `git 2.50.1`, `gh 2.89.0`, Python 3.13.8 in a fresh venv. Cloned `https://github.com/ranaroussi/yfinance.git`, HEAD `beac22d981ab37362a70c9e4e49261ac622acbe4`, 2026-07-23, "Version 1.5.2".
- `gh api repos/ranaroussi/yfinance --jq .stargazers_count` -> `24812`. Matched the research note, so no correction needed.
- `pip install -e ./yfinance` plus `scipy` (imported lazily by the 100x detector). Resolved to pandas 3.0.5, numpy 2.5.1, scipy 1.18.0.
- Did not run the upstream suite. It needs live Yahoo for timezone and `fast_info` lookups on essentially every test, and the research note flags it as rate-limited. Recorded as a disclosed limitation rather than worked around with retries.

## Prior work
- Read `C:\jeffy-launch\evals-research\partial\yfinance\` first, as instructed. It had a repro, a patch and a truncated report from an earlier attempt. Reused none of it as-is: rebuilt the harness, re-derived every line number from this HEAD, and re-reproduced every claim. Two of its findings I could not stand behind in the form written and one framing I had to reverse.
- The one I reversed: the earlier attempt scored the crude fallback's `Adj Close` omission and the `Repaired?` gap but did not find the `currencyRepaired` / whole-table-revert interaction, which turned out to be the worst defect in the module. Starting from its conclusions would have missed it.

## Lead triage
- Pulled issue bodies with `gh api repos/ranaroussi/yfinance/issues/N` rather than trusting summaries. #2890's traceback names `history.py:1647` - identical to this HEAD, so the reporter was on the same code.
- #2866's own printed output settled the primary lead against the lead's framing. The reporter shows `history_metadata` is not in his output at all, and `price_repair.rst:9` documents the currency conversion as intended behaviour. So "silently corrupts correct data" is not what happens; a documented conversion happens, and the flag lies about it. Wrote that down before writing any fix, so the report could not drift back to the more dramatic version.
- The "Volume not adjusted" complaint is simply wrong. A currency rescale does not change a share count. Asserted it as a passing regression case rather than leaving it as an opinion.

## Offline harness
- Two obstacles. First, blocking `socket.socket` outright breaks the import chain - `ssl` subclasses it at import time and dies with `TypeError: function() argument 'code' must be code, not str`. Fixed by importing first, then replacing `socket.socket.connect`, `connect_ex`, `create_connection` and `getaddrinfo`.
- Second, `PriceHistory.__init__` builds a session. Constructed via `__new__` and set the seven attributes the repair functions actually read. That is what makes every case a pure function call.
- The key that unlocked the crude 100x fallback offline: `_reconstruct_intervals_batch` returns early with "Too old" when every tagged row is outside the sub-interval lookback (`min_lookbacks['1h'] = 730 days`). Dating the fixture 1200 days back makes the fallback deterministic and network-free. Confirmed by the captured log line, not assumed.

## Class audit
- Enumerated every assignment to a price, `Adj Close`, `Dividends` or `Volume` column in `history.py` with one regex, then read each site for a matching `Repaired?` write. 60-odd sites. Exactly two price-mutating ones lack a flag: `_standardise_currency` 1094-1096 and the crude fallback 1254-1289. Two dividend-only ones also lack it, 2547 and 2571.
- That is four instances of one idiom. Under the three-strike rule I fixed the two price sites - the ones with the reproduced consequence - and filed the two dividend sites as a Proposed contract question instead of patching a fourth instance. `price_repair.rst:18` already carves an Adj-Close-only fix out of the flag, so the dividend-only case is genuinely the maintainer's call.
- Same discipline on the read-only-numpy class: grepped every `to_numpy()` followed by an in-place write. `history.py:2802-2803` already guards with `if not price_data.flags.writeable: price_data = price_data.copy()`. Line 1642 is the only unguarded one. One instance, so one fix - not a sweep.

## Findings, in the order they fell out
- Y1 came straight from #2890 and reproduced first try. The upgrade came later: replaying `tests/data/SSNLF-1d-bad-div.csv` - upstream's own fixture for "Adj Close went to infinity" - triggers it. That is much better evidence than my synthetic frame, so the synthetic frame stayed as the repro case and the fixture became the regression proof.
- Y3 and Y4 came from reading the crude fallback, not from the leads. Y3's severity only became clear after tracing `Adj Close` through the restore loop at 1304-1310 and then into `utils.auto_adjust`, which is on by default. That chain is why a "crude" fallback returns a fully 100x-wrong row on the default path.
- Y6 came from noticing that `n_before` at 1239 reads a snapshot taken at 1217, before the tags are written at 1237, while the sibling `_fix_zeroes` gets the order right at 1437-1438. Verified by capturing the logger while a repair provably happened: zero lines.
- Y7 came from reading `_repair_capital_gains` for the flag audit and noticing `sum(dcs.values()) / len(dcs)` with no guard on an empty dict. Two realistic shapes reach it.
- Y2 was last and worst. Started as "why is `currencyRepaired` set unconditionally at 1098?", followed the only reader to 3381, and found that the revert rescales the whole table and inverts the whole flag array after what may have been a 20-row repair. Built the fixture, got 90 of 90 rows wrong. Then built the control with the branch disabled: 0 of 90 wrong. That pair is the finding.

## Fixes
- Six edits in `history.py`, one line in `price_repair.rst`. The crude fallback's two near-identical loops collapsed into one local helper rather than being patched twice - the class rule applied to the fix, not just the finding.
- Deliberately did not touch: the `prices_in_subunits = True` default (needs live data to re-decide), the `Volume` behaviour in `_standardise_currency` (already correct), and issue 2857's OHLC-clipping request (a feature, and one with a false-positive profile only the maintainer can accept).
- The Y8 fix converts a silent assumption into a logged one and removes the bare `except Exception: pass`. Kept the third branch for `Close <= 0` so the removed except cannot become a new `ZeroDivisionError`.

## Verification
- `repro.py` unpatched at HEAD: 3 pass, 13 fail. Patched: 16 pass, 0 fail. Ran unpatched via `git stash` on the same editable install so both runs used identical fixtures.
- Built `regress.py`, a differential harness replaying all 42 CSV golden fixtures in `tests/data/` through the same repair calls the upstream tests make, digesting each result. Unpatched: 41 match, 1 raises. Patched: 42 match. Diffing the two result files shows exactly one changed row, `SSNLF`. So the patch fixes upstream's own broken fixture and provably changes nothing else.
- One harness bug caught by that: my first pass called `_fix_bad_div_adjust` with `prepost=False` for the 15m `EA` fixture, where upstream passes `True`. It showed as a difference in both the patched and unpatched runs, so it never contaminated the differential, but I fixed it rather than explaining it away.
- Cross-checked Y1 on a second venv with pandas 2.3.3: it passes with the old default and fails with `copy_on_write = True`. Stated in the report in both directions instead of claiming a universal crash.
- `pyflakes` clean on the patched file.

## Judgement calls I want on the record
- Did not score Y4 as High. The output is wrong, but the row is partially repaired and the previous value was worse; a bounded degradation on a self-declared crude fallback is Medium under this rubric. The temptation to call it High because "users get wrong High/Low" was real and I turned it down.
- Did not score Y2 lower because its trigger is compound. Both components - a GBp table and a partial 100x block - are states this module's own code and fixtures exist to handle, so their intersection is in envelope. What I would not claim is a frequency, and I did not.
- Did not restate the primary lead as given. "Converts pence to pounds, a 100x price error" is the reporter's reading, not the code's contract, and repeating it would have inflated the receipt with a finding that is documented behaviour. The report says so plainly and puts the real 100x corruption where it actually is.
- Did not fabricate a live-data check. Three of the four issue tickers were never fetched, and the report names them.
