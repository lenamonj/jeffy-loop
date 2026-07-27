# Engineering log - PyPortfolio/PyPortfolioOpt audit

Date: 2026-07-27. Workspace: scratch clone plus a pinned worktree; nothing in the upstream repo touched, nothing pushed, no issue or PR opened.

## Setup
- `git 2.50.1`, `gh 2.89.0`, Python 3.13.8 in a fresh venv.
- Cloned the repo. HEAD `a6638d2e06dae6f444fd022cfd4b3c528902a85b`, `2026-07-07 21:13:11 +0000`, "[DOC] fix outdated links and badges in README (#735)".
- `gh api repos/PyPortfolio/PyPortfolioOpt --jq .stargazers_count` -> `5894`.
- Installed `-e .[all_extras,dev,cov]`. Resolved: cvxpy 1.9.2, numpy 2.5.1, pandas 3.0.5, scipy 1.18.0, scikit-learn 1.9.0, cvxopt 1.3.3, ecos 2.0.14, matplotlib 3.11.1, plotly 6.9.0, pytest 9.1.1. Same scipy the failing CI job used.

## Baseline
- `gh api .../actions/runs/28899115146` confirms `head_sha` is exactly my HEAD and `conclusion` is `failure`. Pulled `--log-failed`: 5 unique failing tests, all in `test_hrp.py`, all `AttributeError: module 'scipy.cluster.hierarchy' has no attribute '_LINKAGE_METHODS'` at `hierarchical_portfolio.py:179`. Job line: `5 failed, 280 passed, 32 skipped`.
- Local first run: `9 failed, 303 passed, 5 skipped`. Two of the nine were `_tkinter.TclError` - a GUI backend artefact of this Windows box, not the project. Re-ran with `MPLBACKEND=Agg`, which is what the CI workflow forces on Windows: `7 failed, 305 passed, 5 skipped`. Used that as the baseline and disclosed the tkinter exclusion rather than quietly dropping it.
- Local has 7 where CI has 5 because CI's coverage job installs no matplotlib, so its 32 skips include the two `test_plotting` tests that hit the same code path. Same root cause, different visibility.
- Checked whether it is environmental before calling it a defect: installed `scipy==1.17.0` in a throwaway venv - `_LINKAGE_METHODS` present. scipy 1.18.0 (PyPI upload 2026-06-19) - absent; it now lives in `scipy.cluster.hierarchy._hierarchy_impl`. `pyproject.toml` says `scipy>=1.3.0`, unbounded. Downloaded the `pyportfolioopt-1.6.0` wheel from PyPI and grepped it: same line at `pypfopt/hierarchical_portfolio.py:152`. So it is a real shipped defect, not a local accident.

## Lead triage
- Pulled the three issue bodies with `gh api` rather than trusting the summaries.
- 737 (singular PSD covariance): reproduces immediately. `LinAlgError: Singular matrix` from `cla.py:357`. Also reproduces via `min_volatility` and `efficient_frontier`, so it is the shared `_solve`, not `max_sharpe`.
- 738 (equal expected returns): the `TypeError` reproduces. The *non-determinism* in the title does not. 30 random problems x 20 in-process repeats: 1 distinct outcome each. Five separate interpreters under different `PYTHONHASHSEED`: 1 distinct result set. The plausible mechanism was `_diff_lists` returning `list(set(...) - set(...))`, but the elements are small integers whose CPython hash is the integer itself, so the iteration order is content-determined. Recorded as not reproduced with the evidence attached rather than quietly dropped.
- 694 (ill-conditioning warning): confirmed nothing inspects a condition number anywhere. But a PSD matrix with condition number 1.0e+12 gave the corner solution it actually implies from both optimizers, not garbage, so there is no wrong result to file. Missing diagnostic, not a defect.

## Class audit
- Built a 40-cell matrix: `CLA`, `EfficientFrontier` and the risk-model helpers crossed with singular PSD covariance, equal expected returns, a single asset, NaNs in the price history, negative-definite, indefinite, ill-conditioned, a zero price, a two-row history, and a length mismatch. Classified each outcome by whether the exception came from inside `pypfopt` or from a third-party frame. At HEAD: 1 clear, 8 raw, 6 warn, 25 silent.
- That matrix is what turned up the two findings the leads never mentioned: `CLA` returning a NaN weight silently where `EfficientFrontier` rejects the same input, and `cvxpy.SolverError: 4` escaping the base optimizer with a bare status integer for its whole message.

## The finding I did not go looking for
- While characterising the equal-returns case I ran a control: 300 random *non*-degenerate problems, distinct expected returns, well-conditioned positive definite covariances. Compared `CLA.max_sharpe` against `EfficientFrontier.max_sharpe`. 22 of 300 came back short, worst 2.02 percent of Sharpe. That is not a degeneracy, that is ordinary input.
- Verified the oracle before believing the result. Ran scipy SLSQP from 60 Dirichlet starts on the worst case: it agreed with cvxpy to 10 significant figures, and both disagreed with CLA. So CLA was wrong, not the oracle.
- Instrumented `_solve` with the two purges disabled. 6 raw turning points, of which point 4 had `sum(w) = 0.7645`. `_purge_num_err` deletes it correctly, and then `max_sharpe` golden-sections between points 3 and 5, which are no longer adjacent. The chord cuts the corner. Best achievable along the raw chain was 0.2308095, cvxpy's optimum 0.2308604, CLA's answer 0.2262073.
- Traced the off-budget point to `_get_matrices` slicing `wB` out of `self.w[-1]` while `_solve` had already written the boundary value into the live `w`. Tested the hypothesis rather than asserting it: subclassed CLA with a live-`w` variant and re-ran all 300. Budget violations 50/300 -> 0/300 (worst 9.07e-01 -> 2.13e-14). Sharpe shortfalls 22/300 -> 0/300.
- The upstream structure matches Bailey and Lopez de Prado's published CLA verbatim, so this is inherited rather than introduced. Said so rather than implying the port was careless.

## The fix I tried and rejected
- Issue 738's own diagnosis implies guarding the raw `lam` with `_infnone`. Implemented exactly that and measured it: 294/300 equal-mu problems now return an answer, and 256 of those are silently suboptimal, worst 85.8 percent of Sharpe. It trades 245 loud crashes for 256 silent wrong answers. Kept the variant in `repro.py` as item N2 so the claim is checkable, and fixed the degeneracy by failing loudly instead.
- Evidence that equal returns is a bug and not a documented precondition: swept eps in `mu = [0.1, 0.1 + eps]`. At 1e-2, 1e-4, 1e-6, 1e-8 and 1e-10 CLA returns the correct answer, converging to `[0.5, 0.5]`. At exactly 0 it returns `[0.0, 1.0]`. Discontinuous at a single point is a bug, not a precondition.

## The fix I tried and reverted
- First attempt at the `CovarianceShrinkage` NaN finding was listwise deletion at a single boundary in `__init__` plus a warning. Suite went from 7 failures to 7 different failures. Looked at why: the project's own fixture is 7126 rows of which 6230 contain at least one NaN, because the 20 tickers list at different dates. Listwise deletion throws away 87 percent of the history. My fix was wrong.
- Reverted the estimator change and kept only the warning. Then measured the defect properly on that same fixture: `ledoit_wolf` gives BABA an annualised variance of 0.01344 against `sample_cov`'s 0.10096, and the understatement per ticker tracks its missing fraction almost exactly. Downstream, `min_volatility` puts 43.2 percent in BABA versus 12.6 percent. That is the number that made it a High.
- Did not seize the estimator convention. There is no clearly-right minimal fix - pairwise deletion is what `self.S` already does but `sklearn.covariance.ledoit_wolf` takes a data matrix, not a covariance - so it went under Proposed with the failed listwise attempt written up as part of the case.

## Verification
- Full suite after all fixes: `312 passed, 5 skipped`, from `7 failed, 305 passed, 5 skipped`. `ruff check .` clean, `ruff format --check` clean.
- One upstream test line changed: `tests/test_risk_models.py:227`, `assert len(w) == 1` inside a `pytest.warns(RuntimeWarning)` block. `pytest.warns` records every warning in the block, not just the matching category, so the new UserWarning tripped an assertion that was only ever about RuntimeWarnings. Now filters by category first. Disclosed in the report; nothing deleted, skipped or loosened.
- Round-tripped the deliverable properly. Fresh `git worktree` pinned at `a6638d2e...` in a *separate* venv, ran `repro.py`: 3/13 pass (the two non-reproduction items and the wrong-fix demonstration - exactly the three that should pass at HEAD). `git apply --check` then `git apply fixes.patch`: 13/13. Suite on that worktree: 7 failed before, 312 passed after. Reverted it and confirmed the 7 come back.

## Judgement calls I want on the record
- Did not grade the ill-conditioning issue (694) as a defect. Nothing inspects the condition number, but nothing returned a wrong answer either. Filing a missing warning as a bug would have made the count look better and the audit worse.
- Did not grade the non-PSD covariance path in `CLA` at all, beyond recording it in the enumeration and routing it. A non-PSD matrix is not a covariance matrix, `EfficientFrontier` documents that it will fail, and the remedy is a behaviour change.
- Did grade the `SolverError` escape as a real Medium anyway, because the precondition being documented does not license a message whose entire content is the integer 4.
- Deleted the commented-out `self.mean[-1, 0] += 1e-5` perturbation hack at `cla.py:72-73`. It was the abandoned guard for exactly the degeneracy PPO-3 now handles properly; leaving dead code next to a real fix invites someone to uncomment it.
- Every number in the report came out of a run recorded here. The 300-problem sweeps use `np.random.default_rng(3)` so they are reproducible, and `repro.py` regenerates them from the same seed.
