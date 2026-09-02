# Jeffy eval: apple/swift-collections

Apple's 4,488-star package of Deque, OrderedSet, OrderedDictionary, Heap,
BitSet and the persistent Tree collections; sibling of swift-algorithms,
which converged in an earlier cohort. Run 2026-09-01/02 as wave 11
(COHORT-WAVE11.md). **5 runs, 25 iterations, converged** in round 2 at
`be64bd66f55f056edd3394aa47dc3b3d1f7417b3` and re-declared in round 3 at
`0add406d848216f9120d0f853860ce95f1e82c24`, within a **pre-registered
budget of 5 rounds of 10**. Rounds 4 and 5 were one-iteration ratchets
that re-verified the declared tree and changed nothing.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `26f299bd4932ab9b0f6fd226e5fc1084f75b22b0` (1.6.0-162-g26f299bd, main) |
| Findings closed | **11** - 4 Medium, 7 Low |
| Shipped-code change | 5 files, **+44 / -39** |
| Surface inventory | **17 of 17 reachable rows swept**; 13 rows unreachable on this host, see below |
| Ledger at convergence | empty |
| Evaluator | **2 invocations: PASS, PASS** |
| Suite at convergence | `swift test`: `Executed 623 tests, with 0 failures`, `check-claims` 15 checked / 0 mismatched |

## Read this first: what this host could not reach

The package's primary manifest declares tools version 6.2. The host runs
Swift 6.1.2, so SwiftPM selects `Package@swift-6.0.swift` instead. Two
consequences, both recorded in the run's environment fingerprint and
verified by building rather than by reading: the `SortedCollections`
target is absent from that manifest, and every `#if compiler(>=6.2)` block
is false, which empties four declared test targets (BasicContainersTests,
ContainersTests, SpanPreviewTests, TrailingElementsTests) to zero cases.
Types such as `RigidArray` compile down to an `@available(*, unavailable)`
placeholder on this toolchain. The loop marked 13 of its 30 inventory
rows `[~]` unreachable, each with the grep or build that proves it, and
swept the 17 it could execute. **The convergence claim covers the 17
reachable rows only.** A run on a Swift 6.2 toolchain would face a
different, larger surface, and this receipt makes no claim about it.

## What the loop found

- **`SC-1` (Medium, docs)** - README's SwiftPM adoption snippet declared
  `// swift-tools-version:6.3`, above every released Swift and above the
  package's own stated minimum.
- **`SC-2` (Medium, packaging)** - no `.gitattributes`, so a `git archive`
  of the tree shipped the loop's own state files. The loop caused this
  one; `export-ignore` entries fix it.
- **`SC-5` (Medium, docs)** - the doc comment on
  `BitArray.init?(_ description: String)` showed `BitArray("42") // nil`,
  but a string literal at that call site resolves to
  `init(stringLiteral:)`, which calls `fatalError`. The documented
  expressions could not reach the initializer they documented.
- **`SC-8` (Medium, docs)** - README's `UnstableContainersPreview` section
  listed four types the package does not declare and pointed six source
  links at paths absent from the tree.
- **`SC-6` (Low, runtime)** - `_UnsafeDequeSegments.count` and
  `isIdentical(to:)` had no caller anywhere in the module, gated or not;
  removed.
- `SC-3`, `SC-4`, `SC-7`, `SC-9`, `SC-10`, `SC-11` (Low, docs) - stale
  version pins, a truncated change-propagation chain, a missing product
  mention, and link and formatting defects in the same README section.

## What the loop got wrong

Two things, both disclosed rather than tidied. `SC-2` is a defect the
loop introduced: the state files it writes into the tree were exported by
`git archive` because the repository had no `.gitattributes`; the loop
found and fixed its own mess. And the campaign driver reported this
target as **not converged** after round 5, because its convergence test
read the last journal heading and that heading was a ROTATION entry, not
the EVALUATOR entry two lines above it. The hook-accepted declarations at
`be64bd66` and `0add406d` are in `.jeffy/metrics`, and rounds 4 and 5 were
ratchets that re-verified them. The driver fix (skip ROTATION and SALVAGE
headings) is queued as P2-48 and was not applied while units were running.

## Why the findings are what they are

Every reachable row of a mature Apple package with 623 executing tests
was swept, and the sweep found no runtime defect in the code that runs on
this toolchain beyond two uncalled internal functions. What it found was
documentation that had drifted from the tree: a tools version that does
not exist, an example that traps, and a README section describing types
that were renamed or removed. Those are Mediums by the rubric (a reader
following them fails), and nothing above that was there to find on the
surface this host could reach.
