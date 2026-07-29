<div align="center">

[![Validate](https://img.shields.io/github/actions/workflow/status/lenamonj/jeffy-loop/validate.yml?style=for-the-badge&label=validate&logo=githubactions&logoColor=white)](https://github.com/lenamonj/jeffy-loop/actions/workflows/validate.yml)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Skill-D97757?style=for-the-badge&logo=claude&logoColor=white)](https://claude.com/claude-code)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Mac%20%7C%20Linux-0EA5E9?style=for-the-badge)
[![Fable 5](https://img.shields.io/badge/Built_with-Fable_5-D97757?style=for-the-badge&logo=claude&logoColor=white)](https://claude.ai)

# Jeffy Loop [![License: MIT](https://img.shields.io/badge/License-MIT-22C55E?style=flat-square)](LICENSE)

**Point it at a project. Give it a budget. Come back to a better codebase and a report.**

</div>

Jeffy Loop is an autonomous improvement loop for Claude Code that works on your codebase the way a disciplined principal engineer would: audit first, prioritize by real impact, fix one verified task at a time, and stop when the job is actually done.

Run `/jeffy 10` in any project and walk away. Jeffy audits every quality dimension that applies, writes a backlog where every task carries a runnable acceptance check, then burns through it - one task per iteration, each one verified, each one checkpointed. When it finishes, it tells you exactly what changed, what it couldn't do, and what needs your decision.

## Quickstart

You need [Claude Code](https://claude.com/claude-code) (installed and signed in once) and git. The installer handles everything else, including `jq`.

```bash
git clone https://github.com/lenamonj/jeffy-loop.git
cd jeffy-loop
./install.sh        # Windows PowerShell: .\install.ps1
```

Then open Claude Code in the project you want to improve and type `/jeffy 10`. It is a slash command inside the Claude Code session, not a shell command. Details, including the Windows execution-policy note, are under [Install](#install).

<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="media/flowchart-dark.png">
  <img src="media/flowchart-light.png" alt="Flowchart of a /jeffy run: the launch skill bootstraps the state files, each iteration audits or executes one verified task and checkpoints it, the adversarial evaluator - a fresh-context sub-agent - countersigns convergence, and the Stop hook re-feeds the loop until convergence, budget end, or a blocker - all steered by three files and the git log." width="830">
</picture>

<sub>How one command becomes a run. Solid arrows are control flow; dashed arrows are the file reads and writes that steer it. Outside a run the Stop hook exits instantly - no live state file, no behavior - and <code>/cancel-jeffy</code> ends a run at any time. Diagram source: <a href="media/flowchart.mmd"><code>media/flowchart.mmd</code></a>.</sub>

</div>

<div align="center">

![Jeffy Loop vs a raw prompt loop - the head-to-head](media/jeffy-vs-raw-loop.gif)

<sub>The head-to-head vs a raw prompt loop. Every row is a guarantee you can verify in the code: the engine is <code>skills/jeffy/hooks/stop-hook.sh</code>, the discipline is <code>skills/jeffy/references/iteration-prompt.txt</code>, and the receipts from real runs live under <a href="evals/"><code>evals/</code></a>. <a href="media/jeffy-vs-raw-loop.mp4">Watch in HD</a>.</sub>

</div>

Jeffy Loop descends from the [Ralph technique](https://ghuntley.com/ralph/), Geoffrey Huntley's insight that a coding agent re-fed one prompt in a loop compounds into real work. The comparison above is engine versus method: the raw loop is the engine pattern Jeffy is built on, and Jeffy is the engineering method wrapped around it. The method itself distills what the people running loops at scale have published - Anthropic's [Claude Code best practices](https://code.claude.com/docs/en/best-practices) and [Boris Cherny's public workflow](https://x.com/bcherny/status/2007179832300581177): give the agent a check it can run, one task at a time, promote every hard-won lesson into a file the next run reads, and prefer small fresh-context runs over one long one.

## Why Jeffy

- **An engineer's judgment, not a linter's.** Every run starts from a real audit - architecture, correctness, security, testing, error handling, performance, accessibility, developer experience, and more - and every finding becomes a prioritized task with a concrete acceptance check. Evidence over assertion: a finding exists only if the loop can point at it.

- **It cannot wreck your repo.** Every iteration ends in a local checkpoint commit. A repo-level verify gate guards every change: an iteration that breaks the project is reverted on the spot. Nothing is ever pushed, no branches are created. Review with `git log`, revert any single iteration, squash the run when you're happy.

- **It doesn't invent problems.** Severity is judged against a declared operating envelope - your project's real input surfaces, not imagined attackers. Out-of-envelope findings can't inflate the backlog, and only you can widen the envelope: the loop files a proposal and moves on.

- **Done means done.** The loop converges only when a full fresh audit finds zero High and zero Medium findings *and* the backlog is empty - every Low fixed, declined with a reason, or blocked with its reason on record. A **surface inventory** bounds the claim: the first audit maps the whole public surface into a checkbox table and probes it breadth-first, every sweep records the commit it certified, and clean scores claim only examined rows - "no findings" can never quietly mean "nowhere looked". Once one audit comes back clean, the loop stops auditing and finishes the ledger, so a tail of Lows cannot keep it busy forever.

- **Convergence needs a second signature.** An agent grading its own work praises it. So before the loop may claim convergence, **the adversarial evaluator** - a fresh-context sub-agent carrying none of the run's self-persuasion - re-runs the verify gate and the closed tasks' acceptance checks, hunts for missed findings, and must return PASS. A rejection files its evidence as new tasks; a second ends the run as a hard blocker.

- **The stop is machine-checked, and the machine is tested.** The Stop hook - plain shell, not a model - refuses the converged stop unless the ledger is empty, the Converged commit still certifies the tree, no inventory row is unswept, and the project's own verify command exits green when the hook re-runs it. A failed check re-feeds the loop with the evidence. The engine itself is held to **75 behavioural checks** in CI, on Linux and Windows.

- **It knows when to stop.** Budget spent, convergence reached, progress stalled, or a decision only you can make - the loop ends itself and says why, instead of burning budget spinning.

- **It ends with receipts.** The run report lists iterations used, tasks closed with severities, the run's diffstat, anything blocked, and decisions waiting on you. An append-only journal and the checkpoint commits hold the full, greppable record.

## What it does

Running `/jeffy` in a Claude Code session:

1. **Bootstraps the loop's memory** at the project root: `PLAN.md` (goal, operating envelope, surface inventory, verify command, lessons, definition of done), `BACKLOG.md` (the task ledger - findings prioritized most severe first, plus proposals awaiting your decision, settled defect classes, and the Converged record), and `JOURNAL.md` (append-only iteration log). They persist between runs.
2. **Runs the budgeted loop.** The first audit maps the project's whole public surface into the inventory and files a backlog where every task carries a runnable acceptance check. Each iteration after that either audits or executes exactly one task, verifies its check, and ends in a local checkpoint commit; a task that newly breaks the project's verify command is reverted. Once one full audit comes back clean of High and Medium, the run stops auditing and finishes the ledger.
3. **Stops for a reason and reports.** Convergence - a clean audit, an empty ledger, a fully swept inventory, the adversarial evaluator's PASS, all re-checked in shell by the Stop hook - or the budget, a stall, a hard blocker, or your cancel. The run report lists tasks closed with severities, the diffstat, rows swept of rows total, and anything waiting on your decision.

## What a run looks like

Jeffy built this repository by running on itself. The dev journal it wrote stays out of the published tree - state files are the loop's memory, not the product - but two abridged entries show the shape of a run, shown as written (journal headings have since tightened to the pipe-delimited grammar the loop uses today). First, the opening audit that generated the backlog:

```
## Iteration 1 - 2026-07-03 - Audit (Improvement mode)

Audit scores (highest finding severity per applicable dimension):
- Testing: Medium. Zero automated validation of installers or skills; a syntax
  break or missing SKILL.md frontmatter would ship silently (M2).
- Git hygiene: Medium. .gitignore does not exclude the loop's transient
  session-scoped state file, which every Jeffy run creates (M1).
- Security: None. No network fetch beyond trusted CLIs; no secrets.
(10 more dimensions scored Low, None, or N/A)

Findings written to BACKLOG.md: 0 High, 2 Medium, 4 Low.
Next: Execute M1 (gitignore the loop state file) as the top unblocked item.
```

Then, the full fresh-evidence audit that ended a later run:

```
## Iteration 1 (run 6, budget 5) - 2026-07-05 - Full audit (convergence check)

Evidence gathered this iteration (fresh):
- Validator: bash scripts/validate.sh exits 0, every check green.
- Check 6 has teeth: negative-path test on a scratch copy with the
  "## Operating envelope" marker mangled fails the build. Not a silent no-op.
(7 more evidence lines)

Result: zero High, zero Medium. The Definition of done is genuinely and
verifiably true. Recorded a Converged line with the full commit hash
under ## Converged in BACKLOG.md so future relaunches on an unchanged tree
ratchet in O(1) instead of re-auditing.
```

That convergence is re-earned, not archived: every fresh run of Jeffy on this repo has to reach it again with fresh evidence. When Jeffy converges on your project, the checkpoint is recorded in your `git log` and under `## Converged` in the loop's backlog, so relaunches on an unchanged tree re-verify instead of re-auditing. Run `/jeffy` on your own project and read the journal it leaves behind.

## Proven on strangers' codebases

Self-runs are easy mode. So Jeffy was pointed at real, famous, unaffiliated projects - every one in a local clone, nothing pushed upstream, all of it held to the same rules: evidence before filing, severity judged against a declared envelope, one verified fix at a time, and red-green proof anyone can re-run. **Every entry below is a full `/jeffy` loop run that converged.** The bar tightened as the engine shipped: the earliest runs converged on a clean closing audit and an empty ledger, the later ones under the shell-enforced converged stop, and the latest three with the adversarial evaluator's countersignature - each receipt states what its run passed. None of this has to be taken on trust.

Ordered by severity of what was found, most severe first.

**[ranaroussi/quantstats](evals/quantstats/REPORT.md)** (7,489 stars, loop run, **converged**) - the deepest run in this set, and the one where the loop and the engine improved each other in public. Portfolio analytics whose output goes straight into investor-facing tearsheets, green at 125 tests, hiding **29 findings**. Four budgeted runs, 40 iterations, machine-checked convergence with an evaluator countersignature. The suite ends at **393 passing** and the library ends **smaller than it started** - 570 source insertions against 759 deletions, plus 1,694 lines of tests, every one proven to fail against the unfixed code, which the closing evaluator re-proved wholesale by reverting the source and failing 65 of them in one command. The findings run the whole taxonomy: a process-global cache serving one caller's DataFrame to another caller's Series so a benchmark-free report **poisoned the next report in the same process** (deleting it also made metrics 19.8% faster); two contradictory timezone conventions that made the package **disagree with itself about which year** an Asia/Tokyo return belongs to; `aggregate_returns` silently no-oping on its own documented `'M'`, `'Q'` and `'Y'` so `compare(aggregate='M')` returned daily rows where monthly belong; a montecarlo module whose advertised distribution was a **point mass** - permutation preserves the compound product, so terminal-value std was 1e-15 float noise; `cagr(rf=0.05)` equal to `cagr(rf=0.0)` to eight decimals because a caller-name skip list silently voided the risk-free rate; `make_index` whose `.resample` exists **only in its docstring**; a probabilistic-Sharpe family subtracting an annual rate from a per-observation ratio and subtracting the kurtosis excess **twice**. Each of those classes was caught by an engine rule that did not exist when the previous class was found - the run exposed a sweep bias, the engine shipped a hardened contract, all certifications were re-earned under it, three generations in sequence - and the receipt states the boundary as plainly as the wins: **six convention defects a manual audit of the same commit proved remain at the converged tree**, kelly's scale-invariant sizing and the unannualized information ratio among them, because a known-answer probe verifies a formula and cannot adjudicate which formula the context demands. Convergence is a claim about a contract, and the receipt says exactly which one. Findings were disclosed upstream with repros and a PR offer in [ranaroussi/quantstats#537](https://github.com/ranaroussi/quantstats/issues/537).

**[kennethreitz/records](evals/records/REPORT.md)** (7,220 stars, loop run, **converged**). At upstream HEAD, `pytest` says 31 passed. At the same HEAD, `INSERT`s silently lose data, `transaction()` swallows every exception, and every query leaks a pooled connection. Jeffy reproduced **four High-severity bugs hiding behind a green test suite**, closed three with one structural fix at the boundary they share, restored a fix upstream had reverted the same day it was made, and left a regression suite proven to fail on the old code - [`repro.py`](evals/records/repro.py) shows the bugs on upstream HEAD, [`fixes.patch`](evals/records/fixes.patch) makes it show them fixed. Findings were disclosed upstream with repros and a PR offer in [kennethreitz/records#236](https://github.com/kennethreitz/records/issues/236).

**[PyPortfolio/PyPortfolioOpt](evals/pyportfolioopt/REPORT.md)** (5,905 stars, loop run, **converged**) - the run where the gate proved it cannot be bluffed. Portfolio optimization with its own CI red on the default branch: six runs, 58 iterations, the suite from **5 failed to 356 passed**, and **37 findings filed, 36 closed, five of them High** - `bl_weights()` **inverting every position** whenever the implied portfolio is net short, `min_cov_determinant` understating variance by more than half, the tail-risk classes reporting a CVaR **overstated by up to 50.7%** against the very weights they returned. The adversarial evaluator rejected **five convergence attempts before its PASS**, every rejection filing real work - and in run 5 it passed and the run *still* refused to converge over a defect the evaluator had just found in the run's own work: "the gate is worth more than the convergence line." The Stop hook then rejected the first declaration too, and convergence landed only when every gate held at once. The receipt is honest in both directions: a 13-check repro from an earlier manual audit of the same commit scores **8 of 13** at the converged tree - three **distributional defects** remain, named plainly - while the loop filed 32 findings that audit never saw. Findings were disclosed upstream in [PyPortfolio/PyPortfolioOpt#750](https://github.com/PyPortfolio/PyPortfolioOpt/issues/750), and the CI-red fix went up as [PR #751](https://github.com/PyPortfolio/PyPortfolioOpt/pull/751) with a regression test proven to fail on their master.

**[iamkun/dayjs](evals/dayjs/REPORT.md)** (48,657 stars, loop run, **converged**) - the run that named the third boundary. The date library, 63M downloads a week: eight runs, 74 iterations, the suite from 773 tests to **1,230 with the 100 percent line-coverage bar held**, and **45 findings closed, 10 High** - the core parser reading ISO fractional seconds as an integer count of milliseconds so `.5` meant 5ms; a failed build that **reported success straight into the publish workflow**; the Sinhala locale shipping lunar month names so every `si` date named the wrong month; December parsed in one of 12 two-arm locales landing in **the following year**; format-then-parse round-trips coming back 12 hours off. Fourteen defect classes settled with enumerations over all 143 locales, all 181 bundle entries, and **40 shipped declaration files no compiler had ever checked**. The adversarial evaluator rejected three times across the conversion - one rejection surfaced a High and a Medium the run had introduced itself - and the closing run's audit reversed its predecessor's wrong "blocked" verdict with a deterministic instrument before converging. The receipt's boundary is the starkest yet: the earlier manual audit's five-check timezone repro scores **1 of 5 at the converged tree, the identical score pristine upstream gets**, because the loop never entered the timezone plugin - single-host probes cannot see **host-environment defects**, the third boundary class after quantstats' convention defects and PyPortfolioOpt's distributional defects, and the receipt proves it by running the full suite under a real Whitehorse host, where the converged tree fails the same 4 timezone tests upstream does. First disclosure went upstream as a pull request rather than an issue - the channel a 968-issue backlog is most likely to read: [iamkun/dayjs#3167](https://github.com/iamkun/dayjs/pull/3167), the one-line fractional-seconds fix, with a regression test proven to fail on their dev.

**[janl/mustache.js](evals/mustache.js/REPORT.md)** (16,725 stars, loop run, **converged**). At upstream HEAD on current Node, the test suite **cannot start** - the abandoned `esm` shim crashes before a single assertion - and `bin/mustache` crashes outright. Jeffy revived the gate with one structural fix across all three loading sites, fixed a second reproduced correctness bug in the CLI with a regression test, deleted the dead browser-test stack, and modernized the toolchain, taking `npm audit` from **107 vulnerabilities (24 critical) to 2 lows** with the suite at 297 passing, official Mustache spec compliance included. The closing audit then filed a Medium against the run's own earlier work - docs still pointing at the deleted stack - and fixed it before declaring convergence. Findings were disclosed upstream with repros and a PR offer in [janl/mustache.js#848](https://github.com/janl/mustache.js/issues/848).

**[bukosabino/ta](evals/ta/REPORT.md)** (5,129 stars, loop run, **converged**) - the hardest target in this set. Technical-analysis indicators, dormant since 2023, no GitHub Actions run ever, and a test suite already **red at upstream HEAD**. Six runs and 64 iterations, every one checkpointed. Parabolic SAR mixed label-based and positional writes on the same Series, so on the project's own quickstart path it returned **46,465 rows for a 46,306-bar input**, 9,408 of them wrong, worst error 3,410.89. On-Balance Volume adds volume on bars where the close is unchanged, against the definition its own docstring cites: 85 of 399 bars are flat on real data and the series ends at **1631.93 against 533.44**, a 205.9 percent error that compounds monotonically, invisible because the fixture has no flat bar in its 30 rows. Fourteen defect classes were closed **class-complete**, each with an enumerating check over all 43 indicator classes rather than a patched instance, and three findings were **declined** - one because the premise was wrong and extending the loop as the task asked raised `KeyError: 120`. It caught itself: a seeding change it made at iteration 6 turned KAMA into a constant, and its own audit found it ten iterations later and wrote *"It is mine"* - after a green suite, 100 percent line coverage and a targeted sweep had all passed over the defect, because "no NaN and no infinity" is satisfied by a constant. It then ran the CI documentation job, which four jobs of config had defined and **nobody had ever executed**, and when that surfaced two trivially fixable warnings in code untouched since the convergence commit it refused to fix them, routing both to Proposed because the ratchet rule said so and, in its own words, fixing them unasked "would have been the rule bending to convenience." Final state: **134 tests with 2 errors to 211 passing**, coverage 100 percent of 1,388 statements, `prospector` at `veryhigh` clean across both trees with all eight tools. It wrote **2,112 lines of tests against 958 lines of source changes**. The adversarial evaluator gate did not run - that session carried a standing instruction against sub-agents, and the receipt records it as `unavailable` rather than papering over it. Findings were not disclosed upstream: the project has been dormant since 2023 with red CircleCI on HEAD and no merged pull request in over two years.

**[sivel/speedtest-cli](evals/speedtest-cli/REPORT.md)** (14,080 stars, loop run, **converged**). The restraint case: dormant since 2021 but fundamentally sound, where the honest outcome is small findings and nothing invented. Jeffy fixed the project's own lint gate - red on unchanged code from eight Python 2 builtin false positives - with one structural config change and zero `noqa` comments, removed a dead Travis badge advertising CI that had not run in years, and routed the decisions it had no right to make - the Python version floor, the CI replacement, the hostile-server parsing posture - to the owner under Proposed. The sandbox's unreachable live-network test legs were recorded as an environment limitation, never counted as a finding. Findings were not disclosed upstream: the repository does not accept issues, so the offer-first channel the other disclosures used does not exist here.

**[chalk/chalk](evals/chalk/REPORT.md)** (23,288 stars, loop run, **converged**) - the control, and the one that got fixed. One of the best-maintained small libraries alive, chosen to test whether the loop invents problems where there are none. The core survived clean: correctness, security and architecture all scored None on first pass, vendored code was declined rather than churned, and a semver-major engines bump was routed to the owner instead of seized. The audit still had teeth, surfacing one genuine reproduced Medium - `ansi256` skips level downconversion, contradicting the readme's promise. Findings were disclosed upstream with repros and a PR offer in [chalk/chalk#686](https://github.com/chalk/chalk/issues/686) - a chalk contributor reproduced it independently and called it surprising that it had not surfaced sooner given how heavily chalk is used, the project owner then wrote and merged [#687](https://github.com/chalk/chalk/pull/687) implementing exactly that fix, and it **shipped in [chalk v6.0.0](https://github.com/chalk/chalk/releases/tag/v6.0.0)**.

Two more receipts live under [`evals/`](evals/) - [PapaParse](evals/papaparse/REPORT.md) and [yfinance](evals/yfinance/REPORT.md) - audits under the same rules that have not yet been converted to loop runs; each will be. The upstream engagement recorded there stays live: four PapaParse pull requests ([#1133](https://github.com/mholt/PapaParse/pull/1133)-[#1136](https://github.com/mholt/PapaParse/pull/1136)) and [yfinance#2927](https://github.com/ranaroussi/yfinance/pull/2927) are open, each carrying a regression test proven to fail on the unpatched upstream branch it targets.

Disclosure is deliberate and selective. Filing a machine-generated issue costs a maintainer real attention, so these findings go upstream only where the defect is severe and the project takes outside contributions; where nothing was filed, the receipt says so and why.

## Install

Install Claude Code first from https://claude.com/claude-code and sign in once, and have git available: they are the only prerequisites the installer cannot handle for you. Then clone and run the installer.

Windows (PowerShell):

```powershell
git clone https://github.com/lenamonj/jeffy-loop.git
cd jeffy-loop
.\install.ps1
```

If PowerShell blocks the script with "running scripts is disabled on this system", run it once with `powershell -ExecutionPolicy Bypass -File .\install.ps1`, which applies the bypass to that single invocation only.

macOS / Linux:

```bash
git clone https://github.com/lenamonj/jeffy-loop.git
cd jeffy-loop
./install.sh
```

The installer verifies the Claude Code CLI, verifies `jq` (offering to install it via winget, Homebrew, or apt if missing), copies the `/jeffy` and `/cancel-jeffy` skills - engine included - to `~/.claude/skills`, and registers the loop's hook in `~/.claude/settings.json`. Every step prints an [OK] or the exact fix. Re-running is always safe: it skips what is installed, upgrades in place, and never duplicates the hook registration. To update later, `git pull` and re-run the installer. To uninstall, delete `~/.claude/skills/jeffy` and `~/.claude/skills/cancel-jeffy` and remove the hook entry from `~/.claude/settings.json`.

### Use it

Start a new Claude Code session in the project you want to improve and run `/jeffy`.

## Usage

```
/jeffy [N] [focus...]
```

- `N` - iteration budget, default 10. Sizing is low-stakes in both directions: the loop ends itself at convergence, so unused budget costs nothing, and a budget that runs dry loses no work - the state files persist, so the next `/jeffy` picks up where the run stopped. The floor for converging in one run is the opening audit, one iteration per expected finding, and a closing audit; when that arithmetic outgrows the default, prefer a second run over a bigger number (see Good to know).
- `focus` - optional directive for the run, e.g. `/jeffy 8 test coverage and error handling`.

Examples:

```
/jeffy            # 10 iterations, full-spectrum improvement
/jeffy 5          # 5 iterations
/jeffy 12 accessibility and performance
```

### Scoped mode

By default `/jeffy` runs in Improvement mode: an open-ended audit-and-fix loop. To run it against a concrete target instead, edit `PLAN.md`: replace the Goal and Definition of done with the target, seed `BACKLOG.md` with the finite tasks, then run `/jeffy`. Everything else (envelope, verify gate, checkpoints, journal, report) behaves the same.

## The rules a run lives by

Each rule is enforced by the iteration prompt, the state files, or the Stop hook itself - not by good intentions.

- **One verified task per iteration.** Every task carries a runnable acceptance check; done means the check ran and passed. Three failed fix attempts mark the task blocked with a reason instead of thrashing.
- **Checkpoint everything, push nothing.** Every iteration ends in a local commit prefixed `jeffy:` - the revert and recovery unit. No pushes, no branches; pre-flight warns on a dirty tree so your work is never swept into a checkpoint. Without git, checkpoints degrade to journal-only discipline.
- **The verify gate guards every change.** An iteration that newly breaks the verify command recorded in `PLAN.md` is reverted on the spot and its task marked blocked.
- **Interrupted work is salvaged, never discarded.** A run that resumes over a dirty tree commits the salvage before touching anything.
- **Audits work from a written map, never from wandering.** The first audit lists the whole public surface as a checkbox inventory in `PLAN.md` and probes it breadth-first before filing anything. Every sweep records the commit it certified, a row reopens when its code changes, dimension scores claim only swept rows, and no run converges while a row is unswept.
- **Sweeps prove correctness, not liveness.** A row that computes values needs a known answer or a strong invariant - run-without-crashing certifies nothing - and every documented parameter must be shown to change the output at two or more values. A parameter whose value changes nothing is a finding, never a pass.
- **Severity comes from the envelope, never from imagination.** Envelope changes and audit escalations go to the Proposed section of `BACKLOG.md` for your approval - the loop never widens its own mandate.
- **Changes are made with the map open.** Before touching shared code the loop reads its callers and the tests that pin it and states the contract the change preserves; a change that alters behavior updates the documentation and reopens the affected inventory rows in the same iteration.
- **The third strike forces structure.** Repeated-idiom fixes must enumerate and cover every sibling site; the third finding sharing one root cause forces a single structural fix or a user decision, never a fourth spot patch.
- **Published code is run code.** Anything that leaves the project - an issue body, a report, a pull request - must have been executed in exactly the form it is published. A trimmed version of a verified script is new, unverified code.
- **Convergence is sticky.** The converged commit is recorded; relaunching on an unchanged tree re-verifies and re-converges in O(1) instead of re-rolling the audit dice. A seeded backlog or a focus directive always gets a real run, and settled defect classes are never re-litigated on unchanged code.
- **Convergence needs the adversarial evaluator's signature.** One fresh-context sub-agent that assumes the work is broken re-runs the checks itself, bound by the same envelope and evidence rules. At most two reviews per run; a second rejection ends the run; a session that cannot spawn sub-agents records that instead of silently skipping the gate. The ratchet never invokes it.
- **The converged stop is enforced in shell.** At the promise the Stop hook itself re-checks: no open task, a Converged line whose commit still certifies the tree, no unswept inventory row, and the project's verify command exiting 0, re-run by the hook under a timeout (240s default, `verify_timeout_seconds` to override; the installer registers the hook at 600s - re-run it after upgrading). Violations block the stop and re-feed the evidence; missing infrastructure fails open with a stderr diagnostic.
- **Every iteration answers for its hygiene.** Between iterations the hook checks the journal entry (heading grammar, with a run token telling two runs in one session apart), the checkpoint, and that `JOURNAL-archive.md` only ever grows. Violations ride the next re-feed as an ITERATION HYGIENE note.
- **Stalls end runs before budgets do.** Progress means HEAD moved or `BACKLOG.md` changed. The first flat iteration re-feeds with a STALL note; a second consecutive one ends the run from shell. Without git the ledger signal alone decides.
- **Lessons persist.** An operational rule learned the hard way - a build quirk, a command that must not be used - is promoted to the Lessons section of `PLAN.md`, which every future iteration reads in full. Add your own lines there to steer future runs: fix the loop, not the run.

## Cancel

Run `/cancel-jeffy`. It reports which loop it found, deletes the loop state file, and leaves `PLAN.md`, `BACKLOG.md`, and `JOURNAL.md` untouched, so the next `/jeffy` picks up exactly where it left off. (Equivalent manual action: delete `.claude/jeffy-loop.local.md` at the project root.)

## Good to know

- One loop per project at a time. A crashed session can leave a stale state file behind; the skill detects it at launch and asks before cleaning up.
- You can talk to the session mid-run: your message gets answered, then the loop resumes on its own. The turn counts against the budget.
- Permission prompts pause the loop. For unattended runs, allowlist your test and file tools or use acceptEdits mode. Never allowlist push or force operations for a loop.
- Budget counts turns, and a single turn is unbounded in time and cost - keep N small on a first run and watch it. Check spend anytime with `/cost`.
- Prefer several small runs over one big one. The engine re-feeds the same session, so context accumulates across iterations within a run; the state files persist between runs and convergence is sticky, so two runs of 5 beat one run of 10. The clean context only arrives with a new session, though: relaunching `/jeffy` in the session that just finished keeps every accumulated token and forfeits the benefit. Close the session and start a fresh one in the same directory - the state files carry the run forward, nothing is lost.
- Edit `PLAN.md` or `BACKLOG.md` between iterations, not mid-iteration; the Proposed section is the designed channel for decisions.
- Trust model: the entire engine is one auditable shell script in this repo (`skills/jeffy/hooks/stop-hook.sh`), registered as a Claude Code Stop hook. It fires at turn end but exits instantly unless the current project has a live Jeffy state file naming that session - zero cost and zero behavior outside a run. The installer's only writes outside this repo are the two skill folders it copies into `~/.claude/skills` (engine included) and that one hook registration in `~/.claude/settings.json`.

## Contributing

Before submitting a change, run the repo validator:

```bash
bash scripts/validate.sh
```

It gates, among other things:

- **Syntax and lint** - both installers and the Stop hook (`bash -n`, PowerShell parser, shellcheck).
- **Skill integrity** - frontmatter, referenced paths, the governance markers that keep the envelope, ratchet, verify gate, run report, and convergence rules from silently regressing - including the `Command:` line the default plan hands the hook to run - and the iteration prompt's injection invariants.
- **Behavior, not just parsing** - both installers run non-interactively against sandboxed profiles (skills and engine must land, and the hook registration must appear exactly once even after a re-run and carry the 600s timeout, whether written fresh or upgraded from an older entry), and the Stop hook itself is exercised through its full lifecycle: mid-budget re-feed, budget exhaustion, completion promise, foreign-session isolation, and the no-state no-op. The gates that guard the converged stop are held to the same standard - an open task, a `Converged` line that no longer certifies the tree, an unswept Surface inventory row, and a verify command that is red, that overruns its timeout, or that is declared `none` each have to produce the right outcome, a fully swept inventory and a pre-inventory `PLAN.md` are both accepted, and the verify parser is proven on both plan shapes, the labelled `Command:` line and the bare first-line form - as are the per-iteration hygiene gates and the fail-open paths for a missing ledger, journal, or plan, a malformed counter, and a moved prompt file. The hygiene gates are proven both ways too: a journal heading that names the session but not the run is rejected and a legacy state file without a run token falls back cleanly, and a rotation that shrinks or deletes `JOURNAL-archive.md` is caught while an appending one passes and a never-rotated project is left alone. The stall gate is proven the same way: progress on either signal stays silent, the first flat iteration draws the STALL note and arms the flag, the second consecutive one ends the run, progress resets the strike, a non-git project stalls out on the ledger signal alone, a project with neither signal skips with a stderr note, and neither budget exhaustion nor a valid promise is disturbed by an armed flag.

Core checks need only bash and coreutils; shellcheck, PowerShell, and jq passes skip cleanly when absent. CI runs the same validator on Linux and Windows.

## License

MIT
