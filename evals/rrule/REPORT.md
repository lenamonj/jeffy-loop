# Jeffy eval: jkbrzt/rrule

**Target**: [jkbrzt/rrule](https://github.com/jkbrzt/rrule) (3,738 stars, verified via `gh api repos/jkbrzt/rrule --jq '.stargazers_count'` on 2026-08-08) at `9f2061febeeb363d03352efe33d30c33073a0242`, upstream master at the time of the run. BSD-3-Clause. TypeScript, in a local clone; the loop's work was never pushed anywhere. rrule implements RFC 5545 recurrence rules for JavaScript and is the library behind a large share of calendar and scheduling front-ends.

**This is a full `/jeffy` loop run that reached machine-checked convergence, in four runs of 33 iterations.** **23 findings filed and closed (10 High, 9 Medium, 4 Low)**, of which the shipped-code change is **15 files, +589/-193**. Converged at `bb9931395325c2c109705bbe155d0f1581b5ca2d` on 2026-08-08: empty ledger, all **15 surface-inventory rows swept**, the verify command re-run fresh for this receipt, and the adversarial evaluator's PASS on record after one rejection.

It is the second target chosen for the cold cohort, whose selection rule is an oracle the loop cannot rewrite into agreement. rrule declares itself a port of `python-dateutil`'s rrule module, so a reference implementation of the same RFC exists and can arbitrate.

## The oracle overruled the loop, and the loop accepted it

This is the run's most important event and it is a finding the loop **withdrew**.

In run 3, iteration 2, an audit filed **H7 as a High engine defect**: mixing an nth-prefixed `BYDAY` value with plain ones yields no occurrences instead of their union, so `FREQ=YEARLY;BYDAY=+2MO,TU,WE,TH,FR` returns nothing where RFC 5545's reading gives 211 occurrences in 2020. The reproduction stood up. The next iteration went to fix it, checked the reference implementation first, and stopped:

> The reproduction stood up but the diagnosis did not: python-dateutil returns the same empty result, so this is parity with the library this project declares itself a port of, not a porting error.

H7 was withdrawn and replaced by **M3**, a documentation task adding a fourth bullet to the README's existing "Differences From iCalendar RFC" section with a runnable example, plus a **Proposed** item putting the divergence question to the project owner rather than deciding it.

Re-derived independently for this receipt on 2026-08-08, all three numbers:

| Implementation | `FREQ=YEARLY;BYDAY=+2MO,TU,WE,TH,FR`, 2020 |
|:---|---:|
| rrule at the converged tree | **0** occurrences |
| `python-dateutil` 2.9.0.post0 | **0** occurrences |
| RFC 5545 union reading | **211** occurrences |

The 211 checks out by hand: 2020 began on a Wednesday and had 366 days, giving 52 Tuesdays, 53 Wednesdays, 53 Thursdays and 52 Fridays, which is 210, plus the second Monday.

A loop with no external referee closes H7 as a High, ships a behavioural change to a public library, and books it as a win. This one reproduced its own finding, consulted the oracle, lost the argument, and recorded the loss. No target in this corpus had produced that before, and it is the specific behaviour the cold cohort exists to make possible.

**The owner's decision, recorded here rather than left open: do not diverge.** rrule's declared purpose is fidelity to dateutil, the project already maintains a documented list of deliberate RFC deviations, and the realistic deployment shares stored RRULE strings between JavaScript front-ends and Python back-ends where a semantic split would expand the same rule to 211 occurrences on one side and 0 on the other. The delta is documented instead. Note also where the behaviour originates: the intersection semantics are dateutil's, and rrule is porting them faithfully, so this is not a defect the JavaScript library introduced.

## The oracle also ran on every iteration, unmodified

The verify command is `npx jest`, which runs the project's own suite including `test/dateutil.test.ts`, the fixtures derived from the reference implementation.

**The loop never touched `test/`.** Not one line, across 33 iterations. Derived rather than asserted: `git diff --stat 9f2061f..HEAD -- test/` is empty, and the count of `it(`/`test(` invocations under `test/` is **109 at the base commit and 109 at the converged commit**.

The suite reads **381 passed, 9 skipped, 390 total** at the converged tree, identical to the baseline measured before the first iteration.

That identity means something different here than it would elsewhere. The gate the loop could not edit ran against every one of the 589 inserted lines, and reported no regression - not because nothing was measured, but because nothing broke.

## What the loop found

23 findings closed: **10 High, 9 Medium, 4 Low**, spread across parsing, serialization, natural-language rendering and validation.

The Highs are dominated by inputs that failed silently rather than loudly:

- **`fromText` and `fromString` returned the library's default `FREQ=YEARLY` rule** for input their parser recognised nothing in, so unparseable third-party text came back as a plausible recurrence instead of an error.
- **`parseText` built its `until` date with `Date.parse`**, which reads a date-only string in local time while the rest of the library treats every Date as a UTC wall clock, so the same text parsed to a different rule on every host.
- **`rrulestr` resolved its documented `dtstart` and `tzid` options separately in each of two result shapes**, so the shapes disagreed: one branch ignored both options, the other let them override values the string itself carried, and compatible mode crashed.
- **`optionsToString` serialized the two-letter weekday form to `BYDAY=undefined`**, so a rule built through the library's own exported type could not be read back.
- **`isFullyConvertibleToText` never evaluated its own capability table**, reporting rules fully convertible that `toText` renders only in part, while `toText` withheld the `(~ approximate)` marker that says so.
- **Weekday tokens were validated on the RFC-string path and not the programmatic one**, so an unrecognised `byweekday` string was swallowed into an empty occurrence set while any string `wkst` became `undefined` and hung the iterator.

Two of the ten are worth naming for what they say about the run rather than the library. **H4 and H5 were filed by the evaluator gate**, not by an audit, after it rejected run 2's convergence attempt - and H4 was a defect inside a class run 2 had recorded as settled. And **B1 was self-inflicted**: the loop's own committed artifacts sat inside the project's format gate, so `yarn build` failed at `yarn format-check`. The run filed it as a High against itself and fixed it by excluding its own paths in `.prettierignore`.

Three findings were closed as structural tasks rather than as the instances they were filed as, under the rule that the third finding sharing a root cause replaces instance patching.

## The evaluator earned the run

Two invocations across four runs, **one REJECT and one PASS**.

Run 2 spent its final iteration on the gate and was rejected; it ended out of budget. The two findings that rejection produced, H4 and H5, took run 3 two iterations to close. Run 4 then invoked the gate **early** - the iteration the ledger first sat empty with a clean full audit on record and three iterations still in hand - and declared on the PASS in that same entry.

Runs 1 and 3 never reached the gate. Both ended at their budget with a WRAPUP rather than starting work they could not finish, and run 3's entry records the reasoning explicitly so the next run would not have to reconstruct it.

## Honest caveats

- **The project's own test suite is unchanged**: 109 test invocations before and after. All of the run's regression evidence - 12 batteries, 29 files, 4,702 lines - lives in `.jeffy/probes/`, which is loop state rather than the project's harness. A maintainer applying `fixes.patch` receives the fixes with none of the tests that prove them, and reproducing that proof means running the batteries from this receipt's own structure.
- **Nothing was filed upstream.** The repository has been dormant since 2024-06-27 with 212 open issues, so a disclosure has no realistic path to review. This follows the same reasoning recorded for `ta` and `dayjs`.
- **One Proposed item was closed by an owner decision, not by evidence** - see above. It is recorded rather than silently dropped.
- **The 9 skipped tests in the suite were not investigated.** They were skipped at the base commit and remain skipped; the run neither enabled nor examined them, and this receipt does not claim they hide nothing.
- Severity is judged against the operating envelope the run declared in its first audit, which treats RFC strings and natural-language text from third parties as untrusted input.
- The run executed entirely on Windows against Node 22.

## Independently re-verified for this receipt

Every figure above was derived from the tree and the journals on 2026-08-08:

- 4 runs and 33 iterations, from 34 journal entries less the one ROTATION entry, cross-checked against 66 checkpoint commits in `git log 9f2061f..HEAD`.
- The product diff with the four state files, `.jeffy/` and `.claude/` excluded: 15 files, +589/-193.
- Test invocation counts by `git grep -cE "^\s*(it|test)\("` under `test/` at both commits: 109 and 109.
- The suite re-run at the converged tree: 381 passed, 9 skipped, 390 total.
- The three occurrence counts in the parity table, each executed rather than quoted: the converged tree through `ts-node`, `python-dateutil` 2.9.0.post0 through its own `rrule`, and the RFC figure by hand from the 2020 calendar.
- `fixes.patch` applies to a clean clone of pristine upstream `9f2061f` taken fresh from GitHub, not to the loop's tree, and that patched clone runs the project's own suite to **381 passed, 9 skipped, 390 total** - the same figures as the loop's tree and as the untouched baseline.
- The Converged hash is reachable from HEAD, checked with `git merge-base --is-ancestor`.

`journal.md` is the run's complete journal, both the rotated archive and the live file, exactly as the loop wrote it.
