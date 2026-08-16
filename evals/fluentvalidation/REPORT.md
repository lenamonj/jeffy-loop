# Jeffy eval: FluentValidation/FluentValidation

The validation library behind a large share of .NET request pipelines. **1 run,
8 iterations, converged** at `eda515f7aba3eba1339bd5f80e47e20c1c15411a`,
against a **pre-registered budget of 4 runs of 10 iterations** - the budget's
first run was also its last.

**Convergence standard**: evaluator countersigned.

The ledger at convergence was **empty** - nothing carried at all.

| | |
|---|---|
| Base | tag `12.1.0`, `b960f42b6065d1aeecddb0c747e532b1842a96ef` |
| Upstream CI on the base | **22 of 22 check-runs green** |
| Findings closed | **4** - 2 High, 2 Medium |
| Shipped-code change | 19 files, **+160 / -55** (3 library files; the rest is tests, test project hygiene and one benchmark project) |
| Surface inventory | **20 of 20 rows swept** |
| Ledger at convergence | **empty** - no Low carried |
| Evaluator | **1 invocation, PASS** |
| Suite | 865 passing and 1 skipped at the base; 870 passing and 1 skipped at convergence, on each of net8.0 and net9.0 |

## What the loop found

Both Highs sat behind a fully green 865-case suite.

- **`FV-001` (High)** - `CreditCard()` accepted any string that reduced to no
  digits once dashes and spaces were stripped: `"-"`, `"   "` and `" - - "`
  all validated as credit card numbers. The Luhn checksum of an empty digit
  string is zero, and `0 % 10 == 0`. The fix returns false when the stripped
  value is empty; `null` still passes, deferring to `NotNull`/`NotEmpty` as
  the library documents.
- **`FV-002` (High)** - `LanguageManager.GetString` returned the **empty
  string** instead of the documented English fallback for any unsupported
  neutral culture, so every validation message under such a culture was
  blank. The closing evidence is a differential rather than an argument: all
  907 cultures on the host crossed with all 28 translation keys, dumped
  against the base and against the fix - 6,076 lookups changed, the old value
  was the empty string on all 6,076, and none of the 217 moved cultures is
  among the 59 the library registers, so no real translation was displaced.
- **`FV-003` (Medium)** - `RangeValidator`'s inverted-range guard tested
  `Compare(to, from) == -1`, so a comparer expressing "less" as any other
  negative number - subtracting comparers do exactly that - left an inverted
  range in place instead of throwing, producing a rule that rejects every
  value. Now `< 0`. This is a deliberate behaviour change on public API and
  is recorded as such: the constructor throws in a strictly larger set of
  cases and in no case where it did not throw before.
- **`FV-004` (Medium)** - the test and benchmark projects resolved transitive
  packages carrying High-severity advisories. `dotnet nuget why` showed the
  vulnerable package reached through four separate parents, so all four moved
  (xunit 2.2.0 to 2.9.3 among them). The newer xunit's analyzers, under the
  project's own `TreatWarningsAsErrors`, turned eleven findings into build
  errors; every one was repaired rather than suppressed, and one was a real
  defect - an `[InlineData(0)]` on a string-typed theory, passing only via
  xunit's silent type coercion. No shipping library code was touched by this
  task.

## What the gate recorded without rejecting

The evaluator's PASS artifact lists five observations that are not REJECT
reasons, published here as the next run's first work rather than fixed after
the PASS (a fix after a PASS invalidates the PASS): a probe row's scope
command understates what its battery covers; three files appear in two row
scopes each, so "exactly one row per file" is not literally true;
`src/FluentValidation/Syntax.cs` appears in no battery's paths file; the
backlog's Settled classes section was left empty although two classes were
settled; and `.gitignore` was rewritten from CRLF to LF across all 28
pre-existing lines in order to append two, a whole-file diff where a two-line
one was intended. That last one is visible in `fixes.patch` and is disclosed
rather than cleaned up.

## Declared limits

- **The verify command grades net9.0.** The test project multi-targets
  `net8.0;net9.0`, and both frameworks were built and run green at the base,
  at every checkpoint, and by the evaluator (870 passing, 1 skipped on each) -
  but the pre-registered verify command runs one framework, and nothing here
  claims a framework it did not run.
- **`global.json` pins SDK 9.0.0 with `rollForward: latestFeature`**, which
  does not cross a major version. The host runs SDK `9.0.317` under that pin.
  The pin is the project's own and was not edited.
- One test, `AccessorCacheTests.Benchmark`, is **skipped by the project
  itself** (`Skip = "Manual benchmark"`), and the surface fingerprint's
  enumeration returns exactly that one line, so the skip is disclosed rather
  than absorbed.
- Graded on .NET SDK 9.0.317, Linux x86_64 under WSL2, run headless by
  `claude -p` on **claude-opus-5 (1M context) at xhigh effort** - recorded
  here because a model change is a larger variable than most engine version
  bumps, and receipts before this cohort did not name it.

## Nothing was sent upstream

Every finding rests on tests this loop wrote; the suite grew from 865 to 870
passing cases and no existing test was deleted, disabled or weakened. The two
assertion rewrites the xunit upgrade forced are strictly tighter than what
they replaced, and the two `async void` tests it converted are now tests whose
failures xunit can actually observe.
