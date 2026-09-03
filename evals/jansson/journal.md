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

## iter 1/10 | 9220c553-230734 | 2026-09-02 | AUDIT | audit

Task: first audit of a fresh bootstrap. Fill the Operating envelope, the Surface inventory, and the Verify command block in PLAN.md, enumerate the artifact-producing channels, then audit breadth-first and file findings.

Changed: PLAN.md (envelope surfaces, 22 inventory rows, Verify command / Oracle class / Environment fingerprint / summary pattern, Stated counts table), BACKLOG.md (J-01 through J-04), .jeffy/probes/verify-exclusions/enumerate.sh (new; named by the Environment fingerprint), .gitignore (loop state file, added at bootstrap).

Checkpoint: 6a753a248194c8e136ba4bb982565cc0c390812c

Verification: verify green through quiet-verify.sh - 100% tests passed, 0 tests failed out of 215. check-claims.sh: 2 checked, 0 mismatched, 0 errored, 0 skipped. Publication channels enumerated by command and each verified to exclude PLAN.md, BACKLOG.md, JOURNAL.md and .jeffy/: (1) cmake install to a configure-time prefix, installed tree listed, only include/, lib/, lib/pkgconfig, lib/cmake; (2) autotools `make dist` run in a copy at /tmp/jdist, tarball listed, 0 of 455 entries match the state files; (3) release.sh, which wraps that same `make dist` plus an html tarball built from doc/_build/html; (4) .github/workflows, where only fuzz.yml archives anything and its path is ./out/artifacts. Envelope claim that no state-at-rest surface exists derived by `grep -nE 'fopen|open\(' src/*.c`, which returns only json_load_file's and json_dump_file's caller-supplied paths and the read-only /dev/urandom seed source. J-01 evidenced by building the shared library and diffing `nm -D` against src/jansson.def: 46 internal symbols exported, SYMVER_WORKS=1 in the cache so the version-script else-branch never runs. Acceptance checks for J-01, J-03 and J-04 each run against the unfixed tree and observed to fail (46 not 0; test_version listed; json_relloc_t printed); J-02's check is differential by construction and cannot run before its fix exists.

Scores, and they claim only what was probed this iteration - all 22 inventory rows are unswept, so no dimension below is a statement about the project as a whole: architecture Medium (J-01), testing Low (J-02, J-03), documentation Low (J-04), security None on what was probed (indirect cycle detection on dump and deep_copy, the depth-2048 guards in load.c/dump.c/value.c, UTF-8 and surrogate-pair validation, and the overflow guards in strbuffer_append_bytes all held), correctness None on what was probed (three executed probes over the encoding flags, the decoding flags and the API contract; every apparent failure was re-examined and was my own wrong expectation, not the library's), error handling None on what was probed (8 of 8 json_error_code and position checks held), code quality None on what was read, dependency hygiene None - no external dependencies, the only vendored code is src/dtoa.c and its row is unswept, developer experience None on what was probed. Performance not scored: no measurement was taken. Observability and UX/accessibility do not apply - a C library with no logging surface and no user-facing surface.

Learnings: the Oracle class line rides the wrapper's green stderr line verbatim, so a long one floods the window every iteration - keep it to a few sentences. Probe expectations about this library must be checked before they are believed: json_array_append and json_object_set reject self-reference outright, so a cycle for testing has to be built indirectly through two containers, and `cmake --install --prefix` overrides the destination but not the configure-time prefix baked into jansson.pc, which looks exactly like a packaging defect and is not one.

Next: J-01, the only open Medium. Then the inventory rows, which outrank the three open Lows.

## iter 2/10 | 9220c553-230734 | 2026-09-02 | SWEEP | done

Task: sweep Surface inventory rows. No open High, so the map is the top of the queue; ten rows had a known-answer battery that could be properly evidenced this iteration.

Changed: .jeffy/probes/_common/ (new shared check harness and battery runner), ten new batteries under .jeffy/probes/ - value-core, value-array, value-object-mutation, value-object-iteration, value-string, value-number, value-equal-copy, utf8, strbuffer-strconv, version - each with probe.c, paths, claims, run.sh and README.md; .jeffy/probes/verify-exclusions gained paths, claims and a README so it is a well-formed battery too. PLAN.md: ten inventory rows flipped to swept, five Lessons added. No file outside .jeffy/ and the state files was touched, so nothing the Verify command grades changed.

Checkpoint: 96f42304bc5a507a99e118e5806e6c6946330701

Verification: verify green through quiet-verify.sh - 100% tests passed, 0 tests failed out of 215. check-claims.sh: 13 checked, 0 mismatched, 0 errored, 0 skipped. Every battery is a known-answer battery: expected values are hand-written literals, hand-encoded byte sequences from the Unicode standard, or a differential between two entry points that must disagree, never a second call to the code under test. Each of the ten was then observed failing on a discriminating state, which is what the READMEs record: a copy of the tree at /tmp/jmut carrying one targeted mutation per battery was built as a separate library and every battery re-run against it through JEFFY_MUTANT_BUILD, and all ten went red on the checks their own mutation targets - json_null returning the false singleton, json_array_remove not closing the gap, update_recursive short-circuited to a plain set, key_to_iter returning NULL, json_string_length reporting strlen, jsonp_dtostr ignoring its precision, deep_copy aliasing array children, utf8_check_full accepting surrogates, strbuffer_pop not shortening, and jansson_version_cmp dropping its micro field. The value-array case is the one worth naming: with the removal's array_move disabled, three element assertions went red while the size assertion still passed, which is precisely the shape a length-only probe would have certified as clean.

No finding was surfaced by this sweep. Three probe expectations failed and all three were mine, not the library's, each checked against doc/apiref.rst or the implementation before being corrected: json_real_value returns 0.0 for a non-real rather than widening, utf8_check_full validates a sequence whose length the caller already derived rather than re-deriving it from the lead byte, and the encoder writes exponents with no plus sign and no zero padding.

Learnings: keep the Oracle class line short, because quiet-verify.sh reprints it verbatim every iteration. Check a surprising probe result against the documentation before treating it as a defect - three of three surprises here were the probe's error. Build a battery's observed-failing evidence against a mutated copy under /tmp through JEFFY_MUTANT_BUILD, never by editing src/ in place. Run packaging channels in a copy outside the tree, because their output lands untracked and the checkpoint would sweep it in.

Next: twelve rows remain unswept - decode-api, decode-lexer, encode, pack, unpack, error, memory, hashtable, hashtable-seed, dtoa-vendored, build-install, docs. They still outrank J-01, the only open Medium.

## iter 3/10 | 9220c553-230734 | 2026-09-02 | SWEEP | done

Task: sweep Surface inventory rows. Still no open High, so the map is still the top of the queue; six of the twelve remaining rows had a known-answer battery that could be properly evidenced this iteration.

Changed: six new batteries under .jeffy/probes/ - decode-api, decode-lexer, encode, pack, unpack, error - each with probe.c, paths, claims, run.sh and README.md. PLAN.md: six inventory rows flipped to swept. No file outside .jeffy/ and the state files was touched.

Checkpoint: c1dc68033607721740108481f05b5ba639e273d9

Verification: verify green through quiet-verify.sh - 100% tests passed, 0 tests failed out of 215. check-claims.sh: 19 checked, 0 mismatched, 0 errored, 0 skipped. Every documented format specifier of json_pack and json_unpack is now driven, taken from the two specifier lists in doc/apiref.rst rather than from the source, and every encoding and decoding flag is driven at two or more values whose outputs must differ - the optional pack forms on both sides of their NULL condition, since a specifier that ignores its NULL case and one that always omits agree on half the inputs. Each of the six was observed failing on a discriminating state: a second mutated copy at /tmp/jmut2 was built as a separate library and every battery re-run against it through JEFFY_MUTANT_BUILD, with JSON_REJECT_DUPLICATES ignored, the lone-high-surrogate rejection replaced by a substitution, the JSON_COMPACT object separator forced on, the pack star form emitting null instead of omitting, the object-side strict check disabled, and error->column assigned the byte position. Each battery went red on the checks its own mutation targets: decode-api on the duplicate-key pair, decode-lexer on the lone high surrogate while the valid pair still decoded, encode on the dumpb sizes and every EMBED comparison, pack on the three star forms while every question-mark form passed, unpack on the object strict checks while the array side passed, and error on the two column assertions while every line and position assertion held.

No finding was surfaced by this sweep. Six probe expectations failed and all six were mine, each resolved against doc/apiref.rst or the enum before correcting: json_error_end_of_input_expected is 7 and json_error_invalid_syntax is 8, and a trailing letter after a literal is the latter while trailing text after a complete number is the former; object keys cannot carry an embedded nul even under JSON_ALLOW_NUL, which apiref states outright, and the refusal is json_error_null_byte_in_key; the decoding functions write position on success, documented as the one member a caller may read there; and I mis-hand-counted the character column and byte position of a document containing two-byte codepoints.

Learnings: hand-count the expected column and position of a multi-byte document twice - the character column and the byte position are different numbers and getting one of them right does not check the other. Take a format-specifier list from the documentation, not from the source, so the sweep grades the published contract rather than the implementation's own idea of it.

Next: six rows remain unswept - memory, hashtable, hashtable-seed, dtoa-vendored, build-install, docs. They still outrank J-01, the only open Medium.

## iter 4/10 | 9220c553-230734 | 2026-09-02 | SWEEP | done

Task: sweep the last six Surface inventory rows - memory, hashtable, hashtable-seed, dtoa-vendored, build-install, docs. Still no open High, so the map remained the top of the queue.

Changed: six new batteries under .jeffy/probes/ - four C probes and two shell batteries, each with paths, claims, run.sh and README.md. PLAN.md: the last six inventory rows flipped to swept, three Lessons added. No file outside .jeffy/ and the state files was touched.

Checkpoint: 9651bc0364e3eece068603ad5bb857ff48e4818c

Verification: verify green through quiet-verify.sh - 0 tests failed out of 215. check-claims.sh: 25 checked, 0 mismatched, 0 errored, 0 skipped. The Surface inventory now lists no unswept row. Four batteries were observed failing against a third mutated copy at /tmp/jmut3 through JEFFY_MUTANT_BUILD: the realloc emulation copying zero bytes reddened memory's two content checks while every allocation count still balanced; the rehash loop indexing modulo half the new size reddened hashtable's `every key resolves after growth`; generate_seed replaced by a constant reddened hashtable-seed's entropy check while every explicit-seed check passed; and the dtoa digit count clamped to 15 reddened the hand-written shortest forms for 2^53, DBL_MAX and DBL_MIN, the adjacent-double discrimination, and about three thousand round trips. The two shell batteries needed no mutation: build-install is red on `no internal symbols exported`, which names the 46 symbols of J-01, and docs is red on `documented names absent from src/jansson.h`, which names json_relloc_t of J-04. Both now reproduce their finding independently of the ledger line that filed it, and closing those tasks is what turns them green.

One mutation was recorded and then withdrawn: replacing hashtable.c's length-aware key comparison with strcmp reddened nothing, because the stored hash already covers the key length and separates those keys before the comparison runs. The README records the mutation that was actually observed to fail, not the one that was expected to.

No new finding was surfaced by this sweep. Two probe defects were mine: the hashtable-seed probe forked after the parent had already created an object, so every child inherited a seeded address space and json_object_seed did nothing in any of them, and its first draft used key iteration order as the discriminator when object order is insertion order and therefore seed-independent by design.

Learnings: fork before the parent touches the per-process state a forked comparison is about. Check that a battery actually reddened on a mutation before recording it as that battery's evidence. A battery that grades an open finding is red by design until the finding closes; pin its claims line at the pre-fix count and name the ID.

Next: the map is complete at 22 of 22 rows, so the queue falls to J-01, the only open Medium, and then the three open Lows.

## iter 5/10 | 9220c553-230734 | 2026-09-02 | J-01 | done

Task: J-01 (Medium, build-ci, architecture) - the CMake shared-library build applied no export restriction, so libjansson.so exported 46 internal symbols the autotools build hides and src/jansson.def excludes.

Changed: CMakeLists.txt (the symbol-versioning block), .jeffy/probes/build-install/claims and README.md, PLAN.md (Stated counts row removed, build-install row re-recorded, two Lessons added), BACKLOG.md (J-01 deleted), JOURNAL.md (restored, see below).

Checkpoint: bc22223e95b8007845dbd51f48ea16e43ec3a7c0

Closed: J-01 (Medium) - CMakeLists.txt now writes a version script in both branches of the symbol-versioning check and applies it whenever the linker accepts one, instead of writing it only in the branch taken when --default-symver is unsupported. Acceptance: the leaked-symbol count command returns 0, down from 46.

Verification: the fix was chosen against the autotools build as the reference ABI rather than invented. That build, made in a copy at /tmp/jauto, exports 83 symbols all versioned @@libjansson.so.4 and nothing else; the pre-fix cmake build exported 129 with the same versions. An anonymous version node applied alongside --default-symver reproduces the reference exactly - `diff` of the two `nm -D` outputs, symbol versions included, is empty at 83 lines - whereas the named node the old else-branch wrote would have moved every symbol to a JANSSON_4 version and broken the ABI for anyone already linked against a cmake build. The named node is therefore kept only in the branch where no default version exists to preserve. Contract preserved: the public export set and its version strings are byte-identical to the autotools reference, and no test in the tree references an internal symbol, checked by grepping test/ for the jsonp_, strbuffer_, hashtable_, utf8_ and dtoa families, which returns nothing. A shared build with tests enabled was configured, built and run to confirm the restriction does not hide anything the suite needs: 100% tests passed, 0 tests failed out of 215. Verify gate green through quiet-verify.sh - 0 tests failed out of 215. Battery ownership: the diff touches CMakeLists.txt, which .jeffy/probes/build-install declares, so that battery was re-run through run-probe.sh and now reports 33/33 where it reported 32/33 before; its claims line and README were updated in this iteration and its inventory row re-recorded at this checkpoint. check-claims.sh: 24 checked, 0 mismatched, 0 errored, 0 skipped. The PLAN.md Stated counts row for the leaked-symbol count was removed rather than set to zero, because the prose claim it derived left the ledger with J-01 and the build-install battery is the instrument that now owns that regression.

JOURNAL.md repair: iteration 4's bookkeeping edit truncated this file to zero bytes and committed it. The cause was writing `open(p, "w").write(open(p).read().replace(...))` on one line, where the write handle truncates the file before the read is evaluated. The content was recovered intact from the iteration 4 checkpoint commit 9651bc0364e3eece068603ad5bb857ff48e4818c, which predates the bookkeeping commit, and the checkpoint hash that edit was meant to record was then filled in correctly. All four earlier entries are present and unmodified. Nothing else was lost: PLAN.md and BACKLOG.md were written by the safe two-step form in that same script.

Learnings: never write a file with the read nested inside the write call - the truncation happens first and the file is destroyed. Use a quoted heredoc for every inline python payload, or the shell expands backticks inside prose and deletes the spans between them, which mangled a README in this iteration before it was caught. When a fix changes a published artifact, pick the target by measuring an existing reference implementation of the same artifact rather than by reasoning about what it should be: the obvious version-script edit here would have silently changed the symbol version strings.

Next: three open Lows remain - J-02, J-03, J-04. J-02 adds the export-visibility regression test to the CMake path, which is the check that would have caught J-01.

## iter 6/10 | 9220c553-230734 | 2026-09-02 | J-02 | done

Task: J-02 (Low, test, testing) - nothing in the CMake test path graded symbol visibility, which is why J-01 shipped unnoticed.

Changed: test/suites/api/check-exports (now takes the shared object and def file as optional arguments and makes its own scratch directory when the autotools harness has not provided one), CMakeLists.txt (registers that script as a ctest test when JANSSON_BUILD_SHARED_LIBS is on and the platform is UNIX, with SKIP_RETURN_CODE 77 so a non-GNU nm skips rather than fails), .jeffy/probes/verify-exclusions/claims and README.md, PLAN.md (Environment fingerprint), BACKLOG.md (J-02 deleted).

Checkpoint: ecfc24913a9e08c1bcab1e7f8dc1cac46734d531

Closed: J-02 (Low) - the exports check is now part of the CMake test path. Acceptance, run as filed and then strengthened because the filed wording named the static build the Verify command uses, where there is no shared object to inspect: configured with -DJANSSON_BUILD_SHARED_LIBS=ON, `ctest -N` lists check-exports as test 216 and `ctest -R check-exports` passes; with J-01's version-script application disabled in a copy at /tmp/jrev and this test kept, the same command fails with exit 8 and reports check-exports as the failure. That differential is the whole point of the task: the check is strong enough to fail on the defect it exists for.

Verification: the reproduction was run first and returned zero registered export tests. The script is shared with the autotools suite, so the risk in touching it is breaking that path; a full `autoreconf -fi && ./configure && make && make check` was run in a copy at /tmp/jauto2 and exited 0, and a verbose run of the api suite there reports `check-exports... ok`, so the script still works with no arguments in its original layout and is genuinely effective there rather than skipping. Verify gate green through quiet-verify.sh - 0 tests failed out of 215; the static build the gate uses does not register the new test, which is why the Environment fingerprint now says so explicitly instead of listing check-exports as unreachable. Battery ownership: the diff touches CMakeLists.txt, which both .jeffy/probes/build-install and .jeffy/probes/verify-exclusions declare. build-install re-run through run-probe.sh reports 33/33 unchanged. verify-exclusions changed, because its third section greps CMakeLists.txt for each asset's path and check-exports now appears there: its count dropped from ten to nine, and its claims line and README were updated in this iteration. check-claims.sh: 24 checked, 0 mismatched, 0 errored, 0 skipped.

Learnings: an acceptance check that names a build configuration must name the one the check can actually run in - this one named the static build the Verify command uses, where there is no shared object to inspect at all. When a fix touches a file two build systems share, run the other build system's full suite before the checkpoint, verbosely enough to see the individual test result rather than the suite total.

Next: two open Lows remain, J-03 and J-04. Then the closing full audit and the evaluator gate.

## iter 7/10 | 9220c553-230734 | 2026-09-02 | J-03 | done

Task: J-03 (Low, test, testing) - test/suites/api/test_version.c was in the autotools check_PROGRAMS list but not in the CMakeLists api_tests list, so ctest never built or ran it and the version macros went ungraded on the CMake path.

Changed: CMakeLists.txt (test_version added to api_tests), .jeffy/probes/verify-exclusions/claims and README.md, PLAN.md (Environment fingerprint drops test_version from its exclusion list), BACKLOG.md (J-03 deleted).

Checkpoint: cbb42eb49bf25bb708fdaff044b7d598dd89d344

Closed: J-03 (Low) - test_version now builds and runs under ctest. Acceptance run as filed: the enumeration prints nothing under its "api test programs on disk not registered in ctest" heading, where it printed test_version before the change, and `ctest -R test_version` passes as test 18. The registration was then checked to be worth having rather than a name on a list: version.c was mutated in a copy at /tmp/jtv so jansson_version_cmp drops its micro field, and the newly registered test failed there with exit 8, so it grades the thing it is named for.

Verification: the reproduction was run first and printed test_version. Verify gate green through quiet-verify.sh - 0 tests failed out of 216, up from 215, which is the newly registered test and the only change to that total. Battery ownership: the diff touches CMakeLists.txt, which .jeffy/probes/build-install and .jeffy/probes/verify-exclusions both declare. build-install re-run through run-probe.sh reports 33/33 unchanged. verify-exclusions moved again, from nine to eight, because test_version has left its list; its claims line and README were updated in this iteration, and the README now records the whole arc rather than only the current number. check-claims.sh: 24 checked, 0 mismatched, 0 errored, 0 skipped. The Environment fingerprint no longer lists test_version as unreachable; what remains excluded there is the ossfuzz corpus, the two autotools suite drivers, the dtoa-guarded case directory, and check-exports in a static build.

Learnings: a task that only registers an existing test still owes evidence that the test can fail - registering a vacuous test closes the ledger line and grades nothing, and the mutation that proves it takes one build.

Next: one open Low remains, J-04, the doc/apiref.rst type-name typo, whose fix also turns the docs battery green. Then the closing full audit and the evaluator gate.

## iter 8/10 | 9220c553-230734 | 2026-09-02 | J-04 | done

Task: J-04 (Low, docs, documentation) - doc/apiref.rst declared json_set_alloc_funcs2 with the parameter type json_relloc_t, a name that exists nowhere in src/jansson.h; the real typedef is json_realloc_t.

Changed: doc/apiref.rst (one signature line), .jeffy/probes/docs/claims and README.md, BACKLOG.md (J-04 deleted).

Checkpoint: 9592254b6eca3c86e7c12b39e0da24dce9f2532f

Closed: J-04 (Low) - the documented signature now matches the header. Acceptance run as filed: the set difference between the names the reference uses in function signatures and the names src/jansson.h declares is empty, where it printed json_relloc_t before. The class was enumerated rather than assumed: `grep -rn relloc doc/ src/ README.rst CHANGES` returned exactly one line before the fix and returns nothing after it, so this is a single-site correction and not the first instance of a pattern. The signature also carried the parameter name relloc_fn while the prose beneath it already said realloc_fn; both are now realloc_fn, matching src/jansson.h.

Verification: the reproduction was run first and printed json_relloc_t. Verify gate green through quiet-verify.sh - 0 tests failed out of 216. Battery ownership: the diff touches doc/apiref.rst, which .jeffy/probes/docs declares; that battery re-run through run-probe.sh now reports 8/8 where it reported 7/8, and its claims line and README were updated in this iteration. The docs battery has now gone green for the reason it was built red: it was written to grade an open finding, its claims line was pinned at the pre-fix count with the ID named, and closing the finding moved it. check-claims.sh: 24 checked, 0 mismatched, 0 errored, 0 skipped.

The ledger is now empty: no open High, no open Medium, no open Low, no unswept row. No full audit this run has yet scored clean, because the only full audit on record is iteration 1's, which found J-01 at Medium.

Learnings: a documentation finding still gets its class enumerated by command before it is called a single site - the grep that establishes it is one line is the same evidence a multi-site class would have needed, and it costs one command.

Next: the closing full audit with fresh evidence across every applicable dimension, then the evaluator gate and the declaration in the final iteration, which keeps the second gate invocation in reserve for a rejection.

## iter 9/10 | 9220c553-230734 | 2026-09-02 | AUDIT | audit

Task: the closing full audit. Rescore every applicable dimension against the severity rubric and the Operating envelope with fresh evidence taken this iteration, over the whole mapped surface.

Changed: BACKLOG.md (J-05 filed), PLAN.md (its stated-count row).

Checkpoint: 5eef14c12d20beb070da1ec2a83b2891edf4f8cb

Verification: every figure below was produced this iteration, not carried from an earlier one. Verify green through quiet-verify.sh - 0 tests failed out of 216. check-claims.sh over all seventeen batteries and both counts rows: 25 checked, 0 mismatched, 0 errored, 0 skipped. The Oracle class and Environment fingerprint were both re-read and the exclusion list re-derived by the command the fingerprint names; it returns the eight assets the fingerprint describes - the dtoa-guarded case directory, the five ossfuzz files, and the two autotools suite drivers - plus check-exports, which the fingerprint covers separately because it is registered only in a shared build. No entry in this run has claimed any of those green. Ten test modules were each run alone, and a full run under ctest --schedule-random was green at 216, so neither order dependence nor cross-module state leakage is hiding behind the whole-suite pass.

Scores. All 22 inventory rows are swept, so these claim the whole mapped surface rather than an examined fraction of it. Architecture None - the shared build's export set is byte-identical to the autotools reference at 83 symbols with matching version strings, and build-install reports 33/33. Correctness None - seventeen batteries, roughly fourteen thousand checks, all green. Security None - the decoder is the only adversarial surface in the envelope, decode-lexer drives its whole rejection set including overlong forms, surrogates, above-range codepoints, truncated tails and the depth limit from both sides, and utf8 drives the codec against hand-encoded sequences from the standard. Error handling None - every error code a caller can provoke is driven from an input chosen to produce that one. Documentation None - the docs battery's set comparisons over documented names, exported symbols, flag macros, error codes, three version strings, the CHANGES entry and the toctree all pass. Dependency hygiene None - ldd on the built shared library shows libc and the loader and nothing else, the only vendored code is src/dtoa.c and src/lookup3.h in tree with no fetch step, and neither jansson.pc.in nor configure.ac declares a dependency. Testing None - 216 green, ten modules green in isolation, a random-order run green, and the unreachable assets disclosed rather than assumed absent. Developer experience None - a scratch-prefix install with consumers built through both pkg-config and find_package, and a source tarball built and inspected. Performance None on what was measured, and it was measured rather than assumed: 200000 integers in 778001 bytes parse in 0.016s and re-encode in 0.007s, with no pathological behaviour observed. Code quality Low, J-05. Observability does not apply - a C library with no logging, metric or trace surface. UX and accessibility do not apply - no user-facing surface.

Filed: J-05 (Low, dev-tooling, code quality) - four warnings on a -Wall -Wextra Release build. Both sites were run down by execution rather than by reading, and both are false positives. src/load.c's stream_get writes stream->buffer[count] into a char[5] after count = utf8_check_first(c); GCC cannot see across the translation unit that the function is bounded, and NDEBUG has removed the assert that says so. Enumerating all 256 possible lead bytes returns the set {0,1,2,3,4} with maximum 4, so the write lands at index 4 of 5 at worst. src/error.c's jsonp_error_set_source draws its strncpy bound from the source length; 500 source lengths from 0 to 499 were driven through it under AddressSanitizer and UndefinedBehaviorSanitizer, and every result terminates inside the 80-byte buffer, with short sources copied verbatim and long ones marked with the ellipsis and filling the buffer exactly. The finding is therefore build noise that names nothing a user of the shipped product meets, which is why it is a Low, and its remedy is a decision about adding bounds the code cannot reach - something the Constraints discourage - so it is filed for a future run rather than fixed inside the convergence sequence.

Closeout has begun: this audit scored zero High and zero Medium in-envelope, so the run stops auditing for the rest of the run and finishes by converging, carrying J-05.

Learnings: run a compiler warning down to an executed enumeration before scoring it either way - reading the code says the bound holds, running every one of the 256 lead bytes through the function says it holds, and only the second is evidence. A warning that survives that treatment is build noise and a Low, not a defect to be hidden and not a defect to be inflated.

Next: the evaluator gate and, on a PASS, the declaration, both in the final iteration so the second invocation stays in reserve for a rejection.

## iter 10/10 | 9220c553-230734 | 2026-09-02 | EVALUATOR | converged

Task: the evaluator gate and, on a PASS, the declaration.

Changed: .jeffy/evaluator/9220c553-230734-1.md (the gate's artifact), BACKLOG.md (J-06 and J-07 filed from the gate's observations, and the Converged line), JOURNAL.md.

Checkpoint: 48d3af09af9588630a946430f0b2748404c31b08

Verification: standing claims were brought current in this iteration before the invocation. All 22 swept Surface inventory rows were checked for staleness mechanically, by resolving each battery's declared paths and asking git whether any of them changed after the commit the row records: 0 stale. There are no Declined entries and no Settled classes, so no Derivation or enumeration to re-run. PLAN.md names no finding ID as carried or blocked. check-claims.sh over all 23 batteries and both Stated counts rows: 25 checked, 0 mismatched, 0 errored, 0 skipped. The Oracle class and Environment fingerprint were re-read and hold. Verify green through quiet-verify.sh - 0 tests failed out of 216.

Evaluator: PASS - invocation 1 of this run, artifact at .jeffy/evaluator/9220c553-230734-1.md, 172 lines listing every command with its real exit status and closing with the verdict on its own line. It reproduced J-01 at the base commit 851a214, where the filed acceptance printed 46 rather than 0, and confirmed it prints 0 at HEAD; it independently re-derived the ABI claim, finding the diff of nm -D output between the autotools reference and the cmake build empty at 83 lines with the version suffixes included, and readelf -V showing identical version definition sections; it exercised the restructured else branch by forcing SYMVER_WORKS off and found the named node still produces 83 exported and 0 leaked; it re-ran the three Low acceptances at base and at HEAD; and it re-derived J-05's severity itself rather than trusting the run, confirming both warned sites are unreachable as out-of-bounds writes.

The gate recorded four observations, none a REJECT reason, and per the closing rule none was fixed inside the convergence sequence: two were actionable and are filed as carried Lows, J-06 and J-07, and two are corrections to this run's own prose. The first correction belongs here because a past entry is never rewritten: iteration 9's audit entry says "seventeen batteries" where .jeffy/probes holds 23 battery directories, which is the figure check-claims reports as 23 battery claims plus 2 Stated counts rows for its 25. The second is that J-01's filed acceptance line said the suite would still pass 215 tests, and it passes 216, because J-03 registered test_version in the same run; the gate confirmed it passes.

Carried Lows at this declaration, each with its severity written on its task line: J-05 (Low, dev-tooling, code quality) - four warnings on a -Wall -Wextra Release build, both sites run down and shown by execution to be false positives, whose remedy is a decision about adding bounds the code cannot reach. J-06 (Low, test, testing) - check-exports strips only the default version suffix, so it fails on a linker without --default-symver despite a correct export set, reproduced by the gate. J-07 (Low, dev-tooling, documentation) - the Verify count cell is empty because the summary pattern's first integer is a percentage, which PLAN.md documents as the case to leave empty, so the wrapper's total is recorded nowhere in PLAN.md.

Closing conditions, each verified this iteration: the full fresh-evidence audit of iteration 9 scored zero High and zero Medium in-envelope; the Surface inventory lists 22 swept rows, no unswept row, no unreachable row and no stale row; Now, Next and Later hold zero open High and zero open Medium; the only commits since that clean audit are that audit's own checkpoint and bookkeeping plus this iteration's; the Verify command is green; and the evaluator returned PASS in this same iteration.

Learnings: bring the standing claims current before the gate rather than after it - the staleness sweep, the claims run and the fingerprint re-read all passed here, and each one that had not would have cost an invocation the declaration needs. A gate observation that is not a reject reason is filed, not fixed: fixing it after the PASS would invalidate the PASS that the declaration rests on.

Next: convergence is declared. The next run ratchets if nothing but loop state changes, and otherwise starts from J-05, J-06 and J-07.
