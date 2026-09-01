<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="media/banner-dark.png">
  <img src="media/banner-light.png" alt="Jeffy Loop - point it at a project, give it a budget, come back to a better codebase and a report" width="900">
</picture>

[![Validate](https://img.shields.io/github/actions/workflow/status/lenamonj/jeffy-loop/validate.yml?style=for-the-badge&label=validate&logo=githubactions&logoColor=white)](https://github.com/lenamonj/jeffy-loop/actions/workflows/validate.yml)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Skill-D97757?style=for-the-badge&logo=claude&logoColor=white)](https://claude.com/claude-code)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Mac%20%7C%20Linux-0EA5E9?style=for-the-badge)
[![License: MIT](https://img.shields.io/badge/License-MIT-22C55E?style=for-the-badge)](LICENSE)

**[Quickstart](#quickstart)** &nbsp;·&nbsp; **[Usage](#usage)** &nbsp;·&nbsp; **[What makes it different](#what-makes-it-different)** &nbsp;·&nbsp; **[The receipts](#real-world-validation-on-open-source-repositories)** &nbsp;·&nbsp; **[How a run works](#how-a-run-works)** &nbsp;·&nbsp; **[White paper](https://github.com/lenamonj/jeffy-loop/raw/main/The-Jeffy-Loop.pdf)**

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

Eight fixes are in other people's code because a maintainer with no stake in this project reviewed them and said yes. Seven are patches this loop wrote and a maintainer merged; the eighth is a finding a maintainer found convincing enough to fix himself:

- **[bat](https://github.com/sharkdp/bat/pull/3862) - merged.** A just-merged security flag did nothing when piped; caught before it ever shipped.
- **[fasthttp](https://github.com/valyala/fasthttp/pull/2343) - merged.** A `Content-Length` no parser should accept became a wrong number.
- **[jsoncpp](https://github.com/open-source-parsers/jsoncpp/pull/1709) - merged.** The build the project documents for handling secrets had never compiled on MSVC, and the memory it promises to wipe was only partly wiped. Merged 2026-08-20.
- **[PapaParse](https://github.com/mholt/PapaParse/pull/1135) - merged.** Header de-duplication re-ran on every row after a resume, rewriting data in place: `"foo, bar"` came back as `"foo, bar_1"`. Merged 2026-08-24, shipped in PapaParse 5.7.0.
- **[mimalloc](https://github.com/microsoft/mimalloc/pull/1385) - merged.** `mi_theap_zalloc_csize` delegated its large-size branch to the plain malloc path, so a documented zeroing allocator returned uninitialized heap memory for every size above the small-size threshold. Merged 2026-08-31 by the library's author.
- **[ada](https://github.com/ada-url/ada/pull/1244) - merged.** `ada::url` reported `host_end` one byte short of the position its own documentation describes, so slicing `href` by `[host_start, host_end)` truncated the host; `ada::url_aggregator` disagreed with it on every URL with a host. Merged 2026-09-01, about forty minutes after it was opened. ada is the URL parser inside Node.js.
- **[nanoid](https://github.com/ai/nanoid/pull/609) - merged.** `customAlphabet` accepted alphabets it cannot sample from and hung forever in `while (true)`; the maintainer judged the runtime guard too expensive for the reachability and asked for a docs notice instead, which was reworked and merged the same day. Merged 2026-09-01.
- **[chalk](https://github.com/chalk/chalk/pull/687) - fixed upstream.** The maintainer reproduced the finding, then wrote and merged his own fix, shipped in v6.0.0.

One more is not a fix and is not counted as one: a **security finding this loop produced in [claude-code-action](evals/claude-code-action/REPORT.md) is open with Anthropic's own security program**, scored Low (2.3) on 2026-08-20. Their review is ongoing, so nothing here calls it accepted, and the details stay unpublished at their request until the report resolves.

Behind them: **<!-- count:converged -->73<!-- /count --> open-source projects run to convergence across <!-- count:languages -->13<!-- /count --> languages**, every run published in full - and **33 attempts that did not converge**, each with the budget it was given before it started and the reason it ran out. Three greenfield builds converged from empty directories under judges the loop could not edit, one of them against a deliberately mutated specification where recalling the real format produces wrong answers.

**[Read the receipts table](#real-world-validation-on-open-source-repositories)**, or the [full record of every attempt ever started](evals/ATTEMPTS.md).

New to autonomous agent loops, or want the full argument? **The Jeffy Loop** is a 32-page white paper written for readers with no prior knowledge of agents: how loops got here from ReAct to AutoGPT to the Ralph Loop, what Anthropic recommends and what that guidance leaves open, then every rule explained from first principles - including an honest account of what this method still cannot do. It cites 28 sources, all linked. **[Download it here.](https://github.com/lenamonj/jeffy-loop/raw/main/The-Jeffy-Loop.pdf)**

<div align="center">

![Jeffy Loop vs a raw prompt loop - the head-to-head](media/jeffy-vs-raw-loop.gif)

<sub>The head-to-head vs a raw prompt loop. Every row is a guarantee you can verify in the code: the engine is <code>skills/jeffy/hooks/stop-hook.sh</code>, the discipline is <code>skills/jeffy/references/iteration-prompt.txt</code>, and the receipts live under <a href="evals/"><code>evals/</code></a>.</sub>

</div>

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

- **Re-run** - always safe: it skips what is installed, upgrades in place, and never duplicates the hook registration.
- **Update** - see [Already installed? Upgrade](#already-installed-upgrade) below.
- **Uninstall** - delete `~/.claude/skills/jeffy` and `~/.claude/skills/cancel-jeffy`, and remove the hook entry from `~/.claude/settings.json`.

Then open Claude Code in the project you want to improve and type `/jeffy 10`.

> [!TIP]
> `/jeffy` is a slash command inside the Claude Code session, not a shell command.

When that run ends, close the session and start a new one to run it again. That restart is doing real work, and [why is worth two minutes](#use-several-short-runs-not-one-long-one).

### Already installed? Upgrade

Upgrading touches `~/.claude` and nothing else. No project you have run against is modified. Pull and re-install:

```bash
cd jeffy-loop && git pull
./install.sh        # Windows PowerShell: .\install.ps1
```

Then **start a new Claude Code session** - skills and hook registrations are read at session start, so an open session keeps running the old engine until you restart it. That is the whole upgrade. `/jeffy` names the engine version on its first line, so you will see the new one immediately.

Deleted the clone since installing? Clone it again and run the installer from there; it only ever reads from the clone.

> [!NOTE]
> Do not upgrade underneath a live run. The Stop hook is read from disk every time it fires, so replacing it mid-run changes that run's rules halfway through. Let the run finish, or stop it with `/cancel-jeffy` first.

> [!NOTE]
> The installer copies over the top and never deletes, so a file removed in a later version stays behind. For a clean slate, delete `~/.claude/skills/jeffy` and `~/.claude/skills/cancel-jeffy` before re-running it - the installer puts both back.

## Usage

```
/jeffy [N] [focus...] [--max-time <45m|2h|900s>] [--max-iter-time <20m>] [--max-context <4>]
```

- `--max-context` - optional context-pressure advisory, **off by default**. The engine re-feeds one session, so context accumulates within a run; past N times the transcript's size at the run's first iteration, the loop is advised to finish its current task and close so the next run reads the state files with a clean window. It advises and never stops: the closing rule governs and a declared budget is never cut short. Measured from the transcript rather than counted in iterations, and reported every iteration whether a threshold is set or not.
- `--max-time` / `--max-iter-time` - optional time ceilings, **off by default**. A turn budget counts turns and a turn is unbounded in time, so these bound the run in hours instead: `--max-time` ends the run out of time the way exhaustion ends it out of turns, and `--max-iter-time` draws a note on a long iteration, ending the run after two consecutive ones. Neither can cut a turn short (the hook fires at turn end) and neither preempts a closing extension or a converged declaration. They default to off rather than to a number nobody measured; for reference, rounds of ten iterations in the receipts below run roughly 60 to 130 minutes. Elapsed wall time is reported every iteration either way.
- `N` - iteration budget, default 10. Sizing is low-stakes in both directions: the loop ends itself at convergence, so unused budget costs nothing, and a budget that runs dry loses no work - the next `/jeffy` picks up where the run stopped. The floor for converging in one run is the opening audit, one iteration per expected finding, and a closing audit; when that arithmetic outgrows the default, prefer a second run over a bigger number (see [Good to know](#good-to-know)).
- `focus` - optional directive for the run, e.g. `/jeffy 8 test coverage and error handling`.

```
/jeffy                                     # 10 iterations, full-spectrum improvement
/jeffy 5                                   # 5 iterations
/jeffy 12 accessibility and performance    # 12 iterations with a focus directive
/jeffy 15                                  # one round of 15 - the loose budget for a wide surface
/jeffy 10 --max-time 2h                    # 10 iterations, but stop after two hours either way
```

A **round** is one `/jeffy` invocation; a **budget** is rounds times iterations. The receipts below were mostly run as 3 rounds of 10, declared before launch: `/jeffy 10`, a new session, `/jeffy 10` again, a third time if the second did not converge. The loop ends itself at convergence, so a declared spare round costs nothing when it is not needed. To run rounds without typing them, see [How to run Jeffy fully autonomously with bash](#how-to-run-jeffy-fully-autonomously-with-bash).

**Scoped mode.** By default `/jeffy` runs in Improvement mode: an open-ended audit-and-fix loop. To run it against a concrete target instead, edit `PLAN.md` - replace the Goal and Definition of done with the target, seed `BACKLOG.md` with the finite tasks, then run `/jeffy`. Everything else (envelope, verify gate, checkpoints, journal, report) behaves the same.

**Cancel.** Run `/cancel-jeffy`. It reports which loop it found, deletes the loop state file, and leaves `PLAN.md`, `BACKLOG.md`, and `JOURNAL.md` untouched, so the next `/jeffy` picks up exactly where it left off. (Equivalent manual action: delete `.claude/jeffy-loop.local.md` at the project root.)

## How to run Jeffy fully autonomously with bash

`/jeffy` is a slash command, but Claude Code can take one from the shell: `claude -p "/jeffy 10"` runs a full round headless and exits when the round ends. Every receipt from `ryu` onward was produced that way, unattended, with a shell loop supplying the rounds. Nothing in the engine changes; the loop cannot tell whether a person typed the command.

**Setup, once.**

1. Install Jeffy as in the [Quickstart](#quickstart) and sign in to Claude Code once interactively (`claude` then `/login`); the headless form reuses that session.
2. Clone the target and make sure the tree is clean and on a branch you are willing to see commits on. The loop checkpoints every iteration as a commit, and its pre-flight asks what to do about uncommitted work - a question a headless session never answers, so the round ends with nothing done.
3. Decide the budget before the first round and write it down: rounds and iterations per round. Below 10 iterations a round rarely reaches its own gate; narrow single-purpose libraries in the receipts converged in 10 to 20 iterations, wide surfaces (30+ inventory rows) took 40 or more.
4. Pass `--permission-mode bypassPermissions`. A headless session has nobody to answer a permission prompt, so without it the round stalls silently at the first tool call.

Two targets from the receipts, at the pins they were run at:

```bash
git clone https://github.com/dtolnay/itoa.git   ~/targets/itoa     # Rust,  converged in 2 rounds of 10
git clone https://github.com/ljharb/qs.git       ~/targets/qs       # JavaScript, 3 rounds of 10 declared
```

**Linux / macOS / WSL**

```bash
#!/usr/bin/env bash
# Run ROUNDS rounds of ITERS iterations against TARGET; stop early at convergence.
set -euo pipefail
TARGET=~/targets/itoa
ROUNDS=3
ITERS=10

cd "$TARGET"
for r in $(seq 1 "$ROUNDS"); do
  before=$(git rev-parse HEAD)
  claude -p "/jeffy $ITERS" --permission-mode bypassPermissions >> jeffy-run.log 2>&1
  # A round that made no checkpoint commit almost always hit a pre-flight
  # question nobody answered. Stop rather than burn the remaining rounds.
  [ "$before" != "$(git rev-parse HEAD)" ] || { echo "round $r: no progress, stopping"; exit 1; }
  grep -q '^Converged:' BACKLOG.md && { echo "converged in round $r"; exit 0; }
done
echo "budget spent: $ROUNDS rounds of $ITERS, not converged"
```

Two rounds of 15 instead: `ROUNDS=2 ITERS=15`. A single `/jeffy 10` is `ROUNDS=1`. To leave it running after you log out, put the script under `nohup`, `setsid -f`, or a `systemd-run --user` unit; the receipts used the last, with a memory ceiling so a runaway test binary cannot take the host with it.

**Windows PowerShell**

```powershell
# Run $Rounds rounds of $Iters iterations against $Target; stop early at convergence.
$Target = "$HOME\targets\itoa"
$Rounds = 3
$Iters  = 10

Set-Location $Target
for ($r = 1; $r -le $Rounds; $r++) {
    $before = git rev-parse HEAD
    claude -p "/jeffy $Iters" --permission-mode bypassPermissions 2>&1 | Add-Content jeffy-run.log
    if ($before -eq (git rev-parse HEAD)) { Write-Host "round $r: no progress, stopping"; exit 1 }
    if (Select-String -Path BACKLOG.md -Pattern '^Converged:' -Quiet) { Write-Host "converged in round $r"; exit 0 }
}
Write-Host "budget spent: $Rounds rounds of $Iters, not converged"
```

**What to read afterwards.** `JOURNAL.md` has one entry per iteration; `BACKLOG.md` ends with a `Converged:` line naming the commit if the run declared, and holds the open findings if it did not; `.jeffy/evaluator/` holds every gate verdict with the commands it ran. The log file is the raw session transcript and is only interesting when a round made no progress.

> [!NOTE]
> Rounds are separate sessions on purpose. Each new session re-reads the tree cold, which is what makes the second round's audit independent of the first round's beliefs. [Why that matters](#use-several-short-runs-not-one-long-one).

## What makes it different

Five guarantees. Each one is enforced by the iteration prompt, the state files, or the Stop hook, and each is checkable in this repository.

**It audits like an engineer, not a linter.** Every run opens with a real audit across architecture, correctness, security, testing, performance and more. Every finding becomes a task with a runnable acceptance check, and a finding exists only if the loop can point at it.

**It cannot wreck your repo.** Every iteration ends in a local checkpoint commit, and a verify gate reverts any iteration that breaks the project. Nothing is pushed, no branches are created.

**"Done" is not the agent's opinion.** A declaration needs a fresh audit finding zero High and zero Medium, a fully swept surface inventory, and an adversarial evaluator's countersignature. Then a plain shell script re-checks all of it, re-runs your test suite, and refuses the stop if anything fails.

**It cannot claim what it never looked at.** The whole public surface goes on a checklist before any finding is filed, each swept row records the commit it certified, and a row reopens when its code changes. "No findings" can never mean "nowhere looked".

**Lessons become machinery.** A rule learned the hard way binds every iteration after it, and a rule that has to be written twice gets promoted into a mechanism. The engine itself is held to <!-- count:checks -->**312 behavioural checks**<!-- /count --> on Linux, Windows and macOS, each one added because something went wrong once.

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

<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="media/language-pie-dark.png">
  <img src="media/language-pie-light.png" alt="Pie chart of the 62 converged public targets by language: Python 14 at 22.6 percent, Go 10 at 16.1 percent, Rust 8 at 12.9 percent, JavaScript 7 at 11.3 percent, C++ 5 at 8.1 percent, TypeScript 4 at 6.5 percent, C 3 at 4.8 percent, Ruby 3 at 4.8 percent, C# 2 at 3.2 percent, Java 2 at 3.2 percent, PHP 2 at 3.2 percent, Kotlin 1 at 1.6 percent, Swift 1 at 1.6 percent." width="900">
</picture>

<sub>Every converged public target, by the language it was written in. Counts are derived from the receipts table below at render time by <a href="scripts/render-language-pie.py"><code>scripts/render-language-pie.py</code></a>, largest slice first, ties alphabetical. Chart source: <a href="media/language-pie.html"><code>media/language-pie.html</code></a>.</sub>

</div>

## Real-World Validation on Open-Source Repositories

Empirical evidence of how an autonomous coding agent performs on real software: Jeffy was run against widely-used open-source projects with no connection to this repository, with each project's own test suite as the oracle. The engine ships no language-specific analyzer, ruleset or plugin, so the same method carried across <!-- count:languages -->13<!-- /count --> languages. Every run used a local clone, and nothing went upstream without a filed issue or PR.

| Projects tested | Fixed | Failed to converge | PRs opened | PRs merged | Issues filed |
|:---:|:---:|:---:|:---:|:---:|:---:|
| **<!-- count:tested -->101<!-- /count -->** | **<!-- count:fixed -->74<!-- /count -->** | **<!-- count:failed -->27<!-- /count -->** | **<!-- count:prs -->19<!-- /count -->** | **<!-- count:merged -->7<!-- /count -->** | **<!-- count:issues -->4<!-- /count -->** |

**Fixed** means the loop's closing audit came back clean and an independent evaluator countersigned it: <!-- count:converged -->73<!-- /count --> loop runs converged, plus one audit (PapaParse) held to the same method. That is a standard this repository set and checked itself. A merged pull request is the one outcome it cannot award itself, which is why those rows come first. **Failed** means the project's pre-registered run budget ran out without convergence; every one is published.

<sub>Ordered by upstream outcome, then by stars; failures last, alphabetically. Run-by-run detail for every project, including re-attempts, is in [evals/ATTEMPTS.md](evals/ATTEMPTS.md).</sub>

| Project | Language | Details | Jeffy Result |
|:---|:---|:---|:---|
| bat | Rust | [details](evals/bat/REPORT.md) - security flag no-op piped - [PR merged](https://github.com/sharkdp/bat/pull/3862) | Fixed |
| fasthttp | Go | [details](evals/fasthttp/REPORT.md) - bad Content-Length accepted - [PR merged](https://github.com/valyala/fasthttp/pull/2343) | Fixed |
| PapaParse | JavaScript | [details](evals/papaparse/REPORT.md) - *audit*; 4 Highs in streaming - [PR merged](https://github.com/mholt/PapaParse/pull/1135) | Fixed |
| jsoncpp | C++ | [details](evals/jsoncpp/REPORT.md) - secure build never compiled - [PR merged](https://github.com/open-source-parsers/jsoncpp/pull/1709) | Fixed |
| mimalloc | C | [details](evals/mimalloc/REPORT.md) - zalloc returned dirty memory - [PR merged](https://github.com/microsoft/mimalloc/pull/1385) | Fixed |
| ada | C++ | [details](evals/ada/REPORT.md) - host_end truncated the host - [PR merged](https://github.com/ada-url/ada/pull/1244) | Fixed |
| nanoid | JavaScript | [details](evals/nanoid/REPORT.md) - empty alphabet hung the generator - [PR merged](https://github.com/ai/nanoid/pull/609) | Fixed |
| chalk | JavaScript | [details](evals/chalk/REPORT.md) - maintainer wrote own fix - [fixed upstream](https://github.com/chalk/chalk/pull/687) | Fixed |
| dayjs | JavaScript | [details](evals/dayjs/REPORT.md) - 45 findings, 10 High - [PR open](https://github.com/iamkun/dayjs/pull/3167) | Fixed |
| yfinance | Python | [details](evals/yfinance/REPORT.md) - High its own test advertised - [PR open](https://github.com/ranaroussi/yfinance/pull/2927) | Fixed |
| typer | Python | [details](evals/typer/REPORT.md) - hash seed chose which app runs - [PR open](https://github.com/fastapi/typer/pull/1946) | Fixed |
| PHP-Parser | PHP | [details](evals/php-parser/REPORT.md) - test class ran no code - [PR open](https://github.com/nikic/PHP-Parser/pull/1162) | Fixed |
| python-dotenv | Python | [details](evals/python-dotenv/REPORT.md) - 8 runs, 48 findings - [PR open](https://github.com/theskumar/python-dotenv/pull/678) | Fixed |
| PyPortfolioOpt | Python | [details](evals/pyportfolioopt/REPORT.md) - CI-red to 356 passing - [PR open](https://github.com/PyPortfolio/PyPortfolioOpt/pull/751) | Fixed |
| go-yaml | Go | [details](evals/go-yaml/REPORT.md) - 20 findings, 6 High - [PR open](https://github.com/goccy/go-yaml/pull/915) | Fixed |
| rust-url | Rust | [details](evals/rust-url/REPORT.md) - 20 findings, 10 High - [PR open](https://github.com/servo/rust-url/pull/1147) | Fixed |
| rouge | Ruby | [details](evals/rouge/REPORT.md) - unknown theme crashed the CLI - [PR open](https://github.com/rouge-ruby/rouge/pull/2332) | Fixed |
| pflag | Go | [details](evals/pflag/REPORT.md) - deprecated flag field ignored - [PR open](https://github.com/spf13/pflag/pull/507) | Fixed |
| unicode-segmentation | Rust | [details](evals/unicode-segmentation/REPORT.md) - empty-string size_hint panic - [PR open](https://github.com/unicode-rs/unicode-segmentation/pull/181) | Fixed |
| classnames | JavaScript | [details](evals/classnames/REPORT.md) - null-prototype objects crashed all three modules - [PR open](https://github.com/JedWatson/classnames/pull/579) | Fixed |
| console | Rust | [details](evals/console/REPORT.md) - truncate_str panicked mid-character - [PR open](https://github.com/console-rs/console/pull/296) | Fixed |
| mustache.js | JavaScript | [details](evals/mustache.js/REPORT.md) - revived a dead suite - [issue filed](https://github.com/janl/mustache.js/issues/848) | Fixed |
| Spectre.Console | C# | [details](evals/spectre.console/REPORT.md) - panel header dropped - [issue filed](https://github.com/spectreconsole/spectre.console/issues/2184) | Fixed |
| quantstats | Python | [details](evals/quantstats/REPORT.md) - 29 findings behind green - [issue filed](https://github.com/ranaroussi/quantstats/issues/537) | Fixed |
| records | Python | [details](evals/records/REPORT.md) - 4 High data-loss bugs - [issue filed](https://github.com/kennethreitz/records/issues/236) | Fixed |
| cobra | Go | [details](evals/cobra/REPORT.md) - timezone-dependent build | Fixed |
| zod | TypeScript | [details](evals/zod/REPORT.md) - cyclic value validated | Fixed |
| commander.js | JavaScript | [details](evals/commander-js/REPORT.md) - error named wrong argument | Fixed |
| underscore | JavaScript | [details](evals/underscore/REPORT.md) - __proto__ prototype write | Fixed |
| gson | Java | [details](evals/gson/REPORT.md) - one audit, nothing changed | Fixed |
| rack | Ruby | [details](evals/rack/REPORT.md) - multipart limits off by one | Fixed |
| urfave/cli | Go | [details](evals/urfave-cli/REPORT.md) - a lone - ended flag parsing | Fixed |
| Catch2 | C++ | [details](evals/catch2/REPORT.md) - 18 findings, 6 High | Fixed |
| validator | Go | [details](evals/validator/REPORT.md) - cyclic struct killed process | Fixed |
| clap | Rust | [details](evals/clap/REPORT.md) - 35 rows over 4 runs | Fixed |
| uuid (JS) | JavaScript | [details](evals/js-uuid/REPORT.md) - crash on unpaired surrogates | Fixed |
| speedtest-cli | Python | [details](evals/speedtest-cli/REPORT.md) - small findings only | Fixed |
| phpdotenv | PHP | [details](evals/phpdotenv/REPORT.md) - silent [] on bad multiline | Fixed |
| cJSON | C | [details](evals/cjson/REPORT.md) - sort dropped later appends | Fixed |
| nlohmann/json | C++ | [details](evals/json/REPORT.md) - Bazel header list omitted a dep | Fixed |
| RuboCop | Ruby | [details](evals/rubocop/REPORT.md) - null result, zero findings | Fixed |
| lz4 | C | [details](evals/lz4/REPORT.md) - silent data loss, exit 0 | Fixed |
| godotenv | Go | [details](evals/godotenv/REPORT.md) - parser panic from .env | Fixed |
| moshi | Kotlin | [details](evals/moshi/REPORT.md) - 5 Highs behind green CI | Fixed |
| FluentValidation | C# | [details](evals/fluentvalidation/REPORT.md) - CreditCard() took no digits | Fixed |
| qs | JavaScript | [details](evals/qs/REPORT.md) - global state leaked | Fixed |
| claude-code-action | TypeScript | [details](evals/claude-code-action/REPORT.md) - converged on attempt 2 | Fixed |
| path-to-regexp | TypeScript | [details](evals/path-to-regexp/REPORT.md) - 4 REJECTs on evidence | Fixed |
| claude-agent-sdk-python | Python | [details](evals/claude-agent-sdk-python/REPORT.md) - converged on attempt 2 | Fixed |
| marshmallow | Python | [details](evals/marshmallow/REPORT.md) - 3 Highs in load path | Fixed |
| swift-algorithms | Swift | [details](evals/swift-algorithms/REPORT.md) - doc examples did not compile | Fixed |
| magic_enum | C++ | [details](evals/magic_enum/REPORT.md) - 6 members never compiled | Fixed |
| vavr | Java | [details](evals/vavr/REPORT.md) - BitSet.removeAll threw | Fixed |
| go-uuid | Go | [details](evals/go-uuid/REPORT.md) - SQL NULL returned stale UUID | Fixed |
| indicatif | Rust | [details](evals/indicatif/REPORT.md) - draw-width underflow panic | Fixed |
| ta | Python | [details](evals/ta/REPORT.md) - wrong numbers since 2023 | Fixed |
| go-cmp | Go | [details](evals/go-cmp/REPORT.md) - 2 grouping bugs, +31/-13 | Fixed |
| CLI11 | C++ | [details](evals/cli11/REPORT.md) - empty strtoX read as a value | Fixed |
| more-itertools | Python | [details](evals/more-itertools/REPORT.md) - sample() wrong on negatives | Fixed |
| idna | Python | [details](evals/idna/REPORT.md) - empty label raised IndexError | Fixed |
| sqlparse | Python | [details](evals/sqlparse/REPORT.md) - converged on run 5 of 5 | Fixed |
| sqlfluff | Python | [details](evals/sqlfluff/REPORT.md) - fix commented out the statement | Fixed |
| rrule | TypeScript | [details](evals/rrule/REPORT.md) - 23 findings, 10 High | Fixed |
| humanize | Python | [details](evals/humanize/REPORT.md) - 4 float-range Highs | Fixed |
| ryu | Rust | [details](evals/ryu/REPORT.md) - s2f rejected 7,807 strings | Fixed |
| rust-semver | Rust | [details](evals/rust-semver/REPORT.md) - ledger nearly shipped | Fixed |
| heck | Rust | [details](evals/heck/REPORT.md) - NFD lost combining marks | Fixed |
| mapstructure | Go | [details](evals/mapstructure/REPORT.md) - silent numeric overflow | Fixed |
| itoa | Rust | [details](evals/itoa/REPORT.md) - no-panic build failed to link | Fixed |
| cachetools | Python | [details](evals/cachetools/REPORT.md) - held iterator froze the clock | Fixed |
| memchr | Rust | [details](evals/memchr/REPORT.md) - crate shipped loop state | Fixed |
| python-slugify | Python | [details](evals/python-slugify/REPORT.md) - one bad entity voided all decoding | Fixed |
| bidict | Python | [details](evals/bidict/REPORT.md) - declared dependency floor could not import | Fixed |
| unicode-width | Rust | [details](evals/unicode-width/REPORT.md) - published crate lacked its own test corpus | Fixed |
| BurntSushi/toml | Go | [details](evals/ATTEMPTS.md) - 5 runs, 52 iters, not converged | Failed |
| Carbon | PHP | [details](evals/ATTEMPTS.md) - 4 runs, 17 iters, not converged | Failed |
| casbin | Go | [details](evals/casbin/REPORT.md) - 5 runs, 46 iters, not converged - [PR open](https://github.com/apache/casbin/pull/1753) | Failed |
| cast | Go | [details](evals/ATTEMPTS.md) - 2 runs, 22 iters, not converged | Failed |
| chroma.js | JavaScript | [details](evals/ATTEMPTS.md) - 4 runs, 30 iters, not converged | Failed |
| click | Python | [details](evals/ATTEMPTS.md) - 5 runs, 42 iters, not converged | Failed |
| decimal.js | JavaScript | [details](evals/ATTEMPTS.md) - 4 runs, 41 iters, not converged | Failed |
| diff-so-fancy | Perl | [details](evals/ATTEMPTS.md) - 3 runs, 30 iters, not converged | Failed |
| eemeli/yaml | TypeScript | [details](evals/ATTEMPTS.md) - 5 runs, 50 iters, not converged | Failed |
| faker | Ruby | [details](evals/ATTEMPTS.md) - 3 runs, 30 iters, not converged | Failed |
| go-humanize | Go | [details](evals/ATTEMPTS.md) - 2 runs, 21 iters, not converged | Failed |
| go-querystring | Go | [details](evals/ATTEMPTS.md) - 2 runs, 20 iters, not converged | Failed |
| goldmark | Go | [details](evals/ATTEMPTS.md) - 5 runs, 47 iters, not converged | Failed |
| Humanizer | C# | [details](evals/ATTEMPTS.md) - 4 runs, 32 iters, not converged | Failed |
| image-rs | Rust | [details](evals/ATTEMPTS.md) - 5 runs, 40 iters, not converged | Failed |
| immer | TypeScript | [details](evals/immer/journal.md) - 3 runs, 31 iters, not converged | Failed |
| itsdangerous | Python | [details](evals/ATTEMPTS.md) - 3 runs, 31 iters, not converged | Failed |
| libuv | C | [details](evals/ATTEMPTS.md) - started, then abandoned | Failed |
| mruby | C | [details](evals/ATTEMPTS.md) - 10 runs, 113 iters, not converged | Failed |
| node-semver | JavaScript | [details](evals/ATTEMPTS.md) - 4 runs, 30 iters, not converged | Failed |
| shopspring/decimal | Go | [details](evals/ATTEMPTS.md) - 4 runs, 33 iters, not converged | Failed |
| spdlog | C++ | [details](evals/ATTEMPTS.md) - 4 runs, 40 iters, not converged | Failed |
| tenacity | Python | [details](evals/ATTEMPTS.md) - 2 runs, 20 iters, not converged | Failed |
| testify | Go | [details](evals/ATTEMPTS.md) - 4 runs, 40 iters, not converged | Failed |
| thor | Ruby | [details](evals/ATTEMPTS.md) - 2 runs, 20 iters, not converged | Failed |
| validator.js | JavaScript | [details](evals/ATTEMPTS.md) - 2 runs, 20 iters, not converged | Failed |
| zstd | C | [details](evals/ATTEMPTS.md) - 6 runs, 54 iters, not converged | Failed |

### Greenfield: three builds judged by suites the loop did not write

Every receipt above is brownfield - the project arrived with a test suite the loop did not author. The white paper's own limits section names the residual weakness anyway: the loop writes many of the tests that certify the loop. Greenfield is that weakness at its maximum, so the answer was pre-registered: start from an empty directory, commit the goal and a Verify command naming an **external judge** before iteration 1, ship the backlog empty so the task decomposition is the loop's own work, and never intervene in a run. The engine is unmodified. All three targets converged.

| Target | Judge | Final position | Rows swept | Iterations | Runs |
|:---|:---|:---|---:|---:|---:|
| [TOML 1.0 decoder, Rust](https://github.com/lenamonj/jeffy-greenfield-toml) | `toml-test` v2.2.0 - 679 external assertions | **205 of 205 valid, 474 of 474 invalid** | 17 of 17 | 11 | 1 |
| [gitignore matcher, Rust](https://github.com/lenamonj/jeffy-greenfield-gitignore) | `git check-ignore` 2.50.1, differential | **106 cases, 300 queries, 0 disagreements** | 12 of 12 | 42 | 5 |
| [TOML-M decoder, Rust](https://github.com/lenamonj/jeffy-greenfield-toml-mutated) - *mutated spec* | `toml-test` v2.2.0 through a frozen output adapter | **205 of 205 valid, 474 of 474 invalid** (and 169 of 205 against *standard* TOML) | 17 of 17 | 14 | 1 |

The TOML decoder's zero measurement was the suite failing because the binary did not exist; eleven iterations later every one of 679 externally authored assertions passed, and even the surface-inventory rows were the suite's own test groups rather than the loop's choice. The gitignore matcher is the stopping-discipline story: its frozen corpus was fully green from the first iteration of run 2, and everything after that was the adversarial evaluator probing beyond the corpus and refusing to countersign - **invoked 8 times, rejecting 7**, filing findings that marched from matcher semantics into `wildmatch.c`'s escaped-slash clause, git's four-byte `isspace`, NTFS case folding, 8.3 short-name aliases, and the Win32 normalization layer git's own file opens bypass. Three runs ended blocked and are published as the receipts they are; once, the loop reproduced two of its gate's three rejection reasons and **refuted the third with direct oracle evidence**, filing exactly what reproduced.

The third target answers the objection the first two invite: TOML and gitignore saturate any plausible training set, so convergence there might measure recall. **TOML-M is TOML v1.0.0 with two rules deliberately inverted** - `true` and `false` swap payloads, and tab and line feed swap inside string values - so remembering the real format produces wrong answers. Both amendments are involutions, which lets the unmodified `toml-test` binary stay the judge through a frozen 61-line adapter that inverts the decoder's output. The receipt reports two numbers from one binary: **205 of 205 against the mutated suite, and 169 of 205 against standard TOML**, failing on exactly the cases the mutation touches. It built the dialect rather than recalling the format, at a cost of 14 iterations against 11 for the unmutated build. That receipt also discloses a rule violation on its own front page: an audit ran inside the closing extension window, which the engine forbids, and the convergence declaration cites it.

Stated as narrowly as the result deserves: the same engine, unmodified, converged on builds whose completeness was decided by judges it did not write - including one where recalling the real specification actively hurts. Not claimed: any completion rate (three chosen targets are not a sample), or invention (a two-rule dialect is not a novel format). The gitignore corpus is self-authored - frozen at 53 cases, grown monotonically to 106, never shrunk, and since scored cold against 119 blind-authored queries with no disagreements - and the white paper weighs that honestly against the TOML target's fully external 679. All three repositories ship their complete run record - pre-registration, journal, backlog, every iteration commit - because for a greenfield build the process is the evidence.

## How a run works

<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="media/flowchart-dark.png">
  <img src="media/flowchart-light.png" alt="Flowchart of a /jeffy run: the launch skill bootstraps the state files, each iteration audits or executes one verified task and checkpoints it, the adversarial evaluator - a fresh-context sub-agent - countersigns convergence, and the Stop hook re-feeds the loop until convergence, budget end, or a blocker - all steered by three files and the git log." width="830">
</picture>

<sub>How one command becomes a run. Solid arrows are control flow; dashed arrows are the file reads and writes that steer it. Outside a run the Stop hook exits instantly - no live state file, no behavior - and <code>/cancel-jeffy</code> ends a run at any time. Diagram source: <a href="media/flowchart.mmd"><code>media/flowchart.mmd</code></a>.</sub>

</div>

Running `/jeffy` in a Claude Code session:

1. **Bootstraps the loop's memory** at the project root: `PLAN.md` (goal, operating envelope, surface inventory, verify command, lessons, definition of done), `BACKLOG.md` (the task ledger - findings prioritized most severe first, plus proposals awaiting your decision, settled defect classes, and the Converged record), and `JOURNAL.md` (append-only iteration log). They persist between runs.
2. **Runs the budgeted loop.** The first audit fills the surface inventory and the backlog. Each iteration after that either audits or executes exactly one task, verifies it, and checkpoints it; a task that newly breaks the verify command is reverted. Once one full audit comes back clean of High and Medium, the run stops auditing and finishes the ledger.
3. **Stops for a reason and reports.** Convergence - a clean audit, zero open High or Medium with every carried Low named, a fully swept inventory, the adversarial evaluator's PASS, all re-checked in shell by the Stop hook - or the budget, a stall, a hard blocker, or your cancel. The run report lists tasks closed with severities, the diffstat, rows swept of rows total, and anything waiting on your decision.

### Use several short runs, not one long one

A budget is a ceiling, not a target. **Run `/jeffy 10`, let it finish, close the session, then open a new one and run it again.** The receipts that took 40 or 58 or 74 iterations got there as four to eight budgeted runs, never as one enormous budget.

The reason is context. The loop starts each iteration from written state precisely because a fresh reading of the record beats a long conversation's memory of it, but inside one session that conversation keeps growing until the loop is reasoning over its own transcript instead of its files. A new session throws that away. The receipts show the cost of skipping it: in the python-dotenv run, later runs kept filing findings on surface earlier runs had already swept and scored clean.

The restart is also the natural review point. Between runs the tree is committed and the report is written, so it costs nothing to read the journal, answer anything under Proposed, and decide whether to keep going.

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

## Good to know

- **One loop per project at a time.** A crashed session can leave a stale state file behind; the skill detects it at launch and asks before cleaning up.
- **You can talk to the session mid-run.** Your message gets answered, then the loop resumes on its own. The turn counts against the budget.
- **Permission prompts pause the loop.** For unattended runs, allowlist your test and file tools or use acceptEdits mode. Never allowlist push or force operations for a loop.
- **Budget counts turns, and a single turn is unbounded in time and cost.** Keep N small on a first run and watch it. Check spend anytime with `/cost`.
- **Prefer several small runs over one big one.** Context accumulates across iterations within a run, and the state files carry everything between runs, so two runs of 5 beat one run of 10 - but the clean context only arrives with a new session. Close the session and start a fresh one in the same directory; nothing is lost.
- **Edit `PLAN.md` or `BACKLOG.md` between iterations, not mid-iteration.** The Proposed section is the designed channel for decisions.
- **A `.jeffy/` directory appears at the root of a project the loop has swept.** It holds the known-answer probe batteries a later sweep re-runs instead of rebuilding, and the evaluator artifacts under `.jeffy/evaluator/` - one per gate invocation, naming the commands the adversarial gate actually ran and what they exited. The checkpoints commit all of it on purpose - loop memory, exactly like the three state files. Only the transient loop state file is gitignored.

> [!IMPORTANT]
> **Trust model.** The entire engine is one auditable shell script in this repo (`skills/jeffy/hooks/stop-hook.sh`) plus the small library it sources from `skills/jeffy/hooks/lib/`, registered as a Claude Code Stop hook. It fires at turn end but exits instantly unless the current project has a live Jeffy state file naming that session - zero cost and zero behavior outside a run. The installer's only writes outside this repo are the two skill folders it copies into `~/.claude/skills` (engine included), that one hook registration in `~/.claude/settings.json`, and - only when jq is missing and you answer yes to its prompt - a jq install through your system package manager (winget, Homebrew, or apt).

## The loop improves the loop

The rule above - fix the loop, not the run - applies to Jeffy itself, and that is the part designed to compound. Most tools improve when their authors read bug reports. Jeffy improves by being run against its own source under its own rules, and by converting what that finds into machinery that cannot be forgotten. Four mechanisms do the work, and each leaves evidence in this repository you can check rather than take on trust.

**The engine is audited by the engine, and the results are merged in public, failures included.** Jeffy is pointed at its own repository exactly as it is pointed at any external target: same envelope, same evidence rules, same adversarial gate, no privileged mode. Those runs are in this history under their own merge commits, and the subjects say what happened rather than what would read better. `ba032bc` merged the first self-run to converge under the gate, and shipped the first published evaluator artifacts with it. `20ab642` merged the v1.9.0 self-run, converged in 6 of 15 iterations. `d89c0ac` reads, in full, *"merge: three self-runs of harness work, none of which converged"*. Real fixes came out of that third merge and none of them earned a convergence stamp, so the commit says so. A tool that publishes only its successful self-audits is evidence of nothing.

**A lesson a machine can check becomes a check, never a paragraph.** This is the mechanism that accumulates. When a run finds a defect in the engine, the fix is not a warning in the documentation but a behavioural check in `scripts/validate.sh` that fails if the defect returns. The count is the visible result: it started at 119 and stands at <!-- count:checks -->**312 behavioural checks**<!-- /count --> on a clone, each one added because something went wrong once and was made unable to go wrong silently again. The number in that sentence is itself derived by the validator rather than typed, which is the next mechanism.

Check K is the clearest example, because it closed the hole it was born from. The lesson was that a published number must be recomputed from the run rather than copied from wherever it last appeared. Prose saying so would have been read and forgotten. Instead check K derives the check count this README publishes from the validator run itself and refuses a mismatch - and during a release build it did exactly that, rejecting a stale `203` that a human had already read past.

**The gate grades the run's evidence, not only the code.** The adversarial evaluator is the mechanism that makes self-improvement honest, because the most common failure is not a missed bug but a proof that does not prove anything. `path-to-regexp` is the plainest case in the corpus: three runs, five evaluator invocations, four of them rejections, and **not one rejection was a missed defect in the library**. Every one was a defect in the run's own evidence, including a verify command whose randomised assertions could report safe without ever searching. Those findings improve the method, not the target.

**Failures are published beside successes.** `evals/ATTEMPTS.md` carries every attempt, including **32 attempts that did not converge**, each with the budget it was given before it started and the reason it ran out. A corpus of only successes cannot teach anything about where the method stops working, and knowing where it stops is what tells us what to build next. Several of the engine's largest changes exist because a published failure named the gap first.

The governing principle came from a self-run that caught its own author. A run promoted a lesson into `PLAN.md` and then broke that same lesson two iterations later, in the very work that promoted it. **A promoted lesson does not protect the iteration that promotes it.** So where a lesson can be checked mechanically it belongs in the harness, and where it cannot it is written down knowing that prose is the weaker instrument.

## Contributing

Before submitting a change, run the repo validator:

```bash
bash scripts/validate.sh
```

It gates, among other things:

- **Syntax and lint** - both installers and the Stop hook (`bash -n`, PowerShell parser, shellcheck).
- **Skill integrity** - frontmatter, referenced paths, the governance markers that keep the envelope, ratchet, verify gate, run report, and convergence rules from silently regressing - including the `Command:` line the default plan hands the hook to run - and the iteration prompt's injection invariants.
- **Behavior, not just parsing** - both installers and the Stop hook are exercised end to end, every gate proven able to fail. The full scenario list is below.

<details>
<summary>The full behavioural scenario list</summary>
<br>

Both installers run non-interactively against sandboxed profiles (skills and engine must land, and the hook registration must appear exactly once even after a re-run and carry the 600s timeout, whether written fresh or upgraded from an older entry), and the Stop hook itself is exercised through its full lifecycle: mid-budget re-feed, budget exhaustion, completion promise, foreign-session isolation, and the no-state no-op. The gates that guard the converged stop are held to the same standard - an open task, a `Converged` line that no longer certifies the tree, an unswept Surface inventory row, and a verify command that is red, that overruns its timeout, or that is declared `none` each have to produce the right outcome, a fully swept inventory and a pre-inventory `PLAN.md` are both accepted, and the verify parser is proven on the one shape the hook executes, the labelled `Command:` line - backticks stripped only when the wrapping pair is unambiguous, an annotated line named as a `bash -n` defect before anything runs, and a section carrying no command skipped with a note rather than run as prose - as are the per-iteration hygiene gates and the fail-open paths for a missing ledger, journal, or plan, a malformed counter, and a moved prompt file. The two newest gates get the same treatment: the closing extension has to be granted once at exact budget exhaustion with zero open High and zero open Medium - carried Lows included - over a swept inventory and refused everywhere else - a Medium still open, a task line whose severity the parse cannot read, a row still unswept, a flag already set, a frontmatter that never closes, an iteration already past its budget - and the granted window has to survive the Lows it was granted over while a non-evaluator refill, a Medium or a Low filed inside it, still ends the run - and a declaration must be rejected when its closing entry records no evaluator verdict, accepted on `Evaluator: PASS` backed by this run's committed evaluator artifact, rejected when that artifact is missing, belongs to another run, or sits uncommitted in the tree, rejected outright on `Evaluator: unavailable`, exempt for a ratchet, and failed open when the journal holds no entry for the run. The hygiene gates are proven both ways too: a journal heading that names the session but not the run is rejected and a legacy state file without a run token falls back cleanly, and a rotation that shrinks or deletes `JOURNAL-archive.md` is caught while an appending one passes and a never-rotated project is left alone. The stall gate is proven the same way, and from 1.7.0 against the engine's own commit behaviour rather than against synthetic state: progress on either signal stays silent, the first flat iteration draws the STALL note and arms the flag, the second consecutive one ends the run, progress resets the strike, a non-git project stalls out on the ledger signal alone, a project with neither signal skips with a stderr note, and neither budget exhaustion nor a valid promise is disturbed by an armed flag. The commit-driven cases are the ones that matter, because the loop checkpoints every iteration: two journal-only iterations that each committed draw the note and then end the run, a battery-only iteration under `.jeffy/` draws it too, a committed `.claude/settings.local.json` and a tracked loop state file are read as harness churn rather than progress, a one-line source change committed alongside the state files stays silent, all four ceremony types are exempt and carry the flag through untouched while a fourth consecutive one draws the note and a fifth ends the run, a stale entry heading at a desynced index does not exempt the entry that replaced it, a state file with no run token gets no exemption at all, a recorded head this repository cannot resolve fails open, a repository that disappears mid-run falls back to the ledger, and a forfeited closing extension is named on the way out. Both tree gates are also proven in a project that sits below the repository root, where git reports paths from the repository root and every filename the two exclusion lists carry is anchored at the project root.

</details>

Core checks need only bash and coreutils; shellcheck, PowerShell, and jq passes skip cleanly when absent, and the closing line reports how many checks ran against how many were skipped, reprinting each skip with its reason - a check that did not run covers nothing, and an exit code alone cannot say which is which. The one exception is shellcheck in the maintainer tree, where a release is cut: there it is a failure rather than a skip, because that lint rides the Linux CI leg and a skip would put its first real run after the push. CI runs the same validator on Linux, Windows, and macOS - the macOS leg exists because BSD userland differs from GNU in `sed`, `grep`, and `stat`, and nothing exercised it before.

## License

MIT
