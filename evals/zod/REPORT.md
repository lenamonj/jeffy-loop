# Jeffy eval: colinhacks/zod

The schema validation library under a large share of the TypeScript ecosystem,
and the largest surface in its cohort at 196 source files. **4 runs, 39
iterations, converged** at `e316d0e1d4f2c3e5d8300789c90abe179a547b33`, against
a **pre-registered budget of 4 runs of 10 iterations**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | tag `v4.4.3`, `1fb56a5c18c27102dbc92260a4007c7732a0ccca` |
| Upstream CI on the base | 13 green, 19 skipped, **3 red - all `pullfrog`, a third-party bot leg, declared below** |
| Findings closed | **25** - 3 High, 15 Medium, 7 Low |
| Shipped-code change | 31 files, **+623 / -69** |
| Surface inventory | **28 of 28 rows swept** |
| Ledger at convergence | **6 Lows carried**, listed below |
| Evaluator | **4 invocations: 3 REJECT, then PASS** |
| Suite | `pnpm test` = vitest plus typechecking; 339 files / 3,811 tests at the base, 343 / 3,845 at convergence, `Type Errors: no errors` throughout |

## The cohort context

This cohort's question was whether a fresh context, rather than accumulated
iterations, is what makes runs converge - and its control was surface size,
spanning 4 files (`decimal`) to zod's 196. **zod, the largest surface,
converged in budget; decimal, the smallest, did not.** That is the second
cohort in a row whose outcome refused surface size as a predictor, this time
from the opposite direction.

The run shape is worth recording: runs 1 and 2 spent 20 iterations sweeping
and closing findings without the gate ever being due. Run 3 reached it twice
and was rejected twice - the second terminal, sending the run into gate
salvage. Run 4 answered the gate's findings and passed on its second
invocation.

## What the loop found

The three Highs:

- **`SUCCESS-1`** - `$ZodSuccess` (`z.success()`) never cleared the failure
  state its inner schema wrote into the shared payload, so its `false` branch
  was unreachable; the sibling `$ZodCatch` cleared issues but not `aborted`,
  so a `.refine()` on a `catch` wrapping a pipe was silently skipped. A
  wrapper that swallows an inner failure has to clear both, and now does, at
  all four sync/async sites.
- **`TL-1`** - template literal composition dropped regex flags: `u`/`v` now
  propagate to the composed pattern, and `i`/`s` are refused with an error
  naming the flag, because a flag that cannot be confined to one part cannot
  be composed. The built-in `boolean`/`null`/`undefined` patterns carried a
  case-insensitive flag their own inferred types (`` `true` | `false` ``)
  contradicted; they are now case-sensitive, with the question of whether any
  caller relied on `TRUE` parked as a Proposed item for the maintainer.
- **`SLUG-1`** - slug folding dropped accented Latin letters entirely.
  `.normalize("NFKD")` plus a mark strip plus a 13-entry fold table now
  covers every letter in U+00C0-U+017F, with the 107 Latin Extended-B
  letters priced, declined, and pinned by a probe so the decision cannot rot
  silently.

The dominant Medium class was **stack-overflow handling at boundaries that
walk caller-supplied trees**: an engine `RangeError` reached callers
unconverted from the JSON Schema converters, was misattributed ("nested too
deeply" for exhaustion it had not diagnosed), was absorbed entirely by
`catch`/`success` wrappers so **a cyclic value validated**, and - the false
positive - once a lazy had re-entered anywhere in a parse, every later
`RangeError` was relabelled "Recursion limit exceeded". It took three
attempts and two gate rejections before the class held: the final form
guards the four boundary entry points, discriminates on the error itself,
and leaves `$ZodLazy` untouched. The probes drive both axes - where the
overflow happens and what sits between it and the boundary - and fail
against both previous implementations.

## Six Lows carried at convergence

Published rather than dropped, per the severity floor: `CORE-PROCESS-1` (the
typed-public `process` walk still escapes a bare `RangeError`),
`FROMJS-BIGINT-1` (a BigInt-bearing document misdiagnosed as possibly
cyclic), `OVERFLOW-I18N-1` (the one hardcoded English issue message that
survives a locale swap), `PROBE-PATHS-1`, `SCOPE-COVERAGE-1` and
`DOCS-COVERAGE-1` (three loop-harness coverage debts, the last two filed as
root-cause replacements for classes the run had been patching one instance
at a time).

## Declared limits

- **Upstream CI is red on this commit and that is declared, not fixed.**
  The 3 failing check-runs at the base are all `pullfrog`, a third-party bot,
  not test legs. No iteration touched them.
- **`pnpm test` includes typechecking**, so the oracle is stronger than the
  case count suggests - but it is one command on one platform; nothing here
  claims the 19 skipped upstream legs green.
- Two behaviour questions are **Proposed for the maintainer, not decided by
  the loop**: whether the dead `zsf.ts` module (18 interfaces, reachable
  from nothing, all four facts probe-pinned) should stay, and whether any
  string surface was meant to accept `TRUE`/`NULL` case-insensitively.
- Graded on Node v24.17.0 and pnpm 10.12.1, Linux x86_64 under WSL2, run
  headless by `claude -p` on **claude-opus-5 (1M context) at xhigh effort**.

## Nothing was sent upstream

Every finding rests on tests and probes this loop wrote; the suite grew from
3,811 to 3,845 cases and no existing test was deleted, disabled or weakened.
The one existing test whose bail-outs could not signal a skip now routes
them through `ctx.skip(...)`, so a not-applicable environment reads as
skipped rather than as a pass that asserted nothing.
