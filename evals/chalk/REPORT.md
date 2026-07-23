# Jeffy eval: chalk/chalk

**Target**: [chalk/chalk](https://github.com/chalk/chalk) (~23.3k stars) at HEAD `aa06bb5`, chalk 5.6.2, Node 22.18.0 - run in a local clone; nothing was pushed upstream.

**The frame is different here.** chalk was chosen as a control: one of the most famous and best-maintained small libraries in the ecosystem, picked to test whether the loop invents problems where there are none, rather than to find real ones. The question this run is answering is not "what's wrong with chalk" - it's whether a full-rigor audit against a genuinely well-run project comes back clean, and whether the loop can tell the difference between a real finding and manufacturing one to justify its own existence. Everything below should be read against that question first.

**The headline**: at that HEAD, `npm test` is green - 32/32 ava tests, 99.61 percent statement coverage, xo and tsd both pass. The first audit scored the core library **None** on correctness, security, and architecture. The core held. Every finding the audit filed anyway sat in the tooling perimeter around the library - the benchmark script, dev-dependency chains, CI configuration, a coverage gap - plus exactly one genuine correctness finding, surfaced later by a replenishment audit, in the public API itself.

| Finding | Severity | Behavior at HEAD |
|---|---|---|
| `npm run bench` | Medium (developer experience) | Exits 1: dead `matcha` dependency, plus an import of `./index.js`, a file that no longer exists |
| npm audit, xo/ava dev chains | Medium (dependency hygiene) | 12-14 vulnerabilities across the xo/ava dev-dependency chains; zero in the shipped runtime, which has no runtime dependencies at all |
| `ansi256`/`bgAnsi256` | Medium (testing) | Public path had zero test coverage (index.js lines 90-91 never exercised) |
| CI matrix | Medium (testing) | Covered only EOL Node lines (14/16/18) with a deprecated `codecov-action@v2` |
| `ansi256`/`bgAnsi256` level downconversion (CHALK-5) | Medium (correctness) | At level 1, `ansi256(196)` emitted raw `38;5;196` instead of downsampling to ANSI-16 the way the `rgb`/`hex` models do - contradicting the readme's own downsampling promise. Reproduced with a one-liner |

**Why CHALK-5 is the one that matters**: every other row is infrastructure around the library, not the library. CHALK-5 is different - a correctness bug in the public API, reachable by any caller on a level-1 terminal, contradicting documented behavior. It is the proof the audit had teeth: the loop did not stop at "everything looks fine" and it did not pad the backlog with cosmetic churn either. It found the one place the library's stated contract and its actual behavior disagreed, fixed exactly that, and left the rest of a genuinely well-run project alone.

## What the run did (two runs: 5 iterations, then 3 of a second budget)

1. **Audit** (iter 1/5) - first full audit against all 12 dimensions on Node 22.18.0, verify command set to `npm test`. Filed 4 Medium tasks, 1 Proposed (an engines bump), 2 settled classes, 1 declined finding. Scored architecture, security, and correctness **None**; testing and dependency hygiene **Medium**; code quality and error handling **Low**, both against pre-existing, declined classes.
2. **CHALK-1** (iter 2/5) - rewrote `benchmark.js` on `node:perf_hooks`, dropped the dead `matcha` dependency. Two silent-benchmark traps were documented and fixed along the way: V8 dead-code-eliminates discarded return values, and non-TTY stdout reports color level 0, so a naive rewrite would have quietly measured nothing. Bonus: audit vulnerabilities fell from 14 to 12 as a side effect (the one critical was in matcha's own chain).
3. **CHALK-2** (iter 3/5) - npm audit to 0 vulnerabilities via xo `^0.60.0` and ava `^6.4.1`. xo 4.0.0 was tried first and rejected: audit-clean but 94 lint errors of pure churn (markdown linting, a TS project-service requirement, new rules hitting vendored code). The smaller, non-churning 0.60.x bump was kept instead and the rejection documented rather than quietly avoided.
4. **CHALK-3** (iter 4/5) - added the missing ansi256 coverage test; index.js reached 100 percent statement coverage. The replenishment partial audit this iteration triggered (backlog fell below 3 open items) is what surfaced CHALK-5, the level-1 downconversion gap.
5. **CHALK-4** (iter 5/5) - CI matrix moved to `[24, 22]`, `codecov-action` bumped to v5. End of the first 5-iteration budget, with CHALK-5 still open and handed off explicitly.
6. **CHALK-5** (iter 1/6, second run) - `getModelAnsi` now routes the ansi256 model through `ansiStyles.ansi256ToAnsi` at level 1, mirroring the existing rgb branch. Regression test added; a behavior-change rationale was recorded per the run's own constraints, since observable level-1 output for ansi256 calls changes.
7. **Closing audit** (iter 2/6) - full fresh-evidence audit across all 12 dimensions, re-examining every file touched since the first audit. Zero High, zero Medium in-envelope. One Low filed (CHALK-6: an example file's undeclared transitive import of ansi-styles), so the run was not yet converged per its own closing rule.
8. **CHALK-6** (iter 3/6) - fixed by switching to the package's own `#ansi-styles` subpath import. Convergence declared at `274c733`.

Full iteration-by-iteration record: [journal.md](journal.md). Complete product diff: [fixes.patch](fixes.patch) - 6 files, +76/-67 (excluding the regenerated `package-lock.json`, which is not counted in that diffstat).

**Discipline receipts**: vendored code was declined rather than churned, twice, both recorded as settled classes with reasons - invalid color-model arguments degrading silently on the JS API's user-error surface, and lint warnings inside `source/vendor/*`, which intentionally mirrors upstream. A semver-major engines bump (dropping Node 12/14 to allow `String.prototype.replaceAll`) was filed under Proposed for the owner rather than seized. xo was bumped only to the 0.60.x line, with the larger-churn 4.0 upgrade explicitly tried, rejected, and documented rather than silently skipped.

End state: 34/34 tests, 100 percent statement coverage, npm audit 0 vulnerabilities.

**Status**: fixes live in this eval's artifacts. Nothing was pushed upstream. The correctness finding was disclosed upstream with a repro and a PR offer in [chalk/chalk#686](https://github.com/chalk/chalk/issues/686) (2026-07-23). Merging anything remains the maintainers' call.
