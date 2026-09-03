# Jeffy eval: akheron/jansson

The 3,360-star C library for encoding, decoding and manipulating JSON. Run
2026-09-02 as wave 15 (COHORT-WAVE15.md). **1 run, 10 iterations,
converged** in round 1 at `48d3af09af9588630a946430f0b2748404c31b08`, within
a **pre-registered budget of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `851a2145e3256f2e67e5dfe24b0e456bf198b741` (master) |
| Findings closed | **4** - 1 Medium, 3 Low |
| Shipped-code change | 4 files, **+57 / -13** (one line of it is loop housekeeping, see below) |
| Surface inventory | **22 of 22 rows swept** |
| Ledger at convergence | 3 Lows carried (see below) |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | `cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build && ctest --test-dir build --output-on-failure`: `100% tests passed, 0 tests failed out of 216` (215 at base) |
| Upstream | nothing filed; no High found |

## What the loop found

- **`J-01`** (Medium) - the CMake shared-library build applied no export
  restriction, so `libjansson.so` exported 46 internal symbols (129 in all)
  that the autotools build hides and `src/jansson.def` excludes. The
  version script was written only in the branch taken when the linker lacks
  `--default-symver`, so on every linker that has it nothing was applied.
  Fixed by writing an anonymous version node in both branches and applying
  it whenever the linker accepts one. The fix was chosen against the
  autotools build as the reference ABI: after it, `nm -D` of the cmake
  build is byte-identical to the autotools build at 83 symbols, version
  strings included. The named node the old else-branch wrote would have
  moved every symbol to a `JANSSON_4` version and broken the ABI for
  anyone already linked against a cmake build.
- **`J-02`** (Low) - `check-exports`, the test that would have caught
  `J-01`, ran only under autotools. It is now registered with ctest for
  the shared build (test 216).
- **`J-03`** (Low) - `test_version` existed on disk but was not in the
  CMake `api_tests` list; registered. Checked to be worth having by
  mutating `version.c` and watching it fail.
- **`J-04`** (Low) - `doc/apiref.rst` documented `json_relloc_t`, a type
  the header does not declare (`json_realloc_t`).

## What the loop got wrong

**Nothing High.** The loop swept all 22 inventory rows in three iterations
with seventeen probe batteries (roughly fourteen thousand checks over the
encoding flags, the decoding flags, the API contract, the depth guards,
UTF-8 and surrogate validation, the overflow guards in `strbuffer`) and
every apparent failure re-examined was the loop's own wrong expectation.
The one Medium is a build-system defect, not a library one. This is the
shape the corpus predicts for a 3,000-star C library with a 20-year
history: the runtime is clean and the loop's value was the packaging.

**Iteration 4 truncated its own journal.** A bookkeeping edit written as
`open(p, "w").write(open(p).read().replace(...))` opens the write handle
before the read is evaluated and emptied `JOURNAL.md`, which was then
committed. Iteration 5 recovered it intact from the iteration 4 checkpoint
commit and recorded the lesson. Product files were not touched.

**Three Lows carried, none blocking under the declaration floor**: `J-05`,
four `-Wall -Wextra` warnings on a Release build, both sites run down by
execution and shown to be false positives (GCC cannot see across the
translation unit that `utf8_check_first` is bounded); `J-06`, the new
`check-exports` strips only the default version suffix, so on a linker
without `--default-symver` it fails despite a correct export set; `J-07`,
the loop's own PLAN.md leaves the Verify count cell empty because the
summary line's first integer is a percentage.

**Loop housekeeping in the product diff.** One `.gitignore` line for the
loop's own state file.

## Upstream

Nothing filed. `J-01` is the only finding above Low and it does not meet
the bar for a genuinely High PR: the exported symbols are internal, no
test references one, and the shipped autotools build is unaffected. The
disclosure owed here is that the CMake path was the oracle; CI's autotools
leg (`CFLAGS=-Werror ./configure && make check`) was not run by the loop
inside the round, although the loop built it once in a copy to measure the
reference export set.

## Files

- [journal.md](journal.md) - the full loop journal, every iteration
- [fixes.patch](fixes.patch) - the product diff, base to converged HEAD, loop state excluded
