# Jeffy eval: CuyZ/Valinor

The 1,527-star PHP object mapper. Run 2026-09-02 as wave 15
(COHORT-WAVE15.md). **2 runs, 17 iterations, converged** in round 2 at
`b66802b091df7a1eeeb3d1a06488082c64999d20`, within a **pre-registered budget
of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `03a6f34f5c44d5f99319400ad58c53d62b277f17` (master) |
| Findings closed | **4** - 1 High, 3 Medium (one of the Mediums is loop housekeeping, see below) |
| Shipped-code change | 19 files, **+290 / -109** |
| Surface inventory | **25 of 25 rows swept** |
| Ledger at convergence | 7 Lows carried (see below) |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | `phpunit`: 2881 tests, 10877 assertions, 3 skipped (2872 / 10861 at base) |
| Upstream | [#838](https://github.com/CuyZ/Valinor/pull/838) (V-007), filed 2026-09-02 |

## What the loop found

- **`V-007`** (High) - `TokenParser::parseUseStatements()` treated every
  `use` token as an import statement, but PHP spells three constructs that
  way: an import, a closure's variable capture, and a trait import inside
  a class body. The scanner consumed the code around the other two into the
  alias map, so a closure with a capture earlier in the same file made
  `registerConstructor` resolve its return type to a class that does not
  exist (`ReflectionException: Class "boolPoint" does not exist`). Round 1
  filed it with a reliable reproduction but no isolated trigger; round 2
  narrowed it to the three-part shape (a capture clause, a return type, a
  mention of the class name followed by a comma or semicolon) and fixed the
  parser to skip `use` inside a class-like body and `use` followed by `(`.
- **`V-001`** (Medium) - `array{` and `list{` with nothing after the
  bracket parsed as the empty sealed shape instead of raising
  `ShapedArrayClosingBracketMissing`; every other truncation was refused.
  One guard, the same one the sibling `arrayType()` already had. The loop
  enumerated 129 truncations of twelve shaped signatures to establish that
  exactly those two resolved before and none after.
- **`V-004`** (Medium) - the integer types decided the subtype relation by
  naming which sibling types they matched, so `int<2, 5>` did not match
  `int<1, 10>` and `positive-int` did not match `int<1, 100>`. Through
  `registerConverter`, which consumes `matches()`, a converter declared to
  return a narrower integer type was silently skipped and the mapper
  returned the unconverted value. Replaced with an interval-containment
  trait shared by six of the seven integer types. The evaluator observed
  that a silently wrong mapping result reads as the rubric's High line;
  the finding was inherited at Medium and never re-scored, and the loop
  recorded the observation rather than fixing after the PASS.
- **`V-002`** (Medium, loop housekeeping) - the loop's own state files
  carried no `export-ignore`, so the Composer dist archive Packagist serves
  would have shipped `PLAN.md`, `BACKLOG.md`, `JOURNAL.md` and `.jeffy/`
  (141 paths) into every `vendor/cuyz/valinor/`. Fixed in `.gitattributes`.
  This is a defect of the loop's presence in the tree, not of Valinor, and
  is counted here only because the loop filed and closed it.

## What the loop got wrong

**Round 1 spent its budget on the map and left every finding open.** Ten
iterations swept 23 of 25 rows and filed seven findings without closing
one, so the High sat on the ledger for the whole round with a reproduction
that a dozen reconstructions had failed to isolate. Round 2 closed all
four above-Low findings in five iterations. The loop's own lesson is the
one it recorded at V-007: build the enumeration before the fix, because
it decides how wide the fix has to be.

**The evaluator recorded two observations, neither a REJECT reason**: the
Settled-classes line for the integer relation overstates how many types
share the trait (filed as `V-011`), and `V-004`'s severity (above).

**Seven Lows carried, none blocking under the declaration floor**: `V-003`,
the `JsonNormalizer::withOptions()` docs omit `JSON_FORCE_OBJECT`, which
the code accepts; `V-005`, `FakePsrRequest` types its parsed body as
`object|array`, so no test reaches the null branch PSR-7 permits; `V-006`,
`FileSystemCache::clear()` skips an entry whose header was damaged, so a
wedged cache directory stays wedged (the library's own write path is
atomic and cannot produce such a file); `V-008`, `composer check-todo`
fails on the loop's own state files; `V-009`, the type parser stops at
the first complete type, so `iterable{a: int}` reads as bare `iterable`
(strict mode still refuses the permissive result); `V-010`,
`.gitattributes` export-ignores a `psalm.xml` the tree no longer has;
`V-011`, above.

**Loop housekeeping in the product diff.** The `.gitattributes` and
`.gitignore` hunks are for the loop's own files.

## Upstream

`V-007` is filed as [#838](https://github.com/CuyZ/Valinor/pull/838).
Verified on a fresh clone at upstream HEAD (`03a6f34`, the base): a
12-line script with one captured closure ahead of `registerConstructor`
fails with `Class "boolPoint" does not exist` before the change and maps
after it; the two new `PhpParserTest` cases fail before and pass after;
both phpunit suites with and without `mb_strcut`, phpstan (three configs),
psalm (both configs), php-cs-fixer, rector and `check-todo` all pass
after. Novelty: issues [#543](https://github.com/CuyZ/Valinor/issues/543)
and [#756](https://github.com/CuyZ/Valinor/issues/756) are different
alias-resolution defects, both closed. `V-004` is held: the fix replaces
the `matches()` of six types with a trait across nine files, a design
change for the maintainer to make. `V-001` is a Medium and stays in the
receipt. Disclosure: the PR's first push failed the repository's
mutation-testing gate (infection, 100% MSI required on changed lines, four
escaped mutants); the block stack was replaced with a brace-depth counter
in a follow-up commit, which reaches 100% MSI locally and on CI.

## Files

- [journal.md](journal.md) - the full loop journal, every iteration
- [fixes.patch](fixes.patch) - the product diff, base to converged HEAD, loop state excluded
