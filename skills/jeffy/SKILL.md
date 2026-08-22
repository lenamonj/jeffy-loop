---
name: jeffy
description: Use when the user runs /jeffy to start an autonomous Jeffy improvement loop on the current project
disable-model-invocation: true
argument-hint: "[N] [focus...]"
---

# Jeffy

Bootstrap per-project Jeffy state files, write the loop state file, and begin iteration 1. The loop engine is Jeffy's own Stop hook, shipped with this skill at hooks/stop-hook.sh: at every turn end it reads `.claude/jeffy-loop.local.md` at the project root, and while that file names this session and budget remains it re-feeds the iteration prompt; it deletes the file and lets the session end when the budget is spent or the completion promise fires. The hook anchors itself to CLAUDE_PROJECT_DIR, which hooks receive fixed at the directory Claude Code was started in, so shell cwd drift mid-iteration cannot kill the loop. The hook is registered machine-wide in `~/.claude/settings.json` by the installer but exits immediately in any session whose project has no state file. This skill only sets up and launches; the hook implements the loop mechanics.

Project root means the directory Claude Code was started in - the session's primary working directory shown in the environment, which is stable regardless of shell drift. Resolve it to an absolute path with forward slashes and use it everywhere below; never trust the shell's current cwd, which persists across Bash calls and may have drifted into a subdirectory.

## Arguments

Parse $ARGUMENTS: if the first token is an integer, it is the iteration budget N, default 10; all remaining text is a focus directive for this run. If the token after the optional budget is exactly `enhance`, refuse the launch and stop: Enhance mode was removed in v1.11.0 - the defect loop is the product - and the last release that carries it is v1.10.0. On a fresh project, iteration 1 is always consumed by the audit that generates the backlog, so N=2 executes exactly one task; if the user picks N below 5, proceed but note that larger budgets make materially more progress.

## Step 1: Pre-flight

If any check fails, stop and report the exact fix needed. Do no other work first.

1. Hook dependency: `which jq`. If missing the Stop hook cannot parse its input and the loop cannot run. Suggest `winget install jqlang.jq` (Windows), `brew install jq` (macOS), or `sudo apt-get install jq` (Debian/Ubuntu) and stop.
2. Hook install: locate Jeffy's Stop hook script, substituting the absolute home directory and using forward slashes even on Windows (`~` is not expanded by this tool). Glob for `<home>/.claude/skills/jeffy/hooks/stop-hook.sh`. If it is missing, the install is broken or predates the self-owned engine; tell the user to re-run the installer (install.sh or install.ps1) and stop. If it exists, the hook must also be registered: read `<home>/.claude/settings.json` and confirm some Stop hook command contains `skills/jeffy/hooks/stop-hook.sh`. If the registration is missing, tell the user to re-run the installer, which registers it, and stop.
3. Session identity: `echo "$CLAUDE_CODE_SESSION_ID"` must print a non-empty id. If empty, the state file would be written without session scoping and the loop would capture every Claude session in this project. Stop.
4. Existing loop state: if `.claude/jeffy-loop.local.md` exists at the project root, do not assume a loop is active. Read its frontmatter and compare its `session_id` with the current session id:
   - Equal: this session already has a loop running. Stop.
   - Different or missing: either another live session owns it or, far more often, it is an orphan from a closed session. The hook deletes the file only when its own session reaches the budget or the promise, so a crashed or closed session leaks it forever. Report the file's session_id, started_at, and iteration, then ask the user: if no other session is running Jeffy in this project, confirm deletion and continue; otherwise stop. Never delete the file without explicit confirmation.
   Also check for a legacy `.claude/ralph-loop.local.md` at the project root: it belongs to the ralph-loop plugin's engine (or a pre-2.0 Jeffy). If present, a ralph-loop-driven loop may still be active in another session; report it and ask the user to cancel or delete it before launching, so two engines never interleave in one project.
5. Checkpoint baseline: if the project is a git repository (`git rev-parse --is-inside-work-tree` succeeds), run `git status --porcelain` and ignore any path under `.jeffy/metrics/`. That file is the engine's own telemetry, written at the end of every turn including the one that ends a run - so the last write of any completed run necessarily lands after that run's final checkpoint and leaves the path modified with no iteration left to commit it. It is never the user's work, the next checkpoint sweeps it up, and treating it as a dirty tree stops every unattended second round dead: the question goes to a headless session that cannot answer it. If what remains prints anything, tell the user: the loop ends every iteration with a local checkpoint commit made with `git add -A`, so these uncommitted changes would be swept into the first checkpoint. Ask them to choose: commit or stash first (then relaunch), proceed anyway (their changes ride along in the first jeffy checkpoint), or abort. Never proceed silently past a dirty tree. When every modified path is a symlink in the index (`git ls-files -s` reports mode `120000` for each), say so explicitly: the likely cause is a cross-filesystem tree - Windows git cannot stat symlinks over `\\wsl.localhost` and reports them all modified - and the fix is running the loop from a git that lives on the same filesystem as the tree, not committing or stashing. If the project is not a git repository, note once that checkpoints, salvage, the ratchet, the verify-gate revert, and the stall check degrade to journal-only discipline, and continue.
6. Verify command lint: if `PLAN.md` exists at the project root and its `## Verify command` section carries a `Command: ` line whose payload is neither `none` nor an unfilled `<...>` placeholder, sanitize that payload exactly as the hook does - trim the surrounding whitespace, then strip one wrapping pair of backticks when both ends carry one and nothing between them does - and run `bash -n` over the result. If it does not parse, report the exact defect (the first `bash -n` error line) and the exact corrected `Command: ` line to write into PLAN.md, then stop. Apply the same refusal when the payload contains a pipe and its final pipeline stage is a pager or truncator - `head`, `tail`, `less`, `more`, or `cat` - because the pipeline's exit status is then the truncator's, not the suite's, and a failing suite reports green; name the offending stage and tell the user to drop it. The hook executes that line verbatim at the converged stop, so a malformed line costs a rejected declaration at the end of a run instead of one message at its start. A missing PLAN.md, a section carrying no `Command: ` line, a payload of `none`, and a payload still wearing the template's `<first audit fills this in>` placeholder are all fine and stop nothing: the hook skips its own check on the first three, and the placeholder is the line the first audit exists to fill, so linting it would hard-stop every relaunch whose bootstrapped PLAN.md never reached that audit.
7. Line-ending safety: if the project is a git repository and the platform is not Windows (or the project root is a Linux or WSL filesystem path), run `git config core.autocrlf`. If it prints `true` or `input`, refuse to launch: the loop's verify-gate revert path runs `git checkout`, which would rewrite every text file in the tree to CRLF and break the build while looking like a clean revert. Report the exact fix - run `git config core.autocrlf false` at the project root - and stop.
8. Repository scope: if the project is a git repository, compare `git rev-parse --show-toplevel` with the project root. When they differ, the project is a subdirectory of a larger repository, so every checkpoint's `git add -A` stages changes across the whole parent tree. State both paths plainly and ask the user whether to proceed, exactly as the dirty-tree check does; working in a subdirectory is legitimate, so never refuse outright.
9. Nested Jeffy project: glob for `*/.claude/jeffy-loop.local.md` and `*/PLAN.md` below the project root. If a nested directory carries Jeffy state files, surface its path and ask whether the user meant to launch there instead: launching above an existing Jeffy project sweeps that project's state files into this project's checkpoints.

## Step 2: Bootstrap state files

Create each file at the project root only if it is missing. The default contents live in this skill's references directory and are copied with cp, never read into context or retyped: the templates are large static payloads and the copy is byte-exact.

First resolve REF, the absolute path of this skill's references directory. Glob for `<home>/.claude/skills/jeffy/references/iteration-prompt.txt`, substituting the absolute home directory with forward slashes as in pre-flight check 2. REF is the directory of the match. If nothing matches, stop and report a broken install: the references directory is missing, so re-run the installer. Substitute the resolved REF below and wherever later steps say REF.

Mode guard: when PLAN.md already exists at the project root, read the first word of its `## Mode` section body. If it reads Enhance, refuse the launch: Enhance mode was removed in v1.11.0, and its ledger ranks work by impact rather than severity, so its state files must not continue under the standard rules. Tell the user to archive those state files first - commit them and delete them, or keep them on a separate branch or checkout - and relaunch standard, or to run v1.10.0, the last release that carries the mode; then stop. Any other mode proceeds and reuses the existing state files exactly as any relaunch does; a PLAN.md with no `## Mode` section is a user-authored plan and is treated as standard.

```bash
REF="<resolved references dir>"
PR="<PROJECT_ROOT>"
[ -f "$PR/PLAN.md" ]    || cp "$REF/plan-default.md"    "$PR/PLAN.md"
[ -f "$PR/BACKLOG.md" ] || cp "$REF/backlog-default.md" "$PR/BACKLOG.md"
[ -f "$PR/JOURNAL.md" ] || cp "$REF/journal-default.md" "$PR/JOURNAL.md"
```

The templates define Improvement mode (PLAN.md with the Goal, Operating envelope, Method, severity rubric, and Definition of done), the BACKLOG.md ledger sections (Now, Next, Later, Proposed, Settled classes, Declined, Converged), and the append-only JOURNAL.md heading grammar. Edit the copies in the project to customize one run; edit the templates in references/ only to change every future run.

All work happens directly in the current project folder on the current branch. When the project is a git repository, every iteration ends in a local checkpoint commit made with git add -A and a message prefixed jeffy:. The checkpoint is the loop's revert and recovery unit; nothing is ever pushed and no branches are created - the user reviews with git log and squashes if they want one commit. Because the checkpoint uses git add -A, also do this during bootstrap: if the project is a git repository and `git check-ignore -q .claude/jeffy-loop.local.md` fails, append `.claude/jeffy-loop.local.md` to the project's .gitignore (creating the file if needed) so the transient session-scoped loop state can never be committed.

## Step 3: Launch the loop

Verify bound first: when PLAN.md exists at the project root and carries a `Command: ` line under `## Verify command`, look there for a labeled line reading `Verify duration: <N>s` (a measured figure earlier runs record). The launcher computes no bound of its own: it resolves the same chain the hook resolves when the state file carries no key - `verify_timeout_seconds`, else `Verify duration` x3 floored at 240s, else 240s, capped at 1740s because the installer registers the hook with an 1800s timeout. Found: resolve that chain against the measured seconds and add a `verify_timeout_seconds: <bound>` line to the frontmatter written below, so the Stop hook's converged-stop verify re-run inherits a bound sized to this suite across relaunches. Absent, with a `Command: ` line present: ask the user one question - roughly how long does the verify command run? Resolve the chain against their answer: if it lands on the floor, write no line, because the hook applies that same floor by default; if it lands above the floor, write `verify_timeout_seconds: <that resolved bound>`. This threshold is the chain's rather than a separate one, so it moved when the chain became the single statement of the bound: the replaced text wrote no line for any answer under four minutes, where the chain writes one for any answer above eighty seconds, always wider than the floor it replaces and never narrower. An answer of a minute still writes no line, because three times it lands on the floor. No PLAN.md yet, or no `Command: ` line: write no line and move on; the first run measures, records `Verify duration:` in PLAN.md, and every later launch inherits it from there.

Write the loop state file yourself, at the project root, with an absolute path. If focus text was given, sanitize it first: remove double quotes, backticks, dollar signs, and newlines, which would break the heredoc or the frontmatter, then substitute it below; with no focus, leave the value empty (the line stays, its value blank). Substitute PROJECT_ROOT, REF (resolved in Step 2), and N. `base_head` records the commit the run starts on, or `none` outside a repository; the Stop hook uses it to tell a genuine convergence ratchet, which re-declares a tree an earlier run certified, from a run that did the work itself and typed RATCHET over it. The heredoc terminator EOF must stay at column 0.

```bash
PR="<PROJECT_ROOT>"
REF="<resolved references dir>"
mkdir -p "$PR/.claude"
cat > "$PR/.claude/jeffy-loop.local.md" <<EOF
---
session_id: $CLAUDE_CODE_SESSION_ID
iteration: 1
max_iterations: <N>
prompt_path: $REF/iteration-prompt.txt
focus: <sanitized focus, or empty>
completion_promise: JEFFY CONVERGED
started_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
run_started_at: $(date +%s)
iteration_started_at: $(date +%s)
max_wall_clock_seconds: <seconds from --max-time, else 0>
max_iteration_seconds: <seconds from --max-iter-time, else 0>
max_context_growth: <multiple from --max-context, else 0>
sandboxed: <yes|no|unknown from hooks/lib/detect-sandbox.sh>
base_head: $(git -C "$PR" rev-parse HEAD 2>/dev/null || echo none)
<verify_timeout_seconds line when derived above, else omit this line entirely>
---
Jeffy loop state. Session-scoped and transient: the Stop hook deletes it when
the run ends. Cancel with /cancel-jeffy, or delete this file to end the loop.
EOF
grep -n "session_id\|iteration:" "$PR/.claude/jeffy-loop.local.md"
```

**Blast radius.** Run `bash <REF>/../hooks/lib/detect-sandbox.sh` at launch
and record its answer as `sandboxed` in the state file. When it answers `no`,
the launch banner carries one further line: *"Not sandboxed: this run has
whatever access this shell has - credentials, SSH keys, tokens - and an
unattended agent usually runs with permissions relaxed. See SECURITY.md."*
On `yes` or `unknown`, say nothing. **It never blocks and never prompts.**
The loop does not widen its own mandate, and it has no business narrowing the
operator's either; what it owes them is one honest sentence about what is
reachable, said once, before the run rather than after it.

**Context pressure.** The engine re-feeds one session, so context accumulates
within a run, and the corpus prices that: later runs of long targets re-filed
findings earlier runs had already swept and scored clean. The hook measures it
from the transcript the harness names on its stdin - the thing itself, rather
than an iteration ordinal standing in for it - as a multiple of this run's own
first measurement, which calibrates to the project instead of to a constant
invented here. `--max-context <N>` sets `max_context_growth`; past N times the
opening size, the re-feed carries a CONTEXT PRESSURE note recommending the run
finish its current task and close, so the next one reads the state files with a
clean window. **It is advice and never a stop**: the closing rule governs, and
a pre-registered budget is never cut short by it. Off unless set, and the
measured growth is reported in the run state either way.

**Time ceilings.** A turn budget counts turns, and a turn is unbounded in
time, so the state file carries two optional ceilings the Stop hook enforces
at every turn end. Both are **0 (off) unless the launch sets them**, and that
default is deliberate: this engine publishes no figure it has not measured,
and the right ceiling belongs to the project rather than to the tool. For
reference when choosing one, rounds of ten iterations in the published corpus
run roughly 60 to 130 minutes. `--max-time <duration>` sets
`max_wall_clock_seconds` and ends the run out of time the way exhaustion ends
it out of turns; `--max-iter-time <duration>` sets `max_iteration_seconds`,
after which a long iteration draws an ITERATION OVERRUN note and two
consecutive overruns end the run. Accept `45m`, `2h`, `900s` or a bare
integer of seconds, and `0` as an explicit opt-out. Neither ceiling can cut a
turn short - the hook fires after it - and neither preempts the closing
extension or a converged declaration. Whether a ceiling is set or not, the
run state line reports elapsed wall time every iteration, so a run can see
its own clock.

Verify the write: the grep output must show the current session id and `iteration: 1`. If the session id line is empty or wrong, delete the file, report the failure, and stop. The iteration prompt itself is a single line stored at `$REF/iteration-prompt.txt`; the hook reads it from disk at every turn end and JSON-encodes it with jq, so its content never needs to be injected through the shell. Never edit iteration-prompt.txt casually: the loop's journal grammar, checkpoint discipline, run report, and closing rule all live in it, and it must stay a single line.

Then announce the launch in one line - Jeffy v<version>, N iterations, and the focus if one was given - reading the version from the installed hook with `sed -n 's/^JEFFY_VERSION="\(.*\)"/\1/p' <home>/.claude/skills/jeffy/hooks/stop-hook.sh`, so every run's transcript opens by naming the engine version a bug report needs.

## Step 4: Begin iteration 1

Read "<REF>/iteration-prompt.txt" now (REF as resolved in Step 2), its only in-context load, and immediately start following it yourself. Do not wait for input. Every later turn end triggers the Stop hook, which re-feeds the same prompt until N iterations complete, the promise fires, or the state file is deleted.

## Operational notes

- Cancel: run /cancel-jeffy (or delete `.claude/jeffy-loop.local.md`).
- Permission prompts pause the loop. Unattended runs need test and file tools allowlisted, or acceptEdits mode. Never allowlist push or force operations for a loop.
- A user message sent mid-loop gets answered and then the Stop hook re-feeds the iteration prompt, so a side question flows straight into the next iteration. The turn it consumed counts against the iteration budget, because the budget counts turns.
- Prefer several small runs over one large budget. The hook re-feeds the same session, so context accumulates across iterations within a run; the state files persist between runs and convergence is sticky, so two runs of 5 beat one run of 10. The clean context is the whole point, and it only arrives with a new session: relaunching /jeffy in the session that just finished a run keeps every accumulated token and forfeits the benefit entirely. Close the session and start a new one in the same directory; the state files on disk carry the run forward, nothing is lost.
- Edit PLAN.md or BACKLOG.md between iterations, not while one is running: a mid-iteration edit can collide with the loop's own in-flight edit. The Proposed section of BACKLOG.md is the designed channel for decisions.
- Checkpoints: every iteration ends in a local commit prefixed jeffy:. Review a run with git log --oneline, revert a bad iteration by reverting its checkpoint, and squash the run into one commit if you want tidy history. Nothing is ever pushed.
- One Jeffy loop per project at a time. The state file is transient; a crashed or closed session can leave it behind, which pre-flight check 4 handles. Orphans can also hide in subdirectories if a session was ever started there; they are inert for the hook, which anchors at the project root, but confuse relative-path checks, so always inspect state files with absolute paths.
- Git hygiene: `.claude/jeffy-loop.local.md` is transient, session-scoped state that must never be committed. Bootstrap appends it to the target project's `.gitignore` automatically, because the checkpoint's git add -A would otherwise sweep it in. The three state files (PLAN.md, BACKLOG.md, JOURNAL.md) are meant to persist between runs and are committed by the checkpoints; that is intentional, they are the loop's memory.
- If a loop ever dies silently mid-run (turn ends, no re-feed, state file frozen at its last iteration), the likely causes are: the hook was installed or registered after this session started (start a fresh session and relaunch); or the jeffy skills folder was moved or removed, so the state file's prompt_path went stale - the hook then ends the loop with a message to stderr, and re-running /jeffy relaunches with the new path.
- When a run ends, the loop closes with a run report; JOURNAL.md and the checkpoint commits in git log hold the full record.
