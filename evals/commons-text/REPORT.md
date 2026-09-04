# Jeffy eval: apache/commons-text

The 377-star Apache Commons library of string algorithms: edit
distances, diffs, variable substitution, string builders and lookups.
Run 2026-09-02 as wave 12 (COHORT-WAVE11.md). **3 runs, 24 iterations,
converged** in round 3 at `b5dac21e06e132bfd8a376a8df966e9631fb8ffe`,
within a **pre-registered budget of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `52c1e545be7c0c0fad766e4133a055706f4a222d` (master, 208 commits after 1.15.0) |
| Findings closed | **9** - 5 High, 3 Medium, 1 Low |
| Shipped-code change | 29 files, **+506 / -98** (one line of it is loop housekeeping, see below) |
| Surface inventory | **29 of 29 rows swept** |
| Ledger at convergence | 0 open; 1 Medium blocked on a maintainer decision |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | `mvn test`: `Tests run: 1912, Failures: 0, Errors: 0, Skipped: 4` (1891 at base) |
| Upstream | [#767](https://github.com/apache/commons-text/pull/767) (T5), [#768](https://github.com/apache/commons-text/pull/768) (T6, MERGED 2026-09-04 by Gary Gregory after one review round that reshaped the tests), [#769](https://github.com/apache/commons-text/pull/769) (T1), filed 2026-09-02 |

## What the loop found

- **`T5` (High, correctness)** - `LevenshteinDetailedDistance.apply`
  reported a distance larger than the true Levenshtein distance. The
  method returned `addCount + delCount + subCount` recovered from a
  greedy backtrace instead of the cell the dynamic program filled, and
  the greedy walk took steps the matrix did not support:
  `apply("aba", "bab")` returned 3 against `LevenshteinDistance`'s 2.
  The walk now takes only steps whose predecessor holds this cell's value
  less the step's cost, and the distance comes from the matrix cell.
- **`T1` (High, security)** - `PathFence`, which bounds the `file:`,
  `properties:` and `xml:` lookups, normalized paths lexically, so a
  symbolic link inside a fenced directory that points outside it passed
  the fence and the lookup read the target. Both the fence roots and the
  path under test are now resolved to their real locations before the
  containment check.
- **`T7` (High, correctness)** - `ReplacementsFinder` handed a pending
  replacement to the handler only when a following `KeepCommand`
  arrived, so a pair of sequences that differ at their end never reported
  the tail: replaying the reported replacements rebuilt everything but
  the end of the second sequence. `CommandVisitor` gains a default
  `visitEndOfScript()` that `EditScript.visit` calls once after the last
  command, and the finder flushes there.
- **`T10` (High, correctness)** - `StrBuilder.append(CharSequence, int,
  int)` read its third argument as a length where `Appendable`, which
  the class declares, documents an exclusive end index. Through an
  `Appendable`-typed reference the builder appended the wrong span. The
  one in-tree caller that bound to the overload, in `StrSubstitutor`,
  was passing a length and is corrected with it.
- **`T6` (High, correctness; filed Medium)** - `StringMatcher`'s default
  `isMatch(CharSequence, int, int, int)` forwarded `bufferEnd` in the
  `bufferStart` slot. The filing scored it Medium on the claim that no
  in-tree component reaches the `CharSequence` overload; the closing
  iteration found six call sites in `StringSubstitutor` that do, since
  it searches a `TextStringBuilder`, and a caller-supplied prefix matcher
  installed through the public `setVariablePrefixMatcher` returned the
  input unsubstituted. One argument changed; the evaluator confirmed the
  re-score.
- **`T4` (Medium)** - `JaroWinklerSimilarity` scored two empty inputs
  0.0 (and the distance 1.0) whenever the `CharSequence` type carrying
  them does not define equality by content: `apply(new StringBuilder(),
  new StringBuilder())` fell through the `Objects.equals` shortcut into
  a match loop that found nothing.
- **`T8` (Medium)** - `AlphabetConverter.toString` rendered each letter
  against its own code point instead of its encoding (`a -> 97` for the
  class Javadoc's own example, whose encoding of `a` is `00`); a
  `forEach` rewrite had used the key where the value belonged.
- **`T2` (Medium, documentation)** - 20 published Javadoc examples
  asserted return values the implementation does not produce, across
  `CaseUtils`, `WordUtils`, `JaroWinklerSimilarity`,
  `JaroWinklerDistance`, `ParsedDecimal`, `Builder` (whose worked
  example does not compile) and `StringLookupFactory` (whose example key
  is not the registered one). Each corrected value was re-derived from a
  real call, compile or interpolation; the enumeration returns 20 at
  base and 0 at HEAD.
- **`T3` (Low)** - the only `main()` under `src/main/java`, a debugging
  printer in `JavaPlatformStringLookup`, and the assertion-free test
  that called it.

**Blocked, not open**: `T11` (Medium) - `StrBuilder` and
`TextStringBuilder` append their configurable null text where
`Appendable` documents the four characters `null`. Both classes'
own Javadoc and tests assert the deviation, so honouring the interface is
a public behaviour change the loop left as a maintainer decision.

## What the loop got wrong

- Round 1 ended after 6 of its 10 iterations with a clean exit; the
  journal's last entry that round is a sweep, not a wrap-up. Rounds 2
  and 3 ran their full budgets. The count above is the 24 iterations
  that ran.
- The product diff includes one line in `.gitignore`
  (`.claude/jeffy-loop.local.md`), added by the loop for its own state
  file. It is not a finding and would not be part of any upstream
  change.

## Why the numbers look like this

commons-text is the shape that converges: a library of independent
pure functions, each with a definition outside the code (the Levenshtein
recurrence, the `Appendable` contract, the Javadoc's own examples) that a
battery can be checked against. Four of the five Highs are places where
the implementation drifted from a contract the class itself declares.
