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

## iter 1/10 | bb553b5a-022747 | 2026-09-02 | AUDIT | audit

Task: First audit. Fill the Operating envelope, the Surface inventory and the Verify command in PLAN.md, then audit the project breadth-first and seed BACKLOG.md.

Changed: PLAN.md (envelope surfaces, 13 inventory rows, Verify command / Oracle class / Environment fingerprint / summary pattern / Verify count, one Stated counts row), BACKLOG.md (3 Medium in Now, 3 Low in Later).

Checkpoint: b907726f619c351c7415db5b040040f7560c1fd4

Verification:
- Verify command established and green through the installed quiet-verify.sh: `verify: green (5s, oracle=doctest unit tests plus the external fastfloat/supplemental_test_files round-trip conformance corpus..., verify totals: 29 ctest cases passed across 2 configurations)`. Verify count 29 recorded from the wrapper's own measurement, not typed.
- check-claims.sh: `MATCH PLAN:excluded-test-targets: 10`, `claims: 1 checked, 0 mismatched, 0 errored, 0 skipped`.
- Artifact-producing channels enumerated by command, not recall. `ls Cargo.toml package.json MANIFEST.in pyproject.toml *.gemspec *.nuspec Dockerfile` finds none; the tree's channels are (a) CMake `install(DIRECTORY include/fast_float ...)` plus the two generated config files, (b) Bazel `cc_library(hdrs = glob(["include/fast_float/*.h"]))`, (c) `.github/workflows/on-release.yml`, which uploads only the single file `script/amalgamate.py` writes, and (d) `.github/workflows/pages.yml`, which deploys `folder: docs`. Each was checked against PLAN.md, BACKLOG.md, JOURNAL.md, JOURNAL-archive.md and .jeffy/: (a) and (b) ship only include/fast_float, (c) reads the fixed file list in amalgamate.py (AUTHORS, CONTRIBUTORS, the three LICENSE files, nine headers) and no other path, (d) deploys docs/ alone. No channel can reach the loop's state files, so nothing was filed here. No release or publish workflow archives the tree.
- Float differential against glibc strtod, 1166339 comparisons (466476 random strings over "0123456789.eE+-", 500000 well-formed decimals with exponents in [-400,400], 199863 strings with up to 40 integer and 40 fractional digits): zero differences in parsed value or in consumed length. Two systematic differences are convention, not defect, and were excluded by construction: fast_float rejects a leading '+' by default per C++17 20.19.3.(7.1), and glibc sets ERANGE on subnormal results where fast_float reports success with the same bits.
- Integer differential against an independently written reference, 3685775 comparisons: zero differences in status, value or consumed length. Includes every string of length 1..5 over "0123456789-" parsed as uint8_t, uint16_t, int8_t, int16_t and int (885775 comparisons), which covers the hand-rolled uint8_t and uint16_t SWAR fast paths in parse_int_string exhaustively at those lengths; 1800000 random decimal comparisons across six widths; and 1000000 comparisons over random strings in bases 2..36.
- C++23 fixed-width known-answer bit patterns all hold: float16 1/2/0.5/65504/min-normal/min-subnormal, bfloat16 1/2/0.5/3.140625, float32 1/0.1, float64 0.1; float16 "70000" reports result_out_of_range with an infinite value.
- FF-001 reproduced: with chars_format::hex, "0x1p3" returns ec == 0, ptr == first+1, value == 0; "1p3" returns 1. `grep -rn 'chars_format::hex' include/ tests/ benchmarks/ fuzz/` returns the enum declaration alone.
- FF-002, FF-003 and FF-005 acceptance checks were run against this unfixed tree and all three failed as filed (`MISSING benchmark`; MODULE.bazel 8.2.4 against CMakeLists 8.2.10; duplicate `a4.cpp`).

Scores. This audit swept 0 of 13 Surface inventory rows - a row needs an executed battery under .jeffy/probes/ and none exists yet - so every score below claims only the breadth-first probes recorded above and never the unexamined remainder. Correctness Medium (FF-001). Documentation Medium (FF-002). Dependency hygiene Medium (FF-003). Testing Low (FF-004, FF-006). Code quality Low (FF-005). Developer experience Low (same three lines). Architecture None, security None, error handling None - all three on probed surface only; the float and integer differentials and the error-contract probe found nothing, and the library allocates nothing, throws nothing and touches no environment, file or socket, derived by the envelope's absence command returning empty. Performance not scored: the Verify command does not grade it and no benchmark was run this iteration. Observability not applicable: a header-only parsing library has no logging, metric or trace surface, by the same absence command. UX and accessibility not scored: the only user-facing surface is the docs/ site, which sits in the unswept dev-scripts-docs row.

Learnings: The verify gate must run two build directories, because the default C++11 configuration never compiles fixedwidthtest or the constexpr arm of basictest; a single-configuration gate would leave the C++23 fixed-width float surface ungraded for the whole run. build/cxx23 is used rather than a sibling directory because .gitignore ignores build/* and an untracked build tree at the root would be swept into every checkpoint by git add -A.

Next: Start sweeping the Surface inventory. The queue puts the three open Medium tasks above the rows, so iteration 2 takes FF-001.

## iter 2/10 | bb553b5a-022747 | 2026-09-02 | SWEEP | done

Task: Sweep Surface inventory rows. The queue puts unswept rows above every open Medium, so this iteration built and ran known-answer batteries rather than starting FF-001.

Changed: .jeffy/probes/_lib/ (shared harness: check.h, run-battery.sh, mutate-battery.sh) and eight batteries - from-chars-float, from-chars-int, format-options, infnan-errors, ascii-lexing, integer-times-pow10, char-types, fixedwidth-floats - each with probe.cpp, run.sh, mutate.sh, paths, claims and README.md. PLAN.md: those eight Surface inventory rows flipped to swept. No product code was touched this iteration.

Checkpoint: a63f1af8b630d2362d8e4eb490a4b933b59b718d

Verification:
- Verify command green through the installed wrapper: `verify: green (4s, oracle=..., verify totals: 29 ctest cases passed across 2 configurations)`.
- check-claims.sh: `claims: 17 checked, 0 mismatched, 0 errored, 0 skipped` - the sixteen battery claims plus the PLAN.md Stated counts row.
- Every battery was observed failing before it was trusted, each under damage chosen to be silent rather than fatal: from-chars-float 10/32 (Clinger negative-exponent divide turned into a multiply), from-chars-int 4/43 (uint8_t SWAR magic product shifted one bit), format-options 5/47 (JSON dispatch bit forced off), infnan-errors 8/35 (parse_infnan requires four characters instead of three), ascii-lexing 4/21 (eight-digit SWAR multiplier perturbed), integer-times-pow10 8/23 (the shared Clinger divide), char-types 2/25 (width guards dropped from is_space and ch_to_digit), fixedwidth-floats 9/28 (binary16 given nine mantissa bits instead of ten). Each mutation leaves every parse succeeding and every value finite, so none of them is visible to a run-without-crashing probe.
- Two batteries certify by invariant rather than by sample: fixedwidth-floats round-trips every finite bit pattern of binary16 and of bfloat16 through a printed decimal and back, and from-chars-int compares every string of length 1 to 5 over "0123456789-" against an independently written reference for five target types.
- Documented parameters were driven at two or more values that must change the output, per the sweep rule: `base` at seven values plus four out-of-domain ones, `decimal_point` at two values each changing both spellings of the same number, `decimal_exponent` at three values straddling zero, and every chars_format flag as a flip with the opposite setting checked on the same input so a check cannot pass by rejecting everything.
- No new finding surfaced. FF-001 was already filed against chars_format::hex in iteration 1, and the format-options battery deliberately does not certify that bit; its README records why and the check joins the battery in the iteration that closes FF-001.

Learnings: A battery must be watched failing on damage that leaves the program working, not on damage that breaks it - two candidate mutations here reddened a single check each and were replaced, because a mutation that only one check can see says little about the other forty. Batteries live under .jeffy/probes/<row-slug>/ and compile against $JEFFY_FF_INCLUDE when set, which is what lets mutate.sh point the same probe at a damaged copy of include/ without touching the tree.

Next: Five rows remain unswept - eisel-lemire, slow-path, float-common-traits, packaging-install, dev-scripts-docs. They stay above the open Mediums in the queue, so iteration 3 continues sweeping.

## iter 3/10 | bb553b5a-022747 | 2026-09-02 | SWEEP | done

Task: Sweep the five remaining Surface inventory rows - eisel-lemire, slow-path, float-common-traits, packaging-install and dev-scripts-docs - which the queue still puts above every open Medium.

Changed: five new batteries under .jeffy/probes/ with probe or run script, mutate.sh, paths, claims and README.md; PLAN.md rows flipped and three operational rules added under Lessons. No product code was touched this iteration.

Checkpoint: 39db2ccc8c3546166fb9fc2737c455707a392033

Verification:
- Verify command green through the installed wrapper: `verify: green (4s, oracle=..., verify totals: 29 ctest cases passed across 2 configurations)`.
- check-claims.sh: `claims: 27 checked, 0 mismatched, 0 errored, 0 skipped`.
- float-common-traits, 36 checks: every binary_format constant is derived rather than compared against a copy of itself - infinite_power is read out of this machine's own infinity, minimum_exponent out of numeric_limits, the masks out of the digit count. leading_zeroes and countr_zero_32 are checked at every single-bit position plus 100000 samples each against the compiler builtins; full_multiplication against unsigned __int128 on edges and 200000 samples; to_float round-trips 200000 sampled bit patterns; max_digits_u64 and min_safe_u64 are recomputed for every base 2..36; ch_to_digit and is_space are checked over all 256 byte values against a reference and against the C locale, and no code unit from 256 to 70000 may be either. Mutation (binary64 given 51 mantissa bits): 4/36 red.
- eisel-lemire, 15 checks: the 128-bit powers-of-five table is verified entry by entry against exact big-integer arithmetic the probe performs itself. Every non-negative power must be exactly the truncated top 128 bits of 5^q; every negative power must lie within one unit in the last place of the exact normalised significand, stated as the bracket (t-1)*5^n <= 2^(127+k) < (t+1)*5^n so that multiplication and comparison suffice and no division is needed. compute_float is then required to agree with strtod wherever it resolves, across every exponent in the table with eight mantissas each, and the check also requires that a substantial number resolved so it cannot pass by resolving nothing. Mutation (one bit of one entry out of 651): 2/15 red.
- slow-path, 10 checks: bigint pow5 and pow10 compared against an independent big integer for every exponent 0..320, mul and add walked step by step until the fixed capacity refuses to grow, compare and hi64 checked as contracts. End to end, every power of five from 5^1 to 5^340 written out in full by long division inside the probe, parsed in four scalings, must round exactly as the C library does. Mutation (one entry of the small pow5 table): 2/10 red - and the end-to-end parses did not move under it, which the battery README records plainly rather than implying wider coverage than it has.
- packaging-install, 15 checks: a real cmake --install into a temporary prefix, then a separate project that finds the package with find_package and links FastFloat::fast_float, built and run; the installed tree checked to carry no loop state file and nothing but headers and package config; the amalgamation run as README.md instructs, compiled into a consumer, and required to give the same answers as the installed library; the --license option exercised at two values that change the output. Mutation (install narrowed to one header): 5/15 red.
- dev-scripts-docs, 14 checks: every complete C++ program in README.md extracted from its fenced block, compiled and run - several of them assert their own stated results and fail when the library disagrees. Version consistency checked across CMakeLists, the shipped header macros and every vX.Y.Z string in README.md. Every local asset docs/index.html references must exist, and the {{VERSION}} placeholder must not sit in a file extension the deploy workflow skips. Mutation (a worked example's stated value and a stale release tag): 4/14 red.
- Two rows deliberately leave a check out and say so in their README, because certifying present behaviour there would freeze an open finding: packaging-install does not compare MODULE.bazel's version to the project version (FF-003), and dev-scripts-docs does not run the documented ./build/benchmarks/benchmark path (FF-002). Both checks join their battery in the iteration that closes the finding.
- No new finding surfaced. The three Mediums filed in iteration 1 remain the ledger's top, and every one of them was independently re-confirmed by the batteries declining to certify around them.

Learnings: A battery covering non-header surface needs a whole-tree copy to mutate, not just include/, so packaging-install and dev-scripts-docs take JEFFY_FF_ROOT and mutate a git ls-files copy. Verifying a numeric table is worth doing exactly rather than by sampling: the powers-of-five check needed only multiplication and comparison once the claim was stated as a bracket instead of as a quotient, which removed the need for big-integer division entirely.

Next: The map is complete - 13 of 13 rows swept. The queue now moves to the open Mediums, so iteration 4 takes FF-001.

## iter 4/10 | bb553b5a-022747 | 2026-09-02 | FF-001 | done

Task: FF-001 (Medium, runtime, correctness) - chars_format::hex was declared in the public enum and read nowhere, so a caller who asked for hexadecimal silently received a decimal parse.

Changed: include/fast_float/parse_number.h (a rejection at both advanced entry points), include/fast_float/float_common.h (the enum member documents what it now does), README.md (the restriction paragraph states the rejection), tests/basictest.cpp (a new TEST_CASE), and the format-options battery, which now certifies the rejection instead of declining to certify the bit.

Checkpoint: a83cd8a9efd9be6130c4ade12a6f57c046746a68

Verification:
- Reproduction on the pre-fix tree, run first as the working rules require: `from_chars("0x1p3", +5, v, chars_format::hex)` returned `ec=0 consumed=1 value=0` and `"1p3"` returned `ec=0 consumed=1 value=1`.
- Acceptance, run as filed against both trees rather than reasoned about: tests/basictest.cpp compiled against the pre-fix headers extracted with `git archive HEAD include` reports `test cases: 1 | 0 passed | 1 failed`, `assertions: 21 | 2 passed | 19 failed`; the same file compiled against the fixed headers reports `1 passed | 0 failed` and `21 | 21 passed | 0 failed`. The check is therefore strong enough to fail.
- Verify command green through the installed wrapper: `verify: green (54s, oracle=..., verify totals: 29 ctest cases passed across 2 configurations)`.
- check-claims.sh: `claims: 27 checked, 0 mismatched, 0 errored, 0 skipped`.
- Battery ownership: the diff touches parse_number.h, float_common.h, README.md and tests/basictest.cpp. Ten of the thirteen batteries declare one of those paths and were all re-run through the installed run-probe.sh in this iteration, every one green: from-chars-float 32/32, from-chars-int 43/43, format-options 50/50, infnan-errors 35/35, integer-times-pow10 23/23, fixedwidth-floats 28/28, char-types 25/25, float-common-traits 36/36, packaging-install 15/15, dev-scripts-docs 14/14. Their rows are re-recorded at this iteration's checkpoint. ascii-lexing, eisel-lemire and slow-path declare no touched path and keep their earlier commit.
- The format-options battery gained three checks and its claims were re-measured in the same iteration: `format-options: 50/50 checks passed` and `format-options mutation: 5/50 checks failed`. The new checks are written as flips - the same inputs must still parse under general - so they cannot pass by rejecting everything.

Contract preserved. Before changing it I enumerated every caller of the bit: `grep -rn "chars_format::hex" include tests benchmarks fuzz` returns the enum declaration alone, and no composite value in the enum sets bit 3 - json, json_or_infnan, fortran and general are built from bits 0, 2, 4, 5 and 6 - so no documented format silently acquires the rejection. The change turns a silent wrong answer into `std::errc::invalid_argument` with `ptr == first` and the caller's value untouched, which is the same failure shape every other rejecting path in this library already uses. It is a behaviour change and is recorded here as one: code that passed chars_format::hex and relied on getting a decimal parse will now get an error. Hexadecimal integer parsing is unaffected, because that is selected by parse_options::base rather than by this bit, and the new test asserts base 16 still returns 22250738585072012 for "4f0cedc95a718c".

Learnings: An acceptance check that must fail on the pre-fix tree is cheapest to run by extracting the old headers with `git archive HEAD include` into a scratch directory and compiling the same test file against each include path in turn - no checkout of the working tree, so the fix being proved is never at risk.

Next: FF-002, the benchmark path README.md and the published site both tell users to run.

## iter 5/10 | bb553b5a-022747 | 2026-09-02 | FF-002 | done

Task: FF-002 (Medium, docs, documentation) - README.md and docs/index.html both told the reader to run ./build/benchmarks/benchmark, a binary benchmarks/CMakeLists.txt never produces.

Changed: README.md and docs/index.html (both paths now name realbenchmark), and the dev-scripts-docs battery, which now certifies the rule instead of declining to certify it.

Checkpoint: 1b26eb2511d536331eb6d409e6c9e2b7ce39713f

Verification:
- The finding was reproduced end to end rather than by reading the CMake file, because the task is about a command a user runs. `cmake -B build/bench -D FASTFLOAT_BENCHMARKS=ON` and `cmake --build build/bench` both succeed and produce exactly realbenchmark, bench_ip and bench_uint16; `ls build/bench/benchmarks/benchmark` reports No such file or directory. `./build/bench/benchmarks/realbenchmark` then runs to completion with exit 0 and prints the throughput table the documentation is showing. A separate build directory was used so the verify gate's own build trees were left alone; the documented commands are otherwise run as written.
- Acceptance, as filed, run against both trees: on the unfixed tree the check printed `MISSING benchmark`; after the fix it prints nothing, and the only benchmark path either document now names is realbenchmark.
- Verify command green through the installed wrapper: `verify: green (4s, oracle=..., verify totals: 29 ctest cases passed across 2 configurations)`.
- check-claims.sh: `claims: 27 checked, 0 mismatched, 0 errored, 0 skipped`.
- Battery ownership: the diff touches README.md and docs/index.html. dev-scripts-docs is the only battery declaring either path; it was re-run and is green, and its row is re-recorded at this iteration's checkpoint. It gained a check requiring every executable path the documentation names to be a declared target, written so it also fails if the documentation stops naming any such path, and its mutation gained a third drift - an executable path naming a target that does not exist - so the new check has itself been observed failing. Claims re-measured in the same iteration: `dev-scripts-docs: 15/15 checks passed` and `dev-scripts-docs mutation: 5/15 checks failed`.
- Recorded as an observation, not filed: the sample output README.md prints under that command lists netlib, doubleconversion, strtod and abseil rows, and realbenchmark on this host prints only the fastfloat rows, because the competitor libraries are not installed here. That is a property of the machine the sample was taken on rather than of the documented command, so it is not a finding; a reader on a machine without those libraries sees fewer rows and the same fastfloat measurement.

The fix renames the documented path rather than the CMake target. Renaming the target would be the larger change and would contradict the README's own Benchmarking section, which already says realbenchmark, and any script a user has written against the existing name.

Learnings: A documentation finding about a command is cheapest to prove by running the command, and configuring a separate build directory under build/ keeps that from disturbing the verify gate's trees, since .gitignore already ignores everything below build/.

Next: FF-003, the stale MODULE.bazel version and the release script that never rewrites it.

## iter 6/10 | bb553b5a-022747 | 2026-09-02 | FF-003 | done

Task: FF-003 (Medium, build-ci, dependency hygiene) - MODULE.bazel declared version 8.2.4 against a project at 8.2.10, and script/release.py rewrote CMakeLists.txt, float_common.h and README.md but never MODULE.bazel, so every release left it further behind.

Changed: MODULE.bazel (version brought to the project version), script/release.py (a fourth rewrite block), and the packaging-install and dev-scripts-docs batteries, which now certify both halves of the finding instead of declining to.

Checkpoint: fd25837b6766d3b71f46e8651264943c7c29e08f

Verification:
- Reproduction, run rather than read: a scratch git repository was built from the tracked tree, tagged v8.2.10 and given itself as a remote so release.py's `git remote update` succeeds offline. `python3 script/release.py 8.2.11` exited 0 and left CMakeLists.txt at 8.2.11, FASTFLOAT_VERSION_PATCH at 11 and three v8.2.11 strings in README.md, while MODULE.bazel still said 8.2.4. That is the defect in one command.
- Acceptance, both halves as filed. First: `test "$(sed -n 's/.*version = "\([0-9.]*\)".*/\1/p' MODULE.bazel | head -1)" = "$(sed -n 's/.*project(fast_float VERSION \([0-9.]*\).*/\1/p' CMakeLists.txt)"` printed DIFFERS (8.2.4 against 8.2.10) before the fix and EQUAL after. Second: the same scratch run after the fix leaves all four files at 8.2.11.
- The new rewrite pattern is anchored to the start of a line on purpose, and that was checked rather than asserted: MODULE.bazel also carries `bazel_dep(name = "doctest", version = "2.4.11", ...)` and `bazel_dep(name = "rules_cc", version = "0.2.17")`, and after the scratch release run both still read 2.4.11 and 0.2.17. An unanchored pattern would have rewritten the doctest dependency to the fast_float version.
- Verify command green through the installed wrapper: `verify: green (5s, oracle=..., verify totals: 29 ctest cases passed across 2 configurations)`.
- check-claims.sh: `claims: 27 checked, 0 mismatched, 0 errored, 0 skipped`.
- Battery ownership: the diff touches MODULE.bazel and script/release.py. packaging-install declares MODULE.bazel and dev-scripts-docs declares script/*.py; no other battery declares either, and both were re-run and are green with their rows re-recorded at this iteration's checkpoint. packaging-install gained the version-equality check its README had been holding open for this task. dev-scripts-docs gained three checks that run release.py for real against a scratch repository, because what a script says it rewrites and what it does rewrite are different claims: every file carrying the project version must move by one patch release and no dependency version may move at all. Its mutation gained a fourth drift, a release script that silently stops rewriting one of those files, so the new checks have themselves been observed failing. Claims re-measured in the same iteration: `packaging-install: 16/16 checks passed` with `5/16` under damage, `dev-scripts-docs: 18/18 checks passed` with `6/18`.

Learnings: A release script that talks to git can be exercised offline by building a scratch repository from the tracked tree, tagging it at the current version and adding itself as its own remote, which makes `git remote update` succeed with no network and no upstream.

Next: three Lows remain - FF-004, FF-005, FF-006. The ledger is at the severity floor, so the next iteration also opens the question of when to spend the evaluator gate.

## iter 7/10 | bb553b5a-022747 | 2026-09-02 | AUDIT | audit

Task: The closing full audit. The map is swept and the ledger is at the severity floor, so this iteration rescores every applicable dimension with fresh evidence rather than starting a task that would not change the declaration.

Changed: JOURNAL.md only. This iteration changed no file other than the state files, no BACKLOG.md item changed state, and no Surface inventory row changed state; that is recorded here as the stall check requires. An AUDIT that files nothing is one of the ceremony entries the stall rule exempts, and it is the first of this run's closing sequence rather than a repeat of one.

Checkpoint: 79a593a0214840ec73745a91f2ab07d3168f6420

Verification:
- Staleness, derived rather than trusted: for every one of the 13 swept rows, `git log --oneline <recorded commit>..HEAD -- <the battery's declared paths>` returns no commits. No row is stale, so the map certifies the tree as it stands.
- All 13 batteries re-run fresh through the installed run-probe.sh, every one green: ascii-lexing 21/21, char-types 25/25, dev-scripts-docs 18/18, eisel-lemire 15/15, fixedwidth-floats 28/28, float-common-traits 36/36, format-options 50/50, from-chars-float 32/32, from-chars-int 43/43, infnan-errors 35/35, integer-times-pow10 23/23, packaging-install 16/16, slow-path 10/10.
- Verify command green through the installed wrapper: `verify: green (4s, oracle=..., verify totals: 29 ctest cases passed across 2 configurations)`. The Oracle class and Environment fingerprint were re-read, and the fingerprint's own figure re-derived: the excluded-target command still returns 10, and check-claims reports `MATCH PLAN:excluded-test-targets: 10`, `claims: 27 checked, 0 mismatched, 0 errored, 0 skipped`. Verify count 29 equals the wrapper's own last green measurement recorded under .jeffy/metrics/.
- Security, fresh evidence on the surface the Operating envelope classifies adversarial: a probe under AddressSanitizer and UndefinedBehaviorSanitizer drove roughly 4.4 million parses over exact-size heap buffers - every byte value, all 512 combinations of the low format bits including the bit the enum reserves and never names, bases 0 through 39, arbitrary decimal-point characters, char and char16_t widths, and number-like shapes that reach deeper than random bytes. Clean. The harness was itself proven to fire first: handing from_chars a range one byte past its allocation produces `ERROR: AddressSanitizer: heap-buffer-overflow`, so a silent clean run means something.
- Two documented promises checked rather than believed. README.md states the implementation does not throw and does not allocate: a global operator new detector armed only around the parse loop reports no allocation across 22000 inputs including 800-digit mantissas that force the truncation and big-integer paths, and the detector was proven to fire on a deliberate allocation; the headers also compile under -fno-exceptions.
- Concurrency, because this library lives inside multithreaded parsers: 8 threads x 20 rounds x 4000 inputs under ThreadSanitizer produced no warning and no disagreement with the single-threaded answers. The one piece of shared state in the parse path is the function-local static volatile float in rounds_to_nearest().
- Testing, per the Method's rule that a suite only ever run whole hides order dependence: one case run in isolation passes, and the whole basictest binary re-run with `--order-by=rand --rand-seed=20260907` reports `assertions: 8079 | 8079 passed | 0 failed`.
- The three carried Lows were re-verified as still real and re-scored: FF-004, the fuzz harness's four-way switch still returns chars_format::fixed from two of its cases; FF-005, `grep -o 'a[0-9]*\.cpp' ... | uniq -d` still prints a4.cpp; FF-006, tests/CMakeLists.txt still declares doctest with no GIT_TAG and supplemental_test_files at origin/main. All three are class test or build-ci and name nothing a user of the shipped product meets, so Low is the ceiling the rubric sets, not a downgrade.

Scores, over the whole map - 13 of 13 rows swept, none stale - so these claim the project and not a sampled part of it. Correctness None. Security None. Error handling None. Architecture None. Performance None, with the caveat that the Verify command does not grade it and the evidence is the benchmark run recorded in iteration 5 rather than a gate. Documentation None. UX and accessibility None, over the one user-facing surface there is, the published docs site. Testing Low (FF-004, FF-006). Dependency hygiene Low (FF-006). Code quality Low (FF-005). Developer experience Low (FF-004, FF-005, FF-006). Observability not applicable: a header-only parsing library has no logging, metric or trace surface, derived by the envelope's absence command returning empty.

Zero High and zero Medium in-envelope. Closeout has begun: this run will file no further findings on swept surface, replenish nothing, and run no further audit. It finishes by carrying the three Lows to the declaration and spending the remaining budget on the convergence sequence.

Learnings: A sanitizer sweep proves nothing until the harness has been watched detecting the thing it exists to detect; the same rule that governs a probe battery governs an audit's own instruments, and both the ASan harness and the allocation detector here were verified against a deliberate fault before their clean runs were believed.

Next: the evaluator gate, invocation 1, at iteration 8, leaving 9 and 10 for whatever a REJECT files.

## iter 8/10 | bb553b5a-022747 | 2026-09-02 | EVALUATOR | converged

Task: The evaluator gate, invocation 1 of this run, and the declaration it cleared.

Changed: PLAN.md (one prose clause in the format-options row stopped naming a closed finding ID, so the gate could not read it as a dangling reference), BACKLOG.md (the gate's five observations filed as four Low lines, and the Converged line), JOURNAL.md, and the gate's own artifact under .jeffy/evaluator/.

Checkpoint: 0bc29cdd5e4043f5eb7fa7e267f3f05c19011972

Verification:
- Standing claims brought current before the invocation, not after: no Surface inventory row is stale, re-derived by running `git log --oneline <recorded commit>..HEAD -- <the battery's declared paths>` for all 13 rows and getting nothing; BACKLOG.md holds no Declined entry and no Settled class, so there was no Derivation and no enumeration to re-run; check-claims reports `claims: 27 checked, 0 mismatched, 0 errored, 0 skipped`; the Oracle class and Environment fingerprint were re-read and the fingerprint's own figure re-derived at 10; Verify count 29 equals the wrapper's last green measurement. PLAN.md named FF-001 in one prose clause describing why the format-options battery certifies the hex bit; FF-001 is closed and no ledger line holds it, so the clause was rewritten to describe the behaviour instead of citing the ticket. A REJECT spent on a claim this run had already outdated is an invocation the declaration would then lack.
- Verify command green through the installed wrapper this iteration: `verify: green (5s, oracle=..., verify totals: 29 ctest cases passed across 2 configurations)`.
- Evaluator: PASS - all three closed Mediums reproduced as failing at the base commit and passing at HEAD, every filed acceptance re-executed as written, no regression found in the code the fixes touched, and the three open Lows re-scored as accurately Low.
- The gate's own words on each: FF-001, basictest against the pre-fix headers fails `chars_format.hex_is_rejected` at `21 | 2 passed | 19 failed` and passes at HEAD at `21 | 21 passed`, and it independently re-ran the format-options battery against pre-fix headers to get 48/50 with the two hex checks red. FF-002, the acceptance prints `MISSING benchmark` at the base commit and nothing at HEAD. FF-003, the version-equality test fails at base and succeeds at HEAD, and its own offline scratch release run moved all four files while leaving doctest at 2.4.11 and rules_cc at 0.2.17.
- The gate recorded five observations, none of them a REJECT reason, and none was fixed here: a fix after a PASS invalidates that PASS and spends an invocation the declaration needs. Four are filed as FF-007 through FF-010 for the next run; the fifth, that the new MODULE.bazel regex would catch a dependency version if that file were reformatted multi-line, is hypothetical and unreproduced, so it is named in the run report and not filed - the evidence rule admits a finding only when something can be pointed at.
- FF-007 is the one this run caused: the iteration-3 checkpoint committed five script/__pycache__ bytecode files that the dev-scripts-docs battery's py_compile step produced. Verified independently of the gate with `git ls-files script/__pycache__/` and `git log --diff-filter=A`. Nothing installed, amalgamated or globbed by BUILD.bazel reaches script/, so it is clutter a maintainer meets rather than anything a user of the shipped product does.

Carried Lows, each open with its severity on its own line so the hook can read it:
- FF-004 (Low, test, testing): the OSS-Fuzz harness's four-way format switch returns chars_format::fixed from two of its cases, so it explores three formats where it was written to explore four.
- FF-005 (Low, build-ci, code quality): tests/bloat_analysis/CMakeLists.txt lists a4.cpp twice; CMake deduplicates it, so the build is unaffected.
- FF-006 (Low, test, dependency hygiene): the test build fetches doctest with no GIT_TAG and supplemental_test_files at origin/main, so a green run is not reproducible from the tree alone.
- FF-007 (Low, build-ci, code quality): five script/__pycache__ bytecode files committed by this run's own battery step.
- FF-008 (Low, dev-tooling, documentation): the float-common-traits battery has no README.md.
- FF-009 (Low, build-ci, dependency hygiene): release.py moves MODULE.bazel's version but not its compatibility_level.
- FF-010 (Low, docs, documentation): README.md's sample benchmark output lists competitor rows a default build does not print.

Closing conditions, each checked rather than assumed: the full fresh-evidence audit at iteration 7 scored zero High and zero Medium in-envelope; the Surface inventory lists no unswept row and no stale one; Now, Next and Later hold no open High and no open Medium; the only commits between that audit and this declaration are its own bookkeeping and this iteration's state-file edits; the Verify command is green this iteration; the evaluator returned PASS with its artifact at .jeffy/evaluator/bb553b5a-022747-1.md, committed by this iteration's checkpoint and carrying no machine-absolute path.

Learnings: Bring the standing claims current before the gate rather than after, and read the state files the way the gate will: a single prose clause in PLAN.md that cited a closed finding by ID was enough to look like a dangling reference, and rewriting it cost one edit before the invocation instead of an invocation after it.

Next: the run converges here. The seven carried Lows are the next run's first work, and FF-007 is the one this run should clean up first because this run created it.
