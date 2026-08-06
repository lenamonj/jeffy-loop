# Security Policy

## Supported versions

| Version | Supported |
| ------- | --------- |
| 1.x     | Yes       |

## Threat model

Jeffy Loop is deliberately small and auditable:

- The entire engine is one shell script in this repo, `skills/jeffy/hooks/stop-hook.sh`, registered as a Claude Code Stop hook. It fires at turn end but exits instantly unless the current project has a live Jeffy state file naming that session - zero cost and zero behavior outside a run.
- The installer's only writes outside the cloned repo are the two skill folders it copies into `~/.claude/skills` (engine included), one hook registration in `~/.claude/settings.json`, and - only when jq is missing and the user answers yes to its prompt - a jq install through the system package manager (winget, Homebrew, or apt).
- The hook and skills make no network calls. The loop drives local CLIs only (`git`, `jq`, and whatever your project's own verify command runs).
- A run never pushes, never creates branches, and never widens its own operating envelope: envelope changes require your approval through the Proposed section of `BACKLOG.md`.
- The convergence declaration is machine-checked in shell: at the converged stop the hook itself verifies an empty task ledger, a Converged line certifying the current tree, no unswept row in the surface inventory, an evaluator PASS recorded in the run's closing journal entry and backed by the gate's own artifact - `.jeffy/evaluator/<run-id>.md`, naming every command it ran and each command's real exit status, required committed and unmodified - and a green project verify command re-run under a timeout, before the run may end. A recorded `Evaluator: unavailable` does not converge the run; it ends blocked, and the declaration waits for a session where the sub-agent can be spawned. Per-iteration discipline is checked the same way: a mid-budget re-feed carries an evidence note when the finished iteration skipped its journal entry, left tracked changes uncommitted, desynced the iteration counter against the journal, or shrank the append-only journal archive, and two consecutive iterations that change nothing outside the loop's own files end the run as stalled - a checkpoint commit alone is not progress, and the convergence-sequence iterations (a closeout audit, the evaluator gate, a ratchet, a wrapup) are exempt from the strike, capped at three in a row. One mechanical exception is on the record too: when the budget expires with the ledger empty and the surface swept, the hook grants a single +2-iteration closing extension, once per run, so the convergence sequence can finish - and a backstop closes it, ending the run the moment non-evaluator work refills the ledger inside that window or an audit runs there, because the extension buys the convergence sequence - the gate, its one-transaction fixes, the declaration - and never a further round of work, and never the clean audit a declaration cites. The verify command is checked before it is trusted: a pipeline whose last stage is a truncator (`head`, `tail`) is refused at launch and again at the gate, since such a pipeline reports the truncator's exit status and a red suite would read as green. The gate is never skipped for want of a timeout binary: the hook uses `timeout`, else `gtimeout`, else a shell watchdog, so a host with no GNU coreutils - a stock macOS - runs the same bounded check as any other. Discipline violations re-feed the loop with the evidence; infrastructure defects (missing ledger, journal, or plan, no progress signal at all) fail open with a stderr diagnostic.
- Loop state is three plain-text files at your project root plus one transient session-scoped state file that is gitignored and deleted when the run ends.

If a behavior you observe contradicts any line above, treat it as a security bug and report it.

## Reporting a vulnerability

Use GitHub Private Vulnerability Reporting: the Security tab of this repository, then "Report a vulnerability". If that is unavailable to you, email lenamonj@yahoo.com with the details.

You will get an acknowledgment within 48 hours. Please include the OS, the Claude Code version, and the relevant `JOURNAL.md` excerpt or hook output when applicable.

## Scope

In scope: both installers, the Stop hook, the skill prompts under `skills/`, and `scripts/validate.sh`.

Out of scope: Claude Code itself and model behavior - report those to Anthropic through https://www.anthropic.com/responsible-disclosure-policy.
