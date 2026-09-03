# Jeffy eval: Kotlin/kotlinx-datetime

The multiplatform date and time library from JetBrains. Run 2026-09-02 as
wave 16 (COHORT-WAVE15.md). **2 runs, 17 iterations, converged** in round 2
at `4b48ad2e29fa1c423e06211eda11dbb571f07602`, within a **pre-registered
budget of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `e8019ead59ba44bb300c12108185f0f69a6ebd2c` (master) |
| Findings closed | **6** - 2 High, 2 Medium, 2 Low |
| Shipped-code change | 12 files, **+137 / -15** (one line of it is loop housekeeping, see below) |
| Surface inventory | **32 of 32 reachable rows swept**; 1 row unreachable and disclosed (see below) |
| Ledger at convergence | 2 Lows carried (see below) |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | `jvmTest` + `jsTest` + `wasmJsTest`: 1793 tests, 0 failed, 12 skipped (1781 at base) |
| Upstream | [#650](https://github.com/Kotlin/kotlinx-datetime/pull/650) (KDT-5) **merged** 2026-09-03 by the maintainer; [#649](https://github.com/Kotlin/kotlinx-datetime/pull/649) (KDT-1) open, both filed 2026-09-03 |

## What the loop found

- **`KDT-1`** (High) - `byUnicodePattern` silently dropped the escaped
  quote inside a quoted literal. The Unicode pattern grammar, which the
  KDoc says this function follows, spells an apostrophe inside a literal as
  `''`, and java.time formats `'o''clock'` as `o'clock`; kotlinx-datetime
  formatted it as `oclock` and parsed only the wrong spelling. The parser
  walked the pattern by character and had no way to look at the next one,
  so the second quote read as the literal closing and reopening. Fixed by
  walking by index and treating `''` inside a literal as one apostrophe.
- **`KDT-5`** (High) - the `@Deprecated` `ReplaceWith` migration metadata on
  the superseded `kotlinx.datetime.Instant` named a different member than
  the one it was attached to, at four sites: `toEpochMilliseconds()`
  offered `nanosecondsOfSecond` as its replacement (in the `expect` and
  both `actual` declarations), and `isDistantFuture` offered
  `isDistantPast`. An IDE quick-fix applied to either changed the program's
  result with no compiler warning left behind. Reproduced by evaluating
  both sides: `DISTANT_FUTURE.isDistantFuture` is true where its stated
  replacement is false, and an instant with a fractional second returned
  1709596800123 where its stated replacement returned 123456789.
- **`KDT-2`** (Medium) - the `ZZZZZ` Unicode directive formatted a zero UTC
  offset as `+00:00` where the directive table in the same KDoc, and
  java.time, give `Z`. One argument to the existing offset directive. An
  upstream PR for the same defect,
  [#648](https://github.com/Kotlin/kotlinx-datetime/pull/648), was opened by
  another contributor about seven hours before the loop's fix and predates
  it; the loop had no access to it.
- **`KDT-3`** (Medium) - the README's note on time zones in Kotlin/JS said
  the default zone is `SYSTEM` "with a fixed offset"; the implementation
  calls `Date.getTimezoneOffset()` per instant and binary-searches for
  transitions, so it follows the host's daylight saving rules. The
  correction states what the project's own integration test asserts.
- **Lows closed**: `KDT-4`, `DateTimeFormat.parse` threw
  `Failed to parse value from '<input>'` and kept the position-bearing
  diagnostic only on the exception's `cause`, so a caller logging
  `e.message` learned nothing (one internal helper now composes the cause
  into the message, seven wrappers use it); `KDT-6`, the loop's own
  documentation battery read JUnit XML that a filtered test run had
  replaced, a defect of the loop's instrument and counted here only because
  the loop filed and closed it.

## What the loop got wrong

**Round 1 ran its budget out with every condition met except the one it
could no longer meet.** Six sweep iterations built the map, and the two
Mediums were queued behind them, so the severity floor and the swept map
arrived together at iteration 10, the last budgeted one. The closing rule
wants a clean fresh-evidence audit on the run's record before the gate,
and the extension iterations that followed cannot carry one. The loop's
own WRAPUP names it a sequencing failure, not a budget shortfall: reach
the floor two iterations early and schedule the closing audit as its own
iteration. Round 2 did exactly that and declared with four iterations in
hand.

**Two Lows carried, none blocking under the declaration floor**, both
filed from the evaluator's observations against the loop's own batteries:
`KDT-7`, the replace-with battery's paths file names four module roots
while its checks walk every module under `core/*/src`; `KDT-8`, five rows
in the parse-diagnostics battery assert digit markers the failing input
already contains, so they rest on the neighbouring cause-substring check.

**One row unreachable.** The Darwin, Windows and Android Native
implementations need a runtime the Linux host does not have. It is
disclosed, not swept, and the audit scores exclude it. The native
`linuxX64` target also did not run inside the loop: the host had only an
older `kotlin-native-prebuilt` cached and the loop ran offline. The verify
gate was the JVM, JS and Wasm/JS suites.

**One Proposed item left to the maintainers.** The JVM serialization
proxy carries no tag for `DateTimePeriod` or `DatePeriod`, so a data class
holding one gets `NotSerializableException`; nothing documented promises
otherwise, and adding a tag is a permanent compatibility commitment.

**Loop housekeeping in the product diff.** One `.gitignore` line for the
loop's own state file.

## Upstream

`KDT-5` is [#650](https://github.com/Kotlin/kotlinx-datetime/pull/650),
merged by the maintainer about six hours after filing; `KDT-1` is
[#649](https://github.com/Kotlin/kotlinx-datetime/pull/649), open. Both were verified on a fresh clone at upstream HEAD (`e8019ead`, the base): the
new escaped-quote test fails before the `Unicode.kt` change and passes after
it, and with both changes applied `jvmTest`, `jsTest` and `wasmJsTest` pass
at 1784 tests and the compiled `linuxX64` test binary passes in full, with
`apiCheck` green. `KDT-5` is annotation-only, so it carries no test; the
mismatch is visible by reading the two names on each line. Disclosure: the
repository runs no GitHub Actions, so neither PR has CI to settle; the
project's own test target was run locally in full instead. `KDT-2` is not
filed: [#648](https://github.com/Kotlin/kotlinx-datetime/pull/648) already
covers it. `KDT-3` and `KDT-4` stay in the receipt.

## Files

- [journal.md](journal.md) - the full loop journal, every iteration
- [fixes.patch](fixes.patch) - the product diff, base to converged HEAD, loop state excluded
