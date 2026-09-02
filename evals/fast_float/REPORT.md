# Jeffy eval: fastfloat/fast_float

The header-only C++ float parser that GCC's `from_chars` has relied on
since GCC 12 and that Chromium ships, 2,091 stars. Run 2026-09-01/02 as wave 11 (COHORT-WAVE11.md). **1 run, 8
iterations, converged** in round 1 at
`0bc29cdd5e4043f5eb7fa7e267f3f05c19011972`, within a **pre-registered
budget of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `a8a02f77480d10c5dc90d39f7b890bc1dff9c1b9` (8.2.10) |
| Findings closed | **3** - all Medium |
| Shipped-code change | 8 files, **+99 / -4** |
| Surface inventory | **13 of 13 rows swept** |
| Ledger at convergence | 7 Lows carried |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | `verify totals: 29 ctest cases passed across 2 configurations`, `check-claims` 27 checked / 0 mismatched |

## What the loop found

- **`FF-001` (Medium, correctness)** - `chars_format::hex` was declared in
  the public enum and read nowhere. `from_chars("0x1p3", ..., chars_format::hex)`
  returned `ec == 0`, one byte consumed, value 0; `"1p3"` returned 1. A
  caller who asked for hexadecimal silently got a decimal parse. Both
  advanced entry points now return `std::errc::invalid_argument` with
  `ptr == first`, the same shape every other rejecting path uses; the enum
  member and README say so. Hexadecimal integers are unaffected, since
  they are selected by `parse_options::base`, and the new test pins that.
  The gate compiled the new `basictest` against the pre-fix headers:
  `21 | 2 passed | 19 failed`, then `21 | 21 passed` at HEAD.
- **`FF-002` (Medium, documentation)** - README.md and the published docs
  site both told the reader to run `./build/benchmarks/benchmark`, a binary
  `benchmarks/CMakeLists.txt` never produces. Acceptance prints
  `MISSING benchmark` at base and nothing at HEAD.
- **`FF-003` (Medium, dependency hygiene)** - `MODULE.bazel` declared
  version 8.2.4 against a project at 8.2.10, because `script/release.py`
  rewrote CMakeLists.txt, float_common.h and README.md and never
  MODULE.bazel, so every release left it further behind. The release
  script now moves all four files; the gate's offline scratch release run
  confirmed the dependency pins (doctest 2.4.11, rules_cc 0.2.17) stay put.

Seven Lows are carried: the OSS-Fuzz harness's four-way format switch
returns `chars_format::fixed` from two of its cases; a duplicated `a4.cpp`
in the bloat-analysis CMake list; doctest and the supplemental test files
fetched with no pinned tag; `release.py` moving MODULE.bazel's version but
not its `compatibility_level`; a battery with no README; and two about the
run's own instruments.

## What the loop got wrong

One of the carried Lows is the run's own doing: an iteration-3 checkpoint
committed five `script/__pycache__/*.pyc` files that a battery's
`py_compile` step produced. The evaluator caught it and filed it as
`FF-007`. Those binary hunks are stripped from the published `fixes.patch`
here, which is why the diff says 8 files where the tree had 13; the
line counts are unchanged. The engine fix is queued: the probe runner
should export `PYTHONDONTWRITEBYTECODE=1`.

## Why so few findings

fast_float is a narrow, heavily differential-tested library: two entry
points, one algorithm, an OSS-Fuzz harness and known-answer differentials
against the standard library. Thirteen rows swept, every battery observed
failing under a mutation, and what remained was one public enum member
that had never been wired up, a doc path that did not exist, and a version
file the release script forgot. The `chars_format::hex` finding is real:
the enum value has shipped in the public header since it was added, and no
test, benchmark or fuzzer ever passed it.
