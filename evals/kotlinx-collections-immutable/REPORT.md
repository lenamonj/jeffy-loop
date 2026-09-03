# Jeffy eval: Kotlin/kotlinx.collections.immutable

Kotlin's persistent and immutable collection interfaces and their
implementations (persistent vector, hash and ordered maps and sets, and
their builders). Run 2026-09-03 as wave 18 (COHORT-WAVE17.md). **1 run, 9
iterations, converged** in round 1 at
`761e8f9769f355dbd105b4639580485319857fb9`, within a **pre-registered budget
of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `9f961e4dd419dff58ffea164dd41ebba68acc8d6` (master) |
| Findings closed | **4** - 4 Low as closed (one filed Medium, re-scored Low on differential evidence and carried); 3 Lows carried, 1 blocked (see below) |
| Shipped-code change | 4 files, **+57 / -6** |
| Surface inventory | **19 of 19 rows swept** |
| Ledger at convergence | 3 Lows: 2 open, 1 blocked |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | `./gradlew :kotlinx-collections-immutable:jvmTest`: 259 tests, 0 failures (258 at base) |
| Upstream | none - nothing High or Medium |

## What the loop found

Nothing above Low survived the run. The library's contracts held under
19 known-answer batteries; what the loop closed were promises in the
documentation and one builder identity guarantee.

- **`LOW-1`** (runtime) - `PersistentCollection.Builder.build()` promises to
  return the source collection when nothing changed, and the hash map and
  hash set builders keep that promise; `PersistentVectorBuilder` did not,
  because a content-preserving `set(i, sameElement)` still marked the
  builder modified and `build()` returned a fresh list. The no-op set no
  longer modifies the builder.
- **`LOW-2`** (docs) - `Iterable.toPersistentSet` and `Map.toPersistentMap`
  documented "if the receiver is already a persistent set/map, returns it
  as is", while each short-circuits only on the ordered implementation and
  copies a hash-backed receiver. Both sentences now say what the code
  does; the whole class of pass-through sentences was enumerated and
  settled with a re-runnable command rather than the two instances patched.
- **`LOW-3`** (docs) - `CharSequence.toImmutableSet` declares
  `PersistentSet<Char>` where the `Iterable`, `Array` and `Sequence`
  overloads of the same name declare `ImmutableSet`. Documented rather
  than changed, since aligning a published signature is the maintainers'
  call; the alignment is recorded as a Proposed line.
- **`MED-1`, re-scored to `LOW-5`** - a sub-list view of a
  `PersistentList.Builder` does not fail fast: a structural modification
  through the view while one of its iterators is in flight surfaces as
  `NoSuchElementException` rather than `ConcurrentModificationException`.
  Filed Medium from the guava-testlib conformance corpus; a differential
  against the JDK's own `ArrayList.subList` showed the premise overstated
  and it was re-scored Low and carried, still open.

**Carried, not blocking**: `LOW-5` above; `LOW-6` the loop's own mistake,
raised by the gate: iteration 1 appended to a `.gitignore` with no trailing
newline, fusing two entries, so the benchmark-results ignore no longer
matches and the loop's state file became trackable; `LOW-4` (blocked) a
bump of the `guava-testlib` 18.0 pin on the jvmTest classpath, which waits
on `LOW-5` because the newer corpus tests exactly that behaviour.

## What the loop got wrong

**It fused two `.gitignore` lines** in its first iteration and did not
notice; the evaluator did, and verified it independently. Filed, not
fixed, because a fix after a PASS invalidates the PASS. It is the next
run's first task and is disclosed here.

**Host limits, disclosed**: the loop verified the JVM source set only
(`jvmTest`); the JS, wasm and native source sets of this multiplatform
library were not built or tested, the same disclosure as kotlinx-io and
kotlinx-datetime. The project builds on TeamCity rather than GitHub
Actions, so no CI job was reproduced.

## Upstream

Nothing meets the bar: no finding is High, and `LOW-3`'s signature question
is a design decision the receipt raises rather than files.

## Files

- [journal.md](journal.md) - the full loop journal, every iteration
- [fixes.patch](fixes.patch) - the product diff, base to converged HEAD, loop state excluded
