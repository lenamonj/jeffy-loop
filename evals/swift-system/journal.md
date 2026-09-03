# Journal

Append-only. One primary entry per iteration; SALVAGE and ROTATION entries are additional. Never rewrite past entries (filling the current entry's Checkpoint field is completion, not a rewrite).

Heading grammar, exactly (fenced and indented here so this example is never mistaken for an entry by anything that counts or rotates them):

```
  ## iter <i>/<N> | <run-id> | <YYYY-MM-DD> | <task-id or AUDIT or SWEEP or EVALUATOR or RATCHET or WRAPUP or SALVAGE or ROTATION> | <done|blocked|audit|converged|salvage|rotation>
```

Write a real heading at column zero, never indented: the indentation above belongs to the example alone, and an indented heading is invisible to the rotation anchor and to the archive counter, so the entry under it is not counted and not rotated.

A SWEEP entry is an iteration spent sweeping Surface inventory rows and takes status done. SALVAGE entries take status salvage; ROTATION entries take status rotation. An EVALUATOR entry records an evaluator-gate iteration: status audit when the run continues after the verdict, blocked on a terminal REJECT (one with no invocation remaining), converged when that same iteration declares.

run-id is the first 8 characters of the session id, a hyphen, then the HHMMSS of started_at from the loop state frontmatter, so two runs in one session are told apart. Body fields, in order: Task, Changed, Checkpoint (the jeffy checkpoint commit hash, or none with the reason), Verification, Learnings, Next.

The closing entry that declares convergence carries the evaluator verdict in its Verification field: `Evaluator: PASS - <one-line summary>`. `Evaluator: unavailable (<reason>)` is recorded when no sub-agent can be spawned, and it is not a verdict a run declares on: the Stop hook refuses it and the run ends blocked until a relaunch where the gate can run. An earlier EVALUATOR entry records its own verdict the same way and never stands in for the closing one: the Stop hook reads the closing entry alone, so a run that gates early and keeps working re-invokes the gate at the declaration.

Closed tasks are recorded here as one line each (ID, title, closing evidence), because BACKLOG.md deletes them. Rotation: when this file exceeds 500 lines, move all but the last 10 entries to the end of JOURNAL-archive.md, appending to whatever that file already holds and never overwriting it, because the archive accumulates across every rotation and every run; create it only when it does not already exist, and record the rotation as a ROTATION entry.

## iter 1/10 | 0188a734-012350 | 2026-09-02 | AUDIT | audit

Task: First audit of apple/swift-system. Fill the Operating envelope, the Surface
inventory and the Verify command block, then score every applicable dimension
breadth-first and file what the probes found.

Changed: PLAN.md (envelope surfaces, 23 inventory rows, Verify command block),
BACKLOG.md (SS-1, SS-2, SS-3).

Checkpoint: 4319403

Verification: `swift test` through the installed quiet-verify wrapper: green
(8s, oracle=unit tests), summary line `Executed 55 tests, with 0 failures (0
unexpected)`. That line is XCTest's aggregate only; the same command also runs a
swift-testing suite whose result the pattern does not match, so `Verify count`
is left empty rather than recording a subtotal as a total.

Breadth-first probe evidence, all executed this iteration against a scratch
SwiftPM package at $SCRATCH/jprobe that depends on this tree by path:
  - FilePath query, decomposition, extension/stem, lexical normalization,
    lexicallyResolving, removePrefix, append, push, removeLastComponent and the
    root setter, driven from the doc comments' own worked examples: 66/66.
  - Components view (count, first, last, map, reversed, duplicate separators,
    dot components, removeSubrange, insert), FilePath string round trip through
    an invalid UTF-8 byte, Component and Root failable initializers, Errno raw
    values and strerror description, FilePermissions description, FileMode and
    FileType masking, and a FileDescriptor open/writeAll/read/pread/stat round
    trip on a real file: 45/45.
Neither probe is yet a kept battery under .jeffy/probes/, so no inventory row is
flipped this iteration; every row starts unswept except the four the guards put
out of reach on this host.

Scores, claiming only the surface actually probed and not the unswept remainder
(3 of 23 rows probed shallowly; 4 more are `[~]` unreachable here; 16 unswept):
  - correctness: Low - SS-3. The FilePath families probed above returned every
    documented answer.
  - security: Medium - SS-1, a file created with the process default DACL where
    the documentation promises a trap.
  - documentation: Medium - SS-1 is a doc comment the Windows code does not keep.
  - dependency hygiene: Medium - SS-2. The package itself declares no
    dependencies at all.
  - error handling: Low - the `try?` at FilePathTemp.swift:27 hides SS-3;
    recorded inside SS-3 rather than filed separately, since it is the same
    root cause and one fix closes both.
  - testing: Low - the whole IORing surface is ungraded on this toolchain, and
    the temporary-directory helper is exercised only with flat directories.
  - architecture, code quality, performance, developer experience: None over the
    probed rows.
  - observability: not applicable - a syscall wrapper vends errno to its caller
    and owns no logging or metrics surface. Recorded, not scored.
  - UX, accessibility: not applicable - the package has no user-facing surface;
    it is a library of system-call bindings.

Learnings: `swift test` here drives two runners in one invocation and prints two
independent totals, so no single line reports what the command graded.
`compiler(>=6.2)` gates every IORing source and test file, so on a Swift 6.1.2
toolchain that surface compiles to nothing and no verify run touches it - an
exclusion no pass count can reveal. Probing this package from outside needs a
scratch SwiftPM package with a path dependency; `.build` carries no linkable
library archive.

Next: SS-1, then SS-2, then the unswept inventory rows, then SS-3.

## iter 2/10 | 0188a734-012350 | 2026-09-03 | SWEEP | done

Task: Sweep Surface inventory rows. No open High, so the map is the top of the
queue; rows batch and the evidence bar per row is unchanged.

Changed: .jeffy/probes/_harness/run.sh (new), five new batteries under
.jeffy/probes/ - filepath-syntax, filepath-components, filepath-string,
filepermissions, filemode-filetype-ids - each with paths, probe.swift,
README.md and claims. JOURNAL.md (this entry, and the iteration 1 heading's
run-id, corrected below). Sources/ is unchanged: every mutation below was
applied to a pristine file, measured, and restored, and `git status --porcelain
-- Sources/` is empty at the checkpoint.

Checkpoint: ccbebc4

Verification: `swift test` through the installed quiet-verify wrapper: green
(4s), summary line `Executed 55 tests, with 0 failures (0 unexpected)`.
`skills/jeffy/hooks/lib/check-claims.sh .` reports `claims: 5 checked, 0
mismatched, 0 errored, 0 skipped`.

swift-system vends no linkable archive under .build, so a probe cannot be
compiled against it directly. The harness builds one scratch SwiftPM package
that depends on this tree by path and swaps only its main.swift per battery, so
SystemPackage is compiled once and each battery costs a single-file recompile.

Every battery was observed failing before it was trusted, each against a
mutation of the code its row certifies, applied and then reverted:
  - filepath-syntax: `lexicallyResolving`'s containment guard rewritten from
    `.parentDirectory` to `.currentDirectory`. Red, exit 1, four checks named
    in the battery README; `resolve escape` returned
    `/var/www/my-website/static/../../../../etc/passwd` where the doc comment
    promises nil.
  - filepath-components: `Component.kind` returning `.parentDirectory` for a
    current-directory component. Red, exit 1, `component kind dot`.
  - filepath-string: `String.init?(validating:)` routed to the lossy
    `init(decoding:)`. Red, exit 1, `validating bad rejects`.
  - filepermissions: `groupWrite` returning 0o10 instead of 0o20. Red, exit 1,
    `raw groupWrite` and `group rwx is union`.
  - filemode-filetype-ids: the `FileMode.type` setter with its mask on the new
    value dropped. This is the one that mattered: the battery as first written
    stayed fully green under that mutation, because it set the type from an
    out-of-range value while the permission bits were already all ones, so the
    unmasked setter wrote exactly the bits the next check read back. Four
    cross-contamination checks were added against values the other half does
    not already hold, and the same mutation then reddened `set type does not
    leak into permissions`.

Learnings: an instrument that has never been seen to fail reads exactly like
one that passed - the FileMode battery proved that on its first mutation
attempt, and the fix was to assert non-interference against a value the other
field does not already carry, not to add more assertions. Probing this package
from outside needs a scratch SwiftPM package with a path dependency, because
.build carries no linkable library archive. A source mutation that violates
FilePath's storage invariant trips the package's own `_invariantCheck`
precondition and kills the probe process before any check runs, so the battery
still exits 1 but names no failing check.

Next: keep sweeping - errno-values, errno-description, filedescriptor-values,
filedescriptor-ops, filedescriptor-helpers and stat are the next rows that can
be evidenced from outside the module.

## iter 3/10 | 0188a734-012350 | 2026-09-03 | SWEEP | done

Task: Keep sweeping Surface inventory rows. No open High, so the map is still
the top of the queue.

Changed: six new batteries under .jeffy/probes/ - errno-values,
errno-description, filedescriptor-values, filedescriptor-ops,
filedescriptor-helpers, stat - each with paths, probe.swift, README.md and
claims. JOURNAL.md and PLAN.md (six rows flipped in the bookkeeping edit).
Sources/ is unchanged: every mutation below was applied to a pristine file,
measured, and restored, and `git status --porcelain -- Sources/` is empty at
the checkpoint.

Checkpoint: 03377b3

Verification: `swift test` through the installed quiet-verify wrapper: green
(2s), summary line `Executed 55 tests, with 0 failures (0 unexpected)`.
`skills/jeffy/hooks/lib/check-claims.sh .` reports `claims: 11 checked, 0
mismatched, 0 errored, 0 skipped`.

Each battery was observed failing before it was trusted, against a mutation of
the code its row certifies, applied and then reverted:
  - errno-values: `isDirectory` bound to `_ENOTDIR` instead of `_EISDIR`. Red,
    exit 1, `raw isDirectory` and `only documented aliases collide` - the
    second caught the duplicate pair the first would have missed had both
    spellings named a real macro.
  - errno-description: `system_strerror` passed a constant 0 instead of
    `self.rawValue`. Red, exit 1; `descriptions distinct` collapsed to a single
    rendering and `thrown description` printed `Success` for a failed open.
  - filedescriptor-values: `OpenOptions.truncate` returning 0, an option
    present in the API and inert. Red, exit 1, and three of the five failing
    checks were behavioural, so the inert flag would have been caught even had
    the constant table agreed with itself.
  - filedescriptor-ops: `_write(toAbsoluteOffset:)` calling `system_write`
    instead of `system_pwrite`. Red, exit 1, on the two offset checks; every
    byte-count and length check stayed green under it.
  - filedescriptor-helpers: `closeAfter`'s `try? self.close()` removed from the
    catch arm, so the descriptor leaks whenever the body throws. Red, exit 1,
    on `closeAfter closed on throw` alone - including the check that asserts
    the body's error is rethrown, which stayed green.
  - stat: `_stat` always calling `system_stat`, ignoring `followTargetSymlink`.
    Red, exit 1, on four checks.

The stat battery needed one repair before it could be trusted for a different
reason: comparing two whole `Stat` structs across a symlink traversal is flaky,
because traversing the link updates its access time. That check now compares
type, size and inode, and the battery was run three times consecutively green
to confirm the rest is stable.

Learnings: a documented parameter has to be driven at both of its values
against real behaviour, not only against the constant table - the inert
`truncate` and the ignored `followTargetSymlink` were both caught by
behavioural checks and would both have survived a constants-only battery. The
C-spelled aliases on `FileDescriptor.AccessMode` and `OpenOptions` are
`@available(*, unavailable)`, so a probe that references them fails to compile
rather than running; they cannot be checked at run time at all. Comparing whole
`Stat` values across calls separated by filesystem access is time-dependent and
must be narrowed to the fields under test.

Next: the seven remaining unswept rows all cover module-internal surface -
FilePath parsing internals, the POSIX temporary-path helpers, the internal
utilities, the platform constants, the syscall shims, the mocking layer and the
CSystem shims - none of which an external package can reach. They need a
battery that runs inside the package's own test target.

## iter 4/10 | 0188a734-012350 | 2026-09-03 | SWEEP | done

Task: Keep sweeping. The seven rows left all cover module-internal surface, so
this iteration built the second harness they need and swept the first three.

Changed: .jeffy/probes/_harness/run-internal.sh (new), three new batteries -
internal-utilities, filepath-parsing, filepath-temp-posix - each with paths,
probe.swift, README.md and claims. JOURNAL.md and PLAN.md (three rows flipped
in the bookkeeping edit). Sources/ and Tests/ are unchanged at the checkpoint:
every mutation below was applied to a pristine file and restored, and the
harness removes its copied test file under a trap.

Checkpoint: 3af4741

Verification: `swift test` through the installed quiet-verify wrapper: green
(10s), summary line `Executed 55 tests, with 0 failures (0 unexpected)`.
`skills/jeffy/hooks/lib/check-claims.sh .` reports `claims: 14 checked, 0
mismatched, 0 errored, 0 skipped`.

run-internal.sh exists because the parsing helpers, the consumer family, the
errno wrappers and the temporary-path helpers are all internal, so a package
that merely depends on this one cannot reach them. It copies a battery into
Tests/SystemTests under a fixed name, runs `swift test` filtered to it, and
removes it again under a trap.

Each battery was observed failing before it was trusted:
  - internal-utilities: `Slice._eat(if:)` rewritten to drop the first element
    before testing the predicate, so a failed match consumes input anyway. Red,
    exit 1, on four checks; every hit-only check stayed green, which is why
    each consumer is driven on a miss as well.
  - filepath-parsing: `isPrenormalSeparator` with its `c == genericSeparator`
    term dropped. Red, exit 1, on `isPrenormalSeparator slash on windows`
    alone; every POSIX check stayed green.
  - filepath-temp-posix: `makeLockedDownDirectory` creating the directory
    0o755 instead of 0o700 - a temporary directory readable by every user on
    the host. Red, exit 1, on `temp dir is owner only`; every existence check
    passed over it.

The first of those runs exposed a defect in the harness rather than in the
code: run-internal.sh treated a non-zero `swift test` exit as a build failure,
so a red battery printed no FAIL lines and no summary at all. It now decides on
the summary line first and treats its absence, not the exit status, as the
build failure. Both the red and the green case were re-run after the fix.

filepath-temp-posix deliberately does not pin the nested-subdirectory case.
That is the open finding SS-3: pinning the correct behaviour would leave the
battery permanently red and the row permanently unswept, and pinning the
current behaviour would certify a defect. The battery's README says so, and
the nested regression test belongs to SS-3's acceptance check.

Learnings: `Slice` and `ArraySlice` are different types, so the package's
`_eat` consumers - defined on `Slice` - need `Slice(base:bounds:)` values, not
`array[...]`. `_withCStringArray` hands back a buffer whose count covers the
strings only; the guaranteed null slot sits one past it and must be read
through `baseAddress`, because the buffer subscript is bounds checked in a
debug build and traps on that index. A probe harness needs its own red-case
test: this one reported a failing battery as a broken build until it was
driven with a real failure.

Next: four internal rows remain - the mocking layer, the syscall shims, the
platform constants and interop, and the CSystem shims.

## iter 5/10 | 0188a734-012350 | 2026-09-03 | SWEEP | done

Task: Sweep the last four unswept rows, all module-internal.

Changed: four new batteries under .jeffy/probes/ - mocking, syscall-shims,
platform-constants, csystem-shims - each with paths, probe.swift, README.md and
claims. JOURNAL.md and PLAN.md (four rows flipped in the bookkeeping edit).
Sources/ and Tests/ are unchanged at the checkpoint.

Checkpoint: 9dd20fe

Verification: `swift test` through the installed quiet-verify wrapper: green
(5s), summary line `Executed 55 tests, with 0 failures (0 unexpected)`.
`skills/jeffy/hooks/lib/check-claims.sh .` reports `claims: 18 checked, 0
mismatched, 0 errored, 0 skipped`. The Surface inventory now lists no unswept
row: 18 swept, 5 unreachable on this host, none open.

Two of these rows are swept against an enumeration derived by command rather
than by reading. syscall-shims drives every definition in Syscalls.swift whose
body reads `mockingEnabled` and asserts each records its own name in the trace;
platform-constants compares every `_`-prefixed constant this platform's guards
admit against the C macro it wraps, and asserts its own count so a constant
added without a check is caught rather than skipped.

Each battery was observed failing before it was trusted:
  - mocking: the `.counted` arm setting forceErrno straight to `.none` instead
    of decrementing, so a counted force fires once whatever its count. Red,
    exit 1, on two checks; the retry check stayed green, because a retry loop
    succeeds either way.
  - syscall-shims: `system_pwrite` passing an explicit `name:` of its sibling,
    so it traces as `write`. Red, exit 1, on `pwrite records its own name`
    alone; the argument and entry-count checks stayed green.
  - platform-constants: `_MODE_PERMISSIONS_MASK` narrowed from 0o7777 to
    0o777, dropping setuid, setgid and sticky from every mode decomposition.
    Red, exit 1, on the mask check alone; all ninety per-constant checks
    stayed green.
  - csystem-shims: `csystem_posix_dup3` calling `dup2` on the branch this
    platform takes - a silent degradation that still returns a valid
    descriptor. Red, exit 1, on `dup3 honoured CLOEXEC` and `dup3 refuses an
    identical pair`; every check that only moved bytes through the duplicate
    stayed green.

Learnings: a C shim that exists only to reach a flag must be probed through
that flag's observable effect - `FD_CLOEXEC` read back through fcntl here -
because a wrapper that degrades to the flagless syscall still returns a
working descriptor. Constants of differing C types cannot share one Swift
comparison table; widening both sides to Int64 is what let the whole constant
enumeration be driven in one loop.

Next: the map is fully swept, so the queue falls to the open Medium tasks -
SS-1 first, then SS-2, then the carried Low SS-3.

## iter 6/10 | 0188a734-012350 | 2026-09-03 | SS-1 | done

Task: SS-1 (Medium, runtime, correctness) - on Windows, `FileDescriptor.open`
with `.create` in `options` and `permissions: nil` did not trap, though the doc
comment on all three `open` overloads says it does.

Closed this iteration: SS-1 - the `options.contains(.create)` fatalError guard
now exists in the Windows `_open` as well as the POSIX one, so the documented
contract holds on both, and the one in-tree caller that violated it was given
explicit permissions.

Changed: Sources/System/FileOperations.swift (the guard, copied verbatim from
the POSIX branch into the Windows one),
Tests/SystemTests/FileOperationsTest.swift (`generateRandomData`, inside
`#if os(Windows)`, opened with `[.create, .truncate]` and no `permissions:` -
exactly the programmer error the doc names, and it would now trap; it passes
`.ownerReadWrite`).

Checkpoint: 5ca35b5

Verification: acceptance check as filed - `grep -c "must not be nil when
'options' contains" Sources/System/FileOperations.swift` equals `grep -c
'internal static func _open' Sources/System/FileOperations.swift`. Against
`git show HEAD:Sources/System/FileOperations.swift` the two were 1 and 2; after
the fix both are 2, so the check does fail on the unfixed code. `swift test`
through the installed quiet-verify wrapper: green (5s), summary line `Executed
55 tests, with 0 failures (0 unexpected)`. The owning battery
filedescriptor-ops, whose paths file declares FileOperations.swift, re-ran
through run-probe.sh: 29/29.

The changed branch is inside `#if os(Windows)` and this host builds
x86_64-unknown-linux-gnu, so the Verify command never compiles it. Rather than
ship an unbuilt edit on that evidence alone, the whole Windows `_open` was
extracted verbatim, renamed, and compiled inside the package's own test target
against the real internal symbols - `system_open`, `valueOrErrno`,
`FilePermissions`, `OpenOptions` - and it typechecks. That is compile
coverage, not behavioural coverage: no host here can observe the trap firing.

Contract preserved: a Windows caller that passes `permissions` is unaffected -
that arm is untouched and is the one every in-tree caller now takes. A caller
that passes `.create` with nil permissions previously received a file created
with the process default DACL, because the Windows adapter hands
`lpSecurityDescriptor: nil` to CreateFileW; it now traps, which is what the doc
comment on that overload has always promised and what the POSIX branch has
always done. The alternative fix - rewriting the doc to describe the default
DACL - was rejected because file permissions are the one thing this call is
choosing, and failing loudly is the safer default when the caller has said
nothing about them.

Learnings: a fix confined to a platform branch this host cannot build is still
compilable evidence if the branch's body is extracted verbatim and typechecked
inside the test target; say plainly in the entry that this is compile coverage
and not behavioural coverage. Before adding a precondition to a public API,
enumerate the in-tree callers that would newly trip it - here the package's own
Windows test helper was relying on the behaviour the documentation calls a
programmer error.

Next: SS-2, the loop's state files reaching the published source archive.

## iter 7/10 | 0188a734-012350 | 2026-09-03 | SS-2 | done

Task: SS-2 (Medium, build-ci, dependency hygiene) - the loop's own state files
reach the package's published source.

Closed this iteration: SS-2 - `.gitattributes` now marks PLAN.md, BACKLOG.md,
JOURNAL.md, JOURNAL-archive.md, `.jeffy/` and itself `export-ignore`, so the
source archive no longer carries them. The fix is partial and the residual is
filed under Proposed; see below.

Changed: .gitattributes (new).

Checkpoint: 45b9c0b

Verification: the finding reproduces on the unfixed tree exactly as filed -
`swift package archive-source` against HEAD before the fix put 101 state-file
entries in the zip out of 219 total. With the rules in place,
`git archive --worktree-attributes --format=zip HEAD` produces 0 state-file
entries out of 117 total, and all 61 `Sources/` entries survive, so nothing the
library needs was caught by the patterns. The `--worktree-attributes` flag is
needed only because `git archive` reads `.gitattributes` from the tree-ish it
is archiving, and at that point the file was staged rather than committed; the
committed-state check is recorded in the bookkeeping edit below.
`swift test` through the installed quiet-verify wrapper: green (2s), summary
line `Executed 55 tests, with 0 failures (0 unexpected)`. No battery declares
`.gitattributes` in its paths file, so no battery was owed a re-run.

Committed-state acceptance check: with `.gitattributes` committed, `swift package archive-source` puts 0 state-file entries in the zip, against 118 total entries and 61 under Sources/. That is the acceptance check as filed, run against the committed tree.

What this fix does not close, verified rather than assumed: SwiftPM resolves a
git dependency by cloning the repository and checking out a working copy, and
`export-ignore` has no effect there. A scratch consumer package depending on
this tree by `file://` URL was resolved, and
`.build/checkouts/swift-system/` held PLAN.md, BACKLOG.md, JOURNAL.md and
`.jeffy/`. So the archive channel is closed and the clone channel is not. The
only remedy for the clone channel is to stop committing the state files, which
conflicts with the loop's own design, so it is filed under Proposed as a
decision for the user rather than silently left as a closed finding.

Learnings: `git archive` reads `.gitattributes` from the tree-ish being
archived, not from the working tree, so an `export-ignore` rule cannot be
tested against the current commit until it is itself committed;
`--worktree-attributes` proves the patterns are right in the meantime. A
packaging finding has one channel per distribution mechanism, and closing the
archive channel says nothing about the clone channel - both had to be measured
separately, and the clone channel was measured by actually resolving the
package from a consumer rather than by reasoning about what SwiftPM does.

Next: SS-3, the carried Low - recursiveRemove addressing entries below the
first level against the wrong directory.

## iter 8/10 | 0188a734-012350 | 2026-09-03 | SS-3 | done

Task: SS-3 (Low, runtime, correctness) - the temporary-directory cleanup walk
resolved every name below the first level against the top-level descriptor
instead of the one that enumerated it.

Closed this iteration: SS-3 - the walk now opens each subdirectory and recurses
on its own descriptor, so every `unlinkat` and every descent resolves against
the directory that produced the name.

Changed: Sources/System/FilePath/FilePathTempPosix.swift (the walk restructured;
`recursiveRemove(in:name:)` and `impl_opendirat` replaced by
`recursiveRemoveContents(in:)` and a `forEachFile(in:)` that takes a descriptor
rather than a parent-plus-name pair, which is what made the old shape
expressible at all), Tests/SystemTests/FilePathTests/FilePathTempTest.swift
(testNestedCleanup, a permanent regression test),
.jeffy/probes/filepath-temp-posix (nested, directories-only and wide cases
added; removal failures now reported as named checks; README and claims
updated).

Checkpoint: edea071

Verification: the acceptance check as filed - a test that builds a nested tree
inside `withTemporaryFilePath` and asserts the directory no longer opens after
the closure returns. Against `git show HEAD:Sources/System/FilePath/
FilePathTempPosix.swift` restored over the fix, `swift test --filter
testNestedCleanup` fails with two assertion errors; against the fix it passes.
`swift test` through the installed quiet-verify wrapper: green (5s), summary
line `Executed 56 tests, with 0 failures (0 unexpected)` - one higher than
every earlier iteration, which is the new regression test. The owning battery
filepath-temp-posix re-ran green at 33/33 and `check-claims.sh` matches.

Two fix attempts were needed, and the second was found by the instrument
rather than by reading. The first restructure handed `fdopendir` a
`system_dup` of the caller's descriptor. A duplicate shares its file position
with the original, so the walk's second enumeration began where the first had
stopped, saw nothing, unlinked nothing, and `rmdir` failed `ENOTEMPTY` - the
same symptom as the original defect, from a different cause. The battery
reported it immediately. The walk now opens the directory through itself with
`openat(dirfd, ".")`, which yields an independent description with its own
position. That failure is recorded in the battery README as its second
discriminating mutation, because it is a real defect this instrument caught
rather than an invented one.

Contract preserved: `_recursiveRemove(at:)` keeps its signature, its
throw-on-failure behaviour and its removal of the named directory itself; the
`.` and `..` entries are still skipped by the same byte comparison. One
pre-existing limitation is preserved rather than introduced: an entry whose
`d_type` is `DT_UNKNOWN`, which some filesystems report, is treated as a
non-directory and its `unlinkat` fails - the old walk had the same behaviour,
and widening it is out of this task's scope.

Learnings: `fdopendir` takes ownership of its descriptor and `dup` does not
give an independent file position, so a walk that enumerates one directory
twice must open it afresh each time. A battery that lets an operation's throw
escape reports a red run with no named check; catching it and scoring it as a
check is what makes the failure legible.

Next: the closing full audit. The ledger is empty of High and Medium and now
of Low as well, and the map is swept, so what remains is a fresh-evidence
rescore of every dimension, then the evaluator gate.

## iter 9/10 | 0188a734-012350 | 2026-09-03 | AUDIT | audit

Task: The closing full audit. Rescore every applicable dimension against the
severity rubric and the Operating envelope with fresh evidence. This is the
last iteration that can hold one: the closing extension window admits no audit.

Changed: JOURNAL.md only. No BACKLOG item changed state and no Surface
inventory row changed state, because the audit filed nothing; an AUDIT entry
that files nothing is a ceremony entry and not a stall.

Checkpoint: ee6bdf7

Verification: `swift test` through the installed quiet-verify wrapper: green
(10s), summary line `Executed 56 tests, with 0 failures (0 unexpected)`.

Fresh evidence gathered this iteration, not carried from earlier ones:
  - Every battery re-executed through check-claims.sh: `claims: 18 checked, 0
    mismatched, 0 errored, 0 skipped`, 952 known-answer checks across the whole
    swept map. Each of those batteries was, at its creation, observed failing
    under a discriminating mutation of the code its row certifies.
  - Row staleness derived from each battery's own paths file rather than
    trusted: for every swept row, `git diff --name-only <recorded commit> HEAD`
    over that battery's declared globs is empty. No stale rows.
  - The Environment fingerprint's exclusion list re-derived by the command the
    line itself names. It still returns exactly IORingTests.swift and
    IORequestTests.swift (inside `#if compiler(>=6.2) && $Lifetimes`, and
    `swift --version` still reports 6.1.2), FileOperationsTestWindows.swift
    (`#if os(Windows)`), and MachPortTests.swift (`#if SYSTEM_PACKAGE_DARWIN`).
    Package.swift's `testsToExclude` is still empty on Linux, so these are
    excluded by source guard alone. The Oracle class was re-read and still
    describes what the command grades.
  - Artifact channels re-enumerated by command, not recalled: the manifests are
    Package.swift and the CMakeLists set; there is no release or publish
    workflow, no container build, no podspec, gemspec, nuspec or sdist config.
    `swift package archive-source` now yields zero state-file entries. The
    CMake install rules name only headers. The SwiftPM clone channel remains
    open and is the Proposed item.
  - The project's own soundness check re-run: the SwiftPM source list for
    SystemPackage and the CMakeLists source list agree exactly.
  - `git diff` of Sources/ against the commit preceding this run's first
    checkpoint adds and removes no `public` declaration, so this run changed no
    public API.
  - Declined entries: none, so there is no Derivation to re-run. Settled
    classes: none, so there is no enumeration to re-run.

Scores. All 18 swept rows carry fresh evidence this iteration; 5 rows are `[~]`
unreachable on this host and are claimed by no score below.
  - correctness: None over the swept rows.
  - security: None over the swept rows. SS-1 closed the one path where a file
    was created with the process default DACL against a documented trap; the
    temporary directory's 0o700 mode and lexicallyResolving's containment,
    including four subpaths that must refuse, are both pinned by batteries.
  - architecture, code quality, performance, developer experience: None over
    the swept rows.
  - error handling: None over the swept rows. The `try?` around cleanup in
    withTemporaryFilePath is not a swallowed error in the usual sense: a Swift
    `defer` block cannot throw, so the language forces it.
  - documentation: None. SS-1 was the one documented promise the code did not
    keep; the README's toolchain table still matches the manifest's
    swift-tools-version.
  - dependency hygiene: None. The package declares no dependencies, and the
    archive channel is clean. The SwiftPM clone channel is not scored here
    because it is a Proposed item awaiting a user decision, and it is named in
    the run report rather than hidden behind this score.
  - testing: Low. The entire IORing surface - five source files and two test
    files - is ungraded on this toolchain, which is what the `[~]` rows and the
    Environment fingerprint both record. No task is filed for it: it is not a
    gap in the suite but a platform this host cannot reach, which is what the
    `[~]` state exists to record, and the run report names every such row.
  - observability: not applicable. A syscall wrapper vends errno to its caller
    and owns no logging or metrics surface.
  - UX, accessibility: not applicable. The package has no user-facing surface.

Zero High and zero Medium in-envelope. Closeout has begun: no further audit and
no replenishment for the rest of this run.

Learnings: an audit's own tooling can fabricate a finding. The first parse of
the CMake source list used a regex anchored at end of line, and CMake closes
each `target_sources` group on the same line as its last entry, so five files
read as missing from CMake that are plainly listed there. Had that gone into
the ledger it would have been five invented defects in the project's build
files. Strip the delimiter and re-derive before believing a comparison that
says a list is incomplete.

Next: the evaluator gate, then the declaration if it passes.

## iter 10/10 | 0188a734-012350 | 2026-09-03 | EVALUATOR | converged

Task: The evaluator gate and, on a PASS, the declaration. The clean full audit
this declaration cites is on record from iteration 9, before any extension
window.

Changed: PLAN.md (one swept row's prose no longer names a closed finding ID, so
no reader can mistake it for a carried reference; the row's recorded commit and
battery are untouched), .jeffy/evaluator/0188a734-012350-1.md (the gate's
artifact), JOURNAL.md, BACKLOG.md (the Converged line, appended in the
bookkeeping edit).

Checkpoint: 39b0c81

Verification: standing claims brought current in this same iteration before the
invocation - `check-claims.sh` reports `claims: 18 checked, 0 mismatched, 0
errored, 0 skipped`; row staleness re-derived from each battery's own paths
file against its recorded commit, zero stale; Declined derivations and
Settled-class enumerations both empty, so neither had anything to re-run; every
battery's claims file well formed; the Oracle class and Environment fingerprint
re-read. `swift test` through the installed quiet-verify wrapper this
iteration: green (2s), summary line `Executed 56 tests, with 0 failures (0
unexpected)`.

Evaluator: PASS - invocation 1 of this run reproduced all three closed tasks on
both sides of their base commit, confirmed the Verify command and check-claims
green, re-scored the ledger, and judged the SS-1 compile-coverage claim and the
empty Verify count cell honest.

The `Verify count` cell is deliberately empty and the gate confirmed the
premise independently: the command drives two runners, the summary pattern
matches XCTest's aggregate alone, so the matched integer is a subtotal and
recording it as the total would be false. The Stop hook permits an empty cell.

Carried Lows at this declaration: none. The ledger holds no open task at any
severity.

Observations the gate recorded, none of them REJECT reasons, none fixed inside
this convergence sequence and all carried to the run report and the next run's
ledger:
  - The SS-1 compile-coverage extraction was transient, so the journal's
    evidence is reconstructable rather than re-runnable from the repository.
  - That typecheck bound this host's POSIX `system_open` and
    `CInterop.PlatformChar`, not Windows's, so it certifies that the added
    lines typecheck and not that the Windows branch compiles on Windows. The
    iteration 6 entry did not draw that distinction and should have.
  - The restructured cleanup walk holds about two descriptors per directory
    level during its first pass where the old one held about one, and no
    battery exercises deep trees.
  - `Sources/CMakeLists.txt`, `Sources/CSystem/CMakeLists.txt`,
    `Sources/System/CMakeLists.txt` and `Sources/CSystem/include/io_uring.h`
    appear in no battery's paths file, so no row's staleness derivation covers
    them.

Learnings: a swept row's prose that names a closed finding ID reads like a
carried reference to anything checking for dangling IDs; describe the behaviour
and leave the ID to the journal. A gate observation is not a defect to fix
before declaring - fixing one invalidates the PASS it was recorded under and
spends an invocation the declaration needs.

Next: nothing in this run. The four gate observations are the next run's first
material, and the Proposed item about the SwiftPM clone channel awaits a user
decision.
