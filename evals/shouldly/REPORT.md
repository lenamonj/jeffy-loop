# Jeffy eval: shouldly/shouldly

The 3,412-star C# assertion library. Run 2026-09-02 as wave 15
(COHORT-WAVE15.md). **1 run, 8 iterations, converged** in round 1 at
`d68946d94042e37ae04be203e3438d26d6bd54b1`, within a **pre-registered budget
of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `ff69151de1b4242666b03e235d58dd6205991a30` (master) |
| Findings closed | **2** - 1 High, 1 Medium |
| Shipped-code change | 7 files, **+313 / -7** (one line of it is loop housekeeping, see below) |
| Surface inventory | **22 of 22 rows swept** |
| Ledger at convergence | 5 Lows carried (see below) |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | `dotnet test` (net10.0): 1168 succeeded, 0 failed (1131 at base) |
| Upstream | [#1335](https://github.com/shouldly/shouldly/pull/1335) (SH-005), filed 2026-09-02, closes the 2020 issue [#601](https://github.com/shouldly/shouldly/issues/601) |

## What the loop found

- **`SH-005`** (High) - `ShouldContainKeyAndValue` and
  `ShouldNotContainValueForKey` accept any
  `IEnumerable<KeyValuePair<TKey, TValue>>`, but both failure-message
  generators cast the actual value to the non-generic `IDictionary`. A
  failing assertion over a `List<KeyValuePair<,>>`, an array of pairs, a
  LINQ projection over a dictionary, or a mocked dictionary interface threw
  `InvalidCastException` instead of `ShouldAssertException`. The passing
  path was unaffected, so the assertion looked healthy until it had
  something to report. Fixed with a lookup helper that keeps the
  `IDictionary` fast path (every BCL dictionary produces a byte-identical
  message) and otherwise scans the pairs.
- **`SH-001`** (Medium) - `Numerics.IsNumericType` accepts `System.Half`,
  which does not implement `IConvertible`, so every `Convert.To*` call in
  the comparison cascade threw `InvalidCastException` when a boxed `Half`
  met a numeric of any other type: all 22 mixed pairings crashed, and only
  Half-to-Half worked. Fixed by widening the `Half` side to `double`
  (exact: 11-bit significand into 53) at the entry of both object-taking
  methods, leaving the existing Half-to-Half branch and its tolerance
  contract untouched.

## What the loop got wrong

**Nothing in the product beyond the two findings.** Three sweep iterations
took the map from 0 to 22 rows with seven probe batteries, and both
findings lived on the failing side of an assertion: the loop's recorded
lesson is that a sweep of an assertion library must drive every assertion
on its violated side, because a green pass tells you nothing about the
message layer.

**The evaluator recorded four observations, none a REJECT reason**, left
unfixed inside the convergence sequence and carried instead: the
`WidenMixedHalf` call in `Numerics.Compare` is redundant beside the two
unconditional widenings that follow it; a custom type implementing only
`IReadOnlyDictionary` with a non-default comparer now reports "the key
does not exist" where the real failure is a value mismatch (wording only,
and strictly better than the crash it replaced); `ShouldContain` over
`object[]` does no cross-type numeric widening, pre-existing; and
`SH-006`'s passing-path timings measure higher than the gate's, probably
because they include array construction.

**Five Lows carried, none blocking under the declaration floor**: `SH-002`,
`Numerics.Compare(object, object)` has no call site in either shipped
project; `SH-003`, `build.ps1` lists three of the six test projects, so
TUnitTests, DeterministicTests and LangVersionCompatTests never run in
CI; `SH-004`, no test on any host exercises the `net8.0` leg of the
shipped assembly; `SH-006`, the `ignoreOrder` failure path is superlinear
in collection size (about n^1.35, 4 s at 10k elements); `SH-007`, a
failing collection assertion renders every element with no truncation, so
a 100,000-element mismatch produces a 1.4-million-character message.

**Loop housekeeping in the product diff.** One `.gitignore` line for the
loop's own state file.

## Upstream

`SH-005` is filed as [#1335](https://github.com/shouldly/shouldly/pull/1335),
closing [#601](https://github.com/shouldly/shouldly/issues/601), opened
2020-02-26 with the same `InvalidCastException` from an NSubstitute
proxy and a later report over `System.Text.Json`'s `JsonObject`. Verified
on a fresh clone at upstream HEAD (`ff69151d`, the base) with `build.ps1`'s
commands run directly on Linux (neither host has pwsh): the new tests
alone fail 9 of 10 with `InvalidCastException` before the change; after it
every test in the three projects the script tests passes with 0 warnings,
and both `dotnet pack` steps succeed. `SH-001` is a Medium
and stays in the receipt. Disclosure: the `net48` test leg is Windows-only
and did not run on the host.

## Files

- [journal.md](journal.md) - the full loop journal, every iteration
- [fixes.patch](fixes.patch) - the product diff, base to converged HEAD, loop state excluded
