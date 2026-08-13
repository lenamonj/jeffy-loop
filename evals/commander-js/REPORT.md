# Jeffy eval: tj/commander.js

**Target**: [tj/commander.js](https://github.com/tj/commander.js) (28,358 stars, verified via `gh api repos/tj/commander.js --jq '.stargazers_count'` on 2026-08-13) at tag `v15.0.0`, commit `ba6d13ddb4243e5913367734f8c159089ffe7834`, MIT. JavaScript, in a local clone; the loop's work was never pushed anywhere. commander.js is the most widely used command-line interface framework in the Node ecosystem.

**Convergence standard**: evaluator countersigned. The adversarial evaluator's verdict for this run is in the narrative below; the standard each target met is recorded in [evals/ATTEMPTS.md](../ATTEMPTS.md).

**This is a full `/jeffy` loop run that reached machine-checked convergence, in one run of 10 iterations against a pre-registered budget of three.** **Seven findings closed - 3 Medium, 4 Low, and no High at all** - with **two Lows carried** at the declaration. The shipped change is **11 files, +228/-8**, of which the runtime surface is `lib/command.js` and `lib/option.js`. Converged at `1d5e59f9f0ee7430828c0e1f7623edd221992bd5` on 2026-08-13, at the **last budgeted iteration**, after an evaluator REJECT at invocation 1 and a PASS at invocation 2.

## This is the cleanest target in the corpus, and the receipt should say so first

The findings here are modest and that is the result, not a disappointment. commander.js arrives with 1,373 passing tests, a TypeScript type-surface check that runs in the same command, and green CI across three operating systems and three Node versions. The loop swept all 22 surface-inventory rows with a known-answer battery each in the opening iteration, and the worst thing it found in the entire public API was a `TypeError` from a malformed flag string. There is no security finding, no data-corruption finding, and nothing an ordinary user would hit.

What it did find, in the order the audit scored it:

- **A1** (Medium, correctness): `.arguments('')` and `.arguments('   ')` registered one nameless **required** argument, so the command could never run - the usage line advertised an argument with no name and parsing demanded it.
- **A2** (Medium, error handling): an option flag whose long name contains an empty dash-separated word - a doubled dash, or a trailing one - produced a raw `TypeError` out of `camelcase`, or silently produced an empty attribute name. Now refused at declaration with a stated rule, and the rule is written into the Readme.
- **A7** (Medium, UX): a group of short options split across a parent and a subcommand reported a **fabricated token** in its error. `deploy -dry-run` printed `error: unknown option '-ry-run'`, naming an argument the user never typed. This one was filed by the evaluator, not the audit - see below.
- **A3, A4** (Low, UX): `program help <unknown>` printed root help to stderr and exited non-zero without saying the name was not a command; an unknown option inside a short-option group was reported as the leftover of splitting that group.
- **A5** (Low, testing): `copyInheritedSettings` copied `_showSuggestionAfterError` with **no test pinning it** - deleting the line left the suite green.
- **A6** (Low, dependency hygiene): one high-severity advisory in a transitive development dependency.

## The gate rejected, and the rejection was the best finding of the run

The run reached iteration 9 with a clean full audit already on the record and invoked the gate. It came back **REJECT**, and the reason was A7 above: a real, reproducible fabricated argument in a user-facing error message, in the code the run had itself touched at iteration 5.

That left one iteration. Under the one-transaction rule the closing iteration fixed A7, proved the fix red-then-green through real CLI processes, re-invoked the gate, and declared on the **PASS at invocation 2** - which is the exemption's intended use and the reason it exists. The gate's second invocation re-ran the verify command, the batteries and `npm audit`, exercised the new state across siblings, repeated parses, coinciding tokens, default-command dispatch and the help-command fallback, re-ran the acceptance checks of all six earlier tasks, and re-scored the carried Lows.

## The carried Low that the fix itself created

**A9 is a defect this run introduced.** The A7 fix hands a subcommand the split its parent computed; if a `preSubcommand` hook throws before that subcommand parses, the subcommand keeps the handed-down split, so a later direct parse can name an argument absent from its own input. The evaluator recorded it as an observation rather than a REJECT reason, the loop reproduced it independently, scored it Low, and **left it unfixed on purpose**, because a fix after a PASS invalidates that PASS and there was no invocation left to spend. It is published here rather than quietly repaired.

The other carried Low, **A8**, is pre-existing: `.arguments()` splits only on runs of spaces, so a tab-separated spec silently becomes one malformed argument.

## Verify command

```
npm test
```

**Oracle class**: unit and integration tests over the library's own public API - `node --test` across more than 100 test files driving real `Command` objects and spawning real executable subcommands from `tests/fixtures/` - followed by the TypeScript type-surface check `tsd && tsc -p tsconfig.ts.json` over `typings/index.d.ts`. The suite carries exactly one skip, an unconditional `test.skip` for a `.ts` subcommand suffix, and the environment fingerprint names it, so no entry in this run claims it green.

**Verify duration**: 19s measured 2026-08-12. **Surface inventory**: 22 rows, all 22 swept, each by an executed known-answer battery under `.jeffy/probes/`, all of them written in the opening iteration before any finding was filed.

**Final state**: `npm test` exit 0 with 1,390 tests, 1,389 passing, 0 failing, 1 skip; `npm run test-all` also exit 0.

## A process note

The target was chosen to test a specific risk, written down before iteration 1: that a library this well tested would yield nothing at all, in which case the run would have converged on an empty ledger and the receipt would have said so. It yielded three Mediums, none of them dramatic. Both halves of that prediction are worth publishing - a corpus that only records the targets where the loop found something impressive is measuring the selection, not the method.

## Disclosure

The loop ran against a local clone on a branch. Nothing here was pushed to tj/commander.js, and no issue or pull request was opened. `journal.md` is the run's unedited journal and `fixes.patch` is the complete diff from `v15.0.0` to the converged commit, excluding the loop's own plan, backlog, journal and probe files.
