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

## iter 1/10 | 626d9b82-054124 | 2026-09-02 | AUDIT | audit

Task: First audit. Fill the Operating envelope, the Surface inventory, and the Verify command block in PLAN.md; enumerate the artifact-producing channels; probe the whole surface breadth-first and file findings.

Changed: PLAN.md (envelope surfaces, 18 inventory rows, Verify command / Oracle class / Environment fingerprint / duration / summary pattern, Stated counts table), BACKLOG.md (5 findings), .gitignore (loop state), JOURNAL.md.

Checkpoint: f466dc259d93e996b470500639ed5af13c36cbea (no stall: this iteration changed .gitignore and added five ledger items)

Verification:
- Verify command set to `{ [ -f build/CMakeCache.txt ] || cmake -S . -B build -DUTF8PROC_ENABLE_TESTING=ON; } && cmake --build build -j4 && ctest --test-dir build --output-on-failure`. Through quiet-verify.sh: green (1s), summary line `100% tests passed, 0 tests failed out of 10`.
- Stated counts armed and executed: `check-claims.sh .` reports `claims: 2 checked, 0 mismatched, 0 errored, 0 skipped`.
- Artifact channels enumerated by command, not recall. Packaging manifests: `ls Cargo.toml package.json MANIFEST.in pyproject.toml *.gemspec *.nuspec Dockerfile` finds none. The only release channel is `make dist`, which is `git archive master`; `git archive master --prefix=x/ | tar t | grep -E 'PLAN\.md|BACKLOG\.md|JOURNAL|\.jeffy'` returns nothing (exit 1), so the loop's state files cannot reach a release tarball from master. `grep -n 'install(' CMakeLists.txt` and the Makefile `install` target ship only utf8proc.h, the libraries, libutf8proc.pc and the CMake package files. `.github/workflows/cmake.yml` uploads only `build/libutf8proc.*`. No channel can reach the state files; nothing filed.
- Breadth-first probes, all executed this iteration and all against the current tree:
  - Documented-option liveness: for each of the 14 documented utf8proc_option_t flags, searched every valid codepoint under six base option sets for an input where adding the flag changes utf8proc_map output. Result: 13 live, UTF8PROC_STABLE inert; a two-codepoint probe on U+0915 U+093C (a composition exclusion) is also inert. Filed as U1.
  - Memory safety, clang -fsanitize=address,undefined -fno-sanitize-recover=all: 400000 random-codepoint utf8proc_map calls over random flag combinations, clean; 200000 random raw-byte inputs through the project's own LLVMFuzzerTestOneInput, clean; 300000 utf8proc_reencode/utf8proc_normalize_utf32 calls on in-range UTF-32 buffers, clean, with no result exceeding the documented 4-bytes-per-codepoint bound; 200000 utf8proc_decompose two-pass calls with exact-size and deliberately short buffers, clean, and the required-size return matched the written size every time.
  - Error masking in seqindex_write_char_decomposed (`written += utf8proc_decompose_char(...)` tested only against `written < 0`, so a nonzero prefix could mask a negative error): swept every codepoint with DECOMPOSE|COMPAT|CASEFOLD with and without REJECTNA. REJECTNA rejected the unassigned codepoints and produced no other divergence; the masking path is unreachable with the current tables. Not filed - no evidence.
  - Strict-warning build: `make clean && make utf8proc.o` with -Wsign-conversion -Wall -Wextra -Wc++-compat -pedantic compiles clean.
  - Corpus reality check: normtest and graphemetest were run directly and print the number of corpus lines they consumed, so the two conformance corpora demonstrably execute rather than being silently skipped. Both figures are now Stated counts rows.
- Dimension scores. This audit is breadth-first and shallow by design and NO Surface inventory row is swept, so every score below claims only what the probes above exercised and says nothing about the unexamined remainder (0 of 18 rows swept):
  - correctness: Medium (U1 - a documented option that selects nothing).
  - documentation: Medium (U1), plus Low (U5 - lump.md omits one lump rule).
  - testing: Low (U2 fuzz harness guard inverted, U3 version assertion compiled out of the ctest suite, U4 iscase absent from the ctest suite).
  - security: None observed - the sanitizer sweeps above found nothing, over the probed inputs only.
  - error handling: None observed - the REJECTNA sweep and the two-pass buffer contract both held.
  - architecture, code quality, dependency hygiene, developer experience, observability: None observed. The library has no runtime dependencies; dependabot covers the workflows; data/Manifest.toml pins the generator's julia packages.
  - performance: not scored - no measurement taken this iteration.
  - UX and accessibility: not applicable - utf8proc is a C library with no user-facing surface.

Learnings: The verify command must not reconfigure CMake every iteration - `cmake -S . -B build` re-runs `file(DOWNLOAD ...)` unconditionally and pulls about 2.9 MB from unicode.org each time, so the command configures only when build/CMakeCache.txt is absent. The ctest summary line's first integer is the pass percentage rather than the test total, so Verify count is deliberately left empty. julia is not installed on this host, which is why the Makefile `check` target cannot be the gate.

Next: U1 is the top of the queue; the 18 unswept Surface inventory rows outrank the four open Lows.

## iter 2/10 | 626d9b82-054124 | 2026-09-02 | SWEEP | done

Task: Sweep Surface inventory rows. The queue puts unswept rows above every open Medium, and 18 of 18 rows were unswept, so this iteration built and ran known-answer batteries rather than starting task U1.

Changed: .jeffy/probes/ (nine batteries plus a shared lib), PLAN.md (nine inventory rows flipped), JOURNAL.md. Also corrected the run-id in the iteration 1 heading, which had been derived from local time instead of the started_at field of the loop state; the entry's content is untouched.

Checkpoint: b5c9d65c651b6fd91291df2e08befd33cefad2ea (no stall: nine .jeffy/probes batteries added and nine inventory rows flipped)

Verification:
- Nine rows swept, each by an executed known-answer or invariant battery under .jeffy/probes/, never a run-without-crash probe: version-errmsg 26/26, utf8-codec 52/52, property-category 49/49, case-mapping 45/45, charwidth 29/29, grapheme-break 26/26, decompose-char 60/60, decompose-string 20/20, normalize-compose 36/36.
- Every battery was observed failing before it was trusted. Each README records the exact source mutation, the checks it reddened and the resulting score: the surrogate guard in utf8proc_iterate widened to 0xff (utf8-codec 50/52), the first category_string entry rewritten to "Zz" (property-category 46/49), the titlecase exclusion deleted from utf8proc_isupper (case-mapping 44/45), charwidth_ambiguous forced to 0 (charwidth 24/29), the GB3 arm flipped to true (grapheme-break 25/26), the Hangul trailing-jamo guard forced (decompose-char 58/60), the canonical-ordering guard widened to 1000 (decompose-string 19/20), the Hangul V-index guard forced closed (normalize-compose 32/36), and UNICODE_VERSION rewritten in data/Makefile (version-errmsg 25/26). Every edit was reverted from a copy taken before it, and all nine batteries are green again on the restored tree.
- Documented parameters were exercised at two or more values that must change the output wherever the row owns one: every filter option of utf8proc_decompose_char at both polarities, every entry of the lump.md table plus the rule that file omits, all three NLF targets over all four NLF sources, STRIPCC at four distinct control classes, UTF8PROC_STABLE at both polarities over a composition exclusion, and a null versus non-null custom_func and grapheme-break state pointer.
- One invariant I wrote was wrong and the battery caught it rather than the code: "every canonical decomposition yields only valid codepoints" fails on all 2048 surrogates, which utf8proc_decompose_char passes through unchanged because it documents NOTASSIGNED only outside 0..0x10FFFF and utf8proc_iterate is what rejects surrogates on input. The invariant now holds over valid codepoints and pins the surrogate pass-through separately.
- check-claims.sh: 11 checked, 0 mismatched, 0 errored, 0 skipped.
- Verify through quiet-verify.sh: green (1s), 100% tests passed, 0 tests failed out of 10.
- No new finding. The sweep corroborated two already on the ledger: normalize-compose reproduces UTF8PROC_STABLE having no effect at either polarity (U1), and decompose-char drives the Zl/Zp lump rule that lump.md does not list (U5). Nothing else in envelope surfaced.

Learnings: A battery invariant is a claim about the contract, not about the code, and writing one that the code correctly violates costs an iteration to diagnose - assert the documented boundary (utf8proc_decompose_char's range check is 0..0x10FFFF, which admits surrogates) rather than the intuitive one. Mutation-testing each battery before trusting it is what turned that from a suspicion into an answer.

Next: nine rows remain unswept - public header contract, generated data tables, reencode and allocation API, normalization convenience wrappers, build and install surface, test harness, fuzz harness, benchmarks, and Unicode data generation. The map still outranks the open Medium.

## iter 3/10 | 626d9b82-054124 | 2026-09-02 | SWEEP | done

Task: Sweep the remaining Surface inventory rows. Nine of eighteen were unswept and the map still outranks the two open Mediums.

Changed: .jeffy/probes/ (eight new batteries plus a jb_external helper in the shared lib), BACKLOG.md (two new findings), PLAN.md (eight rows flipped, one marked unreachable), JOURNAL.md.

Checkpoint: 4335fd487f6eda3aa76a0b2acf166dfccab6c754 (no stall: eight batteries added, eight rows flipped, two findings filed)

Verification:
- Eight rows swept by executed batteries: reencode-map 23/23, norm-wrappers 28/28, data-tables 17/17, header-contract 59/59, build-install 26/26, test-harness 17/17, fuzz-harness 7/7, benchmarks 16/16. One row, Unicode data generation, is marked unreachable on this host: data/Makefile's generator rules require julia and `which julia` finds none, so no sweep of data_generator.jl is possible here and a disclosure is the honest answer rather than a checkbox.
- Every battery was observed failing before it was trusted, one source mutation each, each reverted from a copy taken beforehand: the reencode NUL store set to 1 (17/23), COMPAT dropped from utf8proc_NFKD (25/28), comb_index narrowed from 10 bits to 9 (15/17), UTF8PROC_STRIPNA moved to bit 15 (58/59), the Makefile's major-version symlink repointed at a nonexistent target (25/26), tests.c's failure exit replaced by a bare return (16/17), the fuzz harness's oversized-input guard returning 1 (6/7), and bench.c's unrecognized-option diagnostic deleted (15/16). Every battery is green again on the restored tree and `git status` shows no source file modified.
- Two findings surfaced by the sweep and filed at rubric severity in this iteration. U7 (Medium, docs): the committed MANIFEST names `lib/libutf8proc.so.2` where `make install` creates `lib/libutf8proc.so.3` - `make manifest && diff MANIFEST MANIFEST.new` returns exactly that one line. It survives because the install test reads the freshly generated MANIFEST.new, never the committed file, and distcheck greps MANIFEST only for the soname, which the stale line still contains. U6 (Low, build-ci): utf8proc.h fails to compile under `cc -std=c90 -pedantic-errors`, on trailing commas in enumerator lists and on three bitfields whose base type is utf8proc_uint16_t; NEWS 2.11.0 records a C90 build fix and the header does reach C90 with -Wall -Wextra -Werror, which is the level the header-contract battery pins.
- Two batteries deliberately stop short of a check that a filed finding blocks, and say so in their READMEs rather than pinning the defect: build-install compares the staged tree against the manifest make generates rather than the stale committed one (U7), and fuzz-harness does not claim the UTF-32 path is exercised, because the inverted allocation guard makes it unreachable (U2). Each gains its check when the finding closes.
- The batteries also carry the project's only sanitizer coverage: fuzz-harness runs a random corpus through the OSS-Fuzz entry point under AddressSanitizer and UndefinedBehaviorSanitizer with -fno-sanitize-recover=all. The Verify command has none.
- Test isolation, which PLAN.md's audit discipline requires before scoring Testing clean: every ctest program was run individually rather than only through the suite, and all ten pass alone. The shared harness's check() was driven at both polarities to prove it can fail.
- check-claims.sh: 19 checked, 0 mismatched, 0 errored, 0 skipped.
- Verify through quiet-verify.sh: green (1s), 100% tests passed, 0 tests failed out of 10.

Learnings: A battery certifies a row only if it is green, so a finding the sweep surfaces must be filed and left out of the battery rather than pinned into it - record the omission in the battery README with the task id, or the next reader cannot tell a gap from an oversight. Mutating a Makefile or a shell script with sed needs the pipe and dollar characters escaped or the edit silently does not apply and the battery reads as green under a mutation that never happened; check `git status` after each mutation round.

Next: the map is complete - seventeen rows swept and one disclosed as unreachable, none unswept. The queue is now the two open Mediums, U7 first.

## iter 4/10 | 626d9b82-054124 | 2026-09-02 | U7 | done

Task: U7 (Medium, docs) - the committed MANIFEST named a symlink `make install` does not create.

Changed: MANIFEST (regenerated), Makefile (the distcheck MANIFEST assertion), .jeffy/probes/build-install (a check against the committed MANIFEST, README, claims), .jeffy/probes/*/README.md (removed stated measurements with no recorded derivation), BACKLOG.md, JOURNAL.md.

Checkpoint: 9d6bafccc5d33e5349f0d7585dd63c08cd8288fe (no stall: MANIFEST and Makefile changed, U7 removed from the ledger)

Verification:
- The filed reproduction was run first, against the tree as it stood: `make manifest && diff MANIFEST MANIFEST.new` exited 1 on the single line `lib/libutf8proc.so.2` versus `lib/libutf8proc.so.3`. After the fix the same command exits 0.
- Contract preserved: MANIFEST is not read by any build or install rule - `grep -rn MANIFEST Makefile CMakeLists.txt test/` shows it consumed only by the distcheck assertion and by test/install_uninstall.sh, which reads the generated MANIFEST.new - so correcting its content changes no build behaviour. Nothing installs it and nothing links against it.
- The class, not just the instance. The ABI and API version is duplicated across Makefile, CMakeLists.txt, utf8proc.h and MANIFEST, and distcheck asserted three of those four properly while checking MANIFEST only by grepping it for the soname `libutf8proc.so.3.2.3` - which the stale symlink line still contained, which is exactly why the drift survived. That assertion is now a regeneration and a diff, so any future divergence in any line of MANIFEST fails distcheck rather than passing it. Recorded under Settled classes with its enumerating command.
- The new distcheck assertion was driven at both polarities: with the corrected MANIFEST the regenerate-and-diff sequence exits 0; with the pre-fix `libutf8proc.so.2` line restored it exits 1 and prints that line. The pre-fix state was restored from a copy and reverted, not by git checkout.
- Battery ownership: the diff touches MANIFEST, Makefile and paths under .jeffy/probes/. The batteries whose paths files match are build-install and version-errmsg; both were re-run through the installed run-probe.sh and are green, build-install now at 27 checks after gaining the committed-MANIFEST comparison. Both rows are re-recorded at this iteration's checkpoint.
- Verify through quiet-verify.sh: green (0s), 100% tests passed, 0 tests failed out of 10.
- check-claims.sh: 19 checked, 0 mismatched, 0 errored, 0 skipped.
- Also removed a standing-claim hazard the sweep iterations introduced: each battery README described its mutation test with a numeric score ("reports 25/26 with exit 1"), which is a measurement of a mutated tree that no longer exists and that no recorded command can reproduce. The mutation and the names of the checks it reddened are the evidence and they stay; the scores are gone. `grep -rn '[0-9]\+/[0-9]\+ with exit' .jeffy/probes/*/README.md` now returns nothing.
- Closed this iteration: U7 (Medium, docs) - MANIFEST regenerated to match `make install`, distcheck strengthened from a soname grep to a regenerate-and-diff, build-install battery extended to compare against the committed file.

Learnings: An assertion that greps a file for a substring is not an assertion that the file is correct - the stale MANIFEST line still contained the soname the check looked for, so the check passed for years over a wrong file. Where a file is generated by a rule the project already has, assert by regenerating and diffing. A README under .jeffy/ that states a number is a standing claim like any other, so state only what a recorded command can re-derive.

Next: U1 (Medium, docs) is the top of the queue - UTF8PROC_STABLE documented as a behaviour-selecting option that has selected nothing since v2.10.0.

## iter 5/10 | 626d9b82-054124 | 2026-09-02 | U1 | done

Task: U1 (Medium, docs) - UTF8PROC_STABLE documented as a behaviour-selecting option that has selected nothing since v2.10.0.

Changed: utf8proc.h (the STABLE enumerator, both function option lists that name it, the normalization-wrapper paragraph, and the comp_exclusion field note), NEWS.md (the 2.10.0 entry), .jeffy/probes/option-liveness (new battery), BACKLOG.md, JOURNAL.md.

Checkpoint: 402cf08f69c5d039b74154a4ff838c8495b11af0 (no stall: utf8proc.h and NEWS.md changed, U1 removed from the ledger)

Verification:
- The filed reproduction was run first, against the tree as it stood. Sweeping every valid codepoint under six base option sets for an input where adding a flag changes utf8proc_map output: thirteen of the fourteen documented flags are live and UTF8PROC_STABLE is inert, and the two-codepoint probe on U+0915 U+093C - the composition exclusion the old wording promised the flag would control - is inert too. The doc half of the acceptance also failed: `grep -c 'no effect' utf8proc.h NEWS.md` returned zero for both files.
- Fix chosen: document the flag as having no effect rather than restore its old behaviour. Restoring it would mean composing Unicode composition exclusions when the flag is absent, which is wrong for NFC; the current behaviour is correct and only the documentation was false. Recorded here because it is a deliberate decision not to change observable behaviour.
- Contract preserved: no code changed. The flag keeps its bit value, the five normalization wrappers keep passing it, and `utf8proc_map` accepts it exactly as before, so no caller's source or binary breaks. The comp_exclusion field also keeps its place in the public struct and is now documented as informational rather than removed, which would have been an ABI change.
- Acceptance, both halves, green on the fixed tree: `.jeffy/probes/option-liveness` reports 23/23 with STABLE inert and every other documented flag live, and the documentation checks pass for the enumerator, both option lists, the wrapper paragraph, the comp_exclusion note and the NEWS entry.
- The new battery was observed failing at both polarities, each mutation reverted from a copy taken beforehand. Guarding the composition pass on `!(options & UTF8PROC_STABLE)`, which gives the flag an effect again, reddens the STABLE check. Deleting the NEWS entry reddens the NEWS check. That pairing is what the battery is for: code and documentation can only drift apart by reddening one half or the other.
- Class closed, not just the instance. The class is documented option flags that select nothing, and its enumeration is the battery itself, which drives all fourteen. Recorded under Settled classes with that command.
- Battery ownership: the diff touches utf8proc.h and NEWS.md. Enumerating the batteries whose paths files list either returned fourteen, and all fourteen were re-run through the installed run-probe.sh and are green. Their rows are re-recorded at this iteration's checkpoint. No row flips back to unswept: nothing about any public function's behaviour, signature or accepted inputs changed, so no re-sweep is owed.
- Verify through quiet-verify.sh: green (1s), 100% tests passed, 0 tests failed out of 10.
- check-claims.sh: 20 checked, 0 mismatched, 0 errored, 0 skipped.
- Closed this iteration: U1 (Medium, docs) - UTF8PROC_STABLE documented as inert in the header and in NEWS, with a battery that fails if code or documentation moves without the other.

Learnings: When a flag's behaviour was silently dropped and the new behaviour is the correct one, the fix is the documentation, not a restoration - and the record belongs in the release notes of the version that changed it, marked as recorded retroactively, because the reader who needs it is the one upgrading across that boundary. An instrument that checks only the code or only the prose cannot catch them diverging; pair them in one battery so either drift reddens.

Next: the ledger is at the severity floor - zero High, zero Medium, five open Lows - and the map is swept. U6 is the top of the queue.

## iter 6/10 | 626d9b82-054124 | 2026-09-02 | U6 | done

Task: U6 (Low, build-ci) - utf8proc.h did not compile under `cc -std=c90 -pedantic-errors`.

Changed: utf8proc.h (six trailing commas removed from enumerator lists, a comment recording the remaining C90 limit), NEWS.md (the 2.11.0 C90 line, which overclaimed), .jeffy/probes/header-contract (two probes, README, claims, paths), BACKLOG.md, JOURNAL.md.

Checkpoint: ddcd670b2edf3a0cdda673b25881a59d2f9608d2 (no stall: utf8proc.h and NEWS.md changed, U6 removed from the ledger)

Verification:
- The filed reproduction was run first, against the tree as it stood: a translation unit that only includes utf8proc.h, compiled with `cc -std=c90 -pedantic-errors`, exited 1 with two kinds of diagnostic - comma at end of enumerator list, and type of bit-field is a GCC extension.
- Split by cost, not by convenience. The trailing commas are pure C90 conformance with no effect on layout, so they are fixed: every `typedef enum` block in the header was processed and the last enumerator of each no longer ends with a comma. The bit-field half is an ABI question and is not taken; it is filed under Proposed with the measurement that motivates it and the reason it cannot be settled here.
- ABI evidence for that Proposed item, measured rather than assumed: with the three bit-fields redeclared `unsigned`, `sizeof(utf8proc_property_t)` is 24 both before and after under gcc 15.2.0 on x86-64, and the pedantic diagnostics drop to zero. That is one toolchain. utf8proc_get_property hands callers a pointer into an array of this struct, and a toolchain that packs bit-fields by declared type would lay it out differently; this host has no MSVC, so the question is the maintainer's. The measurement was taken from a copy of the header and reverted.
- Contract preserved: removing a trailing comma changes no enumerator value. The header-contract battery pins every option flag, error code and enumerator to its exact value and is green after the change, which is the check that would have caught a slip.
- Acceptance, on the fixed tree: the C90 pedantic compile reports zero `comma at end of enumerator list` diagnostics, the only remaining ones are the three documented bit-fields, and the limit is stated in the header and in the NEWS entry for the release that claimed the C90 fix.
- Both new probes were observed failing, each mutation reverted from a copy taken beforehand: reintroducing one trailing comma reddens the pedantic probe and names the offending line, and replacing the header's `otherwise C90 clean` wording reddens the documentation probe.
- Battery ownership: the diff touches utf8proc.h and NEWS.md. All fourteen batteries whose paths files list either were re-run through the installed run-probe.sh and are green; header-contract is now at 61 checks. Their rows are re-recorded at this iteration's checkpoint.
- Verify through quiet-verify.sh: green (1s), 100% tests passed, 0 tests failed out of 10.
- check-claims.sh: 20 checked, 0 mismatched, 0 errored, 0 skipped.
- Closed this iteration: U6 (Low, build-ci) - the header's C90 conformance gap narrowed to the three bit-fields, which are now documented and raised as a Proposed ABI decision.

Learnings: When a finding splits into a free half and a half that costs ABI, fix the free half and file the rest as Proposed with the measurement attached - and say which toolchain the measurement came from, because a layout question answered on one compiler is not answered. A release note that claims a fix should state the fix's boundary, or the next reader takes the claim for the whole thing.

Next: four Lows remain - U5, U2, U3, U4 - and the convergence sequence needs the closing full audit and the evaluator gate. U5 is the top of the queue.

## iter 7/10 | 626d9b82-054124 | 2026-09-02 | U5 | done

Task: U5 (Low, docs) - lump.md, which Doxygen publishes and utf8proc.h points readers at, omitted one of the UTF8PROC_LUMP rules.

Changed: lump.md (the missing entry), .jeffy/probes/decompose-char (a set-comparison check, README, claims), BACKLOG.md, JOURNAL.md.

Checkpoint: 665ff10fe79dda9148549e0eb4acf4006cd5c5ec (no stall: lump.md changed, U5 removed from the ledger)

Verification:
- The filed reproduction was run first, against the tree as it stood: `grep -c '^U+' lump.md` returned 13 while `grep -c 'utf8proc_decompose_lump(0x' utf8proc.c` returned 14, and the missing rule is the conditional one - Zl and Zp fold to U+000A only when both UTF8PROC_NLF2LS and UTF8PROC_NLF2PS are set.
- lump.md is published, not internal: `grep -rn 'lump.md' Doxyfile utf8proc.h NEWS.md` shows it in the Doxyfile INPUT list, referenced from the UTF8PROC_LUMP enumerator comment, and named in the NEWS entry that introduced the option. A reader following that pointer got an incomplete table.
- The entry was added in the file's existing sorted-by-target order and carries the condition, because unlike the other thirteen this rule does not fire under LUMP alone. The decompose-char battery already drove that rule at both polarities before this iteration, so the behaviour it documents was verified before it was written down.
- Contract preserved: documentation only. No code changed, and decompose-char - which pins every lump target at a category-driven and a codepoint-driven member - is green.
- Acceptance, on the fixed tree: the two counts agree. The check that went into the battery is stronger than the acceptance asked for: it diffs the set of codepoints the code lumps onto against the set lump.md lists, because two different sets of the same size would satisfy a count comparison.
- The new check was observed failing: deleting the U+000A entry again reddens it and prints the differing codepoint. The edit was reverted from a copy taken before it.
- Class closed, not just the instance: published documentation of a code-defined table drifting from that table. Recorded under Settled classes with the set-diff as its enumerating command.
- Battery ownership: the diff touches lump.md. The one battery whose paths file lists it, decompose-char, was re-run through the installed run-probe.sh and is green at 61 checks; its row is re-recorded at this iteration's checkpoint.
- Verify through quiet-verify.sh: green (0s), 100% tests passed, 0 tests failed out of 10.
- check-claims.sh: 20 checked, 0 mismatched, 0 errored, 0 skipped.
- Closed this iteration: U5 (Low, docs) - lump.md completed and pinned to the code by a set comparison.

Learnings: A count comparison between documentation and code is satisfied by two different sets of the same size; diff the sets. When documentation omits a conditional rule, write the condition into the entry rather than the rule alone, or the table reads as though every entry fires under the same option.

Next: three Lows remain - U2, U3, U4 - and all three are carried-eligible. The convergence sequence is what is left: the closing full audit, then the evaluator gate and the declaration.

## iter 8/10 | 626d9b82-054124 | 2026-09-02 | AUDIT | audit

Task: The closing full audit. Rescore every applicable dimension against the severity rubric and the Operating envelope with fresh evidence gathered this iteration.

Changed: JOURNAL.md only. No file outside the state files changed, and no BACKLOG item and no Surface inventory row changed state - this iteration is a stall by the mechanical definition, and says so; it is an AUDIT ceremony entry, which is exempt, and the previous primary entry does not say the same.

Checkpoint: 637189066911e1debe3d16507e9a501c5ef0f682 (stall by the mechanical definition: only JOURNAL.md changed and no ledger item or inventory row changed state; an AUDIT ceremony entry is exempt and the previous primary entry does not say the same)

Verification:
- Closeout has begun. This audit scored zero High and zero Medium in-envelope, so the run stops auditing for the rest of its budget: no replenishment and no further full audit, only the evaluator gate and the declaration.
- What changed this run, established by command rather than recall: `git diff --stat` against the commit before the run's first checkpoint touches .gitignore, MANIFEST, Makefile, NEWS.md, lump.md and utf8proc.h. `git diff` over utf8proc.c and utf8proc_data.c is empty - no runtime code changed at all this run - and the non-comment part of the utf8proc.h diff is exactly six trailing commas removed from enumerator lists, with every enumerator value unchanged.
- Independent oracle, run this iteration and new to this run. Every codepoint's NFD, NFC, NFKD and NFKC output was dumped from the library and compared against Python 3.14.4's unicodedata, an implementation sharing no code with utf8proc. Unicode's Normalization Stability Policy fixes decomposition mappings for characters that already exist, so a codepoint assigned in Python's Unicode 16.0.0 must normalise identically under utf8proc's Unicode 17.0.0 tables. 148853 codepoints compared, zero differences in all four forms.
- Second independent oracle, stronger because it removes the version caveat. The authoritative UnicodeData.txt for Unicode 17.0.0 was fetched from unicode.org and parsed including its First/Last range rows, then compared against the library's general category and canonical combining class for every codepoint: 299382 assigned codepoints, zero category differences and zero combining-class differences, and every codepoint the file does not assign reads as Cn or Cs.
- The one difference the Python comparison did surface was chased to the authoritative files rather than assumed: U+0295 is Lo in utf8proc and Ll in Python. UnicodeData.txt 17.0.0 gives Lo and 16.0.0 gives Ll, so the library tracks the upstream change correctly and there is no finding.
- Every battery re-run this iteration through the installed run-probe.sh: benchmarks 16/16, build-install 27/27, case-mapping 45/45, charwidth 29/29, data-tables 17/17, decompose-char 61/61, decompose-string 20/20, fuzz-harness 7/7, grapheme-break 26/26, header-contract 61/61, norm-wrappers 28/28, normalize-compose 36/36, option-liveness 23/23, property-category 49/49, reencode-map 23/23, test-harness 17/17, utf8-codec 52/52, version-errmsg 26/26. None red.
- Memory safety, rebuilt against HEAD this iteration with clang -fsanitize=address,undefined -fno-sanitize-recover=all: 400000 utf8proc_map calls over random codepoints and random flag combinations, 200000 random raw-byte inputs through the project's own fuzz entry point, 300000 utf8proc_reencode and utf8proc_normalize_utf32 calls on in-range UTF-32 buffers, and 200000 utf8proc_decompose two-pass calls with exact-size and short buffers. All clean.
- The library compiles clean under the Makefile's own warning set with -Werror added.
- Standing claims re-run: all three Settled-class enumerations hold - the lump.md set diff matches, option-liveness is green, and distcheck still names CMakeLists.txt, MANIFEST and utf8proc.h. There are no Declined entries, so no Derivation to re-run. PLAN.md names no finding ID as carried or blocked, so there is no dangling reference. check-claims.sh: 20 checked, 0 mismatched, 0 errored, 0 skipped.
- Oracle class and Environment fingerprint re-read. The fingerprint's one real exclusion is test/iscase, which needs julia; nothing in this run claims it was green, and the version assertion the ctest suite compiles out is independently covered by the version-errmsg battery, which compares utf8proc_unicode_version against data/Makefile directly. Verify count is deliberately empty because the ctest summary line's first integer is a percentage, not the total.
- Verify through quiet-verify.sh: green, 100% tests passed, 0 tests failed out of 10.
- Dimension scores. Seventeen of eighteen inventory rows are swept and one is disclosed unreachable (Unicode data generation - julia is not installed here), so these scores claim the whole surface except that row, which is named:
  - correctness: None. Two independent oracles agree with the library across 148853 and 299382 codepoints respectively; both conformance corpora execute and pass; fifteen known-answer batteries green.
  - security: None. Four sanitizer sweeps rebuilt against HEAD, all clean, over adversarial-class input.
  - error handling: None. Every documented error return is pinned at both polarities by the batteries, including the two INVALIDOPTS combinations and the destination-pointer clearing on failure.
  - testing: Low - U2, U3 and U4 remain open, all of them about the suite rather than the shipped library.
  - documentation: None. U1, U5, U6 and U7 closed this run, and lump.md, the header and NEWS are now pinned to the code by batteries that fail if either side moves alone.
  - architecture and code quality: None.
  - dependency hygiene: None. No runtime dependencies; dependabot covers the workflows; data/Manifest.toml pins the generator's julia packages.
  - developer experience: None open; the remaining C90 question is a Proposed ABI decision, which never blocks convergence.
  - performance: None observed. The bench program was built and run over a 380000-byte mixed-script corpus in all five modes, each completing in roughly four to five milliseconds per pass with no mode an outlier. No historical baseline exists in the tree, so this is a smoke measurement rather than a regression check, and it is recorded as such.
  - observability: not applicable - a pure computation library with no logging or metrics surface.
  - UX and accessibility: not applicable - no user-facing surface.
- Zero High and zero Medium in-envelope. Three Lows are carried: U2 (the fuzz harness's inverted allocation guard leaves the UTF-32 path unfuzzed), U3 (the ctest suite compiles out misc.c's Unicode-version assertion), U4 (test/iscase has no add_test entry and needs julia to build its data).

Learnings: A closing audit earns the word fresh by bringing an oracle the run did not already have. Two were available here at almost no cost - an unrelated implementation of the same standard, and the standard's own data files - and between them they cover more of the surface than every hand-written battery in the run. When a differential turns up a single difference, fetch the authoritative source before calling it either a bug or a version artefact.

Next: the evaluator gate, then the declaration if it returns PASS and the closing conditions still hold.

## iter 9/10 | 626d9b82-054124 | 2026-09-02 | EVALUATOR | converged

Task: Bring the standing claims current, run the adversarial evaluator gate, and declare convergence if it returns PASS and the closing conditions hold.

Changed: .jeffy/evaluator/626d9b82-054124-1.md (the gate's artifact), BACKLOG.md (the Converged line), JOURNAL.md.

Checkpoint: de90d0f0f4313c0096e7476ff85f549f7e0728cd (no stall: the evaluator artifact was added and the Converged line appended)

Verification:
- Evaluator: PASS - one fresh-context sub-agent, invocation ordinal 1, reproduced both Medium fixes against the base commit in a detached worktree, re-executed every acceptance as written, found check-claims clean and every swept row fresh, and recorded four observations none of which is a REJECT reason.
- Standing claims brought current in this iteration before the invocation. Row staleness was derived mechanically rather than trusted: for each of the seventeen swept rows, `git diff --name-only <recorded commit> HEAD --` over that battery's own declared paths returned nothing, so no row certifies code that moved after it was swept. All three Settled-class enumerations were re-run and hold - the lump.md set diff matches, option-liveness is green, and distcheck still names CMakeLists.txt, MANIFEST and utf8proc.h. There are no Declined entries, so no Derivation to re-run. PLAN.md names no finding ID as carried or blocked, so nothing dangles. check-claims.sh: 20 checked, 0 mismatched, 0 errored, 0 skipped. The Oracle class and Environment fingerprint were re-read, and the Verify count cell is deliberately empty because the ctest summary line's first integer is a percentage rather than the total.
- The gate's own evidence, independently obtained from the run's: U7's reproduction `make manifest && diff MANIFEST MANIFEST.new` exited 1 at the base commit on the `so.2` versus `so.3` line and exits 0 at HEAD, and pointing HEAD's build-install battery at the base tree reddened exactly the one named check. U1's option-liveness battery scored 18/23 against the base tree with all five documentation checks red and 23/23 at HEAD. The gate corroborated the new prose rather than accepting it: it confirmed by grep that UTF8PROC_STABLE and comp_exclusion are never read in the implementation, confirmed by `git tag --contains b18c5b5` that v2.10.0 is the release the wording names, and confirmed that comp_exclusion is genuinely populated so the informational-only sentence is not hollow.
- Closing conditions, each checked this iteration: the full fresh-evidence audit of iteration 8 scored zero High and zero Medium in-envelope; the Surface inventory lists no unswept row, with one `- [~]` row disclosed; the ledger holds zero open High and zero open Medium; the only commit between that audit and this iteration is its own bookkeeping commit, which touched PLAN.md and JOURNAL.md and nothing else; the Verify command is green this iteration; and the evaluator returned PASS with its artifact written, carrying no machine-absolute path.
- Carried Lows, each open with its severity on its task line:
  - U2 (Low, test): test/fuzzer.c's UTF-32 scratch buffer is allocated under the inverse of the intended guard, so the OSS-Fuzz target never fuzzes utf8proc_normalize_utf32.
  - U3 (Low, test): CMakeLists.txt never passes UNICODE_VERSION as a compile definition, so test/misc.c's utf8proc_unicode_version assertion is compiled out of the ctest suite that CI runs.
  - U4 (Low, test): test/iscase.c has no add_test entry, so the Lowercase and Uppercase derived-property cross-check runs only in the Makefile path, which needs julia.
- Gate observations, recorded here and carried to the run report rather than fixed, because a fix after a PASS invalidates that PASS: a garbled sentence in .jeffy/probes/build-install/README.md left by iteration 4's score removal; option-liveness double-printing its shell-half failure lines through jb_external, with the counts still correct; the three bit-field diagnostics under strict C90, already disclosed in the header and NEWS and raised as a Proposed ABI decision; and the run's commits sitting on the jeffy-run branch while master is still at the base commit, so `make dist`, which archives master, does not yet carry the MANIFEST fix - a pre-existing branch arrangement this run did not introduce.
- Verify through quiet-verify.sh: green (0s), 100% tests passed, 0 tests failed out of 10.

Learnings: Bring the standing claims current before the invocation and derive row staleness with a command rather than by remembering which iteration touched what - the gate consumes those claims exactly as the declaration does, and an invocation spent on a claim the run had already outdated is one the declaration then lacks.

Next: none - the run is converged.
