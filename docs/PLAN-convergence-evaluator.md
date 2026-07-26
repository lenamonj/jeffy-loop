# Plan: independent convergence evaluator (the second signature)

Status: proposed, not yet implemented. This is an implementation plan, not loop state -
it deliberately lives in docs/ because a root PLAN.md would be adopted by Jeffy's own
bootstrap as loop state.

## Why this change, and only this change

Jeffy's per-task verification is already objective: every task carries a runnable
acceptance check, and the verify gate re-runs the project's real gate each iteration.
The one judgment call the loop still grades itself on is the one that matters most:
the convergence declaration. The closing audit - "zero High, zero Medium, Definition
of done genuinely true" - is performed by the same agent, in the same context, that
just wrote every fix in the run. That context is full of the reasons the work was done
the way it was, which is precisely the self-persuasion failure mode documented for
generator-graded output: an agent asked to grade its own work praises it, and tuning
an independent skeptic is far more tractable than making the author self-critical.

The fix is structural, small, and bounded: exactly one fresh-context skeptical
evaluator sub-agent, invoked only at the moment of convergence declaration, whose
PASS becomes a precondition for emitting the completion promise. Everything else in
Jeffy stays as it is.

## Design

### Scope and invariants

- Exactly one evaluator invocation per convergence attempt. Never per task, never
  during ordinary iterations, never as a panel.
- The ratchet stays evaluator-free. Ratchet re-convergence verifies a mechanical fact
  (unchanged tree since a recorded converged commit), not a judgment; adding an
  evaluator there would tax every relaunch for nothing.
- The evaluator is subject to the same evidence rule as the audit: a REJECT reason
  must point at a file and line, a failing command, or a reproduced behavior.
  Opinions are not findings.
- The Operating envelope binds the evaluator exactly as it binds the audit:
  out-of-envelope reasons are Low at most, envelope challenges go to Proposed.
- Fail open with disclosure: if sub-agent spawning is unavailable in the session
  (no sub-agent tool, or permission denied), record `Evaluator: unavailable
  (<reason>)` in the closing journal entry and in the run report, and let the
  existing convergence rule stand. This mirrors the Stop hook's jq fail-open
  philosophy: never brick a run over a missing capability, always say so out loud.

### The evaluator sub-agent

Spawned fresh-context at the point the closing rule would otherwise emit the promise.
Its instructions (embedded verbatim in the iteration prompt, compact form):

> You are an adversarial reviewer for an autonomous improvement run. Assume the run's
> work is broken until proven otherwise; do not praise. You are given the project
> root. Read PLAN.md (Goal, Operating envelope, Method, Verify command, Definition of
> done) and BACKLOG.md, and the run's changes: git diff and git log against the commit
> that preceded this run's first `jeffy:` checkpoint. Check, in order: (1) run the
> Verify command yourself and paste its real output; (2) re-run the acceptance checks
> of tasks closed this run, from the journal's closing lines, and paste real output;
> (3) look for in-envelope High or Medium findings the closing audit missed,
> especially in code this run touched; (4) check the Definition of done clause by
> clause against evidence, not assertion. Verdict: PASS only if every check holds.
> Otherwise REJECT with each reason as one line carrying a file and line, a failing
> command, or a reproduced behavior. Out-of-envelope reasons are Low at most. Return
> only the verdict and the reasons.

### Verdict handling

- PASS: record `Evaluator: PASS - <one-line summary>` in the Verification field of
  the closing JOURNAL entry, then proceed exactly as today: run report, then the
  promise. The promise may never be emitted without a recorded PASS (or a recorded
  unavailability) in that entry.
- REJECT: convergence is not declared. Each substantiated reason is filed as an
  ordinary backlog task at rubric severity (or under Proposed if it is an envelope
  challenge), a journal entry records the rejection, and the run continues under the
  normal iteration discipline and budget.
- Rejection cap: at most 2 evaluator invocations per run. A second REJECT ends the
  run as a hard blocker - journal entry naming the evaluator's remaining reasons,
  state file deleted, run report listing them - instead of letting generator and
  evaluator ping-pong the budget away. The next `/jeffy` run picks the filed tasks up
  from the backlog as usual.

## File-by-file changes

### 1. `skills/jeffy/references/iteration-prompt.txt`

The only behavioral change. In the closing rule, between the existing convergence
conditions and "output the run report, then the exact phrase JEFFY CONVERGED":

- Insert the evaluator step: spawn one fresh-context sub-agent with the instructions
  above (compact inline form), handle PASS / REJECT / unavailable as specified,
  including the 2-invocation cap and the requirement that the verdict line lands in
  the closing entry's Verification field.
- State explicitly that the ratchet path skips the evaluator.

Constraints: the file must remain a single line (the hook reads and JSON-encodes it
as one line; the validator enforces this), and the added text must not contain the
promise phrase in its tagged form.

### 2. `skills/jeffy/references/plan-default.md`

- Definition of done: add one sentence - convergence additionally requires the
  independent evaluator's PASS recorded in the closing journal entry, or its recorded
  unavailability with the reason.
- Audit discipline clause: the current wording forbids "adversarial sub-auditor
  panels" outright, which would now contradict the closing rule. Reword to: never
  escalate rigor unilaterally - no improvised sub-auditor panels, fuzzing campaigns,
  or dimensions beyond the Goal's list; the single convergence evaluator defined in
  the Definition of done is the only sub-agent review this Method authorizes.

### 3. `skills/jeffy/references/journal-default.md`

One line: the closing entry's Verification field carries the evaluator verdict
(`Evaluator: PASS - ...`, or `Evaluator: unavailable (...)`). No new heading tokens,
no grammar change - REJECT outcomes are ordinary entries under the existing grammar.

### 4. `README.md`

- "Done means done" bullet: one sentence - before the loop may declare convergence, a
  fresh-context skeptical evaluator, spawned with none of the run's self-persuasion in
  its context, re-runs the gate and the closed tasks' checks and must return PASS; a
  REJECT files its evidence as tasks and the run continues.
- "The rules a run lives by": add the evaluator rule with the 2-rejection cap.

### 5. `scripts/validate.sh`

Extend the governance markers so the gate cannot silently regress:

- iteration-prompt.txt must contain the evaluator-gate phrases (spawn, PASS
  precondition, rejection cap) - and must still be a single line.
- plan-default.md's Definition of done must mention the evaluator PASS requirement.
- Negative-path check in the same style as the existing marker tests: a scratch copy
  with the evaluator marker mangled must fail validation.

### 6. No changes

- `hooks/stop-hook.sh` - the engine is untouched; the gate lives entirely in the
  prompt/method layer, which keeps the trust model ("the entire engine is one
  auditable shell script") intact.
- `backlog-default.md`, `cancel-jeffy`, installers - evaluator findings are ordinary
  tasks; nothing structural changes.

## Acceptance checks for this change itself

- `bash scripts/validate.sh` exits 0 with the new markers; the mangled-marker
  negative test fails as designed.
- `wc -l` on iteration-prompt.txt is still 1.
- End-to-end: run `/jeffy` on a small scratch project to convergence; the closing
  journal entry shows `Evaluator: PASS`; then seed a deliberate uncaught Medium
  (e.g. a swallowed error in code the run touched) and confirm the evaluator REJECTs
  and the reason lands in BACKLOG.md.

## Explicitly not adopted (considered and declined)

- Per-task evaluator review - the runnable acceptance check is already an objective
  verifier; a second opinion per task adds cost without a failure mode to close.
- Wall-clock/token cap in the hook - the iteration budget plus stall detection plus
  `/cost` covers the realistic risk; engine complexity not justified today.
- Parallel worktrees, connectors, scheduled-run recipes - all conflict with or dilute
  Jeffy's identity (one verified task per iteration, local-only writes, one auditable
  engine script) for marginal gain.
