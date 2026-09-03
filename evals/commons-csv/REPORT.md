# Jeffy eval: apache/commons-csv

The Apache Commons CSV reader and writer. Run 2026-09-02 as wave 16
(COHORT-WAVE15.md). **2 runs, 18 iterations, converged** in round 2 at
`0da529f5bd61496d9081a5a322f3b5bfc3b0e93c`, within a **pre-registered budget
of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `880622c50fd5738a0f2ca7022db90b4ace18a534` (master) |
| Findings closed | **11** - 6 Medium, 5 Low; 1 Low declined |
| Shipped-code change | 8 files, **+426 / -10** |
| Surface inventory | **13 of 13 rows swept** |
| Ledger at convergence | 3 Lows carried (see below) |
| Evaluator | **3 invocations: REJECT, REJECT (round 1, terminal), PASS (round 2)** |
| Suite at convergence | `mvn -o -Drat.skip=true test`: 980 tests, 0 failures, 11 skipped (972 at base) |
| Upstream | none - nothing High |

## What the loop found

Most of the run was one family: CSVFormat and CSVPrinter Javadoc that
promised more than the code delivers. Six Mediums are documented promises
the code did not keep; the loop corrected the documentation to what the
code does, and sent the two behaviour questions to the project owner as
Proposed lines rather than changing the output of released public methods.

- **`CSV-P1`** (Medium) - `CSVPrinter.getRecordCount()` counted the header
  the constructor writes, and its Javadoc said it did not; a caller
  reporting how many records were written got one too many whenever the
  format carried a header. Javadoc corrected.
- **`CSV-P7`** (Medium) - the same count, other route: `printHeaders(ResultSet)`
  writes a header without incrementing the count, so two outputs that differ
  only in which route wrote the header report 4 and 5. Javadoc now enumerates
  the routes.
- **`CSV-P5`** (Medium) - `CSVFormat.format(Object...)` is documented as
  returning "the specified values as a CSV record string" and returns two
  records when the format carries a header or header comments; the result
  never round-trips through the same format. Javadoc corrected; the
  behaviour question is a Proposed line.
- **`CSV-P9`**, **`CSV-P10`** (Medium) - the `toString()` Javadoc claimed two
  formats `equals()` reports as different never describe themselves
  identically. An executed enumeration over every setting at its boundary
  found four ways they do (header arrays, null versus `ALLOW_ALL` duplicate
  header mode, `maxRows` at or below zero, and a delimiter embedding a later
  setting's rendering). The Javadoc now names exactly what the enumeration
  returns.
- **`CSV-P12`** (Medium) - filed by the round-2 closing audit against the
  loop's own `CSV-P11` fix: a `CSVFormat.DEFAULT` serialized by the pre-fix
  library deserialized to `equals()` false against the freshly built one,
  with a different hash. Reproduced by building the base commit into a
  separate class directory and reading its bytes back. Fixed by removing the
  derived `quotedNullString` field from `equals` and `hashCode`; the
  evaluator built 13,464 formats through every public path and found 0
  equal-but-behaviourally-different pairs after the change.
- **Lows closed**: `CSV-P2`, `CSVRecord.putIn(M)` documents `@throws
  NullPointerException` for a null map and returned null when the record
  has no header mapping (code now throws); `CSV-P3`, `toString()` omitted
  eight settings `equals()` compares; `CSV-P4`, three `printRecords`
  overloads silently stop at `setMaxRows` and only the two `ResultSet`
  overloads said so; `CSV-P8`, `validate()` rejects a delimiter colliding
  with the quote, escape or comment character but accepts a record
  separator containing it, so `setRecordSeparator(",\n")` prints a record
  that reads back as three fields (documented; rejection is a Proposed
  line); `CSV-P11`, `setQuotedNullString` derived the literal string
  `"null"` when no null string was set, so a format compared unequal to the
  format it was derived from with no observable difference (fixed at the
  root, and the fix produced `CSV-P12`).
- **Declined**: `CSV-P6`, the proposal to make `CSVFormat.copy()` return
  `this`; every field is final and the arrays are cloned on both sides, but
  the loop found the premise false on its own derivation and recorded a
  throughput argument for keeping the copy.

## What the loop got wrong

**Round 1 ended blocked, not budget-exhausted.** The evaluator rejected
twice: first because the loop had written a Javadoc generalisation over
"a header record that was written" that only one of two header-writing
routes satisfied, and had scored `CSV-P7` Low on a rationale its own
iteration-3 edit had voided; second because the narrowed `toString` claim
named two collision cases when the gate found a third, and `CSV-P5` was
carried at Low while three identically shaped findings in the same run were
Medium. Both invocations were spent by iteration 10, which is terminal
under the engine's cap, so the round did not declare. The loop's recorded
lesson, three times in one run: never write a bounded claim over a set
without executing the enumeration of that set. Round 2 did exactly that for
every remaining claim and passed on its first invocation.

**A fix broke the suite mid-iteration.** The first attempt at `CSV-P9`
changed `toString` emission; seven fixture files under
`src/test/resources` pin that output, which a grep of `src/test/java` could
not see. Reverted inside the iteration.

**A fix introduced a finding.** `CSV-P11` changed a serialized field's
value; the closing audit caught the cross-version skew and `CSV-P12` fixed
it at the right layer. The reverse skew (a format serialized at HEAD read
by the older release) is recorded and not a defect of the shipped product.

**Three Lows carried, none blocking under the declaration floor**:
`CSV-P13`, the new `setRecordSeparator` note is wrong for a repeated line
break; `CSV-P14`, the `toString` Javadoc's "four of the settings" has a
fifth member; `CSV-P15`, two comments sit on the `quotedNullString` field
and the older one is false when the null string is absent.

**Loop housekeeping in the product diff.** One `.gitignore` line for the
loop's own state file. `-Drat.skip=true` was needed only because the loop's
state files are unlicensed; `pom.xml` was not touched.

## Upstream

Nothing meets the bar. Every Medium is a documentation correction, and the
two runtime changes (`CSV-P2`'s throw, `CSV-P11`/`CSV-P12`'s equality) have
no observable effect on any parsed or printed byte. The two Proposed
questions (whether `format()` should emit a header, whether `validate()`
should reject a record separator containing the delimiter) are the project
owner's to decide and stay in the receipt.

## Files

- [journal.md](journal.md) - the full loop journal, every iteration
- [fixes.patch](fixes.patch) - the product diff, base to converged HEAD, loop state excluded
