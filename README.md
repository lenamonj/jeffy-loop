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

## The receipts

Every target, the merged patches and the greenfield builds: **[evals/README.md](evals/README.md)**.

Behind them: **<!-- count:converged -->96<!-- /count --> open-source projects run to convergence across <!-- count:languages -->13<!-- /count --> languages**, every run published in full - and **34 attempts that did not converge**, each with the budget it was given before it started and the reason it ran out. Three greenfield builds converged from empty directories under judges the loop could not edit, one of them against a deliberately mutated specification where recalling the real format produces wrong answers.

**[Read the receipts table](evals/README.md)**, or the [full record of every attempt ever started](evals/ATTEMPTS.md).

New to autonomous agent loops, or want the full argument? **The Jeffy Loop** is a 32-page white paper written for readers with no prior knowledge of agents: how loops got here from ReAct to AutoGPT to the Ralph Loop, what Anthropic recommends and what that guidance leaves open, then every rule explained from first principles - including an honest account of what this method still cannot do. It cites 28 sources, all linked. **[Download it here.](https://github.com/lenamonj/jeffy-loop/raw/main/The-Jeffy-Loop.pdf)**

## Quickstart

You need exactly two things. The installer handles everything else, including `jq`.

1. **[Claude Code](https://claude.com/claude-code)** - installed and signed in once
2. **[git](https://git-scm.com/downloads)** - confirm with `git --version`

No git yet? One command for your platform:

**Windows**

```powershell
winget install Git.Git
```

**macOS**

```bash
brew install git
```

**Debian/Ubuntu**

```bash
sudo apt-get install git
```

Install Jeffy:

```bash
git clone https://github.com/lenamonj/jeffy-loop.git
cd jeffy-loop
./install.sh        # Windows PowerShell: .\install.ps1
```

> [!NOTE]
> If PowerShell blocks the installer with "running scripts is disabled on this system", run it once with `powershell -ExecutionPolicy Bypass -File .\install.ps1` - the bypass applies to that single invocation only.

The installer verifies the Claude Code CLI and `jq` (offering to install it via winget, Homebrew, or apt), copies the `/jeffy` and `/cancel-jeffy` skills - engine included - to `~/.claude/skills`, and registers the loop's hook in `~/.claude/settings.json`. Every step prints an [OK] or the exact fix.

- **Update** - see [Already installed? Upgrade](docs/usage.md#already-installed-upgrade) below.

Then open Claude Code in the project you want to improve and type `/jeffy 10`.

> [!TIP]
> `/jeffy` is a slash command inside the Claude Code session, not a shell command.

When that run ends, close the session and start a new one to run it again. That restart is doing real work, and [why is worth two minutes](docs/usage.md#use-several-short-runs-not-one-long-one).

## Usage

Flags, rounds and budgets, scoped mode, cancelling, upgrading: **[docs/usage.md](docs/usage.md)**.

## Headless runs

Budgeted rounds from bash or PowerShell, unattended: **[docs/headless.md](docs/headless.md)**.

## How it works

The run lifecycle, the five guarantees and the full rule set: **[docs/how-it-works.md](docs/how-it-works.md)**.

> [!IMPORTANT]
> **Trust model.** The entire engine is one auditable shell script in this repo (`skills/jeffy/hooks/stop-hook.sh`) plus the small library it sources from `skills/jeffy/hooks/lib/`, registered as a Claude Code Stop hook. It fires at turn end but exits instantly unless the current project has a live Jeffy state file naming that session - zero cost and zero behavior outside a run. The installer's only writes outside this repo are the two skill folders it copies into `~/.claude/skills` (engine included), that one hook registration in `~/.claude/settings.json`, and - only when jq is missing and you answer yes to its prompt - a jq install through your system package manager (winget, Homebrew, or apt).

## Contributing

See **[CONTRIBUTING.md](CONTRIBUTING.md)**.

## License

MIT
