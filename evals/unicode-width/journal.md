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

## iter 1/10 | de26a3ba-142344 | 2026-09-01 | AUDIT | audit

Task: First audit of the `unicode-width` crate. Filled the Operating envelope, the Surface inventory, and the Verify command block in PLAN.md; enumerated the artifact-producing channels; probed every inventory row shallowly, breadth-first; filed findings.

Changed: PLAN.md (envelope surfaces, 14 inventory rows, Verify command / Oracle class / Environment fingerprint / duration / summary pattern / count, one Stated counts row, three Lessons), BACKLOG.md (UW-001 in Next, UW-002 and UW-003 in Later), .gitignore (bootstrap: `.claude/jeffy-loop.local.md`), plus the three bootstrapped state files.

Checkpoint: 12d35e2408feef78dd164a0de93c6e426e59f2b0. Not a stall: this iteration added task lines to BACKLOG.md and also changed `.gitignore`, which is not a state file.

Verification: `bash <jeffy>/hooks/lib/quiet-verify.sh PLAN.md` green, 3s, `verify totals: 78 passed` (39 tests x two feature configurations). `check-claims.sh` reports `claims: 1 checked, 0 mismatched, 0 errored, 0 skipped`. Reproduction for UW-001: `cargo package --allow-dirty --no-verify`, extract, `cargo test` in the extracted tree exits 101 with `emoji_test_file` panicking at `tests/tests.rs:578` on `File::open("tests/emoji-test.txt")`; the same suite exits 0 in the working tree.

Artifact channels: enumerated by command, not by recall. `git ls-files` shows exactly one packaging manifest (`Cargo.toml`) and one workflow file (`.github/workflows/rust.yml`); there is no package.json, MANIFEST.in, pyproject, gemspec, nuspec, Dockerfile or release/publish workflow (`git ls-files | grep -icE 'package.json|MANIFEST.in|pyproject|gemspec|nuspec|Dockerfile'` returns 0, and the only workflow job set is build/regen/msrv, none of which archives the tree). The single channel is `cargo package`, and `cargo package --list --allow-dirty` returns a 20-entry list containing no PLAN.md, BACKLOG.md, JOURNAL.md, JOURNAL-archive.md or `.jeffy/` path, because the manifest's `include` list admits only COPYRIGHT, the two licenses, README.md, `src/**/*.rs`, `benches/**/*.rs` and `tests/**/*.rs`. The loop's state files cannot reach the published artifact. That same `include` list is what UW-001 is about, from the other direction.

Audit scores, against the severity rubric and the Operating envelope. These claim only what this audit's shallow probes reached: no Surface inventory row is swept, because a sweep needs an executed committed battery under `.jeffy/probes/` and none exists yet.
- correctness: None. Probed all 1,114,112 codepoints in 34 distinct right-hand state contexts (2 width modes each): no panic, no wraparound, maximum width seen 5, zero results above the per-context bound. Documented ligature rules checked against the sets `lib.rs` names - Arabic Lam-Alef over all 8 Lam and 8 Alef codepoints with and without an intervening transparent mark, the Khmer coeng set in full plus every in-block character outside it, Tifinagh left and right consonant ranges enumerated by probe, Buginese, Hebrew, Lisu, Old Turkic, Kirat Rai - all agree with the documentation. Insertion of each of 10 ligature-transparent characters at every position of each of 7 non-Arabic ligatures left every width unchanged, which is the documented invariance claim. 1000-fold repetition of each ligature unit accumulates linearly.
- security: None. `#![forbid(unsafe_code)]`, no I/O, no allocation, no runtime input beyond `char`; `grep -rnE 'std::|env::|File::|fs::|unsafe' src/*.rs src/gen/lookup.rs src/gen/props.rs src/gen/width_info.rs` returns no match. The only network access in the tree is the maintainer-run generator.
- architecture: None. Generated and hand-written code are separated under `src/gen/`, and the hand-written `lookup_width` documents its coupling to the generator's table shape.
- code quality: None on the surface probed. `cargo clippy --lib --tests` and the `--no-default-features` form are clean under `-D warnings`; `cargo fmt --check` is clean.
- testing: None as a runtime finding; the suite is unusually strong for a library of this size (two whole-codespace loops plus a full NormalizationTest.txt replay plus the emoji conformance corpus). Every test module also passes in isolation (`--lib`, `--test tests`, `--doc`, and a single filtered test), so nothing here depends on cross-module ordering. The gap is UW-001, which is about the artifact rather than the suite.
- documentation: Low. UW-003. The `lib.rs` rule list is accurate everywhere this audit checked it, including the two rules easiest to get wrong (text-presentation sequences excluded for the Enclosed Ideographic Supplement block, and the quote/variation-selector widths that differ between modes).
- dependency hygiene: None. Two optional dependencies, both `rustc-std-workspace-*` shims, neither reachable in a normal build.
- developer experience: Low. UW-002.
- build-ci: Medium. UW-001.
- performance: None examined beyond confirming the benchmarks compile on nightly; no evidence gathered, so this is silence rather than a clean score.
- error handling: not applicable. The crate has one fallible-looking API (`width` returning `Option`) and it is total over its domain; there are no error paths to swallow.
- observability: not applicable. A `no_std` pure-function library has no runtime observability surface.
- UX and accessibility: not applicable. No user-facing surface; the crate is a library with no binary.

Learnings: `cargo` lives at `$HOME/.cargo/bin` and is absent from the default PATH here, so every verify and probe command must export it. `cargo clippy --all-targets` and `cargo test --all-features` both reach configurations this project does not ship - the nightly-only benchmarks and the `rustc-dep-of-std` shims respectively - and neither is the gate. The published-artifact check has to be run, not read: the `include` list looks complete until you extract the tarball and run the suite inside it.

Next: UW-001 is the top of the queue as the only open Medium; after it, the fourteen unswept inventory rows outrank the two open Lows.

## iter 2/10 | de26a3ba-142344 | 2026-09-01 | SWEEP | done

Task: Sweep the Surface inventory. The queue put the map above the open Mediums, so this iteration built a battery for every row, observed each one failing under a discriminating mutation, and swept the rows the batteries certify.

Changed: .jeffy/probes/ - a shared harness (`harness/`, ten Rust batteries behind one binary, plus `lib.sh` for the shell batteries) and fourteen battery directories, each with `run.sh`, `paths`, `claims` and a README recording the mutation it was observed failing on. BACKLOG.md: UW-005 filed in Next, UW-004 filed in Later, UW-002 deleted as subsumed. PLAN.md: thirteen inventory rows flipped to swept in the bookkeeping edit.

Checkpoint: e23f597e8e397e9a8d9d16632e2eb9b6860a7ec1. Not a stall: thirteen Surface inventory rows changed state and two BACKLOG.md task lines were added.

Verification: `bash <jeffy>/hooks/lib/quiet-verify.sh PLAN.md` green, 4s, `verify totals: 78 passed`. Every battery run through `check-claims.sh`: thirteen MATCH, one ERROR (packaging-and-ci, which is red on the defect UW-005 describes and whose row is therefore left unswept), plus the PLAN Stated counts row MATCH.

Mutation evidence, one per battery, each applied to the tree, the battery re-run, and the file restored from a copy - never `git checkout`, and `git status --porcelain` was empty afterwards. Every battery exited 1 under its own mutation: the ASCII fast path under `c >= '\u{20}'` narrowed to `c > '\u{20}'`; the tables under a middle-table mask of `0x1F` instead of `0x3F`; the fold under a `'\r'` arm returning 1 instead of 0; the Arabic ligature under an unreachable `is_joining_group_lam` guard; the Brahmic ligatures under a Khmer coeng arm returning 0 instead of -1; Tifinagh/Lisu/Old Turkic under a Lisu range narrowed by one codepoint; the emoji sequences under a ZWJ arm returning 1 instead of 0; the variation selectors under a swapped `IS_CJK` expression; the predicates under `'\u{34F}'` removed from `is_ligature_transparent`; the API surface under a changed `UNICODE_VERSION`; the generator battery under a bumped version constant in `scripts/unicode.py`; the packaging battery under `"PLAN.md"` added to `include`; the docs battery under a changed README install snippet; the test-assets battery under a truncated `tests/emoji-test.txt`.

Generator determinism, run once against the live UCD rather than left as a standing claim: a clean export of HEAD into a scratch directory, `rm tests/emoji-test.txt && cd scripts && python3 unicode.py`, then `diff -rq` against this tree. The generator exited 0 and both diffs were empty, so the checked-in `src/gen/*.rs` and `tests/emoji-test.txt` are byte-identical to what the generator produces from unicode.org today. The battery itself stays offline, because an instrument that errors whenever the host has no network reports the network rather than the project.

Findings this sweep surfaced, both filed at rubric severity:

UW-005 (Medium, build-ci). The packaging battery went red the moment the loop wrote its first `.jeffy/probes/*/README.md`. Cargo matches `include` entries with gitignore semantics, so a pattern carrying no slash is unanchored and matches at any depth: `README.md` in the list selects every README in the tree. `cargo package --list --allow-dirty` on this tree returns a listing whose first fourteen entries are the loop's battery READMEs. The shape of the fix was checked in a scratch copy of the tree - anchoring the five bare filenames with a leading slash restores the listing to exactly the entries the crate wants - but the fix is not applied here, because a sweep batches rows and never findings. That check also folds in UW-002: `"CARGO.toml"` becomes `"/Cargo.toml"` in the same edit, so UW-002 was deleted from the ledger as subsumed rather than left to be closed twice.

UW-004 (Low, docs). The generator battery's new mask-versus-array-width checks pass, but writing them exposed that the comments beside those masks do not. `TABLE_SPLITS = [7, 13]` drives every expression in the emitted `lookup_width`, and the middle sub-table is therefore six bits wide and sixty-four bytes long - the emitted type is `Align64<[[u8; 64]; WIDTH_MIDDLE_LEN]>` and the mask is `0x3F` - while the comment above it says seven bits and one hundred and twenty-eight bytes. The leaf comment says six bits where the leaf spans seven bits of codepoint. Both literals are hardcoded in the emitter template that surrounds them with derived values. Scored Low because a user of the shipped product never reads them; the rubric's ceiling by class puts a docs finding with no user consequence there.

Rows swept: thirteen of fourteen. packaging-and-ci is left unswept because its battery is red on UW-005, and a row whose battery does not pass certifies nothing.

Learnings: cargo's `include` entries are gitignore patterns, so a bare filename is unanchored and a leading slash is what pins it to the package root - which is why the loop's own probe directory reached the package listing here. A battery has to be run before its row is claimed: the packaging battery was written expecting to pass and immediately found a live leak that the first audit's by-hand check had correctly reported clean one commit earlier. Battery build output belongs in `$CARGO_TARGET_DIR` under the temp directory, never in the repository, or `git add -A` sweeps a target tree into the checkpoint.

Next: UW-005 is the top of the queue - it is a Medium and its fix unblocks the one unswept row - then UW-001, then the two carried Lows.

## iter 3/10 | de26a3ba-142344 | 2026-09-01 | UW-005 | done

Task: UW-005 - the `include` list in `Cargo.toml` published every file matching a bare filename anywhere in the tree, so the loop's own `.jeffy/probes/*/README.md` files were in the package listing.

Changed: Cargo.toml (the `include` list, eight entries anchored with a leading slash and the dead `CARGO.toml` entry corrected to `/Cargo.toml`). BACKLOG.md: UW-005 deleted as closed, one Settled classes line added. PLAN.md: the packaging-and-ci row swept and the docs-and-readme row re-recorded, both in the bookkeeping edit.

Checkpoint: 8661f2c5b1c9de31fb634f5d0e587f1e150d169d. Not a stall: Cargo.toml changed, one BACKLOG.md task line was removed, and one Surface inventory row changed state.

Verification: the filed reproduction ran first and still reproduced - `cargo package --list --allow-dirty` returned fourteen `.jeffy/` paths and `bash .jeffy/probes/packaging-and-ci/run.sh` exited 1 on the unfixed tree. After the fix the same battery exits 0 with `packaging-and-ci: 9/9 checks passed`, and the listing is the twenty entries the manifest intends with no `.jeffy/` path among them. `bash <jeffy>/hooks/lib/quiet-verify.sh PLAN.md` green, 4s, `verify totals: 78 passed`. Battery ownership: the diff touches `Cargo.toml`, which is declared by `packaging-and-ci/paths` and by `docs-and-readme/paths`; both were run through `run-probe.sh` and both exit 0 (`docs-and-readme: 8/8 checks passed`).

Closed: UW-005 (Medium, build-ci) - `include` entries anchored; the package listing carries no loop state. It also closed UW-002 (Low, build-ci), which was the same list's dead `CARGO.toml` entry and was deleted from the ledger as subsumed in iteration 2.

Enumeration behind the class claim, built by provoking the leak at every entry rather than by reading the manifest: in a clean export of HEAD, a file of each of the five bare-filename names was planted in its own subdirectory, and `src`, `benches` and `tests` trees were planted under a nested directory. The package listing then carried all five planted bare-filename files and none of the three planted source trees, so the leak is exactly the entries with no slash, and the three slashed patterns were already anchored. After anchoring all eight, the same probe tree publishes none of them. That is the whole set; the Settled classes line records the derivation command, which returns 0 on this tree and returned 8 against the manifest at the commit before the fix.

Contract preserved: this changes packaging metadata only. No public function's behaviour, signature or accepted inputs move, and the published file set is unchanged from what the manifest already intended - the root COPYRIGHT, both licences, the root README, the manifest, and the three source trees. The three slashed patterns were anchored too, though they did not leak, because a list where some entries are anchored and some are not is exactly the trap that produced this defect; a reader should not have to know gitignore anchoring rules to audit it.

Learnings: cargo's `include` and `exclude` take gitignore patterns, so an entry with no slash matches at any depth and an entry with a slash is anchored to the package root; anchor every entry explicitly. A packaging claim is only worth what the listing says: the enumeration here was built by planting files and reading `cargo package --list`, never by reasoning about the patterns, and the first attempt at the derivation command was wrong in a way only the negative control caught.

Next: UW-001, the remaining Medium - `tests/emoji-test.txt` is still absent from the published artifact.

## iter 4/10 | de26a3ba-142344 | 2026-09-01 | UW-001 | done

Task: UW-001 - the published crate shipped `tests/tests.rs` without `tests/emoji-test.txt`, so `cargo test` on the crates.io artifact failed at the one test that reads a data file.

Changed: Cargo.toml (`/tests/**/*.txt` admitted to the `include` list). .jeffy/probes/packaging-and-ci/ (a check that the package carries the data its tests read, its claims line, and its README). BACKLOG.md: UW-001 deleted as closed, one Settled classes line added. PLAN.md: two swept rows re-recorded in the bookkeeping edit.

Checkpoint: b3b59206fa7fc25627f259620b63c9e9ab732540. Not a stall: Cargo.toml changed and one BACKLOG.md task line was removed.

Verification: the filed reproduction ran first and still reproduced - packaging HEAD, extracting it and running `cargo test` in the extracted tree exited 101 with `emoji_test_file` panicking at `tests/tests.rs` on `File::open("tests/emoji-test.txt")`, and the extracted `tests/` directory held only `tests.rs`. After the fix the acceptance check as filed exits 0 and the packaged suite reports 1, 36 and 2 passing across its three binaries. `bash <jeffy>/hooks/lib/quiet-verify.sh PLAN.md` green, 4s, `verify totals: 78 passed`. `check-claims.sh` reports `claims: 15 checked, 0 mismatched, 0 errored, 0 skipped`. Battery ownership: the diff touches `Cargo.toml`, declared by `packaging-and-ci/paths` and `docs-and-readme/paths`; both were run through `run-probe.sh` and both exit 0.

Closed: UW-001 (Medium, build-ci) - the artifact now carries the corpus, and its suite is green when built from the package rather than from the repository.

The packaging battery was updated in the same iteration as the behaviour it pins, per battery ownership: it now asserts the listing carries `tests/emoji-test.txt`, its claims line moved to the new total, and its recorded discriminating mutation was re-observed against the edited battery - with `"PLAN.md"` added to `include`, it exits 1 on the loop-state check.

Cost of the fix, measured rather than assumed: the crate archive grows from 207,874 to 267,246 bytes, about 29 percent, because the corpus is 669,326 bytes of highly compressible text. That is the price of a suite that is green for whoever builds from the artifact, and the alternative - letting the test skip when its input is missing - would have weakened a conformance check in exactly the configuration distributors build, which the Constraints forbid.

Enumeration behind the class claim: the sites are the paths the test tree opens or embeds, listed by grepping `tests`, `src` and `benches` for `File::open`, `include_str!` and `include_bytes!` arguments, and each is checked for membership in the real `cargo package --list` output rather than against the manifest patterns. That enumeration returns exactly one site today, `tests/emoji-test.txt`; the count of listed sites the package does not carry is 0 on this tree and was 1 against the manifest at the commit before the fix. The Settled classes line records that command, and the fix is class-complete rather than instance-specific: `/tests/**/*.txt` admits any future test data file of the same form.

Contract preserved: packaging metadata only. No public function's behaviour, signature or accepted inputs move, no test was weakened or deleted, and the file set the crate publishes gains exactly the one data file its own shipped suite reads.

Learnings: a packaging fix is only proved by unpacking the artifact and running the suite inside it; the manifest pattern looking right is not the check. A battery that pins a listing must be updated in the same iteration as the listing changes, and its recorded mutation re-observed afterwards, or the instrument silently stops covering the thing it was written for.

Next: the ledger is at the severity floor - UW-003 and UW-004 are the only open items, both Low - and the map is fully swept. The evaluator gate is due while its verdict can still be answered.

## iter 5/10 | de26a3ba-142344 | 2026-09-01 | AUDIT | audit

Task: The closing full audit. Iteration 1's audit scored a Medium, so the run had no clean full audit on record and could not reach the closing rule; this one rescores every applicable dimension against the severity rubric and the Operating envelope with evidence executed this iteration.

Changed: BACKLOG.md (UW-006 filed in Later). No source file changed.

Checkpoint: 05c8be75055ee66b2bce3edad54fc71710980089. Not a stall: this iteration changed only state files and no Surface inventory row moved, but a BACKLOG.md task line was added, and an AUDIT entry is a ceremony entry that never forms a stall pair.

Verification: `bash <jeffy>/hooks/lib/quiet-verify.sh PLAN.md` green, 3s, `verify totals: 78 passed`, which is the figure the Verify count cell carries. `check-claims.sh` reports `claims: 15 checked, 0 mismatched, 0 errored, 0 skipped`. All fourteen batteries were executed through `run-probe.sh` this iteration and every one exits 0; their claims lines sum to 790 checks, derived from the claims files rather than counted by hand. Staleness was derived, not assumed: for every swept row, `git diff --name-only <recorded commit> HEAD` over that battery's own `paths` file returns nothing, so no row is stale and none is unswept. Both Settled classes enumerations were re-run and still return what their lines state - unanchored `include` entries returns 0, and test-data sites the package listing does not carry returns 0. The Environment fingerprint's exclusion command was re-derived and still returns 1. There are no Declined entries to re-derive, and PLAN.md names no finding ID as carried or blocked.

Closeout has begun. This audit scored zero High and zero Medium in-envelope, so the run stops auditing: no replenishment and no further full audit, whatever budget remains.

Audit scores, each against evidence executed this iteration. All fourteen inventory rows are swept and none is stale, so these scores claim the whole mapped surface rather than a sample of it.
- correctness: None. The fourteen batteries ran clean, and beyond them a fresh whole-codespace sweep drove every codepoint through thirty-four distinct right-hand state contexts in both width modes - 75,759,616 evaluations - with no panic, a maximum observed width of 5, and no result above the per-context bound. The count of codepoints answering None is 65, exactly the thirty-two C0 controls, DEL, and the thirty-two C1 controls.
- security: None. `#![forbid(unsafe_code)]` is present and the only occurrence of the token `unsafe` anywhere in the library source is that attribute itself. No library source file references `std::`, `env::`, `File::` or `fs::`, so the crate performs no I/O and reads nothing from its environment. `cargo tree -e normal` lists the crate alone: no normal dependency, and therefore no dependency with a known vulnerability.
- build-ci: None, where iteration 1 scored Medium. Both Mediums are closed and their instruments hold: `cargo package` with its verification build exits 0, the packaged crate compiles and its suite is green, and the package listing carries no loop-state path while carrying the data its shipped tests read.
- testing: None as a runtime finding. The suite is green in three feature configurations - default, `--no-default-features`, and `--no-default-features --features cjk` - and every test binary passes in isolation, which the test-assets battery re-checked this iteration.
- code quality: None. `cargo fmt --check` clean; `cargo clippy --lib --tests` clean under `-D warnings` in both the default and no-default configurations.
- documentation: Low. UW-003 and UW-004 stand, both docs class with no user consequence. `cargo doc --no-deps` is clean under `-D warnings`, and the docs-and-readme battery re-checked every claim the README and the `lib.rs` preamble make about the crate.
- dependency hygiene: None. Two optional dependencies, both `rustc-std-workspace-*` shims, neither reachable in a normal build.
- developer experience: Low. UW-006, filed by this audit.
- performance: None, and this time with evidence rather than silence. `cargo +nightly bench` completes and the synthetic benchmarks land where a table lookup should - about 2.0 microseconds for four thousand ASCII characters, within noise of the two hand-written `simple_width_*` baselines the file carries for comparison and slightly faster than the standard library's own. No performance finding.
- architecture: None. Generated and hand-written code stay separated under `src/gen/`, and the coupling between them is now pinned by a battery rather than by a comment.
- error handling: not applicable. The one fallible-looking API returns `Option` and is total over its domain; there are no error paths to swallow.
- observability: not applicable. A `no_std` pure-function library has no runtime observability surface.
- UX and accessibility: not applicable. No user-facing surface; the crate is a library with no binary.

Filed by this audit: UW-006 (Low, dev-tooling). Running the benchmarks for performance evidence is what surfaced it. The three data-driven benchmarks read their corpus with `unwrap_or_default()`, and `bench_data/` is gitignored and fetched by hand, so on a fresh checkout `enwik8`, `jawiki` and `emoji` measure the empty string and print a timing that reads as a result. The differential is clean: `enwik8` reports about 1.2 ns/iter with the directory absent and about 209,800 ns/iter with a 200 KB file planted there, and the planted file was removed afterwards. Scored Low by the severity ceiling by class, which puts a dev-tooling finding at Low always because a user of the shipped product never runs a benchmark.

Learnings: a dimension scored None without a command behind it is silence wearing a score - running the benchmarks to earn the performance line is exactly what turned up UW-006, and iteration 1 had scored that dimension on nothing but the fact that the benchmarks compiled.

Next: the ledger is at the severity floor with three carried Lows, the map is fully swept, and a clean full audit is now on this run's record. The evaluator gate is due next, with budget left to answer a REJECT.

## iter 6/10 | de26a3ba-142344 | 2026-09-01 | EVALUATOR | converged

Task: The evaluator gate and, on its PASS, the declaration. The closing conditions were already true when this iteration opened - a clean full audit on this run's record from iteration 5, a fully swept map, and a ledger at the severity floor - so the gate was invoked and the run declared in the same iteration.

Changed: BACKLOG.md (UW-007, UW-008 and UW-009 filed in Later from the gate's Low observations; the Converged line appended in the bookkeeping edit). .jeffy/evaluator/de26a3ba-142344-1.md written by the evaluator and committed by this iteration's checkpoint. No source file changed.

Checkpoint: 07ce6756cc0b16cd5ad4f464398622c789293e37. Not a stall: this iteration changed only state files and no Surface inventory row moved, but three BACKLOG.md task lines were added, and an EVALUATOR entry is a ceremony entry that never forms a stall pair.

Verification: `bash <jeffy>/hooks/lib/quiet-verify.sh PLAN.md` green, 3s, `verify totals: 78 passed`, equal to PLAN.md's Verify count cell. `check-claims.sh` reports `claims: 15 checked, 0 mismatched, 0 errored, 0 skipped`. Standing claims were brought current before the invocation, not after it: staleness re-derived from every battery's own `paths` file against its recorded commit returns fourteen rows swept, zero stale, zero unswept; both Settled classes enumerations re-run and still return 0; the Declined section holds no entry to re-derive; the Environment fingerprint's exclusion command re-derived and still returns 1; the one finding ID PLAN.md names, UW-006, resolves to an open ledger line that still holds it; and the Oracle class and Environment fingerprint were re-read, including the line that says the nightly-only benchmarks are outside what the gate grades - nothing in this entry claims they were.

Evaluator: PASS - invocation 1 of this run, iteration 6 of 10, artifact `.jeffy/evaluator/de26a3ba-142344-1.md` with forty-one commands and their real exit statuses. It reproduced both closed Mediums at the base commit and confirmed both fixed at HEAD: `cargo package --list` at 832f7ca returns fourteen `.jeffy/probes/*/README.md` paths and the packaging battery exits 1 there, against 10/10 at HEAD; the packaged artifact at 832f7ca fails `cargo test` with `emoji_test_file` panicking on the missing corpus, against a green suite at HEAD. It read the diff for regressions and found the packaged file sets differ by exactly one added path, `tests/emoji-test.txt`, with nothing dropped, and it re-observed the packaging battery's recorded mutation still reddening it. It re-scored both closed Mediums as accurately Medium and all carried findings as accurately Low.

Carried Lows, each by ID:
- UW-003 (Low, docs): the README changelog's newest heading is 0.2.0 while the crate ships 0.2.2, so two released versions are undocumented there.
- UW-004 (Low, docs): the lookup template in `scripts/unicode.py` hardcodes table geometry in comments that `TABLE_SPLITS` contradicts; the gate confirmed these are `//` comments inside a `pub(crate)` function body, not rustdoc.
- UW-006 (Low, dev-tooling): the three data-driven benchmarks measure the empty string when `bench_data/` is absent, which is its default state.
- UW-007 (Low, dev-tooling): the packaging battery names the one shipped data file rather than deriving the set, so the Settled line's class-completeness claim outruns its instrument.
- UW-008 (Low, docs): that Settled line's enumeration matches three call forms and misses `std::fs::read_to_string`, so it is narrower than the sentence it derives.
- UW-009 (Low, docs): the `packaging-and-ci` inventory row still describes the pre-iteration-4 check set.

UW-007, UW-008 and UW-009 are the gate's own Low observations, filed rather than fixed: a fix after a PASS invalidates that PASS and spends an invocation the declaration needs.

One correction the gate's fourth observation prompts, recorded here rather than by editing iteration 4's entry: the archive sizes that entry states, 207,874 growing to 267,246 bytes, were measured by `cargo package` inside this repository, while the gate measured 207,777 growing to 267,120 from a `git archive` export. Both are real; they differ by about a hundred bytes because `Cargo.lock` and `.cargo_vcs_info.json` differ between the two, and the roughly twenty-nine percent growth the entry reports is the same either way.

Learnings: bringing the standing claims current before invoking the gate rather than after is what kept this invocation from being spent on the run's own bookkeeping - the gate re-derived staleness, both settled enumerations and the Verify count independently, and every one already matched.

Next: the run is converged. The three findings this run closed are UW-005, UW-001 and UW-002; six accurately scored Lows are carried to the next run, which will open with a fresh audit rather than a ratchet, because the ledger is not empty.
