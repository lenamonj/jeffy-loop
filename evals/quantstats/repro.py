#!/usr/bin/env python
"""
Reproduction script for the Jeffy audit of ranaroussi/quantstats.

Target: ranaroussi/quantstats at HEAD fbd10daed0227aa0d10da6513f1b15e7e98d7fae
(quantstats 0.0.81, released 2026-01-13).

Fully offline. Every series is synthetic and every expectation is a closed form
or an exact identity, so no market data and no network access are needed.

Each QS-* check asserts the CORRECTED behaviour and prints the value observed at
upstream HEAD alongside it. Run against upstream HEAD, every QS-* check FAILs and
prints the HEAD number that made it fail; run against this eval's fixes.patch,
all checks PASS. The N-* checks are leads that did NOT reproduce, or that are
defensible conventions rather than defects; they assert the observation that
establishes that verdict and pass in both directions.

Usage:  python repro.py
Exit code 0 if every check passes.

Requires: quantstats, pandas, numpy, scipy.
"""

import sys
import warnings

import numpy as np
import pandas as pd
from scipy.optimize import brentq

import quantstats as qs

warnings.filterwarnings("ignore")

RESULTS = []
HEAD = "fbd10daed0227aa0d10da6513f1b15e7e98d7fae"


def safe(fn, *args, **kwargs):
    """Call fn, returning the exception text instead of propagating it.

    Several fixes widen a public signature. Against upstream HEAD the call
    raises TypeError; recording that as the observed value lets every check
    report FAIL with its own evidence rather than aborting the run.
    """
    try:
        return fn(*args, **kwargs)
    except Exception as exc:
        return f"raised {type(exc).__name__}: {exc}"


def check(ident, title, expected, actual, head_value=None, rtol=1e-9, note=None):
    """Record one check. expected/actual may be floats, bools or strings."""
    if isinstance(expected, bool) or isinstance(actual, bool):
        ok = bool(expected) == bool(actual)
    elif isinstance(expected, str) or isinstance(actual, str):
        ok = str(expected) == str(actual)
    else:
        ok = np.isclose(float(expected), float(actual), rtol=rtol, atol=0.0)
    RESULTS.append((ident, title, ok))
    print(f"[{'PASS' if ok else 'FAIL'}] {ident}  {title}")
    print(f"         expected : {expected}")
    print(f"         actual   : {actual}")
    if head_value is not None:
        print(f"         at HEAD  : {head_value}")
    if note:
        print(f"         note     : {note}")
    print()


# --------------------------------------------------------------------------
# synthetic series builders
# --------------------------------------------------------------------------
def daily(n=252 * 10, mu=0.0004, sig=0.01, seed=1):
    rng = np.random.default_rng(seed)
    return pd.Series(rng.normal(mu, sig, n), index=pd.bdate_range("2015-01-01", periods=n))


def monthly(n=132, mu=0.006, sig=0.035, seed=4):
    rng = np.random.default_rng(seed)
    return pd.Series(rng.normal(mu, sig, n), index=pd.date_range("2015-01-31", periods=n, freq="ME"))


def binary(p, win, loss, n=100000, seed=3):
    """Two-outcome series: +win with probability p, -loss otherwise."""
    rng = np.random.default_rng(seed)
    x = np.where(rng.random(n) < p, win, -loss)
    return pd.Series(x, index=pd.bdate_range("1990-01-01", periods=n))


def growth_optimal(r):
    """Exact growth-optimal fraction: root of E[r/(1+f r)] = 0."""
    r = np.asarray(r, dtype=float)
    hi = 1.0 / abs(r.min())
    return brentq(lambda f: np.mean(r / (1 + f * r)), 0.0, hi * (1 - 1e-12), xtol=1e-14)


print("=" * 78)
print("quantstats audit - reproduction")
print(f"installed quantstats {qs.__version__} | pandas {pd.__version__} | numpy {np.__version__}")
print(f"upstream HEAD under audit: {HEAD}")
print("=" * 78)
print()

# ==========================================================================
# QS-1  kelly_criterion returns the growth-optimal fraction scaled by the
#       average loss, because the textbook two-outcome form assumes a losing
#       bet forfeits 100% of the stake.
# ==========================================================================
print("--- QS-1  kelly_criterion (stats.py:2553, issue 535) ---\n")

for p, w, loss, head in [(0.60, 0.02, 0.01, 0.399985),
                         (0.55, 0.01, 0.01, 0.099640),
                         (0.60, 0.20, 0.10, 0.399985)]:
    s = binary(p, w, loss)
    ph = (s > 0).mean()
    exact = ph / loss - (1 - ph) / w          # closed form for a two-outcome bet
    check(
        "QS-1", f"two-outcome series p={p} win=+{w:.0%} loss=-{loss:.0%}: growth-optimal f",
        expected=exact, actual=qs.stats.kelly_criterion(s), head_value=head, rtol=1e-6,
        note=f"HEAD answer is the exact one multiplied by the loss magnitude ({loss}); ratio 1/{loss} = {1/loss:g}",
    )

base = daily()
for scale, head in [(1.0, 0.03554685), (0.5, 0.03554685), (0.1, 0.03554685)]:
    s = base * scale
    check(
        "QS-1", f"10y daily series scaled by {scale}: growth-optimal f scales as 1/{scale}",
        expected=growth_optimal(s.values), actual=qs.stats.kelly_criterion(s),
        head_value=head, rtol=1e-6,
        note="HEAD returns the same number for all three scales: a leverage recommendation invariant to the size of the losses",
    )

# ==========================================================================
# QS-2  rar() dropped the periods-per-year argument and always annualized at
#       252, while the CAGR row two lines above it in the same table used the
#       report's periods_per_year.
# ==========================================================================
print("--- QS-2  rar() vs cagr() periods-per-year (stats.py:1561, reports.py:1444, issue 516 family) ---\n")

m = monthly()
cagr12 = qs.stats.cagr(m, 0.0, True, 12)
check(
    "QS-2", "11y monthly series: rar(periods=12) equals cagr(periods=12)/exposure",
    expected=cagr12 / qs.stats.exposure(m), actual=safe(qs.stats.rar, m, 0.0, 12),
    head_value="rar() had no periods argument; rar(m) = 5.079452491926482 vs cagr = 0.08975000448300419 (56.60x)",
    note="exposure is 1.0 here, so the two must be equal",
)

t = safe(qs.reports.metrics, m, benchmark=None, mode="full", periods_per_year=12,
         display=False, prepare_returns=False, internal=True)


def row(frame, name):
    if isinstance(frame, str):
        return frame
    key = next(i for i in frame.index if i.startswith(name))
    return frame.loc[key].iloc[0]


check(
    "QS-2", "reports.metrics(periods_per_year=12): CAGR row equals Risk-Adjusted Return row",
    expected=row(t, "CAGR"), actual=row(t, "Risk-Adjusted Return"),
    head_value="CAGR 8.98% vs Risk-Adjusted Return 507.95% in the same table",
)

# ==========================================================================
# QS-3  the risk-free rate was routed by caller name (inspect.stack), so cagr
#       and gain_to_pain_ratio silently discarded it; and `if rf > 0` discarded
#       negative rates everywhere.
# ==========================================================================
print("--- QS-3  rf silently discarded (utils.py:610/641) ---\n")

r = daily(seed=21)
c0, c5 = qs.stats.cagr(r, rf=0.0), qs.stats.cagr(r, rf=0.05)
check(
    "QS-3", "cagr() honours rf: cagr(rf=0.05) is strictly below cagr(rf=0)",
    expected=True, actual=bool(c5 < c0 - 1e-12),
    head_value="cagr(rf=0.00) == cagr(rf=0.05) == cagr(rf=0.50) == 0.2163540607973844",
    note=f"this build: cagr(rf=0)={c0:.10f}  cagr(rf=0.05)={c5:.10f}",
)

g0, g5 = qs.stats.gain_to_pain_ratio(r, rf=0.0), qs.stats.gain_to_pain_ratio(r, rf=0.05)
check(
    "QS-3", "gain_to_pain_ratio() honours rf",
    expected=True, actual=bool(float(g5) < float(g0) - 1e-12),
    head_value="g2p(rf=0.00) == g2p(rf=0.05) == 0.23518822033805786",
    note=f"this build: g2p(rf=0)={g0:.10f}  g2p(rf=0.05)={g5:.10f}",
)

rneg = daily(n=252 * 8, seed=17)
s0, sneg = qs.stats.sharpe(rneg, 0.0), qs.stats.sharpe(rneg, -0.005)
check(
    "QS-3", "negative rf raises the excess return: sharpe(rf=-0.5%) exceeds sharpe(rf=0)",
    expected=True, actual=bool(sneg > s0 + 1e-12),
    head_value="sharpe(rf=0) == sharpe(rf=-0.005) == sharpe(rf=-0.02) == 0.62583574 (`if rf > 0`)",
    note=f"this build: sharpe(rf=0)={s0:.8f}  sharpe(rf=-0.005)={sneg:.8f}",
)

# ==========================================================================
# QS-4  aggregate_returns silently ignored the documented codes 'M','Q','Y'
#       and raised AttributeError on 'W'.
# ==========================================================================
print("--- QS-4  aggregate period codes (utils.py:443-507, 12 documented call sites) ---\n")

ra = daily(seed=41)
for short, long, head in [("M", "ME", 0.035997), ("Q", "QE", 0.035997), ("Y", "YE", 0.035997)]:
    check(
        "QS-4", f"best(returns, aggregate='{short}') equals best(returns, aggregate='{long}')",
        expected=qs.stats.best(ra, aggregate=long), actual=qs.stats.best(ra, aggregate=short),
        head_value=f"'{short}' fell through every branch and returned the unaggregated series: {head} (the best DAY)",
        rtol=1e-9,
    )

try:
    w = qs.utils.aggregate_returns(ra, "W")
    weekly_ok, weekly_n = True, len(w)
except Exception as exc:
    weekly_ok, weekly_n = False, f"{type(exc).__name__}: {exc}"
check(
    "QS-4", "aggregate_returns(returns, 'W') aggregates instead of raising",
    expected=True, actual=weekly_ok,
    head_value="AttributeError: 'DatetimeIndex' object has no attribute 'week' (removed in pandas 2.0)",
    note=f"this build produced {weekly_n} weekly buckets from {len(ra)} daily observations",
)

try:
    qs.utils.aggregate_returns(ra, "not-a-period")
    loud = False
except ValueError:
    loud = True
check(
    "QS-4", "an unrecognised period code raises instead of silently returning daily data",
    expected=True, actual=loud,
    head_value="returned the unaggregated series",
)

# ==========================================================================
# QS-5  treynor_ratio's documented `periods` argument had no effect, and the
#       numerator was the whole-sample cumulative return.
# ==========================================================================
print("--- QS-5  treynor_ratio periods argument (stats.py:1355-1391) ---\n")

rt, bt = daily(seed=31), daily(mu=0.0003, sig=0.008, seed=32)
t252, t12 = qs.stats.treynor_ratio(rt, bt, periods=252), qs.stats.treynor_ratio(rt, bt, periods=12)
check(
    "QS-5", "treynor_ratio responds to its documented `periods` argument",
    expected=True, actual=bool(abs(t252 - t12) > 1e-9),
    head_value="periods=252 == periods=12 == periods=1 == -52.05502714897246",
    note=f"this build: periods=252 -> {t252:.10f}   periods=12 -> {t12:.10f}",
)
check(
    "QS-5", "treynor numerator is annualized, not the 10-year cumulative return",
    expected=qs.stats.cagr(rt, 0.0, periods=252) / qs.stats.greeks(rt, bt)["beta"],
    actual=safe(qs.stats.treynor_ratio, rt, bt, periods=252),
    head_value=f"comp(returns) = {qs.stats.comp(rt):.10f} (cumulative over the whole sample) was used",
    rtol=1e-9,
)

# ==========================================================================
# QS-6  probabilistic_ratio(annualize=True) multiplied a probability by
#       sqrt(252), hardcoded, ignoring `periods`.
# ==========================================================================
print("--- QS-6  probabilistic_ratio annualize (stats.py:1252-1253) ---\n")

rp = daily(seed=5)
psr = qs.stats.probabilistic_sharpe_ratio(rp, 0.0, 252, True)
check(
    "QS-6", "probabilistic_sharpe_ratio stays a probability in [0, 1] when annualize=True",
    expected=True, actual=bool(0.0 <= psr <= 1.0),
    head_value="15.852114 (= 0.998589 * sqrt(252)), identical for periods=12 and periods=252",
    note=f"this build: {psr:.10f}",
)

# ==========================================================================
# QS-7  rolling_greeks' alpha used the full-sample mean at every point.
# ==========================================================================
print("--- QS-7  rolling_greeks alpha (stats.py:2776) ---\n")

rg = qs.stats.rolling_greeks(rt, bt, periods=252)
recon = (rg["alpha"] + rg["beta"] * bt.mean()).dropna()
check(
    "QS-7", "rolling alpha is not reconstructible from the full-sample mean",
    expected=False, actual=bool(np.allclose(recon.values, rt.mean())),
    head_value="alpha_t + beta_t * benchmark.mean() == returns.mean() for every t (whole-sample mean, future data included)",
)

# ==========================================================================
# QS-8  "total return" inside ratios was compounded in some functions and
#       arithmetically summed in others.
# ==========================================================================
print("--- QS-8  compounding convention for total return (stats.py:2357 vs 1732) ---\n")

rc = daily(seed=1)
mdd = qs.stats.max_drawdown(rc)
check(
    "QS-8", "recovery_factor compounds its numerator, matching the compounded drawdown denominator",
    expected=abs(qs.stats.comp(rc)) / abs(mdd), actual=qs.stats.recovery_factor(rc),
    head_value=f"used returns.sum() = {rc.sum():.10f} against comp() = {qs.stats.comp(rc):.10f}, "
               f"a {100*(qs.stats.comp(rc)/rc.sum()-1):.1f}% gap on this series",
    rtol=1e-9,
)
check(
    "QS-8", "recovery_factor(compounded=False) still offers the arithmetic convention",
    expected=abs(rc.sum()) / abs(mdd), actual=safe(qs.stats.recovery_factor, rc, compounded=False),
    rtol=1e-9,
)

# ==========================================================================
# QS-9  3Y/5Y/10Y windows disagreed with each other (issue 516).
# ==========================================================================
print("--- QS-9  3Y/5Y/10Y annualized-return windows (reports.py:1548-1561, issue 516) ---\n")

import inspect  # noqa: E402
import re  # noqa: E402
from dateutil.relativedelta import relativedelta  # noqa: E402

# Read the three window offsets straight out of reports.metrics so this check
# binds to the shipped code rather than to a restatement of it.
src = inspect.getsource(qs.reports.metrics)
found = re.findall(
    r"d = today - relativedelta\((years|months)=(\d+)\)\s*\n\s*metrics\[\"(\d+)Y \(ann\.\) %\"\]",
    src,
)
offsets = {int(lab): (int(num) * 12 if unit == "years" else int(num)) for unit, num, lab in found}
resid = {lab: offsets[lab] - lab * 12 for lab in offsets}
check(
    "QS-9", "3Y, 5Y and 10Y windows in reports.metrics share one offset convention",
    expected=True,
    actual=bool(len(offsets) == 3 and len(set(resid.values())) == 1),
    head_value="3Y=35 months, 5Y=59 months, 10Y=relativedelta(years=10)=120 months -> "
               "offsets of -1, -1 and 0 months against their labels",
    note=f"this build: months offsets {offsets}, residual against label {resid}",
)

rw = daily(n=252 * 15, seed=2)
today = rw.index[-1]
spans = {}
for lab, months in sorted(offsets.items()):
    w = rw[rw.index >= today - relativedelta(months=months)]
    spans[f"{lab}Y"] = (w.index[-1] - w.index[0]).days / 365.25
check(
    "QS-9", "the realised calendar spans of the three windows sit the same distance below their labels",
    expected=True,
    actual=bool(max(spans[f"{k}Y"] - k for k in offsets) - min(spans[f"{k}Y"] - k for k in offsets) < 0.02),
    head_value="spans were 2.919y / 4.917y / 9.996y against labels 3 / 5 / 10",
    note="this build spans: " + ", ".join(f"{k}={v:.3f}y" for k, v in spans.items()),
)

# ==========================================================================
# QS-10 information_ratio was not annualized while sharpe() in the same module
#       and the same tearsheet row block was.
# ==========================================================================
print("--- QS-10  information_ratio annualization (stats.py:2635, issue 514 family) ---\n")

ri = daily(seed=11)
zero = pd.Series(0.0, index=ri.index)
ir = safe(qs.stats.information_ratio, ri, zero)
sh = qs.stats.sharpe(ri, 0.0, 252, True)
check(
    "QS-10", "against a zero benchmark the information ratio equals the annualized Sharpe",
    expected=sh, actual=ir,
    head_value=f"IR = 0.047640 vs Sharpe = 0.756265; the ratio was exactly sqrt(252) = {np.sqrt(252):.6f}",
    rtol=1e-9,
)
check(
    "QS-10", "information_ratio(annualize=False) still exposes the per-period ratio",
    expected=qs.stats.sharpe(ri, 0.0, 252, False),
    actual=safe(qs.stats.information_ratio, ri, zero, annualize=False),
    rtol=1e-9,
)

# ==========================================================================
# Leads that did NOT reproduce, or that are defensible conventions.
# These pass against upstream HEAD and against the patched build alike.
# ==========================================================================
print("=" * 78)
print("LEADS THAT DID NOT REPRODUCE, OR ARE DEFENSIBLE CONVENTIONS")
print("=" * 78)
print()

# N-1  issue 514: arithmetic vs geometric active return.
ra1, rb1 = daily(seed=11), daily(mu=0.0003, sig=0.009, seed=12)
arith = (ra1 - rb1).mean()
geo = (1 + ra1).prod() ** (1 / len(ra1)) - (1 + rb1).prod() ** (1 / len(rb1))
check(
    "N-1", "issue 514: arithmetic active return differs from geometric, as the reporter says",
    expected=True, actual=bool(abs(arith - geo) / abs(geo) > 0.10),
    note=f"arithmetic {arith:.10f} vs geometric {geo:.10f}, a {100*(arith-geo)/abs(geo):.2f}% gap on 10y of daily data. "
         "NOT FILED AS A DEFECT: the arithmetic difference returns - benchmark is the standard Grinold-Kahn "
         "active-return convention and is what the docstring describes. A defensible-but-different convention "
         "is not a defect. The defect in this function was the missing annualization (QS-10).",
)

# N-2  issue 518: EOY returns vs benchmark over ranges longer than 10 years.
import matplotlib  # noqa: E402
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

mismatches = []
for span in (8.5, 9.5, 10.5, 12.5):
    n = int(252 * span)
    idx = pd.bdate_range("2010-01-04", periods=n)
    rr = pd.Series(np.random.default_rng(2).normal(0.0005, 0.011, n), index=idx)
    bb = pd.Series(np.random.default_rng(3).normal(0.0004, 0.010, n), index=idx)
    fig = qs.plots.yearly_returns(rr, bb, show=False, savefig=None)
    ax = fig.axes[0]
    ticks = [t.get_text() for t in ax.get_xticklabels()]
    n_bars = [len(c) for c in ax.containers]
    n_years = len(sorted(set(idx.year)))
    if ticks != [str(y) for y in sorted(set(idx.year))] or set(n_bars) != {n_years}:
        mismatches.append((span, ticks, n_bars))
    plt.close(fig)
check(
    "N-2", "issue 518: EOY-vs-benchmark bar labels over 10y+ ranges",
    expected=0, actual=len(mismatches),
    note="NOT REPRODUCED. At 8.5y, 9.5y, 10.5y and 12.5y the x tick labels and both bar containers all carry "
         "exactly one entry per calendar year, in order. The sparsification branch at _plotting/core.py:273 "
         "computes mod = int(len(years)/10), which is 1 for 11-19 years, so every label is drawn; and pandas "
         "places bar categories at 0..n-1, which is exactly what the np.arange(len(years)) override supplies. "
         "At 21 years mod becomes 2 and every second label is deliberately blanked, still correctly aligned.",
)

# N-3  issue 493: trade-analysis metrics computed from returns.
r3 = daily(seed=51)
check(
    "N-3", "issue 493: payoff_ratio is exactly avg_win / |avg_loss| of the return series",
    expected=r3[r3 > 0].mean() / abs(r3[r3 < 0].mean()), actual=qs.stats.payoff_ratio(r3),
    rtol=1e-12,
    note="NOT FILED AS A DEFECT: these are period statistics computed correctly as period statistics. The "
         "maintainer's own reply on 493 states this is by design for a returns-analysis library. The naming "
         "question is a scope decision for the owner, not an arithmetic defect. The one metric in that list "
         "that IS arithmetically wrong independently of the trade-vs-returns question is Kelly (QS-1).",
)
check(
    "N-3", "issue 493: profit_factor is exactly sum(wins) / |sum(losses)|",
    expected=r3[r3 >= 0].sum() / abs(r3[r3 < 0].sum()), actual=qs.stats.profit_factor(r3),
    rtol=1e-12,
)

# N-4  cagr's denominator is observation count / periods, not calendar time.
cal = pd.date_range("2015-01-01", periods=365 * 5, freq="D")
rc4 = pd.Series(0.0002, index=cal)
check(
    "N-4", "cagr uses len(returns)/periods, which is exact when periods matches the data frequency",
    expected=(1.0002 ** 365) - 1, actual=qs.stats.cagr(rc4, 0.0, True, 365), rtol=1e-12,
    note=f"NOT FILED AS A DEFECT: self-documented at stats.py:1545-1547 and consistent with sharpe/sortino. "
         f"The same series at the 252 default gives {qs.stats.cagr(rc4, 0.0, True, 252):.10f} against the exact "
         f"{(1.0002 ** 365) - 1:.10f} - that is the caller's periods argument doing exactly what it says.",
)

# N-5  sortino divides the downside deviation by N while sharpe uses ddof=1.
r5 = daily(seed=61)
downside = np.sqrt((r5[r5 < 0] ** 2).sum() / len(r5))
check(
    "N-5", "sortino divides the downside sum of squares by N, sharpe's std uses ddof=1",
    expected=r5.mean() / downside * np.sqrt(252), actual=qs.stats.sortino(r5, 0, 252, True), rtol=1e-12,
    note="NOT FILED AS A DEFECT: dividing by the full N is the convention in the Red Rock Capital paper the "
         "sortino docstring cites (stats.py:1015-1016), while ddof=1 is correct for a sample standard "
         "deviation. Two different conventions for two different statistics is not an inconsistency.",
)

# N-6  greeks annualizes alpha linearly while cagr annualizes geometrically.
check(
    "N-6", "greeks() annualizes alpha by multiplying by periods",
    expected=(rt.mean() - qs.stats.greeks(rt, bt)["beta"] * bt.mean()) * 252,
    actual=qs.stats.greeks(rt, bt, periods=252)["alpha"], rtol=1e-9,
    note="NOT FILED AS A DEFECT: linear annualization of Jensen's alpha is the standard convention, and it "
         "differing from cagr's geometric annualization is a difference between two statistics, not an error.",
)

# --------------------------------------------------------------------------
print("=" * 78)
passed = sum(1 for _, _, ok in RESULTS if ok)
print(f"{passed}/{len(RESULTS)} checks passed")
for ident, title, ok in RESULTS:
    if not ok:
        print(f"  FAILED: {ident}  {title}")
print("=" * 78)
sys.exit(0 if passed == len(RESULTS) else 1)
