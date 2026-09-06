# Jeffy eval: apache/commons-codec

The 490-star Apache Commons Codec, the Base64, Hex, URL, quoted-printable,
digest, checksum and phonetic encoders that ship in a large share of the
Java ecosystem. Run 2026-09-05 as the second target of the 1.21.1
acceptance cohort (COHORT-ACCEPTANCE-1211.md). **2 runs, 18 iterations,
converged** in round 2 at `5b1919109883b60ad3fbc1125b7e01ad591639fb`,
within a **pre-registered budget of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `20a5d22bc05933e2ff7a8f2cb3bce5cee8db64c1` (master, 2026-08-31, after 1.22.1) |
| Findings closed | **6** - 1 High, 5 Medium (one of the five filed by the gate, see below) |
| Shipped-code change | 8 files, **+102 / -22** (1 line of it is loop housekeeping, see below) |
| Surface inventory | **27 of 27 rows swept** |
| Ledger at convergence | 6 Lows carried (`CODEC-2`, `CODEC-3`, `CODEC-4`, `CODEC-9`, `CODEC-10`, `CODEC-13`); one High blocked on a maintainer decision (`CODEC-6`) |
| Evaluator | **2 invocations: REJECT, then PASS** |
| Suite at convergence | `mvn -B -Drat.skip=true test`: `Tests run: 18927, Failures: 0, Errors: 0` (18,925 at base) |
| Upstream | [#443](https://github.com/apache/commons-codec/pull/443) (`CODEC-1`) open |

## What the loop found

- **`CODEC-1` (High, correctness)** - `GitIdentifiers`, the 1.22 addition
  that computes Git blob and tree ids, ordered tree entries with
  `String.compareTo`, which compares UTF-16 code units. Git orders the raw
  UTF-8 bytes, and the two disagree for any name outside the Basic
  Multilingual Plane: a directory holding the names U+FF21 and U+1F600 got
  the tree id `c64581e4...` from the library and `9f9c1fc3...` from
  `git write-tree`. The sort key is now the name's UTF-8 bytes compared
  unsigned; names below U+D800 keep their order, so every existing
  constant is unchanged, and a test pins the id Git computes.
- **`CODEC-5` (Medium, docs; filed High, re-scored by the loop)** -
  `Crypt.crypt(byte[], ...)` zeroes the caller's key array on the SHA-2
  and MD5 branches, which its delegates document and `Crypt` itself did
  not. The loop first filed the clearing as undocumented High behaviour,
  re-read the delegates' Javadoc, found the contract stated on 17 of 17
  parameters there, and narrowed the finding to the two `Crypt` overloads,
  which now carry the per-branch contract and a test over all five
  dispatch branches.
- **`CODEC-7` (Medium, docs)** - `QuotedPrintableCodec`'s six encode
  methods documented a quoted-printable string return and `null` only for
  `null` input, while strict mode also returns `null` for any input
  shorter than three bytes. The Javadoc says so now.
- **`CODEC-11` (Medium, docs)** - the `ColognePhonetic` class Javadoc's
  step 3 described a rule the code deliberately stopped implementing under
  CODEC-317, and the sentence had been left standing.
- **`CODEC-8` (Medium, docs)** - `DoubleMetaphone.encode` and
  `doubleMetaphone` documented "An encoded String" and never the `null`
  they return for empty input, where `Metaphone` returns the empty string.
- **`CODEC-12` (Medium, docs; filed by the gate)** - the `CODEC-8` fix
  had shipped a false `@return` clause onto `encode(Object)`, enumerated
  through the type it delegates with rather than through its own guard;
  the gate reproduced it, rejected, and the fix landed before the second
  invocation passed.

`CODEC-6` (High, correctness) is blocked, not open: strict-mode
`QuotedPrintableCodec.encode` returns `null` for a one- or two-byte body
where the Javadoc promised a string. The loop's fix broke the project's own
suite, the null turned out to be a documented upstream decision carrying a
JIRA id, and the gate verified the block; the documentation half became
`CODEC-7`. Six Lows are carried with a measured reason each, among them
`CODEC-2` and `CODEC-10` on the package-private `DirectoryEntry` that no
user of the shipped jar reaches.

## What the loop got wrong

One score and one sentence. `CODEC-5` was filed as a High on a grep that
searched the Javadoc for "zero", "cleared" and "wiped" and missed "set to
{@code 0}"; the next iteration re-read the exact methods and re-scored it
before any fix. The `CODEC-8` fix wrote a false `@return` clause that the
gate's first invocation caught and rejected on, the run's only REJECT
reason; the second invocation passed after the correction.

One line in `fixes.patch` is loop housekeeping and is counted in the
numbers above: `.gitignore` gains the loop's transient state file, which
bootstrap adds so the checkpoints never commit it.

## Upstream

`CODEC-1` is [#443](https://github.com/apache/commons-codec/pull/443),
verified on a fresh clone at upstream master (`20a5d22b`, equal to the
base commit): the test-only patch fails with `expected: <9f9c1fc3...> but
was: <c64581e4...>`, and the full patch passes the project's default Maven
goal (`clean verify` with rat, japicmp, pmd, checkstyle, spotbugs and
javadoc) with 18,926 tests on JDK 21. The PR carries the fix, the test and
the `changes.xml` entry the project asks for, 49 lines, and answers the
template's generative-tooling question.

The five Mediums carry fixes in `fixes.patch` and are not filed: each is a
Javadoc correction the maintainers may prefer to word themselves.

## Files

- [journal.md](journal.md) - the full loop journal, both runs
- [fixes.patch](fixes.patch) - the product diff, base to converged HEAD, loop state excluded
