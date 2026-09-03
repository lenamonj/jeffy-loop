# Jeffy eval: apple/swift-system

The Swift system-call layer (`SystemPackage`). Run 2026-09-02 as wave 16
(COHORT-WAVE15.md). **1 run, 10 iterations, converged** in round 1 at
`39b0c815aff046afe7367ecc7e1fbbf383b9b2d8`, within a **pre-registered budget
of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `1b452c2996c677d8e435bf0b766fc927176d8c77` (main) |
| Findings closed | **3** - 2 Medium, 1 Low (one Medium is loop housekeeping, see below) |
| Shipped-code change | 6 files, **+117 / -56** |
| Surface inventory | **18 of 18 rows swept** (5 unreachable on a Linux host: Windows, Darwin and the compiler-gated IORing code) |
| Ledger at convergence | 0 open, 0 blocked |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | `swift test`: XCTest 56 tests, 0 failures (55 at base); swift-testing 7 tests passed |
| Upstream | none - nothing High |

## What the loop found

- **`SS-1`** (Medium) - the doc comment on all three `FileDescriptor.open`
  overloads says that `.create` in `options` with `permissions: nil` traps.
  The POSIX `_open` has that guard; the Windows `_open` did not, so on Windows
  the file was created with the process default DACL instead. The guard is
  now in both arms. The one in-tree caller that violated the contract, the
  Windows `generateRandomData` test helper, now passes `.ownerReadWrite`.
- **`SS-3`** (Low) - `withTemporaryFilePath` cleans up with a recursive walk
  that resolved every name below the first level against the top-level
  descriptor instead of the directory that enumerated it, so a nested tree
  was not removed and the temporary directory leaked; the cleanup is wrapped
  in `try?`, so nothing reported it. The walk now recurses on each
  subdirectory's own descriptor. `testNestedCleanup` fails at base with two
  assertion errors and passes after.
- **`SS-2`** (Medium, loop housekeeping) - `swift package archive-source`
  shipped the loop's own state files (101 of 219 archive entries). A
  `.gitattributes` with `export-ignore` closes the archive channel; the
  SwiftPM clone channel stays open by design of the loop and is recorded as
  a decision for the user. This is a finding about the loop's footprint, not
  about swift-system.

## What the loop got wrong

**Nothing in the product beyond the findings above.** The closing audit
filed nothing: every battery re-executed (18 claims checked, 0 mismatched),
no swept row stale, no `public` declaration added or removed.

**The first SS-3 fix was wrong and the loop's own probe caught it**: it
handed `fdopendir` a `dup` of the caller's descriptor, which shares the file
position, so the second enumeration started where the first stopped and
`rmdir` failed `ENOTEMPTY`. The second attempt opens each subdirectory
itself.

**Host limits, disclosed**: `swift --version` reports 6.1.2, so the IORing
code behind `#if compiler(>=6.2)` was neither built nor tested; the Windows
`_open` fix was compile-checked by extracting its body verbatim into a
scratch test under a new name, not by running on Windows.

## Upstream

Nothing meets the bar. `SS-1` is a Windows-only contract gap with no
observable failure on the platforms the host can run; `SS-3` is a leaked
temporary directory behind a `try?`. Both stay in the receipt.

## Files

- [journal.md](journal.md) - the full loop journal, every iteration
- [fixes.patch](fixes.patch) - the product diff, base to converged HEAD, loop state excluded
