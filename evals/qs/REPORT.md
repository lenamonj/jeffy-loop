# Jeffy eval: ljharb/qs

The query-string parser and stringifier under Express's `req.query` and
most of the Node HTTP ecosystem, run 2026-08-25 as a single-target cohort
on engine 1.17.0 - the corpus's fiftieth brownfield convergence and its
seventh in JavaScript. **2 runs, 18 iterations, converged** at
`dbfb07c53bf56b381fb33b38b919a952949c22f7`, in round 2 of a
**pre-registered budget of 3 rounds of 10**. Round 1 declared and was
refused; see below, because that refusal is the most useful thing in this
receipt.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `3a890d4ecd3deb72a45d90be36f4f8c5970467c7` |
| Findings closed | **10** - 4 High, 4 Medium, 2 Low |
| Shipped-code change | 9 files, **+388 / -26** |
| Surface inventory | **14 of 14 rows swept** |
| Ledger at convergence | **2 Lows carried** (QS-012, QS-013) |
| Evaluator | **3 invocations: REJECT, PASS (declaration refused by the hook), PASS** |

## What the loop found

- **`QS-003` (High)** - `lib/utils.js` kept one module-global
  side-channel for every arrayLimit-overflow object it ever marked, so
  on an engine without WeakMap the marks accumulated for the life of the
  process and, with it, leaked across unrelated parses. Closed with a
  parse-scoped registry released in a `finally`; the gate then spent
  three attempts on re-entrant parses from getters and decoders trying
  to defeat the release, and could not.
- **`QS-002` (High)** - the default `strictMerge` did not apply when the
  primitive side of an object/primitive conflict arrived as combined
  duplicates, so `a[b]=c&a=1,2` with `comma: true` silently produced a
  different shape from `a[b]=c&a=1&a=2`.
- **`QS-001` (High)** - `interpretNumericEntities` stringified the whole
  value before substituting entities, so with `comma: true` it joined
  the split it had just made. A 20,000-case check of the invariant the
  README now states found no shape mismatch after the fix.
- **`QS-006` (High)** - the component.json publication channel shipped a
  file list omitting `lib/formats.js`, which three of the four files it
  did list `require`. Any consumer on that channel got a module that
  could not load.
- **`QS-005` / `QS-011` (Medium, Medium)** - the npm tarball carried the
  loop's own state files. The first fix, a `publishConfig.ignore` entry,
  worked only on the `prepack` path and was accepted by an acceptance
  check that generated the `.npmignore` it then measured. The Stop hook
  refused the round-1 declaration on exactly that: `npm pack` from a
  clean clone still shipped PLAN.md, BACKLOG.md, JOURNAL.md and all of
  `.jeffy/`. Round 2's first iteration replaced it with a `files`
  allowlist, which npm honours unconditionally.
- **`QS-004`, `QS-007`, `QS-008` (Medium)** - a README claim that two
  option combinations error when neither does; component.json
  advertising 6.13.1 for a 6.15.3 package; and PLAN.md's own Oracle
  class line stating 1,045 test assertions where the verify command
  graded 1,064 - filed by the gate's REJECT, one invocation spent on a
  number the verify log already held.

## The gate, and the refusal between two PASSes

Three invocations across two runs. Run 1: REJECT on the Oracle count,
then PASS at iteration 12 of 12 - and the declaration that PASS
countersigned was refused by the Stop hook's packaging check, which
inspects the artifact `npm pack` produces from the tree as it sits, not
as a publish would leave it. The run recorded the refusal as a 13/12
WRAPUP entry, filed QS-011, and closed blocked. The `Converged:` line
appended at that declaration stands in BACKLOG.md because the rules
forbid editing one; it certifies nothing and this receipt says so.

Run 2 closed QS-011 and both carried Lows in three iterations, audited
clean at the fourth, and PASSed the gate at the fifth: verify re-run,
all three closed tasks' acceptance checks re-executed, 14 batteries and
the 16-mutation harness green, every Declined premise and Settled-class
enumeration re-derived, 65 commands with real exit statuses. Its two
non-blocking observations were filed as QS-012 and QS-013 and carried.

## Declared limits

- Graded on Node v24.17.0, npm 11.13.0, linux under WSL2, run headless
  as systemd user units by `claude -p` on **claude-opus-5 (1M
  context)**, engine **1.17.0**. Two rounds were run of the three
  declared; the second round's declaration is the one that stands.

## Nothing was sent upstream

Every finding rests on tests this loop wrote; no existing test was
deleted, disabled or weakened. Whether the side-channel or strictMerge
fixes go upstream is a separate decision, made one finding at a time.
