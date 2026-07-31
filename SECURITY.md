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
- The convergence declaration is machine-checked in shell: at the converged stop the hook itself verifies an empty task ledger, a Converged line certifying the current tree, no unswept row in the surface inventory, an evaluator verdict recorded in the run's closing journal entry, and a green project verify command re-run under a timeout, before the run may end. Per-iteration discipline is checked the same way: a mid-budget re-feed carries an evidence note when the finished iteration skipped its journal entry, left tracked changes uncommitted, desynced the iteration counter against the journal, or shrank the append-only journal archive, and two consecutive iterations with no commit and no ledger change end the run as stalled. One mechanical exception is on the record too: when the budget expires with the ledger empty and the surface swept, the hook grants a single +2-iteration closing extension, once per run, so the convergence sequence can finish. Discipline violations re-feed the loop with the evidence; infrastructure defects (missing ledger, journal, or plan, no timeout binary, no progress signal at all) fail open with a stderr diagnostic.
- Loop state is three plain-text files at your project root plus one transient session-scoped state file that is gitignored and deleted when the run ends.

If a behavior you observe contradicts any line above, treat it as a security bug and report it.

## Reporting a vulnerability

Use GitHub Private Vulnerability Reporting: the Security tab of this repository, then "Report a vulnerability". If that is unavailable to you, email lenamonj@yahoo.com with the details.

You will get an acknowledgment within 48 hours. Please include the OS, the Claude Code version, and the relevant `JOURNAL.md` excerpt or hook output when applicable.

## Scope

In scope: both installers, the Stop hook, the skill prompts under `skills/`, and `scripts/validate.sh`.

Out of scope: Claude Code itself and model behavior - report those to Anthropic through https://www.anthropic.com/responsible-disclosure-policy.
