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

## iter 1/10 | d1f7f03c-183640 | 2026-09-01 | AUDIT | audit

Task: First audit of the itertools crate (v0.15.0). Filled the Operating envelope, the Surface inventory, the Verify command block and the Stated counts table, enumerated the artifact-producing channels, probed the whole public surface breadth-first, and filed what reproduced.

Changed: PLAN.md (envelope surfaces, 22 inventory rows, Verify command / Oracle class / Environment fingerprint, Stated counts table, 3 Lessons), BACKLOG.md (IT-1, IT-2, IT-3), .gitignore (loop state, at bootstrap).

Checkpoint: 3557ef5861e2f4f94b11b9989068e1328307a925

Verification:
- Verify command established as `cargo test --all-features` and run through quiet-verify.sh: green (8s). 655 tests pass across 13 integration binaries plus doc-tests; cargo emits no single total line, so Verify summary pattern and Verify count are deliberately left empty rather than recording the doc-test subtotal as a total.
- Artifact channels enumerated by command, not recall: the only packaging channel is Cargo.toml (no package.json, MANIFEST.in, pyproject, gemspec, nuspec, Dockerfile; no publish or release workflow under .github/workflows). `cargo package --list --allow-dirty` lists PLAN.md, BACKLOG.md and JOURNAL.md, so the loop's state files reach the published artifact. Filed as IT-1 (Medium) with its Consequence.
- Breadth-first known-answer probe over all 22 inventory rows, from a scratch crate outside the project: 179/180 checks passed. The one mismatch was the probe's own wrong expectation - `take_while_ref` correctly leaves the failing element in the source iterator - corrected in the probe, not a crate defect.
- Invariant probe over 330 checks: size_hint lower bound <= real count <= upper bound; ExactSizeIterator::len() equal to the real count and still correct after every next(); rev() equal to the forward sequence reversed; nth(k) equal to skip(k).next() for every k up to n+1; fold-based consumption equal to iterative collection (this is what catches a wrong fold specialization). 330/330 passed across combinations, permutations, powerset, cartesian products, merges, dedup, k-selection, tail and the tuple and array adaptors, on inputs of length 5, 1 and 0.
- Stated counts table armed with 3 rows; `check-claims.sh .` reports 3 checked, 0 mismatched, 0 errored, 0 skipped.
- MSRV verified rather than assumed: installed the declared 1.63.0 toolchain and `cargo +1.63.0 check --all-features` exits 0.
- Each filed task's acceptance check was run against the unfixed code and observed to fail: IT-1's grep matches three state files (exit 0), IT-2's `grep -c 'Running unittests'` returns 0, IT-3's clippy exits 101.

Scores (over the breadth and invariant probes only - 0 of 22 Surface inventory rows are swept, so these are not project-wide scores and the unexamined remainder is not claimed):
- correctness: None. 179/180 known-answer checks and 330/330 invariant checks reproduced no defect.
- security: None. Pure library - no network, filesystem, process or deserialization surface; the only unsafe is the internal ArrayBuilder.
- error handling: None. Panics are pinned by should_panic doc examples (zip_eq, chunks) and internal invariants use debug_assert!.
- documentation: None. Every rustdoc example executes and passes under the Verify command.
- architecture: None over what was read.
- testing: Low - IT-2.
- code quality: Low - IT-3.
- developer experience: Low - same root cause as IT-3, not filed separately.
- dependency hygiene: Medium - IT-1. One shipped runtime dependency (either 1.x); dev-dependencies rand 0.7, quickcheck 0.9 and criterion 0.4 are old but never reach a consumer, and no advisory tooling (cargo-audit, cargo-deny) is installed on this host to check them.
- performance: not scored. Benches exist but this audit took no measurement, and a score without one would be an assertion.
- observability: not applicable - an iterator library emits no telemetry.
- UX and accessibility: not applicable - no user-facing surface.

Learnings: The `Command:` payload in PLAN.md must be written bare; quiet-verify.sh hands the value to `bash -c` without stripping backticks, so a fenced command becomes command substitution and the suite's own stdout is executed (exit 127, `running: command not found`). Probes for this crate belong in a scratch cargo crate outside the project, because a probe file under tests/ would change the Verify command's own test count. Many itertools adaptors deliberately implement neither DoubleEndedIterator nor ExactSizeIterator, so an invariant probe that assumes them fails to compile instead of reporting a defect.

Next: IT-1 is the top of the queue (only open Medium, no open High). After it, the 22 unswept inventory rows outrank IT-2 and IT-3; the breadth and invariant probes written this iteration are the starting instrument for those sweeps and need to be committed under .jeffy/probes/ with paths and claims files before any row flips.

## iter 2/10 | d1f7f03c-183640 | 2026-09-01 | SWEEP | done

Task: Sweep the Surface inventory. The queue puts unswept rows above every open task but a High, and the ledger holds no High, so this iteration built the known-answer and invariant batteries for all 22 rows and swept them.

Changed: .jeffy/probes/_crate (a battery crate depending on itertools by path, with 802 checks tagged by row slug), .jeffy/probes/<row>/ x22 (paths, claims, README.md), PLAN.md (2 Lessons; the 22 row flips land in this iteration's bookkeeping edit at the checkpoint hash).

Checkpoint: f5c4f443b37b5dc271a24bacbb55a1ebecb5b92f

Verification:
- Every row's battery is known-answer or invariant, never run-without-crash. Known-answer checks carry a hand-computed or closed-form expected value (binomial counts for combinations, the multiset coefficient for combinations_with_replacement, 2^n for powerset, n!/(n-k)! for permutations). Invariant checks are: size_hint lower <= real count <= upper; ExactSizeIterator::len() equal to the real count and still correct after every next(); rev() equal to the forward sequence reversed; nth(k) equal to skip(k).next() for every k up to n+1; and fold-based consumption equal to iterative collection, which is what catches a wrong fold specialization.
- Documented parameters are exercised at two or more values that must change the output, boundary and negative sides included: chunks at sizes 1, 2, 3 and empty; combinations, combinations_with_replacement, permutations and k_smallest/k_largest at k=0, k=1, k=n and k>n; intersperse and format at two separators; fold and GroupingMap::fold at two inits; every std range shape for get; both comparator directions for merge_by, sorted_by, minmax_by and the GroupingMap _by family. No documented parameter was found inert.
- Each battery was observed failing before it was trusted. 22 source mutations were applied one at a time, the batteries re-run, and the tree restored; each battery's README records the mutation that reddens it and the count it reddens by. Examples: swapping the k_smallest sift helper's child indices reddens 5 of 67; flipping the minmax comparison reddens 8 of 30; making src/group_map.rs prepend instead of push reddens 4 of 14; truncating chain!'s tail arm reddens 2 of 13.
- check-claims.sh reports 25 checked, 0 mismatched, 0 errored, 0 skipped - the 22 battery claims plus the 3 PLAN.md Stated counts rows.
- Verify command green through the wrapper (10s).
- The sweep found no in-envelope defect. Three probe checks that first read red were the probe's own wrong expectations, corrected against the code and its documentation rather than filed: multi_cartesian_product over an empty outer iterator yields one empty vec, which src/lib.rs documents as the nullary cartesian product; and the two ExactlyOneError Display strings are "got at least 2 elements when exactly one was expected" and "got zero elements when exactly one was expected".
- One gap in the instrument was found by the mutation pass rather than by reading it: mutating UniqueBy::size_hint reddened nothing, because the battery had a size_hint check on unique but none on unique_by. Checks for unique_by, duplicates_by and dedup_by were added, after which the same mutation reddens 1 of 36.

Learnings: Restoring src/ from a `cp -a` backup preserves the old mtimes, so cargo serves the artifacts it built from the mutated tree; a battery then reads red on a pristine checkout until the sources are touched. The battery crate must build with CARGO_TARGET_DIR pointed under the root target/, or the nested crate writes .jeffy/probes/_crate/target/, which the root /target gitignore rule does not cover and the checkpoint would commit. A mutation whose replacement is semantically identical (whitespace inside a macro arm) reddens nothing and is not evidence; a mutation that makes size_hint lie can panic every battery at once, which is a crash rather than a countable red.

Next: with the map swept, the queue falls to IT-1 (Medium, the published artifact carrying the loop's state files), then IT-2 and IT-3 (Low).

## iter 3/10 | d1f7f03c-183640 | 2026-09-01 | IT-1 | done

Task: IT-1 (Medium, build-ci, dependency hygiene) - the published .crate carried this loop's state files, because Cargo.toml declared no `exclude` and a Cargo package defaults to shipping the whole tree.

Changed: Cargo.toml (an `exclude` list covering PLAN.md, BACKLOG.md, JOURNAL.md, JOURNAL-archive.md and .jeffy/), .jeffy/probes/*/README.md x22 (rewritten to the form the Stop hook requires), PLAN.md (one Lesson).

Checkpoint: 0ab0a516b6128d99d66274c8d24ad21a17997691

Verification:
- The filed reproduction was run first, as the working rules require, and it had grown since it was filed: `cargo package --list --allow-dirty` listed the three state files and, because iteration 2 committed the probe batteries, 67 files under .jeffy/ as well. A backlog line is a hypothesis and this one had rotted in the direction of being worse.
- Acceptance, both halves, run after the fix: `cargo package --list --allow-dirty | grep -E '^(PLAN|BACKLOG|JOURNAL|JOURNAL-archive)\.md$|^\.jeffy/'` prints nothing and exits 1, and `cargo package --list --allow-dirty | grep -c '^src/lib.rs$'` returns 1.
- Stronger than the acceptance check asks: `cargo package --allow-dirty` exits 0, so the verification build of the packaged crate compiles without the excluded files, and `tar tzf target/package/itertools-0.15.0.crate` finds no state file in the artifact itself. The evidence is the tarball a consumer downloads, not only the file list cargo prints.
- Contract preserved: `exclude` affects packaging alone. Nothing under src/, tests/, benches/ or examples/ reads Cargo.toml, the packaged file count is 91, and the lib target is unchanged.
- Battery ownership: this diff touches Cargo.toml and .jeffy/probes/*/README.md. No battery's `paths` file declares either - all 22 declare src/ paths only - so no swept row is outdated by this change and no row was re-recorded.
- Verify command green through the wrapper (9s). check-claims.sh: 25 checked, 0 mismatched, 0 errored, 0 skipped.
- Instrument correction, not a product change: the Stop hook rejected the battery READMEs iteration 2 wrote, because each stated "<n> of <m> checks red" and no command returns that count. All 22 were rewritten to name the discriminating mutation without quoting a count. The mutations themselves are unchanged and each battery is still one that has been seen to fail.

Closed this run: IT-1 (Medium, build-ci) - published artifact no longer carries the loop's state files, proven against the .crate tarball.

Learnings: A battery README must never write "<n> checks red"; the hook refuses that form because no command returns it, and a "<battery>: x/y checks passed" phrase in a README has to appear verbatim as a claims-file value. Record a discriminating mutation by naming it, not by counting what it reddened. A Cargo package with no `exclude` ships every committed file in the tree, so any file a tool adds at the repository root reaches consumers.

Next: two open Low tasks remain (IT-2, IT-3), which is below the replenishment threshold of 3, and no full audit this run has scored clean - iteration 1's filed a Medium. The next iteration replenishes with a partial audit before working the Lows.

## iter 4/10 | d1f7f03c-183640 | 2026-09-01 | IT-2 | done

Task: IT-2 (Low, test, testing) - Cargo.toml set `[lib] test = false`, so the unit tests inside src/ were compiled by nobody and run by nobody, under the Verify command or in CI.

Changed: Cargo.toml (dropped `test = false` from `[lib]`), src/adaptors/mod.rs and src/next_array.rs (one `#[cfg(feature = "use_std")]` each, on the two test assets that need std), PLAN.md (Oracle class, Environment fingerprint, Stated counts table, one Lesson).

Checkpoint: 38808122f916ad9a3a6e3893d76d11f882dc6fa6

Verification:
- Reproduction first: `cargo test --all-features 2>&1 | grep -c 'Running unittests'` returned 0.
- The one-line fix was not the whole fix. Dropping `test = false` made `cargo test --no-default-features` fail to build the lib target, because src/next_array.rs's test uses `std::panic::catch_unwind` and src/adaptors/mod.rs's uses `vec!`; with `test = false` neither was ever compiled. Trading a silent gap for a build that does not compile would have been the worse defect, so both assets were gated at the narrowest scope that keeps them running wherever std exists.
- The baseline was measured rather than assumed. The fixed files were copied aside, HEAD restored, and `cargo test --no-default-features` and `--no-default-features --features use_alloc` were run there: both already exited 101 before this run touched anything, because the integration tests under tests/ are not gated for reduced feature sets. That failure is pre-existing and untouched by this change; what this change had to avoid was adding a new one in the lib target.
- The lib target was then measured in isolation across all four feature configurations, which is the scope this diff can affect: `--all-features` 6 tests, default 6 tests, `--no-default-features` 4 tests, `--no-default-features --features use_alloc` 4 tests, every one exit 0. The two std-gated assets are the difference between 6 and 4.
- Acceptance: `cargo test --all-features` exits 0, prints one `Running unittests` line, and reports no FAILED result.
- Claims this fix invalidated were re-executed, not left standing: the Oracle class no longer says the command skips the lib unit tests, and the Environment fingerprint was rewritten around a derivation that actually finds the new gates - the old command filtered `feature = "use_(std|alloc)"` lines out and would have hidden them. The fingerprint now names three commands and discloses the two reduced-feature configurations that do not build.
- Stated counts: `lib-only-tests` was renamed `lib-unit-tests` because its meaning changed, and a `use-std-gated-tests` row was added. check-claims.sh reports 26 checked, 0 mismatched, 0 errored, 0 skipped.
- Battery ownership: the diff touches src/adaptors/mod.rs and src/next_array.rs. Matching every changed path against all 22 `paths` files names three batteries - internal-support, itertools-tuples-arrays and sources-put-back - and all three were re-run through run-probe.sh in this iteration and passed. Their rows are re-recorded at this iteration's checkpoint hash in the bookkeeping edit.
- Verify command green through the wrapper (7s).

Closed this run: IT-1 (Medium, build-ci); IT-2 (Low, test) - the 6 unit tests in src/ now execute under the Verify command and in CI, with no feature configuration left unbuildable that built before.

Learnings: Enabling a lib test target compiles the crate's `#[cfg(test)]` code under every feature set, so a test asset using a std or alloc item needs its own feature gate. A fingerprint's derivation command must be re-read when the thing it derives changes: this one filtered out exactly the attribute the fix added, so it would have reported the new gates as absent.

Next: IT-3 (Low, dev-tooling, the clippy gate red on stable) is the last open task. After it the ledger is empty, and the closing full audit and the evaluator gate follow.

## iter 5/10 | d1f7f03c-183640 | 2026-09-01 | IT-3 | done

Task: IT-3 (Low, dev-tooling, code quality) - CI's clippy gate was red on current stable, so a contributor running the project's own gate met four errors before writing a line.

Changed: src/lib.rs, src/adaptors/mod.rs, src/multipeek_impl.rs, src/next_array.rs (eight lint fixes), .jeffy/probes/*/paths x22 (corrected to declare the files each battery's checks actually touch).

Checkpoint: 3cbb55be32fc7fa22bc6b0951446cae7e18c9da5

Verification:
- Reproduction first: `RUSTFLAGS="--deny warnings" cargo clippy --all-targets --all-features` exited 101 with four `clippy::question_mark` errors in src/adaptors/mod.rs, src/multipeek_impl.rs and two in src/lib.rs.
- Fixing those four exposed four more, in the lib test target that IT-2 enabled last iteration: `--all-targets` now builds code clippy had never seen, because `[lib] test = false` had kept it out. One `needless_range_loop` in src/adaptors/mod.rs and three `redundant_pattern_matching` in src/next_array.rs. All four were fixed, because the acceptance check defines the scope and it names `--all-targets`.
- Acceptance: that command exits 0. The other three entries of CI's clippy matrix were run too - default, `--no-default-features`, and `--no-default-features --features use_alloc` - and all exit 0.
- Contract preserved: the four `?` conversions return the same early value on the same input. In `fold_ok` the `?` applies `From::from` to the error, which for E into E is the reflexive impl and therefore the identity, so the propagated `Err` is unchanged; `fold_options` propagates `None` directly; the two adaptor sites return `None` from the same `next()` call they did before. The four test-code fixes change what the assertions are written as, never what they assert.
- The map was found dishonest and was corrected. A row's scope is the paths its battery declares, and `itertools-combinatorics` certifies `cartesian_product` while declaring only combinations.rs, permutations.rs, powerset.rs, multi_product.rs and lazy_buffer.rs - not src/adaptors/mod.rs, where `Product` is defined. This iteration edited that very file, and the row would not have gone stale. Only two batteries declared src/lib.rs, where most Itertools method bodies live. All 22 `paths` files were rewritten to declare the files their checks actually touch, and every file under src/ is now declared by at least one battery, checked with `comm` against `find src -name '*.rs'`.
- Under the corrected paths this diff outdates 18 of the 22 rows. All 22 batteries were re-run through run-probe.sh and all passed, and all 22 rows are re-recorded at this iteration's checkpoint hash in the bookkeeping edit.
- Verify command green through the wrapper (11s). check-claims.sh: 26 checked, 0 mismatched, 0 errored, 0 skipped.

Closed this run: IT-1 (Medium, build-ci); IT-2 (Low, test); IT-3 (Low, dev-tooling) - the project's own clippy gate is green on stable across all four CI feature configurations. The ledger is now empty.

Learnings: A battery's `paths` file is the row's scope, so a battery that omits the file implementing what it certifies produces a row that never goes stale - check the mapping against `find src -name '*.rs'` rather than trusting the scope prose. Enabling a lib test target widens `cargo clippy --all-targets` onto code the linter had never compiled, so a lint fix and a test-target fix arrive together.

Next: the ledger is empty, the map is swept, and no full audit this run has scored clean - iteration 1's filed a Medium. The next iteration is the closing full audit; the evaluator gate and the declaration follow it.

## iter 6/10 | d1f7f03c-183640 | 2026-09-01 | AUDIT | audit

Task: The closing full audit. Every applicable dimension rescored against the severity rubric and the Operating envelope on evidence gathered this iteration, with all 22 Surface inventory rows swept, so these scores claim the whole mapped surface rather than a sample of it.

Changed: .jeffy/probes/_crate/src/main.rs and .jeffy/probes/either-or-both/{claims,README.md} (the insert family, previously undriven, is now covered), BACKLOG.md (IT-4).

Checkpoint: cf57d03b349df663ad9ced0e44d0013a42e0508a

Verification:
- Operating envelope re-derived rather than re-read: `grep -rnE 'std::(net|fs|process|env)|File::|TcpStream|Command::' src/` returns no match, so the surfaces table still describes the project - a library with no network, filesystem, process or environment input.
- Artifact channels re-enumerated by command: Cargo.toml is still the only packaging manifest, there is still no publish or release workflow, and `cargo package --list --allow-dirty` matches no state file, so IT-1's fix holds.
- All 22 batteries re-run at HEAD through run-probe.sh: 849 of 849 checks pass, none red.
- Differential against the pre-run tree, which is the strongest evidence this run's source changes were behaviour-preserving: the base commit was extracted with `git archive`, a second copy of the battery crate was pointed at it, and all 22 batteries were run against both trees. The results are identical on every battery, 830 of 830 checks on both sides - the 830 that existed in both. (An earlier journal entry called that total 802; the measured figure, summed from the claims files, is 830, and 849 after this iteration's additions.)
- Unsafe code examined and driven, not just read. Ten unsafe sites exist, all in src/either_or_both.rs and src/next_array.rs. The three `unreachable_unchecked` calls each sit immediately after a write that makes the following pattern total, so each SAFETY comment is accurate. miri was run on the lib unit tests covering ArrayBuilder - `cargo +nightly miri test --lib --all-features next_array`, 4 tests including the drop-tracking one - and reported no undefined behaviour. What miri was not run over: the doc-tests and the integration suite, which CI covers and this host did not, because `test_checked_binomial` iterates a 500 by 500 table and does not finish under miri in a useful time.
- Testing dimension: ten integration modules were each run alone - arrays, zip, flatten_ok, tuples, merge_join, peeking_take_while, macros_hygiene, adaptors_no_collect, laziness, test_core - and all pass in isolation, so the suite hides no order dependence or leaked state.
- The audit found the map over-claiming and closed it inside this iteration. The either-or-both row certified "the 34 public methods", but the battery drove none of the insert family - the only unsafe in that module - and `insert_both` is driven by nothing in the shipped suite either. Nineteen checks were added covering insert_left, insert_right, insert_both, left_or_insert, right_or_insert, both _with variants and as_mut, across all three variants of the receiver. They were then shown to discriminate: making `insert_both` skip its write when self is already Both reddens `insert_both/from-both`, and the tree was restored.
- Oracle class and Environment fingerprint re-read and their derivations re-run: `grep -c '^test = false' Cargo.toml` finds no such line so the lib test target is built, the use_std-gated test assets return 2, the miri and cfg(test) guards return 8 lines, and `cargo test --all-features --lib` reports 6 passed.
- Gates: Verify green through the wrapper (9s). `RUSTFLAGS="--deny warnings" cargo clippy --all-targets --all-features` exits 0. `RUSTDOCFLAGS="-Dwarnings" cargo doc --all-features` exits 0 with no warning. `cargo bench --no-run --all-features` exits 0. check-claims.sh: 26 checked, 0 mismatched, 0 errored, 0 skipped.

Scores (all 22 of 22 inventory rows swept, so these claim the whole mapped public surface):
- correctness: None. 849/849 battery checks at HEAD, and identical results against the pre-run tree.
- security: None. No network, filesystem, process or deserialization surface; every unsafe site read and its safety argument checked; miri clean over the MaybeUninit code.
- error handling: None. Error types, their Display strings and their std::error::Error impls pinned; the `?` conversions preserve error identity.
- documentation: None. The doc gate exits 0 under -Dwarnings and every doc example executes in the suite.
- architecture: None over what was read.
- dependency hygiene: None. One shipped runtime dependency, either 1.18.0, from `cargo tree --edges normal`; the published artifact carries no state files. No advisory scanner is installed on this host, which is disclosed rather than scored as clean.
- code quality: None. clippy under --deny warnings exits 0 on all four CI feature configurations.
- developer experience: None. The project's own gates - test, clippy, doc, package - are all green.
- testing: Low - IT-4, filed this iteration.
- performance: not scored. The benches compile but this audit took no measurement, and a score without one would be an assertion.
- observability: not applicable - an iterator library emits no telemetry.
- UX and accessibility: not applicable - no user-facing surface.

Zero High and zero Medium in-envelope. Closeout has begun: no further audit and no replenishment for the rest of this run.

Learnings: A battery's coverage claim needs checking against the module's unsafe sites specifically, because unsafe is exactly where an undriven public method costs most - the either-or-both row read as complete while the only three unsafe-bearing methods in its module went untouched by any check.

Next: IT-4 is a Low and does not block a declaration, but it is cheap and closes a real gap in the shipped suite, so the next iteration fixes it; the evaluator gate and the declaration follow.

## iter 7/10 | d1f7f03c-183640 | 2026-09-01 | IT-4 | done

Task: IT-4 (Low, test, testing) - `EitherOrBoth::insert_both` is public API carrying `unsafe { unreachable_unchecked() }`, and nothing in the shipped suite drove it: no test in tests/ and, unlike its siblings insert_left and insert_right, no doc example either.

Changed: src/either_or_both.rs (a `# Examples` block on insert_both, in the style the two sibling methods already use).

Checkpoint: 53249fbe435c511cd91581d4408ed37596cb8d97

Verification:
- Reproduction first: `cargo test --all-features --doc 2>&1 | grep -c 'insert_both'` returned 0, while the same grep for insert_left returned 1.
- The first attempt at this fix was not good enough, and the check that caught it is the one the Method demands. The initial doc example inserted only into a `Left` and a `Right` receiver. Mutating `insert_both` to skip its write when `self` is already `Both` left the doc suite green at exit 0, so the example passed over a broken implementation and proved nothing. A third case was added - overwriting an existing `Both` - and the same mutation then failed the doc-test with exit 101 and one FAILED doc-test named insert_both. The example is evidence now because it has been seen to fail.
- Acceptance: `cargo test --all-features --doc` exits 0, the grep returns 1, and the doc suite reports 211 passed, one more than before this change.
- Contract preserved: this change adds documentation only. No signature, behaviour or accepted input changed, and the diff touches no executable line of the function.
- Battery ownership: the diff touches src/either_or_both.rs, which one battery declares. either-or-both was re-run through run-probe.sh and reports 55 of 55, and its row is re-recorded at this iteration's checkpoint hash in the bookkeeping edit.
- Verify green through the wrapper (9s). check-claims.sh: 26 checked, 0 mismatched, 0 errored, 0 skipped.

Closed this run: IT-1 (Medium, build-ci); IT-2 (Low, test); IT-3 (Low, dev-tooling); IT-4 (Low, test) - the shipped suite now drives every unsafe-bearing method on EitherOrBoth. The ledger is empty and no Low is carried.

Learnings: A doc example written to close a coverage gap is not evidence until it has been observed failing - mutate the documented function and confirm the doc-test reddens, because an example that exercises only the easy receiver is satisfied by a broken implementation.

Next: the ledger is empty, the map is swept at 22 of 22, and iteration 6's full audit scored zero High and zero Medium with closeout declared. The only commits since that audit are this fix for the task that audit itself filed. The next iteration brings the standing claims current, invokes the adversarial evaluator gate for the first time this run, and declares on a PASS.

## iter 8/10 | d1f7f03c-183640 | 2026-09-01 | EVALUATOR | converged

Task: The convergence sequence - bring every standing claim current, invoke the adversarial evaluator gate, and declare on a PASS.

Changed: PLAN.md (the four optional Verify labels cleared from their template placeholders to their honest empty state), .jeffy/evaluator/d1f7f03c-183640-1.md (the gate's artifact), BACKLOG.md (the Converged line, appended in this iteration's bookkeeping edit).

Checkpoint: 4eed79bee4d05a9320d9c11f1acdab5a5a9942d6

Verification:
- Standing claims brought current before the gate was invoked, so no invocation could be spent on a claim this run had already outdated. Row staleness was derived rather than trusted: for every swept row, each path its battery declares was checked with `git diff --name-only <recorded-hash> HEAD -- <path>`, and no row is stale - 22 of 22 swept. BACKLOG.md holds no Declined entry and no Settled class, so there was no Derivation and no enumeration to re-run. PLAN.md names no finding ID as carried or blocked, so nothing dangles. The Oracle class and Environment fingerprint were re-read and all four of their derivations re-run: no `test = false` line in Cargo.toml, use_std-gated test assets return 2, tests binaries return 13, miri guards in test_std return 5. The Verify count cell carries no figure because `cargo test` emits no single total line, which is the condition PLAN.md says to leave it empty for; the three sibling optional labels were cleared of template prose in the same edit so nothing in the receipt reads as content that is not.
- check-claims.sh: 26 checked, 0 mismatched, 0 errored, 0 skipped. Verify green through the wrapper (11s).
- Evaluator: PASS - one fresh-context sub-agent, invocation 1 of this run, re-derived the base premises rather than accepting them, ran the 22-battery differential itself and got byte-identical output on both trees at 849 of 849, and proved the instrument falsifiable by deleting a line from base multipeek and watching a battery redden.
- What the gate checked and reported: the Verify command exits 0 with 662 tests across 15 targets; all four acceptance checks pass at HEAD exactly as filed; IT-1's reproduction, reconstructed against the base Cargo.toml with the loop files present, prints 70 paths and exit 0, and swapping in HEAD's Cargo.toml alone flips it to exit 1, isolating the `exclude` key as the fix; the real .crate tarball carries none of those paths; base clippy exits 101 with the four errors IT-3 named; base `Running unittests` returns 0 and base `insert_both` returns 0; IT-4's doc example fails at exit 101 under a mutation of the function it documents. It re-scored every closed task and agreed with each severity, checking specifically whether IT-3's Low hid a user-facing consequence given its fix touched three shipped source files, and found the identical differential says it does not.
- Five observations the gate recorded, every one scored Low and none a REJECT reason. They are not fixed here: a fix after a PASS invalidates that PASS and spends an invocation the declaration needs. They go to the run report and to the next run's ledger. (1) .jeffy/probes/either-or-both/README.md still says nothing drives insert_both, which iteration 7 falsified. (2) The EitherOrBoth inventory row's prose ends "the part the shipped suite leaves undriven", falsified by the same commit. (3) No wrapper-measured verify total is on record, so that cross-check is unarmed. (4) IT-4's acceptance grep would count a FAILED line naming insert_both; only its trailing green-suite clause closes that. (5) `cargo test --no-default-features` and `--features use_alloc` do not build - identical at base, pre-existing, and already disclosed in the Environment fingerprint.

Closing conditions, each verified this iteration: iteration 6's full fresh-evidence audit scored zero High and zero Medium in-envelope and declared closeout; the Surface inventory lists no unswept and no stale row at 22 of 22; Now, Next and Later hold no open task at all, so no Low is carried; the only commits since that clean audit are iteration 7's fix for IT-4, which that audit itself filed, plus loop state edits; the Verify command is green this iteration; and the evaluator returned PASS with its artifact committed by this iteration's checkpoint.

Learnings: Bringing the standing claims current before invoking the gate is what let a single invocation carry the declaration - the gate spent none of itself on a row, a count or a derivation the run had already outdated.

Next: none. The run converged at this iteration; the Converged line naming this checkpoint is appended under ## Converged in BACKLOG.md.
