# Jeffy eval: ai/nanoid

The URL-safe unique ID generator - zero dependencies, three builds
(node, browser, non-secure) plus a CLI, its README's headline a
118-byte size budget. Run 2026-09-01 as wave 7 of the campaign: **the
controlled engine test**, re-running previously failed targets
unchanged on engine 1.20.0 (COHORT-WAVE7.md). The first attempt
(2026-08-26, engine 1.18.2) ended not converged after 3 runs and 30
iterations, three of six rejections on the loop's own notes - the
form-only acceptance-check gap fixed in 1.18.3 (P1-65). The
pre-registered prediction was "converges, medium confidence."

**This attempt: 2 runs, 16 iterations, converged** in run 2 at
`deea1114deb8c11250ba7198c6e52a756f5e8470` - same repository, same
pinned base (tag 6.0.1), same standard budget of 5 rounds of 10.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `9247b6dbfe97854e6e136784ae5dde0c672d22c5` (6.0.1, unchanged from attempt 1) |
| Findings closed | **9** - 1 High, 3 Medium, 5 Low |
| Shipped-code change | 14 files, **+198 / -23** |
| Surface inventory | **12 of 12 rows swept** |
| Ledger at convergence | 7 Lows carried, 1 Declined on a measured premise |
| Evaluator | **3 invocations: REJECT, REJECT, PASS** |
| Suite at convergence | 93 tests green (~2 s) |

## What the loop found

- **`AL-1` (High)** - every factory accepted an alphabet it cannot
  sample from, and then the secure builds **hung forever** in
  `while (true)`: `nanoid --alphabet <300 chars>` never returned, and
  `customAlphabet('')()` spun on both secure builds while the
  non-secure build returned IDs made of the literal text `undefined`.
  The suite had full line, branch and function coverage - and every
  hang sat behind a case that only ever called the generator with size
  0. Fixed with one guard per module at the boundary the argument
  enters: `RangeError: Wrong alphabet size` at construction time.
- **`CLI-4` (Medium, filed by the gate)** - `bin/nanoid.js` tested the
  alphabet for truthiness, so `--alphabet ""` (an empty shell
  variable) was silently ignored and the CLI printed IDs from the
  default alphabet the user did not ask for.
- **`CLI-5` (Medium)** - the library reduces size with `size |= 0`, so
  `--size 4294967301` wrapped and printed a five-character ID at exit
  0. The parser now bounds the flag and names the bound.
- **`PKG-1` (Medium)** - the published npm tarball carried the loop's
  own state (105 entries down to 29 after the fix), plus `CLI-1`-`CLI-3`
  (missing flag values accepted, non-integer sizes accepted, library
  throws escaping as 13-line stack traces).

`LIB-1` - the same `size |= 0` wrap reachable through the library
exports - was **declined on a measurement, not a shrug**: guarding it
costs 43 brotlied bytes, a 36 percent increase in the headline
118-byte figure that is this package's stated value proposition, to
defend an input the envelope classifies as an exotic hand-written
shape. The derivation is recorded and re-run at every declaration.

## The engine-test result

Attempt 1 lost three of its six rejections to the loop's own notes.
Attempt 2's two REJECTs were both substance - settled-class
enumerations claiming surfaces their own commands never reached (the
CLI, then the jsr channel) - and the second even caught the run
applying a rule it had just learned to one line while ignoring the
identical defect one line above. Run 2's fresh gate passed on first
invocation. The prediction held, and the rejections the engine now
spends are the kind worth paying for.

## Upstream

`AL-1` was filed as
[PR #609](https://github.com/ai/nanoid/pull/609): the unsamplable-alphabet
hang, duplicate-searched clean, red/green proven on a fresh clone at
upstream HEAD, provenance disclosed. The maintainer reviewed within the
hour and judged the guard's byte cost too high for the reachability
("too big price for the case which we haven't in reality") - the same
trade this run's own LIB-1 decline priced - and asked for a docs notice
instead. The PR was reworked the same day to a README-only change
stating the 1-to-256 bound and the loop-forever consequence - and the
maintainer **merged it the same day** (2026-09-01, "Thanks!"). The
runtime fix stands in this receipt's fixes.patch; the project chose the
documentation defense, and that call was the maintainer's to make.
