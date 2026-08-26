# Jeffy eval: python-humanize/humanize

The number-and-date humanizing library (`intcomma`, `naturalsize`,
`naturaltime` and their siblings), run 2026-08-26 as one of the two targets
in the target-side acceptance cohort for engine 1.18.3, alongside `nanoid`.
**3 runs, 30 iterations, converged** at
`63e7acead8199264cd1b6cf91c1c73362f65ae57`, in round 3 of a
**pre-registered budget of 3 rounds of 10**. Run 1 closed six (four Highs
among them) and ended out of budget with four Mediums and seven Lows open;
run 2 closed eight more and ended on a gate REJECT; run 3 closed the last
eight, took a second REJECT, and passed on the invocation after it.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `3c577d7650508d52aa2982e930b0e744c343082f` (tag 4.16.0) |
| Findings closed | **22** - 5 High, 10 Medium, 7 Low |
| Shipped-code change | 12 files, **+605 / -83** |
| Surface inventory | **14 of 14 rows swept** |
| Ledger at convergence | **empty** - nothing carried |
| Evaluator | **3 invocations: REJECT, REJECT, then PASS** |
| Suite at convergence | 866 passed |

## What the loop found

- **`H1` (High)** - `number.py` tested for nan and inf by calling
  `float(value)`, so `ordinal`, `intcomma`, `apnumber` and `intword`
  raised on inputs a float conversion cannot represent, where the
  documented contract returns the value unchanged.
- **`H2` (High)** - `scientific`, `fractional` and `metric` routed large
  integers through `float`, so an integer past float range raised
  `OverflowError` instead of formatting.
- **`H3` (High)** - `naturalsize` converted its argument with
  `float(value)`, so a byte count past float range raised where it should
  have printed.
- **`H4` (High)** - `ordinal` derived its suffix from `value % 10`, and
  Python's modulo on a negative integer returns the positive remainder, so
  negative ordinals carried the wrong suffix.
- **`H5` (High)** - filed by the run's own closing audit against its own
  H2 fix: the `_exact_int` fast path made `scientific(0)` return
  `'0.00 x 10²'` (because `format(Decimal(0), '.2e')` is `'0.00e+2'`) and
  `fractional(True)` return `'True'` where every sibling formatter returns
  `'1'`. Both regressions the loop introduced, both caught by differential
  testing against upstream before the gate saw them.
- **`M1` (Medium)** - `_date_and_delta` built `now - delta` for every
  input, so `naturaltime` and `precisedelta` raised `OverflowError` on
  deltas past the datetime range.
- **`M6` (Medium)** - `naturalsize` had no non-finite handling and raised
  `ValueError: cannot convert float NaN to integer`.
- **`M9` (Medium)** - `naturaldelta`, `naturaltime` and `precisedelta`
  raised `OverflowError` on both float infinities while their own docs
  promise a string.
- **`M3`, `M7`, `M8`, `M10`, `M11` (Medium)** - the test and CI harness:
  pytest 9 ignored tox.ini's `[pytest]` section; a `testpaths` that put the
  checkout's `src` at the front of `sys.path` so `tox -e py` on every CI
  job tested the working tree instead of the built package it had just
  installed; a line that broke the project's own black and ruff limits;
  the lint and mypy jobs left red by an earlier iteration of this same
  loop; coverage XML recorded under absolute scratch paths.
- **`M2`, `M4` (Medium)** - `clamp` annotated `-> str` while returning
  `None`; hatchling's sdist shipped the loop's own state files.
- **Seven Lows** - unknown `minimum_unit` escaping as a bare `KeyError`;
  `natural_list` annotated as a list while documented as an iterable;
  `intword` raising a bare exception near 1.8e408; the wheel shipping 35
  `.po` sources beside the compiled `.mo` files it reads; three public
  functions with no `Args:` docstring; README's language list naming 33
  languages while the tree ships 35 catalogues; a numeric string passing
  the non-finite guard unconverted.

## The gate

Three invocations. Run 2's REJECTed on M7 alone: it showed that the
`testpaths` the loop had added at M3 inserted the repository's `src` ahead
of the installed distribution under pytest's default import mode, so every
CI job across nine interpreters and three operating systems built a package
and then never exercised it. Run 3's first invocation REJECTed on three
reasons, the first being black: green at three earlier checkpoints and red
again at the loop's iteration 7, a required CI check the loop itself had
re-broken. The second invocation PASSed with the ledger empty, every closed
task's acceptance re-executed as written, and the suite at 866 passed. No
REJECT reason on this target was a stated count, which was the acceptance
test the cohort was pre-registered to answer.

## Status

Fixes live in this eval's artifacts (`fixes.patch`); nothing was pushed
upstream. The four float-range Highs and the negative-ordinal suffix are
the candidates if anything goes upstream, each with a one-line reproduction
in the journal. Journal at `journal.md`.
