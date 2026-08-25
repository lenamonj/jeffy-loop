# Jeffy eval: uuid (JavaScript)

The `uuid` package - the identifier generator in a vast share of npm
dependency trees - run in the 2026-08-24/25 JavaScript wave on engine
1.16.0. **2 runs, 20 iterations, converged** at
`62a09063eae82d1f966cb5fc578f203b3a28397f`, against a **pre-registered
budget of 2 rounds of 10**. Never pooled with this corpus's Go
`go-uuid`: different project, different language, both receipts say so.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `fd59f0277549d22cc7ec00a7b3b5c9bccb4d3c1d` |
| Findings closed | **13** - 1 High, 8 Medium, 4 Low |
| Shipped-code change | 20 files, **+713 / -284** |
| Surface inventory | **12 of 12 rows swept** |
| Ledger at convergence | **3 Lows carried** with acceptance lines |
| Evaluator | **1 invocation, PASS** |

## What the loop found

- **`UUID-001` (High)** - `v3()` and `v5()` threw `URIError: URI
  malformed` for any name containing an unpaired UTF-16 surrogate - a
  crash on a plain string argument in the name-based generators.
- **`UUID-006`** - `v1ToV6()` and `v6ToV1()` accepted a UUID of any
  version and silently returned a wrong-version result.
- **A CI-that-cannot-fail cluster**, the instrument class this engine
  release names: `npm run docs:diff` ended in a bare `git diff` that
  exits 0 either way, so CI's doc lint never failed (`UUID-002`); the
  workflow ran `npm exec publint --strict` where npm ate the flag as its
  own config, so publint never ran strict (`UUID-013`).
- The rest of the Mediums: the CLI dumping raw stack traces on argument
  errors, no `engines.node` despite a documented support range, a README
  documenting a throw that uuid@11 removed, `npm audit` red with 8
  advisories (6 fixed, the rest priced).

## The gate

A single invocation, PASS, with the three carried Lows re-scored
individually - including `UUID-016`, the run filing **its own battery's
surviving mutant** (a UTF-8 boundary change its probe does not kill) as
a carried Low rather than claiming coverage it could not prove. That is
the observed-failing discipline internalized by a run.

## Declared limits

- Graded on Node v24.17.0, linux under WSL2, run headless as a systemd
  user unit by `claude -p` on **claude-opus-5 (1M context)**, engine
  **1.16.0**.

## Nothing was sent upstream

Every finding rests on tests this loop wrote; no existing test was
deleted, disabled or weakened. Whether UUID-001's surrogate fix goes
upstream is a separate decision, made one finding at a time.
