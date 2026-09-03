# Jeffy eval: apple/swift-http-types

Apple's currency types for HTTP requests, responses and header fields
(`HTTPTypes`, `HTTPTypesFoundation`). Run 2026-09-03 as wave 17
(COHORT-WAVE17.md). **2 runs, 18 iterations, converged** in round 2 at
`4181d60256510e7f7e102f518e59c0c55e15fe69`, within a **pre-registered budget
of 5 rounds of 10**. The first launch died in round 1 on a provider outage
(API 500) before any iteration completed; that round is spent, and the
campaign resumed with the remaining 4 rounds, of which it used 2.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `6aff14dae9014b5b5da8f25c9b3b863cd2ab8001` (main) |
| Findings closed | **10** - 3 High, 2 Medium, 5 Low (one Medium is loop housekeeping; one Low declined on a measurement) |
| Shipped-code change | 16 files, **+1762 / -24** (most of it eleven known-answer test batteries under `Tests/`) |
| Surface inventory | **29 of 30 rows swept** (Benchmarks disclosed unreachable: package-benchmark's jemalloc module does not build on the host) |
| Ledger at convergence | 0 open, 0 blocked |
| Evaluator | **2 invocations: REJECT (round 1), PASS (round 2)** |
| Suite at convergence | `swift test -Xswiftc -warnings-as-errors`: 107 tests, 0 failures (44 at base, one of them a `withKnownIssue`) |
| Upstream | two PRs prepared (HT-8, HT-2), see below; HT-1 landed upstream the same day as #143 |

## What the loop found

Three of the findings are the `Hashable` contract of `HTTPFields`, and the
gate found the one the loop's own differential missed.

- **`HT-1`** (High) - `HTTPFields.hash(into:)` was order-sensitive while
  `==` lets differently named fields interleave freely, so equal values
  hashed differently. A `Set` holding two equal, differently interleaved
  values reported 1 on 14 of 30 runs, 2 on 11, and trapped on 5 with
  "Duplicate elements of type 'HTTPFields' were found in a Set". The
  project's own suite recorded this as a `withKnownIssue`. The hash now
  groups fields by name and combines the group hashes commutatively; 30 of
  30 runs report 1. Upstream merged the same fix as #143 on 2026-09-03,
  after the pin, so nothing was filed.
- **`HT-2`** (High) - `URLRequest.httpRequest`, an `Optional`-returning
  conversion, trapped with "Schemeless URL is not supported" on any URL
  without a scheme: a relative path, `foo/bar`, a protocol-relative URL, a
  query-only or fragment-only URL. 14 URL shapes were driven one process
  each so a trap could not hide the rest; six trapped. The guard now
  answers nil, which is what the doc comment promised.
- **`HT-8`** (High, filed by the evaluator's REJECT) - the lock-step branch
  of `HTTPFields.==` compared only `name` and `value` while the pending
  branch, `isEqualByNameIndex` and `hash(into:)` compared whole fields. Two
  lists differing only in `indexingStrategy`, or in raw bytes that decode to
  the same replacement character, reported `HTTPField ==` false,
  `HTTPFields ==` true, unequal hashes, and `==` answered differently
  depending on whether another field was interleaved. The branch now
  compares whole fields. The gate's own check found 6732 equality
  violations in 27000 generated pairs on the base tree and none at HEAD.
- **`HT-7`** (Medium) - `HTTPResponse.Status` documents that characters not
  representable in ISO Latin 1 become spaces, but `legalizingReasonPhrase`
  judged validity per UTF-8 byte, so every non-ASCII scalar passed
  unchanged. The predicate now judges per unicode scalar.
- **`HT-4`** (Medium, loop housekeeping) - `git archive` shipped 53 of the
  loop's own state files; a `.gitattributes` with `export-ignore` closes
  that channel. A finding about the loop's footprint, not about the
  library.
- **`HT-5`** (Low) - `HTTPField.Name(parsed:)` stored a name that was not
  lowercased verbatim as `canonicalName`, so a field built from
  `"Content-Type"` could not be found by `fields[.contentType]`. It now
  canonicalizes, as the sibling initializer already did.
- **`HT-3`**, **`HT-6`**, **`HT-9`** (Low) - the two non-failable URL entry
  points now document that they trap on a schemeless URL; two
  `swift-format` warnings from the project's own soundness job are gone;
  the differential generator now varies `indexingStrategy` and byte storage.
- **`HT-10`** (Low, declined) - the gate observed that the HT-1 hash costs
  1.2x to 2.1x the old one. A release-build harness timed an
  allocation-free candidate at 0.8x to 1.6x of the shipped hash across
  seven sizes, faster only at the extremes; the remedy does not achieve its
  purpose and the entry is declined on that measurement.

## What the loop got wrong

**The round-1 closing audit scored correctness None over HT-8.** The
battery pinning `HTTPFields.==` compared the implementation against a
reference written from the doc comment over 20000 random lists, and both
ignored `indexingStrategy` and raw bytes, so they agreed for the wrong
reason. The evaluator rejected the declaration on that defect. Round 2
fixed it and widened the generator (HT-9) so the differential reddens on
its own.

**Iteration 1's reproduction overstated one observation.** Its entry says
the pre-fix `Set` reported count 1; on the base commit it reports 2 as
often as not, because the hash there already combined whole fields. The
`==` clauses of the acceptance discriminate; the `Set` clause alone does
not. The gate recorded this and confirmed the acceptance as a whole.

**Host limits, disclosed**: Linux only, Swift 6.1.2. CI's Windows, macOS,
embedded, static-SDK and cxx-interop jobs were not run; the Benchmarks
package does not build here.

## Upstream

Two PRs are prepared on upstream main `6c8ca82` (which carries #143 and
#150, both merged 2026-09-03 after the pin): HT-8 as
`fields-equality-whole-field` and HT-2 as `urlrequest-schemeless-nil`, each
verified red-then-green in a fresh clone under CI's
`-warnings-as-errors --explicit-target-dependency-import-check error
-require-explicit-sendable` flags. HT-7 stays in the receipt: it changes the
observable output of a released legalizer.

## Files

- [journal.md](journal.md) - the full loop journal, every iteration
- [fixes.patch](fixes.patch) - the product diff, base to converged HEAD, loop state excluded
