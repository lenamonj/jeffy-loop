# Jeffy eval: pillarjs/path-to-regexp

**Target**: [pillarjs/path-to-regexp](https://github.com/pillarjs/path-to-regexp) (8,598 stars, verified via `gh api repos/pillarjs/path-to-regexp --jq '.stargazers_count'` on 2026-08-13) at tag `v8.4.2`, commit `cbf30259e6d34d6135f9e7dbaa3371e7188f9936`, MIT. TypeScript, in a local clone; the loop's work was never pushed anywhere. path-to-regexp turns Express-style route patterns into regular expressions, and sits under a large share of the JavaScript routing ecosystem.

**Convergence standard**: evaluator countersigned. The adversarial evaluator's verdicts for every run are in the narrative below; the standard each target met is recorded in [evals/ATTEMPTS.md](../ATTEMPTS.md). This run declared under the v1.9.0 severity floor, and what it carried is named below.

**Three runs, 27 iterations, converged at `813b89f2` on 2026-08-13** at iteration 8 of a 10-iteration budget, two iterations unspent, inside a pre-registered three-run budget. **15 findings closed - 11 Medium, 4 Low, and no High at all.** The shipped change is **9 files, +241/-24**. **Five evaluator invocations across the three runs returned four REJECTs before the PASS.**

## The run that did not finish, disclosed first

**Run 1 was killed by a host crash**, not by a stopping rule. The machine went down at 01:29 local on 2026-08-13, during iteration 10 of 10, with the gate's invocation-1 REJECT already committed at iteration 9 and an unfinished edit in the working tree. Nine iterations of that run are on the record; the tenth does not exist. The uncommitted work was discarded rather than carried, and run 2 started from run 1's last checkpoint. This is stated because a run count is only meaningful with its ending: three runs were budgeted and three were spent, but one of them ended on hardware rather than on the rule.

## What the loop found

No High findings in three runs against a library this heavily used is itself a result, and the Mediums are where the interest is:

- **PTR-3** (Medium, correctness): `stringify` emitted a parameter name with `JSON.stringify`, while `parse` reads a backslash inside quotes as "take the next character literally". The emitter and the parser disagreed about escapes, so a name round-tripped through `stringify` then `parse` could come back different. Closed class-complete by routing both quoting sites through one `quoteName`, with the affected code points enumerated exactly as U+0000 to U+001F and U+D800 to U+DFFF by comparing old and new emitters over every BMP code point plus astral samples.
- **PTR-9** (Low, error handling): an empty `delimiter` was accepted by every entry point and silently degraded matching instead of failing.
- **PTR-1** (Medium, code quality): `toRegExpSource` emitted an alternation whose two branches were identical whenever the text preceding a wildcard equalled the delimiter.
- **PTR-8** (Medium, testing): **the project's own ReDoS gate was load-sensitive** - 15 of its 101 assertions failed on a saturated machine while every one of them passed idle. A gate that flakes under load is a gate that gets disabled.
- **PTR-5, PTR-7** (documentation): `decode`'s default throws `URIError` on percent-encoding a URL may legitimately carry, undocumented; and the Readme's Errors section never mentioned the exported `PathError` class or its `originalPath` property, so the documented way to catch a parse failure was missing.
- **PTR-6** (Low, developer experience): `npx vitest run` failed out of the box with "No test suite found in file src/cases.spec.ts", because the fixture corpus carried a `*.spec.ts` name and only ts-scripts' hardcoded `--passWithNoTests` hid it. Closed at the name rather than with a config exception.

## The gate rejected four times, and each rejection was about the instruments

Four of the five evaluator invocations came back REJECT, and the pattern across them is the useful part: **not one rejection was a missed defect in the library. Every one was a defect in the run's own evidence.**

- **Run 1's gate** re-opened `PTR-4`, which had been carried blocked on flakiness that a later iteration had already removed. A blocked task is a claim with an expiry, and no iteration went back to re-test it.
- **Run 2's first gate** rejected on the Verify command carrying **randomized assertions**: a starved recheck search could report `safe` where the suite asserts `vulnerable`, and could equally turn 146 `safe` assertions green without having searched at all.
- **Run 2's second gate** rejected on the Oracle class line calling the verify command "four stages" while it runs five, the omitted stage being the only one that type-checks the spec files.
- **Run 3's gate** rejected on a Settled class recorded as closed while a third site still emitted duplicate branches.

The declaration then came at iteration 8, on invocation 2, and that gate did not take the run's load-bearing claim on trust. `E-4`'s argument for where the class boundary sits was written from reading the code; the gate built a mutated build and executed it, `match(["/x/:a","/x/:a","/y/:b"])("/y/foo")` returning `{a:"foo"}` with the collapse and `{b:"foo"}` without, which is what turned an argument into evidence. It also hunted rather than only re-ran: a capture-group-count invariant over 6,660 pattern and option pairs, 2,920 compile-then-match round-trips with a parse-stringify identity sweep, and recheck over eight shapes that duplicate at the open join, all rated safe.

## What is still open, and why it did not block

**`PTR-2` is an open Medium at convergence, blocked with its reason recorded, and it is a security finding.** recheck rates 3 of 48 generated regexps unsafe, all of them the shape `/:a--:b--:c`. Eight formulations were tried; every one that clears the verdict drops the separator-absorbing parse that `match("/:a-:b")("/a-b-c")` returning `a = "a-b"` depends on. Closing it is therefore a public behaviour change, which the loop does not get to make: the choice sits under Proposed as a question for the owner. The rules allow a Medium that is blocked with its reason recorded, and the receipt names it rather than leaving it to be discovered in the ledger.

## Verify command

```
npm test
```

**Oracle class**: the project's own published gate, five stages, the list derived from a real run by a probe battery rather than from prose - `tsc --build` of the published entry point, a prettier format check, `tsc --noEmit` over the whole project (the only stage covering the spec files and the fixture, since `tsconfig.build.json` excludes them), the vitest suite with v8 coverage, and a **hard 2 kB size-limit budget on the built bundle**, so a fix that grows the bundle fails the command with every assertion green.

**Environment fingerprint**: Linux x86_64 (WSL2), Node v24.17.0, TypeScript 5.9.3, vitest 3.2.7, recheck 4.5.0. The exclusion sweep for skipped or guarded tests **matches nothing at all**: no skip, no todo, no platform guard, no environment guard, so no entry in this run claims a test green that never ran.

**Verify duration**: 21s measured 2026-08-13, 18s to 26s idle across about thirty timed runs. **Surface inventory**: 6 rows, all 6 swept, none unreachable.

**Final state**: `npm test` exit 0, 531 assertions, 99.5% line coverage, size-limit 1.99 kB of 2 kB.

**Declared limit, carried from the target brief**: there is **no lockfile at this tag**, so `npm install` resolves fresh semver ranges and the dependency set is not reproducible run to run.

## Disclosure

The loop ran against a local clone on a branch. Nothing here was pushed to pillarjs/path-to-regexp, and no issue or pull request was opened. `journal.md` is the run's unedited journal across all three runs and `fixes.patch` is the complete diff from `v8.4.2` to the converged commit, excluding the loop's own plan, backlog, journal and probe files.
