# Usage

```
/jeffy [N] [focus...] [--max-time <45m|2h|900s>] [--max-iter-time <20m>] [--max-context <4>]
```

- `--max-context` - optional context-pressure advisory, **off by default**. The engine re-feeds one session, so context accumulates within a run; past N times the transcript's size at the run's first iteration, the loop is advised to finish its current task and close so the next run reads the state files with a clean window. It advises and never stops: the closing rule governs and a declared budget is never cut short. Measured from the transcript rather than counted in iterations, and reported every iteration whether a threshold is set or not.
- `--max-time` / `--max-iter-time` - optional time ceilings, **off by default**. A turn budget counts turns and a turn is unbounded in time, so these bound the run in hours instead: `--max-time` ends the run out of time the way exhaustion ends it out of turns, and `--max-iter-time` draws a note on a long iteration, ending the run after two consecutive ones. Neither can cut a turn short (the hook fires at turn end) and neither preempts a closing extension or a converged declaration. They default to off rather than to a number nobody measured; for reference, rounds of ten iterations in [the receipts](../evals/README.md) run roughly 60 to 130 minutes. Elapsed wall time is reported every iteration either way.
- `N` - iteration budget, default 10. Sizing is low-stakes in both directions: the loop ends itself at convergence, so unused budget costs nothing, and a budget that runs dry loses no work - the next `/jeffy` picks up where the run stopped. The floor for converging in one run is the opening audit, one iteration per expected finding, and a closing audit; when that arithmetic outgrows the default, prefer a second run over a bigger number (see [Good to know](#good-to-know)).
- `focus` - optional directive for the run, e.g. `/jeffy 8 test coverage and error handling`.

```
/jeffy                                     # 10 iterations, full-spectrum improvement
/jeffy 5                                   # 5 iterations
/jeffy 12 accessibility and performance    # 12 iterations with a focus directive
/jeffy 15                                  # one round of 15 - the loose budget for a wide surface
/jeffy 10 --max-time 2h                    # 10 iterations, but stop after two hours either way
```

A **round** is one `/jeffy` invocation; a **budget** is rounds times iterations. [The receipts](../evals/README.md) were mostly run as 3 rounds of 10, declared before launch: `/jeffy 10`, a new session, `/jeffy 10` again, a third time if the second did not converge. The loop ends itself at convergence, so a declared spare round costs nothing when it is not needed. To run rounds without typing them, see [How to run Jeffy fully autonomously](headless.md).

**Scoped mode.** By default `/jeffy` runs in Improvement mode: an open-ended audit-and-fix loop. To run it against a concrete target instead, edit `PLAN.md` - replace the Goal and Definition of done with the target, seed `BACKLOG.md` with the finite tasks, then run `/jeffy`. Everything else (envelope, verify gate, checkpoints, journal, report) behaves the same.

**Cancel.** Run `/cancel-jeffy`. It reports which loop it found, deletes the loop state file, and leaves `PLAN.md`, `BACKLOG.md`, and `JOURNAL.md` untouched, so the next `/jeffy` picks up exactly where it left off. (Equivalent manual action: delete `.claude/jeffy-loop.local.md` at the project root.)

## Use several short runs, not one long one

A budget is a ceiling, not a target. **Run `/jeffy 10`, let it finish, close the session, then open a new one and run it again.** The receipts that took 40 or 58 or 74 iterations got there as four to eight budgeted runs, never as one enormous budget.

The reason is context. The loop starts each iteration from written state precisely because a fresh reading of the record beats a long conversation's memory of it, but inside one session that conversation keeps growing until the loop is reasoning over its own transcript instead of its files. A new session throws that away. The receipts show the cost of skipping it: in the python-dotenv run, later runs kept filing findings on surface earlier runs had already swept and scored clean.

The restart is also the natural review point. Between runs the tree is committed and the report is written, so it costs nothing to read the journal, answer anything under Proposed, and decide whether to keep going.

## Already installed? Upgrade

Upgrading touches `~/.claude` and nothing else. No project you have run against is modified. Pull and re-install:

```bash
cd jeffy-loop && git pull
./install.sh        # Windows PowerShell: .\install.ps1
```

Then **start a new Claude Code session** - skills and hook registrations are read at session start, so an open session keeps running the old engine until you restart it. That is the whole upgrade. `/jeffy` names the engine version on its first line, so you will see the new one immediately.

Deleted the clone since installing? Clone it again and run the installer from there; it only ever reads from the clone.

- **Re-run** - always safe: it skips what is installed, upgrades in place, and never duplicates the hook registration.
- **Uninstall** - delete `~/.claude/skills/jeffy` and `~/.claude/skills/cancel-jeffy`, and remove the hook entry from `~/.claude/settings.json`.

> [!NOTE]
> Do not upgrade underneath a live run. The Stop hook is read from disk every time it fires, so replacing it mid-run changes that run's rules halfway through. Let the run finish, or stop it with `/cancel-jeffy` first.

> [!NOTE]
> The installer copies over the top and never deletes, so a file removed in a later version stays behind. For a clean slate, delete `~/.claude/skills/jeffy` and `~/.claude/skills/cancel-jeffy` before re-running it - the installer puts both back.

## Good to know

- **One loop per project at a time.** A crashed session can leave a stale state file behind; the skill detects it at launch and asks before cleaning up.
- **You can talk to the session mid-run.** Your message gets answered, then the loop resumes on its own. The turn counts against the budget.
- **Permission prompts pause the loop.** For unattended runs, allowlist your test and file tools or use acceptEdits mode. Never allowlist push or force operations for a loop.
- **Budget counts turns, and a single turn is unbounded in time and cost.** Keep N small on a first run and watch it. Check spend anytime with `/cost`.
- **Prefer several small runs over one big one.** Context accumulates across iterations within a run, and the state files carry everything between runs, so two runs of 5 beat one run of 10 - but the clean context only arrives with a new session. Close the session and start a fresh one in the same directory; nothing is lost.
- **Edit `PLAN.md` or `BACKLOG.md` between iterations, not mid-iteration.** The Proposed section is the designed channel for decisions.
- **A `.jeffy/` directory appears at the root of a project the loop has swept.** It holds the known-answer probe batteries a later sweep re-runs instead of rebuilding, and the evaluator artifacts under `.jeffy/evaluator/` - one per gate invocation, naming the commands the adversarial gate actually ran and what they exited. The checkpoints commit all of it on purpose - loop memory, exactly like the three state files. Only the transient loop state file is gitignored.

