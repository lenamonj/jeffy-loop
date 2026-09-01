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

## iter 1/10 | 89e44a56-014605 | 2026-08-31 | AUDIT | audit

Task: First audit. Fill the Operating envelope, the Surface inventory and the Verify command block in PLAN.md, enumerate the artifact-producing channels, then probe the whole public surface breadth-first and file what it finds.

Changed: PLAN.md (envelope surfaces, 8 inventory rows, Command / Oracle class / Environment fingerprint / Verify duration / Verify summary pattern / Verify count), BACKLOG.md (5 findings: 2 Medium, 3 Low). No product code touched.

Checkpoint: 0c093ba32730d9664c52049bb05c794f27066f4e (not a stall: this iteration added five task lines to BACKLOG.md, and an AUDIT entry is exempt regardless)

Verification: `bash .../hooks/lib/quiet-verify.sh PLAN.md` green, `verify totals: 47 passed`, 1s, and the wrapper's own count 47 equals the Verify count cell.

Artifact channels, enumerated by command, not recall: the only packaging manifest in the tree is Cargo.toml and the only workflow is .github/workflows/rust.yml, which builds, tests, lints and diffs regenerated files but never packages or publishes. `cargo package --list --allow-dirty` returns .cargo_vcs_info.json, COPYRIGHT, Cargo.lock, Cargo.toml, Cargo.toml.orig, LICENSE-APACHE, LICENSE-MIT, README.md, four benches/*.rs, five src/*.rs, tests/test.rs and tests/testdata/mod.rs - PLAN.md, BACKLOG.md, JOURNAL.md and .jeffy/ appear nowhere, because Cargo.toml carries an `include` allowlist rather than an exclude list. That same allowlist is what P1-01 is about: it admits benches/**/*.rs and no bench data.

Audit evidence, breadth-first, every row probed shallowly before any deep dive:
- grapheme-cursor: a differential driver in a scratch crate outside this repo fed GraphemeCursor chunk by chunk at sizes 1 to 6, forward via next_boundary and backward via prev_boundary, answering PreContext and NextChunk/PrevChunk, and compared the boundary offsets against `graphemes()`; 10 hand-picked strings plus 4000 proptest cases over an 18-codepoint alphabet chosen for the hard rules (RI pairs, ZWJ emoji, InCB linkers, Prepend, CR/LF, Hangul jamo). All matched, both extended and legacy.
- graphemes-iter, word-bounds, unicode-words, sentences: an invariant battery over 23 inputs - the 8 bench corpora truncated to 20000 chars plus 15 hand-picked strings - checked concatenation for graphemes/words/sentences, index offsets equal to prefix sums for all four indices iterators, unicode_sentences equal to split_sentence_bounds filtered by alphanumeric content, unicode_words equal to unicode_word_indices, reverse iteration equal to reversed forward for words/word indices/graphemes, size_hint bounding the true count, and as_str returning the untouched remainder after three steps. No failures.
- tables-lookup: the crate's Alphabetic_table and N_table were expanded to code point sets in Python and compared against sets dumped from std by a Rust program on this toolchain. Alphabetic 147421 code points on both sides, N 1924 on both sides, symmetric difference empty in both. This matters because tables::util dispatches to std when std's Unicode version equals the crate's, so the two paths must agree or output would depend on the compiler; they agree exactly.
- packaging-generators: `python3 scripts/unicode.py` in a clean temp directory downloads the six UCD files and emits tables.rs byte-identical to src/tables.rs; `python3 scripts/unicode_gen_breaktests.py` likewise emits testdata.rs byte-identical to tests/testdata/mod.rs. Both regeneration claims CI makes hold today.
- MSRV: `rustup run 1.85.0 cargo build` and `rustup run 1.85.0 cargo test` both exit 0, so the rust-version = "1.85.0" claim in Cargo.toml holds.
- CI-equivalent lints: `RUSTFLAGS=-D warnings cargo clippy --all-targets --all`, `cargo fmt --all --check` and `RUSTDOCFLAGS=-D warnings cargo doc --no-deps` all exit 0 with no output.
- One probe failure was my driver's, not the library's, and is recorded here so a later iteration does not re-file it: feeding next_boundary a chunk that does not contain the cursor panics inside the slice at src/grapheme.rs rather than returning the documented GraphemeIncomplete::InvalidOffset that is_boundary returns for the same condition. The documented contract says the chunk must contain the codepoint after the cursor, and the envelope classes those arguments user-error, so this is not filed; the corrected driver, which selects the chunk containing the cursor, found no mismatch.

Scores, claiming only what the evidence above reached - all 8 Surface inventory rows are still unswept, no battery is committed yet, so every None below is silence on the unexamined remainder rather than a clean bill for the project: correctness None on what was probed, security None (`#![deny(unsafe_code)]`, no I/O, zero runtime dependencies), architecture None, code quality None, dependency hygiene None for the library, testing Low (P1-03, P1-04), error handling Low (P1-05), documentation Medium (P1-02), developer experience Medium (P1-01), performance not scored - no measurement was taken this iteration, observability not applicable to a no_std segmentation library that emits no logs or metrics, UX and accessibility not applicable - the crate has no user-facing surface.

Learnings: cargo is not on PATH in a non-login shell on this host, so the Verify command exports $HOME/.cargo/bin itself. `cargo test` prints three separate `test result:` lines (lib unit, integration, doc), so the Command sums them with awk into one `verify totals: N passed` line for the wrapper to quote. Probes must run from a scratch crate outside this repository, depending on it by path, so that no test file lands in a tree the checkpoint would commit. Network is reachable from this host, so the UCD generators and rustup toolchain installs are runnable here.

Next: P1-01, then P1-02, then the inventory rows, which outrank the three open Lows in the queue.

## iter 2/10 | 89e44a56-014605 | 2026-08-31 | SWEEP | done

Task: Sweep the Surface inventory. The map outranks every open Medium and Low, and all 8 rows were unswept, so this iteration built one committed battery per row and flipped the rows the batteries can actually evidence.

Changed: .jeffy/probes/ - eight batteries, each with probe.rs or run.sh, paths, claims, README.md and a mutate.sh, plus three shared runners under _common/ (run.sh builds a battery in a scratch cargo crate outside the tree, mutate.sh and mutate-tree.sh apply a recorded mutation to a clean export of HEAD, at-commit.sh runs a battery against an older commit). PLAN.md: 7 rows flipped to swept. BACKLOG.md: P2-01 filed. No product code touched - the whole diff is .jeffy/, PLAN.md and BACKLOG.md.

Checkpoint: d81cbf1d93b2894625d654a432086fa2015220b7 (not a stall: seven Surface inventory rows changed state and one task line was added to BACKLOG.md)

Verification: quiet-verify green, `verify totals: 47 passed`, 1s. check-claims over all 8 batteries: 16 rows checked, 14 MATCH, and packaging-generators ERROR plus MISMATCH, which is that battery reporting the defect it found rather than an instrument fault - see below.

Batteries and their discriminating evidence. Every one records a change it was observed catching, because an instrument never seen to fail reads exactly like an instrument that passed; the green and reddened figures are both claims lines that check-claims executes:
- graphemes-iter 266/266, reddened to 263/266 by breaking GB3.
- grapheme-cursor 44462/44462, reddened to 43986/44462 at 9a42b9d~1 - the commit before PR #172, "Fix GB11 case on a chunk boundary". This one is not an invented mutation: the battery catches the real defect that PR fixed, in the surface that carries the crate's two most recent correctness fixes and had no test outside its four doc-examples.
- word-bounds 124/124, reddened to 122/124 by disabling WB3d. Only the two known-answer checks see it; concatenation and the index invariants hold whatever the boundaries are, which is the whole argument for known-answer checks over invariants on a row like this.
- word-ascii-fastpath 48321/48321, reddened to 44276/48321 by dropping the underscore from the ASCII scanner's word core.
- unicode-words 94/94, reddened to 86/94 by narrowing the documented filter to ASCII digits.
- sentences 104/104, reddened to 103/104 by disabling SB3.
- tables-lookup 10/10, reddened to 9/10 by deleting the A-Z range from Alphabetic_table - the table stays sorted and disjoint, so only the differential against std sees it.
- packaging-generators 14/15 on this tree, reddened to 13/15 by adding PLAN.md to the include allowlist.

Finding surfaced by the sweep, filed at rubric severity in this iteration: P2-01 (Medium). Writing eight battery READMEs made a latent Cargo.toml defect manifest. Four `include` entries - COPYRIGHT, LICENSE-MIT, LICENSE-APACHE and README.md - are unanchored gitignore-style globs matching at any depth, so `cargo package --list` now carries eight `.jeffy/probes/*/README.md` paths and the loop's own memory is inside the published artifact. Enumerated by experiment rather than by reading the manifest: a clean export of HEAD with those four names planted in a subdirectory publishes all four, while a nested Cargo.toml does not, because cargo skips sub-packages - so the claim is narrowed to the four names actually verified. Iteration 1's channel check passed honestly and was still incomplete: it asked what the tree publishes today, not what the allowlist admits.

Rows: 7 of 8 swept at this iteration's checkpoint. packaging-generators stays unswept because its battery is red, and it is red because P2-01 is open - the row certifies what the artifact carries, and the artifact carries the loop's state. Its claims record what the battery returns today (14/15 green, 13/15 mutated), so check-claims will keep reporting ERROR for it until P2-01 closes; both figures are re-measured in the iteration that closes it. The bench-data gap P1-01 names is reported by that battery, not asserted, because asserting a defect already open in the ledger would leave the instrument red forever and turn every later Cargo.toml edit into a verify failure.

Learnings: a battery must certify the contract the tree has today and never duplicate an open ledger item as a standing assertion, or it is red forever and every iteration that touches its paths reads as a verify failure. Battery probes build in a scratch cargo crate under $TMPDIR with a path dependency on the project, never inside the tree, because the checkpoint commits with git add -A. Expectations that spell Unicode strings must use escapes, not literal characters: the first graphemes-iter run failed on a precomposed e-acute where the rustdoc example uses e plus a combining acute. A packaging allowlist is checked by asking cargo what it admits, not by reading the manifest - the manifest looked correct for a whole iteration.

Next: P2-01, which is both the blocking Medium and the only thing keeping the last inventory row unswept; then P1-01, then P1-02, then the three Lows.

## iter 3/10 | 89e44a56-014605 | 2026-08-31 | P2-01 | done

Task: P2-01 (Medium, build-ci) - Cargo.toml's `include` allowlist used unanchored gitignore-style globs for its bare-name entries, so each matched a file of that name at any depth and the loop's own battery READMEs were inside the published crate.

Changed: Cargo.toml - the five bare-name include entries COPYRIGHT, LICENSE-MIT, LICENSE-APACHE, Cargo.toml and README.md now carry a leading slash, which anchors them to the package root. The three glob entries already contained a slash and were already anchored, so they are untouched. PLAN.md: the packaging-generators row flipped to swept, four Lessons added. BACKLOG.md: P2-01 deleted. .jeffy/probes/packaging-generators: mutate.sh re-pointed at the anchored line and both claims re-measured.

Checkpoint: 4be1e3bc0526843b6ce4d3f7da6e3aacf4442773 (not a stall: Cargo.toml changed, P2-01 was removed from BACKLOG.md and an inventory row changed state)

Verification: quiet-verify green, `verify totals: 47 passed`, 1s. check-claims over all eight batteries: 16 checked, 0 mismatched, 0 errored, 0 skipped.

Closed: P2-01 (Medium) - `cargo package --list --allow-dirty` returns 19 paths and none under `.jeffy/`, while README.md, COPYRIGHT and both licences are still carried; the acceptance check `bash .jeffy/probes/packaging-generators/run.sh` exits 0 on the fixed tree and exits 1 with `FAIL published artifact excludes .jeffy` when pointed at the unfixed tree, so the check is strong enough to fail.

Class, not instance: the fix anchors every bare-name entry rather than the one that had a live instance. Enumerated by experiment on the fixed tree - all five names planted in a subdirectory, `cargo package --list` publishing none of them - where the same experiment on the unfixed tree published four of the five (a nested Cargo.toml was never published, because cargo skips sub-packages).

Contract preserved: the published file set is byte-for-byte the set the crate shipped before .jeffy/ existed - 19 paths, the same 19 iteration 1 recorded from `cargo package --list`. Anchoring narrows what the allowlist admits and adds nothing, so no consumer loses a file.

Rows: 8 of 8 swept. packaging-generators went green the moment the defect it found was fixed, which is the row's own evidence that the instrument tracks the artifact rather than the manifest.

Learnings: a fix that edits the exact line one of the loop's own mutation scripts targets must re-point that sed and re-measure the claim in the same iteration - the mutation degraded to `unavailable:sed-matched-nothing` until it was re-pointed, and a mutation that matches nothing reports no failure at all, which reads exactly like an instrument that passed. Anchoring a packaging allowlist is checked by asking cargo, never by reading the manifest: the manifest read as correct through a whole iteration while it was publishing the loop's memory.

Next: P1-01, the remaining Medium - the published crate ships bench targets without benches/texts - then P1-02, then the three Lows.

## iter 4/10 | 89e44a56-014605 | 2026-08-31 | P1-01 | done

Task: P1-01 (Medium, build-ci) - the published crate shipped the four criterion bench targets while Cargo.toml's include list carried no glob for benches/texts/, the data those targets read at runtime, so `cargo test --all-targets` inside the extracted tarball panicked at benches/chars.rs and exited 101 while the same command passed in the repository.

Changed: Cargo.toml - `benches/**/*.rs` removed from the include list, so the artifact carries neither the bench targets nor their data instead of one without the other. PLAN.md: the packaging-generators row re-recorded at this checkpoint, because Cargo.toml is one of that battery's declared paths. BACKLOG.md: P1-01 deleted. .jeffy/probes/packaging-generators: the bench-data condition promoted from a reported observation to an executed assertion, with both claims re-measured.

Checkpoint: 3b2d701d4a634c5e8e8f568e1bb17638a98543b8 (not a stall: Cargo.toml changed and P1-01 was removed from BACKLOG.md)

Verification: quiet-verify green, `verify totals: 47 passed`, 2s. check-claims over all eight batteries: 16 checked, 0 mismatched, 0 errored, 0 skipped.

Closed: P1-01 (Medium) - the acceptance check as filed, `cargo package --allow-dirty --no-verify` then extract then `cargo test --all-targets` in the extracted 1.13.3 tarball, now exits 0 where iteration 1 measured it exiting 101.

Which fix, and why deletion rather than addition: the two candidates were to ship benches/texts/ or to stop shipping the bench targets. The data is 425560 bytes against a 109818-byte crate, so shipping it would roughly quintuple the download for every consumer of the library; it is third-party material under CC-BY-SA 3.0 (Wikipedia) and Apache-2.0 (Neovim source) per benches/texts/README, a licensing surface distinct from the crate's own MIT OR Apache-2.0; and a bench target is something no dependent ever builds, since cargo does not build a dependency's benches. Deleting beats adding, and nothing usable is lost: the benches were already non-functional in the tarball, and `cargo build --benches` still exits 0 in the repository, which is where benchmarking happens.

Contract preserved: cargo strips the four `[[bench]]` sections from the packaged manifest when their sources are not included, so the published Cargo.toml declares no target it cannot build - checked by reading the extracted manifest, which carries no `[[bench]]` section at all. `cargo package --allow-dirty` with full verification, the path `cargo publish` takes, exits 0. The artifact went from 109818 to 109015 bytes.

The new assertion is strong enough to fail: pointed at a tree whose include list re-adds `benches/**/*.rs` without the data, the battery prints `FAIL no bench target ships without its benches/texts data` and drops to 15/16. That is the check the README said would arrive with the fix, and it is what stops a bench target being re-added without what it opens at runtime.

Learnings: when a battery reports a condition rather than asserting it because the defect is open in the ledger, the iteration that closes that defect is the one that promotes the report to an assertion and re-measures both claims - otherwise the fix lands and the instrument that found it still cannot see a regression.

Next: P1-02, the last Medium - README.md's Change Log has no 1.13.3 entry - then the three Lows, then the evaluator gate.

## iter 5/10 | 89e44a56-014605 | 2026-08-31 | P1-02 | done

Task: P1-02 (Medium, docs) - README.md's Change Log had no 1.13.3 section although Cargo.toml declares version 1.13.3, so the newest entry was 1.13.2 and the GB11 chunk-boundary fix that shipped in 1.13.3 was unrecorded in the artifact users read on crates.io and docs.rs.

Changed: README.md - a 1.13.3 section added above 1.13.2, listing the five pull requests that release contains. PLAN.md: one Lesson. BACKLOG.md: P1-02 deleted.

Checkpoint: 09a9848b5397a64b1c90bdfa7ecab47f2050b69e (not a stall: README.md changed and P1-02 was removed from BACKLOG.md)

Verification: quiet-verify green, `verify totals: 47 passed`, 1s. packaging-generators re-run because README.md is in the published artifact, 16/16, though no battery declares README.md among its paths so none was owed.

Closed: P1-02 (Medium) - `grep -q '^## 1.13.3' README.md` exits 0 and the section names #172, which is the acceptance as filed.

The entry's contents are derived, not recalled. The two version-bump commits were located with `git log -S'version = "1.13.x"' -- Cargo.toml`: 1.13.2 is d446fa8 and 1.13.3 is 66a032f. `git log d446fa8..66a032f` returns exactly six commits - the bump itself and #166, #167, #168, #169, #172 - and the new section names those five. Both directions were checked: every pull request the section names is in that range, and every commit in that range other than the bump is named by the section, so the entry is neither inventing nor omitting.

One thing checked and found not to be a defect: the 1.13.2 entry credits #164 with setting a 1.85 MSRV while commit d446fa8's own title says 1.84. The commit's diff adds `rust-version = "1.85.0"` and `git log -G'rust-version = ' -- Cargo.toml` returns that commit alone, so the changelog is right and the commit title is wrong - which is what #169, "Update couple of mistakes in the changelog", was for. Nothing to file.

Scope held: #175, #176 and #178 sit on master unreleased, and no changelog section claims them, which is correct for a changelog of released versions. They belong to whatever version publishes next, and adding a heading for them here would be inventing a release.

Learnings: derive a changelog entry from the commit range between two version bumps located by their Cargo.toml diff, never from commit titles - in this repository the 1.13.2 bump rides on a commit whose title is about MSRV and states the wrong number.

Next: the ledger is at the severity floor with three Lows open - P1-03, P1-04, P1-05. Work them in that order, then a full fresh-evidence audit, then the evaluator gate. No full audit this run has yet scored clean: iteration 1's found the two Mediums that iterations 4 and 5 just closed.

## iter 1/10 | 3e59c682-042321 | 2026-09-01 | P1-03 | done

Task: P1-03 (Low, test) - the chunked `GraphemeCursor` / `GraphemeIncomplete` API had no test outside its four rustdoc examples, although the crate's two most recent grapheme correctness fixes, #172 (GB11 on a chunk boundary) and #175 (GB12/GB13 when the RI count is already known), both live in exactly that code.

Reproduction, run first: `grep -rl GraphemeCursor src tests` returns src/lib.rs and src/grapheme.rs, and `grep -rn 'GraphemeCursor\|GraphemeIncomplete' tests` returns nothing at all. The finding held.

Changed: tests/test.rs - one new integration test, `test_grapheme_cursor_chunked`, which drives the cursor forward and backward at every chunk size from 1 to 6, in both modes, over TEST_SAME, TEST_DIFF and nine extra strings chosen for the rules that need context across a chunk boundary (GB11 ZWJ sequences, regional-indicator runs, an InCB conjunct, Prepend, SpacingMark, CRLF), asserting the boundaries it reports equal the ones the contiguous `graphemes()` iterator reports. PLAN.md: Verify count 47 to 48, one Lesson. BACKLOG.md: P1-03 deleted.

Checkpoint: a9692d88b85bb1e3abc834b49b18186b8e0b8f06 (not a stall: tests/test.rs changed and P1-03 was removed from BACKLOG.md)

Verification: quiet-verify green, `verify totals: 48 passed`, 2s. `cargo fmt --check` and `cargo clippy --all-targets` both clean, and `cargo +1.85.0 test` - the MSRV job's own command - exits 0 at 48 passed, so the new test costs neither CI job.

Closed: P1-03 (Low) - the acceptance as filed. The test passes at HEAD and fails when src/ is replaced by src/ from 9a42b9d~1: `forward cursor disagrees with graphemes(true) on "a<RI><RI><RI>b" at chunk size 1, left [1, 5, 13, 14], right [1, 9, 13, 14]`.

The check is strong enough to fail, and against both fixes rather than one. Against src/ from 5dfedef~1 - after #172, before #175 - it fails on the same regional-indicator disagreement, so it sees #175's defect. Narrowing the corpus to the two ZWJ strings isolates the other half: that corpus passes at HEAD and fails at 9a42b9d~1 with `disagrees ... on "\u{1f468}\u{200d}\u{1f467}\u{200d}\u{1f466}" at chunk size 1, left [7, 14, 18], right [18]` - the family emoji split three ways instead of one, which is #172's defect exactly. The narrowed corpus was a scratch edit, measured and reverted; the committed test carries the full corpus.

What the existing suite could not see: with the new test skipped, `cargo test` against src/ from 9a42b9d~1 exits 0 at 10, 8 and 23 passed. Both defects were live in that tree and the whole existing suite was green over them, because no iterator test ever splits its input.

Contract preserved: the change is additive and touches no shipped code. No Surface inventory row moved - the diff is tests/test.rs alone, which no battery's paths file declares, so no battery was owed and no row went stale.

Learnings: restoring a temporarily swapped-out `src/` with `cp -a` preserves the old mtimes, so cargo judges the crate up to date and the next `cargo test` grades the previous tree's binary instead of the restored one. That produced a run in which the same corpus appeared to fail at HEAD and pass nowhere; every before/after pair here was re-measured with `touch src/*.rs` and accepted only when `Compiling` appeared in the output. A rebuild nobody checked for is a measurement of the wrong tree.

Next: P1-04, the sentence-surface test, then P1-05, then a full fresh-evidence audit - no audit this run has scored anything yet - then the evaluator gate.

## iter 2/10 | 3e59c682-042321 | 2026-09-01 | P1-04 | done

Task: P1-04 (Low, test) - the sentence surface was the thinnest tested of the three: `tests/test.rs::test_sentences` drove only `split_sentence_bounds` forward against TEST_SENTENCE, and no quickcheck pinned the concatenation promise that `split_sentence_bounds` documents, though graphemes and words each have one.

Reproduction, run first: `grep -rn 'split_sentence_bound_indices\|unicode_sentences' tests/` returns nothing outside tests/testdata, and the five quickcheck properties are the two grapheme ones, join_graphemes, forward_reverse_words and join_words - none for sentences. The finding held.

Changed: tests/test.rs - a new `test_sentence_bound_indices_and_concatenation` asserting, across TEST_SENTENCE, that the bounds pieces concatenate back to the input and none is empty, that `split_sentence_bound_indices` yields exactly the prefix sums of those pieces paired with the pieces themselves, that each offset locates its own piece by slicing the original string, and that `unicode_sentences` equals those pieces filtered by the documented Alphabetic-or-Number predicate; plus `quickcheck_join_sentences` pinning the concatenation promise over arbitrary strings. PLAN.md: Verify count 48 to 50, one Lesson. BACKLOG.md: P1-04 deleted.

Checkpoint: 804d7c81c26849eea00aa4aab5299eaecb15a2dc (not a stall: tests/test.rs changed and P1-04 was removed from BACKLOG.md)

Verification: quiet-verify green, `verify totals: 50 passed`, 1s. `cargo fmt --check` and `cargo clippy --all-targets` clean, `cargo +1.85.0 test` - the MSRV job's command - exits 0.

Closed: P1-04 (Low) - the acceptance as filed, both halves. Inverting the concatenation assertion fails with `split_sentence_bounds does not concatenate back to "\r\r"`; inverting the prefix-sum assertion fails with `split_sentence_bound_indices disagrees with split_sentence_bounds on "\r\r"`. The other two assertions were inverted as well and both fail.

An inverted assertion is a weak witness, so the test was also run against four mutations of the implementation, and the value it adds over the existing suite is one of them. Dropping the Number half of the documented `unicode_sentences` predicate - filtering on Alphabetic alone - leaves all 23 doc-tests green and the whole existing integration suite green at 9 passed, and is caught only by the new test, on the corpus string `"\r0"`. That is the gap the finding named: the two indices and filtering iterators were reached only by rustdoc examples over one 42-byte ASCII English sentence with no digits, so a predicate half that only fires on digits was untested. Three further mutations - offsets shifted by one, the filter made unconditional, and single-byte pieces dropped from the bounds iterator - are all caught by the new test too; the first two are also caught by the doc examples and the third by the existing `test_sentences`, so only the digit mutation is exclusive to this test.

On the independence of the filter check: the test spells the documented predicate with std's `char::is_alphabetic` and `char::is_numeric`, while the crate uses `tables::util::is_alphanumeric`. Per the Environment fingerprint that function takes its std branch on this host, because `char::UNICODE_VERSION` equals the crate's, so today the check pins the contract rather than differentially comparing two datasets; on a toolchain whose Unicode version differs it becomes a real differential against the crate's own table fallback.

Contract preserved: additive, and no shipped code was touched. The diff is tests/test.rs alone, which no battery's paths file declares, so no battery was owed and no Surface inventory row went stale.

Learnings: this crate is `edition = "2018"`, where an `assert!(cond, "message with {x:?}")` carrying no trailing argument is not treated as a format string - clippy's `non_fmt_panics` fires on it and CI runs `cargo clippy --all-targets --all`. `assert_eq!` messages and `panic!` calls that already carry arguments are unaffected, which is why iteration 1's test did not hit it.

Next: P1-05, the last open task - `scripts/unicode.py::fetch` accepting an HTTP error body as UCD data - then a full fresh-evidence audit, then the evaluator gate.

## iter 3/10 | 3e59c682-042321 | 2026-09-01 | P1-05 | done

Task: P1-05 (Low, dev-tooling) - `scripts/unicode.py::fetch` shelled out to `curl -O` with neither `-f` nor a status check, so an HTTP error response landed under the expected filename and the `os.path.exists` guard immediately after it passed. The generator then parsed the error page as UCD data.

Reproduction, run first: `curl -sS -O https://www.unicode.org/Public/17.0.0/ucd/NoSuchFile.txt` exits 0 and leaves a 196-byte HTML 404 page named NoSuchFile.txt; calling the shipped `fetch('NoSuchFile.txt')` in an empty directory returns normally with that file present and the interpreter exiting 0. The finding held exactly as written.

Changed: scripts/unicode.py - `fetch` hoists the URL out of the two branches, passes `curl -f` so an HTTP error is a nonzero exit and no body is saved, tests the exit status, removes any partial file, writes the URL it could not fetch to stderr and exits 1. The two stderr messages also gained the trailing newline they lacked. PLAN.md: the packaging-generators and tables-lookup rows re-recorded, since scripts/unicode.py is in both batteries' paths. BACKLOG.md: P1-05 deleted, one Settled classes line.

Checkpoint: 548b6c1ee992b4f7f30bea8917f4a32d5a109e6e (not a stall: scripts/unicode.py changed and P1-05 was removed from BACKLOG.md)

Verification: quiet-verify green, `verify totals: 50 passed`, 1s. Both owed batteries re-run through run-probe.sh: tables-lookup 10/10, packaging-generators 16/16 - the latter regenerates src/tables.rs and tests/testdata/mod.rs from unicode.org and diffs them against the committed files, so the fixed generator is confirmed byte-identical in output.

Closed: P1-05 (Low) - the acceptance as filed. `fetch('NoSuchFile.txt')` in an empty directory now exits 1, prints `cannot fetch https://www.unicode.org/Public/17.0.0/ucd/NoSuchFile.txt`, and leaves no file of that name behind.

Class, not instance: the idiom is an unchecked external-command error path, and its enumeration is `grep -rn "os.system\|subprocess\|popen" scripts/`, which before the fix returned two lines, both inside `fetch`, one per URL branch. Both were measured defective against the pre-fix file - `NoSuchFile.txt` and `emoji-NoSuchFile.txt` each exited 0 with a 196-byte 404 page present - and both are fixed: the same two calls now exit 1 with no file left behind. The enumeration returns one line today, because the fix collapsed the two branches into one status-checked call.

Positive controls, so the fix is not merely a refusal: `fetch` still downloads ReadMe.txt (740 bytes) on the plain branch, emoji-data.txt (107324 bytes) on the emoji branch, and the nested auxiliary/GraphemeBreakProperty.txt (99377 bytes), and a second call on an already-present file still short-circuits without a request. The end-to-end control is packaging-generators, which runs both generator scripts for real and diffs their whole output against the tree.

Contract preserved: `fetch` keeps its signature, its basename-based caching and its stdout, and both readers still open `os.path.basename(f)`. What changed is only the failure path, from silently accepting an error body to exiting 1. No Rust code was touched and the Verify count is unchanged at 50.

Learnings: none new this iteration.

Next: BACKLOG.md now holds no open task and no full audit this run has scored anything, so the next iteration is the closing full fresh-evidence audit, then the evaluator gate, then the declaration if it comes back clean.

## iter 4/10 | 3e59c682-042321 | 2026-09-01 | AUDIT | audit

Task: full fresh-evidence audit. BACKLOG.md held no open task, all 8 Surface inventory rows were swept and none stale, so this is the closing audit the Definition of done requires. It is not clean: it files one High, so closeout has NOT begun and the run needs a second full audit after the fixes land.

Changed: BACKLOG.md - A1 filed under Now, A2 and A3 under Later. No source file was touched.

Checkpoint: e1fcf14951ce2fc03ebc38d3774cc4fa237224cc (an AUDIT that filed three findings, so no stall and no ceremony exemption needed: BACKLOG.md gained three task lines)

Verification: quiet-verify green, `verify totals: 50 passed`, 1s. All 16 battery claims re-executed through check-claims.sh: 16 checked, 0 mismatched, 0 errored, 0 skipped - every battery at its full count and every discriminating mutation still reddening by the recorded amount, which is the fresh evidence behind the swept rows.

Evidence gathered this audit, all executed:
- 588 panic probes: 28 edge inputs (empty, one and two ASCII bytes, NUL, CR, CRLF, a lone combining mark, ZWJ, one and two regional indicators, Prepend, SpacingMark, an InCB conjunct, Hangul, a tag sequence, a format character, an apostrophe, a Hebrew quote, and others) crossed with 21 public call shapes across all three surfaces, in a debug build with overflow checks on. Exactly 3 panicked, all the empty string on the sentence surface, all one root cause. Nothing else panicked anywhere.
- Test isolation, which the Method requires before scoring Testing clean: each of the five integration tests run alone, the lib unit target alone (16 passed), the doc-test target alone (23 passed). No order dependence and no leaked state.
- `cargo fmt --check`, `cargo clippy --all-targets` and `cargo doc --no-deps` all clean; `cargo +1.85.0 test` green at the declared MSRV.
- The README's fenced Rust example extracted and run verbatim: exits 0, so the documentation is accurate; it is simply not wired to any test target.
- Environment fingerprint re-derived by its own recorded command: the only hits are the two `#[cfg(test)]` module gates in src/lib.rs and src/word.rs, so the exclusion list is still none. Oracle class re-read against a real run: 16 lib, 11 integration, 23 doc, summing to the Verify count of 50.
- Dependency resolution read from cargo rather than the manifest, and latest stable versions read from the crates.io API.

Scores, claiming all 8 of 8 swept rows and no unexamined remainder:
- correctness: High - A1.
- code quality: Low, folded into A1 rather than filed apart: the same expression wraps both branches in `cmp::max(0, ...)`, which on `usize` is a no-op that reads as saturation and hides the underflow sitting beside it. Same line, same root cause, so it is one finding.
- testing: Low - A2. The suite is green whole, per test and per target.
- dependency hygiene: Low - A3. Zero runtime dependencies, so no runtime dependency can carry a vulnerability; the three dev-dependencies never reach a user of the shipped product.
- security: None. `#![deny(unsafe_code)]`, zero `unsafe` in src including the generated tables, zero runtime dependencies, no I/O in the library, and the 588-probe sweep produced no crash outside A1. No vulnerability scanner is installed on this host - cargo-audit, cargo-deny and cargo-outdated are all absent - so this score rests on the dependency shape rather than on an advisory database, and that limit is stated rather than hidden.
- architecture: None. Three segmentation modules, one generated table module, one public trait; no coupling or layering defect found.
- error handling: None. The `GraphemeIncomplete` paths are exhaustively differentialled by the grapheme-cursor battery, including the InvalidOffset answer.
- documentation: None. rustdoc builds without a warning under `#![deny(missing_docs)]`, the README example is correct as written, the changelog's newest section matches the manifest version, and the documented `unicode_sentences` predicate is now pinned by a test.
- performance: None, with its evidence limit stated: no timing measurement was taken this audit, and the word-ascii-fastpath battery certifies that the fast path agrees with the general path, not that it is faster. Nothing is claimed about speed.
- developer experience: None. Six CI jobs, both generators re-run against unicode.org and diffed byte-identical this run.
- observability: not applicable - a pure segmentation library with no logging, metrics or error-reporting surface.
- UX and accessibility: not applicable - no user-facing surface; the crate ships no CLI and no UI.

Filed: A1 (High, runtime, correctness) - the empty-string `size_hint` underflow, reproduced in both profiles. A2 (Low, test, documentation) - the README example no test target compiles. A3 (Low, dev-tooling, dependency hygiene) - criterion resolving to 0.5.1 against a latest stable of 0.8.2.

On A1's severity: the Operating envelope classifies `&str` content passed to the `UnicodeSegmentation` methods as adversarial, the empty string is realistic in-envelope input, and the rubric puts a crash on realistic in-envelope input at High. Release builds do not crash but return a hint whose lower bound exceeds its upper bound, which is a documented contract violation callers turn into allocations. No downgrade rationale exists that the envelope does not contradict.

Learnings: none new this iteration.

Next: fix A1, then A2 and A3, then a second full fresh-evidence audit - this one was not clean, so it cannot be the audit a declaration cites - then the evaluator gate and the declaration. Six iterations remain, which fits that sequence.

## iter 5/10 | 3e59c682-042321 | 2026-09-01 | A1 | done

Task: A1 (High, runtime, correctness) - `USentenceBounds::size_hint` subtracted 1 from the inner hint's lower bound on `usize`, and that bound is 0 for an empty string, so three public calls panicked in debug and returned a lower bound above their own upper bound in release.

Reproduction, run first: `"".split_sentence_bounds().size_hint()`, `"".split_sentence_bound_indices().size_hint()` and `"".unicode_sentences().size_hint()` each panicked at HEAD in a debug build. The finding held.

Changed: src/sentence.rs - both bounds now use `saturating_sub(1)`, and the `cmp::max(0, ...)` wrappers are gone, being no-ops on `usize` that read as saturation while the underflow sat inside them; the file's top-level `use core::cmp` went with them, since the remaining `cmp::min` lives in the `fwd` submodule and has its own import. tests/test.rs - `test_size_hint_is_a_valid_bound`, driving all ten public iterators over a corpus led by the empty string. PLAN.md: Verify count 50 to 51, the sentences row re-recorded. BACKLOG.md: A1 deleted, A4 filed.

Checkpoint: 6b0810fe1aabf66130673d03473296c588c08a9e (not a stall: src/sentence.rs and tests/test.rs changed, A1 was removed from BACKLOG.md and A4 added)

Verification: quiet-verify green, `verify totals: 51 passed`, 2s. The sentences battery, the only one whose paths file names src/sentence.rs, re-run through run-probe.sh: 104/104. `cargo fmt --check` and `cargo clippy --all-targets` clean - clippy caught the now-dead `use core::cmp` the fix orphaned, which is how it was found. `cargo +1.85.0 test` green.

Closed: A1 (High) - the three calls now answer `(0, Some(0))`, which is the correct hint for an input that yields no sentence.

The check is strong enough to fail, in both profiles. Against the unfixed src it panics in debug with `attempt to subtract with overflow` inside src/sentence.rs, and in release, where overflow checks are off and no panic occurs, it still fails with `split_sentence_bounds: size_hint lower 18446744073709551615 exceeds the 0 items yielded on ""`. That second half matters: the release build is what a user of the shipped crate runs, and a test that only caught the debug panic would have certified the release defect as fixed without ever seeing it.

Contract preserved: for every non-empty input the arithmetic is unchanged, because `cmp::max(0, x - 1)` on `usize` and `x.saturating_sub(1)` agree wherever `x >= 1`. Only the empty-string case moves, from a panic or a wrapped bound to `(0, Some(0))`. No signature, no iteration order and no yielded item changed, and the sentences battery pins the segmentation behaviour either side of the fix.

Filed while executing this task: A4 (Medium, runtime, correctness). The new test, written to A1's acceptance, was first drafted asserting the hint at every step of iteration rather than only at the start, and in that stronger form it failed on the fixed tree with `split_sentence_bounds: size_hint lower 1 exceeds the 0 items remaining after 1 on "ab"`. That is a second and distinct defect: the inner `SentenceBreaks::size_hint` reads the whole string's length and never the consumed position, so the hint never shrinks. Its reach was measured rather than guessed - 12 inputs crossed with the 10 public iterators produced 16 violations, all `lower 1 > 0 remaining`, all on `split_sentence_bounds` and `split_sentence_bound_indices`, none on the grapheme or word surfaces, none on `unicode_sentences`. The landed test therefore checks the hint at the start of iteration, which is exactly A1's acceptance and passes; extending it to every step is A4's acceptance and lands with A4's fix. Batching the two fixes into this iteration was the alternative and the rule forbids it.

Learnings: none new this iteration.

Next: A4, the Medium this iteration surfaced, then A2 and A3, then the second full fresh-evidence audit, then the evaluator gate. Five iterations remain after this one, which fits A4 plus an audit plus the gate and declaration; A2 and A3 are Lows that can ride to the declaration as carried debt if the budget tightens.

## iter 6/10 | 3e59c682-042321 | 2026-09-01 | A4 | done

Task: A4 (Medium, runtime, correctness) - the inner `SentenceBreaks::size_hint` derived both bounds from the whole string's length rather than the unconsumed remainder, so `split_sentence_bounds` and `split_sentence_bound_indices` kept reporting a lower bound of 1 after their last item had been yielded, which the `Iterator::size_hint` contract forbids because its bounds are on the items remaining.

Reproduction, run first: the acceptance test, extended to check the hint before every `next()` call, fails at HEAD with `split_sentence_bounds: size_hint lower 1 exceeds the 0 items remaining after 1 on "ab"`. The finding held.

Changed: src/sentence.rs - `SentenceBreaks::size_hint` now measures the remaining bytes, `self.string.len() - self.pos`, and bounds the break positions still to come by that: at least one while any byte is left, because end-of-text is always yielded before the iterator finishes, and at most one per remaining byte plus that end-of-text position. `USentenceBounds::size_hint` now spends the extra position only before its first sentence, when no start is held, instead of subtracting one unconditionally. tests/test.rs - `test_size_hint_is_a_valid_bound` extended from the first position to every position. BACKLOG.md: A4 deleted. PLAN.md: the sentences row re-recorded.

Checkpoint: 298b6e8f6cbdc4c0a637b0cc18d743d732138de3 (not a stall: src/sentence.rs and tests/test.rs changed and A4 was removed from BACKLOG.md)

Verification: quiet-verify green, `verify totals: 51 passed`, 2s. The sentences battery, the only one whose paths file names src/sentence.rs, re-run through run-probe.sh: 104/104, so the segmentation the fix sits beside is unchanged. `cargo fmt --check` and `cargo clippy --all-targets` clean, `cargo +1.85.0 test` green.

Closed: A4 (Medium) - the acceptance as filed. The strengthened test drives all ten public iterators over the empty string, seven other short inputs and the whole of TEST_SAME, TEST_WORD and TEST_SENTENCE, asserting at every position that the hint brackets what is left, and it passes.

Independently measured outside the project, with a second harness in a scratch crate that depends on this one by path: every string of up to three characters over a ten-character alphabet chosen for the sentence rules, plus three prose sentences - 1114 inputs - crossed with the ten public iterators and walked position by position. Zero violations, in a debug build and in a release build alike. The same harness on the pre-fix tree reported 16.

Three attempts, and the first two are worth recording because each was refuted by measurement rather than by reading. Taking the remaining bytes but keeping the inner lower bound of `min(remaining, 2)` fails: after `"abc"` yields its Sot position two bytes remain and only the end-of-text position is still to come, so 2 is not a lower bound. Taking `min(remaining, 1)` but keeping the outer's unconditional subtraction fails too, with `the 1 items remaining exceed size_hint upper 0 after 1 on "\r\r"`: with a start already held and no bytes left, the end-of-text position still closes one more sentence, so the upper bound must not lose a position there. The third form spends that position only when no start is held, which is where it is actually spent.

Contract preserved, and the hint is not merely correct but no looser than before. At the first position the upper bound is `Some(len)` exactly as it was. The lower bound was `min(len, 2) - 1`, which is 0 for a one-byte string and 1 above that; it is now 1 for every non-empty string, so it is unchanged for inputs of two bytes or more and strictly tighter for one-byte inputs. Nothing else about the iterators moved: no signature, no yielded item, no ordering, and the battery pins the segmentation either side.

Learnings: none new this iteration.

Next: A2 and A3, the two carried Lows, then the second full fresh-evidence audit - iteration 4's filed a High and a Medium, so it cannot be the audit a declaration cites - then the evaluator gate and the declaration. Four iterations remain after this one, so if the budget tightens A2 and A3 ride to the declaration as carried Lows, which the closing rule allows.

## iter 7/10 | 3e59c682-042321 | 2026-09-01 | A2 | done

Task: A2 (Low, test, documentation) - the README's Rust example was compiled by no test target, so it could drift from the API with every CI job still green.

Reproduction, run first: `grep -rn 'include_str!("../README.md")' src/` returned nothing and the crate carried no doc-include of the README, so the only thing grading the front-page example was a reader.

Changed: src/lib.rs - a `#[cfg(doctest)] #[doc = include_str!("../README.md")] struct ReadmeDoctests;`, which makes rustdoc compile and run the README's fenced Rust block as a doc-test. PLAN.md: Verify count 51 to 52, the Oracle class extended to say the README is now graded by the command, and the four rows whose batteries name src/lib.rs re-recorded. BACKLOG.md: A2 deleted.

Checkpoint: ecb3d4f68816e197028133514610d229ca948082 (not a stall: src/lib.rs changed and A2 was removed from BACKLOG.md)

Verification: quiet-verify green, `verify totals: 52 passed`, 1s - one more than before, and the new one is `src/lib.rs - ReadmeDoctests`. The four batteries whose paths files name src/lib.rs re-run through run-probe.sh: graphemes-iter 266/266, sentences 104/104, unicode-words 94/94, word-bounds 124/124. `cargo fmt --check` and `cargo clippy --all-targets` clean, `cargo +1.85.0 test` green at 24 doc-tests.

Closed: A2 (Low) - the acceptance as filed, and checked against every assertion in the example rather than one. Altering the expected grapheme slice, the expected `unicode_words` slice, or the expected `split_word_bounds` slice each reddens `src/lib.rs - ReadmeDoctests`; the README was restored byte-identical after each, confirmed with `cmp`.

Why this shape rather than a copy of the example in tests/test.rs: a copy is a second thing to keep in sync and drifts exactly as the original did. `cfg(doctest)` is set only while rustdoc collects doc-tests, so the item is in no ordinary build and, checked rather than assumed, in no rendered page either - `grep -rl ReadmeDoctests target/doc/unicode_segmentation/` after `cargo doc --no-deps` returns nothing. The include also needs README.md to be inside the published crate, which `cargo package --list` confirms it is, so the doc-test is runnable from the artifact and not only from the repository.

Contract preserved: no public item was added, removed or changed - the new struct is private and exists only under `cfg(doctest)` - and the four batteries covering src/lib.rs pin the segmentation behaviour either side of the change.

Learnings: none new this iteration.

Next: A3, the last open item, a Low of class dev-tooling. Three iterations remain, and the convergence sequence needs two of them - a second full fresh-evidence audit, since iteration 4's filed a High and a Medium, then the evaluator gate and the declaration. A3 is therefore priced next iteration and either fixed inside it or Declined under the one-iteration rule, so the audit lands with a clean ledger.

## iter 8/10 | 3e59c682-042321 | 2026-09-01 | A3 | done

Task: A3 (Low, dev-tooling, dependency hygiene) - criterion was declared `0.5` in Cargo.toml and resolved to v0.5.1 while crates.io reported 0.8.2 as the latest stable.

Reproduction, run first: `cargo tree --edges dev --depth 1` printed `criterion v0.5.1`, and the crates.io API reported 0.8.2 as `max_stable_version`. The finding held.

Changed: Cargo.toml - criterion `0.5` to `0.7`, which resolves to v0.7.0. benches/chars.rs, benches/words.rs, benches/word_bounds.rs, benches/unicode_word_indices.rs - `black_box` imported from `std::hint` instead of `criterion`, because criterion deprecated its own re-export. BACKLOG.md: A3 deleted, one Proposed item added. PLAN.md: the packaging-generators row re-recorded, Cargo.toml being one of its declared paths.

Checkpoint: 2665a76eb0b2f8448e79baf0f1a410363c7b0eb3 (not a stall: Cargo.toml and four bench files changed and A3 was removed from BACKLOG.md)

Verification: quiet-verify green, `verify totals: 52 passed`, 1s. `cargo build --benches` exits 0 with zero warnings, and the benches run rather than merely compile - `cargo bench --bench chars` produced real timings for all six texts. `cargo clippy --all-targets --all`, which is the CI job's own command and the one that reaches the bench targets, exits 0 with no warning or error line. `cargo fmt --check` clean. `cargo +1.85.0 test` exits 0, and `cargo +1.85.0 build --benches` does too, which is stronger than the MSRV job asks for. packaging-generators, the only battery whose paths file names Cargo.toml, re-run through run-probe.sh: 16/16.

Closed: A3 (Low), with the half of its acceptance that a measurement refused stated plainly rather than quietly dropped. `cargo build --benches` exits 0, as filed. `cargo tree` does not show criterion at the latest stable, and cannot: criterion 0.8.2 declares `rust-version = 1.86` while this crate declares 1.85.0, and with `criterion = "0.8"` in Cargo.toml `cargo +1.85.0 test` exits 101 with `error: rustc 1.85.0 is not supported by the following package`. 0.7.0 is the newest release compatible with the crate's own published MSRV - the version table from the crates.io API shows 0.8.0, 0.8.1 and 0.8.2 at 1.86 and 0.7.0 at 1.80 - so the dependency moved as far as the crate's contract allows and the remainder is a decision, not a task.

Why the deprecation swap rides with the bump rather than being churn: measured, not assumed. With the original `use criterion::black_box` imports restored and criterion at 0.7, `cargo build --benches` prints 16 warning lines, 12 of them `use of deprecated function criterion::black_box`; with the imports moved to `std::hint::black_box` it prints none. The bump requires the swap, and `std::hint::black_box` has been stable since well before this crate's MSRV.

Filed: one Proposed item - raise `rust-version` to 1.86 so dev-dependencies can track latest stable - carrying the failing command as its evidence. Raising a published MSRV changes a contract the crate's users read, so it goes to the owner rather than into a fix, and Proposed never blocks convergence.

Contract preserved: no shipped code was touched. The benches are excluded from the published artifact, which packaging-generators asserts, so a consumer of the crate sees neither the criterion version nor the `black_box` import; what changes is which harness the repository benchmarks with.

Learnings: a dev-dependency bump is bounded by the crate's own `rust-version`, and the check that catches it is `cargo +<msrv> test`, not `cargo build` - the MSRV job resolves every dev-dependency even though it builds none of them, so an incompatible dev-dependency fails resolution before anything compiles.

Next: the ledger is empty, so the next iteration is the second full fresh-evidence audit - iteration 4's filed a High and a Medium and cannot be the audit a declaration cites - and, if it comes back clean, the evaluator gate and the declaration follow in the last iteration and the closing window.

## iter 9/10 | 3e59c682-042321 | 2026-09-01 | AUDIT | audit

Task: the second full fresh-evidence audit of this run. Iteration 4's audit filed a High and a Medium and so cannot be the audit a declaration cites; this one is clean, and closeout has begun - no further audit and no replenishment for the rest of the run.

Changed: PLAN.md - the Environment fingerprint's exclusion sentence corrected. No source file was touched and no finding was filed.

Checkpoint: 58789059ab5c22233b23f2009c6868fb606dd7cf (an AUDIT entry, which the stall rule exempts; this iteration changed only PLAN.md, filed nothing and moved no ledger item, and it says so here)

Verification: quiet-verify green, `verify totals: 52 passed`, 1s. All 16 battery claims re-executed through check-claims.sh: 16 checked, 0 mismatched, 0 errored, 0 skipped, so every swept row rests on an instrument that still reaches its full count and still reddens by the recorded amount under its discriminating mutation.

Row currency, derived rather than trusted: for each of the 8 rows, `git diff --name-only <row commit> HEAD -- <the battery's declared paths>` returns nothing. No row is stale.

Evidence gathered this audit, all executed:
- Panic sweep re-run at HEAD: 588 probes, 28 edge inputs crossed with 21 public call shapes, in debug and in release. Zero panics, where iteration 4's identical sweep found 3. That is A1 closed by measurement rather than by assertion.
- `Iterator::size_hint` contract walk: 1113 inputs - every string of up to three characters over a ten-character alphabet chosen for the sentence rules, plus prose - crossed with all 10 public iterators and checked before every `next()` call. Zero violations, debug and release, where the pre-A4 tree reported 16.
- Test isolation, which the Method requires before scoring Testing clean: each of the six integration tests run alone, the lib unit target alone at 16 passed, the doc-test target alone at 24 passed. No order dependence, no leaked state.
- `cargo fmt --check` clean; `cargo clippy --all-targets --all`, the CI job's own command, exits 0 with zero warning or error lines; `cargo doc --no-deps` the same. `cargo +1.85.0 test` exits 0 across all three targets and `cargo +1.85.0 build --benches` exits 0.
- The Settled class re-derived by its own recorded command: `grep -rn "os.system\|subprocess\|popen" scripts/` returns one line, the status-checked `curl -f` inside `fetch`. The class still holds. The Declined section holds no entry, so there is no Derivation to re-run.
- Zero runtime dependencies, read from `cargo tree --edges normal`; the three dev-dependencies read from `cargo tree --edges dev` are criterion 0.7.0, proptest 1.11.0 and quickcheck 1.1.0.

One correction this audit made to the run's own bookkeeping, which is worth naming rather than burying: the Environment fingerprint asserted that its derivation command's only hits were two `#[cfg(test)]` module gates. Re-running that command returns three - iteration 7 added a `#[cfg(doctest)]` gate and did not update the sentence that counts them. The line now names all three and says why the third admits rather than excludes: it gates the item that pulls README.md in as a doc-test, and the doc-tests are part of what the Verify command runs. Nothing about coverage changed; a claim the run itself outdated did, and the declaration re-reads that line.

Scores, claiming all 8 of 8 swept rows with no unexamined remainder:
- correctness: None. The panic sweep and the size_hint walk both come back empty at HEAD where each found real defects earlier this run, and the conformance corpus and every battery are green.
- security: None. `#![deny(unsafe_code)]`, zero `unsafe` anywhere in src including the generated tables, zero runtime dependencies, no I/O in the library. The limit is stated rather than hidden: no vulnerability scanner is installed on this host - cargo-audit and cargo-deny are both absent - so this rests on the dependency shape, and the shape is that nothing ships with the crate at all.
- testing: None. The suite grades 52 across three targets, runs clean in isolation, and the two surfaces this run found thin - the chunked cursor and the sentence iterators - now carry differential and invariant tests of their own.
- error handling: None. The `GraphemeIncomplete` paths are exhaustively differentialled by the grapheme-cursor battery, and the generator's fetch path now fails closed.
- documentation: None. rustdoc builds without a warning under `#![deny(missing_docs)]`, and the README example is no longer merely read - it is compiled and run by the Verify command.
- dependency hygiene: None. criterion is at 0.7.0, the newest release compatible with the crate's declared MSRV; the other two dev-dependencies resolve to their latest stable. The remaining gap is the Proposed MSRV decision, and a Proposed item is not a finding.
- architecture: None. Three segmentation modules, one generated table module, one public trait.
- code quality: None. The `cmp::max(0, ...)` no-ops that hid the underflow are gone, and the dead import they left behind with them.
- performance: None, with its evidence limit stated: `cargo bench --bench chars` was run this run and produced timings, but no before-and-after comparison was made, so nothing is claimed about speed. The word-ascii-fastpath battery certifies that the fast path agrees with the general path, not that it is faster.
- developer experience: None. Six CI jobs, both generators re-run against unicode.org and diffed byte-identical this run.
- observability: not applicable - a pure segmentation library with no logging, metrics or error-reporting surface.
- UX and accessibility: not applicable - no user-facing surface; the crate ships no CLI and no UI.

Filed: nothing. Zero High and zero Medium in-envelope, and no Low either: the three Lows this run carried are all closed, and the one remaining question - raising the published MSRV so dev-dependencies can track latest stable - sits under Proposed, where it never blocks convergence and is never worked without the owner's approval.

Learnings: none new this iteration.

Next: the evaluator gate, then the declaration if it returns PASS. The ledger is empty, every row is swept and current, the Verify command is green, and this audit is clean, so the closing conditions hold on everything but the gate itself.

## iter 10/10 | 3e59c682-042321 | 2026-09-01 | EVALUATOR | converged

Task: the evaluator gate and, on its PASS, the declaration. Iteration 9's full fresh-evidence audit scored zero High and zero Medium in-envelope, the ledger was empty, all 8 Surface inventory rows were swept and current, and the Verify command is green, so the only outstanding closing condition was the gate itself.

Changed: BACKLOG.md - E1 filed under Later from a gate observation, and the Converged line appended. .jeffy/evaluator/3e59c682-042321-1.md - the gate's artifact, committed by this iteration's checkpoint. No source file was touched.

Checkpoint: ded7a7b787e380f02fef8ec7340718ca9285fc2e (an EVALUATOR entry, which the stall rule exempts; it changed only BACKLOG.md and the gate artifact, and it added E1 to the ledger)

Verification: Evaluator: PASS - invocation 1 of this run, artifact .jeffy/evaluator/3e59c682-042321-1.md, 140 lines opening with the run-id, ordinal and iteration and recording every command with its real exit status; it re-ran A1's and A4's reproductions against the trees they were filed against and confirmed both failed there and pass at HEAD in debug and release, found the sentence segmentation byte-identical either side of the fixes by digest over 11111 inputs, and found no violation over 22222 independently constructed exhaustive inputs. quiet-verify green this iteration, `verify totals: 52 passed`, 1s.

Standing claims brought current in this same iteration, before the invocation: all 8 rows checked for staleness by `git diff --name-only <row commit> HEAD -- <the battery's declared paths>`, which returns nothing for every one; the Declined section holds no entry, so there was no Derivation to re-run; the single Settled class re-derived by its own recorded command, which still returns the one status-checked `curl -f` inside `fetch`; check-claims.sh at 16 checked, 0 mismatched, 0 errored, 0 skipped; PLAN.md names no finding ID as carried or blocked, so there is no reference to resolve; the Oracle class re-read against a real run at 16, 12 and 24 across the three targets, summing to the Verify count of 52; and the Environment fingerprint re-derived by its own command, returning the three hits the line now names, on the toolchain it names.

Carried Low, listed by ID as the closing rule requires:
- E1 (Low, runtime, code quality) - the bare `usize` subtraction in `SentenceBreaks::size_hint`. Sound today and measured clean over 22222 inputs; filed because it is the shape the A1 fix removed elsewhere, and it is an observation the gate recorded rather than a defect it reproduced.

Two things the gate flagged that are corrections to this journal's own prose rather than tasks, recorded here because a journal entry is never rewritten. First, iteration 5's entry called A1's release form a contract violation callers turn into allocations; the gate measured the reach at the base commit and found that only a direct `size_hint()` call reaches it, since `collect`, `zip`, `chain`, `peekable`, `Vec::extend` and `String::from_iter` all call `next()` first and the empty string yields `None` immediately. The High stands on the reproduced debug panic, which the gate confirmed at exit 101; the allocation clause overstated the measured reach and should have been narrowed to the single path actually verified. Second, the gate read 1114 in iteration 6's entry against 1113 in iteration 9's as an off-by-one; both are right and the harnesses differ - each generates 1111 strings exhaustively, iteration 6 adding three prose sentences and iteration 9 adding two. The gate's fourth observation, that PLAN.md's Stated counts table holds no row yet, is the documented armed-by-the-first-row state and needs nothing.

The gate's PASS declares in this same iteration, as the rule requires: no observation it recorded was fixed inside the convergence sequence, because a fix after a PASS invalidates the PASS.

Learnings: none new this iteration.

Next: nothing in this run. The next run starts from a converged tree with E1 open as a carried Low and one Proposed item awaiting the owner's decision, so its ratchet will not fire and its first iteration is a fresh audit.
