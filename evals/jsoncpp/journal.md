# Journal

Append-only. One primary entry per iteration; SALVAGE and ROTATION entries are additional. Never rewrite past entries (filling the current entry's Checkpoint field is completion, not a rewrite).

Heading grammar, exactly:
## iter <i>/<N> | <run-id> | <YYYY-MM-DD> | <task-id or AUDIT or RATCHET or WRAPUP or SALVAGE or ROTATION> | <done|blocked|audit|converged|salvage|rotation>

SALVAGE entries take status salvage; ROTATION entries take status rotation.

run-id is the first 8 characters of the session id, a hyphen, then the HHMMSS of started_at from the loop state frontmatter, so two runs in one session are told apart. Body fields, in order: Task, Changed, Checkpoint (the jeffy checkpoint commit hash, or none with the reason), Verification, Learnings, Next.

The closing entry that declares convergence carries the evaluator verdict in its Verification field: `Evaluator: PASS - <one-line summary>`, or `Evaluator: unavailable (<reason>)`.

Closed tasks are recorded here as one line each (ID, title, closing evidence), because BACKLOG.md deletes them. Rotation: when this file exceeds 500 lines, move all but the last 10 entries to the end of JOURNAL-archive.md, appending to whatever that file already holds and never overwriting it, because the archive accumulates across every rotation and every run; create it only when it does not already exist, and record the rotation as a ROTATION entry.

## iter 1/10 | 9b4ea811-060501 | 2026-07-30 | AUDIT | audit
Task: First full audit. Filled Operating envelope (6 surfaces), Surface inventory (16 rows, 15 swept at 60de77f), and Verify command in PLAN.md; generated backlog.
Changed: PLAN.md (envelope, inventory, verify, lessons), BACKLOG.md (5 tasks filed), JOURNAL.md; also bootstrap of the three state files and .gitignore entry for the loop state.
Checkpoint: 2b55c2b3858506bb886bf641ee127d53672900da
Verification: Verify gate green before filing: VS2022 Debug build OK, 132/132 unit tests passed, ctest 3/3 passed (jsoncpp_readerwriter 6.6s, json_checker 8.8s, jsoncpp_test 0.06s). Probes executed: secure-memory build reproduced error C3861 at allocator.h:47 (JC-1); allocator.h:49 fill_n wipes n bytes not n*sizeof(T) (JC-1); value.h:42-46 string_view detection ignores _MSVC_LANG (JC-2); amalgamate.py generated all three outputs; five examples built, four ran correctly; version 1.10.0 consistent across version.h/CMakeLists/meson.build/MODULE.bazel; doxybuild.py and get_version.pl syntax-clean.
Scores (swept rows only): security High (JC-1), correctness Medium (JC-2), testing Medium (JC-3), dependency-hygiene Low (JC-4), architecture None, code-quality None, error-handling None, documentation None, developer-experience None; performance skipped (README declares it out of scope); observability not applicable (library, error reporting covered under error handling); UX/accessibility not applicable (no user-facing UI). Meson row remains unswept (JC-5); Bazel row swept shallowly (version probe only) with residual risk noted.
Learnings: Git Bash mangles MSVC slash-flags into paths - use dash-prefixed flags; shell cwd drifts between calls - anchor at project root; rm -rf in scratchpad can be denied - use fresh dir names. Copied to PLAN.md Lessons.
Next: Execute JC-1 (fix SecureAllocator compile break and undersized wipe).

## iter 2/10 | 9b4ea811-060501 | 2026-07-30 | JC-1 | done
Task: JC-1 (High, security) - fix SecureAllocator so JSONCPP_USE_SECURE_MEMORY=1 works. Closed: MSVC secure build went from error C3861 to compiling with all 132 tests passing; wipe now covers the full block.
Changed: include/json/allocator.h (deallocate: removed the RtlSecureZeroMemory branch that required windows.h in a public header; portable volatile fill_n now zeroes n*sizeof(T) bytes, was n); src/lib_json/json_value.cpp (CZString move-assign released a non-prefixed key with releasePrefixedStringValue, which under secure memory reads 4 key bytes as a length and memsets gigabytes - pre-existing heap smash exposed by the newly compiling config, fixed to releaseStringValue matching the destructor); src/test_lib_json/main.cpp (test suite itself had bitrotted std::string/Json::String mixes at ~15 sites; switched to Json::String, type-identical in the default build).
Checkpoint: b19f8711132578c0fb059f0f8042f975a1a81950
Verification: Acceptance: cmake build of jsoncpp_test with -DJSONCPP_USE_SECURE_MEMORY=1 now compiles and reports All 132 tests passed (before fix: error C3861 at allocator.h:47, then access violation 0xC0000005 in ValueTest/CZStringCoverage). Verify gate green on default build: All 132 tests passed + ctest 3/3. Differential evidence: default build was green at checkpoint 2b55c2b and remains green with identical test count; Json::String aliases std::string when the macro is 0, so test edits are type-identity-preserving there. Contract preserved: standard C++11 allocator interface unchanged; CZString destructor/move-assign now use the same release path.
Learnings: The Edit tool handles CRLF transparently but raw python string matching must account for CRLF working copies (core.autocrlf); prefer decoded utf-8 with count asserts. A config that does not compile hides runtime defects behind it - the CZString heap smash was invisible until the build was fixed.
Next: JC-2 (string_view detection honoring _MSVC_LANG).

## iter 3/10 | 9b4ea811-060501 | 2026-07-30 | JC-2 | done
Task: JC-2 (Medium, correctness) - string_view detection now honors _MSVC_LANG so MSVC /std:c++17 consumers get the same public API as GCC/Clang. Closed: compile-only probe of isMember(string_view) and operator[](string_view) at MSVC C++17 without /Zc:__cplusplus went from error C2665 to compiling.
Changed: include/json/value.h (detection block at lines 42-48: added _MSVC_LANG >= 201703L alternative plus explanatory comment).
Checkpoint: 58e465e5bc15f105c7567613d7ce18e363894214
Verification: Acceptance check executed pre-fix and confirmed failing (error C2665, overloads invisible), then post-fix compiling (probe.lib produced). Verify gate green: All 132 tests passed, ctest 100% of 3. Contract preserved: single detection site (grep shows no other 201703 gate in include/ or src/); every string_view overload is an inline header-defined wrapper forwarding to existing exported members, so no new library symbols and no ABI change; default C++11 builds are byte-identical (macro still undefined there).
Learnings: none new.
Next: JC-3 (CI job compiling JSONCPP_USE_SECURE_MEMORY=1).

## iter 4/10 | 9b4ea811-060501 | 2026-07-30 | JC-3 | done
Task: JC-3 (Medium, testing) - CI now compiles and runs the unit suite with JSONCPP_USE_SECURE_MEMORY=1. Closed: cmake.yml gained a cmake-secure-memory job (3 OSes, C++17, flag via CMAKE_CXX_FLAGS).
Changed: .github/workflows/cmake.yml (new job following the existing threeal/cmake-action convention).
Checkpoint: 89f11fc08b1c23967680ebee8d6c1f501829ae80
Verification: Acceptance: grep shows the flag in the workflow; yaml.safe_load parses the file. The exact job configuration was executed locally as the strongest available approximation of the runner: MSVC C++17 + -DJSONCPP_USE_SECURE_MEMORY=1 built jsoncpp_test and reported All 132 tests passed (this also integration-tests the JC-2 string_view overloads together with the secure allocator). Verify gate green: All 132 tests passed, ctest 100% of 3. Workflow not pushed anywhere per the never-push rule; it runs when the user next pushes.
Learnings: none new.
Next: JC-4 (retire stale appveyor.yml).

## iter 5/10 | 9b4ea811-060501 | 2026-07-30 | JC-4 | done
Task: JC-4 (Low, dependency-hygiene) - removed stale appveyor.yml. Closed: file deleted; grep confirms no reference to AppVeyor anywhere outside jeffy state files (no README badge, no docs), so nothing dangles.
Changed: appveyor.yml (deleted); PLAN.md inventory row wording updated.
Checkpoint: 039601aa14af9702a16a2ec6531ab1336adc3072
Verification: Rationale: config pinned retired VS2015/2017 AppVeyor images and submitted to a CDash dashboard via ctest ExperimentalSubmit; Windows coverage is provided by cmake.yml (windows-latest at C++11/17/20 plus the JC-3 secure-memory job), so the file was dead weight that could only mislead. Verify gate green: All 132 tests passed, ctest 100% of 3. Open tasks now below 3 (JC-5, JC-6); replenishment will come from the closing full audit rather than a mid-task partial, keeping one action per iteration.
Learnings: none new.
Next: JC-5 (pip-install meson, sweep the Meson build row).

## iter 6/10 | 9b4ea811-060501 | 2026-07-30 | JC-5 | done
Task: JC-5 (Low, testing) - swept the Meson build row, the last unswept Surface inventory row. Closed: meson 1.11.2 (pip-installed) setup + compile + test all exit 0 on MSVC; 3/3 suites green (unit tests, jsontestrunner corpus, jsonchecker corpus).
Changed: PLAN.md (Meson row flipped to swept at 039601a), BACKLOG.md (JC-5 deleted). No project source changed.
Checkpoint: c3c4186fd872b1ff557019920d6669da24121bae
Verification: meson test output: Ok: 3, Fail: 0. Verify gate green: All 132 tests passed, ctest 100% of 3. Note recorded in the row: meson maps cpp_std=c++11 to C++14 on MSVC with a warning - meson-standard behavior, not a project defect. Surface inventory now 16 of 16 rows swept.
Learnings: none new.
Next: JC-6 (CZString copy-assign footgun and stale comment), then the closing full audit.

## iter 7/10 | 9b4ea811-060501 | 2026-07-30 | JC-6 | done
Task: JC-6 (Low, code-quality) - eliminated the CZString copy-assign footgun and corrected the misleading comment. Closed: copy-assign explicitly deleted (was a shallow copy of an owning pointer, latent double free; grep shows zero call sites - the two json_valueiterator.inl uses are copy construction), and the value.h cstr_ comment now states the truth: non-prefixed duplicateStringValue copy owned when policy_ is duplicate, aliased caller memory otherwise.
Changed: include/json/value.h (operator= declared = delete with rationale; cstr_ comment corrected), src/lib_json/json_value.cpp (shallow definition removed).
Checkpoint: 0d8bc9181eb8c14696dc550d5f8aaa040d267968
Verification: Acceptance met: default build All 132 tests passed; secure-memory C++11 build All 132 tests passed; secure-memory C++17 build All 132 tests passed; ctest 100% of 3. Contract preserved: CZString is a private nested class, copy-assign had no callers in library, tests, or iterators, and std::map never copy-assigns keys, so no observable behavior changes; deleting beats keeping a wrong implementation or adding an unused correct one.
Learnings: none new.
Next: Ledger is empty - iteration 8 runs the closing full fresh-evidence audit.

## iter 8/10 | 9b4ea811-060501 | 2026-07-30 | AUDIT | audit
Task: Closing full fresh-evidence audit across all applicable dimensions, all 16 Surface inventory rows swept and none stale (no implementing code changed since 0d8bc91).
Changed: JOURNAL.md only (this entry); no source changes, no BACKLOG items filed - the audit found nothing to file.
Checkpoint: 2745b28fc8de3a77af11163dc1c4daea2c47cb2f
Verification: Fresh evidence executed this iteration: default build All 132 tests passed and ctest 100% of 3 (unit suite, jsontestrunner corpus, jsonchecker corpus); secure-memory C++17 build All 132 tests passed; amalgamate.py regenerated outputs successfully; version 1.10.0 consistent across version.h, meson.build, CMakeLists.txt, MODULE.bazel; run diff (60de77f..HEAD, source files only) reviewed hunk by hunk - each change matches its journal entry, and both release functions retain their correct call sites (releasePrefixedStringValue for Value string payloads at json_value.cpp:1075, releaseStringValue for CZString keys). Scores on the fully swept surface: correctness None, security None, testing None, architecture None, code-quality None, error-handling None, documentation None, dependency-hygiene None, developer-experience None; performance skipped (README declares it out of scope); observability and UX/accessibility not applicable (library, no user-facing UI). Zero High, zero Medium in-envelope: CLOSEOUT BEGINS - no further audits or replenishment this run; ledger is already empty, so the next iteration runs the evaluator gate and, on PASS, declares convergence.
Learnings: none new.
Next: Iteration 9 - adversarial evaluator, then convergence on PASS.

## iter 9/10 | 9b4ea811-060501 | 2026-07-30 | AUDIT | blocked
Task: Evaluator gate (invocation 1 of 2) ahead of convergence. Result: REJECT - convergence not declared.
Changed: BACKLOG.md (JC-7 filed at High), JOURNAL.md. No source changes.
Checkpoint: e92d135135d13a85b8bc0d55c16942e4922f6d0a
Verification: Evaluator (fresh-context sub-agent) confirmed the Verify command green (132/132 unit, ctest 3/3), re-ran and confirmed all six closed acceptance checks (JC-1 secure jsoncpp_test 132/132; JC-2 probe compiles with no /Zc:__cplusplus; JC-3 YAML parses with the flag present; JC-4 appveyor gone; JC-5 meson 3/3 re-run; JC-6 delete verified with correct release pairing), but REJECTED with one reproduced finding: the full default-target build under the CI job's exact flags fails at src/jsontestrunner/main.cpp:331 (error C2440, Json::String assigned to std::string), meaning the committed cmake-secure-memory job is red on all OSes. Root cause of the miss: JC-1 and JC-3 verification built only the jsoncpp_test target, never the default target set the CI job builds. Filed as JC-7 (High). This is a High found by the gate, worked despite closeout per the closeout rules.
Learnings: Verifying a CI job requires building the job's actual target set, not a proxy target - a partial-target build certifies nothing about the job. Copied to PLAN.md Lessons.
Next: Iteration 10 - fix JC-7, re-run the full secure build, evaluator invocation 2 of 2, converge on PASS or close with the run report.

## iter 10/10 | 9b4ea811-060501 | 2026-07-30 | JC-7 | converged
Task: JC-7 (High, security) - jsontestrunner now compiles and runs under JSONCPP_USE_SECURE_MEMORY=1; run converged. Closed: one-line fix at src/jsontestrunner/main.cpp:331 (std::string -> Json::String, type-identical in default builds).
Changed: src/jsontestrunner/main.cpp (one line), BACKLOG.md (JC-7 deleted, Converged line appended), JOURNAL.md.
Checkpoint: 5664f81ea214380e7c116181dd370c89d031b555
Verification: Acceptance: full default-target build with CMAKE_CXX_STANDARD=17 and CMAKE_CXX_FLAGS=-DJSONCPP_USE_SECURE_MEMORY=1 exits 0 with All 132 tests passed (was error C2440); verify gate green (132/132 unit, ctest 3/3). Evaluator: PASS - invocation 2 of 2 independently rebuilt the previously failing configuration from scratch (exit 0, 132/132, macro propagation verified in vcxproj), ran the corpus suites inside the secure build (3/3), re-ran the Verify command (3/3), confirmed HEAD touches only the one source line plus ledger, greped jsontestrunner clean of remaining std::string uses, and traced the CZString allocation/release pairing; no in-envelope High or Medium found. Convergence conditions: clean full audit iter 8, 16/16 rows swept, ledger empty (nothing Declined-by-convenience, nothing blocked), commits since the clean audit are exactly the JC-7 fix the gate filed plus state-file edits, Verify green this iteration.
Learnings: none new.
Next: Run complete. Next session may start a fresh run; the ratchet applies while only state files change.
