# Journal

Append-only. One primary entry per iteration; SALVAGE and ROTATION entries are additional. Never rewrite past entries (filling the current entry's Checkpoint field is completion, not a rewrite).

Heading grammar, exactly (fenced and indented here so this example is never mistaken for an entry by anything that counts or rotates them):

```
  ## iter <i>/<N> | <run-id> | <YYYY-MM-DD> | <task-id or AUDIT or EVALUATOR or RATCHET or WRAPUP or SALVAGE or ROTATION> | <done|blocked|audit|converged|salvage|rotation>
```

Write a real heading at column zero, never indented: the indentation above belongs to the example alone, and an indented heading is invisible to the rotation anchor and to the archive counter, so the entry under it is not counted and not rotated.

SALVAGE entries take status salvage; ROTATION entries take status rotation. An EVALUATOR entry records an evaluator-gate iteration: status audit when the run continues after the verdict, blocked on a terminal second REJECT, converged when that same iteration declares.

run-id is the first 8 characters of the session id, a hyphen, then the HHMMSS of started_at from the loop state frontmatter, so two runs in one session are told apart. Body fields, in order: Task, Changed, Checkpoint (the jeffy checkpoint commit hash, or none with the reason), Verification, Learnings, Next.

The closing entry that declares convergence carries the evaluator verdict in its Verification field: `Evaluator: PASS - <one-line summary>`, or `Evaluator: unavailable (<reason>)`. An earlier EVALUATOR entry records its own verdict the same way and never stands in for the closing one: the Stop hook reads the closing entry alone, so a run that gates early and keeps working re-invokes the gate at the declaration.

Closed tasks are recorded here as one line each (ID, title, closing evidence), because BACKLOG.md deletes them. Rotation: when this file exceeds 500 lines, move all but the last 10 entries to the end of JOURNAL-archive.md, appending to whatever that file already holds and never overwriting it, because the archive accumulates across every rotation and every run; create it only when it does not already exist, and record the rotation as a ROTATION entry.

## iter 1/10 | 8cd957c6-235720 | 2026-07-30 | SALVAGE | salvage

Task: Commit bootstrap state files (PLAN.md, BACKLOG.md, JOURNAL.md, .gitignore entry) left uncommitted by /jeffy bootstrap.
Changed: none beyond the bootstrap files themselves.
Checkpoint: cb709c1697f8ee09ae6c8269c7dbeb18d228d690 (jeffy: salvage before iter 1).
Verification: git status clean after commit.
Learnings: none.
Next: first audit.

## iter 1/10 | 8cd957c6-235720 | 2026-07-30 | AUDIT | audit

Task: First full audit of Gson 2.14.1-SNAPSHOT at cb709c16 (source tree byte-identical to upstream google/gson origin/main 0482d5ca; git diff against origin/main is empty apart from jeffy state files).
Changed: PLAN.md (envelope surfaces, 17 surface inventory rows, verify command, lessons), BACKLOG.md (G1 declined), JOURNAL.md.
Checkpoint: 8251d5cd7690531298d8fc563f1a57c920c145cd. Stall check: this iteration changed only state files, but BACKLOG.md changed state (G1 filed and declined) and the inventory went 0 to 16 rows swept, so no stall.
Verification: Verify command as written in PLAN.md exit 0. Full sweep evidence: mvn test green for gson+extras+proto+metrics (134 surefire test classes, 0 failures, 0 errors); mvn verify -pl test-jpms,test-shrinker -am exit 0 (JPMS module descriptor + ProGuard/R8 shrinker assertions). Scores, swept rows only: correctness None (known-answer suite green at this commit), testing None, security None (adversarial JSON path bounded: 255 nesting limit, NumberLimits, strictness modes; HEAD carries InetAddress hardening #3075), architecture None, code quality None (Error Prone 2.50.0 enforced in build), error handling None (malformed input raises JsonSyntaxException/MalformedJsonException with JSONPath context, verified by JsonReaderTest assertions), documentation None (README cites latest release 2.14.0 by design; UserGuide/Troubleshooting current), dependency hygiene Low (G1: Caliper 1.0-beta-3 in metrics; runtime gson artifact has zero dependencies; protobuf 4.35.1, guava 33.6.0, truth 1.4.5 current), dev experience None (single mvn gate; graal harness disclosed [~]), performance skipped (no baseline on this host; benchmarks exist in metrics, no regression evidence), observability skipped (pure library; exceptions already carry troubleshooting URLs), UX/accessibility skipped (no user-facing surface). Zero High, zero Medium in-envelope: closeout begins this run - no further audits or replenishment.
Learnings: echo EXIT:$? through wsl.exe always prints 0 - rely on wsl.exe exit-code propagation; test-jpms/test-shrinker need mvn verify -am, bare -pl test resolves gson from ~/.m2 and fails spuriously; both copied to PLAN Lessons.
Next: ledger is empty with a clean full audit and 9 iterations remain, so iter 2 runs the adversarial evaluator gate and on PASS declares convergence.

## iter 2/10 | 8cd957c6-235720 | 2026-07-31 | EVALUATOR | converged

Task: Run the adversarial evaluator gate and declare convergence.
Changed: PLAN.md (corrected date-time-adapters row citation: JavaTimeTypeAdaptersTest does not exist; java.time coverage lives in DefaultTypeAdaptersTest testJavaTime*), BACKLOG.md (Converged line), JOURNAL.md. Correction to iter 1 entry, recorded here because past entries are never rewritten: the true surefire class count for gson+extras+proto+metrics is 128 (118+4+6+0), not 134; 133 including test-jpms and the shrinker IT.
Checkpoint: 1a5ecc1cce061b782294d806d2b9f925894246e3. Stall check: only state files changed, but the Converged line is a BACKLOG.md state change and the gate verdict is progress; no stall.
Verification: Evaluator: PASS - fresh-context evaluator independently confirmed the tree byte-identical to upstream origin/main 0482d5ca, re-ran the Verify command with exit 0 (118 gson test classes, 0 failures), re-ran extras/proto/jpms/shrinker suites green, judged the G1 declination honest and the zero-High zero-Medium scores plausible; its two Low bookkeeping notes are fixed in this entry. Verify command green this iteration via the evaluator's own re-run, exit 0.
Learnings: cite battery classes from git ls-files output, not from memory - one misnamed test class cost an evaluator finding.
Next: run ends converged.
