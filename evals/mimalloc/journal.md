# Journal archive

Entries rotated out of JOURNAL.md, oldest first. Appended to across every rotation
and every run; never overwritten and never rewritten.

## iter 1/10 | 7f2a700e-233033 | 2026-08-30 | AUDIT | audit

Task: bootstrap the state files for a fresh project and run the first full audit - fill the Operating envelope, the Surface inventory, and the Verify command block, enumerate the artifact-producing channels, and file what the audit finds.

Changed: PLAN.md (envelope surfaces, 27 inventory rows, verify command block), BACKLOG.md (H1, M1, M2, M3), JOURNAL.md, .gitattributes untouched, and a new battery at .jeffy/probes/option-defaults/ (run.sh, probe.c, paths, claims, README.md).

Checkpoint: 1c57193b4d69713878df5d20b57119c0bbc6d62f

Verification: the verify command runs `cmake` + `ctest` for both Debug and Release; through `quiet-verify.sh` it is green in 27s on a warm tree, reporting `100% tests passed, 0 tests failed out of 7` for each configuration. Both configurations are graded on purpose: Release defines NDEBUG so `MI_DEBUG` is 0 and the `#if MI_DEBUG >= 2` bodies of `test/test-api-fill.c` compile to nothing there. The exclusion list in the Environment fingerprint is derived by command, not asserted: the eight override and link-mode programs under `test/` belong to a separate CMake project that requires an installed mimalloc, so this gate never compiles them.

Artifact channels, enumerated by command rather than recall - CMake `install(...)` rules, `bin/bundle.sh`, `.github/workflows/release.yaml`, `contrib/vcpkg/portfile.cmake`, `contrib/docker/*/Dockerfile`, `mimalloc.pc.in`. The binary channel verifies clean: `cmake --install out/jeffy-Release --prefix /tmp/j-prefix` emits only the four public headers, the shared and static libraries, the object file, the CMake package files and `mimalloc.pc`. The vcpkg and docker channels build from an upstream tag through that same install path. The source-archive channel does not verify clean, and is filed as M3.

Audit scores against the rubric and the envelope, claiming only what was probed this iteration and not the unswept remainder: correctness High (H1), error handling Medium (M1), documentation Medium (M2), dependency hygiene Medium (M3), security None on the surface probed, architecture None, code quality None, performance None, testing None, observability None. UX and accessibility do not apply - this is a library with no user-facing surface. Every one of these scores rests on the shallow breadth-first probing described below and on no swept inventory row: all 26 reachable rows are still `- [ ]`, so this audit is emphatically not the whole project, and the next iterations sweep before any of these Nones can mean anything.

Evidence. Three known-answer probes were compiled against the tree's own static library and run: a size-class and contract sweep over the unaligned, aligned, realloc, string, option and heap families (3265 checks, all passing, covering `mi_good_size`/`mi_usable_size` coherence for every size 0..1024, alignment for every power of two to 4096, offset alignment, calloc and recalloc zeroing, count-overflow returning NULL, and `posix_memalign` error codes); a second over the `u`-API block-size out-parameters, the `theap` family, the POSIX shims, `mi_expand`, `mi_heap_visit_blocks`, subprocesses, process info and arena introspection (68 checks, 66 passing); and a differential of every `(=X)` default stated in the `mi_option_t` enum against `mi_option_get`. The two failures in the second probe were the probe's own expectations, not defects: `mi_reallocarray` on multiplication overflow sets `EOVERFLOW`, and a differential against this host's glibc `reallocarray` shows glibc setting errno 75 as well, so mimalloc matches the implementation its documentation points at. That check was corrected rather than filed.

H1 was reproduced differentially: after dirtying the size class with nonzero-filled blocks, 64 of 64 `mi_theap_zalloc_csize(theap, MI_SMALL_SIZE_MAX+1)` allocations came back holding nonzero bytes, against 0 of 64 for the `mi_zalloc_csize` control on the same tree.

Learnings: this project's test suite must be built and run in both Debug and Release, because `MI_DEBUG` is 0 under NDEBUG and the fill and padding assertions in `test/test-api-fill.c` disappear in a Release-only build - a green Release gate says nothing about them. `mi_subproc_id_t` is a struct wrapping a `void*`, so probe code compares `._mi_subproc_id` and never the value itself. When a probe expectation about a libc-compatible shim fails, check it against this host's own libc before filing: two of the three candidate findings this iteration died that way.

Next: H1 - fix the `mi_theap_zalloc_csize` delegation and build the `csize-wrappers` battery that pins it, after observing that battery fail on the unfixed header.

## iter 2/10 | 7f2a700e-233033 | 2026-08-30 | H1 | done

Task: H1 - `mi_theap_zalloc_csize` in `include/mimalloc.h` delegated its large-size branch to `mi_theap_malloc` instead of `mi_theap_zalloc`, so a documented zeroing allocator returned uninitialized heap memory for every size above `MI_SMALL_SIZE_MAX`.

Changed: `include/mimalloc.h` (one identifier on the `mi_theap_zalloc_csize` large-size branch), a new battery at `.jeffy/probes/csize-wrappers/` (probe.c, run.sh, mutate.sh, paths, claims, README.md), `.jeffy/probes/option-defaults/README.md` (removed a predicted measurement the claims file did not carry, per the hook's README MEASUREMENTS notice), BACKLOG.md, JOURNAL.md.

Checkpoint: b99c8f2f569d4237aeb0f7b12352c0b45dcdcb76

Verification: the battery was built before the fix and observed failing on the unfixed header - `csize-wrappers: 1642/1834 checks passed`, with all 192 failures being `mi_theap_zalloc_csize zeroes` at 1025, 4096 and 65536 bytes and none at or below `MI_SMALL_SIZE_MAX`, which localises the failure to exactly the branch H1 names. After the fix it reports `csize-wrappers: 1834/1834 checks passed`. The verify gate through `quiet-verify.sh` is green in 31s, reporting `100% tests passed, 0 tests failed out of 7` for each of the two configurations it builds. `check-claims.sh` over the whole probe directory reports 3 checked, 0 mismatched, 0 errored, 0 skipped.

The battery's first draft passed on the unfixed header and had to be corrected before it was worth anything. It dirtied every size class with `mi_malloc`, which draws on the default theap, so the theap under test still handed back freshly mapped zero pages and the defect was invisible. Dirtying through `mi_theap_malloc` on the same theap the wrapper allocates from is the discriminating input, and `mutate.sh` now reintroduces the defective branch, runs the battery, restores the header and records the mutated summary as the battery's second claim, so its ability to fail stays checkable instead of remembered.

Contract preserved: the change alters one identifier inside one `static inline` wrapper. Signature, arity, `mi_attr` annotations and the small-size branch are untouched, and the wrapper now does for `theap` exactly what the sibling `mi_zalloc_csize` two lines above already did for the default heap. Nothing in the tree calls it - the only `mi_theap_malloc_tp` uses in `test/test-api.c` sit inside a block comment - so no caller's behaviour changes; what changes is that a caller who trusted the name now gets what the name promises. No public documentation contradicts the new behaviour, and no Surface inventory row is swept yet, so none needed flipping.

`option-defaults` declares `include/mimalloc.h` in its paths file and was therefore re-run in this iteration. It still reports `option-defaults: 18/25 checks passed` and still exits 1, unchanged from the value iteration 1 recorded, because it pins M2 which is still open - this is the battery reporting a filed finding, not a regression this diff caused.

Learnings: a zeroing probe that dirties the wrong heap certifies nothing - dirty the same theap the wrapper under test allocates from, or the allocator hands back fresh zero pages and the battery passes over the defect it was written for. Never write a restoring `sed` for these header wrappers: `mi_theap_malloc_csize` and the defective `mi_theap_zalloc_csize` branch end in the identical text, so a pattern that matches one matches both; `mutate.sh` copies the file aside and restores by copy.

Next: M1 - the empty `MIMALLOC_*` environment value silently read as boolean 1.

## iter 3/10 | 7f2a700e-233033 | 2026-08-30 | SWEEP | done

Task: sweep Surface inventory rows. With no open High at the start of this iteration the map outranked the three open Mediums, and 26 rows were unswept against 8 remaining iterations.

Changed: new batteries at `.jeffy/probes/alloc-core/`, `.jeffy/probes/alloc-aligned/` and `.jeffy/probes/u-api/`, a shared `.jeffy/probes/harness.h`, a shared builder `.jeffy/probes/run-battery.sh` and a shared discriminating-mutation runner `.jeffy/probes/mutate-battery.sh`; PLAN.md (six rows flipped to swept); BACKLOG.md (H2 filed); JOURNAL.md.

Checkpoint: d0a5dd45dd45e851292a116a4c036f8725297845

Verification: six rows swept - core-alloc, core-free, realloc-family and size-introspection by `alloc-core`, aligned-alloc by `alloc-aligned`, u-api by `u-api` - leaving 20 unswept of 27 total. `alloc-core` reports 10611/10611, `alloc-aligned` 15807/15807, `u-api` 368/378 red at the three sites H2 names. The verify gate through `quiet-verify.sh` is green in 32s, reporting `100% tests passed, 0 tests failed out of 7` for each of the two configurations. `check-claims.sh` over the whole probe directory reports 8 checked, 0 mismatched, 0 errored, 0 skipped.

Each new battery carries a discriminating record rather than an assertion that it works. `alloc-core` has a mutation making `mi_zalloc` pass `false` for its zero flag, which takes it to 10602/10611; `alloc-aligned` has one making `mi_zalloc_aligned` delegate to `mi_theap_malloc_aligned`, dropping the zeroing while keeping the alignment, which takes it to 15759/15807. Both are recorded as claims and both restore the file by copy. `u-api` needs no mutation while it stands red on real code: it is the instrument that filed H2.

The sweep filed one High. `u-api` compares every block-size out-parameter against `mi_usable_size` of the block returned, and found `mi_umalloc_aligned`, `mi_uzalloc_aligned` and `mi_urealloc`'s `pblock_size_pre` reporting more bytes than are usable at the pointer they hand back - `mi_umalloc_aligned(1, 512, &bs)` says 640 where 256 are usable. All three report `mi_page_block_size(page)`, which equals the usable size only when the returned pointer is the block start, and an aligned allocation may shift it inside a larger block. The enumeration is those three sites and no others: the unaligned entry points all route through `mi_ublock_size` on a path where the pointer is the block start, which an executed comparison across every u-API entry point confirmed. Filed as H2 at High because a caller that writes the reported number of bytes overruns its block.

The u-api battery asserts the invariant rather than equality for the aligned forms, and that choice is load-bearing: whether a given size and alignment shift the pointer depends on where the block lands, so an equality assertion flaps between runs. Three consecutive runs of the invariant form report the same summary, which is what makes the claims line stable enough to be worth recording.

Learnings: assert the safety invariant, not the equality, when the quantity depends on where a block happens to land - equality flapped across runs on the aligned allocators while `reported <= usable` held steady, and only the stable form can be a recorded claim. A battery built from a shared harness and a shared runner costs one small file per battery rather than one program each, which is what made sweeping four rows with one instrument affordable.

Next: H2 - derive the u-API block size from the returned pointer rather than from the page, at the point the size is taken.

## iter 4/10 | 7f2a700e-233033 | 2026-08-30 | H2 | done

Task: H2 - the `u`-API block-size out-parameter reporting more bytes than are usable at the pointer it returns. Investigating it before fixing showed the finding was over-scored, so this iteration re-scored it to M4 and closed it as a documentation defect.

Changed: `include/mimalloc.h` (the `Return allocated block size` section comment now states what `block_size` is), `.jeffy/probes/u-api/` (probe.c assertions rewritten to the documented contract, plus a balance check driven at every entry point; README.md, claims, new mutate.sh), `.jeffy/probes/run-battery.sh` (a probe that fails to compile is now an error, not an unavailable host), PLAN.md (Lessons, and six rows re-recorded), BACKLOG.md (H2 withdrawn, M4 filed and closed, one Proposed item added), JOURNAL.md.

Checkpoint: 46fb3e1e71fa2172cec53a617c3e034447a27ca1

Verification: `u-api` reports 559/559 against the documented contract, and its new mutation - `mi_ufree` reporting zero instead of the block it freed - takes it to 461/559, so the balance claim the header makes is pinned by an instrument that has been seen to fail. Every battery declaring `include/mimalloc.h` was re-run because this diff touched it: `alloc-core` 10611/10611, `alloc-aligned` 15807/15807, `csize-wrappers` 1834/1834, `option-defaults` still 18/25 red on M2 as recorded. `check-claims.sh` reports 9 checked, 0 mismatched, 0 errored, 0 skipped. The verify gate through `quiet-verify.sh` is green in 98s, reporting `100% tests passed, 0 tests failed out of 7` for each configuration.

Why H2 was withdrawn. It was filed at High on the premise that `block_size` promises the bytes usable at the returned pointer, so reporting more of them is a heap overflow waiting for a correct-looking caller. That premise is not written anywhere: the whole documentation of this family is one section comment reading `Return allocated block size`, with no entry in `doc/mimalloc-doc.h`, none in the readme, and none in the release notes, and its introducing commit calls it an initial API. The debug build then disproved the premise outright - with `MI_PADDING` on, every entry point in the family reports more than `mi_usable_size`, including the six unaligned ones, because the padding bytes belong to the block and are reserved rather than usable. A contract that no configuration implements is not the contract. What survives is real and narrower: the same out-parameter means the bytes at `p` for the unaligned forms in a release build and the containing block for the aligned ones, with nothing telling a caller which, and the only natural use of a size an allocator hands back is to size the buffer. That is a documentation defect on a public API, filed as M4 at Medium and closed here.

M4 closed: the section comment now says `block_size` is the whole block's size, names the two cases where it exceeds the bytes at `p` - an aligned pointer placed inside a larger block, and padding - gives the measured example `mi_umalloc_aligned(100, 512, &bs)` reporting 640 where 256 are available, and points at `mi_usable_size` for what may be written. Contract preserved: no code path changed, so no caller's behaviour moves; what changed is that the header now describes the figure the code has always returned.

The header also makes a claim over a set - that `mi_ufree` reports the same figure the allocating call did - so the battery drives it at every entry point that writes a size rather than at one, aligned and unaligned, and it holds at all of them.

The code-level question is left to the owner as a Proposed item: making `block_size` mean the usable bytes everywhere would be safe to use as a buffer size and would change nothing for the six unaligned entry points in a release build, but it touches all seven write sites including the one in `mi_free_nonnull`, whose comment records that its fast path is written to avoid register spilling, and this tree carries no benchmark by which this run could show that costs nothing.

One instrument defect was found and fixed on the way. The shared battery runner reported `unavailable:probe did not compile` and exited 0, so when a bad edit broke `probe.c` the battery read as passing. A host that cannot build the library is genuinely unavailable; a probe that will not compile is the battery's own bug. The runner now exits 2 and prints the compiler output for the second case.

Learnings: check the other build configuration before scoring a finding that rests on an undocumented contract - `MI_PADDING` makes debug and release disagree about what a reported size means, and that disagreement is what showed the High was wrong. An instrument's failure modes need the same scepticism as the product's: a runner that maps every failure to `unavailable` turns a broken probe into a green one.

Next: the map - 20 rows are unswept with 6 iterations left, so sweeping outranks the three open Mediums.

## iter 5/10 | 7f2a700e-233033 | 2026-08-30 | SWEEP | done

Task: sweep Surface inventory rows. With no open High at the start of this iteration the map outranked the three open Mediums, and 20 rows were unswept.

Changed: new batteries at `.jeffy/probes/posix-shims/`, `heap-api/`, `theap-api/`, `options-api/`, `stats-api/` and `exported-symbols/`; `.jeffy/probes/run-battery.sh` (a build-type argument and `-ldl`); PLAN.md (seven rows flipped, three Lessons); BACKLOG.md (H3 and M5 filed); JOURNAL.md.

Checkpoint: 3ec398cb4a47bc4af9dd40934ba65b514dbcf5f6

Verification: seven rows swept, taking the map from 6 of 27 to 13 of 27 with 13 unswept and one unreachable. `posix-shims` reports 287/287, `heap-api` 1469/1469, `theap-api` 216/216, `options-api` 573/573, `stats-api` 112/112, and `exported-symbols` 192/194, red at the two symbols H3 names. `check-claims.sh` over the whole probe directory reports 20 checked, 0 mismatched, 0 errored, 0 skipped. The verify gate through `quiet-verify.sh` is green in 31s, reporting `100% tests passed, 0 tests failed out of 7` for each of the two configurations.

The sweep filed one High and one Medium. H3: `mi_stats_merge` and `mi_collect_reduce` are declared `mi_decl_export` in the public header, and `mi_stats_merge` is documented in `doc/mimalloc-doc.h`, but neither is defined in the shared library or the archive, so a program calling either fails to link against what this project installs. Found because the stats battery would not link, and confirmed by compiling a one-line program and reading `undefined reference to 'mi_stats_merge'`, then by `nm -D`. The enumeration is a battery rather than a claim: an earlier draft of it reported six missing symbols, four of which were commented-out declarations its grep did not skip. M5: `mi_stat_count_t.current` is documented as the current allocation, but after 128 blocks of 512 bytes are allocated into a fresh heap and every one is freed, `malloc_normal.current` and `malloc_requested.current` both still report the full amount and a collect does not move them. Medium rather than High because statistics are compiled out in a release build, so a user of the default configuration does not meet it.

The posix-shims battery was written twice, and the reason is the substantial finding of this iteration about instruments rather than about mimalloc. Its first draft was a differential against libc - the strongest oracle available - and it was worthless: this probe links `libmimalloc.a`, which is built with `MI_OVERRIDE` and therefore defines `malloc`, `free`, `strdup`, `strndup`, `posix_memalign` and `reallocarray` itself, so every call to a bare libc name resolved to mimalloc and the differential compared mimalloc against mimalloc. The mutation is what exposed it: changing `mi_reallocarray`'s overflow errno from `EOVERFLOW` to `ENOMEM` left the battery reporting 272 of 272 checks passed, because the reference moved with the subject. Resolving libc through `dlsym` fixed the symbol and not the problem - glibc's `strdup` allocates through whichever `malloc` the process bound, so freeing its result with libc's `free` crosses allocators, and the probe segfaulted. The reference is now written in the probe itself, `realpath` is kept as the one true differential because mimalloc does not override it, and the mutation now moves the battery to 286 of 287.

Three assertions were weakened after measurement rather than filed as findings, each with the measurement recorded in the battery. `peak_rss` is no longer compared against `rss`: it comes from `getrusage`'s `ru_maxrss`, which on this host reads below the kernel's own `VmHWM` while `VmHWM` equals `VmRSS`, so the discrepancy is the platform's and the envelope classes OS facilities machine-generated. Bin-size monotonicity is asserted over bins 0 to 72 and not over bin 73, `MI_BIN_HUGE`, whose nominal size measures smaller than its predecessor's with nothing documenting what it should mean. And `mi_stats_t` is a versioned struct that refuses a zeroed argument by design, which was the probe's error and is now checked in both directions.

The stats battery links the debug build, because `MI_STAT` is 0 in release and 2 in debug: a release-linked statistics battery would have read zero for every counter and passed vacuously. `run-battery.sh` grew a build-type argument for it.

Learnings: a differential is only as good as the independence of its reference, and linking the subject can silently supply the reference - the mutation, not the reading, is what proves independence. Weakening an assertion is legitimate when the measurement says the assertion was wrong, but the measurement belongs in the battery beside the weakened check, or the next reader cannot tell a considered limit from an oversight.

Next: the map - 13 rows are unswept with 5 iterations left, so sweeping still outranks the two open Highs' successors on the ledger.

## iter 6/10 | 7f2a700e-233033 | 2026-08-30 | H3 | done

Task: H3 - `mi_stats_merge` and `mi_collect_reduce` declared `mi_decl_export` in the public header but absent from the library, so a program calling either fails to link.

Changed: `src/stats.c` (`mi_stats_merge` implemented), `include/mimalloc.h` (the `mi_collect_reduce` declaration removed), `.jeffy/probes/stats-api/` (a behavioural check for the merge, a new mutation, README, claims), `.jeffy/probes/exported-symbols/` (mutation, README, claims), PLAN.md (Settled classes, thirteen rows re-recorded, two Lessons), BACKLOG.md (H3 closed), JOURNAL.md.

Checkpoint: 8b8345c726eac8a405ad698392631660f74df15d

Verification: `exported-symbols` reports 193/193 with no MISSING line, against 192/194 before, and its mutation - re-declaring `mi_collect_reduce` - takes it to 193/194. `stats-api` reports 116/116 and its new mutation takes it to 115/116. A one-line program calling `mi_stats_merge` links against `out/jeffy-Release/libmimalloc.a` and exits 0. Every battery declaring `include/mimalloc.h` or `src/stats.c` was re-run: `alloc-core` 10611/10611, `alloc-aligned` 15807/15807, `csize-wrappers` 1834/1834, `heap-api` 1469/1469, `theap-api` 216/216, `options-api` 573/573, `posix-shims` 287/287, `u-api` 559/559, `option-defaults` still 18/25 red on M2. `check-claims.sh` reports 21 checked, 0 mismatched, 0 errored, 0 skipped. The verify gate is green in 39s, reporting `100% tests passed, 0 tests failed out of 7` for each configuration.

The two symbols needed opposite remedies, and the history decided which. `mi_collect_reduce` entered in commit 9b7ac9a1, which added the declaration to the header and the definition to `src/segment.c`; commit 67cc424a deleted `src/segment.c` entire in the v3 rewrite and left the declaration behind. Its body worked in segments and `mi_option_target_segments_per_thread`, concepts v3 does not have, and it carries no entry in `doc/mimalloc-doc.h`. Re-implementing it would mean inventing semantics for an abstraction that no longer exists, which the Constraints forbid, so the declaration is removed. That is a public interface change and the rationale is this: nothing can be calling it, because it has never linked in any v3 build, so removing it cannot break a working program, while leaving it promises an entry point that does not exist. `mi_stats_merge` is the opposite case - `doc/mimalloc-doc.h` documents it and marks it a v1/v2 API, and of the two functions the doc marks that way its sibling `mi_stats_reset` is still declared and still defined in v3. So it is the odd one out of its own pair rather than a deliberate removal, its documented semantics still mean something in v3, and it is implemented rather than deleted.

Contract preserved: `mi_stats_merge` does in v3 what the documentation says it did in v1 and v2 - merges the calling thread's statistics into the process-wide statistics and resets them. In v3 a thread's figures live in its theap, so the merge runs theap into heap and then heap into subproc, and `_mi_stats_merge_into` zeroes the source at each step, which is where the reset comes from. No existing code path changed; a symbol that did not resolve now does.

The acceptance check is behavioural rather than linkage, because an empty function links perfectly well, and getting it right took two attempts for a reason worth recording. The first draft read the process-wide total before the merge and after it. Reading process-wide statistics aggregates by visiting heaps, and that visit merges each live theap into its heap destructively - so the read drained the theap, and the reset the check then observed was the read's doing. The mutation is what exposed it: replacing the merge with an add that never resets left the battery reporting every check passed. Restructured to read nothing process-wide until after the merge, the same mutation now moves it to 115 of 116.

Confirming the fix also caught a stale artifact. The `exported-symbols` battery builds only the shared library, so the first check of the fix linked against a `libmimalloc.a` that predated it and reported the symbol still missing. Both targets are built before that claim is made now.

Learnings: reading process-wide statistics has the side effect of merging live theaps into their heaps, so a probe that reads before it acts has already changed what it is measuring - order the reads, or the check cannot fail. Where a symbol is declared but never defined, the history says which remedy is right: a definition deleted with the module that held it is an orphan to remove, while one whose documented sibling survives is an omission to fill.

Next: the map - 13 rows remain unswept with 4 iterations left, so sweeping outranks the four open Mediums.

## iter 7/10 | 7f2a700e-233033 | 2026-08-30 | SWEEP | done

Task: sweep Surface inventory rows. No open High at the start of this iteration, so the map outranked the four open Mediums, with 13 rows unswept.

Changed: new batteries at `.jeffy/probes/libc-and-bits/` and `.jeffy/probes/page-map/`; PLAN.md (two rows flipped, one Lesson); BACKLOG.md (L2 filed); JOURNAL.md.

Checkpoint: 76d552002d68d28d7752ee736e63755bd28c9cad

Verification: two rows swept, taking the map from 13 of 27 to 15 of 27 with 11 unswept and one unreachable. `libc-and-bits` reports 2177/2177 and its mutation - `_mi_toupper` made a no-op - takes it to 2092/2177. `page-map` reports 12217/12217 and its mutation - `mi_heap_contains` answering for any non-NULL pointer - takes it to 10169/12217. `check-claims.sh` reports 25 checked, 0 mismatched, 0 errored, 0 skipped. The verify gate is green in 34s, reporting `100% tests passed, 0 tests failed out of 7` for each configuration.

`libc-and-bits` is the strongest oracle in the probe set so far, because these functions have genuine independent references and mimalloc does not override them the way it overrides the malloc family. The formatter is compared byte for byte against this host's `snprintf` over a generated matrix of flags, widths, length modifiers, conversions and values. It found 191 differences on its first run, which took some care to score honestly, because they were three different things wearing one shape.

The uppercase hex is not a defect. `mi_out_num` emits uppercase throughout and every `%x` in the tree is mimalloc's own output, so it is a consistent style choice rather than a divergence from an intended contract; the comparison is now case-insensitive with that reason recorded beside it. `%p` was already excluded for the same kind of reason - mimalloc documents its own layout - and is checked against that shape instead.

What is left is real and is filed as L2: zero-padding a signed value emits the sign after the padding, so `%05d` of -1 gives `000-1` where C gives `-0001`, and the left-align flag does not suppress zero fill, so `%-05d` of 7 gives `70000` where C gives `7` and four spaces. It is Low rather than higher because no call site reaches it, and that is enumerated rather than asserted: the format specifiers the tree passes to this formatter come from a grep over `src/*.c`, `src/prim/*.c` and `src/prim/unix/*.c`, and the only zero-padded numeric among them is `%03zu`, which is unsigned, with no left-align-and-zero-fill anywhere. A user of the shipped product never meets the wrong output. The three assertions now hold the current behaviour still so a change is noticed, and become differentials when L2 is fixed.

`page-map` is a lookup whose answer the probe already knows, so it is checked against that: blocks allocated interleaved across four heaps and eight size classes, each looked up against the heap it came from and against one it did not, aligned blocks included because there the pointer is not the block start. The negative side carries as much weight - stack, static, code and NULL addresses must not resolve, since a map answering yes to everything would satisfy every positive check - and the last section churns pages until they retire and are replaced, then confirms the survivors still resolve.

Learnings: when a differential reports many differences, group them before scoring any of them - these 191 were three unrelated things, one a style choice, one a documented design, and only the third a defect, and treating the count as one finding would have been wrong three ways. Exclude a case from a differential only with the reason written beside it, because an unexplained exclusion and an overlooked defect are indistinguishable to the next reader.

Next: the map - 11 rows remain unswept with 3 iterations left, so sweeping still outranks the four open Mediums.

## iter 8/10 | 7f2a700e-233033 | 2026-08-30 | SWEEP | done

Task: sweep Surface inventory rows. No open High at the start of this iteration, so the map outranked the four open Mediums, with 11 rows unswept.

Changed: a new battery at `.jeffy/probes/cpp-new-delete/`; PLAN.md (one row flipped, one Lesson); BACKLOG.md (H4 filed); JOURNAL.md.

Checkpoint: 33e0c57bd5ef1432d133f8e402b3b8e4d5b0698e

Verification: one row swept, taking the map from 15 of 27 to 16 of 27 with 10 unswept and one unreachable. `cpp-new-delete` reports 99/99 and its mutation - removing the `count * size` overflow guard from `mi_theap_alloc_new_n` - takes it to 95/99. `check-claims.sh` reports 27 checked, 0 mismatched, 0 errored, 0 skipped. The verify gate is green in 34s, reporting `100% tests passed, 0 tests failed out of 7` for each configuration.

One row rather than the several the sweep rate projected, because the row turned up a High and running it down was worth more than the rows it cost. `mi_new` on an unsatisfiable size aborted the probe. `include/mimalloc.h` says the `mi_new` wrappers call `std::get_new_handler` and may raise `std::bad_alloc`, so the abort was worth following.

The root cause is one weak symbol. To reach `std::get_new_handler` without requiring a C++ build, `src/alloc.c` defines a weak `_ZSt15get_new_handlerv` that returns NULL, and `MI_USE_CXX` defaults OFF so the default build ships it. Measured three ways. With the default build's `libmimalloc.a` statically linked into a C++ program, `std::get_new_handler()` returns null immediately after `std::set_new_handler` installed one, and the handler is called 0 times - the stub wins over the standard library's definition for the whole program. With a `-DMI_USE_CXX=ON` build, the same program reads the real handler and it is called 4 times. With the shared library the symbol is not exported, so the program's own lookup is correct while mimalloc's internal one still is not. Filed as H4 at High: the static case is a wrong answer from a standard library function on ordinary input, needing no out-of-memory condition to observe, and the consequence on the out-of-memory path is that `mi_new` kills the process where the header promises C++ semantics.

Two build facts shaped the battery and are recorded in it. The static library already carries the operator new and delete replacements, so including `mimalloc-new-delete.h` in the probe as well is a multiple-definition link error; the header is for builds whose library does not provide them, so `run.sh` checks it compiles standalone rather than linking it twice. And the throwing out-of-memory path is left out of the battery entirely, because provoking it under the default build kills the probe - the nothrow forms are exercised on the same input instead, since they return null safely either way.

What the battery does check is that global `operator new` and `delete` route into mimalloc, and it asks that as an ownership question of every object it allocates - scalars, arrays, an over-aligned type, a `std::vector`'s buffer, a long `std::string`'s buffer. Ownership is the only way to tell a working replacement from one that compiled and did nothing.

Learnings: a probe that dies is evidence, not an obstacle - this iteration's High was found because a check aborted the process rather than failing, and the abort was the finding. When a library offers a C build and a C++ build of the same entry point, measure both before scoring anything about it: the same program links to different behaviour, and the default is the one users get.

Next: the map - 10 rows remain unswept with 2 iterations left, and iteration 10 is the final one, so iteration 9 sweeps what it can and iteration 10 writes the handoff.

## iter 9/10 | 7f2a700e-233033 | 2026-08-30 | H4 | done

Task: H4 - a weak `_ZSt15get_new_handlerv` definition in `src/alloc.c` preempting the standard library's for the whole program, so a C++ program statically linking mimalloc saw its own `std::get_new_handler()` return null, and mimalloc never found an installed handler.

Changed: `src/alloc.c` (the weak definition replaced by a weak declaration), `include/mimalloc.h` (the `mi_new` comment now states which build raises `std::bad_alloc`), `.jeffy/probes/cpp-new-delete/` (handler checks restored, a mutation that reinstates the defect, README, claims), PLAN.md (sixteen rows re-recorded, one Lesson), BACKLOG.md (H4 closed), JOURNAL.md.

Checkpoint: 2038f07cb41d41844dcdcc14d6829383c6c9e97c

Verification: measured on the same C++ program before and after, statically linked against the default build. Before: `std::get_new_handler()` returned nil immediately after `std::set_new_handler` installed a handler, the handler was called 0 times, and `mi_new` on an unsatisfiable size aborted. After: `std::get_new_handler()` returns the installed handler, mimalloc calls it 4 times, and `mi_new` returns null rather than aborting. The static archive no longer defines `_ZSt15get_new_handlerv` at all, and a plain C program still links and runs with no undefined reference, which was the case the weak definition existed to serve. `cpp-new-delete` reports 105/105 with the handler checks restored. Every battery declaring `src/alloc.c` or `include/mimalloc.h` was re-run: `alloc-core` 10611/10611, `alloc-aligned` 15807/15807, `csize-wrappers` 1834/1834, `heap-api` 1469/1469, `theap-api` 216/216, `options-api` 573/573, `posix-shims` 287/287, `u-api` 559/559, `stats-api` 116/116, `exported-symbols` 193/193, `option-defaults` still 18/25 red on M2. `check-claims.sh` reports 27 checked, 0 mismatched, 0 errored, 0 skipped. The verify gate is green in 66s, reporting `100% tests passed, 0 tests failed out of 7` for each configuration.

The fix is one line of linkage. A weak *definition* of a foreign symbol is exported from the static archive and wins for the whole program; a weak *declaration* binds to the standard library's definition when the program has one and stays null in a plain C program, which is the case the original code was reaching for. Contract preserved: the C build still cannot raise `std::bad_alloc`, a plain C program still links with no C++ runtime, and the only behaviour that changed is that an installed handler is now found and called instead of being invisible.

What is not fixed, and is now stated in the header rather than left implied: a default build is plain C, so it cannot raise `std::bad_alloc` itself, and an exception thrown by a new handler cannot unwind through its frames - a throwing handler terminates the process whatever mimalloc does. `MI_USE_CXX=ON` gives the throwing behaviour. The header previously said the wrappers "potentially raise a `std::bad_alloc` exception" without saying which build makes that true; it now names the option, says the default is off, and says what the C build does instead.

The battery's mutation is the finding itself: it restores the weak definition, and its observable effect is that the probe dies rather than reporting a count. Rather than leave a claim with nothing to compare, the mutation reports the signal, so `killed by signal 6 under the restored defect` is the recorded value - which is also the most honest single sentence about what the defect did to any program that reached it.

Learnings: never define a weak stub for a symbol another library owns - declare it weakly instead, because a weak definition in a static archive preempts the real one for every translation unit in the program, not just for the library that wrote it. When a mutation kills the probe instead of reddening it, that outcome is the claim worth recording rather than a reason to pick a gentler mutation.

Next: iteration 10 is the final one, and the ledger holds four open Mediums against ten unswept rows, so it writes the handoff rather than starting work that cannot finish.

## iter 1/10 | 4fefea3e-004657 | 2026-08-30 | SWEEP | done

Task: sweep Surface inventory rows. New run, clean tree, no open High, so the map outranked the four open Mediums with 10 rows unswept and 16 swept.

Changed: new batteries at `.jeffy/probes/random/`, `.jeffy/probes/internal-headers/`, `.jeffy/probes/arena-api/` and `.jeffy/probes/subproc-thread-lifecycle/`; PLAN.md (four rows flipped, three Lessons); JOURNAL.md. No source file changed this iteration.

Checkpoint: 6eabbb33a1d20a289d3f3a06e1f13accc4a882dd

Verification: four rows swept, taking the map from 16 of 27 to 20 of 27 with 6 unswept and one unreachable. `random` reports 4139/4139 and its mutation - the chacha round count taken from 20 to 12 - takes it to 283/4139. `internal-headers` reports 24777/24777 and its mutation - one splitmix64 constant changed - takes it to 19777/24777. `arena-api` reports 728/728 and its mutation - `mi_arena_contains` answering for any non-NULL pointer - takes it to 715/728. `subproc-thread-lifecycle` reports 1038/1038 and its mutation - `mi_subproc_new` handing back the main subprocess - takes it to 1026/1038. `check-claims.sh` reports 35 checked, 0 mismatched, 0 errored, 0 skipped. The verify gate is green in 31s, reporting `100% tests passed, 0 tests failed out of 7` for each configuration. No finding was filed: every check that failed on first run was the probe's own mistake, and each is recorded below.

`random` is the strongest oracle in the probe set. chacha20 is a published algorithm with a published test vector, so the battery does not ask whether the stream looks random - it asks whether it is the exact stream the algorithm defines. The RFC 8439 section 2.3.2 vector is hardcoded and matched word for word, and because that vector reaches only one key, one counter and one nonce, a from-spec reference in the probe is checked against it and then used as the differential over a matrix four blocks deep. The 64-bit counter spread across two state words is where a hand-rolled generator goes wrong, so its carry into the nonce word is named explicitly rather than left to the matrix. mimalloc's generator matched the published vector exactly on the first run.

`internal-headers` grades the atomics twice, and the split matters. Single-threaded checks pin the return-value contract, because fetch-add returning the value after the addition rather than before is a defect that passes every liveness check while being off by one at every call site. Eight threads and twenty thousand increments each then grade atomicity itself, where the known answer is an exact product a non-atomic increment cannot reach.

Two probe mistakes are worth recording because both looked like findings. The first: a new heap does not share the default theap, so asserting that it does is wrong - the real contract is a round trip, and the check now requires a heap's theap to report that heap back. The second: sixteen threads created and then joined are not necessarily alive at the same moment, so a finished thread's theap address can legitimately be reused and the no-sharing claim failed. A barrier fixes the claim rather than weakening it.

One invented invariant also failed and was removed: `mi_arena_max_object_size` is not bounded by `mi_arena_min_size` - it is driven by the `arena_max_object_size` option and clamped between a floor and a fixed maximum, which the battery now grades at values that must change the answer. Checking the implementation before scoring it is what kept this out of the ledger.

Learnings: a probe including mimalloc's internal headers must define NDEBUG before them, because their inline bodies call `_mi_assert_fail` and only a debug library defines it while the batteries link the Release archive. Choose a mutation for blast radius: `_mi_align_up` and `_mi_divide_up` were the first candidates for `internal-headers` and both abort the process inside glibc rather than reddening checks, which turns the recorded claim into a signal instead of a count. And a claim that two threads do not share something needs a barrier holding them alive together, or address reuse reads as a defect.

Next: the map - 6 rows remain unswept (bitmap, page-management, override-layer, os-layer-posix, build-packaging, docs-public) with 9 iterations left, so sweeping still outranks the four open Mediums.

## iter 2/10 | 4fefea3e-004657 | 2026-08-30 | SWEEP | done

Task: sweep Surface inventory rows. No open High, so the map still outranked the four open Mediums, with 6 rows unswept.

Changed: new batteries at `.jeffy/probes/bitmap/` and `.jeffy/probes/page-management/`; `.jeffy/probes/subproc-thread-lifecycle/` (a second barrier, README, claims); PLAN.md (two rows flipped, one re-recorded, three Lessons); BACKLOG.md (L3 and L4 filed); JOURNAL.md. No source file changed this iteration.

Checkpoint: 0b1540de80528b4ba04833e1878e04e7f7cd0c60

Verification: two rows swept, taking the map from 20 of 27 to 22 of 27 with 4 unswept and one unreachable. `bitmap` reports 2240/2249 - red by design at exactly the checks L3 names - and its mutation, `mi_bitmap_popcountN` counting whole ranges, takes it to 2085/2249. `page-management` reports 334/334 and its mutation, one bit off the sub-bin selector, takes it to 325/336. `subproc-thread-lifecycle` now reports 1039/1039 with its mutation at 1030/1039. `check-claims.sh` reports 41 checked, 0 mismatched, 0 errored, 0 skipped. The verify gate is green in 35s, reporting `100% tests passed, 0 tests failed out of 7` for each configuration.

The bitmap is the one module here where a complete independent reference is cheap, so the battery keeps one: a byte array shadowing the same bits, with every operation applied to both and the whole bitmap compared bit by bit afterwards. That found L3 on the first run. `mi_bchunks_unsafe_setN` marks `ceil(n / MI_BCHUNK_BITS)` chunks in the chunkmap, which is the right count only when the range starts on a chunk boundary; a range starting part-way in spans one more. The bits themselves are correct - the bit-by-bit comparison passes - and only the operations that scan through the chunkmap fail to see them, which is why a liveness probe would never have found it.

Scoring L3 took the rest of the iteration and was worth it. The arithmetic says the miscount needs a range that both starts part-way into a chunk and ends before the bitmap's last chunk boundary, and every in-tree call site either starts on a boundary or runs to the end of a chunk-multiple bitmap. Arithmetic is not evidence, so `reachability.sh` instruments the function to report every call where the two counts disagree, rebuilds, and drives the tree two ways: the `bitmap` battery as a positive control, because it calls the function with ranges that deliberately cross, and the project's own ctest suite in both configurations plus every other battery as the subject. It prints `control 3 subject 0`. The control is what makes the subject number mean anything - without it, a zero could equally mean the instrument was never compiled in. So the defect is real and latent, and Low is the rubric's answer for something a user of the shipped product never meets.

Three probe mistakes are recorded because each looked like a finding. The first exploration program called functions and read their out-parameters in the same `printf`, and gcc evaluates arguments right to left, so every reported value was stale and several contracts looked inverted. The second was assuming `mi_bin` round-trips over every bin: its alignment rounding skips bins entirely on this configuration, and bins past the large-object maximum are never reached by any size, so the claim has to be made about the reachable set - which the battery now measures rather than assumes. The third was assuming `mi_page_immediate_available` becomes true when a block is freed; it reads the page's own free list, which a freed block reaches only at a collect, so the battery checks the consequence instead.

L4 came out of the same section. The comment above `mi_bin` says the top three bits pick the bin, at "~12.5% worst internal fragmentation", but the expression divides each octave into four size classes rather than eight. `measure-fragmentation.sh` walks every size and reports the worst ratio above the word-rounding floor as one in four. It is a comment in an internal source file, so a user of the shipped product never reads it, and it is filed at Low as class docs.

One thing was noticed and deliberately not filed: neither header comment for `_mi_bitmap_forall_setc_ranges` nor `_mi_bitmap_forall_setc_rangesn` says that the walk clears the bits it visits, though both do. The `c` in the name carries it, `_mi_bitmap_forall_set` without the `c` is the non-clearing form, and the only caller in the tree is the purge path, which wants the clear. There is no observed wrong reading to point at, so it goes here rather than into the ledger.

`check-claims.sh` earned its place this iteration. The subprocess battery had barriered only its sixteen-worker group, leaving the three-worker group's theap comparison flapping between two summaries; the mismatch showed up as soon as the claim was recorded rather than after a future run blamed the product.

Learnings: never call a function and read its out-parameter in the same `printf` - C leaves argument evaluation order unspecified and gcc reads the variable first, so the printed value is stale. Measure which cases a mapping actually produces before asserting a round trip over all of them. And when a battery pins a filed finding it is red by design, so record the red summary in `claims` so drift is still detected.

Next: the map - 4 rows remain unswept (override-layer, os-layer-posix, build-packaging, docs-public) with 8 iterations left against four open Mediums and four open Lows, so sweeping still comes first.

## iter 3/10 | 4fefea3e-004657 | 2026-08-30 | SWEEP | done

Task: sweep Surface inventory rows. No open High at the start of this iteration, so the map still outranked the four open Mediums, with 4 rows unswept.

Changed: new batteries at `.jeffy/probes/os-layer-posix/` and `.jeffy/probes/build-packaging/`; PLAN.md (two rows flipped, three Lessons); BACKLOG.md (H5 filed); JOURNAL.md. No source file changed this iteration.

Checkpoint: de5075347223598dc78902403722b2a78c1db440

Verification: two rows swept, taking the map from 22 of 27 to 24 of 27 with 2 unswept and one unreachable. `os-layer-posix` reports 172/172 and its mutation - the offset compensation dropped from `_mi_os_alloc_aligned_at_offset` - takes it to 164/172. `build-packaging` reports 36/39, red by design at the checks H5 and M3 name, and its mutation - the CMake package config installed one directory away from where `find_package` searches - takes it to 32/39. `check-claims.sh` reports 45 checked, 0 mismatched, 0 errored, 0 skipped. The verify gate is green in 31s, reporting `100% tests passed, 0 tests failed out of 7` for each configuration.

The OS layer is the one surface where the reference is a running kernel, and it can be asked directly: the page size against `sysconf`, the overcommit answer against `/proc/sys/vm/overcommit_memory`, the reported virtual address bit count against a real mapping. Where no query exists the effect is observed rather than inferred, and that is what the battery is really for - protect, guard-page and decommit are all graded by touching the memory afterwards under a SIGSEGV handler, or by reading what comes back. A decommit that quietly did nothing returns success either way.

Two return values had to be read before they could be graded. `_mi_os_purge` returns `needs_recommit`, not success, and on this host that is false because `MADV_DONTNEED` needs no recommit; a battery that scored the return as success would have filed a defect that is not there. And `_mi_os_secure_guard_page_size()` is zero in a build without `MI_SECURE`, so the guard-page entry points are no-ops that report success - the battery grades that as the contract it is and records that their faulting behaviour is unreachable here.

H5 came out of the packaging sweep and is the first High this run. The battery does not list the files an install produced; it consumes the install from two separate projects, one through the CMake package config and one through the pkg-config file, compiling and running each. The CMake consumer works. The pkg-config consumer does not compile at all: the default install puts the public headers in `<prefix>/include/mimalloc-<version>/`, while the generated `mimalloc.pc` sets `includedir` to `<prefix>/include`, so `#include <mimalloc.h>` is not found. `CMakeLists.txt` derives the two `.pc` paths from `CMAKE_INSTALL_INCLUDEDIR` and `CMAKE_INSTALL_LIBDIR` instead of from the `mi_install_incdir` and `mi_install_objdir` it installs to.

Scoring it took care in two directions. The link half was checked separately from the compile half and passes, because the shared library and its unversioned symlink do land directly in `<prefix>/lib` - an earlier version of this battery reported the symlink missing, which was an artifact of using `find -type f`. And the same tree was built and installed with `MI_INSTALL_TOPLEVEL=ON`, where the layout and the `.pc` agree and the consumer compiles, which bounds the finding to the default layout rather than to pkg-config in general. The rubric calls a broken build or install a user performs High, the envelope's user-error class for build configuration does not apply because no wrong value is supplied - this is the default - and the class is build-ci, so the line carries its Consequence.

The mutation for the packaging battery is worth recording for what it revealed rather than for what it broke. Moving the installed headers into a subdirectory reddens nothing, because the checks locate them with `find` and the CMake package exports whatever directory they landed in. Only the pkg-config path, which hard-codes a directory instead of following the install, is visible to this battery - which is the same asymmetry that lets H5 exist.

Learnings: a claims line for a battery that exits non-zero must end in `| tail -n 1`, or `check-claims.sh` records it as ERROR instead of comparing the summary text. Grade an install by consuming it from a separate project rather than by listing the files it produced. And `find -type f` hides symlinks, so an install check written that way reports a missing `.so` that is actually there.

Next: H5 is an open High and outranks the two remaining unswept rows, so the next iteration fixes it; override-layer and docs-public follow.

## iter 4/10 | 4fefea3e-004657 | 2026-08-30 | H5 | done

Task: H5 - the generated `mimalloc.pc` pointed `includedir` at `${prefix}/include` while the default install layout puts the public headers in `${prefix}/include/mimalloc-<version>/`, so a program built with `pkg-config --cflags mimalloc` could not find `mimalloc.h` at all.

Changed: `CMakeLists.txt` (the two `.pc` path variables now follow the directories the install writes to, and a third added), `mimalloc.pc.in` (`objdir` defined and put on the library search path), `.jeffy/probes/build-packaging/` (a new `pc-paths.sh` enumeration, README, claims), PLAN.md (one row re-recorded), BACKLOG.md (H5 closed, one Settled class recorded), JOURNAL.md.

Checkpoint: bc622641bae51ddb03d00834ec27ec27250b4c6a

Verification: the filed reproduction was run first and failed as filed - `bash .jeffy/probes/build-packaging/run.sh` reported both H5 checks red at 36/39. After the fix the same battery reports 38/39 with only M3's check red, and its mutation moves to 34/39. Measured directly as well: with the default layout the generated `.pc` now reads `includedir=${prefix}/include/mimalloc-3.5` and `objdir=${prefix}/lib/mimalloc-3.5`, a program compiled with the reported cflags and libs links and prints 30500, and the same program built with `--libs --static -static` also links and runs. The `MI_INSTALL_TOPLEVEL=ON` layout is unchanged - `includedir=${prefix}/include`, `libdir` and `objdir` both `${prefix}/lib` - and still compiles and runs. Both batteries declaring the changed paths were re-run: `build-packaging` 38/39 and `exported-symbols` 193/193. `check-claims.sh` reports 46 checked, 0 mismatched, 0 errored, 0 skipped. The verify gate is green in 34s, reporting `100% tests passed, 0 tests failed out of 7` for each configuration.

The contract the change preserves is the meaning of every field in the `.pc` file; only the directories they name changed, and only in the layout where they were wrong. `prefix`, `libdir`, `Name`, `Description`, `Version`, `URL`, `Libs.private` and `Cflags` are untouched in form. In the toplevel layout `mi_install_incdir` equals `CMAKE_INSTALL_INCLUDEDIR` and `mi_install_objdir` equals `CMAKE_INSTALL_LIBDIR`, so the only textual difference there is a duplicated `-L`, which is why that configuration was checked before and after rather than reasoned about.

The fix is the class rather than the instance. The root cause is that the `.pc` path variables were derived from the standard install directories instead of from the ones this project installs to, and `includedir` was one of two variables with that shape; the static library had the same problem in a quieter form, reachable only when someone asks pkg-config for a static link. Both are fixed and the class is recorded as settled with `pc-paths.sh` as its enumeration - it takes the path variables from `mimalloc.pc.in` rather than from a list, resolves each through pkg-config against a real install, and requires the directory to hold what the field is for.

The two H5 checks stay in the battery as the standing regression: the `.pc` include directory must be the directory the headers landed in, and a program must compile against the cflags pkg-config reports. The toplevel check, which was written to bound the finding, is now the check that the fix did not break the layout that already worked.

Learnings: none new this iteration; the rules that mattered were already in Lessons - grade an install by consuming it from a separate project, and check the other build configuration before scoring a finding on it.

Next: two rows remain unswept, override-layer and docs-public, and the map outranks the four open Mediums, so the next iteration sweeps them.

## iter 5/10 | 4fefea3e-004657 | 2026-08-30 | SWEEP | done

Task: sweep the last two Surface inventory rows, override-layer and docs-public. No open High at the start of this iteration, so the map outranked the four open Mediums.

Changed: new batteries at `.jeffy/probes/docs-public/` and `.jeffy/probes/override-layer/`; PLAN.md (two rows flipped, three Lessons); BACKLOG.md (M6 filed); JOURNAL.md. No source file changed this iteration.

Checkpoint: 367cf044e871c157f5d37875ed12f97ca3cecbeb

Verification: two rows swept, taking the map from 24 of 27 to 26 of 27 swept with no unswept row left and one unreachable. `override-layer` reports 23/23 and its mutation - the guard that admits the override definitions turned off - takes it to 16/23. `docs-public` reports 14/17, red by design at the checks M6 names, and its mutation - one readme link pointed at a file that is not in the tree - takes it to 13/17. `check-claims.sh` reports 50 checked, 0 mismatched, 0 errored, 0 skipped. The verify gate is green in 37s, reporting `100% tests passed, 0 tests failed out of 7` for each configuration.

The override layer has exactly one question worth asking and it is not liveness: when a program calls plain `malloc`, does the block come from mimalloc or from libc? `mi_check_owned` answers it exactly. The probe that asks never includes `mimalloc.h` for its allocation calls, so the names it calls are whatever the link or the preload resolved, and every block it takes is freed through those same plain names. Each mode is a separate program because they are separate mechanisms: the static archive, the object file `mimalloc-obj` produces, a hand compile of `static.c`, the override header, the shared library, and `LD_PRELOAD` over a program with no mimalloc in its link. That last case carries a control - without the preload the same program must find no mimalloc in its process - because otherwise it proves nothing. All of it is green, and it is worth noting that none of this surface is reachable from the Verify command, whose Environment fingerprint records that the project's own override tests are outside it.

One probe mistake nearly became a filed defect. A hand compile of `src/static.c` without `-DMI_MALLOC_OVERRIDE=1` builds a perfectly working allocator that defines none of the plain names, and the battery duly reported that the single-object build does not override anything. The CMake build passes that define through `mi_defines` when `MI_OVERRIDE` is on. The battery now grades the object the project itself produces first, which is what a user gets, and compiles `static.c` by hand only as a self-containment check.

M6 is one task rather than three. The documentation names things the library does not have in three separate places: `doc/mimalloc-doc.h` declares functions that exist nowhere in the headers, the sources or the exported symbols; it lists `mi_option_` members the header's enum does not define, so `mi_option_set` cannot be called with them; and `readme.md` tells a user to write a `find_package(mimalloc <version>)` line whose major the installed package config refuses - confirmed by configuring that exact snippet against a real install and reading back `The version found is not compatible with the version requested`. M2, L1 and these share one root cause, that the documentation drifts from the header with nothing comparing them, so the three-strike rule applies and the filing is a single structural task whose acceptance is the comparison itself.

The battery treats the two directions differently on purpose. A documented name that does not exist breaks a user's build the moment they copy it, so that fails. A name that exists but is undocumented is a gap rather than a breakage, so it is computed, printed and does not fail - and the same holds for the option enum, where a deprecated alias needs no entry in the API documentation.

Learnings: compile `src/static.c` by hand only with `-DMI_MALLOC_OVERRIDE=1`. Ask ownership rather than liveness of an interposition layer. And never run `check-claims.sh` while another command is in flight - the mutation scripts edit source files in place, so a concurrent run reports mismatches that are the overlap rather than drift, which happened once this iteration and cleared on a clean re-run.

Next: the map is complete, so the queue is the ledger - five open Mediums (M6, M5, M1, M2, M3) with five iterations left, which does not leave room for the closing audit and the evaluator gate as well, so the run will carry what it cannot close.

## iter 6/10 | 4fefea3e-004657 | 2026-08-30 | M5 | done

Task: M5 - `mi_stat_count_t.current` is documented as the current allocation, but `malloc_normal.current` and `malloc_requested.current` never fell: after allocating a hundred and twenty-eight blocks into a fresh heap and freeing every one, both still read their full allocated values, and a collect did not move them.

Changed: `src/free.c` (`mi_stat_free` now takes the usable size its caller already computed, attributes the decrease to the accounting the matching increase used, and decreases `malloc_requested` again), `.jeffy/probes/stats-api/` (the two pinning assertions became the equalities the contract requires, two attribution cases added, paths widened to the files whose counters it grades, README, claims), PLAN.md (nine rows re-recorded), BACKLOG.md (M5 closed), JOURNAL.md.

Checkpoint: 13613c118c7fd12074fd44c8a7e6c0f263480bdc

Verification: the filed reproduction was run first and failed as filed - both figures stayed at 80896 and 65536 through the free and the collect. After the fix the same program reads 0 for both after the free, with the peak still 80896 and the total still 65536. Two further cases were measured directly: a worker thread allocating from a shared heap and the main thread freeing gives 0 to 48640 to 0 for `malloc_normal` and 0 to 44800 to 0 for `malloc_requested`, and a four-megabyte block gives `malloc_huge` 0 to 4456448 to 0 while `malloc_requested` stays at 0 across both. `stats-api` now reports 129/129 with its mutation at 128/129. Every battery declaring a path this diff touched was re-run: `alloc-core` 10611/10611, `u-api` 559/559, `csize-wrappers` 1834/1834, `posix-shims` 287/287, `cpp-new-delete` 105/105, `exported-symbols` 193/193. `check-claims.sh` reports 50 checked, 0 mismatched, 0 errored, 0 skipped. The verify gate is green in 31s, reporting `100% tests passed, 0 tests failed out of 7` for each configuration.

The defect was an attribution one, not only a missing decrement. `mi_stat_free` took the freeing thread's default theap, while the matching increase in `alloc.c` recorded on the theap the block was allocated from. Those are the same theap only for the default heap, which is why a first-class heap's figure never fell and why the default heap's looked correct. The decrease now goes to the theap that owns the page when it belongs to this thread, and otherwise to the owning heap - whose counters are updated atomically, which a foreign theap's are not. Writing another thread's theap stats directly would have traded a wrong number for a data race; the heap path already exists for exactly this and `mi_heap_stats_get` merges the theap into the heap before reading, so the figure is complete either way.

The `malloc_requested` decrement had been commented out entirely. Restoring it took two corrections. The commented line recomputed the usable size by decoding the padding a second time, which asserts once the block is on the free path; both call sites already hold that figure from their own padding check, so it is passed in instead. And the first restored version subtracted unconditionally while the increase sits inside the `bsize <= MI_LARGE_MAX_OBJ_SIZE` branch, so a huge block subtracted from a counter it had never added to and drove `malloc_requested` to -4194304. That was caught by measurement rather than by reading, and it is now a standing check in the battery.

The contract preserved: the counters keep their meaning, `total` and `peak` are untouched in behaviour, the guarded-allocation adjustment in `alloc.c` is unchanged, and all of this is inside `#if MI_STAT>0` or `MI_STAT>1`, which are zero in a release build. `mi_stat_free`'s signature changed, but it is static to `src/free.c` with two callers, both of which already had the value to pass.

The battery's paths file was widened in the same iteration: it grades counters that live in `src/free.c` and `src/alloc.c` while declaring only `src/stats.c`, so a change to the files it actually checks would not have re-run it.

Learnings: when restoring a commented-out counter update, put it in the same guard and the same branch as its increase and then measure a case on each side of that branch - an unconditional decrement paired with a conditional increase goes negative, and nothing in the suite would have said so. And a battery's paths file has to name the files its checks touch, not the file its row is about.

Next: four Mediums remain (M6, M1, M2, M3) with four iterations left, so the last is a wrapup and three can be closed; the run will not converge and will carry what it cannot close.
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

## iter 7/10 | 4fefea3e-004657 | 2026-08-30 | M1 | done

Task: M1 - an empty value for any `MIMALLOC_*` environment variable was read as the boolean 1 by `mi_option_init`, including for numeric and size-valued options, so `MIMALLOC_ARENA_RESERVE=` collapsed the arena reservation from a gigabyte to a kilobyte with no diagnostic, while every other unparseable value warns.

Changed: `src/options.c` (an empty value is the boolean "on" spelling only where the option's domain is boolean, and a numeric parse that consumed no characters is no longer a success), `.jeffy/probes/options-api/empty-value.sh` (new, the enumeration of what the rule cannot see) and its claims, PLAN.md (two rows re-recorded, two Lessons), BACKLOG.md (M1 closed, M7 filed), JOURNAL.md.

Checkpoint: f40c13440efb2bf7b68722e3069b5d4bbbae20b1

Verification: the acceptance was run as written. `MIMALLOC_VERBOSE=1 MIMALLOC_ARENA_RESERVE=` now reports `option 'arena_reserve': 1048576 KiB`, identical to the unset environment, and emits `environment option mimalloc_arena_reserve has an invalid value`; before the fix the same command reported 1 KiB and printed nothing. `MIMALLOC_VERBOSE=` still enables verbose output and prints the whole option listing, so the boolean spelling is intact. `MIMALLOC_ARENA_RESERVE=2G` still parses to 2147483648, and `MIMALLOC_PURGE_DELAY=` and `MIMALLOC_MINIMAL_PURGE_SIZE=` now warn and keep their defaults. Both batteries declaring `src/options.c` were re-run: `options-api` 573/573, and `option-defaults` still 18/25, red on M2 exactly as before. `check-claims.sh` reports 51 checked, 0 mismatched, 0 errored, 0 skipped. The verify gate is green in 33s, reporting `100% tests passed, 0 tests failed out of 7` for each configuration.

The rule the fix uses is the option's own data rather than a new table. An option whose compiled default is something other than 0 or 1 has said that its domain is not boolean, and an option that `mi_option_has_size_in_kib` classes as size-valued is not boolean whatever its default happens to be. Those two together cover every case the finding named. The second edit is the mechanism that lets an empty value reach the warning at all: `strtol` leaves `*end == 0` on an empty string, so the existing success test would have read an empty value as a successful parse of zero, silently.

What the rule cannot see is a numeric option whose default is 0 or 1, because nothing then distinguishes it from a boolean. That set is filed as M7 rather than described, and `empty-value.sh` derives it: every option whose default is 0 or 1, which is read numerically, which is not size-valued, and which is never read through `mi_option_is_enabled`. It prints seven. Closing that set needs a boolean marker in `mi_option_desc_t`, which touches every row of the option table, so it is a task of its own and not a widening of this one.

Writing that enumeration took one correction worth keeping. Reading the option names by counting `MI_OPTION(...)` occurrences in the table gives the wrong index mapping, because the table's `#if` branches declare `show_errors` twice; the names came out shifted and `arena_reserve` appeared to default to 0. The library's own `mi_options_print_out` listing is authoritative and in enum order, and the script now parses that.

Learnings: `strtol` leaves `*end == 0` on an empty string, so a parser that accepts `*end == 0` as success reads an empty value as zero - require `end != buf` too. And take an option's name-and-value listing from `mi_options_print_out` rather than by counting table lines.

Next: three iterations left and four open Mediums (M6, M7, M2, M3), so two can close and the last iteration writes the handoff; the run will not converge.

## iter 8/10 | 4fefea3e-004657 | 2026-08-30 | M7 | done

Task: M7 - after M1, an empty `MIMALLOC_*` value was still read as the boolean 1 for options that are read only numerically and whose compiled default happens to be 0 or 1, so `MIMALLOC_MAX_VABITS=` or `MIMALLOC_USE_NUMA_NODES=` silently set them to 1 with no diagnostic.

Changed: `src/options.c` (a `mi_option_is_boolean` classifier replaces the default-derived rule), `.jeffy/probes/options-api/empty-value.sh` (rewritten as a behavioural check) and its claims, PLAN.md (two rows re-recorded, one Lesson), BACKLOG.md (M7 closed, one Settled class recorded), JOURNAL.md.

Checkpoint: c6f65935d16eaf0b181878910143902ae58f12d4

Verification: `empty-value.sh` reports 0 of 47 options taking an empty value outside the boolean set, with 11 accepting one in total. It was measured against the pre-M1 rule in the same iteration to show it can fail: restoring the unconditional `buf[0] == 0` takes it to 29 of 47 outside the set and 40 accepting one. M1's acceptance still holds - `MIMALLOC_VERBOSE=1 MIMALLOC_ARENA_RESERVE=` reports `option 'arena_reserve': 1048576 KiB` with the invalid-value warning, and `MIMALLOC_VERBOSE=` still prints the whole option listing - and `MIMALLOC_MAX_VABITS=` now warns and keeps 0. Both batteries declaring `src/options.c` were re-run: `options-api` 573/573 and `option-defaults` 18/25, still red on M2 exactly as before. The verify gate is green in 29s, reporting `100% tests passed, 0 tests failed out of 7` for each configuration.

M1's rule read the option's compiled default as a statement about its domain, which is sound wherever the default is outside 0 and 1 and blind wherever it is not. The classifier replaces it with the set the library itself treats as boolean: the options it reads through `mi_option_is_enabled`. That is a list in the source, but it is a derived one - the same grep that produced it is what `empty-value.sh` re-derives to decide which options are allowed to accept an empty value, so the list and the check cannot drift apart silently.

The check is behavioural now rather than a restatement of the rule. It sets each option in turn to an empty value, compares the reported value against a clean-environment baseline, and reports any option that moved and is not in the boolean set. A check written against the parser's own condition would have reported zero however the condition was written.

Deriving the boolean set took one correction worth keeping. The first grep included `mi_option_secure`, which appears only inside a commented-out line in `src/page.c` and is not an option at all; the build failed on the undeclared name. Stripping comment lines before extracting symbols is now a Lesson, and `empty-value.sh` does the same.

The contract preserved: the boolean spelling is unchanged for every option that had it, every non-empty value parses exactly as before, and the only behaviour that changed is that an empty value on a non-boolean option now warns and keeps the default instead of silently becoming 1.

Learnings: derive a set of symbols from the sources with comment lines stripped first. And write the check for a parsing rule against the behaviour, not against the rule - otherwise it passes by construction.

Next: two iterations left and three open Mediums (M6, M2, M3), so one can close and the last writes the handoff; the run will not converge.

## iter 9/10 | 4fefea3e-004657 | 2026-08-30 | M6 | done

Task: M6 - the API documentation names things the library does not have, filed as one structural task covering documented functions that do not exist, documented options the header's enum does not define, and a readme `find_package` snippet whose major the installed package config refuses.

Changed: `doc/mimalloc-doc.h` (one declaration removed, one option marked with the version it belongs to), `readme.md` (the `find_package` snippet), `.jeffy/probes/docs-public/` (the version-marker rule corrected, one check widened, README, claims), PLAN.md (one row re-recorded, one Lesson), BACKLOG.md (M6 closed), JOURNAL.md.

Checkpoint: fc75dcbb5d08ef93b86c2bcc476b8cc44bc8d030

Verification: the filed reproduction was run first and failed as filed at 14/17. After the fixes the battery reports 17/17, and its mutation - one readme link pointed at a file that is not in the tree - takes it to 16/17. The `find_package` fix was measured rather than reasoned: configuring the readme's old snippet against a real install printed `The version found is not compatible with the version requested` and failed, and a version-less request configures against the same install. `docs-public` is the only battery declaring any path this diff touched. `check-claims.sh` reports 51 checked, 0 mismatched, 0 errored, 0 skipped. The verify gate is green in 29s, reporting `100% tests passed, 0 tests failed out of 7` for each configuration.

Most of M6 as filed was not a defect, and finding that out was the work. `doc/mimalloc-doc.h` documents three major versions at once and marks which is which: a description introduced by `__v1__,__v2__:` describes the older API on purpose, and `@see mi_theap_get_default() for __v3__` is a cross-reference, not a marker. The battery matched any occurrence of `__v1__`, so it faulted the deliberate v1/v2 entries; and when that was corrected to require the marker, the cross-references defeated it again, because a v1/v2 entry names its v3 replacement. Only the marker-followed-by-a-colon form separates the two. Of the nine function names the filing listed, one survived that correction, and of the eight option names, one did.

What was real is now fixed. `mi__posix_memalign` was declared in a block of POSIX convenience names where every sibling resolves in the library and it resolved nowhere; the line is gone. `mi_option_visit_abandoned` was listed with no version marker while the header carries only `mi_option_deprecated_visit_abandoned`, so a v3 reader was sent to a name their enum does not have; it now carries the same marker its renamed siblings already had. And `readme.md` told a user to write `find_package(mimalloc 1.8 REQUIRED)`, which fails against any install of a different major; it now shows a version-less request, which is what serves a readme that covers v1, v2 and v3 alike, and the battery's check accepts either no version or a matching one.

The three-strike reasoning that produced M6 still holds - M2 and L1 share the root cause that the documentation drifts from the header with nothing comparing them - and the comparison now exists and is green. What it reports rather than faults is unchanged: names that exist but are undocumented, and options the header has that the docs do not, are gaps rather than breakages.

Learnings: `doc/mimalloc-doc.h` documents v1, v2 and v3 together and marks each with a version followed by a colon; a check matching any occurrence of `__v1__` faults the cross-references too and invents findings. More generally, when a filing rests on a set a script produced, re-read the source before fixing anything - the fix here was three lines and the instrument was wrong about six.

Next: the final iteration writes the handoff. Two Mediums remain open, M2 and M3, along with four Lows, so the run ends out of budget without converging.

## iter 10/10 | 4fefea3e-004657 | 2026-08-30 | WRAPUP | done

Task: final iteration. The ledger is not at the severity floor - two Mediums remain open - so this is a wrapup that tidies BACKLOG.md and writes the handoff rather than the closing audit, and the run ends out of budget without converging.

Changed: BACKLOG.md (Later reordered runtime-first, L1 corrected to the set its own command reports), JOURNAL.md.

Checkpoint: 0d540b2360212ae95133db186f5233672001a608

Verification: every carried finding's premise was re-run rather than assumed. L1's command reports three constant-size allocators with no `@brief`, not the four its line claimed - `mi_free_csize` has one - so the line now names what the command returns and carries that command as its acceptance. L2's battery reports 2177/2177, still pinning the two formatter divergences. L3's battery reports 2240/2249, still red at exactly the checks that finding names. L4's measurement is a standing claim in `check-claims.sh` and matched. `docs-public` reports 17/17 after the tidy. The verify gate is green in 28s, reporting `100% tests passed, 0 tests failed out of 7` for each configuration.

The run's shape is worth recording for the next one. Five of the ten iterations went to the map, which was the right call and the queue's: it started at 16 of 27 rows swept and ends with none unswept and one unreachable, and three of the five findings this run filed came out of those sweeps rather than out of an audit. The sweeps also produced the run's only High, which the packaging battery found by consuming an install from a separate project rather than by listing the files it produced.

Two things this run got wrong and corrected are worth carrying forward more than the fixes are. M6 was filed from a script's output without re-reading the source, and most of it was not a defect: `doc/mimalloc-doc.h` documents three major versions at once, and the instrument was faulting the deliberate v1/v2 entries. Of seventeen names the filing listed, two were real. And the first restored `malloc_requested` decrement subtracted unconditionally while its increase sits inside a size branch, driving the counter negative for huge blocks - caught by measuring both sides of the branch, not by reading.

Learnings: none new; the rules this iteration relied on are already in Lessons.

Next: the handoff is the run report below. The next run starts with M2, then M3, then the four carried Lows, and should expect the ratchet not to apply.

## iter 1/10 | b64bceb1-024535 | 2026-08-30 | M2 | done

Task: M2 - the `mi_option_t` enum comments state `(=X)` defaults that `mi_option_get` does not return, for seven options.

Changed: `include/mimalloc.h` (seven default comments), `doc/mimalloc-doc.h` (six of the same seven), `.jeffy/probes/option-defaults/` (run.sh extended to the documentation header, a byte-unit normalisation, two mutation scripts, paths, README, claims), `.jeffy/probes/docs-public/README.md` (one sentence naming M2 as open), BACKLOG.md (M2 closed), PLAN.md, JOURNAL.md.

Checkpoint: 4aefdf34e051a6951deb2aac06d7ad5bde77518e

Verification: the filed reproduction ran first and failed as filed, `option-defaults: 18/25 checks passed` with the seven MISMATCH lines the finding names. After the fix the battery reports `49/49`, and both discriminating mutations take it to `48/49`. `check-claims.sh` over the thirteen batteries that declare a path this diff touched reports 29 checked, 0 mismatched, 0 errored, 0 skipped - which covers the four `option-defaults` claims and leaves the batteries that are red by design at exactly the summaries they recorded. The verify gate is green in 28s, reporting `100% tests passed, 0 tests failed out of 7` for each configuration.

The seven defaults were each read off `src/options.c` rather than off the finding: `purge_delay` is 1000, `arena_purge_mult` 4, `deprecated_visit_abandoned` 1, `guarded_max` `MI_GiB`, `page_cross_thread_max_reclaim` 32. Two do not reduce to a number and are now stated with the condition instead. `guarded_sample_rate` is 0 unless the build defines both `MI_GUARDED` and `NDEBUG`, in which case it is 4000, so the comment states both. `max_vabits` is 0, and 0 is not a bit count: `_mi_page_map_init` and `mi_page_map_init_once` both read 0 as "ask the OS", so the comment says that rather than naming a number a user would then try to reproduce.

The finding named `include/mimalloc.h` alone, but the same enum is documented a second time in `doc/mimalloc-doc.h`, and six of the seven were wrong there too. Fixing only the file the finding named would have left the generated API documentation stating exactly the defect the finding is about, so both were corrected and the battery was extended to compare both. That is what makes it a class fix rather than an instance one: the acceptance check now enumerates every place a default is stated, so neither file can drift alone.

The seventh, `mi_option_visit_abandoned`, is left as written. It is the v1/v2 spelling of this tree's `mi_option_deprecated_visit_abandoned` and its entry is marked `__v1__,__v2__:`, so its `(=0)` is a statement about v1 and v2, and nothing in this tree establishes what those released. The battery excludes it under the rule that a name this library does not define has no runtime value to compare against, and the README enumerates the eight excluded entries with the command that derives them.

Extending the instrument in the same iteration as the fix is the move that can hide a defect, so the battery was made to fail twice on purpose. Two things say it did not go green by being loosened. The total did not shrink: the header comparison stayed at 25 checks across the fix, and 24 more arrived with the documentation header. And each file compared now has its own discriminating mutation - `mutate.sh` on `include/mimalloc.h`, `mutate-doc.sh` on `doc/mimalloc-doc.h` - each reddening exactly one check, because a comparison that has never been seen to fail on a file is not evidence about that file.

One defect in the instrument was found and fixed on the way. The header pass keyed its runtime map on the enum line with its leading indentation still attached, which the original single-file battery never noticed because it only printed the name. The documentation pass looks names up in that map and matched nothing, so the first run reported 45 documented options this library does not define and added zero comparisons while still printing a green summary. What caught it was the count, not the colour.

The contract preserved: no code changed. `src/options.c` still holds every default it held, and the only edits outside `.jeffy/` are comments.

Learnings: an instrument extended in the same iteration as the fix it grades needs the total watched as closely as the pass count - a lookup that matches nothing drops every new comparison and still prints green. And when a documented default is conditional on the build, state the condition; a number that is right in one configuration is a fresh defect in the other.

Next: M3 is the last open Medium, then four carried Lows. Nine iterations remain, so the ledger can drain and a closing audit can run with budget left for what it files.

## iter 2/10 | b64bceb1-024535 | 2026-08-30 | M3 | done

Task: M3 - no path in the tree is marked `export-ignore`, so `git archive` carries the loop's state files and `.jeffy/` into the published source tarball.

Changed: `.gitattributes` (six `export-ignore` paths), `.jeffy/probes/build-packaging/run.sh` (the archive check widened to the whole class), BACKLOG.md (M3 closed, one Settled class recorded), JOURNAL.md, PLAN.md.

Checkpoint: 539ab8c65deb69e83c6c88d33dfc2f773d98936f

Verification: the filed reproduction ran first and failed as filed - `git archive HEAD | tar -t` listed 181 loop-state paths and `git check-attr export-ignore` reported `unspecified` for every one of PLAN.md, BACKLOG.md, JOURNAL.md and `.jeffy`. After the fix `git check-attr` reports `set` for all six marked paths and `unspecified` for `src/alloc.c`, `include/mimalloc.h` and for files under `.jeffy/`, which inherit exclusion from the directory rather than carrying the attribute themselves. The archive was then measured on the fixed tree rather than argued about: `git archive $(git write-tree)` over the staged fix lists 405 entries against HEAD's 586, the acceptance regex finds no match and exits 1, and the three spot-checked project files - `include/mimalloc.h`, `CMakeLists.txt`, `src/alloc.c` - are all still in it, so the 181 paths removed are the loop's and nothing else went with them. The verify gate is green in 28s, reporting `100% tests passed, 0 tests failed out of 7` for each configuration.

The battery's own summary could not be measured before the checkpoint, and that is a property of the oracle rather than an omission. `build-packaging` archives `HEAD`, because a published tarball is made from a commit and not from a working tree, so on the pre-fix HEAD it necessarily still reports the M3 check red. Its post-fix summary and its mutation's summary are therefore measured immediately after this iteration's checkpoint and recorded with the claims file in the bookkeeping edit that completes this entry. Changing the battery to archive the working tree would have made the figure available a few minutes earlier at the cost of grading something other than what a user downloads.

The fix covers the class rather than the three files the finding named. `.gitattributes` marks six paths: the three ledger files, `JOURNAL-archive.md`, `.jeffy` and `.claude`. Two of those are not defects today and are marked because the way they become defects is already in place - `JOURNAL-archive.md` does not exist until the first rotation, and `.claude` is untracked but the checkpoint runs `git add -A`, so a harness-written `.claude/settings.local.json` would be committed and would ship. The battery's check was widened the same way, from the regex the finding's Acceptance names to one that also covers `.claude/`, so the check enumerates every path the loop writes rather than the subset that happened to be wrong.

The paths are anchored with a leading slash. `PLAN.md` in gitattributes matches a `PLAN.md` at any depth, and this project has none, but the attribute should say what it means: these are the loop's files at the project root, not a rule about that name anywhere in a source tree.

The contract preserved: no code changed and no build input changed. `git archive` is the only consumer of `export-ignore`, so the CMake build, the install, the pkg-config path and the vcpkg port are all untouched - which the verify gate and the rest of the `build-packaging` checks confirm rather than assume.

Learnings: a battery whose oracle is a commit cannot be green in the iteration that fixes what it grades; measure the fix directly against the tree the checkpoint will create, with `git write-tree` and `git archive` over that tree, and re-measure the battery after the commit.

Next: no Medium remains open. Four carried Lows are left - L2, L3, L4, L1 - and eight iterations, so the ledger can drain with budget for a closing audit and the evaluator gate well before the end.

## iter 3/10 | b64bceb1-024535 | 2026-08-30 | L2 | done

Task: L2 - `_mi_vsnprintf` in `src/libc.c` diverges from printf on two flag combinations: zero-padding a signed value puts the sign after the padding, and the left-align flag does not suppress zero fill.

Changed: `src/libc.c` (two hunks in `_mi_vsnprintf`), `.jeffy/probes/libc-and-bits/` (three pinned assertions and two matrix skips converted to differentials, two mutation scripts added, README, claims), BACKLOG.md (L2 closed), PLAN.md (two Lessons), JOURNAL.md.

Checkpoint: 6a0423e191e77a617d635a0dffabc05875e4a7ff

Verification: the filed reproduction ran first and the battery reported `2177/2177` - green, because the three assertions pinned the defect rather than compared it, which is what the finding's Acceptance asks to be changed. With the fix in `src/libc.c` and the pins converted to differentials the battery is `2177/2177` again, the same total, because each pinned assertion became one comparison. That figure alone proves nothing, so the negative control was run: the pre-fix `src/libc.c` restored under the current probe gives `2036/2177`, 141 red checks, including all fifteen `%-016ll[ux]` cases the unsigned matrix had been skipping. The two halves of the fix were then measured separately as standing mutations - `mutate-signpad.sh` gives `2109/2177` and `mutate-leftalign.sh` gives `2104/2177` - so each half has its own recorded discriminator. `check-claims.sh` for the battery reports 4 checked, 0 mismatched, 0 errored, 0 skipped. The verify gate is green in 28s, reporting `100% tests passed, 0 tests failed out of 7` for each configuration.

The fix is two hunks. The left-align flag now clears the fill character to a space when it is seen, which is C's rule that `-` overrides `0`; that one line also fixes the unsigned side, where `%-016llx` was zero-filling on the right. And the signed conversion now emits its sign ahead of the padded field and shortens the field by it, but only when the fill is `0` and the field is right-aligned, because C puts zero padding between the sign and the digits (`-0001`) and space padding before the sign (`   -1`). Those are different placements and the branch keeps them apart rather than picking one.

The contract preserved: `_mi_vsnprintf` is shared internal code behind every `_mi_fprintf`, `_mi_verbose_message` and `_mi_error_message` in the tree, so the question is which in-tree format strings change output. The enumeration is the same one the finding's downgrade rationale used, re-run this iteration: the specifiers the tree passes to this formatter are `%-10s %-11s %-3s %03zu %11s %12s %24s %2s %3lu %5i %5lld %5zu %d %i %ld %lld %lx %p %s %tx %u %x %zd %zu %zx`, and filtering that set for the shapes this diff changes - a zero fill combined with a sign or with left align - returns nothing. `%03zu` is unsigned and right-aligned; the `%-Ns` forms carry no zero flag, so their fill was already a space. No in-tree output moves, which is why the verify gate reads the same green as before rather than serving as evidence here.

The `%p` path is untouched and had to be checked rather than assumed, because it sets `fill = '0'` itself when the width is derived and no explicit flag was given. It does that only under `alignright`, so the new left-align line cannot reach it, and it is unsigned, so the new sign branch cannot either. The battery's separate `%p`-shape checks are among the 2177 and stayed green throughout.

L2 was filed Low because no call site reached either divergence, and that reasoning is unchanged by fixing it: the severity described what a user meets, and the fix was worth an iteration because it is small, the oracle is exact, and the probe was carrying three assertions that asserted a defect. What the fix buys is that the formatter now agrees with C everywhere the probe can reach, so the next divergence to appear is a regression rather than a known exception.

Learnings: prove a converted pin with a negative control that restores the pre-fix source - watching the new comparison pass shows only that it agrees with the code it was written against. And when a fix has two independent halves, give each its own mutation: one summary line covering both cannot say which half is still being caught.

Next: three carried Lows remain, L3, L4 and L1, with seven iterations. L3 is next in the queue, then the two documentation Lows, which leaves room for the closing audit and the evaluator gate.

## iter 4/10 | b64bceb1-024535 | 2026-08-30 | L3 | done

Task: L3 - `mi_bchunks_unsafe_setN` in `src/bitmap.c` counts the chunkmap bits it marks from the range length alone, so a range that starts part-way into a chunk leaves the last chunk's chunkmap bit clear.

Changed: `src/bitmap.c` (the chunk count measured from the offset), `.jeffy/probes/bitmap/` (reachability.sh re-aimed at the corrected line, README, claims), BACKLOG.md (L3 closed), PLAN.md, JOURNAL.md.

Checkpoint: 9f0d9328782f1c17b0d7d401719e23b2028ec119

Verification: the filed reproduction ran first and failed as filed - `bitmap: 2240/2249` with nine red checks at the three ranges the finding names, `{507, 10}`, `{511, 2}` and `{924, 300}`, three checks each for `unsafe_setN set exactly its range`, `popcount matches the model` and `bsr names the highest set bit`. After the fix the battery is `2249/2249` and its mutation is `2094/2249`. `reachability.sh` reports `control 3 subject 0`, which is the second half of the Acceptance: the instrument still fires on the battery that deliberately crosses a chunk boundary, so the zero is a measurement rather than an absence. `check-claims.sh` for the battery reports 3 checked, 0 mismatched, 0 errored, 0 skipped. The verify gate is green in 28s, reporting `100% tests passed, 0 tests failed out of 7` for each configuration.

The fix is one expression. The number of chunks a range covers is `ceil((idx % MI_BCHUNK_BITS + n) / MI_BCHUNK_BITS)`, not `ceil(n / MI_BCHUNK_BITS)`: the offset into the first chunk pushes the end of the range further than its length does. The function already had `cidx` in hand for the first-chunk write, so the correction reuses it. Everything below the chunkmap write was already correct - the first-chunk, mid-chunk and last-chunk writes are driven by `m` and the running `n`, which is why the bits themselves were always right and only the chunkmap was short.

The reachability instrument had to be re-aimed rather than left alone, and that is worth recording because leaving it would have looked like it still worked. It matched the pre-fix line by exact text, so the fix would have made it exit with `instrumentation target not found exactly once`; and matching the new line while comparing against the corrected formula would have made both sides equal and reported `control 0`, an instrument that reports nothing and reads like a clean result. It now computes what the length alone would have given and compares that against the corrected count, which is the same set of calls it always reported, so the recorded `control 3 subject 0` is comparable across the fix rather than a fresh number.

The contract preserved: `mi_bitmap_unsafe_setN` is internal and has three call sites - two in `src/arena.c` that pass `idx` 0, where the old and new formulas agree, and one in `src/threadlocal.c` that passes the previous slot count, which is a multiple of 1024 and therefore chunk-aligned too. That is why the subject count is zero rather than merely small, and why no in-tree behaviour changes. The chunkmap is only ever widened by this fix, never narrowed: `cidx + n >= n`, so the corrected count is greater than or equal to the old one for every input, and a chunkmap bit set for a chunk that has bits set is exactly the invariant the structure wants.

L3's Low severity rested on the subject count of zero, and closing it does not disturb that reasoning: the finding described metadata a user never met, and the fix was worth an iteration because it is one expression, the model in the battery already knew the right answer, and the alternative was carrying nine deliberately-red checks that hide a real regression if one lands beside them.

Learnings: an instrument that matches its target by exact source text is invalidated by the fix it was written to measure; re-aim it in the same iteration and check that its control still fires, because both failure modes - not finding the target and finding nothing to report - are silent.

Next: two carried Lows remain, L4 and L1, both documentation. Six iterations left, so both can close with room for the closing audit, the evaluator gate and the declaration.

## iter 5/10 | b64bceb1-024535 | 2026-08-30 | L4 | done

Task: L4 - the bin computation's comment in `src/page-queue.c` claims "~12.5% worst internal fragmentation" where the expression divides each octave into four size classes, not eight.

Changed: `src/page-queue.c` (the comment), `.jeffy/probes/page-management/measure-fragmentation.sh` (it now compares the comment against the measurement instead of only printing the measurement), its README, BACKLOG.md (L4 closed), PLAN.md, JOURNAL.md.

Checkpoint: 88a5e23975161ec74e40569e3d4adf6490bd86df

Verification: the filed measurement ran first and reported `worst internal fragmentation above 64 bytes: 1 in 4.00 (at size 262145)` against a comment claiming an eighth. The comment now states 1 in 4 and the script confirms the agreement rather than asserting it: it extracts the ratio from `src/page-queue.c`, compares it with the measured one, and fails when they differ. That comparison was shown to fail before it was trusted - putting the eighth back makes it print `MISMATCH src/page-queue.c states 1 in 8, the mapping produces 1 in 4` and exit non-zero. `check-claims.sh` for `page-management` reports 3 checked, 0 mismatched, 0 errored, 0 skipped. The verify gate is green in 28s, reporting `100% tests passed, 0 tests failed out of 7` for each configuration.

Only the figure was wrong, not the description. `(b << 2) + ((wsize >> (b - 2)) & 0x03)` keeps the highest bit and two more, which is three significant bits and therefore four classes per power of two; the worst relative waste for three significant bits is a quarter, and an eighth is the figure for four. The measurement lands exactly on the quarter at size 262145, one byte past a class boundary, which is where the bound is tight.

The correction is one figure, so the work worth doing was making the sentence checkable. A measurement that nobody compares to the sentence it corrects is how the sentence drifted in the first place, and the script had been printing the right number beside a comment that said something else for as long as the finding was open. It now reads both and fails on disagreement, so a future change to `mi_bin` that moves the bound reddens `page-management` rather than quietly re-opening L4.

The comment names no path under `.jeffy/`. That was the first phrasing and it is wrong: `.jeffy/` is `export-ignore` as of this run, so a source comment pointing at the measuring script would point at nothing in the published tarball. The comment states the ratio and the reason for it; the script that checks it stays on the loop's side of that line.

The contract preserved: no code changed. `_mi_bin` maps exactly as before, which the battery's own round-trip and monotonicity checks confirm at `334/334`, and the mapping's mutation still reports `325/336`.

L4 is documentation of an internal function rather than of the public API, which is why it did not join M2 and M6 under one structural task: those two were about the header and the generated documentation a user reads, and the `option-defaults` and `docs-public` batteries close that class. This one is a maintainer's comment about an implementation detail, and its oracle is a measurement over the mapping rather than a comparison against a public declaration.

Learnings: a source comment must not name a path the published archive excludes; `export-ignore` makes `.jeffy/` invisible to anyone reading the shipped tree.

Next: one carried Low remains, L1, with five iterations. Closing it next leaves three for the closing audit, the evaluator gate and the declaration.

## iter 6/10 | b64bceb1-024535 | 2026-08-30 | L1 | done

Task: L1 - three of the constant-size allocators in `doc/mimalloc-doc.h` are bare declarations with no `@brief`, so the generated documentation shows them with no description and never states that the `zalloc` forms return zeroed memory.

Changed: `doc/mimalloc-doc.h` (three documentation blocks), `.jeffy/probes/docs-public/` (a general check for undocumented declarations, README, claims), BACKLOG.md (L1 closed, L5 filed), PLAN.md (the docs-public row, a Stated counts row, one Lesson), JOURNAL.md.

Checkpoint: bbf21ab54a0563d9f7107b8a5c18bd3c4762725a

Verification: the filed reproduction ran first and named `mi_theap_malloc_csize`, `mi_theap_zalloc_csize` and `mi_zalloc_csize`. With the three blocks written the acceptance command prints nothing, exactly as filed. `docs-public` reports `17/18` and its mutation `16/18`, the one red check being L5 below; `option-defaults`, which also declares `doc/mimalloc-doc.h`, is unchanged at `49/49` with both its mutations. `check-claims.sh` over both batteries reports 5 checked, 0 mismatched, 0 errored, 0 skipped, including the new Stated counts row. The verify gate is green in 28s, reporting `100% tests passed, 0 tests failed out of 7` for each configuration.

The two theap blocks were written with six comment lines first and the acceptance still named them, because the check reads five lines back. Trimming one `@see` from each is the right answer rather than widening the check: five lines is what `mi_malloc_csize` and `mi_free_csize` already use, so the blocks now match the file's own convention and the acceptance passes as it was written rather than as it was rewritten.

Closing L1 by name left the general case unmeasured, and measuring it is what this iteration is really about. A check was added to `docs-public` for any declaration with no `///` line above it, since that is what renders as a signature and nothing else, and it asks for a comment line rather than for `@brief` because this file uses a bare description line as often as the tag. It reports 58 such declarations - the whole `mi_option_get`/`mi_option_set` block, the aligned and recalloc families, `mi_theap_calloc`, `mi_theap_realloc`, the posix shims - so it is filed as L5 and the battery is red at exactly that check. Before this iteration the same command returned 61; the difference is L1's three.

The check was nearly added vacuous, and the mutation is what caught it. The first pattern used `\b` for a word boundary, which gawk reads as a backspace, so it matched no line at all; the battery reported `18/18` on the tree and `18/18` again under a mutation that stripped a comment block off a declaration. An instrument that reports the same number whether or not the defect is present is the failure mode the mutation discipline exists for, and this is the second time this run that a green figure from a newly written comparison turned out to be a lookup matching nothing.

The contract preserved: no code changed and no public declaration changed. The three blocks describe what the wrappers in `include/mimalloc.h` do - each branches on `MI_SMALL_SIZE_MAX` and forwards to the small or general form - and the zeroing promise the finding asked for is now stated on both `zalloc` forms, which is the promise the `csize-wrappers` battery already grades by dirtying the same theap before checking.

Learnings: `\b` is a backspace in gawk, not a word boundary, so a pattern using it matches nothing and the check passes vacuously. And when an acceptance check reads a fixed window of lines, fit the fix to the file's existing convention rather than widening the check, or the acceptance stops being the thing that was agreed.

Next: the ledger holds one Low, L5, which is carried. The map is swept and no full audit has run this run, so iteration 7 is the closing audit, with the evaluator gate and the declaration after it.

## iter 7/10 | b64bceb1-024535 | 2026-08-30 | ROTATION | rotation

Task: JOURNAL.md reached 567 lines, past the 500-line rotation threshold.

Changed: JOURNAL.md (15 entries moved out), JOURNAL-archive.md (created).

Checkpoint: f822f46506f71eb64bc6a4dced5edc33faa264f7

Verification: 25 entries before, 10 kept and 15 moved, counted by `grep -c '^## iter [0-9]'` on each file after the split. The archive runs from `iter 1/10 | 7f2a700e-233033` to `iter 6/10 | 4fefea3e-004657` and the journal now opens at `iter 7/10 | 4fefea3e-004657`, so the sequence is continuous across the two files. The preamble stayed in JOURNAL.md and its indented heading-grammar example was not counted or moved, which is what the anchor's leading-column rule is for. `git check-attr` reports `export-ignore: set` for JOURNAL-archive.md, so the new file is already covered by this run's packaging fix rather than needing a second one.

Learnings: none new.

Next: the primary entry for this iteration follows.

## iter 7/10 | b64bceb1-024535 | 2026-08-30 | L5 | done

Task: L5 - `doc/mimalloc-doc.h` carries declarations with no `///` line above them, which doxygen renders as a signature and nothing else.

Changed: `doc/mimalloc-doc.h` (58 declarations documented), `.jeffy/probes/docs-public/` (a mutation for the description check, README, claims), BACKLOG.md (L5 closed), PLAN.md (the docs-public row, the Stated counts row removed), JOURNAL.md.

Checkpoint: f822f46506f71eb64bc6a4dced5edc33faa264f7

Verification: the check that filed L5 reported 58 before and reports 0 now, and `docs-public` is `18/18` where it was `17/18`. The check is no longer red by design, so it needed a mutation to stay checkable: `mutate-bare.sh` strips the comment block off one declaration and takes the battery to `17/18`, and the existing readme-link mutation still gives `17/18`. `option-defaults`, which also declares `doc/mimalloc-doc.h`, is unchanged at `49/49` with both its mutations. `check-claims.sh` over both batteries reports 7 checked, 0 mismatched, 0 errored, 0 skipped. The verify gate is green in 29s, reporting `100% tests passed, 0 tests failed out of 7` for each configuration.

The 58 fall into families, and the work was reading each family's real behaviour rather than pattern-matching the names. Six aligned and offset-aligned variants sit under a documented `mi_malloc_aligned`, which doxygen attaches to that declaration alone; twelve more are the `rezalloc` and `recalloc` families and their heap forms; eleven are the heap-scoped realloc and aligned allocators; ten are the whole option get and set block, which had no description at all between the enum and the group close; three are theap allocators; and sixteen are the posix and Windows shims, from `mi__expand` to `mi_free_aligned`.

Three descriptions were written from the implementation rather than from the name. `mi_option_get_size` clamps a negative value to zero, scales the KiB-valued options to bytes and returns every other option unchanged, so the line says all three things instead of only the scaling. `mi_option_set_default` and `mi_option_set_enabled_default` leave an option alone once it has been initialized, which is what makes them different from the plain setters and is the whole reason to call them. And `mi_pvalloc` rounds the request up to a whole number of pages before aligning, where `mi_valloc` only aligns.

One thing found on the way and documented rather than filed: `mi_recalloc` is declared twice in this file, once with a full block and once bare a few lines below. The second declaration now says so and points at the first. It is a documentation duplicate rather than a defect in the library - `include/mimalloc.h` declares it once - and doxygen renders one entry either way.

Every `@see` name added was checked to resolve in `include/mimalloc.h` rather than assumed, which matters because the battery's other direction faults a documented name that does not exist, and a cross-reference to a name that was renamed is the same defect one step removed.

The contract preserved: no code changed and no declaration changed. The file gained comment lines only, which is why the verify gate reads the same green and `option-defaults` - which parses the same enum in the same file - reports the same 49 comparisons.

Learnings: none new; this iteration relied on rules already in Lessons.

Next: the ledger is empty and the map is swept. Iteration 8 is the closing full audit, with the evaluator gate and the declaration after it.

## iter 8/10 | b64bceb1-024535 | 2026-08-30 | AUDIT | audit

Task: the closing full audit. The ledger is empty, the Surface inventory lists no unswept row, and no full audit had run this run.

Changed: PLAN.md (four inventory row tails corrected), JOURNAL.md. No product file changed and no ledger item changed state, which the stall check would otherwise call a no-progress iteration; an AUDIT that files nothing is a ceremony entry and is exempt, and this is the first such entry of the run.

Checkpoint: 86bc8c5b0c98f2393c073d3a745b148a057c91e4

Verification: fresh evidence over the whole map rather than a re-reading of it. `check-claims.sh` across every battery reports 57 checked, 0 mismatched, 0 errored, 0 skipped - each battery's clean summary and each recorded mutation, so every instrument was made to fail and to pass in this iteration. The Environment fingerprint's exclusion command was re-run and returns the same eight override and link-mode programs the line names, and the toolchain matches it: Linux 6.18.33.1-microsoft-standard-WSL2 x86_64, gcc 15.2.0, cmake 4.2.3. The three Settled classes were re-derived through their own commands, all inside the claims run, and the fourth - the export-ignore class this run settled - reports `set` for all six paths. The Declined section is empty, so there is no Derivation to re-run. Two test modules were run in isolation before scoring Testing, `test-api-fill` alone and the five stress tests alone, both passing. The verify gate is green in 28s, reporting `100% tests passed, 0 tests failed out of 7` for each configuration.

Scores, over the 26 swept rows and the one unreachable row named below. Correctness: None - every battery green, and each one shown able to fail this iteration by its own mutation. Architecture: None. Code quality: None. Security: None - the size, count and alignment surface the envelope classes adversarial is graded at its overflow boundaries by `alloc-core` and `alloc-aligned`, and `MI_SECURE` is off in this build, which the `os-layer-posix` row records and its battery grades as the contract that holds there. Testing: None on what is swept, with the disclosure that the gate compiles seven of fifteen test sources and the eight it does not are the override and link-mode programs, which `override-layer` sweeps separately. Error handling: None - the documented `EINVAL` and `ENOMEM` paths in `posix-shims` and the invalid-value warning path in `options-api` are graded. Performance: not scored, and the reason is recorded rather than assumed - there is no benchmark in this tree, which is also why the standing Proposed item about the `u`-API declines to reason about the free path's cost. Documentation: None - `docs-public` 18/18 and `option-defaults` 49/49, both comparisons between the documentation and the code. Dependency hygiene: None - the project vendors nothing, and `build-packaging` 39/39 covers the install, the pkg-config path, the CMake package and the published archive. Developer experience: None. Observability: None - `stats-api` 129/129. UX and accessibility: not applicable, a C library with no user-facing surface.

Zero High and zero Medium in-envelope. Closeout has begun: no further audit and no replenishment for the rest of this run.

The audit's one finding is about the state files rather than the product, and it was corrected here rather than filed. Four Surface inventory rows still asserted a present-tense state their own batteries contradict - `u-api` and `build-packaging` each said the battery "is red" at the checks H2, H5 and M3 name, and those batteries now report 559/559 and 39/39 with all three findings fixed. Two more, on `libc-and-bits` and `stats-api`, named L2 and M5 as filed without saying they had been closed. All four tails now say what the measurement says. This is the shape of drift this run has hit repeatedly: a sentence written when a battery was red outlives the fix, and nothing compares the two unless an audit reads them side by side.

Learnings: a row tail that states a battery's colour is a standing claim and goes stale the moment the finding it describes is fixed; the iteration that closes a finding should correct every row tail naming it, not only the row it re-records.

Next: the closing conditions hold, so iteration 9 brings the standing claims current, invokes the evaluator gate for the first time this run, and declares on a PASS.

## iter 9/10 | b64bceb1-024535 | 2026-08-30 | EVALUATOR | converged

Task: bring the standing claims current, invoke the adversarial evaluator gate for the first time this run, and declare convergence on a PASS.

Changed: BACKLOG.md (four Lows filed from the gate's observations, one Converged line), `.jeffy/evaluator/b64bceb1-024535-1.md` (the gate's artifact), JOURNAL.md.

Checkpoint: 41ad01a66dbea484eb9ecd06ae978afdc2016275

Verification: Evaluator: PASS - invocation 1 of this run, artifact `.jeffy/evaluator/b64bceb1-024535-1.md`, which re-ran the verify gate green, `check-claims.sh` at 57 checked and 0 mismatched, reproduced both Mediums as failing on the base commit and passing at HEAD, re-executed both Acceptances as written, and found no regression in either diff. The claims were brought current in this same iteration before the invocation: `check-claims.sh` across every battery reports 57 checked, 0 mismatched, 0 errored, 0 skipped; the four Settled-class enumerations were re-derived, the fourth reporting `set` for all six export-ignore paths; the Declined section is empty so there is no Derivation to re-run; the Environment fingerprint's exclusion command returns the same eight override and link-mode programs the line names; the Oracle class was re-read and the Verify count cell is deliberately empty for the reason written beneath it, because the summary line's first integer is a percentage; no Surface inventory row is stale; and the only commits since the clean audit at 86bc8c5b are that audit's own bookkeeping edit to JOURNAL.md. The verify gate is green in 28s, reporting `100% tests passed, 0 tests failed out of 7` for each configuration.

The gate checked the two Mediums the way the rules ask rather than the way that would have been easy. For M2 it could not simply run the current battery against the base commit, because the battery was extended in the same iteration as the fix; it swapped the base commit's `include/mimalloc.h` into the worktree, ran the current battery against it, and got `42/49` with exactly the seven MISMATCH lines the finding names, against `49/49` at HEAD. It also confirmed the fix is comment-only by preprocessing both trees and finding the output identical, and confirmed the battery still compares all 25 header entries rather than going green by dropping checks. For M3 it measured 179 loop-state paths in the base archive against none at HEAD, and checked that nothing was lost with it: both archives list 405 non-loop entries and `comm` is empty in both directions.

Four observations came back, all scored Low and none a reject reason, and none is fixed here: a fix after a PASS invalidates the PASS and spends an invocation the declaration needs. They are filed as L6 through L9 and carried.

Carried Lows at this declaration:
- L6 - two descriptions added under L5 name their return codes incompletely: `mi_dupenv_s` omits `ENOMEM` and `mi_posix_memalign` omits the null-pointer `EINVAL`.
- L7 - the `guarded_sample_rate` comment says "MI_GUARDED and NDEBUG" where the guard tests `MI_GUARDED && !MI_DEBUG`; the two agree in the default configuration and differ only where `MI_DEBUG` is set explicitly.
- L8 - PLAN.md's `cpp-new-delete` row tail still points the throwing out-of-memory path at H4, which closed in the previous run; the fifth tail of the class the closing audit corrected four of.
- L9 - the caller enumeration behind L3's severity is narrower in prose than in the measurement; `mi_bchunks_unsafe_setN` is also reached through `mi_bbitmap_unsafe_setN`, and the severity rests on the measured `control 3 subject 0` rather than on the sentence.

The one unreachable row is `os-layer-nonposix`: `src/prim/windows/`, `src/prim/osx/`, `src/prim/wasi/` and `src/prim/emscripten/` are compiled only on Windows, macOS, WASI and Emscripten, and `src/prim/prim.c` includes none of them on Linux, so no build on this host can execute them.

Learnings: the gate is worth more than the checks it repeats when it reads the run's own prose against the run's own measurements - three of its four observations are sentences this run wrote that are narrower or looser than the commands beside them, and none of them was reachable by re-running anything.

Next: the run is converged. The next run starts with L6 through L9, all Low, and should expect the ratchet not to apply because those are open tasks.
