# Jeffy eval: webmozarts/assert

The assertion library most of the modern PHP ecosystem validates its
arguments with - type, format, comparison, collection and reflection
checks, each promising an `InvalidArgumentException` on failure, plus
the generated `nullOr`, `all` and `allNullOr` mixins and a Psalm plugin
that preserves types across an assertion. Run 2026-09-01 as wave 9 of
the campaign (COHORT-WAVE9.md). **2 runs, 21 iterations, converged** in
round 2 at `5b5f156a7e12d25db5d030c9ab89f8b742e29aac`, within a
**pre-registered budget of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `2ccb7c2e8210` (2.4.1) |
| Findings closed | **13** - 4 High, 8 Medium, 1 Low (plus 1 filed by the gate and closed in the same run) |
| Shipped-code change | 8 files, **+821 / -114** |
| Surface inventory | **26 of 26 reachable rows swept** |
| Ledger at convergence | 2 Lows carried |
| Evaluator | **2 invocations: REJECT, PASS** |
| Suite at convergence | green through the verify gate at `Tests: 5594, Assertions: 6912`, 26 batteries each observed failing under a discriminating mutation |

## What the loop found

Four Highs, and three of them are one class: **a value the library
never checked reaching a PHP operation that decides the answer by
coercion or by throwing something the library does not own.**

- **`A1` (High)** - a literal `%` in a custom message was consumed as a
  sprintf conversion specification, so `Assert::string(1, '100% no')`
  **escaped an uncaught `ValueError` in place of the
  `InvalidArgumentException` every assertion promises**, and
  `Assert::string(1, 'Need 100% coverage')` reported `Need 100
  overage`. Fixed class-complete at one boundary: all 92 message sites
  route through a new `formatMessage()` helper. The acceptance replays
  the project's own accept/reject provider with a hostile message,
  which drove 291 red cases against the unfixed file where a single
  probe drove one.
- **`A2` (High)** - `Assert::uniqueValues()` counted duplicates with
  `array_unique()`'s default `SORT_STRING`, which stringifies every
  element, so **three distinct arrays were rejected as duplicates** and
  a pair of objects without `__toString` escaped a raw `Error`. The
  docblock already promised `SORT_REGULAR` semantics, so the fix needed
  no documentation change. The four existing provider rows all used
  `ToStringClass`, so neither shape was covered by the suite.
- **`B1` (High)** - the five ordering assertions handed their operands
  straight to PHP's relational operators, so `greaterThan([1,2], 10)`
  and `greaterThan('abc', 10)` **accepted silently and
  `lessThan(json_decode('{"nested":1}'), 100)` accepted behind an
  `E_NOTICE`, certifying an ordering that was never performed**.
  Provoking the remaining kinds added two the audit had not named,
  `lessThan(false, 10)` and `lessThan(null, 10)`. The fix is a
  `comparable()` predicate over the pair, not a type guard on the
  value, so DateTimeImmutable against DateTimeImmutable, `'5'` against
  10, `'abc'` against `'abd'` and `[1]` against `[1,2]` keep their
  verdicts; NAN is refused against everything including itself.
- **`B2` (High)** - `Assert::isInitialized()` built a
  `ReflectionProperty` before it tested anything, so an object that
  simply lacks the property **escaped a raw `ReflectionException`**.
  Its sibling `Assert::propertyExists()` rejects the identical pair
  cleanly, which is what proves the library already knows the right
  answer.
- **`A3` (Medium)** - `Assert::notStatic()` reported `Closure is not
  static.`, which is `isStatic()`'s message, so **the two opposite
  failures were byte-identical**. The check asserts that the pair
  differs, not that one string is right.
- **`A4` (Medium)** - `Assert::implementsInterface()` matched interface
  names with a case-sensitive `in_array(..., true)`, so
  `implementsInterface(ArrayObject::class, 'countable')` threw while
  **its own siblings `subclassOf` and `isAOf` accepted the identical
  name**, because those delegate to PHP's case-insensitive resolution.
- **`A5` (Medium)** - `isInstanceOfAny()`, `isAnyOf()` and
  `isNotInstanceOfAny()` consumed an iterable in their loop and then
  listed the same value again to build the failure message, so **a
  Generator argument escaped a raw `Exception`**. `isNotInstanceOfAny`
  passed the first provocation and was broken anyway: it had matched on
  the first element, leaving the generator open, and only reddened when
  the match moved to the last.
- **`A6` (Medium)** - `.gitattributes` export-ignored every development
  path but not the loop's own state, so **the Composer dist tarball
  carried 141 extra paths**, the three state files and every probe
  battery. The acceptance was executed before the fixing commit by
  running `git archive` over `git write-tree` output.
- **`A7` (Medium)** - `Assert::isInitialized()` declares
  `@psalm-assert object $value` but was absent from
  `HasAssert::HAS_ASSERT`, because the generator's skip list ran before
  the bookkeeping, so **the Psalm plugin never restored the argument's
  type for that one assertion**. Found by a battery that derives
  membership from the generator's own rule rather than spot-checking
  names.
- **`B3` (Medium)** - NAN, both infinities and a float past
  `PHP_INT_MAX` reached a string cast in `valueToString`, an integer
  cast in `integerish` and the bool cast `empty()` performs, so **under
  a host error handler that throws on warnings the assertion escaped an
  `ErrorException`** instead of rejecting. `json_decode('{"x":1e999}')`
  produces INF, so an untrusted JSON body reaches the first site
  directly. Seventeen methods escaped and resolved to three sites; a
  grep for casts would have found two, because `empty()` names none.
- **`B4` (Medium)** - `regex()` and `notRegex()` read `preg_match`'s
  return as a boolean, so a pattern that failed to compile was
  indistinguishable from a clean no-match: **`notRegex('abc', '/[/')`
  accepted every value it was given**, and `regex()` blamed the subject
  for the pattern's defect. The fix captures PHP's own compile reason
  with a temporary handler, which `preg_last_error_msg()` does not
  carry.
- **`B6` (Medium)** - the B4 helper read every false return as a
  compile failure, so a backtrack-limit, JIT-stack-limit or bad-UTF-8
  failure over a **valid** pattern **was reported as an invalid
  pattern, blaming the one argument that was not at fault**. A `/u`
  pattern over an untrusted string is the ordinary way to reach it.
  This is a regression this run introduced at iteration 5 and its own
  closing audit found at iteration 7.
- **`B5` (Low)** - `composer run cs-check` failed on
  tests/AssertTest.php, so **the CI Static Code Analysis job was red on
  this branch**, from fully-qualified names in test code the previous
  run added.

## What the gate caught

The evaluator rejected at invocation 1, on one reason, and the reason
is worth publishing: **a settled class recorded a derivation command
that does not run.** The line for the A1 sprintf class stated `grep -c
'\sprintf(' src/Assert.php` returning 1, and run exactly as written
that command prints 0 and exits 1, because `\s` inside single quotes
reaches grep as the whitespace class rather than as a literal
backslash. The class's substance was intact - there is one such call
site, and `grep -cF` returns 1 - so what was broken is the recorded
derivation, which is the thing that makes a settled class re-checkable
rather than believed. Filed as `B9` and fixed in the closing iteration,
with an acceptance generalised past the one command: it extracts every
backticked command from every Settled line in BACKLOG.md and runs each
verbatim, requiring exit 0 and the shape its line states. All three
pass.

Invocation 2 passed, and it built its own instruments rather than
reading the journal: a 3472-row verdict-and-message matrix over every
public and protected static method at both commits, differing on 244
lines of which 124 are helpers that do not exist at base and all 120
others are the intended B1 and B2 changes, with `integerish`
byte-identical across all 31 values; a throwing-host-handler sweep over
140 regex calls and 2304 ordering calls producing 0 escapes; and each
of B1, B2, B3, B4 and B6 reproduced at its true pre-fix commit and
confirmed fixed at HEAD. Two Lows are carried open by design: `B7`, the
hot-path cost of this run's guards, where `lessThan(5, 10)` moved from
25.7 to 60.7 ns per call, and `B8`, an object whose `__toString()`
throws propagating its own exception out of the message-rendering path.

## Upstream

Two PRs were filed, each verified on a fresh clone at upstream HEAD
against the project's own targets - `composer test`, `cs-check` and
`static-analysis`. Both are open.

[PR #365](https://github.com/webmozarts/assert/pull/365) is finding
`B2`: `Assert::isInitialized` escaped a raw `ReflectionException` on an
absent property instead of the library's own
`InvalidArgumentException`. The change is +2/-3 in src plus two
provider rows, which is what makes it the easier of the two to review -
the accepted-input set does not move, because `property_exists` is true
for declared and dynamic properties alike, and only the failure type on
a path that never had a legitimate success changes.

[PR #366](https://github.com/webmozarts/assert/pull/366) is finding
`B1`: the ordering assertions - `greaterThan`, `greaterThanEq`,
`lessThan`, `lessThanEq` and `range` - accepted incomparable operand
pairs such as an object against an integer. It adds a `comparable()`
helper and 13 provider rows. The NAN rows are deliberately left out:
the maintainer refused NAN handling in #302, so the PR draws its
boundary where the project has already said it wants it, and the rows
that would reopen that argument are not part of the change.
