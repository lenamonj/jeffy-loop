#!/usr/bin/env python
"""Jeffy audit reproduction cases for ranaroussi/yfinance price repair.

Target: ranaroussi/yfinance at HEAD beac22d981ab37362a70c9e4e49261ac622acbe4
        (2026-07-23, "Version 1.5.2").

Usage:

    pip install -e <clone-of-yfinance>
    pip install scipy
    python repro.py

The upstream test suite hits live Yahoo endpoints and is rate-limited, so this
file does not use it. Every case drives yfinance's repair functions directly
with hand-built fixture DataFrames, and the process blocks socket connect /
DNS before the first case runs, so a case that silently reached the network
would raise instead of passing. Fixtures are seeded, so results are identical
run to run.

Against the UNPATCHED library at that HEAD, 13 of the 16 graded cases FAIL
(Y1, Y2, Y2b, Y2c, Y3, Y3b, Y4, Y5, Y6, Y7, Y7b, Y8, Y9). fixes.patch makes all
16 PASS. The NOTREPRO, DOCUMENTED and GUARD cases pass both before and after;
they record what was observed and guard behaviour that is correct today.

One scoping note, observed not assumed: Y1 fails on pandas 3.0.5 and on pandas
2.3.3 with copy_on_write enabled, and PASSES on pandas 2.3.3 with the old
default. yfinance declares pandas>=1.3.0, so a fresh install today gets
pandas 3 and hits it.
"""

import sys
import traceback

import numpy as np
import pandas as pd

from yfinance.scrapers.history import PriceHistory
from yfinance import utils

# Block the network AFTER imports (ssl subclasses socket.socket at import time).
import socket


class NetworkBlocked(RuntimeError):
    pass


def _no_net(*a, **k):
    raise NetworkBlocked("repro.py must not touch the network")


socket.socket.connect = _no_net
socket.socket.connect_ex = _no_net
socket.create_connection = _no_net
socket.getaddrinfo = _no_net


# ---------------------------------------------------------------------------
# harness
# ---------------------------------------------------------------------------

RESULTS = []


def check(case, dimension, what, expected, actual, ok, info=False):
    RESULTS.append((case, ok, info))
    tag = "INFO" if info else ("PASS" if ok else "FAIL")
    print(f"[{tag}] {case} ({dimension})")
    print(f"       {what}")
    print(f"       expected: {expected}")
    print(f"       actual  : {actual}")
    print()


def make_ph(currency="USD", ticker="TEST", tz="America/New_York", meta=None):
    """A PriceHistory with no session and no network, built for direct calls."""
    ph = PriceHistory.__new__(PriceHistory)
    ph._data = None
    ph.ticker = ticker
    ph.tz = tz
    ph.session = None
    ph._history_cache = {}
    ph._history_metadata = {"currency": currency, "exchangeTimezoneName": tz}
    if meta:
        ph._history_metadata.update(meta)
    ph._history_metadata_formatted = True
    ph._dividends = None
    ph._splits = None
    ph._capital_gains = None
    ph._reconstruct_start_interval = None
    ph._last_error = None
    return ph


def synth_frame(n=40, days_ago=1200, seed=7, tz="America/New_York", level=50.0):
    """Seeded daily OHLCV. days_ago=1200 puts every row outside Yahoo's 730-day
    intraday window, so _reconstruct_intervals_batch bails out before fetching."""
    rng = np.random.default_rng(seed)
    start = pd.Timestamp.now(tz=tz).normalize() - pd.Timedelta(days=days_ago)
    idx = pd.DatetimeIndex([start + pd.Timedelta(days=i) for i in range(n)])
    close = level + np.cumsum(rng.normal(0, 0.005 * level, n))
    open_ = close + rng.normal(0, 0.003 * level, n)
    high = np.maximum(open_, close) + np.abs(rng.normal(0, 0.007 * level, n))
    low = np.minimum(open_, close) - np.abs(rng.normal(0, 0.007 * level, n))
    return pd.DataFrame(
        {
            "Open": open_, "High": high, "Low": low, "Close": close,
            "Adj Close": close,
            "Volume": rng.integers(1e5, 5e5, n).astype(float),
            "Dividends": 0.0, "Stock Splits": 0.0,
        },
        index=idx,
    )


# XDEV.L, from issue 2866. Real pence values as Yahoo served them.
XDEV_ROWS = [
    ("2026-06-10", 5985.0, 6001.0, 5910.0, 5942.0, 36166),
    ("2026-06-11", 5949.0, 6008.0, 5945.0, 5969.0, 10714),
    ("2026-06-12", 6060.0, 6152.549805, 6043.0, 6144.0, 27824),
    ("2026-06-15", 6224.0, 6270.0, 6224.0, 6236.0, 29171),
    ("2026-06-16", 6262.0, 6300.0, 6188.0, 6198.0, 35757),
    ("2026-06-17", 6215.0, 6215.0, 6162.016113, 6201.0, 20438),
    ("2026-06-18", 6247.350098, 6287.0, 6230.0, 6272.0, 46333),
]


def xdev_frame(tz="Europe/London"):
    idx = pd.DatetimeIndex([pd.Timestamp(r[0], tz=tz) for r in XDEV_ROWS])
    return pd.DataFrame(
        {
            "Open": [r[1] for r in XDEV_ROWS],
            "High": [r[2] for r in XDEV_ROWS],
            "Low": [r[3] for r in XDEV_ROWS],
            "Close": [r[4] for r in XDEV_ROWS],
            "Adj Close": [r[4] for r in XDEV_ROWS],
            "Volume": [r[5] for r in XDEV_ROWS],
            "Dividends": 0.0, "Stock Splits": 0.0,
        },
        index=idx,
    )


# ---------------------------------------------------------------------------
# Y1 - _fix_bad_div_adjust writes into a read-only numpy view (issue 2890)
# ---------------------------------------------------------------------------

def case_Y1():
    df = synth_frame()
    df.iloc[10, df.columns.get_loc("Dividends")] = 0.5
    ac = df["Adj Close"].to_numpy(copy=True)
    ac[3] = np.inf          # the overflow the block exists to tame
    ac[5] = 1e9             # > Close*10, so the while-loop actually writes
    df["Adj Close"] = ac

    ph = make_ph()
    err = None
    try:
        out = ph._fix_bad_div_adjust(df.copy(), "1d", False, "USD")
        actual = "returned a frame; Adj Close[5] = %.4g" % out["Adj Close"].iloc[5]
        ok = True
    except Exception as e:
        err = e
        actual = "%s: %s" % (type(e).__name__, e)
        ok = False
    check(
        "Y1", "correctness / error handling",
        "_fix_bad_div_adjust() on a frame whose Adj Close contains inf "
        "(history.py:1642 to_numpy() then in-place write at :1647)",
        "no exception - infinite Adj Close is reduced, not fatal",
        actual, ok,
    )
    if err is not None and not isinstance(err, ValueError):
        print("       (unexpected exception type - full traceback:)")
        traceback.print_exception(type(err), err, err.__traceback__)


# ---------------------------------------------------------------------------
# Y2 - unit-switch revert rescales the whole table after a partial repair
# ---------------------------------------------------------------------------

def case_Y2():
    tz = "Europe/London"
    n = 90
    base = synth_frame(n=n, days_ago=n - 1, seed=11, tz=tz, level=50.0)
    # newest row must be recent so _standardise_currency's quote check can run
    base.index = pd.DatetimeIndex(
        [pd.Timestamp.now(tz=tz).normalize() - pd.Timedelta(days=n - 1 - i) for i in range(n)]
    )
    true_gbp = base["Close"].to_numpy(copy=True)

    # Yahoo serves this LSE ticker in pence, and for rows 40..59 it applied the
    # pence scaling twice - a genuine 100x block error inside a pence table.
    pence = base.copy()
    for c in ["Open", "High", "Low", "Close", "Adj Close"]:
        pence[c] = pence[c] * 100.0
    for c in ["Open", "High", "Low", "Close", "Adj Close"]:
        pence.iloc[40:60, pence.columns.get_loc(c)] *= 100.0

    ph = make_ph(currency="GBp", ticker="TEST.L", tz=tz,
                 meta={"regularMarketPrice": pence["Close"].iloc[-1]})
    d1, cur = ph._standardise_currency(pence.copy(), "GBp")
    ph._history_metadata["currency"] = cur
    d2 = ph._fix_unit_switch(d1, "1d", tz)

    got = d2["Close"].to_numpy()
    n_wrong = int((np.abs(got / true_gbp - 1) > 0.01).sum())
    check(
        "Y2", "correctness",
        "GBp table with a genuine 100x block: rows still wrong after "
        "_standardise_currency + _fix_unit_switch (history.py:3377-3392)",
        "0 of %d rows wrong" % n,
        "%d of %d rows wrong; Close[0] = %.4f, true = %.4f (x%.1f)"
        % (n_wrong, n, got[0], true_gbp[0], got[0] / true_gbp[0]),
        n_wrong == 0,
    )

    block = d2["Repaired?"].to_numpy()[40:60]
    outside = d2["Repaired?"].to_numpy()[:40]
    check(
        "Y2b", "correctness / silent failure",
        "the same call's 'Repaired?' column. Rows 40-59 are the ones that carried a "
        "block error; the revert at history.py:3392 inverts the whole flag array",
        "all 20 block rows flagged True",
        "%d/20 block rows True, %d/40 rows outside the block True"
        % (int(block.sum()), int(outside.sum())),
        bool(block.all()),
    )


# ---------------------------------------------------------------------------
# Y3 - crude 100x fallback leaves Adj Close bad, auto_adjust reapplies it
# Y4 - crude 100x fallback discards recoverable High/Low
# Y5 - crude 100x fallback does not set 'Repaired?'
# Y6 - the crude-repair INFO log can never fire
# ---------------------------------------------------------------------------

def _crude_fallback_output():
    df = synth_frame()
    bad = 20
    true_row = df.iloc[bad][["Open", "High", "Low", "Close", "Adj Close"]].copy()
    df_bad = df.copy()
    for c in ["Open", "High", "Low", "Close", "Adj Close"]:
        df_bad.iloc[bad, df_bad.columns.get_loc(c)] *= 100.0
    ph = make_ph()
    out = ph._fix_unit_random_mixups(df_bad.copy(), "1d", "America/New_York", False)
    return true_row, out, out.iloc[bad], bad


def case_Y3():
    true_row, out, row, _ = _crude_fallback_output()
    ratio_ac = row["Adj Close"] / true_row["Adj Close"]
    check(
        "Y3", "correctness",
        "crude 100x fallback: 'Adj Close' after repair (history.py:1244-1310)",
        "%.4f (x1.0)" % true_row["Adj Close"],
        "%.4f (x%.1f)" % (row["Adj Close"], ratio_ac),
        abs(ratio_ac - 1.0) < 0.01,
    )

    adj = utils.auto_adjust(out)
    ra = adj.iloc[20]
    ratios = {c: ra[c] / true_row[c] for c in ["Open", "Close"]}
    worst = max(abs(v - 1.0) for v in ratios.values())
    check(
        "Y3b", "correctness",
        "the same frame through utils.auto_adjust() - yfinance's default path",
        "Open x1.0, Close x1.0 (true Open %.4f, Close %.4f)"
        % (true_row["Open"], true_row["Close"]),
        "Open x%.1f (%.4f), Close x%.1f (%.4f)"
        % (ratios["Open"], ra["Open"], ratios["Close"], ra["Close"]),
        worst < 0.01,
    )


def case_Y4():
    true_row, out, row, _ = _crude_fallback_output()
    true_rng = (true_row["High"] - true_row["Low"]) / true_row["Close"]
    got_rng = (row["High"] - row["Low"]) / row["Close"]
    ok = abs(row["High"] - true_row["High"]) < 1e-6 and abs(row["Low"] - true_row["Low"]) < 1e-6
    check(
        "Y4", "correctness",
        "crude 100x fallback: High/Low are exactly recoverable by the detected "
        "factor, but are overwritten with max/min of the body (history.py:1259-1267)",
        "High %.4f, Low %.4f, range %.4f%% of Close"
        % (true_row["High"], true_row["Low"], true_rng * 100),
        "High %.4f, Low %.4f, range %.4f%% of Close"
        % (row["High"], row["Low"], got_rng * 100),
        ok,
    )


def case_Y5():
    _, out, row, _ = _crude_fallback_output()
    flagged = bool(out["Repaired?"].any()) if "Repaired?" in out.columns else False
    check(
        "Y5", "correctness / silent failure",
        "crude 100x fallback rewrote a row's prices - does 'Repaired?' say so? "
        "(history.py:1244-1310; doc/source/advanced/price_repair.rst:7)",
        "True on the rewritten row",
        "%s (column present: %s)" % (row.get("Repaired?", "column absent"),
                                     "Repaired?" in out.columns),
        flagged,
    )


def case_Y6():
    import logging

    records = []

    class Grab(logging.Handler):
        def emit(self, record):
            records.append(record.getMessage())

    logger = utils.get_yf_logger()
    h = Grab()
    old_level, old_prop = logger.level, logger.propagate
    logger.addHandler(h)
    logger.setLevel(logging.INFO)
    logger.propagate = False
    try:
        _crude_fallback_output()
    finally:
        logger.removeHandler(h)
        logger.setLevel(old_level)
        logger.propagate = old_prop

    hit = [m for m in records if "currency unit mixups" in m]
    check(
        "Y6", "observability",
        "the only user-visible report of a crude repair, logged at INFO "
        "(history.py:1298-1302); its counter reads a pre-tag snapshot at :1239",
        "one 'fixed N/M currency unit mixups' line",
        "%d such lines (captured: %s)" % (len(hit), hit if hit else records[-1:]),
        len(hit) == 1,
    )


# ---------------------------------------------------------------------------
# Y7 - _repair_capital_gains divides by zero
# ---------------------------------------------------------------------------

def case_Y7():
    df = synth_frame()
    df["Capital Gains"] = 0.0
    df.iloc[20, df.columns.get_loc("Capital Gains")] = 0.9   # no dividend that day
    ph = make_ph()
    try:
        ph._repair_capital_gains(df.copy())
        actual = "returned a frame"
        ok = True
    except Exception as e:
        actual = "%s: %s" % (type(e).__name__, e)
        ok = False
    check(
        "Y7", "correctness / error handling",
        "_repair_capital_gains() on a fund that distributed capital gains with no "
        "dividend that day (history.py:1542)",
        "no exception - nothing to un-double-count, so nothing to repair",
        actual, ok,
    )

    df2 = synth_frame()
    df2["Capital Gains"] = 0.0
    df2.iloc[0, df2.columns.get_loc("Capital Gains")] = 0.9
    df2.iloc[0, df2.columns.get_loc("Dividends")] = 1.2
    ph = make_ph()
    try:
        ph._repair_capital_gains(df2.copy())
        actual = "returned a frame"
        ok = True
    except Exception as e:
        actual = "%s: %s" % (type(e).__name__, e)
        ok = False
    check(
        "Y7b", "correctness / error handling",
        "_repair_capital_gains() when the only capital-gains row is the first row "
        "(no preceding interval to calibrate against)",
        "no exception",
        actual, ok,
    )


# ---------------------------------------------------------------------------
# Y8 - GBp subunit assumption is applied unchecked and unflagged
# ---------------------------------------------------------------------------

def case_Y8():
    tz = "Europe/London"
    df = xdev_frame(tz)
    # Same instrument, but Yahoo served this window already in pounds while still
    # tagging the currency GBp. The window ends >30 days ago, so the live-quote
    # check at history.py:1083 cannot run.
    for c in ["Open", "High", "Low", "Close", "Adj Close"]:
        df[c] = df[c] / 100.0
    df.index = df.index - pd.Timedelta(days=400)
    before = df["Close"].to_numpy(copy=True)

    import logging
    records = []

    class Grab(logging.Handler):
        def emit(self, record):
            records.append((record.levelname, record.getMessage()))

    logger = utils.get_yf_logger()
    h = Grab()
    old_level, old_prop = logger.level, logger.propagate
    logger.addHandler(h)
    logger.setLevel(logging.WARNING)
    logger.propagate = False
    try:
        ph = make_ph(currency="GBp", ticker="XDEV.L", tz=tz,
                     meta={"regularMarketPrice": 6272.0})
        out, _ = ph._standardise_currency(df.copy(), "GBp")
    finally:
        logger.removeHandler(h)
        logger.setLevel(old_level)
        logger.propagate = old_prop

    warned = [m for lvl, m in records if lvl == "WARNING"]
    check(
        "Y8", "error handling / observability",
        "GBp frame Yahoo already served in pounds, window ends 400 days ago so the "
        "live-quote check at history.py:1083 is unreachable - is the guess announced?",
        "at least one WARNING naming why the assumption could not be checked",
        "%d WARNING lines %s; Close %.4f -> %.4f"
        % (len(warned), warned, before[-1], out["Close"].iloc[-1]),
        len(warned) >= 1,
    )


# ---------------------------------------------------------------------------
# Issue 2866 - what does and does not hold
# ---------------------------------------------------------------------------

def case_2866():
    tz = "Europe/London"
    df = xdev_frame(tz)
    ph = make_ph(currency="GBp", ticker="XDEV.L", tz=tz)
    out, cur = ph._standardise_currency(df.copy(), "GBp")

    # (a) the conversion itself - documented, not a defect
    converted = np.allclose(out["Close"].to_numpy(), df["Close"].to_numpy() / 100.0)
    check(
        "DOCUMENTED-2866a", "documentation",
        "issue 2866 'prices have erroneously been converted to GBP': the conversion "
        "is what doc/source/advanced/price_repair.rst:9 promises, and "
        "history_metadata['currency'] is updated to match",
        "Close/100 and history_metadata['currency'] == 'GBP'",
        "Close %.1f -> %.2f, history_metadata['currency'] = %r"
        % (df["Close"].iloc[-1], out["Close"].iloc[-1], ph._history_metadata["currency"]),
        converted and ph._history_metadata["currency"] == "GBP", info=True,
    )

    # (b) Volume left alone - correct, the issue is wrong about this
    vol_same = (out["Volume"].to_numpy() == df["Volume"].to_numpy()).all()
    check(
        "NOTREPRO-2866b", "correctness",
        "issue 2866 'volumes have not been adjusted': a currency conversion must "
        "not rescale a share count, so leaving Volume alone is correct",
        "Volume unchanged",
        "Volume unchanged: %s (%d -> %d)"
        % (vol_same, df["Volume"].iloc[-1], out["Volume"].iloc[-1]),
        vol_same,
    )

    # (c) the flag - this is the part that holds, and it is Y8's sibling
    flagged = bool(out["Repaired?"].any()) if "Repaired?" in out.columns else False
    check(
        "Y9", "correctness / silent failure",
        "issue 2866 'Repaired? column is set to False': every price in every row "
        "was multiplied by 0.01 at history.py:1094-1096",
        "Repaired? True on the converted rows",
        "column present: %s, any True: %s" % ("Repaired?" in out.columns, flagged),
        flagged,
    )


# ---------------------------------------------------------------------------
# Issue 2857 - the filed complaint, checked against the repair module
# ---------------------------------------------------------------------------

def case_2857():
    tz = "America/New_York"
    df = synth_frame(n=30, seed=3)
    # A row where Yahoo's High is below the body - the shape issue 2857 reports.
    df.iloc[12, df.columns.get_loc("High")] = df.iloc[12]["Close"] * 0.997
    ph = make_ph(tz=tz)
    out = ph._fix_unit_random_mixups(df.copy(), "1d", tz, False)
    out = ph._fix_zeroes(out, "1d", tz, False)
    still_bad = float(out.iloc[12]["High"]) < float(
        max(out.iloc[12]["Open"], out.iloc[12]["Close"])
    )
    check(
        "NOTREPRO-2857", "correctness",
        "issue 2857 asks repair to clip High/Low to the candle body. No repair "
        "function claims to; the OHLC-ordering violation survives repair=True",
        "High still below max(Open, Close) - repair does not address this",
        "High %.4f vs max(Open, Close) %.4f, violation survives: %s"
        % (out.iloc[12]["High"], max(out.iloc[12]["Open"], out.iloc[12]["Close"]),
           still_bad),
        still_bad, info=True,
    )


# ---------------------------------------------------------------------------
# Guards - behaviour that is correct today and must stay correct
# ---------------------------------------------------------------------------

def case_guards():
    tz = "Europe/London"
    df = xdev_frame(tz)
    df.index = pd.DatetimeIndex(
        [pd.Timestamp.now(tz=tz).normalize() - pd.Timedelta(days=len(df) - i)
         for i in range(len(df))]
    )
    pounds = df.copy()
    for c in ["Open", "High", "Low", "Close", "Adj Close"]:
        pounds[c] = pounds[c] / 100.0
    ph = make_ph(currency="GBp", ticker="XDEV.L", tz=tz,
                 meta={"regularMarketPrice": 6272.0})
    out, cur = ph._standardise_currency(pounds.copy(), "GBp")
    unchanged = np.allclose(out["Close"].to_numpy(), pounds["Close"].to_numpy())
    check(
        "GUARD-1", "correctness",
        "when the live quote can be compared and says prices are already in the "
        "major unit, no conversion happens (history.py:1083-1093)",
        "Close unchanged, currency tag still moved to GBP",
        "Close unchanged: %s, currency = %s" % (unchanged, cur),
        unchanged and cur == "GBP",
    )
    check(
        "Y2c", "correctness",
        "and 'currencyRepaired' must not be set when nothing was converted - "
        "_fix_prices_sudden_change:3381 reads it",
        "currencyRepaired absent or False",
        "currencyRepaired = %r" % ph._history_metadata.get("currencyRepaired"),
        not ph._history_metadata.get("currencyRepaired", False),
    )

    # A clean US frame must come back untouched.
    clean = synth_frame(n=30, seed=5)
    ph2 = make_ph()
    out2 = ph2._fix_unit_random_mixups(clean.copy(), "1d", "America/New_York", False)
    same = np.allclose(out2[["Open", "High", "Low", "Close"]].to_numpy(),
                       clean[["Open", "High", "Low", "Close"]].to_numpy())
    no_flag = not bool(out2["Repaired?"].any()) if "Repaired?" in out2.columns else True
    check(
        "GUARD-3", "correctness",
        "a clean frame passes through _fix_unit_random_mixups unchanged and unflagged",
        "prices identical, Repaired? all False",
        "prices identical: %s, any Repaired?: %s" % (same, not no_flag),
        same and no_flag,
    )


# ---------------------------------------------------------------------------

def main():
    print("yfinance price-repair reproduction - offline, fixture-driven")
    print("pandas %s, numpy %s, python %s"
          % (pd.__version__, np.__version__, sys.version.split()[0]))
    print("=" * 78)
    print()

    for fn in (case_Y1, case_Y2, case_Y3, case_Y4, case_Y5, case_Y6,
               case_Y7, case_Y8, case_2866, case_2857, case_guards):
        try:
            fn()
        except NetworkBlocked:
            raise
        except Exception:
            print("[FAIL] %s raised while running the case itself:" % fn.__name__)
            traceback.print_exc()
            RESULTS.append((fn.__name__, False, False))
            print()

    graded = [(c, ok) for c, ok, info in RESULTS if not info]
    failed = [c for c, ok in graded if not ok]
    print("=" * 78)
    print("%d graded cases, %d passed, %d failed"
          % (len(graded), len(graded) - len(failed), len(failed)))
    if failed:
        print("failing: %s" % ", ".join(failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
