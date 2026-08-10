# Jeffy eval: rubocop/rubocop

**Target**: [rubocop/rubocop](https://github.com/rubocop/rubocop) (12,892 stars) at master tip `68bd0839` on the day of the run, Ruby 3.3.8 - run in a local clone; nothing was pushed upstream. The sixth language in this set.

**The frame, stated honestly.** chalk was chosen as a control, expected to be clean. RuboCop was not: it was chosen because its maintainers merge outside bugfix PRs daily, on the theory that a project with that intake rate would have something worth filing. It came back clean anyway. That makes this the set's second control-grade result, and the more meaningful one, because nobody picked it to be clean.

**The headline**: one run, seven iterations, converged with an adversarial evaluator countersignature - and **zero findings filed at any severity, zero lines of project code changed**. The certified tree `ce05341` differs from upstream `68bd0839` by 225 inserted lines of loop bookkeeping (PLAN.md, BACKLOG.md, JOURNAL.md) and nothing else. There is no fixes.patch in this receipt because there is nothing to patch. A loop that filed 45 findings against dayjs and 31 against fasthttp filed none here, which is the point: the method does not manufacture work to justify its budget.

## What "clean" was earned against

A null result is a claim about the surface examined, so here is the surface. The first audit built a 21-row inventory and the run swept all of it:

- **Every cop department** - Layout (100 cops), Lint (157), Style (300), plus Bundler, Gemspec, Migration, Metrics, Naming, Security, and InternalAffairs - each backed by the project's per-cop `expect_offense`/`expect_correction` known-answer batteries, with the full suite green: **33,546 examples, 0 failures** (test-queue, 14 workers, ~90s).
- **CLI, config system, runner and cache, formatters, server mode, LSP, and MCP** - suite-swept plus live end-to-end probes: a lint + `-a` autocorrect roundtrip, a `.rubocop.yml` `TargetRubyVersion` override honored, an LSP initialize handshake over stdio advertising `codeActionProvider`.
- **The last 20 upstream commits, individually re-verified.** The run's distinctive move: its first audit reasoned that on a target repo, "co-edited specs can certify a planted defect" - a commit that changes code and tests together is certified only by tests written by the same hand. So iterations 2 through 5 live-probed each of the 20 most recent no-merge commits against the behavior its message claimed: 16 live probes, including three differential autocorrect comparisons proven byte-identical on escape-heavy input, and a false-positive hunt on `Lint/AmbiguousAssignment` that went beyond what the commit message claimed to the mixin's wider dispatch surface.

The closing audit (iteration 6) rescored all dimensions on fresh evidence in one iteration: suite re-run green, `rake internal_investigation` (RuboCop linting itself, 1,734 files) at zero offenses, documentation syntax check green, security posture read at the source level (server binds 127.0.0.1 with a per-request token; config YAML restricted to Regexp/Symbol). Every dimension scored **None, on swept rows only**.

The evaluator then earned its PASS rather than granting it: it re-ran the 33,546-example suite fresh, reproduced four of the audited commits' claims with its own probes, and hunted with adversarial input - invalid UTF-8 and null-byte source files (graceful `Lint/Syntax` offense, no crash), endless-method autocorrect emitting valid Ruby. One invocation, no REJECT.

## What the run did, iteration by iteration

1. **Audit** (iter 1/10) - bootstrap, operating envelope, the 21-row inventory, verify command set to the full suite through a Windows-to-WSL bridge. Baseline green. 17 suite-backed rows swept with e2e probes; the four differential-review rows deliberately left for their own iterations.
2. **Differential rows 1-4** (iters 2-5) - the 20-commit re-verification described above, five commits per iteration, every probe clean. Verify command not re-run when no code changed, with the reasoning stated each time.
3. **Closing audit** (iter 6) - full fresh-evidence rescore, all dimensions None, closeout declared.
4. **Evaluator gate + declaration** (iter 7) - gate and declaration in one iteration, spending a single invocation. `Evaluator: PASS` recorded in the closing entry, `Converged: ce05341` appended, and the Stop hook's machine checks - empty ledger, resolvable Converged hash with only loop-state paths past it, no unswept row, verdict present, verify command exit 0 on the hook's own re-run - all passed on the first attempt.

Full iteration-by-iteration record: [journal.md](journal.md).

## The limits, stated plainly

- `rake spec` exercises the Parser engine only; Prism-engine behavior is untested by the verify gate. The run knew this and pinned `ParserEngine: parser_prism` in its own probes where a commit's behavior was Prism-specific, but the gate itself never ran Prism. A defect visible only under Prism could survive this run.
- `bundler-audit` was not installed on the host, so dependency-advisory posture was disclosed as unscored rather than scored clean.
- Seven iterations is a breadth pass with targeted depth on recent changes, not an exhaustive adversarial campaign per cop. A null result here means the examined surface held under the checks described, not that RuboCop has no bugs - its own issue tracker, where maintainers fix false positives weekly, says otherwise. What this run certifies is that none of those were findable at the severity bar and surface this method sweeps.
- Process note from the evaluator, recorded as a Learning: this run's probes lived in `/tmp` rather than committed under `.jeffy/probes/`, acceptable because the project's own committed suite is the battery, but flagged against the method's standing rule.

**Convergence standard**: evaluator countersigned. The adversarial evaluator's verdict for this run is in the narrative above; the standard each target met is recorded in [evals/ATTEMPTS.md](../ATTEMPTS.md).

**Status**: nothing lives in this eval's artifacts but the record itself - the certified tree is pristine upstream `68bd0839`. Findings were not disclosed upstream: there are none.
