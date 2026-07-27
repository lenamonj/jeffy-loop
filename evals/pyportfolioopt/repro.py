"""Standalone reproduction of the defects found in PyPortfolio/PyPortfolioOpt at
HEAD a6638d2e06dae6f444fd022cfd4b3c528902a85b (2026-07-07) under Python 3.13.8,
numpy 2.5.1, scipy 1.18.0, cvxpy 1.9.2, pandas 3.0.5.

Fully offline. Every covariance matrix here is synthetic and built in this file;
nothing is downloaded and no fixture is read.

    git clone https://github.com/PyPortfolio/PyPortfolioOpt.git && cd PyPortfolioOpt
    git checkout a6638d2e06dae6f444fd022cfd4b3c528902a85b
    python -m venv venv && venv/Scripts/pip install -e ".[all_extras]"
    venv/Scripts/python path/to/repro.py     # -> P1..P6 FAIL, N1/N2 PASS
    git apply path/to/fixes.patch
    venv/Scripts/python path/to/repro.py     # -> every item PASS

Items P* are defects. Items N* are leads that did NOT reproduce; they PASS both
before and after the patch and are here so the negative claim is checkable too.
"""

import subprocess
import sys
import warnings

import numpy as np
import pandas as pd

from pypfopt import risk_models
from pypfopt.cla import CLA
from pypfopt.efficient_frontier import EfficientFrontier
from pypfopt.hierarchical_portfolio import HRPOpt

RESULTS = []


def check(ident, name, ok, detail=""):
    RESULTS.append(ok)
    print("{} {:<6} {}".format("PASS" if ok else "FAIL", ident, name))
    if detail:
        print("         {}".format(detail))


def sharpe(w, mu, S):
    w = np.asarray(w, dtype=float).ravel()
    return float(w @ mu) / float(w @ S @ w) ** 0.5


def random_problem(rng, n):
    """A synthetic, well-conditioned, strictly positive definite covariance."""
    A = rng.normal(size=(n + 6, n))
    return np.cov(A, rowvar=False)


# ---------------------------------------------------------------------------
# P1 - HRPOpt.optimize() is dead on scipy >= 1.18
# pypfopt/hierarchical_portfolio.py:179 reads sch._LINKAGE_METHODS, a private
# attribute that left the scipy.cluster.hierarchy namespace in scipy 1.18.
# Every call to the documented public method raises AttributeError, including
# the default linkage_method. This is the project's own red Test workflow.
# ---------------------------------------------------------------------------
rng = np.random.default_rng(0)
rets = pd.DataFrame(rng.normal(0, 0.01, size=(400, 4)), columns=list("ABCD"))
try:
    w = HRPOpt(rets).optimize()
    ok = abs(sum(w.values()) - 1) < 1e-9 and len(w) == 4
    detail = ""
except Exception as e:
    ok, detail = False, "{}: {}".format(type(e).__name__, e)
check("P1", "HRPOpt.optimize() works on the installed scipy", ok, detail)

# The documented ValueError contract for a bad linkage method must survive.
try:
    HRPOpt(rets).optimize(linkage_method="not_a_method")
    ok, detail = False, "no exception raised"
except ValueError as e:
    ok, detail = True, "ValueError: {}".format(e)
except Exception as e:
    ok, detail = False, "{}: {}".format(type(e).__name__, e)
check("P1b", "bad linkage_method still raises ValueError", ok, detail)

# ---------------------------------------------------------------------------
# P2 - CLA turning points can violate the budget constraint sum(w) == 1
# pypfopt/cla.py:201 slices the bounded weights wB out of self.w[-1], the
# PREVIOUS turning point, but _solve has already written the boundary value
# into the live weight vector for the asset that just became bounded. The free
# weights are solved against the wrong bounded budget.
# ---------------------------------------------------------------------------
_purge_num_err, _purge_excess = CLA._purge_num_err, CLA._purge_excess


def raw_turning_points(mu, S):
    CLA._purge_num_err = lambda self, tol: None
    CLA._purge_excess = lambda self: None
    try:
        c = CLA(mu, S)
        c._solve()
        return [np.copy(x).ravel() for x in c.w]
    finally:
        CLA._purge_num_err, CLA._purge_excess = _purge_num_err, _purge_excess


rng = np.random.default_rng(3)
problems = []
for _ in range(300):
    n = int(rng.integers(2, 7))
    problems.append((np.linspace(0.05, 0.15, n), random_problem(rng, n)))

worst_budget, worst_at = 0.0, None
n_bad = 0
for mu, S in problems:
    try:
        v = max(abs(x.sum() - 1) for x in raw_turning_points(mu, S))
    except Exception:
        continue
    if v > 1e-9:
        n_bad += 1
    if v > worst_budget:
        worst_budget, worst_at = v, (mu, S)
check(
    "P2",
    "every CLA turning point satisfies sum(w) == 1",
    n_bad == 0,
    "{}/300 synthetic problems produce a turning point off budget; "
    "worst |sum(w)-1| = {:.3e}".format(n_bad, worst_budget),
)

# ---------------------------------------------------------------------------
# P3 - consequence of P2: max_sharpe silently returns a suboptimal portfolio.
# The off-budget turning points are correctly deleted by _purge_num_err, after
# which max_sharpe interpolates between survivors that are no longer adjacent
# on the frontier. The chord cuts the corner and the answer is wrong, with no
# warning of any kind. cvxpy is the oracle; scipy SLSQP agreed with it
# independently during the audit.
# ---------------------------------------------------------------------------
shortfalls = []
for mu, S in problems:
    try:
        w_cla = np.array(list(CLA(mu, S).max_sharpe().values()))
    except Exception:
        continue
    w_ef = np.array(list(EfficientFrontier(mu, S).max_sharpe(risk_free_rate=0.0).values()))
    r = sharpe(w_cla, mu, S) / sharpe(w_ef, mu, S)
    if r < 1 - 1e-4:
        shortfalls.append(100 * (1 - r))
check(
    "P3",
    "CLA.max_sharpe matches the convex-solver optimum",
    not shortfalls,
    "{}/300 synthetic problems are >0.01 pct short of the optimum; "
    "worst shortfall {:.4f} pct of Sharpe ratio".format(
        len(shortfalls), max(shortfalls) if shortfalls else 0.0
    ),
)

# ---------------------------------------------------------------------------
# P4 - equal expected returns (issue 738).
# _compute_lambda returns (None, None) when its denominator c is exactly zero,
# which equal expected returns guarantee. cla.py:367-368 then compares that raw
# None. The outcomes are a raw TypeError, a raw IndexError out of _purge_excess
# (cla.py:271), or - worse - a silently wrong portfolio.
# ---------------------------------------------------------------------------
mu_eq = np.array([0.1, 0.1])
S_eq = np.array([[0.04, 0.01], [0.01, 0.04]])
try:
    w = np.array(list(CLA(mu_eq, S_eq).max_sharpe().values()))
    ok = False
    detail = "returned {} (Sharpe {:.6f}); the optimum is [0.5, 0.5] (Sharpe {:.6f})".format(
        np.round(w, 8).tolist(), sharpe(w, mu_eq, S_eq), sharpe([0.5, 0.5], mu_eq, S_eq)
    )
except ValueError as e:
    ok, detail = True, "ValueError: {}".format(str(e)[:70])
except Exception as e:
    ok, detail = False, "raw {}: {}".format(type(e).__name__, str(e)[:70])
check("P4", "equal expected returns fail loudly, not silently wrong", ok, detail)

rng = np.random.default_rng(3)
kinds = {"clear ValueError": 0, "raw TypeError": 0, "raw IndexError": 0, "returned a value": 0}
wrong = 0
for _ in range(300):
    n = int(rng.integers(2, 7))
    S = random_problem(rng, n)
    mu = np.full(n, 0.1)
    try:
        w = np.array(list(CLA(mu, S).max_sharpe().values()))
        kinds["returned a value"] += 1
        # equal expected returns => max Sharpe is exactly the min-variance portfolio
        w_ref = np.array(list(EfficientFrontier(mu, S).min_volatility().values()))
        if sharpe(w, mu, S) < sharpe(w_ref, mu, S) * (1 - 1e-6):
            wrong += 1
    except ValueError:
        kinds["clear ValueError"] += 1
    except TypeError:
        kinds["raw TypeError"] += 1
    except IndexError:
        kinds["raw IndexError"] += 1
check(
    "P4b",
    "no equal-mu problem yields a raw exception or a wrong portfolio",
    kinds["raw TypeError"] == 0 and kinds["raw IndexError"] == 0 and wrong == 0,
    "over 300 synthetic equal-mu problems: {}; of those that returned, "
    "{} were strictly worse than the true optimum".format(kinds, wrong),
)

# ---------------------------------------------------------------------------
# P5 - singular positive semidefinite covariance (issue 737).
# Perfectly collinear assets give a valid PSD covariance that CLA cannot
# invert. cla.py:342/357/374/386 call np.linalg.inv unguarded, so the user gets
# numpy.linalg.LinAlgError("Singular matrix") from a private helper.
# ---------------------------------------------------------------------------
mu_s = np.array([0.1, 0.12, 0.08])
S_s = np.array([[0.04, 0.04, 0.01], [0.04, 0.04, 0.01], [0.01, 0.01, 0.09]])
assert min(np.linalg.eigvalsh(S_s)) > -1e-12, "S_s must be PSD"
assert abs(np.linalg.det(S_s)) < 1e-12, "S_s must be singular"
try:
    CLA(mu_s, S_s).max_sharpe()
    ok, detail = False, "no exception raised"
except np.linalg.LinAlgError as e:
    ok, detail = False, "raw numpy.linalg.LinAlgError: {}".format(e)
except ValueError as e:
    ok = "singular" in str(e).lower() and "collinear" in str(e).lower()
    detail = "ValueError: {}...".format(str(e)[:60])
except Exception as e:
    ok, detail = False, "{}: {}".format(type(e).__name__, e)
check("P5", "singular PSD covariance gets an actionable error", ok, detail)

# ---------------------------------------------------------------------------
# P6 - NaN propagates through CLA into the weights, silently.
# EfficientFrontier rejects the same input. CLA did not, so a covariance matrix
# with a NaN (a price history with a zero or a gap yields one) produced a
# portfolio containing a NaN weight with no warning at all.
# ---------------------------------------------------------------------------
S_nan = np.array([[0.04, 0.01, 0.005], [0.01, np.nan, 0.002], [0.005, 0.002, 0.16]])
with warnings.catch_warnings(record=True) as caught:
    warnings.simplefilter("always")
    try:
        w = list(CLA(np.array([0.1, 0.12, 0.08]), S_nan).max_sharpe().values())
        ok = False
        detail = "returned {} with {} warning(s)".format(
            np.round(w, 6).tolist(), len(caught)
        )
    except ValueError as e:
        ok, detail = True, "ValueError: {}".format(str(e)[:70])
    except Exception as e:
        ok, detail = False, "raw {}: {}".format(type(e).__name__, str(e)[:70])
check("P6", "NaN in the covariance is rejected, not turned into NaN weights", ok, detail)

# ---------------------------------------------------------------------------
# P7 - CovarianceShrinkage records a missing return as a 0% return, silently.
# The shrinkage estimators pass self.X through np.nan_to_num
# (risk_models.py:532/556/613/666), so an asset that was not yet listed reads
# as an asset that did not move. self.S, on the same object, uses pandas'
# pairwise deletion instead, so the two disagree. The patch does not change the
# numbers - choosing the estimator's NaN convention is the maintainer's call -
# it makes the dilution visible.
# ---------------------------------------------------------------------------
rng = np.random.default_rng(11)
rets_full = pd.DataFrame(rng.normal(0, 0.02, size=(500, 3)), columns=list("ABC"))
rets_gap = rets_full.copy()
rets_gap.iloc[100:350, 1] = np.nan  # B missing 50 pct of its history

with warnings.catch_warnings(record=True) as caught:
    warnings.simplefilter("always")
    v_full = float(
        risk_models.CovarianceShrinkage(rets_full, returns_data=True).ledoit_wolf().loc["B", "B"]
    )
    n_before = len(caught)
    v_gap = float(
        risk_models.CovarianceShrinkage(rets_gap, returns_data=True).ledoit_wolf().loc["B", "B"]
    )
    warned = len(caught) > n_before
bias = 100 * (1 - v_gap / v_full)
check(
    "P7",
    "shrinkage estimators warn when returns are missing",
    warned,
    "B's annualised variance falls from {:.6f} to {:.6f} ({:.1f} pct understated) "
    "with 50 pct of its history missing; warned = {}".format(v_full, v_gap, bias, warned),
)

# ---------------------------------------------------------------------------
# P8 - a non-positive-semidefinite covariance reaches the user as
# cvxpy.error.SolverError whose entire message is a solver status code.
# The precondition is documented; the message is not actionable.
# ---------------------------------------------------------------------------
S_neg = np.diag([-0.04, -0.09, -0.16])
try:
    EfficientFrontier(np.array([0.1, 0.12, 0.08]), S_neg).min_volatility()
    ok, detail = False, "no exception raised"
except Exception as e:
    name = type(e).__module__.split(".")[0] + "." + type(e).__name__
    ok = type(e).__module__.startswith("pypfopt")
    detail = "{}: {}".format(name, str(e)[:70])
check("P8", "non-PSD covariance raises a pypfopt error, not a raw solver code", ok, detail)

# ---------------------------------------------------------------------------
# N1 - CLA is NOT non-deterministic. Issue 738's title claims it is. Identical
# input, repeated in-process and across interpreters with different
# PYTHONHASHSEED values, gives byte-identical output. This item passes at HEAD
# and after the patch; the lead does not reproduce.
# ---------------------------------------------------------------------------
rng = np.random.default_rng(7)
distinct = 1
for _ in range(20):
    n = int(rng.integers(3, 8))
    S = random_problem(rng, n)
    mu = rng.normal(0.08, 0.05, size=n)
    outs = set()
    for _ in range(20):
        try:
            outs.add(tuple(np.round(list(CLA(mu, S).max_sharpe().values()), 14)))
        except Exception as e:
            outs.add("EXC" + type(e).__name__)
    distinct = max(distinct, len(outs))
check(
    "N1",
    "CLA is deterministic in-process (lead did not reproduce)",
    distinct == 1,
    "20 synthetic problems x 20 repeats: max {} distinct outcome(s)".format(distinct),
)

_CROSS = """
import numpy as np
from pypfopt.cla import CLA
rng = np.random.default_rng(7)
out = []
for _ in range(20):
    n = int(rng.integers(3, 8))
    A = rng.normal(size=(n + 6, n))
    S = np.cov(A, rowvar=False)
    mu = rng.normal(0.08, 0.05, size=n)
    try:
        out.append(tuple(np.round(list(CLA(mu, S).max_sharpe().values()), 14)))
    except Exception as e:
        out.append('EXC' + type(e).__name__)
print(repr(out))
"""
import os

seen = set()
for seed in ["0", "1", "12345", "99"]:
    env = dict(os.environ, PYTHONHASHSEED=seed)
    r = subprocess.run([sys.executable, "-c", _CROSS], capture_output=True, text=True, env=env)
    seen.add(r.stdout.strip())
check(
    "N1b",
    "CLA is deterministic across PYTHONHASHSEED values (lead did not reproduce)",
    len(seen) == 1,
    "4 hash seeds: {} distinct result set(s)".format(len(seen)),
)

# ---------------------------------------------------------------------------
# N2 - the fix implied by issue 738's diagnosis is the WRONG fix. Guarding the
# raw lam with _infnone, so the TypeError goes away, converts loud crashes into
# silently wrong portfolios. Recorded so the finding is checkable rather than
# asserted. This item passes before and after the patch.
# ---------------------------------------------------------------------------
class _CLAInfnoneOnly(CLA):
    """cla.py:367-368 with _infnone applied to lam, and nothing else changed."""

    def _solve(self):
        f, w = self._init_algo()
        self.w.append(np.copy(w))
        self.ls.append(None)
        self.g.append(None)
        self.f.append(f[:])
        while True:
            l_in = None
            if len(f) > 1:
                covarF, covarFB, meanF, wB = self._get_matrices_compat(f, w)
                covarF_inv = np.linalg.inv(covarF)
                for j, i in enumerate(f):
                    lam, bi = self._compute_lambda(
                        covarF_inv, covarFB, meanF, wB, j, [self.lB[i], self.uB[i]]
                    )
                    if CLA._infnone(lam) > CLA._infnone(l_in):
                        l_in, i_in, bi_in = lam, i, bi
            l_out = None
            if len(f) < self.mean.shape[0]:
                for i in self._get_b(f):
                    covarF, covarFB, meanF, wB = self._get_matrices_compat(f + [i], w)
                    covarF_inv = np.linalg.inv(covarF)
                    lam, bi = self._compute_lambda(
                        covarF_inv, covarFB, meanF, wB, meanF.shape[0] - 1, self.w[-1][i]
                    )
                    if (
                        self.ls[-1] is None or CLA._infnone(lam) < self.ls[-1]
                    ) and CLA._infnone(lam) > CLA._infnone(l_out):
                        l_out, i_out = lam, i
            if (l_in is None or l_in < 0) and (l_out is None or l_out < 0):
                self.ls.append(0)
                covarF, covarFB, meanF, wB = self._get_matrices_compat(f, w)
                covarF_inv = np.linalg.inv(covarF)
                meanF = np.zeros(meanF.shape)
            else:
                if CLA._infnone(l_in) > CLA._infnone(l_out):
                    self.ls.append(l_in)
                    f.remove(i_in)
                    w[i_in] = bi_in
                else:
                    self.ls.append(l_out)
                    f.append(i_out)
                covarF, covarFB, meanF, wB = self._get_matrices_compat(f, w)
                covarF_inv = np.linalg.inv(covarF)
            wF, g = self._compute_w(covarF_inv, covarFB, meanF, wB)
            for i in range(len(f)):
                w[f[i]] = wF[i]
            self.w.append(np.copy(w))
            self.g.append(g)
            self.f.append(f[:])
            if self.ls[-1] == 0:
                break
        self._purge_num_err(10e-10)
        if len(self.w) > 1:
            self._purge_excess()

    def _get_matrices_compat(self, f, w):
        """_get_matrices gained a second parameter in fixes.patch; call either."""
        try:
            return self._get_matrices(f, w)
        except TypeError:
            return self._get_matrices(f)


rng = np.random.default_rng(3)
returned = silently_wrong = 0
worst_naive = 0.0
for _ in range(300):
    n = int(rng.integers(2, 7))
    S = random_problem(rng, n)
    mu = np.full(n, 0.1)
    try:
        w = np.array(list(_CLAInfnoneOnly(mu, S).max_sharpe().values()))
    except Exception:
        continue
    returned += 1
    w_ref = np.array(list(EfficientFrontier(mu, S).min_volatility().values()))
    r = sharpe(w, mu, S) / sharpe(w_ref, mu, S)
    if r < 1 - 1e-6:
        silently_wrong += 1
        worst_naive = max(worst_naive, 100 * (1 - r))
check(
    "N2",
    "the _infnone-only fix is worse than the crash (recorded, not adopted)",
    silently_wrong > 0,
    "it returns on {}/300 equal-mu problems and {} of those are silently "
    "suboptimal, worst {:.1f} pct of Sharpe".format(returned, silently_wrong, worst_naive),
)

print()
print("{}/{} checks passed".format(sum(RESULTS), len(RESULTS)))
raise SystemExit(0 if all(RESULTS) else 1)
