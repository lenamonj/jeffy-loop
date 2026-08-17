# Jeffy eval: catchorg/Catch2

The C++ test framework - a library whose entire job is deciding whether
other code passes, pointed at a loop whose diagnosed weakness is evidence
quality. **4 runs, 35 iterations, converged** at
`098144b5ce58cb8384872346508180e2bb02c901`, against a **pre-registered
budget of 4 runs of 10 iterations**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | tag `v3.15.3`, `8b08d4d79514f45f7e4ce2a607ac9c94e920d1bb` |
| Upstream CI on the base | **100 of 100 green** |
| Findings closed | **18** - 6 High, 6 Medium, 6 Low |
| Shipped-code change | 38 files, **+1,660 / -132** |
| Surface inventory | **38 of 38 rows swept** |
| Ledger at convergence | **empty** - every finding worked, none carried |
| Evaluator | **3 invocations: 2 REJECT, then PASS** |

## What the loop found

Six Highs in a framework 100 CI legs called green, and the two most telling
were filed by the adversarial gate rather than by the run. The run's four:
**`SPLIT-1`**, `splitStringRef` dropped every one-character field, so
`CATCH_REGISTER_ENUM` mis-mapped single-letter enumerator names and read
past the end of its name vector; **`JSON-1`**, the JSON writer escaped only
seven characters, so the other twenty-five C0 controls reached the output
raw and the JSON reporter emitted documents no JSON parser accepts;
**`BOOTSTRAP-1`**, the benchmark bootstrap subscripted its resample vector
out of bounds on degenerate input; **`CPP20BUILD-1`**, a build break under
`-DCMAKE_CXX_STANDARD=20` with extensions off. Then the gate's two, each a
REJECT reason the run had to close under salvage rules:
**`CONFINT-1`**, `--benchmark-confidence-interval` is documented as bounded
to [0, 1] and nothing enforced it, and **`QUANTILE-1`**, `normal_quantile`
inverted at both ends of its domain, so an out-of-range interval reported a
collapsed, zero-width confidence interval with no diagnostic - a silent
wrong number from a tool people benchmark with.

The Mediums include invalid UTF-8 passed through to the JSON reporter
(`JSON-2`), an off-by-one in `XmlEncode`'s CDATA guard that let `]]>` out
verbatim (`XML-1`), and **`AMALGDIV-1`**, where the state files claimed the
committed single-header amalgamation diverged from `src/` "in exactly two
places" while regenerating and diffing measured 28 hunks and five missing
fixes, two of them High - the battery could only see divergences it already
had checks for. The six Lows include a release-notes script that cannot run
from any working directory and fifteen example programs the build compiled
but nothing ever ran.

## Declared limits

- The wave was interrupted by the provider's session usage window: run 2
  was killed mid-iteration 9, its orphan loop state file was inspected and
  deleted, and three untracked probe-scratch directories the killed
  iteration left behind were deleted by the operator, with approval, before
  run 3 relaunched. The budget did not change - 4 runs of 10, spent as
  declared, in two scheduled segments.
- `ctest` with a default configure runs **0 tests and exits 0**;
  `-DCATCH_DEVELOPMENT_BUILD=ON` is required for the SelfTest to exist, and
  the build step sits inside the verify command so a stale binary can never
  be graded.
- Run 1's checkpoint swept 1,306 build artifacts into a commit because the
  project's own CMake preset builds into a directory its `.gitignore` does
  not cover; corrected in a follow-up bookkeeping commit and filed as the
  finding it is.
- The loop's stall heuristic reads a sweep-only iteration as no progress,
  which forced deliberate sweep-plus-task pairings twice; recorded as a
  loop-mechanics observation for the engine backlog, not a target finding.
- Graded under WSL2 Linux x86_64, run headless by `claude -p` on
  **claude-opus-5 (1M context) at xhigh effort**.

## Nothing was sent upstream

Every finding rests on probes this loop wrote; no existing test was
deleted, disabled or weakened. Run 3 ended blocked on a terminal second
REJECT with its salvage worked and no legal declaration path left, and the
receipt says so. Run 4 opened with a fresh audit, closed the High and
Medium it filed, audited clean again, and the gate's PASS re-ran the verify
command, every acceptance check as filed, and the full SelfTest under a
C++20 configure before countersigning.
