# Jeffy eval: thephpleague/csv

The 3,481-star PHP CSV library from The League of Extraordinary Packages,
`league/csv` 9.x. Run 2026-09-02 as wave 14 (COHORT-WAVE13.md). **4 runs,
37 iterations, converged** in round 4 at
`b8abf4501fb769ed9ff0eb5cfe1834c33fd3534b`, within a **pre-registered budget
of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `e6de76c0a3b1aa05aee97ccfed686201c8251be1` (master) |
| Findings closed | **23** - 8 High, 14 Medium, 1 Low (a fifteenth Medium, `CSV-23`, was closed together with the `CSV-22` fix) |
| Shipped-code change | 31 files, **+418 / -56** (two lines of it are loop housekeeping, see below) |
| Surface inventory | **22 of 22 rows swept** |
| Ledger at convergence | 3 Lows carried, each re-scored by the gate (see below) |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | `composer phpunit`: `Tests: 1019, Assertions: 2037, Deprecations: 17, Skipped: 3` (1009 tests, 2014 assertions and 1 PHP warning at base) |
| Upstream | [#591](https://github.com/thephpleague/csv/pull/591) (CSV-12), [#592](https://github.com/thephpleague/csv/pull/592) (CSV-14), [#593](https://github.com/thephpleague/csv/pull/593) (CSV-10), filed 2026-09-02 |

## What the loop found

- **`CSV-12`** (High) - a date-only `DateTimeField` format took its time of
  day from the wall clock: the CSV value `2024-01-01` parsed to
  `2024-01-01` at whatever time the parse ran, because
  `DateTimeImmutable::createFromFormat` fills every field the format does
  not mention from the current time. Fixed by appending the `|` reset
  modifier to the format.
- **`CSV-14`** (High) - `TimeField` interpolated the caller's separator into
  its matching regex unquoted, so a `.` separator accepted any byte
  (`10x30` parsed as `10.30.00`) and a `/` separator broke the pattern
  outright. Fixed with `preg_quote`.
- **`CSV-10`** (High) - `EscapeFormula::escapeField()` read `$strOrNull[0]`
  on every empty field and emitted `Uninitialized string offset 0`; the
  base suite carried that warning as its one `Warnings: 1`.
- **`CSV-8`** (High) - `ResultSet::fetchColumn()` and `fetchPairs()` returned
  an empty iterator on a directly constructed `ResultSet` carrying a header.
- **`CSV-9`** (High) - `Query\Limit::slice()` raised `OutOfBoundsException`,
  a class outside the package's exception hierarchy, on a zero length and
  on an offset past the end of a seekable iterable.
- **`CSV-11`** (High) - a single-element RFC 7111 range such as `row=2-2`
  selected nothing where the bare `row=2` selected the row: `FragmentFinder`
  tested `$end <= $start` where `<` was meant.
- **`CSV-13`** (High) - `EnumField::parse()` raised an uncaught `TypeError`
  for an int value against a string-backed enum, where its contract is to
  return `null`.
- **`CSV-21`** (High) - a stream filter attached on the write side of a
  stream nothing closes explicitly raised an uncaught `TypeError` at PHP's
  shutdown flush, so the process exited 255 after its work was done.
- Fourteen Mediums: `SetField` ignored the `$limit` it stored and reported;
  `TimeField` rendered a `DateTimeInterface` with a hard-coded `H:i:s`
  regardless of the configured separator; `StreamFilter` compared filter
  names against `stream_get_filters()` exactly, which lists families, so
  `zlib.deflate` was refused; a null `$params` passed positionally to
  `stream_filter_append()` made PHP's `convert.*` filters refuse the call;
  `SwapDelimiter::prependTo()` appended, and its direction test misread
  `php://temp` as write-only (`CSV-23`); `CastToString` silently replaced
  every non-string value on a nullable property with the default;
  `FieldList::removeByOffset()` returned the unmodified list when the
  removal would empty it; and seven documentation defects, among them a
  deprecation message pointing at `XMLConverter::impoprt()`, a
  `getDelimiterStats()` docblock stating the wrong count, and three worked
  examples in the 9.0 docs that do not run as written.

## What the loop got wrong

**Three rounds ran their whole budget without a declaration.** Round 1
closed four Highs and ended with seven rows unswept; round 2 closed the
other four Highs, cleared the map and filed fourteen findings while doing
it, ending with thirteen Mediums open; round 3 spent all ten iterations
closing ten Mediums and still had three docs Mediums left. Round 4 closed
them, audited fresh and declared at iteration 8 on the first evaluator
invocation. Four rounds is the longest of this wave and the pattern is the
one the corpus keeps showing: the Highs landed inside the first two rounds
and the tail was documentation and ceremony.

**Round 1 began on a red gate for an environment reason.** Three
`StreamTest` cases used `STDOUT` as a stand-in for a non-seekable stream,
and under the loop's wrapper stdout is a regular file, so they failed until
`CSV-5` (Low, test) replaced the stand-in with a socket pair in round 4.
The loop read the three failures before concluding anything and recorded
that any later red gate must be checked against that set first.

**The evaluator filed five observations and one of them was wrong.** It
reported that the new `nonSeekableStreamPair()` fixture leaked three
socket pairs per suite run; fifty iterations of the construction leave the
process's open descriptors at 6, because PHP's refcounting closes both
ends when the locals leave scope. The loop measured the claim before
carrying it and recorded the lesson: an evaluator observation is evidence,
not a verdict. Two of the other four were errors in the loop's own earlier
journal prose (a battery count of 1,918 where the claims files sum to
1,842, and "sixteen fields" where the example yields 17), reported here
rather than rewritten, because past entries are never edited.

**Three Lows carried, none blocking under the declaration floor**:
`Stream::seek()` leaves `key()` one behind `SplFileObject::seek()` on an
`@internal` class with no public path found to diverge; one
`CastToFloat` failure message names `int` where the branch below names
`float`; and `rector.php`, a 165-byte dev config, ships in the published
archive where its four siblings are export-ignored. The gate re-scored each
as accurately Low.

**Loop housekeeping in the product diff.** One `.gitignore` line for the
loop's own state file, and `CSV-7`: the package publishes through the
Packagist dist tarball with `git archive` semantics, and `.gitattributes`
carried no `export-ignore` for the loop's state files, so the loop added
one for them. Both lines exist only because the loop was in the tree.

## Upstream

`CSV-12`, `CSV-14` and `CSV-10` are filed as
[#591](https://github.com/thephpleague/csv/pull/591),
[#592](https://github.com/thephpleague/csv/pull/592) and
[#593](https://github.com/thephpleague/csv/pull/593), each verified on a
fresh clone at upstream HEAD (`e6de76c0`, the base): the new test alone red
(the wall-clock time in the parsed date; `'10.30.00' is null`; the
`Uninitialized string offset 0` warning under `--fail-on-warning`), the
full change green under `composer phpunit`, `composer phpstan` and
`composer phpcs`, the three commands the project's CI runs, on PHP 8.5.
The other five Highs are held: `CSV-8`, `CSV-9`, `CSV-11`, `CSV-13` and
`CSV-21` each carry a change to public behaviour or exception type that
belongs to the maintainer, and the standing rule is at most three per
repository.

## Files

- [journal.md](journal.md) - the full loop journal, every iteration of all four rounds
- [fixes.patch](fixes.patch) - the product diff, base to converged HEAD, loop state excluded
