# Jeffy eval: google/uuid

The UUID package a large share of the Go ecosystem generates and parses its
identifiers with, and the first of three targets in the 2026-08-23 cohort -
the first cohort run on engine 1.15.2, all three chosen for the shape that
converges: one job, a decidable oracle, a suite that runs in seconds.
**2 runs, 20 iterations, converged** at
`80a0e35eeed8642a5ca9fe0e754814c5978790ab`, against a **pre-registered
budget of 2 rounds of 10 iterations declared in the cohort file before the
launch command existed**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `2d3c2a9cc518326daf99a383f07c4d3c44317e4d` |
| Upstream CI on the base | **no runs exist for the base commit** - 0 check-runs and 0 check-suites via the GitHub API; the tree carries `tests.yaml` but nothing executed it for that sha |
| Findings closed | **13** - 3 High, 5 Medium, 5 Low |
| Shipped-code change | 18 files, **+436 / -79** (library, CI workflow, and the tests that pin each fix) |
| Surface inventory | **15 of 15 rows swept** |
| Ledger at convergence | **1 Low carried** (POOL-BENCH, below); 1 item awaiting the maintainer under Proposed |
| Evaluator | **1 invocation, PASS** |

## What the loop found

Three Highs in a package whose one job is being right about 16 bytes:

- **`SQL-NULL`** - `UUID.Scan` returned early on a nil driver value, an
  empty string and an empty byte slice without touching its destination, so
  a SQL NULL handed the caller **the previously scanned row's UUID**. The
  structural fix (`DEST-RESET`) closed the class: every failing entry point
  now leaves `Nil` rather than a value the caller should not hold, pinned
  across seventeen failure cases.
- **`V6-RACE`** - `NewV6WithTime` called the unlocked inner `getTime`
  instead of taking `timeMu`, so the package clock globals `lasttime` and
  `clockSeq` were read and written concurrently with every other
  time-ordered generator. The project's own CI could not have seen it: its
  workflow ran a bare `go test -v ./...` with no race detector (`CI-RACE`,
  fixed alongside).
- **`V2-TIME`** - `UUID.Time()` decoded the DCE security id as the low 32
  bits of the timestamp on version 2 UUIDs, so a documented accessor
  returned a time **up to 7m9.4967296s off in either direction**. Found by
  the second run's fresh audit after the first run's audit had scored the
  accessors clean.

The five Mediums: `NULL-ROUNDTRIP` (NullUUID's text and binary marshalers
emitted a null form their own unmarshalers rejected); `NULL-TESTS` (the
test named for `UnmarshalText` was a copy of the marshal test and never
called it); `DEST-RESET` (the structural close above); `DOC-INVALID` (five
doc sentences promised empty or nil returns a `[16]byte` type cannot
produce, so callers testing `u.String() == ""` wrote dead code); and
`CI-RACE`. The five Lows closed: gofmt debt across seven files with a CI
format job added (`FMT-CLEAN`), `Scan` errors wrapped with `%w` so the
package's exported sentinels reach callers (`SCAN-WRAP`), the rand-pool
serialization cost documented (`POOL-CONCURRENCY`), `SetRand`'s missing
concurrency contract written (`DOC-SETRAND`), and a `go` directive stated
in go.mod (`GOMOD-DIRECTIVE`).

## The gate

The single invocation re-ran the Verify command raw and under a second
toolchain (go1.21.13), re-ran all 17 committed batteries - **2,975 checks**
- and re-derived the total from the per-battery counts. It proved every
acceptance check strong enough to fail by extracting pre-fix trees and
watching each go red (`V2-TIME`'s check fails 1,400 ways on the unfixed
code). It wrote its own version 2 decoder and drove 1,000 DCE UUIDs
against it, diffed a 4,096-value corpus across the fix and found only
version 2 changed, checked 500,000 consecutive `NewV7` values strictly
increasing, ran all 49 test functions isolated under the race detector,
and executed the one test the Verify command cannot reach
(`TestClockSeqRace`, gated behind a flag). It also re-ran every Settled
classes enumeration and caught its own tooling once: a session grep alias
stripped the `./` prefix that a filter depended on, which it recorded
rather than filing a false finding.

## One Low carried at convergence

`POOL-BENCH`: `BenchmarkUUID_NewPooled` enables the rand pool and never
restores the prior state, so any later benchmark in the same process would
generate from the pool. The gate verified the "nothing is misreported
today" clause by reading the two benchmarks that sort after it. Under
Proposed: raising go.mod's `go` directive from 1.16 to the 1.19 floor CI
already tests, a compatibility decision that is the owner's, whose factual
premises the gate checked (upstream v1.6.0 ships no directive at all).

## Declared limits

- The oracle is the package's own unit suite under `-race` plus vet and a
  wasm cross-compile; it is not a conformance corpus. The RFC 9562 vectors
  checked are the six from Appendix A, transcribed into a committed battery
  and verified character-for-character by the gate.
- The version 7 timestamp running ahead of the wall clock under sustained
  generation is settled as RFC 9562 Section 6.2 conformant, measured, not
  fixed.
- Graded on go1.26.2, linux/amd64 under WSL2, run headless by `claude -p`
  on **claude-opus-5 (1M context)**, driven by `jeffy-campaign.sh`.

## Nothing was sent upstream

Every finding rests on tests this loop wrote; no existing test was
deleted, disabled or weakened. Whether any of this goes upstream is a
separate decision, made one finding at a time.
