# Journal archive

Rotated out of JOURNAL.md, oldest first. Append-only and cumulative across
every rotation and every run; entries are never removed or rewritten.
## iter <i>/<N> | <run-id> | <YYYY-MM-DD> | <task-id or AUDIT or RATCHET or WRAPUP or SALVAGE or ROTATION> | <done|blocked|audit|converged|salvage|rotation>

SALVAGE entries take status salvage; ROTATION entries take status rotation.

run-id is the first 8 characters of the session id, a hyphen, then the HHMMSS of started_at from the loop state frontmatter, so two runs in one session are told apart. Body fields, in order: Task, Changed, Checkpoint (the jeffy checkpoint commit hash, or none with the reason), Verification, Learnings, Next.

The closing entry that declares convergence carries the evaluator verdict in its Verification field: `Evaluator: PASS - <one-line summary>`, or `Evaluator: unavailable (<reason>)`.

Closed tasks are recorded here as one line each (ID, title, closing evidence), because BACKLOG.md deletes them. Rotation: when this file exceeds 500 lines, move all but the last 10 entries to the end of JOURNAL-archive.md, appending to whatever that file already holds and never overwriting it, because the archive accumulates across every rotation and every run; create it only when it does not already exist, and record the rotation as a ROTATION entry.

## iter 1/10 | deef07ee-221242 | 2026-07-28 | AUDIT | audit

Task: First full audit of PyPortfolioOpt 1.6.0. Filled the Operating envelope, the Verify command, and the Surface inventory, then swept the inventory breadth-first with known-answer and invariant probes before filing.

Changed: PLAN.md (envelope, 26 inventory rows, verify command), BACKLOG.md (5 findings filed).

Checkpoint: 83459dc81b3976fd515c9f046447653affededfe

Stall check: not applicable - this iteration filed 5 backlog items and changed the inventory from empty to 26 rows.

Bookkeeping correction: the first checkpoint swept in `weights.csv`, a test artifact the README example test writes into the repo root. It has been untracked and added to .gitignore in the bookkeeping commit, and the underlying issue is filed as PR-06.

Verification: Baseline `MPLBACKEND=Agg ./.venv/Scripts/python.exe -m pytest ./tests -q` is RED at a6638d2 - 5 failed, 279 passed, 33 skipped; all five failures are tests/test_hrp.py sharing PR-01's root cause. Sweep evidence: 39-check probe over expected_returns and risk_models (37 passed, 2 real failures -> PR-04), 60-check probe over objective_functions, base, and the four efficient-frontier classes (54 passed; 2 were my own probe errors - a slack `>=` return constraint and an infeasible market-neutral target - and the rest -> PR-03), 35-check probe over CLA, Black-Litterman, discrete allocation, HRP, plotting and exports (5 HRP failures -> PR-01, 1 -> PR-02). Known-answer anchors used: two-asset min-variance closed form, CAGR identity, CAPM beta==1 identity, He-Litterman zero-omega and infinite-omega limits, closed-form shrinkage, numpy `cov` and pandas `corr` as reference implementations, and CLA cross-checked against EfficientFrontier. Both filed automatable acceptance checks were run against the unfixed code and observed to fail (PR-01 AssertionError, PR-05 AssertionError after correcting the check, which first failed for its own reason).

Dimension scores, claiming only the 24 swept rows of 26: correctness High (PR-01, PR-02, PR-03), dependency hygiene High (PR-01: private scipy API behind an unbounded `scipy>=1.3.0` pin), documentation Medium (PR-02, PR-04), error handling Medium (PR-03), testing Medium (`tests/test_black_litterman.py::test_bl_weights` passes a computed delta and asserts only that weights sum to 1 and match view direction, so it cannot fail on PR-02), architecture Low, code quality Low (PR-05), developer experience Low, security None, performance None, observability None, UX and accessibility not applicable - an importable library with no user-facing surface. Two rows remain unswept and are excluded from these scores: `min_cov_determinant` (deprecated) and `plot_dendrogram` (blocked by PR-01).

Learnings: The project venv at `.venv` already has an editable install and is the only working interpreter; the global Python 3.13 has no cvxpy. matplotlib and plotly were absent and had to be installed into `.venv` before the plotting row could be swept. Two Black-Litterman parameters look inert on first probe but only one is a defect: `tau` genuinely cancels under the default He-Litterman omega and `docs/BlackLitterman.rst:187` documents that, whereas `risk_aversion` cancels through an undocumented normalization - checking the user guide before filing separated them.

Next: PR-01, the only High and the blocker for two inventory rows and all five failing tests.

## iter 2/10 | deef07ee-221242 | 2026-07-28 | PR-01 | done

Task: PR-01 (High) - `HRPOpt.optimize()` validated `linkage_method` against the removed private scipy attribute `sch._LINKAGE_METHODS`, making the entire HRP surface and `plotting.plot_dendrogram` unreachable on scipy 1.18.

Changed: pypfopt/hierarchical_portfolio.py (deleted the private-attribute guard, documented the ValueError it preserved), pyproject.toml (scipy pin bounded to `<2.0.0`), PLAN.md (HRP and dendrogram inventory rows re-swept, Lessons), BACKLOG.md (PR-01 closed, private-attribute class settled).

Checkpoint: 1479e689178cad1d837ba17b06bf271e2af137e7

Verification: Both acceptance checks pass - `pytest ./tests/test_hrp.py -q` is 6 passed, and the `_LINKAGE_METHODS` source assertion exits 0. Verify command went from RED (5 failed, 279 passed, 33 skipped) to GREEN: 302 passed, 15 skipped, 0 failed. The skip count fell because matplotlib and plotly were installed in iteration 1, so the plotting tests now execute rather than skip. Contract preserved: `optimize()` still raises `ValueError` for an unrecognised method, now from scipy's own `linkage` with the message "Invalid method: blah", which is what `tests/test_hrp.py::test_hrp_errors` pins; behaviour for every valid method is untouched. Re-sweep evidence beyond liveness: with a diagonal covariance matrix HRP must reduce to inverse-variance weighting, and the observed weights [0.0466, 0.1865, 0.0207, 0.7461] match the closed form to 1e-6. `linkage_method` was checked as a live parameter - it changes nothing on 4 near-independent assets, but on 10 assets with two correlated blocks and a bridge asset, `complete` and `ward` move weights 0.0976 against `single`, so the parameter is live and no finding was filed.

Learnings: Deleting the guard was the whole fix - scipy's `linkage` already validates its `method` argument and raises the same exception type, so the pre-check bought nothing and cost the private-API coupling. Sweeping a parameter for inertness needs data whose structure the parameter can actually act on; a flat result on unstructured data is weak evidence, and the 4-asset probe would have produced a false finding had it been filed.

Next: PR-02 (Medium) - `bl_weights()` normalizes away the documented `risk_aversion` parameter.

## iter 3/10 | deef07ee-221242 | 2026-07-28 | PR-02 | done

Task: PR-02 (Medium) - `bl_weights()` normalizes its solution to sum to one, which cancels `risk_aversion` exactly, leaving a documented parameter inert while the docs taught users to compute and pass a delta.

Changed: pypfopt/black_litterman.py (bl_weights docstring), docs/BlackLitterman.rst (caution block after the bl_weights example), tests/test_black_litterman.py (two new tests), BACKLOG.md (PR-02 closed, PR-07 filed).

Checkpoint: db573529f355ff52a9afa84b772e0783e1e85ef3

Verification: Resolved by documenting rather than by honouring delta, and the rationale is that the normalization is the deliberate library-wide contract: `BlackLittermanModel` inherits `BaseOptimizer`, `docs/BlackLitterman.rst:203` states it follows the same API as `EfficientFrontier`, and `tests/test_black_litterman.py::test_bl_weights` pins both `sum(w) == 1` and twenty exact weight values. Honouring delta would have meant returning leverage-bearing weights, breaking that contract and rewriting a passing test to accept a new answer, which the Constraints forbid. Contract preserved: no executable behaviour changed this iteration, only documentation and added tests. Acceptance met on all three limbs - the docstring and a new `.. caution::` block both state that the returned weights are normalised and delta-invariant, `test_bl_weights_are_delta_invariant` pins that delta in (1, 2.5, 100) gives identical weights, and `test_bl_weights` still passes untouched (the diff against HEAD for that file is purely additive, no deleted lines). Both doc claims were checked before being written: with `pi="market"` the constructor's risk_aversion moves posterior returns from [0.1033, 0.0352, 0.0214] at delta=1 to [0.1165, 0.1160, 0.0869] at delta=5, and `test_bl_constructor_risk_aversion_affects_market_prior` pins that counterpart. Verify command GREEN: 304 passed, 15 skipped, 0 failed, up from 302 passed by the two new tests.

New finding filed: PR-07 (High). Working inside `bl_weights` exposed a second, distinct defect in the same normalization line - when the raw solution is net short, dividing by a negative sum inverts every position. Reproduced on the repository's own price data with a market prior and a broadly bearish view set: posterior returns all negative, raw weights summing to -7.15 with 15 of 20 assets short, returned portfolio 15 of 20 long summing to +1, every sign flipped, no warning. PR-02 and PR-07 share that one line but are different defects (delta cancellation versus sign inversion); the three-strike rule is not yet triggered.

Learnings: When inserting a test next to an existing one, anchor the edit on the end of the target function, not on an interior block - anchoring mid-function split `test_bl_weights` and orphaned its tail into the new test, which surfaced only as a NameError. An invariance assertion over a weight vector must use atol, not rtol alone: most entries are numerically zero and a relative tolerance there compares the last bits of floating-point noise.

Next: PR-07 (High) - the sign inversion in the same normalization line.

## iter 4/10 | deef07ee-221242 | 2026-07-28 | PR-07 | done

Task: PR-07 (High) - `BlackLittermanModel.bl_weights()` divided the raw solution by its own signed sum, inverting every position when the implied portfolio was net short.

Changed: pypfopt/black_litterman.py (net-exposure guard plus a Raises section), docs/BlackLitterman.rst (second paragraph of the caution block), tests/test_black_litterman.py (two new tests), BACKLOG.md (PR-07 closed, PR-08 filed), PLAN.md (Black-Litterman row re-swept).

Checkpoint: 7d3bb33c4bf3aa59f4a4d42d3903e86fa791ee85

Verification: Probing the failure boundary first turned out to matter - a pure sign check would have been the obvious guard and would have been wrong. Bisecting the view scale to the zero crossing produced a raw sum of -9.7e-17 and weights of [9.6e8, 1.07e9, -2.03e9] that were finite and summed to exactly 1.0, so a magnitude test on the denominator was required, not a sign test. The guard is `net <= 1e-8 * abs(raw).sum()`, comparing net exposure against gross. Contract preserved: for every input whose implied portfolio has meaningful positive net exposure the returned weights are unchanged, and `test_bl_weights_sign_agrees_with_raw_solution` pins that they remain exactly a positive scalar multiple of `np.linalg.solve(delta*cov, posterior_rets)`; the accepted-input set narrows only where the old answer was the inverted book. Accepted inputs changed, so the docstring gained a Raises section and the user guide gained a paragraph, per change discipline. Acceptance: `test_bl_weights_rejects_net_short_implied_portfolio` was run against the unfixed implementation by stashing only the source change and observed to FAIL, then to pass with the fix. Verify command GREEN: 306 passed, 15 skipped, 0 failed, up from 304 by the two new tests, no regressions. Black-Litterman row re-swept with 15 checks covering the zero-omega and infinite-omega limits, tau liveness under explicit omega, dict/Series view equivalence, unknown-ticker rejection, default_omega shape, idzorek confidence liveness, bl_cov PSD, weight sign agreement, delta invariance, net-short refusal, and both pi variants.

New finding filed: PR-08 (Low). Writing the Settled classes line claimed an enumeration I had not run; running it found four divide-by-own-sum sites, not the two I assumed. Three are safe (`hierarchical_portfolio.py:104` inverse variances are strictly positive, `black_litterman.py:55` market caps are positive, and the guarded site), but `discrete_allocation.py:244` divides by exactly zero when the budget affords no shares, reproduced with prices {500, 800, 1200} and a portfolio value of 100, emitting `RuntimeWarning: invalid value encountered in divide`. The allocation returned is still correct, so it is Low. The class line was withdrawn rather than left overstated; the class settles when PR-08 closes. Two of four sites carried a real defect, so the three-strike rule is not triggered.

Learnings: Never write a Settled classes line before running its enumerating check - the claim was wrong the moment it was written, and the check that proved it wrong took one command. When guarding a division, probe the boundary rather than assume it: the dangerous neighbourhood of a normalizer is both sides of zero, not just the negative side, and the near-zero case produces large finite numbers that no NaN or infinity check would catch.

Next: PR-03 (Medium) - the four optimizers disagree on the domain of `target_return`.

## iter 5/10 | deef07ee-221242 | 2026-07-28 | PR-03 | done

Task: PR-03 (Medium) - the four `efficient_return` implementations disagreed on the domain of the same documented `target_return` parameter, and two of them could not express a negative target at all.

Changed: pypfopt/efficient_frontier/efficient_frontier.py (new shared `_validate_target_return`, EF call site, `numbers` import), efficient_semivariance.py, efficient_cvar.py, efficient_cdar.py (call the shared validator, `nonneg=True` removed from the CDaR parameter, three docstrings corrected), tests/test_efficient_frontier.py (3 new tests), tests/test_efficient_semivariance.py, tests/test_efficient_cdar.py, tests/test_efficient_cvar.py (assertions retargeted), BACKLOG.md (PR-03 closed, class settled), PLAN.md (four rows re-swept).

Checkpoint: c6987a9d159b87b30ddabe8679ac4a71acb70dca

Verification: The domain chosen is any real number up to the largest achievable return, computed by the existing `_max_return()`, which needs only `expected_returns` and so works for all four classes. Negative targets were confirmed solvable before the design was fixed - on an all-negative universe EF and CVaR both hit targets of -0.10 and -0.08 exactly with weights summing to 1 - so the two classes that refused them were wrong, not protective. The old semivariance bound `np.abs(self.expected_returns).max()` was replaced: with all-negative returns it admitted targets far above anything achievable, which then surfaced as a solver `OptimizationError`. Acceptance: three new tests over a bearish fixture (real price data shifted so every expected return is negative) assert all four optimizers accept a negative target and reach it, all four reject an unachievable target with the same "largest achievable return" message, and all four reject a non-numeric target with the same "real number" message; all three were run against the unfixed code by stashing only `pypfopt/efficient_frontier/` and observed to FAIL, then to pass. Verify command GREEN: 309 passed, 15 skipped, 0 failed. Ruff check and ruff format both clean.

Verify gate, pre-existing fault exposed rather than introduced: `tests/test_efficient_cdar.py::test_cdar_errors` and `tests/test_efficient_cvar.py::test_cvar_errors` went red because both asserted `OptimizationError` for a target above the maximum expected return. Their own comments read "Must be <= max expected return", so they always meant to pin the contract PR-03 states; they expressed it as a solver failure only because no validation existed, which is the defect. Both were retargeted to the validation error rather than reverted, and `tests/test_efficient_semivariance.py` lost its "Must be > 0" assertion because that contract is the one being corrected. Differential evidence that no previously-passing output moved: 12 portfolios were solved at the previous checkpoint 270cf40 and again on the working tree - 4 optimizers times 3 valid targets of 0.10, 0.20, 0.25 on the repository's own data - and the maximum absolute weight difference is 0.000e+00, bit-identical.

Rows re-swept at this checkpoint by re-running the iteration-1 60-check probe: 54 of 60 pass, the same count as iteration 1 but with a better composition. `cdar_efficient_return_target` now passes where it previously raised the raw cvxpy error, and `semivariance_efficient_return_target` no longer fails on the "positive float" rejection. The four remaining failures were all established in iteration 1 as probe errors or deliberate behaviour: a slack `>=` return constraint (twice), an infeasible market-neutral target, an out-of-envelope 2 percent daily semivariance benchmark, and `beta=0` being accepted with a warning by design.

Learnings: A test whose comment states the intended contract but whose assertion pins the mechanism is the signature of a fault that was never fixed, only observed; retarget the assertion to the contract rather than preserve the mechanism. Before changing a validation domain, prove the underlying solver accepts the wider domain, otherwise the widening trades a clear rejection for an obscure solver failure. Run `ruff format --check` after adding tests: the suite passes but CI runs pre-commit and would have failed on formatting alone.

Next: PR-04 (Medium) - `prices_from_returns` silently discards the caller's first return observation.

## iter 6/10 | deef07ee-221242 | 2026-07-28 | PR-04 | done

Task: PR-04 (Medium) - `prices_from_returns` sets `ret.iloc[0] = 1`, consuming the caller's first return, and the docstring documented neither the precondition that avoids the loss nor the asymmetry with `returns_from_prices`.

Changed: pypfopt/expected_returns.py (module docstring, `prices_from_returns` docstring, `returns_from_prices` Returns section), tests/test_expected_returns.py (2 new tests), BACKLOG.md (PR-04 closed), PLAN.md (conversions row re-swept).

Checkpoint: f33ede1f7dbf18888e40eb731ded3932ead637cd

Verification: Reading the tests that pin the function changed the diagnosis, and the original filing was too harsh. `tests/test_expected_returns.py:20` feeds it `df.pct_change()` with the comment "keep NaN row", which is the designed input: returns still aligned to the price index, whose first row carries no return and can therefore hold the base price. On that input the function is exactly lossless, confirmed on a hand-built 4-row series where pseudo-prices times the initial price reproduce [100, 110, 99, 118.8] to floating point. The loss appears only when it is fed the output of `returns_from_prices`, which drops that row - the pairing the module docstring advertises as "convert from returns to prices and vice-versa". There the first return of 0.10 is spent on the base and the path becomes [1.0, 0.9, 1.08] rather than [1.1, 0.99, 1.188]. Every consecutive change in that result still equals the corresponding input return, so the output is truncated rather than wrong, which is why this closed as documentation rather than as a behaviour change. Resolved by documenting the precondition, stating plainly that the two functions are not exact inverses, and pointing users at `returns_data=True` as the lossless path; a prepended base row was rejected because no index label for the period before the first return can be synthesised for an arbitrary index, and inspecting the data to guess which convention the caller meant would be implicit magic for a marginal gain. Contract preserved: no executable behaviour changed this iteration - the diff to `pypfopt/` is docstrings only - so the two new tests pin the contract rather than fail against a prior defect, and that is the honest status of a documentation finding. Verify command GREEN: 311 passed, 15 skipped, 0 failed, up from 309 by the two new tests. Ruff check and ruff format clean.

Stall check: not applicable - `pypfopt/expected_returns.py` and `tests/test_expected_returns.py` both changed and PR-04 changed state.

Learnings: Read the tests that pin a function before believing a finding about it; the test comment "keep NaN row" encoded a precondition that the docstring omitted, and it turned an apparent data-loss bug into a documentation defect with a much smaller correct fix. When two functions are presented as a converting pair, check whether they actually invert: N prices carry only N-1 returns, so one direction must lose something, and the honest fix is to say which.

Next: PR-05 (Low) - `_validate_beta` duplicated byte-identically across EfficientCVaR and EfficientCDaR.

## iter 7/10 | deef07ee-221242 | 2026-07-28 | PR-05 | done

Task: PR-05 (Low) - `_validate_beta` was duplicated byte-identically in `EfficientCVaR` and `EfficientCDaR`.

Changed: pypfopt/efficient_frontier/efficient_frontier.py (module-level `_validate_beta`), efficient_cvar.py and efficient_cdar.py (staticmethod deleted, helper imported, now-unused `import warnings` removed), tests/test_efficient_frontier.py (1 new test), BACKLOG.md (PR-05 closed, duplicated-validator class settled), PLAN.md (CVaR and CDaR rows re-swept).

Checkpoint: b8139ddbd414037115aa926a4afab64956bf0ee1

Verification: `diff` of the two ten-line definitions confirmed they were byte-identical before the change, and no test or doc referenced `_validate_beta`, so collapsing them touched nothing outside the package. The helper became a module-level private function in `efficient_frontier.py` rather than a method on `EfficientFrontier`, because the base class has no beta concept and inheriting one would have put a tail-risk parameter on the mean-variance API; this also matches where the shared `_validate_target_return` from PR-03 lives. Removing the staticmethod left `import warnings` unused in both siblings, which ruff F401 would have failed, so both imports went too. Contract preserved: both classes still reject beta outside [0, 1) with "beta must be between 0 and 1" and still warn at beta <= 0.2, now provably via the same function object. Acceptance: the check filed in iteration 1 asserted `EfficientCVaR._validate_beta is EfficientCDaR._validate_beta`, which assumed the fix would be inheritance; it was replaced rather than weakened with a source enumeration asserting exactly one `def _validate_beta` in `pypfopt/`, which was run against the unfixed code and observed to FAIL with 2 definitions at efficient_cvar.py:104 and efficient_cdar.py:104, plus a behavioural test driving both classes through three invalid betas, the warning threshold, and a valid value. Verify command GREEN: 312 passed, 15 skipped, 0 failed. Ruff check and ruff format clean, after `ruff format` corrected the new test.

Rows re-swept at this checkpoint: CVaR and CDaR, 12 checks, with beta 0.90 to 0.99 raising tail risk 0.0117 to 0.0173 for CVaR and 0.0962 to 0.1115 for CDaR, out-of-range beta rejected on both, and unachievable targets rejected by the shared validator rather than the solver. One probe assertion failed and was investigated rather than filed: CDaR's `efficient_return` returned -0.0073 for a target of -0.0337, because `min_cdar` already clears that target and the `ret >= target` constraint is slack. With a binding target of -0.0018 the achieved return is -0.0018 exactly, so the formulation is correct and this is the same slack-constraint artifact recorded for EfficientFrontier in iteration 1.

Learnings: An acceptance check written before the fix can encode an assumption about the fix's shape - this one assumed inheritance and would have failed against a correct module-level solution. Replace such a check with one that tests the property rather than the mechanism, state that it was replaced, and prove the replacement fails against the unfixed code. Deleting a method can strand its imports: after removing the last user of a module-level import, run ruff before the checkpoint.

Next: PR-08 (Low) - `discrete_allocation.py:244` divides by a zero sum when the budget affords no shares.

## iter 8/10 | deef07ee-221242 | 2026-07-28 | PR-08 | done

Task: PR-08 (Low) - `discrete_allocation.py:244` normalised `current_weights` by its own sum, which is exactly zero when the first round affords no shares, emitting `RuntimeWarning: invalid value encountered in divide`.

Changed: pypfopt/discrete_allocation.py (skip the division when nothing has been bought), tests/test_discrete_allocation.py (1 new test, `warnings` imported), BACKLOG.md (PR-08 closed, divide-by-own-sum class settled), PLAN.md (discrete allocation row re-swept).

Checkpoint: 283b6ebe3231183c03a21e2602fe0ded2ae67487

Verification: The fix leaves `current_weights` as zeros when nothing has been bought, which makes `deficit` equal `ideal_weights` - the correct reading of "nothing held yet, so every asset is fully deficient" - rather than a vector of NaN. Contract preserved: the previous behaviour reached the same terminal state, because comparisons against NaN are all False and the inner search simply spun to its counter limit and broke; the difference is that the loop now reasons about real numbers instead of NaN, and the warning is gone. Differential evidence that no working allocation moved: greedy allocations were computed at the previous checkpoint and on the working tree for five portfolio sizes of 2000, 10000, 20000, 100000 and 1000000 against the repository's own max-Sharpe weights and latest prices, and the serialised results are identical. Acceptance: the filed command exits 0 under `-W error::RuntimeWarning` and still reports an empty allocation with leftover 100. The new regression test was run against the unfixed code and observed to FAIL at `pypfopt/discrete_allocation.py:244: RuntimeWarning`, then to pass. Verify command GREEN: 313 passed, 15 skipped, 0 failed. Ruff check and ruff format clean, after `ruff check --fix` corrected the import ordering the new `warnings` import introduced.

Class settled: normalising a vector by its own sum. Of the four sites enumerated in iteration 4, two carried defects and are now guarded (`bl_weights` net exposure, this one), and the enumerating check still reports two that divide strictly positive quantities - market caps at `black_litterman.py:55` and inverse variances at `hierarchical_portfolio.py:104`. Both guarded sites now divide by a named checked variable and so no longer match the pattern, which is worth recording because a future enumeration using the same grep will not see them.

Learnings: A degenerate branch can produce NaN and still reach the right answer, because every comparison against NaN is False and the surrounding control flow falls through to the same exit. That makes the defect invisible to output-based tests and visible only as a warning, which is why `-W error::RuntimeWarning` is worth running over a suite that is otherwise green. Adding an import to a test file can break ruff's isort rule without touching any logic; `ruff check --fix` resolves it.

Next: PR-06 (Low) - the suite writes `weights.csv` into the repository root.

## iter 9/10 | deef07ee-221242 | 2026-07-28 | PR-06 | done

Task: PR-06 (Low) - running the suite left `weights.csv` in the repository root. Also swept the last unswept Surface inventory row, `min_cov_determinant`.

Changed: tests/test_readme.py and tests/test_readme_examples.py (both now execute the README in a scratch directory carrying `tests/resources`), .gitignore (the `weights.csv` entry added in iteration 1 removed), BACKLOG.md (PR-06 closed, PR-09 filed), PLAN.md (min_cov_determinant row swept).

Checkpoint: d1fc5bfa144ccd8224a71882f9d01907030405c7

Verification: The filing named the wrong file. `tests/test_readme_examples.py` was the obvious suspect because it is the one that reads README.md:94, but running each candidate against a deleted `weights.csv` showed the writer is `tests/test_readme.py`, which executes the merged README blocks through `subprocess.run` with the inherited cwd. Both files now copy `tests/resources` into a pytest `tmp_path` and run there - via `monkeypatch.chdir` in one and `cwd=tmp_path` plus an explicit `PYTHONPATH` in the other - so the relative read still resolves and any write lands in the scratch directory. The `weights.csv` line was also removed from .gitignore: it was my own defensive addition in iteration 1, and while it was present it masked exactly this bug, which is why the acceptance check as filed - `git status --porcelain` empty - passed even while the artifact was still being written. Acceptance, restated as the file itself: after a full suite run `weights.csv` does not exist and `git status --porcelain` lists only the intended source edits. Run against the unfixed code by stashing the two tests and .gitignore, `weights.csv` was written, so the check fails as required. Verify command GREEN: 313 passed, 15 skipped, 0 failed. Ruff check and ruff format clean.

Surface inventory now complete at 26 of 26 rows. The final row, `min_cov_determinant`, was swept with 10 checks: deprecation warning emitted, shape and labels, symmetry, positive semidefiniteness, `frequency` scaling linearly, `returns_data` agreeing with the prices path, `log_returns` changing the output, `random_state` reproducible, and robustness confirmed - under a contaminated series its variance is 0.0160 against the sample covariance's 1.1144. The known-answer check failed and produced PR-09.

New finding filed: PR-09 (High). Against a known covariance with diagonal [0.04, 0.09, 0.0225] over 4000 draws, `min_cov_determinant` returns ratios to truth of [0.36, 0.44, 0.43], because `risk_models.py:361` uses the raw `fast_mcd` covariance rather than a consistency-corrected one; sklearn's `MinCovDet` on the same sample returns [1.01, 1.03, 1.00]. A risk model roughly 2.5 times too small is returned without complaint. This is exactly the failure mode the Surface inventory section of PLAN.md describes - a metric off by a constant factor passes every liveness probe - and it is why the row could not be certified on shape and symmetry alone. The run therefore does not converge: an in-envelope High is open.

Learnings: A finding's stated location is a hypothesis, not evidence; the cheapest confirmation is to delete the artifact and bisect over candidate producers rather than trust the plausible one. Never add an ignore rule for an artifact whose production is itself the bug - the rule silences the acceptance check along with the noise, and here it made a still-broken state look clean for eight iterations.

Next: PR-09 (High) - `min_cov_determinant` returns a covariance roughly 2.5 times too small.

## iter 10/10 | deef07ee-221242 | 2026-07-28 | PR-09 | done

Task: PR-09 (High) - `min_cov_determinant` returned the raw `fast_mcd` covariance, which is not consistent at the normal distribution and understates variance by more than half. Final iteration, so this entry also carries the run's wrap-up.

Changed: pypfopt/risk_models.py (MinCovDet replaces raw fast_mcd, stale deprecation version corrected, `# pragma: no cover` removed now that the function is tested), tests/test_risk_models.py (1 known-answer test), BACKLOG.md (PR-09 closed, ledger now empty).

Checkpoint: 79780bfcd66465fb3ada9a3bd75dba576e2f57ff

Verification: Fixed rather than removed. The warning has promised removal "in v1.5" since before 1.6.0 shipped, so completing the removal would be a breaking public API change the maintainers have twice declined to make and that no user of this run authorised; correcting the numbers is strictly an improvement and preserves the signature. The estimator now uses `MinCovDet(random_state=...).fit(X).covariance_`, which applies the consistency correction the raw estimate omits, and the deprecation message no longer names a version that has already passed. Contract preserved: signature, parameters and return type are unchanged, and the function still warns on call. Acceptance: the new known-answer test samples 4000 draws from a covariance with diagonal [0.04, 0.09, 0.0225] and requires each estimated diagonal within 20 percent of truth; run against the unfixed implementation it FAILS with ratios [0.360, 0.438, 0.433], and passes after the change. The `# pragma: no cover` was dropped because the function is now exercised by a test, so excluding it from coverage would misreport. Verify command GREEN: 314 passed, 15 skipped, 0 failed. Ruff check and ruff format clean.

Run outcome: not converged, budget exhausted. The ledger is empty and the Surface inventory is complete at 26 of 26 rows, but the Definition of done also requires a full fresh-evidence audit executed in one iteration that scores zero High and zero Medium in-envelope, and this run has no such audit. The only full audit was iteration 1, which scored two Highs and four Mediums; every one of those findings has since been closed, but the closing rule counts a clean audit, not the absence of open tasks, and there was no budget left to run one. The evaluator gate was therefore not invoked either, since it applies only on the Definition of done path. Declaring convergence here would have meant asserting a clean audit that was never executed.

Handoff for the next run: start a fresh session in this directory so iteration 1 gets clean context, and let its audit be the clean full audit this run lacked. It should re-sweep with fresh evidence rather than trust these rows, paying particular attention to the eight modules this run touched - hierarchical_portfolio, black_litterman, the four efficient_frontier classes, expected_returns and risk_models - and to the four classes recorded under Settled classes, whose implementing code all changed during this run. If that audit comes back with zero High and zero Medium it enters closeout immediately and can converge within a small budget; PLAN.md Lessons now carries eleven operational rules that should keep it from repeating this run's mistakes.

Learnings: A deprecated function is not exempt from the severity rubric - it was the last inventory row, it was excluded from coverage by a pragma, and it was the only place in the project returning numbers that were simply wrong. Excluding code from coverage and from sweeps is how a defect survives; the pragma and the deprecation label together made this the least examined and most broken surface in the library. When a fix makes previously-uncovered code testable, remove the coverage pragma in the same change, or the exclusion outlives its reason.

Next: none - final iteration. The next run opens with the clean full audit that convergence requires.

## iter 1/10 | 93087ff0-231822 | 2026-07-28 | AUDIT | audit

Task: AUDIT - the full fresh-evidence audit the previous run ended without budget to run. Its handoff asked for exactly this, with attention to the eight modules that run touched and the four Settled classes whose implementing code all changed.

Changed: BACKLOG.md (five findings filed, one declined), PLAN.md (nine stale Surface inventory rows re-swept, two Lessons added). No source file changed this iteration.

Checkpoint: 133ba5167f9eff58bbdeb86a947442155321147e

Verification: Verify command GREEN at the start of the iteration: 314 passed, 15 skipped, 0 failed, exit 0. Staleness was computed mechanically rather than by eye - for each source file the last commit touching it, compared against the commit each inventory row recorded - which found nine stale rows of twenty-six. Eight follow from a file changing after its row was swept; the ninth is EfficientSemivariance, whose own file last changed at the commit it was swept at but which inherits `_validate_target_return` from EfficientFrontier, changed later at b8139dd. A per-file staleness check calls that row clean, and it is exactly where this audit found a defect, so staleness has to follow the inheritance edge and not just the path. All nine were re-swept with known-answer checks: CAGR and arithmetic closed forms, sample covariance against numpy, a hand-computed downside product for semicovariance, the closed-form shrinkage identity, the two-asset min-variance closed form, minimality against 400 random simplex points, `delta*S*w_mkt + rf` for the Black-Litterman prior, a hand-computed implied risk aversion, and budget conservation for the LP allocation. Seventeen rows carry sweeps at commits whose implementing code is unchanged and were not re-probed.

Scores, claiming all 26 rows: correctness Medium (PR-10, PR-12), error handling Medium (PR-11), testing Medium (the `# pragma: no cover` branch at risk_models.py:103 is reachable, demonstrated, and excluded from coverage - same root cause as PR-11, not filed separately), documentation Low (PR-13), code quality Low (PR-14), architecture None, security None (no eval, exec, pickle, subprocess or network anywhere in `pypfopt/`; the surfaces are the library API and local file writes), performance None (the sweeps ran the whole public surface at realistic sizes with no pathological timing; the suite completes in 28s), dependency hygiene None (bounded declarations, no known-vulnerable pin; `scikit-base<0.14.0` is a deliberate cap), developer experience None. UX and accessibility do not apply: this is a library with no user-facing surface. Closeout does NOT begin - three in-envelope Mediums were found, so the run must close them and earn a clean full audit before it can converge.

PR-10 (Medium): `capm_return` mutates its caller's data. At `expected_returns.py:302` the `returns_data=True` path binds `market_returns = market_prices` with no copy, and line 317 then assigns `market_returns.columns = ["mkt"]`, renaming the caller's own DataFrame in place. Reproduced: a frame passed in with columns `['SPY']` comes back `['mkt']`. The sibling branch three lines earlier does `returns = prices.copy()`, so the copy exists on one alias and not the other - the shape of a bug fixed once where it bit and left everywhere else. The prices path cannot mutate because `returns_from_prices` builds a new object.

PR-12 (Medium): asking for the maximum-return portfolio is refused. `_validate_target_return` compares the target against `_max_return()`, a solved LP whose optimum on a long-only universe is exactly `mu.max()` but which the solver returns 1.11e-9 low. Any target above that computed value is rejected, so `efficient_return(target_return=mu.max())` raises "target_return must be lower than the largest achievable return of 0.388666" - the number the caller just passed. Identical in all four optimizers, since PR-03 gave them one shared validator. The comparison is pre-existing, not a regression: a6638d2 used the same `>` test and differed only in wording, and it was this run's more informative message, which now prints the limit, that made the contradiction visible.

PR-11 (Medium): the PSD predicate is scale-dependent. `_is_positive_semidefinite` tests `cholesky(matrix + 1e-16 * I)`; the jitter is absolute while eigenvalue noise scales with the matrix, so a matrix that is PSD by construction is rejected once its magnitude is large - `B @ B.T` rank-deficient was called non-PSD at 5x5 and above. My first hypothesis, that the spectral repair systematically self-reports failure, was wrong and I killed it: it fired on 0 of 100 random non-PSD matrices. The real trigger is magnitude. Returns quoted in percent, a common convention, put a 60-asset 40-observation covariance at max eigenvalue 1.6e3, and there `sample_cov` emits both "non positive semidefinite. Amending eigenvalues" and "Could not fix matrix. Please try a different risk model." on an input that was genuinely PSD, after a repair that moved the numbers by 2.3e-15 relative, returning a matrix `min_volatility` then solves without complaint. The user is told to abandon a correct risk model. Not scored High: no number is wrong, only the diagnosis.

Declined: the numpy RuntimeWarning from `(1 + returns).prod()` on infinite returns. `_check_returns` already warns "Some returns are infinite" on that exact input, so it is a duplicate signal, and silencing it would wrap defensive code around a correct computation.

Two candidate findings were tested and killed rather than filed. `risk_free_rate` looked inert in `capm_return` until I retried it on assets with differing betas - a single-asset universe is its own market proxy, so beta is 1 and rf cancels by the CAPM identity, which is correct behaviour and not an inert parameter. And `efficient_return` looked to miss low targets until I read the constraint: it binds return >= target, so a slack target correctly returns the global minimum-variance portfolio, and my equality assertion was the broken part.

Learnings: Staleness must follow inheritance, not just file paths - the one row a per-file check would have cleared is the row that carried a defect. A fixed absolute epsilon inside a numerical predicate is a scale-dependent bug that hides perfectly at the project's default units: `1e-16` is invisible on daily-return covariances near 1e-2 and wrong on the same data quoted in percent, so such predicates need probing at several magnitudes, not just the one the tests use. When a probe fails, the first question is whether the probe or the code is wrong; two of five candidates here were my own bad assertions, and filing them would have cost fix iterations chasing correct behaviour.

Next: PR-10 (Medium) - `capm_return` renames the caller's market DataFrame in place.

## iter 2/10 | 93087ff0-231822 | 2026-07-28 | PR-10 | done

Task: PR-10 (Medium) - `capm_return` aliased its `market_prices` argument on the `returns_data=True` path, so renaming the market column renamed the caller's own dataframe in place.

Changed: pypfopt/expected_returns.py (one-line copy plus a comment saying why), tests/test_expected_returns.py (1 new regression test), BACKLOG.md (PR-10 closed, caller-mutation class settled), PLAN.md (inventory row for the return models flipped back to unswept, one Lesson added).

Checkpoint: 529f997df4787ef69431a1e3047a0e0b2c083e0f

Verification: The fix is `market_returns = market_prices.copy()`. Contract preserved: signature, return type and every returned number are unchanged, and the only observable difference is that an undocumented side effect on the caller's object is gone. Differential evidence that no working output moved: `capm_return` was evaluated across 26 parameter combinations - compounding, log_returns and risk_free_rate crossed, on the prices path, the returns_data path and the no-benchmark equally-weighted path - at the previous checkpoint and on the working tree, and all 26 serialised identically. Callers read first, as change discipline requires: `return_model` dispatches to it, four tests pin it, and `test_risk_matrix_and_returns_data` exercises `returns_data=True` but never together with `market_prices`, so the aliasing branch had no test at all. Acceptance: the filed command exits 0; run against the unfixed code it exits 1 with `AssertionError: ['mkt']`. The new regression test passes and, run against the unfixed source with the test retained, FAILS with "DataFrame.columns values are different, [left]: Index(['mkt']), [right]: Index(['SPY'])". Verify command GREEN: 315 passed, 15 skipped, 0 failed, exit 0. Ruff check and ruff format clean.

Class settled: mutating a caller-supplied pandas object in place. The grep enumerating check reports one site, `expected_returns.py:319`, and both branches reaching it now hold a fresh object, a copy on one and a `returns_from_prices` result on the other. I also wrote an AST enumeration over `pypfopt/` for attribute, subscript or `inplace=True` mutation of any parameter or parameter alias; it reports zero sites now and exactly this one against the unfixed code.

That AST check was wrong on its first two attempts and both failures are worth recording. The first version flagged 147 sites because it counted `self.x = ...` as mutation of a caller's object, which is just ordinary object state, and counted locally built arrays whose constructors it did not recognise. The second version reported zero sites against the unfixed code - it proved nothing at all. The cause was flow insensitivity with last-write-wins: `market_returns` is aliased to the parameter in the `returns_data` branch and rebound to a fresh object in the `else` branch, and processing assignments in source order let the second binding clear the alias recorded by the first. Making the alias sticky - risky on any path means risky - found the defect. An enumerating check is code, and a check that has never been observed to fail is not evidence.

Learnings: A static-analysis enumerating check has to be run against the unfixed code before it is trusted, exactly like a test. Mine returned a clean zero on a defect I had already reproduced by hand, and had I written the Settled classes line from that output I would have recorded a false class-complete claim on the strength of a broken analyser. The specific trap is flow insensitivity: when one branch of an if/else aliases a parameter and the other rebuilds it fresh, source-order last-write-wins erases the alias, so the alias set must only ever grow.

Next: PR-12 (Medium) - a target equal to the largest achievable return is refused by the shared validator.

## iter 3/10 | 93087ff0-231822 | 2026-07-28 | PR-12 | done

Task: PR-12 (Medium) - `_validate_target_return` rejected a target equal to the largest achievable return with a message that named, as the limit, a value above the target it had just refused.

Changed: pypfopt/efficient_frontier/efficient_frontier.py (the rejection message now prints the limit at full round-trip precision, with a comment saying why), tests/test_efficient_frontier.py (1 new regression test), BACKLOG.md (PR-12 closed), PLAN.md (four inventory rows flipped back to unswept, one Lesson added).

Checkpoint: 225b735b74f3e23aabcc3e896f889616a4025a78

Verification: The filed acceptance check assumed the fix was to loosen the guard so `efficient_return(target_return=mu.max())` would be accepted. I tested that assumption before implementing it and it is wrong. With the guard bypassed, EfficientFrontier cannot solve at the boundary at all: targets at gaps of 0, 1e-12, 1e-10, 1e-9, 1e-8, 1e-7 and 1e-6 below the true maximum every one raise OptimizationError, and only a gap of 1e-5 solves. Clamping the target down to the solver's own computed maximum also fails. The other three optimizers do solve at `mu.max()`, so the guard over-rejects them by about 1e-9, but loosening a shared validator to buy that would hand EfficientFrontier callers an OptimizationError reading "Please check your objectives/constraints or use a different solver" in place of a clear ValueError. The library already concedes this numerically: `plotting._ef_default_returns_range` builds its range as `linspace(min_ret, max_ret - 0.0001)`, and `tests/test_plotting.py:251` carries the comment "Internally _max_return() is used, so subtract epsilon". Refusing the boundary is therefore correct; the defect was entirely in the message.

The message formatted the limit with `{:.6g}`. Rejecting 0.3886658284439337 it printed "target_return must be lower than the largest achievable return of 0.388666" - and 0.3886658284439337 is lower than 0.388666, so the message was formally self-contradictory and told the caller nothing about which values would be accepted. It now prints `repr` of the float, the shortest representation that round-trips, so the stated limit can never round above the value it refused. Six significant figures were not merely imprecise: any fixed precision can round up past the target, and only an exact representation closes that.

Acceptance check revised, with the reason recorded here rather than silently: the original encoded an assumption about the fix's shape that the evidence above refuted. The replacement tests the property instead - for all four optimizers, the limit stated in the rejection must be strictly less than the target that was rejected. Run against the unfixed code it FAILS with "AssertionError: target_return must be lower than the largest achievable return of -0.233123, assert -0.233123 < -0.23312330617881427", and it passes after the change. Contract preserved: the exception type is unchanged and the substring "largest achievable return" that four tests match on is unchanged, so `test_efficient_cdar.py:433`, `test_efficient_cvar.py:438` and `test_efficient_frontier.py:1412` still pass untouched; only the formatting of the number changed. Verify command GREEN: 316 passed, 15 skipped, 0 failed, exit 0. Ruff check and ruff format clean.

Inventory: the four rows naming `efficient_return` - EfficientFrontier targets and validation, EfficientSemivariance, EfficientCVaR and EfficientCDaR - are flipped back to unswept, because an exception message is observable behaviour and all four reach it through the shared validator. Five rows now stand unswept and the closing audit must re-sweep them.

Learnings: Before loosening a validation boundary, check that the code behind it can handle the values the loosening would admit. Here the guard looked over-strict and the obvious fix was a tolerance, but the QP it protects is degenerate within 1e-6 of the maximum, so accepting the boundary would have replaced a clear error with an obscure solver failure and called it an improvement. The corroboration was already in the repository: two separate places back off from the maximum by a hardcoded 1e-4, which is what a codebase looks like when it has already met this wall and worked around it locally.

Next: PR-11 (Medium) - the PSD predicate's absolute epsilon misclassifies large-magnitude matrices.

## iter 4/10 | 93087ff0-231822 | 2026-07-28 | PR-11 | done

Task: PR-11 (Medium) - `_is_positive_semidefinite` nudged the diagonal by an absolute 1e-16, a constant that does not scale with the matrix, so matrices that are positive semidefinite by construction were rejected once their magnitude was large, and `fix_nonpositive_semidefinite` then told the caller "Could not fix matrix. Please try a different risk model." about output that was correct.

Changed: pypfopt/risk_models.py (relative tolerance in the predicate, an all-zero guard, docstring paragraph explaining the scaling), tests/test_risk_models.py (2 new tests, `warnings` imported), BACKLOG.md (PR-11 closed), PLAN.md (four risk_models inventory rows flipped back to unswept, one Lesson added).

Checkpoint: cf685b43aff1df7ac3a20cad4764d6d780b6b4e3

Verification: The tolerance was calibrated rather than guessed. I built 31 matrices that are positive semidefinite by construction - `B @ B.T` at ranks 3 to 30 and magnitudes from 1e-4 to 1e8, plus full-rank cases and the 100x100 zero matrix the existing test pins - and 14 that are genuinely indefinite, including the repository's own `test_sample_cov_npd` fixture and six synthetic matrices carrying a single negative eigenvalue at a known fraction of the largest, from 1e-2 down to 1e-8. The current predicate accepts only 15 of the 31 valid matrices: every rank-deficient case at magnitude 1 or above is rejected. Factors of 1e-14, 1e-12, 1e-10 and 1e-8 all accept 31 of 31 while still catching 14 of 14. I took 1e-12, which sits four orders above eigenvalue round-off near 1e-16 relative and four orders below the smallest negative eigenvalue worth catching at 1e-8 relative, so it is centred in the safe band rather than at an edge of it.

The all-zero guard is required, not defensive: with a relative jitter the zero matrix has no scale to work from, the jitter becomes zero, and `cholesky` on an exactly singular matrix fails, which would have broken `test_is_positive_semidefinite`. It is also the mathematically right answer, since the zero matrix is positive semidefinite.

Contract preserved: the predicate is private, its signature and return type are unchanged, and every risk model reaches it only through `fix_nonpositive_semidefinite`. Differential evidence that no number moved: all eight `risk_matrix` methods crossed with two frequencies and both `log_returns` settings, three `shrunk_covariance` deltas and `min_cov_determinant` - 36 outputs in total - were serialised on the repository's own price data at the previous checkpoint and on the working tree, and all 36 are identical. The change is confined to the classification of borderline matrices; it does not alter arithmetic. Acceptance: the filed check passes - the percent-quoted 60-asset 40-observation covariance now emits neither warning, while the genuinely indefinite matrix still emits exactly one "Amending eigenvalues" warning and is still repaired to something the predicate accepts. Both new tests fail against the unfixed source, the first at `scale=1.0` and the second on the spurious UserWarning. Verify command GREEN: 318 passed, 15 skipped, 0 failed, exit 0. Ruff check and ruff format clean.

The `# pragma: no cover` on the "Could not fix" branch is kept. The audit filed it as reachable, and it was - that was the whole defect. Now that a correctly repaired matrix is no longer misclassified, the branch is a last-resort guard reachable only on pathological input such as a matrix containing NaN, so excluding it from coverage is honest rather than a way of hiding an untested path. The original reproducer, a 3x3 correlation matrix with 0.9 and -0.9 entries, now produces one warning instead of two and its repair is verified positive semidefinite.

Inventory: the four risk_models rows are flipped back to unswept. All of them reach the changed predicate - the three sample estimators, `min_cov_determinant` and `CovarianceShrinkage` through `fix_nonpositive_semidefinite` and `_format_and_annualize`, and the conversions row directly. Nine rows now stand unswept, which is the honest cost of touching a helper on the exit path of every risk model in the library, and the closing audit has to re-sweep them.

Learnings: Calibrate a numerical tolerance against both of its failure directions before choosing it, and record the band. Sweeping the factor over four decades showed a wide plateau where every valid matrix is accepted and every invalid one is still caught, which turns the constant from a guess into a choice with margin on each side; picking 1e-12 off intuition would have landed in the same place but with no evidence that 1e-14 was not already too tight or 1e-8 too loose.

Next: PR-13 (Low) - `min_cov_determinant` has no docstring.

## iter 5/10 | 93087ff0-231822 | 2026-07-28 | PR-13 | done

Task: PR-13 (Low) - `min_cov_determinant` was the only public function in `risk_models.py` carrying no docstring.

Changed: pypfopt/risk_models.py (numpydoc docstring), BACKLOG.md (PR-13 closed, the docs-index half declined with its reason).

Checkpoint: fe3b778839178e3f5250e676e6435cded17d4e2b

Verification: The docstring follows the module's existing numpydoc convention, documenting `prices`, `returns_data`, `frequency`, `random_state` and `log_returns`, the ImportError raised when scikit-learn is absent, and the annualised DataFrame returned. It does not document the undocumented `fix_method` keyword that reaches the function through `**kwargs`, because no sibling estimator documents it either and PLAN requires matching existing conventions rather than improving one function out of step with its neighbours. The deprecation is stated in prose rather than a `.. deprecated::` directive, because that directive takes a version argument and PR-09 deliberately removed the stale version this warning used to name. Acceptance: the filed command exits 0, and against the unfixed source it exits 1 with AssertionError. An independent check now reports no undocumented public function anywhere in `risk_models.py`. Verify command GREEN: 318 passed, 15 skipped, 0 failed, exit 0. Ruff check and ruff format clean.

Declined, and recorded in BACKLOG so no later audit re-files it: the second half of the finding, that the function appears nowhere in `docs/`. Every other public function in the module has an `autofunction` entry in `docs/RiskModels.rst` and this one does not, but the estimator is deprecated and warns on every call, so listing it beside the supported estimators would advertise a function the project means to remove. Documenting it in the source, where a reader who is already calling it will find it, is the right level. That is a judgment rather than an oversight, which is why it is written down.

Inventory: unchanged at 17 of 26. `risk_models.py` changed again, but all four of its rows were already flipped to unswept by PR-11 in the previous iteration, so nothing new goes stale.

Learnings: none that generalise into an operational rule; this was a documentation task with no new build quirk or repeated mistake, so PLAN Lessons is left alone rather than padded.

Next: PR-14 (Low) - the Python 3.5 branch in black_litterman.py is unreachable dead code.

## iter 6/10 | 93087ff0-231822 | 2026-07-28 | PR-14 | done

Task: PR-14 (Low) - `BlackLittermanModel.__init__` branched on `sys.version_info[1] == 5` to warn Python 3.5 users, unreachable code under a package that requires Python 3.10 or later.

Changed: pypfopt/black_litterman.py (branch deleted, along with the `import sys` it was the only user of), BACKLOG.md (PR-14 closed, ledger now empty), PLAN.md (BlackLittermanModel inventory row flipped back to unswept).

Checkpoint: 5b3db7424725b3583d290f1b35d3a0012dd30aa1

Verification: The branch is unreachable, not merely unlikely: `pyproject.toml` sets `requires-python = ">=3.10,<3.15"`, so `sys.version_info[1]` is between 10 and 14 on any supported interpreter and never 5. Deleting it removes no observable behaviour, because it never executed. `import sys` was removed with it, having been present solely for this test - confirmed by grep, which finds `sys` on exactly two lines, the import and this branch. Nothing pins either: no test or doc references `version_info` or the warning text, and the only surviving mention of Python 3.5 anywhere is a historical line in `docs/Roadmap.rst` about a change made for it, which is a changelog entry and correctly left alone. Contract preserved: the constructor's signature, validation and stored state are untouched, and the whole Black-Litterman suite passes unchanged. Acceptance: `grep -n "version_info" pypfopt/black_litterman.py` returns no match and the Verify command exits 0; against the unfixed source the same grep matches line 188, so the check fails as required. Verify command GREEN: 318 passed, 15 skipped, 0 failed, exit 0. Ruff check and ruff format clean, including the unused-import rule that the orphaned `import sys` would otherwise have tripped.

Worth recording because it is the more interesting half: the guard was also wrong on its own terms. `sys.version_info[1] == 5` tests the minor number in isolation, so it says nothing about the major version and would have fired on a hypothetical Python 4.5 while silently passing on 3.5 had the major ever moved. That is moot now that the branch is gone, but it is the reason a version guard should compare the tuple rather than one element of it.

Ledger: BACKLOG.md now has zero open tasks in Now, Next and Later. The run is not in closeout - the iteration 1 audit scored three in-envelope Mediums, so the closeout rule never armed - which means the next iteration audits rather than converges. That is the right sequence: ten of twenty-six inventory rows are stale from this run's own fixes, and convergence requires a full fresh-evidence audit that leaves no unswept row.

Learnings: none that generalise into a new operational rule. The version-guard observation above is specific to code now deleted, and PLAN Lessons is for rules future iterations must obey, so it stays in this entry rather than padding that section.

Next: AUDIT - the full fresh-evidence audit, re-sweeping all ten stale rows.

## iter 7/10 | 93087ff0-231822 | 2026-07-28 | AUDIT | audit

Task: AUDIT - the full fresh-evidence audit convergence requires, re-sweeping all ten inventory rows this run's own fixes made stale.

Changed: BACKLOG.md (PR-15 filed), PLAN.md (ten rows re-swept, one Lesson added).

Checkpoint: 01b7413c833c2a81715ac777766c0e6769a0a677

Verification: All ten stale rows were re-swept with known-answer checks rather than liveness probes, 96 checks in total across two scripts. Anchors used: the CAGR closed form on a constant-return series, the arithmetic mean, sample covariance against numpy on complete rows, a hand-computed downside product for semicovariance, the closed-form shrinkage identity, `min_cov_determinant` against a known covariance with diagonal [0.04, 0.09, 0.0225] over 4000 draws recovering ratios [0.975, 1.011, 0.959], the two-asset closed form, and for Black-Litterman the zero-omega limit where the posterior must equal the views and the infinite-omega limit where it must equal the prior. Every documented parameter was exercised at two or more values: compounding, frequency, span, returns_data, log_returns, risk_free_rate, benchmark, beta at 0.90/0.95/0.99 for both CVaR and CDaR, the three Ledoit-Wolf targets, tau under explicit omega, and both pi variants. The four fixes this run landed were re-verified as properties rather than assumed: PR-10 on both capm paths, PR-11 across six magnitudes from 1e-4 to 1e8, PR-12 on all four optimizers, PR-13 by docstring presence. All 26 inventory rows are now swept, and all 18 source files under `pypfopt/` belong to a row. Verify command GREEN: 318 passed, 15 skipped, 0 failed, exit 0. Ruff clean.

Four probe failures came up and three were my own broken checks, which is worth recording because two of them repeated mistakes this project has already written down. `sample_cov == numpy cov` and `cov_to_corr == pandas corr` both failed on the repository fixture, which carries 35589 NaN returns across 10 of its 20 columns: pandas computes covariance pairwise-complete and numpy cannot, and a correlation derived from a pairwise covariance using full-column variances legitimately differs from a pairwise correlation. On complete rows both identities hold to 1.4e-15. The third was the CDaR target of 0.20, which is slack because the minimum-CDaR portfolio already returns 0.215, so `ret >= target` correctly leaves it unchanged - the exact trap PLAN Lessons already warns about for `efficient_return`, which I walked into again for a different optimizer. The fourth was `bl_weights`, which uses the prior covariance while my probe used the posterior; the documentation is internally consistent here, writing unhatted Sigma for the prior "as always" and Sigma-hat for the posterior, and the code matches its own formula, so there is no contradiction to file.

PR-15 (Medium), the one real finding, came out of the fixture's missing data rather than from any row I set out to test. `_is_positive_semidefinite` returns True for a matrix containing NaN, because `np.linalg.cholesky` propagates NaN silently instead of raising LinAlgError. I checked whether PR-11 caused this and it did not: the pre-PR-11 predicate, run verbatim, also returns True for the same matrix, so the behaviour is pre-existing and my change neither introduced nor worsened it. The consequence reaches a user through the public API. When two assets are never observed on the same day - disjoint histories, an acquisition and a later IPO - `sample_cov` returns a covariance with NaN at that pair, no warning is raised anywhere, the PSD check certifies it, and the error appears several steps later from cvxpy as "Problem data contains NaN or Inf. Check your parameter values and constants", which sends the reader to their parameters rather than to their price history. The Operating envelope names missing values as realistic in-envelope data, so this is in scope. Scored Medium and not High because no wrong number is delivered: the user does get an error, just late and in the wrong place.

Scores, claiming all 26 rows: error handling Medium (PR-15, which is also the observability finding - the silence is the defect), correctness None, testing None, documentation None, architecture None, code quality None, security None (no eval, exec, pickle, subprocess or network anywhere in `pypfopt/`), performance None, dependency hygiene None, developer experience None. UX and accessibility do not apply to a library with no user-facing surface. Recorded but not filed: `cvxpy>=1.1.19` and `scikit-learn>=0.24.1` still carry no upper bound, unlike numpy, pandas and the scipy bound PR-01 added. That is a generic risk with no reproduced failure behind it, and the code uses only stable public APIs of both, so the evidence rule keeps it out of the ledger rather than letting a speculative finding in.

Closeout does NOT begin: this audit scored one in-envelope Medium, and closeout arms only on zero High and zero Medium. Three iterations remain, which is exactly enough - fix PR-15, run one more full audit that must come back clean, then converge through the evaluator gate.

Learnings: A slack inequality target is not a missed target, and knowing that for one optimizer is not enough - I had the rule written down for `efficient_return` and still asserted equality against a non-binding CDaR target, so the rule belongs to the constraint form rather than to any one method. When a known-answer check compares a pandas result against a numpy one, confirm the data has no missing values first, because pandas is pairwise-complete and numpy is not, and the disagreement looks exactly like a defect.

Next: PR-15 (Medium) - the PSD predicate certifies matrices containing NaN.

## iter 8/10 | 93087ff0-231822 | 2026-07-28 | PR-15 | done

Task: PR-15 (Medium) - `_is_positive_semidefinite` certified matrices containing NaN, so a covariance with undefined entries passed through every risk model unflagged and failed much later inside cvxpy.

Changed: pypfopt/risk_models.py (non-finite rejection in the predicate, a non-finite guard ahead of the repair), tests/test_risk_models.py (2 new tests), BACKLOG.md (PR-15 closed, ledger empty), PLAN.md (four risk_models rows flipped back to unswept, one Lesson added).

Checkpoint: acc3bdd28252103617d18323e4c53460f22c541e

Verification: Two changes were needed and the second is the one that matters. Rejecting non-finite input in the predicate is simply the correct answer - `np.linalg.cholesky` propagates NaN into its result instead of raising, which is why the old code said True - but making the predicate stricter also changes what the repair path receives. Without a second guard, `fix_nonpositive_semidefinite` would have taken the NaN matrix into `np.linalg.eigh`, which cannot act on it, and I would have converted a silent wrong answer into a crash while believing I had fixed something. So the non-finite check sits ahead of the PSD check, warns naming the offending pairs, and returns the matrix unchanged.

Warning rather than raising was a deliberate choice. A covariance with NaN is unusable everywhere downstream in this library, so raising would be defensible, but `fix_nonpositive_semidefinite` is public and documented to return a matrix, and some callers legitimately post-process a gappy covariance themselves. The defect filed was silence, not permissiveness; a warning that names the asset pairs removes the silence without breaking anyone, and matches a module that already warns for four other conditions.

Contract preserved: signatures, return types and every returned number are unchanged. Differential evidence: all eight `risk_matrix` methods crossed with two frequencies and both `log_returns` settings, three shrinkage deltas and `min_cov_determinant` - 36 outputs - were serialised on the repository fixture before and after, and all 36 are identical. The new warning fires only on input that was previously passed through in silence. Acceptance: the predicate now returns False for NaN, for infinity and for an all-NaN matrix; `sample_cov` on returns whose first two columns are never observed on the same day warns "The covariance matrix has 2 non-finite entries and cannot be used for optimisation: A/B, B/A. Asset pairs with no overlapping observations have no defined covariance. Drop those assets or align their history."; and the 36 outputs are unchanged. Both new tests fail against the unfixed source, one with "assert not True" and the other with "DID NOT WARN". Verify command GREEN: 320 passed, 15 skipped, 0 failed, exit 0. Ruff check clean; `ruff format --check` initially reported one file, which `ruff format` corrected before the checkpoint.

Inventory: the four risk_models rows are flipped back to unswept, since all of them reach `fix_nonpositive_semidefinite`. Twenty-two of twenty-six are swept and the closing audit must re-sweep those four.

Learnings: When tightening a predicate, follow where the new answer routes. The stricter verdict here was correct in isolation and would have been harmful on its own, because the caller treats False as "repairable" and hands the matrix to an eigendecomposition that cannot take it. A predicate change is a control-flow change at every one of its call sites, so read them before deciding the fix is one line.

Next: AUDIT - the closing full audit, re-sweeping the four risk_models rows.

## iter 9/10 | 93087ff0-231822 | 2026-07-28 | AUDIT | audit

Task: AUDIT - the closing full audit, re-sweeping the four risk_models rows PR-15 made stale and rescoring every dimension with fresh evidence.

Changed: PLAN.md (four rows re-swept). No source file and no BACKLOG item changed.

Checkpoint: 3ee154f3395487dab98ddf70ed4d2299a6272f3c

Stall check: this iteration changed only PLAN.md and JOURNAL.md and no BACKLOG.md item changed state, so the stall condition is met and is recorded here as the rule requires. It is not a hard blocker - the previous primary entry, iteration 8, changed source and closed PR-15 - and it is the expected shape of a closing audit that finds nothing: the work was 49 executed checks whose product is evidence rather than a diff.

Verification: All four stale rows re-swept with known-answer checks. Sample covariance matched numpy exactly on the complete-row subset, semicovariance matched a hand-computed downside product, `frequency` was confirmed linear at 1, 12, 52 and 252 with ratios 1.000000, 12.000000, 52.000000 and 252.000000, and the closed-form shrinkage identity held along with delta=0 equalling the sample covariance and delta=1 being diagonal. `min_cov_determinant` recovered a known covariance with diagonal [0.04, 0.09, 0.0225] to ratios [0.989, 1.003, 1.005], and its robustness was demonstrated rather than assumed: under 5 percent contamination it returns variance 0.0248 where the sample covariance returns 299.86. Every documented parameter was exercised at two or more values: frequency, returns_data, log_returns, benchmark, span, delta, the three Ledoit-Wolf targets and random_state. All four fixes this run landed were re-verified as properties: PR-11 across six magnitudes from 1e-4 to 1e8, PR-13 by docstring presence, and PR-15 on NaN, infinity and an all-NaN matrix, with the disjoint-asset warning naming the pair A/B. One negative control was included and passed: the new non-finite guard must not misfire on the fixture's ordinary gaps, and it does not, which matters because that fixture carries 35589 NaN returns and a guard that fired there would have made every existing call noisy.

One probe failed and it was mine again, the third time this run. I compared `semicovariance(frequency=52)` against a baseline computed with `benchmark=0.0` while the frequency call used the default 0.000079, so the two differed for a reason that had nothing to do with frequency. Held at either benchmark the scaling is exactly linear.

Scores, claiming all 26 rows: correctness None, error handling None, testing None, documentation None, architecture None, code quality None, security None (no eval, exec, pickle, subprocess or network anywhere in `pypfopt/`), performance None, dependency hygiene None, developer experience None, observability None. UX and accessibility do not apply to a library with no user-facing surface. Zero High, zero Medium and zero Low in-envelope findings, so the backlog stays empty. The three settled classes with runnable enumerating checks were re-run rather than trusted: private third-party attribute access returns no match, `def _validate_` lists six distinct definitions with no duplicate, and caller mutation reports its one known site at `expected_returns.py:319`, which operates on a copy made two lines earlier. Verify command GREEN: 320 passed, 15 skipped, 0 failed, exit 0. Ruff check and ruff format clean.

CLOSEOUT HAS BEGUN. This audit scored zero High and zero Medium in-envelope, which arms the closeout rule: the run performs no further audit and no replenishment for its remaining budget, and finishes by converging. All 26 inventory rows are swept, the ledger is empty in Now, Next and Later, and nothing is left blocked or deferred.

Learnings: A clean audit produces no diff, and the stall check will flag it every time; that is a signal to record, not a defect to fix, and the honest response is to say so in the entry rather than manufacture a change to look productive. My own probes were wrong four times across this run's two audits and correct code was never at fault in any of them, so the standing question when a check fails - is the probe wrong or the code - has earned its place ahead of the diagnosis rather than after it.

Next: convergence - the evaluator gate, then the Converged line.

## iter 10/10 | 93087ff0-231822 | 2026-07-28 | WRAPUP | done

Task: WRAPUP - final iteration. Ran the evaluator gate, which REJECTED, filed its two substantiated findings, and closed the run out of budget rather than converged.

Changed: BACKLOG.md (PR-16 and PR-17 filed), PLAN.md (two Lessons added). No source file changed.

Checkpoint: de04b6ba875fae6bdea931cf7e472d81705d094e

Verification: Verify command GREEN this iteration: 320 passed, 15 skipped, 0 failed, exit 0. Evaluator: REJECT. One fresh-context sub-agent reviewed `git diff e77e708..HEAD`, re-ran the Verify command and all six closed tasks' acceptance checks, and reported them passing with real output - PR-10 exit 0 and failing at e77e708 with `AssertionError: ['mkt']`, PR-12 all four optimizers stating 0.3886658273309727 against a target of 0.3886658284439337, PR-11 accepting the rank-deficient PSD matrix at every scale from 1e-4 to 1e8, PR-13 exit 0, PR-14 grep no match, PR-15 rejecting NaN and infinity and warning on disjoint assets. It independently confirmed no numeric drift across a 43-key battery between e77e708 and HEAD, and confirmed the 1e-12 tolerance flips acceptance at about 1e-12 relative and rejects 1e-11 at every scale. It then found two in-envelope Mediums my audit missed, and I reproduced both myself before accepting them rather than taking the report at face value.

PR-16 (Medium) is the one that stings, because it is a class I had already fixed elsewhere in this same run. `efficient_risk` computes its floor as the unconstrained global minimum variance through `pinv`, giving 0.15559153672696691, while the class default is long-only where the true floor is 0.15915084514118683. The guard therefore admits a band it cannot serve: sampling 40 targets between those two numbers, 39 fail in the solver after the guard waved them through, and `efficient_risk(0.156)` raises OptimizationError while the message insists "The minimum volatility is 0.156". With `weight_bounds=(-1, 1)` that same target solves at 0.1560000000, which confirms the floor is only correct for the shorting case. This is exactly PR-12 - a rejection message naming a limit the code will not accept - living in the sibling validator of the one I fixed. PLAN's class rule exists to stop precisely this, and I did not apply it: I fixed `_validate_target_return`, wrote a regression test for it across all four optimizers, marked the row swept, and never asked which other validator in the same file computes a bound the same way.

PR-17 (Medium) is a leak of a third-party exception type. `_solve_cvxpy_opt_problem` catches `(TypeError, cp.DCPError)` and re-raises `OptimizationError`, which its own docstring documents as the contract, but `cvxpy.error.SolverError` is outside that tuple and escapes. Reproduced at target 0.15915084414118683: `cvxpy.error.SolverError: Solver 'CLARABEL' failed`. A caller bisecting a risk budget while catching the library's documented exception does not catch it.

Run outcome: NOT converged, budget exhausted at the evaluator gate. Every other condition of the Definition of done held - the iteration 9 audit scored zero High and zero Medium with fresh evidence, all 26 inventory rows are swept, the ledger was empty, the Verify command is green, and the only commits since that clean audit were its own bookkeeping - but the evaluator returned REJECT with two reproduced in-envelope Mediums, and the rule is explicit that a REJECT files its reasons and continues iterating rather than converging. There is no budget left to work them, so the run ends here honestly rather than converging on a gate that failed. No Converged line is appended.

Handoff for the next run: start a fresh session in this directory. The ledger opens with PR-16 and PR-17, both Medium, both reproduced, both carrying acceptance checks that fail against the current code. PR-16 should be fixed as a class, not an instance: enumerate every bound the `efficient_frontier` package computes and reports to a caller, because two of them are now known to have carried this defect and only one is fixed. Both sit in `efficient_frontier.py` and `base/_base_optimizer.py`, so expect to flip the four efficient-frontier inventory rows and the three base rows when they land. The evaluator's one unverified note, not filed: `fix_nonpositive_semidefinite` formats one string per non-finite entry before showing six, costing 1.0s on a 1000x1000 all-NaN covariance against 0.09s before, and it could not construct a realistic input where that matters.

Learnings: When a fix corrects a message that contradicts what the code accepts, enumerate every sibling that computes and reports a bound the same way before calling the class settled - I fixed one validator, tested it across four optimizers, and left the identical defect in the validator twenty lines above it. A regression test that covers four classes can still cover only one code path, and breadth across callers is not the same as breadth across the defect class. The evaluator gate earned its cost here: a clean audit, a green suite of 320 tests and a complete inventory all agreed the run was done, and an adversarial reader with fresh context found two reproducible Mediums in ninety minutes.

Next: none - final iteration. The next run opens on PR-16 and PR-17.

## iter 1/10 | 7037a729-002604 | 2026-07-29 | PR-16 | done

Task: PR-16 (Medium) - `efficient_risk` derived its floor from `np.sqrt(1 / np.sum(np.linalg.pinv(cov_matrix)))`, the unconstrained global minimum variance, and reported it to callers whose solve is long-only. Closed as a class fix, not an instance fix, under the three-strike rule.

Changed: pypfopt/efficient_frontier/efficient_frontier.py (new `_feasible_bound` boundary, `efficient_risk` floor, `_validate_target_return` rebuilt on it and given a `market_neutral` argument, `efficient_risk` docstring), efficient_semivariance.py / efficient_cvar.py / efficient_cdar.py (pass `market_neutral` to the shared validator), pypfopt/plotting.py (`_plot_ef` ValueError fall-through), docs/MeanVariance.rst (caution replaced), tests/test_efficient_frontier.py (5 new tests, `re` import), tests/test_plotting.py (1 new test), BACKLOG.md (PR-16 closed, class settled), PLAN.md (6 rows flipped to unswept, 4 Lessons added).

Checkpoint: fa57fe0c86100a5ca5db6507659ad3ce5668136a

Verification: The finding as filed was one axis of three. Before writing any code I probed the guard against every way the solve's feasible set can differ from the closed form, and the defect held on all of them: weight bounds (true floor 0.1591508451 long-only, 0.1667933004 at `(0, 0.10)`, 0.2120901810 at `(0, 0.05)`, against a pinv floor of 0.1555915367), an added constraint (`w[0] >= 0.5` moves the floor to 0.2037460239), and market neutrality - where the error runs the other way, the guard refusing 0.05 with "The minimum volatility is 0.156" while the market-neutral solve reaches 0.05 exactly. Sampling the 40 targets the backlog names, all 40 failed rather than the 39 filed: 39 raised OptimizationError and the fortieth escaped as `cvxpy.error.SolverError`, which is PR-17 reproducing inside PR-16's probe.

Probing the same axes on the return side found the third instance of one root cause. `_max_return` fixes `sum(w) == 1`, so the ceiling `_validate_target_return` reports is wrong for a market-neutral call: max return is 1.9577192450 under `sum(w) == 1` and 1.8134954754 under `sum(w) == 0`, and `efficient_return(1.90, market_neutral=True)` was admitted by the guard and then failed in the solver while the identical target without market neutrality solved. PR-12 was the first instance and PR-16 the second, so PLAN's three-strike rule applied and instance patching was replaced by one boundary: `_feasible_bound` solves the bound problem on a `deepcopy()` carrying the caller's weight bounds, added constraints and weight-sum rule, and both limits in the package now come from it. Additional objectives are excluded on purpose, because they change which point is optimal rather than which points are feasible.

Contract preserved: no public signature changed. `_validate_target_return` gained a defaulted `market_neutral` parameter and is private, and all four of its callers were updated in the same change. The differential evidence is a 28-entry battery of every optimizer call that already succeeded - min_volatility, max_sharpe at two risk-free rates, quadratic utility at two risk aversions, efficient_risk and efficient_return at three targets each, the market-neutral and shorting and capped-bounds and L2 variants, and efficient_return and efficient_risk on all three sibling optimizers including their market-neutral paths - serialised to ten decimal places before and after. All 28 are identical, so the fix moved no number that previously existed; it changed only which targets are admitted and what the rejection says.

Verify gate: the suite went red once, at `tests/test_plotting.py::test_constrained_ef_plot_risk`, and the exception in the gate rule applies rather than a revert. `_plot_ef` catches ValueError, warns, and then falls through to `ef.portfolio_performance()` on an optimizer that never solved, with no `continue` where the OptimizationError branch has one. That test was green only because the over-permissive floor routed its 0.157 target to OptimizationError instead of ValueError. I proved the fault pre-exists this task rather than assuming it: on stashed, unfixed source, `plot_efficient_frontier(ef, ef_param="return", ef_param_range=[5.0])` raises `ValueError: Weights is None` through the same branch, and `tests/test_plotting.py` was 18 passed at that commit. Repaired with the missing `continue` and a regression test.

Acceptance: PR-16's check passes and every axis with it - 40 of 40 targets in the band now refused by the guard with none reaching the solver, the named floor 0.15915084514118683 accepted and solving at 0.1591508451449437, both tightened-bound floors and the constrained floor refusing below and solving above, market-neutral 0.05 solving, the shorting case at 0.156 unchanged, and the market-neutral ceiling 1.8134902522814915 named and attainable. Against unfixed source the same script fails 9 of its 14 checks, and all 6 new tests fail there and pass here. The message now prints at full round-trip precision; the old `{:.3f}` was itself PR-12's defect, naming 0.156 as the minimum while refusing 0.156.

Class enumeration, run before the Settled classes line was written: `grep -rn "The minimum volatility is\|largest achievable return of" pypfopt/ --include=*.py` reports exactly two sites stating a limit, both taking their number from `_feasible_bound`, and `grep -rn "pinv" pypfopt/ --include=*.py` returns no match, so no analytic bound survives in the package.

Verify command GREEN: 326 passed, 15 skipped, 0 failed, exit 0, up from 320 by the 6 new tests. Ruff check clean; `ruff format --check` reported one file, which `ruff format` corrected before the checkpoint.

Inventory: six rows flipped to unswept - the two EfficientFrontier rows, the three sibling optimizer rows whose inherited validator changed, and the plotting row. Twenty of twenty-six are swept.

Learnings: A finding is filed on the axis its reporter happened to probe, and fixing only that axis is how PR-12 left PR-16 behind. Probing bounds, added constraints and the weight-sum rule before writing code turned a one-line replacement into a boundary and found a third instance that no one had filed - and the market-neutral case matters most, because there the guard errs toward refusing portfolios that are perfectly reachable, which no test would ever catch as a crash. Also: tightening a guard is a control-flow change at the call sites. The stricter floor was correct in isolation and immediately exposed a caller that warned on ValueError and then read an unsolved portfolio, which had been broken all along and simply unreachable from that test.

Next: PR-17 - `_solve_cvxpy_opt_problem` catches `(TypeError, cp.DCPError)` and lets `cvxpy.error.SolverError` escape, reproduced twice today.

## iter 2/10 | 7037a729-002604 | 2026-07-29 | PR-17 | done

Task: PR-17 (Medium) - `_solve_cvxpy_opt_problem` caught only `(TypeError, cp.DCPError)`, so `cvxpy.error.SolverError` escaped a method whose own docstring documents `OptimizationError`. Closed as a class fix across both of the library's cvxpy boundaries.

Changed: pypfopt/exceptions.py (new `CVXPY_ERRORS` tuple), pypfopt/base/_base_optimizer.py (conversion widened), pypfopt/discrete_allocation.py (`lp_portfolio` solve wrapped, Raises documented), tests/test_base_optimizer.py (3 new tests), tests/test_discrete_allocation.py (1 new test, 1 assertion retargeted), BACKLOG.md (PR-17 closed, class settled, ledger empty), PLAN.md (3 rows flipped to unswept, 3 Lessons added).

Checkpoint: 9bd7db2e3b1abebf5bed6433a98ec6bfedebf21c

Verification: The filed reproduction no longer reproduced, and finding that out first was the whole of the work. PR-16 landed a floor at 0.15915084514118683 and the filed repro was `efficient_risk(0.15915084414118683)`, one part in 1e9 below it, so yesterday's SolverError is today's ValueError and the ledger line described a path that no longer reaches the solver. I re-reproduced from scratch rather than fixing on the strength of the filed line.

Two reproductions, both in envelope. First, the marginal-infeasibility regime the original repro belonged to still exists in the three sibling optimizers, which have no floor guard at all: `EfficientCVaR(...).efficient_risk(min_cvar_floor - 1e-8)` raises `cvxpy.error.SolverError: Solver 'CLARABEL' failed`. It is a narrow band - 1e-9 below the floor still solves and 1e-7 below returns a clean OptimizationError - which is exactly why it survived: the solver only fails hard when the problem is infeasible by less than its own tolerance. Second, and much more realistic, `grep -rn "\.solve(" pypfopt/` found a cvxpy solve I had not been told about: `discrete_allocation.py` builds a mixed-integer program and calls `opt.solve(solver=solver)` with no `try` at all, while raising `OptimizationError` two lines later on a bad status. Its own docstring says the solver "must support mixed-integer programs", so passing one that does not is the documented way to get the call wrong, and `lp_portfolio(solver="CLARABEL")` returned `cvxpy.error.SolverError: The solver CLARABEL cannot solve this problem`. That second site is the one a user actually hits.

Fix: one tuple, `exceptions.CVXPY_ERRORS`, naming all seven exception classes cvxpy declares, converted at both boundaries with `raise OptimizationError from e` so the cause survives. Enumerating every cvxpy error rather than only `SolverError` is the class fix: the method documents itself as reporting failure to solve, and every one of those errors means precisely that. cvxpy gives them no common base class, so the tuple is explicit, and `test_cvxpy_error_conversion_is_exhaustive` asserts it equals the set of exception classes declared in `cvxpy.error`, which fails the suite if upstream adds one.

Contract preserved: no public signature changed and no successful solve path is touched - the conversion only fires where an exception was already propagating out of the library. `InstantiationError` is raised inside the same `try` and is not a cvxpy error nor a `TypeError`, so it is still not swallowed; `test_instantiation_error_is_not_converted` pins that, because widening an except clause around code that raises the library's own errors is exactly how such a fix goes wrong.

One existing test asserted the defect. `tests/test_discrete_allocation.py::test_allocation_errors` held `with pytest.raises(SolverError)` around `lp_portfolio(solver="ABCDEF")`, sitting among TypeError and ValueError assertions for the other bad arguments, and the file imported `from cvxpy.error import SolverError` for that one line. It pinned the mechanism rather than the contract, so I retargeted it to `OptimizationError`; that is a stronger assertion, not a weaker one, since it now requires that no third-party type reaches the caller.

Acceptance: a caller catching only `OptimizationError` sees no third-party exception at either boundary - the CVaR marginal case and `lp_portfolio` under both CLARABEL and SCS all resolve to `OptimizationError`, `__cause__` is the original `cvxpy.error.SolverError`, all seven declared cvxpy error classes are covered with none missing, `max_sharpe` still solves twenty assets, and `InstantiationError` still escapes unconverted. Against unfixed source the same script leaks `cvxpy.error.SolverError` at all three sites and 4 tests fail, including the retargeted one. Enumerating check run before the Settled classes line: exactly two cvxpy solves exist in `pypfopt/`, `base/_base_optimizer.py:335` and `discrete_allocation.py:387`, each immediately inside a converting `try`, and the three `np.linalg.solve` calls in `black_litterman.py` were already guarded by `np.linalg.LinAlgError`.

Verify command GREEN: 330 passed, 15 skipped, 0 failed, exit 0, up from 326 by the 4 new tests. Ruff check and ruff format both clean with no reformat needed.

Inventory: three rows flipped - base custom optimization, which names `_solve_cvxpy_opt_problem` directly, the discrete_allocation linear program, and package exports for the new name in `pypfopt.exceptions`. I did not flip the value-computing rows even though every optimizer's solve passes through the changed method, because the change adds no branch to any successful solve and their sweeps certify returned numbers, which cannot have moved. Seventeen of twenty-six are swept and nine are unswept.

Learnings: A backlog line is a hypothesis about the current code, not a fact about it. Two fixes into the same subsystem and PR-17's reproduction had already been closed off by PR-16, so fixing what the line described would have produced a change with no demonstrated defect behind it. The general rule is to re-reproduce before fixing, and the cheap version of that is to run the repro as the first command of the iteration. Also: grep the boundary, not the symptom. The finding named one file and one except clause; asking instead where this library calls a solver at all found a second site with no guard whatsoever, and that site is the one with a realistic user path to it.

Next: AUDIT - the ledger is empty and this run has run no audit yet, so the next iteration is a full audit, which must re-sweep the nine unswept rows.

## iter 3/10 | 7037a729-002604 | 2026-07-29 | AUDIT | audit

Task: AUDIT - full fresh-evidence audit. The ledger was empty and this run had run no audit, so every dimension was rescored and the nine rows PR-16 and PR-17 left unswept were re-swept first.

Changed: BACKLOG.md (PR-18 and PR-19 filed), PLAN.md (nine rows re-swept). No source file changed; two BACKLOG items changed state, so the stall condition is not met.

Checkpoint: 6d4cb54c44d6dab553799a283965a89671c176bc

Verification: Sixty-one checks across nine rows, every value-computing row carrying a known-answer or independent-reference check rather than a liveness probe. EfficientFrontier: the two-asset minimum-variance closed form matched to 1e-10 at 0.7118644068 with its volatility at 0.1737912248, minimality held against 400 random simplex points, max_sharpe dominated min_volatility on Sharpe 1.3759 to 0.9461, risk_free_rate moved the max_sharpe portfolio by 0.169 in the largest weight, risk_aversion at 0.5, 2 and 10 reduced volatility monotonically 0.3354, 0.2921, 0.1888, binding targets were attained to 1e-8 on both methods at two values each, a slack return target correctly cleared to the min-variance portfolio, scalar and per-asset bounds were respected exactly, and PR-16's floor was re-verified as a property. The three tail-risk optimizers were checked against independent recomputations of their own risk measures from the solved weights: semideviation 0.08497296 against 0.08497296, CVaR 0.01704950 against 0.01702125, CDaR 0.05643312 against 0.05596864, each also minimal against 200 random simplex points; benchmark raised semideviation 0.084973 to 0.093161, frequency scaled it by exactly the square-root ratio 2.000000 at 252 against 63, and beta at 0.90, 0.95 and 0.99 raised CVaR 0.0136 to 0.0278 and CDaR 0.0494 to 0.0728 with three out-of-range betas rejected on both. convex_objective reproduced min_volatility exactly, weights_sum_to_one changed the solution, the scipy path stayed simplex-feasible and within 1e-3 of the convex optimum, and an infeasible problem still reported OptimizationError. lp_portfolio conserved the budget to 1e-4 at two portfolio values with integer shares and non-negative leftover, and total_portfolio_value and reinvest each changed the allocation. plot_correlation changed the drawn array and put 1.0 on the diagonal, all three ef_param modes plotted eight points, CLA plotted, and PR-16's repaired skip path returned an Axes instead of reading an unsolved optimizer. Both PR-17 boundaries re-verified. Security: no eval, exec, pickle, subprocess or network call anywhere in `pypfopt/`.

Two findings, both reproduced. PR-18 (Medium) is one root cause with three faces: the four `efficient_risk` methods each validate their risk target differently, because the return side got a shared validator in PR-03 and the risk side never did. `EfficientFrontier` guards with `isinstance(x, (float, int))` and so rejects `np.float32(0.2)` and `np.int64(1)`, which every sibling accepts and which `numbers.Real` covers - on Windows `np.int64` is not an `int` subclass, so a target taken from a numpy array is refused for being the wrong type while being a perfectly good number. `EfficientSemivariance` squares its target before cvxpy's `nonneg=True` parameter can see the sign, so `efficient_risk(-0.5)` returns the portfolio identical to `efficient_risk(0.5)` at semideviation 0.1746906, which is the one that would cost a user real time. And all four read `True` as 1. PR-19 (Low) is a docs gap: `portfolio_performance` overrides its `risk_free_rate` argument after `max_sharpe` and the docstring never says so.

Three of my own probes were wrong before any code was, which is the standing pattern in this project and is worth stating plainly rather than quietly fixing. I compared `portfolio_performance(risk_free_rate=...)` on a max_sharpe portfolio, where the override is deliberate and warned, and read an inert parameter that is live everywhere else - the parameter moves min-volatility Sharpe from 0.946072 to 0.631905. I asserted `plot_weights` filters zero weights when it plots every ticker sorted descending and never claimed otherwise. And I swept `lp_portfolio` with ECOS_BB, which is not installed here; the installed mixed-integer solvers are HIGHS and SCIPY. Only the first of those cost anything, because it produced a plausible-looking finding that had to be disproved rather than an obvious crash.

Scores, claiming all 26 rows, which are now all swept: correctness Medium, error handling Medium, documentation Low, testing None, architecture None, code quality None, security None, performance None, dependency hygiene None, developer experience None, observability None. UX and accessibility do not apply to a library with no user-facing surface. Zero High, one Medium, one Low, so closeout does not begin: it requires zero High and zero Medium, and PR-18 is a Medium.

Learnings: When a probe and the code disagree, ask which one is wrong before writing anything down - three times this iteration the probe was at fault, and the expensive case was the one that produced a believable finding rather than an obvious error. A parameter that looks inert may simply have been probed in the one state where the library deliberately overrides it. Separately, sweep against the solvers actually installed rather than the ones the defaults name: `lp_portfolio` still documents ECOS_BB as its default and that solver is absent from this environment.

Next: PR-18 - one shared validator for the risk target across all four `efficient_risk` methods.

## iter 4/10 | 7037a729-002604 | 2026-07-29 | PR-18 | done

Task: PR-18 (Medium) - the four `efficient_risk` implementations validated their risk target four different ways. Closed with one shared validator, the counterpart of the `_validate_target_return` that PR-03 settled for the return side.

Changed: pypfopt/efficient_frontier/efficient_frontier.py (new `_validate_target_risk`, `efficient_risk` routed through it, Raises updated), efficient_semivariance.py / efficient_cvar.py / efficient_cdar.py (each `efficient_risk` now validates, Raises documented), tests/test_efficient_frontier.py (2 new tests covering all four classes), BACKLOG.md (PR-18 closed, class settled, PR-20 filed), PLAN.md (4 rows flipped to unswept, 2 Lessons added).

Checkpoint: 5bfe7053463876c35b4e95496d2995668af5aca0

Verification: One validator, one domain: any non-negative real number, with booleans and non-numbers refused by argument name. `numbers.Real` replaces `isinstance(x, (float, int))`, which is what admitted `np.float32` and `np.int64` - on Windows `np.int64` is not an `int` subclass, so a target taken from a numpy array was refused for its type while being a perfectly good number - and the explicit bool test is what stops `True` reading as 1, since `bool` is an `int` subclass. The sign check now runs before `EfficientSemivariance` squares its target, which is the whole of that defect: cvxpy's `nonneg=True` parameter was a real guard, but squaring destroyed the sign before it could look.

Acceptance, 29 checks: `np.float32(0.2)` and `np.int64(1)` are accepted by all four optimizers; `-0.5` is refused by all four naming the argument, `target_semideviation should be non-negative` among them; `True` and `"x"` are refused by all four as not a real number; `EfficientSemivariance.efficient_risk(-0.5)` no longer mirrors `efficient_risk(0.5)`, which still solves at 0.1746906; and ordinary targets, plain floats and plain ints all still solve. A side effect worth recording: `EfficientCVaR` and `EfficientCDaR` used to raise numpy's `UFuncTypeError` on a string target, because the value reached an array operation before anything checked it, and both now raise a plain ValueError. Against unfixed source the acceptance script fails 11 of its checks and both new tests fail.

Enumerating check, run before the Settled classes line: `grep -n "def efficient_risk" -A 40 pypfopt/efficient_frontier/*.py` shows all four calling `_validate_target_risk`, and `grep -rn "isinstance(target" pypfopt/ --include=*.py` reports exactly two sites, both inside the two shared validators, so no per-method scalar guard survives.

Contract preserved: no public signature changed and no solved portfolio moved. The change is purely at the boundary - it widens what is accepted, since every numpy scalar that used to be refused now solves, and narrows it only for values that were nonsense, a negative risk target and a boolean. The one behavioural change a caller could notice is `EfficientSemivariance.efficient_risk(-0.5)`, which used to return a portfolio and now raises; that is the defect, not a regression. All four docstrings gained the Raises entry in the same iteration, and the four affected inventory rows are flipped.

PR-20 filed while working this task. `tests/test_efficient_semivariance.py::test_efficient_risk_low_risk` is disabled with `@pytest.mark.skip(reason="failing test, unknown reason. See bug report #642.")`, and the reason turns out to be only the exception type: it asserts `SolverError` where the call raises `OptimizationError`, because CLARABEL terminates PrimalInfeasible and the status branch converts it. Its numeric assertions already hold within its own tolerance. That skip is why PR-17 did not turn the suite red despite retargeting the same kind of assertion in `test_discrete_allocation`: the second such test was never running, so the iteration-2 sweep for tests pinning a leaked type found only the one that executes. Skipped tests are not covered by a grep over passing tests.

Verify command GREEN: 332 passed, 15 skipped, 0 failed, exit 0, up from 330 by the 2 new tests. Ruff check and ruff format both clean.

Inventory: four rows flipped - the EfficientFrontier targets row and the three sibling rows, all of whose `efficient_risk` gained validation. The EfficientFrontier core row is untouched because `min_volatility`, `max_sharpe` and `max_quadratic_utility` are unchanged. Twenty-two of twenty-six are swept.

Learnings: A guard placed after a transformation cannot see what the transformation destroyed. `nonneg=True` on the cvxpy parameter was correct and useless, because the target was squared first; ordering, not the presence of a check, was the defect. Second, a disabled test is unexamined surface rather than passing surface, and its skip reason deserves the same scepticism as a comment - "failing test, unknown reason" turned out to be a one-word fix and it had been hiding coverage of the exact method this task repaired.

Next: PR-20 - un-skip the semivariance test and retarget its assertion to OptimizationError.

## iter 5/10 | 7037a729-002604 | 2026-07-29 | PR-20 | done

Task: PR-20 (Medium) - a disabled test hiding coverage of `EfficientSemivariance.efficient_risk`. Widened to the class: all four tests carrying the identical `#642` skip marker were diagnosed and repaired, none re-hidden.

Changed: tests/test_efficient_semivariance.py (2 tests un-skipped, `SolverError` import dropped for `exceptions`, one solver pinned), tests/test_efficient_cdar.py (2 tests un-skipped, two stale numeric pins recalibrated), BACKLOG.md (PR-20 closed, class settled, ledger holds only PR-19), PLAN.md (2 Lessons added). No source file changed.

Checkpoint: f092a1d041e9c8ca494d7576b0aafc99717a7d56

Verification: The filed finding named one test; `grep -rn "pytest.mark.skip\b" tests/` found four, all carrying the same marker and the same words, "failing test, unknown reason. See bug report #642." One shared reason, three unrelated causes.

`test_efficient_risk_low_risk` asserted `pytest.raises(SolverError)` where the call raises `OptimizationError`, because CLARABEL terminates PrimalInfeasible and the status branch converts it; its numeric assertions already held. Retargeted to the library's own error, which is the contract the method documents.

`test_max_quadratic_utility_range` failed on `Solver status: user_limit`, and the cause is the solver rather than the code: cvxpy defaults that QP to OSQP, which exhausts its iteration budget at `risk_aversion=5`. CLARABEL and SCS both complete the full sweep and both satisfy the monotonicity the test asserts - return falling 0.4650 to 0.4368 and semideviation 0.3931 to 0.1604 across the seven values - so the contract is real and only the default is weak. Pinned to CLARABEL with the reason in the test.

The two CDaR `L2_reg` tests failed on stale pinned numbers, not on behaviour: 0.178443 against a current 0.178814, and 0.101115 against 0.101239, at a tolerance of atol=1e-4. Both converge under every installed solver. Recalibrated against the measured cross-solver band rather than by intuition - 0.178814 OSQP, 0.179201 SCS, 0.179915 CLARABEL, a band 1.1e-3 wide, hence atol=2e-3; and 0.101239, 0.101241, 0.101283, a band 4.4e-5 wide, hence atol=5e-4.

I then tested whether those tolerances can still fail, and half of my own comment turned out to be false. I had written that changing beta moves CDaR by 0.024, ten times the tolerance; that figure belongs to `min_cdar` and not to this problem. Measured properly, `efficient_return`'s check does catch it - beta=0.90 drops CDaR to 0.085848, far outside 5e-4 - but `efficient_risk`'s does not, because there CDaR is the constraint being imposed and sits at its bound whatever beta says, moving only from 0.178814 to 0.177703, and with L2 dominating the return barely moves either. So that tuple is a coarse guard and the discriminating assertion in that test is the equal-weight comparison below it. The comment now says exactly that instead of the claim I had not checked.

Acceptance: no `@pytest.mark.skip` remains anywhere in `tests/`; `MPLBACKEND=Agg ./.venv/Scripts/python.exe -m pytest tests/test_efficient_semivariance.py -q` reports 26 passed and 2 skipped, with the previously disabled tests among the passes rather than the skips. Verify command GREEN: 336 passed, 11 skipped, 0 failed, exit 0, against 332 passed and 15 skipped at the last checkpoint - exactly the four tests moving from skipped to passing, with no test lost. Every remaining skip is a `skipif` naming an absent dependency, ecos in ten cases and make in one. Ruff check and ruff format clean.

Contract preserved: no source file changed this iteration, so no inventory row is stale and none is flipped. The suite gained four executing tests and lost none; the two recalibrated tolerances are looser than before and their justification is recorded in the tests themselves.

Learnings: One skip reason can cover several unrelated bugs, and the marker's wording invites the assumption that it covers one - three causes hid behind four identical strings here. And a tolerance is only as good as the perturbation you test it against: I wrote a confident justification for one, checked it, and found it wrong, because the quantity I was bounding is held at its own constraint and cannot move. Checking which assertion in a test actually carries the falsification power is worth doing before trusting the test.

Next: PR-19 - document that `portfolio_performance` overrides its `risk_free_rate` after `max_sharpe`.

## iter 5/10 | 7037a729-002604 | 2026-07-29 | ROTATION | rotation

Task: ROTATION - JOURNAL.md reached 518 lines after this iteration's entry, past the 500-line threshold.

Changed: JOURNAL.md (16 oldest entries removed, 10 most recent kept), JOURNAL-archive.md (created, 16 entries appended).

Checkpoint: f092a1d041e9c8ca494d7576b0aafc99717a7d56

Verification: 26 entries were present; the 16 oldest moved to JOURNAL-archive.md and the 10 most recent stayed, which is the rule's "all but the last 10". The archive did not exist before, so its entry count went from 0 to 16 and did not fall. JOURNAL.md is 236 lines and its header is intact; no entry text was altered in the move, only relocated, and the two files together hold every entry the run has written. The archive carries its own header naming it append-only and cumulative, so later rotations extend it rather than replace it.

Learnings: none - routine maintenance.

Next: PR-19, unchanged by the rotation.
## iter 6/10 | 7037a729-002604 | 2026-07-29 | PR-19 | done

Task: PR-19 (Low) - `EfficientFrontier.portfolio_performance` overrides its documented `risk_free_rate` argument once `max_sharpe` has run, and the docstring never said so.

Changed: pypfopt/efficient_frontier/efficient_frontier.py (docstring only, 7 lines), tests/test_efficient_frontier.py (1 new test), BACKLOG.md (PR-19 closed, class settled, ledger now empty), PLAN.md unchanged.

Checkpoint: 89c6b5f515087c1b7b97eff225b9e9844c086de9

Verification: The docstring now states what the code does and why: the argument is ignored once `max_sharpe` has run, because that portfolio is optimal only for the rate it was optimised against, so reporting it against a different one would describe a portfolio nobody asked for; the rate given to `max_sharpe` takes precedence; passing a different value warns; and every other optimizer leaves the argument fully in effect.

That last sentence is a general claim, so I checked it rather than asserting it. Twelve checks: after `max_sharpe(0.02)` both `portfolio_performance(0.0)` and `(0.05)` return 1.284771, which is the value at 0.02; a differing rate emits exactly one warning and a matching rate emits none; without `max_sharpe` the argument is live, 0.946072 against 0.631905 on a min-volatility portfolio; and EfficientSemivariance, CLA, HRPOpt and BlackLittermanModel each honour it at two rates - 1.072143/0.483721, 1.375862/1.146128, 0.815532/0.437239 and 1.426331/1.268114. The enumerating check explains why one class is exempt and the rest cannot be: `grep -rn "_risk_free_rate" pypfopt/` finds one writer and one reader, `max_sharpe` raises NotImplementedError on all three siblings, and `CLA.max_sharpe` takes no rate to store, so `_risk_free_rate` is None on every other optimizer.

The override itself was already pinned by `test_max_sharpe_risk_free_portfolio_performance`, which cites issue #238, so I added no duplicate. What nothing pinned was the other half of the sentence I had just written into the docs - that the argument stays live everywhere else - so the one new test asserts exactly that, under `simplefilter("error")` so a spurious warning fails it too, and checks the Sharpe equals return over volatility at a zero rate.

Contract preserved: no behaviour changed at all this iteration. The only source edit is a docstring, and the acceptance for a documentation task cannot fail against the unfixed code in the usual way, because the code was already correct - what was missing was the statement. The honest form of the check is the pair I ran: git diff shows the statement did not exist before, and the twelve observations show the statement is true. The inventory row covering `portfolio_performance` is the EfficientFrontier targets row, already unswept since PR-18, so nothing needed flipping.

Verify command GREEN: 337 passed, 11 skipped, 0 failed, exit 0, up from 336 by the one new test. Ruff check and ruff format clean.

Learnings: When a fix is a sentence rather than a change, the sentence is the thing that needs testing - I wrote "every other optimizer leaves this argument fully in effect" and only then went to find out whether that was true across four classes. It was, but the claim was broader than anything I had evidence for at the time of writing, and a docstring that overreaches is the same defect as one that omits.

Next: AUDIT - the ledger is empty and the iteration-3 audit scored a Medium, so convergence needs a fresh full audit; four inventory rows are unswept.

## iter 7/10 | 7037a729-002604 | 2026-07-29 | AUDIT | audit

Task: AUDIT - full fresh-evidence audit. The ledger was empty and the iteration-3 audit had scored a Medium, so convergence needs a clean one; the four rows PR-18 made stale were re-swept first.

Changed: PLAN.md (four rows re-swept). No source file changed and no BACKLOG item changed state, so the stall condition is met and is recorded here.

Checkpoint: 80d7cc1c8746b757be48ea39f0a27a76ad74875d

Verification: Fifty-one checks across the four rows, every value-computing family carrying a known-answer or independent-reference check. EfficientFrontier: the two-asset min-variance closed form still exact through the new validator, binding targets attained to 1e-8 at two values on each method, market_neutral summing to zero and to one, per-asset bounds exact, and the parameter-update path re-solving to 0.25000000 on a second `efficient_risk` call with the validator still firing on it - that path matters because PR-18 inserted a conversion in front of a cached bound. PR-16 re-verified as a property at tightened bounds, refusing below a floor of 0.16679330 and solving at it. PR-19 re-verified both ways: live without `max_sharpe`, overridden with exactly one warning after it. The three tail-risk optimizers were checked against independent recomputations of their own measures from the solved weights - semideviation 0.08497296 against 0.08497296, CVaR 0.01704950 against 0.01702125, CDaR 0.05643312 against 0.05596864 - each minimal against 200 random simplex points, with benchmark, frequency, beta and both target families exercised at two or more values and every out-of-range beta rejected. PR-18's domain holds identically on all four optimizers and PR-17's conversion still holds.

All ten settled classes were re-run rather than trusted. No eval, exec, pickle, subprocess or network call in `pypfopt/`; no private third-party attribute access; caller mutation still the single known-safe site at `expected_returns.py:319`; the two divide-by-own-sum sites still dividing strictly positive quantities; no `pinv` bound anywhere; no unexplained skip in `tests/`; seven `_validate_` definitions, each appearing once, now including `_validate_target_risk`; both cvxpy solves sitting immediately inside a converting `try`, confirmed by reading the block rather than inferring it; one writer and one reader of `_risk_free_rate`; and `CVXPY_ERRORS` still equal to the set cvxpy declares.

Staleness was computed from git rather than assumed. Only the four `efficient_frontier` files have changed since 6d4cb54, and the diff hunks in `efficient_frontier.py` fall at the new validator, `efficient_risk` and the `portfolio_performance` docstring, missing `min_volatility`, `max_sharpe` and `max_quadratic_utility` entirely, so the EfficientFrontier core row remains validly swept at its recorded commit; its `max_sharpe` was re-exercised here anyway by the PR-19 property.

I ran the suite once under `-W error::RuntimeWarning`, which the Lessons recommend, and it produced three failures and no findings. `test_returns_warning` is the already-Declined numpy infinite-return warning. `test_cdar_example_weekly` passes in isolation and only fails in suite order, which is the warning registry rather than the code. `test_exception_immutability` fails because the library emits its own deliberate "Market neutrality requires shorting - bounds have been amended", a warning `test_efficient_risk_market_neutral_warning` exists to assert; turning intentional warnings into errors is what that flag does, and it is not a defect. I also walked into the verbose-helper trap a second time despite having written the Lesson in iteration 5, and got a page of solver output for a one-line answer.

Scores, claiming all 26 rows, all of them swept: correctness None, error handling None, testing None, documentation None, architecture None, code quality None, security None, performance None, dependency hygiene None, developer experience None, observability None. UX and accessibility do not apply to a library with no user-facing surface. Zero High, zero Medium and zero Low in-envelope findings, so the backlog stays empty.

CLOSEOUT HAS BEGUN. This audit scored zero High and zero Medium in-envelope, which arms the closeout rule: no further audit and no replenishment for the rest of the run, which finishes by converging. All 26 inventory rows are swept, Now, Next and Later are empty, nothing is blocked or deferred, and no Proposed item is outstanding.

Verify command GREEN: 337 passed, 11 skipped, 0 failed, exit 0. Ruff check and ruff format clean.

Learnings: A diagnostic flag that promotes warnings to errors will flag a library's intentional warnings first, so read what each failure is warning about before treating any of them as a finding - two of the three here were the code working as designed and the third was test ordering. And a Lesson written down is not a Lesson learned: I hit the verbose test-helper trap again one iteration after recording it, which argues for building probe objects directly as a habit rather than as a rule to remember.

Next: convergence - the evaluator gate, then the Converged line.

## iter 8/10 | 7037a729-002604 | 2026-07-29 | AUDIT | audit

Task: Convergence attempt - the evaluator gate. It returned REJECT, so the run does not converge; its one substantiated reason is filed as PR-21 and the run continues.

Changed: BACKLOG.md (PR-21 filed). No source file changed; one BACKLOG item changed state, so the stall condition is not met.

Checkpoint: 6f63a126d09d584f136aedc27e80bb4c8ea98f76

Verification: Evaluator: REJECT. One fresh-context sub-agent reviewed `git diff 25d2c6a..HEAD`, re-ran the Verify command and all five closed tasks' acceptance checks, and reported them holding with real output - PR-16 with eleven sampled targets all refused before the solver and the named floor 0.15915084514118683 round-tripping, PR-17 converting at both boundaries with `SolverError` preserved as `__cause__`, PR-18's domain holding on all four optimizers, PR-19's general claim confirmed across four other classes, and PR-20's four tests executing. It also independently judged the CLARABEL pin honest by showing OSQP completes the same sweep at `max_iter=200000`, and showed the recalibrated CDaR tolerances still fail at four gamma values and two targets, which is more than I had established.

Then it found what I missed, and it is one root cause with three faces. `_min_volatility_value` and `_max_return_value` are cached per instance and keyed on nothing, but PR-16 made both bounds depend on `market_neutral` and on constraints added later. A first call that only reaches the guard populates the cache, and every later call on that object reuses a bound belonging to a different feasible set. I reproduced all three cases myself rather than accepting the report: `efficient_risk(0.05)` then the same call with `market_neutral=True` refuses at 0.15559153672696688 where a fresh object solves; `efficient_risk(0.10)` then `add_constraint(w[0] >= 0.5)` then `efficient_risk(0.17)` reaches the solver and raises OptimizationError where a fresh object gives the clear ValueError naming 0.2037460238718606 - the admit-then-fail behaviour PR-16 was written to eliminate, reintroduced one layer up.

The third case is a regression and I verified that separately by checking `pypfopt/` out at 25d2c6a and running the sequence: `efficient_return(99.0, market_neutral=True)` then `efficient_return(1.9)` solves at ret 1.9 there, with the cached ceiling 1.9577192449738545, and fails here with the market-neutral ceiling 1.8134954754484658. PR-16 threaded `market_neutral` into `_validate_target_return` without touching the cache in front of it, so a bound that used to be unconditionally computed under `sum(w) == 1` became conditional while its cache stayed unconditional.

The evaluator also listed five things it suspected and could not substantiate, and I am recording them rather than filing them: a negative solver value making the market-neutral floor NaN, which it could not produce across five solvers; `efficient_risk(0.0, market_neutral=True)` returning a degenerate all-but-zero portfolio, which is mathematically correct; `float()` raising OverflowError on 10**400 and `Decimal` being refused while `Fraction` is accepted, both Low polish; `ParameterError` being mapped onto OptimizationError, where `__cause__` preserves the detail; and the extra solve now paid by the first call of each guard.

Verify command GREEN this iteration: 337 passed, 11 skipped, 0 failed, exit 0. Ruff check and ruff format clean. The gate is the only failing condition: the iteration-7 audit is clean, all 26 inventory rows are swept, and the ledger held nothing until PR-21 was filed.

Learnings: A cache in front of a guard has to be keyed on everything the guard's answer depends on, and PR-16 changed exactly that without changing the cache. The general shape is that widening a function's inputs silently invalidates any memoisation upstream of it, and the place to look is not the function that changed but whatever remembers its old answer. Also worth recording: the evaluator earned its cost for the second run in a row, and both times the miss was in code the run itself had written rather than in the untouched project.

Next: PR-21 - key both cached bounds on the feasible set they were computed for.

## iter 9/10 | 7037a729-002604 | 2026-07-29 | PR-21 | done

Task: PR-21 (Medium) - both cached limits were keyed on nothing while PR-16 had made them depend on `market_neutral` and on constraints added later, so a call refused by a guard decided the limit for every later call on that object.

Changed: pypfopt/efficient_frontier/efficient_frontier.py (new `_discard_stale_bounds`, called at both guard sites, plus a `_bound_key` slot), tests/test_efficient_frontier.py (2 new tests), BACKLOG.md (PR-21 closed, class settled, ledger empty), PLAN.md (4 rows flipped to unswept, 2 Lessons added).

Checkpoint: 101f30ef38889cf757ee18bd795bac55756f414d

Verification: All three reported sequences now answer exactly as the same calls on a fresh object. After a refused `efficient_risk(0.05)`, the market-neutral call solves; after a refused `efficient_return(99.0, market_neutral=True)`, `efficient_return(1.9)` solves with the ceiling back at 1.9577192449738545; and after a refused call followed by `add_constraint(w[0] >= 0.5)`, the next call gives the clear ValueError naming 0.2037460238718606 instead of reaching the solver.

The first fix was wrong and the gate caught it, which is worth recording in full. I invalidated whenever the constraint count changed, and that turned `tests/test_base_optimizer.py::test_exception_immutability` red: it appends to `_constraints` directly after a solve and expects "The constraints were changed after the initial optimization", but my invalidation recomputed the limit first, solved a problem carrying both `sum(w) == 1` and twenty weights forced above 0.1, and reported an opaque solver failure in its place. That was a regression I introduced, not a stale test, so I narrowed the rule rather than reinterpreting the test: once `_opt` is not None the feasible set is frozen - `add_constraint` is blocked and the weight-sum rule is validated - so the caches are correct by construction and are returned untouched. Invalidation now applies only in the window where the feasible set can still change, which is before the first solve. The narrower rule is also faster than the original: a four-target sweep derives the limit once, where my first attempt derived it twice.

Acceptance, ten checks: the three sequences match a fresh object; four identical calls and a four-point sweep each solve the bound exactly once; changing `market_neutral` after solving still raises "A new instance must be created when changing market_neutral" from both `efficient_risk` and `efficient_return`; and ordinary targets, plus the parameter-update path, are unchanged. Against unfixed source the sequence test fails.

I tightened one of my own tests after writing it. `test_cached_bounds_are_still_reused_when_valid` first asserted at most two bound solves, which the broken first attempt also satisfied, so it could not have caught the thing it exists to catch. It now asserts exactly one.

Contract preserved: no public signature changed and no solved portfolio moved. The change only affects which cached limit a second call on the same object sees, and every difference it makes is a call that now matches what a fresh object already returned. All four docstrings and the two guards are unchanged in what they promise.

Verify command GREEN: 339 passed, 11 skipped, 0 failed, exit 0, up from 337 by the two new tests. Ruff check and ruff format clean.

Inventory: four rows flipped - the EfficientFrontier targets row and the three siblings, whose `efficient_return` calls the changed shared validator. The EfficientFrontier core row is not flipped: `__init__` gained one slot but `min_volatility`, `max_sharpe` and `max_quadratic_utility` are unchanged and none of them reads it, which is the same reasoning the iteration-7 audit recorded for that row. Twenty-two of twenty-six are swept.

Learnings: Invalidate a cache only across the window where the thing it depends on can still change. My first attempt was correct about what the limit depends on and wrong about when, and the cost was replacing a precise error with an opaque one - the same shape of harm as the defect I was fixing. Second, every face of this defect needed two calls on one object, which is why five sweeps and the whole existing suite missed it and an adversarial reader did not: single-call probes cannot see state that outlives a call.

Next: WRAPUP - final iteration. Re-sweep the four flipped rows, run the second and last evaluator invocation, and converge if it passes.

## iter 10/10 | 7037a729-002604 | 2026-07-29 | WRAPUP | blocked

Task: WRAPUP - final iteration. Re-swept the four flipped rows, ran the second and last evaluator invocation, which REJECTED. A second REJECT is a hard blocker, so the run ends here without converging.

Changed: BACKLOG.md (PR-22 and PR-23 filed, the PR-16 settled line corrected), PLAN.md (2 Lessons added). No source file changed; BACKLOG items changed state, so the stall condition is not met.

Checkpoint: 2050cf9db683ecb1df354aba7417a011f2bada42

Verification: Verify command GREEN: 339 passed, 11 skipped, 0 failed, exit 0. Ruff check and ruff format clean. The four rows PR-21 flipped were re-swept with the same 51-check battery and returned zero failures, and PR-21's own ten acceptance checks all held.

Evaluator: REJECT, the second of two permitted invocations. It confirmed every closed task's acceptance check with real output, attacked PR-21's rule directly, and found no constraint-count collision reachable through the public API, no numeric regression across a 44-case battery diffed against 25d2c6a, and no NaN floor across four solvers. Then it broke the rule where I had not looked: `self._opt is not None` protects the caches but not the computation underneath them. When a cache is still empty the code below still calls `_feasible_bound`, which solves a copy of an already-solved problem carrying two conflicting weight-sum constraints.

I reproduced it before accepting it, at HEAD and at 25d2c6a. `min_volatility()` then `efficient_risk(0.20, market_neutral=True)` gives `OptimizationError: Solver status: infeasible`; `max_sharpe()` then `efficient_risk(0.20)` the same; `max_sharpe()` then `efficient_return(0.30, market_neutral=True)` gives `ValueError: target_return must be lower than the largest achievable return of 2.7451052567329115e-11`, against a true ceiling of 0.3886658273309727. All three give the clear `InstantiationError: Adding constraints to an already solved problem` at 25d2c6a, so all three are regressions this run introduced. Filed as PR-22 at Medium.

The root cause is one I should have seen, because it is the same mistake twice in two iterations. In iteration 9 my first fix replaced a precise `InstantiationError` with an opaque solver failure and the verify gate caught it; I narrowed the rule to protect the caches after a solve and wrote in that entry that the narrower rule was correct. It was not: `_market_neutral` is set only by `_make_weight_sum_constraint`, so `min_volatility`, `max_sharpe` and `convex_objective` leave it None, the validation branch never fires for them, and the empty cache sends the computation down the same bad path. I used `_market_neutral` as a proxy for "has been solved" when `_opt` is the thing that means that.

The evaluator also substantiated two items below Medium. The cache key misses a `cp.Parameter` value changed inside a user constraint, the one public way to move the feasible set without changing the constraint count, reproduced and filed as PR-23 at Low. And it showed that this run's own Settled classes line for PR-16 overstated: the volatility floor round-trips, verified at 0.15915084514118683 solving at 0.1591508451449437, but the return ceiling does not - `efficient_return(99.0)` names 0.3886658273309727 and passing it back raises `Solver status: user_limit`. That is pre-existing and identical at 25d2c6a, a degeneracy PLAN's Lessons already record, so the code is not at fault but my ledger claim was. I corrected the line rather than filing a task about my own bookkeeping.

The four inventory rows PR-21 flipped stay unswept even though this iteration's re-sweep passed. Marking them swept would certify a surface in which an evaluator has just found a Medium that my own 51 checks did not see, and PR-22 will change that code anyway. Twenty-two of twenty-six are swept.

Hard blocker: the second evaluator REJECT. The rule allows two invocations per run and makes the second rejection terminal, so I am not fixing PR-22 in this final iteration - a fix landed now would carry no evaluator review at all, which is the outcome the two-invocation cap exists to prevent. The loop state file is deleted and the run closes with its report.

Learnings: I made the same class of mistake in two consecutive iterations and called it fixed in between. Both times the harm was identical - a precise error replaced by an opaque one - and both times the cause was reasoning about the guard while ignoring the code it guards. The narrower fix in iteration 9 was better than the first attempt and still wrong, and the journal entry that announced it read as confident. Where a fix is a rule about when something may run, enumerate every caller that reaches it rather than the ones the failing test happened to name: `test_exception_immutability` pins this contract only for the `efficient_risk` then `efficient_return` order, which is exactly why the suite stayed green through both attempts.

Next: none - final iteration, run ends blocked. The next run opens on PR-22 and PR-23.

## iter 1/10 | e811c066-022400 | 2026-07-29 | PR-22 | done

Task: PR-22 (Medium) - `_discard_stale_bounds` protected the two cached limits after a solve but not the derivation underneath them, so any guarded call arriving with an empty cache sent `_feasible_bound` off to solve a copy of an already-solved problem.

Changed: pypfopt/efficient_frontier/efficient_frontier.py (`_discard_stale_bounds` now returns whether this call may derive a limit, and both guards act on that answer instead of deriving unconditionally), tests/test_efficient_frontier.py (1 new test covering all twelve combinations), BACKLOG.md (PR-22 closed, the PR-21 settled line corrected), PLAN.md (2 Lessons added).

Checkpoint: a974409a8cc820acedda382427a3557df50e9c06

Verification: All twelve combinations of {`min_volatility`, `max_sharpe`, `convex_objective`} x {`efficient_risk`, `efficient_return`} x {market_neutral False, True} now raise `InstantiationError: Adding constraints to an already solved problem` and derive no bound, matching 25d2c6a exactly. I re-ran the baseline from `git archive 25d2c6a` rather than trusting the filed repro, and it returns InstantiationError on all twelve.

Before the fix all twelve failed, in two distinct ways rather than the one the ledger described. The six market-neutral sequences raised `OptimizationError: Solver status: infeasible` from inside `_feasible_bound`, the copy carrying `sum(w) == 1` from the solve that had run and `sum(w) == 0` from the rule the call asked for. Of the six non-neutral ones, four raised the right exception while still caching a limit derived from the wrong problem, and `max_sharpe()` then `efficient_risk(0.20)` reported `The minimum volatility is 0.6678460257742026` - a floor read off max_sharpe's transformed constraint set, about four times the true one, and reported to the caller as fact.

The new test asserts both halves, and against unfixed source it fails on the cache assertion rather than the exception: `assert np.float64(0.15559153672696688) is None`. That matters, because four of the twelve raise the correct exception even when broken, so a test that only checked the exception would have certified the defect.

Siblings: EfficientSemivariance, EfficientCVaR and EfficientCDaR all inherit the changed `_validate_target_return`. All six of their solve-then-`efficient_return` sequences raise InstantiationError and cache nothing. The market-neutral three now name the market_neutral conflict where 25d2c6a named the constraint one - same exception type, strictly more specific message, and it comes from PR-21's validation branch rather than from this change.

Contract preserved: no public signature changed and no solved portfolio moved. `_discard_stale_bounds` is private with exactly two call sites, both updated, and `_feasible_bound` has no caller in `pypfopt/` outside this file. Both behaviours the suite pins here are untouched - `test_cached_bounds_are_still_reused_when_valid` still derives exactly one bound across a four-target sweep, because a solved problem holding a populated cache still answers from it, and all five sequences in `test_exception_immutability` still raise their existing messages. The only calls this change affects are those reaching a guard with an empty cache on a solved problem, and every one of them was previously reaching the solver.

Verify command GREEN: 340 passed, 11 skipped, 0 failed, exit 0, up from 339 by the new test. Ruff check and ruff format clean.

Inventory: the four rows PR-21 flipped stay unswept. This iteration changed the code under them again, so iteration 10's re-sweep no longer certifies it. Twenty-two of twenty-six swept.

Learnings: The protection this defect removed was accidental, which is why three iterations of careful reasoning walked past it. At 25d2c6a the ceiling came from `self.deepcopy()._max_return()`, and `deepcopy()` shares `_opt`, so the copy inherited the solved problem and its own `add_constraint` refused the call. PR-16 set `a._opt = None` so the copy could be solved as a problem in its own right, which was necessary and correct, and in doing so deleted a guard nobody had written down. Second, the fix is structural rather than one more conditional: two call sites were each carrying their own version of one rule, and the rule was stated in a docstring that only one of them followed. `_discard_stale_bounds` now returns the verdict and both guards consume it, so there is exactly one place left that can be wrong about when a limit may be derived.

Next: PR-23 (Low) - the cache key misses a `cp.Parameter` value change inside a user constraint.

## iter 2/10 | e811c066-022400 | 2026-07-29 | PR-23 | done

Task: PR-23 (Low) - the bound cache key `(market_neutral, len(self._constraints))` missed a `cp.Parameter` value changed inside a user constraint, the one public way to move the feasible set without changing the count.

Changed: pypfopt/efficient_frontier/efficient_frontier.py (new `_feasible_set_key`, called from `_discard_stale_bounds` in place of the inline count-based key), tests/test_efficient_frontier.py (1 new test), BACKLOG.md (PR-23 closed, ledger empty, the settled class line rewritten as the three-strike close), PLAN.md (2 Lessons added).

Checkpoint: 6356cd5d0fcca5ffebd7553f952bbae31a4a3a05

Verification: Reproduced as filed before touching anything. A cap parameter at 0.05 refuses `efficient_risk(0.16)` with the floor 0.21209018103844537; `update_parameter_value("cap", 1.0)` then leaves that floor in place and the next call is refused with it, while a fresh object at cap=1.0 has a floor of 0.15915084514118683 and solves. After the fix the updated object derives 0.15915084514118683 itself and its weights match the fresh object's to 1e-6.

This was the third finding sharing one root cause, after PR-21 and PR-22, so the three-strike rule forbade patching one more ingredient into the key. I checked the obvious structural close first - delete the cache and derive fresh whenever `_opt` is None, which makes staleness impossible by construction - and measured it rather than reasoning about it. It costs 18 `_feasible_bound` solves against 1 on a 100-point `plot_efficient_frontier` sweep with a 0.10 weight cap, because `_plot_ef` reuses one object and every target below the floor is refused while `_opt` is still None. That is a real regression on the library's own plotting path, so the cache stays.

The close that survives is a key that is complete rather than wider. A cvxpy expression is immutable apart from the values of its `cp.Parameter` leaves, so before the first solve `self._constraints` moves in exactly two ways: the list gains or replaces entries, and a parameter inside an entry takes a new value. `_feasible_set_key` carries the constraint identities and the parameter values, which catch those two and there is no third. The weight bounds need no separate term because `_map_bounds_to_constraints` expresses them as two constraints, so any change to them changes the identities. Parameter values are compared as `np.asarray(value).tobytes()`, which cannot miss a change for a fixed shape and dtype and at worst invalidates spuriously, the safe direction. `Constraint.parameters()` is cvxpy's public enumeration, so this adds no private access.

The complete key still derives exactly once across that same 100-point sweep, so the correctness gain is free. Constraint identities are stable across calls, which those 17 refused calls sharing one derivation demonstrate directly.

The new test fails against the unfixed key with `ValueError: The minimum volatility is 0.21209018103844537` at the call that should now solve.

Contract preserved: no public signature changed and no solved portfolio moved. `_feasible_set_key` is new, private, and called from exactly one place; `_bound_key` is still written and compared in one place each. The change is confined to the `_opt is None` branch, so the post-solve behaviour that `test_exception_immutability` pins - a direct `_constraints` mutation after a solve still reporting "The constraints were changed after the initial optimization" rather than an opaque solver failure - cannot be reached by it. `test_cached_bounds_are_still_reused_when_valid` still derives exactly one bound across its four-target sweep.

Verify command GREEN: 341 passed, 11 skipped, 0 failed, exit 0, up from 340 by the new test. Ruff check and ruff format clean.

Inventory: unchanged at twenty-two of twenty-six swept. The four unswept rows cover the code this iteration changed again.

Learnings: The instinct on a third strike is to delete the mechanism, and here that instinct was wrong by a measured factor of eighteen; the rule is to measure the structural alternative on the project's own call paths before adopting it, because "simpler" and "cheaper" came apart. What replaced it is worth keeping as a shape: when a key has been too narrow twice, the fix is not a wider list of ingredients but an argument that the list is closed - here, that cvxpy expressions are immutable apart from parameter values, which turns "what else might I have forgotten" into a two-item enumeration that can be checked.

Next: the ledger is empty, so iteration 3 is a full fresh-evidence audit, which must sweep the four stale Surface inventory rows.

## iter 3/10 | e811c066-022400 | 2026-07-29 | AUDIT | audit

Task: Full fresh-evidence audit. The ledger was empty and four Surface inventory rows were stale, so the audit swept those four with known-answer and invariant checks rather than liveness probes, then rescored the dimensions.

Changed: PLAN.md (4 inventory rows swept, so 26 of 26 are now marked), BACKLOG.md (PR-24 filed High, PR-25 filed Low). No source file changed; BACKLOG items changed state, so the stall condition is not met.

Checkpoint: 2998bdea19c69c3c96bc69eb6a362df2b58956a1

Verification: 71 checks across the four rows, 1 failure, and that failure is the audit's High.

Row 1, EfficientFrontier targets and validation: 27 checks, 0 failures, against a two-asset closed form built independently in the probe. With mu = [0.10, 0.20] and sigma = [0.20, 0.30] uncorrelated, `efficient_return(0.16)` must put 0.6 on the second asset and does, to 1e-7, with the volatility matching sqrt(0.0388); `efficient_risk(0.25)` must sit at the root of 0.13t^2 - 0.08t - 0.0225 = 0 and does, to 1e-6. Both targets were exercised at two values with monotone frontiers over five and four points, market_neutral at both values, weight bounds shown binding at 0.10 and moving the answer, the negative and above-ceiling and below-floor rejections, the named floor round-tripping as an accepted target, a negative target_return accepted, risk_free_rate moving the Sharpe ratio with the identity exact to 1e-12, and verbose in both directions.

Rows 2 to 4, the three siblings: 44 checks, 1 failure. The semivariance metric was checked against a hand-computed answer through `set_weights` - returns [0.1, -0.2, 0.3, -0.1] at benchmark 0 give sqrt(0.0125) exactly - with frequency shown to scale it by sqrt(4) exactly and benchmark 0.05 matching its own hand-computed value while raising the measure. CVaR and CDaR were checked against independent empirical implementations that do not go through cvxpy, evaluating the CVaR objective at every observed loss and taking the minimum, which is exact for the empirical problem. `min_semivariance` and `min_cvar` beat 200 random simplex portfolios and `min_cdar` beat 100; beta was rejected at 1.0, -0.1 and 1.5 and warned below 0.2, and moved both the weights and the measure between 0.90 and 0.99.

The failure is PR-24, filed High. `EfficientCVaR.portfolio_performance` and `EfficientCDaR.portfolio_performance` read `cvar.value` and `cdar.value` off the solver's auxiliary variables rather than recomputing from the weights. In `efficient_risk` the objective is portfolio return, so those variables appear only in the constraint `risk <= target` and every feasible value of them is optimal; wherever the target is slack the reported number is essentially the target. Swept across eight CVaR targets and seven CDaR targets: exact wherever the constraint binds, and overstating by 1.33, 15.40, 28.63 and 50.67 pct at CVaR targets 0.030 through 0.050, and by 9.59 and 36.44 pct at CDaR targets 0.16 and 0.20. The optimization itself is sound - the independently computed risk never exceeds the target at any point I probed - so this is purely a reporting defect, and `min_cvar`, `min_cdar` and both `efficient_return` methods are exact because there the risk measure is the objective.

Two things made this survive five earlier sweeps. The CVaR and CDaR inventory rows did not list `efficient_risk` in their scope at all, so no sweep was ever obliged to probe it, and both rows now do. And every existing test uses a binding target, where the reported value and the true one coincide: `test_efficient_risk` at 0.02 and `test_efficient_risk_low_risk` at min_cvar plus 0.01 are both in the region where the constraint is tight, so the suite is green over a 50 pct error.

PR-25, filed Low: all three siblings answer a below-floor risk target with an opaque `Solver status: infeasible` where `EfficientFrontier.efficient_risk` names the floor. The exception type is pinned by an existing test, so the fix adds the floor to the message rather than changing the type.

Scores, claiming only the four rows swept with fresh evidence this iteration; the other twenty-two carry sweeps from earlier commits and this run has changed only `pypfopt/efficient_frontier/efficient_frontier.py`, which none of them cover:
- correctness: High - PR-24, a documented public method returning a number up to 50.7 pct wrong without complaint.
- error handling: Low - PR-25.
- testing: no separate finding; the gap that hid PR-24 is that nothing in the suite compares a reported risk against an independent computation, and PR-24's acceptance check closes exactly that.
- architecture and code quality: None beyond PR-24's root cause, which is two classes reading solver state where their sibling recomputes from weights.
- documentation: None beyond PR-24; the two docstrings promise the portfolio's CVaR and CDaR, which is what the fix restores rather than something to reword.
- performance: None.
- security: not applicable on these rows - the Operating envelope records no adversarial surface and no untrusted input reaches an optimizer constructor.
- observability: None.
- UX and accessibility: not applicable - the envelope records no network endpoint, CLI or config surface.
- dependency hygiene: not rescored, no inventory row covers it and no dependency changed this run.

Closeout does not begin: this audit found a High.

Verify command GREEN: 341 passed, 11 skipped, 0 failed, exit 0. Ruff check and ruff format clean.

Learnings: A row's scope line is load-bearing, not commentary. The CVaR and CDaR rows omitted `efficient_risk`, and five sweeps honoured that omission exactly, so the inventory certified a surface it had defined not to include the method with the defect. When a class's public methods are enumerated in a row, the enumeration has to come from the class, not from what a previous audit happened to probe. Second, the shape of this defect is worth remembering: a value reported from a solver's auxiliary variable is only trustworthy when that variable is part of the objective, because a constraint fixes a bound and not a value.

Next: PR-24 (High) - recompute the reported risk from the weights in both classes.

## iter 4/10 | e811c066-022400 | 2026-07-29 | PR-24 | done

Task: PR-24 (High) - `EfficientCVaR.portfolio_performance` and `EfficientCDaR.portfolio_performance` reported a risk read off the solver's auxiliary variables rather than the risk of the weights they returned, overstating it by up to 50.7 pct wherever the `efficient_risk` target was slack.

Changed: pypfopt/efficient_frontier/efficient_frontier.py (new module-level `_empirical_cvar`), pypfopt/efficient_frontier/efficient_cvar.py and efficient_cdar.py (both `portfolio_performance` methods compute from the weights), tests/test_efficient_cvar.py and tests/test_efficient_cdar.py (1 new test each, 2 pinned tuples corrected), BACKLOG.md (PR-24 closed, class settled), PLAN.md (2 rows flipped, 3 Lessons added).

Checkpoint: 9e15d70643111be74d01b13e30250973c2704972

Verification: Across eight CVaR targets from 0.020 to 0.050 and seven CDaR targets from 0.060 to 0.200, the reported risk now equals an independent empirical reference to 1e-16 at every point, where before it overstated by up to 50.67 pct and 36.44 pct. The corrected value plateaus at the portfolio's true risk once the target goes slack, which is the shape the defect hid: it used to keep climbing with the target it was never measuring. `min_cvar`, `min_cdar` and both `efficient_return` methods are unchanged, as expected, because there the risk measure is the objective.

The fix computes CVaR through one shared `_empirical_cvar` placed beside `_validate_beta`, which is where these two classes already take their common code. It is the exact optimum of the Rockafellar-Uryasev programme - the mean of the worst `1 - beta` fraction with the boundary observation weighted by the part of it that falls inside - so it agrees with the programme wherever the programme is actually minimising. CDaR reuses it on the drawdown series its own constraints define, derived as the running peak of the uncompounded cumulative return minus its current level, which is the closed form of `u[i] = max(0, u[i-1] - r[i-1])` and needs no Python loop.

This was a class rather than an instance, so I enumerated it. `grep -rn "\.value\b" pypfopt/ --include=*.py` reports twelve sites, and every one is now in the safe class: a solved value may be read where the solve pinned it - the decision variable, an affine function of it such as `discrete_allocation`'s remaining funds, or the problem's own optimal objective value at the two `_opt.value` sites where the objective is exactly the quantity reported - and not where the variable only appears in a constraint. The two offenders no longer appear in that grep at all.

Two tests went red, both `test_efficient_risk_L2_reg`, and both were green only because they pinned the defect. The differential evidence is that one solve produces all three numbers. For CVaR the old auxiliary read gave 0.02939347475637203, matching the pinned 0.029393474756427136; the new value is 0.029122293560090193 and the independent reference is 0.029122293560090193 exactly. For CDaR the old gave 0.17881425269321666 inside the pinned band around 0.179365, the new gives 0.15567981354448202 and the reference 0.155679813544482. Decisively, the return element of both tuples is unchanged - 0.28899615771351145 against a pinned 0.2889961577134966, and 0.28899971711956696 against 0.289000 - so the weights did not move and the optimization was never what changed. Each test's discriminating assertion, the equal-weight comparison at the end, still holds.

Correcting the CDaR tuple also let its tolerance tighten by two orders of magnitude. Its comment recorded a 1.1e-3 cross-solver band, which was a property of the constraint-tracking value rather than of the solvers: measured again, the true CDaR of the weights is 0.155679814 under OSQP, 0.155681008 under SCS and 0.155678412 under CLARABEL, a band of 2.6e-6, so atol went from 2e-3 to 1e-5. I rewrote both comments with those measured numbers rather than leaving the obsolete ones.

PR-24's acceptance said the two test files should pass unchanged. That clause did not survive contact with the evidence and I am not pretending otherwise: two tuples had to be corrected, under the verify gate's exception for a test that was green only because of the defect being fixed, with the differential evidence above recorded here as that exception requires. Everything else in both files passes untouched.

Contract preserved: no public signature changed and no solved portfolio moved anywhere in the suite. Both docstrings already promised the portfolio's CVaR and CDaR, so the change makes the code match its documentation rather than requiring a documentation change. The new tests assert both halves - the reported risk equals the independent reference, and the true risk never exceeds the target - so they also pin the finding that the optimization was correct all along.

Verify command GREEN: 343 passed, 11 skipped, 0 failed, exit 0, up from 341 by the two new tests. Ruff check and ruff format clean.

Inventory: the EfficientCVaR and EfficientCDaR rows flip back to unswept, since this iteration changed the code under them. The two EfficientFrontier rows stay swept: `efficient_frontier.py` gained a module-level function but no method either row covers was touched, which is the same reasoning iteration 9 recorded for the `__init__` slot. Twenty-four of twenty-six swept.

Learnings: The tolerance was the tell, and I nearly missed it. A comment justifying atol=2e-3 by a 1.1e-3 spread across three solvers reads like a fact about numerical conditioning, and it was really a fact about a number that tracked whatever bound the caller happened to impose; the moment the value became the portfolio's own risk the spread fell to 2.6e-6. A wide tolerance earned by measurement is still worth re-measuring after a correctness fix. Second, the rule that made this tractable is narrow and checkable: read a solved cvxpy value only where the solve pinned it, which is the decision variable, an affine function of it, or the optimal objective value, and never a variable that only appears in a constraint.

Next: PR-25 (Low) - name the achievable floor in the three siblings' below-floor OptimizationError.

## iter 5/10 | e811c066-022400 | 2026-07-29 | PR-25 | done

Task: PR-25 (Low) - `EfficientSemivariance`, `EfficientCVaR` and `EfficientCDaR` answered a risk target below anything they could reach with a bare `Solver status: infeasible`, where `EfficientFrontier` names the floor it refused against.

Changed: pypfopt/efficient_frontier/efficient_frontier.py (new `_reachable_risk_floor` and `_solve_naming_the_risk_floor`, one `_floor_probe` slot), efficient_semivariance.py, efficient_cvar.py and efficient_cdar.py (each `efficient_risk` snapshots the probe and returns through the new helper), the three matching test files (1 new test each), BACKLOG.md (PR-25 closed, ledger empty), PLAN.md (1 row flipped, 2 Lessons added).

Checkpoint: 81996456138bca4e755d644cc3f004951dc17c94

Verification: All three now name their own floor exactly. `EfficientSemivariance.efficient_risk(0.05)` reports a minimum semideviation of 0.08497296368473181 against the 0.084972963685 its own `min_semivariance` reaches, `EfficientCVaR.efficient_risk(0.010)` reports 0.017049502125558898 against 0.017049502126, and `EfficientCDaR.efficient_risk(0.03)` reports 0.05643312227143925 against 0.056433122271. Each named number round-trips, which PLAN's Lessons require of any limit printed in a message: passing it straight back solves, at realised risks of 0.0849729996311259, 0.017049510796428635 and 0.05643312361271792.

Two negative checks matter as much as the positive one. Reachable targets are untouched on all three classes, and an infeasibility that is not the risk floor keeps its own error: a CVaR problem carrying `w[0] >= 0.6` and `w[1] >= 0.6` still reports the plain solver status rather than being relabelled a floor problem, because the helper only rewrites the message when the target is genuinely below the computed floor.

The design constraint I set was that this run has already spent three iterations - PR-16, PR-21 and PR-22 - fixing defects born from copy-and-probe machinery on `EfficientFrontier`, so adding the same shape to three more classes had to be contained rather than merely careful. It is: the probe runs only inside the `except` of a call that has already failed, and `_reachable_risk_floor` returns None on any solver or instantiation failure, in which case the original error is re-raised untouched. The worst case of the new code is exactly today's behaviour. That containment is what made the trade worth taking on a Low; on the happy path nothing was added at all beyond one `deepcopy` per first call.

The floor is measured on `_floor_probe`, the optimizer as it stood before the target constraint went in, because by the time the failure surfaces `self._constraints` already carries the target and stripping it back out is the fragile approach. Additional objectives are cleared on the probe for the reason `_feasible_bound` already documents: they change which point is optimal, not which points are feasible, and a floor is a statement about feasibility.

One defect of my own, caught by the probe rather than by reasoning: `EfficientSemivariance.portfolio_performance` measures with numpy, so the first version put `np.float64(0.08497296368473181)` in the message. That is not a value a caller can paste back into a call, which is the whole point of naming it, so the floor is coerced with `float()`.

The three new tests fail against the unfixed source, each on the `pytest.raises(match="The minimum ... is")` that the bare solver status does not satisfy.

Contract preserved: no public signature changed, no solved portfolio moved, and the exception type is unchanged. That last point was deliberate and is what `tests/test_efficient_cvar.py::test_efficient_risk_low_risk` pins - it expects `OptimizationError` for a below-floor target - so the fix adds to the message rather than changing what callers catch. `EfficientFrontier` still raises `ValueError` for its own below-floor case; the two differ because the existing tested contracts differ, and unifying them would be a breaking change rather than a message improvement.

Verify command GREEN: 346 passed, 11 skipped, 0 failed, exit 0, up from 343 by the three new tests. Ruff check and ruff format clean.

Inventory: the EfficientSemivariance row flips back to unswept alongside the two PR-24 already flipped. The EfficientFrontier rows stay swept: `efficient_frontier.py` gained two methods and an `__init__` slot, and no method either row covers was touched. Twenty-three of twenty-six swept.

Learnings: New machinery is worth its risk when its failure mode is the status quo. The rule that made a Low finding worth three files of change is that the probe sits inside an `except` and degrades to the original error, so it can add information but cannot subtract any. Reaching for that shape first would have made the decision quick rather than long. Second, coerce a numpy scalar with `float()` before it reaches a user-facing message: `{!r}` renders it as `np.float64(...)`, which fails the round-trip rule this project already had, and only running the probe showed it.

Next: re-sweep the three flipped inventory rows, which is what convergence still needs.

## iter 5/10 | e811c066-022400 | 2026-07-29 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines at 526, so all but the last 10 entries moved to the end of JOURNAL-archive.md.

Changed: JOURNAL.md (11 entries removed, 10 kept, 526 lines down to 281), JOURNAL-archive.md (11 entries appended).

Checkpoint: 81996456138bca4e755d644cc3f004951dc17c94

Verification: The archive held 16 entries before and holds 27 after, so it only accumulated. JOURNAL.md keeps its header and the last 10 entries, the earliest being iteration 6 of the previous run. Nothing was rewritten and nothing was dropped: 16 plus 11 is 27, and 21 minus 11 is 10.

Learnings: none - routine rotation.

Next: the iteration 5 primary entry above records the work; PR-25 is closed and the ledger is empty.
## iter 6/10 | e811c066-022400 | 2026-07-29 | AUDIT | audit

Task: Full fresh-evidence audit. The ledger was empty and the three sibling rows were stale, so the audit swept them - including the code PR-24 and PR-25 had just added - and rescored the dimensions.

Changed: PLAN.md (3 inventory rows swept, so 26 of 26 are marked). No source file changed and no BACKLOG item changed state, because the audit filed nothing; the ledger was already empty and stays empty. Stall check: this iteration changed only PLAN.md and JOURNAL.md and no BACKLOG item changed state, so the stall condition is met on the letter of the rule. The previous primary entry does not say the same - iteration 5 closed PR-25 and changed six source and test files - so this is not a hard blocker, and the iteration is not idle: it executed 85 checks whose result is the convergence precondition the run has been working toward.

Checkpoint: 212362e2dea62e712028362159e441f4771e5876

Verification: 85 checks across the three rows, 0 failures.

The 44-check sibling battery from iteration 3 was re-run against the current code and returned clean, so nothing PR-24 or PR-25 changed disturbed the semivariance known-answers, the optimality invariants against random portfolios, the beta validation, or the target-parameter behaviour.

A further 34 checks cover the new code specifically. `_empirical_cvar` was checked against hand-computed answers rather than against itself: [1,2,3,4,5] at beta=0.6 gives 4.5, the mean of the worst two; at beta=0.5 it gives 4.2, which is the fractional-tail case (5 + 4 + 0.5*3)/2.5 and the one an implementation using a plain quantile would get wrong; at beta=0 it gives the sample mean, the boundary `_validate_beta` admits. It equals an independent LP optimum to 1e-9 over 200 random samples at random betas, is exact for a single observation, a constant sample, negative losses, a tail of exactly one and an exactly-integer tail size, and is monotone in beta. The vectorised drawdown derivation equals the recursion it replaces to 1e-12 over 50 random series. Reported risk equals the independent reference at beta 0.80, 0.90, 0.95 and 0.99 for both classes.

The floor probe was checked on both weight-sum rules and both call paths, and correcting my own probe is the part worth recording. It first reported six failures under `market_neutral=True`, and the code was right and the probe was wrong, twice over: it built market-neutral reference objects but called `efficient_risk` without passing `market_neutral`, and it assumed the market-neutral call would fail. It does not fail, because under market neutrality the all-zero portfolio is feasible, so the risk floor is exactly zero - verified directly, `min_cvar(market_neutral=True)` returns weights with max absolute value 6.175e-10 and a risk of 2.8e-11 - and `_validate_target_risk` refuses negative targets, so no admissible target can fall below it. The guard is unreachable under plain market neutrality. Rewritten to force a nonzero exposure with `w[0] >= 0.5`, which gives a genuine market-neutral floor, all three classes name that floor to 1e-6, and it differs from the long-only floor on the same object, which is what shows the probe honours the weight-sum rule rather than assuming the long-only one. Both the first-call and the parameter-update paths name the floor.

Inventory staleness was settled mechanically rather than by reading. An AST comparison of the `EfficientFrontier` class between the iteration-3 sweep at 2998bde and HEAD reports two methods added, `_reachable_risk_floor` and `_solve_naming_the_risk_floor`, none removed, and exactly one changed: `__init__`, which gained the `_floor_probe` slot. No method either EfficientFrontier row covers changed, and `grep -rn "_floor_probe" pypfopt/` shows the slot is read only inside `_reachable_risk_floor` and written only by the three siblings' `efficient_risk`, so neither row's surface can reach it. Both rows stay swept on that evidence.

Scores, claiming the three rows swept with fresh evidence this iteration; the other twenty-three carry sweeps from earlier commits, and the only source files this run has touched are the four in `pypfopt/efficient_frontier/`, whose EfficientFrontier rows were shown unaffected above:
- correctness: None. PR-24's defect is closed and re-verified at four beta values; `_empirical_cvar` is exact against an independent reference.
- error handling: None. PR-25's floor naming holds on both weight-sum rules and both call paths, degrades to the original error when the probe cannot solve, and does not relabel an infeasibility that is not the floor.
- testing: None. The suite now contains the two checks whose absence hid PR-24 and PR-25 - a reported risk compared against an independent computation, and a below-floor target asserted to name its floor.
- architecture and code quality: None. The reporting convention is uniform across all four optimizers, and the enumerating check for the settled `.value` class still reports twelve safe sites.
- documentation: None. Both tail-risk docstrings promise the portfolio's own risk, which is now what they return.
- performance: None. The floor probe runs only inside an `except`; nothing was added to a path that succeeds beyond one `deepcopy` per first `efficient_risk` call.
- security: not applicable on these rows - the Operating envelope records no adversarial surface reaching an optimizer constructor.
- observability: None.
- UX and accessibility: not applicable - the envelope records no network endpoint, CLI or config surface.
- dependency hygiene: not rescored; no inventory row covers it and no dependency changed this run.

Zero High and zero Medium in-envelope, so closeout begins. The run stops auditing for the rest of its budget: no replenishment and no further full audit, whatever iterations remain. The ledger is empty, all 26 inventory rows are swept, and the remaining condition for convergence is the independent evaluator.

Verify command GREEN: 346 passed, 11 skipped, 0 failed, exit 0. Ruff check and ruff format clean.

Learnings: When a sweep reports a failure, the probe is a suspect alongside the code, and here it was the guilty party twice in one construction. What settled it quickly was asking what the answer should be rather than which side was wrong: a market-neutral portfolio can hold nothing, so its risk floor is zero, so a guard against targets below the floor has nothing to guard. Recording that reasoning is worth more than the corrected check, because the next audit will otherwise re-derive the same surprise. Second, staleness is a mechanical question and deserves a mechanical answer: an AST diff of one class between two commits settled in seconds what reading a diff had left ambiguous, and it is repeatable by the next person who has to justify leaving a row swept.

Next: convergence - the evaluator gate, then the Converged line, with no further auditing under closeout.
## iter 7/10 | e811c066-022400 | 2026-07-29 | AUDIT | audit

Task: Convergence attempt. Every other condition held - ledger empty, 26 of 26 rows swept, closeout in force, Verify green - so this iteration ran the evaluator gate. It returned REJECT. Four findings, one Medium and three Low, are filed as PR-26 through PR-29 and the run continues.

Changed: BACKLOG.md (PR-26 filed Medium, PR-27 to PR-29 filed Low). No source file changed; BACKLOG items changed state, so the stall condition is not met.

Checkpoint: b9f880a0dd1041b813965dbd8f52984f55fdb4ed

Verification: The evaluator confirmed all four acceptance checks from this run with real output, and went further than I had on three of them. PR-22 holds on all twelve combinations with a monkeypatched spy showing zero `_feasible_bound` calls, and it extended the check to the three siblings. PR-23 holds with a floor difference of exactly 0.0 against a fresh object, and it additionally tried `add_sector_constraints` and a deepcopy-then-diverge sequence, which invalidate correctly. PR-24 holds to 0.0 at seven CVaR targets and 1.1e-16 at six CDaR targets against its own `scipy.optimize.linprog` solution of the Rockafellar-Uryasev programme, and it checked `_empirical_cvar` over T from 1 to 253 crossed with twelve beta values including 1-1e-13. PR-25 holds with the floor honouring weight bounds, added constraints and the market-neutral rule. Verify green at 346 passed, 11 skipped, exit 0. It also confirmed no test was removed and no assertion weakened.

Its Medium is substantiated but its diagnosis was wrong, and both halves of that matter. It reported that the numbers in the two comments PR-24 added are "fabricated" because neither reproduces. I checked before accepting it, by extracting `pypfopt` at 824879b and running both datasets side by side. Mine reproduce exactly: on returns built as `returns_from_prices(prices).dropna()`, CVaR at target 0.05 reports 0.0445554997 against an actual 0.0295719614, 50.67 pct, and CDaR at 0.20 reports 0.1989386199 against 0.1458032290, 36.44 pct - the figures I recorded, to every digit. The evaluator's reproduce exactly too, on `get_data().dropna(axis=0, how="any")` then `returns_from_prices`, which is what the test helpers use: 0.0476136750 against 0.0384513115, 23.83 pct, and 0.2000000001 against 0.1999999999, 0.00 pct. Both datasets carry 895 rows, which is why this was invisible; the values differ because `pct_change` spans the dropped gaps differently.

So nothing was fabricated, and the finding is real anyway. A comment inside `tests/test_efficient_cdar.py` cites numbers that the helper used two lines below does not produce, and at that target on that fixture the defect does not manifest at all - a maintainer re-deriving it from where it is written would conclude there was never a defect. That is misleading documentation of the evidence for a High, and PLAN's Publication rule is explicit that a stated output must be the real output of the run as published. Filed as PR-26 at Medium. I am not downgrading it because the numbers turned out to be honest; the rule is about reproducibility where the claim sits, and it fails that.

The evaluator also showed the defect is worse than I filed it, which is worth recording: at CVaR target 0.08 the old code reported 0.0672761461 for weights whose CVaR is 0.0384513115, 74.97 pct, and at CDaR 0.30 it reported 0.2986593793 against 0.2108883384, 41.62 pct. The High was under-stated, not over-stated.

The three Low findings I reproduced myself rather than taking them on report, and one of them did not reproduce as described until I fixed my own construction. PR-27: `_reachable_risk_floor` omits the `warnings.catch_warnings` guard that `_feasible_bound` carries with a comment stating the rule. My first attempt emitted one warning, because contradictory constraints under amended bounds are satisfiable and the call simply solved, so the probe never ran; with default bounds, a forced `w[0] >= 0.5` and a target below the market-neutral floor it emits the warning twice. PR-28: all three sibling `efficient_risk` docstrings list only `ValueError` under Raises while PR-25 made them raise `OptimizationError` carrying the floor, which is a Change-discipline miss in that iteration - the rule says documentation is updated in the same iteration as the behaviour. PR-29: with an additional objective the named floor is a feasibility floor the default solver cannot serve at, reproduced under OSQP where CLARABEL and SCS solve it, and floor plus 1e-3 fails identically, so it is the near-floor degeneracy PLAN already records rather than a new fault.

Evaluator: REJECT, the first of two permitted invocations. One remains, so the second must be the converging one.

Learnings: Two probes can disagree while both are honest, and the tell here was that they agreed on the row count. Same 895 rows, different values, because one dropped price rows before differencing and the other differenced first and dropped the resulting gaps. The operational rule is that a number quoted in a comment or a report has to be produced by the fixture that sits beside it, not merely by some correct run somewhere - which is what the Publication rule already says and what I applied to the code while exempting my own commentary. Second, an adversarial reviewer being wrong about the cause does not make it wrong about the defect, and checking before accepting cost one script and turned a vague charge into a precise, fixable task.

Next: PR-26, then the three Low findings, then the second and final evaluator invocation.
## iter 8/10 | e811c066-022400 | 2026-07-29 | PR-26 | done

Task: PR-26 (Medium) - the evidence numbers in the two comments PR-24 added were measured on a different fixture from the one the tests they sit beside use. Chasing that down found the larger fault underneath it: the CDaR regression test's targets never reached the region where the defect exists, so it passed against the unfixed code.

Changed: tests/test_efficient_cdar.py (targets extended past the binding region, comment rewritten), tests/test_efficient_cvar.py (same), BACKLOG.md (PR-26 closed), PLAN.md (2 Lessons added).

Checkpoint: 0b6dac9c36498dabaf2db1d045d0788ce7f4d866

Verification: The substantive half first. On `setup_efficient_cdar`'s fixture the CDaR constraint does not go slack until past target 0.20, and the test swept 0.06 to 0.20 - entirely inside the binding region, where the reported value and the true one agree whether or not the defect is present. Checked out `efficient_cvar.py` and `efficient_cdar.py` at 824879b and ran both regression tests against them: `test_cvar_reported_risk_is_the_portfolios_own` failed, at target 0.04, difference 0.00139230098978773; `test_cdar_reported_risk_is_the_portfolios_own` passed. It certified nothing. That is exactly the failure PLAN's Method names, a check the broken implementation also satisfies, and I had not run it against the unfixed code in iteration 4 because the two tests that broke there absorbed the attention the new ones deserved.

Targets now span both regions on each file's own fixture: CVaR sweeps 0.02 to 0.08, binding through 0.03 and slack from 0.04; CDaR sweeps 0.06 to 0.40, binding through 0.20 and slack from 0.25. Against 824879b both tests now fail. Against HEAD both pass.

Then the numbers. Every figure left in either comment was reproduced by a script importing the same helpers the tests use, recovering the old reported value by evaluating the cvxpy expression the old code read after the identical solve. CVaR at target 0.08: old reported 0.0672761461, actual 0.0384513115, 74.96 pct, written as 75.0. CDaR at 0.30: 0.2986593793 against 0.2108883384, 41.62 pct, and at 0.40, 89.39 pct. The binding boundaries the comments assert are reproduced too: CVaR first goes slack at 0.04 and CDaR at 0.25.

The old figures were never wrong, only measured elsewhere, and the iteration 7 entry records that verification in full. JOURNAL.md is append-only, so the numbers in the iteration 4 entry stay as written and this entry is the correction: read against `setup_efficient_cvar` and `setup_efficient_cdar`, the overstatements are 74.96 pct at CVaR target 0.08 and 89.39 pct at CDaR 0.40, larger than the 50.67 and 36.44 recorded there.

Contract preserved: no source file changed this iteration, so no behaviour moved and no inventory row goes stale. Only two test target lists and two comments changed, and neither test's assertions were weakened - both still assert the reported risk equals an independent reference to 1e-6 and that the true risk never exceeds the target, now over a range that includes cases the old code got wrong.

Verify command GREEN: 346 passed, 11 skipped, 0 failed, exit 0. Ruff check and ruff format clean.

Learnings: A regression test proves nothing until it has been run against the code it was written to catch, and the temptation to skip that is strongest exactly where I skipped it - when the fix has already turned other tests red, the red feels like proof. It is not: those were pre-existing tests pinning the defect, and the new ones were still unexamined. The second rule is upstream of it: measure a finding on the fixture the test will use. Two constructions of the same data differed here while agreeing on row count, and every number and every target range I derived from the wrong one inherited the error silently.

Next: PR-27, PR-28 and PR-29, then the second and final evaluator invocation.
## iter 9/10 | e811c066-022400 | 2026-07-29 | PR-27 | done

Task: PR-27 (Low) - `_reachable_risk_floor` solved its probe without the `warnings.catch_warnings` guard `_feasible_bound` carries, so a market-neutral call on non-negative bounds emitted "Market neutrality requires shorting - bounds have been amended" twice.

Changed: pypfopt/efficient_frontier/efficient_frontier.py (`minimise(probe, ...)` wrapped in the same RuntimeWarning suppression `_feasible_bound` uses), tests/test_efficient_cvar.py (1 new test), BACKLOG.md (PR-27 closed), PLAN.md (3 rows flipped).

Checkpoint: 71c6d68a1b91a34bd44f05128bbc5ad38061da7b

Verification: All three siblings now emit the warning once where CVaR emitted it twice, and the floor each names is unchanged: EfficientSemivariance 0.04826098356892335, EfficientCVaR 0.009508612929597128 - the same value the finding recorded - and EfficientCDaR 0.05555522081363159. The new test fails against the unfixed source on the warning count and passes against the fix.

Contract preserved: only which warnings reach the caller changed, and only for warnings the caller has already been given by their own solve. The suppression is scoped to RuntimeWarning around the probe's solve alone, matching the rule `_feasible_bound` states, and the probe is a private computation on a copy, so nothing it has to say about that copy is the caller's business. No floor moved, no signature changed, and the suite is unchanged apart from the new test.

Verify command GREEN: 347 passed, 11 skipped, 0 failed, exit 0, up from 346 by the new test. Ruff check and ruff format clean.

Inventory: the three sibling rows flip back to unswept. Their `efficient_risk` reaches `_reachable_risk_floor`, which this iteration changed, so the iteration 6 sweep no longer certifies it. The two EfficientFrontier rows stay swept: `EfficientFrontier.efficient_risk` does not call `_solve_naming_the_risk_floor` at all, so nothing on their surface reaches the change. Twenty-three of twenty-six swept.

Learnings: none new - this was the rule `_feasible_bound` already documented, applied to the sibling that was written without reading it. The reusable point is already in PLAN's Lessons about enumerating every site of an idiom before settling a class, and this was a site added after that class was settled.

Next: the run is out of budget after the next iteration, so iteration 10 is a WRAPUP. PR-28 and PR-29 stay open, both Low, and three inventory rows need a re-sweep.
## iter 10/10 | e811c066-022400 | 2026-07-29 | WRAPUP | done

Task: Final iteration. Closed PR-28, which fits in the budget left, and wrote the handoff. The run ends out of budget rather than converged: PR-29 is open, three inventory rows need a re-sweep, and one evaluator invocation is unused.

Changed: pypfopt/efficient_frontier/efficient_semivariance.py, efficient_cvar.py and efficient_cdar.py (Raises sections document OptimizationError), BACKLOG.md (PR-28 closed). No test changed.

Checkpoint: 3180c9cc0af004e380bad3958321d08da063cd81

Verification: All three `efficient_risk` docstrings now document `exceptions.OptimizationError` alongside the ValueError, and say what its message names: the floor is the value the class's own `min_*` achieves under the same weight bounds, added constraints and weight-sum rule, and the advice is to use a target higher than the one named. That claim was checked rather than asserted - the named floor equals `min_semivariance()` at 0.08497296368473181, `min_cvar()` at 0.017049502125558898 and `min_cdar()` at 0.05643312227143925, each to the last digit. This pays a Change-discipline debt from PR-25, which altered the behaviour without updating the documentation in the same iteration.

Verify command GREEN: 347 passed, 11 skipped, 0 failed, exit 0. Ruff check and ruff format clean.

Inventory unchanged at twenty-three of twenty-six. The three sibling rows were already unswept from PR-27 and this iteration touched the same three files, so nothing moved.

Handoff. One task is open, PR-29, Low: the floor `_reachable_risk_floor` names is a feasibility floor computed with additional objectives cleared, so with an additional objective present the default solver may fail exactly at it - reproduced with `add_objective(L2_reg, gamma=1)` under OSQP, where CLARABEL and SCS solve it and floor plus 1e-3 fails identically. My reading, recorded so the next run can decide fast rather than re-derive it: this looks like a Decline. The floor is correct, the message already says "Please use a higher target" rather than promising the named value works, and the phenomenon is the near-boundary degeneracy PLAN's Lessons and the PR-16 settled line already record and accept for the return ceiling. I did not make that call here, because declining the last open item in the last iteration under budget pressure is exactly the shape of decision the Definition of done warns about, and nothing was gained by it - three unswept rows meant this run could not converge either way.

The three sibling rows - EfficientSemivariance, EfficientCVaR, EfficientCDaR - need a re-sweep, stale since PR-27 changed `_reachable_risk_floor` and PR-28 changed their docstrings. The sweep scripts that produced the 85 checks in iteration 6 are the shape to repeat: known-answer checks on `_empirical_cvar`, the drawdown derivation against its recursion, and the floor probe under both weight-sum rules and both call paths.

Convergence is close and the path is short. A fresh run should need roughly three iterations: settle PR-29, re-sweep the three rows in one audit, then the evaluator and the Converged line. The evaluator budget resets with the run, and the previous one earned its cost twice over.

Learnings: The budget arithmetic should have been done at iteration 7, not felt at iteration 9. The evaluator returning four findings at iteration 7 left three iterations for four tasks under a one-task-per-iteration rule, which was already arithmetically short of convergence, and knowing that earlier would have changed nothing about the work but everything about how it was framed. The rule to carry forward is that an evaluator REJECT late in a budget ends the run in practice, so the gate is worth running earlier when the ledger first empties, with iterations still in hand to answer it.

Next: none - final iteration, run ends out of budget. The next run opens on PR-29 and the three stale rows.
## iter 1/10 | 3c6e8691-040322 | 2026-07-29 | PR-29 | done

Task: PR-29 (Low, error handling) - the floor `_reachable_risk_floor` names is computed with additional objectives cleared, and the finding held that with an additional objective present the default solver may not solve at it, so the message points a caller into a target it cannot serve. Declined, on the acceptance check's second branch, but not for the reason the previous run's handoff predicted: the re-derivation found the finding had misattributed the failure.

Changed: BACKLOG.md (PR-29 deleted from Later, Declined line added), PLAN.md (1 Lesson added). No source file and no test changed.

Checkpoint: b94f3a0f9ac1d18fb6d5c358c6e5d5c4e1b52d0f

Verification: The finding reproduces exactly as filed. `EfficientCVaR` with `add_objective(L2_reg, gamma=1)` names 0.017049502125558898, and under the default solver that target fails, as do floor plus 1e-6, 1e-4 and 1e-3; floor plus 1e-2 solves. So the filed behaviour is real. Its stated cause is not.

The differential settles it. Without the additional objective the problem is an LP, cvxpy picks CLARABEL, and every target from the floor upward solves - at exactly the floor, to 0.017050. With the additional objective the problem is a QP, cvxpy picks OSQP, and the first four targets fail. The solver name was read off `_opt.solver_stats` on each run rather than inferred. Pinning the solver removes the effect entirely: with `L2_reg` attached and the target set to exactly the named floor, CLARABEL solves to 0.017049502 and SCS to 0.017066824. The floor is therefore a target that configuration can serve, and the message names no unreachable value. What the additional objective changes is the problem class, and through it cvxpy's default solver choice, not the feasible set and not the floor.

The siblings confirm the mechanism rather than the symptom. Each was run at its own floor with `L2_reg` attached: EfficientSemivariance, whose default stays CLARABEL, solves; EfficientCDaR, whose default becomes OSQP, fails, and solves under CLARABEL. The split tracks the selected solver in all three classes and nothing else.

The alternative fix was measured and is worse than the finding. Retaining the additional objective in the probe would name 0.02339147930360343, 1.37x the true minimum CVaR, and CLARABEL was then observed solving at 0.018, 0.020 and 0.023 - three targets the alternative floor would have reported as unreachable. A floor that overstates the minimum by 37 pct misleads every caller whose solver works, to spare one whose solver does not.

Decline rests on three precedents already in the state files, named in the Declined line: the Operating envelope classifies installed dependency behaviour, cvxpy solver backends explicitly, as machine-generated, so a backend's failure on a degenerate QP is out of envelope and Low at most; the PR-16 settled line already accepted the identical near-boundary case on the return ceiling as a bound the code cannot serve at its own edge rather than a bound computed over the wrong set; and the message's advice is actionable even under OSQP, floor plus 0.01 solving to 0.024104865. The message states two things and both are true: the minimum CVaR is that number, and a higher target works.

Verify command GREEN: 347 passed, 11 skipped, 0 failed, exit 0. Ruff check and ruff format clean.

Contract preserved: no source file changed, so no behaviour moved, no public signature or documentation changed, and no inventory row goes stale. The three sibling rows stay unswept from PR-27 and PR-28.

Stall check does not fire: the iteration changed only PLAN.md and BACKLOG.md, but a BACKLOG.md item changed state, PR-29 moving from Later to Declined.

Learnings: A finding can reproduce perfectly and still name the wrong cause, and the reproduction is what makes that hard to see - the failure was real, the floor was in the message, and the two were not related. Reading the solver cvxpy actually selected, rather than reasoning about the value the code computed, was the whole diagnosis. The reusable rule is in PLAN's Lessons. The second point is about handoffs: the previous run's WRAPUP predicted this Decline and gave near-floor degeneracy as the reason, which the evidence contradicts, since the floor round-trips exactly under CLARABEL with the objective attached. The verdict it predicted was right and the reason it gave was wrong, and inheriting the reason would have put a false statement into the Declined line that no later audit would have reopened.

Next: BACKLOG.md is now empty in Now, Next and Later, so iteration 2 audits. Its first duty is the three stale inventory rows - EfficientSemivariance, EfficientCVaR, EfficientCDaR - which are the only thing left between this project and convergence.
## iter 2/10 | 3c6e8691-040322 | 2026-07-29 | AUDIT | audit

Task: Full fresh-evidence audit. The ledger was empty after PR-29 was declined and the three sibling rows were stale, so the audit swept them and rescored the dimensions. It filed one Medium, so closeout does not begin.

Changed: BACKLOG.md (PR-30 filed under Next), PLAN.md (3 inventory rows swept, their scope lines widened to the classes' own public surface). No source file changed.

Checkpoint: 79b115328cdab9189e8b69c5b34e41f285eadc5a

Verification: 60 checks across the three rows, 0 failures, plus three audit probes on surface the rows' scope lines had omitted.

Staleness was settled mechanically first, per the Lesson. An AST comparison of the four classes between the sweep commit 212362e and HEAD reports nothing added and nothing removed, `EfficientFrontier._reachable_risk_floor` with its body changed, and the three siblings' `efficient_risk` changed in docstring only - the comparison strips the docstring and compares the remaining body, so that distinction is derived rather than asserted. That is exactly PR-27 and PR-28 and nothing else.

The sweep itself. Semivariance known-answers are exact: semideviation sqrt(0.0125) through `set_weights` on a hand-built frame, frequency scaling by sqrt(4), benchmark 0.05 giving sqrt(0.02125), and the Sortino identity at two risk-free rates. `_empirical_cvar` was checked against six hand-computed answers - including the fractional-tail case at beta=0.5 giving 4.2, which a plain-quantile implementation gets wrong, and the beta=0 boundary giving the sample mean - and against an independent Rockafellar-Uryasev optimum minimised over its own breakpoints, agreeing to 1.78e-15 across 200 random samples at random betas. Reported CVaR equals that independent reference at beta 0.80, 0.90, 0.95 and 0.99 to 1.73e-18, and reported CDaR to 6.25e-17; the vectorised drawdown derivation equals the recursion it replaced to 5.55e-16 over 50 random series and matches a hand-computed [0, 0.2, 0.15, 0.25]. All three minimisers are minimal against random simplex portfolios scored by the independent references, 200, 200 and 100 of them with no counterexample.

Every documented parameter was moved at two or more values with the direction asserted: frequency, benchmark, risk_free_rate, risk_aversion at 0.5 against 10 and rejected at the 0 boundary and negative, beta changing both weights and measure and rejected at 1.0, -0.1 and 1.5 while accepted at the 0.0 boundary with the low-beta warning below 0.2 and silence at 0.95, market_neutral summing to zero on all three classes, both targets on each class respected and monotone, and verbose printing on all three.

The changed code was probed directly. All three classes name their own floor on both the first-call and the parameter-update paths - semideviation 0.08497296368473181, CVaR 0.017049502125558898, CDaR 0.05643312227143925, each equal to its own `min_*` value - and PR-27's suppression holds, the market-neutrality amendment warning reaching the caller once rather than twice on every class.

Then the part that earned the iteration. PLAN's Lesson says an inventory row's scope line is load-bearing and a class's public methods must be enumerated from the class itself, so the audit read the class docstrings rather than the scope lines. `EfficientCVaR` and `EfficientCDaR` both list ``set_weights()`` under Public methods while overriding it with an unconditional NotImplementedError. Five audits swept these rows without seeing it, because the scope lines named five methods and `set_weights` was not among them. What settles it as an error rather than a convention is that the same two docstrings correctly omit `min_volatility`, `max_sharpe` and `max_quadratic_utility`, which also raise: the list names only available methods everywhere else. Filed as PR-30, Medium under the rubric's misleading-documentation clause. The acceptance check was written direction-agnostic - it fails whether the fix deletes the docstring line or the stub - and was run against the unfixed code, where it reports exactly those two offenders and exits 1. It does not flag `save_weights_to_file`, whose NotImplementedError is conditional on an unsupported extension; a first draft that scanned source text rather than parsing it did flag it, on all three classes, and the AST form replaced it.

Two further probes found nothing to file. The `set_weights` prohibition no longer protects anything, which is context for PR-30 rather than a separate finding: since PR-24 both classes compute `portfolio_performance` from `self.weights` alone, and weights assigned directly returned a CVaR of 0.024057956640642652 equal to the independent reference exactly. And `EfficientSemivariance.portfolio_performance` returns an infinite Sortino ratio with numpy's divide-by-zero warning when a portfolio has no downside at all; that is the mathematically correct answer for a zero denominator here rather than a defect, and it matches the numpy-RuntimeWarning item already under Declined.

Scores, claiming the three rows swept with fresh evidence this iteration; the other twenty-three carry sweeps from earlier commits and no source file has changed this run:
- documentation: Medium. PR-30, on the two class docstrings.
- correctness: None. 60 checks, 0 failures, every risk measure matched against an independent reference rather than against itself.
- error handling: None. Floor naming holds on both paths for all three classes, beta validation holds at both boundaries and both rejections, risk_aversion rejected at zero and negative.
- testing: None on these rows. The suite carries the reported-risk and below-floor checks whose absence hid PR-24 and PR-25.
- architecture and code quality: None.
- performance: None. Nothing was added to a path that succeeds.
- security: not applicable on these rows - the Operating envelope records no adversarial surface reaching an optimizer constructor.
- observability: None.
- UX and accessibility: not applicable - the envelope records no network endpoint, CLI or config surface.
- dependency hygiene: not rescored; no dependency changed this run.

One Medium in-envelope, so closeout does not begin and the run continues auditing discipline as normal. All 26 inventory rows are now swept.

Verify command GREEN: 347 passed, 11 skipped, 0 failed, exit 0. Ruff check and ruff format clean.

Learnings: The finding this audit exists to have caught was invisible to five previous ones for a structural reason, not a diligence one: the row's scope line listed five methods, and every sweep honoured that list exactly. Reading the class instead of the scope line took one call to `inspect.getdoc` and found a contradiction sitting in the file header. The scope lines are now widened so the next sweep cannot inherit the same blind spot. Second, an enumerating check must distinguish an unconditional stub from a conditional raise: the source-text version of this check reported `save_weights_to_file` on all three classes, and parsing the body with ast rather than grepping its text is what separated the two.

Next: PR-30 is the only open task. Execute it in iteration 3, then the evaluator gate and the Converged line.
## iter 3/10 | 3c6e8691-040322 | 2026-07-29 | PR-30 | done

Task: PR-30 (Medium, documentation) - `EfficientCVaR` and `EfficientCDaR` listed ``set_weights()`` under "Public methods" in their class docstrings while overriding the method with an unconditional NotImplementedError. Closed by correcting the documentation, which changes no behaviour, and by pinning the class with an enumerating test.

Changed: pypfopt/efficient_frontier/efficient_cvar.py and efficient_cdar.py (the `set_weights()` line removed from each class docstring), tests/test_base_optimizer.py (1 new test plus its imports), BACKLOG.md (PR-30 closed, 1 Proposed item filed), PLAN.md (1 Lesson added, 2 inventory rows re-verified at this commit).

Checkpoint: 7b2f8dc98a23a9a57ca50838b6e2ad4f4568ed89

Verification: The fix direction was decided by history rather than by preference, which is the part worth recording. Both readings were available - delete the docstring line, or delete the stub - and the audit's own evidence that the prohibition protects nothing pointed at deleting the stub. `git log -S "Method not available in EfficientCVaR"` settles it: the override arrived in upstream cb2bb3e, "added warnings for set_weights (#447)", in May 2022, after the docstring already listed the method. The prohibition is the maintainer's deliberate decision and the docstring line is the stale artifact, so the documentation is the side that was wrong.

The fix is class-complete rather than two edits. Enumerating every class `pypfopt.__all__` exports - nine of them - and every method their docstrings list, 61 in total, now reports zero offenders. Enumerating in the other direction is what shows the convention is real: the package contains eleven unconditional NotImplementedError stubs across four classes, and every one of them is now absent from its class's "Public methods" list. `CLA.set_weights` raises and is correctly undocumented, which is a fourth class independently following the rule that `EfficientCVaR` and `EfficientCDaR` broke.

The new test `test_documented_public_methods_are_available` was run against the unfixed code before being trusted, per the Lesson. Restoring both source files to HEAD, it fails naming exactly `EfficientCVaR.set_weights` and `EfficientCDaR.set_weights` and no others; restored, it passes. It parses each body with ast rather than scanning source text, because `save_weights_to_file` raises NotImplementedError for an unsupported extension and a text scan reports that as a stub - the draft written during the audit did exactly that on all three classes. It also asserts the enumeration found more than 50 documented methods, so a parser that silently stops matching fails the test rather than passing it vacuously.

Contract preserved: no executable line changed. `set_weights` still raises on both classes, every other method behaves as before, and no signature or accepted input moved. The only change to the shipped package is two lines of prose, and the sole caller-visible consequence is that a reader is no longer told about a method that would refuse them. The docs build reads these docstrings through autoclass, so the rendered API pages follow automatically.

Inventory: the EfficientCVaR and EfficientCDaR rows certify "the class docstring's own list of public methods", and this iteration edited exactly that docstring, so their sweep evidence needed re-establishing rather than assuming. The docstring enumeration was re-run at this commit and passes, and an AST comparison of both classes against the previous sweep at 79b1153 reports no method added, removed or changed in body - the difference is confined to the class docstring the enumeration itself checks. Both rows are updated to this commit on that evidence. All 26 rows stay swept.

Proposed: whether to re-enable `set_weights` on the two classes is filed for the user. PR-24 removed the technical reason for the prohibition, since both classes now compute their risk from `self.weights`, and the sibling `EfficientSemivariance` permits the same call - but reversing a maintainer's deliberate public-API decision is the owner's call, not an audit's, so it is a Proposed item and does not block convergence.

Verify command GREEN: 348 passed, 11 skipped, 0 failed, exit 0, up from 347 by the new test. Ruff check and ruff format clean.

Learnings: A docs-versus-code contradiction has two fixes and they are not interchangeable, so the question of which side is wrong needs evidence rather than taste. `git log -S` on the offending line answered it in one command, and the answer was the opposite of what the audit's technical evidence suggested: the prohibition is vestigial, and it is still deliberate. Recording both halves matters, because the technical finding is real and belongs to the user as a Proposed decision rather than being quietly acted on under cover of a documentation fix.

Next: the ledger is empty in Now, Next and Later, all 26 inventory rows are swept, and iteration 2's audit is the run's full fresh-evidence audit. Iteration 4 runs the evaluator gate and, on PASS, appends the Converged line.


---

# Journal

Append-only. One primary entry per iteration; SALVAGE and ROTATION entries are additional. Never rewrite past entries (filling the current entry's Checkpoint field is completion, not a rewrite).

Heading grammar, exactly:

## iter 4/10 | 3c6e8691-040322 | 2026-07-29 | AUDIT | audit

Task: Full fresh-evidence audit. The ledger emptied when PR-30 closed, and iteration 2's audit cannot support convergence because it scored a Medium, so the Closing rule's condition - a full fresh-evidence audit scoring zero High and zero Medium - still needed satisfying. This audit targets the two dimensions the Method's own scores have never actually claimed.

Changed: PLAN.md (2 Lessons added). No source file changed, no test changed, and BACKLOG.md is untouched because the audit filed nothing.

Checkpoint: 7ce3b40cd5c66896752e831bbcae9806cc819c8f

Verification: Both previous audits, iteration 6 of the last run and iteration 2 of this one, recorded dependency hygiene as "not rescored", and developer experience has never appeared in a scores line at all. Both are in the Goal's dimension list, so this audit went at them with fresh evidence rather than re-probing rows that were swept 60 checks ago.

Dependency hygiene, structural. An AST enumeration of every import in `pypfopt/` resolves each third-party module against `pyproject.toml`: cvxpy, numpy, pandas, scipy, skbase and sklearn are declared core and all are genuinely imported; matplotlib and plotly are declared under all_extras. No module is imported without being declared, and no core dependency is declared without being imported. The half that matters for a fresh install is where the extras are imported from: matplotlib appears at module level in zero files and lazily in one, plotly at module level in zero and lazily in two, so `import pypfopt` succeeds on a core-only install. That is not only inferred - CI's nosoftdeps job installs the dev extra without the soft dependencies and runs the whole suite on five Python versions.

Dependency hygiene, forward-looking. The suite was run under `-W error::DeprecationWarning -W error::FutureWarning`: 348 passed, 11 skipped, so no third-party API already slated for removal is exercised anywhere the tests reach. The known-vulnerability half of the dimension is recorded as unexamined rather than scored clean: neither pip-audit nor safety is installed, and installing one would alter the resolved dependency set the Operating envelope treats as the contract and that the Verify command runs against. That is a limit of this environment, stated rather than papered over.

Developer experience. The repository carries CONTRIBUTING.md, a Makefile, README, docs and a cookbook; pre-commit pins ruff lint and format, which is the gate CI runs first; the CI matrix covers Python 3.10 through 3.14 in both nosoftdeps and allsoftdeps configurations. README examples are executed by `tests/test_readme_examples.py` rather than merely written. The suite is 348 passed and 11 skipped in about 37 seconds, and every one of the 11 skips is a skipif naming an absent dependency - ten on ecos, one on make - so PR-20's settled class still holds and no test is disabled by an unexplained marker.

One cross-cutting probe, the one PLAN's Lessons recommend running occasionally. Under `-W error::RuntimeWarning` the suite reports two failures and neither is a defect. `test_returns_warning` is the numpy duplicate-signal warning already under Declined. `test_exception_immutability` calls `efficient_return(0.2, market_neutral=True)` on long-only bounds, which fires the library's own deliberate "Market neutrality requires shorting - bounds have been amended" warning on purpose. The probe's purpose is to expose a degenerate branch that produces NaN and still reaches the right answer, because every NaN comparison is False; no such branch surfaced.

A near-finding is worth recording because the evidence reversed it. The market-neutrality message uses RuntimeWarning, which read as a category misuse against the UserWarning used by `_validate_beta` and by `max_sharpe`. A census says otherwise: the library raises RuntimeWarning at 14 sites across expected_returns, risk_models, black_litterman, plotting and efficient_frontier, against UserWarning's 6, so RuntimeWarning is the house convention rather than the exception. It is also load-bearing - ten tests pin the category and the two suppression sites added by PR-16 and PR-27 target it by name - so changing it would silently defeat those suppressions. Nothing filed, and the rule is now in PLAN's Lessons.

The `lp_portfolio` solver default was checked against its docstring as well, since an earlier sweep noted in passing that the docstring still names ECOS_BB as the default. The docstring says it defaults to ECOS_BB if ecos is installed and to None otherwise, which is exactly what lines 320 to 321 do, with a deprecation warning naming the 1.7.0 change. Accurate, not a finding.

Scores. All 26 inventory rows are swept and none is stale, so these claim the whole mapped surface rather than a subset:
- dependency hygiene: None on the checks run - every import declared, extras never imported at module level, no deprecated third-party API exercised. The known-CVE question is unexamined for the reason above, not scored.
- developer experience: None. Contributor docs, a pre-commit gate matching CI, a five-version matrix in two dependency configurations, executed README examples, and no unexplained skip.
- correctness: None. 26 of 26 rows carry known-answer or independent-reference evidence; the 60 checks of iteration 2 stand on code that has not changed since apart from two docstring lines, verified by AST comparison in iteration 3.
- documentation: None. PR-30 closed the only finding; the enumeration now reports 9 classes and 61 documented methods with zero offenders, and `test_documented_public_methods_are_available` pins it.
- error handling: None. Floor naming holds on both call paths for all three tail-risk classes, beta validation holds at both boundaries and all three rejections.
- testing: None. 348 tests, every skip explained, and the run added a regression test proven to fail against the code it was written for.
- architecture and code quality: None.
- performance: None. Nothing was added to a path that succeeds.
- observability: None.
- security: not applicable - the Operating envelope records no adversarial surface; the library takes no network, CLI, environment or config input.
- UX and accessibility: not applicable - the envelope records no user-facing surface.

Zero High and zero Medium in-envelope, so closeout begins. The run stops auditing for the rest of its budget: no replenishment and no further full audit, whatever iterations remain. The ledger is empty in Now, Next and Later, all 26 rows are swept, and the only remaining condition for convergence is the independent evaluator.

Stall check: this iteration changed only PLAN.md and JOURNAL.md and no BACKLOG item changed state, so the stall condition is met on the letter of the rule. The previous primary entry does not say the same - iteration 3 changed two source files and a test and closed PR-30 - so this is not a hard blocker, and the iteration is not idle: it produced the clean audit that is the convergence precondition, and it scored two dimensions that five previous audits had left unclaimed.

Verify command GREEN: 348 passed, 11 skipped, 0 failed, exit 0. Ruff check and ruff format clean.

Learnings: A dimension recorded as not rescored twice is an unexamined dimension wearing a status word, and it survives exactly as long as nobody reads the scores line as a claim. Dependency hygiene had been carried that way through two audits; scoring it took one AST enumeration and one flag on the test command. The second lesson is that an environment limit belongs in the scores as a limit: pip-audit cannot be installed here without changing the contract the envelope names, so the CVE question is written as unexamined rather than folded into a None that would have read as cleanliness.

Next: iteration 5 runs the evaluator gate and, on PASS, appends the Converged line under closeout.
## iter 4/10 | 3c6e8691-040322 | 2026-07-29 | ROTATION | rotation

Task: JOURNAL.md reached 566 lines after this iteration's audit entry, past the 500-line threshold, so the oldest entries rotate into JOURNAL-archive.md. Done now rather than in iteration 5, so it cannot collide with the convergence entry.

Changed: JOURNAL.md (10 oldest entries moved out, 10 most recent kept), JOURNAL-archive.md (those 10 appended at the end).

Checkpoint: 21d75f35f71f819ce6cf13ab94f250f22e12309e

Verification: JOURNAL.md held 20 entries and now holds 10, falling from 566 lines to 290. JOURNAL-archive.md rose from 27 entries to 37 and from its previous length to 807 lines; the count rose by exactly the 10 moved, which is the invariant the Stop hook checks. The archive was opened in append mode and its existing content was read back afterwards to confirm it still starts with its own header, so nothing was overwritten. Entries were split on their own headings rather than by line count, so no entry was cut in half, and the preamble above the first entry stayed in JOURNAL.md.

One pre-existing artefact is worth naming rather than compounding. JOURNAL.md's preamble ends at "Heading grammar, exactly:" with no template line beneath it, because an earlier rotation split on that template - it is a line beginning with the entry-heading prefix - and carried it into the archive, where it now sits as the archive's fourth line. This rotation did not repeat that: the split point is the first real entry heading, and the surviving preamble was written back unchanged. Restoring the template line was left alone as outside this iteration's task.

Learnings: A rotation that splits on a heading prefix will also split on any example or template using that prefix, and the loss is silent because the preamble still looks reasonable afterwards. The archive's own copy of the grammar is the evidence of what happened. Anchor a rotation on the first heading that carries a real iteration number, not on the prefix alone.

Next: unchanged - iteration 5 runs the evaluator gate and, on PASS, appends the Converged line under closeout.
## iter 5/10 | 3c6e8691-040322 | 2026-07-29 | AUDIT | audit

Task: Evaluator gate. Every other convergence precondition held - iteration 4's audit scored zero High and zero Medium with all 26 rows swept, the ledger was empty, nothing but journal state had changed since that audit, and the Verify command was green - so this iteration spawned the single fresh-context adversarial reviewer the Definition of done requires. It returned REJECT with two substantiated reasons, both reproduced independently here, so the run does not converge.

Changed: BACKLOG.md (PR-31 filed under Now, High), PLAN.md (1 Lesson added). No source file changed.

Checkpoint: 80906d94075acc5213f505f1bdd0e312beec28be

Verification: The evaluator confirmed the run's own work. Verify green at 348 passed and 11 skipped, exit 0; ruff check and ruff format clean; PR-30's test passes at HEAD and, with both source files restored from 0ffcecb, fails naming exactly `EfficientCVaR.set_weights` and `EfficientCDaR.set_weights` and no others. It went further than this run did on two points and both held: it re-ran the enumeration over all 13 classes in the package rather than the 9 in `__all__`, including `BaseOptimizer`, `BaseConvexOptimizer` and the two exception types, and found zero offenders; and it checked both tail-risk `portfolio_performance` methods against from-scratch reimplementations, agreeing to between 8e-16 and 1.4e-11 across five beta values. PR-29's Decline was verified rather than accepted: at the named floor with `L2_reg` attached, CLARABEL solves to 0.017049502125769528 and SCS to 0.017066824489422313 while the default fails under OSQP, which is the reasoning the Declined line records.

Then it found what five audits had not. Every treatment of the reasons below was reproduced here before filing, because a sub-agent's claim is a hypothesis:

All four optimizer `__init__` docstrings document `expected_returns=None`. `EfficientFrontier(None, S).min_volatility()` honours it end to end and reports `(None, 0.15915084514118683, None)`. `EfficientSemivariance(None, rets)` and `EfficientCVaR(None, rets)` construct and solve on that path and then raise `ValueError: matmul: Input operand 1 does not have enough dimensions` from `portfolio_performance`. `EfficientCDaR(None, rets)` does not even construct: `TypeError: object of type 'NoneType' has no len()`, because `efficient_cdar.py:84` sizes its dummy covariance from `len(expected_returns)` where the CVaR sibling at `efficient_cvar.py:85` uses `returns.shape[1]`. Three tests pin the contract elsewhere - `test_min_volatility_no_rets`, `test_cvar_no_returns`, `test_es_no_returns` - and the last two stop at solving, never calling `portfolio_performance`, which is exactly why a green suite carried the reporting half.

Filed as one task rather than the evaluator's two, at the higher of the two severities. The Method says file the root cause and not each symptom, and the root cause is single: one documented contract honoured by one class of four. The acceptance check enumerates all four optimizers across construct, solve and report, so the class closes at once rather than in two halves with a window where it is half-fixed.

This is in envelope and it is not hostile-input hardening. `None` on a user-error surface is not a wrong argument here, it is the documented one, and the fix restores a promise the library already keeps in its flagship class. The finding sits in no Settled class and in nothing Declined; searching the state files and the archive for `no_returns`, `324` and `expected_returns=None` returns no match, so no previous audit examined it.

Why it was missed is the useful part, and it is the second occurrence of a Lesson already on the books. The sibling rows' scope lines name methods - `min_cvar`, `efficient_return`, `efficient_risk`, `portfolio_performance`, beta validation - and every sweep honoured that list. Iteration 2 widened them to the classes' own public methods after PR-30 showed the same blind spot, but the widening stopped at methods and never reached the constructor's documented parameter domain. The Surface inventory rule requires every documented parameter exercised at two or more values including the boundary side, and `expected_returns=None` is precisely that boundary; the sweep moved beta, market_neutral, frequency, benchmark, risk_free_rate, risk_aversion, verbose and both targets, and never once passed None. The Lesson is now written to name constructor parameter domains explicitly.

Inventory rows are left swept for now rather than flipped. The code has not changed, so the mechanical staleness rule does not fire; PR-31's fix will change all three sibling files and both `portfolio_performance` implementations, which flips the affected rows by that rule, and the re-sweep then runs against widened scope lines. Flipping them now would claim a code change that has not happened.

Evaluator: REJECT, 1 of at most 2 invocations used. Both reasons were substantiated and both are folded into PR-31.

Verify command GREEN: 348 passed, 11 skipped, 0 failed, exit 0, run in this iteration before the gate.

Learnings: The gate earned its cost on its first invocation of the run, and it earned it against a project that had just scored clean on every dimension - which is the case where an independent reviewer is worth most and feels least necessary. The reusable rule is about scope lines rather than about this defect: a sweep certifies exactly what its scope line names, so an omission there is invisible to every later audit no matter how thorough, and the omission survived one widening because that widening was aimed at the previous miss rather than at the shape of the gap. Scope lines should name the constructor's documented parameter domain, not only the method list.

Next: iteration 6 executes PR-31 as one class fix across the four optimizers, re-sweeps the rows it makes stale, and then the second and final evaluator invocation.
## iter 6/10 | 3c6e8691-040322 | 2026-07-29 | PR-31 | done

Task: PR-31 (High, correctness) - the documented `expected_returns=None` contract was honoured by `EfficientFrontier` and by none of its siblings. Closed as one class fix across five sites. Two further sites in the same class were found while executing and are filed rather than folded in.

Changed: pypfopt/efficient_frontier/efficient_cdar.py (constructor sizing, `portfolio_performance` guard), efficient_cvar.py and efficient_semivariance.py (`portfolio_performance` guards), pypfopt/base/_base_optimizer.py (labelling branch), tests/test_base_optimizer.py (2 new tests), tests/test_efficient_cdar.py (1 new test), tests/test_efficient_cvar.py and tests/test_efficient_semivariance.py (existing no-returns tests extended past construction), BACKLOG.md (PR-31 closed, PR-32 and PR-33 filed), PLAN.md (2 Lessons, 4 inventory rows re-swept).

Checkpoint: d1f1964c0590c4320744b3d0f446e131c896c2a3

Verification: The class was enumerated before anything was edited, and it is larger than the finding described. Five classes document `expected_returns` as optional and one honours it. `EfficientCDaR.__init__` sized its dummy covariance from `len(expected_returns)` where both siblings used `returns`; `EfficientCVaR`, `EfficientCDaR` and `EfficientSemivariance` all called `objective_functions.portfolio_return` unguarded in `portfolio_performance`; and the free `portfolio_performance` in `_base_optimizer.py` derived its integer labels from `len(expected_returns)` in the one branch reached by dict weights with an unlabelled covariance. Six sites, one root cause: deriving an asset count or a label set from the one input documented as optional.

Five were fixed to the pattern `EfficientFrontier` already sets - compute the risk always, compute the return and any ratio only when `expected_returns` is not None, return None in their place - and the sixth, `CLA`, is filed as PR-32 because there the code is right and the docstring is wrong: the critical line algorithm reads the mean at eleven sites including the turning-point sort at `cla.py:126-129`, so `_solve` has no meaning without it. That is the PR-30 shape again, and deciding it needed the same evidence: read what the code does before choosing which side of the contradiction to change.

The verify gate did its job on the first attempt. Sizing CDaR's dummy covariance with `returns.shape[1]`, matching the siblings, turned `test_cdar_errors` red: it asserts `pytest.raises(TypeError)` for a list of returns, and `.shape` on a list raises AttributeError before `_validate_returns` can raise the documented TypeError. The fix became `np.shape(returns)[1]`, which handles lists, arrays and frames alike, so the None path works and the list path still reaches the validator. Reading that test before editing the line would have saved the attempt; the Lesson is recorded.

Chasing it produced PR-33. The identical input is pinned three different ways: `test_cdar_errors` asserts TypeError while `test_efficient_cvar.py:461` and `test_efficient_semivariance.py:105` assert AttributeError, all three under the same comment "list not supported". The siblings' assertions pin the accident, not the contract their own Raises sections document. That is exactly the fault PLAN's Lessons describe, and it is filed rather than fixed here because changing the exception type two public constructors raise is its own change with its own differential.

Every new test was run against the pre-fix sources, and run again after the fix changed shape, because `np.shape(returns)[1]` and `returns.shape[1]` differ precisely for list input and the earlier differential no longer covered the code that shipped. The differential ran against a scratch copy of `pypfopt/` and `tests/` with the four changed files restored from HEAD, so the working tree was never mutated. All five new tests fail there - two ValueError, one TypeError, two assertion failures - and `test_cdar_errors` passes there, which is what shows the final fix preserved it rather than repaired it.

Contract preserved. No signature changed and no previously working call behaves differently: the guards are entered only when `expected_returns is None`, which previously raised, so every path that returned a number before returns the same number now. The 60-check sibling battery from iteration 2 was re-run against the fixed code at 0 failures, which is the evidence that the None branch did not disturb the ordinary one. Documentation moved with the code in the same iteration: the three `portfolio_performance` Returns sections now say which elements come back None, and the constructors' existing promises became true rather than being rewritten.

Inventory: four rows had their implementing code changed and were re-swept in this iteration rather than left stale - the three sibling rows on the 60-check battery plus the new None-path evidence, and the base free-function row on a fresh 12-check battery covering a hand-computed mu, sigma and Sharpe, `risk_free_rate` at two values, both weight forms, both label sources, the changed labelless branch agreeing with the labelled one to 1e-12, the documented None case on both, and both rejections. All 26 rows remain swept.

Verify command GREEN: 351 passed, 11 skipped, 0 failed, exit 0, up from 348 by the three new tests. Ruff check and ruff format clean.

Learnings: The finding as filed named four classes and the class was six sites, which is the ordinary result of enumerating before editing rather than after. The more useful lesson is narrower: I read the tests covering the behaviour I was fixing and not the tests pinning the line I was changing, and those were different tests. A constructor line is load-bearing for every error path that runs after it, so the question is not only what the change does but what it now happens before. Second, a differential expires when the fix changes: the first version of this fix was verified against the pre-fix code, then the fix was rewritten, and only re-running it caught that the new form had to be checked against a contract the first form had broken.

Next: PR-32 and PR-33 are open, both Medium, both discovered under closeout while executing PR-31 and therefore still worked. Iteration 7 takes PR-32, iteration 8 PR-33, then the second and final evaluator invocation.
## iter 7/10 | 3c6e8691-040322 | 2026-07-29 | PR-32 | done

Task: PR-32 (Medium, documentation) - `CLA.__init__` promised `expected_returns` could be None while the critical line algorithm cannot run without it. Closed by removing the promise and replacing the opaque failure with one that names the argument. Re-sweeping the row it made stale found a Medium in `efficient_frontier`, filed as PR-34.

Changed: pypfopt/cla.py (docstring corrected, explicit TypeError added), tests/test_base_optimizer.py (1 new test), BACKLOG.md (PR-32 closed, PR-34 filed), PLAN.md (cla row re-swept).

Checkpoint: 46d400582bfd3ae41b73b779a5a78e2ff60bf6f8

Verification: The direction was settled the way PR-30 and PR-31 settled theirs, by reading what the code can do rather than what looks tidier. `CLA._solve` reads `self.mean` at eleven sites, including the turning-point sort at `cla.py:126-129` that orders assets by expected return to find the frontier's first corner, so there is no volatility-only mode to document. Nothing pinned the promise: no test passes None to CLA and no `.rst` repeats it, so removing it breaks no caller.

Six sites in the package document `expected_returns` as optional. Five now honour it - the four EfficientFrontier-family classes and the free `portfolio_performance` - and the sixth said so wrongly. The new test enumerates them from the signature rather than from a list: every class `pypfopt.__all__` exports whose `__init__` takes `expected_returns` has its docstring entry parsed for the word None and is then constructed with None, and the two must agree. A new optimizer is covered the day it is added, and the check asserts it examined at least five classes so a parser that silently stops matching fails rather than passes empty.

Run against the pre-fix `cla.py` in a scratch copy, with the working tree untouched, the test fails and the twelve existing CLA tests pass; restored, all thirteen pass. The failure is the one that matters - promise True, behaviour False - rather than an incidental error.

The added guard is a message, not a behaviour change. `CLA(None, S)` already raised TypeError, from `len(None)` inside a reshape, naming nothing the caller could act on. It still raises TypeError, which is what the constructor's own Raises section documents, but now says the argument is required and points at `EfficientFrontier.min_volatility` for the case the old docstring was trying to describe. The Operating envelope asks for exactly this on a user-error surface: a wrong value deserves a clear failure message.

Contract preserved: no signature moved, and the only call that behaves differently is the one that previously crashed. The 16-check re-sweep confirms the ordinary path is untouched - min_volatility and max_sharpe still agree with EfficientFrontier as an independent reference to 1e-4, at 0.1591508 and Sharpe 1.375861643701672 against 1.375861643701672, the Sharpe identity holds, `risk_free_rate` moves the answer with its identity exact at two values, and a 0.10 weight cap binds and changes the weights.

Then the re-sweep earned its keep. Exercising `points` at four values, which the row's previous sweep never did, showed `efficient_frontier` returning three empty lists for points below the turning-point count: on this fixture, 16 turning points give 0 points at points=10 and points=15, 1 point at 16 and 17, and a spanning frontier only from 32. The cause is `points // len(self.w)` at `cla.py:475` reaching zero. It is silent, and it is not confined to the method: `plotting.py:168` hands the caller's `points` straight to it, so `plot_efficient_frontier(cla, points=10)` draws nothing. Filed as PR-34 at Medium, a plausible in-envelope call failing quietly. Closeout does not suppress it - a Medium noticed while executing a task is still filed and still worked.

My own probe was wrong twice before the code was, which is the rule PLAN records about treating the probe as a suspect. It asked for 30 points and read the result as a defect when the real answer was that 30 is itself in the degenerate band, and it called `portfolio_performance` on an optimizer it had never solved. Both were probe faults; the third failure, at points=10, was real.

Verify command GREEN: 352 passed, 11 skipped, 0 failed, exit 0, up from 351 by the new test. Ruff check and ruff format clean.

Inventory: the cla row was re-swept at this commit on the 16 checks above rather than left stale, and its scope line now names the `points` parameter and the None rejection so the next sweep cannot skip either. All 26 rows remain swept.

Learnings: Re-sweeping a row after changing its code is not a formality to clear before converging - this one found a Medium in a method the fix never touched, because a re-sweep has to exercise the row's documented parameters and the previous sweep had never moved `points`. That is the same shape as PR-31: the defect was always reachable, and what hid it was a sweep that certified the row without exercising the parameter. The second point is smaller and repeats a Lesson already written: two of the three failures my probe reported were the probe's fault, and reading them as code faults first would have wasted the iteration.

Next: PR-33 and PR-34 are open, both Medium. Iteration 8 takes PR-33, iteration 9 PR-34, iteration 10 the second and final evaluator invocation and, on PASS, the Converged line.
## iter 8/10 | 3c6e8691-040322 | 2026-07-29 | PR-34 | done

Task: PR-34 (Medium, correctness) - `CLA.efficient_frontier(points=n)` returned three empty lists for any n below the frontier's turning-point count, and one degenerate point up to twice it, silently, with `plot_efficient_frontier` passing the caller's `points` straight through.

Changed: pypfopt/cla.py (a per-segment floor of two samples, docstring), tests/test_cla.py (1 new test), BACKLOG.md (PR-34 closed), PLAN.md (1 Lesson, cla and plotting rows re-swept).

Checkpoint: c17fa1b9bd6cca06faf78a0b66304aec8c929179

Verification: The cause is one expression. The frontier is sampled segment by segment between turning points, `points // len(self.w)` per segment, and that reaches zero as soon as the caller asks for fewer points than the frontier has corners. On this fixture, 16 turning points, points=10 and points=15 produced zero samples per segment and therefore an empty frontier; 16 and 17 produced one; only from 32 did the frontier span 0.1592 to 0.3468. The fix floors the per-segment count at two, so every segment contributes its own endpoints and the frontier always spans its corners.

The floor changes only the degenerate band, which is what makes it safe. For points at or above twice the turning-point count the expression already exceeded two and the result is byte-identical: 100 still returns 76 points and 200 still returns 166, both spanning the same 0.1877 of volatility as before. Below it, 2, 10 and 15 now return 16 points spanning that same range instead of nothing. Larger requests still give strictly more points, so the parameter is monotone across its whole domain rather than only above a threshold the caller cannot see.

The new test sweeps `points` over 2, 10, one below the turning-point count, the count itself, twice it, and 100, asserting each returns at least two points, a frontier of positive width, and the same width as every other request, then that 200 returns strictly more points than 100. It derives the turning-point count from the solved object rather than hardcoding 16, so it does not silently stop testing the boundary if the fixture changes. Run against the pre-fix `cla.py` in a scratch copy it fails; restored, the whole CLA and plotting suites pass, 31 tests in both directions.

Contract preserved: no signature moved and no previously non-degenerate result changed. The docstring gained one sentence saying the frontier is sampled between turning points and that a value below their count returns roughly that many points, which is the behaviour the fix now guarantees rather than a promise made ahead of it.

Two probe artifacts are worth recording, because between them they cost more of this iteration than the fix did. The re-sweep script carried an assertion written yesterday that the defect exists, `counts[10] == 0`, and reported FAIL once the defect was gone; an obsolete check asserting a bug is indistinguishable from a regression until read. And a plotting probe reused one Axes across a loop, so matplotlib accumulated lines and `ax.get_lines()[0]` kept returning the first call's data - which read exactly like `plot_efficient_frontier` ignoring the caller's `points`. Rebuilt with a fresh figure per call, the plotted counts track `frontier_values` exactly at 16, 76 and 166. There was no second defect. The Lesson is in PLAN.

Inventory: the cla row was re-swept at this commit on 17 checks, now including `points` at four values against the fixed contract and the default confirmed unchanged at 76. The plotting row was re-swept too, though `plotting.py` did not change: `_plot_cla` calls `cla.efficient_frontier(points=points)`, so the row's behaviour depends on code this iteration altered, which is the inheritance case PLAN's Lessons already record. Both the CLA and EfficientFrontier plotting paths were exercised, `show_assets` at both values, and the plotted point count checked against `frontier_values` at three densities. All 26 rows remain swept.

Verify command GREEN: 353 passed, 11 skipped, 0 failed, exit 0, up from 352 by the new test. Ruff check and ruff format clean.

Learnings: A stale probe is a liability of the same kind as a stale test. This one asserted the presence of a defect, so fixing the defect turned it red, and for a moment that read as the fix breaking something. Checks that pin a bug need retargeting to the contract the moment the bug is closed, exactly as the CDaR and CVaR regression tests did. The second point is narrower and now in the Lessons: matplotlib probes must build a fresh figure per call, because a shared Axes accumulates artists and makes the first call's data look like every later call's answer.

Next: PR-33 is the only open task, the last on the ledger. Iteration 9 takes it, iteration 10 runs the second and final evaluator invocation and, on PASS, appends the Converged line.
## iter 9/10 | 3c6e8691-040322 | 2026-07-29 | PR-33 | done

Task: PR-33 (Medium, testing) - `EfficientCVaR` and `EfficientSemivariance` died on a missing `.shape` attribute when given a list of returns, before reaching the shared validator, and their tests asserted that AttributeError under a comment naming the real contract. Closed class-complete, and the class is now recorded under Settled classes.

Changed: pypfopt/efficient_frontier/efficient_cvar.py and efficient_semivariance.py (dummy-covariance sizing, Raises documented), efficient_cdar.py (Raises documented), tests/test_efficient_cvar.py and tests/test_efficient_semivariance.py (assertions retargeted), tests/test_base_optimizer.py (1 new test), BACKLOG.md (PR-33 closed, class settled, ledger now empty), PLAN.md (1 Lesson, 2 inventory rows re-swept).

Checkpoint: d5ee16321acacb88effed15bc54f21e36e61582c

Verification: The three constructors sized one expression three ways, and the exception a caller saw followed from that rather than from any decision. CDaR reached `_validate_returns` and raised its documented `TypeError: returns should be a pd.DataFrame or np.ndarray`; the two siblings raised a bare AttributeError from `.shape` on a list. All three now compute `np.zeros((np.shape(returns)[1],) * 2)`, and the enumerating check reports exactly those three sites in `pypfopt/` and no others, so no constructor derives its size from the optional `expected_returns` and none dies before the shared validator. Run directly, all three now produce the identical TypeError and message.

The tests were retargeted from the mechanism to the contract, which is the PLAN Lesson this defect was an instance of: both files carried the comment "list not supported", stating the contract, above an assertion pinning whichever error happened to arrive first. They now assert TypeError, and a new test asserts it for all three classes in one place, matching on the message text. Pinning siblings together rather than one per file is the structural half of the fix - three separate files asserting a shared contract is exactly how CDaR came to say TypeError while its siblings said AttributeError without anyone noticing.

Documentation moved with the behaviour in the same iteration. All three Raises sections named TypeError for `expected_returns` only and none mentioned `returns`, though `_validate_returns` has always raised it; all three now document both. The behaviour change is real and recorded: `EfficientCVaR(mu, list)` and `EfficientSemivariance(mu, list)` raised AttributeError before this iteration and raise TypeError after it. That is a public exception type changing, justified because the new type is the one the shared validator raises, the one the third sibling already raised, and now the one the docstrings state.

Contract preserved otherwise: `np.shape` agrees with `.shape` for every DataFrame and ndarray, so no accepted input behaves differently and only the rejected one does. The 60-check sibling battery was re-run against the changed code at 0 failures, which is the evidence that the constructors still build the same optimizers. Against the pre-fix siblings in a scratch copy the two retargeted tests and the new enumerating test all fail, with the AttributeError they used to assert; `test_cdar_errors` passes in both directions, since CDaR was already correct.

Inventory: the EfficientCVaR and EfficientSemivariance rows were re-swept at this commit on the 60-check battery plus the list rejection now reaching the shared validator. All 26 rows remain swept.

Verify command GREEN: 354 passed, 11 skipped, 0 failed, exit 0, up from 353 by the new test. Ruff check and ruff format clean.

Learnings: The divergence survived because the three classes are tested one file at a time, so three different answers to one question each looked like a local convention in its own file. A shared contract needs a test that names the siblings together; that is what turns a divergence into a failure instead of a house style. The rule is in PLAN's Lessons. Worth noting too that the fix here was the same expression PR-31 had already worked out for CDaR - once a class is diagnosed, the remaining sites are cheap, and the cost is almost entirely in the enumeration that finds them.

Next: the ledger is empty in Now, Next and Later for the first time since iteration 5's REJECT. Iteration 10 is the final iteration: it runs the second and last evaluator invocation and, on PASS, appends the Converged line.
## iter 10/10 | 3c6e8691-040322 | 2026-07-29 | WRAPUP | done

Task: Final iteration. Ran the second and last evaluator invocation, which returned PASS, then declined to declare convergence because one of the observations it recorded as Low is a defect this run introduced and is still open. The run ends out of budget with six tasks closed and one Low filed.

Changed: BACKLOG.md (PR-35 filed under Later), PLAN.md (EfficientCDaR row hash carried forward to its true sweep commit). No source file changed, deliberately.

Checkpoint: 8522e3adfb6d8e563c8189cc15ea7cea3abf1779

Verification: Evaluator: PASS, second and final invocation. It re-ran the Verify command at 354 passed, 11 skipped, exit 0, ruff clean; confirmed every one of the six closed tasks' acceptance checks passes at HEAD and fails against its own pre-fix source, restored per task rather than in bulk - PR-30 against 7b2f8dc^, PR-31 against d1f1964^, PR-32 against 46d4005^, PR-33 against d5ee163^, PR-34 against c17fa1b^; reproduced PR-29's Declined reasoning number for number, CLARABEL solving at the named floor to 0.017049502125769528 and SCS to 0.017066824489422313 while the default fails under OSQP; and re-ran both Settled classes' enumerating checks by hand rather than trusting their text. Its strongest contribution was a numeric differential I had not run: 45 result keys and 227 float elements across all four optimizers, HEAD against 0ffcecb, with zero differences at 1e-12, so nothing this run changed moved a previously working number. It also confirmed the new tests are not vacuous, the method enumeration yielding 61 documented methods against its floor of 50 and the optional-expected_returns enumeration yielding 5 classes against its floor of 5.

The run does not converge, and the reason is one of the evaluator's three Low observations, reproduced here before acting on it. PR-33 added `TypeError if returns is not a pd.DataFrame or np.ndarray` to the Raises section of all three tail-risk constructors. That claim is true only for a list. Because `np.shape(returns)[1]` now runs before `_validate_returns`, all three raise `IndexError: tuple index out of range` for `returns` given as None, a Series or a dict. For EfficientCDaR it is also a behaviour regression from this run: at 0ffcecb it sized from `len(expected_returns)`, never touched `returns` at all, and reached the shared validator with the documented TypeError for every one of those shapes.

The severity is Low - off-contract input on a user-error surface, which the Operating envelope caps there whatever the consequence - and the evaluator was right not to make it a REJECT reason. But the Definition of done requires every finding, Low included, to be completed, Declined with a genuine not-worth-fixing reason, or blocked. Declining is not available in good conscience: the docstring is one I added this run and it is untrue, and the envelope's own binding rule asks that a wrong value on this surface get a clear failure message, which `IndexError: tuple index out of range` is not. So it is filed as PR-35 and the ledger is not empty.

Fixing it in this iteration was the tempting move and it is the wrong one. Both evaluator invocations are spent, so any source change made now would be the only change in the run that no adversarial reviewer had seen, and convergence declared over it would hollow out the gate that just did its job. The gate is worth more than the convergence line. PR-35 also wants a boundary fix rather than three copies of a type check, since three copies would violate the duplicated-validation class settled by PR-03 and PR-05, and that is a design decision worth an iteration rather than a hurried edit at the end of one.

Two smaller evaluator observations were handled. Its second, that the EfficientCDaR inventory row recorded a sweep at d1f1964 while `efficient_cdar.py` changed again at d5ee163, was correct bookkeeping: the row's hash is carried to d5ee163, where PR-33's two docstring lines landed and where the 60-check battery covering all three siblings was re-run at 0 failures, so the evidence for the row does exist at the later commit and only the hash was behind. Its third, that CLA crashes on all-equal expected returns, was verified identical at 0ffcecb and is therefore pre-existing rather than a regression; it belongs to the next run's audit, not to this run's diff.

Verify command GREEN: 354 passed, 11 skipped, 0 failed, exit 0, run in this iteration. Ruff check and ruff format clean.

Inventory: 26 of 26 rows swept, none stale. Every row this run touched was re-swept in the iteration that touched it rather than left for the end.

Learnings: The final gate found a defect the run itself created, in the documentation the run wrote, in a class the run had spent three tasks closing - which is the strongest argument for the gate that any of these iterations produced. The rule worth carrying is about timing rather than about the defect: an evaluator budget is a review budget, so the last invocation should be spent when the code is genuinely final, and anything discovered after it either ends the run or waits for the next one. Spending both invocations early enough to answer them is the same lesson the previous run recorded about arithmetic, arriving from the other direction.

Next: the run ends out of budget. PR-35 is the only open task and is precisely specified with its acceptance check. A fresh run should close it, re-sweep the three sibling rows it makes stale, and reach the Converged line in about three iterations, with a full evaluator budget available.
## iter 1/15 | 1f0a28c0-053034 | 2026-07-29 | PR-35 | done

Task: PR-35 (Low, documentation) - all three tail-risk constructors documented TypeError for off-contract `returns` while raising `IndexError: tuple index out of range` for None, a Series and a dict, because the dummy-covariance sizing read the shape of `returns` before `_validate_returns` ran; only a 2-d list reached the documented TypeError. Closed at the shared boundary the task specified, and the sizing settled class is refreshed to cover it.

Changed: pypfopt/efficient_frontier/efficient_frontier.py (new `_validate_returns_type` staticmethod, which `_validate_returns` now calls first), efficient_semivariance.py, efficient_cvar.py and efficient_cdar.py (dummy-covariance sizing chained through the shared check), tests/test_base_optimizer.py (family test extended from one off-contract shape to four), BACKLOG.md (PR-35 closed, sizing settled class refreshed, duplicated-validation settled line extended), PLAN.md (3 sibling rows re-swept, 1 Lesson).

Checkpoint: fb790ea09a5bfe90c04a51e1da979b2c6722f569

Verification: Reproduced first at HEAD: twelve calls, three classes by four shapes, gave IndexError for None, a Series and a dict and TypeError only for a list, exactly as filed. The fix is one staticmethod on EfficientFrontier, `_validate_returns_type`, that both `_validate_returns` and the three sizing expressions call: `np.zeros((self._validate_returns_type(returns).shape[1],) * 2)` validates and sizes in a single expression, so the check and the shape lookup cannot drift apart. No docstring changed, because the point of the fix is that the Raises sections PR-33 wrote are now true.

The extended family test asserts the validator's TypeError message for 3 classes x 4 shapes. Against the pre-fix source in a scratch copy it fails with the filed IndexError at the old sizing line; against the fixed tree it passes, as do test_cdar_errors and both sibling error tests pinning the list rejection. Contract preserved: `_validate_returns` has exactly three callers, the three constructors, and for every accepted input the sizing is unchanged since `np.shape(x)[1]` equals `x.shape[1]` for a DataFrame or ndarray and the isinstance check is the one `_validate_returns` always ran, now earlier. The only behaviour change is IndexError becoming the documented TypeError for three off-contract shapes on a user-error surface. Evidence: the 60-check sibling battery re-run at 0 failures and the full suite green.

Enumerating checks re-run before the settled lines were rewritten: the guarded sizing form appears at exactly three sites, no `np.zeros((np.shape` or `np.zeros((len(` form remains in pypfopt/, and `def _validate_` lists each validator exactly once, `_validate_returns_type` joining the single definitions on EfficientFrontier.

Staleness settled mechanically: an AST comparison of efficient_frontier.py between HEAD and the fixed tree reports added `EfficientFrontier._validate_returns_type`, changed `EfficientFrontier._validate_returns`, nothing else - so the two EfficientFrontier inventory rows' scoped methods are untouched and those rows are not stale. The three sibling rows, whose constructors did change, were re-swept in this same iteration: the 60-check battery, recovered from the previous session's scratchpad rather than rebuilt, passed 60 of 60 against the fixed code, and the four-shape TypeError contract is the new test.

Verify command GREEN: 354 passed, 11 skipped, 0 failed, exit 0 - the count is unchanged from the last checkpoint because the acceptance extended an existing test rather than adding one. Ruff check and ruff format clean.

Learnings: A previous session's scratchpad survives under Temp/claude/<project>/<session>/scratchpad and held the exact 60-check battery this re-sweep needed; checking there before rebuilding a battery turned a half-iteration of reconstruction into a copy. Added to PLAN's Lessons.

Next: Now, Next and Later are all empty. This run has had no audit, so the next iteration generates the backlog with a full fresh-evidence audit per the Method, sweeping any stale rows first - which is also the first requirement on the Definition-of-done path, since the previous run's audits do not carry.

## iter 2/15 | 1f0a28c0-053034 | 2026-07-29 | AUDIT | audit

Task: Full fresh-evidence audit, the run's first. One finding filed: PR-36 (Medium, correctness), a CLA crash on all-equal expected returns. Two candidates examined and Declined with evidence. Closeout does not begin: a Medium was filed.

Changed: BACKLOG.md (PR-36 filed in Next, 2 Declined lines added), PLAN.md (EfficientFrontier core and targets rows re-swept, 1 Lesson), JOURNAL.md (this entry, rotation).

Checkpoint: ec1dcd32e28a51a9e57cf5a8507e605734f9e45b

Verification: Staleness first, settled mechanically from git for all 26 rows. 17 rows had no implementing file changed since their recorded sweep. Of the 9 flagged, 6 were changes outside the row's scoped functions, each covered by a sibling row with a later hash. One flag was a probe artifact: add_sector_constraints appeared changed only because subprocess text=True decodes git show as cp1252 on Windows while the working tree was read as UTF-8, so upstream's non-breaking space produced a phantom diff - git's own hunks for that file since a6638d2 touch only _solve_cvxpy_opt_problem (PR-17) and portfolio_performance (PR-31), so the plumbing row was never stale. The remaining two flags were real: EfficientFrontier core (swept 6d4cb54) and targets/validation (swept 2998bde) predate __init__ gaining the bound-cache and floor-probe slots and the floor machinery PR-24 added. Both re-swept this iteration: the targets row on the recovered 27-check battery at 0 failures, the core row on a 9-check battery rebuilt from the row's own recorded known answers - min-variance closed form exact at 0.711864406779661, minimal against 400 random simplex points, max_sharpe at 1.375861643701672 dominating equal weight 0.7192, risk_free_rate moving the weights by L1 0.401, risk_aversion 0.5/2/10 monotone, market_neutral summing to zero at 7.6e-17, risk_aversion=0 rejected.

The finding: with every expected return equal, _compute_lambda's denominator c is exactly 0 for every candidate, it returns None - a path marked pragma: no cover - and case b) of _solve compares lam bare at cla.py:375-376 where case a) shields the same value with CLA._infnone. Both min_volatility and max_sharpe die with TypeError. Ties at top, bottom and middle only are handled fine; the boundary is the fully flat vector, a coherent no-view prior inside the constructor's documented domain. Medium: a crash on a plausible in-envelope edge case, with a message naming nothing the caller can act on.

Examined and Declined, with the evidence trail: the 11 non-ASCII bytes in pypfopt/ and tests/ (8 NBSP, 3 en dashes) are upstream-original - git blame names pre-jeffy commits at every site; my first two classification probes said otherwise and were both wrong, one on CRLF line endings breaking exact-line membership, one on the cp1252 decode. And the tail-risk constructors' IndexError on a 1-d ndarray: in-contract type, vacuous single-asset case, declined rather than hardened.

Dimension scores, claiming all 26 rows, all swept, staleness verified this iteration: correctness Medium (PR-36); architecture None (settled boundaries hold: 2 sum-normalization sites both provably positive, 2 cvxpy solves both converting, 2 limit-stating sites both fed by _feasible_bound, pinv 0); code quality None (ruff check and format clean); security None (no eval, exec, pickle, subprocess, __import__ or os.system in pypfopt/; no network or CLI surface exists); testing None (354 passed 11 skipped exit 0, zero bare skip markers, all 11 skips are skipif on named absent dependencies); error handling None (exception-conversion exhaustiveness pinned by suite, isinstance(target 2 sites both in shared validators); performance None (bound-cache class intact per its grep, suite runtime stable ~37s); documentation None (docstring-truth enumeration tests green in suite; typography Declined as upstream); dependency hygiene None with the standing caveat that no CVE scanner is available in this venv and the known-CVE question stays recorded as unexamined, pip check reports no broken requirements; developer experience None (make-based workflow untouched, ruff gates green); observability None (verbose paths exercised by the batteries, warning conventions settled); UX/accessibility skipped - no interactive user-facing surface, plotting certified by its swept rows.

Verify command GREEN: 354 passed, 11 skipped, 0 failed, exit 0, run this iteration. Ruff check and ruff format clean.

Learnings: Two of my three archaeology probes this iteration reported false findings before the code did - CRLF contamination and a cp1252 decode both fabricated diffs that a git blame then overturned. The operational rule is in PLAN's Lessons: decode git show explicitly as UTF-8 and strip carriage returns before comparing lines on Windows. The audit pattern that keeps working: settle staleness from git per function, not per file, and treat every probe failure as a probe suspect first.

Next: PR-36 is the only open task. Iteration 3 executes it and re-sweeps the cla row; the run then needs a fresh full audit before any convergence, since this one filed a Medium.
## iter 2/15 | 1f0a28c0-053034 | 2026-07-29 | ROTATION | rotation

Task: ROTATION - JOURNAL.md reached 512 lines after this iteration's AUDIT entry, past the 500-line threshold.

Changed: JOURNAL.md (9 oldest entries removed, 10 most recent kept), JOURNAL-archive.md (9 entries appended).

Checkpoint: ec1dcd32e28a51a9e57cf5a8507e605734f9e45b

Verification: 19 entries were present; the 9 oldest moved to the end of JOURNAL-archive.md and the 10 most recent stayed, which is the rule's "all but the last 10". The archive's entry count rose from 37 to 46 and did not fall; no entry text was altered in the move, only relocated, and the two files together hold every entry.

Learnings: none - routine maintenance.

Next: PR-36, unchanged by the rotation.

## iter 3/15 | 1f0a28c0-053034 | 2026-07-29 | PR-36 | done

Task: PR-36 (Medium, correctness) - CLA crashed with a bare TypeError on all-equal expected returns. Closed with two layers: the None-shield the finding named, and a constructor guard the fix attempt proved necessary, because the shield alone converted the crash into a silently wrong portfolio.

Changed: pypfopt/cla.py (case b) of _solve shields lam with _infnone as case a) does; constructor rejects a flat mean vector with more than one asset, replacing upstream's commented-out perturbation hack; Raises documented), tests/test_cla.py (1 new test, pandas import), BACKLOG.md (PR-36 closed), PLAN.md (cla and plotting rows re-swept, 1 Lesson).

Checkpoint: fa51ba7d471263ff9d79344b5394acb9a3c71930

Verification: The filed acceptance check was wrong about the fix's shape, and the first fix attempt is what showed it. With only the comparison shielded, flat-mu min_volatility completed and returned {AAPL 0.25, BAC 0.25, SBUX 0.50} against the true minimum-variance portfolio, a maximum weight deviation of 0.4898: every lambda is None, so the algorithm can never free an asset and terminates on its init state. Case 3's minimum-variance solve is only correct over the free set the iteration discovers, and the iteration cannot start. There is no cheap correct answer inside CLA - computing the box-constrained QP directly is EfficientFrontier's job - so the honest shape is the one PR-32 set for CLA(None, S): refuse at the constructor with a message naming the alternative. The acceptance was retargeted per the Lesson on checks encoding a fix's shape: the property is no crash and no silently wrong answer, and the rewritten test fails against the pre-fix source in a scratch copy, with TypeError arriving where ValueError is expected.

The guard is exact, not heuristic: c = -c1*c2[i] + c3*c4[i] is zero for every candidate iff Sinv*m is parallel to Sinv*1 iff the mean vector is constant, so np.ptp(self.mean) == 0 with more than one asset is precisely the input set with no frontier. Upstream knew: the constructor carried a commented-out hack perturbing the last mean by 1e-5 on exactly this condition, present since the original de Prado import at faa2d52 and disabled ever since. The guard replaces silent data modification with a typed refusal. A single asset has ptp 0 by construction and keeps working - case b) never runs there - which the new test pins alongside the near-tie case, one asset at +1e-6, probed before pinning: min_volatility sums to 1 with max weight 0.1886 and max_sharpe completes.

Contract preserved for every other input, with differential evidence: 582 floats across min_volatility and max_sharpe weights and performance, frontiers at points 32, 100 and 200, and a 0.10-capped portfolio, dumped pre-fix and re-run post-fix, max abs diff 0.0 - bit-identical. The shield is a no-op wherever no lambda is None, since _infnone is the identity on floats; the guard touches only the input set that previously crashed. The 17-check CLA battery passes, the plotting probe tracks frontier_values exactly at 16, 76 and 166 plotted points for 10, 100 and 200 requested, and the whole CLA file passes 14 of 14.

The shield stays alongside the guard deliberately: partial degeneracy - c == 0 for some single candidate mid-iteration - remains reachable in principle, case a) has always shielded it, and case b) now treats the same value the same way.

Verify command GREEN: 355 passed, 11 skipped, 0 failed, exit 0, up from 354 by the new test. Ruff check and ruff format clean.

Inventory: the cla row re-swept at this commit on the 17-check battery plus the flat rejection, near-tie acceptance and single-asset exemption; the plotting row re-swept on the 3-density probe because _plot_cla passes through cla.efficient_frontier. All 26 rows swept.

Learnings: A shield that converts a crash into a silently wrong answer is worse than the crash. When a degenerate input has no correct answer inside the algorithm, reject it at the boundary with a message naming the alternative, and treat the first fix attempt's failure as the diagnosis it is. Added to PLAN's Lessons.

Next: the ledger is empty. This run's only audit filed a Medium, so convergence still needs a fresh full audit scoring zero High and zero Medium; iteration 4 runs it.

## iter 4/15 | 1f0a28c0-053034 | 2026-07-29 | AUDIT | audit

Task: Second full fresh-evidence audit. Iteration 2's audit filed a Medium, so convergence still needed an audit scoring zero High and zero Medium; this one goes at the code the run has touched since, and files one finding of its own: PR-37 (Medium, error handling). Closeout does not begin.

Changed: BACKLOG.md (PR-37 filed in Next), JOURNAL.md (this entry). No source file changed.

Checkpoint: 517e759fb4f6a5a17475c7834110c231f2f680dd

Verification: Staleness is a two-file question this time: since the last audit checkpoint ec1dcd3 the only non-state paths changed are pypfopt/cla.py and tests/test_cla.py, both from PR-36, and both affected rows - cla and plotting - were re-swept in that same iteration at fa51ba7 with the 17-check battery, a 582-float bit-identical differential, and the 3-density plotting probe. No other row's implementing code changed, so all 26 rows are swept and current.

The hard look went at PR-36's own diff, per the rule that the audit hunts hardest in code the run touched. The guard's exact-condition proof stands: c is zero for every candidate iff the mean vector is constant, and the single-asset exemption plus near-tie acceptance are pinned by test. Probing the guard's neighbourhood is what produced the finding: np.ptp propagates NaN, NaN == 0 is False, so a mean vector containing NaN sails past the new guard exactly as it sailed past the old code, and CLA then completes silently. With one NaN in the mean, min_volatility returns sum-1 weights deviating 0.8744 from the true minimum-variance portfolio; an all-NaN mean constructs; inf in the mean and NaN in the covariance also complete, leaking only numpy RuntimeWarnings from _compute_w's arithmetic. Severity is set by contrast and by the envelope: the EfficientFrontier family fails the identical inputs loudly - cvxpy raises "Problem data contains NaN or Inf. Check your parameter values and constants." - and the library's own estimators cannot produce a non-finite mean, since mean_historical_return on an all-NaN ticker yields 0.0. A wrong value on a user-error surface deserves a clear failure message; CLA alone answers it with silence and a plausible-looking wrong portfolio. That is a silently swallowed error: Medium, filed as PR-37 with the constructor boundary named.

Dimension scores, claiming all 26 rows: correctness None - PR-36 closed with differential evidence, the cla row re-swept at fa51ba7, every other row's known-answer evidence current at its recorded hash; error handling Medium - PR-37; architecture None - settled boundaries hold, the sum-normalization grep still reports exactly the 2 provably-positive sites and cla.py contains no cvxpy solve and no .value read; code quality None - ruff check and format clean; security None - no adversarial surface, no dynamic-execution primitive in pypfopt/; testing None - 355 passed, 11 skipped, every skip a skipif naming an absent dependency; performance None - PR-36 added one O(n) check per construction, nothing on a solve path; documentation None - Raises sections moved with behaviour in the same iteration, docstring-truth enumeration tests green; dependency hygiene None with the standing caveat that the known-CVE question is unexamined because no scanner is installable under the envelope, pip check clean; developer experience None; observability None; UX and accessibility not applicable - no interactive surface.

Verify command GREEN: 355 passed, 11 skipped, 0 failed, exit 0, run this iteration. Ruff check and ruff format clean.

Learnings: The probe that found PR-37 came from asking what the new guard does NOT catch - enumerating the neighbours of a fix's condition (NaN against ptp, inf against equality) is cheap and it is where this run's only new finding lived. Not yet a PLAN Lesson; one instance.

Next: PR-37 is the only open task. Iteration 5 executes it; the run then needs a third full audit to score clean before the evaluator gate and convergence.

## iter 5/15 | 1f0a28c0-053034 | 2026-07-29 | PR-37 | done

Task: PR-37 (Medium, error handling) - CLA silently returned a plausible-looking wrong portfolio for non-finite inputs. Closed with one finite-ness gate in the constructor over both numeric arguments, each named in its message.

Changed: pypfopt/cla.py (isfinite checks on expected_returns and cov_matrix, Raises documented), tests/test_cla.py (1 new test, four rejection cases), BACKLOG.md (PR-37 closed), PLAN.md (cla and plotting rows re-swept).

Checkpoint: 9cf3793708d99a5d870f15c63efd53591b31bf42

Verification: The guard is two isfinite checks: the mean immediately after it is shaped, before the flat-vector guard whose ptp a NaN would sail past, and the covariance immediately after asarray. Messages name the argument - "expected_returns contains NaN or infinite values", "cov_matrix contains NaN or infinite values" - which is the clear failure the envelope asks for on a user-error surface, replacing silent completion at 0.8744 weight deviation from the true minimum-variance portfolio.

The new test pins four cases: NaN and inf in the mean, NaN and inf in the covariance. Against the pre-fix source in a scratch copy it fails with DID NOT RAISE on the first case; against the fixed tree the whole CLA file passes 15 of 15. Contract preserved for every finite input by construction - isfinite touches no numeric path - and by evidence: the 582-float differential against the pre-PR-36 baseline remains bit-identical at 0.0, the 17-check battery passes, and the plotting probe tracks frontier_values at all three densities. No caller of the constructor passes non-finite data: the suite and both batteries construct from the fixture pipeline, which cannot produce it.

Verify command GREEN: 356 passed, 11 skipped, 0 failed, exit 0, up from 355 by the new test. Ruff check and ruff format clean.

Inventory: the cla row re-swept at this commit - 17-check battery plus the four-case non-finite rejection joining the flat rejection, near-tie acceptance and single-asset exemption in the constructor's documented domain; the plotting row re-swept on the 3-density probe. All 26 rows swept.

Learnings: none new - the fix followed the boundary the audit named, and the probe-the-guard rule that found this defect is already recorded in iteration 4's entry.

Next: the ledger is empty again. Iteration 6 runs the third full fresh-evidence audit; scoring clean there starts closeout, and the evaluator gate then stands between the run and convergence.

## iter 6/15 | 1f0a28c0-053034 | 2026-07-29 | AUDIT | audit

Task: Third full fresh-evidence audit. Zero High and zero Medium in-envelope, so closeout begins: no replenishment and no further full audit for the rest of this run's budget. The ledger is already empty, so what remains is the evaluator gate and, on PASS, the Converged line.

Changed: JOURNAL.md (this entry only). No source file changed and BACKLOG.md is untouched because the audit filed nothing.

Checkpoint: 1114347f46af11f2351936df03b3f0759cf89e72

Verification: Staleness is again a two-file question: since the last audit checkpoint 517e759 the only non-state changes are pypfopt/cla.py and tests/test_cla.py from PR-37, and the cla and plotting rows were re-swept in that same iteration at 9cf3793 - the 17-check battery, the 582-float differential still bit-identical to the pre-PR-36 baseline, the four-case non-finite rejection, and the 3-density plotting probe. All 26 rows swept, none stale.

The hard look went at PR-37's guards, asking what they do not catch, which is the probe that found PR-37 itself last audit. Off-contract dtypes - strings, booleans - still raise TypeError, the type the constructor documents for non-numeric input, from the same arithmetic sites as before; the guards neither mask nor worsen them. The guard order is right: a NaN-containing flat vector gets the finite-ness message, the more fundamental problem, not the flat-vector one.

The cross-cutting probe re-ran the whole suite under -W error::RuntimeWarning, now including this run's five closed tasks: exactly the two known non-defect failures appear - test_returns_warning, the numpy duplicate signal already under Declined, and test_exception_immutability, the library's own deliberate market-neutrality warning - and 354 pass. No degenerate branch produces NaN and still reaches a right answer anywhere the suite exercises.

Dimension scores, claiming all 26 rows: correctness None - the cla row's evidence is current at 9cf3793 and every other row's known-answer evidence stands on unchanged code; error handling None - PR-37 closed at the boundary the audit named, four rejection cases pinned; architecture None; code quality None - ruff check and format clean; security None - no adversarial surface; testing None - 356 passed, 11 skipped, every skip a named-dependency skipif; performance None - two isfinite calls per construction, nothing on a solve path; documentation None - Raises moved with behaviour in the closing iteration; dependency hygiene None with the standing CVE-unexamined caveat; developer experience None; observability None; UX and accessibility not applicable.

Stall check: this iteration changed only JOURNAL.md and no BACKLOG item changed state, so the stall condition is met on the letter of the rule. The previous primary entry closed PR-37 with source changes, so this is not a second consecutive no-progress iteration and not a hard blocker; the iteration produced the clean audit that closeout and convergence require.

Verify command GREEN: 356 passed, 11 skipped, 0 failed, exit 0, run this iteration. Ruff check and ruff format clean.

Learnings: none new - the audit applied the recorded rules and found the surface clean.

Next: iteration 7 spawns the single fresh-context adversarial evaluator, the run's first invocation. On PASS, the Converged line is appended and the run closes with its report; on REJECT, the evidenced reasons become tasks and the run continues.

## iter 7/15 | 1f0a28c0-053034 | 2026-07-29 | WRAPUP | converged

Task: Convergence. The evaluator gate ran as the run's first and only invocation and returned PASS; every closing-rule condition is now verifiably true, and the Converged line is appended.

Changed: BACKLOG.md (1 Declined line for the evaluator's Low observation, Converged line appended), JOURNAL.md (this entry). No source file changed.

Checkpoint: d4482e00e255e381c21b9376883b1b2d0e881c3d

Verification: Evaluator: PASS - a fresh-context adversarial reviewer re-ran the Verify command at 356 passed, 11 skipped, exit 0 captured directly; confirmed all three closed tasks' acceptance tests pass at HEAD and fail against their pre-fix sources restored per task from git archive - PR-35 at de834b6 failing with the IndexError the fix removed, PR-36 at e4c5849 and PR-37 at 93faf62 each failing with DID NOT RAISE; ran ruff check and format clean; re-derived the differential independently at 198 floats bit-identical between HEAD and pre-run de834b6, with CLA max_sharpe at 1.375861643701672 equal to the EfficientFrontier reference; probed the shield on near-tie and partial-tie means against EF to 1e-6; and re-ran the settled sizing class's enumerating greps at exactly three guarded sites and zero unguarded. It found no in-envelope High or Medium.

Its one Low observation is disposed, not dropped: CLA(mu, None) raises the docstring's documented TypeError at construction but with numpy's raw ufunc wording. Reproduced and judged: the documented type contract holds, the failure moved earlier and clearer than the pre-run state - which constructed silently and died at solve with IndexError - and None is off-contract on a user-error surface, so a bespoke message is cosmetic. Recorded under Declined with that reasoning.

Closing-rule checklist: the iteration 6 audit scored zero High and zero Medium with fresh evidence; the Surface inventory lists 26 of 26 rows swept, none stale; Now, Next and Later are empty, with every finding this run filed either completed (PR-35, PR-36, PR-37) or Declined with reasons; the commits since the clean audit are state-file bookkeeping only; the Verify command ran green this iteration at 356 passed, 11 skipped, exit 0; the evaluator returned PASS; and the Converged line names b12a86ab911449e0049969c155315c849591a03a, the commit whose tree the evaluator verified.

Learnings: none new - the gate did what the previous run's final entry predicted a fresh run with a full evaluator budget would do.

Next: the run is converged. The state files carry forward; the next run's fresh audit and the ratchet both apply from here.

## iter 8/15 | 1f0a28c0-053034 | 2026-07-29 | WRAPUP | converged

Task: Re-declare convergence after the stop hook rejected it. The hook's own re-run of the Verify command exited 127; the cause was not the suite - it is green - but markdown backticks around the Command line in PLAN.md, which no previous run ever tripped because no previous run ever reached the hook's convergence gate.

Changed: PLAN.md (backticks removed from the Verify Command line, 1 Lesson), JOURNAL.md (this entry). No source file changed; the code tree is byte-identical to the one the evaluator verified.

Checkpoint: b357c61417284bcd4e384a1555b5d33cafedd6b0

Verification: The hook runs the extracted text with bash -c after cd to the project root. With backticks, bash treats the whole string as command substitution: it executes the suite - successfully - captures its stdout, then tries to execute that output as a command, which exits 127. The mechanism reproduces in one line: bash -c with a backticked echo exits 127 the same way. The fix is the bare command form the hook's awk expects, and the acceptance check is the hook's own pipeline replicated exactly - the same awk extraction from the edited PLAN.md, cd to root, timeout 240 bash -c - observed exiting 0 this iteration, which is also this iteration's green Verify run: 356 passed, 11 skipped inside the substitution-free invocation.

Closing-rule conditions re-verified: the clean audit stands (iteration 6, zero High zero Medium); 26 of 26 rows swept; Now, Next and Later empty; every commit since the clean audit touches only PLAN.md, BACKLOG.md and JOURNAL.md; Evaluator: PASS stands from iteration 7 on this same code tree - b12a86a remains the last commit that touched pypfopt/ or tests/ - and the Converged line naming b12a86ab911449e0049969c155315c849591a03a is already appended. Nothing the evaluator verified has changed.

Stall check: this iteration changed only PLAN.md and JOURNAL.md and no BACKLOG item changed state, so the condition is met on the letter; the previous primary entry does not say the same, and the iteration turned the hook's rejection into a passing gate, which is the run's remaining obstacle removed.

Learnings: The Verify Command line in PLAN.md is executed text, not prose - the hook runs it through bash -c, so markdown backticks become command substitution and exit 127 at the only moment that line is ever mechanically read. Rule added to PLAN's Lessons.

Next: the run is converged, on the same evidence as iteration 7 plus a Verify gate the hook itself can now execute.
