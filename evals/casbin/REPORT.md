# Jeffy eval: casbin/casbin

Apache Casbin (20,362 stars, verified via `gh api repos/casbin/casbin --jq
'.stargazers_count'` on 2026-08-31), the Go authorization library behind
ACL, RBAC and ABAC enforcement across a very large amount of Go
infrastructure. Apache-2.0, run in a local clone; the loop's work was never
pushed anywhere. Run 2026-08-31 as wave 5 of the merged-PR campaign
(COHORT-WAVE5.md). **5 runs, 46 iterations, not converged.** The full
pre-registered budget of 5 rounds of 10 was spent; the final run used the
engine's +2 closing extension and ended at iteration 12.

The scorecard treats this as not converged, full stop. No fresh-evidence
audit was executed after the ledger cleared, the evaluator gate was never
invoked, and no declaration exists. What the record shows alongside that is
a near-miss of a specific kind: at the end of the last run the ledger stood
at the severity floor - zero High, zero Medium, three Lows - and all 26
surface rows were swept, but every budgeted iteration to that point had
gone to a sweep or a fix that had to land before an audit could come back
clean. The closing extension buys only the gate and the declaration, never
an audit, so the convergence sequence was unstartable and the final run
recorded the handoff instead of manufacturing a claim.

| | |
|---|---|
| Base | `34297a19bd65cd52d40d146452c20aea7b45c205` (master; upstream CI at pin: 3 success) |
| Budget | pre-registered 5 rounds of 10 (COHORT-WAVE5.md); all spent, final run at 12 via the closing extension |
| Findings closed | **27** - 19 High, 8 Medium as first filed |
| Shipped-code change | 41 files, **+3,862 / -457** |
| Surface inventory | **26 of 26 rows swept** |
| Ledger at end | 3 Lows open (CAS-28, CAS-22, CAS-21), nothing above Low |
| Evaluator | **0 invocations** - the run never reached the gate |
| Suite | `go test -count=1 ./...` green throughout (~21 s) |

## Runs

| Run | Iterations | Closed |
|---|---:|---|
| 1 | 10 | audit; CAS-1, CAS-2, CAS-6, CAS-3, CAS-4, CAS-7 |
| 2 | 10 | CAS-9, CAS-10, CAS-14, CAS-15, CAS-18 |
| 3 | 6 | CAS-19, CAS-20, CAS-23 |
| 4 | 8 | CAS-25, CAS-26, CAS-27, CAS-29 |
| 5 | 12 | CAS-30 plus eight Mediums; ledger reached the floor at iteration 10, the +2 extension recorded the handoff |

19 Highs is the highest High count of any campaign target. That is a
statement about the target's density, not an excuse: the surface kept
yielding real findings for five straight runs - three separate times,
instrumenting a surface row bought a finding instead of a checkbox - and
that is why the closing ceremony never fit inside the budget. A
hypothetical next run would inherit the expensive half of convergence
already paid for: the map complete at 26 of 26, a ledger holding nothing
above Low, and nine settled classes each carrying an executed enumeration.
Its first iteration would be the full fresh-evidence audit and its second
the evaluator gate. That run was not part of the pre-registered budget and
was not launched.

## What the loop found

- **`CAS-1` (High)** - `enforcer_cached.go` / `enforcer.go`. The decision
  cache is keyed by request but invalidation deleted only the exact tuple
  of the changed rule, so a role-mediated grant survived its revocation and
  a cached denial survived the grant that lifted it. CachedEnforcer and
  SyncedCachedEnforcer served decisions from a policy that had since
  changed.
- **`CAS-6` (High)** - `rbac/default-role-manager/role_manager.go`. Link
  condition functions lived on Role objects that the role manager's Clear
  discards, and the condition check defaults to pass when no function is
  found, so after a plain LoadPolicy every temporal constraint was gone and
  the role link became unconditional. Fail-open: access granted through a
  window that closed in year 0.
- **`CAS-14` (High)** - `internal_api.go` / `model/constraint.go`. A
  grouping rule that violated a constraint was reported as rejected and
  left in force, so a separation-of-duties control refused the grant and
  the grant took effect anyway. Validation now runs before the mutation at
  every site instead of being unwound after it.
- **`CAS-15` (High)** - `model/constraint.go`. The sod, sodMax, rolePre and
  roleMax constraints read only directly granted roles, so a single
  intermediate role bypassed every one of them.
- **`CAS-9` (High)** - `internal_api.go`. UpdateFilteredPolicies and
  UpdateFilteredNamedPolicies never removed the rules they were meant to
  replace, so a revocation performed through this API silently did not
  happen and the new rules landed beside the old ones. CAS-27 closed the
  same class in `enforcer_distributed.go`, where a dispatcher-driven update
  degraded into an insert on every node.
- **`CAS-3` (High)** - `persist/string-adapter/adapter.go`. RemovePolicy
  erased the whole policy store instead of the named rule, and the next
  enforcer built over the same adapter failed with "invalid line, line
  cannot be empty". One removal destroyed every remaining rule.
- **`CAS-7` (High)** - `util/util.go`. Set2DEquals sorts every row of both
  arguments in place, and GetPermissionsForUser hands back the model's own
  slices, so comparing a user's permissions corrupted live policy: after
  the comparison a stored rule read `[data1 read zoe]` and an Enforce that
  had answered true answered false.
- **`CAS-25` (High)** - `rbac_api_with_domains.go`. DeleteDomains with no
  argument, documented to delete all domains, skipped every domain carrying
  no grouping rule, so a tenant's access grants survived a call that
  reported success.

## Upstream

`CAS-7` was filed upstream as
[PR #1753](https://github.com/apache/casbin/pull/1753), with
[issue #1752](https://github.com/apache/casbin/issues/1752) opened first as
the project's CONTRIBUTING asks. It was verified against a fresh clone of
upstream master before filing: the reproduction is red there, green with
the patch, and the shipped regression test fails without the fix.

A pull request is judged on the finding, not on the run that produced it.
This run did not converge, and that is what the scorecard records; the
finding was filed because it passed the same bar every other upstream
contribution here has to pass. Nothing about the non-convergence touches
it: the budget ran out during the closing ceremony, not on any doubt
about this defect.

## Environment

WSL2 x86_64, Go toolchain, `go test -count=1 ./...` as the verify command.
Engine 1.20.0 on Claude Code 2.1.232, model `opus[1m]`. Oracle
sabotage-proven before launch: Enforce made to always deny reddened **5
packages**, with 0 failures on revert. Flake gate 10/10 green.

Full iteration record: [journal.md](journal.md). Complete shipped diff:
[fixes.patch](fixes.patch).
