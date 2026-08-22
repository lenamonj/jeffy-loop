# Security Policy

## Supported versions

| Version | Supported |
| ------- | --------- |
| 1.x     | Yes       |

## Threat model

Jeffy Loop is deliberately small and auditable:

- The entire engine is one shell script in this repo, `skills/jeffy/hooks/stop-hook.sh`, plus the small library it sources from `skills/jeffy/hooks/lib/` (the verify wrapper and the sandbox detector), registered as a Claude Code Stop hook. It fires at turn end but exits instantly unless the current project has a live Jeffy state file naming that session - zero cost and zero behavior outside a run.
- The installer's only writes outside the cloned repo are the two skill folders it copies into `~/.claude/skills` (engine included), one hook registration in `~/.claude/settings.json`, and - only when jq is missing and the user answers yes to its prompt - a jq install through the system package manager (winget, Homebrew, or apt).
- The hook and skills make no network calls. The loop drives local CLIs only (`git`, `jq`, and whatever your project's own verify command runs).
- A run never pushes, never creates branches, and never widens its own operating envelope: envelope changes require your approval through the Proposed section of `BACKLOG.md`.
- The convergence declaration is machine-checked in shell: at the converged stop the hook itself verifies a task ledger that is present with zero open High and zero open Medium tasks - an open Low is carried and named, and a task line with no parseable severity blocks because the floor fails closed - a Converged line whose commit is reachable from HEAD and still certifies the current tree, no unswept row in the surface inventory, a verify command that has declared what it grades and which test targets this platform excludes, an evaluator PASS recorded in the run's closing journal entry and backed by the gate's own artifact - `.jeffy/evaluator/<run-id>-<n>.md`, one path per invocation so no history rewrite can reduce a run's verdicts to the last one, naming every command it ran and each command's real exit status, required committed and unmodified at the highest ordinal on record - and a green project verify command re-run under a timeout, before the run may end. A Converged hash that merely resolves is not enough: an orphan left by a rebase resolves, and a receipt whose commit no clone can reach is one nobody can check. A history rewrite that preserved the tree is answered by appending a repoint line naming both hashes, accepted only when the two commits carry the same tree. A recorded `Evaluator: unavailable` does not converge the run; it ends blocked, and the declaration waits for a session where the sub-agent can be spawned. Per-iteration discipline is checked the same way: a mid-budget re-feed carries an evidence note when the finished iteration skipped its journal entry, left tracked changes uncommitted, desynced the iteration counter against the journal, or shrank the append-only journal archive, and two consecutive iterations that change nothing outside the loop's own files end the run as stalled - a checkpoint commit alone is not progress, and the convergence-sequence iterations (a closeout audit, the evaluator gate, a ratchet, a wrapup) and an iteration honestly recorded blocked are exempt from the strike, capped at three in a row. One mechanical exception is on the record too: when the budget expires with zero open High and zero open Medium and the surface swept - carried Lows included, since an accurately scored Low never blocks a declaration - the hook grants a single +2-iteration closing extension, once per run, so the convergence sequence can finish - and a backstop closes it, ending the run the moment non-evaluator work above Low refills the ledger inside that window or an audit runs there, because the extension buys the convergence sequence - the gate, its one-transaction fixes, the declaration - and never a further round of work, and never the clean audit a declaration cites. The verify command is checked before it is trusted: a pipeline whose last stage is a pager or truncator (`cat`, `head`, `less`, `more`, `tail`) is refused at launch and again at the gate, since such a pipeline reports the truncator's exit status and a red suite would read as green. The gate is never skipped for want of a timeout binary: the hook uses `timeout`, else `gtimeout`, else a shell watchdog, so a host with no GNU coreutils - a stock macOS - runs the same bounded check as any other. Discipline violations re-feed the loop with the evidence, and a violation that lands once the budget is already spent buys a single corrective re-feed, so the run is directed to record the refusal and close without claiming convergence instead of the refusal reaching stderr alone. That grant has a stated bound rather than an implied absolute: where a closing-extension gate has already ended the run for its own reason - an audit inside the window, or the ledger refilling there - that gate wins and the refusal is not re-fed. Infrastructure defects that leave a check with nothing to read (no `PLAN.md`, no progress signal at all) fail open with a stderr diagnostic; a missing task ledger or journal does not, because every convergence gate reads them and accepting the promise without them would be accepting it unchecked.
- Loop state is three plain-text files at your project root plus one transient session-scoped state file that is gitignored and deleted when the run ends.

If a behavior you observe contradicts any line above, treat it as a security bug and report it.

## Reporting a vulnerability

Use GitHub Private Vulnerability Reporting: the Security tab of this repository, then "Report a vulnerability". If that is unavailable to you, email lenamonj@yahoo.com with the details.

You will get an acknowledgment within 48 hours. Please include the OS, the Claude Code version, and the relevant `JOURNAL.md` excerpt or hook output when applicable.

## Scope

In scope: both installers, the Stop hook, the skill prompts under `skills/`, and `scripts/validate.sh`.

Out of scope: Claude Code itself and model behavior - report those to Anthropic through https://www.anthropic.com/responsible-disclosure-policy.

## Blast radius

Jeffy runs unattended, usually over a repository you did not write, and an
unattended agent is usually given relaxed permissions so it does not stop to
ask. Once they are relaxed, the sandbox is the only boundary left, and what
sits outside it is everything the shell can reach: credentials, SSH keys,
browser cookies, access tokens, every other repository on the disk.

This is not a hypothetical for this project. Its own receipts describe
cloning strangers' repositories and running an autonomous loop across them,
and the corpus is now 38 targets deep.

The engine's answer is a statement rather than a restriction. At launch it
runs `skills/jeffy/hooks/lib/detect-sandbox.sh`, records `sandboxed:
yes|no|unknown` in the run state, and prints one line naming the blast radius
when the answer is `no`. It does not block, prompt, or refuse. A loop that
narrowed the operator's mandate would be making a decision that is not its
to make; what it owes is that the decision is made knowingly.

What actually reduces the radius, in the order they cost you something:

- **Run the session inside a container** that mounts the target repository
  and nothing else, and forwards only the credential the CLI needs. Jeffy is
  a slash command inside a session, so the container wraps the session rather
  than the other way round: start it first, then run `/jeffy` inside.
  `--network none` is not viable for the session itself, because the model
  API is reached over the network.
- **Keep the allowlist narrow.** Allowlist the project's own test and file
  tools; never allowlist push or force operations. The engine never pushes
  and never creates branches, so nothing it does needs them.
- **Give it its own checkout.** The loop commits every iteration and reverts
  its own breakage against those commits; a scratch clone costs nothing and
  bounds what a bad iteration can reach.

`JEFFY_SANDBOXED=1` declares a boundary the probe cannot see - a VM, a jail,
a locked-down user - and is taken at its word.
