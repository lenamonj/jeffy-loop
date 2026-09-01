# Jeffy eval: JedWatson/classnames

The conditional-className utility in half the React ecosystem - three
shipped modules, ESM-only since v3. Run 2026-09-01 as wave 7 of the
campaign: **the controlled engine test**, re-running targets that
previously failed, unchanged, on engine 1.20.0 (COHORT-WAVE7.md). The
first attempt (2026-08-25, engine 1.17.0) ended not converged after 3
runs and 32 iterations, four rejections on one acceptance-check class
the engine has since learned to catch (P1-65, fixed in 1.18.0). The
pre-registered prediction was "converges, medium confidence."

**This attempt: 1 run, 10 iterations, converged** at
`fa56b02820795f726cfc24fe5c47530170b3235f` - same repository, same
pinned base, same standard budget of 5 rounds of 10, first round.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `abd6314010de053a09df5acc53e474ff65cea470` (main, unchanged from attempt 1) |
| Findings closed | **5** - 2 High, 3 Medium |
| Shipped-code change | 8 files, **+100 / -14** |
| Surface inventory | **8 of 8 rows swept** (nine batteries, 200 checks, each observed failing under a recorded mutation) |
| Ledger at convergence | 5 Lows carried |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | 73 tests green (~2 s) |

## What the loop found

- **`CN-1` (High)** - all three entry points threw `TypeError` on an
  object with no `Object.prototype` in its chain or whose `toString` is
  not callable. That is not an exotic shape: `Object.groupBy` returns
  null-prototype objects, so `classNames(Object.groupBy(...))` crashed.
  Fixed class-complete at all three enumerated sites, with the
  reproduction failing 9 of 9 calls on the unfixed tree.
- **`CN-2` (High)** - the README documented the pre-ESM CommonJS and
  UMD distribution for a package that is ESM-only, so the primary usage
  example could not run at all. The fix ships with a battery that
  extracts every fenced snippet from the README, executes it against
  the tree, and compares every `// => 'value'` annotation to the real
  result - documentation that can no longer drift silently.
- **`CN-4` (Medium)** - `bind.js` resolved class names through
  `this[name]` with no own-property guard, so a class named
  `toString`, `constructor` or `__proto__` returned the inherited
  value - a non-string - instead of the name. The enumeration was built
  by provoking the failure at every route into the lookup (48 of 48
  wrong at base, 0 after), because three of the four routes reach it
  only by recursion and a grep would have missed them.
- **`CN-3` (Medium)** - dedupe emitted an empty class token for
  strings with edge whitespace, producing doubled separators.
- **`CN-5` (Medium)** - the README's falsy-values example passed `0`,
  which the shipped `index.d.ts` rejects; the battery now compiles
  every runnable README snippet against the shipped declarations.

The gate's PASS came with a 189-pair differential sweep between base and
HEAD: 11 behavioural differences found, every one attributed to CN-1,
CN-3 or CN-4 - nothing moved that the ledger does not explain.

## The engine-test result

Attempt 1 spent four evaluator rejections on the README-count class -
instrument prose, not product defects - and never got to converge.
Attempt 2, on an engine that catches that class itself, converged in a
single round while finding strictly more product substance (two Highs
attempt 1's record never reached). The prediction held.

## Upstream

`CN-1` was filed as
[PR #579](https://github.com/JedWatson/classnames/pull/579): the
null-prototype / non-callable-toString crash, duplicate-searched clean,
red/green proven on a fresh clone at upstream HEAD (identical to the
pin), `npm test` and `check-types` green, the CONTRIBUTING
performance concern addressed in the body, and provenance disclosed.
