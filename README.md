<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="media/banner-dark.png">
  <img src="media/banner-light.png" alt="Jeffy Loop - point it at a project, give it a budget, come back to a better codebase and a report" width="900">
</picture>

[![Validate](https://img.shields.io/github/actions/workflow/status/lenamonj/jeffy-loop/validate.yml?style=for-the-badge&label=validate&logo=githubactions&logoColor=white)](https://github.com/lenamonj/jeffy-loop/actions/workflows/validate.yml)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Skill-D97757?style=for-the-badge&logo=claude&logoColor=white)](https://claude.com/claude-code)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Mac%20%7C%20Linux-0EA5E9?style=for-the-badge)
[![License: MIT](https://img.shields.io/badge/License-MIT-22C55E?style=for-the-badge)](LICENSE)

**[Quickstart](#quickstart)** &nbsp;·&nbsp; **[Usage](docs/usage.md)** &nbsp;·&nbsp; **[How it works](docs/how-it-works.md)** &nbsp;·&nbsp; **[The receipts](evals/README.md)** &nbsp;·&nbsp; **[Headless](docs/headless.md)** &nbsp;·&nbsp; **[White paper](https://github.com/lenamonj/jeffy-loop/raw/main/The-Jeffy-Loop.pdf)**

## Autonomous Engineering With Proof

> **Agents that don’t just act.**  
> They audit · verify · attack · and prove.

</div>

Jeffy Loop is an autonomous engineering system built around a simple principle: **AI agents shouldn’t just produce work. They should produce evidence that the work is correct.** Instead of asking an agent to complete a task and trusting its conclusion, Jeffy creates a continuous **Audit → Attack → Verify → Prove** loop in which specialized agents inspect the work, challenge it, validate the result, and generate an auditable record of what happened. The goal isn’t simply autonomous code generation; it is **autonomous engineering with proof** - where every claimed result is accompanied by reproducible evidence that can be independently examined.

**Jeffy treats “done” as something that must be demonstrated, not declared.** The system is designed to turn autonomous engineering from a conversational interaction into an evidence-producing process: actions leave traces, decisions have provenance, failures are exposed rather than hidden, and successful outcomes produce a durable receipt of what was changed, why it was changed, and how the result was verified.

<div align="center">
  <img src="media/jeffy-loop-architecture.jpg" alt="Jeffy Loop Architecture" width="900">
</div>

## The proof

Jeffy was run against widely-used open-source projects with no connection to this repository, each project's own test suite as the oracle, and every run published in full.

| Projects tested | Fixed | Failed to converge | PRs opened | PRs merged | Issues filed |
|:---:|:---:|:---:|:---:|:---:|:---:|
| **<!-- count:tested -->129<!-- /count -->** | **<!-- count:fixed -->101<!-- /count -->** | **<!-- count:failed -->28<!-- /count -->** | **<!-- count:prs -->57<!-- /count -->** | **<!-- count:merged -->18<!-- /count -->** | **<!-- count:issues -->4<!-- /count -->** |

**<!-- count:converged -->100<!-- /count --> projects run to convergence across <!-- count:languages -->13<!-- /count --> languages** with no language-specific analyzer or ruleset. Of the <!-- count:tested -->129<!-- /count --> projects, <!-- count:failed -->28<!-- /count --> never converged. Counted per attempt rather than per project, the ledger holds **34 attempts that did not converge**: every budgeted retry of those 28, plus the first attempt at each project that converged only on a retry. Each one is published with the budget it was given before it started and the reason it ran out. Three greenfield builds converged from empty directories under judges the loop could not edit.

A merged pull request is the one outcome the loop cannot award itself. Fifteen projects have merged its patches; four of them:

- **Apple, [swift-log](https://github.com/apple/swift-log/pull/504)** - the attributes setter documented a no-op and asserted instead; merged by the maintainer after he asked for the doc-only form.
- **Microsoft, [mimalloc](https://github.com/microsoft/mimalloc/pull/1385)** - a documented zeroing allocator returned uninitialized heap memory above the small-size threshold; merged by the library's author the same day.
- **Node.js, [ada](https://github.com/ada-url/ada/pull/1244)** - the URL parser inside Node.js reported `host_end` one byte short and truncated the host; merged twelve minutes after filing.
- **JetBrains, [kotlinx-datetime](https://github.com/Kotlin/kotlinx-datetime/pull/650)** - deprecation quick-fixes pointed developers at the wrong replacement; merged within two hours.

**[The full scorecard, every merged patch, and every failure](evals/README.md)**, or the [record of every attempt ever started](evals/ATTEMPTS.md).

## Five guarantees

Each one is enforced by the iteration prompt, the state files, or the Stop hook, and each is checkable in this repository. [How they are enforced.](docs/how-it-works.md#five-guarantees)

1. **It audits like an engineer, not a linter.** Every run opens with a real audit; a finding exists only if the loop can point at it and prove it with a runnable check.
2. **It cannot wreck your repo.** Every iteration ends in a local checkpoint commit, a verify gate reverts any iteration that breaks the project, and nothing is pushed.
3. **"Done" is not the agent's opinion.** A declaration needs a clean audit, a fully swept surface inventory, and an adversarial evaluator's countersignature, all re-checked in shell.
4. **It cannot claim what it never looked at.** The whole public surface goes on a checklist before any finding is filed, and a swept row reopens when its code changes.
5. **Lessons become machinery.** A rule learned the hard way binds every iteration after it; the engine itself is held to <!-- count:checks -->**312 behavioural checks**<!-- /count --> on Linux, Windows and macOS.

## Quickstart

You need exactly two things. The installer handles everything else, including `jq`.

1. **[Claude Code](https://claude.com/claude-code)** - installed and signed in once
2. **[git](https://git-scm.com/downloads)** - confirm with `git --version`; otherwise `winget install Git.Git`, `brew install git`, or `sudo apt-get install git`

Install Jeffy:

```bash
git clone https://github.com/lenamonj/jeffy-loop.git
cd jeffy-loop
./install.sh        # Windows PowerShell: .\install.ps1
```

> [!NOTE]
> If PowerShell blocks the installer with "running scripts is disabled on this system", run it once with `powershell -ExecutionPolicy Bypass -File .\install.ps1` - the bypass applies to that single invocation only.

The installer verifies the Claude Code CLI and `jq` (offering to install it via winget, Homebrew, or apt), copies the `/jeffy` and `/cancel-jeffy` skills - engine included - to `~/.claude/skills`, and registers the loop's hook in `~/.claude/settings.json`. Every step prints an [OK] or the exact fix.

Then open Claude Code in the project you want to improve and type `/jeffy 10`.

> [!TIP]
> `/jeffy` is a slash command inside the Claude Code session, not a shell command.

When that run ends, close the session and start a new one to run it again. That restart is doing real work, and [why is worth two minutes](docs/usage.md#use-several-short-runs-not-one-long-one).

## Documentation

| Page | What it covers |
|:---|:---|
| [Usage](docs/usage.md) | Flags, rounds and budgets, scoped mode, cancelling, [upgrading](docs/usage.md#already-installed-upgrade), uninstalling, and what to know before a first run |
| [How it works](docs/how-it-works.md) | The run lifecycle, the five guarantees, the full rule set, what a converged stop looks like, and how the loop improves itself |
| [Headless runs](docs/headless.md) | Running budgeted rounds unattended from bash or PowerShell |
| [The receipts](evals/README.md) | Every open-source target with its outcome, the merged patches, the greenfield builds |
| [Contributing](CONTRIBUTING.md) | The validator and the review bar |
| [White paper](https://github.com/lenamonj/jeffy-loop/raw/main/The-Jeffy-Loop.pdf) | 32 pages for readers new to agent loops: how loops got here, every rule from first principles, and what this method still cannot do |

> [!IMPORTANT]
> **Trust model.** The entire engine is one auditable shell script in this repo (`skills/jeffy/hooks/stop-hook.sh`) plus the small library it sources from `skills/jeffy/hooks/lib/`, registered as a Claude Code Stop hook. It fires at turn end but exits instantly unless the current project has a live Jeffy state file naming that session - zero cost and zero behavior outside a run. The installer's only writes outside this repo are the two skill folders it copies into `~/.claude/skills` (engine included), that one hook registration in `~/.claude/settings.json`, and - only when jq is missing and you answer yes to its prompt - a jq install through your system package manager (winget, Homebrew, or apt).

## License

MIT
