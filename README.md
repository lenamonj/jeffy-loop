<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="media/banner-dark.png">
  <img src="media/banner-light.png" alt="Jeffy Loop - point it at a project, give it a budget, come back to a better codebase and a report" width="900">
</picture>

[![Validate](https://img.shields.io/github/actions/workflow/status/lenamonj/jeffy-loop/validate.yml?style=for-the-badge&label=validate&logo=githubactions&logoColor=white)](https://github.com/lenamonj/jeffy-loop/actions/workflows/validate.yml)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Skill-D97757?style=for-the-badge&logo=claude&logoColor=white)](https://claude.com/claude-code)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Mac%20%7C%20Linux-0EA5E9?style=for-the-badge)
[![License: MIT](https://img.shields.io/badge/License-MIT-22C55E?style=for-the-badge)](LICENSE)

**[Quickstart](#quickstart)** &nbsp;·&nbsp; **[Usage](#usage)** &nbsp;·&nbsp; **[What makes it different](#what-makes-it-different)** &nbsp;·&nbsp; **[The receipts](#external-validation-public-open-source-projects)** &nbsp;·&nbsp; **[How a run works](#how-a-run-works)** &nbsp;·&nbsp; **[White paper](https://github.com/lenamonj/jeffy-loop/raw/main/The-Jeffy-Loop.pdf)**

</div>

Jeffy Loop is an autonomous improvement loop for [Claude Code](https://claude.com/claude-code) that works on your codebase the way a disciplined principal engineer would: audit first, fix one verified task at a time, prove every claim, and stop when the job is actually done. It descends from Geoffrey Huntley's [Ralph technique](https://ghuntley.com/ralph/) - the insight that a coding agent re-fed one prompt in a loop compounds into real work. The head-to-head below is engine versus method: the raw loop is the engine pattern Jeffy is built on, and Jeffy is the engineering method wrapped around it. The method distills what the people running loops at scale have published - Anthropic's [Claude Code best practices](https://code.claude.com/docs/en/best-practices) and [Boris Cherny's public workflow](https://x.com/bcherny/status/2007179832300581177): give the agent a check it can run, one task at a time, promote every hard-won lesson into a file the next run reads, and prefer small fresh-context runs over one long one.

Run `/jeffy 10` and walk away. Jeffy maps your project's whole public surface, audits it breadth-first, and writes a backlog where every task carries a runnable acceptance check. Then it executes: one verified, checkpointed task per iteration, behind a verify gate that reverts anything that breaks your project. And "done" is never a feeling - a fresh audit must come back clean, an adversarial evaluator must countersign, and a plain shell script re-checks the whole claim before the run is allowed to end.

## The receipts

Three fixes are in other people's code because a maintainer with no stake in this project reviewed them and said yes:

- **[bat](https://github.com/sharkdp/bat/pull/3862) - merged.** A just-merged security flag did nothing when piped; caught before it ever shipped.
- **[fasthttp](https://github.com/valyala/fasthttp/pull/2343) - merged.** A `Content-Length` no parser should accept became a wrong number.
- **[chalk](https://github.com/chalk/chalk/pull/687) - fixed upstream.** The maintainer reproduced the finding, then wrote and merged his own fix, shipped in v6.0.0.

A fourth is not a fix and is not counted as one: a **security finding this loop produced in [claude-code-action](evals/claude-code-action/REPORT.md) is open with Anthropic's own security program**, scored Low (2.3) on 2026-08-20. Their review is ongoing, so nothing here calls it accepted, and the details stay unpublished at their request until the report resolves.

Behind them: **<!-- count:converged -->46<!-- /count --> open-source projects run to convergence across <!-- count:languages -->13<!-- /count --> languages**, every run published in full - and **22 attempts that did not converge**, each with the budget it was given before it started and the reason it ran out. Three greenfield builds converged from empty directories under judges the loop could not edit, one of them against a deliberately mutated specification where recalling the real format produces wrong answers.

**[Read the receipts table](#external-validation-public-open-source-projects)**, or the [full record of every attempt ever started](evals/ATTEMPTS.md).

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
```

**Scoped mode.** By default `/jeffy` runs in Improvement mode: an open-ended audit-and-fix loop. To run it against a concrete target instead, edit `PLAN.md` - replace the Goal and Definition of done with the target, seed `BACKLOG.md` with the finite tasks, then run `/jeffy`. Everything else (envelope, verify gate, checkpoints, journal, report) behaves the same.

**Cancel.** Run `/cancel-jeffy`. It reports which loop it found, deletes the loop state file, and leaves `PLAN.md`, `BACKLOG.md`, and `JOURNAL.md` untouched, so the next `/jeffy` picks up exactly where it left off. (Equivalent manual action: delete `.claude/jeffy-loop.local.md` at the project root.)

## What makes it different

Five guarantees. Each one is enforced by the iteration prompt, the state files, or the Stop hook, and each is checkable in this repository.

**It audits like an engineer, not a linter.** Every run opens with a real audit across architecture, correctness, security, testing, performance and more. Every finding becomes a task with a runnable acceptance check, and a finding exists only if the loop can point at it.

**It cannot wreck your repo.** Every iteration ends in a local checkpoint commit, and a verify gate reverts any iteration that breaks the project. Nothing is pushed, no branches are created.

**"Done" is not the agent's opinion.** A declaration needs a fresh audit finding zero High and zero Medium, a fully swept surface inventory, and an adversarial evaluator's countersignature. Then a plain shell script re-checks all of it, re-runs your test suite, and refuses the stop if anything fails.

**It cannot claim what it never looked at.** The whole public surface goes on a checklist before any finding is filed, each swept row records the commit it certified, and a row reopens when its code changes. "No findings" can never mean "nowhere looked".

**Lessons become machinery.** A rule learned the hard way binds every iteration after it, and a rule that has to be written twice gets promoted into a mechanism. The engine itself is held to <!-- count:checks -->**277 behavioural checks**<!-- /count --> on Linux, Windows and macOS, each one added because something went wrong once.

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
  <img src="media/language-pie-light.png" alt="Pie chart of the 46 converged public targets by language: Python 11 at 23.9 percent, Go 7 at 15.2 percent, JavaScript 6 at 13.0 percent, Rust 6 at 13.0 percent, TypeScript 4 at 8.7 percent, C++ 3 at 6.5 percent, C 2 at 4.3 percent, C# 2 at 4.3 percent, Java 1 at 2.2 percent, Kotlin 1 at 2.2 percent, PHP 1 at 2.2 percent, Ruby 1 at 2.2 percent, Swift 1 at 2.2 percent." width="900">
</picture>

<sub>Every converged public target, by the language it was written in. Counts are derived from the receipts table below at render time by <a href="scripts/render-language-pie.py"><code>scripts/render-language-pie.py</code></a>, largest slice first, ties alphabetical. Chart source: <a href="media/language-pie.html"><code>media/language-pie.html</code></a>.</sub>

</div>

## External Validation: Public Open-Source Projects

Testing a tool against its own codebase proves little, so Jeffy was run against widely-used open-source projects with no connection to this repository. <!-- count:converged -->46<!-- /count --> of those runs converged, across <!-- count:languages -->13<!-- /count --> languages. That breadth is evidence of something specific rather than decoration: the engine ships no language-specific analyzer, no ruleset, and no per-ecosystem plugin. It works from what a project already has, its own test suite and its own verify command, so what carries from a Rust CLI to a Ruby linter to a C++ parser is the method itself.

Every run used a local clone, and nothing went upstream without a filed issue or PR. Each was held to the rules current at its date, those rules only tightened, and every receipt names the standard its run met.

A method that always converges is not measuring anything, so the record shows what the standard costs when a project resists it. python-dotenv was published here as *not converged* through four runs and 25 findings, and needed eight runs and 73 iterations before an audit finally filed nothing. sqlparse makes the point under a stricter rule: its budget of five runs was fixed in writing before its first iteration, four runs failed, and it converged on the fifth and last - one more rejection and it would have been published as a non-convergence, because the rule said so in advance. One row is not a loop run at all. PapaParse is an audit under the same method, kept in the table rather than hidden, and its conversion waits on four open upstream PRs.

<sub>Ordered by upstream outcome - fixes merged first, then fixed upstream, open PRs, filed issues - then by stars.</sub>

| Project | Stars | Language | Iters | Upstream | Headline |
|:---|---:|:---|---:|:---|:---|
| [bat](evals/bat/REPORT.md) | 59,915 | Rust | 10 | **[FIX MERGED](https://github.com/sharkdp/bat/pull/3862)** | a just-merged security flag did nothing when piped; caught before it ever shipped |
| [fasthttp](evals/fasthttp/REPORT.md) | 23,422 | Go | 58 | **[FIX MERGED](https://github.com/valyala/fasthttp/pull/2343)** | 31 findings in a tagged release; a Content-Length no parser should accept became a wrong number |
| [chalk](evals/chalk/REPORT.md) | 23,288 | JavaScript | 8 | **[FIXED UPSTREAM](https://github.com/chalk/chalk/pull/687)** | the control: one Medium found - the maintainer wrote and merged the fix himself, shipped in chalk v6.0.0 |
| [dayjs](evals/dayjs/REPORT.md) | 48,657 | JavaScript | 74 | [PR open](https://github.com/iamkun/dayjs/pull/3167) | 45 findings, 10 High, in a 63M-downloads-a-week library |
| [yfinance](evals/yfinance/REPORT.md) | 24,837 | Python | 9 | [PR open](https://github.com/ranaroussi/yfinance/pull/2927) | closed a High that upstream's own failing test was advertising |
| [PHP-Parser](evals/php-parser/REPORT.md) | 17,450 | PHP | 29 | [PR open](https://github.com/nikic/PHP-Parser/pull/1162) | the tenth language; told nothing, it found its project's largest oracle by itself, then proved one of the suite's own test classes passes without executing the code it names |
| [jsoncpp](evals/jsoncpp/REPORT.md) | 8,876 | C++ | 10 | [PR open](https://github.com/open-source-parsers/jsoncpp/pull/1709) | the documented secure-memory build never compiled on MSVC; the evaluator caught the fix being half done |
| [python-dotenv](evals/python-dotenv/REPORT.md) | 8,830 | Python | 73 | [PR open](https://github.com/theskumar/python-dotenv/pull/678) | the grind: 8 runs, 48 findings, seven audits that each filed something before the eighth came back empty; suite 220 to 511 |
| [PyPortfolioOpt](evals/pyportfolioopt/REPORT.md) | 5,905 | Python | 58 | [PR open](https://github.com/PyPortfolio/PyPortfolioOpt/pull/751) | CI-red baseline to 356 passing; the evaluator rejected five convergence attempts |
| [go-yaml](evals/go-yaml/REPORT.md) | 2,217 | Go | 29 | [PR open](https://github.com/goccy/go-yaml/pull/915) *(not a loop finding)* | 20 findings, 6 High, including a regression the run introduced and the gate caught; the vendored conformance corpus never ran, and scores identically before and after |
| [rust-url](evals/rust-url/REPORT.md) | 1,570 | Rust | 30 | [PR open](https://github.com/servo/rust-url/pull/1147) | 20 findings, 10 High, in the URL crate under cargo and reqwest; a class was settled and withdrawn three times before it held, and the PR closes a conformance case open upstream since 2023 |
| [PapaParse](evals/papaparse/REPORT.md) | 13,532 | JavaScript | *audit* | [4 PRs open](https://github.com/mholt/PapaParse/issues/1132) | four Highs in the streaming path; conversion waits on four open PRs |
| [mustache.js](evals/mustache.js/REPORT.md) | 16,725 | JavaScript | 11 | [issue filed](https://github.com/janl/mustache.js/issues/848) | revived a suite that could not start; npm audit 107 to 2 |
| [Spectre.Console](evals/spectre.console/REPORT.md) | 11,567 | C# | 8 | [issue filed](https://github.com/spectreconsole/spectre.console/issues/2184) | a panel header wider than its content was dropped, not truncated - invisible to 3,618 tests |
| [quantstats](evals/quantstats/REPORT.md) | 7,489 | Python | 40 | [issue filed](https://github.com/ranaroussi/quantstats/issues/537) | 29 findings behind 125 green tests; the library ended smaller than it started |
| [records](evals/records/REPORT.md) | 7,220 | Python | 7 | [issue filed](https://github.com/kennethreitz/records/issues/236) | four High data-loss bugs behind a green suite |
| [cobra](evals/cobra/REPORT.md) | 44,436 | Go | 32 | - | the CLI framework under kubectl and Hugo, converged with an empty ledger and no High at all: `SOURCE_DATE_EPOCH` was resolved in the host timezone, so the one variable whose purpose is byte-reproducible output produced different bytes per machine |
| [zod](evals/zod/REPORT.md) | 43,471 | TypeScript | 39 | - | the largest surface in its cohort at 196 files converged while the 4-file target in the same wave did not: `catch` and `success` wrappers absorbed the engine's own stack overflow so a cyclic value validated, and `z.success()` carried an unreachable `false` branch. Three gate REJECTs before the PASS, and the stack-overflow class took three attempts before the probes could not break it |
| [commander.js](evals/commander-js/REPORT.md) | 28,358 | JavaScript | 10 | - | the most-used CLI framework in Node, and the cleanest target in the corpus: 1,373 green tests, no High findings, and an error message naming an argument the user never typed. The gate rejected on the last iteration and the fix landed inside the one-transaction rule |
| [underscore](evals/underscore/REPORT.md) | 27,330 | JavaScript | 20 | - | the highest-starred convergence in the corpus: a computed __proto__ key wrote through the prototype chain in the library that taught JavaScript its idioms, and the gate proved by module resolution that every test loads a different bundle than the one npm serves consumers |
| [gson](evals/gson/REPORT.md) | 24,229 | Java | 2 | - | the fastest run: one audit, one gate, one priced-and-declined Low, not a line changed |
| [Catch2](evals/catch2/REPORT.md) | 21,430 | C++ | 35 | - | a test framework graded by the method it exists to serve: 18 findings, 6 High, behind 100 green CI legs - a JSON reporter emitting documents no parser accepts, single-letter enum names read past the end of their vector - and the two sharpest Highs were filed by the adversarial gate itself, including a benchmark confidence interval that reported a collapsed zero-width answer with no diagnostic |
| [validator](evals/validator/REPORT.md) | 20,110 | Go | 31 | - | four Highs behind a green suite in the struct validator under Gin and Echo: a cyclic struct graph exhausted the goroutine stack and killed the process unrecoverably, and the `unix_addr` tag accepted every string, so a validation its own docs describe never rejected anything |
| [clap](evals/clap/REPORT.md) | 16,634 | Rust | 31 | - | the target this cohort predicted would fail, named at risk in writing before launch: 35 inventory rows, and after 30 iterations it had swept 20 of them with the gate never once invoked - then run 4 swept the remaining 15 and passed first time, while the second-smallest surface in the same cohort did not converge at all |
| [uuid (JS)](evals/js-uuid/REPORT.md) | 15,320 | JavaScript | 20 | - | v3/v5 crashed on any name with an unpaired surrogate, version converters silently returned wrong-version results, and two CI gates could not fail (a bare git diff exiting 0 either way; publint whose --strict npm ate) - single gate invocation, first PASS |
| [speedtest-cli](evals/speedtest-cli/REPORT.md) | 14,080 | Python | 5 | - | the restraint case: small findings, nothing invented |
| [cJSON](evals/cjson/REPORT.md) | 12,916 | C | 10 | - | the eleventh language, and the first target picked by shape rather than by oracle: a pre-registered two-run budget, converged in one. Sorting an object silently dropped every later append. The gate rejected a leaking test the project's own suite could not see |
| [moshi](evals/moshi/REPORT.md) | 10,154 | Kotlin | 49 | - | the thirteenth language, and the clearest before-and-after in the corpus: three runs left Square's JSON library with an empty ledger, five unswept rows and the gate never once invoked, then two runs under an engine that ranks the map above every Medium swept those rows and converged. Five Highs behind twenty green CI legs, including integral reads that returned silently out of range and a record's canonical constructor whose exceptions were all swallowed |
| [RuboCop](evals/rubocop/REPORT.md) | 12,892 | Ruby | 7 | - | the null result: every cop department swept, the last 20 commits re-proven, zero findings, zero lines changed |
| [lz4](evals/lz4/REPORT.md) | 12,004 | C | 15 | - | the anti-cheat oracle: `decompress(compress(x)) == x` is arithmetic the loop cannot rewrite, and under it the CLI still hid silent data loss - an over-declared skippable frame made `lz4 -dc` emit nothing and exit 0 while `lz4 -t` called the file sound, the third finding on one root cause, closed as a single boundary. Converged with an empty ledger and a +188/-115 diff |
| [godotenv](evals/godotenv/REPORT.md) | 10,600 | Go | 19 | - | the Go port of dotenv, converged in the cheap shape the cohort was chosen for: a one-second suite, four Highs behind it - a hand-crafted `.env` could panic the parser from outside, lowercase `${a}` never expanded, an escaped quote at the end of a value was dropped and broke the library's own round trip - and credentials files written at 0644 now land at 0600 |
| [FluentValidation](evals/fluentvalidation/REPORT.md) | 9,753 | C# | 8 | - | one run of eight iterations, the budget's first and last: `CreditCard()` accepted `" - - "` as a card number - the Luhn checksum of no digits is zero - and any unsupported neutral culture turned every validation message into the empty string, both behind 865 green tests. Converged with an empty ledger; a 907-culture differential proved the fallback fix moved nothing else |
| [claude-code-action (attempt 2)](evals/claude-code-action/REPORT.md) | 8,618 | TypeScript | 30 | - | the acceptance test for the engine's own release, and the sharpest limit in the corpus: attempt 1 swept 17 of 23 rows and never once reached the gate, attempt 2 swept 28 of 28 and converged - and did not rediscover three High findings attempt 1 had filed on identical code |
| [path-to-regexp](evals/path-to-regexp/REPORT.md) | 8,598 | TypeScript | 27 | - | three runs and five evaluator invocations, four of them REJECTs - and not one rejection was a missed defect in the library. Every one was a defect in the run's own evidence, including a verify command whose ReDoS assertions were randomized enough to pass without searching |
| [claude-agent-sdk-python (attempt 2)](evals/claude-agent-sdk-python/REPORT.md) | 7,881 | Python | 30 | - | the same limit, proved by an instrument instead of a diff: attempt 1 swept 19 of 44 rows and never reached the gate, attempt 2 swept 31 of 31 and converged - then attempt 1's own battery, run unmodified against the converged tree, exited 1 with `create_sdk_mcp_server published an empty schema`. The run had swept that row and edited that very function |
| [marshmallow](evals/marshmallow/REPORT.md) | 7,242 | Python | 10 | - | one round: three Highs in the load path of the validation library under half of Python's APIs - and the gate caught two Highs the run itself introduced, reproduced against the baseline, before countersigning |
| [swift-algorithms](evals/swift-algorithms/REPORT.md) | 6,323 | Swift | 24 | - | the twelfth language: one real High in Apple's code, then fourteen findings tracing back to a single cause - nothing compiled or ran the doc-comment examples, so ten of them did not compile. Run 2 refused a loophole that would have earned it a third evaluator invocation |
| [magic_enum](evals/magic_enum/REPORT.md) | 6,165 | C++ | 19 | - | six broken public members of a header-only library that no compiler had ever seen - C++ does not compile a class template member nothing instantiates, and nothing did. One of them answered `all() == false` on a full bitset without crashing. The structural fix makes the suite instantiate them, so a seventh cannot ship |
| [go-uuid](evals/go-uuid/REPORT.md) | 6,141 | Go | 20 | - | three Highs in the identifier package under much of Go's ecosystem: a SQL NULL handed back the previous row's UUID, a documented accessor decoded version 2 time up to seven minutes wrong, and one generator took no lock on the shared clock - invisible to a project CI that ran without the race detector |
| [ta](evals/ta/REPORT.md) | 5,129 | Python | 64 | - | wrong numbers shipped since 2023; caught its own regression and wrote "It is mine" |
| [go-cmp](evals/go-cmp/REPORT.md) | 4,672 | Go | 15 | - | the smallest surface in the corpus at 620KB, from the same wave whose 4-file target did not converge: Google's comparison library was gated by CI on Go 1.21 alone, and two genuine grouping bugs in its diff reporter hid from a 4,000-case suite. The whole shipped diff is +31/-13 - on a well-kept codebase the loop's bill is small and precise |
| [more-itertools](evals/more-itertools/REPORT.md) | 4,089 | Python | 16 | - | the iteration-recipes library: sample() silently produced meaningless draws on negative weights, and the flit sdist shipped without its tests or docs - the artifact-channel rule catching under-shipping as readily as leaking. One gate invocation, one PASS |
| [sqlparse](evals/sqlparse/REPORT.md) | 4,009 | Python | 47 | - | the pre-registered budget was five runs and it took five; the loop declined a finding the gate handed it, after running the claim |
| [rrule](evals/rrule/REPORT.md) | 3,738 | TypeScript | 33 | - | 23 findings, 10 High, in the RFC 5545 library behind much of the JavaScript calendar ecosystem; the reference implementation overruled one of the loop's own High findings and the loop withdrew it |
| [ryu](evals/ryu/REPORT.md) | 704 | Rust | 10 | - | the float printer under serde_json, converged in one round with a +65/-1 diff: s2f rejected 7,807 strings ryu's own formatter emits, fixed as a class with bit-exact agreement against the standard library - and the run found and closed its own packaging leak, converting the manifest to an include allowlist the gate verified byte-identical against the pre-run crate |
| [rust-semver](evals/rust-semver/REPORT.md) | 674 | Rust | 16 | - | the version parser under Cargo itself, converged on an empty ledger - and the gate rejected twice first, once on a Medium no instrument could see: `cargo package` would have shipped the loop's own audit ledger inside the published crate tarball, and the packaging probe graded exit status instead of contents |
| [heck](evals/heck/REPORT.md) | 595 | Rust | 17 | - | the case converter under cargo and serde codegen, graded against the Unicode Character Database itself: seven Mediums closed, and the gate found the headline High - NFD text silently losing its combining marks - that the run's own 149,106-point differential was structurally blind to, because its reference split words on the same predicate. That High is carried blocked on an owner decision, stated on the receipt up front |

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

**A lesson a machine can check becomes a check, never a paragraph.** This is the mechanism that accumulates. When a run finds a defect in the engine, the fix is not a warning in the documentation but a behavioural check in `scripts/validate.sh` that fails if the defect returns. The count is the visible result: it started at 119 and stands at <!-- count:checks -->**277 behavioural checks**<!-- /count --> on a clone, each one added because something went wrong once and was made unable to go wrong silently again. The number in that sentence is itself derived by the validator rather than typed, which is the next mechanism.

Check K is the clearest example, because it closed the hole it was born from. The lesson was that a published number must be recomputed from the run rather than copied from wherever it last appeared. Prose saying so would have been read and forgotten. Instead check K derives the check count this README publishes from the validator run itself and refuses a mismatch - and during a release build it did exactly that, rejecting a stale `203` that a human had already read past.

**The gate grades the run's evidence, not only the code.** The adversarial evaluator is the mechanism that makes self-improvement honest, because the most common failure is not a missed bug but a proof that does not prove anything. `path-to-regexp` is the plainest case in the corpus: three runs, five evaluator invocations, four of them rejections, and **not one rejection was a missed defect in the library**. Every one was a defect in the run's own evidence, including a verify command whose randomised assertions could report safe without ever searching. Those findings improve the method, not the target.

**Failures are published beside successes.** `evals/ATTEMPTS.md` carries every attempt, including **22 attempts that did not converge**, each with the budget it was given before it started and the reason it ran out. A corpus of only successes cannot teach anything about where the method stops working, and knowing where it stops is what tells us what to build next. Several of the engine's largest changes exist because a published failure named the gap first.

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
