# Jeffy eval: Kotlin/kotlinx-io

The 1,549-star multiplatform I/O library from JetBrains, the `Buffer`,
`Source`, `Sink` and `ByteString` core under Ktor 3. Run 2026-09-02 as
wave 14 (COHORT-WAVE13.md). **2 runs, 19 iterations, converged** in round 2
at `c83beca31a00b556c9e35536b7b9c1950e8b9e10`, within a **pre-registered
budget of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `362bdc35e159bad6da1e08101c8321792d762281` (master, tagged 0.9.1; upstream develops on `develop`, see below) |
| Findings closed | **5** - 1 High, 3 Medium, 1 Low (a sixth, `IO-2`, was subsumed by `IO-6`) |
| Shipped-code change | 13 files, **+298 / -19** (one line of it is loop housekeeping, see below) |
| Surface inventory | **27 of 27 rows swept** (2 further rows marked unreachable on this host) |
| Ledger at convergence | 3 Lows carried, listed by the declaration |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | `./gradlew jvmTest jsNodeTest wasmJsNodeTest wasmWasiNodeTest linuxX64Test` green; `linuxX64Test` alone reports 1115 tests |
| Upstream | [#521](https://github.com/Kotlin/kotlinx-io/pull/521) (IO-1), filed 2026-09-02 against `develop` |

## What the loop found

- **`IO-1`** (High) - `SystemTemporaryDirectory` was `Path("")` on the
  Linux, Android Native and MinGW targets whenever neither `TMPDIR` nor
  `TMP` was set, which is the normal state of a container, a systemd unit
  or a CI runner. Every path built from it resolved against the filesystem
  root: with both variables unset, `linuxX64Test` failed 19 tests with
  `Permission denied` on `/<name>`. The `unix` source set now falls back to
  `/tmp` and `mingw` to `GetTempPathA`.
- **`IO-6`** (filed Medium, subsuming `IO-2`) - the file-backed `RawSource`
  and `RawSink` implementations on Kotlin/Native, Node and WASI skipped the
  argument and closed-state checks their interfaces document. On the base
  tree the native `FileSource` read through a closed `FILE*`, so
  read-after-close was a segfault rather than the documented
  `IllegalStateException`; the loop measured that in its pre-fix run and
  recorded the escalation in its journal, while the ledger line kept its
  Medium label. All six implementations now use the project's own
  `checkByteCount` / `checkOffsetAndCount` helpers plus a closed check,
  with a contract test per platform.
- **`IO-5`** (Medium) - `Buffer.indexOf(byte, startIndex, endIndex)` raised
  `IndexOutOfBoundsException` for a negative index where its KDoc and the
  `Source.indexOf` sibling promise `IllegalArgumentException`.
- **`IO-3`** (Medium) - the three `ByteString.lastIndexOf` overloads claimed
  compatibility with `CharSequence.lastIndexOf` that their `startIndex`
  semantics do not deliver (lowest index examined rather than highest; an
  empty needle returns `size`; a negative start searches everything). The
  loop drove all ten `compatible with [CharSequence...]` claims in the file
  against the reference and rewrote only the three that were false.
- **`IO-4`** (Low) - the read-error branch of native
  `FileSource.readAtMostTo` reported itself as `write failed`, reachable
  through the public API by opening a directory as a source.

## What the loop got wrong

**The pin was the release branch.** The base is `master` at 0.9.1, but
upstream merges to `develop`, which at the time of the run was 6 commits
ahead and had already rewritten the native `FileSource` and `FileSink`
onto unbuffered `open`/`read`/`write` (#507, July 2026). On `develop` the
`IO-6` crash is gone: read-after-close raises `IOException` for `EBADF`
and a negative count raises `IOException` for `EFAULT`, wrong types but not
a crash, so `IO-6` is a Medium there and is not filed. `IO-1` is unchanged
on `develop` and is the one PR. The selection procedure now pins the
development branch when a repository names one.

**Round 1 ran its whole budget without a declaration.** It closed `IO-1`
at iteration 2 and spent the rest sweeping the 27-row map and building
batteries; round 2 closed the remaining four in four consecutive
iterations, audited fresh, and declared on the first gate.

**Three Lows carried, none blocking under the declaration floor**:
`ByteStringBuilder(-1)` raises `NegativeArraySizeException` on JVM and
`IllegalArgumentException` on Native with no `@throws` documented; four
battery READMEs whose mutation figures were not re-measured when the
battery changed; and the native `FileSource.readAtMostTo` allocating the
whole requested count up front, read from source rather than reproduced.
The gate also noted the `IO-6` ledger label, above.

**Verification scope.** The verify command ran five targets on this host:
JVM, JS on Node, Wasm/JS on Node, Wasm/WASI on Node and Kotlin/Native
linuxX64. The Apple and MinGW `actual` implementations were compiled
(`compileKotlinMingwX64`) but never executed, and no journal entry claims
otherwise; the pre-registration had budgeted `jvmTest` alone, and the loop
widened the gate itself at its first audit.

**Loop housekeeping in the product diff.** One `.gitignore` line for the
loop's own state file.

## Upstream

`IO-1` is filed as [#521](https://github.com/Kotlin/kotlinx-io/pull/521)
against `develop`, verified on a fresh clone at `5b94edd1`:
`env -u TMPDIR -u TMP ./gradlew :kotlinx-io-core:linuxX64Test` fails 19
of 1115 before and exits 0 after, `compileKotlinMingwX64` and
`checkLegacyAbi` pass. The MinGW half is compiled here, not run, and the
PR says so. `IO-6` is not filed, for the reason above; `IO-5` and `IO-3`
are Mediums and stay in the patch.

## Files

- [journal.md](journal.md) - the full loop journal, every iteration of both rounds
- [fixes.patch](fixes.patch) - the product diff, base to converged HEAD, loop state excluded
