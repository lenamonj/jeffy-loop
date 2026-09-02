# Jeffy eval: apache/commons-cli

The 392-star Apache Commons command-line parser, a dependency of Maven,
Hadoop, Kafka and a long tail of JVM tooling. Run 2026-09-02 as wave 13
(COHORT-WAVE13.md). **2 runs, 20 iterations, converged** in round 2 at
`9984b99c150094da18e6815121b3e8b331ceb631`, within a **pre-registered budget
of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `226e2a5d222204fedfbbd537f1da535a33f84e86` (master, 169 commits past rel/commons-cli-1.11.0) |
| Findings closed | **10** - 1 High, 6 Medium, 3 Low |
| Shipped-code change | 13 files, **+288 / -31** (one line of it is loop housekeeping, see below) |
| Surface inventory | **23 of 23 rows swept** |
| Ledger at convergence | empty, nothing carried |
| Evaluator | **3 invocations: PASS, PASS, PASS** |
| Suite at convergence | `mvn --batch-mode --no-transfer-progress test`: `Tests run: 1006, Failures: 0, Errors: 0, Skipped: 61` (994 run at base) |
| Upstream | nothing filed; the one High is already open as [#433](https://github.com/apache/commons-cli/pull/433), see below |

## What the loop found

- **`CLI-001`** (High) - `DefaultParser.handleProperties` applied a
  `Properties` default by calling `processValue` on the caller's own
  `Option` instead of the per-parse clone every argv path already uses, so
  the default stayed on the shared `Options` after the parse and a second
  parse over the same `Options` silently served the first parse's value.
  Fixed by storing the value on the clone `handleOption` already makes.
- **`CLI-006`** (Medium) - the same write-through in the legacy
  `Parser.processProperties`, which also put the shared `Option` on the
  `CommandLine`. Closed as the second and last site of the `CLI-001` class.
- **`CLI-002` / `CLI-003`** (Medium) - both help renderers looped without
  advancing when the usable line width collapsed: the legacy
  `HelpFormatter.printHelp` and `printUsage` never returned at width 1, and
  `help.TextHelpAppendable` exhausted the heap at width 1 and again at width
  4, where the default indent of 3 leaves one usable column. Width 4 was in
  neither filing; the loop found it by provoking every wrapping entry point
  at every width from 1 to 8.
- **`CLI-004`** (Medium) - `CommandLine.Builder.get()` handed the produced
  `CommandLine` the builder's own `args` and `options` lists, so every
  instance from one builder aliased one state.
- **`CLI-005`** (Medium) - Javadoc contradicting behavior at three sites:
  `TypeHandler.createDate` documented as "not yet implemented" while it
  parses; `Option.getValue(int)` documented to throw below index 1 while
  index 0 returns the first value; `getOptionProperties` describing
  odd/even value pairing backwards.
- **`CLI-008`**, **`CLI-009`** (Medium) - `indexOfWrap` promised
  `startPos+width` for a window with no whitespace and returned one less;
  `Builder.get()` promised non-shared state while both instances held the
  caller's `Option` objects.
- Lows: `CLI-007` (`TextHelpAppendable` blamed the caller for a width they
  never supplied, because the indent had already been subtracted),
  `CLI-010` and `CLI-011` (the loop's own bookkeeping: a settled-class
  enumeration that missed one file, a probe battery no inventory row named).

## What the loop got wrong

**Round 1 ended blocked on two hook-refused declarations, with the product
already done.** The round closed its work at iteration 9, audited clean at
10, and took a PASS from the evaluator at 11. The Stop hook refused that
declaration: a settled-class line in `BACKLOG.md` had been wrapped for
readability, putting the `enumerated by:` clause on a continuation line the
hook does not read. The loop repaired it, took a second PASS at 12, and was
refused again, this time on a `PLAN.md` sentence that said an enumeration
"returns one row per test class", the phrasing the stated-count rule
reserves for validated counts. Both evaluator invocations spent, the round
ended blocked. Round 2 fixed the two forms, closed the carried Low and four
new findings, and declared at iteration 7 on a third PASS. Two of the three
evaluator PASSes therefore bought nothing but a re-run; the loop's own
learnings line says to lint the state files against the hook's forms before
spending an invocation, not after.

**The gate recorded six observations on the round-2 PASS that nothing
fixed**, none a REJECT reason: two correct the loop's own reasoning (the
`CLI-009` entry claimed both parsers add the caller's `Option` instances to
the `CommandLine`; both clone, so that supporting sentence was wrong while
the conclusion survived on the public builder contract) and four are
under-specified or over-general Javadoc in the replacement `indexOfWrap`
comment. They are in the journal and were not polished after the PASS,
since a fix after a PASS invalidates it.

**Loop housekeeping in the product diff.** One `.gitignore` line for the
loop's own state file.

## Upstream

`CLI-001` is the only High, and it is not novel: farkhalit opened
[#433](https://github.com/apache/commons-cli/pull/433) on 2026-07-21 with
the same clone-before-store change at both sites (`DefaultParser` and
`Parser`), and the maintainer converted it to draft, reading the
three-stage usage pattern in the user guide as not promising `Options`
reuse across parses. The loop reproduced the same defect six weeks later
without seeing that PR. Nothing else here clears the bar for a PR: the
wrap-loop non-termination is real but needs a width no caller sets, and
the rest is documentation.

## Files

- [journal.md](journal.md) - the full loop journal, every iteration of both rounds
- [fixes.patch](fixes.patch) - the product diff, base to converged HEAD, loop state excluded
