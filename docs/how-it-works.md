# How a run works

<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../media/flowchart-dark.png">
  <img src="../media/flowchart-light.png" alt="Flowchart of a /jeffy run: the launch skill bootstraps the state files, each iteration audits or executes one verified task and checkpoints it, the adversarial evaluator - a fresh-context sub-agent - countersigns convergence, and the Stop hook re-feeds the loop until convergence, budget end, or a blocker - all steered by three files and the git log." width="830">
</picture>

<sub>How one command becomes a run. Solid arrows are control flow; dashed arrows are the file reads and writes that steer it. Outside a run the Stop hook exits instantly - no live state file, no behavior - and <code>/cancel-jeffy</code> ends a run at any time. Diagram source: <a href="../media/flowchart.mmd"><code>media/flowchart.mmd</code></a>.</sub>

</div>

Running `/jeffy` in a Claude Code session:

1. **Bootstraps the loop's memory** at the project root: `PLAN.md` (goal, operating envelope, surface inventory, verify command, lessons, definition of done), `BACKLOG.md` (the task ledger - findings prioritized most severe first, plus proposals awaiting your decision, settled defect classes, and the Converged record), and `JOURNAL.md` (append-only iteration log). They persist between runs.
2. **Runs the budgeted loop.** The first audit fills the surface inventory and the backlog. Each iteration after that either audits or executes exactly one task, verifies it, and checkpoints it; a task that newly breaks the verify command is reverted. Once one full audit comes back clean of High and Medium, the run stops auditing and finishes the ledger.
3. **Stops for a reason and reports.** Convergence - a clean audit, zero open High or Medium with every carried Low named, a fully swept inventory, the adversarial evaluator's PASS, all re-checked in shell by the Stop hook - or the budget, a stall, a hard blocker, or your cancel. The run report lists tasks closed with severities, the diffstat, rows swept of rows total, and anything waiting on your decision.

## Five guarantees

Each one is enforced by the iteration prompt, the state files, or the Stop hook, and each is checkable in this repository.

**It audits like an engineer, not a linter.** Every run opens with a real audit across architecture, correctness, security, testing, performance and more. Every finding becomes a task with a runnable acceptance check, and a finding exists only if the loop can point at it.

**It cannot wreck your repo.** Every iteration ends in a local checkpoint commit, and a verify gate reverts any iteration that breaks the project. Nothing is pushed, no branches are created.

**"Done" is not the agent's opinion.** A declaration needs a fresh audit finding zero High and zero Medium, a fully swept surface inventory, and an adversarial evaluator's countersignature. Then a plain shell script re-checks all of it, re-runs your test suite, and refuses the stop if anything fails.

**It cannot claim what it never looked at.** The whole public surface goes on a checklist before any finding is filed, each swept row records the commit it certified, and a row reopens when its code changes. "No findings" can never mean "nowhere looked".

**Lessons become machinery.** A rule learned the hard way binds every iteration after it, and a rule that has to be written twice gets promoted into a mechanism. The engine itself is held to <!-- count:checks -->**312 behavioural checks**<!-- /count --> on Linux, Windows and macOS, each one added because something went wrong once.

<div align="center">

![Jeffy Loop vs a raw prompt loop - the head-to-head](../media/jeffy-vs-raw-loop.gif)

<sub>The head-to-head vs a raw prompt loop. Every row is a guarantee you can verify in the code: the engine is <code>skills/jeffy/hooks/stop-hook.sh</code>, the discipline is <code>skills/jeffy/references/iteration-prompt.txt</code>, and the receipts live under <a href="../evals/"><code>evals/</code></a>.</sub>

</div>

<details>
<summary><b>The full rule set a run lives by</b></summary>
<br>

**Every iteration**

- **One verified task.** Every task carries a runnable acceptance check; done means the check ran and passed. Three failed fix attempts mark it blocked rather than thrashing.
- **Checkpoint everything, push nothing.** Every iteration ends in a local commit prefixed `jeffy:`, which is the revert unit. Pre-flight warns on a dirty tree. Without git, checkpoints degrade to journal-only discipline.
- **The verify gate guards every change.** An iteration that newly breaks the verify command in `PLAN.md` is reverted and its task marked blocked.
- **Interrupted work is salvaged, never discarded.** A run resuming over a dirty tree commits the salvage first.
- **Stalls end runs before budgets do.** Progress means a path outside the loop's own memory moved, or the ledger changed. A checkpoint commit is not progress on its own, since the engine commits every iteration. The first flat iteration re-feeds with a note; a second consecutive one ends the run. The convergence sequence is exempt, capped at three iterations.
- **The hook does the budget arithmetic.** Every re-feed carries the iteration count, open tasks per section, unswept rows, and what the convergence sequence still costs.

**Every audit**

- **Work from a written map.** The first audit lists the whole public surface and probes it breadth-first before filing anything.
- **Prove correctness, not liveness.** A row that computes values needs a known answer or a strong invariant. Every documented parameter must change the output at two or more values; one that changes nothing is a finding.
- **Keep the instruments.** Known-answer batteries live under `.jeffy/probes/` and are committed, so a re-sweep re-runs them instead of rebuilding them.
- **Severity comes from the envelope.** Findings are scored against your project's real input surfaces. Envelope changes go to Proposed for your approval; the loop never widens its own mandate.
- **The third strike forces structure.** The third finding sharing one root cause forces a structural fix or a decision, never a fourth spot patch.

**Convergence**

- **Convergence is sticky.** The converged commit is recorded, and relaunching on an unchanged tree re-verifies in O(1) instead of re-rolling the audit dice.
- **The evaluator cannot be worn down.** At most two reviews per run, three when the first landed early. A rejection with no review left ends the run blocked, and it spends the remaining budget closing what the gate filed. A session that cannot spawn sub-agents ends blocked, because the gate is never waived.
- **The stop is enforced in shell.** At the promise the hook re-checks every condition: zero open High and Medium with an unparseable severity blocking, a Converged line still certifying the tree, no unswept row, a declared oracle class, an evaluator PASS backed by its committed artifact, and your verify command exiting 0 when the hook re-runs it. That re-run is bounded by a timeout whose bound resolves as `verify_timeout_seconds`, else `Verify duration` x3 floored at 240s, else 240s, capped at 1740s because the installer registers the hook with an 1800s timeout, so a suite that legitimately runs long is bounded by its own measured time rather than refused for outrunning a bound nobody measured. The bound is enforced by `timeout`, `gtimeout`, or a shell watchdog, so it holds on a host with no GNU coreutils.

**Always**

- **Published code is run code.** Anything leaving the project must have been executed in exactly the form it is published.
- **Lessons persist.** Operational rules are promoted into `PLAN.md`, which every future iteration reads. Add your own lines there: fix the loop, not the run.

</details>

## What a converged stop looks like

Jeffy built this repository by running on itself, and that convergence is re-earned, not archived - every fresh run has to reach it again with fresh evidence. One such run opens by filing three Mediums against the repo's own trust-model and check-count claims, spends an iteration on each, and still has to earn the stop. The dev journal stays out of the published tree, since state files are the loop's memory rather than the product, but the closing sequence, abridged, shows the texture of a converged stop:

```
## iter 5/8 | e64f9b2c-160059 | 2026-07-31 | AUDIT | audit

Verification: bash scripts/validate.sh exit 0 fresh this iteration,
119 OK, 0 FAIL, 96s wall against the hook's 240s verify budget.
Inventory: all 12 rows stand. Dimension scores over all 12 swept rows,
fresh evidence each: (12 dimension scores, every one None)
Result: zero High, zero Medium, zero new findings at any severity.
Closeout begins: no further audit or replenishment this run; only the
convergence sequence remains.

## iter 6/8 | e64f9b2c-160059 | 2026-07-31 | EVALUATOR | converged

Verification: Evaluator: PASS - fresh-context adversarial review
confirmed scope, re-ran the Verify command at exit 0 (119 OK, 0 FAIL,
1 SKIP), (re-proved each of the run's three findings against the
shipped files) and found no missed in-envelope High or Medium.
Closing conditions: closing audit scored zero High zero Medium over
all 12 swept rows; Now, Next, Later all empty; all three filed
findings completed (D1 at 5e9be82, D2 at 71a420c, D3 at fa73cf3);
no unswept or stale inventory row; Converged line appended for
fa73cf3a6e5e277d80e48dc2d34111f67cc4f526.

(run report, and then the session's last words - the phrase the
Stop hook verifies against every condition above before letting
the run end:)

<promise>JEFFY CONVERGED</promise>
```

When Jeffy converges on your project, the checkpoint lands in your `git log` and under `## Converged` in the loop's backlog, so relaunches on an unchanged tree re-verify instead of re-auditing. Run `/jeffy` on your own project and read the journal it leaves behind.

## The loop improves the loop

The rule above - fix the loop, not the run - applies to Jeffy itself, and that is the part designed to compound. Most tools improve when their authors read bug reports. Jeffy improves by being run against its own source under its own rules, and by converting what that finds into machinery that cannot be forgotten. Four mechanisms do the work, and each leaves evidence in this repository you can check rather than take on trust.

**The engine is audited by the engine, and the results are merged in public, failures included.** Jeffy is pointed at its own repository exactly as it is pointed at any external target: same envelope, same evidence rules, same adversarial gate, no privileged mode. Those runs are in this history under their own merge commits, and the subjects say what happened rather than what would read better. `ba032bc` merged the first self-run to converge under the gate, and shipped the first published evaluator artifacts with it. `20ab642` merged the v1.9.0 self-run, converged in 6 of 15 iterations. `d89c0ac` reads, in full, *"merge: three self-runs of harness work, none of which converged"*. Real fixes came out of that third merge and none of them earned a convergence stamp, so the commit says so. A tool that publishes only its successful self-audits is evidence of nothing.

**A lesson a machine can check becomes a check, never a paragraph.** This is the mechanism that accumulates. When a run finds a defect in the engine, the fix is not a warning in the documentation but a behavioural check in `scripts/validate.sh` that fails if the defect returns. The count is the visible result: it started at 119 and stands at <!-- count:checks -->**312 behavioural checks**<!-- /count --> on a clone, each one added because something went wrong once and was made unable to go wrong silently again. The number in that sentence is itself derived by the validator rather than typed, which is the next mechanism.

Check K is the clearest example, because it closed the hole it was born from. The lesson was that a published number must be recomputed from the run rather than copied from wherever it last appeared. Prose saying so would have been read and forgotten. Instead check K derives the check count this repository publishes from the validator run itself and refuses a mismatch - and during a release build it did exactly that, rejecting a stale `203` that a human had already read past.

**The gate grades the run's evidence, not only the code.** The adversarial evaluator is the mechanism that makes self-improvement honest, because the most common failure is not a missed bug but a proof that does not prove anything. `path-to-regexp` is the plainest case in the corpus: three runs, five evaluator invocations, four of them rejections, and **not one rejection was a missed defect in the library**. Every one was a defect in the run's own evidence, including a verify command whose randomised assertions could report safe without ever searching. Those findings improve the method, not the target.

**Failures are published beside successes.** `evals/ATTEMPTS.md` carries every attempt, including **34 attempts that did not converge**, each with the budget it was given before it started and the reason it ran out. A corpus of only successes cannot teach anything about where the method stops working, and knowing where it stops is what tells us what to build next. Several of the engine's largest changes exist because a published failure named the gap first.

The governing principle came from a self-run that caught its own author. A run promoted a lesson into `PLAN.md` and then broke that same lesson two iterations later, in the very work that promoted it. **A promoted lesson does not protect the iteration that promotes it.** So where a lesson can be checked mechanically it belongs in the harness, and where it cannot it is written down knowing that prose is the weaker instrument.

