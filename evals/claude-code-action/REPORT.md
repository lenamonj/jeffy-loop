# Jeffy eval: anthropics/claude-code-action

**Target**: [anthropics/claude-code-action](https://github.com/anthropics/claude-code-action) (8,618 stars, verified via `gh api repos/anthropics/claude-code-action --jq '.stargazers_count'` on 2026-08-13) at `main` commit `e63208cb983318a44e3f945e959ef894b707dcfa`, MIT. TypeScript, in a local clone; the loop's work was never pushed anywhere. This is the GitHub Action that runs Claude against issues and pull requests.

**Convergence standard**: evaluator countersigned. The adversarial evaluator's verdicts for this run are in the narrative below; the standard each target met is recorded in [evals/ATTEMPTS.md](../ATTEMPTS.md). This run declared under the v1.9.0 severity floor, and the four Lows it carried are named below.

**This is attempt 2. Attempt 1 did not converge and is published as such**, in ATTEMPTS.md, with its own row. Both attempts started from the same commit with the same verify command and the same pre-registered three-run budget. The variable that changed between them was the engine: attempt 1 ran on v1.9.0, attempt 2 on **v1.10.0**, whose defining change was to make sweeping the Surface inventory scheduled work rather than something an audit elects to do.

**Attempt 2: three runs, 30 iterations, converged at `4d8bdeb` on 2026-08-14** at the last budgeted iteration of the last budgeted run. **24 findings filed, 20 closed - 11 Medium, 13 Low, and no High** - with **four Lows carried** at the declaration. The shipped change is **59 files, +5,214/-1,918**.

## The number this receipt exists for

| End of | Attempt 1 (engine v1.9.0) | Attempt 2 (engine v1.10.0) |
|---|---|---|
| run 1 | 4 of 23 rows swept | 6 of 28 |
| run 2 | 14 of 23 | 25 of 28 |
| run 3 | **17 of 23** | **28 of 28** |
| sweep-typed iterations | **0 across 30** | **8 across 30** |
| evaluator invocations | **0** | **2** |
| outcome | not converged | **converged** |

Attempt 1 closed 20 findings, ended with an empty ledger and a green suite, and was still refused a declaration, because convergence requires no unswept inventory row and six rows were never reached. Sweeping only happened inside audits, audits only fired when the ledger emptied, and an open Low kept the ledger non-empty. The engine change put unswept rows in the same queue as findings, ranked above Lows. Attempt 2's run 2 then swept nineteen rows in a single run, and run 3 cleared the last three in its first iteration.

The surface is larger in attempt 2 (28 rows against 23) because that run's opening audit enumerated a finer-grained inventory. The comparison is unfavourable to attempt 2 in the denominator and it still finished the map.

## The gate, on its first invocation in 60 iterations against this target

Neither attempt-1 run nor attempt-2 runs 1 and 2 ever invoked the evaluator, because the declaration path never opened. Run 3 reached it at iteration 9.

**Invocation 1 returned REJECT**, and the reason was a finding the run had not filed: a nested manifest and lockfile pair still shipped a dependency version carrying published advisories, on the exact function the code calls, while the run's own Settled classes line recorded that class as fixed class-complete with "both manifest floors raised." It had raised the floors in the top-level manifest and missed the nested one, then declared the class closed. That is a settled class asserted on an enumeration narrower than the class, which is the defect shape the gate exists to catch and which no suite run can catch, because the claim is about a set of sites rather than about behaviour.

**Invocation 2 returned PASS**, at iteration 10, under the one-transaction rule. It verified the fix with its own commands rather than the run's: every manifest and lockfile pair resolved above the advisory ranges, `bun audit` over each pair separately reported no direct-dependency groups, and - the part that makes it evidence - it ran those same checks against the pre-fix pairs and watched them fail. It also confirmed the new lockfile invariant catches a hypothetical fourth pair by glob, closed a second observation with a battery that fails in both source trees where invocation 1 had reproduced it passing, and left the working tree exactly as it found it.

## What was found

Twenty findings closed across three runs, eleven Medium and thirteen Low filed in total, no High. The Mediums that mattered were about the seams: a library-level `process.exit` killing a caller's `finally` block, bot identifiers hardcoded against the wrong defaults, MCP server modules that exported nothing and so could not be tested at all, an actor-matching comparison that was case-sensitive where the underlying identifiers are not, and a dependency-hygiene class that the gate ultimately reopened.

**Three security findings from attempt 1 are not in this list, and that is the most important sentence in this receipt.** See below.

## The limit this target demonstrates, stated plainly

Attempt 1, on identical code, filed **three High-severity security findings**. Attempt 2 swept the entire surface, including the rows that own the code those findings live in, and **did not rediscover any of them**. They remain in the tree this attempt declared converged, verified by diffing the converged commit against the base: neither file was touched.

So two independent runs over the same code produced **disjoint high-severity findings**, and a fully swept map did not mean a fully examined one. "Swept" is a single bit covering a wide range of sweep quality: it records that a row was exercised by an executed battery, not that the battery asked every question worth asking. A convergence declaration means what the rules say it means - this run's own audit and an adversarial gate found no open High or Medium - and it does not mean the code is free of defects a different run would find.

The three findings are described by class only, here and in ATTEMPTS.md. One has been reported to the vendor through their published security channel; the other two have not been reported. Their mechanics were public in this repository earlier on 2026-08-14 and were redacted the same day, with the redaction disclosed in ATTEMPTS.md rather than performed quietly, and with the original text left in this repository's git history rather than rewritten.

## Verify command

```
bun run typecheck && bun test
```

**Oracle class**: the project's own CI gate, run as two stages - a TypeScript type-check over the whole tree, and the `bun test` suite driving the real modules against a mocked GitHub context.

**Verify duration**: 7s measured 2026-08-13. **Surface inventory**: 28 rows, **all 28 swept**, none unreachable.

**Final state**: the verify command exits 0 with **1,009 tests passing across 59 files**, up from 910 at the base commit, so the run added test surface rather than only changing code.

**Carried at the declaration**: four accurately scored Lows, named in the closing journal entry, none blocking under the v1.9.0 severity floor.

## Disclosure

The loop ran against a local clone on a branch. Nothing here was pushed to anthropics/claude-code-action, and no pull request was opened. `journal.md` is the unedited journal across all three runs of attempt 2 and `fixes.patch` is the complete diff from `e63208c` to the converged commit, excluding the loop's own plan, backlog, journal and probe files.

Two findings from these runs were independently fixed upstream within a day, without any contact from us: the dependency advisory the gate rejected on, and a path-validation gap in an MCP tool that attempt 2 filed as a Medium. Both fixes landed in upstream commits of their own. That is not a claim of credit; it is the most useful calibration available, since it shows the maintainers reached the same conclusions about the same code independently.
