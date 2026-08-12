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

## iter 1/10 | b783c3f3-034143 | 2026-08-11 | AUDIT | audit

Task: First audit of cJSON 1.7.19. Filled the Operating envelope, the Verify command with its Oracle class and Environment fingerprint, and the Surface inventory, then swept the inventory breadth-first with a known-answer battery.

Changed: PLAN.md (envelope, 24 inventory rows, verify command), BACKLOG.md (6 findings), .jeffy/probes/api-known-answer/{probe.c,run.sh,paths}, .gitignore.

Checkpoint: 43c59a9c48dbaeadb13e2458baf68a12696fcfb8

Verification: Verify command exits 0 - 22/22 ctest targets pass, so the whole suite is green over every defect below. The battery `./.jeffy/probes/api-known-answer/run.sh` exercises 21 of the 24 rows with known-answer expectations taken from cJSON.h, cJSON_Utils.h, RFC 8259, RFC 6901, RFC 6902 and RFC 7386, and reports 6 failures, one per finding. Two findings were confirmed beyond the battery with AddressSanitizer repros: sort-then-append leaks the dropped item (LeakSanitizer, 66 bytes in 2 allocations, cJSON_New_Item via cJSON_CreateNumber), and detach-foreign-then-append is a heap-use-after-free (WRITE of size 8 in suffix_object at cJSON.c:1986). One probe expectation was wrong and was corrected rather than filed: cJSON_CreateArrayReference takes the child list head, not the container.

Scores, claiming the 21 swept rows only and not the 3 unswept ones (build-packaging, fuzz-harness, docs): correctness High (F1, F2, F3, F4), security High (F2), error handling Medium (F1 returns true after dropping the item; F4 mutates silently), testing Medium (the full suite is green over all six defects; ctest runs each of the 22 targets as its own process, so the isolation check the Method requires is inherent here and no order dependence is possible), documentation Low (F5), architecture None, code quality None, performance None, dependency hygiene None (no external runtime dependencies; vendored Unity under tests/unity is the only bundled code), developer experience None. Observability is not applicable - a parsing library with no logging or metrics surface. UX and accessibility are not applicable - no user-facing surface.

F1 and F2 share one root cause class, the child-list circular tail-pointer invariant (head->prev is the tail): sort_list drops it, DetachItemViaPointer corrupts it. Two instances, so the three-strike rule has not fired; a third instance replaces instance patching with one structural task.

Severity rationale for F2 against the envelope: the surface is user-error class, but a valid cJSON node passed as the wrong parent's child is a wrong value rather than the hand-corrupted node the envelope puts out of scope, and the function already carries a guard that intends to reject exactly this. In-envelope input with heap corruption as the consequence, so High stands rather than the Low cap.

Learnings: cJSON keeps a circular tail pointer on every child list (head->prev is the tail, every other prev is the real predecessor), and add_item_to_array silently no-ops when it is NULL - any code that rebuilds a child list must restore it. The default `cmake -S . -B build` leaves ENABLE_CJSON_UTILS OFF and silently omits 3 of the 22 test targets, so the Verify command sets it explicitly. Probe expectations must come from the headers and the RFCs, not from running the code first: the battery caught six defects precisely because it was written against the contract.

Next: F1, the High with the widest blast radius - four public cJSONUtils entry points corrupt any object they touch.

## iter 2/10 | b783c3f3-034143 | 2026-08-11 | F1 | done

Task: F1 (High, runtime, correctness) - sort_list rebuilds an object's child list without restoring the circular tail pointer, so every later append is silently dropped, reported as success, and leaked.

Closed: F1 - restore the child-list tail pointer after sorting - fixed in sort_object, with two regression tests in tests/misc_utils_tests.c that both fail against the unfixed code.

Changed: cJSON_Utils.c (sort_object restores head->prev), tests/misc_utils_tests.c (two regression tests), BACKLOG.md (F1 deleted, one Settled class added), PLAN.md (four cJSON_Utils rows re-swept at this checkpoint).

Checkpoint: f100c1d7264d45ce034067cbe26bd3755fe9c953

Verification: Filed reproduction re-run first, as required, and it still reproduced on unfixed code - LeakSanitizer reported 66 bytes in 2 allocations and the appended member was absent from the printed document. After the fix both repros exit 0 and print `{"a":1,"b":2,"c":3,"z":26}`, through cJSONUtils_SortObject and through cJSONUtils_GeneratePatchesCaseSensitive. The two new Unity tests were proved strong enough to fail: with `git show HEAD:cJSON_Utils.c` restored over the working file and the fix held aside, `ctest -R misc_utils_tests` exits 8 with `3 Tests 2 Failures`, both new tests failing on the tail-pointer assertion; with the fix back, 22/22 ctest targets pass and the Verify command exits 0. Battery differential: 6 failures at the start of this iteration, 4 after, and the 4 remaining are exactly F2, F3, F4 and F5, which are still open on the ledger. No new battery failure appeared, which is the regression signal; the battery goes green when the ledger empties.

Contract preserved: the sort order and the entire next chain are untouched - only head->prev is restored, and cJSON already maintains that pointer as the list tail in add_item_to_array, cJSON_DetachItemViaPointer and cJSON_InsertItemInArray, so the fix makes cJSON_Utils agree with the invariant the rest of the library already relies on rather than introducing a new one. No public signature, no documented behavior and no printed output changes, so no documentation edit and no inventory row flip back to unswept is due on that account; the four rows implemented by cJSON_Utils.c are re-swept at this iteration's checkpoint because the battery covering them re-ran green here.

Learnings: the existing sort_tests in tests/old_utils_tests.c walks the sorted list with ->next only, which is exactly why a green suite sat over this defect for as long as it did - a doubly linked list test that never asserts on prev tests half the structure. A battery whose expectations encode open findings fails by design, so the regression signal is the failure set shrinking, never the exit status alone; record the set each iteration.

Next: F2, the second High - cJSON_DetachItemViaPointer accepts a foreign item and leaves a dangling tail pointer behind it.

## iter 3/10 | b783c3f3-034143 | 2026-08-12 | F2 | done

Task: F2 (High, runtime, security) - cJSON_DetachItemViaPointer accepts an item belonging to another parent, cross-linking the two documents and leaving parent's tail pointer dangling.

Closed: F2 - reject an item that is not a child of parent - fixed class-complete across both pointer-taking entry points with one shared has_child helper, plus a regression test in tests/misc_tests.c that fails against the unfixed code.

Changed: cJSON.c (has_child helper; both ViaPointer guards), cJSON.h (both contracts documented), tests/misc_tests.c (one regression test), BACKLOG.md (F2 deleted, one Settled class added), PLAN.md (seventeen cJSON.c rows re-swept at this checkpoint).

Checkpoint: 00091a7ded01773c853222e23e687f671532de91

Verification: Filed reproduction re-run first and still reproduced - AddressSanitizer heap-use-after-free, WRITE of size 8 in suffix_object at cJSON.c, reached through add_item_to_array. Filed as one instance, fixed as a class: the enumeration is `grep -n ViaPointer cJSON.h`, which returns exactly two entry points, and the second site was reproduced before the fix rather than assumed - cJSON_ReplaceItemViaPointer(a, foreign, x) returned 1, left a as `[1,2]` and silently rewrote the unrelated document b from `[7,8,9]` to `[7,5,9]`. After the fix both refuse the foreign item, both documents print unchanged, and both repros exit 0 under ASan. The new Unity test was proved strong enough to fail: against `git show HEAD:cJSON.c` with the fix held aside, `ctest -R '^misc_tests$'` exits 8 with `31 Tests 1 Failures` on the detach assertion. Verify command exits 0, 22/22. Battery differential: 4 failures at the start of this iteration, 3 after, the 3 remaining being exactly F3, F4 and F5, still open on the ledger.

Verify gate fired once and was repaired rather than reverted, and the repair was mine to make: the first fix attempt replaced the whole guard with the membership walk, which dropped a second contract the pre-existing test cjson_detach_item_via_pointer_should_return_null_if_item_prev_is_null pins - that test hand-builds a list whose back-links were never set, so an element reachable by next can still carry a NULL prev, and the unlink arithmetic dereferenced it. misc_tests segfaulted, ASan located it at cJSON_DetachItemViaPointer, and the second attempt restored the prev check alongside the membership check. This was a regression I introduced inside the iteration, not a pre-existing fault newly exposed, so it was fixed before the checkpoint rather than carried.

Contract preserved and changed: every item that really is a child of parent behaves exactly as before, and cJSON_ReplaceItemViaPointer keeps its documented early-true when replacement equals item. What changed is accepted inputs - a foreign item is now refused instead of corrupting memory - and the cost, since both entry points now walk parent's child list. The four call sites inside cJSON.c already performed an O(n) lookup before calling through, so cJSON_DetachItemFromArray, DetachItemFromObject, ReplaceItemInArray and ReplaceItemInObject keep their complexity; a caller invoking the two public ViaPointer functions directly pays O(n) where it paid O(1). Both header comments now state the membership requirement and that cost, so the module does not contradict its own documentation. The seventeen inventory rows implemented by cJSON.c are re-swept at this checkpoint because the battery covering them re-ran here.

Learnings: tests/common.h includes ../cJSON.c, so a test translation unit must never also be linked against cJSON.c - compile the test file alone or the link fails on duplicate symbols. cJSON's own tests hand-build malformed lists on the stack to pin guard behaviour, so a guard cannot be replaced wholesale by a stronger-looking check without reading what the existing tests construct.

Next: F3, the first Medium - the number parser accepts four RFC 8259 violations.

## iter 4/10 | b783c3f3-034143 | 2026-08-12 | F3 | done

Task: F3 (Medium, runtime, correctness) - parse_number accepts RFC 8259 violations because it delegates the grammar to strtod, which is more permissive than JSON.

Closed: F3 - measure the JSON number prefix before strtod sees it - fixed with a json_number_prefix_length scan in parse_number, with a regression test in tests/parse_number.c covering 13 invalid and 14 valid forms that fails against the unfixed code.

Changed: cJSON.c (json_number_prefix_length; parse_number truncates to the validated prefix), tests/parse_number.c (one regression test), .jeffy/probes/api-known-answer/probe.c (parse-scalars expectation corrected), BACKLOG.md (F3 deleted, one Settled class added), PLAN.md (seventeen cJSON.c rows re-swept at this checkpoint).

Checkpoint: 24f9cba2e025d40023e9a387a5e2c7896ba74350

Verification: Filed reproduction re-run first and all four forms still parsed. The root cause is that parse_number collects a span of number-ish characters and lets strtod decide how much of it to consume; strtod accepts leading zeros, a trailing decimal point and hex, none of which are JSON. Fixed at the single boundary rather than per-form: the span is now measured against the RFC 8259 grammar and truncated to the longest valid prefix before strtod runs, which preserves cJSON's existing consume-the-longest-number-and-let-the-caller-reject-the-rest behaviour. `[01]`, `[00]`, `[-01]`, `[1.]`, `[.5]`, `[+1]`, `[-]`, `[1e]`, `[e5]`, `[--1]`, `[1e+]`, `[0x10]` and `[1.2.3]` are now all rejected, and 14 valid forms including `[0]`, `[-0]`, `[1e+5]`, `[-1.5e-3]` and `[0e0]` still parse. Verify command exits 0, 22/22, with no pre-existing test having pinned the lenient behaviour. The 11 documents under tests/inputs parse exactly as before, test6 rejected and the other ten accepted, matching what parse_examples asserts. New Unity test proved strong enough to fail: against `git show HEAD:cJSON.c` it exits 8 with `7 Tests 1 Failures` on `[01]`.

A battery expectation was wrong and was corrected rather than filed as a second finding, the second time this run: the probe asserted `cJSON_Parse("01") == NULL`, but cJSON_Parse deliberately tolerates trailing garbage - `cJSON_Parse("{}garbage")` succeeds by the same rule - so parsing `01` as the number 0 with `1` left unconsumed is correct. The grammar is now checked where that tolerance does not apply, inside a container and with require_null_terminated set, and both were confirmed to reject all four filed forms. The corrected battery was re-run against the unfixed source to prove it still detects the defect: 11 failures there against 2 here.

Contract preserved and changed: valid JSON numbers parse to the same values, and the trailing-garbage tolerance of cJSON_Parse is untouched. What changed is that a prefix which is not a JSON number no longer counts as one, so documents that were accepted only through strtod's C-flavoured leniency are now rejected. That is a deliberate narrowing of accepted input on an adversarial surface and the reason the finding was filed; README and cJSON.h make no leniency promise to contradict, so no documentation edit is due. The seventeen inventory rows implemented by cJSON.c are re-swept at this checkpoint because the battery covering them re-ran here.

Learnings: cJSON_Parse tolerates trailing garbage by design, so a grammar rejection must be probed inside a container or with require_null_terminated set - a bare cJSON_Parse of an invalid tail proves nothing. When a battery expectation turns out to encode the probe author's assumption rather than the documented contract, correct the battery and re-run it against the unfixed source to prove it still fails there, or the correction can quietly delete the check.

Next: F4, the remaining Medium - cJSON_ReplaceItemInObject renames the matched key to the lookup string's casing.

## iter 5/10 | b783c3f3-034143 | 2026-08-12 | F4 | done

Task: F4 (Medium, runtime, correctness) - replace_item_in_object adopts the caller's lookup string as the member key, silently renaming a member matched case insensitively.

Closed: F4 - keep the document's own key on replacement - and F7 (High, runtime, security), a heap use-after-free in the same function, filed this iteration and closed by the same root-cause change; one regression test in tests/misc_tests.c covers both and fails against the unfixed code.

Changed: cJSON.c (replace_item_in_object looks the member up first, copies its key before releasing the old one, and returns early on self-replace), tests/misc_tests.c (one regression test), BACKLOG.md (F7 filed then F4 and F7 deleted, one Settled class added), PLAN.md (seventeen cJSON.c rows re-swept at this checkpoint).

Checkpoint: 645a34e875b42366bbedeb2e76c3dc8fd97c4ff7

Verification: Filed reproduction re-run first and F4 still reproduced - replacing via the lookup string "aA" on a document holding "Aa" printed `{"aA":5,"b":2}`. Probing the same function for the fix turned up a second, worse defect: cJSON_ReplaceItemInObject(object, item->string, item) frees replacement->string and then reads it, an AddressSanitizer heap-use-after-free, READ of size 2 in cJSON_strdup reached from replace_item_in_object. It was filed as F7 at High rather than folded in silently, and it was confirmed pre-existing rather than assumed: the same repro built against `git show c859b25:cJSON.c`, the commit this run started on, aborts the same way, and `git diff c859b25 -- cJSON.c | grep -c replace_item_in_object` returns 0, so this run had not touched the function. Both are one root cause - the function managed the member key wrongly - so they were fixed as one change per the Method's file-the-root-cause-not-the-symptom rule, and both are recorded separately here and on the ledger so the severity discovered is not lost. After the fix the document keeps `{"Aa":5,"b":2}` and the self-replace repro exits 0 under ASan. Verify command exits 0, 22/22. New Unity test proved strong enough to fail: against `git show HEAD:cJSON.c` it exits 8 with `32 Tests 1 Failures`, reporting `Expected '{"Aa":5,"b":2}' Was '{"aA":5,"b":2}'`. Battery differential: 2 failures at the start of this iteration, 1 after, the remainder being F5, still open.

Contract preserved and changed: a successful replacement still swaps the item and still clears cJSON_StringIsConst on the replacement, and the return value is unchanged in every case - a missed lookup returned false before and returns false now. Two things changed. The stored key is now the document's rather than the caller's, which is the finding. And a failed lookup no longer has a side effect: previously the replacement's string was freed and overwritten before the lookup was attempted, so a miss left the caller's item mutated; now nothing is touched until the member is found. Self-replacement is now an explicit early true, which is what cJSON_ReplaceItemViaPointer already did for the equivalent case. cJSON.h documents neither the key spelling nor the miss behaviour, and the new behaviour is the one a reader of that header would assume, so no header edit is due. The seventeen inventory rows implemented by cJSON.c are re-swept at this checkpoint because the battery covering them re-ran here.

Learnings: when a fix needs to read a field it is about to free, copy first and release second - the caller may legitimately have passed that very buffer as an argument, which is how the self-replace use-after-free arose. Probing the function being fixed for neighbouring defects is worth the minutes: F7 was a High sitting one line away from a Medium, invisible to the whole suite.

Next: F5, a Low - cJSON_InsertItemInArray's undocumented append fallback past the end of the array.

## iter 6/10 | b783c3f3-034143 | 2026-08-12 | F5 | done

Task: F5 (Low, docs, documentation) - cJSON_InsertItemInArray silently appends when which is past the end and returns true, a contract stated nowhere.

Closed: F5 - state the out-of-range contract - documented in cJSON.h and README.md, pinned by a new Unity test and by the corrected battery section, with no behaviour change.

Changed: cJSON.h (comment), README.md (the paragraph describing the function), tests/misc_tests.c (one regression test), .jeffy/probes/api-known-answer/probe.c (insertion expectations rewritten against the documented contract), BACKLOG.md (F5 deleted).

Checkpoint: 08d54932b5c6b862620f4f8e7411ccc24ca7941c

Verification: Filed reproduction re-run first, then the whole out-of-range domain was mapped rather than assumed, because a contract cannot be documented from one sample: on `[1,2]`, which of -1 returns 0 and changes nothing, 0, 1 and 2 insert at that position, and 3 and 99 both append; on `[]`, both 0 and 5 leave `[9]`. The behaviour is deliberate - an explicit `return add_item_to_array(array, newitem)` branch, not an accident - and cJSON_InsertItemInArray has shipped this way for years, so the fix documents it rather than changing it. The competing option, making it return false past the end to match cJSON_ReplaceItemInArray, was rejected: it would break callers relying on the fallback for no correctness gain, and the finding was filed as a docs gap, not a behaviour defect. README.md was found to describe the function too, by `grep -n InsertItemInArray README.md CHANGELOG.md`, so both places now state the same contract; the CHANGELOG hit is a historical CVE line and was left alone. Verify command exits 0, 22/22. Battery now exits 0 with no failures, the first fully green run of this battery.

The battery correction was proved not to be a weakening, which is the risk when a probe is edited to agree with the code: the insertion section now asserts position and ownership rather than a bare return value, and re-running it against a variant of cJSON.c whose append fallback was replaced with `return false` produces 3 failures including `got "[0,1,2,3]" want "[0,1,2,3,7]"`. That variant was discarded and cJSON.c is unchanged this iteration, confirmed by `git diff --stat cJSON.c` being empty.

Contract preserved: no behaviour changed at all this iteration. cJSON.c was not modified, so no Surface inventory row went stale and none needed re-recording; the rows implemented by cJSON.c still name iteration 5's checkpoint, which is the commit their code still carries.

Learnings: document the whole domain of a parameter, not the one value the finding named - mapping which across negative, interior, boundary and far-past-the-end took one command and turned a one-line guess into a contract. When a probe is corrected to match the code, prove the corrected probe still fails against a deliberately broken variant, or the correction is indistinguishable from deleting the check.

Next: the ledger holds one open task, F6, which is below the replenishment threshold of 3, and the Surface inventory still lists 3 unswept rows - build-packaging, fuzz-harness and docs - which convergence requires. The next iteration sweeps those three rows as a partial audit, which replenishes the ledger and closes the inventory gap in the same pass.

## iter 7/10 | b783c3f3-034143 | 2026-08-12 | AUDIT | audit

Task: Full fresh-evidence audit, sweeping the last three unswept Surface inventory rows - build-packaging, fuzz-harness and docs - and rescoring every dimension.

Changed: PLAN.md (three rows swept, Oracle class corrected), BACKLOG.md (F8 filed).

Checkpoint: be27a1221c97a796bc17c9ec9302c1a1dbdf5592

Verification: The inventory now lists no unswept row, 24 of 24. Fresh evidence for the 21 code rows: the battery exits 0 with no failures, the Verify command exits 0 at 22/22, and the plain Makefile path builds every target clean under -std=c89 -Werror -Wconversion -Wcast-qual -Wc++-compat -Wstrict-overflow=2, which is a stricter compile than the cmake path applies and which every change this run passes. build-packaging also checked version agreement across cJSON.h 1.7.19, CMakeLists PROJECT_VERSION 1.7.19 and both pkg-config templates. fuzz-harness built cjson_read_fuzzer.c under ASan and UBSan and drove all 14 shipped inputs with no sanitizer report. docs resolved all 70 cJSON_ and cJSONUtils_ names README.md mentions against the two headers with comm; the four unmatched are the prose family prefixes cJSON_Add, cJSON_Create, cJSON_Is and the module name cJSON_Utils, so no reference is broken, and the README code examples are executed by the readme_examples ctest target.

Sweeping build-packaging found F8, a High, and it also invalidated an assumption this run had been making since iteration 1. Configuring into a fresh directory fails: `cmake_minimum_required(VERSION 3.0)` is below CMake 4's hard floor of 3.5, so cmake 4.2.3 exits 1 with "Compatibility with CMake < 3.5 has been removed". Every Verify run this run has made reused the `build/` directory that already existed in this working copy, whose cache records CMAKE_CACHE_MAJOR_VERSION 4, and cmake reuses a valid cache without re-running the version check. So the green results recorded in iterations 1 through 6 do certify that the sources compile and that 22 of 22 test targets pass - that part was really executed every time - but they never certified that the project configures from nothing, and it does not. The Oracle class line in PLAN.md now says so, and the Verify command will be tightened to a fresh-directory configure in the iteration that fixes F8, so a stale cache can never certify it again. Fixing the command before the defect would only make the gate red without telling anyone anything new.

F8 was confirmed pre-existing rather than assumed: `git archive c859b25 | tar -x` into a clean directory, then configure, reproduces the failure at the commit this run started from, and `git diff c859b25 --stat -- CMakeLists.txt` is empty. Adding -DCMAKE_POLICY_VERSION_MINIMUM=3.5 configures successfully, which confirms the cause rather than merely correlating with it. `grep -rn cmake_minimum_required --include=CMakeLists.txt --include=*.cmake .` returns two sites and both are below the floor: CMakeLists.txt at 3.0 and library_config/uninstall.cmake at 2.8.5, so the fix covers both. The README's own documented recipe - mkdir build, cd build, cmake .. - is the failing command, which is what puts this at High rather than lower: a user following the project's install instructions on a current toolchain gets nothing.

Scores, now claiming all 24 rows: build High (F8, the only High). correctness None, security None, error handling None, architecture None, code quality None, performance None, documentation None, dependency hygiene None (no external runtime dependencies; vendored Unity is the only bundled code), developer experience None. testing Low (F6, no fuzz target reaches cJSON_Utils). Observability not applicable, no logging or metrics surface. UX and accessibility not applicable, no user-facing surface. Closeout does not begin: this audit found a High, and the rule requires zero High and zero Medium.

Learnings: a build directory that already exists is not evidence that the project configures, because cmake reuses a valid cache without re-checking cmake_minimum_required - configure into a throwaway directory, or from a `git archive` export, before believing a build is sound. An audit that sweeps the build surface should run the project's own documented install recipe verbatim, because that recipe is the contract with users and it can be broken while every test passes.

Next: F8, the High - raise both cmake_minimum_required floors and tighten the Verify command to a fresh-directory configure in the same iteration.

## iter 8/10 | b783c3f3-034143 | 2026-08-12 | F8 | done

Task: F8 (High, build-ci, build) - the project does not configure on CMake 4.x because both cmake_minimum_required floors sit below CMake 4's hard minimum of 3.5.

Closed: F8 - raise both cmake_minimum_required floors to 3.10 and tighten the Verify command to a from-scratch configure - the whole documented install path now works on cmake 4.2.3, and the tightened Verify command exits 1 against the unfixed CMakeLists.

Changed: CMakeLists.txt and library_config/uninstall.cmake (floor 3.10), PLAN.md (Verify command gains a leading `rm -rf build`, Oracle class rewritten, Verify duration remeasured, build-packaging row re-swept), BACKLOG.md (F8 deleted, one Settled class added).

Checkpoint: d7fde9565fb45cd92e4928078d9cb8afb7d879ac

Verification: Filed reproduction re-run first and still failed - a `git archive HEAD` export configured with no policy flag exits 1 on "Compatibility with CMake < 3.5 has been removed". The floor chosen is 3.10 rather than the minimum 3.5 that would unbreak it, because cmake 4.2.3 emits "Compatibility with CMake < 3.10 will be removed from a future version" for anything lower: 3.5 would fix today and break again at the next removal, and it would leave the deprecation warning that has appeared in every configure this run. 3.10 dates from 2017, so the compatibility cost to downstream packagers is nil. Both sites were fixed, not just the one the error named, from `grep -rn cmake_minimum_required --include=CMakeLists.txt --include=*.cmake .` which returns exactly two.

The acceptance evidence is the documented install path driven end to end on a pristine export, not just a configure: configure exits 0 with zero deprecation or warning lines, build exits 0, ctest is 22/22, `cmake --install` lays down headers, both sonamed shared libraries, both pkg-config files and the CMake package config, `pkg-config --modversion libcjson libcjson_utils` reports 1.7.19 twice, a consumer program compiles against the pkg-config flags and prints `{"a":[1,2]}`, the same consumer builds through `find_package(cJSON REQUIRED)` against the installed package config and prints the same, and `cmake --build . --target uninstall` exits 0 and removes the installed files - which is what actually exercises library_config/uninstall.cmake, the second file whose floor was stale. The audit could reach none of this in iteration 7 because configure failed before any of it.

The tightened Verify command was proved to grade what it now claims: run verbatim it exits 0, and run against `git show HEAD:CMakeLists.txt` restored over the working file it exits 1. Battery exits 0. Two stated numbers in PLAN.md were invalidated by this change and re-measured rather than left standing: the Verify duration is now 20s from a timed run, up from 4s when the command reused a warm build directory, still far below the four-minute threshold so no verify_timeout_seconds line is due; and the Environment fingerprint's exclusion enumeration was re-run and still returns exactly one skipped body, print_number_should_print_non_number, plus tests/unity_setup.c which only compiles under MSVC, with `ls tests/*.c` at 22 files - 21 test programs and that MSVC helper - against 22 registered ctest targets, the twenty-second being cJSON_test from the root test.c.

Contract preserved and changed: no library behaviour changed and no source file under test was touched, so the code rows keep their existing sweep commits. What changed is the minimum supported CMake, from a nominal 3.0 that no longer works anywhere to a real 3.10 that does. That is a compatibility narrowing and it is recorded here deliberately; the alternative, leaving the floor where it was, means the project cannot be built at all by anyone on a current CMake. The build-packaging inventory row went stale when CMakeLists.txt changed and is re-swept at this checkpoint with the install evidence above.

Learnings: choose a version floor against what the toolchain says it will remove next, not only against what it rejects today - cmake names both, and fixing to the current hard minimum buys one release of relief. When a fix unblocks a path an earlier audit could not reach, exercise that whole path in the fixing iteration, because the audit's clean score for it was silence rather than evidence.

Next: F6, the one remaining task, a Low - no fuzz target reaches the cJSONUtils_* entry points.

## iter 9/10 | b783c3f3-034143 | 2026-08-12 | EVALUATOR | audit

Task: Adversarial evaluator gate, invocation 1 of a cap of 2. Run early rather than at the declaration: the ledger held only a Low, the closing conditions otherwise appeared to hold, and gating at the last iteration would leave a REJECT unanswerable.

Changed: .jeffy/evaluator/b783c3f3-034143-1.md (the gate's artifact), BACKLOG.md (F9 filed from the rejection, F10 filed from a gate observation).

Checkpoint: 7f9a937880f71e5bc32c24bf4bfc834f956af24f

Verification: Verify command exits 0 at 22/22 and the battery exits 0 before the gate was invoked. Evaluator: REJECT - one substantiated reason, a leaking test this run introduced.

The rejection was not taken on trust; it was reproduced independently before being accepted. tests/misc_tests.c builds a cJSON_CreateNumber(9) for the refused-replacement assertion in cjson_replace_item_in_object_should_keep_the_documents_key, the call correctly refuses it, and nothing frees it. Configuring with -DCMAKE_C_FLAGS="-g -fsanitize=address" and matching linker flags, ctest exits 8 with `95% tests passed`, `14 - misc_tests (Failed)`, and a 64-byte direct leak traced through cJSON_CreateNumber to that assertion. tests/CMakeLists.txt wraps every test in `valgrind --trace-children=yes --leak-check=full --error-exitcode=1` under the CI ENABLE_VALGRIND leg, so this turns a CI leg red. Filed as F9 at Medium: it cannot affect the shipped library, only the suite, and only under the mem-check legs, which is why it is not High.

This one stings, and it is worth recording why it got through. Iteration 5 wrote the sibling assertion thirty-five lines earlier with an explicit `cJSON_Delete(replacement)` and a comment reading "a refused replacement is not adopted, so the caller still owns it" - the contract was understood, written down, and then violated in the next assertion in the same function. The run's own Verify command cannot see it because ENABLE_VALGRIND and ENABLE_SANITIZERS are both OFF, which the Environment fingerprint has disclosed since iteration 1; that disclosure is what made the gap findable rather than invisible. The ASan ctest configuration is not added to the Verify command in this iteration: inside the convergence sequence only the gate's own findings may be worked, and broadening the gate now would invalidate the PASS the declaration needs. It goes to the run report as next-run work.

The gate also recorded one observation that is not a rejection reason, filed as F10 (Low, docs) for the next run rather than fixed here, exactly as the rule requires: every adopting function requires an unowned item, and passing one a document already owns builds a cyclic child list that makes any later print or walk loop forever. It reproduces identically at the run's base commit and through five separate entry points, so it is one library-wide precondition nobody has written down, not a defect in the two entry points iteration 3 guarded.

Everything else the gate checked held: every closed task's acceptance check reproduces and fails against unfixed code, the battery exits 1 with 12 failures against base sources so it is strong rather than vacuous, the F8 install path runs end to end on a pristine export, a 643-token number differential and a 4000-document round-trip differential against Python json under ASan and UBSan found no real disagreement, 6000 generated patch pairs through every cJSONUtils_ entry point were clean, and F6's Low was re-scored and confirmed accurate.

Learnings: a contract worth writing in a comment is worth obeying in the very next line - the ownership rule this run violated was one it had just documented itself. When the Verify command cannot see a class of defect and the fingerprint says so, that class needs a check somewhere outside the gate, or it reaches CI instead.

Next: the final iteration fixes F9, re-invokes the gate as invocation 2, and declares on a PASS, carrying F6 and F10 as Lows. The one-transaction rule permits combining the gate-filed fix, its acceptance check, the re-invocation and the declaration when the budget forces it, and with one iteration left it does.

## iter 10/10 | b783c3f3-034143 | 2026-08-12 | F9 | converged

Task: Close F9, the single reason the iteration 9 gate rejected, then re-invoke the gate and declare. One transaction under the closing rule, permitted because this is the final iteration and the budget forces the combination.

Closed: F9 - free the refused replacement in cjson_replace_item_in_object_should_keep_the_documents_key - the test now holds the item in a local, asserts the refusal, and deletes it, matching the ownership pattern its sibling assertion already used.

Changed: tests/misc_tests.c (the leaking assertion), BACKLOG.md (F9 deleted, F11 filed, Converged line appended), .jeffy/evaluator/b783c3f3-034143-2.md (the gate's artifact).

Checkpoint: 6aa7e5acc5b5655a918c26924d0e4a36c59d0a41

Verification: Evaluator: PASS - invocation 2 re-ran the Verify command, the sanitizer gate and every closed task's acceptance check, hunted independently, and confirmed all three carried findings are accurately scored Low.

F9's acceptance check is met and was graded rather than assumed: the ctest suite built with -DCMAKE_C_FLAGS="-g -fsanitize=address" and matching linker flags exits 0 at 22/22 with no leak in any of the 22 targets, where before the fix it exited 8 with `14 - misc_tests (Failed)` and a 64-byte direct leak. The gate independently reintroduced the leak in a working-tree copy and confirmed that same sanitizer gate then exits 8, so the check can fail. Running the whole suite under the sanitizer rather than the one repaired test also establishes that no other instance of this class was introduced this run. The Verify command exits 0 at 22/22 and the battery exits 0.

The declaring iteration re-read the Oracle class and Environment fingerprint as required. The fingerprint names two things this command cannot reach: print_number_should_print_non_number, whose body is TEST_IGNORE'd, and tests/unity_setup.c, which compiles only under MSVC. No entry in this journal claims either ran. The fingerprint also discloses that neither mem-check leg runs under the Verify command, which is exactly the gap F9 slipped through; that gap is now a filed task, F11, rather than a disclosure alone.

The gate's independent evidence, none of which this run produced: a structural-invariant probe over both sort twins at sizes 0 to 40, the full prev chain, head-prev-is-tail, and detach, replace and insert at every position fails 239 times at the base commit and 5 times at HEAD, and those 5 are RFC 7386's inability to express null as a merge-patch value, identical at base. A 2674-token number differential against Python json shows 0 accept/reject and 0 value disagreements at HEAD against 254 at base. 170,036 fuzzed patch documents through ten cJSONUtils_ entry points under ASan and UBSan are clean, as are all 14 shipped fuzz inputs and exact-size non-NUL-terminated buffers. No inventory row is stale: git log -1 per implementing file returns the commits PLAN.md records.

Carried Lows, each accurately scored and confirmed by the gate: F6, no fuzz target reaches the cJSONUtils_ entry points, Low because that surface is covered by the RFC 6902 corpus, two unit-test binaries and four battery rows and the gate's own 170k-document campaign found nothing there. F10, the unowned-item precondition that no header states, Low because the envelope classifies caller-passed cJSON pointers as user-error, it reproduces identically at the base commit across five adopting entry points, and the remedy is one header sentence. F11, the Verify command has no memory-check leg, Low because CI still runs valgrind and sanitizer legs, so the gap delays a catch rather than shipping a defect.

Two gate observations are recorded in the artifact and deliberately not fixed here, because a fix after a PASS invalidates it: a stale comment above json_number_prefix_length in cJSON.c that belongs to parse_number, and a note that the 5 merge-patch mismatches are RFC semantics so a future probe does not re-file them. Both go to the run report and the next run's ledger.

Convergence conditions, each checked: the iteration 7 full fresh-evidence audit is on record and the only commits since it are the fixes for the tasks it and the gate filed plus state-file edits; the Surface inventory lists no unswept row, 24 of 24; no open High or Medium remains; the Verify command is green this iteration; the evaluator returned PASS at invocation 2 with its artifact committed by this checkpoint; and the Converged line is appended below with the checkpoint hash.

Learnings: gating one iteration before the last is what saved this run - invocation 1 rejected on a real defect, and had it been deferred to the declaration there would have been no budget to answer it. A rejection that names your own newest test is worth reproducing yourself before accepting, and worth accepting quickly once reproduced.

Next: nothing blocking. The next run starts from three carried Lows, F6, F10 and F11, plus the two gate observations above.
