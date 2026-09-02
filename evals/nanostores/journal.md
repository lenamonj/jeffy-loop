# Journal archive

Entries moved out of JOURNAL.md by rotation, oldest first. Appended to, never rewritten.

## iter 1/10 | fa642772-022756 | 2026-09-02 | AUDIT | audit

Task: First audit of a fresh Jeffy project. Fill the Operating envelope, the
Surface inventory, the Verify command block and the Stated counts table in
PLAN.md, then probe the whole public surface breadth-first and file findings.

Changed: PLAN.md (envelope surfaces, 20 inventory rows, Command/Oracle
class/Environment fingerprint/Verify summary pattern/Verify count, three
Stated counts rows), BACKLOG.md (11 findings filed).

Checkpoint: b7d817366646d9c7c0723ba430c101da0a5745b7

Verification: `pnpm test` through quiet-verify.sh - green (6s), summary line
`. test:coverage: ℹ pass 61`, so Verify count is 61 as recorded. Every finding
below was reproduced by running it; each acceptance check was executed against
the unfixed tree and observed to fail. check-claims.sh: 3 checked, 0
mismatched, 0 errored, 0 skipped. Three test modules run in isolation
(keep-mount, task, map-creator) all pass, so no order dependence was found in
the cheapest modules.

Dimension scores. These claim only what this audit probed; all 20 Surface
inventory rows are still unswept, so no row is certified by an executed
battery and these scores are the audit's reading, not a sweep.
- correctness: High (NS-1, NS-2)
- error handling: Medium (NS-7, NS-11)
- documentation: Medium (NS-8; README's Batching promise is what NS-1 breaks)
- architecture: None
- code quality: Low
- security: None. setPath/setByKey were probed for prototype pollution -
  `setPath({}, '__proto__.x', 1)` leaves `({}).x` undefined - and the library
  has no adversarial input surface per the envelope.
- testing: Low. The suite is green at 100% line coverage and every one of the
  11 findings is invisible to it, which is the gap; missing tests are Low by
  the severity ceiling.
- performance: None
- dependency hygiene: None. Devdependencies only; no runtime dependency.
- developer experience: None
- observability: Low (NS-7 loses errors, NS-11 can throw from the warn path)
- UX and accessibility: not applicable - a library with no user-facing surface.

Findings filed: NS-1, NS-2 (High); NS-3..NS-8 (Medium); NS-9..NS-11 (Low).

Learnings: The verify command is `pnpm test`, which runs five scripts through
`pnpm run /^test:/` in about 6s. Probe scripts must import the library by
absolute path or run with cwd at the project root; a `/tmp` script importing
`./index.js` resolves against `/tmp`. `deepMap()` prints a deprecation trace
on every construction, so probe output needs `2>/dev/null` or a grep filter.

Next: NS-1, the top open High.
## iter 2/10 | fa642772-022756 | 2026-09-02 | NS-1 | done

Task: NS-1 (High, runtime, correctness) - `batch()` called from inside a store
listener re-invoked listeners that had already run in the same flush.

Changed: atom/index.js (drainQueue advances lqIndex past the current entry
before invoking that entry's listener, resets lqIndex only after the queue
drains, and the unsubscribe scan in listen() now starts at lqIndex rather than
lqIndex + QUEUE_ITEMS_PER_LISTENER to stay aligned with that pre-advance),
atom/index.test.ts (two regression tests), BACKLOG.md (NS-1 deleted), PLAN.md
(four Lessons).

Checkpoint: 3af8aa73f67026c7483a77003e8d6b28623872cf

Verification: the filed reproduction was run first and printed `A,A,B`; after
the fix it prints `A,B`, which is the acceptance check as written. The two new
tests were run against the unfixed atom/index.js by stashing that one file:
`bnt -t 'replay listeners already run' atom/index.test.ts` reports fail 1 on
the unfixed tree and pass 1 on the fixed one, so the tests discriminate.
`pnpm test` through quiet-verify.sh - green (5s), `. test:coverage: ℹ pass 61`,
unchanged because node:test rolls this file into one reporter entry.
check-claims.sh: 3 checked, 0 mismatched, 0 errored, 0 skipped. No battery
under .jeffy/probes/ exists yet, so none owned these paths.

Contract preserved: listeners still run in queue order, still receive
(value, oldValue, changedKey), a listener unsubscribed mid-flush still has its
pending entries dropped, and the last thrown listener error is still rethrown
after the queue drains. What changed is only that a re-entrant drain resumes
instead of replaying, so the README's Batching promise - listeners and effects
fire at most once per flush - now holds when the batch is opened from inside a
listener. No public signature or documented behavior changed, so no
documentation edit was due and no Surface inventory row needed flipping; all
20 rows were already unswept.

Size: the change is 4 B smaller, not larger - size-limit reports Atom 368 B
against its 372 B limit and Popular Set 911 B against 912 B. The limits in
package.json are left where they are, so package.json's description and the
README byte figures still agree and test:synced stays green.

Learnings: atom/index.js is byte-budgeted and the verify gate enforces it, so
measure any change there with `pnpm test:size`. better-node-test rolls a whole
file into one reporter entry, so a new test's discrimination has to be shown
with `bnt -t '<fragment>' <file>` rather than read off the summary counts.

Next: NS-2, the remaining open High.
## iter 3/10 | fa642772-022756 | 2026-09-02 | NS-2 | done

Task: NS-2 (High, runtime, correctness) - the unbind returned by `on()` in
lifecycle/index.js was not idempotent: a second call got `indexOf` -1 and
`splice(-1, 1)` silently detached a different listener, and a third threw
TypeError on the already-deleted event list.

Changed: lifecycle/index.js (the unbind guards on `~index` and no longer
deletes the listener array when it empties, so a later call finds an array
rather than undefined), lifecycle/index.test.ts (two regression tests),
PLAN.md (Verify count 61 to 63), BACKLOG.md (NS-2 deleted).

Checkpoint: f28d5a6e122f40947fbbe322fd27b13b3a6bc55f

Verification: the filed reproduction was run first and threw
`TypeError: Cannot read properties of undefined (reading 'indexOf')`; after the
fix it prints `["m2"]` with no throw, which is the acceptance check as written.
Both new tests were run against the unfixed lifecycle/index.js by stashing that
one file: `bnt -t 'no-op when called more than once'` and
`bnt -t 'reinstalls the mutation'` each exit 1 unfixed and 0 fixed. `pnpm test`
through quiet-verify.sh - green (5s), `. test:coverage: ℹ pass 63`, and PLAN.md's
Verify count now carries that 63. check-claims.sh: 3 checked, 0 mismatched, 0
errored, 0 skipped. No battery under .jeffy/probes/ owns these paths yet.

Contract preserved: the first unbind still removes exactly its own listener,
the revert-mutation closure still runs when the last listener goes, and
re-registering after the last unbind still reinstalls the store mutation -
that second property is what the new `reinstalls the mutation` test pins,
because leaving the empty array behind changes which branch of
`object.events[eventKey] = object.events[eventKey] || []` runs on
re-registration. `object.events[eventKey]` is read nowhere outside
lifecycle/index.js, enumerated by
`grep -rn '\.events' --include='*.js' --include='*.ts' . --exclude-dir=node_modules`,
so leaving an empty array in place is not observable elsewhere. No public
signature or documented behavior changed.

Size: the Popular Set bundle moved 911 B to 912 B against its 912 B limit and
the Atom bundle is unchanged at 368 B against 372 B, so size-limit stays green
and the advertised figures in package.json and README still hold. The Popular
Set now has no headroom, which the next fix touching computed, map, atom or
lifecycle has to plan for.

Class note: NS-2 is the second instance of one idiom - a disposer handed to the
caller must be idempotent. Sites enumerated by
`grep -rn 'return () =>\|return unbind\|return endTask' --include='index.js' . --exclude-dir=node_modules`,
of which the ones a caller can invoke twice are atom's listen/subscribe unbind
(already guarded by `if (~index)`), listenKeys and subscribeKeys (they return
atom's unbind), lifecycle's `on` unbind (this task), `effect()`'s dispose
(NS-3, open) and `startTask()`'s end function (the negative-counter half of
NS-5, open); the rest are revert closures the library calls itself. The class
gets one Settled classes line with that enumeration once NS-3 and NS-5 close,
rather than a fourth instance patch.

Learnings: the Popular Set bundle is now at exactly its 912 B limit, so any
further change to atom, computed, map or lifecycle must be measured with
`pnpm test:size` before the verify gate sees it. Deleting a container on empty
and re-creating it lazily is what made this unbind non-idempotent; keeping the
empty container is both cheaper in bytes and safe.

Next: NS-3, the top open Medium.
## iter 4/10 | fa642772-022756 | 2026-09-02 | SWEEP | done

Task: Sweep the Surface inventory. With no open High left, the map outranks
every Medium and Low, so this iteration built the known-answer batteries the
rows need and swept all 20 of them.

Changed: .jeffy/probes/ (15 batteries plus a shared _lib.js: atom, computed,
map, deep-map, deep-map-path, effect, lifecycle, listen-keys, task,
clean-stores, keep-mount, map-creator, warn, package, types - each with a
check.js, a paths file, a claims file and a README recording the discriminating
mutation it was observed failing on), BACKLOG.md (NS-12 and NS-13 filed),
PLAN.md (20 inventory rows flipped in the bookkeeping edit below).

Checkpoint: c14a47c31e4d3b0287258a5f7306481a1a8a1d76

The bookkeeping edit that records this hash also repaired a state-file defect
this run introduced at iteration 1: the 20 inventory rows had been written into
the middle of the Surface inventory's own prose paragraph rather than under the
`Rows (first audit fills this in, one line each):` heading, because that
iteration replaced the first `- [ ] <surface>: <scope>` occurrence in the file
and the prose quotes that placeholder before the heading uses it. The rows now
sit under the heading, the paragraph is restored byte-exact from
references/plan-default.md, and `grep -c '^- \[ \] ' PLAN.md` returns 0.

Verification: every battery is a known-answer or invariant battery, never a
run-without-crash probe, and every one was observed failing before it was
recorded. Two were reddened by this run's own earlier trees - atom reports
14/15 against commit 2dcbbb4 before the NS-1 fix, lifecycle reports 9/10
against the same commit before NS-2 - and the other thirteen by a deliberate
source mutation applied, observed, and reverted with `git diff --quiet`
confirming the restore: computed 5/9, map 6/8, deep-map 3/8, deep-map-path
4/12, effect 5/6, listen-keys 6/8, task 3/8, clean-stores 4/8, keep-mount 3/5,
map-creator 7/8, warn 3/4, package 5/6, types 3/5. Each README names its own
mutation. check-claims.sh: 18 checked, 0 mismatched, 0 errored, 0 skipped.
`pnpm test` through quiet-verify.sh - green (5s), `. test:coverage: ℹ pass 63`.

The verify gate went red once during this iteration and was repaired rather
than reverted, because nothing about the product changed: oxlint lints
`.jeffy/probes/` along with the source and rejected three things in the new
battery code - a bare `hasOwnProperty` call, the console stubbing the warn
battery needs, and a floating promise in the task battery. All three are in
files this iteration created, the product tree was untouched, and the gate is
green after fixing them in place. This is the loop's own instruments meeting
the project's linter, not a regression.

Findings filed by the sweep, both at rubric severity in this same iteration:
- NS-12 (Medium, runtime): `setPath` writes a deeper path over a string leaf by
  spreading the string, so `setPath({a:'ab'},'a.b',1)` returns
  `{a:{0:'a',1:'b',b:1}}` instead of `{a:{b:1}}`. The same write over a null or
  numeric leaf is already correct, which is what makes the string case a defect
  rather than a design.
- NS-13 (Low, runtime): `effect()` keeps whatever its callback returns and
  calls it on the next change, so a concise arrow over a non-function
  expression throws `TypeError: lastRunUnbind is not a function` on a later
  tick rather than reporting the mistake where it was made.

Two contracts the sweep pinned that are worth naming because neither is
documented and both would otherwise be easy to change by accident: lifecycle
event listeners run in reverse registration order, because `on()` walks the
list with `reduceRight` - the project's own shared-payload test pushes the
shared object by reference and so never noticed - and a computed keeps
following its dependencies for the full STORE_UNMOUNT_DELAY after its last
listener leaves.

Learnings: oxlint has no ignore for `.jeffy/`, so every battery this loop
writes has to be lint-clean under the project's own config or the verify gate
goes red on the loop's own files. A battery whose waits are unbounded turns a
mutation into an unsettled top-level await and node exits 13 with no summary
line at all, which the claims file cannot read; the task battery now races
every wait against a deadline.

Next: NS-3, the top open Medium.
## iter 5/10 | fa642772-022756 | 2026-09-02 | NS-3 | done

Task: NS-3 (Medium, runtime, correctness) - `effect()` never cleared
`lastRunUnbind` after invoking it, so disposing twice ran the cleanup twice and
a callback that threw left the already-invoked cleanup to run again on the next
dependency change.

Changed: effect/index.js (a `cleanUpLastRun` helper drops the pending cleanup
before invoking it, used by both `run()` and the returned dispose),
effect/index.test.ts (two regression tests), .jeffy/probes/effect/ (two checks
added, claims and README updated), .jeffy/probes/*/README.md (13 rewritten,
see below), .jeffy/probes/types/claims and .jeffy/probes/package/claims (three
stated counts backed), PLAN.md (Verify count 63 to 65), BACKLOG.md (NS-3
deleted).

Checkpoint: 4de6c0f73a98d7eb69ff67938067271b92ebadf5

Verification: the filed reproduction was run first and printed `2`; after the
fix it prints `1`, which is the acceptance check as written. The throwing-
callback half prints `1` where it printed `2`. Both new tests were run against
the previous `effect/index.js` from HEAD: `bnt -t 'unsubscribe is called more
than once'` and `bnt -t 'throwing callback left behind'` each exit 1 there and
0 after. The effect battery, whose paths file declares `effect/index.js`, was
re-run through run-probe.sh and reports 8/8; run against the pre-fix file it
exits 1 on exactly the two checks this fix added. `pnpm test` through
quiet-verify.sh - green (5s), `. test:coverage: ℹ pass 65`, and PLAN.md's
Verify count now carries that 65. check-claims.sh: 22 checked, 0 mismatched, 0
errored, 0 skipped.

Contract preserved: the first run still happens immediately, the cleanup still
runs before each re-run and once at dispose, and dispose still detaches every
dependency listener. What changed is only that a cleanup is now dropped before
it is called rather than after, so it can never be called a second time. The
typed contract in effect/index.d.ts - `cb: (...) => (() => void) | void`
returning `() => void` - is unchanged, so no documentation edit was due.

Instrument repair the Stop hook asked for: 15 battery READMEs stated a
measurement - the `x/y checks passed` figure their discriminating mutation
produced - that no claims line carried, which the hook refuses. Backing each
with a claims line would mean a mutate-run-restore command executed on every
gate run, which is a worse instrument than no figure, so the figures were
removed and each README now records the mutation and that the battery was
observed exiting 1 under it. That still satisfies the rule the figures existed
for: the discriminating input is named, and the observation that it reddened
the battery is recorded. Three genuine standing counts were kept and backed
instead, because their derivations are cheap and side-effect free: the 48 names
index.d.ts declares and the 8 errors.ts fixtures in the types battery, and the
28 public exports and the 372 B minimum size budget in the package battery.

Class note: NS-3 is the third site of the disposer-idempotency idiom and the
second one fixed. The remaining enumerated site is the end function
`startTask()` returns, which is the second half of NS-5; the class gets its one
Settled classes line with the enumerating command when NS-5 closes, rather than
a fourth instance patch.

Learnings: a battery README may state a measurement only as a claims value, so
record a discriminating mutation by naming it and the fact that it reddened the
battery, never by quoting the count it produced. Backing a mutation figure with
a claims line would execute the mutation on every gate run.

Next: NS-4, the top open Medium.
## iter 6/10 | fa642772-022756 | 2026-09-02 | NS-4 | done

Task: NS-4 (Medium, runtime, correctness) - `listenKeys` missed a nested-path
key when its parent was replaced through `setKey`, because the keyed branch
matched only an exact key or the first segment of the changed key.

Changed: listen-keys/index.js (an `onSamePath` predicate replaces the
exact-or-first-segment test, and the `keysSet` allocation goes with it),
listen-keys/index.test.ts (four tests), listen-keys/index.d.ts and README.md
(the widened relation documented), .jeffy/probes/listen-keys/ (three checks
added, claims and README updated), PLAN.md (Verify count 65 to 69), BACKLOG.md
(NS-4 deleted).

Checkpoint: 106c70af2cc4d892981aeb5efa5c6def0a82cc8a

Verification: the filed reproduction was run first and printed `0`; after the
fix it prints `1`, which is the acceptance check as written. Probing around it
found a second gap with the same root cause, fixed by the same predicate: a
watcher on an intermediate path missed a change below it - watching `a.b`, a
write to `a.b.c` reported 0 and now reports 1 - because the old ancestor test
looked only at the first segment. Three of the four new tests exit 1 against
the previous listen-keys/index.js from HEAD and 0 after; the fourth, `does not
fire when a changed key only shares a prefix`, passes on both trees and is
kept as a regression guard for the widened match rather than offered as
evidence of the fix. The listen-keys battery, whose paths file declares
`listen-keys/index.js`, was re-run through run-probe.sh and reports 11/11;
against the pre-fix file it exits 1 on the two lineage checks. `pnpm test`
through quiet-verify.sh - green (5s), `. test:coverage: ℹ pass 69`, and
PLAN.md's Verify count now carries that 69. check-claims.sh: 22 checked, 0
mismatched, 0 errored, 0 skipped.

Contract preserved and widened, so the documentation moved with it: an exact
key match still fires, the documented base-key direction still fires for
nested and indexed writes under it, and a whole-store `set` is still compared
key by key through `getPath`. What changed is that the relation is now
symmetric - a watched key fires when it and the changed key name the same value
or one contains the other, at whole segment boundaries only. README.md and the
`listenKeys` doc comment in listen-keys/index.d.ts both state that, since a
listener firing in a case the docs did not describe is a documented promise
going stale in the other direction.

One consequence worth naming rather than burying: `listenKeys` cannot tell a
`map` from a `deepMap`, so a plain map key that literally contains a dot is
treated as a path. That conflation predates this change in the other direction
- watching `a` already fired for a map write to the key `a.b` - and this fix
makes it symmetric, so watching `a.b` now also fires for a write to `a`. The
new false positive is a listener that runs and finds nothing changed; the
defect it replaces was a listener that never ran for a change that did happen,
which is the direction that loses updates. The existing test `keeps plain map
keys containing a dot working` drives whole-store `set`, where `changed` is
undefined, so it is untouched by either direction.

Learnings: when a keyed-notification predicate handles only one direction of a
containment relation, probe the other direction before writing the fix - the
same missing predicate hid two gaps here, and fixing only the filed one would
have left a sibling defect with the same root cause in place.

Next: NS-5, the top open Medium.
## iter 7/10 | fa642772-022756 | 2026-09-02 | NS-5 | done

Task: NS-5 (Medium, runtime, correctness) - `cleanTasks()` zeroed the task
counter but never cleared `resolves`, so an outstanding `allTasks()` waiter
never settled, and an end function returned before the clean decremented the
counter afterwards, driving it negative so every later `allTasks()` hung for
the life of the process.

Changed: task/index.js (a `generation` counter that `cleanTasks` bumps, an
`ended` flag in each end function, and a shared `flush` that `cleanTasks` now
also calls), task/index.test.ts (three regression tests, each bounded with
`{ timeout: 1000 }`), .jeffy/probes/task/ (three checks added, claims and
README updated), PLAN.md (Verify count 69 to 72, a `disposer-sites` Stated
counts row), BACKLOG.md (NS-5 deleted, NS-14 filed, the disposer-idempotency
class settled).

Checkpoint: 1c8c670bca64dc5c0b81688eec5b331f3d235841

Verification: the filed reproduction was run first and printed `false`; after
the fix it prints `true`, which is the acceptance check as written. The
negative-counter half prints `true` where it printed `false`. All three new
tests exit 1 against the previous task/index.js from HEAD and 0 after. They
carry `{ timeout: 1000 }` deliberately: without it they do not fail on the
unfixed tree, they hang, and a regression would stall the suite instead of
reporting - the first run of them against the unfixed tree was killed at 60s by
an external timeout with no verdict at all. The task battery was re-run through
run-probe.sh and reports 11/11; against the pre-fix file it exits 1 with
exactly three `still pending after 500ms` failures, the three checks this fix
added. The types battery was re-run for the stale row the Stop hook named and
reports 5/5. `pnpm test` through quiet-verify.sh - green (6s),
`. test:coverage: ℹ pass 72`, and PLAN.md's Verify count carries that 72.
check-claims.sh: 23 checked, 0 mismatched, 0 errored, 0 skipped.

Contract preserved: `allTasks()` still resolves immediately with nothing
running and still waits for every outstanding task including ones started while
it waits, `task()` still returns its callback's value and marks the promise,
and both failure paths still close their task. Two behaviours changed and both
are what the defect was: `cleanTasks()` now resolves waiters it overtakes,
which is the condition it establishes, and an end function is inert if it was
created before a clean or has already been called. `cleanTasks` is documented
as "Forget all tracking tasks. Use it only for tests", which is what it now
does; no signature changed, so no documentation edit was due.

Stale row: the Stop hook reported the `TypeScript declaration surface` row
stale, because iteration 6 edited listen-keys/index.d.ts and that battery's
paths file globs `*.d.ts`. That is bookkeeping iteration 6 owed rather than a
queue item of its own - it re-recorded the listen-keys row and missed the types
row covering the same file - so the battery was re-run here and the row is
re-recorded in this iteration's bookkeeping edit.

Class settled: disposer idempotency is now class-complete and recorded under
Settled classes with its enumerating command. All seven caller-facing disposers
were driven twice in one process and all seven behaved: atom's listen and
subscribe unbind, listenKeys, subscribeKeys, lifecycle's `on` unbind, effect's
dispose, and startTask's end function.

Finding filed while enumerating that class, at rubric severity in this same
iteration: NS-14 (Medium, runtime) - `onMount` pushes whatever its initialize
callback returns onto the unmount list and calls it from a timer a second
later, so `onMount($store, () => log.push('x'))` kills the process with an
uncaught `TypeError: destroy is not a function` one STORE_UNMOUNT_DELAY after
unmount, blamed on lifecycle internals rather than the call site. It is the
same idiom as the already-filed NS-13 in `effect`, so it is filed as the class
task over both sites and closing it closes NS-13. It is scored above NS-13
because effect's version throws where the caller can catch it, while this one
throws from a timer, which in node is an uncaught exception that ends the
process.

Learnings: a regression test for a hang needs its own deadline - node:test
accepts `{ timeout: ms }` as the second argument - or the suite hangs instead
of failing and CI reports nothing. Re-recording one inventory row after a fix
is not enough when several batteries glob the same path; check every battery
whose paths file matches the diff, not just the obvious one.

Next: NS-6, the top open Medium.
# Journal

Append-only. One primary entry per iteration; SALVAGE and ROTATION entries are additional. Never rewrite past entries (filling the current entry's Checkpoint field is completion, not a rewrite).

Heading grammar, exactly (fenced and indented here so this example is never mistaken for an entry by anything that counts or rotates them):

```
  ## iter <i>/<N> | <run-id> | <YYYY-MM-DD> | <task-id or AUDIT or SWEEP or EVALUATOR or RATCHET or WRAPUP or SALVAGE or ROTATION> | <done|blocked|audit|converged|salvage|rotation>
```

Write a real heading at column zero, never indented: the indentation above belongs to the example alone, and an indented heading is invisible to the rotation anchor and to the archive counter, so the entry under it is not counted and not rotated.

A SWEEP entry is an iteration spent sweeping Surface inventory rows and takes status done. SALVAGE entries take status salvage; ROTATION entries take status rotation. An EVALUATOR entry records an evaluator-gate iteration: status audit when the run continues after the verdict, blocked on a terminal REJECT (one with no invocation remaining), converged when that same iteration declares.

run-id is the first 8 characters of the session id, a hyphen, then the HHMMSS of started_at from the loop state frontmatter, so two runs in one session are told apart. Body fields, in order: Task, Changed, Checkpoint (the jeffy checkpoint commit hash, or none with the reason), Verification, Learnings, Next.

The closing entry that declares convergence carries the evaluator verdict in its Verification field: `Evaluator: PASS - <one-line summary>`. `Evaluator: unavailable (<reason>)` is recorded when no sub-agent can be spawned, and it is not a verdict a run declares on: the Stop hook refuses it and the run ends blocked until a relaunch where the gate can run. An earlier EVALUATOR entry records its own verdict the same way and never stands in for the closing one: the Stop hook reads the closing entry alone, so a run that gates early and keeps working re-invokes the gate at the declaration.

Closed tasks are recorded here as one line each (ID, title, closing evidence), because BACKLOG.md deletes them. Rotation: when this file exceeds 500 lines, move all but the last 10 entries to the end of JOURNAL-archive.md, appending to whatever that file already holds and never overwriting it, because the archive accumulates across every rotation and every run; create it only when it does not already exist, and record the rotation as a ROTATION entry.

## iter 8/10 | fa642772-022756 | 2026-09-02 | NS-14 | done

Task: NS-14 (Medium, runtime, error handling) - a public API storing whatever
its caller callback returned and calling it later, where the documented
contract is a cleanup function or nothing. Filed as the class task over the two
sites known at filing time, `onMount` and `effect`; closing it closes NS-13
(Low), which was the `effect` instance.

Changed: lifecycle/index.js, effect/index.js and map-creator/index.js (each
keeps a returned value only when `typeof` says it is a function),
lifecycle/index.test.ts, effect/index.test.ts and map-creator/index.test.ts
(one regression test each), .jeffy/probes/lifecycle, effect and map-creator
(one check each, claims and READMEs updated), .jeffy/probes/callback-returns/
(the provocation enumeration, kept as the Settled line's derivation), PLAN.md
(Verify count 72 to 75), BACKLOG.md (NS-14 and NS-13 deleted, the class
settled).

Checkpoint: 9a5a6863cc617cb18a113e4b922d1a2673448021

Verification: the filed reproduction was run first and exited 1 with
`TypeError: destroy is not a function` from the unmount timer; after the fix it
exits 0. NS-13's own acceptance prints `ok`. Each of the three regression tests
exits 1 against its module's previous file from HEAD and 0 after. All three
batteries were re-run through run-probe.sh - lifecycle 11/11, effect 9/9,
map-creator 9/9 - and against their pre-fix files lifecycle and map-creator
exit 1 without printing a summary line at all, because the uncaught TypeError
from the unmount timer ends the process before the harness reports; that
failure mode is the finding, and both READMEs now say so. `pnpm test` through
quiet-verify.sh - green (7s), `. test:coverage: ℹ pass 75`, and PLAN.md's
Verify count carries that 75. check-claims.sh: 23 checked, 0 mismatched, 0
errored, 0 skipped, plus the new callback-returns claim matching.

Enumeration, built by provocation rather than by grep, as the class rule
requires: every public API that takes a caller callback - listen, subscribe,
computed, batched, effect, onMount, onStart, onStop, onSet, onNotify,
listenKeys, subscribeKeys, mapCreator, task and keepMount - was driven with a
callback returning a truthy non-function, then mounted, changed and unmounted
past STORE_UNMOUNT_DELAY with uncaught exceptions captured. With onMount and
effect already fixed, that enumeration named a third site nothing in the
backlog had: `mapCreator`'s init, which reaches the same unmount timer through
its own teardown. It is fixed in this iteration too, because a class task that
leaves a site it just discovered open is an instance patch wearing a class
label. The enumeration is kept at .jeffy/probes/callback-returns/ as the
derivation on the Settled classes line and reports 0 sites today.

Contract preserved: a callback returning a cleanup function still has it stored
and called at exactly the documented moment, and a callback returning nothing
still works. What changed is that any other return is now ignored rather than
stored. No signature changed and the declaration files already described this
contract, so no documentation edit was due.

Severity note, recorded because it narrows the finding rather than widening it:
check-dts rejected all three regression tests when they were first written, so
the typed surface already forbids this return for TypeScript callers, and the
tests now cast to reproduce a JavaScript caller. The finding is therefore about
JS consumers only. It stays Medium rather than dropping to Low because the
README's own examples are JavaScript, and the failure a JS caller meets is an
uncaught TypeError thrown from a timer one second after the mistake, which in
node ends the process and cannot be caught at the call site.

Size: the Popular Set moved 912 B to 911 B, so the guard paid for itself; the
Atom bundle is unchanged at 368 B and the advertised figures still hold.

Learnings: build a class enumeration by provoking every candidate site, not by
grepping for the call - the grep would have found onMount and effect and
stopped, and the third site was reachable only by driving mapCreator through a
real unmount. When a regression test has to violate the project's own types to
reproduce a JavaScript caller's mistake, cast at the call site and say so in a
comment; check-dts is part of the verify gate and a `@ts-expect-error` would
have hidden which caller the finding is about.

Next: NS-6, the top open Medium.

## iter 9/10 | fa642772-022756 | 2026-09-02 | NS-6 | done

Task: NS-6 (Medium, runtime, correctness) - `map().setKey` read the current
value through the prototype chain, so a key named after an Object.prototype
member behaved as though the inherited value were the map's own.

Changed: map/index.js (both reads are own-property reads now: `Object.hasOwn`
replaces `key in $map.value`, and the equality branch compares against
`undefined` rather than the inherited member), map/index.test.ts (two tests),
package.json and README.md (the Popular Set budget and the advertised range,
see below), .jeffy/probes/map/ (two checks, claims and README updated),
.jeffy/probes/callback-returns/enumerate.js (lint), BACKLOG.md (NS-6 deleted).

Checkpoint: f160947d1f9e6cfc12332a36d6e4af2e77df561c

Verification: the filed reproduction was run first and printed `["toString"]`;
after the fix it prints `[]`, which is the acceptance check as written. The
first attempt at this fix changed only the `in` test and did not work - the
reproduction still printed `["toString"]` - because the equality branch reads
`$map.value[key]` through the prototype too and compared `undefined` against
`Object.prototype.toString`, so the fix had to make both reads own-property
reads. `bnt -t 'inherited from Object.prototype as absent'` exits 1 against the
previous map/index.js from HEAD and 0 after; the second new test, `sets and
deletes a key named after an Object.prototype member`, passes on both trees and
is kept as a regression guard for the own-property reads rather than offered as
evidence. The map and package batteries were both re-run through run-probe.sh
and report 10/10 and 6/6; against the pre-fix file the map battery exits 1 on
the inherited-key check. `pnpm test` through quiet-verify.sh - green (7s),
`. test:coverage: ℹ pass 75`, unchanged because node:test rolls map/index.test.ts
into one reporter entry, so PLAN.md's Verify count still carries 75.
check-claims.sh: 24 checked, 0 mismatched, 0 errored, 0 skipped.

Public figure changed, with the rationale the Constraints require: the fix costs
9 bytes and the Popular Set bundle was already sitting at exactly its 912 B
limit, so package.json's size-limit entry moved to 921 B and README.md's
"Between 372 and 921 bytes" moved with it, which test:synced enforces as a
pair. The Atom budget and package.json's `(372 bytes)` description are
untouched, because `map` is not in the Atom bundle. This is the one change this
run made to a number the project advertises, and it is a product decision the
owner may want to revisit: the alternative was leaving `setKey` reading through
the prototype to keep the byte count, and a run does not get to trade a
correctness defect for a marketing figure quietly. The run report names it.

Contract preserved: setting, changing and deleting an own key behave exactly as
before, `eqKey` still receives the old value and the key, and the value object
is still replaced rather than mutated. What changed is that a key the map does
not own now compares against `undefined` instead of against whatever
Object.prototype holds under that name, so `setKey('toString', undefined)` is
the no-op it always should have been while `setKey('toString', 'x')` still
stores an own key.

Gap in iteration 8 found and closed here: the verify gate went red on
`.jeffy/probes/callback-returns/enumerate.js`, which failed oxlint on a bare
`console` and an UPPER_CASE `let`. That file was created after iteration 8's
verify run, so the gate never saw it and the checkpoint committed it unchecked.
The product tree was untouched by the repair. The rule this breaks is ordering,
not content: the gate has to be the last thing an iteration runs.

Learnings: run the verify gate after the last file an iteration writes, not
after the last file it thinks matters - a battery added post-gate rides into the
checkpoint unchecked and reddens the next iteration. When a defect comes from
reading through the prototype chain, fix every read on that path in one go; the
guard on one read moved the same bug into the branch next to it.

Next: NS-7, the top open Medium. One iteration of budget remains, so the next
one is a WRAPUP.

## iter 10/10 | fa642772-022756 | 2026-09-02 | WRAPUP | done

Task: Final iteration of the budget. The ledger holds three open Medium tasks,
so it is not at the severity floor and the closing-audit exception does not
apply; this iteration tidies the ledger, re-checks every standing claim, and
writes the handoff rather than starting a task it cannot finish.

Changed: JOURNAL.md only. No BACKLOG.md item changed state and no Surface
inventory row changed state, so by the stall check this iteration is a
no-progress iteration - which is what a WRAPUP is, and the stall rule exempts
it by name. The previous entry closed NS-6, so no pair forms.

Checkpoint: 5b226ed63674f38a54b4c7926b388a0e38e70201

Verification: `pnpm test` through quiet-verify.sh - green (7s),
`. test:coverage: ℹ pass 75`, matching PLAN.md's Verify count. check-claims.sh:
24 checked, 0 mismatched, 0 errored, 0 skipped. All 15 batteries re-run and all
green: atom 15/15, clean-stores 8/8, computed 9/9, deep-map 8/8, deep-map-path
12/12, effect 9/9, keep-mount 5/5, lifecycle 11/11, listen-keys 11/11, map
10/10, map-creator 9/9, package 6/6, task 11/11, types 5/5, warn 4/4, and the
callback-returns enumeration reports 0 sites. Both Settled classes lines were
re-derived: the disposer enumeration returns 6 files and the callback-return
enumeration returns 0 sites, matching what the lines state.

Oracle class and Environment fingerprint re-read and re-derived, as the closing
discipline requires: the exclusion command
`grep -rnE '\.(skip|todo)\(|skipIf|\.only\(|process\.(platform|arch)|process\.env\.CI' --include='*.test.*' . --exclude-dir=node_modules`
still returns no matches, and the tree still holds 14 files matching
better-node-test's own selection regex, so nothing this run added is excluded
from the gate and no journal entry in this run claimed a green it did not get.

Rotation was evaluated and not performed: JOURNAL.md is over 500 lines but
holds 9 entries, and the rule moves all but the last 10, so nothing is due.

Ledger tidied and every open task's reproduction re-run today, because a
backlog line is a hypothesis that rots as sibling fixes land around it. All six
still reproduce on HEAD:
- NS-7 (Medium): two throwing listeners in one flush, only `second` reaches the
  caller.
- NS-12 (Medium): `setPath({a:'ab'},'a.b',1)` returns
  `{"a":{"0":"a","1":"b","b":1}}`.
- NS-8 (Medium): `npm pack --dry-run` now leaks 71 paths matching the state-file
  pattern, up from 4 at filing, because this run added `.jeffy/probes/`. The
  finding did not change but its extent did, and the next run should re-read the
  line before fixing it.
- NS-9 (Low): NaN over NaN through `deepMap().setKey` notifies once.
- NS-10 (Low): `batched()` recomputes once after unmount.
- NS-11 (Low): `deepMap({})` throws TypeError when console lacks
  groupCollapsed.

Handoff for the next run. Start at NS-7; it is the top open Medium and its
reproduction is one line. NS-12 is the other runtime Medium and its fix belongs
in `setByKey`, where `{ ...obj }` spreads a string leaf into indexed keys - the
null and numeric leaf cases are already correct, so the fix is narrow. NS-8 is
last of the Mediums by the class ordering and is the one whose extent grew.
Two things a next run needs to know before touching shipped code: the Atom
bundle has 4 B of headroom against its 372 B limit and the Popular Set has none
against the 921 B this run moved it to, so measure with `pnpm test:size` before
assuming a fix fits; and oxlint lints `.jeffy/probes/` alongside the source, so
any battery must be lint-clean or the verify gate reddens on the loop's own
files. The Lessons section of PLAN.md carries both, plus the ordering rule this
run learned the hard way at iteration 9.

Learnings: a WRAPUP earns its iteration by re-running what the ledger asserts
rather than by summarising it - the NS-8 extent moved from 4 paths to 71 during
this run and nothing but re-running the check would have caught that the line
now understates itself.

Next: NS-7, for the next run. This run ends out of budget, not converged: three
Medium tasks remain open, the only full audit on this run's record is iteration
1's, which scored High and Medium, and no closing audit is legal in the final
iteration while the ledger sits above the severity floor.

## iter 1/10 | 64b18370-032702 | 2026-09-02 | NS-7 | done

Task: NS-7 (Medium, runtime, error handling) - `drainQueue()` kept only the
last listener error in `thrown` and rethrew that one, so when two listeners
threw during a single flush the first error was discarded with nothing logged.
No unswept or stale inventory row and no open High stood above it in the queue,
so it was the top item.

Changed: atom/index.js (`thrown` is an array, every catch pushes, and the
rethrow is the lone error itself or an `AggregateError` over several),
atom/index.test.ts (three tests), package.json and README.md (both size-limit
budgets and the two advertised figures, see below), .jeffy/probes/atom/ (two
checks, one renamed check, claims and README), .jeffy/probes/package/ (the
advertised-size claim and its README), BACKLOG.md (NS-7 deleted).

Checkpoint: 95aca5f70aabbfb82c19f2153ccbfa555dcd7256

Verification: the filed reproduction was run first and printed `second ` - only
the last error reaching the caller. After the fix it prints ` first,second`,
which is the acceptance check as written. `bnt -t 'several throw in one flush'`
and `bnt -t 'falsy listener error'` each exit 1 against the previous
atom/index.js from HEAD and 0 after; the third new test, `rethrows a lone
listener error as itself, not wrapped`, passes on both trees and is kept as a
regression guard against a later simplification that would wrap every error,
not offered as evidence. The atom battery is 17/17 and exits 1 with those same
two checks red against the pre-fix file; callback-returns and package, the
other two batteries whose paths files match this diff, report 0 sites and 6/6.
check-claims.sh: 24 checked, 0 mismatched, 0 errored, 0 skipped.

A second defect on the same line, found while fixing and fixed here rather than
filed: the old guard was `if (thrown) throw thrown`, so a listener throwing a
falsy value - `throw 0`, `throw ''` - was swallowed entirely and `set()`
returned as though nothing had happened. The array form tests `thrown.length`
and cannot repeat it. It is the same root cause, one truthiness test standing
in for an error count, so it is one fix rather than a second ledger line.

Public figures changed, with the rationale the Constraints require. The fix
costs 24 B brotlied: the Atom bundle moves 368 to 392 B against a 372 B limit,
and the Popular Set 921 to 946 B against a 921 B limit, so package.json's two
size-limit entries and its `(372 bytes)` description and README's
`Between 372 and 921 bytes` all moved, which test:synced enforces as a set.
Three cheaper shapes were measured and rejected: `thrown ??= e` keeps the first
error and drops the rest, which relabels the defect rather than fixing it;
`thrown[1] ? ... : thrown[0]` measures the same 392 B and reintroduces the
truthiness hole for a falsy second error; and always wrapping in an
`AggregateError` is smaller but changes what every single-listener throw
delivers to the caller. This is the second run in a row to move an advertised
byte figure for a correctness fix, and 24 B is 6.5% of the headline number this
library sells itself on, so it is named in the run report as a product decision
the owner may want to revisit - the alternative is carrying NS-7 as a knowingly
declined Medium.

Contract preserved: one throwing listener still delivers that exact error
object to the caller, every listener still runs before the throw, the queue is
still cleared before rethrowing, and batch and computed behaviour is unchanged.
What changed is that several errors now arrive together as an `AggregateError`
in listener order rather than as the last one alone, and that a falsy thrown
value now propagates. Neither README.md nor any `.d.ts` documents listener
error propagation, so no documentation edit was due; the atom battery README
now states the three-part contract in place of its `Not pinned here: NS-7`
note.

Learnings: oxlint's no-throw-literal and typescript/only-throw-error both
reject a test that reproduces a caller throwing a literal, and the verify gate
runs oxlint - bind the value to a variable first (`let falsy: unknown = 0`)
rather than suppressing the rule, which keeps the test readable and says which
caller the finding is about. When a battery README records a discriminating
mutation against a value the run then changes, update the sentence to say what
the value was when the observation was made; rewriting the number in place
turns an observed run into one nobody performed.

Next: NS-12, the top open Medium.

## iter 2/10 | 64b18370-032702 | 2026-09-02 | NS-12 | done

Task: NS-12 (Medium, runtime, correctness) - `setPath` wrote a deeper path over
a string leaf by spreading that string, so the leaf became indexed character
keys beside the new one instead of being replaced. No unswept or stale row and
no open High stood above it in the queue.

Changed: deep-map/path.js (`ensureKey` now asks whether the object owns a
container at that key rather than whether the key is merely present),
deep-map/path.test.ts (three tests), .jeffy/probes/deep-map-path/ (one check
widened, two added, claims 12/12 to 14/14, README), BACKLOG.md (NS-12 deleted,
NS-15 filed).

Checkpoint: be476c37e2dfcf162a0bd9e301d4f31e1e3f1f70

Verification: the filed reproduction was run first and printed
`{"a":{"0":"a","1":"b","b":1}}`; after the fix it prints `{"a":{"b":1}}`, which
is the acceptance check as written. All three new tests exit 1 against the
previous deep-map/path.js from HEAD and 0 after
(`bnt -t 'replaces a primitive leaf'`, `-t 'creates an array over a primitive
leaf'`, `-t 'inherited from the prototype'`). The deep-map-path battery is
14/14 and reports 11/14 against the pre-fix file; deep-map, the only other
battery whose paths could be affected, is 8/8. `pnpm test` through
quiet-verify.sh - green (7s), `. test:coverage: pass 78`. check-claims.sh: 25
checked, 0 mismatched, 0 errored, 0 skipped.

The gate went red twice before it went green, both times on the perimeter
rather than on behaviour, and both are recorded because the fix for each is a
rule rather than a one-off: check-dts rejected all three new tests, since the
declared `AllPaths` offers no deeper path under a primitive leaf, so each call
site names the loose type a JavaScript caller actually holds
(`Record<string, {b?: number}>`, `Record<string, number[]>`) instead of
suppressing the error; and oxlint's no-extend-native rejected the inherited
-container test in both the test file and the battery, which is disabled on
that one line with a reason, the project's existing convention for a rule a
test has to break to reproduce the defect.

Verify count moved 75 to 78 and PLAN.md carries the new figure. Chasing the
three-test delta showed the figure is not what it looks like: better-node-test's
reporter emits a single entry for some files and the individual cases of
others, so iteration 1's three new atom tests moved it by nothing while this
iteration's three moved it by three, and the tree holds 192 top-level test
cases against a reported 78. It is stable across runs on this host - three
consecutive runs reported 78 - so it still works as the equality the hook
checks, but it is not a test count and no entry should read it as one.
PLAN.md's Oracle class now says so, and the Stated counts table carries the
real case count with the command that produces it.

Extent, mapped by running the whole leaf domain before writing the fix rather
than trusting the filed line, which named the string case only. Three shapes
were wrong and all three came from one predicate:
- `setPath({a:'ab'}, 'a.b', 1)` returned `{a:{0:'a',1:'b',b:1}}` - the filed
  case.
- `setPath({a:'ab'}, 'a[0]', 1)` returned `{a:{0:1,1:'b'}}` - an object with an
  index key where an absent key yields an array, and the other characters
  survived.
- `setPath({a:null}, 'a[0]', 1)` returned `{a:{0:1}}` while
  `setPath({}, 'a[0]', 1)` returned `{a:[1]}` - a primitive leaf and an absent
  key disagreed about whether a numeric next key builds an array.
`ensureKey` returned early on `key in obj`, which tests presence and nothing
else, so any present-but-unusable value was written through instead of
replaced. The guard now tests that the object owns a non-null object at that
key, which makes a primitive leaf behave exactly like an absent one in every
case above.

The guard is an own-property read rather than a plain one, per the Lesson NS-6
left: `key in obj` also answers true for an inherited member, so a container
reachable only through Object.prototype was previously spread into the result -
`setPath({}, 'inheritedContainer.b', 1)` carried that object's own `secret` key
into the store. Writing the new guard as a prototype-chain read would have
planted the bug NS-6 had just removed from `map`, so it is
`Object.hasOwn(obj, key)`.

Contract preserved: an existing object or array at the key is still extended
and still copied at every level walked, structural sharing is unchanged, array
creation for a numeric next key is unchanged where the key was absent, deletion
is unchanged, and `__proto__` still cannot reach Object.prototype. What changed
is that a present primitive leaf is now replaced rather than written through,
and that an inherited container is replaced rather than extended. Neither
README.md nor path.d.ts documents the primitive-leaf case, and the declared
`AllPaths` type does not offer `a.b` for a string-typed `a` at all, so this is
a finding about JavaScript callers and about values typed with an index
signature, which is how the README's own deepMap examples are written; no
documentation edit was due.

NS-15 filed, and filed as a structural task rather than an instance line
because the three-strike rule applies: `getPath` reads every caller-supplied
key with `res[key]`, so `getKey($deepMap, 'toString')` returns
Object.prototype.toString rather than undefined, which is the read-side twin of
NS-6 and the third finding of one class after NS-6 and this one. It is not
fixed here - it is a separate semantic change with its own risk, since an own
-property rule also hides prototype getters on class instances a caller may
have stored - and it takes its own iteration with the enumeration built by
driving every public key-taking API.

Learnings: when a filed line names one input shape for a predicate defect, run
the whole domain of that predicate before writing the fix - the ledger line
named the string leaf, and two more wrong answers were sitting beside it under
the same early return, including one where a primitive leaf and an absent key
disagreed with each other. A discriminating test for an inherited container
needs the property defined non-enumerable on Object.prototype: an enumerable
one is copied by the spread before the guard ever sees it, and it also
pollutes every other test in the file.

Next: NS-15, the top open Medium.

## iter 3/10 | 64b18370-032702 | 2026-09-02 | NS-15 | done

Task: NS-15 (Medium, runtime, correctness) - `getPath` read every
caller-supplied key with `res[key]`, so a key naming an Object.prototype member
was answered with that inherited member instead of being absent. Filed as a
structural task rather than an instance line because the three-strike rule
applied: NS-6 fixed the same idiom in `map().setKey` and NS-12 fixed it in
`ensureKey`, so this one closes the class at the boundary and settles it.

Changed: deep-map/path.js (`getPath` reads own properties only),
deep-map/path.d.ts and deep-map/index.d.ts (the own-property rule stated in the
`getPath` and `getKey` doc comments), deep-map/path.test.ts and
deep-map/index.test.ts (two tests each), .jeffy/probes/prototype-key-reads/
(new, the class enumeration and its README), .jeffy/probes/deep-map-path/ and
.jeffy/probes/deep-map/ (one check each, claims and READMEs), PLAN.md
(test-cases count), BACKLOG.md (NS-15 deleted, the class settled).

Checkpoint: 57f7d3db8fe49b5bf726243ee5d78faa375c356e

Verification: the filed reproduction was run first and printed
`[Function: toString]`; after the fix its last line is `undefined`, which is
the acceptance check as written. `bnt -t 'inherited from Object.prototype as
absent'` exits 1 against the previous deep-map/path.js from HEAD and 0 after in
both deep-map/path.test.ts and deep-map/index.test.ts; the other two new tests,
`still reads own members that live beside inherited ones` and `sets and reads a
key named after an Object.prototype member`, pass on both trees and are kept as
guards against a fix that over-reaches into own keys, not offered as evidence.
The deep-map-path battery is 15/15 and 14/15 against the pre-fix file, deep-map
is 10/10 and 9/10, and the new enumeration reports 0 sites and 4 against that
same file. `pnpm test` through quiet-verify.sh - green (7s),
`. test:coverage: pass 80`, and PLAN.md's Verify count carries that 80.
check-claims.sh: 26
checked, 0 mismatched, 0 errored, 0 skipped.

Enumeration, built by provocation rather than by grep, as the class rule
requires and as the Lesson from NS-14 insists: every public API that takes a
caller-supplied key or path - `getPath`, `getKey`, `setPath`,
`deepMap().setKey`, `map().setKey`, `listenKeys`, `subscribeKeys`,
`mapCreator` - was driven with the key `toString`. Four sites answered with the
inherited member before this fix: `getPath` flat, `getPath` nested, `getKey`,
and `deepMap().setKey`, which notified once over a key the store never held.
All four came from the one read in `getPath`, so one fix closes them. The
enumeration is kept at .jeffy/probes/prototype-key-reads/ as the derivation on
the Settled classes line.

Two sites are settled rather than fixed, and the drive is what distinguishes
them from the four above. `listenKeys` and `subscribeKeys` compare
`value[key]` against `oldValue[key]` through the prototype on both sides, so an
inherited member is equal to itself and cannot report a difference the store
does not have - and the `getPath` comparison beside it is now own-only, so the
pair agrees. `mapCreator` reads `Creator.cache[id]` through the prototype, but
the guard above it refuses an inherited id outright (upstream #424), so that
read is never reached with one. Both are named on the Settled line rather than
left silent, because a class line that says class-complete has to account for
every site the enumeration visits.

Contract preserved: own keys are unchanged at every depth, including an own key
named `toString`; `length` on an array or a string is an own property and still
reads; a missing key is still undefined and a nullish level still short
-circuits. What changed is that a key naming an inherited member is now missing
rather than answered with Object.prototype's member. The declared
`BaseDeepMap` is `Record<string, unknown>`, which is plain data, and the doc
comment already said undefined if the key is missing - it now says which keys
count as missing. The visible cost is that a caller who stored a class instance
in a deepMap can no longer read a prototype getter or method through a path;
that is the intended meaning of an own-key store, and it is stated in the docs
rather than left to be discovered.

Learnings: when the enumeration reaches a site that already refuses the input,
a probe that only asks whether the call returned cleanly scores the refusal as
a defect - encode the settled answer explicitly, so the enumeration
distinguishes a site that was fixed from one that was never in the class. A
class task is where the sites that are not in the class get written down; the
Settled line has to name them, or the next audit re-derives the same three
questions from scratch.

Next: NS-8, the last open Medium.

## iter 4/10 | 64b18370-032702 | 2026-09-02 | SWEEP | done

Task: the TypeScript declaration surface row went stale when iteration 3 added
doc comments to deep-map/index.d.ts and deep-map/path.d.ts, both of which the
types battery globs. A stale row outranks every open Medium in the queue, so
this iteration re-swept it. Recomputing staleness for all 20 rows against their
batteries' paths files found that one and no other.

Changed: .jeffy/probes/types/ (the module check broadened and moved off the git
index, README), PLAN.md (the row re-recorded with its new scope).

Checkpoint: 9377831bbbc512525cda46e6ea176492d4d81cca

Verification: the types battery is 5/5 through run-probe.sh. Re-stamping it
would have certified nothing new, so the sweep checked what the row's own scope
line claims and found the module check narrower than its words. Two defects in
the instrument, both fixed here:
- It listed modules with `git ls-files '*/index.js'`, so `deep-map/path.js` -
  a module with its own declaration file and its own public exports, the file
  this run has edited in two of three iterations - was never in the check.
  The list is now every tracked `*.js` outside `test/` and `.jeffy/`, minus
  test files and dotfiles, minus the documented `warn/index.js` exclusion.
- It answered the declaration side with a second `git ls-files '*.d.ts'`, so a
  declaration tracked but deleted from disk read as present. It asks the
  filesystem now.
The mutation proving the broadened check: an empty tracked `deep-map/mutant.js`
with no declaration beside it - a module the old glob could not have seen -
reddens `every shipped module has a declaration file beside it` and nothing
else. Applied, observed, reverted; `git status --porcelain` named no such path
afterwards. Deleting `deep-map/path.d.ts` from disk was tried first and reddened
the wrong check, which is how the second defect surfaced: both sides were
reading the same git index, so neither could see the disk.

`pnpm test` through quiet-verify.sh - green (7s), `. test:coverage: pass 80`,
matching PLAN.md's Verify count. check-claims.sh: 26 checked, 0 mismatched, 0
errored, 0 skipped. No BACKLOG.md item changed state this iteration, which is
what a sweep iteration is; the Surface inventory row did change state, so this
is not a stall by either definition.

Learnings: a check that asks git on both sides of a comparison cannot see the
working tree at all - it will agree with itself over a file that is not there.
When a probe is meant to certify what a consumer meets, at least one side of it
has to touch the filesystem. And a glob written for the modules that existed
when the battery was written silently stops covering the ones added since; a
module list is an enumeration and belongs in the README as one.

Next: NS-8, the last open Medium.

## iter 5/10 | 64b18370-032702 | 2026-09-02 | NS-8 | done

Task: NS-8 (Medium, build-ci, documentation) - `npm pack` shipped this loop's
own working files, because `.npmignore` named no state file and npm ignores
`.gitignore` entirely once `.npmignore` exists. Consequence, as filed: a user
who installs nanostores gets PLAN.md, BACKLOG.md, JOURNAL.md and
`.claude/jeffy-loop.local.md` inside node_modules/nanostores. It was the last
open Medium.

Changed: package.json (a `files` allowlist), .npmignore (the state paths),
.jeffy/probes/package/ (two checks, claims 6/6 to 8/8, README),
.jeffy/probes/types/paths (`.npmignore` declared, see below), BACKLOG.md (NS-8
deleted).

Checkpoint: e2392a7876b9f4dba5c0cf4fa1990e315e6f2d42

Verification: the filed reproduction was run first and listed 76 paths, not the
four the line named - the previous run's WRAPUP had already measured the extent
growing from 4 to 71 as this loop added `.jeffy/probes/`, and three more
arrived since. After the fix the acceptance grep prints nothing. The package
battery is 8/8 and 6/8 against the pre-fix packing configuration, with exactly
the two new checks red; the types battery is 5/5. `pnpm test` through
quiet-verify.sh - green (7s), `. test:coverage: pass 80`. check-claims.sh: 26
checked, 0 mismatched, 0 errored, 0 skipped.

Fixed as an allowlist rather than by lengthening the denylist, because the
denylist is what failed: this finding was filed at 4 leaked paths and reached 76
without anyone changing `.npmignore`, since a denylist only excludes the
directories somebody thought to name. `files` now names the six patterns the
package actually ships and everything else is out by construction. The tarball
went from 116 entries to 31.

Both layers are kept, and the reason is a channel this host cannot verify
rather than belt-and-braces. The release workflow publishes through
`ai/clean-npm-project`, which copies the tree and strips package.json fields; it
is not installed here and its field list cannot be read offline, so whether a
`files` key survives into the published manifest is unknown to me. `.npmignore`
is a file rather than a manifest field, so it survives any such stripping. Each
layer was proved to block the leak alone: with `files` removed from
package.json, the state-file grep over `npm pack` still returns nothing.

What else the allowlist drops, stated because it is wider than the finding: the
tarball no longer carries `.devcontainer.json`, `.editorconfig`, `.github/`
including both workflows, `.prettierrc.js`, `oxfmt.config.ts`,
`oxlint.config.ts` or `pnpm-workspace.yaml`. None of them is reachable from the
package's exports map and none is a documented part of the surface, so no
consumer meets them except as bytes to download. Every runtime file the tarball
carried before is still in it, verified by diffing the two packed file lists
rather than by reading the patterns: nothing was added and nothing but loop
state and repository furniture was dropped. CHANGELOG.md is named explicitly in
the allowlist because npm's always-included set covers only README, LICENSE and
package.json, and dropping it silently would have been exactly the kind of
unannounced change this project's Constraints forbid.

Instrument gap found on the way and closed here: the types battery reads
`.npmignore` in its `errors.ts` exclusion check but did not declare that path
in its own `paths` file, so an iteration editing `.npmignore` alone would never
have run it and the row would never have gone stale. That is the same class as
iteration 4's finding about that battery - a check whose declared scope is
narrower than what it actually reads - and the path is now declared.

Learnings: a packing denylist is a claim about the directories that exist
today, so it decays by addition rather than by edit; when a project's own
tooling writes new directories, the allowlist is the only form that stays true.
When a fix depends on a publishing channel this host cannot execute, say which
link is unverified and keep a layer that does not depend on it, rather than
asserting the channel behaves.

Next: NS-9, the top open Low. The ledger is now at the severity floor - three
Lows, no High or Medium - so the run's remaining shape is those Lows, then a
full closing audit, then the evaluator gate.

## iter 6/10 | 64b18370-032702 | 2026-09-02 | NS-9 | done

Task: NS-9 (Low, runtime, correctness) - `deepMap().setKey` compared the value
already at the path with the new one using `!==` instead of the store's own
`eq`, so writing NaN over NaN notified every time. Top of the queue: no High,
no Medium, no unswept or stale row.

Changed: deep-map/index.js (the comparison goes through `$deepMap.eq`),
deep-map/index.d.ts and atom/index.d.ts (the `setKey` and `eq` doc comments say
which comparison `DeepMap#setKey` uses), deep-map/index.test.ts (three tests),
.jeffy/probes/deep-map/ (one check, claims 10/10 to 11/11, README), PLAN.md
(test-cases count), BACKLOG.md (NS-9 deleted).

Checkpoint: f28fdfde07c41cd75ff9cb5eed8269894c62ef80

Verification: the filed reproduction was run first and printed `1`; after the
fix it prints `0`, which is the acceptance check as written. All three new
tests exit 1 against the previous deep-map/index.js from HEAD and 0 after. The
deep-map battery is 11/11 and 10/11 against that pre-fix file; the
prototype-key-reads enumeration, the other battery whose paths match this diff,
still reports 0 sites, and the types battery is 5/5 because two `.d.ts` files
changed. `pnpm test` through quiet-verify.sh - green (7s),
`. test:coverage: pass 80`, unchanged and still matching PLAN.md's Verify
count: deep-map/index.test.ts rolled into one reporter entry this run, so the
three added cases moved the figure by nothing, exactly the reporter behaviour
iteration 2 recorded.
check-claims.sh: 26 checked, 0 mismatched, 0 errored, 0 skipped. Both bundle
budgets are unmoved at 392 B and 946 B: `deepMap` is in neither.

Two cases beyond the filed one, both from the same comparison and both fixed by
the same line. Writing -0 over 0 now notifies and stores -0, where `!==` called
them equal and kept the 0 - the same signed-zero distinction upstream fixed for
`computed` in #423, so the store is now consistent with its sibling. And a
caller who replaces `eq` on a deepMap now has it honoured by `setKey`, where
before the replacement was silently ignored for key writes and applied only to
whole-value `set`.

Contract preserved: an ordinary unequal write still notifies once with the
changed key, an ordinary equal write is still silent, and `eq` still defaults to
`Object.is`, so nothing changes for a store that never touches NaN, -0 or a
custom `eq`. What changed is which comparison decides, and it is now the same
one `set` uses on the same store. Documentation followed the behaviour in the
same iteration: `DeepMap#setKey` now states that it compares through the
store's `eq`, and `Store#eq`, which already said `Map#setKey` uses `eqKey`
instead, now also says `DeepMap#setKey` calls this one - that sentence listed
the exception and left the reader to guess the rule.

Learnings: when a store family has more than one equality hook, the doc comment
on the hook is where the map of which writer calls which belongs; `eq` already
carried the `Map#setKey` exception, so the deepMap answer was the one thing a
reader could not look up.

Next: NS-10, then the closing sequence. Four iterations remain and the
convergence sequence needs two of them - a full closing audit, then the
evaluator gate and the declaration - so at most one more Low is worked and the
rest are carried.

## iter 7/10 | 64b18370-032702 | 2026-09-02 | AUDIT | audit

Task: the closing full audit, run with fresh evidence against every applicable
dimension, the severity rubric and the Operating envelope. Three iterations
remained and the convergence sequence needs two of them, so the two open Lows
are carried rather than worked and this iteration buys the audit the
declaration requires. Closeout begins with this entry: no further audit and no
replenishment for the rest of the run.

Changed: BACKLOG.md (NS-16 filed), JOURNAL.md.

Checkpoint: abc3bff60843a185fe44dc9bb564878a279f26dc

Verification and evidence. Every claim below was executed this iteration, not
re-read:
- Surface inventory: 20 rows, 0 unswept, 0 stale, recomputed by diffing each
  row's recorded commit against HEAD over its battery's own paths file. The
  audit therefore claims the whole mapped surface rather than a part of it.
- All 17 batteries executed through run-probe.sh and green: atom 17/17,
  clean-stores 8/8, computed 9/9, deep-map 11/11, deep-map-path 15/15, effect
  9/9, keep-mount 5/5, lifecycle 11/11, listen-keys 11/11, map 10/10,
  map-creator 9/9, package 8/8, task 11/11, types 5/5, warn 4/4, and both class
  enumerations reporting 0 sites.
- Both Settled classes re-derived: the disposer enumeration returns 6 files and
  the callback-return and prototype-key-read enumerations return 0 sites, which
  is what their lines state. No Declined entries exist, so there were no
  Derivations to re-run.
- Oracle class and Environment fingerprint re-read and re-derived: the
  exclusion command returns no matches, so no test target is guarded off on
  this host, and the toolchain still measures Node v24.17.0, pnpm 10.12.1,
  TypeScript 7.0.2, oxlint 1.80.0, exactly as the fingerprint states.
- Testing was probed for order dependence before being scored, as the audit
  discipline requires: keep-mount, clean-stores, deep-map/path and map were run
  as isolated modules and each exits 0 on its own.
- Production behaviour exercised directly with NODE_ENV=production, where the
  dev-only branches are compiled out: atom set and deepMap setKey both behave.
- Dependency hygiene measured, not assumed: the package declares no runtime
  dependencies and no peer dependencies, and `pnpm audit --prod` reports no
  known vulnerabilities.
- Security probed rather than reasoned about: `setPath({}, '__proto__.polluted',
  'yes')` leaves Object.prototype untouched and puts no own key on the result.
- Both carried Lows re-run and both still reproduce, so neither line has rotted.

Scores, claiming the whole mapped surface: architecture None, code quality
None, security None, testing None, error handling Low (NS-11), performance
None, documentation Low (NS-16, filed here), dependency hygiene None, developer
experience None, correctness Low (NS-10), observability Low (NS-11 is the
deprecation channel itself). UX and accessibility do not apply: the package
ships no user-facing surface, only a module API. Zero High and zero Medium
in-envelope.

NS-16 filed and deliberately scoped. Comparing the 28 runtime exports against
README.md showed eight absent from the guide, but five of them - `deepMap`,
`getKey`, `getPath`, `setPath`, `setByKey` - are the deprecated deepMap family,
which prints a notice on every construction pointing at
`@nanostores/deepmap` and is slated for removal in 2.0; documenting a surface
the project is removing would be the wrong fix, so the finding covers only the
three non-deprecated names. It is Low rather than Medium under the severity
ceiling by class: a docs finding is Medium only when it can name a documented
promise the code does not keep or an install that fails, and this one is a
coverage gap in the guide while every one of the three carries a doc comment in
the declarations a consumer's editor reads.

No BACKLOG.md item changed state by completion this iteration and no inventory
row changed state; the audit filed one new task, which is a state change under
the stall definition, and an AUDIT entry is in any case exempt.

Learnings: an audit earns its iteration by running the claims rather than
reading them - the dependency score, the fingerprint, the two settled classes
and both carried Lows were all confirmed by command here, and the one new
finding came from a comparison nothing in the batteries performs, the runtime
export list against the guide that is supposed to teach it.

Next: the evaluator gate, then the declaration. Two iterations remain after
this one, so a REJECT still has an iteration to be answered in.

## iter 7/10 | 64b18370-032702 | 2026-09-02 | ROTATION | rotation

Task: JOURNAL.md stood at 1169 lines and 17 entries, so the rotation rule
applied - it was evaluated and declined at the end of the previous run, which
held 9 entries against a threshold of 10. Done here rather than in the next
iteration so that the evaluator gate and the declaration run against a stable
tree.

Changed: JOURNAL.md (the seven entries of the previous run moved out, its
preamble and the ten most recent entries kept), JOURNAL-archive.md (new).

Checkpoint: efe801d411a725a5e6e784fad2dc024e7df49d0c

Verification: entries were split only on lines beginning `## iter` followed by
a digit, so the heading-grammar example in the preamble was neither counted nor
moved. JOURNAL.md went from 17 entries to 10 and JOURNAL-archive.md holds the 7
oldest, which are the whole of run fa642772-022756 through its iteration 7; the
counts were read back from both files after the write. The archive was created
rather than overwritten - it did not exist before - and every later rotation
appends to it. `npm pack --dry-run` still lists no state file, so the new
JOURNAL-archive.md is outside the published tarball by both the `files`
allowlist and the `.npmignore` line NS-8 added, which named it before it
existed.

Learnings: rotation is worth doing before the convergence sequence rather than
inside it - the archive write is the largest diff a bookkeeping step produces,
and the declaring iteration should carry nothing but the gate and the
declaration.

Next: the evaluator gate.

## iter 8/10 | 64b18370-032702 | 2026-09-02 | EVALUATOR | converged

Task: the adversarial evaluator gate, invocation 1 of this run, and the
declaration it cleared. Standing claims were brought current in this same
iteration before the sub-agent was spawned.

Changed: .jeffy/evaluator/64b18370-032702-1.md (the gate's artifact),
BACKLOG.md (NS-17 and NS-18 filed from the gate's observations, the Converged
line appended), JOURNAL.md.

Checkpoint: 5d2c0e8cb20a4b4fb9e5acba8fc8ba4833b094dc

Verification, all executed this iteration before the invocation: the Surface
inventory holds 20 rows with 0 unswept and 0 stale, recomputed by diffing each
row's recorded commit against HEAD over its battery's paths file; the disposer
enumeration returns 6 files and both class enumerations return 0 sites, which
is what their Settled lines state; BACKLOG.md has no Declined entries, so there
were no Derivations to re-run; PLAN.md names no finding ID, so nothing dangles;
check-claims.sh reports 26 checked, 0 mismatched, 0 errored, 0 skipped; the
Oracle class and Environment fingerprint were re-read and the exclusion command
re-derived to no matches; `pnpm test` through quiet-verify.sh is green (7s),
`. test:coverage: pass 80`, equal to PLAN.md's Verify count.

Evaluator: PASS. It reproduced all four Mediums and the one Low closed this run
against base commit dc9e636 in a throwaway worktree, confirmed each fails there
and passes at HEAD, re-executed every acceptance as written, installed the
packed tarball into a fresh package and exercised all 28 exports, ran a
269-divergence differential of base against HEAD over getPath and setPath and
found every divergence inside the two fixes' intended domains, and confirmed
the advertised byte figures agree with a real size run and with each other.

Four observations, none a REJECT reason and none fixed here, because a fix
after a PASS invalidates the PASS. Two became ledger lines: NS-17, PLAN.md's
Lessons still quoting the pre-run bundle figures, and NS-18, three battery
paths files omitting a file their checks depend on, which makes the audit's
zero-stale derivation true as computed and under-inclusive. Two go to the run
report only: NS-15 changes what an upgrading consumer meets beyond its filed
shape, for a value holding a class instance, which both `.d.ts` files and this
journal already record; and NS-10's filed wording overstates its timing, since
STORE_UNMOUNT_DELAY is 1000 ms and its acceptance waits 30 ms, so the store is
still mounted when the stray recompute lands - the defect it counts is real and
the check discriminates, and the next run corrects the sentence when it works
the task.

Convergence declared. Every closing condition holds and was checked rather than
assumed: this run's iteration 7 full audit scored zero High and zero Medium
in-envelope with fresh evidence; the Surface inventory lists no unswept row;
Now, Next and Later hold no open High and no open Medium; the only commits
since that clean audit are the journal rotation and this iteration's own loop
state edits; the Verify command is green this iteration; and the evaluator
returned PASS with its artifact committed by this checkpoint.

Carried Lows, each with its severity on its line: NS-10, a `batched()` recompute
scheduled on a timer the mount teardown never clears. NS-11, `warn()` calling
console.groupCollapsed, trace and groupEnd after guarding only console.warn.
NS-16, three non-deprecated public exports absent from the README guide.
NS-17, PLAN.md's Lessons quoting stale bundle figures. NS-18, three battery
paths files omitting a file their checks read.

Learnings: bringing the standing claims current before spawning the gate is
what makes the invocation worth its cost - every one of the six checks the gate
consumes was already green when it arrived, so its whole invocation went on
reproducing the run's fixes rather than on bookkeeping the run had left
undone.

Next: the run ends converged.
