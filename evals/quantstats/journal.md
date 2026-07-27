# Engineering log - ranaroussi/quantstats audit

Date: 2026-07-27. Conducted under Jeffy's method; not a `/jeffy` loop run, no loop iterations.
Workspace: scratch clone only. Nothing in the upstream repo was touched, nothing was pushed, no issue or PR was opened.

## Setup

- `git 2.50.1`, `gh 2.89.0`, `C:\Users\lenam\AppData\Local\Programs\Python\Python313\python.exe` = Python 3.13.8. Toolchain present, proceeded.
- Cloned `https://github.com/ranaroussi/quantstats.git`. HEAD `fbd10daed0227aa0d10da6513f1b15e7e98d7fae`, 2026-01-13, "fix: misc bugfixes for 0.0.78 release (#499, #501, #502)". `git describe --tags` -> `v0.0.81`. `quantstats/version.py` -> `0.0.81`.
- `gh api repos/ranaroussi/quantstats --jq '.stargazers_count'` -> `7485`. Also captured `default_branch=main`, `license=Apache-2.0`, `open_issues_count=26`. `pushed_at` is 2026-07-20 but the newest commit on `main` is 2026-01-13; the repo has 16 branches, so `pushed_at` reflects a side branch. Confirmed `gh api repos/.../commits/main` returns the same sha as the clone before trusting the hash.
- venv, `pip install -e ./qs`. Resolved to pandas 3.0.5 / numpy 2.5.1 / scipy 1.18.0.
- Baseline `pytest tests -q`: 2 failed, 123 passed. Both failures are `_tkinter.TclError` in `test_plots`, i.e. no Tk on this Windows box. Re-ran with `MPLBACKEND=Agg`: **125 passed, 0 failed**. Recorded the Agg run as the baseline and said so in the report rather than quietly using the green number.

## Lead triage

- Pulled all five issue bodies with `gh api repos/.../issues/N` plus their comments, rather than trusting the one-line summaries in the candidate file. Two of the five were reframed by their own comment threads.
- #493: the maintainer's own reply (2025-12-29) already states the trade metrics are period statistics by design. Verified the arithmetic anyway - `payoff_ratio` and `profit_factor` match their definitions to 1e-12 - and declined it. Filing a documented design decision as a defect would have inflated the count and wrecked the receipt.
- #518: rendered `qs.plots.yearly_returns` at 8.5, 9.5, 10.5, 12.5 and 21 year spans under the Agg backend and read `ax.get_xticklabels()` and `ax.containers` back programmatically instead of eyeballing a PNG. Labels and bar counts match the EOY index at every span. Also disproved the hypothesis posted in the thread: pandas puts bar categories at `0..n-1`, so the `np.arange(len(years))` override cannot misalign them. Recorded as not reproduced with the measurement, not with an opinion.
- #514: measured the arithmetic-versus-geometric active-return gap (16.30% on 10y of daily data), then declined it. Arithmetic active return is the Grinold-Kahn convention and is what the docstring says. But the same probe, run against a zero benchmark, showed `sharpe/information_ratio` = exactly `sqrt(252)`. That is the real defect in that function and the issue does not mention it.
- #535: rather than argue discrete-versus-continuous, derived the exact two-outcome Kelly (`f* = p/l - q/w`) and compared. quantstats' answer is exactly `l * f*`. That turns a matter of convention into an arithmetic identity, and it holds for the discrete case the current formula is supposed to be right for.
- #516 reproduces exactly as filed. Only lead that did.

## Class audit

- Did not read the annualization behaviour off the source. Wrote a probe that calls each function at `periods=63` and `periods=252` and reports the exponent `k` in `f(252)/f(63) = 4**k`. `0.5` = `sqrt(periods)`, `1.0` = linear, `0.0` = the argument does nothing. That is what caught `treynor_ratio` (k=0.0 with a documented "Periods per year for annualization") and `probabilistic_sharpe` on the annualize path.
- The functions with no `periods` argument at all needed a different probe. Ran them alongside their annualized neighbours in `reports.metrics` output and looked for exact `sqrt(252)` ratios. Found three: `information_ratio`, `risk_return_ratio` and, in a different flavour, `treynor_ratio`'s cumulative numerator.
- Three instances of one root cause hit the three-strike rule. Stopped patching instances. `ulcer_performance_index` and `serenity_index` are the fourth and fifth; both were enumerated in the class table and routed under Proposed instead, because neither takes a `periods` argument and neither docstring claims annualization, so there is nothing to point at except a convention choice.
- The `inspect.stack()[1][3]` dispatch in `_prepare_returns` was the root cause of the `rf` findings. Enumerated all four call sites that depended on the caller's function *name* before touching it, and settled each in a table. `_prepare_benchmark`'s exclusion turned out to be correct (it prevents double-subtraction); the other three were bugs, one of them latent - `rolling_volatility` passes `rolling_period` into the `rf` slot and is saved only by being on the exclusion list.
- The clincher on `cagr` came from `reports.py` itself, not from the docstring: line 1314 calls `cagr(df, rf, ...)` and lines 1550-1563 call `cagr(df[...], 0.0, ...)`. The author wrote two different calls for two different rows, and at HEAD all five return the same number.
- `aggregate_returns`: 12 docstrings in `stats.py` document `('D','W','M','Q','Y')`. Tested all five plus the spelled-out forms. Three silently no-op, one raises. Fixed once at the boundary rather than 12 times at the call sites, per the class rule.

## Fixes

- Kelly: replaced the discrete form with a root find on `E[r/(1+f r)] = 0` over the interval where the objective is concave, using `scipy.optimize.brentq`. Before choosing, benchmarked three candidate fixes against the exact answer on six distributions (two-outcome, two normals, Student-t(4), lognormal). The obvious cheap fix - dividing the existing formula by `|avg_loss|` - is exact for two-outcome series but 57% to 100% too high for continuous ones. The Gaussian `mu/var` shortcut is within 1.5% for continuous but 8% off for two-outcome. Only the root find is right in both, so that is what went in.
- `_prepare_returns`: deleted `inspect.stack()`, added `apply_rf=True`, changed `if rf > 0` to `if rf != 0`, and put `apply_rf` into the cache key so the two variants cannot collide. `import inspect` then became dead and was removed.
- `aggregate_returns`: `_PERIOD_ALIASES` map plus `_normalize_period`, `.week` -> `.isocalendar().week`, and a `ValueError` on an unrecognised code so the silent no-op cannot come back.
- The rest are small: `rar` gains `periods`; `gain_to_pain_ratio` gains `periods`; `treynor_ratio`'s numerator becomes `cagr(...)`; `information_ratio` gains `periods`/`annualize`; `rolling_greeks` uses rolling means; `recovery_factor` compounds by default; `reports.py` 10Y offset becomes `months=119`; `risk_return_ratio` docstring corrected.
- Verification: `pytest tests -q` under Agg is `125 passed` before and after, with no test weakened or deleted. `repro.py` is 33/33 PASS against the patch.

## Round-trip check on the deliverable

- `git stash` on the clone put it back at pristine HEAD, ran `repro.py` there: **26 FAIL, 7 PASS**, every QS-* check failing with its own expected-versus-actual numbers and every N-* check passing. `git stash pop`, ran again: **33/33 PASS**. That round trip is what proves the checks bind to the code rather than restating it.
- First HEAD run aborted with `TypeError: rar() takes from 1 to 2 positional arguments but 3 were given`. A reproduction script that dies at the first widened signature is useless to anyone running it upstream, so added a `safe()` wrapper that records the exception text as the observed value. Every check now reports independently.
- `repro.py` is fully offline: `numpy.random.default_rng` only, no network, no market data, no yfinance call.
- Generated the tearsheet exhibit by running the same `reports.metrics` call under stash and under patch and diffing: 8 of 81 rows change.

## Judgement calls I want on the record

- Five findings scored High. Checked each against the rubric's "users get wrong results" rather than against how impressive it sounded. All five put a wrong number into `reports.html` output or return one from a documented public call: Kelly off ~100x, Risk-Adjusted Return off 56x on a monthly report, CAGR ignoring a documented `rf`, `best(aggregate='Y')` silently returning the best day, information ratio off by `sqrt(252)`.
- Did not file four of the five referenced leads at rubric severity. #493 and #514 are defensible conventions, #518 does not reproduce. Two of the three are on functions where a genuine defect does exist, and I filed that instead of the reported one. That distinction is the whole point of the audit and I would rather the receipt show three declines than three inflated findings.
- Did not touch `serenity_index` even though it is visibly inconsistent with `recovery_factor` on the same quantity, because its formula cites a whitepaper I could not read offline. Disclosed that rather than guessing.
- Did not annualize `risk_return_ratio` despite it being the third instance of the same root cause. It takes no `periods` argument and claims no annualization; only its docstring is wrong, so only its docstring was changed. Changing the number would have been seizing a convention.
- Did not seize the three behaviour-changing adoptions. The patch implements them and the report names the alternative for each, so the maintainer gets a real choice rather than a take-it-or-leave-it.
- `cagr`'s `years = len(returns)/periods` looks wrong at first glance and is not; it is self-documented and internally consistent. Verified it to 1e-15 against a closed form and wrote it up as a non-finding, because an audit that cannot say "this one is fine" cannot be trusted when it says the others are not.
