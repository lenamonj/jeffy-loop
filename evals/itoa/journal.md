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

## iter 1/10 | e09ed927-121713 | 2026-08-25 | AUDIT | audit

Task: First audit of the itoa crate. Fill the Operating envelope, the Surface inventory, and the Verify command block in PLAN.md; enumerate the artifact-producing channels by command; probe every inventory row breadth-first; file findings.

Changed: PLAN.md (envelope surfaces, 14 inventory rows, Command/Oracle class/Environment fingerprint/Verify summary pattern, two Lessons), BACKLOG.md (IT-1, IT-2, IT-3 under Next), .gitignore (bootstrap: .claude/jeffy-loop.local.md), JOURNAL.md.

Checkpoint: 1ef2a367af8b0234d960b8e3b627c57c9fb7603d. Stall check: not a stall - this iteration added three BACKLOG.md task lines and filled the Surface inventory, so the ledger signal changed.

Verification:
- Verify command through the installed quiet-verify.sh: green (0s, oracle=unit tests - 13 fixed known-answer cases..., verify totals: 13 passed, 0 failed).
- Artifact channels enumerated by command, not recall. Packaging manifests present: Cargo.toml only (`ls package.json MANIFEST.in pyproject.toml setup.py *.gemspec *.nuspec Dockerfile` reports every one missing and exits 2; `.github/workflows/` holds ci.yml alone, which archives only Cargo.lock via upload-artifact). The one channel is crates.io publish, and it FAILS: `cargo package --list --allow-dirty` lists BACKLOG.md, JOURNAL.md and PLAN.md. Filed as IT-2 (Medium) per the mandatory channel check.
- Correctness probe, breadth-first over every row: a differential harness built with `rustc --edition 2021 -O --extern itoa=target/release/libitoa.rlib` compared `Buffer::format` against `core`'s `Display` for 49,149,051 values - exhaustive over all u8/i8/u16/i16, exhaustive over 0..2_000_000 u32 and -1_000_000..1_000_000 i32, every power of ten plus/minus 2 at every width, every 1<<k and its neighbours for k in 0..128, 2000-wide neighbourhoods of 1e16, 1e32 and u128::MAX, all 24 type boundaries, and 3,000,000 xorshift-seeded rounds covering all twelve types including shifted u128/i128 magnitudes. Zero mismatches and zero MAX_STR_LEN overruns. Re-run against the debug rlib with `-C debug-assertions=on` so `divmod100`'s `debug_assert!(value < 10_000)` was live: same 49,149,051 checks, zero failures, no assertion fired.
- The probe was observed failing before it was trusted: seeding `const SIG: u32 = (1 << EXP) / 100 + 1` -> `/ 100` in a scratch copy reddened 2,438,048 of those checks and exited 1.
- The two numeric cores were verified analytically as well as differentially. `divmod100`: SIG = 5243, and over all 10,000 in-domain values `((v*5243)>>19, v-((v*5243)>>19)*100)` equals `(v//100, v%100)` with no mismatch, max intermediate 52,424,757 well inside u32. `div_rem_1e16`: M_HIGH equals `ceil(2**179 / 1e16)`, the Granlund-Montgomery error term `M*D - 2**179` is 630,438,908,198,912, and the sufficient condition `err * (2**128 - 1) < 2**179` holds, so `floor(n*M/2**179) == floor(n/1e16)` for every n in the u128 domain; 200,000 random plus 10 boundary values agree.
- clippy as CI runs it: `cargo clippy --tests --benches -- -Dclippy::all -Dclippy::pedantic` exit 0.
- `cargo build --tests --features no-panic --release` exit 0 on stable, so the optional no-panic path compiles here even though CI gates it on nightly only.
- `cargo build --target thumbv6m-none-eabi` exit 0, which build-checks the `target_pointer_width = "32"` impls. The 16-bit arm is unreachable on this host; recorded in the Environment fingerprint.
- `cargo miri test` refused: the miri component is unavailable for the stable toolchain, so no UB oracle ran on this host. Recorded in the Environment fingerprint and never claimed green.
- Test-coverage hole reproduced rather than asserted: a scratch copy with `impl_Integer_size!(usize as u64 ...)` changed to `usize as u32` formats `usize::MAX` as "4294967295" and the whole suite stays green (0/11/2 passed, 0 failed). Filed as IT-1 (Medium).
- Documentation links resolve: zmij 200, itoa-benchmark 200, the benchmark png 200, docs.rs 200 (crates.io returns 403 to curl, which is its standard bot response and not a dead link). The `[libcore]` claim was checked against the linked source itself - rust-lang/rust 1.92.0 library/core/src/fmt/num.rs at the cited range contains the `_fmt_inner` loop that `impl_Unsigned` mirrors - so the provenance sentence is accurate, not misleading.
- Dependency surface: `cargo tree --edges normal` shows zero runtime dependencies; the only dev-dependency is criterion 0.8.2 and the only optional dependency is no-panic.

Scores (0 of 14 Surface inventory rows swept - every row is still `- [ ]`, so these scores come from this audit's breadth-first shallow probe and from the differential harness above, and they claim nothing about the unswept remainder):
- correctness: None - 49,149,051 differential checks in both profiles, plus the analytic verification of both magic-constant derivations.
- security: None found, with a stated gap - no UB oracle is available on this host, and IT-3 records an unsafe invariant that nothing in the code enforces.
- testing: Medium - IT-1.
- dependency hygiene: Medium - IT-2 (the crate artifact ships files that are not the crate).
- architecture: None. code quality: None (clippy pedantic clean). documentation: None. performance: None. developer experience: None.
- error handling: not applicable - the crate exposes no fallible operation; the two `.expect` arms are proven unreachable by the `size_of::<Self>() > 1` short circuit and the debug-assertions run exercised every u8 value without firing.
- observability: not applicable - a no_std formatting primitive with no I/O.
- UX and accessibility: not applicable - no user-facing surface.

Learnings: cargo and rustc are absent from this agent shell's PATH and must be prefixed with `PATH="$HOME/.cargo/bin:$PATH"`; both Lessons lines in PLAN.md now record this and the probe-linking recipe. `cargo test` builds exactly two executables here, so benches, the fuzz workspace, the no-panic items and the non-64-bit pointer-width impls are all outside the gate - the Environment fingerprint names them so no later entry claims them green.

Next: no open High, so the queue - open High, then unswept or stale Surface inventory rows, then open Medium, then open Low - puts the fourteen unswept rows ahead of IT-1, IT-2 and IT-3. Iteration 2 is therefore a sweep, batching every row it can properly evidence, starting with the numeric rows the differential harness already covers (unsigned-small, unsigned-128, signed, pointer-sized, digit-tables, mulhi, buffer-api, integer-trait) rewritten as a kept battery under .jeffy/probes/ with a paths file and its discriminating mutation recorded. IT-1, IT-2 and IT-3 follow once the map is clear.

## iter 2/10 | e09ed927-121713 | 2026-08-25 | SWEEP | done

Task: Sweep Surface inventory rows. With no open High, unswept rows outrank the three open Mediums, so this iteration built kept batteries under .jeffy/probes/ and swept the eight code rows: buffer-api, integer-trait, unsigned-small, unsigned-128, signed, pointer-sized, mulhi, digit-tables.

Changed: .jeffy/probes/ (shared format_common.rs oracle, build-and-run.sh, discriminate.sh, and eight battery directories each with probe source, paths, run.sh and README.md), PLAN.md (eight rows flipped to swept; Environment fingerprint corrected now that nightly and miri are installed), JOURNAL.md. No project source changed.

Checkpoint: a38903ef51a7f330a8dfc2b0948653ff9f78c0a9. Stall check: not a stall - eight Surface inventory rows changed state from unswept to swept.

Verification:
- Verify command through the installed quiet-verify.sh: green (1s, verify totals: 13 passed, 0 failed).
- Every battery was executed through the installed run-probe.sh under its ceilings, in both the release and the debug profile where debug-assertions add signal. Green totals, each figure taken from the battery's own tally line: unsigned-small 12,065,964 checks; signed 12,266,579; pointer-sized 6,400,299; unsigned-128 2,024,696; mulhi 2,032,788; buffer-api 600,017; digit-tables 110; integer-trait 44. Zero failures anywhere.
- No battery was trusted before it was watched failing. Each README records a seeded defect and the count it reddens, re-runnable with `bash .jeffy/probes/discriminate.sh <battery> '<sed>'`, which copies the tree to scratch, refuses a mutation that no longer matches the source, and fails if the battery survives it. Observed this iteration: unsigned-small 620,131 reddened by the `divmod100` reciprocal off-by-one; pointer-sized 2,426,336 by wiring usize to u32; mulhi 165,292 by corrupting the carry shift in the 128x128 multiply; signed 27,221 by suppressing the sign for -1; buffer-api 1,538 by leaving a stale byte in the u128 zero fast path; integer-trait 17 of 44 by widening every signed constant; digit-tables 2 by corrupting one pair in the lookup table; unsigned-128 aborts at `format(100000000000000000)` when the Granlund-Montgomery multiplier is decremented, and segfaults when SH_POST moves 51 to 50.
- The oracles are independent implementations, not restatements of the crate. The format batteries compare against `core`'s own `Display`; mulhi compares against a 32-bit-limb schoolbook reference written for this battery, a different decomposition from the 64-bit-limb algorithm under test; integer-trait checks each constant against a hand-written expected value and against what `Display` needs, never against the `ilog10` expression that produced it; digit-tables re-derives EXP and SIG from the source text and checks the reciprocal identity exhaustively over all 10,000 values of its documented domain.
- Documented-parameter rule: the crate documents no tunable parameters - `Buffer::format` takes only the value, and the sweeps drive each type across its full range, both signs, all reachable decimal lengths, and both boundary extremes, with a closing invariant in unsigned-small and unsigned-128 asserting that every decimal length was in fact reached rather than merely not contradicted.
- A UB oracle now exists on this host and it is green. Nightly with the miri component was installed during this iteration, and `MIRIFLAGS=-Zmiri-strict-provenance cargo +nightly miri test` passes 11 tests and 2 doctests with no Undefined Behavior reported. That is the crate's own narrow suite under miri, not the batteries, and the Environment fingerprint in PLAN.md was corrected in the same iteration because it previously asserted the component was unavailable - a claim this iteration falsified.
- One instrument finding, fixed inside the iteration rather than filed: the first signed battery generated decade boundaries with `while p <= i128::MAX { p *= 10 }`, which never terminates for i128 because every i128 satisfies the condition once the multiply wraps. It hung past the 10-minute run-probe ceiling. Rewritten to drive an exponent through `checked_pow`, and the same overflow hazard was removed from pointer-sized's negation. The batteries under .jeffy/probes/ are instruments, so their defects are instrument findings and not project findings.

Learnings: a probe's own loop bounds are part of the instrument and get the same scrutiny as the code under test - `while p <= T::MAX { p *= 10 }` is an infinite loop for the widest type it sweeps, and it cost this iteration a ten-minute ceiling kill. Recorded under Lessons in PLAN.md. Separately, a discriminating mutation that the compiler rejects is a weaker signal than one that compiles and misbehaves; both buffer-api and integer-trait needed a second mutation to get a genuine runtime detection, and the READMEs record which one is load-bearing.

Next: six rows remain unswept - build-configs, test-suite, packaging, ci-workflow, docs, bench-fuzz. Iteration 3 sweeps them. The packaging row cannot flip until IT-2 is fixed, because its battery asserts the published artifact carries no loop state and that assertion fails today; that is the row's own discriminating evidence.

## iter 3/10 | e09ed927-121713 | 2026-08-25 | SWEEP | done

Task: Sweep the six remaining Surface inventory rows: build-configs, test-suite, packaging, ci-workflow, docs, bench-fuzz. Five flipped; packaging did not, and could not.

Changed: .jeffy/probes/ (shlib.sh plus six new batteries with paths, runner and README), PLAN.md (five rows flipped to swept), BACKLOG.md (IT-1 restated on measured evidence), JOURNAL.md. No project source changed.

Checkpoint: 72af2e1b172dc7adff00e2b2088c1c38c477fe03. Stall check: not a stall - five Surface inventory rows changed state from unswept to swept and IT-1's task line was edited.

Verification:
- Verify command through the installed quiet-verify.sh: green (0s, verify totals: 13 passed, 0 failed).
- build-configs: 8 checks, 0 failures. Every configuration the crate claims is built, not assumed - default, --no-default-features, no-panic in release, and thumbv6m-none-eabi, which compiles only if #![no_std] holds and the 32-bit pointer-width arm is valid; plus clippy at -Dclippy::all -Dclippy::pedantic. The one documented build parameter is driven at both values with the requirement that the values differ in effect: no-panic on puts the optional dependency in cargo tree, off keeps it out. Discriminating: replacing #![no_std] reddens it.
- ci-workflow: 28 checks, 0 failures. All twelve gates the crate needs are present in the workflow; the miri job does set -Zmiri-strict-provenance; the msrv job pins and names the 1.68 that Cargo.toml declares; the matrix varies across four toolchains; the token is contents: read. Eight CI steps were then executed here and all exited 0. Discriminating: bumping rust-version without touching the workflow reddens the consistency check.
- docs: 28 checks, 0 failures. html_root_url matches the manifest version, the README example and the crate-doc example are the same program, both libcore provenance links are pinned to 1.92.0 rather than a branch, doctests pass, rustdoc builds under -Dwarnings, and all 17 outbound links resolve. Discriminating: bumping the version without updating html_root_url reddens it.
- bench-fuzz: 8 checks, 0 failures. The benchmark compiles; the fuzz target compiles and then actually ran 200,000 inputs under the sanitizer, clean. Content beyond compilation: all twelve integer types are enumerated in both the Arbitrary enum and the match arms, src/lib.rs still declares those twelve, and the fuzz assertion is a value round-trip rather than a liveness check. Discriminating: removing one enum variant reddens the twelve-type check.
- test-suite: 2 checks, 0 failures, and it is the finding of this iteration. It seeds ten realistic single-token defects, each confirmed to change real output, and asks cargo test about each. The suite catches 5 of 10. It misses the divmod100 reciprocal off-by-one, a sign suppressed for -1, usize wired to u32, a decremented Granlund-Montgomery multiplier, and a corrupted pair in the decimal lookup table. The claim is written as an equality, and running it with ITOA_EXPECTED_CAUGHT=6 reddens it, so the assertion is not vacuous.
- I expected 7 of 10 and wrote that number into the battery before measuring; the battery returned 5 and I checked its most surprising result by hand rather than adjusting the expectation. `cargo test` on a scratch tree carrying the divmod100 mutation exits 0 with 11 passed and 2 doctests passed. The reason is that the mutated reciprocal is wrong only for exact multiples of 100, and no four-digit chunk of any of the eleven test values is one. The measurement stands and my estimate was wrong.
- packaging: 14 checks, 4 failures, red by design. PLAN.md, BACKLOG.md, JOURNAL.md and .jeffy/ all reach the published crate artifact, which is IT-2 reproduced by command. A red battery certifies nothing, so the packaging row stays unswept and will flip when IT-2 lands. The same run confirms the other half of the claim: the crate's own files are all present and exclude = ["*.png"] still keeps the two benchmark images out.
- IT-1 was restated on this evidence. Its acceptance check is now the test-suite battery reporting 10 of 10 with ITOA_EXPECTED_CAUGHT=10, with the pre-fix tree reporting 5 - a check the broken state demonstrably fails, which is what the Method requires of an acceptance check.
- Battery ownership: this iteration's diff touches no path declared by any battery's paths file except .jeffy/probes/ itself, so no battery needed re-running on account of a source change; every battery named above was nonetheless executed in this iteration.

Learnings: an estimate written into an instrument before the instrument runs is not evidence, and when the two disagree the instrument gets checked by hand and the estimate gets discarded - here that turned a guessed 7 into a measured 5 and produced the sharper form of IT-1. Recorded under Lessons in PLAN.md.

Next: thirteen of fourteen rows are swept and the map is otherwise clear, so the queue falls through to the three open Mediums. IT-2 is first: it is the smallest, and fixing it flips the fourteenth row, which is the last thing standing between this run and a complete map. Then IT-1, then IT-3.

## iter 4/10 | e09ed927-121713 | 2026-08-25 | IT-2 | done

Task: IT-2 (Medium, build-ci, dependency hygiene) - the published crate artifact shipped the loop's own state files. This was also the only thing standing between the run and a complete map, because the packaging row could not be swept while its battery was red.

Changed: Cargo.toml (five entries added to the exclude key), BACKLOG.md (IT-2 deleted), .jeffy/probes/packaging/README.md (standing claim re-measured after the fix), PLAN.md (packaging row swept; build-configs and docs rows re-recorded at this checkpoint because their paths files name Cargo.toml), JOURNAL.md.

Checkpoint: 988e9e760dd15c9beaa1c09cea62fef8fc0121fe. Stall check: not a stall - Cargo.toml changed, IT-2 was deleted from the ledger, and the packaging row flipped to swept.

Verification:
- Acceptance check run against the unfixed tree first, as the Method requires of a check that must be able to fail: `cargo package --list --allow-dirty | grep -E '^(PLAN|BACKLOG|JOURNAL|\.jeffy)'` matched 62 paths and exited 0. On the fixed tree the same command produces no output and exits 1.
- The artifact went from 58 paths to 14. The 44 removed are PLAN.md, BACKLOG.md, JOURNAL.md and the 41 files under .jeffy/, which is this loop's probe suite and metrics.
- Contract preserved: the fix is additive to an existing `exclude` key and touches nothing else. The packaging battery checks both directions, so the same run that proves the loop state is gone proves the crate is still whole - Cargo.toml, both sources, README.md, both licences, tests/test.rs and benches/bench.rs are all still in the artifact, and `exclude = ["*.png"]` still keeps the two benchmark images out.
- Battery ownership: the diff touches Cargo.toml, which is named in the paths files of packaging, build-configs and docs. All three were run in this iteration through the installed run-probe.sh: packaging 14 checks 0 failures (14 paths in the artifact), build-configs 8 checks 0 failures, docs 28 checks 0 failures. The build-configs and docs rows are re-recorded at this iteration's checkpoint hash in the bookkeeping edit, because a row certifies the code as of the commit it names and Cargo.toml moved.
- The packaging battery's README recorded "14 checks, 4 failures, red by design" as its standing claim; that claim is now false, so it was re-measured in the same iteration rather than left to rot. Its discriminating state changed with it: removing any one of the new exclude entries reddens the battery, verified by running `bash .jeffy/probes/discriminate.sh packaging 's|^    "/PLAN.md",$||' Cargo.toml`, which reports 14 checks and 1 failure.
- Verify command through the installed quiet-verify.sh: green (0s, verify totals: 13 passed, 0 failed).
- Closed this iteration: IT-2 (Medium) - the published crate artifact no longer carries PLAN.md, BACKLOG.md, JOURNAL.md, JOURNAL-archive.md or .jeffy/, proven by the packaging battery going from 4 failures to 0.

Learnings: a battery written against a known-bad tree carries a standing claim about that badness, and fixing the defect falsifies the battery's own README as surely as it falsifies the ledger line - the re-measurement belongs in the fixing iteration, not in the next audit. No new Lesson: this is the existing "a fix re-executes the claims it invalidates" rule from the Method, applied to a probe README rather than to PLAN.md.

Next: the map is complete - fourteen of fourteen rows swept. Two Mediums remain, IT-1 and IT-3. IT-1 next, because its fix is the one that raises the crate's own oracle from 5 of 10 to 10 of 10 and every later claim about test coverage rests on it.

## iter 5/10 | e09ed927-121713 | 2026-08-25 | IT-1 | done

Task: IT-1 (Medium, test, testing) - tests/test.rs executed no case for seven of the twelve integer types and its thirteen fixed cases caught only 5 of 10 seeded single-token defects.

Changed: tests/test.rs (nineteen further literal known-answer cases, six differential tests, a tightness check over all twelve MAX_STR_LEN constants, and the clippy allow list the crate already applies to its own source), BACKLOG.md (IT-1 deleted), .jeffy/probes/test-suite/ (default and README re-measured), PLAN.md (Oracle class and the paragraph above it rewritten, test-suite row re-recorded), JOURNAL.md. src/ is untouched: this task adds no behaviour and changes none.

Checkpoint: 9486ed39182c39ccef25d811e0829f4964ede3da. Stall check: not a stall - tests/test.rs changed and IT-1 was deleted from the ledger.

Verification:
- Acceptance check, both directions. On the fixed tree the test-suite battery reports 10 of 10 seeded defects caught. On a scratch copy carrying the pre-fix tests/test.rs restored from HEAD, with everything else identical, the same battery reports 5 of 10 - so the improvement is measured against the old file rather than asserted. The five newly caught are the divmod100 reciprocal off by one, the sign suppressed for -1, usize wired to u32, the Granlund-Montgomery multiplier decremented, and one corrupted pair in the decimal lookup table.
- Verify command through the installed quiet-verify.sh: green (0s, verify totals: 38 passed, 0 failed), up from 13.
- clippy as CI runs it: `cargo clippy --tests --benches -- -Dclippy::all -Dclippy::pedantic` exit 0. The first attempt failed with 25 errors, because tests/test.rs is a separate crate and the allow list in src/lib.rs does not reach it; the fix mirrors the crate's own allows rather than scattering per-site attributes.
- Miri, which CI runs on this suite under a 45-minute job timeout, was measured rather than assumed: `MIRIFLAGS=-Zmiri-strict-provenance cargo +nightly miri test` passes 36 tests and 2 doctests in 12 seconds of wall clock with no Undefined Behavior. The exhaustive sweeps take a prime stride of 1021 under `cfg!(miri)` and the u128 boundary span drops from 2000 to 8, so the same code paths are sampled rather than exhausted; without that guard the sweeps would have put the miri job at risk, and the guard is documented in the file.
- Contract preserved: no public interface, signature or behaviour changed. The new tests only observe. The one thing they pin that was previously unpinned is that every MAX_STR_LEN equals the widest string its type actually produces, which is the invariant Buffer::format's pointer cast rests on.
- Battery ownership: the diff touches tests/test.rs, named in the paths file of .jeffy/probes/test-suite and of no other battery. That battery was run in this iteration and its row is re-recorded at this checkpoint hash.
- Two standing claims were falsified by this fix and re-measured in the same iteration rather than left to rot. The battery's own default expectation of 5 became 10, and its README's discriminating state changed from "the claim itself" to the pre-fix suite; running the current tree at ITOA_EXPECTED_CAUGHT=9 reddens it, so the equality is not vacuous in either direction. PLAN.md's Oracle class said "13 fixed known-answer cases ... no differential comparison against core's own Display", which was the whole point of the finding and is no longer true of the suite; both it and the paragraph above it now describe the suite that exists, including the miri stride.
- Closed this iteration: IT-1 (Medium) - the crate's own suite now catches all ten seeded defects, with the pre-fix measurement of 5 preserved in the battery README as the comparison.

Learnings: a test crate does not inherit the lint allowances of the library crate it tests, so a sweep added to tests/ meets `-Dclippy::pedantic` on its own terms. And a suite that CI also runs under miri has a second budget: an exhaustive sweep that costs milliseconds natively can cost a job timeout there, so it takes a stride under cfg!(miri) and the cost is measured before it is committed. Both recorded under Lessons in PLAN.md.

Next: one Medium remains, IT-3 - Buffer::format casts the buffer to I::Buffer with nothing enforcing that the target fits. The new tightness check in test_max_str_len pins the twelve constants against their real outputs, which is the observable half; IT-3 is the compile-time half.

## iter 6/10 | e09ed927-121713 | 2026-08-25 | IT-3 | done

Task: IT-3 (Medium, test, security) - Buffer::format casts its byte array to I::Buffer and writes through it with nothing enforcing that the target fits. The fix adds a const assertion to both impl macros, so every impl carries it by construction rather than by a list that could rot.

Changed: src/lib.rs (a size assertion in impl_Integer!'s existing const block for both the signed and unsigned buffer, and a new const block in impl_Integer_size! for the pointer-sized impls), BACKLOG.md (IT-3 deleted, IT-4 filed as a High), .jeffy/probes/build-configs/ (paths file corrected, downstream no-panic check added), PLAN.md (rows re-recorded, build-configs flipped back to unswept), JOURNAL.md.

Checkpoint: d717d44a342db4f62a0083cc4f22ed5fb2ee8ebd. Stall check: not a stall - src/lib.rs changed, IT-3 was deleted and IT-4 added, and the build-configs row changed state.

Verification:
- Acceptance check, both directions, on a scratch tree where Buffer is sized from the wrong impl (`s|i128::MAX_STR_LEN|u128::MAX_STR_LEN|g`, giving a 39-byte buffer where i128 needs 40). With the assertions, `cargo build` fails: `error[E0080]: evaluation panicked: buffer too small for this impl`. With the pre-fix src/lib.rs restored and the same mutation, `cargo build` exits 0 - the 40-byte write into a 39-byte allocation compiles cleanly, which is the finding.
- That unguarded build is genuinely unsound, not merely unproven: `MIRIFLAGS=-Zmiri-strict-provenance cargo +nightly miri test` on it reports `Undefined Behavior: constructing invalid value of type &mut [MaybeUninit<u8>; 40]: encountered a dangling reference (going beyond the bounds of its allocation)` in test_buffer_reuse_leaves_no_tail. With the assertion the same tree does not compile at all.
- Contract preserved: const assertions emit no runtime code and change no signature, behaviour or accepted input. The public surface is identical.
- Verify command through the installed quiet-verify.sh: green (1s, verify totals: 38 passed, 0 failed).
- Battery ownership: the diff touches src/lib.rs, named in ten batteries' paths files, enumerated by `grep -l '^src/lib\.rs$' .jeffy/probes/*/paths`. All ten were run. Nine are green: unsigned-small 12,065,964 checks; signed 12,266,579; pointer-sized 6,400,299; unsigned-128 2,024,696; buffer-api 600,017; digit-tables 110; integer-trait 44; docs 28; test-suite 2. The tenth, build-configs, went red - see below.
- Closed this iteration: IT-3 (Medium) - the size invariant behind the unsafe cast is now a compile-time assertion carried by every impl, demonstrated failing on an undersized buffer and demonstrated absent before the change.

The build-configs failure, and what it turned out to be:
- `cargo build --tests --features no-panic --release` fails with three `ERROR[no-panic]: detected panic in function` errors naming `Buffer::format`, `<u128 as Unsigned>::fmt` and `<u8 as private::Sealed>::write`.
- It is not caused by this iteration. The same command fails identically at HEAD without the IT-3 change, and succeeds at the iteration-4 checkpoint 988e9e76, so the change of state is iteration 5's.
- It is not caused by iteration 5 either, in the sense that matters. A downstream crate depending on itoa with `features = ["no-panic"]` - a crate that never sees tests/test.rs - formatting a u32 in a loop plus u128, usize and u8 fails to link in release with the same three errors. Built against the pristine upstream tree at 1577ed9, before this run touched anything, it fails identically. The defect is in the published crate and predates the run.
- What iteration 5 changed is only which monomorphizations itoa's own test binary references. Five of the eight tests in the current suite trigger it independently, bisected one at a time on nightly: test_every_decimal_pair, test_decade_boundaries, test_u128_division_boundaries, test_pointer_sized_forwarding and test_buffer_reuse_leaves_no_tail. test_exhaustive_8_bit, test_exhaustive_16_bit and test_max_str_len do not. Formatting a single u8 on the iteration-4 tree does not trigger it either, so the earlier guess that this was simply "u8 was never instantiated" is wrong and is not what the finding says.
- Filed as IT-4 (High, runtime, build) - a broken build for a documented feature in ordinary downstream use. The envelope classes feature selection as user-error, which downgrades findings about wrong values; this is the correct documented value producing a broken link, so no downgrade applies and the rubric's "broken build or install" governs.
- Instrument finding, fixed in this iteration: .jeffy/probes/build-configs/paths listed src/lib.rs, src/u128_ext.rs and Cargo.toml but not tests/test.rs, even though the battery builds `--tests`. That omission is exactly why iteration 5's change was not caught when it landed. tests/test.rs is now in the paths file, and the battery additionally builds a real downstream crate against the feature, so it reproduces the defect directly instead of incidentally. It now reports 9 checks, 2 failures.
- The build-configs row is flipped back to unswept, because a red battery certifies nothing.

Learnings: a battery's paths file must list every path whose content can change the battery's verdict, not just the paths the row is nominally about - build-configs builds `--tests`, so tests/test.rs was always in its scope and its absence hid a state change for a whole iteration. And a feature that exists for downstream consumers is verified by building a downstream consumer: itoa's own `--tests` build exercises only the monomorphizations its own tests reference, which is why a link-time guarantee could be false in the published crate while its CI stayed green. Both recorded under Lessons in PLAN.md.

Next: IT-4 is an open High and outranks everything, including the now-unswept build-configs row. Four iterations remain. If the panic paths turn out not to be eliminable within one iteration, IT-4 is marked blocked with the reason rather than downgraded.

## iter 7/10 | e09ed927-121713 | 2026-08-25 | IT-4 | blocked

Task: IT-4 (High, runtime, build) - the no-panic feature makes a downstream release build fail to link. Three fix attempts spent; the downstream half is fixed and verified, a residue remains, so the task is marked blocked rather than claimed.

Changed: src/lib.rs (an assert_unchecked helper plus hints at all six offset sites in the small-integer and u128 formatters), BACKLOG.md (IT-4 marked [b] with the remaining scope), PLAN.md (rows re-recorded), JOURNAL.md.

Checkpoint: 678ba0f920f857a76650a45e08e49f42159edf36. Stall check: not a stall - src/lib.rs changed and IT-4's task line moved from open to blocked.

Verification:
- Diagnosis first, by reproduction rather than reading. Each call shape alone links: a lone u8, a u8 loop, a u32 loop, a single u32, a single u128 constant, usize::MAX, a u64 loop. The minimal failing case is one runtime u128 - `let v: u128 = std::env::args().count() as u128; buffer.format(v)` - which fails with three `ERROR[no-panic]` errors. A constant u128 links; a non-constant one does not. That is ordinary usage, and it is what made this a High rather than a curiosity.
- Root cause: libcore's own copy of this formatting loop carries `core::hint::assert_unchecked(offset >= 4)` and `assert_unchecked(offset <= buf.len())` at every site where the offset moves, and itoa's copy carries none - `grep -c "assert_unchecked\|unreachable_unchecked" src/lib.rs` returned 1 before this change, that one being the unrelated `unreachable_unchecked` in Buffer::format. Without them the bounds checks on `buf` survive optimization and leave a panicking path in a function the feature promises has none.
- The fix spells assert_unchecked out with `hint::unreachable_unchecked`, because `core::hint::assert_unchecked` is stable only from 1.81 and this crate's declared MSRV is 1.68. Six sites: the four-digit, two-digit and last-digit branches of the impl_Unsigned macro, and the same three in the hand-written u128 formatter. Each carries the SAFETY comment stating why the bound holds.
- The assertions are unsafe, so they were checked rather than argued: `MIRIFLAGS=-Zmiri-strict-provenance cargo +nightly miri test` passes 36 tests and 2 doctests with no Undefined Behavior, and the nine batteries owning src/lib.rs re-ran green over more than 33 million checks - unsigned-small 12,065,964; signed 12,266,579; pointer-sized 6,400,299; unsigned-128 2,024,696; buffer-api 600,017; digit-tables 110; integer-trait 44; docs 28; test-suite 2 of 2 with the suite still catching 10 of 10 seeded defects.
- Result of the fix: `<u128 as Unsigned>::fmt` is no longer flagged. The minimal runtime-u128 downstream links, and so does the four-shape downstream the build-configs battery builds. That battery went from 9 checks 2 failures to 9 checks 1 failure.
- What is not fixed, stated plainly: `cargo build --tests --features no-panic --release` still fails, and a downstream formatting ten or more runtime types still fails, on two symbols - `<itoa::Buffer>::format::__NoPanic` and `<u8 as private::Sealed>::write::__NoPanic`. Neither u8 nor i8 alone triggers it, and deleting both from the ten-type downstream does not clear it, so the trigger is not a panic locatable in either function; it looks like codegen-unit partitioning of the rlib. The third attempt, `#[inline]` on both `Unsigned::fmt` impls, changed nothing and was reverted rather than left in, because it alters codegen for every consumer and bought nothing.
- Verify command through the installed quiet-verify.sh: green (0s, verify totals: 38 passed, 0 failed). clippy at -Dclippy::all -Dclippy::pedantic: exit 0, after the first version of the helper tripped clippy::inline_always and was changed to plain #[inline].
- Contract preserved: no public interface, signature or observable behaviour changed. The hints are optimizer assertions; the 33 million differential checks and the miri run are what say so rather than the claim.
- The build-configs row stays unswept: its battery is still red on one check.

Learnings: when a crate says its implementation comes from libcore, the diff against libcore is a place to look for defects and not only for provenance - the missing hints were visible in the source I had already fetched in iteration 1 to check the documentation claim, and they explain a link failure nobody had located. And a fix that does not move the measurement gets reverted, not kept on the theory that it might help: `#[inline]` on a hot public path is a codegen change for every consumer and it earned nothing here. Recorded under Lessons in PLAN.md.

Next: three iterations remain and IT-4 is blocked, so the run cannot converge. Iteration 8 should decide between a fourth attempt with new information - the CGU-partitioning hypothesis suggests trying codegen-units or a per-function no_panic audit - and leaving IT-4 for the next run with the diagnosis it now carries. The run will end out of budget with an open High, which is the honest outcome.

## iter 1/10 | fae332c9-133050 | 2026-08-25 | AUDIT | audit

Task: full fresh-evidence audit opening a new run. The previous run ended out of budget with IT-4 blocked on a hypothesis - codegen-unit partitioning of the rlib - that this audit set out to test rather than inherit.

Changed: .jeffy/probes/build-configs/no-panic-types.sh (new per-type enumeration instrument), BACKLOG.md (IT-4 replaced by IT-5, IT-6 filed), PLAN.md (build-configs row restated, two Lessons), JOURNAL.md.

Checkpoint: 0d16c3be723ee320d7c2bc519bdafaf6a170229c. Stall check: not a stall - IT-4 left the ledger and IT-5 and IT-6 were added, so items changed state, and a new instrument was written under .jeffy/probes/.

Verification:
- Inventory staleness derived rather than assumed: only JOURNAL.md and PLAN.md changed between 678ba0f and HEAD, and `git diff --name-only <row-commit> HEAD -- $(cat .jeffy/probes/<battery>/paths)` returns empty for all twelve swept rows, so none is stale. 12 of 13 rows swept; build-configs is the one unswept row and was the audit's first target.
- build-configs re-run through the installed run-probe.sh: 9 checks, 1 failure. The single failure is `cargo build --tests --features no-panic --release`, on `<itoa::Buffer>::format::__NoPanic` and `<u8 as private::Sealed>::write::__NoPanic`.
- That command is a CI job (`.github/workflows/ci.yml`, nightly only), so it was re-run on nightly rather than only on stable: it fails there too. A tree extracted from pristine upstream 1577ed9 passes it, exit 0.
- Which half of the tree causes it, by swap rather than by reading: current `src/` with upstream `tests/test.rs` exits 0; upstream `src/` with current `tests/test.rs` exits 101 with 3 no-panic errors. The trigger is in the test file this run wrote. Upstream's tests format only `u64`, `i64`, `i16`, `u128`, `i128` and only as constants; this run's tests loop over runtime `u8`, `i32`, `usize` and the rest.
- That pointed at the real class, and it was enumerated rather than argued. `.jeffy/probes/build-configs/no-panic-types.sh` builds a downstream crate against a given itoa tree, once per supported integer type, formatting one value read from `std::env::args().count()` so the optimizer cannot fold it. At HEAD: 12 checks, 3 failures - `i32`, `i64`, `isize`. Against trees extracted from 1577ed9 and from d717d44: 12 checks, 6 failures each - `u32`, `i32`, `u64`, `u128`, `i128`, `usize`.
- So iteration 7's hints were a net improvement and a partial regression at once: five types fixed (`u32`, `u64`, `u128`, `i128`, `usize`), two broken (`i64`, `isize`), `i32` failing throughout. The blocked IT-4 read the two remaining symbols as evidence of codegen-unit partitioning; the per-type sweep shows an ordinary per-type property instead, and the constant-versus-runtime distinction is what hid it from itoa's own CI. IT-4 is replaced by IT-5 rather than carried, because its stated hypothesis is falsified and the three-strike rule turns a third instance of one root cause into a single structural task.
- Verify command through the installed quiet-verify.sh: green (0s, verify totals: 38 passed, 0 failed).
- Oracle class and Environment fingerprint re-read. The fingerprint says the `no-panic` items and `cargo miri test` are outside the Verify command, and nothing here claims they were green through it: every no-panic figure above comes from a command run by hand or by the battery, and no miri run was made this iteration.

Scores, claiming the 12 swept rows and not the unswept build-configs remainder:
- correctness: High - IT-5, reproduced by an executed twelve-type enumeration.
- testing: Medium - IT-6, the battery that owns this row certified a downstream link while three types did not link.
- security: None. The unsafe code is unchanged since 678ba0f, where miri under -Zmiri-strict-provenance passed it; no new evidence.
- code quality: None. `cargo clippy --tests --benches -- -Dclippy::all -Dclippy::pedantic` exits 0, run inside the battery this iteration.
- documentation: None on the docs row, current at 678ba0f.
- dependency hygiene: None. Zero runtime dependencies; one optional proc-macro, no-panic 0.1.37, pulling proc-macro2 1.0.107, quote 1.0.47, syn 3.0.4, unicode-ident 1.0.24.
- architecture, performance, developer experience: None on swept rows; not re-measured this iteration and claimed no wider than that.
- error handling: not applicable - the public API is infallible by construction and has no error path to swallow.
- observability, UX, accessibility: not applicable - a no_std formatting primitive with no user-facing surface.

Learnings: a build-time guarantee is enumerated per type, not sampled - a probe that formats a constant proves nothing about the same type read at runtime, because the constant folds away and takes its panic path with it, and that single distinction is why itoa's CI has been green over this for as long as the feature has existed. And a fix to such a guarantee is measured across the whole set before and after: two leftover symbols read as "the fix mostly failed" where the enumeration showed six failures becoming three. Both recorded under Lessons in PLAN.md.

Next: IT-5 is an open High and outranks the unswept build-configs row. Iteration 2 works it with the diagnosis it now carries - a per-type property with a runnable enumeration - rather than the partitioning hypothesis that consumed three attempts.

## iter 2/10 | fae332c9-133050 | 2026-08-25 | IT-5 | done

Task: IT-5 (High, runtime, correctness) - with the `no-panic` feature on, a downstream release build failed to link for a runtime `i32`, `i64` or `isize`. The signed `write` reached its digit buffer as `(&mut buf[offset..]).try_into().unwrap()`: a range bounds check and a fallible array conversion, both provably infallible here, plus a third bounds check on `buf[offset].write(b'-')`. The fix replaces the reborrow with the pointer cast `Buffer::format` already uses for the same reason, and the sign write with `get_unchecked_mut`.

Changed: src/lib.rs (the signed `write` in `impl_Integer!`, and the `assert_unchecked` doc comment, whose claim is now a measured figure), .jeffy/probes/test-suite/check.py (one mutation's search text follows the line it mutates), BACKLOG.md (IT-5 deleted, the class recorded under Settled classes), PLAN.md (environment fingerprint, nine rows re-recorded, two Lessons), JOURNAL.md.

Checkpoint: 6d960e12ba2e9671a98ce11670f4562fc54c2bbe. Stall check: not a stall - src/lib.rs changed and IT-5 left the ledger. The nine swept rows whose batteries were re-run are re-recorded at this hash.

Verification:
- The filed reproduction was run first, before any edit: 12 checks, 3 failures - `i32`, `i64`, `isize`.
- Acceptance check, both halves. `bash .jeffy/probes/build-configs/no-panic-types.sh`: 12 checks, 0 failures. `cargo +nightly build --tests --features no-panic --release`, which is the CI job that was red: exit 0, and exit 0 on stable too.
- The check is strong enough to fail, shown on this tree rather than argued from an older one: with `assert_unchecked`'s body made inert, the same enumeration reports 12 checks and 6 failures - `u32`, `i32`, `u64`, `u128`, `i128`, `usize`. So iteration 7's hints and this iteration's fix are both load-bearing, and neither alone reaches zero: the hints carry the unsigned path, and this fix carries `i32`, `i64` and `isize`, which the hints could not reach.
- The new code is unsafe, so it was checked rather than reasoned about. `MIRIFLAGS=-Zmiri-strict-provenance cargo +nightly miri test`: exit 0, 36 tests and 2 doctests, no Undefined Behavior. The nine batteries owning src/lib.rs besides build-configs re-ran green over 33.3 million checks - signed 12,266,579; unsigned-small 12,065,964; pointer-sized 6,400,299; unsigned-128 2,024,696; buffer-api 600,017; digit-tables 110; integer-trait 44; docs 28; test-suite 2 - and build-configs itself is now 9 checks, 0 failures.
- Contract preserved. `private::Sealed::write` is sealed and `#[doc(hidden)]`; its two callers are `Buffer::format` and the pointer-sized forwarding impl, both read before the change. The returned `&str`, the offsets and every formatted byte are unchanged, which the 33.3 million differential checks against `core`'s `Display` are what establish. No public signature, behaviour or accepted input moved, so no Surface inventory row is invalidated and no documentation contradicts its module.
- Battery ownership, and one instrument finding fixed in place: `grep -l '^src/lib\.rs$' .jeffy/probes/*/paths` lists ten batteries and all ten were run. test-suite went red first, correctly - it refuses a mutation whose text no longer matches the source, and this change moved the line the `minus sign replaced by plus` mutation edits. The mutation now names the new line, seeds the same defect, and the battery is back to 10 of 10.
- That battery's README counts were re-measured in the same iteration as the change to it, all three: the current tree catches 10 of 10; `ITOA_EXPECTED_CAUGHT=9` reddens the equality; and tests/test.rs restored from 988e9e7 reports 5 of 10, the pre-IT-1 figure the README records. tests/test.rs was copied aside and restored, and `git diff` on it is empty.
- MSRV, which this host could not reach until now. The 1.68 toolchain was installed this iteration, so the CI msrv job has a real local counterpart instead of an assumption about which constructs are old enough: `cargo +1.68 build` and `cargo +1.68 build --no-default-features` both exit 0. PLAN.md's environment fingerprint said no 1.68 toolchain was installed; that sentence was a standing claim this iteration falsified, and it is rewritten rather than left to rot.
- Verify command through the installed quiet-verify.sh: green (0s, verify totals: 38 passed, 0 failed). Clippy as CI runs it, inside build-configs: exit 0.
- The exclusion list behind the fingerprint was re-derived, not copied: `cargo test --no-run` still reports exactly two executables, `unittests src/lib.rs` and `tests/test.rs`.
- Closed this iteration: IT-5 (High) - all twelve supported integer types now link in a downstream release build with the feature on, up from nine at 0d16c3b and six against pristine upstream.

The build-configs row stays unswept, deliberately. Its battery is green, but the check that reports the downstream link still formats no runtime signed type - the exact blind spot IT-6 exists to close and the reason this defect survived a green battery for two iterations. Flipping the row now would certify the surface on an instrument this run has already filed as inadequate; IT-6 closes that and the row flips there.

Learnings: where a bounds check or a fallible conversion is provably infallible, delete it rather than hint at it - the optimizer folded the identical `buf[..].try_into().unwrap()` for i8, i16 and i128 and not for i32 and i64, and a `no-panic` build fails on exactly that difference. And the declared MSRV now has a toolchain on this host, so any change under src/ runs `cargo +1.68 build` and `cargo +1.68 build --no-default-features`, because CI has an msrv job the Verify command does not reach. Both recorded under Lessons in PLAN.md.

Next: IT-6 is the only open task and the build-configs row is the only unswept row; they are the same work, so iteration 3 wires no-panic-types.sh into the battery, re-measures its README, and sweeps the row.

## iter 3/10 | fae332c9-133050 | 2026-08-25 | IT-6 | done

Task: the top of the queue was the one unswept Surface inventory row, build-configs, and IT-6 (Medium, dev-tooling, testing) was the instrument defect standing between that row and an honest sweep: the battery reported `ok: downstream crate links with the no-panic feature` while three runtime types did not link, and its README stated 8 checks where it ran 9. The row and the task are one piece of work, so this iteration does both and the row flips on a battery that can now see what it certifies.

Changed: .jeffy/probes/build-configs/no-panic-types.sh (the twelve per-type checks moved into a function so run.sh can source it and keep them as twelve checks rather than one, still runnable standalone over any tree), .jeffy/probes/build-configs/run.sh (sources it; the mixed-type downstream kept and renamed for what it actually covers), .jeffy/probes/build-configs/README.md (rewritten around measured figures), BACKLOG.md (IT-6 deleted), PLAN.md (build-configs row swept), JOURNAL.md.

Checkpoint: 796a2aa8ee7411209236b69183642f094af76ee6. Stall check: not a stall - IT-6 left the ledger and the build-configs row flipped to swept at this hash.

Verification:
- The battery now reports 21 checks, 0 failures, through the installed run-probe.sh. It reported 9 before this change and the added twelve are the per-type shape, kept individually so a single broken type reddens a single check and names itself.
- Every figure in the README was re-measured in this iteration rather than carried, which is the rule this battery's own README states and the last version of it broke. Current run 21 checks, 0 failures. `no-panic-types.sh` alone: 12 checks, 0 failures.
- Two discriminating states, both executed here. The build matrix: `bash .jeffy/probes/discriminate.sh build-configs 's|#!\[no_std\]|#![allow(unused)]|'` takes the battery to 21 checks, 1 failure - the thumbv6m target build - and exit 1, as the README claims. The per-type checks: rather than a seeded defect, two real trees, extracted with `git archive <commit> | tar -x -C <dir>` and passed to `no-panic-types.sh` - at 1577ed9, the tree this project started from, 12 checks and 6 failures; at 0d16c3b, iteration 1's checkpoint, 12 checks and 3 failures. So the twelve checks are not vacuous in either direction, and the improvement they measure is on the record as a command anyone can re-run rather than as a sentence.
- The Settled classes line for the no-panic class names `bash .jeffy/probes/build-configs/no-panic-types.sh` as its enumeration. That file changed this iteration, so the enumeration was re-run: 12 checks, 0 failures, the figure the line states.
- Verify command through the installed quiet-verify.sh: green (0s, verify totals: 38 passed, 0 failed).
- Battery ownership: this diff touches only files under .jeffy/probes/build-configs/ and the three state files. `grep -l` over the paths files shows no battery declares any of them - paths files name crate sources - so build-configs is the only battery this diff owns, and it was run.
- Closed this iteration: IT-6 (Medium) - the battery covers every supported type at runtime, and its stated counts are the output of runs made in the same iteration as the change.
- A correction to this run's own record, stated rather than left to propagate: iteration 1's entry gave the inventory as 12 of 13 rows swept. `grep -cE '^- \[[ x~]\] [a-z0-9-]+:' PLAN.md` returns 14 rows, of which 13 were swept at run start. With build-configs flipped this iteration the position is 14 of 14. The run report uses the derived figures, not the earlier ones.

Learnings: none that generalise beyond what PLAN.md already records - the rule that a battery's stated counts are re-measured in the same iteration as any change to it is exactly what the stale 8-checks line broke, and it is already written down.

Next: the ledger is empty and every inventory row is swept, but no full audit on this run's record has scored clean - iteration 1's found a High and a Medium, both since closed. Iteration 4 is the full fresh-evidence audit convergence requires. If it comes back clean, closeout begins and the evaluator gate follows in the same or the next iteration, with budget left to answer a REJECT.

## iter 4/10 | fae332c9-133050 | 2026-08-25 | AUDIT | audit

Task: the closing full audit. The ledger was empty and every inventory row swept, but no audit on this run's record had scored clean - iteration 1's found the High and the Medium this run has since closed - so convergence needed a fresh-evidence pass over the whole map.

Changed: BACKLOG.md (IT-7 filed), PLAN.md (one Lesson), JOURNAL.md.

Checkpoint: 90ae7067acfa32c850f49807c84c003978e94b6c. Stall check: not a stall - IT-7 was added to the ledger. No inventory row changed state, because none was unswept or stale to begin with.

Verification, all executed this iteration:
- Every one of the 14 batteries re-run through the installed run-probe.sh, all green: 35,390,598 checks, 0 failures, summed by script rather than by hand. Per battery - signed 12,266,579; unsigned-small 12,065,964; pointer-sized 6,400,299; mulhi 2,032,788; unsigned-128 2,024,696; buffer-api 600,017; digit-tables 110; ci-workflow 28; docs 28; build-configs 21; packaging 14; bench-fuzz 8; integer-trait 44; test-suite 2.
- Row staleness derived, not assumed: for each of the 14 swept rows, `git diff --name-only <row-commit> HEAD -- $(cat .jeffy/probes/<battery>/paths)` returns empty. No row is stale and none is unswept, so these scores claim the whole mapped surface rather than a part of it.
- Verify command through the installed quiet-verify.sh: green (0s, verify totals: 38 passed, 0 failed). Oracle class and Environment fingerprint re-read; nothing below claims any excluded target was green through the Verify command.
- `MIRIFLAGS=-Zmiri-strict-provenance cargo +nightly miri test`: exit 0, 36 tests and 2 doctests, no Undefined Behavior. This is the oracle for the pointer cast iteration 2 put into the signed `write`, and it is named here as a hand-run command, not as part of the Verify command.
- The one Settled class line's enumeration re-run: `bash .jeffy/probes/build-configs/no-panic-types.sh` reports 12 checks, 0 failures, the figure the line states. The Declined section holds no entries, so there are no Derivations to re-run.
- Every battery README's stated green total re-derived against today's runs; all 14 match.
- Every discriminate command recorded in a battery README re-run, because this run changed src/lib.rs and eight of those mutations target it. Eleven reproduce exactly: buffer-api 1,538; integer-trait 17; mulhi 165,292; pointer-sized 2,426,336; signed 27,221; unsigned-small 620,131; and the qualitative ones for bench-fuzz, ci-workflow, docs and packaging. Two do not, and are the audit's findings.
- Performance, measured rather than assumed, since iteration 2 changed the hot path: `cargo bench --bench bench` at sample-size 20 and one-second measurement, HEAD against a tree extracted from 1577ed9. itoa is faster on six of seven groups - i16[0] -26.5%, i16[min] -28.1%, u128[0] -33.9%, u64[max] -8.4%, u64[half] -7.5%, u64[0] -8.8% - and u128[max] is +3.0%, which a twenty-sample run cannot separate from noise. These are indicative figures from a deliberately short run, not publication-grade ones, and no performance finding follows from them.

Scores, claiming all 14 rows, every one swept and re-run this iteration:
- correctness: None. 35.4 million battery checks, the verify suite, and miri all green on the current tree.
- security: None. The crate's unsafe code, including the pointer cast added this run, carries a miri run under strict provenance this iteration.
- documentation: Medium - IT-7. Two battery README standing claims do not reproduce from the procedure they record.
- testing: None. The instruments themselves detect: re-derived by hand, the digit-tables mutation still reddens exactly the 2 checks its line claims, and the unsigned-128 mutation still takes that battery red. What is wrong is the written claim, not the check.
- performance: None, and materially improved on six of seven benchmark groups.
- code quality: None. `cargo clippy --tests --benches -- -Dclippy::all -Dclippy::pedantic` exits 0, run inside build-configs this iteration.
- dependency hygiene: None. Zero runtime dependencies; one optional proc-macro, no-panic 0.1.37, with proc-macro2 1.0.107, quote 1.0.47, syn 3.0.4 and unicode-ident 1.0.24 beneath it.
- architecture, developer experience: None.
- error handling: not applicable - the public API is infallible by construction and has no error path to swallow.
- observability, UX, accessibility: not applicable - a no_std formatting primitive with no user-facing surface.

Closeout has not begun. This audit scored a Medium, so the run is not clean and the closeout stop does not apply.

Learnings: a mutation written into a markdown README is escaped twice, so a recorded discriminate command is verified by running it and never by reading it - digit-tables' line carried two backslashes where the source has one, and it matched nothing for as long as it stood. Recorded under Lessons in PLAN.md.

Next: IT-7 is the only open task. Iteration 5 fixes it and builds the enumerator its acceptance names, which turns every README's discriminating claim into something a single command re-derives. Iteration 6 is then a fresh full audit that can score clean, and iteration 7 the evaluator gate and, on a PASS, the declaration - four iterations of margin beyond that.

## iter 5/10 | fae332c9-133050 | 2026-08-25 | IT-7 | done

Task: IT-7 (Medium, dev-tooling, docs) - two battery README standing claims did not reproduce from the procedure they record. The fix is the class rather than the two instances: every discriminating claim now carries a machine-readable expectation, and one command re-derives all of them.

Changed: .jeffy/probes/readme-claims.py (new enumerator), all 13 battery READMEs that record a discriminate command (an `Expect:` clause each; digit-tables' sed corrected; unsigned-128's single conflated bullet split into two, one per mutation), BACKLOG.md (IT-7 deleted, the class recorded under Settled classes), PLAN.md (one Lesson), JOURNAL.md.

Checkpoint: 09b3c722dc87193b73b714dcb55a8e3fd7b3bff4. Stall check: not a stall - IT-7 left the ledger and a new enumerator was added under .jeffy/probes/. No inventory row changed state, because none was unswept or stale.

Verification:
- The filed reproduction was run first, unpiped so the status is the command's own: the digit-tables command as recorded exits 2 with `the sed script changed nothing in src/lib.rs`.
- The second half of the finding was measured rather than inherited. The unsigned-128 bullet attributed an abort at exit 101 to the M_HIGH mutation and named a second mutation, `SH_POST` 51 -> 50, without recording a command for it. Run: M_HIGH gives 2,024,696 checks, 188 failures, battery exit 1 - no abort; `SH_POST` is the one that aborts, at exit 139. The bullet had the two mutations' outcomes crossed. It is now two bullets, each with its own command and its own measured expectation.
- Both fixed lines were measured, not reasoned: digit-tables with one backslash reddens exactly the 2 checks its line claims.
- The enumerator's convention: a bullet under `## Standing claims` that records a discriminate command must also carry `Expect: <F> failures, exit <C>` or `Expect: no tally, exit <C>`. A bullet with a command and no expectation is itself a mismatch, which is what makes the convention self-enforcing rather than a habit.
- Acceptance check, both halves. Corrected tree: `python3 .jeffy/probes/readme-claims.py` reports 14 claims, 0 mismatches, exit 0. Against the same tree before the `Expect:` clauses existed it reported 13 claims, 13 mismatches, which is how the eleven observed figures were obtained rather than assumed.
- The check is strong enough to fail, demonstrated on both defects. With digit-tables' sed put back to the over-escaped form and unsigned-128's expectation put back to `no tally, exit 101`, the enumerator exits 1 with exactly two mismatches: `recorded mutation no longer applies to the source; observed discriminate.sh exit 2` and `stated no tally, exit 101; observed 188 failures, exit 1`. The two READMEs were copied aside and restored, and neither carries a stray edit.
- The eleven figures the enumerator now pins were each re-derived by running the recorded mutation this iteration: buffer-api 1,538; integer-trait 17; mulhi 165,292; pointer-sized 2,426,336; signed 27,221; unsigned-small 620,131; digit-tables 2; unsigned-128 188 and the SIGSEGV; bench-fuzz 3; ci-workflow 2; docs 1; packaging 1; build-configs 1. Where a README already stated a number in prose, the measured value matched it; the four qualitative claims now carry a number they did not have.
- Verify command through the installed quiet-verify.sh: green (1s, verify totals: 38 passed, 0 failed).
- Battery ownership: the diff touches only files under .jeffy/probes/, and `grep -l "^<path>$" .jeffy/probes/*/paths` over every changed path returns nothing, because paths files declare crate sources. No battery is owned by this diff and no Surface inventory row moves.
- One stray artifact removed rather than committed: importing the enumerator as a module during development left `.jeffy/probes/__pycache__/`, which `git add -A` would have swept in. Running the file as a script does not create it.
- Closed this iteration: IT-7 (Medium) - every recorded discriminating claim in every battery README is now re-derived by a single command, and two that had been silently unrunnable or wrong are corrected.

Learnings: a battery README's discriminating claim carries a machine-readable `Expect: <F> failures, exit <C>` clause, and `python3 .jeffy/probes/readme-claims.py` re-derives every one of them by running the command each claim records; the declaring iteration runs that rather than re-deriving them by hand. Recorded under Lessons in PLAN.md.

Next: the ledger is empty and every row is swept, but the audit that must certify this run was iteration 4's, which filed this Medium and so did not score clean. Iteration 6 is a fresh full audit; if it scores zero High and zero Medium, closeout begins and iteration 7 runs the evaluator gate and, on a PASS, declares - with three iterations still in hand.

## iter 6/10 | fae332c9-133050 | 2026-08-25 | AUDIT | audit

Task: the closing full audit, repeated with fresh evidence. Iteration 4's audit filed IT-7 and so did not score clean; iteration 5 closed it, and this pass re-scores the whole map against the rubric and the envelope.

Changed: PLAN.md (one Lesson, and a stale causal clause removed from the docs row - it explained a re-recording that a later one superseded), JOURNAL.md.

Checkpoint: 718771f8d9afcebbae79b995bdd72f27b7878458. Stall check: this iteration changed only PLAN.md and JOURNAL.md, no BACKLOG item changed state and no inventory row changed state, so by the letter of the check it is a no-progress iteration. It is an AUDIT that filed nothing, which the ceremony exemption covers, and the previous primary entry - iteration 5's IT-7 done - says no such thing, so no pair forms.

Verification, all executed this iteration:
- All 14 batteries re-run through the installed run-probe.sh: 35,390,598 checks, 0 failures. Per battery - signed 12,266,579; unsigned-small 12,065,964; pointer-sized 6,400,299; mulhi 2,032,788; unsigned-128 2,024,696; buffer-api 600,017; digit-tables 110; integer-trait 44; ci-workflow 28; docs 28; build-configs 21; packaging 14; bench-fuzz 8; test-suite 2.
- Row staleness derived rather than assumed: 14 rows, 0 unswept, 0 stale, each checked with `git diff --name-only <row-commit> HEAD -- $(cat .jeffy/probes/<battery>/paths)`. No crate source has changed since 6d960e1, iteration 2's checkpoint, so every row's commit still certifies the code it names.
- Verify command through the installed quiet-verify.sh: green (0s, verify totals: 38 passed, 0 failed). Oracle class and Environment fingerprint re-read; every figure below that lies outside the Verify command is attributed to the hand-run command that produced it.
- `MIRIFLAGS=-Zmiri-strict-provenance cargo +nightly miri test`: exit 0, 36 tests and 2 doctests, no Undefined Behavior.
- MSRV, which the fingerprint says the Verify command does not reach: `cargo +1.68 build` and `cargo +1.68 build --no-default-features` both exit 0.
- Both Settled-class enumerations re-run. `bash .jeffy/probes/build-configs/no-panic-types.sh`: 12 checks, 0 failures. `python3 .jeffy/probes/readme-claims.py`: 14 claims, 0 mismatches, which re-derives every discriminating claim in every battery README by running the command it records.
- The Declined section holds no entries, so there are no Derivations to re-run. No finding ID is named as carried or blocked anywhere in PLAN.md: the three IT- references it carried were historical narrative about closed work, and one of them, a clause on the docs row explaining a re-recording that a later re-recording superseded, is removed rather than left to read as current.

An instrument observation, recorded because it produced four false failures in this very audit and would have produced them for anyone re-running these commands:
- Running `readme-claims.py` concurrently with the 14-battery sweep made test-suite report 2 checks, 1 failure, and made three discriminators report inflated counts - build-configs 15 where it states 1, ci-workflow 8 where it states 2, docs 3 where it states 1.
- Every one of the four reproduced its recorded figure exactly when re-run alone: test-suite 2 checks, 0 failures with 10 of 10 seeded defects caught; build-configs 1; ci-workflow 2; docs 1. The full enumerator was then re-run alone end to end for an unambiguous record: 14 claims, 0 mismatches.
- This is an observer error, not a project defect, and it is filed as neither. It is recorded under Lessons because the evaluator gate re-runs exactly these commands, and a false red there costs an invocation the declaration needs.

Scores, claiming all 14 rows, every one swept and re-run this iteration:
- correctness: None. 35.4 million battery checks, the verify suite and miri all green on the current tree.
- security: None. The crate's unsafe code, including the pointer cast this run added, carries a miri run under strict provenance this iteration.
- testing: None. The suite catches 10 of 10 seeded defects, and every instrument's discriminating claim is re-derived by one command.
- documentation: None. The two claims that did not reproduce at iteration 4 were fixed in iteration 5, and all 14 now reproduce.
- performance: None. Measured at iteration 4 against a tree extracted from 1577ed9: faster on six of seven benchmark groups, with the seventh inside the noise of a short run. No crate source has changed since.
- code quality: None. `cargo clippy --tests --benches -- -Dclippy::all -Dclippy::pedantic` exits 0, run inside build-configs this iteration.
- dependency hygiene: None. Zero runtime dependencies; one optional proc-macro, no-panic 0.1.37, with proc-macro2 1.0.107, quote 1.0.47, syn 3.0.4 and unicode-ident 1.0.24 beneath it.
- architecture, developer experience: None.
- error handling: not applicable - the public API is infallible by construction and has no error path to swallow.
- observability, UX, accessibility: not applicable - a no_std formatting primitive with no user-facing surface.

Zero High and zero Medium in-envelope. Closeout has begun: no further audit and no replenishment for the rest of this run.

Learnings: run one heavy instrument at a time - the batteries and readme-claims.py assert exact counts, and concurrency turned four of them red on a tree where each reproduces its recorded figure exactly. Recorded under Lessons in PLAN.md.

Next: the ledger is empty, the map is swept, and a clean full audit is on this run's record. Iteration 7 brings the standing claims current, invokes the adversarial evaluator as invocation 1 of this run, and on a PASS declares in that same iteration, with three iterations still in hand to answer a REJECT.

## iter 7/10 | fae332c9-133050 | 2026-08-25 | EVALUATOR | audit

Task: the evaluator gate, invocation 1 of this run. Standing claims were brought current in this same iteration first, then one fresh-context sub-agent was spawned as the adversarial evaluator. The verdict is REJECT, on one substantiated Medium in code this run wrote.

Changed: .jeffy/evaluator/fae332c9-133050-1.md (the gate's artifact), BACKLOG.md (IT-8 filed as the REJECT reason; IT-9, IT-10 and IT-11 filed as the three Low observations the gate recorded but did not reject on), JOURNAL.md.

Checkpoint: 36ea7ceecc434355d35e8e8cb284255cb354a3aa. Stall check: not a stall - IT-8, IT-9, IT-10 and IT-11 were added to the ledger, and the gate's artifact is committed at this hash.

Verification:
- Standing claims brought current in this iteration, sequentially rather than concurrently, per the Lesson iteration 6 recorded. All 14 batteries: 35,390,598 checks, 0 failures. `python3 .jeffy/probes/readme-claims.py`: 14 claims, 0 mismatches. `bash .jeffy/probes/build-configs/no-panic-types.sh`: 12 checks, 0 failures. Both Settled-class enumerations return the figures their lines state. The Declined section is empty, so there is no Derivation to re-run. No finding ID is named as carried or blocked in PLAN.md. Surface inventory derived by git: 14 rows, 0 unswept, 0 stale, 0 unreachable. Oracle class and Environment fingerprint re-read.
- Verify command through the installed quiet-verify.sh: green (0s, verify totals: 38 passed, 0 failed).
- Evaluator: REJECT. Artifact at .jeffy/evaluator/fae332c9-133050-1.md, 156 lines, opening with the run-id, ordinal 1 and iteration 7 of 10, listing every command with its real exit status, closing with the verdict, and carrying no machine-absolute path - it defines `$SCRATCH` once and uses it.
- The gate confirmed the run's mechanical claims: verify green, all three closed tasks' acceptance checks passing as written, all 14 batteries totalling the figures the run states, all rows swept and none stale by its own git derivation, both historical no-panic counts re-derived exactly, miri clean under strict provenance and additionally under Tree Borrows, MSRV 1.68 green on a forced recompile.
- The one REJECT reason, verified here independently rather than taken on the sub-agent's word: the SAFETY comment iteration 2 wrote on the sign write claims that no negative value of the type has `$Signed::MAX_STR_LEN - 1` digits in its magnitude. A compiled recomputation of the crate's own formulas - `MAX_STR_LEN = MAX.ilog10() + 2` against `MIN.unsigned_abs().to_string().len()` - prints equal=true for i8, i16, i32, i64 and i128, with `offset` at every `MIN` measured as exactly 1. So the premise is false precisely at the boundary value the comment exists to rule out, and it would not entail `offset >= 1` even if it held. The guard is sound and the code is not changed by this; what is wrong is a justification inside shipped unsafe code, which is the class this run scored Medium when it found it in test READMEs and which is not less serious here. Filed as IT-8.
- Three Low observations the gate recorded and explicitly did not reject on are filed as IT-9, IT-10 and IT-11 rather than fixed here, because an observation that is not a REJECT reason belongs to the next run's ledger and never to the convergence sequence.
- Invocation accounting: this invocation landed at iteration 7 of 10, after the midpoint, so the cap for this run is 2 and exactly one invocation remains. It must be spent on a re-invocation that can declare, which means IT-8 has to close in its own iteration first.

Learnings: none that generalise beyond a rule PLAN.md already carries - a claim that generalises over a set of sites ships with the enumeration of that set in the same iteration. Iteration 2 wrote that sentence about five instantiations without enumerating them, and enumerating it now is what falsified it.

Next: iteration 8 closes IT-8 - correct the bound the comment states and commit the twelve-type enumeration its acceptance names. Iteration 9 re-invokes the gate as invocation 2, the last this run has, and declares on a PASS, leaving iteration 10 spare. IT-9, IT-10 and IT-11 are carried Lows and do not block.

## iter 8/10 | fae332c9-133050 | 2026-08-25 | IT-8 | done

Task: IT-8 (Medium, runtime, docs) - the SAFETY comment iteration 2 wrote on the sign write stated a premise that is false at every type's MIN, the one value it exists to justify. The fix states the true bound and commits the enumeration behind it as a test the Verify command grades, so the sentence is checked rather than believed.

Changed: src/lib.rs (the SAFETY comment on the sign write, comment only), tests/test.rs (test_sign_byte_room), PLAN.md (Oracle class case count and the paragraph describing what the suite grades), BACKLOG.md (IT-8 deleted), JOURNAL.md.

Checkpoint: 73329e789d167992cd64075b27c845c49b82dbce. Stall check: not a stall - src/lib.rs and tests/test.rs changed and IT-8 left the ledger. The ten rows whose batteries were re-run are re-recorded at this hash.

Verification:
- The filed reproduction was run first: a compiled recomputation of the crate's own formulas prints `equal=true` for i8, i16, i32, i64 and i128 - `digits(|MIN|)` is exactly `MAX_STR_LEN - 1` at every width - with `offset` at each MIN measured as 1.
- The comment now says no magnitude has more than `$Signed::MAX_STR_LEN - 1` digits, names MIN as the tightest case, states that offset is 0 after the decrement there, and points at the test that pins it. That is the true bound and it does entail `offset >= 1`, which the old sentence did not.
- Acceptance check: `cargo test --test test test_sign_byte_room` passes. The test enumerates all twelve supported types - the six signed ones for the bound, the tightest case and `format(MIN).len() == MAX_STR_LEN`, and the six unsigned ones for the other half of the same statement, that their widest value fills the buffer exactly because there is no sign to leave room for.
- The check is strong enough to fail, and both directions were provoked. Widening the signed `MAX_STR_LEN` formula by one makes it fail with its own message: `i8: MIN should be the tightest case, one digit short of the buffer, left: 3, right: 4`. Narrowing it by one never reaches the test at all - the `SIGN_LEN` const added in iteration 2 rejects it at compile time with `attempt to compute 19_usize - 20_usize, which would overflow`. That is worth stating plainly rather than claiming the test caught it: the safety bound has two independent guards now, a compile-time one against a buffer too small and this test against the slack being anything other than exactly one byte.
- Contract preserved: src/lib.rs changed by comment only, verified by reading the diff - no signature, behaviour or accepted input moves, and no Surface inventory row is invalidated by it.
- Clippy went red first, exactly as PLAN.md's Lesson warns: a test added to tests/ meets `-Dclippy::pedantic` on its own terms, and `clippy::int_plus_one` rejected `digits <= MAX_STR_LEN - 1`. Adopted clippy's `digits < MAX_STR_LEN`, which is the same bound and cannot underflow, and re-provoked the discriminating failure afterwards so the demonstration is of the form that shipped. `cargo clippy --tests --benches -- -Dclippy::all -Dclippy::pedantic`: exit 0.
- Verify command through the installed quiet-verify.sh: green (1s, verify totals: 39 passed, 0 failed), up from 38 with the new case.
- The count in PLAN.md's Oracle class was a standing claim this iteration invalidated and it is rewritten rather than left: 36 integration cases became 37, and the paragraph describing what an exit status of 0 buys now names the sign-byte enumeration.
- `MIRIFLAGS=-Zmiri-strict-provenance cargo +nightly miri test`: exit 0, 37 tests and 2 doctests, no Undefined Behavior.
- Battery ownership: `grep -l -E '^(src/lib\.rs|tests/test\.rs)$' .jeffy/probes/*/paths` lists ten batteries and all ten were run, all green - signed 12,266,579; unsigned-small 12,065,964; pointer-sized 6,400,299; unsigned-128 2,024,696; buffer-api 600,017; digit-tables 110; integer-trait 44; docs 28; build-configs 21; test-suite 2, still catching 10 of 10 seeded defects. Both Settled-class enumerations re-run because the diff touches files their discriminators mutate and compile: `readme-claims.py` 14 claims, 0 mismatches; `no-panic-types.sh` 12 checks, 0 failures.
- One recovery worth recording: restoring the tree after the discriminating mutation, I mutated my own backup copy with the same sed and then failed to patch it back, leaving src/lib.rs carrying the mutation. Rebuilt it as `git show HEAD:src/lib.rs` plus this iteration's single comment edit, and confirmed by reading `git diff -- src/lib.rs`, which shows the comment hunk and nothing else.
- Closed this iteration: IT-8 (Medium) - the SAFETY claim states a bound that holds, and the twelve-type enumeration behind it runs in the crate's own suite, under CI and under miri, rather than living in a sentence.

Learnings: when a mutation has to be provoked and undone, restore from git plus the iteration's own edit rather than from a scratch copy that the same sed may have touched - copying aside is only safe if the copy is never a sed target. Recorded under Lessons in PLAN.md.

Next: the ledger holds only the three carried Lows the gate observed, IT-9, IT-10 and IT-11, none of which blocks. Iteration 9 brings the standing claims current, spends the run's last evaluator invocation, and declares on a PASS.

## iter 9/10 | fae332c9-133050 | 2026-08-25 | EVALUATOR | converged

Task: the evaluator gate, invocation 2 of 2 and the last this run is permitted, then the declaration. Standing claims were brought current in this same iteration first.

Changed: .jeffy/evaluator/fae332c9-133050-2.md (the gate's artifact), BACKLOG.md (IT-12 filed as one class from the gate's three non-REJECT observations; the Converged line), JOURNAL.md.

Checkpoint: ecbcb0e5bb02a0c1dcc907077caac1d4b59ece2f. Stall check: not a stall - IT-12 was added to the ledger and the gate's artifact is committed at this hash.

Verification, all executed this iteration and sequentially rather than concurrently:
- All 14 batteries: 35,390,598 checks, 0 failures. `python3 .jeffy/probes/readme-claims.py`: 14 claims, 0 mismatches. `bash .jeffy/probes/build-configs/no-panic-types.sh`: 12 checks, 0 failures. Both Settled-class enumerations return the figures their lines state. The Declined section holds no entries. No finding ID is named as carried or blocked in PLAN.md. Surface inventory derived by git: 14 rows, 0 unswept, 0 stale, 0 unreachable. Oracle class and Environment fingerprint re-read, and the fingerprint's toolchain and target claims checked against `rustup toolchain list` and `rustup target list --installed`.
- Verify command through the installed quiet-verify.sh: green (0s, verify totals: 39 passed, 0 failed), and the Oracle class states 37 integration cases plus 2 doctests, which is that total.
- Evaluator: PASS. Invocation 2 of this run, artifact at .jeffy/evaluator/fae332c9-133050-2.md, 261 lines, 50 numbered commands with real exit statuses, opening with the run-id, ordinal and iteration, closing with the verdict, `$SCRATCH` defined once and no machine-absolute path.
- The gate re-derived rather than read: all four closed tasks' acceptance checks pass as written; both journal claims about iteration 8's discriminating mutations reproduce exactly, the widening one failing with the test's own recorded left and right values and the narrowing one rejected at const eval with the recorded E0080; every row commit is an ancestor of HEAD with an empty path diff; both historical no-panic counts re-derive at 3 and 6; miri is clean under strict provenance and additionally under Tree Borrows; MSRV 1.68 is green on forced recompiles. It also provoked readme-claims.py's MISMATCH path, not only its missing-clause path, to confirm the new enumerator can fail.
- Carried Lows, each listed by ID as the closing rule requires, each re-scored by the gate as accurately Low with its premise re-derived true: IT-9, the Settled-classes line phrasing `across all 14 batteries` beside an unrelated 14-claims figure; IT-10, PLAN.md's buffer-api row describing the battery's whole tally as buffer-reuse checks when some of it is not; IT-11, `.github/FUNDING.yml` matching PLAN.md's row-completeness glob while belonging to no battery's paths file.
- IT-12 is filed, not fixed: the gate recorded three stale present-tense sentences in battery READMEs as Low observations and explicitly not as REJECT reasons, so they go to the next run's ledger and the run report. Fixing one inside the convergence sequence would invalidate the PASS and spend an invocation this run no longer has. They are one class - prose describing the tree as it stood before a finding this project closed - so they are filed once. Each was verified here before filing, and the acceptance's own count was corrected from three to four when the grep returned four hits across four files.
- Closing conditions checked one by one. The clean full audit is iteration 6's, which scored zero High and zero Medium across all 14 rows. The Surface inventory lists no unswept row. Now, Next and Later hold no open High and no open Medium; the four open items are Lows with parseable severities on their lines. The commits since that clean audit are 47413ea, 36ea7ce, 0541346, 73329e7 and 6ca11a4 - the gate's own artifact and ledger entries, the fix for IT-8 which the gate itself filed, and loop state edits, and nothing else. The Verify command is green this iteration. The evaluator returned PASS.

Learnings: none new. The rule that earned its keep this run is one PLAN.md already carried - a claim generalising over a set of sites ships with the enumeration of that set - and it is what the gate used to falsify a sentence about five instantiations that had never been enumerated.

Next: nothing. The run is converged and the Converged line is appended under ## Converged in BACKLOG.md. IT-9, IT-10, IT-11 and IT-12 ride to the next run as carried Lows.
