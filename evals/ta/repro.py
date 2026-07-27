"""Offline reproduction for the bukosabino/ta audit.

Every check is deterministic and needs no network and no data file. Run it
against a clone of bukosabino/ta:

    python repro.py --repo /path/to/ta          # or set TA_REPO
    python repro.py                             # uses an installed `ta`

At upstream HEAD a890410710a6e483c9ba08da7f3dd5089e4b9dff every check below
FAILs. With fixes.patch applied, every check PASSes. Exit status is the number
of failing checks.

Requires pandas and numpy. Verified on pandas 3.0.5 / numpy 2.5.1 and on
pandas 2.2.3, both CPython 3.13.8.
"""
import argparse
import os
import sys
import warnings

RESULTS = []


def check(name, ok, expected, actual, note=""):
    RESULTS.append((name, bool(ok)))
    print("[%s] %s" % ("PASS" if ok else "FAIL", name))
    print("       expected: %s" % expected)
    print("       actual  : %s" % actual)
    if note:
        print("       note    : %s" % note)
    print()


def synthetic(rows=300, seed=7):
    """Deterministic OHLC that looks like a price path."""
    rng = np.random.default_rng(seed)
    close = 100.0 * np.exp(np.cumsum(rng.normal(0.0, 0.012, rows)))
    spread = np.abs(rng.normal(0.0, 0.006, rows)) * close
    return close + spread, close - spread, close


def mismatch(left, right):
    return ~(
        np.isclose(left, right, rtol=1e-12, atol=1e-12)
        | (np.isnan(left) & np.isnan(right))
    )


# --------------------------------------------------------------------------
# TA-1  PSAR mixes label-based and positional writes on the same Series
#       ta/trend.py:1030 at HEAD - `self._psar[i] = high2` beside
#       `self._psar.iloc[i] = high1`.  Issue #354, issue #348.
# --------------------------------------------------------------------------
def ta_1_psar_index_semantics():
    from ta.trend import PSARIndicator

    rows = 300
    high, low, close = synthetic(rows)
    range_index = pd.RangeIndex(rows)
    datetime_index = pd.date_range("2020-01-01", periods=rows, freq="B")
    # what ta.utils.dropna leaves behind, and the README tells you to call it
    gapped_index = pd.Index([i * 3 + 7 for i in range(rows)])

    def psar(index):
        return PSARIndicator(
            pd.Series(high, index=index),
            pd.Series(low, index=index),
            pd.Series(close, index=index),
        ).psar()

    base = psar(range_index)
    for label, index in (("DatetimeIndex", datetime_index),
                         ("gapped integer index", gapped_index)):
        got = psar(index)
        if len(got) != rows:
            check(
                "TA-1 PSAR returns one row per input bar on a %s" % label,
                False,
                "%d rows out for %d rows in" % (rows, rows),
                "%d rows out - %d spurious rows appended, index dtype %s"
                % (len(got), len(got) - rows, got.index.dtype),
                "an integer loop counter was used as a pandas label, so the write "
                "enlarged the Series instead of updating row i",
            )
            continue
        bad = mismatch(base.to_numpy(dtype=float), got.to_numpy(dtype=float))
        worst = (
            float(np.nanmax(np.abs(got.to_numpy(dtype=float) - base.to_numpy(dtype=float))))
            if bad.any()
            else 0.0
        )
        check(
            "TA-1 PSAR returns one row per input bar on a %s" % label,
            not bad.any(),
            "identical to the RangeIndex result on all %d rows" % rows,
            "%d of %d rows differ, max absolute error %.6f" % (int(bad.sum()), rows, worst),
        )

    # values, once the lengths line up
    for label, index in (("DatetimeIndex", datetime_index),
                         ("gapped integer index", gapped_index)):
        got = psar(index)
        n = min(len(got), rows)
        bad = mismatch(base.to_numpy(dtype=float)[:n], got.to_numpy(dtype=float)[:n])
        a = base.to_numpy(dtype=float)[:n]
        b = got.to_numpy(dtype=float)[:n]
        first = int(np.argmax(bad)) if bad.any() else -1
        check(
            "TA-1 PSAR values are index-agnostic on a %s" % label,
            not bad.any(),
            "every row equal to the RangeIndex result",
            (
                "%d of %d rows differ; first at row %d: RangeIndex %.6f vs %s %.6f "
                "(%.4f%% off)"
                % (int(bad.sum()), n, first, a[first], label, b[first],
                   abs((b[first] - a[first]) / a[first]) * 100)
                if bad.any()
                else "all rows equal"
            ),
        )


# --------------------------------------------------------------------------
# TA-2  KST substitutes a whole-series mean for its missing warm-up history,
#       so 30 output rows are computed from prices that have not happened yet.
#       ta/trend.py:500-535 at HEAD - `fill_value=self._close.mean()`.
# --------------------------------------------------------------------------
def ta_2_kst_lookahead():
    from ta.trend import kst

    rows, cut = 400, 200
    _, _, close = synthetic(rows, seed=3)
    series = pd.Series(close)
    full = kst(series).to_numpy(dtype=float)[:cut]
    truncated = kst(series[:cut]).to_numpy(dtype=float)
    bad = mismatch(full, truncated)
    first = int(np.argmax(bad)) if bad.any() else -1
    check(
        "TA-2 KST row k does not depend on rows after k",
        not bad.any(),
        "the first %d rows are the same whether or not later bars exist" % cut,
        (
            "%d of %d rows change; first at row %d: %.6f with the full series vs "
            "%.6f without it" % (int(bad.sum()), cut, first, full[first], truncated[first])
            if bad.any()
            else "no row changes"
        ),
        "the warm-up rows were filled with close.mean() over the whole series",
    )

    # and the fabricated rows are not KST at all
    roc = lambda p: (series - series.shift(p)) / series.shift(p)
    reference = 100 * (
        roc(10).rolling(10, min_periods=10).mean()
        + 2 * roc(15).rolling(10, min_periods=10).mean()
        + 3 * roc(20).rolling(10, min_periods=10).mean()
        + 4 * roc(30).rolling(15, min_periods=15).mean()
    )
    got = kst(series)
    first_defined = int(np.argmax(reference.notna().to_numpy()))
    first_emitted = int(np.argmax(got.notna().to_numpy()))
    check(
        "TA-2 KST emits no value before its first defined bar",
        first_emitted == first_defined,
        "first non-NaN row %d (max(roc_i + window_i) - 1)" % first_defined,
        "first non-NaN row %d%s"
        % (
            first_emitted,
            (
                " - %d fabricated rows, e.g. row %d = %.6f where KST is undefined"
                % (first_defined - first_emitted, first_emitted, got.iloc[first_emitted])
                if first_emitted < first_defined
                else ""
            ),
        ),
    )


# --------------------------------------------------------------------------
# TA-3  ADX +DI / -DI never consume the seed element of _trs/_dip/_din, so the
#       bar at `window` comes back as 0.0.  ta/trend.py:828,849 at HEAD.
#       Issue #314.  Checked against the repo's own StockCharts reference.
# --------------------------------------------------------------------------
def ta_3_adx_warm_up_row(reference_dir):
    from ta.trend import adx_neg, adx_pos

    path = os.path.join(reference_dir, "test", "data", "cs-adx.csv")
    if not os.path.isfile(path):
        print("[SKIP] TA-3 needs test/data/cs-adx.csv from the repo; not found at %s\n" % path)
        return
    df = pd.read_csv(path)
    params = dict(high=df["High"], low=df["Low"], close=df["Close"], window=14,
                  fillna=False)
    for name, func, column in (("+DI14", adx_pos, "+DI14"), ("-DI14", adx_neg, "-DI14")):
        got = func(**params)
        expected = df[column]
        rows = np.flatnonzero(expected.notna().to_numpy())
        row = int(rows[0])
        ok = abs(float(got.iloc[row]) - float(expected[row])) < 1e-4
        check(
            "TA-3 ADX %s reports its first defined bar" % name,
            ok,
            "row %d = %.6f (StockCharts, test/data/cs-adx.csv)" % (row, expected[row]),
            "row %d = %.6f" % (row, got.iloc[row]),
            "0.0 is a legal reading, so a caller cannot tell this row apart from "
            "the zero padding before it",
        )


# --------------------------------------------------------------------------
# TA-4  Too-short input dies inside numpy with a message naming neither the
#       input nor the parameter.  ta/trend.py:807, ta/volatility.py:50.
# --------------------------------------------------------------------------
def ta_4_warm_up_preconditions():
    from ta.trend import ADXIndicator
    from ta.volatility import AverageTrueRange

    cases = [
        ("ADXIndicator", 27, lambda h, l, c: ADXIndicator(high=h, low=l, close=c, window=14).adx()),
        ("AverageTrueRange", 13,
         lambda h, l, c: AverageTrueRange(high=h, low=l, close=c, window=14).average_true_range()),
    ]
    for name, rows, build in cases:
        high, low, close = synthetic(rows, seed=5)
        try:
            build(pd.Series(high), pd.Series(low), pd.Series(close))
            actual = "no error raised"
            ok = False
        except ValueError as exc:
            actual = "ValueError: %s" % exc
            ok = name in str(exc) and "requires at least" in str(exc)
        except Exception as exc:  # noqa: BLE001 - the point is what leaks out
            actual = "%s: %s" % (type(exc).__name__, exc)
            ok = False
        check(
            "TA-4 %s refuses %d rows with a message naming itself" % (name, rows),
            ok,
            "ValueError naming %s, the row count and the requirement" % name,
            actual,
        )


# --------------------------------------------------------------------------
# TA-5  Bollinger ddof.  Issue #307 claims ddof=0 is wrong.  It is not: the
#       project's own StockCharts reference agrees with ddof=0.  This check
#       PASSes at HEAD - it is recorded so the claim is not relitigated.
# --------------------------------------------------------------------------
def ta_5_bollinger_ddof(reference_dir):
    path = os.path.join(reference_dir, "test", "data", "cs-bbands.csv")
    if not os.path.isfile(path):
        print("[SKIP] TA-5 needs test/data/cs-bbands.csv from the repo; not found at %s\n" % path)
        return
    from ta.volatility import BollingerBands

    df = pd.read_csv(path)
    close = df["Close"]
    expected = df["20-day Standard Deviation"]
    rows = expected.notna()
    population = close.rolling(20, min_periods=20).std(ddof=0)
    sample = close.rolling(20, min_periods=20).std(ddof=1)
    err0 = float((population[rows] - expected[rows]).abs().max())
    err1 = float((sample[rows] - expected[rows]).abs().max())
    band = BollingerBands(close=close, window=20, window_dev=2).bollinger_hband()
    errband = float((band[rows] - df["HighBand"][rows]).abs().max())
    check(
        "TA-5 Bollinger matches the population deviation, not the sample one",
        err0 < 1e-5 < err1 and errband < 1e-5,
        "ddof=0 within 1e-5 of the reference, ddof=1 further away",
        "ddof=0 max error %.3e, ddof=1 max error %.3e, library hband max error %.3e"
        % (err0, err1, errband),
        "issue #307 asks for ddof=1; that would widen every band by "
        "sqrt(20/19) = %.4f%% and break this reference"
        % ((np.sqrt(20 / 19) - 1) * 100),
    )


# --------------------------------------------------------------------------
# TA-6  psar_down_indicator is derived from _psar_up.  ta/trend.py:1086 at
#       HEAD.  It happens to agree with the intended definition because the
#       two series are disjoint; the check pins that it stays true.
# --------------------------------------------------------------------------
def ta_6_psar_down_indicator():
    from ta.trend import PSARIndicator

    high, low, close = synthetic(400, seed=3)
    indicator = PSARIndicator(pd.Series(high), pd.Series(low), pd.Series(close))
    down = indicator.psar_down()
    expected = (down.notnull() & down.shift(1).isnull()).astype(float)
    got = indicator.psar_down_indicator().astype(float)
    bad = int((expected.to_numpy() != got.to_numpy()).sum())
    check(
        "TA-6 psar_down_indicator flags every down reversal",
        bad == 0 and float(expected.sum()) > 0,
        "1 on each of the %d bars where a down trend starts, 0 elsewhere"
        % int(expected.sum()),
        "%d rows disagree" % bad,
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo",
        default=os.environ.get("TA_REPO", ""),
        help="path to a bukosabino/ta checkout; omit to use an installed `ta`",
    )
    args = parser.parse_args()
    if args.repo:
        sys.path.insert(0, os.path.abspath(args.repo))

    global np, pd
    import numpy as np  # noqa: E402
    import pandas as pd  # noqa: E402

    warnings.simplefilter("ignore")
    import ta  # noqa: F401,E402

    reference_dir = os.path.abspath(args.repo) if args.repo else os.path.dirname(
        os.path.dirname(os.path.abspath(ta.__file__))
    )
    print("python %s | pandas %s | numpy %s" % (sys.version.split()[0], pd.__version__,
                                                np.__version__))
    print("ta imported from %s\n" % os.path.dirname(os.path.abspath(ta.__file__)))

    ta_1_psar_index_semantics()
    ta_2_kst_lookahead()
    ta_3_adx_warm_up_row(reference_dir)
    ta_4_warm_up_preconditions()
    ta_5_bollinger_ddof(reference_dir)
    ta_6_psar_down_indicator()

    failed = [n for n, ok in RESULTS if not ok]
    print("-" * 72)
    print("%d checks, %d passed, %d failed" % (len(RESULTS), len(RESULTS) - len(failed),
                                               len(failed)))
    for name in failed:
        print("  FAILED: %s" % name)
    return len(failed)


if __name__ == "__main__":
    sys.exit(main())
