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
  <img src="media/flowchart-light.png" alt="Flowchart of a /jeffy run: the launch skill bootstraps the state files, each iteration audits or executes one verified task and checkpoints it, a fresh-context skeptical evaluator countersigns convergence, and the Stop hook re-feeds the loop until convergence, budget end, or a blocker - all steered by three files and the git log." width="830">
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

- **It cannot wreck your repo.** Every iteration ends in a local checkpoint commit. A repo-level verify gate runs every iteration, and an iteration that breaks the project is reverted on the spot. Nothing is ever pushed, no branches are created. Review with `git log`, revert any single iteration, squash the run when you're happy.

- **It doesn't invent problems.** Severity is judged against a declared operating envelope - your project's real input surfaces, not imagined attackers. Out-of-envelope findings can't inflate the backlog, and only you can widen the envelope: the loop files a proposal and moves on.

- **Done means done.** The loop converges only when a full fresh audit finds zero High and zero Medium findings *and* the backlog is empty - every Low either fixed or explicitly declined with a reason. No trail of "minor" issues quietly left behind. And the declaration is countersigned: an agent grading its own work praises it, so before the loop may claim convergence, a fresh-context skeptical evaluator - a sub-agent carrying none of the run's self-persuasion - re-runs the verify gate and the closed tasks' acceptance checks, hunts for missed findings in the run's changes, and must return PASS. A rejection files its evidence as new tasks and the run continues. And the promise itself is machine-checked: the Stop hook - plain shell, not a model - refuses the converged stop unless the task ledger is empty, the recorded Converged commit certifies the tree (nothing but loop state changed since it), and the project's own verify command exits green when the hook re-runs it under a timeout. A failed check re-feeds the loop with the evidence instead of letting the run end. And the run is bounded at the other end too: once one full audit comes back clean of High and Medium, the loop stops auditing for the rest of that run and finishes what is on the ledger. Without that stop a project with a long tail of Low findings never finishes, because every drained backlog triggers another audit that files another Low - productive forever, and never done.

- **It knows when to stop.** Budget spent, convergence reached, progress stalled, or a decision only you can make - the loop ends itself and says why, instead of burning budget spinning.

- **Every run ends with a report.** Iterations used, tasks closed with severities, the run's diffstat, anything blocked, and decisions waiting on you. An append-only journal and the checkpoint commits hold the full, greppable record.

## What it does

Running `/jeffy` in a Claude Code session:

1. Bootstraps three files at the project root: `PLAN.md` (goal, operating envelope, method, verify command, definition of done), `BACKLOG.md` (prioritized tasks, worst severity first), `JOURNAL.md` (append-only iteration log). They persist between runs - they are the loop's memory.
2. Launches a budgeted loop. Each iteration either audits the project or executes exactly one backlog task and verifies its acceptance check; every iteration runs the verify command and ends in a local checkpoint commit.
3. Stops at the budget, at convergence (clean audit, empty backlog), on a stall, or when you cancel - and closes with the run report.

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

Self-runs are easy mode. So Jeffy was pointed at ten real, famous, unaffiliated projects - every one in a local clone, nothing pushed upstream, all of it held to the same rules: evidence before filing, severity judged against a declared envelope, one verified fix at a time, and a reproduction script anyone can run. Every receipt below carries a `repro.py` or `repro.js` that fails on the project's own unmodified code and passes against the patch, so none of this has to be taken on trust.

Two things are worth knowing before the list. **Four of these were full `/jeffy` loop runs** (records, mustache.js, speedtest-cli, chalk), which is why their receipts quote iteration counts and convergence. **Six were audits run under Jeffy's method and rules** but not through the loop, because the loop needs its own session per project; they are marked *audit* below. And **every single audit disproved at least one bug report it was handed.** A tracker issue is a hypothesis, not a finding, and the difference between those two is most of what this section is testing.

Ordered by what was found, worst first.

**[ranaroussi/quantstats](evals/quantstats/REPORT.md)** (7,485 stars, *audit*). Portfolio analytics whose output goes straight into investor-facing tearsheets. Five High findings, all provable against closed-form answers. `kelly_criterion` returns the growth-optimal fraction **multiplied by the average loss** - on a series whose true Kelly is 39.9985, it returns 0.399985, and it is scale-invariant where real Kelly is not. The risk-free rate is routed by inspecting the **call stack**, so `cagr(r, rf=0.00)` and `cagr(r, rf=0.50)` return an identical number, and `reports.py` proves the intent by passing `rf` on one line and `0.0` on another. `aggregate_returns` silently no-ops on its own documented `'M'`, `'Q'` and `'Y'` arguments, so `best(aggregate='Y')` returns the best *day*. Two of the leads it was given were **declined with evidence** as defensible convention, and the arithmetic-versus-geometric information ratio complaint was refused while the genuine defect in that same function - a missing annualization worth exactly `sqrt(252)` - was fixed. Findings were disclosed upstream with repros and a PR offer in [ranaroussi/quantstats#537](https://github.com/ranaroussi/quantstats/issues/537).

**[kennethreitz/records](evals/records/REPORT.md)** (7,220 stars, loop run). At upstream HEAD, `pytest` says 31 passed. At the same HEAD, `INSERT`s silently lose data, `transaction()` swallows every exception, and every query leaks a pooled connection. Jeffy reproduced **four High-severity bugs hiding behind a green test suite**, closed three with one structural fix at the boundary they share, restored a fix upstream had reverted the same day it was made, and left a regression suite proven to fail on the old code - [`repro.py`](evals/records/repro.py) shows the bugs on upstream HEAD, [`fixes.patch`](evals/records/fixes.patch) makes it show them fixed. Findings were disclosed upstream with repros and a PR offer in [kennethreitz/records#236](https://github.com/kennethreitz/records/issues/236).

**[ranaroussi/yfinance](evals/yfinance/REPORT.md)** (24,812 stars, *audit*). The market-data client, audited across its price-repair module. The bug report it was chasing turned out to be **wrong on two of its three claims**, and what the audit found instead is worse: after repairing one bad block, the module rescales the **entire table** and inverts the **entire** repair-flag array. A pence-quoted table containing one genuine 100x block came back with all 90 rows 100x too large, 20 broken rows flagged clean, and 40 clean rows flagged as repaired; the control with that branch skipped got 0 of 90 wrong. Four High findings in all, including a crash reachable from upstream's own committed test fixture. The patch leaves all 42 of the project's golden fixtures byte-identical apart from the one it fixes. Findings were disclosed upstream with repros and a PR offer in [ranaroussi/yfinance#2924](https://github.com/ranaroussi/yfinance/issues/2924).

**[mholt/PapaParse](evals/papaparse/REPORT.md)** (13,532 stars, *audit*). The CSV parser, 14.3M downloads a week. Four High findings in the streaming path: a multi-byte UTF-8 character split across a chunk boundary decodes to `U+FFFD`; the line ending is guessed from a truncated first chunk and then cached for the whole file, leaving a stray `\r` on every last field with no error and a correct row count; header dedupe re-runs on every resumed row and rewrites data in place; and `pause()` applies no backpressure at all, so a 400 MB stream dies with a heap out-of-memory while the unpaused control finishes at 78 MB. A failing regression test sits at HEAD for a bug the project already fixed once. The quoted-field chunk-boundary case, the one most likely to be broken, was tested exhaustively and found **correct**, and is kept as a guard. Findings were disclosed upstream with repros and a PR offer in [mholt/PapaParse#1132](https://github.com/mholt/PapaParse/issues/1132) - a collaborator asked for one pull request per issue with a test for each, and the four High findings went up as [#1133](https://github.com/mholt/PapaParse/pull/1133), [#1134](https://github.com/mholt/PapaParse/pull/1134), [#1135](https://github.com/mholt/PapaParse/pull/1135) and [#1136](https://github.com/mholt/PapaParse/pull/1136), each carrying a regression test proven to fail on master.

**[PyPortfolio/PyPortfolioOpt](evals/pyportfolioopt/REPORT.md)** (5,894 stars, *audit*). Portfolio optimization, with its own CI red on the default branch - traced to a scipy 1.18 removal against an unbounded version pin. Four High findings. The worst is quiet: a stale slice produces off-budget turning points in **50 of 300** ordinary problems, which the library's own error purge then deletes, leaving the optimizer to interpolate across the gap and return **22 of 300 portfolios that are silently suboptimal**, worst case 2.02% of Sharpe. Equal expected returns, a perfectly ordinary input, raise a raw `TypeError` in 244 of 300 cases. The reported non-determinism **did not reproduce** across 400 repeats and four hash seeds, and the obvious one-line fix for the equal-returns crash was implemented, measured, and **rejected** for making 256 of 300 cases silently worse. Findings were disclosed upstream with repros and a PR offer in [PyPortfolio/PyPortfolioOpt#750](https://github.com/PyPortfolio/PyPortfolioOpt/issues/750).

**[iamkun/dayjs](evals/dayjs/REPORT.md)** (48,655 stars, *audit*). The date library, 63M downloads a week. The reported "wrong year" bug is **not a defect** - west of Greenwich the input really is the previous local day, and moment returns the identical value on the same host; it is a timezone-fragile test fixture. Chasing the failures that survived correct measurement found three High defects instead, all host-dependent, in a library whose entire job is to be host-independent: `tz()` shifts by a delta computed from the machine's own offset, ambiguous local times are resolved from `Date.now()` so the same call answers differently in January and July, and arithmetic after `tz()` keeps a frozen offset. It also found why nobody noticed - the CI timezone matrix runs six tests. Core DST arithmetic came out **clean** across 100 checks against moment. Findings were not disclosed upstream: against a 968-issue backlog the useful result here is a correction to an existing report rather than a new one.

**[janl/mustache.js](evals/mustache.js/REPORT.md)** (16,726 stars, loop run). At upstream HEAD on current Node, the test suite **cannot start** - the abandoned `esm` shim crashes before a single assertion - and `bin/mustache` crashes outright. Jeffy revived the gate with one structural fix across all three loading sites, fixed a second reproduced correctness bug in the CLI with a regression test, deleted the dead browser-test stack, and modernized the toolchain, taking `npm audit` from **107 vulnerabilities (24 critical) to 2 lows** with the suite at 297 passing, official Mustache spec compliance included. The closing audit then filed a Medium against the run's own earlier work - docs still pointing at the deleted stack - and fixed it before declaring convergence. Findings were disclosed upstream with repros and a PR offer in [janl/mustache.js#848](https://github.com/janl/mustache.js/issues/848).

**[bukosabino/ta](evals/ta/REPORT.md)** (5,129 stars, loop run) - the hardest target in this set, and the one that proves the loop rather than the method. Technical-analysis indicators, dormant since 2023, no GitHub Actions run ever, and a test suite already **red at upstream HEAD**. Six runs and 64 iterations, every one checkpointed. Parabolic SAR mixed label-based and positional writes on the same Series, so on the project's own quickstart path it returned **46,465 rows for a 46,306-bar input**, 9,408 of them wrong, worst error 3,410.89. On-Balance Volume adds volume on bars where the close is unchanged, against the definition its own docstring cites: 85 of 399 bars are flat on real data and the series ends at **1631.93 against 533.44**, a 205.9 percent error that compounds monotonically, invisible because the fixture has no flat bar in its 30 rows. Fourteen defect classes were closed **class-complete**, each with an enumerating check over all 43 indicator classes rather than a patched instance, and three findings were **declined** - one because the premise was wrong and extending the loop as the task asked raised `KeyError: 120`. It caught itself: a seeding change it made at iteration 6 turned KAMA into a constant, and its own audit found it ten iterations later and wrote *"It is mine"* - after a green suite, 100 percent line coverage and a targeted sweep had all passed over the defect, because "no NaN and no infinity" is satisfied by a constant. It then ran the CI documentation job, which four jobs of config had defined and **nobody had ever executed**, and when that surfaced two trivially fixable warnings in code untouched since the convergence commit it refused to fix them, routing both to Proposed because the ratchet rule said so and, in its own words, fixing them unasked "would have been the rule bending to convenience." Final state: **134 tests with 2 errors to 211 passing**, coverage 100 percent of 1,388 statements, `prospector` at `veryhigh` clean across both trees with all eight tools. It wrote **2,112 lines of tests against 958 lines of source changes**. The independent evaluator gate did not run - that session carried a standing instruction against sub-agents, and the receipt records it as `unavailable` rather than papering over it. Findings were not disclosed upstream: the project has been dormant since 2023 with red CircleCI on HEAD and no merged pull request in over two years.

**[sivel/speedtest-cli](evals/speedtest-cli/REPORT.md)** (14,082 stars, loop run). The restraint case: dormant since 2021 but fundamentally sound, where the honest outcome is small findings and nothing invented. Jeffy fixed the project's own lint gate - red on unchanged code from eight Python 2 builtin false positives - with one structural config change and zero `noqa` comments, removed a dead Travis badge advertising CI that had not run in years, and routed the decisions it had no right to make - the Python version floor, the CI replacement, the hostile-server parsing posture - to the owner under Proposed. The sandbox's unreachable live-network test legs were recorded as an environment limitation, never counted as a finding. Findings were not disclosed upstream: the repository does not accept issues, so the offer-first channel the other disclosures used does not exist here.

**[chalk/chalk](evals/chalk/REPORT.md)** (23,287 stars, loop run) - the control, and the one that got fixed. One of the best-maintained small libraries alive, chosen to test whether the loop invents problems where there are none. The core survived clean: correctness, security and architecture all scored None on first pass, vendored code was declined rather than churned, and a semver-major engines bump was routed to the owner instead of seized. The audit still had teeth, surfacing one genuine reproduced Medium - `ansi256` skips level downconversion, contradicting the readme's promise. Findings were disclosed upstream with repros and a PR offer in [chalk/chalk#686](https://github.com/chalk/chalk/issues/686) - a maintainer reproduced it independently and said he was surprised it had not surfaced sooner given how heavily chalk is used, the project owner then wrote and merged [#687](https://github.com/chalk/chalk/pull/687) implementing exactly that fix, and it **shipped in [chalk v6.0.0](https://github.com/chalk/chalk/releases/tag/v6.0.0)**.

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

- Every task carries a concrete acceptance check; a task is done only when its check has been run and observed to pass (at most 3 fix attempts, then it is marked blocked with a reason).
- Every iteration ends in a local checkpoint commit prefixed `jeffy:` - the revert and recovery unit. Nothing is ever pushed, no branches are created. Pre-flight warns if your tree is dirty at launch so uncommitted work is never swept into a checkpoint. (Without git, checkpoints degrade to journal-only discipline.)
- The verify command recorded in `PLAN.md` runs every iteration; an iteration that newly breaks it is reverted and its task marked blocked.
- An interrupted run salvages its dirty tree into a commit and continues. Work is never reset or discarded.
- Two consecutive no-progress iterations end the loop as a hard blocker instead of burning budget. The Stop hook enforces this itself; see the shell-enforcement rule below.
- Severity comes from the operating envelope, never from imagination; envelope changes and audit escalations go to the Proposed section of `BACKLOG.md` for your approval - the loop never widens its own mandate.
- Convergence is sticky: the converged commit is recorded, and relaunching on an unchanged tree with an empty backlog re-verifies and re-converges immediately instead of re-rolling the audit dice. A seeded backlog or a focus directive always gets a real run. Settled defect classes are not re-litigated on unchanged code.
- Convergence needs a second signature. The closing declaration is gated by one independent fresh-context evaluator sub-agent that assumes the work is broken, re-runs the checks itself, and is bound by the same envelope and evidence rules as the audit. At most two evaluator reviews per run - a second rejection ends the run as a blocker with the reasons in the report - and a session that cannot spawn sub-agents records that in the journal and report instead of silently skipping the gate. The sticky-convergence ratchet, which re-verifies a mechanical fact rather than a judgment, never invokes it.
- The converged stop is enforced in shell, not just prompted. At the promise the Stop hook itself checks three things: no open task in Now, Next, or Later; the latest Converged line naming a commit with nothing but loop state changed since it; and the project's verify command - the one on the `Command:` line of `PLAN.md` - exiting 0, re-run by the hook under a timeout (240s default, `verify_timeout_seconds` in the loop state file to override). Violations block the stop and re-feed with the evidence; a missing ledger or verify infrastructure fails open with a stderr diagnostic rather than trapping the session. The installer registers the hook with a 600s timeout so the verify run fits; re-run the installer after upgrading so an older registration gains the field. Between iterations the same hook runs two hygiene gates: the finished iteration must have journaled itself under the heading grammar and checkpointed its tracked changes, or the next re-feed carries an ITERATION HYGIENE note naming exactly what is missing. Untracked files never trip it - they belong to salvage and the next checkpoint's sweep. The hook also watches for stalls: progress means HEAD moved or `BACKLOG.md` changed since the previous turn end, so an audit that files tasks counts and journal-only churn does not. The first flat iteration re-feeds with a STALL note naming the evidence, a second consecutive one ends the run from shell the way the budget stop does, and any progress resets the strike. Without git the ledger signal alone decides; a project with neither signal skips the check with a stderr diagnostic.
- Lessons persist. An operational rule the loop learns the hard way - a build quirk, a command that must not be used - is promoted to the Lessons section of `PLAN.md`, which every future iteration reads in full. Add your own lines there to steer future runs: fix the loop, not the run.
- Repeated-idiom fixes must enumerate and cover every sibling site to count as done; the third finding sharing one root cause forces a single structural fix or a user decision, never a fourth spot patch.

## Cancel

Run `/cancel-jeffy`. It reports which loop it found, deletes the loop state file, and leaves `PLAN.md`, `BACKLOG.md`, and `JOURNAL.md` untouched, so the next `/jeffy` picks up exactly where it left off. (Equivalent manual action: delete `.claude/jeffy-loop.local.md` at the project root.)

## Good to know

- One loop per project at a time. A crashed session can leave a stale state file behind; the skill detects it at launch and asks before cleaning up.
- You can talk to the session mid-run: your message gets answered, then the loop resumes on its own. The turn counts against the budget.
- Permission prompts pause the loop. For unattended runs, allowlist your test and file tools or use acceptEdits mode. Never allowlist push or force operations for a loop.
- Budget counts turns, and a single turn is unbounded in time and cost - keep N small on a first run and watch it. Check spend anytime with `/cost`.
- Prefer several small runs over one big one. The engine re-feeds the same session, so context accumulates across iterations within a run; the state files persist between runs and convergence is sticky, so two runs of 5 beat one run of 10, and each relaunch starts with a clean context.
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
- **Behavior, not just parsing** - both installers run non-interactively against sandboxed profiles (skills and engine must land, and the hook registration must appear exactly once even after a re-run and carry the 600s timeout, whether written fresh or upgraded from an older entry), and the Stop hook itself is exercised through its full lifecycle: mid-budget re-feed, budget exhaustion, completion promise, foreign-session isolation, and the no-state no-op. The gates that guard the converged stop are held to the same standard - an open task, a `Converged` line that no longer certifies the tree, and a verify command that is red, that overruns its timeout, or that is declared `none` each have to produce the right outcome, and the verify parser is proven on both plan shapes, the labelled `Command:` line and the bare first-line form - as are the per-iteration hygiene gates and the fail-open paths for a missing ledger, journal, or plan, a malformed counter, and a moved prompt file. The stall gate is proven the same way: progress on either signal stays silent, the first flat iteration draws the STALL note and arms the flag, the second consecutive one ends the run, progress resets the strike, a non-git project stalls out on the ledger signal alone, a project with neither signal skips with a stderr note, and neither budget exhaustion nor a valid promise is disturbed by an armed flag.

Core checks need only bash and coreutils; shellcheck, PowerShell, and jq passes skip cleanly when absent. CI runs the same validator on Linux and Windows.

## License

MIT
