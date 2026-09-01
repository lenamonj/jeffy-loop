# Jeffy eval: jab/bidict

The bidirectional mapping library for Python - a mature, dependency-free
package whose value, in its own words, is the carefully-factored
implementation behind a small API. Run 2026-09-01 as wave 8 of the
campaign (COHORT-WAVE8.md). **1 run, 10 iterations, converged** in
round 1 at `1fd781a27b5632f4a2bff5417afc8608df0688a2`, within a
**pre-registered budget of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `61e98274c4b3f041344a2a818315ab2b57c0c358` |
| Findings closed | **3** - 1 High, 1 Medium, 1 Low |
| Shipped-code change | 7 files, **+33 / -10** |
| Surface inventory | **16 of 16 rows swept** |
| Ledger at convergence | 5 Lows carried |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | 317 passed; 15 batteries, 765 known-answer and invariant checks, `check-claims` 30 checked / 0 mismatched |

## What the loop found

- **`H1` (High)** - `pyproject.toml` declared
  `typing_extensions>=4.0; python_version<'3.12'`, but
  `bidict/_typing.py` imports `override`, which typing_extensions first
  provided in 4.4.0. **A permitted resolution produced a package that
  could not be imported at all** on Python 3.11 - the floor admitted
  versions the code cannot run on. Found by resolving the declared
  floors rather than reading them, which is what the project's own CI
  never does: every job installs from `uv.lock`, so no gate anywhere
  exercises the floors the package publishes.
- **`M1` (Medium)** - `README.rst` claimed bidict has "no runtime
  dependencies outside Python's standard library" while
  `pyproject.toml` declares typing_extensions for Python < 3.12. The
  claim was false on 3.11, on the page PyPI serves.
- **`L1` (Low)** - two `blob/main` source links in
  `docs/learning-from-bidict.rst`, published on readthedocs, pointed at
  paths that no longer exist.

A mature library with a small public surface yields few findings, and
the two that matter are both about the gap between what the package
*declares* and what it *needs* - a surface no test suite looks at
because every environment that runs the tests is already pinned.

## A note on this run's environment

bidict's suite read `1 failed, 316 passed` on a fresh clone here. The
failure was a `docs/extending.rst` doctest raising
`ModuleNotFoundError: No module named 'sortedcollections'` - an
optional dependency the project's own docs exercise, absent from the
venv. The environment was completed (that package, plus the
`pytest-xdist` bidict's own pyproject requires) and the suite runs
317/317. No test was skipped, disabled, or pinned backwards to reach a
green base; the gate log records the sequence.

bidict ships an in-repo `CLAUDE.md` addressed to Claude Code. It is
orientation rather than restriction - correctness and API stability
over cleverness, no new runtime dependencies, Semantic Line Breaks in
prose files, MPL headers, CHANGELOG updates for public API changes -
and it was read before the run started and is honoured by this work.
