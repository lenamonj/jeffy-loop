# Jeffy eval: janl/mustache.js

**Target**: [janl/mustache.js](https://github.com/janl/mustache.js) (~16.7k stars) at HEAD `972fd2b` (2023-01-21), Node 22.18.0 - run in a local clone; nothing was pushed upstream.

**The headline**: at that HEAD, `npm test` produces zero assertions - the suite crashes before a single test file loads. At the same HEAD, all of the following are true. Every finding below was reproduced firsthand during the opening audit before it was filed as a task.

| Finding | Severity | Behavior at HEAD |
|---|---|---|
| `npm test` | High | Cannot start: the abandoned `esm@3` shim in `test/helper.js` throws `TypeError: Function.prototype.apply called on undefined` before a single assertion runs |
| `bin/mustache` | High | Crashes on Node 22: `TypeError: Mustache.render is not a function` |
| CLI view-path resolution | Medium | Absolute `.js` view paths are mangled by `path.join(process.cwd(), viewArg)` instead of being resolved |
| `npm audit` | Medium | 107 vulnerabilities (24 critical, 58 high), concentrated in the dead `zuul` browser-test stack (depends on a personal git fork), `esm`, `mocha` 3, `chai` 3, `eslint` 6, `puppeteer` 2 |

**Why nobody had caught it**: mustache.js ships its own source as ESM (`export default`) while its test tooling is CJS from an earlier era; the project bridged that gap with the `esm` shim back when that was the standard trick, then the repository went quiet the way long-lived, feature-complete libraries do - dormant, not derelict, and still widely used. Node's CJS/ESM interop kept moving after that point, with native `require()` of ESM landing mid-major at Node 22.12, and with no maintenance commits in the window to notice the drift, the first line `test/helper.js` executes now throws before test collection even starts. The same frozen-in-time posture explains `bin/mustache`'s crash (a `require('..')` that assumed the old module semantics) and the audit surface (`zuul`, a browser-test harness dead since 2017, pinned to a personal fork, left untouched because nothing forced its removal).

## What the run did (2 runs: 8 iterations, then 3 more to convergence)

1. **Audit** - reproduced the test-suite crash, the CLI crash, the path bug, and the dependency-audit surface firsthand; filed the ESM-from-CJS loading problem as one *structural* task spanning three call sites rather than three spot patches.
2. **T1 (structural)** - fixed the loading class everywhere it appeared: `test/helper.js` (feature-detects native `require` of the ESM source with a `.default` unwrap, keeps the `esm` shim as fallback for Node 10-21), `test/cli-test.js` (drives `--require esm` off that same detection instead of version-sniffing), and `bin/mustache` (`.default` unwrap, no-op against a published UMD build). Closed T1 and T2 together.
3. **T5** - replaced `path.join(process.cwd(), viewArg)` with `path.resolve(viewArg)` in `bin/mustache` so absolute `.js`/`.cjs` view paths resolve correctly; added a regression test.
4. **T3, marked blocked rather than claimed done** - deleted the `zuul` stack, `.travis.yml`, and related dead files, cutting `npm audit` from 107 (24 critical) to 17 (4 critical). The remaining 0-critical bar belonged to T4's mocha upgrade, so the iteration declined to claim T3 complete on an acceptance check another task owned, and filed it blocked instead of batching the evidence.
5. **T4** - mocha 3 to ^11.7.6, chai 3 to ^4.5.0 (with a `serialize-javascript` override for a transitive pin mocha still carries); re-verified and closed T3 in the same iteration.
6. **T8, T6, T9** - removed `jshint` and its Rakefile hint task, upgraded `eslint` 6 to ^8.57.1 (no config changes needed), upgraded `rollup` 1 to ^4 (validated against a scratch UMD build, since `npm run build` overwrites the checked-in ESM source in place). Audit fell from 12 to 3 to 2 vulnerabilities across these three tasks.
7. **T7, second run** - modernized CI: dead action versions (`checkout` v1/v2, `setup-node` v1, `artifact` v2, archived `denolib/setup-deno`) replaced with current majors, Node test matrix extended to 18.x/20.x/22.x.
8. **Closing audit** - filed a Medium (F1) against this run's own earlier work: T3's removal of `zuul` had left a dead Travis badge and browser-test instructions in README.md that T3 itself made false. Declined the residual 2 low advisories with reachability reasoning - mocha generates diffs, it never parses patches.
9. **F1 and convergence** - fixed the README, then declared convergence: the closing audit had scored zero High and zero Medium in-envelope apart from F1; commits since matched exactly; backlog empty; every Low logged under Declined with reasons.

End state: 297 passing, including the official Mustache spec compliance suite; `npm audit` at 2 low, 0 critical/high/moderate.

Full iteration-by-iteration record: [journal.md](journal.md). Complete product diff: [fixes.patch](fixes.patch) (12 files, +85/-140, excluding the regenerated package-lock.json).

**Convergence standard**: this run predates the evaluator gate. It converged under the earlier of Jeffy's three standards - a clean closing audit scoring zero High and zero Medium in-envelope, and an empty backlog - and no adversarial evaluator countersigned it. Which standard a run met is recorded for every target in [evals/ATTEMPTS.md](../ATTEMPTS.md).

**Status**: the fixes live in this eval's artifacts. Nothing was pushed upstream - the run stayed in a local clone throughout. All four findings were disclosed upstream with repros and a PR offer in [janl/mustache.js#848](https://github.com/janl/mustache.js/issues/848) (2026-07-23). Merging anything remains the maintainers' call.
