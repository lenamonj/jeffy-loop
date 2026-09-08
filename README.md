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
| **<!-- count:tested -->132<!-- /count -->** | **<!-- count:converged -->103<!-- /count -->** | **<!-- count:failed -->28<!-- /count -->** | **<!-- count:merged -->30<!-- /count -->** | **<!-- count:prs-open -->34<!-- /count -->** | **<!-- count:issues -->4<!-- /count -->** |

<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="media/language-pie-dark.png">
  <img src="media/language-pie-light.png" alt="Pie chart of the 103 converged public targets by language: Python 20 at 19.4 percent, Rust 14 at 13.6 percent, Go 12 at 11.7 percent, JavaScript 10 at 9.7 percent, C++ 7 at 6.8 percent, Java 6 at 5.8 percent, Ruby 6 at 5.8 percent, Swift 6 at 5.8 percent, C 5 at 4.9 percent, PHP 5 at 4.9 percent, TypeScript 5 at 4.9 percent, Kotlin 4 at 3.9 percent, C# 3 at 2.9 percent." width="900">
</picture>

<sub><!-- count:converged -->103<!-- /count --> projects run to convergence across <!-- count:languages -->13<!-- /count --> languages with no language-specific analyzer or ruleset. Derived from the scorecard at render time.</sub>

</div>

## Independent Validation

A merged pull request is the one result Jeffy cannot award itself. It takes an independent maintainer, someone with no stake in this project, to review the patch and accept it into their own codebase. Maintainers across <!-- count:merged-projects -->24<!-- /count --> open source projects have done exactly that, including:

<table>
  <tr>
    <th align="left">Merged by</th>
    <th align="left">Pull request</th>
    <th align="left">Merged in</th>
  </tr>
  <tr>
    <td><img src="https://github.com/google.png" width="20" height="20" alt="" align="absmiddle"> Google</td>
    <td><a href="https://github.com/google/snappy/pull/257">snappy #257</a><br>Every release build compressed a 4 GiB input into a stream whose header claimed 0 bytes</td>
    <td>1 day</td>
  </tr>
  <tr>
    <td rowspan="3"><img src="https://github.com/apple.png" width="20" height="20" alt="" align="absmiddle"> Apple</td>
    <td><a href="https://github.com/apple/swift-log/pull/504">swift-log #504</a><br>A documented no-op setter asserted instead</td>
    <td>2 days</td>
  </tr>
  <tr>
    <td><a href="https://github.com/apple/swift-log/pull/503">swift-log #503</a><br>A handler implementing only <code>log(event:)</code> overflowed the stack on the SwiftLog 1.0 entry point</td>
    <td>5 days</td>
  </tr>
  <tr>
    <td><a href="https://github.com/apple/swift-protobuf/pull/2164">swift-protobuf #2164</a><br>The project's own CMake build of <code>protoc-gen-swift</code> had not compiled since June</td>
    <td>15 hours</td>
  </tr>
  <tr>
    <td rowspan="2"><img src="https://github.com/microsoft.png" width="20" height="20" alt="" align="absmiddle"> Microsoft</td>
    <td><a href="https://github.com/microsoft/mimalloc/pull/1385">mimalloc #1385</a><br>The zeroing allocator returned uninitialized memory above the small-size threshold</td>
    <td>8 hours</td>
  </tr>
  <tr>
    <td><a href="https://github.com/microsoft/snmalloc/pull/878">snmalloc #878</a><br>The header-only build recipe named a CMake target removed in 2021 and include paths that resolved nowhere</td>
    <td>2 hours</td>
  </tr>
  <tr>
    <td rowspan="2"><img src="https://github.com/apache.png" width="20" height="20" alt="" align="absmiddle"> Apache</td>
    <td><a href="https://github.com/apache/commons-text/pull/768">commons-text #768</a><br>A <code>StringMatcher</code> overload forwarded the buffer end as its start</td>
    <td>2 days</td>
  </tr>
  <tr>
    <td><a href="https://github.com/apache/commons-csv/pull/633">commons-csv #633</a><br>The record counter's Javadoc said headers were not counted while the constructor's header was</td>
    <td>3 days</td>
  </tr>
  <tr>
    <td rowspan="2"><img src="https://github.com/JetBrains.png" width="20" height="20" alt="" align="absmiddle"> JetBrains</td>
    <td><a href="https://github.com/Kotlin/kotlinx-datetime/pull/650">kotlinx-datetime #650</a><br>Deprecation quick-fixes pointed developers at the wrong replacement</td>
    <td>90 minutes</td>
  </tr>
  <tr>
    <td><a href="https://github.com/Kotlin/kotlinx-datetime/pull/649">kotlinx-datetime #649</a><br>The Unicode pattern parser dropped the escaped quote inside a literal</td>
    <td>4 days</td>
  </tr>
  <tr>
    <td><img src="https://github.com/nodejs.png" width="20" height="20" alt="" align="absmiddle"> Node.js</td>
    <td><a href="https://github.com/ada-url/ada/pull/1244">ada #1244</a><br>The URL parser Node.js ships reported <code>host_end</code> one byte short</td>
    <td>12 minutes</td>
  </tr>
  <tr>
    <td rowspan="2"><img src="https://github.com/cloudflare.png" width="20" height="20" alt="" align="absmiddle"> Cloudflare</td>
    <td><a href="https://github.com/cloudflare/circl/pull/700">circl #700</a><br>The PKI marshal functions panicked on the library's own post-quantum keys instead of returning an error</td>
    <td>1 day</td>
  </tr>
  <tr>
    <td><a href="https://github.com/cloudflare/circl/pull/699">circl #699</a><br>The hybrid KEM derived a different key pair from the same seed on a random subset of calls</td>
    <td>1 day</td>
  </tr>
  <tr>
    <td><img src="https://github.com/uuid-rs.png" width="20" height="20" alt="" align="absmiddle"> uuid-rs</td>
    <td><a href="https://github.com/uuid-rs/uuid/pull/907">uuid #907</a><br>The UUIDv7 counter lost its top four bits to the version nibble (178 million crates.io downloads in the last 90 days)</td>
    <td>6 days</td>
  </tr>
</table>

**[See every project, every patch, and every failure](evals/README.md)**

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
jeffy install       # installs Jeffy as a Claude Code skill
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

When the run ends, start a new session to run it again; [the restart is doing real work](docs/usage.md#use-several-short-runs-not-one-long-one). A High hunt fixes only the Highs and stops at the first audit that finds none, so it is usually the faster run. [Usage](docs/usage.md) covers every flag, rounds and budgets, scoped mode, and cancelling.

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
