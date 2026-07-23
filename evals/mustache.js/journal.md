# Journal

Append-only. One primary entry per iteration; SALVAGE and ROTATION entries are additional. Never rewrite past entries (filling the current entry's Checkpoint field is completion, not a rewrite).

Heading grammar, exactly:
## iter <i>/<N> | <run-id> | <YYYY-MM-DD> | <task-id or AUDIT or RATCHET or WRAPUP or SALVAGE or ROTATION> | <done|blocked|audit|converged|salvage|rotation>

SALVAGE entries take status salvage; ROTATION entries take status rotation.

run-id is the first 8 characters of the session id. Body fields, in order: Task, Changed, Checkpoint (the jeffy checkpoint commit hash, or none with the reason), Verification, Learnings, Next.

Closed tasks are recorded here as one line each (ID, title, closing evidence), because BACKLOG.md deletes them. Rotation: when this file exceeds 500 lines, move all but the last 10 entries to JOURNAL-archive.md and record the rotation as a ROTATION entry.

## iter 1/8 | f1f30ed3 | 2026-07-22 | AUDIT | audit

Task: First full audit of mustache.js 4.2.0 (Improvement mode, no focus directive). Filled the Operating envelope (6 surfaces) and Verify command (npm test) in PLAN.md; filed 7 tasks and 4 declines in BACKLOG.md.
Changed: PLAN.md (envelope table, verify command), BACKLOG.md (T1-T7, 2 Proposed, 4 Declined), JOURNAL.md, .gitignore (loop state exclusion, added at bootstrap).
Checkpoint: c23357fab3217f1ea1f6a68af64e2703b837e724
Verification: Dimension scores with evidence. correctness: High - bin/mustache crashes on Node 22 (TypeError: Mustache.render is not a function, bin/mustache:101, reproduced) because require('..') of the ESM source returns the module namespace; also path.join(process.cwd(), viewArg) corrupts absolute .js view paths (bin/mustache:58, join output reproduced). testing: High - npm test crashes on Node 22.18: the abandoned esm shim (test/helper.js:13) throws TypeError Function.prototype.apply called on undefined; the suite cannot run at all on current LTS. dependency-hygiene: Medium - npm audit: 107 vulnerabilities (24 critical, 58 high), concentrated in zuul (dead since 2017, depends on personal fork nolanlawson/zuul-ngrok#patch-1), esm, mocha 3, chai 3, eslint 6, puppeteer 2. security: None in-envelope - escapeHtml covers & < > quotes backtick = slash (mustache.js:60-75); shipped library has zero runtime deps; prototype-chain template lookups are out of envelope (developer-authored templates), declined. error-handling: Low - core throws descriptive parse errors; CLI exits with clear messages; unwritable-output stack trace declined. documentation: None beyond T1 root cause - README test instructions become true once T1 lands. architecture, code-quality, performance: None - ES5 single-file by design for browser reach, parse cache in place, no reproduced perf issue. observability: skipped - pure library, no runtime I/O to observe. UX/accessibility: skipped - no GUI; CLI findings live under correctness. developer-experience: covered by T1 (broken gate), T7 (CI matrix caps at Node 15 with deprecated actions).
Learnings: The repo's mustache.js is ESM source (export default, mustache.js:764); npm run build overwrites it in place with a UMD build via rollup - never run npm run build during an iteration, it converts the checked-in source. Native require() of the ESM file on Node 22 succeeds but needs .default. Verify command npm test is red at baseline until T1 lands; the verify-gate revert rule only fires on new breakage.
Next: Execute T1 (fix test loading on modern Node) so the verify gate turns green and guards the rest of the run.

## iter 2/8 | f1f30ed3 | 2026-07-22 | T1 | done

Task: T1 - fix the ESM-source-from-CJS loading class on modern Node. One structural fix across all three sites of the class; T2 closed by the same change because cli-test.js (inside T1's acceptance gate) spawns bin/mustache.
Closed: T1 (High, testing) - npm test now exits 0 on Node 22.18: 296 passing, 13 pending, 0 failing. Closed: T2 (High, correctness) - node bin/mustache view.json template.mustache prints rendered output, exit 0; CLI suite green within npm test.
Changed: test/helper.js (feature-detect native require of the ESM source, .default unwrap, esm shim kept as fallback for Node 10-21, new usesEsmShim global), test/cli-test.js (--require esm flag now driven by usesEsmShim instead of version sniffing), bin/mustache (.default unwrap, no-op on published UMD build), BACKLOG.md (T1 and T2 deleted, class recorded under Settled classes), PLAN.md (two Lessons lines), JOURNAL.md.
Checkpoint: 74c4ed84966d26165e9a9b9f584c133604e49c0e
Verification: Acceptance T1: npm test exit 0 (lint green, 296 passing, 13 pending - pre-existing skips). Acceptance T2: node bin/mustache renders Hello world, exit 0, on Node 22.18. Verify gate: npm test exit 0, first green baseline of the run.
Learnings: cli-test.js was the hidden third site of the class - it injects --require esm when spawning the bin, so any loading fix that ignored it would pass unit tests and still fail the CLI suite. Feature detection (try require, check .default) beats version sniffing because require(esm) landed mid-major at Node 22.12.
Next: T5 - CLI absolute path bug for .js/.cjs views (top of Next).

## iter 3/8 | f1f30ed3 | 2026-07-22 | T5 | done

Task: T5 - CLI mangled absolute paths to .js/.cjs view files: path.join(process.cwd(), viewArg) concatenates instead of resolving when viewArg is absolute.
Closed: T5 (Medium, correctness) - bin/mustache now uses path.resolve(viewArg); absolute .cjs view renders correctly (Howdy LeBron, CLI rox, exit 0) and a regression test guards it in cli-test.js.
Changed: bin/mustache (path.resolve), test/cli-test.js (new test: JavaScript view given as an absolute path), BACKLOG.md (T5 deleted), JOURNAL.md.
Checkpoint: e7bafb834b9af5724ba904956b2814625b6c96e7
Verification: Acceptance: node bin/mustache C:\jeffy-evals\mustache.js\test\_files\cli.cjs test/_files/cli.mustache prints expected output, exit 0, on Node 22.18. Verify gate: npm test exit 0 including the new regression test.
Learnings: path.resolve subsumes the join-against-cwd idiom for user-supplied paths: identical for relative input, correct for absolute. No new operational rule for Lessons.
Next: T3 - remove the dead zuul browser-test stack (top of Next).

## iter 4/8 | f1f30ed3 | 2026-07-22 | T3 | blocked

Task: T3 - remove the dead zuul browser-test stack and clear critical audit findings.
Changed: package.json (removed zuul and zuul-ngrok devDeps; removed pre-test-browser, test-browser, test-browser-local scripts), package-lock.json (uninstall plus npm audit fix), deleted .zuul.yml, .travis.yml, test/create-browser-suite.js, test/render-test-browser-tmpl.mustache, test/helper.js (comment no longer references removed zuul), BACKLOG.md (T3 to [b]), JOURNAL.md.
Checkpoint: a9da3f3c2c158877d33910be20ffe0c92f224091
Verification: Removal delivered: npm audit went 107 vulnerabilities (24 critical) to 17 (4 critical) after uninstall plus npm audit fix (attempt 1, cleared extract-zip); no dependency resolves from a git fork (grep resolved-git in package-lock.json empty); npm test exit 0. Acceptance NOT fully met: 0 criticals requires the mocha major upgrade because all 4 residual criticals (mocha, growl, minimist, mkdirp) sit in the mocha 3 tree - that is T4's scope, and fixing it inside T3 would batch two tasks. Marked [b]: re-verify T3 acceptance after T4.
Learnings: Overlapping acceptance checks across tasks create false blockage - T3's 0-critical criterion double-counted T4's outcome. Write acceptance checks scoped to the task's own diff (here: zuul tree gone, no fork deps) and leave global thresholds to a dedicated task or the closing audit.
Next: T4 - upgrade mocha and chai to supported majors, then re-verify T3.

## iter 5/8 | f1f30ed3 | 2026-07-22 | T4 | done

Task: T4 - upgrade mocha and chai off EOL majors; re-verify blocked T3 afterward.
Closed: T4 (Medium, dependency-hygiene) - mocha ^11.7.6 and chai ^4.5.0 installed; suite passes unchanged (297 passing, 13 pending); mocha/chai trees carry zero high advisories (only diff low remains, via mocha). serialize-javascript pinned to ^7.0.7 via npm overrides because mocha pins ^6.0.2 which has two open advisories. Closed: T3 (Medium, dependency-hygiene) - re-verified acceptance after T4: npm audit 0 critical, 0 git-fork resolved deps in package-lock.json, npm test exit 0.
Changed: package.json (mocha ^11.7.6, chai ^4.5.0, overrides serialize-javascript ^7.0.7), package-lock.json (upgrade plus npm audit fix clearing minimist and mkdirp criticals under eslint), BACKLOG.md (T3 and T4 deleted; discovered T8 jshint removal and T9 rollup upgrade filed; T6 re-tiered Low to Medium in Next - its tree now owns most remaining highs), JOURNAL.md, PLAN.md (Lessons line on overrides).
Checkpoint: b8ef2897589c320e560619a5c7a7497352fb657c
Verification: Acceptance T4: npm test exit 0; audit vulnerabilities total 13 (0 critical, 9 high, 0 moderate, 4 low); mocha tree entries are mocha low and diff low only; chai absent. Acceptance T3 re-verified as above. Verify gate: npm test exit 0.
Learnings: npm audit attribution moves as trees change - the minimist and mkdirp criticals that looked mocha-owned in iter 4 turned out to be under eslint after the mocha upgrade, cleared by plain npm audit fix. The overrides field is the right tool when a maintained parent pins a vulnerable transitive dep.
Next: T8 - remove jshint devDep and Rakefile hint task (smallest remaining Medium).

## iter 6/8 | f1f30ed3 | 2026-07-22 | T8 | done

Task: T8 - remove the jshint devDep (high advisories via its minimatch tree) and the Rakefile hint task that was its only reference.
Closed: T8 (Medium, dependency-hygiene) - jshint uninstalled, Rakefile hint task deleted; jshint absent from npm audit output; audit now 12 total (0 critical, 8 high), npm test exit 0.
Changed: package.json and package-lock.json (jshint removed), Rakefile (hint task deleted), BACKLOG.md (T8 deleted), JOURNAL.md.
Checkpoint: 3897b1578af9d66de4be48bf69dcc4c4734c15e5
Verification: Acceptance: npm audit vulnerability list contains no jshint entry (remaining: diff, eslint, external-editor, file-entry-cache, flat-cache, flatted, inquirer, lodash, minimatch, mocha, rollup, tmp); npm test exit 0. Verify gate: npm test exit 0. The surviving minimatch high is deduped solely under eslint 6 now - T6 owns it.
Learnings: None new - straightforward removal.
Next: T6 - eslint 6 to 8 upgrade, which owns most of the remaining 8 highs.

## iter 7/8 | f1f30ed3 | 2026-07-22 | T6 | done

Task: T6 - upgrade eslint 6 (EOL) to eslint ^8, keeping the existing .eslintrc format and rules unchanged.
Closed: T6 (Medium, dependency-hygiene) - eslint ^8.57.1 installed; zero config changes needed (.eslintrc legacy format and all rules valid in 8); lint passes clean.
Changed: package.json and package-lock.json (eslint ^8), BACKLOG.md (T6 deleted), JOURNAL.md.
Checkpoint: 7af25f902044a64dc91f41dcf9dc38196bc15966
Verification: Acceptance: npm run test-lint exit 0 under eslint 8; npm audit lists no eslint-tree entries - remaining vulnerabilities are diff (low, via mocha), mocha (low), rollup (high, T9): 3 total, down from 12. Verify gate: npm test exit 0.
Learnings: None new - the 2019-era .eslintrc with explicit rules only (no extends) ported to eslint 8 without a single edit.
Next: T9 - rollup 1 to 4 (final open Medium, last high advisory); T7 (Low, CI matrix) remains for a future run if the budget ends first.

## iter 8/8 | f1f30ed3 | 2026-07-22 | T9 | done

Task: T9 - upgrade rollup 1 (EOL, high advisory) to rollup ^4, validating the UMD build pipeline on a scratchpad copy because npm run build overwrites the checked-in ESM source in place.
Closed: T9 (Medium, dependency-hygiene) - rollup ^4 installed; scratch build validated: cp mustache.js to scratch .mjs, npx rollup --format umd --name Mustache produced a UMD file whose require() exposes working render with correct escaping (x and &lt;y&gt;) and version 4.2.0; npm test exit 0.
Changed: package.json and package-lock.json (rollup ^4), BACKLOG.md (T9 deleted), JOURNAL.md.
Checkpoint: 3c6cd02f12fa93b8afe626b644c83ace9645eeb7
Verification: Acceptance: scratch UMD build renders correctly as above; npm test exit 0. Verify gate: npm test exit 0. Final audit state: 2 vulnerabilities total, both low (mocha and its diff dep, no upstream fix released), 0 critical, 0 high, 0 moderate - down from 107 (24 critical) at run start.
Learnings: rollup 1 to 4 needed no flag changes for this single-file UMD wrap; the Windows native binary installs via optional deps automatically.
Next: Handoff for the next run: T7 (Low, CI matrix modernization) is the only open task; Proposed items (spec submodule update, playwright browser testing) await owner decisions; the closing audit for convergence has not yet run - a fresh run of 3-4 iterations should execute T7, then run the full closing audit and likely converge.

## iter 1/8 | f1f30ed3 | 2026-07-22 | T7 | done

Task: T7 - modernize CI workflows: dead action versions (checkout v1/v2, setup-node v1, artifact v2 actions which GitHub disabled, archived denolib/setup-deno) and Node matrices capped at 15, leaving the run-1 fixes unguarded on modern Node. Second run, budget 8, no focus.
Closed: T7 (Low, developer-experience) - verify.yml: tests matrix now 18.x/20.x/22.x (dev toolchain floor is 18 since mocha 11 and rollup 4), lint and build on 20.x, all actions to checkout@v4, setup-node@v4, upload/download-artifact@v4; tests-on-legacy job kept intact (it tests the built UMD with pinned mocha@3 on Node 0.10-8). usage.yml: same action bumps, consumption matrices extended with 20.x/22.x, browser-usage bumped 12.x to 20.x (npm ci with lockfileVersion 3 and mocha 11 need modern Node), denolib/setup-deno@master replaced by maintained denoland/setup-deno@v2 with the deno version pin unchanged.
Changed: .github/workflows/verify.yml, .github/workflows/usage.yml, BACKLOG.md (T7 deleted), JOURNAL.md.
Checkpoint: a82a98e3280dd197f07dd65f651d812217f6543d
Verification: Acceptance: verify.yml matrix line reads [18.x, 20.x, 22.x]; grep across .github/workflows shows no checkout@v1/v2, setup-node@v1, artifact@v2, or denolib references (denoland/setup-deno@v2 is the current major); both files parse clean via js-yaml. Verify gate: npm test exit 0. Caveat: CI runtime behavior is not verifiable locally - matrix jobs on Node 0.10-8 via setup-node@v4 are best-effort compatibility claims only the owner's CI can confirm.
Learnings: None new.
Next: Backlog has zero open tasks - next iteration runs the full closing audit per the Definition of done.

## iter 2/8 | f1f30ed3 | 2026-07-22 | AUDIT | audit

Task: Full closing audit per Definition of done - rescore every applicable dimension with fresh evidence against the envelope, Settled classes, and Declined ledger.
Changed: BACKLOG.md (F1 filed in Next; jsdiff-advisory decline recorded), JOURNAL.md.
Checkpoint: e0b552b30ca1b838481f2e11849a8ffd1aa0b3a7
Verification: Dimension scores with fresh evidence. documentation: Medium - README line 5 carries a dead travis-ci.org badge and lines 575-579 instruct npm run test-browser-local plus a zuul URL, both removed by T3 in run 1; following the docs fails; filed F1. dependency-hygiene: Low, declined - npm audit fresh: 2 low only (mocha and its diff dep, jsdiff DoS in parsePatch/applyPatch); vulnerable path unreachable (mocha generates diffs, never parses patches), dev-only, no sane fix; recorded under Declined. correctness: None - npm test fresh exit 0 (297 passing incl. the mustache spec compliance suite over the test/spec submodule); CLI exercised end to end this run (JSON view, .js view, absolute path, partials via cli-test suite inside the gate). testing: None - suite green on Node 22, CLI suite exercises the real binary, regression test added in run 1 covers the absolute-path fix. security: None in-envelope - mustache.js unchanged across both runs (git diff 972fd2b..HEAD names no core file), so run 1's clean escaping evidence carries; zero runtime deps confirmed by package.json. error-handling: Low standing declines only, code unchanged. architecture, code-quality, performance: None - core file unchanged, prior evidence carries per audit discipline. dependency-hygiene beyond advisories: None - all devDeps on current majors (mocha 11, chai 4, eslint 8, rollup 4), overrides pin documented in Lessons. developer-experience: None - gate green on current LTS, CI on maintained action majors (runtime verifiable only in owner CI, noted in iter 1). observability: skipped - pure library, no runtime I/O. UX/accessibility: skipped - no GUI; CLI covered under correctness. Verify gate: npm test exit 0.
Learnings: A removal task's blast radius includes every doc sentence pointing at the removed thing - grep docs for the removed names in the same iteration next time.
Next: Execute F1 (README badge and test docs); with the backlog then empty and only F1 commits after this audit, the following iteration can declare convergence.

## iter 3/8 | f1f30ed3 | 2026-07-22 | F1 | converged

Task: F1 - fix README misleading docs (dead Travis badge, instructions for the removed zuul browser-test stack), then declare convergence per the Definition of done.
Closed: F1 (Medium, documentation) - badge now points at the GitHub Actions verify workflow; Browser tests section replaced with Module system tests reflecting the real CI surface and the runnable local command npx mocha test/module-systems/browser-test.js.
Changed: README.md, BACKLOG.md (F1 deleted; Converged line appended at bookkeeping), JOURNAL.md.
Checkpoint: b8fe032bc4249e7cf4a3646054397922c90df23b
Verification: Acceptance F1: grep -icE travis-or-zuul-or-test-browser README.md returns 0; npm test exit 0. Convergence conditions: closing audit at e0b552b30ca1b838481f2e11849a8ffd1aa0b3a7 scored zero High and zero Medium in-envelope apart from F1 which it filed; commits since that audit are exactly its bookkeeping (JOURNAL.md only) plus this F1 fix (git log e0b552b..HEAD verified); Now, Next, Later all empty; every Low is in Declined with reasons; Proposed items excluded by rule; Verify command green in this declaring iteration (npm test exit 0, 297 passing, 13 pending).
Learnings: None new.
Next: Run converged. Remaining owner decisions live under Proposed (spec submodule update, optional playwright browser testing). Future runs will ratchet against the Converged commit unless code changes or a focus directive arrives.
