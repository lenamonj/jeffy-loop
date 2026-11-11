# Usage

```
/jeffy [N] [focus...] [--highs] [--max-time <45m|2h|900s>] [--max-iter-time <20m>] [--max-context <4>] [--max-surface <lines>] [--refeed pointer] [--evaluator-probe <k>]
```

- `N` - iteration budget, default 10. Sizing is low-stakes in both directions: the loop ends itself at convergence, so unused budget costs nothing, and a budget that runs dry loses no work - the next `/jeffy` picks up where the run stopped. The floor for converging in one run is the opening audit, one iteration per expected finding, and a closing audit; when that arithmetic outgrows the default, prefer a second run over a bigger number (see [Use several short runs](#use-several-short-runs-not-one-long-one)).
- `focus` - optional directive for the run, e.g. `/jeffy 8 test coverage and error handling`.
- `--highs` - High-hunt mode, see [High hunt](#high-hunt). Default budget 5.
- `--max-time` / `--max-iter-time` - optional time ceilings, **off by default**. A turn budget counts turns and a turn is unbounded in time, so these bound the run in hours instead: `--max-time` ends the run out of time the way exhaustion ends it out of turns, and `--max-iter-time` draws a note on a long iteration, ending the run after two consecutive ones. Neither can cut a turn short (the hook fires at turn end) and neither preempts a closing extension or a converged declaration. They default to off rather than to a number nobody measured; for reference, rounds of ten iterations in [the receipts](../evals/README.md) run roughly 60 to 130 minutes. Elapsed wall time is reported every iteration either way.
- `--max-surface` - the size ceiling, **on by default**: 150,000 tracked source lines on an Improvement launch, 600,000 on a `--highs` launch, `0` off. Pre-flight measures the tree from one git listing (source extensions, vendored directories skipped) and refuses to start above the ceiling, printing the measurement, the five largest files and the exact flag to relaunch with. Every iteration audits the whole surface, so a tree three to ten times the usual one costs three to ten times the hours and the usage; the ceiling makes that a number typed on purpose rather than one discovered at round three. The measurement is a floor: it does not know what is generated or out of scope.
- `--max-context` - optional context-pressure advisory, **off by default**. The engine re-feeds one session, so context accumulates within a run; past N times the transcript's size at the run's first iteration, the loop is advised to finish its current task and close so the next run reads the state files with a clean window. It advises and never stops: the closing rule governs and a declared budget is never cut short. Measured from the transcript rather than counted in iterations, and reported every iteration whether a threshold is set or not.
- `--refeed pointer` - experimental, **off by default**. The Stop hook normally re-feeds the whole iteration prompt at every turn end, about 34 KB of text; in three measured runs that text was 21 to 29 percent of the transcript. With `pointer` the hook re-feeds the run state and one sentence pointing at the prompt file the session read at launch, so the rules stay on disk instead of repeating in the window. The default is unchanged and stays so until a pre-registered A/B on converged targets shows the pointer loses no convergence and no evaluator verdict.
- `--evaluator-probe <k>` - optional, **off by default** (`0`). The evaluator gate is told to check the run's own evidence and not to audit for findings of its own; with `k` above 0 it also probes the `k` swept Surface inventory rows with the oldest sweep commits, re-running each row's battery and driving it with one input no filed finding or battery already exercises, and names each one in its artifact on its own line reading `Probed row: <row name>` - one row to a line, because a row name is free prose that commonly carries commas. The Stop hook counts those lines and refuses a declaration whose PASS artifact names fewer than `k` probed rows, or fewer than every swept row on a smaller map. Added in 1.28.0 after a study of five targets with one converged and one unconverged attempt found that, on four of them, the converged gate had passed a tree still carrying a High the other attempt filed; whether it becomes a default waits on a pre-registered comparison.

```
/jeffy                                     # 10 iterations, full-spectrum improvement
/jeffy 5                                   # 5 iterations
/jeffy 12 accessibility and performance    # 12 iterations with a focus directive
/jeffy 15                                  # one round of 15 - the loose budget for a wide surface
/jeffy 5 --highs                           # High hunt: find and fix only the Highs
/jeffy 10 --max-time 2h                    # 10 iterations, but stop after two hours either way
/jeffy 10 --max-surface 300000             # run a tree measured at 235k source lines, knowingly
```

## High hunt

A High hunt fixes only the Highs and stops at the first audit that finds none, so it is usually the faster run.

```
/jeffy 5 --highs
```

A hunt is the loop with the convergence machinery switched off. It audits the whole surface, fixes only Highs, audits again once no High is open, and closes the first time an audit finds none. There is no sweep obligation, no Medium or Low queue, no evaluator gate, no closing extension and no convergence claim; a Medium or Low the audit notices is written into that audit's journal entry as `Noted, not filed:` and left alone. The close is a `Hunted:` line in `BACKLOG.md` naming the commit a fresh audit found clean of Highs, and the Stop hook refuses it over any open line that is not a High, a closing audit with no resolvable checkpoint, or a product change after that audit. A hunt is not a convergence and is never listed as one in [the receipts](../evals/README.md); its receipt is the pull request its Highs produce. A hunt's state files and a standard run's do not mix: the launcher refuses `--highs` over a standard `PLAN.md` and a standard launch over a hunt's, so archive one set before switching modes on a project.

## Scoped mode

By default `/jeffy` runs in Improvement mode: an open-ended audit-and-fix loop. To run it against a concrete target instead, edit `PLAN.md` - replace the Goal and Definition of done with the target, seed `BACKLOG.md` with the finite tasks, then run `/jeffy`. Everything else (envelope, verify gate, checkpoints, journal, report) behaves the same.

## Cancel

```
/cancel-jeffy
```

It reports which loop it found, deletes the loop state file, and leaves `PLAN.md`, `BACKLOG.md`, and `JOURNAL.md` untouched, so the next `/jeffy` picks up exactly where it left off. The equivalent manual action is deleting `.claude/jeffy-loop.local.md` at the project root.

## Use several short runs, not one long one

A **round** is one `/jeffy` invocation; a **budget** is rounds times iterations. [The receipts](../evals/README.md) were mostly run as 3 rounds of 10, declared before launch: `/jeffy 10`, a new session, `/jeffy 10` again, a third time if the second did not converge. The loop ends itself at convergence, so a declared spare round costs nothing when it is not needed. To run rounds without typing them, see [How to run Jeffy fully autonomously](headless.md).

A budget is a ceiling, not a target. **Run `/jeffy 10`, let it finish, close the session, then open a new one and run it again.** The receipts that took 40 or 58 or 74 iterations got there as four to eight budgeted runs, never as one enormous budget.

The reason is context. The loop starts each iteration from written state precisely because a fresh reading of the record beats a long conversation's memory of it, but inside one session that conversation keeps growing until the loop is reasoning over its own transcript instead of its files. A new session throws that away. The receipts show the cost of skipping it: in the python-dotenv run, later runs kept filing findings on surface earlier runs had already swept and scored clean.

The restart is also the natural review point. Between runs the tree is committed and the report is written, so it costs nothing to read the journal, answer anything under Proposed, and decide whether to keep going.

## Good to know

- **One loop per project at a time.** A crashed session can leave a stale state file behind; the skill detects it at launch and asks before cleaning up.
- **You can talk to the session mid-run.** Your message gets answered, then the loop resumes on its own. The turn counts against the budget.
- **Permission prompts pause the loop.** For unattended runs, allowlist your test and file tools or use acceptEdits mode. Never allowlist push or force operations for a loop.
- **Budget counts turns, and a single turn is unbounded in time and cost.** Keep N small on a first run and watch it. Check spend anytime with `/cost`.
- **Edit `PLAN.md` or `BACKLOG.md` between iterations, not mid-iteration.** The Proposed section is the designed channel for decisions.
- **A `.jeffy/` directory appears at the root of a project the loop has swept.** It holds the known-answer probe batteries a later sweep re-runs instead of rebuilding, and the evaluator artifacts under `.jeffy/evaluator/` - one per gate invocation, naming the commands the adversarial gate actually ran and what they exited. The checkpoints commit all of it on purpose - loop memory, exactly like the three state files. Only the transient loop state file is gitignored.
- **`bash ~/.claude/skills/jeffy/hooks/stop-hook.sh --lint` from a project root, during a run, prints what a declaration would be refused on.** It does not run your tests; on a Rust or npm project it calls `cargo package --list --allow-dirty` or `npm pack --dry-run --json --ignore-scripts` to read what would ship. The loop calls it itself before each gate invocation.

## Already installed? Upgrade

Upgrading touches `~/.claude` and nothing else; no project you have run against is modified. From a clone, pull and re-install:

```bash
cd jeffy-loop && git pull
./install.sh        # Windows PowerShell: .\install.ps1
```

From PyPI, upgrade the package and re-run its installer; `pipx upgrade jeffy-loop` and `uv tool upgrade jeffy-loop` replace the first line:

```bash
pip install --upgrade jeffy-loop
jeffy install
```

Then start a new Claude Code session. Skills and hook registrations are read at session start, so an open session keeps running the old engine until you restart it. `/jeffy` names the engine version on its first line, so you will see the new one immediately.

- **Re-running an installer is always safe.** It skips what is installed, upgrades in place, removes the files the new version no longer ships, and never duplicates the hook registration. `references/` under the installed skill is replaced on reinstall: edits there do not survive.
- **Do not upgrade underneath a live run.** The Stop hook is read from disk every time it fires, so replacing it mid-run changes that run's rules halfway through. Let the run finish, or stop it with `/cancel-jeffy` first.
- **Deleted the clone since installing?** Clone it again and run the installer from there; it only ever reads from the clone.
- **Uninstall.** `jeffy uninstall` from a PyPI install; otherwise delete `~/.claude/skills/jeffy` and `~/.claude/skills/cancel-jeffy` and remove the hook entry from `~/.claude/settings.json`.

## Telemetry

Every Stop writes one JSON record to `.jeffy/metrics/<run>.jsonl`. From 1.28.0 each record also carries what the session has consumed, read from its Claude Code transcript:

- **`session8`** is the first eight characters of the session id, so records from two sessions of one run stay apart.
- **`model`** names the model or models the session's API messages ran, comma-separated in first-seen order.
- **`api_messages`** counts API messages, each once, however many transcript entries repeat it.
- **`tokens_input`, `tokens_cache_write_5m`, `tokens_cache_write_1h`, `tokens_cache_read` and `tokens_output`** are the token components, kept apart because each is priced differently.
- **`context_tokens_last` and `context_tokens_peak`** are the main session's live context in tokens at its last API message and at its largest; RUN STATE states the last as `context <n> tokens`.
- **`iter_type`** is the iteration's type from its JOURNAL.md heading (`AUDIT`, `T3`, `EVALUATOR`), null when the heading is not there yet.

The figures are cumulative over the session since the run's `started_at`, sub-agent transcripts included (the evaluator gate is one). The transcript can lag the conversation, so a final message missing at one Stop lands in the next record, and a run's last record can miss its final message. A transcript the hook cannot read leaves every token field null; it never ends a run. `cost_estimate_usd` stays null: the engine records tokens, not prices.

```
bash scripts/jeffy-stats.sh [project-root] [--weights in,w5m,w1h,read,out] [--input-price <usd per million>]
```

Without flags it adds `IN_M` (input-side tokens in millions) and `OUT_K` (output tokens in thousands) per run, and a `BY TYPE` table of what each iteration type consumed. `--weights` multiplies the five components into weighted units of base input (`W_M`) and prints the cache reads' share of them (`READ_PCT`); `--input-price` turns weighted units into dollars (`COST`). There is no default, because the weights differ by model. From the pricing page (https://platform.claude.com/docs/en/about-claude/pricing, read 2026-11-08): a five-minute cache write is 1.25 times the base input price, a one-hour write 2 times and output 5 times on every model; a cache read is 0.1 times on most models, 0.05 times on Opus 5.5 and Sonnet 5.5, and 0.025 times on Fable 5.1 and Mythos 5.1. A run on Opus 5.5, whose base input price is $4 per million:

```
bash scripts/jeffy-stats.sh . --weights 1,1.25,2,0.05,5 --input-price 4
```

**Which rules fire.** From 1.29.0 every refusal and every run ending the Stop hook can state has a name, stated after its text as `(rule <name>)`. Each time one is stated, the hook appends a line to `.jeffy/metrics/<run>.fires.tsv`: epoch seconds, the iteration, the path and the name, tab separated. The path is `lint` when `stop-hook.sh --lint` printed the refusal, `declaration` when a declaration was refused, and `end` when the hook ended the run. Lint appends its line and still writes no turn record. The log holds names and never message text, and a line that cannot be written changes no verdict. `stop-hook.sh --rules` prints every name the engine carries.

```
bash scripts/jeffy-stats.sh [project-root] --rules
```

`--rules` counts each rule's fires by path (`LINT`, `DECLARED`, `ENDED`) and the runs it fired in (`RUNS`). It then lists the rules that never fired in this project, any fired name this engine does not carry, and the refused declarations of runs that predate the log. A line it cannot read, in a fire log or in such a run's turn records, is counted and said. A count is evidence of use, not a score: a rule can be silent because lint taught the run to avoid it.
