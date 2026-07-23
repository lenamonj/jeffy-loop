# Jeffy eval: kennethreitz/records

**Target**: [kennethreitz/records](https://github.com/kennethreitz/records) (~7.2k stars) at HEAD `ea42736` (2026-02-08), Python 3.11, SQLAlchemy 2.0.x — run in a local clone; nothing was pushed upstream.

**The headline**: at that HEAD, `pytest` reports **31 passed**. At the same HEAD, all of the following are true. Every finding was reproduced before it was filed; `repro.py` in this directory reproduces the four Highs against upstream and passes after `fixes.patch`.

| Finding | Severity | Behavior at HEAD |
|---|---|---|
| `db.query("INSERT ...")` | High | Data silently lost: SQLAlchemy 2.x removed autocommit, nothing commits, rows vanish on close with no error |
| `db.bulk_query(...)` | High | Same silent data loss |
| `db.transaction()` | High | Bare `except:` swallows every exception; callers believe failed transactions succeeded. Upstream added the `raise` on 2026-02-08 and reverted it the same day (`a1ebdde` -> `5df61d3`) |
| Every `query()` | High | Leaks a pooled connection (`close_with_result` is a no-op under 2.x); a pool of 1+1 dies on the third query |
| Legacy varargs `bulk_query(q, {...}, {...})` | Medium | `TypeError` under 2.x |
| The test gate | Medium | Green but meaningless: `:memory:`-only fixture cannot observe commits, persistence, or pools — and one test asserted the swallow bug |

**Why the suite stayed green through four Highs**: in-memory SQLite shares one connection, so uncommitted state is always visible and nothing ever crosses a real connection boundary. The gate measured the wrong world.

## What the run did (6 iterations + 1 correction, budget 8)

1. **Audit** — reproduced everything above firsthand; filed one *structural* task for the three Highs sharing a root cause (the Connection class assumes SQLAlchemy 1.x autocommit/close-with-result semantics), per the three-strike rule — never three spot patches.
2. **S1 (structural)** — commit-and-finalize on result exhaustion, immediate commit for DML, single-result connections returned to the pool, varargs API normalized, and a transaction wrapper so auto-commit never fires inside an explicit transaction (the part a spot patch gets wrong: rollback must keep working — proven by test).
3. **T2** — `transaction()` re-raises after rollback, restoring the fix upstream reverted.
4. **T3** — gave the gate teeth: fixed the test that asserted the bug; added a file-backed regression suite (persistence both paths and both API forms, pool exhaustion, exception propagation, explicit rollback). Proven honest: the new tests **fail 5/6 against the pre-fix code** from the audit checkpoint.
5. **T4** — truthful packaging: `python_requires>=3.7`, impossible 3.4–3.6 classifiers dropped, dead Travis/tox config removed.
6. **Convergence audit** — every repro green, 37 tests passing, backlog empty. Lint style declined with a reason (the project declares no lint gate; imposing one is cosmetic churn). Two genuine owner decisions filed under Proposed, not seized: replacing unmaintained `docopt`, restoring the multi-backend CI matrix.
7. **Correction** — the convergence ledger initially recorded a mistyped full hash; caught, corrected against `git rev-parse`, and journaled. The journal also records two other operator errors caught by the method's own rules (a premature "passed" claim and an invalid first negative-path check).

Full iteration-by-iteration record: [journal.md](journal.md). Complete product diff: [fixes.patch](fixes.patch) (records.py, tests, packaging — about 180 lines).

**Status**: fixes live in this eval's artifacts. All four findings were disclosed upstream with repros and a PR offer in [kennethreitz/records#236](https://github.com/kennethreitz/records/issues/236) (2026-07-22). Merging anything remains the maintainers' call.
