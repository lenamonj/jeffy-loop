<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="media/banner-dark.png">
  <img src="media/banner-light.png" alt="Jeffy Loop - point it at a project, give it a budget, come back to a better codebase and a report" width="900">
</picture>

[![Validate](https://img.shields.io/github/actions/workflow/status/lenamonj/jeffy-loop/validate.yml?style=for-the-badge&label=validate&logo=githubactions&logoColor=white)](https://github.com/lenamonj/jeffy-loop/actions/workflows/validate.yml)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Skill-D97757?style=for-the-badge&logo=claude&logoColor=white)](https://claude.com/claude-code)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Mac%20%7C%20Linux-0EA5E9?style=for-the-badge)
[![Fable 5](https://img.shields.io/badge/Built_with-Fable_5-D97757?style=for-the-badge&logo=claude&logoColor=white)](https://claude.ai)
[![License: MIT](https://img.shields.io/badge/License-MIT-22C55E?style=for-the-badge)](LICENSE)

**[Quickstart](#quickstart)** &nbsp;·&nbsp; **[Usage](#usage)** &nbsp;·&nbsp; **[Why Jeffy](#why-jeffy)** &nbsp;·&nbsp; **[The receipts](#external-validation-public-open-source-projects)** &nbsp;·&nbsp; **[How a run works](#how-a-run-works)** &nbsp;·&nbsp; **[The rules](#the-rules-a-run-lives-by)** &nbsp;·&nbsp; **[White paper](https://github.com/lenamonj/jeffy-loop/raw/main/The-Jeffy-Loop.pdf)**

</div>

Jeffy Loop is an autonomous improvement loop for [Claude Code](https://claude.com/claude-code) that works on your codebase the way a disciplined principal engineer would: audit first, fix one verified task at a time, prove every claim, and stop when the job is actually done.

Run `/jeffy 10` and walk away. Jeffy maps your project's whole public surface, audits it breadth-first, and writes a backlog where every task carries a runnable acceptance check. Then it executes: one verified, checkpointed task per iteration, behind a verify gate that reverts anything that breaks your project. And "done" is never a feeling - a fresh audit must come back clean, an adversarial evaluator must countersign, and a plain shell script re-checks the whole claim before the run is allowed to end.

It has receipts. Widely used open-source libraries have been run to convergence, surfacing shipped, reproducible bugs - many hiding behind green test suites - and three greenfield builds converged from empty directories under external judges the loop could not edit, one of them against a deliberately mutated specification. [The receipts are below.](#external-validation-public-open-source-projects)

New to autonomous agent loops, or want the full argument? **The Jeffy Loop** is a 33-page white paper written for readers with no prior knowledge of agents: how loops got here from ReAct to AutoGPT to the Ralph Loop, what Anthropic recommends and what that guidance leaves open, then every rule below explained from first principles - including an honest account of what this method still cannot do. It cites 28 sources, all linked. **[Download it here.](https://github.com/lenamonj/jeffy-loop/raw/main/The-Jeffy-Loop.pdf)**

<div align="center">

![Jeffy Loop vs a raw prompt loop - the head-to-head](media/jeffy-vs-raw-loop.gif)

<sub>The head-to-head vs a raw prompt loop. Every row is a guarantee you can verify in the code: the engine is <code>skills/jeffy/hooks/stop-hook.sh</code>, the discipline is <code>skills/jeffy/references/iteration-prompt.txt</code>, and the receipts live under <a href="evals/"><code>evals/</code></a>.</sub>

</div>

Jeffy Loop descends from Geoffrey Huntley's [Ralph technique](https://ghuntley.com/ralph/) - the insight that a coding agent re-fed one prompt in a loop compounds into real work. The head-to-head above is engine versus method: the raw loop is the engine pattern Jeffy is built on, and Jeffy is the engineering method wrapped around it. The method distills what the people running loops at scale have published - Anthropic's [Claude Code best practices](https://code.claude.com/docs/en/best-practices) and [Boris Cherny's public workflow](https://x.com/bcherny/status/2007179832300581177): give the agent a check it can run, one task at a time, promote every hard-won lesson into a file the next run reads, and prefer small fresh-context runs over one long one.

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

Then open Claude Code in the project you want to improve and type `/jeffy 10`.

> [!TIP]
> `/jeffy` is a slash command inside the Claude Code session, not a shell command.

When that run ends, close the session and start a new one to run it again. That restart is doing real work, and [why is worth two minutes](#use-several-short-runs-not-one-long-one).

The installer verifies the Claude Code CLI and `jq` (offering to install it via winget, Homebrew, or apt), copies the `/jeffy` and `/cancel-jeffy` skills - engine included - to `~/.claude/skills`, and registers the loop's hook in `~/.claude/settings.json`. Every step prints an [OK] or the exact fix.

- **Re-run** - always safe: it skips what is installed, upgrades in place, and never duplicates the hook registration.
- **Update** - see [Already installed? Upgrade in five steps](#already-installed-upgrade-in-five-steps) below.
- **Uninstall** - delete `~/.claude/skills/jeffy` and `~/.claude/skills/cancel-jeffy`, and remove the hook entry from `~/.claude/settings.json`.

### Already installed? Upgrade in five steps

Upgrading touches `~/.claude` and nothing else. No project you have run against is modified.

**1. Check the version you are on.**

```bash
grep -m1 JEFFY_VERSION ~/.claude/skills/jeffy/hooks/stop-hook.sh
```

Windows PowerShell:

```powershell
Select-String -Path $env:USERPROFILE\.claude\skills\jeffy\hooks\stop-hook.sh -Pattern '^JEFFY_VERSION' | Select-Object -First 1 -ExpandProperty Line
```

Both print `JEFFY_VERSION="x.y.z"`. Nothing to do if it already matches the newest release.

**2. Let any run finish, or stop it with `/cancel-jeffy`.** The Stop hook is read from disk every time it fires, so replacing it underneath a live run changes that run's rules midway through it.

**3. Pull the new version.**

```bash
cd jeffy-loop
git pull
```

Deleted the clone since installing? Clone it again instead - the installer only ever reads from it:

```bash
git clone https://github.com/lenamonj/jeffy-loop.git
cd jeffy-loop
```

**4. Re-run the installer.**

```bash
./install.sh        # Windows PowerShell: .\install.ps1
```

It overwrites both skills in place, leaves a correct hook registration alone, and adds the 600s timeout to a registration made before v1.2.

**5. Start a new Claude Code session.** Skills and hook registrations are read when a session starts, so a session you already have open keeps running the old engine until you restart it.

To confirm the upgrade took, re-run the check from step 1, or just start a run - `/jeffy` names the engine version on its first line.

> [!NOTE]
> The installer copies over the top and never deletes, so a file removed in a later version stays behind. If you want a clean slate, delete `~/.claude/skills/jeffy` and `~/.claude/skills/cancel-jeffy` before step 4; step 4 puts both back.

## Usage

```
/jeffy [N] [focus...]
/jeffy [N] enhance <topic>
```

- `N` - iteration budget, default 10. Sizing is low-stakes in both directions: the loop ends itself at convergence, so unused budget costs nothing, and a budget that runs dry loses no work - the next `/jeffy` picks up where the run stopped. The floor for converging in one run is the opening audit, one iteration per expected finding, and a closing audit; when that arithmetic outgrows the default, prefer a second run over a bigger number (see [Good to know](#good-to-know)).
- `focus` - optional directive for the run, e.g. `/jeffy 8 test coverage and error handling`.
- `enhance <topic>` - runs the loop in Enhance mode against the stated topic instead of hunting defects. See [Enhance mode](#enhance-mode).

```
/jeffy                                     # 10 iterations, full-spectrum improvement
/jeffy 5                                   # 5 iterations
/jeffy 12 accessibility and performance    # 12 iterations with a focus directive
/jeffy 8 enhance the CLI's error messages  # 8 iterations building on one topic
```

### Enhance mode

Jeffy's default loop finds what is wrong and fixes it. Some work is not a defect: a capability the project stops short of, a workflow that takes five steps where a peer tool takes one, a platform the installers support but nothing exercises. `enhance` points the same machinery at that work.

The keyword goes after the optional budget, and everything after it is the topic:

```
/jeffy 10                                                    # find defects and fix them
/jeffy 8 enhance test coverage for the modules with no tests # design and build the tests
```

The first returns a ledger of findings worked worst-severity-first, each with a reproduction. The second returns an opportunity audit of the topic's surface, then ranked improvements built one per iteration, each with an acceptance check observed to fail against the unimproved tree before it passes against the new one.

Everything else is the same loop:

| | Default (Improvement) | Enhance |
|---|---|---|
| **What generates the backlog** | An audit against the rubric, filing defects | An opportunity audit of the topic's surface, filing enhancements |
| **How work is ranked** | Rubric severity | Impact - what users and maintainers would notice and value. Same Now/Next/Later sections, same line grammar, rank sits in the severity slot |
| **What bounds the run** | The Operating envelope | The topic. A task you cannot tie to it in one sentence does not get filed |
| **A defect found mid-run** | Filed at severity and worked | Recorded to Proposed for a standard run to take, never filed at severity - unless it blocks the task in flight, which makes it one ordinary task |
| **Convergence** | Ledger empty, surface swept, verify green, evaluator PASS | Identical, over the topic's surface instead of the whole project |
| **Ratchet** | Skips a re-audit on an unchanged converged tree | Never applies. The topic rides the loop state's focus field, and the ratchet does not fire on a run carrying a focus directive |

Two refusals you will meet:

- **`enhance` with no topic is refused.** An unbounded make-it-better run is exactly the invented work the envelope exists to prevent, so the skill reports the usage and stops.
- **The modes never share state files.** An Enhance launch over a standard `PLAN.md`, or a standard launch over an Enhance one, is refused - the two rank work differently and their ledgers and convergence records must not mix. Finish or archive the other mode's state files first: commit them and delete them, or use a separate branch or checkout. A `PLAN.md` with no `## Mode` section is a user-authored plan and counts as standard.

What Enhance does not change: the Stop hook, the verify gate, the checkpoint commits, the journal, and the adversarial evaluator gate are identical in both modes. Convergence is earned the same way or not at all.

**Scoped mode.** By default `/jeffy` runs in Improvement mode: an open-ended audit-and-fix loop. To run it against a concrete target instead, edit `PLAN.md` - replace the Goal and Definition of done with the target, seed `BACKLOG.md` with the finite tasks, then run `/jeffy`. Everything else (envelope, verify gate, checkpoints, journal, report) behaves the same.

**Cancel.** Run `/cancel-jeffy`. It reports which loop it found, deletes the loop state file, and leaves `PLAN.md`, `BACKLOG.md`, and `JOURNAL.md` untouched, so the next `/jeffy` picks up exactly where it left off. (Equivalent manual action: delete `.claude/jeffy-loop.local.md` at the project root.)

## Good to know

- **One loop per project at a time.** A crashed session can leave a stale state file behind; the skill detects it at launch and asks before cleaning up.
- **You can talk to the session mid-run.** Your message gets answered, then the loop resumes on its own. The turn counts against the budget.
- **Permission prompts pause the loop.** For unattended runs, allowlist your test and file tools or use acceptEdits mode. Never allowlist push or force operations for a loop.
- **Budget counts turns, and a single turn is unbounded in time and cost.** Keep N small on a first run and watch it. Check spend anytime with `/cost`.
- **Prefer several small runs over one big one.** Context accumulates across iterations within a run, and the state files carry everything between runs, so two runs of 5 beat one run of 10 - but the clean context only arrives with a new session. Close the session and start a fresh one in the same directory; nothing is lost.
- **Edit `PLAN.md` or `BACKLOG.md` between iterations, not mid-iteration.** The Proposed section is the designed channel for decisions.
- **A `.jeffy/` directory appears at the root of a project the loop has swept.** It holds the known-answer probe batteries a later sweep re-runs instead of rebuilding, and from 1.7.0 the evaluator artifacts under `.jeffy/evaluator/` - one per gate invocation, naming the commands the adversarial gate actually ran and what they exited. The checkpoints commit all of it on purpose - loop memory, exactly like the three state files. Only the transient loop state file is gitignored.

> [!IMPORTANT]
> **Trust model.** The entire engine is one auditable shell script in this repo (`skills/jeffy/hooks/stop-hook.sh`), registered as a Claude Code Stop hook. It fires at turn end but exits instantly unless the current project has a live Jeffy state file naming that session - zero cost and zero behavior outside a run. The installer's only writes outside this repo are the two skill folders it copies into `~/.claude/skills` (engine included), that one hook registration in `~/.claude/settings.json`, and - only when jq is missing and you answer yes to its prompt - a jq install through your system package manager (winget, Homebrew, or apt).

## Why Jeffy

- **An engineer's judgment, not a linter's.** Every run starts from a real audit - architecture, correctness, security, testing, error handling, performance, accessibility, developer experience, and more - and every finding becomes a prioritized task with a concrete acceptance check. Evidence over assertion: a finding exists only if the loop can point at it.

- **It cannot wreck your repo.** Every iteration ends in a local checkpoint commit. A repo-level verify gate guards every change: an iteration that breaks the project is reverted on the spot. Nothing is ever pushed, no branches are created. Review with `git log`, revert any single iteration, squash the run when you're happy.

- **It doesn't invent problems.** Severity is judged against a declared operating envelope - your project's real input surfaces, not imagined attackers. Out-of-envelope findings can't inflate the backlog, and only you can widen the envelope: the loop files a proposal and moves on.

- **Done means done.** The loop converges only when a full fresh audit finds zero High and zero Medium findings *and* the backlog is empty - every Low fixed, declined with a reason, or blocked with its reason on record. Declining is priced, not felt: a Low outside the shipped runtime whose fix plus its regression test will not fit inside one iteration is declined as `cost: exceeds one iteration` and named by ID in the run report, so polish cannot quietly eat a budget. A **surface inventory** bounds the claim: the first audit maps the whole public surface into a checkbox table and probes it breadth-first, every sweep records the commit it certified, and clean scores claim only examined rows - "no findings" can never quietly mean "nowhere looked". Surface this host genuinely cannot reach is marked `- [~]` with its reason and named in the run report, disclosed rather than counted as swept. Once one audit comes back clean, the loop stops auditing and finishes the backlog, so a tail of Lows cannot keep it busy forever.

- **Convergence needs a second signature.** An agent grading its own work praises it. So before the loop may claim convergence, **the adversarial evaluator** - a fresh-context sub-agent carrying none of the run's self-persuasion - re-runs the verify gate and the closed tasks' acceptance checks, hunts for missed findings, and must return PASS. A rejection files its evidence as new tasks and the run works them. What ends a run is a rejection with **no invocation left**, not the second one as such - a second rejection holding a review files its findings and the run carries on, which is the only way a run whose first verdict was a rejection ever reaches the third review it earned. And from 1.8.0 that ending no longer forfeits the budget: the run spends what remains closing the findings the gate filed, then stops blocked, and convergence waits for the next run's fresh gate. The gate fires while its verdict can still be answered - the iteration the ledger first empties with a clean full audit already on the record and three or more iterations left, not only at the finish line, with up to three reviews when that first one lands before the budget's midpoint. And the verdict has to be on the record with something behind it: the Stop hook refuses a declaration whose closing journal entry carries no evaluator verdict, and refuses a PASS that has no artifact - the evaluator writes `.jeffy/evaluator/<run-id>-<n>.md`, one path per invocation so that no squash or shallow clone can fold a run's three verdicts into whichever came last, naming every command it ran and that command's real exit status, and the hook reads the highest ordinal on record and requires that file committed and unmodified. Shell cannot prove who wrote a file and the rule does not claim to; what it changes is the price of a false PASS, from eleven typed characters to a fabricated forensic record the repository then keeps. From 1.7.0 a session that cannot spawn the sub-agent no longer converges under a stated `unavailable`: the run ends blocked and the declaration waits for a relaunch where the gate can actually run.

- **The stop is machine-checked, and the machine is tested.** The Stop hook - plain shell, not a model - refuses the converged stop unless the ledger is present and empty, the Converged commit is still **reachable from HEAD** and still certifies the tree, no inventory row is unswept, the verify command has declared what it actually grades and what this platform excludes, and the project's own verify command exits green when the hook re-runs it. A failed check re-feeds the loop with the evidence, and when the budget expires with the ledger empty and the surface swept - the shape where runs used to die with the work done - the hook grants one +2 closing extension, once per run, so the convergence sequence has room to finish. The engine itself is held to <!-- count:checks -->**193 behavioural checks**<!-- /count --> on each CI leg, Linux, Windows, and macOS, with a shellcheck lint pass riding the Linux leg on top.

- **It has a self-learning mechanism, and it is pointed at itself.** Every iteration records what the run learned, and an operational rule learned the hard way is binding on every iteration after it. When the same rule has to be written a second time, the loop marks it and **proposes promoting it into a mechanism** - a hook check or a rule - on the reasoning that a rule needing to be written twice is a rule the text is not enforcing. That is not a description of an intention: it has happened on real targets, and their published journals carry the loop's own words for it. Those proposals become scheduled engine work, and once one ships it binds on every project the loop touches afterwards - a defect met in a stranger's repository is how this engine earns its next version. The loop proposes; you reproduce it and decide.

- **It stops on purpose, and it shows its work.** Budget spent, convergence reached, progress stalled, or a decision only you can make - the loop ends itself and says why, instead of burning budget spinning. The run report lists iterations used, tasks closed with severities, the diffstat, anything blocked, and decisions waiting on you; an append-only journal and the checkpoint commits hold the full, greppable record.

<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="media/language-pie-dark.png">
  <img src="media/language-pie-light.png" alt="Pie chart of the 21 converged public targets by language: Python 8 at 38.1 percent, JavaScript 3 at 14.3 percent, Go 2 at 9.5 percent, Rust 2 at 9.5 percent, C# 1 at 4.8 percent, C++ 1 at 4.8 percent, Java 1 at 4.8 percent, PHP 1 at 4.8 percent, Ruby 1 at 4.8 percent, TypeScript 1 at 4.8 percent." width="900">
</picture>

<sub>Every converged public target, by the language it was written in. Counts are derived from the receipts table below at render time by <a href="scripts/render-language-pie.py"><code>scripts/render-language-pie.py</code></a>, and the alt text above is derived from the same table by the repo validator, so neither the chart nor its description can disagree with it. Both read the slices largest first, ties alphabetical. Chart source: <a href="media/language-pie.html"><code>media/language-pie.html</code></a>.</sub>

</div>

## External Validation: Public Open-Source Projects

Testing a tool against its own codebase proves little. Jeffy was therefore run against widely-used open-source projects with no connection to this repository. <!-- count:converged -->21<!-- /count --> of those runs converged, across <!-- count:languages -->10<!-- /count --> languages - Python, JavaScript, TypeScript, Java, C#, C++, Go, Rust, Ruby and PHP - and that breadth is evidence of something specific rather than decoration: the engine ships no language-specific analyzer, no ruleset, and no per-ecosystem plugin. It works from what a project already has, its own test suite and its own verify command, so what carries from a Rust CLI to a Ruby linter to a C++ parser is the method itself. The findings are correspondingly varied: a security flag that did nothing when output was piped, a documented build configuration that had never compiled on MSVC, a Content-Length no parser should accept becoming a wrong number, a panel header dropped rather than truncated.

Every run used a local clone, nothing was pushed upstream without a filed issue or PR, and every run was held to the rules current at its date - a standard that only ever tightened. Of the <!-- count:converged -->21<!-- /count -->, **<!-- count:countersigned -->16<!-- /count --> converged under the adversarial evaluator's countersignature, <!-- count:evaluator-unavailable -->1<!-- /count --> recorded the evaluator as unavailable and says so, and <!-- count:pre-evaluator -->4<!-- /count --> predate the gate entirely**, converging under the earlier standard of a clean closing audit and an empty backlog. Each receipt names the standard its run met. What never varied: evidence before filing, severity judged against a declared operating envelope, and red-green proof that anyone can re-run.

Each receipt below is a full `/jeffy` loop run that converged, with one deliberate exception kept in the table rather than hidden: PapaParse, an audit under the same method whose loop conversion waits on four open upstream PRs. A method that always converges is not measuring anything, and the record shows what the standard costs when a project resists it - python-dotenv was published here as *not converged* through four runs and 25 findings, and it took eight runs and 73 iterations before an audit finally filed nothing. sqlparse makes the same point under a stricter rule: its run budget of five was fixed in writing before its first iteration, four runs failed and two of those ended blocked, and it converged on the fifth and last budgeted run. Had it rejected once more it would have been published as a non-convergence, because the rule said so in advance rather than afterwards. The run before python-dotenv's converging one ended blocked, out of evaluator invocations, with three fresh Mediums on the ledger. The standard tightened as the engine matured. The earliest runs converged on a clean closing audit and an empty backlog, later runs under the shell-enforced converged stop, and the most recent under the adversarial evaluator's countersignature. Each receipt states which standard its run met, so none of this requires taking our word for it.

<sub>Ordered by severity of findings, most severe first.</sub>

| Project | Stars | Language | Iters | Upstream | Headline |
|:---|---:|:---|---:|:---|:---|
| [quantstats](evals/quantstats/REPORT.md) | 7,489 | Python | 40 | [issue filed](https://github.com/ranaroussi/quantstats/issues/537) | 29 findings behind 125 green tests; the library ended smaller than it started |
| [fasthttp](evals/fasthttp/REPORT.md) | 23,422 | Go | 58 | **[FIX MERGED](https://github.com/valyala/fasthttp/pull/2343)** | 31 findings in a tagged release; a Content-Length no parser should accept became a wrong number |
| [rust-url](evals/rust-url/REPORT.md) | 1,570 | Rust | 30 | [PR open](https://github.com/servo/rust-url/pull/1147) | 20 findings, 10 High, in the URL crate under cargo and reqwest; a class was settled and withdrawn three times before it held, and the PR closes a conformance case open upstream since 2023 |
| [PHP-Parser](evals/php-parser/REPORT.md) | 17,450 | PHP | 29 | [PR open](https://github.com/nikic/PHP-Parser/pull/1162) | the tenth language; told nothing, it found its project's largest oracle by itself, then proved one of the suite's own test classes passes without executing the code it names |
| [rrule](evals/rrule/REPORT.md) | 3,738 | TypeScript | 33 | - | 23 findings, 10 High, in the RFC 5545 library behind much of the JavaScript calendar ecosystem; the reference implementation overruled one of the loop's own High findings and the loop withdrew it |
| [go-yaml](evals/go-yaml/REPORT.md) | 2,217 | Go | 29 | [PR open](https://github.com/goccy/go-yaml/pull/915) *(not a loop finding)* | 20 findings, 6 High, including a regression the run introduced and the gate caught; the vendored conformance corpus never ran, and scores identically before and after |
| [records](evals/records/REPORT.md) | 7,220 | Python | 7 | [issue filed](https://github.com/kennethreitz/records/issues/236) | four High data-loss bugs behind a green suite |
| [PyPortfolioOpt](evals/pyportfolioopt/REPORT.md) | 5,905 | Python | 58 | [PR open](https://github.com/PyPortfolio/PyPortfolioOpt/pull/751) | CI-red baseline to 356 passing; the evaluator rejected five convergence attempts |
| [dayjs](evals/dayjs/REPORT.md) | 48,657 | JavaScript | 74 | [PR open](https://github.com/iamkun/dayjs/pull/3167) | 45 findings, 10 High, in a 63M-downloads-a-week library |
| [mustache.js](evals/mustache.js/REPORT.md) | 16,725 | JavaScript | 11 | [issue filed](https://github.com/janl/mustache.js/issues/848) | revived a suite that could not start; npm audit 107 to 2 |
| [ta](evals/ta/REPORT.md) | 5,129 | Python | 64 | - | wrong numbers shipped since 2023; caught its own regression and wrote "It is mine" |
| [bat](evals/bat/REPORT.md) | 59,915 | Rust | 10 | **[FIX MERGED](https://github.com/sharkdp/bat/pull/3862)** | a just-merged security flag did nothing when piped; caught before it ever shipped |
| [jsoncpp](evals/jsoncpp/REPORT.md) | 8,876 | C++ | 10 | [PR open](https://github.com/open-source-parsers/jsoncpp/pull/1709) | the documented secure-memory build never compiled on MSVC; the evaluator caught the fix being half done |
| [yfinance](evals/yfinance/REPORT.md) | 24,837 | Python | 9 | [PR open](https://github.com/ranaroussi/yfinance/pull/2927) | closed a High that upstream's own failing test was advertising |
| [speedtest-cli](evals/speedtest-cli/REPORT.md) | 14,080 | Python | 5 | - | the restraint case: small findings, nothing invented |
| [chalk](evals/chalk/REPORT.md) | 23,288 | JavaScript | 8 | **[FIXED UPSTREAM](https://github.com/chalk/chalk/pull/687)** | the control: one Medium found - the maintainer wrote and merged the fix himself, shipped in chalk v6.0.0 |
| [Spectre.Console](evals/spectre.console/REPORT.md) | 11,567 | C# | 8 | [issue filed](https://github.com/spectreconsole/spectre.console/issues/2184) | a panel header wider than its content was dropped, not truncated - invisible to 3,618 tests |
| [gson](evals/gson/REPORT.md) | 24,229 | Java | 2 | - | the fastest run: one audit, one gate, one priced-and-declined Low, not a line changed |
| [RuboCop](evals/rubocop/REPORT.md) | 12,892 | Ruby | 7 | - | the null result: every cop department swept, the last 20 commits re-proven, zero findings, zero lines changed |
| [python-dotenv](evals/python-dotenv/REPORT.md) | 8,830 | Python | 73 | [PR open](https://github.com/theskumar/python-dotenv/pull/678) | the grind: 8 runs, 48 findings, seven audits that each filed something before the eighth came back empty; suite 220 to 511 |
| [sqlparse](evals/sqlparse/REPORT.md) | 4,009 | Python | 47 | - | the pre-registered budget was five runs and it took five; the loop declined a finding the gate handed it, after running the claim |
| [PapaParse](evals/papaparse/REPORT.md) | 13,532 | JavaScript | *audit* | [4 PRs open](https://github.com/mholt/PapaParse/issues/1132) | four Highs in the streaming path; conversion waits on four open PRs |

<details>
<summary><b>ranaroussi/quantstats</b> - the deepest run, where the loop and the engine improved each other in public</summary>
<br>

Portfolio analytics whose output goes straight into investor-facing tearsheets, green at 125 tests, hiding **29 findings**. Four budgeted runs, 40 iterations, machine-checked convergence with an evaluator countersignature. The suite ends at **393 passing** and the library ends **smaller than it started** - 570 source insertions against 759 deletions, plus 1,694 lines of tests, every one proven to fail against the unfixed code, which the closing evaluator re-proved wholesale by reverting the source and failing 65 of them in one command. The findings run the whole taxonomy: a process-global cache serving one caller's DataFrame to another caller's Series so a benchmark-free report **poisoned the next report in the same process** (deleting it also made metrics 19.8% faster); two contradictory timezone conventions that made the package **disagree with itself about which year** an Asia/Tokyo return belongs to; `aggregate_returns` silently no-oping on its own documented `'M'`, `'Q'` and `'Y'` so `compare(aggregate='M')` returned daily rows where monthly belong; a montecarlo module whose advertised distribution was a **point mass** - permutation preserves the compound product, so terminal-value std was 1e-15 float noise; `cagr(rf=0.05)` equal to `cagr(rf=0.0)` to eight decimals because a caller-name skip list silently voided the risk-free rate; `make_index` whose `.resample` exists **only in its docstring**; a probabilistic-Sharpe family subtracting an annual rate from a per-observation ratio and subtracting the kurtosis excess **twice**. Each of those classes was caught by an engine rule that did not exist when the previous class was found - the run exposed a sweep bias, the engine shipped a hardened contract, all certifications were re-earned under it, three generations in sequence - and the receipt states the boundary as plainly as the wins: **six convention defects a manual audit of the same commit proved remain at the converged tree**, kelly's scale-invariant sizing and the unannualized information ratio among them, because a known-answer probe verifies a formula and cannot adjudicate which formula the context demands. Convergence is a claim about a contract, and the receipt says exactly which one. Findings were disclosed upstream with repros and a PR offer in [ranaroussi/quantstats#537](https://github.com/ranaroussi/quantstats/issues/537).

</details>

<details>
<summary><b>open-source-parsers/jsoncpp</b> - where the adversarial evaluator caught the loop's own headline fix being half finished</summary>
<br>

The long-standing C++ JSON parser, vendored into a very large number of desktop and embedded projects, and the first C++ target in this set. One run, ten iterations, converged. **7 findings closed (2 High, 2 Medium, 3 Low)**, shipped-code change **5 files, +41/-40**, all **16 surface-inventory rows swept**. The headline is a build-configuration defect with real consequences and it is reproducible in one command on pristine upstream: compiling `60de77f` with the project's own documented `JSONCPP_USE_SECURE_MEMORY=1` fails with `error C3861: 'RtlSecureZeroMemory': identifier not found`. **jsoncpp's secure-memory mode did not compile on MSVC at all**, so every Windows user who followed the instructions for handling sensitive data either never got a build or was silently not getting secure memory; the same fix also widened a wipe that had never covered the full allocated block. A second Medium explains how that survived - **nothing in CI ever built the secure configuration** - and the run added a three-OS job so it cannot recur. A third found MSVC consumers at `/std:c++17` silently receiving a **different public API** from GCC and Clang users, because `string_view` detection ignored `_MSVC_LANG`. But the run's real lesson is iteration 9. With an empty ledger, every row swept and a clean closing audit, the loop invoked the adversarial evaluator expecting to declare convergence, and got **REJECT**: the headline fix was incomplete, because `jsontestrunner` still would not compile under the same flag, leaving the configuration broken as a whole. That became a second High, fixed in iteration 10, and the run converged on its last budgeted iteration. The gate did its work exactly where self-assessment is weakest, on the completeness of the loop's own fix in code it had just written - and it only fit because one iteration happened to remain. The receipt states its limits too: both Highs are the same defect in two places, neither is a parsing bug, the crash class was deliberately left to OSS-Fuzz which has fuzzed this library for years, and seven findings from a 16-row surface is a thin yield that the run declines to inflate. Nothing is filed upstream yet.

</details>

<details>
<summary><b>valyala/fasthttp</b> - the largest target yet, and the first where the baseline was a release tag</summary>
<br>

The HTTP server and client library under Fiber and much of the Go web ecosystem, at **exactly the `v1.73.0` tag** rather than a random master commit, which means **every one of these findings shipped to users**. 160 Go source files, four over 80KB, the biggest surface the loop has ever mapped. Seven runs, 58 iterations, **31 findings closed (6 High, 12 Medium, 13 Low)** in a diff of 46 files, +4,112/-269, of which 3,251 insertions are tests; the suite grew by **57 test functions to 1,311 passing**, and all **40 surface-inventory rows** ended swept. The Highs are the kind that hide behind a green suite in a library whose entire job is parsing hostile bytes: `appendBodyFixedSize` **sizing its allocation straight from the peer's declared Content-Length**, so a default-configured client could be killed by an honest-looking response header; `parseUintBuf`'s overflow guard testing the product against the accumulator, missing the wrap that lands back above it, so `ParseUint` disagreed with `strconv` underneath Content-Length parsing - closed with a differential test against `strconv` over a generated search of 19-to-21-digit values so the two cannot silently diverge again; a directory index **advertising its own broken links** because every href was built from an already-decoded path; and Windows-reserved names accepted on every path segment, settled class-complete at one boundary. Two moments say the most about the discipline. `git log -S` against a pinned test produced **opposite verdicts on consecutive iterations** - revealing a deliberate upstream scope decision in one, sending the finding to Proposed unexecuted, and an incidental undefended choice in the other, clearing the fix - and neither was predictable from reading the test. Then the run hit a **hard blocker it refused to score around**: two inventory rows are Unix-only and will not compile on Windows, so rather than infer them the sweep was executed on a real Linux kernel through WSL, asserting a unix socket's actual mode bits at 0600 and 0666 and watching the kernel spread 40 connections exactly 20/20 across two `reuseport` listeners on the same port. The receipt names its limits too: `govulncheck` was unavailable offline so dependency hygiene rests on version currency; one finding was declined on a judgement call the user delegated; and one pre-existing upstream test was renamed, with its no-disclosure assertion **byte-identical**, its status moved 500 to 404 because the traversal is now neutralized before the guard fires, and a **stronger** assertion added. One finding went upstream and **[valyala/fasthttp#2343](https://github.com/valyala/fasthttp/pull/2343) is merged** - the `parseUintBuf` overflow, chosen over the other thirty because its test asserts only that `ParseUint` agrees with `strconv` about which decimal strings are in range, so accepting it requires no judgement call from the maintainer. It is also the first of these disclosures to draw a review with requested changes, and answering them is the part worth recording. The maintainer measured a **60 percent benchmark regression** and proposed gating the overflow test on the digit index. His diagnosis of the shape was right and the attribution was not: `parseUintBuf` sits at **inline cost 79 against a budget of 80**, the submitted version came to 84 and so stopped being inlined **at all three call sites, including both Content-Length paths in `header.go`** - that, not the added arithmetic, was most of what he measured, and his gate over the unchanged two-comparison body comes to 97, no faster. What fit was his gate plus a single combined test: once `v` is known to be no larger than `MaxInt/10` the product either fits or wraps to `MinInt`/`MinInt+1`, so a sign test settles the rest and the function is back at cost 79 and inlined again. The reply carried the benchstat table for base, reviewed and final rather than a claim of parity - the geomean still runs **19 percent over master**, the fixed-length cases are not recovered, and the PR says so and offers to look again if he preferred parity to the fix. He also caught two things the pull request had wrong: its hostile-value table pinned the bug only on 64-bit, when a 32-bit int accepts `5000000000` as `705032704`, and `strconv.ParseInt` was never the exact oracle because it accepts a leading sign that `ParseUint` rejects. Both corrected - the oracle is now `strconv.ParseUint(s, 10, strconv.IntSize-1)`, the digit gate is derived from `strconv.IntSize` rather than a build tag, and a test checks both directions of that derivation on whatever word size the build targets. Merged as `c3791f8` on 2026-08-02 at **2 files, +116/-7**, and unreleased as of this writing: it lands in the first tag after `v1.73.0`.

</details>

<details>
<summary><b>servo/rust-url</b> - where a class was settled three times, withdrawn three times, and held on the fourth</summary>
<br>

The URL implementation underneath most of the Rust ecosystem - cargo, reqwest, hyper clients, Servo itself. The base commit is **still the tip of upstream `main`**, and it is itself the merge of a drive-letter fix from nine days before the run; the loop was pointed at that neighbourhood cold and found it still wrong in ten places. Three runs, 30 iterations, converged, against a **pre-registered budget of five**. **20 findings closed (10 High, 5 Medium, 5 Low)**, none declined, shipped-code change **6 files, +642/-103**, all **19 surface-inventory rows swept**. The oracle is the web-platform-tests URL corpus vendored in-tree, **1,143 cases**, and beside it `url/tests/expected_failures.txt`, an allowlist naming **67 conformance cases the library did not pass** - published headroom, not hypothetical. That allowlist is also a file the loop can edit, which is the property under measurement, and the target brief written before iteration 1 said the receipt would have to prove which way it moved. It does: both vendored corpora are **byte-identical** to pristine upstream by blob hash, `wpt.rs` is unchanged, **zero lines were added** to the allowlist and exactly one was removed, and the workspace carries the same single `#[ignore]` before and after. The list went **67 to 66** in the only direction it can honestly go. **But the run's real headline is a claim it kept having to take back.** `make_relative` is documented as the inverse of `join` and was not; the loop declared the class fixed and complete **three separate times**, and all three were withdrawn - twice by the adversarial evaluator, once by the run's own closing audit - each time because the *enumeration* behind the claim could not express a shape that still failed: no credentials, then no `file:` URLs, then no `|` spelling of a drive letter, then no authority-presence dimension. It held at the fourth attempt with eleven causes closed. A run that had converged at any of the first three points would have published a false class-complete claim with a green suite behind it. The gate rejected three times in total and **every rejection was a real defect, two of them regressions the run had just introduced into its own fixes**. This is also the first convergence on engine v1.8.0 and it uses two things that release shipped: run 3's gate fired at **iteration 8 of 10 rather than at the declaration** - "a REJECT needs budget to answer in" - rejected, was answered at iteration 9, and passed at iteration 10, a path that did not exist before 1.8.0 made a rejection holding an invocation non-terminal; and both verdicts sit on disk under the ordinal artifact contract the same release introduced, with the second recording that it was told not to defer to the first. **No test was deleted or weakened anywhere**: `url/tests/unit.rs` went 72 to 77 test functions and +612 lines of grid generators, the project's own suite went 14,098 to 14,111 passing, and the only other test-path change in the entire span is the single allowlist line. One finding went upstream and only one - **[servo/rust-url#1147](https://github.com/servo/rust-url/pull/1147)**, +12/-2, which closes **[#889](https://github.com/servo/rust-url/issues/889)**, open since 2023 with no replies. The reason it is the only one is a limit the receipt states plainly rather than a modesty note: nineteen of the twenty findings rest on tests the loop wrote, and `make_relative` has no specification to appeal to. The twentieth does - its evidence is a case in the project's own conformance corpus that fails on their master and passes with the change, and that nobody here wrote or can edit without it showing in the diff. The PR is deliberately smaller than the loop's own commit for the same defect, a ten-line minimal form rebuilt on a clean clone, and the two were checked against each other over a grid of 410 `file:` inputs and `join` pairs and agree on every one. What the run did **not** do is also on the record: 66 of the 67 published conformance defects are untouched, and fourteen of the twenty findings sit in one neighbourhood.

</details>

<details>
<summary><b>nikic/PHP-Parser</b> - told nothing, it went and found its project's largest oracle</summary>
<br>

The PHP parser under PHPStan, Psalm, Rector and php-cs-fixer, and the **tenth language** in this corpus. Three runs, 29 iterations, converged, against a **pre-registered budget of four**. **18 findings closed (9 Medium, 9 Low, zero High)**, shipped-code change **5 files, +233/-41**, all **29 surface-inventory rows swept or disclosed**. This target was selected to answer one question, written down before iteration 1: `test_old/run-php-src.sh` runs the parser over an entire php-src release and is named in no README, no CONTRIBUTING, and nothing but a CI YAML file - would a cold loop find it? **It found it in iteration 1**, downloaded the corpus, ran it to exit 0 over **14,695 files**, swept it as an inventory row and built a probe battery around it. Then it did the harder thing: the Verify command it declared is the unit suite, not the differential, and the declaration **says so in its own words**, listing the php-src corpus, the fuzzer and the PHPStan target as things the gate cannot reach. That is the oracle-declaration gate working, and this corpus already records what its absence looks like - the go-yaml receipt, where a run asserted twice that a 402-case conformance corpus was green while nothing ever executed it. **The best finding is not in the backlog at all.** `Lexer\Emulative` re-implements newer-syntax tokenization for older PHP hosts, and `EmulativeTest` exercises it and passes. The loop worked out that on this host it passes *without executing a single emulator body*: every emulator targets PHP 8.5 or older while the host is 8.5.4, so a probe it wrote reports **0 forward selections across all 9 target versions**. It marked the surface unreachable rather than swept, wrote down that the forward direction is covered only by upstream's CI on PHP 7.4 through 8.4, and refused to score it clean. A green test that grades nothing, found unprompted and disclosed. What it **missed** is on the record too: `test_old/run.php` omits its format-preserving failure counter from the exit guard, so the script prints "All tests passed." and exits 0 with any number of byte mismatches - the loop took the exit status and never audited the exit status itself. The maintainer-side check was pre-registered for exactly that and is published in the receipt: 0 mismatches at the converged tree, so the blind spot never fired. The findings themselves are one class - the library's byte offsets and the columns derived from them disagreed with each other and with PHP's own tokenizer. `Error::getEndColumn()` returned **0** for any range ending on a line terminator; `NodeDumper` carried a verbatim stale copy of the same arithmetic; a filtered run of the project's own gate printed `OK` and then **exited 255**. Nine test files changed, several with deletions, which is the shape a laundered regression takes - so the receipt proves otherwise by arithmetic rather than assertion: `'<?php /*'` is 8 bytes and the base tree reported the error ending at **column 9**, a column that does not exist in it. Every changed expectation moves from an impossible value to a possible one, the suite grew **1,895 to 1,907 tests**, and 30 probe batteries run 2,307 checks with none failing. Both anti-cheat diffs the brief named came back clean: the 21-pattern skip list in `test_old/run.php` is **byte-unchanged**, and the two 197KB generated parser tables that upstream CI never regenerates were never touched. One finding went upstream as **[nikic/PHP-Parser#1162](https://github.com/nikic/PHP-Parser/pull/1162)** - the only one of the eighteen whose evidence sits outside the loop's own judgement, because `doc/component/Lexer.markdown` defines `endFilePos` as the offset of the last character in the node while `Lexer.php` passed the exclusive `getEndPos()`, a contradiction between two files in the same repository that `strlen()` settles. Run 2 is named rather than hidden: it spent ten iterations and never reached the evaluator at all.

</details>

<details>
<summary><b>jkbrzt/rrule</b> - where the reference implementation overruled the loop, and the loop withdrew its own High</summary>
<br>

The RFC 5545 recurrence-rule library behind much of the JavaScript calendar ecosystem, and the second target chosen for an oracle the loop cannot edit. rrule declares itself a port of `python-dateutil`'s rrule module, so a reference implementation of the same specification exists and can arbitrate. Four runs, 33 iterations, converged. **23 findings closed (10 High, 9 Medium, 4 Low)**, shipped-code change **15 files, +589/-193**, all **15 surface-inventory rows swept**. The Highs are dominated by input that failed silently rather than loudly: `fromText` and `fromString` returning the library's default `FREQ=YEARLY` rule for text their parser recognised nothing in, so unparseable third-party input came back as a plausible recurrence instead of an error; `parseText` building its `until` date with `Date.parse`, which reads a date-only string in local time while the rest of the library treats every Date as a UTC wall clock, so the same text parsed to a different rule **on every host**; `rrulestr` resolving its documented `dtstart` and `tzid` options separately in two result shapes so the shapes disagreed and compatible mode crashed; the exported two-letter weekday form serializing to `BYDAY=undefined` so a rule built through the library's own type could not be read back; and weekday tokens validated on the RFC-string path but not the programmatic one, where a bad `wkst` became `undefined` and hung the iterator. **But the run's most important event is a finding it withdrew.** An audit filed H7 as a High: mixing an nth-prefixed `BYDAY` value with plain ones yields no occurrences instead of their union, so `FREQ=YEARLY;BYDAY=+2MO,TU,WE,TH,FR` returns nothing where the RFC's reading gives 211 occurrences in 2020. The reproduction stood up. The next iteration checked the reference implementation before fixing it, and stopped - "python-dateutil returns the same empty result, so this is parity with the library this project declares itself a port of, not a porting error." H7 became a documentation task against the README's existing "Differences From iCalendar RFC" section, plus a Proposed item putting the divergence question to the owner rather than deciding it. All three numbers were re-derived for the receipt: converged tree 0, `python-dateutil` 2.9.0.post0 **0**, RFC union reading **211**. A loop with no referee closes that as a High and ships a behavioural change to a public library. The owner's answer is recorded in the receipt: do not diverge, because fidelity to dateutil is the product and a split would expand the same stored rule to 211 occurrences in a JavaScript front-end and 0 in a Python back-end. Two more things the receipt states rather than hides: the evaluator rejected run 2 and the two Highs that rejection filed took run 3 two iterations to close, one of them inside a class run 2 had recorded as settled; and one High was **self-inflicted**, the loop's own committed artifacts sitting inside the project's format gate so `yarn build` failed, filed against itself and fixed. The project's own suite was never touched - **109 test invocations before and after**, reading 381 passed of 390 at the base commit and at the converged one - so the gate the loop could not edit ran against all 589 inserted lines and reported no regression. Nothing was filed upstream: the repository has been dormant since June 2024 with 212 open issues, and the receipt says so.

</details>
<details>
<summary><b>andialbrecht/sqlparse</b> - the pre-registered budget was five runs, and it took five</summary>
<br>

The non-validating SQL parser behind Django's debug toolbar and a large share of Python SQL tooling, and the third target of the cold cohort. Its oracle is a documented invariant rather than a vendored corpus: sqlparse promises to hand your SQL back unmodified, so round-trip fidelity and format-idempotence are checkable on arbitrary text the loop did not pick. **Five runs, 47 iterations, converged.** **31 findings closed (7 High, 11 Medium, 13 Low)** with **6 more declined on evidence**, shipped-code change **12 files, +345/-156**, all **24 surface-inventory rows swept**, suite **494 to 663 passing**. **This is the receipt where the stopping rule did the work.** `ATTEMPTS.md` fixes a run budget before a target's first iteration, and sqlparse was pre-registered at five runs in a cohort brief written the day it launched, which stated in advance that a target not converged in five runs is published as a non-convergence "exactly as libuv is". Runs 1 through 4 all failed, **two of them ending blocked**, out of evaluator invocations with work still open - the worst ratio of any converged target here. Each rejection came from a *pre-existing* defect the gate's own fresh adversarial hunt turned up rather than from anything a run had broken, which is what a mature parser with 241 open issues does to a fixed budget. Run 5 converged at iteration 8 of 10, on its second and final gate invocation, with two iterations unspent. Seven evaluator rejections across eight invocations preceded that PASS. A stopping rule is only evidence when it could have produced the unwelcome answer, and this one could have, right up to the last budgeted run. The Highs are what a library promising fidelity cannot afford: **a destination file truncated to zero bytes** before the work that could fail, so any error after `open(mode='w')` left the user's file empty; **`format('(as)', reindent=True)` raising `IndexError`** because a parenthesis group holding one token was indexed at `[1]`, four ASCII bytes crashing the library and the CLI printing a raw traceback with no `[ERROR]` line; `format('case where end', reindent_aligned=True)` raising `ValueError` on fourteen characters; `sql.Function.get_window()` raising `AttributeError` on **every** function with no OVER clause, because the guard tested the tuple `token_next_by` returns and `(None, None)` is truthy; and three separate ways `output_format='python'`/`'php'` emitted a snippet that either would not parse or whose value differed from the input SQL. **And the loop threw out a finding the gate handed it.** The run-4 evaluator observed that PLAN.md's baseline sentence "reproduces at neither commit"; the loop filed it as R3, then in run 5 ran the claim before fixing it, extracted the named commit with `git archive` into a scratch directory, got exactly the counts the sentence quotes, and declined it - the gate had measured at two commits the sentence does not name. Unlike go-yaml, the regression evidence went into the **project's own harness**: `tests/` is +506/-7, and of the seven deleted lines four are an `xfail` placeholder while three are a live test's header, renamed and widened in place rather than removed. Verified for this receipt on a clone that never saw the run: `fixes.patch` applies clean to pristine upstream at the base commit and the suite reads **663 passed**, with zero non-`SQLParseError` escapes across 21 crash-shape calls. Two caveats stated rather than buried. **Two findings were independently rediscovered, not found first** - upstream's tracker already carried the `(as)` crash and the CASE crash as [#862](https://github.com/andialbrecht/sqlparse/pull/862), [#863](https://github.com/andialbrecht/sqlparse/pull/863) and [#864](https://github.com/andialbrecht/sqlparse/pull/864), filed three weeks earlier by an unconnected contributor, unreviewed by the maintainer and closed unmerged by their own author. Nothing from this run was filed upstream, because a maintainer who merged five PRs while passing over an equivalent fix to the same function is poor odds for a third attempt. And the patch **removes a public option**: `right_margin` now raises instead of being accepted, on the grounds that upstream's own filter file carried `# FIXME: Doesn't work` with its `keep_together` list commented out to empty, and reviving it properly was filed as a Proposed item for the owner rather than decided by the loop.

</details>
<details>
<summary><b>goccy/go-yaml</b> - the first target picked for an oracle the loop could not rewrite, and the oracle did not move</summary>
<br>

A widely used YAML parser and encoder for Go, chosen for a property no earlier target here had: it **vendors an external conformance corpus**, the 402-case YAML test suite, so its correctness can be judged by something the loop did not write. Three runs, 29 iterations, converged. **20 findings closed (6 High, 10 Medium, 4 Low)**, shipped-code change **13 files, +468/-264**, all **30 surface-inventory rows swept**. The Highs are a single shape - the encoder emitting YAML that does not round-trip: literal block style chosen for strings that style cannot carry, `UseSingleQuote(true)` writing Go escape sequences that YAML does not interpret, `WithSmartAnchor` emitting unparseable documents for pointer-shared values, and a scalar node carrying its own quoted rendering instead of its value, so consumers reading the node got quote characters back as data. Each of those means `Marshal` produced a document that failed to parse or decoded to a *different string*. A fifth bounded parser nesting depth, and the run justified the bound by measuring the deepest document in the conformance corpus at 5 rather than by asserting 1000 was generous. The sixth High is the one worth the receipt: **a regression this run introduced itself**, where a `Path` filter dequoted a mapping key that had been a compensation for the old encoder and became a corruption the moment the encoder started storing raw values. The adversarial evaluator caught it, the loop did not, and the run's own words are "the regression this run introduced is repaired." The gate rejected twice in total; its second rejection caught that a checkpoint's `git add -A` had swept a 5,835,264-byte test binary into HEAD, where it sat for four iterations. **And then the part that earns the whole cohort design.** The conformance corpus **never ran, in any of the 29 iterations**. The run's verify command ended `go test ./testdata -modfile=testdata/go_test.mod`, which looks like a conformance leg and is not one - it runs 47 ordinary tests in a module that merely lives under `testdata/`, while the only file importing the corpus is build-tagged `//go:build !windows` and never compiled on the host. Two journal entries say the corpus was green, and the evaluator countersigned both. Scored independently for this receipt at both trees: **355 passed, 0 failed, the same 47 excluded, before and after** - 468 inserted lines of product code moved the external oracle by exactly nothing. The 20 findings may all be real; none of them was a conformance defect, and the instrument that could have found one was dark. Getting that number required fixing two defects in the target's own harness that the loop never saw: the printed pass rate is `total - len(failureTestNames)`, arithmetic over a constant that reported `passed:[355]` while 389 subtests failed, and the corpus loader hardcodes `/` in its path trim so every case name on Windows becomes an absolute path and the known-failure list stops matching. The one-line `filepath.ToSlash` fix went upstream as [goccy/go-yaml#915](https://github.com/goccy/go-yaml/pull/915), and it is **not a loop finding** - it was found verifying this receipt and is never counted as the loop's. The receipt states one more limit plainly: the project's own suite has **144 test functions before and 144 after**, because all 6,871 lines of the run's regression evidence live in `.jeffy/probes/` rather than in the project's harness, so a maintainer applying `fixes.patch` gets the fixes with almost none of the tests that prove them. None of this needs taking on trust: [`reproduce-conformance.sh`](evals/go-yaml/reproduce-conformance.sh) in the receipt clones pristine upstream twice, applies the patch to one copy, measures both conformance scores, and fails unless they match the published figures - about a minute, on any machine with `git`, `go` and `bash`.

</details>
<details>
<summary><b>kennethreitz/records</b> - four High data-loss bugs hiding behind a green test suite</summary>
<br>

At upstream HEAD, `pytest` says 31 passed. At the same HEAD, `INSERT`s silently lose data, `transaction()` swallows every exception, and every query leaks a pooled connection. Jeffy reproduced **four High-severity bugs hiding behind a green test suite**, closed three with one structural fix at the boundary they share, restored a fix upstream had reverted the same day it was made, and left a regression suite proven to fail on the old code - [`repro.py`](evals/records/repro.py) shows the bugs on upstream HEAD, [`fixes.patch`](evals/records/fixes.patch) makes it show them fixed. Findings were disclosed upstream with repros and a PR offer in [kennethreitz/records#236](https://github.com/kennethreitz/records/issues/236).

</details>

<details>
<summary><b>PyPortfolio/PyPortfolioOpt</b> - the run where the gate proved it cannot be bluffed</summary>
<br>

Portfolio optimization with its own CI red on the default branch: six runs, 58 iterations, the suite from **5 failed to 356 passed**, and **37 findings filed, 36 closed, five of them High** - `bl_weights()` **inverting every position** whenever the implied portfolio is net short, `min_cov_determinant` understating variance by more than half, the tail-risk classes reporting a CVaR **overstated by up to 50.7%** against the very weights they returned. The adversarial evaluator rejected **five convergence attempts before its PASS**, every rejection filing real work - and in run 5 it passed and the run *still* refused to converge over a defect the evaluator had just found in the run's own work: "the gate is worth more than the convergence line." The Stop hook then rejected the first declaration too, and convergence landed only when every gate held at once. The receipt is honest in both directions: a 13-check repro from an earlier manual audit of the same commit scores **8 of 13** at the converged tree - three **distributional defects** remain, named plainly - while the loop filed 32 findings that audit never saw. Findings were disclosed upstream in [PyPortfolio/PyPortfolioOpt#750](https://github.com/PyPortfolio/PyPortfolioOpt/issues/750), and the CI-red fix went up as [PR #751](https://github.com/PyPortfolio/PyPortfolioOpt/pull/751) with a regression test proven to fail on their master.

</details>

<details>
<summary><b>iamkun/dayjs</b> - the run that named the third boundary</summary>
<br>

The date library, 63M downloads a week: eight runs, 74 iterations, the suite from 773 tests to **1,230 with the 100 percent line-coverage bar held**, and **45 findings closed, 10 High** - the core parser reading ISO fractional seconds as an integer count of milliseconds so `.5` meant 5ms; a failed build that **reported success straight into the publish workflow**; the Sinhala locale shipping lunar month names so every `si` date named the wrong month; December parsed in one of 12 two-arm locales landing in **the following year**; format-then-parse round-trips coming back 12 hours off. Fourteen defect classes settled with enumerations over all 143 locales, all 181 bundle entries, and **40 shipped declaration files no compiler had ever checked**. The adversarial evaluator rejected three times across the conversion - one rejection surfaced a High and a Medium the run had introduced itself - and the closing run's audit reversed its predecessor's wrong "blocked" verdict with a deterministic instrument before converging. The receipt's boundary is the starkest yet: the earlier manual audit's five-check timezone repro scores **1 of 5 at the converged tree, the identical score pristine upstream gets**, because the loop never entered the timezone plugin - single-host probes cannot see **host-environment defects**, the third boundary class after quantstats' convention defects and PyPortfolioOpt's distributional defects, and the receipt proves it by running the full suite under a real Whitehorse host, where the converged tree fails the same 4 timezone tests upstream does. First disclosure went upstream as a pull request rather than an issue - the channel a 968-issue backlog is most likely to read: [iamkun/dayjs#3167](https://github.com/iamkun/dayjs/pull/3167), the one-line fractional-seconds fix, with a regression test proven to fail on their dev.

</details>

<details>
<summary><b>janl/mustache.js</b> - revived a test suite that could not start</summary>
<br>

At upstream HEAD on current Node, the test suite **cannot start** - the abandoned `esm` shim crashes before a single assertion - and `bin/mustache` crashes outright. Jeffy revived the gate with one structural fix across all three loading sites, fixed a second reproduced correctness bug in the CLI with a regression test, deleted the dead browser-test stack, and modernized the toolchain, taking `npm audit` from **107 vulnerabilities (24 critical) to 2 lows** with the suite at 297 passing, official Mustache spec compliance included. The closing audit then filed a Medium against the run's own earlier work - docs still pointing at the deleted stack - and fixed it before declaring convergence. Findings were disclosed upstream with repros and a PR offer in [janl/mustache.js#848](https://github.com/janl/mustache.js/issues/848).

</details>

<details>
<summary><b>bukosabino/ta</b> - the hardest target, and the run that caught its own regression</summary>
<br>

Technical-analysis indicators, dormant since 2023, no GitHub Actions run ever, and a test suite already **red at upstream HEAD**. Six runs and 64 iterations, every one checkpointed. Parabolic SAR mixed label-based and positional writes on the same Series, so on the project's own quickstart path it returned **46,465 rows for a 46,306-bar input**, 9,408 of them wrong, worst error 3,410.89. On-Balance Volume adds volume on bars where the close is unchanged, against the definition its own docstring cites: 85 of 399 bars are flat on real data and the series ends at **1631.93 against 533.44**, a 205.9 percent error that compounds monotonically, invisible because the fixture has no flat bar in its 30 rows. Fourteen defect classes were closed **class-complete**, each with an enumerating check over all 43 indicator classes rather than a patched instance, and three findings were **declined** - one because the premise was wrong and extending the loop as the task asked raised `KeyError: 120`. It caught itself: a seeding change it made at iteration 6 turned KAMA into a constant, and its own audit found it ten iterations later and wrote *"It is mine"* - after a green suite, 100 percent line coverage and a targeted sweep had all passed over the defect, because "no NaN and no infinity" is satisfied by a constant. It then ran the CI documentation job, which four jobs of config had defined and **nobody had ever executed**, and when that surfaced two trivially fixable warnings in code untouched since the convergence commit it refused to fix them, routing both to Proposed because the ratchet rule said so and, in its own words, fixing them unasked "would have been the rule bending to convenience." Final state: **134 tests with 2 errors to 211 passing**, coverage 100 percent of 1,388 statements, `prospector` at `veryhigh` clean across both trees with all eight tools. It wrote **2,112 lines of tests against 958 lines of source changes**. The adversarial evaluator gate did not run - that session carried a standing instruction against sub-agents, and the receipt records it as `unavailable` rather than papering over it. Findings were not disclosed upstream: the project has been dormant since 2023 with red CircleCI on HEAD and no merged pull request in over two years.

</details>

<details>
<summary><b>sharkdp/bat</b> - the security flag that did nothing when piped, caught before release</summary>
<br>

The syntax-highlighting `cat` replacement, at nearly 60,000 stars the most-starred target in this set, and the first chosen fresh, with no earlier audit to lean on. One run of ten iterations, converged. The loop aimed straight at the newest surface: upstream had just merged `--sanitize`, a defense against escape-sequence and Unicode-spoofing attacks, and the first audit found it **completely inert whenever output is piped** - the exact context sanitization exists for; `bat --sanitize=always evil.txt | cat -v` reproduced raw ESC and CR bytes verbatim. The fix showed restraint: an upstream test pins `--strip-ansi`'s passthrough as deliberate design, so that contract stood and the asymmetry went to Proposed rather than being overturned. Then the run's own iteration 4 audit caught that fix corrupting UTF-16 files into U+FFFD soup, owned it in the journal - *"a regression I introduced"* - and repaired it with the interactive printer's own decoding plus a BOM edge case found on the way. Also closed: 3 of the 12 Unicode Bidi_Control codepoints passing through a sanitizer whose help text promised bidi coverage, settled **class-complete** with a test that enumerates the full set and a proof that ordinary Arabic sharing the 0xD8 lead byte survives; and a `--language` typo silently ignored whenever color was off. **4 findings closed in a +195/-32 diff, eight new tests - five proven to fail against the unfixed code, three pinning contracts that had to survive - and 419 passing at the converged tree.** The adversarial evaluator PASSed with byte-level probes beyond the run's own checks - truncated multibyte at EOF, lone lead bytes, 8-bit C1 CSI, binary input - and the Stop hook rejected two declarations for prose on machine-read lines, the fourth project in a row, both repaired against the hook's own parser on a code tree unchanged since its certified commit. Every fix was re-proven red-green by an independent post-run review. Findings were disclosed upstream and **merged the same day**: the bidi-completeness fix landed as [sharkdp/bat#3862](https://github.com/sharkdp/bat/pull/3862) before the feature's first release, approved with zero requested changes, its enumerating test proven to fail on their unpatched master; the piped-path fix stays local, upstream having recorded loop-through passthrough as intended when they built the feature.

</details>

<details>
<summary><b>ranaroussi/yfinance</b> - the leanest conversion and the sharpest mirror</summary>
<br>

The market-data client, converged in a single run of nine iterations **at the exact commit the earlier audit examined**. The design test passed unprompted: yfinance's suite hits live, rate-limited Yahoo, and the loop's first audit scoped itself an offline verify gate, proved the tree **byte-identical to the published sdist**, and later caught its own probes importing the wrong installed copy and re-ran everything pinned. Three findings closed in a **+40/-9** diff, led by a **High that upstream's own suite had been advertising**: `Ticker('DJI').dividends` returns None where the shipped `test_badTicker` demands a Series - the contract test fails on unmodified upstream - closed at the single cache boundary all three action getters share; beside it, a config layer that silently swallowed unknown option names, whose class enumeration flushed out a latent dead-key toggle. The comparison runs in three corners: the earlier audit's 16-case repro scores **3 of 16 at the converged tree, identical to pristine upstream**, because the audit built synthetic corruption scenarios the shipped fixtures do not express - a sweep certifies what its corpus can express, the fourth boundary instance - and **two of the thirteen surviving defects are already upstream as [PR #2927](https://github.com/ranaroussi/yfinance/pull/2927)**, filed from the audit engagement with regression tests proven red on their dev. Findings were disclosed upstream in [ranaroussi/yfinance#2924](https://github.com/ranaroussi/yfinance/issues/2924), where a collaborator engaged and green-lit the pull request.

</details>

<details>
<summary><b>sivel/speedtest-cli</b> - the restraint case</summary>
<br>

Dormant since 2021 but fundamentally sound, where the honest outcome is small findings and nothing invented. Jeffy fixed the project's own lint gate - red on unchanged code from eight Python 2 builtin false positives - with one structural config change and zero `noqa` comments, removed a dead Travis badge advertising CI that had not run in years, and routed the decisions it had no right to make - the Python version floor, the CI replacement, the hostile-server parsing posture - to the owner under Proposed. The sandbox's unreachable live-network test legs were recorded as an environment limitation, never counted as a finding. Findings were not disclosed upstream: the repository does not accept issues, so the offer-first channel the other disclosures used does not exist here.

</details>

<details>
<summary><b>chalk/chalk</b> - the control, and the one that got fixed upstream</summary>
<br>

One of the best-maintained small libraries alive, chosen to test whether the loop invents problems where there are none. The core survived clean: correctness, security and architecture all scored None on first pass, vendored code was declined rather than churned, and a semver-major engines bump was routed to the owner instead of seized. The audit still had teeth, surfacing one genuine reproduced Medium - `ansi256` skips level downconversion, contradicting the readme's promise. Findings were disclosed upstream with repros and a PR offer in [chalk/chalk#686](https://github.com/chalk/chalk/issues/686) - a chalk contributor reproduced it independently and called it surprising that it had not surfaced sooner given how heavily chalk is used, the project owner then wrote and merged [#687](https://github.com/chalk/chalk/pull/687) implementing exactly that fix, and it **shipped in [chalk v6.0.0](https://github.com/chalk/chalk/releases/tag/v6.0.0)**.

</details>

<details>
<summary><b>spectreconsole/spectre.console</b> - the header that vanished instead of truncating</summary>
<br>

The .NET console-rendering library, and the eighth language in this set. Eight iterations, converged, with **one genuine Medium**: `Panel.Measure` never accounted for the header's width, and the header renders through a `Rule` that discards a title it cannot fit - so `new Panel("x").Header("HDR")` produced a panel with **no header at all**, dropped rather than truncated. It survived a **3,618-test suite** because every header test used content wider than the header, or a constrained width where truncation is the intended result; the unconstrained case where the header is the widest element had no test, and the run's surface inventory is what pointed at it. The fix is **14 insertions and 1 deletion in one file** and it is verified in this receipt against pristine upstream rather than the loop's own tree: the regression test fails on the upstream commit and passes with the patch, with **753 tests green and not one existing snapshot altered** - including `Render_Header_Collapse`, which asserts the collapse behavior that an explicit width, `Expand`, or a narrow parent must still produce. The run's other 22 inventory rows came back clean against 22 committed known-answer batteries, and the receipt calls that thin yield what it is. The adversarial evaluator ran 19 edge probes of its own - markup headers, CJK width, boundary-fit cases - before countersigning. The finding was disclosed upstream with the rendered before/after and a PR offer in [spectreconsole/spectre.console#2184](https://github.com/spectreconsole/spectre.console/issues/2184), raised as an issue first because the project asks for maintainer buyoff before a pull request.

</details>

<details>
<summary><b>google/gson</b> - the fastest convergence, on a freshly swept field</summary>
<br>

The seventh language in this set, and the shortest run in it: **two iterations**, one full audit and one evaluator gate, converged at the upstream master tip of the run day. gson was chosen for the same engagement evidence as RuboCop - its maintainer had merged four outside correctness fixes that same week - and that evidence explains the outcome: the commits immediately under the baseline are those fixes, so the field had just been swept, and this run certifies that what remained held. **Zero High, zero Medium; one Low** - the benchmarks module's Caliper 1.0-beta-3 dependency, unmaintained since 2015 - **filed and declined with its cost stated** under the engine's pricing rule, because migrating a no-runtime-users module to JMH exceeds one iteration. Not a source, test, or build line changed. The single audit swept a 17-row inventory - 128 surefire test classes green across four modules, the JPMS and shrinker assertions run with their required packaging, the adversarial JSON path read at source level - and the GraalVM native-image harness, which cannot run on the host, was marked unreachable in the record rather than silently skipped. The evaluator improved a null result: it re-proved the tree byte-identical to upstream, re-ran every suite, and caught two bookkeeping errors in the audit's own record, both corrected without rewriting history. Findings were not disclosed upstream: the sole finding is a declined Low in a benchmarks-only module.

</details>

<details>
<summary><b>rubocop/rubocop</b> - the null result nobody picked to be clean</summary>
<br>

Ruby's standard linter, the sixth language in this set, chosen for the opposite reason chalk was: its maintainers merge outside bugfix PRs daily, so it was expected to yield findings. It yielded none, and the receipt's value is how that nothing was earned. One run, seven iterations, converged at the upstream master tip of the run day - **zero findings at any severity, zero lines of project code changed**; the certified tree differs from upstream by loop bookkeeping alone, so there is no fixes.patch, only the record. The sweep behind the claim: all 21 inventory rows, every cop department (Layout 100, Lint 157, Style 300, plus seven more) against the project's 33,546-example known-answer suite, live end-to-end probes of the CLI, config, server, and LSP surfaces - and, because a commit that co-edits code and specs is certified only by tests written by the same hand, the loop **individually re-verified the last 20 upstream commits with 16 live probes**, three of them differential autocorrect comparisons proven byte-identical. The adversarial evaluator re-ran the full suite fresh, reproduced four audited claims with its own probes, hunted with invalid UTF-8 and null-byte source, and passed it on the first invocation. The receipt states the limits as plainly as the result: the verify gate exercises the Parser engine only, so Prism-specific behavior is out of scope, and a null result certifies the surface examined, not the absence of bugs. Findings were not disclosed upstream: there are none.

</details>

<details>
<summary><b>theskumar/python-dotenv</b> - the grind, and the one that was published as a failure before it converged</summary>
<br>

The library that loads `.env` files for a very large share of the Python ecosystem, and **the deepest grind in this set: eight runs, 73 iterations, 48 findings closed with none declined, 13 defect classes settled**, suite from **220 tests to 511**, shipped diff 13 files at +2,185/-143. It is also the only receipt here that was **published as a failure first** - through four runs and 25 findings this table said *not converged*, and said so on the front page, because every full audit it ran kept finding something new. Seven audits filed. The eighth came back empty. Somewhere around the fifth, this stopped looking like software and started looking like a honey badger: told no, repeatedly, and entirely unbothered. Convergence landed at `1a4e4d0` on the **first** evaluator invocation of its final run, with an iteration of budget and a gate invocation unspent - one run after its predecessor died **blocked**, out of evaluator invocations, with three fresh Mediums it had no budget left to answer. The findings are the kind a `.env` library cannot afford. `set_key(quote_mode="never")` interpolated values raw, so a `#`, a leading quote or an embedded newline read back as something else while the call returned success - a 4,000-value seeded fuzz measured 927 round-trip failures in that mode against one apiece in `always` and `auto`, all 927 of them returning success, and the newline case is a `.env` **injection primitive** that writes an attacker-chosen second variable. A **UTF-8 byte-order mark was silently deleted from every file the library rewrote**, and the fix went in at the invariant rather than the byte: the parser now yields the mark as a binding of its own, so joining every binding's original reconstructs the input exactly. The **io layer, not the parser, was deciding what a line ending is** - Python's default newline translation destroyed CRLF inside quoted values and rewrote whole files to LF - closed at all four stream boundaries with the rule that a new binding inherits the file's own terminator. On a full or quota-limited filesystem `set_key` raised `OSError` with `filename=None`, **naming nothing at all**, and left a temporary file at mode 0600 holding a partial copy of the secrets it was rewriting. And the CLI reported the wrong subject entirely: `dotenv run ./script.sh` on a non-executable printed `Error accessing env file`, which the fix separated by asking whether the error names the env file, a discriminator the library's own error-renaming work had already made true and which was then executed over five spellings of the same path. The receipt is also where a finding gets **retracted**: the loop claimed the `${VAR:-default}` behaviour contradicts the README's precedence list, independent verification showed the README's own definitions make the current behaviour correct, and the claim is withdrawn in the open rather than dropped. Two engine lessons came out of this target and neither is flattering. Run 3 produced the first live firing of the one-time +2 closing extension and exposed its flaw - the audit inside the extension window filed new work, so the +2 bought work instead of ceremony. And the run-6 rejection taught the sharper one, in the loop's own words: *an enumeration of the sites where a defect class lives must be built from what can fail, not from what is written in the source* - a `grep` for the temporary file's name found three failure sites and missed both the `open` before them and the implicit close at the `with` exit, so the checks written from it certified a class that was half open. Run 7 rebuilt that register from the function's **code object** rather than its text, 45 compiled lines and 11 failing steps, and immediately found a twelfth nobody had listed. The closing evaluator scored **zero High, zero Medium and zero Low**, then earned the number this whole grind rests on: restore the final run's three source files to the base commit and **exactly 10 tests fail, all 10 of them that run's own new tests, 501 still pass, with zero deletions anywhere under `tests/`** - nothing was weakened to reach green. It went further than re-reading the diff, running a **911,250-case differential** on `resolve_variables` across every name permutation, fifteen value shapes, five environment seeds and both `override` settings, and finding zero mismatches. One finding is disclosed upstream: [theskumar/python-dotenv#678](https://github.com/theskumar/python-dotenv/pull/678), `set_key` rejecting a key it cannot write faithfully.

</details>

<details>
<summary><b>mholt/PapaParse</b> - the last audit standing, with four pull requests in flight</summary>
<br>

The CSV parser, 14.3M downloads a week. Four High findings in the streaming path: a multi-byte UTF-8 character split across a chunk boundary decodes to `U+FFFD`; the line ending is guessed from a truncated first chunk and then cached for the whole file, leaving a stray `\r` on every last field with no error and a correct row count; header dedupe re-runs on every resumed row and rewrites data in place; and `pause()` applies no backpressure at all, so a 400 MB stream dies with a heap out-of-memory while the unpaused control finishes at 78 MB. The quoted-field chunk-boundary case, the one most likely to be broken, was tested exhaustively and found **correct**, and is kept as a guard. Findings were disclosed upstream in [mholt/PapaParse#1132](https://github.com/mholt/PapaParse/issues/1132); a collaborator asked for one pull request per issue with a test for each, and the four High findings went up as [#1133](https://github.com/mholt/PapaParse/pull/1133), [#1134](https://github.com/mholt/PapaParse/pull/1134), [#1135](https://github.com/mholt/PapaParse/pull/1135) and [#1136](https://github.com/mholt/PapaParse/pull/1136), each carrying a regression test proven to fail on master. Its conversion to a loop run waits deliberately until those resolve, so the loop is not auditing its author's own pending patches.

</details>

Disclosure is deliberate and selective. Filing a machine-generated issue costs a maintainer real attention, so these findings go upstream only where the defect is severe and the project takes outside contributions; where nothing was filed, the receipt says so and why.

**What is not in the table above is in [evals/ATTEMPTS.md](evals/ATTEMPTS.md):** every target ever started, the runs each one cost, which of three convergence standards it met, and the one public target that was abandoned without a receipt. Convergence here is per-run and a blocked run gets relaunched, so run counts are published with the wins attached rather than a bare success rate. Targets from here on carry a pre-registered run budget committed before their first iteration.

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
3. **Stops for a reason and reports.** Convergence - a clean audit, an empty ledger, a fully swept inventory, the adversarial evaluator's PASS, all re-checked in shell by the Stop hook - or the budget, a stall, a hard blocker, or your cancel. The run report lists tasks closed with severities, the diffstat, rows swept of rows total, and anything waiting on your decision.

### Use several short runs, not one long one

A budget is a ceiling, not a target, and the practice that produced every receipt here is the same one worth copying: **run `/jeffy 10`, let it finish, close the session, then open a new one and run `/jeffy 10` again.** The receipts that took 40 or 58 or 74 iterations got there as four to eight budgeted runs, never as one enormous budget.

That is not superstition about round numbers. The loop is built to start each iteration from written state - `PLAN.md`, `BACKLOG.md` and the last few journal entries - precisely because a fresh reading of the record is more reliable than a long conversation's memory of it. Inside a single session, though, that conversation keeps growing: every audit, every diff, every command output stays in context, and the loop ends up reasoning over its own accumulated transcript instead of the files it was designed to reason over. A new session throws that away and forces it to re-read what it actually wrote. The receipts bear the cost of skipping this out: in the python-dotenv run, later runs kept filing Highs and Mediums on surface that earlier runs had already swept and scored clean.

The restart also gives you the natural review point. Between runs the tree is committed, the report is written, and the handoff names what comes next, so it costs nothing to read the journal, answer anything filed under Proposed, and decide whether to keep going. And because every journal entry is stamped with the run that produced it, a bug introduced in run 3 stays attributable to run 3 rather than dissolving into one undifferentiated log.

Nothing breaks if you hand it a bigger budget. The state files persist, the ratchet skips a re-audit on an unchanged tree, and a fresh run picks up exactly where the last one stopped. Short runs are simply how you get the loop's design working for you instead of against it.

Jeffy built this repository by running on itself, and that convergence is re-earned, not archived - every fresh run has to reach it again with fresh evidence. It last did on 2026-07-31, the day after v1.5.0 shipped, running Fable 5 at x-high effort: the opening audit filed three Mediums against the repo's own trust-model and check-count claims, one iteration each fixed them, and the stop still had to be earned. The dev journal stays out of the published tree, since state files are the loop's memory rather than the product, but the closing sequence, abridged, shows the texture of a converged stop:

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

## The rules a run lives by

Each rule is enforced by the iteration prompt, the state files, or the Stop hook itself - not by good intentions.

**Every iteration**

- **One verified task per iteration.** Every task carries a runnable acceptance check; done means the check ran and passed. Three failed fix attempts mark the task blocked with a reason instead of thrashing.
- **Checkpoint everything, push nothing.** Every iteration ends in a local commit prefixed `jeffy:` - the revert and recovery unit. No pushes, no branches; pre-flight warns on a dirty tree so your work is never swept into a checkpoint. Without git, checkpoints degrade to journal-only discipline.
- **The verify gate guards every change.** An iteration that newly breaks the verify command recorded in `PLAN.md` is reverted on the spot and its task marked blocked.
- **Interrupted work is salvaged, never discarded.** A run that resumes over a dirty tree commits the salvage before touching anything.
- **Every iteration answers for its hygiene.** Between iterations the hook checks the journal entry (heading grammar, with a run token telling two runs in one session apart), the checkpoint, and that `JOURNAL-archive.md` only ever grows. Violations ride the next re-feed as an ITERATION HYGIENE note.
- **Stalls end runs before budgets do.** Progress means a path outside the loop's own memory moved - anything but `PLAN.md`, `BACKLOG.md`, `JOURNAL.md`, `JOURNAL-archive.md`, `.jeffy/`, and the two files under `.claude/` the loop and the harness write for themselves - or `BACKLOG.md` changed. A checkpoint commit is not progress on its own, which is the point: the engine commits every iteration, so a gate that watched HEAD watched itself. The first flat iteration re-feeds with a STALL note; a second consecutive one ends the run from shell. The convergence sequence is exempt, because a closeout audit, the evaluator gate, a ratchet and a wrapup legitimately touch state files only - and the exemption is capped at three consecutive iterations, the length of that sequence, because the entry type is eleven characters the run writes about itself. Without git the ledger signal alone decides.
- **The hook does the budget arithmetic.** Every re-feed carries a RUN STATE line the engine counts itself - the iteration and how many remain after it, open tasks per section, unswept rows - and once the ledger is empty over a swept surface it adds what the convergence sequence still costs, so a run plans its endgame instead of discovering it at the last iteration.

**Every audit**

- **Audits work from a written map, never from wandering.** The first audit lists the whole public surface as a checkbox inventory in `PLAN.md` and probes it breadth-first before filing anything. Every sweep records the commit it certified, a row reopens when its code changes, dimension scores claim only swept rows, and no run converges while a row is unswept.
- **Sweeps prove correctness, not liveness.** A row that computes values needs a known answer or a strong invariant - run-without-crashing certifies nothing - and every documented parameter must be shown to change the output at two or more values. A parameter whose value changes nothing is a finding, never a pass.
- **Instruments are kept, not rebuilt.** A row's known-answer battery lives under `.jeffy/probes/` and the checkpoints commit it, so a re-sweep re-runs the battery instead of reconstructing it, and a battery is updated in the same iteration as the behavior it pins.
- **Every finding is classed by the files its fix will touch.** Backlog lines are written `- [ ] ID (Severity, class, dimension): finding. Acceptance: check.` with a class of runtime, test, build-ci, docs, or dev-tooling, and a section is ordered by severity first, then runtime ahead of the rest, because shipped behavior is what a user meets and perimeter work is what a run drifts into.
- **Severity comes from the envelope, never from imagination.** Envelope changes and audit escalations go to the Proposed section of `BACKLOG.md` for your approval - the loop never widens its own mandate.
- **Changes are made with the map open.** Before touching shared code the loop reads its callers and the tests that pin it and states the contract the change preserves; a change that alters behavior updates the documentation and reopens the affected inventory rows in the same iteration.
- **The third strike forces structure.** Repeated-idiom fixes must enumerate and cover every sibling site; the third finding sharing one root cause forces a single structural fix or a user decision, never a fourth spot patch.

**Convergence**

- **Convergence is sticky.** The converged commit is recorded; relaunching on an unchanged tree re-verifies and re-converges in O(1) instead of re-rolling the audit dice. A seeded backlog or a focus directive always gets a real run, and settled defect classes are never re-litigated on unchanged code.
- **Convergence needs the adversarial evaluator's signature.** One fresh-context sub-agent that assumes the work is broken re-runs the checks itself, bound by the same envelope and evidence rules. It runs the iteration the ledger first empties - given a clean full audit on the record and three or more iterations left - while a rejection can still be answered. At most two reviews per run, three when the first landed before the budget's midpoint, and the cap is absolute - the gate cannot be worn down by persistence. What ends a run is a rejection with no review left, not the second one as such; a terminal rejection then spends the rest of the budget closing the findings the gate filed and ends blocked, deferring the declaration to the next run's fresh gate rather than forfeiting iterations that were already paid for. A session that cannot spawn sub-agents records the reason and ends blocked - the gate is never skipped and never waived. The ratchet never invokes it.
- **The converged stop is enforced in shell.** At the promise the Stop hook itself re-checks: a ledger that exists and lists no open task, a Converged line whose commit is reachable from HEAD and still certifies the tree, no unswept inventory row, a verify command that has declared its oracle class and the targets this platform excludes, an evaluator PASS in the run's closing journal entry backed by the gate's committed artifact at its highest invocation ordinal, and the project's verify command exiting 0, re-run by the hook under a timeout (240s default, `verify_timeout_seconds` to override) enforced by `timeout`, `gtimeout`, or a shell watchdog, so the bound holds on a host with no GNU coreutils. Violations block the stop and re-feed the evidence, and a violation that lands once the budget is spent buys one corrective re-feed - the run is told to record the refusal and close without claiming convergence, rather than the refusal going only to stderr where nobody reads it. One bound is worth stating because the engine does not deliver more: where a closing-extension gate has already ended the run for its own stated reason, that gate wins and the refusal is not re-fed. Genuinely missing infrastructure - no `PLAN.md`, no `Surface inventory` section - fails open with a stderr diagnostic; a missing ledger or journal does not, because every gate reads them.

**Always**

- **Published code is run code.** Anything that leaves the project - an issue body, a report, a pull request - must have been executed in exactly the form it is published. A trimmed version of a verified script is new, unverified code.
- **Lessons persist.** An operational rule learned the hard way - a build quirk, a command that must not be used - is promoted to the Lessons section of `PLAN.md`, which every future iteration reads in full. Add your own lines there to steer future runs: fix the loop, not the run.

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

Both installers run non-interactively against sandboxed profiles (skills and engine must land, and the hook registration must appear exactly once even after a re-run and carry the 600s timeout, whether written fresh or upgraded from an older entry), and the Stop hook itself is exercised through its full lifecycle: mid-budget re-feed, budget exhaustion, completion promise, foreign-session isolation, and the no-state no-op. The gates that guard the converged stop are held to the same standard - an open task, a `Converged` line that no longer certifies the tree, an unswept Surface inventory row, and a verify command that is red, that overruns its timeout, or that is declared `none` each have to produce the right outcome, a fully swept inventory and a pre-inventory `PLAN.md` are both accepted, and the verify parser is proven on the one shape the hook executes, the labelled `Command:` line - backticks stripped only when the wrapping pair is unambiguous, an annotated line named as a `bash -n` defect before anything runs, and a section carrying no command skipped with a note rather than run as prose - as are the per-iteration hygiene gates and the fail-open paths for a missing ledger, journal, or plan, a malformed counter, and a moved prompt file. The two newest gates get the same treatment: the closing extension has to be granted once at exact budget exhaustion over an empty ledger and a swept inventory and refused everywhere else - a task still open, a row still unswept, a flag already set, a frontmatter that never closes, an iteration already past its budget - and a declaration must be rejected when its closing entry records no evaluator verdict, accepted on `Evaluator: PASS` backed by this run's committed evaluator artifact, rejected when that artifact is missing, belongs to another run, or sits uncommitted in the tree, rejected outright on `Evaluator: unavailable`, exempt for a ratchet, and failed open when the journal holds no entry for the run. The hygiene gates are proven both ways too: a journal heading that names the session but not the run is rejected and a legacy state file without a run token falls back cleanly, and a rotation that shrinks or deletes `JOURNAL-archive.md` is caught while an appending one passes and a never-rotated project is left alone. The stall gate is proven the same way, and from 1.7.0 against the engine's own commit behaviour rather than against synthetic state: progress on either signal stays silent, the first flat iteration draws the STALL note and arms the flag, the second consecutive one ends the run, progress resets the strike, a non-git project stalls out on the ledger signal alone, a project with neither signal skips with a stderr note, and neither budget exhaustion nor a valid promise is disturbed by an armed flag. The commit-driven cases are the ones that matter, because the loop checkpoints every iteration: two journal-only iterations that each committed draw the note and then end the run, a battery-only iteration under `.jeffy/` draws it too, a committed `.claude/settings.local.json` and a tracked loop state file are read as harness churn rather than progress, a one-line source change committed alongside the state files stays silent, all four ceremony types are exempt and carry the flag through untouched while a fourth consecutive one draws the note and a fifth ends the run, a stale entry heading at a desynced index does not exempt the entry that replaced it, a state file with no run token gets no exemption at all, a recorded head this repository cannot resolve fails open, a repository that disappears mid-run falls back to the ledger, and a forfeited closing extension is named on the way out. Both tree gates are also proven in a project that sits below the repository root, where git reports paths from the repository root and every filename the two exclusion lists carry is anchored at the project root.

</details>

Core checks need only bash and coreutils; shellcheck, PowerShell, and jq passes skip cleanly when absent. CI runs the same validator on Linux, Windows, and macOS - the macOS leg exists because BSD userland differs from GNU in `sed`, `grep`, and `stat`, and nothing exercised it before.

## License

MIT
