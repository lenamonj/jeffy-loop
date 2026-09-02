# Journal archive

Rotated entries from JOURNAL.md, appended in rotation order and never
overwritten. The newest entries stay in JOURNAL.md.

## iter 1/10 | e6cbe980-022744 | 2026-09-01 | AUDIT | audit

Task: First audit of a fresh Jeffy project. Fill the Operating envelope, the
Surface inventory and the Verify command section, enumerate the tree's
artifact-producing channels, probe the reachable surface breadth-first, and
seed BACKLOG.md.

Changed: PLAN.md (envelope surfaces, 28 inventory rows, Verify command block,
Stated counts table, Lessons), BACKLOG.md (SC-1 through SC-4), JOURNAL.md,
.gitignore (bootstrap entry for the transient loop state file).

Checkpoint: 754e0d37ff866edecf6a000a1dbaedcbbce9da0c

Verification:
- Verify command established as `swift test`, green through the wrapper:
  `verify: green (124s, oracle=XCTest ..., Executed 623 tests, with 0 failures
  (0 unexpected) in 123.403 (123.403) seconds)`. Verify count recorded as 623,
  the wrapper's own figure.
- Environment: SwiftPM selects `Package@swift-6.0.swift`, not `Package.swift`,
  because the installed Swift 6.1.2 is below the primary manifest's declared
  tools version 6.2 (`swift package describe | grep 'Tools version'` prints
  `Tools version: 6.0`). Two consequences the fingerprint now records: the
  `SortedCollections` target is absent from that manifest entirely, so nothing
  under `Sources/SortedCollections` is built or graded; and every
  `#if compiler(>=6.2)` block is false, which empties four declared test
  targets - BasicContainersTests, ContainersTests, SpanPreviewTests,
  TrailingElementsTests - to zero executed cases. The suites that did run were
  cross-checked against the guard enumeration rather than assumed.
- Reachability was established by building, not by reading. A scratch SwiftPM
  package under /tmp that path-depends on this project fails to compile
  `RigidArray<Int>(capacity: 4)` with "argument passed to call that takes no
  arguments", because Swift 6.1.2 compiles the `#if compiler(<6.2)` placeholder
  whose only initializer is `@available(*, unavailable)` and calls
  `fatalError()`. That is deliberate and correct, and it is why eleven
  inventory rows are `[~]` rather than unswept. `Sources/SortedCollections`
  went the other way: a scratch package containing it and
  InternalCollectionsUtilities builds clean, so its two rows are reachable and
  sweepable out-of-tree even though `swift test` never touches them.
- Breadth-first shallow probe, 42 known-answer checks across every reachable
  module (Heap ordering, Deque wrap-around and index arithmetic, OrderedSet
  insertion order and set algebra, OrderedDictionary position stability,
  BitSet/BitArray membership and set ops, TreeSet/TreeDictionary, Codable
  round-trips for all seven reachable Codable types, and four malformed-input
  decodes that must throw): 42/42 passed. This is a shallow probe and flips no
  inventory row; it is not a per-function-family sweep.
- Artifact channels enumerated by command, not recall: `.github/workflows/`
  holds only `pull_request.yml`; there is no MANIFEST.in, package.json,
  gemspec, nuspec, Cargo.toml or Dockerfile; distribution is SwiftPM (git
  clone) plus `swift package archive-source`, with CMake install rules that
  emit only build products. The archive channel fails the state-file check and
  is filed as SC-2: a scratch repo carrying PLAN.md and .jeffy/ reproduces the
  leak, and a `.gitattributes` with `export-ignore` was confirmed to close it.
- SC-1 reproduced by running the README snippet as published: a package whose
  manifest is the README's integration example verbatim fails with
  `error: package is using Swift tools version 6.3.0 but the installed version
  is 6.1.2` before dependency resolution.

Scores. These claim only the surface the shallow probe actually touched; zero
inventory rows are swept, so every None below is silence about the remainder,
not cleanliness. 17 of 28 rows are reachable and unswept, 11 are `[~]`.
- architecture: None (shallow) - module boundaries and trait gating are
  coherent; the `#if compiler(<6.2)` placeholder pattern is deliberate.
- code quality: None (shallow).
- security: None - the one adversarial surface is Codable decoding; all four
  malformed-input probes threw `DecodingError` rather than trapping or
  silently accepting, and the decoders reserve capacity proportional to input
  actually supplied.
- testing: Low - four test targets contribute zero cases on this toolchain
  (an environment fact, recorded in the fingerprint, not a project defect),
  and 23 `#if false` blocks sit in the test tree. Class test, so Low by the
  severity ceiling regardless.
- error handling: None (shallow).
- performance: not scored - no row swept deeply enough to judge.
- documentation: Medium - SC-1.
- dependency hygiene: Medium - SC-2. The package itself has zero external
  dependencies.
- developer experience: Low - SC-3, SC-4.
- correctness: None on the 42 checks run; the 17 unswept rows are unexamined.
- observability: not applicable - a data-structure library emits no telemetry.
- UX and accessibility: not applicable - no user-facing surface.

Learnings: a `public` declaration in Sources is not shipped API until its
enclosing `#if` is checked - BitArray's `|=`, `&=`, `^=` and `~` are all
`public` inside a `#if false` block with a written rationale, and reading the
grep hit alone would have filed a false "untested shipped operator" finding.
Reaching a target the active manifest excludes is done with a scratch package
under /tmp that path-depends on this project, never by editing this project's
manifests.

Next: SC-1, then SC-2, then sweep the reachable inventory rows.

## iter 2/10 | e6cbe980-022744 | 2026-09-01 | SWEEP | done

Task: Sweep Surface inventory rows. The ledger held no open High, so the map
was the top of the queue: 17 reachable rows unswept, 9 iterations left.

Changed: .jeffy/probes/ (harness package and five batteries with their paths,
claims, README and run.sh), BACKLOG.md (SC-5 filed), JOURNAL.md, PLAN.md
(Lessons, and five inventory rows recorded at this checkpoint).

Checkpoint: 0ef92eccdb33f811d11a693311401fa9d3ad7427

Verification:
- Rows swept this iteration, each by an executed known-answer battery, never a
  run-without-crash probe: HeapModule, OrderedCollections/OrderedSet,
  OrderedCollections/OrderedDictionary, DequeModule/Deque,
  BitCollections/BitArray. Five of seventeen reachable rows.
- `check-claims.sh` executes all five batteries plus the PLAN.md counts row:
  `claims: 6 checked, 0 mismatched, 0 errored, 0 skipped`.
- Verify green: `verify: green (122s, oracle=..., Executed 623 tests, with 0
  failures (0 unexpected) in 120.23 (120.23) seconds)`.
- Every battery was observed failing on a real mutation of the code it covers,
  recorded in its README with the exact edit: heapmodule 4 checks red on an
  off-by-one in the min-max level boundary `max` reads; orderedset 20 red on an
  off-by-one in the linear scan used below the hash-table threshold;
  ordereddictionary 1 red on `updateValue` returning `nil` instead of the
  previous value; bitarray 6 red on the `toggleAll` tail mask; deque aborts on
  a wrong `count`. Two of these instruments were rebuilt after the first
  mutation attempt reddened too little: the heap battery now enumerates every
  permutation of every input up to size 5 instead of sampling shuffles, and the
  bit-array battery now sweeps every count from 0 to 130 and compares whole
  values rather than counting set elements, because the first drafts could not
  see the mutations at all.
- SC-5 filed and reproduced: the doc comment on `BitArray.init?(_:)` documents
  `BitArray("42") // nil`, but a string literal at the call site resolves to
  `init(stringLiteral:)` and traps. A program whose only statement is the
  documented expression aborts with `Fatal error: Invalid bit array literal`;
  the same characters through a non-literal `String` return `nil` as
  documented, which is why this is filed against the documentation and not the
  runtime.

Learnings: a probe binary can be stale. SwiftPM recompiled the mutated
DequeModule and then skipped relinking the battery executable, because a change
confined to inlinable code does not move the module interface - both
`swift build --product` and `swift run` reported success and ran the previous
binary, so the battery certified code it never executed. Every `run.sh` now
deletes its executable before building. This is the failure mode the
discriminating-mutation record exists to catch, and it was caught only because
a mutation that should have reddened the battery did not.

A mutation that reddens nothing is a statement about the instrument, not about
the code: three separate mutations passed unnoticed here before the batteries
were strengthened, and the deque battery still misses two off-by-one mutations
of the ring-buffer slot arithmetic, which is recorded in its README and is why
the storage-internals row stays unswept rather than riding along.

Next: sweep the remaining 12 reachable rows, then work SC-1, SC-2 and SC-5.

## iter 3/10 | e6cbe980-022744 | 2026-09-01 | SWEEP | done

Task: Continue sweeping Surface inventory rows. No open High, so the map was
still the top of the queue: 12 reachable rows unswept, 8 iterations left.

Changed: .jeffy/probes/ (five new batteries with their paths, claims, README
and run.sh), JOURNAL.md, PLAN.md (six inventory rows recorded at this
checkpoint).

Checkpoint: 1047496588b94a5014fe46b98ee58537c5917f5c

Verification:
- Rows swept this iteration, each by an executed known-answer battery:
  BitCollections/BitSet, HashTreeCollections/TreeSet,
  HashTreeCollections/TreeDictionary, HashTreeCollections/HashNode,
  Collections umbrella module, and OrderedCollections/HashTable. Eleven of
  seventeen reachable rows are now swept.
- The OrderedCollections/HashTable row is recorded against the existing
  .jeffy/probes/orderedset battery rather than a new one, because that
  battery's paths file already declares the HashTable sources and its size
  sweep is what exercises them: eleven sizes from 0 to 129 straddle the count
  at which the type stops scanning linearly and builds the table, and the
  mutation that battery records is in the linear path the table replaces.
- The HashNode row got its own battery rather than riding on treeset and
  treedictionary. It sweeps hash width as a parameter across five values, from
  every key in one collision node to nothing colliding, and it compares the set
  to its oracle after every single removal rather than only at the end, so a
  node that collapses wrongly is caught at the step it happens instead of being
  masked by later removals.
- `check-claims.sh`: `claims: 11 checked, 0 mismatched, 0 errored, 0 skipped`.
- Verify green: `verify: green (123s, ..., Executed 623 tests, with 0 failures)`.
- Discriminating records, each from a real mutation of the code the battery
  covers: treeset 51 of 147 red and treedictionary 50 of 97 red on a narrowed
  collision-node lookup in `_HashNode+Lookups.swift`; the same mutation reddens
  12 of 155 in the hashnode battery; collections-umbrella 3 of 20 red on the
  OrderedSet linear-scan off-by-one; bitset aborts (exit 132) on a wrong
  `count`. The colliding key type is what makes the collision-node mutation
  visible at all - against plain `Int` elements it is unreachable, which is why
  all three hash-tree batteries carry one.
- The umbrella battery records a limitation rather than hiding it: the Heap
  level-boundary mutation that reddens 4 checks in the heapmodule battery
  reddens none there, because its three-element heap has a layout the mutation
  does not disturb. It is a reachability instrument and its README says so.
- One battery expectation was wrong and the battery caught it before the row
  was recorded: the treedictionary merge check asserted the retained old value
  was 10 where the fixture held 20. Fixed in the battery, not in the ledger.

Learnings: a battery that drives a data structure through only its public
happy path can be unable to reach the code that actually decides correctness -
the CHAMP collision nodes here are unreachable with `Int` elements, and three
batteries needed a purpose-built colliding key type before any mutation of that
code could redden them. When a row's implementing code has a shape parameter
(hash width, capacity, threshold), sweep the parameter rather than picking one
value.

Next: six reachable rows remain - DequeModule storage internals, RopeModule/Rope,
RopeModule/BigString, SortedCollections/BTree, SortedCollections/SortedSet and
SortedDictionary, InternalCollectionsUtilities. Then SC-1, SC-2, SC-5.

## iter 4/10 | e6cbe980-022744 | 2026-09-01 | SWEEP | done

Task: Continue sweeping. The top unswept row was DequeModule storage
internals, the row the previous iteration explicitly declined to claim.

Changed: .jeffy/probes/deque-storage/ (new battery, paths, claims, README),
.jeffy/probes/deque/README.md (a claim in it was wrong and is corrected),
PLAN.md (the storage row split into three, one recorded at this checkpoint),
JOURNAL.md.

Checkpoint: bd65f063c4de035194fdde22631f8658a9b94b25

Verification:
- Built .jeffy/probes/deque-storage, which sweeps the head position rather
  than relying on the buffer shapes ordinary use produces: for capacities 4, 8
  and 16, at six counts each, with the live region rotated to start at every
  slot in turn, it checks contents, count, every subscript, index offsets
  computed from both ends and required to agree, both segments read whole,
  every slice up to length 3 across the segment seam, growth from a wrapped
  state at both ends, and insertion and removal at every position. 2815 checks.
- That battery was still green under all three mutations of
  `_UnsafeDequeHandle.swift`, including one deliberately made unambiguously
  wrong rather than an edge case. Rather than call that weak coverage, the
  reachability was established by provoking a failure at each site:
  `_DequeSlot.advanced(by:)` replaced with `fatalError()` traps immediately, so
  it is reached; `_UnsafeDequeSegments.count` replaced the same way does not
  trap, so the battery never reaches it; and
  `grep -rln '_UnsafeDequeHandle' Sources/DequeModule/` returns only that file
  and `RigidDeque/RigidDeque.swift`, every file of which sits inside a
  `compiler(>=6.2)` guard.
- The conclusion is that `_UnsafeDequeHandle.swift` has no live consumer on
  this toolchain. The single inventory row for storage internals was therefore
  wrong as written: it is now three rows - `_DequeSlot` swept, and recorded at
  this checkpoint; `_UnsafeDequeSegments` unswept with the failure-provocation
  result as its reason; `_UnsafeDequeHandle` marked `[~]` with the grep that
  establishes it.
- The previous iteration's `deque` battery README claimed the two surviving
  mutations showed weak wrap coverage. That claim was wrong and is corrected in
  place, naming the real cause and pointing at the evidence. The `deque`
  battery does detect a real defect in the slot arithmetic it reaches: an
  unconditional off-by-one in `_DequeSlot.advanced(by:)` aborts it with exit
  132, as it aborts the new battery.
- Discriminating record for the new battery is that same unconditional
  mutation, together with the recorded fact that a narrower one conditioned on
  `delta == 3` leaves it green, which bounds what the instrument detects.
- `check-claims.sh`: `claims: 12 checked, 0 mismatched, 0 errored, 0 skipped`.
- Verify green: `verify: green (148s, ..., Executed 623 tests, with 0 failures)`.

Learnings: when a mutation reddens nothing, the question "is my instrument
weak, or is that code dead here?" has to be answered before either conclusion
is written down, and the way to answer it is to replace the body with
`fatalError()` and see whether anything traps. Three mutations were written up
last iteration as a coverage gap when the code had no live caller at all on
this toolchain. A grep for a symbol's consumers is the second half of that
check: code reachable only from a `compiler(>=6.2)` type is dead here exactly
as the `[~]` rows are, and belongs in that state rather than on the unswept
list where it would block a declaration forever.

Next: five reachable rows remain - RopeModule/Rope, RopeModule/BigString,
SortedCollections/BTree, SortedCollections/SortedSet and SortedDictionary,
InternalCollectionsUtilities - plus DequeModule/_UnsafeDequeSegments. Then
SC-1, SC-2, SC-5.

## iter 5/10 | e6cbe980-022744 | 2026-09-01 | SWEEP | done

Task: Continue sweeping. Targets were RopeModule/Rope and RopeModule/BigString.

Changed: .jeffy/probes/_harness (rope target added), .jeffy/probes/rope/ (new
battery, paths, claims, README), PLAN.md (BigString row moved to `[~]`, Rope
row recorded at this checkpoint, Lessons), JOURNAL.md.

Checkpoint: 3bed0d5c15d288373e8ca76d04f6bda8c152fe70

Verification:
- RopeModule/BigString is unreachable on this host and is now `[~]` rather than
  unswept. `find Sources/RopeModule/BigString -name '*.swift'` returns 47 files
  and every one is inside a `compiler(>=6.2)` guard; a scratch target importing
  `_RopeModule` fails with "cannot find type 'BigString' in scope". The type is
  additionally marked `@available(SwiftStdlib 6.2, *)`. RopeModule/Rope is the
  opposite case - none of its 27 files is gated - so it was swept.
- Built .jeffy/probes/rope with a purpose-built `RopeElement`: a chunk of Ints
  whose summary is its element count, and a `RopeMetric` whose `size(of:)` is
  the identity. That is what makes it a known-answer instrument: the flattened
  concatenation is a plain `[Int]` and every offset is a quantity with a value.
  405 checks over seven chunk shapes sized past `maxNodeSize`, covering
  construction and invariants, prepend as append's mirror, summary additivity
  over every ordered pair of shapes, find/offset round-trips, `extract` over
  every ordered pair of six offsets per shape against the flat oracle,
  `removeSubrange` as extract's complement, and 20 randomized builds.
- Discriminating record: narrowing the extracted range by one in
  `Rope+Extract.swift` reddens 140 of 405 checks.
- `check-claims.sh`: `claims: 13 checked, 0 mismatched, 0 errored, 0 skipped`.
- Verify green: `verify: green (130s, ..., Executed 623 tests, with 0 failures)`.
- The first version of the element conformance reported chunks as undersized
  and the battery aborted on `assert(!item.isUndersized)` in
  `Rope+Builder.swift`. That was investigated before anything was written down:
  two one-element chunks cannot merge into a well-sized chunk under any
  threshold above two, so the obligation the protocol states -
  `rebalance(nextNeighbor:)` eliminating the undersized condition - cannot be
  met by that conformance. It is the conformance failing, not `Rope`, and
  `_RopeModule` is outside the package's documented public API besides. No
  finding was filed. The battery now declines the obligation by reporting
  chunks as never undersized, and its README states the consequence plainly:
  the element-rebalancing path is not exercised, every node-level path is.

Learnings: when a battery has to supply a conformance to drive a generic type,
that conformance is part of the instrument and can be the thing that is wrong.
An assertion firing inside the library is not evidence of a library defect
until the conformance's own obligations have been checked against what the
protocol documents.

Next: four reachable rows remain - DequeModule/_UnsafeDequeSegments,
SortedCollections/BTree, SortedCollections/SortedSet and SortedDictionary,
InternalCollectionsUtilities. Then SC-1, SC-2, SC-5.

## iter 6/10 | e6cbe980-022744 | 2026-09-01 | SWEEP | done

Task: Continue sweeping. Targets were the two SortedCollections rows and
InternalCollectionsUtilities - the three rows the active manifest cannot reach
as product dependencies.

Changed: .jeffy/probes/sortedcollections/ and
.jeffy/probes/internalcollectionsutilities/ (new batteries, each with its own
out-of-tree runner, paths, claims and README), PLAN.md (three rows recorded at
this checkpoint, Lessons), JOURNAL.md.

Checkpoint: 350c409b139b3a96784718ad3b77a08ba6c9ead9

Verification:
- Rows swept: SortedCollections/BTree, SortedCollections/SortedSet and
  SortedDictionary, InternalCollectionsUtilities. Sixteen of seventeen
  reachable rows are now swept.
- Both SortedCollections rows share one battery because `SortedSet` and
  `SortedDictionary` are thin faces on the B-tree. The BTree row is evidenced
  rather than assumed: mutating the binary search in
  `_Node.UnsafeHandle.startSlot(forKey:)` from `<=` to `<` reddens 56 of the
  battery's 694 checks.
- Every one of SortedCollections' 54 files sits behind
  `#if UnstableSortedCollections`, a package trait needing a tools-6.1+
  manifest this toolchain cannot load. The battery's runner assembles a scratch
  package outside the repository and sets the trait as a plain define, which is
  the configuration CI builds under `--traits UnstableSortedCollections`. The
  project's manifests were not edited.
- This corrects iteration 1, which recorded that SortedCollections "builds
  clean" out of tree and concluded the row was reachable. It does build - and
  produces an empty module, because without the trait every file compiles to
  nothing. The battery caught it immediately with "cannot find 'SortedSet' in
  scope". The row was reachable in the end, but not for the reason recorded,
  and the correction is now in that battery's README.
- InternalCollectionsUtilities is `package`-visible only, so a battery in a
  separate package sees an empty module. Its runner copies the sources to a
  scratch package and drops the checks in *as one more file of the same
  module*. The scratch manifest has to mirror `_sharedSettings` from the
  project's own manifest - without `MemberImportVisibility` and the
  `AvailabilityMacro` definitions the module does not compile out of tree at
  all. Discriminating record: perturbing the `Word(upTo:)` prefix mask reddens
  2 of 172 checks, precisely the two covering the zero case.
- `check-claims.sh`: `claims: 15 checked, 0 mismatched, 0 errored, 0 skipped`.
- Verify green: `verify: green (130s, ..., Executed 623 tests, with 0 failures)`.

Learnings: a successful build is not evidence that a type exists. Two modules
here compile to nothing under the default configuration - SortedCollections
without its trait define, and any `package`-visible module seen from outside
its package - and both report "Build complete". The check that distinguishes
them is naming a type from the module and seeing whether it resolves.

Reaching a module the active manifest excludes needs its build settings copied,
not just its sources: `MemberImportVisibility` changes which imports satisfy an
inlinable body, so a module that builds in tree fails out of tree without it.

Next: one reachable row remains, DequeModule/_UnsafeDequeSegments. Then SC-1,
SC-2 and SC-5, with SC-3 and SC-4 carried as Lows.

## iter 7/10 | e6cbe980-022744 | 2026-09-01 | SWEEP | done

Task: Sweep the last unswept row, DequeModule/_UnsafeDequeSegments.

Changed: .jeffy/probes/_harness/Sources/deque-storage (bulk-path family added),
.jeffy/probes/deque-storage/ (paths, claims, README), BACKLOG.md (SC-6 filed),
PLAN.md (the last row recorded at this checkpoint), JOURNAL.md.

Checkpoint: 119170704a6b62b1116e36302fc7bd8ebba2e4c3

Verification:
- The map is now clear: seventeen of seventeen reachable rows swept, thirteen
  `[~]` rows named with their reasons.
- Iteration 4 left this row unswept because trapping inside
  `_UnsafeDequeSegments.count` fired zero times. Probing the rest of the type
  showed the conclusion had been drawn from one member: trapping inside its
  three initializers fires 7 times under the deque-storage battery and once
  under the deque battery, so the type is live and merely unreached by
  index-by-index checks.
- Added a bulk-path family that consumes a wrapped deque wholesale at every
  head position - copy construction, `append(contentsOf:)`,
  `insert(contentsOf:at:)` front and middle, `Array(_:)`,
  `withContiguousStorageIfAvailable`, and `replaceSubrange` with a wrapped
  deque as the replacement. Those are what build and consume the two-segment
  descriptor. Battery is now 3023 checks, and mutating the two-segment
  initializer to shorten the second segment by one aborts it with exit 132.
- SC-6 filed (Low, runtime, code quality): `_UnsafeDequeSegments.count` and
  `isIdentical(to:)` have no caller anywhere in the module, gated or not.
  Trapping inside `count` still fires zero times with the bulk family in place,
  and `grep -rnE 'segments\b[^(]*\.(count|isIdentical)' Sources/DequeModule/`
  returns nothing - every consumer reads `first` and `second` directly. Scored
  Low because it is dead internal code a user of the shipped product never
  meets, per the severity rubric's Low line.
- `check-claims.sh`: `claims: 15 checked, 0 mismatched, 0 errored, 0 skipped`.
- Verify green: `verify: green (121s, ..., Executed 623 tests, with 0 failures)`.

Learnings: a fatalError reachability probe answers only for the member it
replaces. Iteration 4 concluded a whole file was unreached from one property,
and the file's initializers were being hit seven times in the same battery
run. Probe the type's constructors before its accessors: a type that is never
constructed is dead, but a type that is constructed and whose accessor is
unused is a dead accessor, which is a different and much smaller finding.

Next: the map is clear, so the queue moves to the Medium tasks - SC-1, SC-2,
SC-5 - with SC-3, SC-4 and SC-6 carried as Lows. Three iterations remain.

## iter 8/10 | e6cbe980-022744 | 2026-09-01 | SC-1 | done

Task: SC-1 (Medium, docs) - README's SwiftPM adoption snippet declared
`// swift-tools-version:6.3`, above every released Swift and above the
package's own stated minimum.

Changed: README.md (one line, in the integration snippet only), BACKLOG.md
(SC-1 deleted), JOURNAL.md.

Checkpoint: 278f8b6c122caff9908639d11cc0e05930cfa7ea

Verification:
- Ran the filed reproduction first, as the working rules require. Extracting the
  snippet from README verbatim into a scratch package and running
  `swift package dump-package` exited 1 with `package 'jeffy-sc1' is using
  Swift tools version 6.3.0 but the installed version is 6.1.2`.
- Fix: the snippet now reads `// swift-tools-version:6.0`. Chosen to match the
  README's own minimum-toolchain table, whose latest row - swift-collections
  1.6.x - requires Swift 6.0.3; a manifest declaring tools version 6.0 loads on
  that toolchain and on every later one. The snippet uses no package traits, so
  it needs nothing a tools-6.0 manifest cannot express.
- Acceptance re-run after the fix, extracting the snippet from README again
  rather than from a copy: `swift package dump-package` exits 0.
- Contract preserved: this is documentation only. The snippet is what a user
  copies into their own package, so lowering its tools version widens the set
  of toolchains that can adopt the package and narrows nothing.
- Verify green: `verify: green (126s, ..., Executed 623 tests, with 0 failures)`.
- Battery ownership: the diff touched README.md alone; no battery's paths file
  matches it, so no battery was owed a re-run and no inventory row went stale.
- Closed this iteration: SC-1 (Medium, docs) - README integration snippet now
  loads on the package's stated minimum toolchain.

Learnings: an ad-hoc consistency check written in the same breath as a fix can
be wrong in the fix's favour. The first version compared the snippet's tools
version against every row of the README's minimum-toolchain table, including
historical rows for 1.0.x through 1.5.x, and reported a mismatch that did not
exist. The correct comparison is against the latest row alone. A check invented
to confirm a fix deserves the same scrutiny as the fix.

Next: SC-2 (Medium, build-ci), then SC-5 (Medium, docs). Two iterations remain,
so SC-5 will likely carry to the next run alongside the Lows.

## iter 9/10 | e6cbe980-022744 | 2026-09-01 | SC-2 | done

Task: SC-2 (Medium, build-ci) - the repository carried no `.gitattributes`, so
a source archive of this tree shipped the loop's own state files.

Changed: .gitattributes (new), BACKLOG.md (SC-2 deleted), JOURNAL.md.

Checkpoint: 85d18d75a04f7f0b9167b7b8ed681618e7803887

Verification:
- Ran the filed reproduction first. `swift package archive-source` produced an
  archive of 1134 entries of which 110 were loop state - PLAN.md, BACKLOG.md,
  JOURNAL.md and the whole of `.jeffy/`, including the probe harness and the
  metrics the Stop hook writes.
- Fix: a `.gitattributes` marking PLAN.md, BACKLOG.md, JOURNAL.md,
  JOURNAL-archive.md and `.jeffy/` as `export-ignore`.
- The acceptance check did not pass on the first attempt, and the reason is
  worth recording rather than working around: `git archive` reads
  `.gitattributes` from the tree being archived, not from the working tree, so
  a newly written but uncommitted `.gitattributes` has no effect and the
  archive still carried all 110 entries. Confirmed the mechanism before
  committing anything, using the flag that exists for exactly this case:
  `git archive HEAD | tar -t` counts 110 loop-state entries,
  `git archive --worktree-attributes HEAD | tar -t` counts 0, and the same
  archive still holds 692 entries under `Sources/` and `Package.swift`. The
  attribute works; it just has to be committed to take effect.
- Acceptance against the committed tree, run after this iteration's checkpoint:
  `swift package archive-source` now yields 0 loop-state entries, while the
  same archive still holds 759 entries under `Sources/`, 136 under `Tests/`,
  `Package.swift` and `README.md`. Verify green afterwards:
  `verify: green (123s, ..., Executed 623 tests, with 0 failures)`, and
  `check-claims.sh` reports `claims: 15 checked, 0 mismatched, 0 errored, 0
  skipped`.
- Contract preserved: `export-ignore` affects `git archive` and the
  `swift package archive-source` built on it. It does not affect a plain clone,
  so a consumer who adds this package as a SwiftPM dependency by URL still
  receives every committed file - that channel is inherent to git-based
  distribution and is not what this task claimed to close.
- Closed this iteration: SC-2 (Medium, build-ci) - source archives of this tree
  no longer carry the loop's state files.

Learnings: `git archive`, and therefore `swift package archive-source`, reads
`.gitattributes` from the committed tree rather than the working tree. An
acceptance check for an export rule cannot pass before the rule is committed;
use `git archive --worktree-attributes` to prove the rule first, then let the
checkpoint make it real.

Next: SC-5 (Medium, docs) remains open with one iteration left, alongside the
carried Lows SC-3, SC-4 and SC-6.

## iter 10/10 | e6cbe980-022744 | 2026-09-01 | SC-5 | done

Task: SC-5 (Medium, docs) - the doc comment on
`BitArray.init?(_ description: String)` documented `BitArray("42") // nil`, but
a string literal at the call site resolves to `init(stringLiteral:)`, which
calls `fatalError`. The documented expressions could not reach the initializer
they documented.

This is the final iteration. The ledger was not at the severity floor - SC-5
was open and Medium - and the fix is a doc comment with a runnable acceptance
check, so it was completable inside one iteration. Closing it was preferred
over a WRAPUP that would have left a Medium open.

Changed: Sources/BitCollections/BitArray/BitArray+LosslessStringConvertible.swift
(doc comment only), BACKLOG.md (SC-5 deleted), JOURNAL.md, PLAN.md (the
BitCollections/BitArray row re-recorded at this checkpoint).

Checkpoint: 635a7f1e15806457e8c8c6d5d9f9a4fe29565131

Verification:
- The doc comment's examples now bind the inputs to `String` values first and
  pass those, which is the form that actually reaches this initializer, and a
  new paragraph states plainly that a literal at the call site resolves to
  `init(stringLiteral:)` and terminates the program on invalid content.
- Acceptance, satisfying the filed check by extracting the documented examples
  out of the source comment mechanically rather than retyping them: the program
  builds and runs to completion, and prints `nil` for both examples documented
  as `nil`. Exit 0. The three valid cases print their values.
- Contract preserved: documentation only. No signature, behaviour or accepted
  input changed, and `git diff` touches one file whose whole diff is comment
  lines. The runtime already behaved as the corrected documentation describes.
- Battery ownership: the diff touched
  `Sources/BitCollections/BitArray/BitArray+LosslessStringConvertible.swift`,
  which `.jeffy/probes/bitarray/paths` declares. That battery was re-run
  through the installed run-probe.sh: `bitarray: 1004/1004 checks passed`. Its
  row is re-recorded at this checkpoint below, because a row certifies the code
  as of the commit it names.
- Verify green: `verify: green (122s, ..., Executed 623 tests, with 0 failures)`.
- Closed this iteration: SC-5 (Medium, docs) - the documented examples now
  reach the initializer they document, and the literal behaviour is stated.

Learnings: a doc example written as a literal can document an overload it
cannot reach. When a type conforms to both a failable string initializer and
`ExpressibleByStringLiteral`, every example in the failable initializer's
documentation has to pass a `String` value, or it silently documents the other
one. Extracting examples from the comment and executing them is what catches
this; reading them does not.

Next: the run ends here, out of budget. No High or Medium remains open. Carried
Lows are SC-3, SC-4 and SC-6. The next run starts with a fresh audit against a
fully swept map.

## iter 11/12 | e6cbe980-022744 | 2026-09-01 | WRAPUP | blocked

Task: The closing extension opened for the convergence sequence. Establish
whether that sequence is legally available, and end the run.

Changed: JOURNAL.md.

Checkpoint: 44f8d8769c57eb50efa09fd438409d1ee9dc49d8

Verification:
- It is not available, and the reason is a precondition this run never met
  rather than anything left undone. The closing rule requires a full
  fresh-evidence audit from this run scoring zero High and zero Medium
  in-envelope. `grep -n '^## iter .* | AUDIT | ' JOURNAL.md` returns exactly
  one entry, iteration 1, and that audit's scores line records
  `documentation: Medium - SC-1` and `dependency hygiene: Medium - SC-2`. Both
  findings were closed later in the run, but the audit that found them is the
  audit on record, and it is not clean.
- The window cannot supply the missing one: it never admits an audit, and the
  hook ends the run out of budget the moment an AUDIT entry appears at an
  iteration inside it. So convergence falls to the next run's fresh audit, and
  the declaration is not deferred by choice.
- The evaluator gate was therefore not invoked. A PASS returned here could not
  be declared on, and a PASS that does not declare in its own iteration does
  not carry forward - it would have been ceremony with no verdict to spend.
- Everything else the closing rule asks for is in place, which is why the next
  run should reach a declaration quickly: the Surface inventory lists no
  unswept row (17 of 17 reachable swept, 13 `[~]` each naming its reason), the
  ledger holds no open High or Medium, Verify is green this iteration -
  `verify: green (121s, ..., Executed 623 tests, with 0 failures)` - and
  `check-claims.sh` reports `claims: 15 checked, 0 mismatched, 0 errored, 0
  skipped`.
- Carried Lows, none blocking: SC-3, README's public-API paragraph names
  version 1.5 while its own tables run through 1.6.x. SC-4, the
  change-propagation chain omits release/1.6. SC-6,
  `_UnsafeDequeSegments.count` and `isIdentical(to:)` have no caller anywhere
  in the module.
- No Proposed items await a decision.
- Ending the run here rather than spending iteration 12. The only legal moves
  left in the window are the gate and the declaration, and neither is
  available; a second ceremony entry would be a no-progress iteration by
  construction. Deleting .claude/jeffy-loop.local.md under the hard blocker
  rule, with the blocker named above.

Learnings: a run that closes its own audit's findings still cannot declare on
that audit. The clean-audit precondition is about the audit's scores, not about
the ledger's final state, so a run whose first audit files Mediums has already
spent its declaration unless it schedules a second full audit before the
closing window opens. On a 10-iteration budget with a large map, that second
audit has to be planned for from the start - by iteration 8 here the budget
was gone, and the sweep could not have been shortened without leaving the map
incomplete, which blocks the declaration just as hard.

Next: the next run opens with a fresh full audit against a fully swept map, a
ledger at the severity floor, and green claims - audit, gate, declare.

## iter 1/10 | 56af17cb-035551 | 2026-09-02 | SC-6 | done

Task: SC-6 (Low, runtime) - `_UnsafeDequeSegments.count` and
`_UnsafeDequeSegments.isIdentical(to:)` in
`Sources/DequeModule/_UnsafeDequeSegments.swift` had no caller anywhere in the
module, gated or not.

Changed: Sources/DequeModule/_UnsafeDequeSegments.swift (15 lines deleted),
BACKLOG.md (SC-6 deleted), PLAN.md (the _UnsafeDequeSegments row's SC-6
sentence, a Lessons line, and the three rows whose batteries were re-run),
JOURNAL.md, JOURNAL-archive.md (new, by rotation).

Checkpoint: e9fb656b930cba689b78e0f93875637b9653c996

Verification:
- Ran the filed reproduction first, and it does not hold as written.
  `grep -rnE 'segments\b[^(]*\.(count|isIdentical)' Sources/DequeModule/`
  returns six lines against the unfixed tree, and every one of them is
  `segments.first.count` - `.count` on the `UnsafeBufferPointer` stored in
  `first`, not on the descriptor. The check could not have returned nothing
  before or after the fix, so it was replaced with a discriminating one rather
  than worked around.
- The claim itself holds, and the enumeration behind it is a type-flow
  enumeration rather than a name scan. `grep -rn '_UnsafeDequeSegments'
  Sources Tests Benchmarks --include='*.swift'` returns six lines: the struct
  declaration, four functions that return one, and one initializer that takes
  one. The type is `internal` to DequeModule, so every value of it in existence
  comes from `Deque._UnsafeHandle.segments()`, `Deque._UnsafeHandle.segments(
  forOffsets:)`, `_UnsafeDequeHandle.segments()` or
  `_UnsafeDequeHandle.segments(forOffsets:)`, and reaches exactly six binding
  sites - Deque+Collection (two), RigidDeque+Hashable (two),
  RigidDeque+Iterable (two) - plus `_UnsafeMutableDequeSegments.init(
  mutating:)`. All seven were read: each touches `.first` and `.second` only.
- Four of those six binding sites are inside `#if compiler(>=6.2)` code this
  toolchain does not build, which is why the enumeration was needed: a
  successful build here clears the other two and says nothing about those.
- Fix: both members deleted. `swift build` exits 0.
- Acceptance, replacing the filed grep: the two members are absent from
  `_UnsafeDequeSegments` and the package builds. That check is strong enough to
  fail, shown rather than asserted - deleting `_UnsafeMutableDequeSegments.count`
  instead, which does have callers, makes the same build exit 1 with 21 errors,
  the first `value of type '_UnsafeMutableDequeSegments<Element>' has no member
  'count'`. That mutation was restored from a copy taken before it, by absolute
  path, before anything else ran.
- Contract preserved: both members were `internal` and `@usableFromInline` on
  an `internal` type, so no code outside DequeModule could name them. No public
  API, signature, or behaviour changed, and no documentation mentions either
  member (`grep -rn 'isIdentical' Documentation README.md` exits 1).
  `_UnsafeMutableDequeSegments.count` is untouched and keeps its callers.
- Battery ownership: the diff touches
  `Sources/DequeModule/_UnsafeDequeSegments.swift`, which
  `.jeffy/probes/deque-storage/paths` declares and `.jeffy/probes/deque/paths`
  matches through `Sources/DequeModule/*.swift`. Both were re-run through the
  installed run-probe.sh: `deque-storage: 3023/3023 checks passed` and
  `deque: 94/94 checks passed`, each equal to its claims line. The three rows
  those two batteries certify are re-recorded at this checkpoint in the
  bookkeeping edit.
- Verify green: `verify: green (131s, ..., Executed 623 tests, with 0 failures
  (0 unexpected) in 128.055 (128.055) seconds)`, and that total equals the
  `Verify count` of 623 in PLAN.md.
- Not a stall: this iteration changed a source file and removed a ledger item.
- Closed this iteration: SC-6 (Low, runtime) - two dead members deleted from
  `_UnsafeDequeSegments`.

Learnings: an acceptance check written as a grep for a member name matches that
name on any receiver. Here `segments.first.count` satisfied a pattern meant for
`segments.count`, so the filed check was unsatisfiable by construction. A
name-based check on a member has to pin the receiver, and where it cannot, the
discriminating check for a dead member is deletion plus a build - with a
control deletion of a member that does have callers to show the build notices.

Next: SC-3 and SC-4, both Low docs findings against README. The ledger empties
after them, and this run's first full audit follows with budget left for the
evaluator gate and a declaration.

## iter 1/10 | 56af17cb-035551 | 2026-09-02 | ROTATION | rotation

Task: JOURNAL.md stood at 720 lines after this iteration's primary entry, above
the 500-line rotation threshold.

Changed: JOURNAL.md, JOURNAL-archive.md (created).

Checkpoint: e9fb656b930cba689b78e0f93875637b9653c996

Verification: the two oldest entries - `iter 1/10 | e6cbe980-022744 | AUDIT`
and `iter 2/10 | e6cbe980-022744 | SWEEP` - were moved to the end of a newly
created JOURNAL-archive.md, splitting only on lines beginning `## iter`
followed by a digit, so the fenced heading-grammar example in the preamble was
neither counted nor moved. JOURNAL.md now holds 10 entries and the archive
holds 2; nothing was overwritten, since the archive did not previously exist.

Learnings: none.

Next: the checkpoint for this iteration.

## iter 2/10 | 56af17cb-035551 | 2026-09-02 | SC-3 | done

Task: SC-3 (Low, docs) - README's "Definition of Public API" paragraph pinned
the version promise to 1.5 while the same file's own tables run through 1.6.x.

Changed: README.md (one word in one paragraph), BACKLOG.md (SC-3 deleted, SC-7
filed), JOURNAL.md, JOURNAL-archive.md (rotation).

Checkpoint: 83dda20bfeb28c72833af0c6df94802f778ce34b

Verification:
- Ran the filed reproduction first. The paragraph read `The public API of
  version 1.5 of the swift-collections package`, while the highest row of the
  minimum-required-toolchain table is `swift-collections 1.6.x`. Two further
  signals in the same file agree on 1.6: the branching table's highest row is
  `swift-collections 1.6.x`, and the dependency snippet under "Using Swift
  Collections in your project" recommends `.upToNextMinor(from: "1.6.0")`.
- The filed acceptance is a comparison rather than a command, so it was made
  executable: extract the paragraph's version with
  `sed -n 's/^The public API of version \([0-9][0-9.]*\) of the .swift-collections. package.*/\1/p' README.md`,
  extract the table's highest with the same sed restricted to the
  `### Minimum Required Swift Toolchain Version` section and sorted numerically
  on both fields, and compare. It is strong enough to fail: against the unfixed
  README it prints `paragraph=1.5 table-highest=1.6` and exits 1. After the fix
  it prints `paragraph=1.6 table-highest=1.6` and exits 0.
- Contract preserved: documentation only, one word, and the direction is the
  one the rest of the file already documents. No code, signature or behaviour
  is touched; `git diff` is one line.
- No battery owns this path: every `paths` file under `.jeffy/probes/` declares
  only `Sources/...` globs, and none matches README.md.
- Verify green: `verify: green (121s, ..., Executed 623 tests, with 0 failures
  (0 unexpected) in 120.207 (120.207) seconds)`, equal to PLAN.md's Verify
  count of 623.
- Filed while re-checking the claims this diff sits next to, per the rule that
  a fix re-executes the prose claims of what it touches: the same paragraph
  enumerates the modules whose public declarations are public API, and that
  list omits `SpanPreview`. `swift package describe --type json` resolves the
  package's products to eleven names, of which `SpanPreview` is exported, is
  non-underscored, carries 34 `public` declarations, and appears nowhere in
  README.md - not in the module catalogue and not in this paragraph, while its
  sibling preview module `ContainersPreview` is in both. Filed as SC-7 at Low:
  the rubric's Medium case is a documented promise the code does not keep, and
  no promise here is broken - the paragraph states an inclusion list and says
  in the next line that anything outside it may change in any release, so a
  reader does get a defined answer for `SpanPreview`. What is missing is that
  the answer is never stated explicitly, which is minor docs. Its acceptance
  check was run against the current tree and prints `MISSING: SpanPreview`.
- Not a stall: README.md changed and two ledger items changed state.
- Closed this iteration: SC-3 (Low, docs) - the public-API paragraph now names
  1.6, matching the highest row of the file's own toolchain table.

Learnings: none beyond the existing Lessons.

Next: SC-4, the change-propagation chain that omits release/1.6. Then the
ledger holds SC-7 alone and this run's first full audit follows, leaving room
for the evaluator gate and a declaration.

## iter 2/10 | 56af17cb-035551 | 2026-09-02 | ROTATION | rotation

Task: JOURNAL.md stood at 649 lines after this iteration's primary entry, above
the 500-line rotation threshold.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: 83dda20bfeb28c72833af0c6df94802f778ce34b

Verification: the two oldest entries - `iter 3/10 | e6cbe980-022744 | SWEEP`
and `iter 4/10 | e6cbe980-022744 | SWEEP` - were appended to the end of the
existing JOURNAL-archive.md, which grew from 2 entries to 4 and was not
overwritten. Splitting used lines beginning `## iter` followed by a digit, so
the fenced heading-grammar example in the preamble was neither counted nor
moved. JOURNAL.md now holds 10 entries.

Learnings: none.

Next: the checkpoint for this iteration.

## iter 3/10 | 56af17cb-035551 | 2026-09-02 | SC-4 | done

Task: SC-4 (Low, docs) - README's change-propagation chain stopped at
`release/1.5`, omitting the `1.6.x` line that the branch table two paragraphs
above lists as open for bugfixes.

Changed: README.md (the chain line and the sentence that restates it),
BACKLOG.md (SC-4 deleted), JOURNAL.md.

Checkpoint: ee881c253f695914ccecec1d60cbdf914cbbf5e4

Verification:
- Ran the filed reproduction first, as an executable form of the filed
  acceptance rather than by eye: parse the Branching Strategy section, take
  every table row whose Status is not `Obsolete, closed`, resolve its branch
  name (the Branch cell where it names one, `release/<minor>` from the version
  cell where it reads `<created on demand>`, `main` for the `n.a.` row), and
  require each to appear in the propagation chain line. Against the unfixed
  README it reports `ok release/1.3`, `ok release/1.4`, `ok release/1.5`,
  `MISSING release/1.6`, `ok main`, and exits 1.
- Fix: the chain now reads
  `release/1.3` -> `release/1.4` -> `release/1.5` -> `release/1.6` -> `main`
  in the file's own arrow glyph. The example sentence immediately below it
  restates the same chain in prose and was updated in the same edit, because a
  fix that leaves the paragraph contradicting the line above it is not done.
- The check passes after the fix: all five rows `ok`, exit 0.
- Contract preserved: documentation only, two lines, no code touched. The
  branch table itself is unchanged - the chain was the stale half of the pair,
  since the table already carries the 1.6.x row and the dependency snippet
  elsewhere in the file already recommends 1.6.0.
- No battery owns this path: every `paths` file under `.jeffy/probes/` declares
  only `Sources/...` globs, and none matches README.md.
- Verify green: `verify: green (122s, ..., Executed 623 tests, with 0 failures
  (0 unexpected) in 121.536 (121.536) seconds)`, equal to PLAN.md's Verify
  count of 623.
- Not a stall: README.md changed and a ledger item was removed.
- Closed this iteration: SC-4 (Low, docs) - the propagation chain now names
  every branch its own table lists as open.

Learnings: none beyond the existing Lessons.

Next: SC-7, the undocumented `SpanPreview` product. The ledger empties after
it, and this run's full audit follows with room for the evaluator gate and a
declaration.

## iter 3/10 | 56af17cb-035551 | 2026-09-02 | ROTATION | rotation

Task: JOURNAL.md stood at 592 lines after this iteration's primary entry, above
the 500-line rotation threshold.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: ee881c253f695914ccecec1d60cbdf914cbbf5e4

Verification: the two oldest entries - `iter 5/10 | e6cbe980-022744 | SWEEP`
and `iter 6/10 | e6cbe980-022744 | SWEEP` - were appended to the end of
JOURNAL-archive.md, which grew from 4 entries to 6 and was not overwritten.
Splitting used lines beginning `## iter` followed by a digit, so the fenced
heading-grammar example in the preamble was neither counted nor moved.
JOURNAL.md now holds 10 entries.

Learnings: none.

Next: the checkpoint for this iteration.

## iter 4/10 | 56af17cb-035551 | 2026-09-02 | SC-7 | done

Task: SC-7 (Low, docs) - `SpanPreview` is an exported library product of both
manifests and README never named it.

Changed: README.md (the `UnstableContainersPreview` trait section: its list
preamble, the `InputSpan` bullet, and two link definitions), BACKLOG.md (SC-7
deleted, SC-8 filed), JOURNAL.md.

Checkpoint: bed5e3a25be40e913262c40f6c51573d3440663f

Verification:
- Ran the filed acceptance first, as filed: every non-underscored name from
  `swift package describe --type json | jq -r '.products[].name'` must appear
  in README.md. Against the unfixed tree it printed `MISSING: SpanPreview`.
- Fixed the root cause rather than the symptom. The reason README never names
  the module is that the trait section still describes `InputSpan` as living in
  `ContainersPreview`, which it left: `grep -rn 'public struct InputSpan'
  Sources` returns `Sources/SpanPreview/InputSpan.swift` and nothing else, and
  `git log --diff-filter=D` shows `Sources/ContainersPreview/Types/InputSpan.swift`
  deleted by "Invert dependencies to ContainersPreview, moving all container
  APIs there". Nothing re-exports it - `grep -rn '@_exported' Sources
  --include='*.swift'` exits 1 - so `import ContainersPreview` does not vend
  `InputSpan`; `import SpanPreview` does. The section's preamble now says the
  listed types are in `ContainersPreview` except `InputSpan`, the bullet states
  which module vends it and that reaching it needs `import SpanPreview`, its
  link points at the file that exists, and a `[SpanPreview]` link was added.
- Acceptance passes after the fix: the product loop prints no MISSING line.
- Contract preserved: documentation only, three edits in one section, no code
  touched. No claim about API stability was added or removed - `SpanPreview` is
  named where the trait that gates it is documented, not added to the
  "Definition of Public API" module list, because whether upstream intends that
  module to carry the version promise is not something this tree states.
- No battery owns this path: every `paths` file under `.jeffy/probes/` declares
  only `Sources/...` globs, and none matches README.md.
- Verify green: `verify: green (121s, ..., Executed 623 tests, with 0 failures
  (0 unexpected) in 119.641 (119.641) seconds)`, equal to PLAN.md's Verify
  count of 623.
- Filed while enumerating the section rather than fixing only the entry that
  raised the question: checking every link definition of the form
  `[Name]: https://github.com/apple/swift-collections/blob/main/<path>` against
  the tree showed 7 of 14 naming paths that do not exist. Two are now fixed.
  The remaining six are SC-8, filed Medium with its Consequence, and the
  evidence is stronger than dead links alone: `Ref`, `MutableRef` and
  `BorrowingIteratorProtocol` are declared nowhere in `Sources` (the tree
  carries 12 `extension BorrowingIteratorProtocol` blocks and no declaration,
  and "Switch to using stdlib Ref and UniqueBox" deleted the package's own
  `Ref`), so the trait section credits this package with types the standard
  library provides; `BorrowingSequence` has zero declarations and zero
  extensions anywhere in `Sources` since its rename to `Iterable`, and
  `Iterable` is not listed; `Producer` and `Drain` link to their pre-refactor
  paths. SC-8 is deliberately scoped to that enumeration rather than to a full
  rewrite of the list, because deciding which of the 12 public protocols and 13
  public structs the two preview modules now declare belong in a README bullet
  list is an editorial judgement, not a mechanical one, and would not fit one
  iteration honestly.
- Not a stall: README.md changed and two ledger items changed state.
- Closed this iteration: SC-7 (Low, docs) - `SpanPreview` is now named in
  README, at the place that had been attributing its contents elsewhere.

Learnings: a README link written as a repository path is a claim that goes
stale silently, and checking one of them is not checking the set. Enumerating
every `blob/main/<path>` link against the tree took one command and turned a
single-entry docs fix into an accurate count of what else had rotted.

Next: SC-8, the Medium. Then the full audit, with room after it for the
evaluator gate and a declaration.

## iter 4/10 | 56af17cb-035551 | 2026-09-02 | ROTATION | rotation

Task: JOURNAL.md stood at 570 lines after this iteration's primary entry, above
the 500-line rotation threshold.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: bed5e3a25be40e913262c40f6c51573d3440663f

Verification: the two oldest entries - `iter 7/10 | e6cbe980-022744 | SWEEP`
and `iter 8/10 | e6cbe980-022744 | SC-1` - were appended to the end of
JOURNAL-archive.md, which grew from 6 entries to 8 and was not overwritten.
Splitting used lines beginning `## iter` followed by a digit. JOURNAL.md now
holds 10 entries.

Learnings: none.

Next: the checkpoint for this iteration.

## iter 5/10 | 56af17cb-035551 | 2026-09-02 | SC-8 | done

Task: SC-8 (Medium, docs) - README's `UnstableContainersPreview` section listed
four types this package does not declare and pointed six of its source links at
paths absent from the tree.

Changed: README.md (four bullets and four link definitions removed, three link
paths corrected), BACKLOG.md (SC-8 deleted), JOURNAL.md.

Checkpoint: 51befbd3fcc4de8432a8e5f57307d88568e84003

Verification:
- Ran the filed reproduction first. Six link definitions named paths that do
  not exist: `Ref`, `MutableRef`, `BorrowingSequence`,
  `BorrowingIteratorProtocol`, `Producer`, `Drain`.
- The filed acceptance had a defect and was corrected rather than satisfied.
  It required `grep -rw BorrowingSequence Sources README.md` to return nothing,
  which cannot pass: the name survives in four source comments - a FIXME in
  `Container.swift`, a FIXME in `UniqueDeque+Prepend.swift` and two doc-comment
  lines in `Iterable+Equality.swift` - and editing unrelated source comments is
  outside this task. The clause was narrowed to README.md, which is the file
  the finding is about.
- The check was also strengthened past what was filed, because a link can name
  a path that exists and still be wrong: it now requires each `blob/main`
  target to exist and, when it is a `.swift` file, to declare the type the link
  is named for. That caught an eighth defect the filed check would have passed
  - `[BidirectionalContainer]` pointed at `Container.swift`, which does not
  declare it - and it is fixed here too.
- Discriminating evidence, run against the committed pre-fix README extracted
  with `git show HEAD:README.md` rather than by reverting the working tree: the
  check reports 8 defects and exits 1 there, and exits 0 against the fixed
  file with all eleven links `ok`.
- Fix: the `Ref`, `MutableRef`, `BorrowingSequence` and
  `BorrowingIteratorProtocol` bullets and their link definitions were removed,
  and `Producer`, `Drain` and `BidirectionalContainer` were repointed at the
  files that declare them. Removal rather than repair is what the evidence
  supports: `grep -rn 'struct Ref\b|struct MutableRef\b|protocol
  BorrowingIteratorProtocol\b|protocol BorrowingSequence\b' Sources` finds no
  declaration of any of them, only two doc-comment mentions of `struct Ref`,
  while the tree carries 12 `extension BorrowingIteratorProtocol` blocks and 6
  `extension Iterable` blocks - so those names are supplied by the toolchain,
  not by this package, and a section headed "this trait enables the following
  types" was crediting the package with them. `BorrowingSequence` is the one
  that resolves nowhere at all, renamed to `Iterable` by "Renaming
  BorrowingSequence_ to Iterable_".
- Deliberately not done here, and not a silent omission: the section still
  does not list `UniqueBox`, `Shared`, `DrainableContainer`, `CountedProducer`
  or `RangeExpression2`, all declared and public in `ContainersPreview`.
  Choosing which of them belong in a README bullet list is editorial, and
  inventing that list is not something this run can verify. Recorded for the
  next run rather than guessed at.
- Contract preserved: documentation only. No code, no manifest, no public
  declaration was touched, and nothing was added that this tree does not state
  - the removals delete claims that were false, and the three repointed links
  now resolve to the declaring file.
- No battery owns this path: every `paths` file under `.jeffy/probes/` declares
  only `Sources/...` globs, and none matches README.md.
- Verify green: `verify: green (122s, ..., Executed 623 tests, with 0 failures
  (0 unexpected) in 120.478 (120.478) seconds)`, equal to PLAN.md's Verify
  count of 623.
- Not a stall: README.md changed and a ledger item was removed.
- Closed this iteration: SC-8 (Medium, docs) - every source link in README now
  resolves to a file that declares the type it names, and no listed type is
  one the package does not declare.

Learnings: a link check that only asks whether the path exists passes a link
that points at the wrong file in the right directory. Requiring the target to
declare the symbol the link is named for is the same command with one more
condition, and it found a defect the weaker form did not.

Next: the ledger is empty. This run's full audit comes next, with room after it
for the evaluator gate and a declaration.

## iter 5/10 | 56af17cb-035551 | 2026-09-02 | ROTATION | rotation

Task: JOURNAL.md stood at 574 lines after this iteration's primary entry, above
the 500-line rotation threshold.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: 51befbd3fcc4de8432a8e5f57307d88568e84003

Verification: the two oldest entries - `iter 9/10 | e6cbe980-022744 | SC-2` and
`iter 10/10 | e6cbe980-022744 | SC-5` - were appended to the end of
JOURNAL-archive.md, which grew from 8 entries to 10 and was not overwritten.
Splitting used lines beginning `## iter` followed by a digit. JOURNAL.md now
holds 10 entries, all of them from this run except the previous run's WRAPUP.

Learnings: none.

Next: the checkpoint for this iteration.

## iter 6/10 | 56af17cb-035551 | 2026-09-02 | AUDIT | audit

Task: the ledger emptied, so this is this run's full fresh-evidence audit,
rescoring every applicable dimension against the rubric and the Operating
envelope.

Changed: BACKLOG.md (SC-9 filed), JOURNAL.md.

Checkpoint: 193eff6719dd0ff4ff0f5ec54d663ae5e4dadb90

Verification:

Scope of these scores. They claim the 17 swept Surface inventory rows and
nothing else. All 17 are current, not merely marked swept: each row's recorded
commit was re-checked against HEAD through its battery's own `paths` file, and
`git diff --name-only <commit> HEAD -- <globs>` is empty for every one, so no
row is stale. There are no unswept rows. The 13 `- [~]` rows are surface this
host cannot reach - Swift 6.1.2 replaces it with `@available(*, unavailable)`
placeholders under `#if compiler(<6.2)`, or the tools-6.0 manifest omits the
target - and each carries its reason in PLAN.md. Nothing here scores them.

Evidence gathered this iteration:
- Batteries: `check-claims.sh` reports `claims: 15 checked, 0 mismatched, 0
  errored, 0 skipped`, exit 0 - all 14 probe batteries re-executed at their
  recorded counts plus the PLAN.md Stated counts row.
- Verify: `verify: green (119s, ..., Executed 623 tests, with 0 failures (0
  unexpected) in 118.115 (118.115) seconds)`, equal to PLAN.md's Verify count.
- Testing in isolation, which the Method requires before scoring testing clean:
  `swift test --filter HeapTests` exits 0 with `Executed 32 tests, with 0
  failures`, and `swift test --filter BitCollectionsTests` exits 0 with
  `Executed 113 tests, with 0 failures`. No order dependence and no leaked
  state surfaced in either.
- Environment fingerprint re-read and its enumeration re-run: the guard census
  over `Tests` still returns the same shapes PLAN.md records, and the Stated
  counts row still `returns 4`.
- Declined and Settled classes: both sections are empty, so there is no
  standing Derivation or class enumeration to re-run.

Dimension scores:
- correctness: None. 623 tests and 14 known-answer batteries green over the
  swept rows, every battery compared against an independent oracle.
- security: None. The Operating envelope's surface enumeration still holds -
  `grep -rn 'ProcessInfo|getenv|FileManager|URLSession' Sources` returns
  nothing, so there is no network, CLI, environment, config or state-at-rest
  surface. The one adversarial surface is Codable, and it was re-examined this
  iteration rather than assumed: of the ten files carrying a conformance, four
  throw no `DecodingError`, and each was read to see whether that is a gap.
  It is not. `Deque` accepts any sequence of elements, so no payload is
  malformed. `BitSet` decodes words and routes through
  `BitSet.init(_words:)`, which calls `_shrink()`, so a payload padded with
  trailing empty words cannot produce the "Extraneous tail slot" state its own
  `_checkInvariants` forbids. `BitSet.Counted` decodes a `BitSet` and
  reconstructs its count from it rather than trusting an encoded count, so the
  count cannot be desynchronized from the contents by a hostile payload. The
  remaining six throw on duplicate keys, mismatched pair counts and corrupted
  strings.
- error handling: None. Out-of-range indices, capacity overflow and unmet
  ordering requirements are documented trapping preconditions of the shipped
  API, which the envelope classifies user-error; the decoders throw rather
  than trap.
- documentation: Low - SC-9. Every `blob/main` link in README now resolves to
  a file that declares the symbol it is named for (11 of 11 ok, exit 0), and
  the four documentation findings this run closed are re-checked green. What
  remains is an omission rather than a falsehood: the trait section does not
  list `UniqueBox`, `Shared`, `DrainableContainer`, `CountedProducer` or
  `RangeExpression2`, all `public` in `ContainersPreview`.
- dependency hygiene: None. The package declares no external dependency at all
  - `grep -n '\.package(' Package.swift Package@swift-6.0.swift` returns
  nothing - so there is no third-party code to carry a known vulnerability.
- architecture: None. No finding on the swept rows.
- code quality: None on the swept rows. The one finding of this class this run,
  SC-6, was closed at iteration 1.
- performance: None, and the evidence is bounded: the batteries drive 400
  scattered inserts followed by 400 scattered removals with a full oracle
  comparison after every step, and sorted collections at sizes to 1000, all
  inside the probe wall-clock ceiling. No timing measurement was taken, so this
  score means no performance finding was reached by that work, not that the
  library was profiled.
- testing: None. Scored under the class ceiling, which puts any test finding at
  Low regardless.
- developer experience: None on the swept rows.
- observability: not applicable. A collection library exposes no logging,
  metric or tracing surface. The only `print` calls in `Sources` are inside
  `dump()`, `_dump()` and `_describe()` debugging helpers, and a grep for
  callers of those helpers outside the Debugging and Builder files that define
  them returns nothing, so nothing prints on an ordinary path.
- UX and accessibility: not applicable. No user-facing surface exists.

Zero High and zero Medium in-envelope. Closeout has begun: no further audit and
no replenishment for the rest of this run, which now works or declines what is
on the ledger and then converges.

Filed this iteration: SC-9 (Low, docs) - five public `ContainersPreview` types
absent from the section that enumerates what their trait enables.

Not a stall: a ledger item was added.

Learnings: none.

Next: the evaluator gate. The closing conditions are otherwise in place - no
unswept row, no open High or Medium, verify green, claims green - so the gate
and the declaration can share iteration 7, carrying SC-9 as the one open Low.

## iter 6/10 | 56af17cb-035551 | 2026-09-02 | ROTATION | rotation

Task: JOURNAL.md stood at 594 lines after this iteration's AUDIT entry, above
the 500-line rotation threshold.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: 193eff6719dd0ff4ff0f5ec54d663ae5e4dadb90

Verification: the two oldest entries - the previous run's `iter 11/12 | WRAPUP`
and this run's `iter 1/10 | SC-6` - were appended to the end of
JOURNAL-archive.md, which grew from 10 entries to 12 and was not overwritten.
Splitting used lines beginning `## iter` followed by a digit. JOURNAL.md now
holds 10 entries, all from this run.

Learnings: none.

Next: the checkpoint for this iteration.

## iter 7/10 | 56af17cb-035551 | 2026-09-02 | EVALUATOR | converged

Task: the convergence sequence - bring the standing claims current, run the
adversarial evaluator gate, and declare if it passes and the closing conditions
hold.

Changed: .jeffy/evaluator/56af17cb-035551-1.md (new, the gate's artifact),
BACKLOG.md (Converged line), JOURNAL.md.

Checkpoint: be64bd66f55f056edd3394aa47dc3b3d1f7417b3

Verification:

Standing claims brought current before the invocation, so no invocation would
be spent on a claim this run had already outdated:
- Every swept Surface inventory row re-checked against HEAD through its own
  battery's `paths` file: no row is stale. This run's only source change was
  iteration 1's, and the three rows its batteries certify were re-recorded at
  that checkpoint; iterations 2 to 5 touched README.md alone, which no battery
  declares.
- `check-claims.sh` re-run this iteration: `claims: 15 checked, 0 mismatched, 0
  errored, 0 skipped`, exit 0.
- Declined and Settled classes are both empty, so there is no recorded
  Derivation and no class enumeration to re-run.
- Finding IDs in PLAN.md: `grep -o 'SC-[0-9]*' PLAN.md` returns SC-6 once, in
  the `_UnsafeDequeSegments` row, naming a completed deletion rather than a
  carried or blocked finding. Nothing dangles; the evaluator checked this
  independently and agreed.
- Oracle class and Environment fingerprint re-read. The Verify count cell reads
  623 and equals the total the wrapper's green line reports.
- Verify green this iteration: `verify: green (124s, ..., Executed 623 tests,
  with 0 failures (0 unexpected) in 123.701 (123.701) seconds)`.

Evaluator: PASS - invocation 1 of this run, at iteration 7 of 10; it reproduced
SC-8 against the base commit (9 defects, exit 1) and confirmed it clean at HEAD
(11 links, 0 defects, exit 0), judged the run's narrowing of that acceptance
legitimate and its strengthening real, found each of the four Lows failing at
base and passing at HEAD, found no regression in the diffs, and confirmed
verify and claims green. Artifact at `.jeffy/evaluator/56af17cb-035551-1.md`,
committed by this iteration's checkpoint.

Closing conditions, each checked rather than assumed:
- A full fresh-evidence audit this run scored zero High and zero Medium
  in-envelope: iteration 6, in this journal.
- The Surface inventory lists no unswept row: 17 swept, 0 unswept, 13 `- [~]`
  unreachable on this host, each carrying its reason.
- No open High and no open Medium in Now, Next or Later.
- The only commits since the clean audit are that audit's own checkpoint and
  this convergence iteration's.
- Verify green this iteration, and the evaluator returned PASS.

Carried Low, listed by ID as the closing rule requires:
- SC-9 (Low, docs): README's `UnstableContainersPreview` section enumerates
  what the trait enables and omits public types of `ContainersPreview` that
  belong in that enumeration.

Gate observations, recorded and deliberately not fixed here, because a fix
after a PASS invalidates the PASS and spends an invocation the declaration
needs. They go to the next run as its opening work:
- SC-9's ledger line overstates its own evidence on two of the five types it
  names. `UniqueBox` is behind no `UnstableContainersPreview` guard and README
  already documents it as the module's one stable entry point, and `Shared` is
  inside a `#if false` block - the exact shape this project's first Lesson
  warns about. Three of the five qualify, and the real omission is larger than
  the line says: the section lists 9 of the 25 public types. The acceptance
  check enumerates all 25, so the task itself is sound and its check still
  discriminates; the prose around it is what needs correcting.
- README's `[SpanPreview]` definition uses a `blob/main/` URL for a directory
  where the file's convention for directories is `tree/main/`. It resolves by
  redirect.
- Removing the `Ref` and `MutableRef` bullets left a pre-existing blank line
  separating a now single-item list.
- JOURNAL.md carries 11 entries against a retention rule of 10, because each
  ROTATION entry is appended after its own count is taken. The evaluator
  confirmed rotation lost nothing: all base entries are present across
  JOURNAL.md and JOURNAL-archive.md.

Not a stall: the ledger and the evaluator artifact both changed, and this is
the convergence sequence in any case.

Learnings: none beyond the existing Lessons.

Next: the run is converged. The next run opens with a fresh audit, the gate's
four observations as its first work, and SC-9 carried.

## iter 7/10 | 56af17cb-035551 | 2026-09-02 | ROTATION | rotation

Task: JOURNAL.md reached 568 lines once the declaring entry was complete, above
the 500-line rotation threshold.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: be64bd66f55f056edd3394aa47dc3b3d1f7417b3 (the rotation rode this
iteration's bookkeeping edit; this entry records it).

Verification: the two oldest entries - `iter 1/10 | ROTATION` and `iter 2/10 |
SC-3` - were appended to the end of JOURNAL-archive.md, which grew from 12
entries to 14 and was not overwritten. Splitting used lines beginning `## iter`
followed by a digit. JOURNAL.md now holds 10 entries.

Learnings: none.

Next: nothing. The run is converged; this entry only records the rotation the
declaring iteration performed.

## iter 1/10 | e2a93ea4-044525 | 2026-09-02 | SC-9 | done

Task: SC-9 (Low, docs) - README's `UnstableContainersPreview` section enumerates
what the trait enables while omitting public types of `ContainersPreview`.

Changed: README.md (three protocol bullets and their three link definitions
added), BACKLOG.md (SC-9 deleted, SC-10 and SC-11 filed), JOURNAL.md.

Checkpoint: 371b61b78d2869fd8167fc69bb75e830c41c4cfe

Verification:

- Ran the filed reproduction first, and it did not hold as written. The ledger
  line named five omitted types; two of them are not omissions. `UniqueBox` is
  declared outside every `UnstableContainersPreview` guard - both the
  `#if compiler(<6.2)` placeholder and the `#else` real definition in
  `Sources/ContainersPreview/Types/UniqueBox.swift` sit outside it, and only
  its extensions are trait-gated - so the trait does not enable the type, and
  README already documents it in the `ContainersPreview` module section as that
  module's one stable entry point. `Shared` is inside a `#if false // TODO`
  block. The prior run's evaluator recorded both, and re-deriving them here
  confirmed them.
- The real extent is larger than the line said and was measured rather than
  estimated: `Sources/ContainersPreview` declares 25 `public struct` or
  `public protocol` types, of which the section listed 9.
- Fix: the three genuine omissions are protocol peers of the nine already
  listed - `DrainableContainer`, `CountedProducer` and `RangeExpression2`, each
  inside `#if compiler(>=6.4) && UnstableContainersPreview` - and each is now a
  bullet in the list with a link definition pointing at the file that declares
  it. Descriptions were written from the declarations, not from the names:
  `DrainableContainer` refines `Container` with `consume(_ subrange:)` and
  builds `remove(at:)`, `removeSubrange`, `removeAll` and `removeFirst` on it;
  `CountedProducer` refines `Producer` with an exact `count`; `RangeExpression2`
  refines `RangeExpression` with `relative(to:)` over a `Container`.
- The other 13 are absent deliberately, each with its reason:
  - `UniqueBox` - not trait-gated, and already documented as the
    `ContainersPreview` module's stable entry point.
  - `Shared` - inside `#if false // TODO`, so the trait does not enable it.
  - `SubrangeConsumer` - inside `#if false // FIXME`, and additionally behind
    `UnstableHashedContainers`; it is also nested inside a `UniqueSet`
    conformance rather than being a module-level type.
  - `BorrowingIterator` - nested in `extension Range: @retroactive Iterable`,
    so it is `Range.BorrowingIterator`, a conformance witness rather than a
    type the module vends.
  - `BorrowingFilter`, `BorrowingMapProducer`, `ConsumingFilterProducer`,
    `ConsumingMapProducer`, `ContainerFilter`, `ContainerIterator`,
    `DrainMapProducer`, `ErrorMappedIterator`, `UnfoldProducer` - the concrete
    return types of the map/filter/unfold operations the listed protocols vend,
    which the section's own closing paragraph already covers as "a large list
    of new APIs ... implementations of the classic `map`/`reduce`/`filter`/etc
    algorithms".
- Acceptance check, made runnable and run in both directions. It enumerates the
  25 public types, treats a type as listed when the section carries its `][Name]`
  link reference, and treats the 13 above as documented exclusions:

      readme="${1:-README.md}"
      excluded="BorrowingFilter BorrowingIterator BorrowingMapProducer \
      ConsumingFilterProducer ConsumingMapProducer ContainerFilter \
      ContainerIterator DrainMapProducer ErrorMappedIterator Shared \
      SubrangeConsumer UnfoldProducer UniqueBox"
      section=$(awk '/^### `UnstableContainersPreview` package trait$/{t=1;next} \
        t && /^The trait also enables/{t=0} t' "$readme")
      types=$(grep -rhoE '^[[:space:]]*public (struct|protocol) [A-Za-z0-9_]+' \
        Sources/ContainersPreview --include='*.swift' \
        | sed -E 's/.*public (struct|protocol) //' | sort -u)
      undoc=0; listed=0
      for t in $types; do
        if printf '%s\n' "$section" | grep -qF "][$t]"; then listed=$((listed+1)); continue; fi
        case " $excluded " in *" $t "*) ;; *) echo "UNDOCUMENTED OMISSION: $t"; undoc=$((undoc+1));; esac
      done
      echo "types: $(printf '%s\n' "$types" | wc -l) public, $listed listed, $undoc undocumented"
      [ "$undoc" -eq 0 ]

  Against the committed pre-fix README, extracted with `git show HEAD:README.md`
  rather than by reverting the working tree, it names `CountedProducer`,
  `DrainableContainer` and `RangeExpression2` and exits 1. Against the fixed
  file it reports `25 public, 12 listed, 0 undocumented` and exits 0.
- Link discipline re-run over the whole set rather than the three added, per the
  standing Lesson: every `blob/main/<path>` definition must exist and, when it
  is a `.swift` file, must declare the symbol the link is named for. 14 links
  checked, 0 defective, exit 0 - the three new definitions included.
- No battery owns this path: every `paths` file under `.jeffy/probes/` declares
  only `Sources/...` globs and none matches README.md.
- `check-claims.sh`: `claims: 15 checked, 0 mismatched, 0 errored, 0 skipped`,
  exit 0.
- Verify green: `verify: green (120s, ..., Executed 623 tests, with 0 failures
  (0 unexpected) in 118.852 (118.852) seconds)`, equal to PLAN.md's Verify
  count of 623.
- Surface inventory re-checked against HEAD through each battery's own `paths`
  file: no row is stale, 17 swept, 0 unswept, 13 `- [~]`.
- No ratchet this iteration. The latest Converged line names
  be64bd66f55f056edd3394aa47dc3b3d1f7417b3, only the state files have changed
  since it, and it is reachable from HEAD - but the ledger carried an open task,
  and a run whose ledger holds work does that work rather than re-declaring over
  it.
- Not a stall: README.md changed and three ledger items changed state.
- Closed this iteration: SC-9 (Low, docs).
- Filed this iteration, both carried from the previous run's evaluator
  observations rather than found here: SC-10 (Low, docs) - `[SpanPreview]`
  points a `blob/main/` URL at a directory; SC-11 (Low, docs) - a blank line
  makes the trait section's bullet list render loose.

Learnings: a ledger line's own list of instances is a hypothesis, not evidence.
Two of the five types this line named were not omissions at all, and the count
it implied was less than a quarter of the real one; deriving the set from the
code before touching the fix is what turned a five-name guess into 25 public
types, 9 listed, 3 genuinely missing.

Next: SC-10, then SC-11. Both are Low and both touch README.md alone, so the
run has room for its full audit afterwards.


## iter 1/10 | e2a93ea4-044525 | 2026-09-02 | ROTATION | rotation

Task: JOURNAL.md stood at 621 lines once this iteration's primary entry was
complete, above the 500-line rotation threshold.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: 371b61b78d2869fd8167fc69bb75e830c41c4cfe (the rotation rode this iteration's checkpoint;
this entry records it).

Verification: the two oldest entries - `iter 2/10 | ROTATION` and `iter 3/10 |
SC-4` - were appended to the end of JOURNAL-archive.md, which grew from 14
entries to 16 and was not overwritten. Splitting used lines beginning `## iter`
followed by a digit. JOURNAL.md now holds 10 entries.

Learnings: none.

Next: the checkpoint for this iteration.

## iter 2/10 | e2a93ea4-044525 | 2026-09-02 | SC-10 | done

Task: SC-10 (Low, docs) - README's `[SpanPreview]` definition points a
`blob/main/` URL at a directory, where the file's own convention for a
directory target is `tree/main/`.

Changed: README.md (one link definition, `blob` to `tree`), BACKLOG.md (SC-10
deleted), JOURNAL.md.

Checkpoint: 81cc2626ea168798c26e96dd466839281573721b

Verification:

- Ran the filed reproduction first, over the whole set rather than the one link
  the finding names, per the standing Lesson. README carries 21 repository link
  definitions: 14 `blob/main/` and 7 `tree/main/`. All 7 `tree` links point at
  directories, and 13 of the 14 `blob` links point at files. The single
  mismatch is `[SpanPreview]` at `Sources/SpanPreview`, a directory. So the
  convention the finding cites is not asserted from style but measured: 7 of 7
  directory targets use `tree/main/`, and this was the eighth.
- Acceptance check, run in both directions. It reads every
  `[Name]: https://github.com/apple/swift-collections/(blob|tree)/main/<path>`
  definition and requires each target to exist and to match its URL kind - a
  `blob` target must be a file, a `tree` target a directory:

      readme="${1:-README.md}"
      total=0; defects=0
      while IFS=' ' read -r kind name path; do
        total=$((total + 1))
        if [ ! -e "$path" ]; then echo "MISSING: [$name] -> $path"; defects=$((defects+1)); continue; fi
        if [ "$kind" = blob ] && [ ! -f "$path" ]; then
          echo "BLOB ON DIRECTORY: [$name] -> $path (should be tree/main/)"; defects=$((defects+1)); continue
        fi
        if [ "$kind" = tree ] && [ ! -d "$path" ]; then
          echo "TREE ON FILE: [$name] -> $path (should be blob/main/)"; defects=$((defects+1)); continue
        fi
      done < <(sed -nE 's#^\[([^]]+)\]: https://github\.com/apple/swift-collections/(blob|tree)/main/(.+)$#\2 \1 \3#p' "$readme")
      echo "repo links: $total checked, $defects mismatched to their target kind"
      [ "$defects" -eq 0 ]

  Against the committed pre-fix README, extracted with `git show HEAD:README.md`
  rather than by reverting the working tree, it reports
  `21 checked, 1 mismatched` naming `[SpanPreview]` and exits 1. Against the
  fixed file it reports `21 checked, 0 mismatched` and exits 0.
- This check is strictly wider than the one iteration 1 used, and both are kept
  because neither contains the other: this one covers all 21 definitions and
  grades URL kind against target kind but says nothing about symbols; the
  iteration 1 check covers only `blob/main/` definitions and requires each
  `.swift` target to declare the symbol its link is named for. Re-run here, the
  symbol check reports `13 checked, 0 defective`, exit 0 - 13 rather than 14
  because `[SpanPreview]` is no longer a `blob` link, which is the fix.
- SC-9's acceptance re-run to confirm this edit did not disturb it:
  `25 public, 12 listed in section, 0 undocumented omissions`, exit 0.
- No battery owns this path: every `paths` file under `.jeffy/probes/` declares
  only `Sources/...` globs and none matches README.md.
- `check-claims.sh`: `claims: 15 checked, 0 mismatched, 0 errored, 0 skipped`,
  exit 0.
- Verify green: `verify: green (120s, ..., Executed 623 tests, with 0 failures
  (0 unexpected) in 119.437 (119.437) seconds)`, equal to PLAN.md's Verify
  count of 623.
- Not a stall: README.md changed and a ledger item changed state.
- Closed this iteration: SC-10 (Low, docs).

Learnings: none.

Next: SC-11, the last open Low. Then the closing full audit, the evaluator gate
and the declaration, which the remaining budget covers comfortably.

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

## iter 2/10 | e2a93ea4-044525 | 2026-09-02 | ROTATION | rotation

Task: JOURNAL.md stood at 643 lines once this iteration's primary entry was
complete, above the 500-line rotation threshold.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: 81cc2626ea168798c26e96dd466839281573721b (the rotation rode this
iteration's bookkeeping edit; this entry records it).

Verification: the two oldest entries - `iter 3/10 | ROTATION` and `iter 4/10 |
SC-7` - were appended to the end of JOURNAL-archive.md, which grew from 16
entries to 18 and was not overwritten. Splitting used lines beginning `## iter`
followed by a digit. JOURNAL.md now holds 10 entries.

Learnings: none.

Next: SC-11.

## iter 3/10 | e2a93ea4-044525 | 2026-09-02 | SC-11 | done

Task: SC-11 (Low, docs) - a blank line inside the `UnstableContainersPreview`
section's bullet list makes markdown render that list loose, wrapping every
item in its own paragraph.

Changed: README.md (one blank line removed), BACKLOG.md (SC-11 deleted),
JOURNAL.md.

Checkpoint: 0ab2af6c390094ba9abd863094552786a8c9ec50

Verification:

- Ran the filed reproduction first: one blank line, at item offset 2, between
  the `InputSpan` bullet and the `Container` bullet.
- Checked the blank line's provenance rather than assuming it was this loop's
  leftover, because removing an upstream author's deliberate formatting is a
  different act from tidying our own debris. The last non-jeffy commit touching
  README.md is 9d0f2adb "Update README", and the blank line is present there,
  separating a three-item struct group (`InputSpan`, `Ref`, `MutableRef`) from
  the protocol group. It is upstream's group separator, not debris. What
  changed is that the previous run's SC-8 removed `Ref` and `MutableRef` as
  types this package does not declare, leaving the separator dividing a
  one-item group from the rest.
- Removal is what the file's own convention supports, and the convention was
  measured rather than asserted: a pass over README.md that walks every
  maximal run of `- ` lines, tolerating single blank lines inside a run,
  reports 13 bullet lists of which exactly 1 contained a blank line - this one.
  The distinction the separator marked is also now carried by the section's own
  intro sentence, "all in the `ContainersPreview` module except `InputSpan`",
  so nothing is lost by closing the gap.
- Acceptance check, run in both directions:

      readme="${1:-README.md}"
      awk '/^### `UnstableContainersPreview` package trait$/{t=1;next} \
           t && /^The trait also enables/{t=0} t' "$readme" \
      | awk 'BEGIN{first=0}
             /^- \[/{ if(!first) first=NR; last=NR }
             { L[NR]=$0 }
             END{ n=0; for(i=first;i<=last;i++) if(L[i]=="") { n++; print "BLANK inside list at item offset " i-first+1 }
                  print "blank lines inside list: " n; exit (n==0 ? 0 : 1) }'

  Against the committed pre-fix README, extracted with `git show HEAD:README.md`
  rather than by reverting the working tree, it reports the blank at offset 2
  and exits 1. Against the fixed file it reports 0 and exits 0. The
  whole-file measurement now reports 13 bullet lists, 0 containing a blank
  line.
- Sibling checks re-run, since all three of this run's fixes touch the same
  region: SC-9's `25 public, 12 listed in section, 0 undocumented omissions`,
  exit 0; SC-10's `21 checked, 0 mismatched to their target kind`, exit 0; the
  symbol-declaration link check's `13 checked, 0 defective`, exit 0.
- No battery owns this path: every `paths` file under `.jeffy/probes/` declares
  only `Sources/...` globs and none matches README.md.
- `check-claims.sh`: `claims: 15 checked, 0 mismatched, 0 errored, 0 skipped`,
  exit 0.
- Verify green: `verify: green (121s, ..., Executed 623 tests, with 0 failures
  (0 unexpected) in 120.379 (120.379) seconds)`, equal to PLAN.md's Verify
  count of 623.
- Not a stall: README.md changed and a ledger item changed state.
- Closed this iteration: SC-11 (Low, docs).

Learnings: before deleting formatting, find out whose it is. This blank line
read as debris from the previous run's own bullet removal and was in fact
upstream's group separator; the removal is still right, but it is right because
12 of the file's 13 lists are tight and the section's intro sentence carries the
distinction, not because the loop left it there.

Next: the ledger is empty. The closing sequence is the full fresh-evidence
audit, then the evaluator gate, then the declaration, with 7 iterations left
after this one.

## iter 3/10 | e2a93ea4-044525 | 2026-09-02 | ROTATION | rotation

Task: JOURNAL.md stood at 645 lines once this iteration's primary entry was
complete, above the 500-line rotation threshold.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: 0ab2af6c390094ba9abd863094552786a8c9ec50 (the rotation rode this
iteration's bookkeeping edit; this entry records it).

Verification: the two oldest entries - `iter 4/10 | ROTATION` and `iter 5/10 |
SC-8`, both from the previous run - were appended to the end of
JOURNAL-archive.md, which grew from 18 entries to 20 and was not overwritten.
Splitting used lines beginning `## iter` followed by a digit. JOURNAL.md now
holds 10 entries. The headings were read back from the archive before this
entry was written.

Learnings: none.

Next: the closing full audit.

## iter 4/10 | e2a93ea4-044525 | 2026-09-02 | AUDIT | audit

Task: the closing full fresh-evidence audit. The ledger emptied at iteration 3
and the Surface inventory has no unswept or stale row, so this iteration
rescores every applicable dimension against the severity rubric and the
Operating envelope.

Changed: JOURNAL.md only. Nothing was filed.

Checkpoint: 3b4fe8b7c97cd2b111474c2da50b36a765679c54

Verification:

Scope, stated before the scores so they are not read as wider than they are.
This run has changed no product code at all:
`git diff --name-only 193eff67 HEAD -- Sources Tests Package.swift
Package@swift-6.0.swift CMakeLists.txt` returns nothing, and the run's whole
diff against its base commit is README.md plus the state files and `.jeffy/`.
The evidence below is therefore freshly executed rather than freshly read - the
Method's rule that a dimension a previous audit scored clean, on code unchanged
since, needs a reproduced failure rather than a deeper reading of the same
lines.

Fresh evidence executed this iteration:
- All 14 probe batteries re-run through `check-claims.sh`, which executes each
  battery's claims file: `claims: 15 checked, 0 mismatched, 0 errored, 0
  skipped`, exit 0. Totalling the batteries' own summary lines by command gives
  6989 checks executed, all passed.
- Verify green: `verify: green (122s, ..., Executed 623 tests, with 0 failures
  (0 unexpected) in 120.559 (120.559) seconds)`, equal to PLAN.md's Verify
  count of 623.
- Testing in isolation, which the Method requires before scoring testing clean:
  `swift test --filter HeapTests` exits 0 with `Executed 32 tests, with 0
  failures`, and `swift test --filter OrderedCollectionsTests` exits 0 with
  `Executed 261 tests, with 0 failures`. No order dependence and no leaked
  state surfaced in either.
- Surface inventory staleness re-derived from each battery's own `paths` file
  against HEAD: 17 swept, 0 unswept, 0 stale, 13 `- [~]` unreachable on this
  host, each carrying its reason.
- Operating envelope enumerations re-run rather than re-read:
  `grep -rn 'ProcessInfo|getenv|FileManager|URLSession' Sources` returns
  nothing, so there is still no network, CLI, environment, config or
  state-at-rest surface; `grep -rln 'Decodable|Codable' Sources` returns the
  same 10 files the table's adversarial row describes; `grep -n '\.package('`
  over both manifests returns nothing, so the package still declares no
  external dependency.
- Environment fingerprint re-read and its enumeration re-run: the guard census
  over `Tests` returns the same shapes PLAN.md records, `swift --version`
  still reports 6.1.2 (swift-6.1.2-RELEASE) on x86_64 Linux, and the Stated
  counts row still `returns 4`.
- Declined and Settled classes are both empty, so there is no standing
  Derivation and no class enumeration to re-run.

Artifact-producing channels, enumerated by command rather than by recall, and
each verified not to carry the loop's state:
- `git archive`, which `swift package archive-source` builds on: the archive of
  HEAD holds 1024 entries and 0 of them match PLAN.md, BACKLOG.md, JOURNAL.md,
  JOURNAL-archive.md, `.jeffy/` or `.claude/`. The committed `.gitattributes`
  carries `export-ignore` for each, and `git ls-files .claude` returns nothing,
  so no `.claude` path is tracked at all.
- `.github/workflows/`: one file, `pull_request.yml`, with 8 jobs, all of them
  test or build. Grepping it for `upload|artifact|release|archive|publish|
  package-source` returns one line, a CMake tarball download URL, so there is
  no step that archives or publishes the tree.
- CMake: the tree's only `install()` calls are three in
  `cmake/modules/SwiftSupport.cmake`, installing `TARGETS` and the built
  `.swiftdoc` and `.swiftmodule`. No `install(DIRECTORY)` of the source tree.
- No Cargo.toml, package.json, MANIFEST.in, pyproject.toml, gemspec, nuspec or
  Dockerfile exists in the tree.

Documentation claims re-checked by executing them, not by reading them:
- The documented install is a promise a user performs, so it was performed. A
  scratch package under `/tmp` with `// swift-tools-version:6.0`, depending on
  this tree and on `.product(name: "Collections", package: "swift-collections")`
  exactly as README's snippet declares, was built with a source file that names
  `Deque`, `OrderedSet` and `Heap` through that single import and calls
  `prepend`, `min` and `max` on them. `swift build` exits 0 with
  `Build complete!`. Naming the types matters here: a build that imports a
  module without resolving a name from it proves nothing, per the standing
  Lesson.
- `swift package dump-package` reports 11 products on this host's active
  manifest, including `Collections`, so the product the snippet names exists.
- The version the README promises against matches the tree: the newest tag is
  1.6.0 and the Definition of Public API is written for version 1.6.
- The README's three link checks all green: 25 public `ContainersPreview`
  types with 12 listed and 0 undocumented omissions; 21 repository link
  definitions with 0 mismatched to their target kind; 13 `blob/main` links with
  0 failing to declare the symbol they are named for.

Dimension scores. Every score claims the 17 swept rows and no more; the 13
`- [~]` rows are surface this toolchain replaces with unavailable placeholders
and no score speaks for them.
- correctness: None. 623 tests and 6989 battery checks green across the swept
  rows, every battery compared against an independent oracle.
- security: None. The envelope's surface enumeration was re-derived this
  iteration and still returns no network, CLI, environment, config or
  state-at-rest surface. The one adversarial surface is Codable; its 10 files
  are unchanged since the previous run's audit read every one of them, and the
  batteries' Codable round-trips and malformed decodes ran green here.
- error handling: None. Out-of-range indices, capacity overflow and unmet
  ordering requirements are documented trapping preconditions of the shipped
  API, which the envelope classifies user-error; the decoders throw rather
  than trap.
- documentation: None. This is the dimension the run worked, and all three
  findings are closed with their checks green above. Examined and deliberately
  not filed: the `1.6.x` row of the toolchain table and four rows of the
  branching table pad their cells differently from their neighbours. Markdown
  renders both tables identically either way, the branching table's column
  widths legitimately vary with content, and the padding is upstream's own, so
  there is nothing here a reader meets - filing it would be activity, not
  improvement.
- dependency hygiene: None. The package declares no external dependency, so
  there is no third-party code to carry a known vulnerability.
- architecture: None on the swept rows.
- code quality: None on the swept rows. No product code changed this run.
- performance: None, and the evidence is bounded the same way it was last run:
  the batteries drive their inputs to completion inside the probe wall-clock
  ceiling, but no timing measurement was taken, so this score means no
  performance finding was reached by that work, not that the library was
  profiled.
- testing: None. Scored under the class ceiling, which puts any test finding at
  Low regardless, and the two isolation runs above found nothing.
- developer experience: None on the swept rows. The documented install builds.
- observability: not applicable. A collection library exposes no logging,
  metric or tracing surface.
- UX and accessibility: not applicable. No user-facing surface exists.

Zero High and zero Medium in-envelope. Closeout has begun: no further audit and
no replenishment for the rest of this run, which now converges.

Carried over from the previous run's evaluator and resolved here rather than
dropped: its fourth observation was that JOURNAL.md held 11 entries against a
retention rule of 10, because a ROTATION entry is appended after its own count
is taken. That is loop memory, not the shipped product - JOURNAL.md is
`export-ignore`d and reaches no artifact, as the channel check above shows - so
it is outside the rubric and is not filed. Its other three observations became
SC-9's corrected account, SC-10 and SC-11, all closed this run.

Filed this iteration: nothing.

Not a stall by the ceremony exemption: this is an AUDIT entry that files
nothing, which the stall rule names explicitly. No file outside the state files
changed and no ledger item changed state.

Learnings: none.

Next: the evaluator gate, and the declaration in the same iteration if it
returns PASS and the closing conditions hold. Six iterations remain after this
one, so a REJECT would still have room to be worked and re-gated.

## iter 4/10 | e2a93ea4-044525 | 2026-09-02 | ROTATION | rotation

Task: JOURNAL.md stood at 724 lines once this iteration's AUDIT entry was
complete, above the 500-line rotation threshold.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: 3b4fe8b7c97cd2b111474c2da50b36a765679c54 (the rotation rode this
iteration's bookkeeping edit; this entry records it).

Verification: the two oldest entries - `iter 5/10 | ROTATION` and `iter 6/10 |
AUDIT`, both from the previous run - were appended to the end of
JOURNAL-archive.md, which grew from 20 entries to 22 and was not overwritten.
Splitting used lines beginning `## iter` followed by a digit. JOURNAL.md now
holds 10 entries. The headings were read back from the archive before this
entry was written.

Learnings: none.

Next: the evaluator gate.

## iter 5/10 | e2a93ea4-044525 | 2026-09-02 | EVALUATOR | converged

Task: the convergence sequence - bring the standing claims current, run the
adversarial evaluator gate, and declare if it passes and the closing conditions
hold.

Changed: .jeffy/evaluator/e2a93ea4-044525-1.md (new, the gate's artifact),
BACKLOG.md (Converged line), JOURNAL.md.

Checkpoint: 0add406d848216f9120d0f853860ce95f1e82c24

Verification:

Standing claims brought current before the invocation, so no invocation would
be spent on a claim this run had already outdated:
- Rows needing re-recording: none, derived rather than assumed. This run's
  non-state diff against its base commit is README.md alone, and matching that
  path against every `paths` glob under `.jeffy/probes/` returns no battery, so
  no swept row certifies code this run touched.
- Surface inventory staleness re-derived from each battery's own `paths` file
  against HEAD: 17 swept, 0 unswept, 0 stale, 13 `- [~]` unreachable on this
  host.
- `check-claims.sh` re-run this iteration: `claims: 15 checked, 0 mismatched, 0
  errored, 0 skipped`, exit 0.
- Declined and Settled classes are both empty, so there is no recorded
  Derivation and no class enumeration to re-run.
- Finding IDs in PLAN.md: `grep -o 'SC-[0-9]*' PLAN.md` returns SC-6 once, in
  the `_UnsafeDequeSegments` row, where it annotates a deletion an earlier run
  completed rather than naming a carried or blocked finding. Nothing dangles;
  the evaluator resolved this independently and agreed.
- Oracle class, Environment fingerprint, Verify duration and Verify summary
  pattern re-read, all present and non-empty. The Verify count cell reads 623
  and equals the total the wrapper's green line reports.
- Verify green this iteration: `verify: green (120s, ..., Executed 623 tests,
  with 0 failures (0 unexpected) in 118.91 (118.91) seconds)`.

Evaluator: PASS - invocation 1 of this run, at iteration 5 of 10. It re-ran the
suite through the wrapper (623 tests, 0 failures, exit 0) and `check-claims.sh`
(15 checked, 0 mismatched, exit 0), re-executed all three closed acceptance
checks verbatim in both directions against pre-fix READMEs extracted with
`git show`, and found each one discriminating: SC-9 exit 1 at base naming the
three missing protocols and exit 0 at HEAD, SC-10 exit 1 naming `[SpanPreview]`
and exit 0 at HEAD, SC-11 exit 1 naming the blank at offset 2 and exit 0 at
HEAD. It re-derived the 25 public `ContainersPreview` types independently, and
went further than the run did by running a laxer control scan that also covers
`public enum`, `class`, `actor` and attribute-prefixed forms, confirming the
anchored grep undercounts nothing. It confirmed the three added protocol
descriptions against their declarations, confirmed `UniqueBox` sits outside
every `UnstableContainersPreview` guard, and confirmed `Shared` and
`SubrangeConsumer` sit inside `#if false` blocks. Artifact at
`.jeffy/evaluator/e2a93ea4-044525-1.md`, committed by this iteration's
checkpoint, carrying no machine-absolute path.

Closing conditions, each checked rather than assumed:
- A full fresh-evidence audit this run scored zero High and zero Medium
  in-envelope: iteration 4, in this journal.
- The Surface inventory lists no unswept row: 17 swept, 0 unswept, 13 `- [~]`
  unreachable on this host, each carrying its reason.
- No open High and no open Medium in Now, Next or Later. The ledger is empty
  outright, so this run carries no Low either - the three it opened with or
  filed, SC-9, SC-10 and SC-11, are all closed.
- The only commits since the clean audit are that audit's own two bookkeeping
  commits, whose whole diff is JOURNAL.md and JOURNAL-archive.md, plus this
  convergence iteration's.
- Verify green this iteration, and the evaluator returned PASS.

Gate observations, recorded and deliberately not fixed here, because a fix
after a PASS invalidates that PASS and spends an invocation the declaration
needs. They go to the run report and the next run's ledger:
- The SC-9 journal entry's exclusion list under-names two of its 13 entries: it
  cites only the `UniqueSet` `SubrangeConsumer` where `RigidSet+Container.swift`
  declares one too, and only the `Range` `BorrowingIterator` where
  `ClosedRange+Iterable.swift` declares one too. The stated reason holds for
  both instances in each case, so the decision and the result stand; only the
  enumeration is partial. That is the same defect class this run's own first
  Lesson names, arriving from the other direction.
- SC-9's acceptance script hardcodes its 13 excluded names rather than deriving
  them from the journal entry the backlog line points at, so a type added to
  both the code and that list would pass with no written reason.
- The three link definitions this run added sit after `[Drain]` rather than in
  bullet order. Link definitions do not render.

Not a stall: the ledger and the evaluator artifact both changed, and this is
the convergence sequence in any case.

Learnings: none beyond the existing Lessons.

Next: the run is converged. The next run opens with a fresh audit and the
gate's three observations as its first work.

## iter 5/10 | e2a93ea4-044525 | 2026-09-02 | ROTATION | rotation

Task: JOURNAL.md reached 713 lines once the declaring entry was complete, above
the 500-line rotation threshold.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: 0add406d848216f9120d0f853860ce95f1e82c24 (the rotation rode this
iteration's bookkeeping edit; this entry records it).

Verification: the two oldest entries - `iter 6/10 | ROTATION` and `iter 7/10 |
EVALUATOR`, both from the previous run - were appended to the end of
JOURNAL-archive.md, which grew from 22 entries to 24 and was not overwritten.
Splitting used lines beginning `## iter` followed by a digit. JOURNAL.md now
holds 10 entries. The headings were read back from the archive before this
entry was written.

Learnings: none.

Next: nothing. The run is converged; this entry only records the rotation the
declaring iteration performed.

## iter 1/10 | c9ceb1d0-052427 | 2026-09-02 | RATCHET | converged

Task: the convergence ratchet - verify that the tree this run opened on is the
tree an earlier run already certified, and re-declare without a fresh audit.

Changed: JOURNAL.md (this entry and the rotation entry that follows it),
JOURNAL-archive.md (rotation).

Checkpoint: a32039455ff6103ad090665de2d4f959e55546cf

Verification: every ratchet precondition derived by command, none assumed.

- The latest Converged line in BACKLOG.md names
  0add406d848216f9120d0f853860ce95f1e82c24 - 2026-09-02.
  `git merge-base --is-ancestor 0add406d848216f9120d0f853860ce95f1e82c24 HEAD`
  exits 0, so the certified commit is still reachable from HEAD, and it is
  likewise an ancestor of this run's `base_head`
  aa4f2274540b2ea536a7ed68cfbaf9d59f1b0a06, so the ratchet re-declares a tree
  that predates this run rather than work this run did.
- That declaration was accepted rather than merely written: the last line of
  `.jeffy/metrics/e2a93ea4-044525.jsonl` carries
  `"declaration":{"hash":"0add406d...","verdict":"accepted"}`, so the line
  certifies a tree the Stop hook itself passed.
- BACKLOG.md lists no open task: Now, Next and Later are all empty, so there is
  no open High, no open Medium, and no carried Low to name.
- This run carries no focus directive; the `focus:` key of the loop state file
  is blank.
- Nothing but loop state has changed since the certified commit.
  `git diff --name-only 0add406d848216f9120d0f853860ce95f1e82c24 HEAD` returns
  BACKLOG.md, JOURNAL-archive.md and JOURNAL.md, and nothing else.
  `git status --porcelain` returns only
  `.jeffy/metrics/e2a93ea4-044525.jsonl`, which the Stop hook owns and the next
  checkpoint sweeps up. No product path moved.
- The Surface inventory in PLAN.md lists 17 swept rows, 0 unswept rows and 13
  `- [~]` rows unreachable on this toolchain, each carrying its reason.
- No swept row is stale. Each row's recorded commit was compared against HEAD
  over the globs in that row's own `.jeffy/probes/<battery>/paths` file: 17 of
  17 fresh, 0 stale, 0 naming a battery without a paths file.
- `check-claims.sh` re-run this iteration: `claims: 15 checked, 0 mismatched, 0
  errored, 0 skipped`, exit 0.
- Declined and Settled classes are both empty, so there is no recorded
  Derivation and no class enumeration to re-run.
- The Verify count cell in PLAN.md reads 623 and equals the count on the
  wrapper's last green record, `.jeffy/metrics/verify-last.json`
  (`"count": 623`, taken at 6470d063f04326a505f80ffc44975a7b51e1879a). Oracle
  class, Environment fingerprint, Verify duration and Verify summary pattern
  were re-read and are all present and filled. The Stop hook re-runs the Verify
  command itself at this converged stop, under the 450s bound this launch
  derived from the recorded 150s measurement.
- No Converged line was appended or edited. A ratchet re-declares the line that
  already stands, and appending a new hash would name a commit that is not an
  ancestor of this run's base_head.
- The evaluator gate was not invoked, and must not be: the gate belongs to the
  Definition of done path, never to the ratchet.

Stall: this iteration changed no file outside JOURNAL.md, JOURNAL-archive.md
and `.jeffy/`, no BACKLOG.md item changed state, and no Surface inventory row
changed state, so it is a no-progress iteration by the stall definition. A
RATCHET is a ceremony entry and never forms the blocking pair; it is the whole
work this iteration was supposed to do.

Learnings: none. Nothing was executed here that the existing Lessons do not
already cover.

Next: nothing in this project. The previous run's evaluator recorded three
observations it deliberately did not fix inside its convergence sequence, and
it left them in its journal entry rather than filing them on the ledger, so the
ledger this run opened on was empty and the ratchet applies. They are named in
this run's run report; a future run that wants them worked has to seed them
into BACKLOG.md first, because an empty ledger over an unchanged tree ratchets
every time.

## iter 1/10 | c9ceb1d0-052427 | 2026-09-02 | ROTATION | rotation

Task: JOURNAL.md stood at 703 lines once the RATCHET entry was appended, above
the 500-line rotation threshold, holding 12 entries.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: a32039455ff6103ad090665de2d4f959e55546cf

Verification: the two oldest entries - `iter 7/10 | 56af17cb-035551 | ROTATION`
and `iter 1/10 | e2a93ea4-044525 | SC-9`, both from earlier runs - were
appended to the end of JOURNAL-archive.md, which grew from 24 entries to 26 and
was not overwritten. Splitting used only lines beginning `## iter` followed by a
digit at column zero, so the fenced heading-grammar example in the preamble was
neither counted nor moved. JOURNAL.md now holds 10 entries in 572 lines, and
the archive's two new headings were read back after the write.

Learnings: none.

Next: nothing. The run is converged by the ratchet; this entry only records the
rotation that iteration performed.

## iter 1/10 | e1b9f255-053139 | 2026-09-02 | RATCHET | converged

Task: ratchet verification. The run opened on an empty ledger over a tree that a
previous run's declaration certified, so the iteration re-ran that verification
rather than starting an audit.

Changed: JOURNAL.md only. No product path was touched.

Checkpoint: a7c6171d14ecd5ae29e7b0ede4cd070ff58e4b07

Verification, each item executed this iteration:

- The latest `Converged` line in BACKLOG.md names
  0add406d848216f9120d0f853860ce95f1e82c24 - 2026-09-02.
  `git merge-base --is-ancestor 0add406d848216f9120d0f853860ce95f1e82c24 HEAD`
  exits 0, so the certified commit is reachable from HEAD, and the same command
  against this run's `base_head` 101581fda78a27e1c4badb2c5ec1b9e218e4fbb3 also
  exits 0, so the ratchet re-declares a tree that predates this run rather than
  work this run did.
- That hash carries an accepted declaration rather than a merely written one.
  The last line of `.jeffy/metrics/e2a93ea4-044525.jsonl` and the last line of
  `.jeffy/metrics/c9ceb1d0-052427.jsonl` both carry
  `"declaration":{"hash":"0add406d...","verdict":"accepted"}` - the original
  Definition-of-done declaration and the intervening run's ratchet, each passed
  by the Stop hook.
- BACKLOG.md lists no open task. Counting checkbox lines between `## Now` and
  `## Proposed` gives 0, so Now, Next and Later are all empty: no open High, no
  open Medium, and no carried Low to name by ID.
- This run carries no focus directive; the `focus:` key of the loop state file
  is blank.
- Nothing but loop state has changed since the certified commit.
  `git diff --name-only 0add406d848216f9120d0f853860ce95f1e82c24 HEAD` returns
  BACKLOG.md, JOURNAL.md, JOURNAL-archive.md and
  `.jeffy/metrics/e2a93ea4-044525.jsonl`, and nothing else. `git status
  --porcelain` returns only the untracked
  `.jeffy/metrics/c9ceb1d0-052427.jsonl`, which the Stop hook owns and this
  iteration's checkpoint sweeps up. No product path moved, so the salvage rule
  did not fire either.
- The Surface inventory in PLAN.md holds 17 `- [x]` rows, 0 `- [ ]` rows and 13
  `- [~]` rows unreachable on this toolchain, each carrying its reason. The
  unreachable rows are named in this run's run report.
- No swept row is stale. Each row's recorded commit was compared against HEAD
  over every glob in that row's own `.jeffy/probes/<battery>/paths` file, one
  `git diff --name-only <commit> HEAD -- <glob>` per glob: 17 of 17 returned
  nothing, 0 stale, 0 rows naming a battery that has no paths file.
- `check-claims.sh` re-run this iteration reports `claims: 15 checked, 0
  mismatched, 0 errored, 0 skipped` and exits 0. That covers the fourteen
  battery claims lines and PLAN.md's single Stated counts row.
- The Declined and Settled classes sections of BACKLOG.md are both empty, so
  there is no recorded Derivation and no class enumeration to re-run.
- The Verify count cell in PLAN.md reads 623 and equals the count on the
  wrapper's last green record, `.jeffy/metrics/verify-last.json`
  (`"count": 623`, taken at 6470d063f04326a505f80ffc44975a7b51e1879a). Oracle
  class, Environment fingerprint, Verify duration and Verify summary pattern
  were re-read and are all present and filled. The Verify command was not run by
  this iteration: the Stop hook re-runs it itself at the converged stop, under
  the 450s bound this launch derived from the recorded 150s measurement.
- No `Converged` line was appended or edited. A ratchet re-declares the line
  that already stands, and appending a new hash would name a commit that is not
  an ancestor of this run's `base_head`.
- The evaluator gate was not invoked, and must not be: the gate belongs to the
  Definition of done path, never to the ratchet.

Stall: this iteration changed no file outside JOURNAL.md, JOURNAL-archive.md and
`.jeffy/`, no BACKLOG.md item changed state, and no Surface inventory row
changed state, so it is a no-progress iteration by the stall definition. A
RATCHET is a ceremony entry and never forms the blocking pair; re-running the
verification is the whole work this iteration was supposed to do.

Learnings: none. Nothing was executed here that the existing Lessons do not
already cover.

Next: nothing in this project. The ledger is empty over an unchanged tree, so
every relaunch without a focus directive will ratchet on iteration 1 and stop.
The three observations the run e2a93ea4 evaluator recorded and deliberately did
not fix inside its convergence sequence are still unfiled; a future run that
wants them worked has to seed them into BACKLOG.md first, or launch with a focus
directive, either of which suppresses the ratchet and forces a real audit.

## iter 1/10 | e1b9f255-053139 | 2026-09-02 | ROTATION | rotation

Task: JOURNAL.md stood at 673 lines once this iteration's RATCHET entry was
appended, above the 500-line rotation threshold, holding 12 entries.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: a7c6171d14ecd5ae29e7b0ede4cd070ff58e4b07

Verification: the two oldest entries - `iter 1/10 | e2a93ea4-044525 | ROTATION`
and `iter 2/10 | e2a93ea4-044525 | SC-10`, both from an earlier run - were
appended to the end of JOURNAL-archive.md, which grew from 26 entries to 28 and
was not overwritten; its two new headings were read back after the write.
Splitting used only lines beginning `## iter` followed by a digit at column
zero, so the fenced heading-grammar example in the preamble was neither counted
nor moved. JOURNAL.md now holds 10 entries in 586 lines.

Learnings: none.

Next: nothing. The run is converged by the ratchet; this entry only records the
rotation that iteration performed.
