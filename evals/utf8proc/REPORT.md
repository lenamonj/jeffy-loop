# Jeffy eval: JuliaStrings/utf8proc

The 1,294-star C library for Unicode normalization, case folding and
grapheme segmentation, maintained by the Julia project and linked by
Julia itself. Run
2026-09-02 as wave 12 (COHORT-WAVE11.md). **1 run, 9 iterations,
converged** in round 1 at `de90d0f0f4313c0096e7476ff85f549f7e0728cd`,
within a **pre-registered budget of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `0075ed7d0adba45682ee6bf7a83b10f8fd110163` (main, after 2.11.0) |
| Findings closed | **4** - 2 Medium, 2 Low |
| Shipped-code change | 6 files, **+56 / -15** |
| Surface inventory | **17 of 17 rows swept** (one row disclosed unreachable) |
| Ledger at convergence | 3 Lows carried |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | `ctest`: `100% tests passed, 0 tests failed out of 10` |

## What the loop found

- **`U7` (Medium, packaging)** - the committed `MANIFEST` named
  `lib/libutf8proc.so.2` where `make install` creates
  `lib/libutf8proc.so.3`. `make manifest && diff MANIFEST MANIFEST.new`
  exits 1 on exactly that line at base and 0 at HEAD. The ABI version is
  duplicated across Makefile, CMakeLists.txt, utf8proc.h and MANIFEST;
  `distcheck` asserted the first three and checked MANIFEST only by
  grepping for the soname, which the stale symlink line survived. The
  Makefile assertion now covers the manifest as a whole.
- **`U1` (Medium, documentation)** - `UTF8PROC_STABLE` was documented in
  the header as an option that selects stable normalization, and the
  implementation has not read it since 2.10.0; the evaluator confirmed by
  grep that neither it nor `comp_exclusion` is referenced anywhere in
  `utf8proc.c`. The header now says what the option does, which is
  nothing, and the 2.10.0 NEWS entry records when that became true.
- **`U6` (Low, build)** - `utf8proc.h` did not compile under
  `cc -std=c90 -pedantic-errors` (six trailing enumerator commas), while
  the 2.11.0 NEWS entry claimed C90. The commas are gone; three
  bit-field diagnostics remain under strict C90 and are disclosed in the
  header and NEWS rather than papered over, since fixing them is an ABI
  decision for the maintainers.
- **`U5` (Low, documentation)** - `lump.md`, which Doxygen publishes,
  omitted one of the `UTF8PROC_LUMP` rules the code applies.

Three Lows are carried, all in the test tree: the OSS-Fuzz harness
allocates its UTF-32 scratch buffer under the inverse of the intended
guard, so `utf8proc_normalize_utf32` is never fuzzed; CMake never passes
`UNICODE_VERSION` as a compile definition, so `test/misc.c`'s version
assertion is compiled out of the suite CI runs; and `test/iscase.c` has
no `add_test` entry, so the case-property cross-check runs only in the
Makefile path, which needs Julia.

## Why so few findings

utf8proc is a table plus a small set of functions over it, and the tables
are generated from the Unicode data files by a script the project runs on
every Unicode release. Seventeen rows swept, every battery observed
failing under a mutation, and the defects were all at the edges: a
manifest that had fallen one soname behind, a header option that outlived
its implementation, and a standards claim the header did not meet. The
carried Lows are the more interesting result for a maintainer: three
tests that exist in the tree and do not run in CI.
