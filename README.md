<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="media/banner-dark.png">
  <img src="media/banner-light.png" alt="Jeffy Loop - point it at a project, give it a budget, come back to a better codebase and a report" width="900">
</picture>

[![Validate](https://img.shields.io/github/actions/workflow/status/lenamonj/jeffy-loop/validate.yml?style=for-the-badge&label=validate&logo=githubactions&logoColor=white)](https://github.com/lenamonj/jeffy-loop/actions/workflows/validate.yml)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Skill-D97757?style=for-the-badge&logo=claude&logoColor=white)](https://claude.com/claude-code)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Mac%20%7C%20Linux-0EA5E9?style=for-the-badge)
[![License: MIT](https://img.shields.io/badge/License-MIT-22C55E?style=for-the-badge)](LICENSE)

**[Quick Install](#quick-install)** &nbsp;·&nbsp; **[Usage](docs/usage.md)** &nbsp;·&nbsp; **[How it works](docs/how-it-works.md)** &nbsp;·&nbsp; **[The receipts](evals/README.md)** &nbsp;·&nbsp; **[Headless](docs/headless.md)** &nbsp;·&nbsp; **[White paper](https://github.com/lenamonj/jeffy-loop/raw/main/The-Jeffy-Loop.pdf)**

## Autonomous Engineering With Proof

**_Agents that don’t just act._**  
_They audit · verify · attack · and prove._

</div>

Jeffy Loop is an autonomous engineering system built around a simple principle: **AI agents shouldn’t just produce work. They should produce evidence that the work is correct.** Instead of asking an agent to complete a task and trusting its conclusion, Jeffy creates a continuous **Audit → Attack → Verify → Prove** loop in which specialized agents inspect the work, challenge it, validate the result, and generate an auditable record of what happened. The goal isn’t simply autonomous code generation; it is **autonomous engineering with proof** - where every claimed result is accompanied by reproducible evidence that can be independently examined.

**Jeffy treats “done” as something that must be demonstrated, not declared.** The system is designed to turn autonomous engineering from a conversational interaction into an evidence-producing process: actions leave traces, decisions have provenance, failures are exposed rather than hidden, and successful outcomes produce a durable receipt of what was changed, why it was changed, and how the result was verified.

## The proof

Jeffy was run against <!-- count:tested -->132<!-- /count --> open-source projects with no connection to this repository, each judged by its own test suite, every run published, failures included.

| Projects tested | Converged | Failed | PRs merged | PRs open | Issues filed |
|:---:|:---:|:---:|:---:|:---:|:---:|
| **<!-- count:tested -->132<!-- /count -->** | **<!-- count:converged -->103<!-- /count -->** | **<!-- count:failed -->28<!-- /count -->** | **<!-- count:merged -->27<!-- /count -->** | **<!-- count:prs-open -->35<!-- /count -->** | **<!-- count:issues -->4<!-- /count -->** |

<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="media/language-pie-dark.png">
  <img src="media/language-pie-light.png" alt="Pie chart of the 103 converged public targets by language: Python 20 at 19.4 percent, Rust 14 at 13.6 percent, Go 12 at 11.7 percent, JavaScript 10 at 9.7 percent, C++ 7 at 6.8 percent, Java 6 at 5.8 percent, Ruby 6 at 5.8 percent, Swift 6 at 5.8 percent, C 5 at 4.9 percent, PHP 5 at 4.9 percent, TypeScript 5 at 4.9 percent, Kotlin 4 at 3.9 percent, C# 3 at 2.9 percent." width="900">
</picture>

<sub><!-- count:converged -->103<!-- /count --> projects run to convergence across <!-- count:languages -->13<!-- /count --> languages with no language-specific analyzer or ruleset. Derived from the scorecard at render time.</sub>

</div>

## Independent Validation

A merged pull request is the one result Jeffy cannot award itself. It takes an independent maintainer, someone with no stake in this project, to review the patch and accept it into their own codebase. Maintainers across <!-- count:merged-projects -->22<!-- /count --> open source projects have done exactly that, including:

- **Google, [snappy](https://github.com/google/snappy/pull/257)** - every release build compressed a 4 GiB input into a stream whose header claimed 0 bytes; merged the morning after filing.
- **Apple (3)**
  - [swift-log](https://github.com/apple/swift-log/pull/504) - a documented no-op setter asserted instead; merged after the maintainer asked for the doc-only form.
  - [swift-log](https://github.com/apple/swift-log/pull/503) - a handler implementing only `log(event:)` overflowed the stack on the SwiftLog 1.0 entry point; approved after one review round, merged three days later.
  - [swift-protobuf](https://github.com/apple/swift-protobuf/pull/2164) - the project's own CMake build of `protoc-gen-swift` had not compiled since June; approved and merged the day it was filed.
- **Microsoft, [mimalloc](https://github.com/microsoft/mimalloc/pull/1385)** - the zeroing allocator returned uninitialized memory above the small-size threshold; merged by the author the same day.
- **Apache (2)**
  - [commons-text](https://github.com/apache/commons-text/pull/768) - a `StringMatcher` overload forwarded the buffer end as its start; merged the morning after review.
  - [commons-csv](https://github.com/apache/commons-csv/pull/633) - the record counter's Javadoc said headers were not counted while the constructor's header was; corrected, merged three days after filing.
- **JetBrains (2)**
  - [kotlinx-datetime](https://github.com/Kotlin/kotlinx-datetime/pull/650) - deprecation quick-fixes pointed developers at the wrong replacement; merged within two hours.
  - [kotlinx-datetime](https://github.com/Kotlin/kotlinx-datetime/pull/649) - the Unicode pattern parser dropped the escaped quote inside a literal; the test moved where the maintainer asked, merged an hour later.
- **Node.js, [ada](https://github.com/ada-url/ada/pull/1244)** - the URL parser reported `host_end` one byte short; merged twelve minutes after filing.
- **Cloudflare, [circl](https://github.com/cloudflare/circl/pull/700)** - the PKI marshal functions panicked on the library's own post-quantum keys instead of returning an error; approved and merged with one word.

**[Every project, every patch, and every failure](evals/README.md)**

## Quick Install

You need [Claude Code](https://claude.com/claude-code), signed in once, and [git](https://git-scm.com/downloads). The installer handles everything else, including `jq`.

```bash
git clone https://github.com/lenamonj/jeffy-loop.git
cd jeffy-loop
./install.sh        # Windows PowerShell: .\install.ps1
```

If PowerShell refuses with "running scripts is disabled on this system", run in PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Or from PyPI, no clone needed; `pipx install jeffy-loop` and `uv tool install jeffy-loop` work the same way:

```bash
pip install jeffy-loop
jeffy install
```

## Running Jeffy

Open Claude Code in the project you want to improve and type `/jeffy 10`. It is a slash command inside the session, not a shell command.

```
/jeffy                                     # 10 iterations, full-spectrum improvement
/jeffy 5                                   # 5 iterations
/jeffy 12 accessibility and performance    # 12 iterations with a focus directive
/jeffy 5 --highs                           # High hunt: find and fix only the Highs
/jeffy 10 --max-time 2h                    # 10 iterations, but stop after two hours either way
```

When the run ends, start a new session to run it again; [the restart is doing real work](docs/usage.md#use-several-short-runs-not-one-long-one). A High hunt fixes only the Highs and stops at the first audit that finds none, so it is usually the faster run. Every flag, rounds and budgets, scoped mode and cancelling are in [Usage](docs/usage.md).

## What the engine enforces

Each one is enforced by the iteration prompt, the state files, or the Stop hook. [How.](docs/how-it-works.md#what-the-engine-enforces)

1. **It audits like an engineer, not a linter.** A finding exists only when the loop can point at it and prove it with a runnable check.
2. **It cannot wreck your repo.** Every iteration is a local commit, a broken verify is reverted, and nothing is ever pushed.
3. **"Done" is not the agent's opinion.** An adversarial evaluator and a shell gate re-check every declaration.
4. **It cannot declare convergence over code it never looked at.** The loop maps the public surface into a checklist, every swept row records the commit it certified, and the Stop hook refuses the declaration while any row is unswept.
5. **Lessons become machinery.** A rule learned once binds every later iteration, and the engine itself passes <!-- count:checks -->**347 behavioural checks**<!-- /count --> on Linux, Windows and macOS.

## Documentation

| Page | What it covers |
|:---|:---|
| [Usage](docs/usage.md) | Flags, rounds and budgets, [High hunt](docs/usage.md#high-hunt), scoped mode, cancelling, [upgrading](docs/usage.md#already-installed-upgrade), uninstalling, and what to know before a first run |
| [How it works](docs/how-it-works.md) | The run lifecycle, what the engine enforces, the full rule set, what a converged stop looks like, and how the loop improves itself |
| [Headless runs](docs/headless.md) | Running budgeted rounds unattended from bash or PowerShell |
| [The receipts](evals/README.md) | Every open-source target with its outcome, the merged patches, the greenfield builds |
| [Contributing](CONTRIBUTING.md) | The validator and the review bar |
| [White paper](https://github.com/lenamonj/jeffy-loop/raw/main/The-Jeffy-Loop.pdf) | For readers new to agent loops: how loops got here, every rule from first principles, and what this method still cannot do |

> [!IMPORTANT]
> **Trust model.** The engine is one shell script, `skills/jeffy/hooks/stop-hook.sh`, plus the small library beside it in `skills/jeffy/hooks/lib/`, registered as a Claude Code Stop hook. In a session with no live Jeffy state file it exits at once and does nothing. The installer writes two skill folders under `~/.claude/skills`, one hook entry in `~/.claude/settings.json`, and, only if you say yes when `jq` is missing, a `jq` install through your package manager.

## License

MIT
