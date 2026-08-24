# Jeffy eval: more-itertools

The iteration-recipes library imported across the Python ecosystem, run
in the 2026-08-24 Python wave on engine 1.16.0. **2 runs, 16 iterations,
converged** at `6df5fffa917c34910fda41e36ff17ee8d43c410e`, against a
**pre-registered budget of 2 rounds of 10**. The evaluator was invoked
once and PASSed - the only single-invocation, first-PASS convergence of
its wave.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `2fe1b2eeb9d75f994113fe3ac76d14b6bcd6fb10` |
| Findings closed | **8** - 2 High, 3 Medium, 3 Low |
| Shipped-code change | 7 files, **+196 / -21** |
| Surface inventory | **23 of 23 rows swept** |
| Ledger at convergence | **2 Lows carried** (both documentation, with acceptance lines) |
| Evaluator | **1 invocation, PASS** |

## What the loop found

- **`P1` (High)** - found by the artifact-channel enumeration this
  engine release introduced, and it is the *inverse* of the leak the
  discipline was born from: the flit 4.x upgrade left `pyproject.toml`
  with no `[tool.flit.sdist]` table, so `make package` published an
  sdist holding **only the module, pyproject, README and LICENSE** - no
  tests, no docs - while a dead `MANIFEST.in` sat in the tree
  describing a build that no longer ran. The channel rule catches
  under-shipping exactly as it catches leaking, because it grades
  contents against intent rather than exit status.
- **`P6` (High)** - `sample(population, k, weights=...)` raised
  `ZeroDivisionError` on a zero weight and **silently produced a
  meaningless draw on a negative one** - a wrong statistical result with
  no complaint. Closed at one boundary with the weights rule documented
  and four regression tests added to the project's own suite.

The Mediums: `outer_product` refusing an empty *ys* against its own
documented behavior; `chunked(iterable, 0)` and `sliced(seq, 0)` silently
discarding the entire input; a `substrings_indexes` docstring describing
an ordering `reverse=True` does not produce. The Lows closed are all
documentation debt, including four `__all__` names invisible to the
rendered API docs.

## The gate

Run 1 swept 22 of 23 rows and spent no invocation; run 2 finished the
map, closed the remainder, and the single invocation PASSed with the two
carried Lows re-scored individually. A wave-level note belongs here for
honesty: this crate's suite runs 736 tests plus 21,039 subtests in ~26
seconds, and the loop's own batteries added known-answer coverage on top
- the cheap-oracle shape doing exactly what the corpus says it does.

## Declared limits

- Graded on Python 3.14.4, linux under WSL2, run headless as a systemd
  user unit by `claude -p` on **claude-opus-5 (1M context)**, engine
  **1.16.0**.

## Nothing was sent upstream

Every finding rests on tests this loop wrote; no existing test was
deleted, disabled or weakened. Whether P6's weights fix goes upstream is
a separate decision, made one finding at a time.
