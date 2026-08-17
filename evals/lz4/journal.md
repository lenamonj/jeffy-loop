# Journal

Append-only. One primary entry per iteration; SALVAGE and ROTATION entries are additional. Never rewrite past entries (filling the current entry's Checkpoint field is completion, not a rewrite).

Heading grammar, exactly (fenced and indented here so this example is never mistaken for an entry by anything that counts or rotates them):

```
  ## iter <i>/<N> | <run-id> | <YYYY-MM-DD> | <task-id or AUDIT or EVALUATOR or RATCHET or WRAPUP or SALVAGE or ROTATION> | <done|blocked|audit|converged|salvage|rotation>
```

Write a real heading at column zero, never indented: the indentation above belongs to the example alone, and an indented heading is invisible to the rotation anchor and to the archive counter, so the entry under it is not counted and not rotated.

SALVAGE entries take status salvage; ROTATION entries take status rotation. An EVALUATOR entry records an evaluator-gate iteration: status audit when the run continues after the verdict, blocked on a terminal second REJECT, converged when that same iteration declares.

run-id is the first 8 characters of the session id, a hyphen, then the HHMMSS of started_at from the loop state frontmatter, so two runs in one session are told apart. Body fields, in order: Task, Changed, Checkpoint (the jeffy checkpoint commit hash, or none with the reason), Verification, Learnings, Next.

The closing entry that declares convergence carries the evaluator verdict in its Verification field: `Evaluator: PASS - <one-line summary>`, or `Evaluator: unavailable (<reason>)`. An earlier EVALUATOR entry records its own verdict the same way and never stands in for the closing one: the Stop hook reads the closing entry alone, so a run that gates early and keeps working re-invokes the gate at the declaration.

Closed tasks are recorded here as one line each (ID, title, closing evidence), because BACKLOG.md deletes them. Rotation: when this file exceeds 500 lines, move all but the last 10 entries to the end of JOURNAL-archive.md, appending to whatever that file already holds and never overwriting it, because the archive accumulates across every rotation and every run; create it only when it does not already exist, and record the rotation as a ROTATION entry.

## iter 1/10 | e66c3630-130623 | 2026-08-17 | AUDIT | audit

Task: bootstrap audit of lz4 v1.10.0 at branch jeffy/audit-2026-08-17. Fill the Operating envelope, Surface inventory and Verify command in PLAN.md, then probe breadth-first and seed BACKLOG.md.

Changed: PLAN.md (envelope surfaces, 21 inventory rows, verify command with Oracle class, Environment fingerprint and Verify duration), BACKLOG.md (3 findings under Next), .gitignore (loop state file).

Checkpoint: 8d9810e8077ca1c22cdc98f2c3692b2180cdc0d7

Verification: Verify command timed end to end at 45s, exit 0. Its three oracles were each observed working: build of lib+CLI clean; `make check` plus test-lz4-skippable, test-lz4-opt-parser, test-decompress-partial and listTest all exit 0; `./fuzzer -s1 -T20s` and `./frametest -s1 -T20s` both report all tests completed. Exclusion list derived by `make -C tests test_targets | tr ' ' '\n' | grep -E '^(test|abiTests|listTest|versionsTest|checkTag)' | sort -u` minus the Command's closure, and the two host-level exclusions were checked rather than assumed: `gcc -m32` fails on missing 32-bit crt objects, `gcc -llz4` fails with `cannot find -llz4`, and `ls /usr/lib/x86_64-linux-gnu/liblz4.so /usr/include/lz4.h` finds neither. `ls tests/goldenSamples` returns exactly one file, skip.bin, and its only referencing script is one the Command runs, so no conformance corpus is sitting unexecuted.

Audit scores, claiming only what this pass actually probed and nothing more - zero of 21 inventory rows are swept, so every score below is about the probes named, never about the project as a whole. Documentation: Medium (DOC-1). Error handling: Medium (LIST-1, LIST-2). Security: no finding from an ASan+UBSan build of tests/fuzzer.c and tests/frametest.c run at seed 7 for 60s each, 2072 and 9829 cases, zero sanitizer reports. Correctness: no finding from the seeded round-trip differential engines, and an LZ4F_preferences_t probe found every documented field changing the output as documented - blockMode, contentChecksumFlag (+4 bytes), blockChecksumFlag, contentSize (+8 bytes), compressionLevel and favorDecSpeed all moved the frame, and the two that did not, blockSizeID=LZ4F_max64KB and autoFlush under one-shot LZ4F_compressFrame, are documented no-ops in exactly those positions. Build and developer experience: no finding; GNU make, cmake, ossfuzz and examples all build and run clean, and a strict `-Wall -Wextra -Wpedantic -Wcast-qual -Wshadow -Wconversion -std=c99` compile of the five library sources yields 3 sign-conversion warnings under a flag the project does not adopt. Dependency hygiene: no finding; the only vendored dependency is xxhash inside lib/. Testing, architecture, code quality, performance, observability and UX are unscored this pass - Testing in particular needs the isolated-module run the Method requires before it can be scored at all.

Learnings: the object cache under cachedObjs/ keys on the compiler flags, so re-running a strict-warning build after a first pass returns silently from cache and looks clean; compile the sources directly with gcc when hunting warnings. `lz4.1.md` documents optional-negation flags in `--[no-]x` form, so a naive diff of man-page flags against lz4cli.c string literals reports seven false positives - expand the `[no-]` form on both sides before comparing.

Next: LIST-1, the top item on the ledger. 21 inventory rows are unswept and outrank every Low, so sweeps follow.

## iter 2/10 | e66c3630-130623 | 2026-08-17 | LIST-1 | done

Task: LIST-1 (Medium, runtime, error handling) - `lz4 --list` exits 0 on a truncated `.lz4` file that `lz4 -t` rejects.

Changed: programs/lz4io.c (`LZ4IO_skipBlocksData` and its contract comment), .jeffy/probes/cli-list-mode/ (new kept battery plus its paths file), PLAN.md (Lessons, and one host exclusion added to the Environment fingerprint), BACKLOG.md (LIST-1 deleted).

Checkpoint: 5b80ace3d99259c9805b7f4a6cb1c237e62b75f9

Verification: the filed reproduction ran first, against unfixed code, and reproduced - a 50-byte frame truncated to 24 bytes listed with exit 0 while `lz4 -t` exited 26. Three distinct loss points were found in `LZ4IO_skipBlocksData`, all closed by this change. First, a block-header read that returns zero bytes at end of input was treated as a normal frame end, so a frame with no EndMark passed. Second, `fread` was tested with `!fread(...)`, which accepts a partial read of 1 to 3 bytes, after which `LZ4IO_readLE32` reads all four bytes of a buffer `fread` only partly wrote; both the reachability of that path and its acceptance by the old code are shown by the baseline runs at 1, 2 and 3 bytes past the frame header below. Third, the content checksum after the EndMark was skipped with `UTIL_fseek`, which succeeds past end of file on a regular file, so a frame whose trailing checksum was cut still passed. The fix requires a full 4-byte block-header read and reads the content checksum instead of seeking over it.

The acceptance check passes and was proved able to fail: a baseline binary built from HEAD in a detached `git worktree` at /tmp/lz4_base returns exit 0 on every case the fixed binary now rejects - the 24-byte truncation, truncations leaving 1, 2, 3 and 4 bytes after the frame header, and a 30317-byte frame with its last 1, 2, 3 or 4 bytes removed. The kept battery `.jeffy/probes/cli-list-mode/run.sh` reports 38 failures against that baseline and PASS against the fix. It sweeps every truncation length of a 50-byte frame exhaustively rather than sampling, so all three loss points are covered by construction.

No regression on well-formed input: `--list` and `-t` both exit 0 on all ten frame shapes the CLI can produce - default, `--content-size`, `-BX` block checksum, `-BD` block independence, HC level 12, `-B4`, `-B7`, legacy `-l`, three frames concatenated, and a skippable frame prefixed to a normal one. Verify command exit 0, both differential engines reporting all tests completed; the `Error ...` lines in its log are the lorem-ipsum payload of the intentional `test-datagen-invalid-input` target, not failures.

Contract preserved: `LZ4IO_skipBlocksData` is static with exactly one caller, `LZ4IO_getCompressedFileInfo`, which treats any 0 return as "format not recognized". Zero was already the documented error sentinel and remains unambiguous, because a complete frame always carries at least an EndMark and so always returns at least 4. The observable CLI change is that `--list` now reports an error and exits non-zero on a truncated archive instead of printing a listing and exiting 0; that is the defect being fixed, and it is recorded here per the Constraints. The man page was checked and is not contradicted - `lz4.1.md` says only "List information about .lz4 files" and never claimed the old behaviour - and it was deliberately not edited, because `programs/lz4.1` is generated from it by `ronn`, which is absent on this host, so editing one without the other would create the divergence this rule exists to prevent.

One consequence for the ledger, not a new finding: fixing LIST-1 widens the symptom LIST-2 already describes. `LZ4IO_displayCompressedFilesInfo` returns 1 as soon as any file fails, so a truncated file in a multi-file listing now stops the run where before it was silently accepted. LIST-2 is the task that makes `--list` report per-file errors and continue, and it is next.

Learnings: `programs/lz4.1` is generated from `programs/lz4.1.md` by `ronn`, which is not installed here, so the pair must never be edited apart. Running a check against unfixed code is done with `git worktree add --detach /tmp/<name> HEAD`, which leaves the working tree and its uncommitted fix untouched.

Next: LIST-2, now the top of the ledger.

## iter 3/10 | e66c3630-130623 | 2026-08-17 | LIST-2 | done

Task: LIST-2 (Medium, runtime, error handling) - `lz4 --list` aborts the whole process at the first unreadable file and drops every file listed after it.

Changed: programs/lz4io.c (`LZ4IO_getCompressedFileInfo` and `LZ4IO_displayCompressedFilesInfo`), .jeffy/probes/cli-list-mode/run.sh (continuation section added), BACKLOG.md (LIST-2 deleted, SKIP-1 filed under Now).

Checkpoint: 77d04cecebbaba3213465811b06ee3704e78612e

Verification: the filed reproduction ran first and reproduced - `lz4 --list good1.lz4 bad.lz4 good2.lz4` printed good1, exited 71, and never reached good2.

The enumeration of abort points was built by provoking a failure at each step of the listing operation, not by grepping for `END_PROCESS` calls. Twelve malformed inputs were constructed, one per step: a short magic number, a frame header cut at the magic, a frame header cut before its extended part, an unusable FLG byte, truncated block data, a legacy frame whose block size runs past end of file, a skippable frame with no size field, one with a partial size field, one whose size runs past end of file, an empty file, an unknown magic number, and a directory. Run as the middle of three files against unfixed code, eleven of the twelve stopped the listing before good2, through four distinct process-killing exits - 40, 71, 72 and 42. The twelfth, the oversized skippable frame, exited 0 and listed good2, which is how SKIP-1 was found; that also settles a question the source could not answer, since `END_PROCESS(43)` on this path could not be provoked at all - `fseek` past end of file succeeds on a regular file, so the branch is unreachable there.

After the fix all twelve continue to good2, and every one that is diagnosed exits non-zero; the oversized skippable frame still exits 0 because nothing detects it yet, which is SKIP-1 and not this task. A listing of two well-formed files still exits 0. The battery `.jeffy/probes/cli-list-mode/run.sh` was extended with this continuation invariant and reports PASS against the fix and 11 failures against a baseline built from HEAD in a detached worktree, which carries the LIST-1 fix and so isolates LIST-2 alone. Verify command exit 0, both differential engines reporting all tests completed.

The battery's first draft was wrong and the run caught it: it tested whether the bad file's name appeared in the output, but a file that lists successfully prints its name too, so the check fired on the one input that was not actually diagnosed. It now looks for the `File format not recognized` diagnostic rather than the bare name.

Contract preserved: the five `END_PROCESS` calls replaced are all inside `LZ4IO_getCompressedFileInfo`, whose only caller is `LZ4IO_displayCompressedFilesInfo`; `git diff -U0` confirms every hunk lies in those two functions, and the `END_PROCESS(40/42/43)` calls on the decompression and compression paths are untouched. Each replaced call now prints the same information through `DISPLAYLEVEL(1, ...)` and breaks to the per-file error result, which is the idiom the legacy-frame branch in this same function already used. Two short-read checks written as `!readBytes` were tightened to exact-length comparisons in the same edit, because they were the same partial-read defect LIST-1 closed and they sat in the statements being rewritten. The observable CLI change: `--list` now reports each bad file and continues, and the exit status is 1 rather than the raw 40/42/71/72 that previously leaked from `END_PROCESS`. The man page is not contradicted - it documents `--list` as listing information and as implying `-m`, which is now more true than before - and it was again not edited, `ronn` being absent on this host.

New finding filed this iteration, at rubric severity: SKIP-1 (High). `lz4 -dc` on an oversized skippable header followed by a valid frame emits nothing and exits 0, from a file and from stdin, while the well-formed equivalent emits its 23 bytes; `lz4 -t` calls the same file good. That is silent data loss on the adversarial surface. It is the third finding sharing the root cause LIST-1 closed twice - a container-declared length trusted and stepped over with a seek that succeeds past end of file - so under the three-strike rule it is filed as one structural task with a class enumeration in its acceptance, not as a patch of the skippable branch.

Learnings: a battery that asserts on a filename appearing in CLI output will match the success path as well as the failure path; assert on the diagnostic text instead. `END_PROCESS(43)` on the `--list` skippable branch is unreachable for regular files, which only provoking the failure could establish - reading the source suggests the opposite.

Next: SKIP-1, now the only High and the top of the ledger.

## iter 4/10 | e66c3630-130623 | 2026-08-17 | SKIP-1 | done

Task: SKIP-1 (High, runtime, correctness) - a container-declared length is stepped over with a seek that succeeds past end of file, so an over-declared region silently swallows whatever followed it. Filed as one structural task under the three-strike rule rather than as a patch of the skippable branch.

Changed: programs/lz4io.c (`fseek_u32` rewritten as the checking boundary; the LZ4F block skip in `LZ4IO_skipBlocksData` and the legacy block skip in `LZ4IO_skipLegacyBlocksData` routed through it), .jeffy/probes/declared-length-skips/ (new class battery and its paths file), BACKLOG.md (SKIP-1 deleted, class recorded under Settled classes).

Checkpoint: 9d6e0f58cd5e8ce87c312f4f20f29a225185a7b0

Verification: the filed reproduction ran first and reproduced - an 8-byte skippable header declaring 0xFFFFFFF0 bytes followed by a valid 50-byte frame produced 0 bytes and exit 0 from `lz4 -dc`, and `lz4 -t` called it sound.

The class enumeration was built by provoking a failure at each place either container format declares a length, not by grepping for seek calls: the skippable frame size field, the LZ4F block size field, and the legacy frame block size field. Each was driven at an oversize value and at a modest value that still runs past end of input, because the two reach different code - only the oversize one crosses the internal seek-step ceiling. Against unfixed code the matrix showed the LZ4F block field already handled correctly at all three operations, and two live sites: the skippable field, wrong at `-dc`, `-t` and `--list` alike, and the legacy field, wrong at `--list` while `-dc` and `-t` rejected it. The legacy site was not in the filing; the enumeration is what found it, and the source itself carried a comment conceding the defect - that a too-large block size would not fail, skipping past the end of the input.

The fix is one boundary, not three patches. `fseek_u32` now advances over all but the last byte of the declared region and reads that last byte, because reaching it is what proves the region is present, and it keeps the existing read-and-forget fallback for non-seekable input. The two raw `UTIL_fseek` declared-length skips were routed through it. The remaining `UTIL_fseek` calls in this file were left alone and are not in the class: a dictionary tail seek, four sparse-output seeks on the output file, and a fixed 4-byte rewind.

All six enumerated cases now fail at every operation. Regression checks on well-formed input: a valid skippable frame followed by a real frame still decompresses to its exact 23 bytes through a file, through a redirect and through a pipe, and the pipe case matters because it is the only one that exercises the read-and-forget fallback I restructured; the oversized case fails through a pipe too, so the fallback rejects rather than silently consuming. The golden sample tests/goldenSamples/skip.bin still decodes all three ways, a legacy frame still round-trips, and two concatenated frames still decompress to both inputs. The new battery `.jeffy/probes/declared-length-skips/run.sh` reports 7 failures against a baseline built from HEAD in a detached worktree and PASS after; both batteries whose paths file matches programs/lz4io.c were run on the final tree and both pass. Verify command exit 0, both differential engines reporting all tests completed.

Contract preserved: `fseek_u32` is static with two callers, the skippable branch of the decompression path and the skippable branch of the `--list` path, and its contract was already "returns 0 on success, non-zero on failure" with the caller reporting an error. What changed is which inputs count as failure, which is the defect. Its stream position on success is unchanged, exactly `offset` bytes forward, since seeking `offset - 1` and reading one byte advances the same distance. The observable CLI change: an archive whose declared region runs past end of input is now refused with a non-zero status instead of producing empty output and exit 0. The man page is silent on truncated input and so is not contradicted; it was again not edited, `ronn` being absent here.

Learnings: an enumeration built by provocation found a live site the filing had missed, and the source's own comment had recorded that site as known-broken without it ever being filed - reading comments is not enumeration either. Testing a skip path only through a file or a shell redirect misses the non-seekable branch entirely, because `< file` is seekable; a real pipe is needed to reach it.

Next: DOC-1, the only remaining open task.

## iter 5/10 | e66c3630-130623 | 2026-08-17 | DOC-1 | done

Task: DOC-1 (Medium, docs, documentation) - `make manuals` regenerates `doc/lz4frame_manual.html` into broken output and the committed copy is stale against the header it is generated from.

Changed: lib/lz4frame.h (one comment opener), doc/lz4frame_manual.html (regenerated), .jeffy/probes/generated-manuals/ (new battery and its paths file), BACKLOG.md (DOC-1 deleted, DOC-2 filed under Later).

Checkpoint: 669620c392c4d1f4404f34edcc4b7dc2bf826414

Verification: the filed acceptance check passed on first run, and that was the check being wrong rather than the defect being gone. `make manuals` printed "Nothing to be done" - the doc/ targets are file targets whose prerequisites are the generator and the header, and iteration 1 left doc/lz4frame_manual.html with a newer mtime than both, because the `git checkout` that restored it stamped it with the current time. So `make manuals && git diff --quiet doc/` passes while the manual is stale, which is exactly the class of check the Method warns about. Invoking the generator directly reproduced the defect unchanged: a 100-line diff against the committed file, zero occurrences of the `LZ4F_decompress` prototype, two of `@brief`. doc/lz4_manual.html was identical, so only the frame manual had drifted.

Root cause, established by reading the generator's dispatch rather than guessing: `contrib/gen_manual` keys entirely on the comment opener. `/*!` means "this documents the declaration that follows", swapping comment and prototype and dropping the first line, which is by convention "LZ4F_xxx() :". `/**` and `/*-` mean "start a chapter", taking the first line as an H2 heading and consuming no declaration. `/**=` and `/*=` mean an H3 header. Enumerating the `/**` blocks in the two headers the Makefile actually processes shows the convention intact: lib/lz4.h has one, opening "Introduction", and lib/lz4frame.h has two, one opening "Introduction" and one opening the `@brief` line. Against 24 `/*!` blocks in the same file, that block is the single departure. The two `/**` blocks in lib/lz4file.h are harmless because that header is not fed to the generator.

So the fix is in the header, not the tool: the block now opens `/*! LZ4F_decompress() :` like its siblings, with the `@brief` sentence moved off the first line so the generator's first-line drop does not eat it. Nothing was lost - the regenerated entry carries the prototype in bold followed by the entire body, and the contents list is back to its 14 real chapters with the bogus one gone. Teaching the generator about doxygen was the alternative and was rejected: it would add a special case to a tool whose `/**` rule is used correctly everywhere else, to accommodate one nonconforming comment. The header diff is comment-only, confirmed by reading it. Verify command exit 0, both differential engines reporting all tests completed. No battery's paths file matched this diff before this iteration; the new one does now and passes.

Because the filed acceptance check could pass vacuously, it was replaced by a kept battery, `.jeffy/probes/generated-manuals/run.sh`, which invokes the generator directly instead of going through make. It asserts the committed manuals match what the generator produces, that the named functions keep their prototypes, that no doxygen tag reaches a heading or the contents list, and that regeneration is deterministic. It reports 3 failures against a baseline built from HEAD in a detached worktree and PASS after.

Its prototype check was itself wrong on first writing, in the same shape as the battery bug of iteration 3: a plain grep for the function name matched the running prose that names `LZ4F_decompress()` five times, so the check passed against the very manual it exists to reject. It now extracts the emphasised declaration blocks and searches only those, and it fires against the baseline as it should.

New finding filed: DOC-2 (Low, docs). The published manual renders raw doxygen markup - `@param[in,out]`, `@p`, `@retval`, `@pre`, `@post`, `@see` - as literal text to readers, 15 occurrences, while every sibling entry reads as prose. It is priced as affordable rather than declined: rewriting one comment block into the file's prevailing style and re-running the battery fits one iteration.

Ledger state: no open High and no open Medium remain, one open Low. Replenishment is not triggered, because the queue is not empty - 21 unswept Surface inventory rows sit above the open Low in the ordering, and sweeping is the next work.

Learnings: `make manuals` is not a regeneration check; its file targets no-op whenever doc/*.html is newer than the generator and the header, which a git checkout alone arranges, so any check on generated output must invoke the generator directly. An acceptance check written as "run the build step, then diff" inherits every way that build step can decide to do nothing.

Next: sweeping the Surface inventory, which outranks the one open Low.

## iter 6/10 | e66c3630-130623 | 2026-08-17 | SWEEP | done

Task: sweep Surface inventory rows, which outrank the single open Low in the queue. Sweeps batch, so this iteration took every row it could properly evidence.

Changed: .jeffy/probes/lib-known-answers/ (new known-answer battery, its runner and its paths file), PLAN.md (five rows flipped to swept, Lessons).

Checkpoint: 6e93fe4c6c95b036f276824cbd33521af1563d29 (battery), 923606b9d50a851320e6be88e01640960bb6b555 (row flips and this entry)

Verification: five rows are now swept, sixteen remain, out of twenty-one. The battery is one C program built against lib/ directly and run by `.jeffy/probes/lib-known-answers/run.sh`; it reports 153 checks and zero failures at the commit the rows cite.

Nothing in it passes by not crashing. The block decompressor is pinned by a block written out by hand from doc/lz4_Block_format.md - four literals, an overlapping match of 12 at offset 4, then a final literal run - decoded against an answer computed by hand, which is the one check here that does not depend on the compressor at all. LZ4_compressBound is checked against the closed form stated in lz4.h at ten sizes plus the negative and maximum edges. LZ4F_getBlockSize is checked against the exact size each of the four legal ids names, and against rejection of two invalid ones. Every documented parameter is driven at two or more values that must move the output: acceleration at 0, 1 and 100 including the documented default equivalence at 0, HC compressionLevel across every level from min to max, LZ4_decompress_safe_partial at four targets each checked against the input prefix, LZ4_compress_destSize at three budgets with the invariant that what it claims to have consumed is exactly what its output decodes to, and all six LZ4F_preferences_t fields with exact known answers for the content checksum and content size fields, +4 and +8 bytes.

The battery was mutation-tested rather than assumed capable of failing. Five mutations were applied to a scratch copy of lib/ and every one was caught: LZ4_compressBound losing its expansion term, LZ4F_getBlockSize returning the wrong size for one id, acceleration made inert at both search-step sites, the CDict path neutralised, and LZ4_decompress_safe_partial ignoring targetOutputSize. Each produced a targeted failure naming the defect. The compressBound mutation aborts the process, because the battery allocates from the bound it is testing; stdout was made unbuffered so its diagnostics survive that, and they now print before the abort.

Three checks in the first draft were wrong and the run caught all three, none of them defects in lz4. A check asserting that a match offset of zero must be rejected contradicted the project's own block format spec, which states that offset zero is invalid but that the reference decoder clears the match segment with zero bytes rather than refusing, precisely so that a naive decoder's disclosure of the caller's prior buffer contents cannot happen; the check now pre-fills the destination with a marker and asserts the twelve match bytes come back cleared and no marker byte leaks, which is the security property that matters, and lz4 satisfies it. A check sizing a frame destination from the NULL-preferences bound failed as dstMaxSize_tooSmall for every preference that enlarges the frame, because LZ4F_compressFrame refuses up front when dstCapacity is below the bound its own preferences imply. A check asserting LZ4F_compressFrameBound >= LZ4F_compressBound asserted a relationship the API never promises: the two bound different things, one a whole frame and one a single LZ4F_compressUpdate call that must be able to flush a buffered block, so at srcSize 0 they are 23 and 65551 and the ordering is the other way round. A NULL cctx passed to LZ4F_compressFrame_usingCDict segfaulted, which is my caller error against a documented precondition and is not a finding: that surface is user-error class in the envelope, where a wrong argument from the linking application inside its own address space is not defended against.

No in-envelope finding was surfaced by this sweep. Verify command exit 0, both differential engines reporting all tests completed.

Dimension scores from this sweep, claiming the five swept rows and nothing else: correctness None, with the evidence above; error handling None on those rows, covering rejection of truncated blocks, corrupted blocks, undersized destinations, out-of-range offsets and invalid block size ids. Sixteen rows remain unswept and no score here speaks for them - the four lz4.h and lz4hc.h streaming rows, the two lz4frame.h streaming rows, lz4file.h, xxhash, the deprecated API, the five CLI rows, ossfuzz, examples and the alternate build systems.

Stall check, recorded because the letter of the rule is met: this iteration changed only paths under .jeffy/ and PLAN.md, both exempt, and no BACKLOG.md item changed state. The previous primary entry does not say the same, so this is not a hard blocker. The rule's definition of progress does not count Surface inventory row flips, which is what a sweep iteration produces by design.

Learnings: a battery must be mutation-tested, not merely run - three of this one's checks were wrong in ways only an executed run exposed, and a fourth would have passed against a broken library had it not been mutated. When a check contradicts the project's own specification, the specification wins until there is evidence otherwise: doc/lz4_Block_format.md states what the reference decoder does about offset zero, and it does it.

Next: sweeping continues - sixteen rows remain and they still outrank the open Low.

## iter 7/10 | e66c3630-130623 | 2026-08-17 | SWEEP | done

Task: continue sweeping Surface inventory rows, which still outrank the open Lows.

Changed: .jeffy/probes/lib-streaming/ (new battery, runner and paths file), PLAN.md (seven rows flipped to swept), BACKLOG.md (RING-1 filed under Later).

Checkpoint: 9354e9857182f12ddd9c24de089ab9824199b1f7 (battery), a78bb6b2d2ce8385d807a183d0ce7d047eaede1c (row flips, RING-1 and this entry)

Verification: seven more rows are swept, so twelve of twenty-one are now done and nine remain. The battery is `.jeffy/probes/lib-streaming/`, 410 checks, zero failures at the commit the rows cite.

The recurring hazard on a streaming surface is that a round trip still passes when block linkage has silently broken, so every round trip here is paired with a check that fails without linkage. Sixty-four linked 4 KB blocks must beat the same blocks compressed independently; LZ4_attach_dictionary must produce byte-identical output to LZ4_loadDict and both must beat no dictionary at all; a frame streamed in 3000-byte pieces must come out byte-identical to the one-shot frame, so chunking is unobservable; and the frame decoded one input byte at a time must match the whole-frame decode, which is where a mishandled buffered state would show and nowhere else. Documented parameters were each driven at two or more values: autoFlush off and on, with the documented difference that an under-block update emits nothing when off and bytes when on; HC level 1 against LZ4HC_CLEVEL_MAX across a whole stream; LZ4_setCompressionLevel between blocks; LZ4_favorDecompressionSpeed, which must change the output and must never compress better than not favouring speed. Known answers: LZ4_loadDict returning 65536 for a 100 KB dictionary as documented, LZ4F_headerSize returning the frame format's 7 for a default header and 15 once a content size is declared, and LZ4F_getFrameInfo reporting back the content size that was set. The file API was read back at read sizes of 1, 7, 4096 and 65536 bytes, because a mishandled partial block fails at some read sizes and not others. The checksum row was swept by corrupting one payload bit and requiring both the content-checksum and block-checksum frames to reject it, with an intact frame carrying both still accepted so the rejection cannot pass for the wrong reason.

The battery was mutation-tested against a scratch copy of lib/ and caught all five mutations applied, each with a message naming the defect: content-checksum verification disabled, checksum verification skipped so a flipped bit passes, LZ4_saveDict reporting more than its maxDictSize, LZ4_favorDecompressionSpeed made inert, and LZ4_compress_fast_continue resetting its dictionary on every call. The last two matter most, because they are the mutations a round-trip-only battery would have missed entirely: the stream still decoded correctly in both cases.

New finding filed: RING-1 (Low, docs). The battery's first draft asserted LZ4_decoderRingBufferSize against the closed form of the LZ4_DECODER_RING_BUFFER_SIZE macro that lib/lz4.h places directly beneath it, and it failed at maxBlockSize 1, function 65566 against macro 65551. Mapping the whole domain showed the two agree exactly on 16 through LZ4_MAX_INPUT_SIZE and disagree outside it: the function clamps a block size below 16 up to 16 and returns 0 for a negative size or one above the maximum, and the macro does neither, so on 0 through 15 the macro names a buffer up to 16 bytes smaller than the minimum the library itself reports. Neither the macro's comment nor the function's doc block mentions the clamp. It is filed Low rather than Medium under the envelope's binding rule, because reaching it requires a caller to choose a sub-16-byte block size on a user-error surface and no consequence beyond the under-allocation was demonstrated; the rationale is recorded here as the severity rule requires. The check now encodes the real contract on both sides of the boundary.

Verify command exit 0, both differential engines reporting all tests completed; the lib-known-answers battery was re-run on the same tree and still reports 153 checks with no failures.

Dimension scores from this sweep, claiming the seven rows it swept and nothing else: correctness None, error handling None on those rows. Nine rows remain unswept and nothing here speaks for them - the deprecated and obsolete lz4.h API, the five CLI rows, the ossfuzz harnesses, the examples, and the alternate build systems.

Learnings: on a streaming surface a round-trip check is close to worthless on its own, because losing the dictionary between blocks still round trips; pair every one with a check that fails when linkage is lost, such as requiring the linked stream to beat independent blocks. A battery's first draft disagreeing with the code is as likely to be a real finding as a bad check - here it was the finding, and mapping the whole input domain rather than the one failing value is what told the two apart.

Next: five CLI rows, the deprecated API row, ossfuzz, examples and the build systems remain. With three iterations left, the run cannot sweep all nine to the evidence bar, so it will not converge; iteration 10 writes a handoff.

## iter 8/10 | e66c3630-130623 | 2026-08-17 | SWEEP | done

Task: continue sweeping. This iteration took the five CLI rows.

Changed: .jeffy/probes/cli-surface/ (new battery and its paths file), PLAN.md (five rows flipped to swept).

Checkpoint: 45e49df1ba6581214c04dee9427315a87e2a9f9b (battery), d9f7c111a1c72cfa44ad823833447d9c7e74f765 (row flips and this entry)

Verification: seventeen of twenty-one rows are now swept and four remain. The battery is `.jeffy/probes/cli-surface/run.sh`, driving the real `lz4` binary end to end, and it passes at the commit the rows cite.

The bar was a known answer or an invariant, never that a command ran. `--list -v` prints raw byte counts rather than the human-readable figures of the plain listing, so its uncompressed column is a known answer against the real input size and its compressed column against the real file size, and three concatenated frames must be counted as three. Documented parameters were driven at two or more values that must move the result: all twelve levels with the level flag required to change the output and level 12 never worse than level 1, block sizes -B4 through -B7 with -B4 and -B7 required to differ, and --fast at 1 and 17 with the faster setting never producing the smaller file. Invariants that a wrong implementation would break: --sparse and --no-sparse must produce byte-identical content, on ordinary data and on a zero-filled file where sparse actually engages; -T1 and -T4 must decompress to identical content, so worker count is not observable; file, redirect and pipe input must agree; -t must agree with -d on a sound file and reject a truncated one; and a dictionary-compressed file must not decode correctly with the wrong dictionary or with none.

Three mutations were applied to a detached worktree and each was caught by the check aimed at it, with the clean tree passing as a control. Writing the content-size header one byte short produced `--list -v reports uncompressed size '399999', the input is 400000 bytes`, which is the known-answer check doing exactly its job. Forcing the block size id to a constant produced `-B4 and -B7 produced identical files, so -B is inert`. Making --rm a no-op produced `--rm left the source file behind`.

Two defects in the battery itself were found and fixed during that mutation run, both about the battery reporting rather than about lz4. The first draft used `set -e` throughout, so the content-size mutation aborted the script with exit 34 and printed no diagnostic at all: detected, but silent about what broke. Expected-to-succeed invocations now go through an `lz4run` helper that reports a non-zero exit and continues, and the script no longer relies on `set -e` past its setup guards. The first draft also used `cmd && note ...` in places, which under `set -e` ends the script whenever the left side is false - that is, whenever the check passes - silently truncating the battery to whatever ran before it. Every conditional is now written as `if`.

No in-envelope finding was surfaced by this sweep. All six batteries pass on the final tree and the Verify command exits 0.

Dimension scores from this sweep, claiming the five CLI rows and nothing else: correctness None, error handling None on those rows. Four rows remain unswept - the deprecated and obsolete lz4.h API, the ossfuzz harnesses, the examples, and the alternate build systems - and nothing here speaks for them.

Learnings: `set -e` is the wrong default for a probe battery. It converts a detected defect into a silent abort, and it turns the common `check && note` idiom into a script that ends when the check passes. Report and continue instead, and wrap the invocations that are supposed to succeed. Plain `lz4 --list` prints human-readable sizes and cannot serve as a known answer; `--list -v` prints raw byte counts and can.

Next: four rows remain - deprecated API, ossfuzz, examples, build systems. Iteration 9 sweeps what it can and iteration 10 writes the handoff.

## iter 9/10 | e66c3630-130623 | 2026-08-17 | SWEEP | done

Task: sweep the last four Surface inventory rows.

Changed: .jeffy/probes/deprecated-api/ and .jeffy/probes/aux-surfaces/ (two new batteries with their paths files), PLAN.md (four rows flipped, the build-systems row split into a swept cmake row and an unreachable row), BACKLOG.md (MT-1 filed under Later).

Checkpoint: 519bef63d91dd8c13542e3c4945568708ebb27b1 (batteries), 3646f1fcaaadfe147ffbace3952c27030f7ae569 (row flips, MT-1 and this entry)

Verification: the map is complete. Twenty-one rows are swept, one is disclosed as unreachable on this host, and none is unswept.

The deprecated API was swept against the modern functions it replaces rather than by round trip, because a round trip passes for an obsolete wrapper that quietly drops an argument. LZ4_compress, _limitedOutput, _withState, _limitedOutput_withState, _continue and _limitedOutput_continue are each required to be byte-identical to their modern counterpart, with the output limits proved to bind; LZ4_uncompress and _unknownOutputSize are checked against their documented return values; the fast decoders and both prefix64k variants are checked against LZ4_decompress_safe_usingDict on the same bytes. 57 checks, zero failures, and a mutation shortening LZ4_compress's input by one byte is caught by the alias comparison.

Two of my own checks were wrong and both were corrected against the header rather than filed. Asserting LZ4_slideInputBuffer non-NULL on a fresh state contradicts lz4.h, which says of that obsolete trio that they retain no history between calls; the pointer is legitimately NULL until a streaming LZ4_compress_continue call establishes a dictionary, which is what the check now encodes on both sides. Driving LZ4_compress_withState and LZ4_compress_continue through one state object then faulted under ASan in LZ4_read32 - withState leaves the object set up as a scratch state and the streaming path follows a stale dictionary pointer. That is caller error on a user-error surface, in a combination no documentation sanctions, so it is not filed; the battery now uses separate states and says why.

The ossfuzz row was swept by building all ten harnesses and running each against six inputs - raw data, a well-formed frame, a truncated frame, a hostile header declaring impossible sizes, random noise and an empty file - with any exit status above 128 counted as a failure, which a trapping process was confirmed to produce, at status 132. Sixty invocations, none crashed. For a fuzz harness that is the contract itself rather than a proxy for one, and the round-trip harnesses assert internally so real data drives a genuine oracle through them. The examples row required simple_buffer to print each of the three success lines it promises and frameCompress to produce a file the shipped CLI decompresses back to the exact input, which cross-checks the example against the tool.

The cmake row was swept by requiring the binary cmake produces to round trip, to emit an archive byte-identical to the make-built binary's, and to report the same version. That comparison is what surfaced MT-1. The remaining build systems are disclosed as unreachable rather than swept: meson is not installed, build/VS2022 targets MSVC and contrib/djgpp targets DOS, and none can be built on this Linux host. That row is named in the run report as the rules require.

New finding filed: MT-1 (Low, build-ci). build/cmake/CMakeLists.txt never defines LZ4IO_MULTITHREAD and mentions threads nowhere, while programs/Makefile probes for pthread and defines it, so a cmake-built lz4 announces itself as single-thread and `-T` does nothing there. Measured on a 20 MB input at level 9: the cmake binary takes 0.23s at both -T1 and -T4, the make binary goes from 0.24s to 0.10s. My first reading of this was Medium on the grounds that a documented flag was silently ignored, and that was wrong - running it without -q shows `warning: this executable doesn't support multithreading`. Nothing is silent, the output is correct, and the only loss is speed the tool says it is not delivering, so Low is the rubric's own answer rather than a downgrade. Recorded here because the reasoning turned on a measurement I nearly skipped.

All eight batteries pass on the final tree and the Verify command exits 0.

Dimension scores, now claiming the whole mapped surface for the first time in this run, since every row is swept or disclosed: correctness None, security None, error handling None, dependency hygiene None, documentation Low with DOC-2 and RING-1 open, developer experience Low with MT-1 open. These scores rest on eight batteries totalling well over seven hundred checks, each mutation-tested, plus the Verify command; they do not rest on a fresh full audit, and they are not one.

Convergence is not available to this run and the reason is structural, not a shortfall in the work. The Definition of done requires a full fresh-evidence audit inside this run scoring zero High and zero Medium in-envelope. The only full audit on this run's record is iteration 1, which found three Mediums, all since closed. A replacement audit would have to run in iteration 10, and the closing rule forbids an audit inside the closing window and requires the clean audit to predate it. So the run ends out of budget with the map complete, no High or Medium open, and three Lows carried.

Learnings: when a probe faults, decide whether the call was sanctioned before reading it as a defect - two of this iteration's three surprises were my own misuse of an obsolete API against a header that says plainly what it does. And measure before scoring: MT-1 was one `-q` away from being filed a full severity level too high, because the warning that makes it Low only prints when output is not suppressed.

Next: iteration 10 is the final one and writes the WRAPUP and handoff.

## iter 10/10 | e66c3630-130623 | 2026-08-17 | WRAPUP | done

Task: final iteration. Tidy the ledger and write the handoff rather than start work that cannot finish.

Changed: JOURNAL.md only. BACKLOG.md needed no tidying and was left byte-identical: Now and Next are empty, Later holds the three carried Lows each with a parseable severity, Settled classes holds the one class this run closed, and Declined and Converged are empty. There are no prose sections and no DONE annotations to remove.

Checkpoint: 9a051f0dd08ad2f8740276cd8b5f42872c8cc35f

Verification: the Verify command exits 0 with both differential engines reporting all tests completed, and all eight probe batteries pass on this tree. The Surface inventory lists twenty-one swept rows, one row disclosed as unreachable on this host, and no unswept row.

Convergence is not declared, and the reason is a structural one this run cannot repair in its last iteration. The Definition of done requires a full fresh-evidence audit inside this run scoring zero High and zero Medium in-envelope. The only full audit on this run's record is iteration 1, which scored three Mediums - all three have since been closed, along with a High the sweeps surfaced - so that audit cannot serve as the clean one. A replacement audit would have to run here, in the final iteration, and the closing rule forbids an audit inside the closing window and requires the audit a declaration cites to predate it. The evaluator gate is therefore not invoked either: it exists on the Definition of done path alone, and that path is not open. Nothing is being deferred to avoid a verdict; the gate simply has no declaration to check.

Handoff for the next run. Start a fresh session in this directory - the state files carry everything forward and a new session is the whole point of the clean context. The fast path to convergence is short: iteration 1 does a fresh full audit, which can lean on the eight kept batteries under .jeffy/probes/ rather than rebuilding instruments, since together they run well over seven hundred checks across every row and each has been mutation-tested. If that audit scores zero High and zero Medium, the run enters closeout immediately, works or declines the three carried Lows one per iteration, invokes the gate, and declares. A budget of five is ample and two runs of five beat one of ten.

Three things the next run should not have to rediscover. Every inventory row records the commit it was swept at, so a row whose implementing code has changed since is stale and flips back to unswept - `git diff --name-only <that commit> HEAD` against the row's paths is the check. Each battery declares the paths it covers in `.jeffy/probes/<row>/paths`, so an iteration touching lib/lz4frame.c knows without searching that lib-known-answers and lib-streaming own it. And the Lessons section of PLAN.md now holds eighteen rules learned by losing time to them in this run, over half of them about probe construction rather than about lz4.

The one unreachable row is meson, Visual Studio and DJGPP: meson is not installed here, build/VS2022 targets MSVC and contrib/djgpp targets DOS. A run on a host with meson installed should flip the meson part back to unswept and sweep it; the other two need Windows and DOS toolchains respectively and will stay unreachable on any Linux host.

Stall check: this iteration changed only JOURNAL.md and no BACKLOG.md item changed state, so it meets the letter of the stall definition. It is a WRAPUP, which the rule names as a ceremony entry that is never a stall and never forms the blocking pair.

Learnings: none new this iteration; the rules learned during the run are already in the Lessons section of PLAN.md.

Next: the run ends here, out of budget, with the map complete, no High or Medium open, and MT-1, RING-1 and DOC-2 carried as Lows.

## iter 1/10 | 77302546-142545 | 2026-08-17 | MT-1 | done

Task: MT-1 (Low, build-ci) - the cmake build shipped an lz4 without multithreaded compression, so -T did nothing there while the make build honoured it.

Changed: build/cmake/CMakeLists.txt (threads detected and LZ4IO_MULTITHREAD defined for the CLI targets), .jeffy/probes/aux-surfaces/run.sh (threading-parity and -T timing checks added to the cmake section), BACKLOG.md (MT-1 closed and deleted), PLAN.md (one Lessons line).

Checkpoint: b460aba137102c90af1073f29615ba81cd0135e9 (fix, battery and this entry), with the cmake inventory row re-recorded at that hash in the bookkeeping commit that follows - the row was stale the moment build/cmake changed, and the re-sweep evidence is the battery run above.

Verification: the filed reproduction was run first and reproduced exactly. The cmake binary at HEAD reported `*** lz4 v1.10.0 64-bit single-thread ***`, took 2267 ms at -T1 and 2262 ms at -T4 on a 20 MB level-9 input, and printed `warning: this executable doesn't support multithreading`, while the make binary went from 2553 ms to 934 ms on the same input.

The fix mirrors programs/Makefile rather than inventing a policy: that Makefile probes for pthread, defines -DLZ4IO_MULTITHREAD and links -pthread, and applies all of it to the lz4 target only, the library being single-threaded. The cmake side now runs find_package(Threads) with THREADS_PREFER_PTHREAD_FLAG once any CLI target is configured, and on success defines LZ4IO_MULTITHREAD=1 and links Threads::Threads on each of them, printing the same two status messages the make build prints. Both CLI targets get it because the make build's lz4c is a symlink to lz4 and is therefore already multithreaded there; giving cmake's separate lz4c executable the same support preserves that observable behaviour rather than extending it. Where Threads is not found the header default stands, which is 1 on Windows and 0 elsewhere - the same answer the Makefile computes.

Acceptance check, run against the rebuilt cmake binary: `lz4 --version` reports `*** lz4 v1.10.0 64-bit multithread ***`, and -T4 on the same 20 MB level-9 input takes 808 ms against 1875 ms at -T1, a 2.3x speedup where the two timings were previously equal. The multithreading warning is gone. The -T4 archive round trips to the exact input, and the make-built binary decodes that archive to the exact input too, so the new threading path is not producing a private format. Configuring with -DLZ4_BUILD_LEGACY_LZ4C=ON builds lz4c, which also reports multithread and round trips at -T4.

Battery ownership: the diff touches build/cmake/, which `.jeffy/probes/aux-surfaces/paths` declares, so that battery ran in this iteration and passes in 15 s.

The battery needed updating, because its cmake section was what let this defect sit behind a swept row: it compared the two builds' version numbers, and `1.10.0` matched while one binary shipped without threads. It now compares the threading token each build announces, checks that a binary announcing multithread does not warn that -T is unsupported, and measures -T1 against -T4 on both binaries, requiring the cmake speedup to reach at least half the make speedup. That last check is written as a ratio of ratios rather than a fixed millisecond threshold so a loaded machine slows both sides and neither number is trusted alone, and it skips itself with a note when the make binary shows no speedup on the host at all.

Both new checks were mutation-tested separately, because the first mutant never reaches the second check. Reverting build/cmake/CMakeLists.txt to its HEAD version in a scratch copy produced `FAIL: cmake build reports single-thread, make build reports multithread`. Since that mutant fails the token check and the timing check is gated on both builds announcing multithread, a second mutant kept the fix and added -DLZ4_NBWORKERS_MAX=1 to the cmake CLI targets only, which announces multithread but clamps -T4 to one worker - the plumbing-bug shape the timing check exists to catch. It produced `FAIL: cmake -T4 barely helps (310ms vs 323ms) while make -T4 does (334ms vs 148ms)`.

Verify command: exit 0 on the final tree, with `make check` and the four named test targets green, the block fuzzer reporting `1619 / 1619 - all tests completed successfully` and frametest reporting `All tests completed`.

Change discipline: no public interface moved. LZ4IO_MULTITHREAD is a build-level macro that programs/lz4conf.h already documents as needing to be set at build level, and programs/README.md already documents -T and LZ4_NBWORKERS_MAX for the CLI generally rather than per build system, so no documentation contradicts the new behaviour. The contract preserved is that the cmake-built and make-built binaries stay interchangeable: the battery still requires them to produce byte-identical archives and now also to agree on threading mode.

Learnings: sweeping an alternate build system by comparing version numbers against the reference build certifies nothing about its features - the two builds agreed on 1.10.0 while one shipped without multithreading. Compare the feature tokens the binaries announce and drive the feature itself. Also, lz4 has no -o flag; output is positional, and `lz4 -9 -T4 -f in.bin -o out.lz4` exits 1 with `Incorrect parameters` in about 3 ms, which reads as an impossibly fast compression if the exit status is not checked.

Next: RING-1 is the top of the queue - the lz4.h disagreement between LZ4_DECODER_RING_BUFFER_SIZE and LZ4_decoderRingBufferSize below block size 16. The run then has DOC-2, and needs a full fresh-evidence audit before it can converge, since the Definition of done requires one inside this run.

## iter 2/10 | 77302546-142545 | 2026-08-17 | RING-1 | done

Task: RING-1 (Low, docs) - LZ4_DECODER_RING_BUFFER_SIZE and LZ4_decoderRingBufferSize sit next to each other in lib/lz4.h, the macro presented as the static-allocation form of the function, and they disagree on part of the input domain without either comment saying so.

Changed: lib/lz4.h (the function's doc block now states the clamp and what makes a maxBlockSize invalid; the macro's comment now names the range it is valid over and points at the function outside it), lib/lz4.c (the same two additions to its copy of the doc block, so the sibling does not contradict the header), doc/lz4_manual.html (regenerated from the edited header), BACKLOG.md (RING-1 closed and deleted), PLAN.md (one Lessons line).

Checkpoint: d511e3a11da84ca9ddd5d7b8e9f24d82022651b3

Verification: the filed reproduction was run first and reproduced exactly - at maxBlockSize 1 the function returns 65566 and the macro 65551.

Rather than stop at the single filed value, the whole domain was mapped before deciding what to write, which is what the disagreement's boundaries had to come from: the two disagree at -1, 0, 1, 15 and at LZ4_MAX_INPUT_SIZE+1, and agree at 16, 17, 1024, 65535, LZ4_MAX_INPUT_SIZE-1 and LZ4_MAX_INPUT_SIZE. So the agreement range is exactly [16, LZ4_MAX_INPUT_SIZE], inclusive at both ends, and that is what the macro's comment now states rather than a rounded approximation of it.

The documentation is a claim about a range, so it ships with the check that drives both boundaries and both sides of each. That check asserts the clamp at 0, 1 and 15 all equal the answer at 16; asserts 0 for -1, for -1073741824 and for LZ4_MAX_INPUT_SIZE+1; asserts macro and function agree at the six in-range points above; and asserts they disagree at all five out-of-range points, so the new warning is not pointing at a hazard that does not exist. It reports `contract check: PASS` and exits 0 against the edited header.

No code changed, only comments, and that was proved rather than asserted, because taking it on trust would have flipped most of the Surface inventory to stale: nearly every library row is implemented in lib/lz4.c or lib/lz4.h. Both versions of all five library sources were compiled into identical relative paths with identical flags and the objects compared - lz4.o, lz4hc.o, lz4frame.o, lz4file.o and xxhash.o are each byte-identical between HEAD and the working tree. No row's implementing code changed, so no row is stale and none was re-recorded.

Battery ownership: the diff touches lib/lz4.h, lib/lz4.c and doc/lz4_manual.html, which four paths files declare. All four batteries ran in this iteration and pass - generated-manuals PASS, deprecated-api 57 checks 0 failures, lib-known-answers 153 checks 0 failures, lib-streaming 410 checks 0 failures. The last of those is RING-1's own third acceptance clause.

doc/lz4_manual.html had to be regenerated in the same iteration, because the generated-manuals battery diffs the committed manual against what contrib/gen_manual produces from the header today; editing the header alone would have left the published manual stale and failed that battery. The generator was invoked directly rather than through `make manuals`, per the standing Lesson. The regenerated diff is five added lines and two changed ones, confined to the LZ4_decoderRingBufferSize entry, and the entry keeps its prototype, which the battery's second check enforces.

Verify command: exit 0, with `make check` and the four named targets green, the block fuzzer reporting `1130 / 1130 - all tests completed successfully` and frametest reporting `All tests completed`.

Severity was not revisited. RING-1 stays Low for the reason it was filed: reaching the disagreement requires a caller to pick a block size under 16 bytes on a user-error surface, and the fix is a documentation fix, which is what the class already said.

Learnings: a comment-only edit to lib/lz4.h or lib/lz4.c looks like it makes most of the inventory stale. Compiling both versions into the same relative paths with the same flags and comparing the objects settles it mechanically, and byte-identical objects mean nothing needs re-sweeping. Also, when a doc comment in a public header is edited, the generated manual under doc/ must be regenerated in the same iteration or the generated-manuals battery fails.

Next: DOC-2 is the last open task - the raw doxygen markup that contrib/gen_manual passes through into doc/lz4frame_manual.html for the LZ4F_decompress entry. After it the ledger is empty, and the run still needs a full fresh-evidence audit before it can converge, since the Definition of done requires one inside this run.

## iter 3/10 | 77302546-142545 | 2026-08-17 | DOC-2 | done

Task: DOC-2 (Low, docs) - the published doc/lz4frame_manual.html rendered raw doxygen markup to readers, because contrib/gen_manual has no doxygen support and passes unknown tags through as literal text.

Changed: lib/lz4frame.h (the LZ4F_decompress doc block rewritten into the prose idiom its siblings use), doc/lz4frame_manual.html (regenerated from the edited header), BACKLOG.md (DOC-2 closed and deleted, leaving the ledger empty), PLAN.md (one Lessons line).

Checkpoint: abbc158afd1a92599225e22dfc4c949a634acfec

Verification: the filed reproduction ran first and reproduced - `grep -cE '@(param|retval|pre|post|see|p) ' doc/lz4frame_manual.html` returned 15.

The finding's two scope claims were checked rather than taken on trust, since both decide how much work this is. All 19 doxygen-tag lines in lib/lz4frame.h fall inside the LZ4F_decompress block, so the defect really is one block and not a file-wide idiom; and `grep -c '^/\*!' lib/lz4frame.h` returns 25, so the "24 siblings" the acceptance names is exact. The house idiom those siblings use was read off them rather than invented: `@paramName <sentence>` for parameters, `@return : <sentence>` with aligned continuation, `note 1 :` and `note 2 :` for notes, `Warning :` for warnings.

Every fact the doxygen block stated is carried over: the call-repeatedly-until-0 contract, the consume-and-produce accounting, the typical loop, all six parameters, the three return cases with the not-yet-complete meaning of a positive value and the non-resumable dctx after an error, the post-conditions on the two size pointers and on the valid range of dstBuffer, the three notes, the getFrameInfo warning about advancing srcBuffer, and the cross-references. The `@pre` line was folded into the dctx parameter sentence it duplicated, which drops a repetition rather than a fact.

One fact was corrected rather than carried over. The block documented the options parameter as `optionsPtr`, a name that appears nowhere in the code: the header prototype calls it `dOptPtr` and the definition in lib/lz4frame.c calls it `decompressOptionsPtr`. The rewrite uses `dOptPtr`, the name a reader of lz4frame.h actually sees on the prototype directly below. Its documented behaviour was verified before being restated - lib/lz4frame.c zero-initialises a local LZ4F_decompressOptions_t and substitutes it when the pointer is NULL, so "one can provide NULL, in which case all options are set to default" is accurate. This is recorded here rather than filed as its own task: it lived inside the block this task owned and is fixed, and filing a ledger item for completed work is the ledger churn the backlog discipline forbids.

Acceptance check: `grep -cE '@(param|retval|pre|post|see|p) ' doc/lz4frame_manual.html` now returns 0, and a wider grep for any of those tags plus @note and @warning finds none anywhere in the manual. `sh .jeffy/probes/generated-manuals/run.sh` passes, which also confirms the entry kept its prototype - the block still opens with the `/*!` marker, so the generator emits the declaration rather than turning the first line into a chapter heading.

No code changed. As in the previous iteration that was proved rather than assumed, because nearly every library row is implemented in these files: all five library sources compiled from HEAD and from the working tree into identical relative paths with identical flags produce byte-identical objects. No Surface inventory row is stale and none was re-recorded.

Battery ownership: the diff touches lib/lz4frame.h and doc/lz4frame_manual.html, declared by three paths files. All three ran and pass - generated-manuals PASS, lib-known-answers 153 checks 0 failures, lib-streaming 410 checks 0 failures.

Verify command: exit 0, with the block fuzzer reporting `1658 / 1658 - all tests completed successfully` and frametest reporting `All tests completed`.

Learnings: the doc idiom in lib/*.h is prose - `@paramName <sentence>`, `@return :`, `note N :`, `Warning :` - and contrib/gen_manual has no doxygen support, so any doxygen tag written into a public header leaks verbatim into the published manual. Also, a doc block can name a parameter the code does not have; when rewriting one, check the documented names against the prototype rather than only the prose around them.

Next: the ledger is now empty and no unswept row remains, but the run cannot converge yet - the Definition of done requires a full fresh-evidence audit inside this run, and this run has none. Iteration 4 runs that audit, leaning on the eight kept batteries rather than rebuilding instruments. If it scores zero High and zero Medium the run enters closeout, and with the ledger empty and more than 3 iterations left the evaluator gate runs in iteration 5 rather than being deferred to the declaration.

## iter 4/10 | 77302546-142545 | 2026-08-17 | AUDIT | audit

Task: the full fresh-evidence audit the Definition of done requires inside this run. The ledger was empty and no Surface inventory row was unswept or stale, so this pass re-scored every applicable dimension against the rubric and the Operating envelope rather than sweeping.

Changed: PLAN.md (the Environment fingerprint's exclusion list, corrected to what its own stated command produces today), JOURNAL.md. No finding was filed, so BACKLOG.md is unchanged and still empty.

Checkpoint: 22e2e553649f3252c587e673700f49417132b1e6

Verification: this pass claims the whole mapped surface, which it is entitled to for the first time in either run - 21 of 21 rows are swept and the 22nd is disclosed unreachable on this host. All eight kept batteries were executed on this tree and pass: lib-known-answers 153 checks, lib-streaming 410 checks, deprecated-api 57 checks, and cli-surface, cli-list-mode, declared-length-skips, generated-manuals and aux-surfaces each PASS. The Verify command exits 0, with the block fuzzer reporting 1825 / 1825 and frametest reporting All tests completed.

Correctness: None. The evidence is the 620 numbered known-answer and invariant checks above plus the two seeded round-trip differential engines in the Verify command, which compare decompressed output byte-for-byte against the original.

Security: None. Both differential engines were rebuilt under AddressSanitizer, UndefinedBehaviorSanitizer and LeakSanitizer and run at seed 7 for 90 s each: the block engine completed 1570 / 1570 cases and the frame engine reached case 612, with zero sanitizer reports of any kind between them. This is the oracle the Verify command does not provide, since the default build carries no sanitizer. The ossfuzz row adds 60 harness invocations over hostile, truncated and random input, all clean.

Testing: None, and this is the dimension the Method demands an isolated run for before it can be scored at all. Each of the nine shell suites the Verify command reaches - test-lz4-basic, test-lz4-multiple, test-lz4-multiple-legacy, test-lz4-frame-concatenation, test-lz4-testmode, test-lz4-contentSize, test-lz4-dict, test-lz4-opt-parser and test-lz4-skippable - was run alone in its own empty directory with only lz4, lz4cat, unlz4 and datagen reachable. All nine exit 0, and none leaves a single file behind afterwards. So there is no order dependence and no suite passing on state a sibling leaked. The suite is built for this: every script carries its own distinct FPREFIX and removes it on a trap.

The first attempt at that run reported test-lz4-basic failing with `lz4cat: not found`, and it was my harness rather than the suite - tests/Makefile puts ../programs on PATH, where lz4cat and unlz4 live as symlinks I had not copied. Recorded because it is the second time this run that a probe fault turned out to be an unsanctioned call rather than a defect.

Error handling: None. cli-list-mode and declared-length-skips both pass; the container-declared-length class remains settled class-complete and its implementing code has not changed since settlement.

Documentation: None. generated-manuals passes, so both published manuals match what contrib/gen_manual produces from their headers today, every checked function keeps its prototype, no doxygen tag reaches a heading or the contents list, and the generator is deterministic across two runs. A flag comparison between programs/lz4.1.md and the string literals in programs/lz4cli.c, expanding the `--[no-]x` form on both sides as the standing Lesson requires, finds no CLI flag undocumented. DOC-2 and RING-1 were closed earlier in this run.

Code quality: None. Compiling all five library sources and all of programs/ directly with gcc under the project's own DEBUGFLAGS sets from lib/Makefile and programs/Makefile produces zero warnings. Compiled directly rather than through make, per the standing Lesson about the object cache returning silently.

Architecture: None. Every shipped source file under lib/ and programs/ maps to a swept Surface inventory row; the enumeration over `lib/*.c lib/*.h programs/*.c programs/*.h` returns no uncovered file, so no orphaned or dead module is sitting outside the map.

Dependency hygiene: None. The only vendored dependency is xxhash inside lib/, a trimmed 0.6.5 subset. It is old relative to upstream, and that is stated rather than filed: age is not a known vulnerability, no defect in it was reproduced here, and its role is the frame integrity checksum, which the project documents as non-cryptographic. Nothing in the build fetches over the network.

Developer experience: None. MT-1 was closed earlier in this run, and the make and cmake builds now agree on threading mode and still produce byte-identical archives.

Observability and UX: None. The CLI was driven through five common user errors and each gives a specific diagnostic and a non-zero exit: a non-lz4 input reports `Error 40 : Unrecognized header : Magic Number unreadable`, a missing input and a missing output directory each report the path with `No such file or directory`, and an unknown long option reports `Incorrect parameters` rather than being ignored.

Performance: None from the probes this pass ran, which is what it claims and no more - the -T1 against -T4 measurement on a 20 MB level-9 input in the aux-surfaces battery, and benchmark mode required to report a plausible compression ratio in cli-surface. No profiling was done and none is claimed.

Accessibility: not applicable and recorded as such. The project ships a library and a terminal CLI, with no graphical or assistive-technology surface for the dimension to apply to.

Two things were checked and deliberately not filed. `lz4 -99` exits 0 and compresses at level 12, byte-identical to `-12`, with no diagnostic - but programs/lz4.1.md states plainly that "Values above 12 are considered the same as 12", so it is documented behaviour and not a swallowed error. And an apparent gap of two undocumented flags, --favor-dec and --long-word, was an artifact of my own regex: the real flag is --favor-decSpeed, whose capital letter truncated the match, and --long-word is prose in the man page's description of long options.

One correction was made rather than filed. The Environment fingerprint said its exclusion list was derived by a named command, and re-running that command today does not reproduce the list it records: the command returns 37 names, of which the Command's closure reaches 12, leaving 25 excluded - including four aggregate targets and the listing target itself, which the old list omitted - while abiTests, versionsTest and checkTag are absent from the TEST_TARGETS variable the command prints and so can never be returned by it, though they are genuinely excluded and cannot run on this host. The line now states all of that, including that the two differential engines are reached despite test-fuzzer and test-frametest appearing among the excluded targets, because the Command builds and runs those binaries directly. This is loop memory rather than project surface, so it is a state-file correction and not a backlog item, and it matters because the declaring iteration is required to re-read this line and stand on it. Every other fingerprint claim was re-executed and reproduces exactly: ronn is absent, `gcc -m32` fails for want of Scrt1.o, `gcc -llz4` fails, neither liblz4.so nor /usr/include/lz4.h exists, and tests/goldenSamples holds exactly one file whose only referencing script the Command does run.

Closeout has begun. This audit scored zero High and zero Medium in-envelope, so the run stops auditing for the rest of its budget - no replenishment and no further full audit - and finishes by converging.

Stall check: this iteration changed only PLAN.md and JOURNAL.md and no BACKLOG.md item changed state, which meets the letter of the stall definition. It is an AUDIT that files nothing, which the rule names as a ceremony entry that is never a stall and never forms the blocking pair.

Learnings: before reading a probe's failure as a defect, check whether the harness gave the code everything the real invocation gives it - the isolated suite run failed first on a missing lz4cat symlink that tests/Makefile supplies via PATH. And an exclusion list in a state file is a claim that has to keep reproducing from the command it names, not a list written once; re-run that command during the audit that a declaration will cite.

Next: iteration 5 runs the adversarial evaluator gate. The ledger is empty, this run has a clean full audit on record, and six iterations remain, which is well past the three the rule requires for running the gate early rather than deferring it to the declaration. If it returns PASS and the closing conditions hold, that same iteration declares.

## iter 5/10 | 77302546-142545 | 2026-08-17 | EVALUATOR | converged

Task: run the adversarial evaluator gate and, if the closing conditions hold, declare convergence in this same iteration.

Changed: .jeffy/evaluator/77302546-142545-1.md (the gate's artifact), BACKLOG.md (the Converged line), JOURNAL.md.

Checkpoint: d6f43e05819d7f1d551926af9f5d4aec4c2b91da

Verification: Evaluator: PASS - invocation 1 of this run, invoked at iteration 5 of 10, re-ran the Verify command, all three closed tasks' acceptance checks and all eight batteries, independently mutation-tested both new battery checks, and exercised a seven-configuration cmake matrix, finding no High or Medium.

The gate was run early rather than deferred, as the rule directs: the ledger first emptied with a clean full audit already on this run's record, and five iterations remained after this one, well past the three the rule requires. It was told its run-id, that it was invocation 1, and that it was invoked at iteration 5 of 10, and it wrote .jeffy/evaluator/77302546-142545-1.md before returning any verdict. That artifact opens by naming the run-id, the ordinal and the invoking iteration, defines $SCRATCH once for every location outside this repository and uses no machine-absolute path anywhere, lists every command it ran with that command's real exit status, and closes with PASS on its own line. This iteration's checkpoint commits it.

What the gate actually executed, in its own numbers. The Verify command exit 0, with the block fuzzer at 1620 / 1620 and frametest reporting All tests completed. MT-1 re-checked from a fresh cmake build tree: Found Threads TRUE, both binaries reporting multithread, and on a 20 MB level-9 input two independent pairs at 267 ms against 133 ms and 278 ms against 132 ms with every invocation's exit status checked, the -T4 archive round tripping under cmp. RING-1 re-checked by compiling its own program against lib/lz4.c rather than reading the header: 0 for -1, INT_MIN, LZ4_MAX_INPUT_SIZE+1 and INT_MAX, a non-error answer at LZ4_MAX_INPUT_SIZE, the clamp for every value in 0 to 15, and function equal to macro across 16 to 99999. DOC-2 re-checked by a vocabulary diff of the old block against the new one, finding the only words lost are doxygen tags, grammatical variants and the string optionsPtr, with all sixteen documented facts surviving and dOptPtr confirmed as the prototype's real parameter name. All eight batteries exit 0.

It did not take this run's mutation testing on trust. It rebuilt both mutants itself: reverting build/cmake/CMakeLists.txt in a scratch worktree drove the battery to exit 1 with the threading-token failure, and clamping only the cmake CLI to LZ4_NBWORKERS_MAX=1 drove it to exit 1 with the timing failure. Neither new check is inert. It also confirmed /bin/sh here is dash and accepts the arithmetic ternary, the function defined inside an if, and date +%s%N, and replayed the timing arithmetic over synthetic values to confirm it fires on a no-gain cmake build and skips on a host with no make-side gain.

The cmake matrix is the part this run had not covered and the gate did: LZ4_BUILD_CLI=OFF with a baseline control, BUILD_SHARED_LIBS=OFF, LZ4_BUILD_LEGACY_LZ4C=ON, CMAKE_BUILD_TYPE=Debug under -pedantic-errors with zero warnings, a bundled subproject, a bundled subproject whose parent found Threads first, and cmake --install in two configurations - all configure and build at exit 0. It read the generated flags file to confirm lz4c keeps both defines rather than one replacing the other: C_DEFINES = -DENABLE_LZ4C_LEGACY_OPTIONS -DLZ4IO_MULTITHREAD=1.

Closing conditions, each checked in this iteration. The full fresh-evidence audit is iteration 4 of this run, which scored zero High and zero Medium in-envelope across the whole mapped surface. The Surface inventory lists 21 swept rows, 1 row disclosed unreachable on this host, and 0 unswept. BACKLOG.md holds no open task in Now, Next or Later, so no Low is carried and there is none to list. The only commits since that clean audit are none at all - git log from the audit's bookkeeping commit to HEAD is empty - and the only working-tree change was the gate's own artifact. The Verify command was re-run by me in this iteration and exits 0, reporting 1723 / 1723 all tests completed successfully for the block engine and All tests completed for the frame engine.

The Oracle class and Environment fingerprint were re-read as the declaring iteration must. The Oracle class still describes what the command grades: a default-flags build, the CLI shell conformance suite, and two seeded randomized round-trip differential engines, with no memory-safety oracle among them - which is why iteration 4 supplied that separately under ASan, UBSan and LeakSanitizer. The Environment fingerprint was corrected in iteration 4 to reproduce from its own stated command and every one of its claims was re-executed there. No entry in this run claims a green result for any asset the fingerprint says the command cannot reach: the batteries, the sanitizer engines and the isolated shell suites were all built and run directly rather than through an excluded make target, and none of the 25 excluded targets, nor abiTests, versionsTest or checkTag, is claimed as green anywhere.

The gate recorded four observations that it did not raise as REJECT reasons, and none is fixed here, because a fix after a PASS invalidates that PASS and spends an invocation the declaration needs. They are: leftover doxygen tags in lib/lz4file.h and lib/lz4hc.h, neither of which is published as a manual so nothing leaks to a reader; a duplicated LZ4 File Decompression heading in lib/lz4file.h; ENABLE_LZ4C_LEGACY_OPTIONS being referenced only in build/cmake/CMakeLists.txt and by no C source; and the new timing check being the one battery verdict that depends on wall-clock timing. The third was checked here far enough to confirm it is neither High nor Medium rather than accepted on the gate's word: the macro is indeed referenced by no C source, and the make build's lz4c is a symlink to lz4, so neither build system produces an lz4c with legacy option handling, no build is broken and no user gets a wrong result. All four carry to the run report and to the next run, whose fresh audit re-examines the surface from scratch; they are not written into BACKLOG.md here, because refilling the ledger during the convergence sequence is exactly what the closing rule keeps out of it.

Learnings: none new. The gate confirmed the run's own evidence rather than overturning it, and the one thing it did that this run had not - the cmake configuration matrix - is worth doing inside the iteration that changes a build system rather than leaving to the gate.

Next: the run is converged. The Converged line naming this iteration's checkpoint is appended under ## Converged in BACKLOG.md, and the run report follows.
