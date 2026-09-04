# Jeffy eval: anthropics/claude-agent-sdk-python

**Target**: [anthropics/claude-agent-sdk-python](https://github.com/anthropics/claude-agent-sdk-python) (7,881 stars) at tag `v0.2.138`, commit `961aff8ca220b2a9c91837ba4353d7ef0b7ad27f`, MIT. Python, in a local clone; the loop's work was never pushed anywhere. This is the SDK for building agents on Claude Code.

**Convergence standard**: evaluator countersigned. This run declared under the v1.9.0 severity floor, and the three Lows it carried are named below. The standard each target met is recorded in [evals/ATTEMPTS.md](../ATTEMPTS.md).

**This is attempt 2. Attempt 1 did not converge and is published as such**, with its own row in ATTEMPTS.md. Both attempts started from the same commit, with the same verify command and the same pre-registered three-run budget, fixed before either launched. One variable changed: attempt 1 ran on engine v1.9.0, attempt 2 on **v1.10.0**, whose defining change was to make sweeping the Surface inventory scheduled work rather than something an audit elects to do.

**Attempt 2: three runs, 30 iterations, converged at `f2e8974` on 2026-08-15** at the last budgeted iteration of the last budgeted run. **18 findings filed, 15 closed - 7 Medium, 11 Low, and no High** - with **three Lows carried** at the declaration. The shipped change is **17 files, +638/-80**, alongside 23 committed known-answer batteries.

## The number this receipt exists for

| End of | Attempt 1 (engine v1.9.0) | Attempt 2 (engine v1.10.0) |
|---|---|---|
| run 1 | 4 of 44 rows swept | 20 of 31 |
| run 2 | 12 of 44 | **31 of 31** |
| run 3 | **19 of 44** | 31 of 31 |
| sweep-typed iterations | **0 across 30** | **9 across 30** |
| evaluator invocations | **0** | **2** |
| outcome | not converged | **converged** |

Attempt 1 closed every finding it filed - all 18, including a High - and was still refused a declaration, because convergence requires no unswept inventory row and 22 rows were never reached. The engine change put unswept rows in the same queue as findings, ranked above open Lows. Attempt 2 then spent nine iterations sweeping, finished the map in run 2, and gave run 3 all ten of its iterations for findings.

**The denominators differ and that is not smoothed over.** Attempt 1's opening audit enumerated 44 rows, three of them recorded unreachable on this host; attempt 2 re-enumerated from the same base commit, as the pre-registration required, and produced 31, none unreachable. A 31-row map is coarser than a 44-row one over identical code, and a coarser map is mechanically easier to finish. Coverage here is comparable as a fraction - 43% against 100% - and never as a row count. What the fraction cannot be explained away by is the sweep-iteration column: nine scheduled sweeps against zero.

## The gate, first invoked in 60 iterations against this target

Neither attempt-1 run nor attempt-2 run 1 ever reached the evaluator, because the declaration path never opened. Attempt 2's run 2 reached it at iteration 10, on a fully swept map.

**Run 2's invocation returned REJECT, and the reason was a defect in this project's test harness rather than in the SDK.** Both of its stated reasons trace to a second Jeffy run executing its own iterations in the same working tree while the gate was reading it. The gate caught that unaided - it recorded `git status` clean at invocation, then modified files eight minutes later, and named the cause: "a different run is executing its own iterations in this working tree while the gate for `e8dcabf9-015845` runs." It was right, and the run ended blocked without declaring.

The cause was the harness that queues runs, not the engine: it started run 3 when the loop state file disappeared, which happens when the budget is spent and *not* when the session finishes its final iteration - and the final iteration is exactly where the gate runs. That REJECT is therefore not evidence about this project or about the engine, and is not counted as either. It is disclosed here because the two commits it names, `38eac5e` and `b983ead`, are visible in the converged commit range. They touch only `JOURNAL.md` and run 2's own gate artifact. The loop's own closing entry discloses the same thing without being asked to.

**Run 3's invocation returned PASS**, at iteration 10, on its first invocation. It re-ran the verify command (exit 0, 1,457 passed / 3 skipped), re-ran all eight of that run's acceptance checks, and went past its brief: it proved every one of them falsifiable by restoring each pre-fix file from a copy-aside, running the check to a failure, and restoring the tree byte-identical afterwards. It ran all 23 batteries green, re-derived inventory staleness per row from each battery's declared paths, re-scored the single open finding as accurately Low, and filed two observations of its own - which the run then deliberately left unfixed, because a fix after a PASS invalidates the PASS.

## The limit this target demonstrates, and it is sharper here than anywhere else in the corpus

Attempt 1, on identical code, filed and closed a **High**: on Python 3.11+, `create_sdk_mcp_server` published `{"type": "object", "properties": {}}` for **any** tool whose `input_schema` is a `typing_extensions.TypedDict`, because detection came from stdlib `typing.is_typeddict`, which returns `False` for that spelling. The tool reached the model with no schema at all, and nothing raised.

**Attempt 2 swept all 31 rows, converged, and left that High standing.** This is not inferred from the diff. Attempt 1's own committed battery, `.jeffy/probes/mcp-schema-derivation/battery.py`, was run unmodified against attempt 2's converged tree and **exits 1 with seven named failures**, among them:

```
typing_extensions TypedDict-style schema: got {'type': 'object', 'properties': {}}
create_sdk_mcp_server published an empty schema for ExtOuter
```

Driven directly on the converged tree under CPython 3.14.4: `typing.is_typeddict(Args)` is `False`, `typing_extensions.is_typeddict(Args)` is `True`, and the version gate at `src/claude_agent_sdk/__init__.py:10-17` still imports the stdlib one. The conversion function itself is correct - called directly it derives the full schema - so the defect is purely in detection, exactly as attempt 1 measured it.

**And attempt 2 edited that very function.** Its `annotations`-mapping fix changed `create_sdk_mcp_server`'s `_build_meta` closure, four lines below the `_build_schema` branch that returns the empty object. The run had the file open, changed code inside the same function, swept the row that owns it, and did not see it.

`claude-code-action` made this point first, with three security Highs from attempt 1 that attempt 2 did not rediscover. This target makes it more precisely, because here there is an executable instrument from the earlier attempt that fails on the later attempt's converged tree in one command. Two independent runs over the same code produced **disjoint high-severity findings**, and a fully swept map is not a fully examined one. "Swept" is one bit covering a wide range of sweep quality: it records that a row was exercised by an executed battery, not that the battery asked every question worth asking. A convergence declaration means what the rules say it means - this run's own audit and an adversarial gate found no open High or Medium - and it does not mean the code is free of defects a different run would find.

## What was found

Fifteen findings closed across three runs, seven Medium and eleven Low filed in total, no High. The Mediums sit where a client library's contract meets its environment: option handling, path derivation, pagination, permission plumbing, hook output types, and a metadata channel that dropped a documented field for one of the two shapes its own signature accepts. Three Lows were carried at the declaration, each named on its ledger line with its severity and none of them worked inside the convergence sequence:

- **SET-3** - every way a settings file can fail to load is diagnosed at one boundary rather than per shape, the structural task the three-strike rule required after SET-1 and SET-2 closed as instances. A file whose bytes are not valid UTF-8 raises `UnicodeDecodeError` naming neither the file nor the option. Filed Low and re-scored Low by the gate: `settings` is a user-error surface, the failure is loud, and `UnicodeDecodeError` is itself a `ValueError`, so only the diagnosis is missing.
- **MIRROR-2** - the gate's own finding against this run's MIRROR-1 fix: an adapter's own `TimeoutError` is reported with a bound that never fired.
- **DOC-2** - the DOC-1 battery grades the CLI bundle rather than the docstring, so that prose could drift back uncaught.

## Verify command

```
.venv/bin/python -m ruff check src/ tests/ scripts/ && .venv/bin/python -m ruff format --check src/ tests/ scripts/ && .venv/bin/python -m mypy src/ scripts/ && .venv/bin/python -m pytest tests/ -q
```

**Oracle class**: the project's own CI gate, reproduced. Two oracles in one chain - a static gate (ruff lint, ruff format check, mypy strict over `src/` and `scripts/`) and a unit-test suite of in-process tests with no network and no real CLI subprocess. It grades types, style and unit behaviour. **It does not grade the SDK against a real Claude Code CLI**, which is what `e2e-tests/` exists for and which this command never reaches.

**Verify duration**: 13s measured 2026-08-15. **Surface inventory**: 31 rows, **all 31 swept**, none unreachable.

**Final state**: the verify command exits 0 with **1,457 passed and 3 skipped**, against 1,437 at the base commit, so the run added test surface rather than only changing code. The three skips are the live-backend session-store adapters wanting environment variables, named one by one by `pytest -q -rs` rather than asserted as a count.

## Disclosure

The loop ran against a local clone on a branch. Nothing from these runs was pushed to anthropics/claude-agent-sdk-python. On 2026-09-04 the High described above was re-verified against upstream `v0.2.152` (still present: the 3.11+ branch imports the stdlib `is_typeddict`) and filed as [#1247](https://github.com/anthropics/claude-agent-sdk-python/pull/1247), a six-line detection fix with a regression test, after reading the merged TypedDict-conversion PRs (#726, #733, #761) and the open schema-fidelity PR (#1176), none of which touch detection. `journal.md` is the unedited journal across all three runs of attempt 2, in the order written, and `fixes.patch` is the complete diff from `961aff8` to the converged commit, excluding the loop's own plan, backlog, journal and probe files.

The High described above is present in upstream `v0.2.138` and was found by attempt 1 of this same study, not by anyone else; it is reported here rather than left implicit because a receipt that named the coverage number without naming what the coverage missed would be the more flattering half of the result.
