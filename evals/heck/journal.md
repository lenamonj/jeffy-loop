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

## iter 1/10 | d6fd570a-000001 | 2026-08-24 | AUDIT | audit

Task: First full audit of heck 0.5.0. Filled the Operating envelope table, the Surface inventory (12 rows), and the Verify command block in PLAN.md, then probed every row breadth-first and filed the findings.

Changed: PLAN.md (envelope surfaces, 12 inventory rows, Command/Oracle class/Environment fingerprint/duration/summary pattern, one Lesson), BACKLOG.md (3 Medium, 3 Low).

Checkpoint: e079a2e7f48923dc089978dad88394b67b47f674

Verification: verify green (1s, 112 unit tests + 16 doc tests, fmt and clippy clean) through quiet-verify.sh. Probes ran from a scratch crate at $SCRATCH/heck-probe depending on this tree by path: an edge/Unicode matrix over all eight conversions and an idempotence sweep, then an alias-and-wrapper probe covering to_snek_case, to_pascal_case, TO_SHOUTY_SNEK_CASE, AsSnekCase, AsPascalCase, AsShoutySnekCase, AsRef<str> over &str/String/&String/Cow, empty input through all eight Display wrappers, and a failing fmt::Write sink (error propagates, exit 0 on all probes).

Scores, claiming only what these shallow probes reached - all 12 Surface inventory rows are still unswept, so no dimension score here stands on a kept battery: correctness Medium (SIGMA-1, TITLE-1 - both reproduced against str::to_lowercase and Unicode SpecialCasing titlecase); testing Medium (TEST-1); developer experience Low (API-1, CI-1); documentation Low (DOCS-1); security None (forbid(unsafe_code), no_std, zero dependencies, no panic on any probed input); error handling None (fmt::Result propagated with ?, confirmed by a sink that fails mid-word); architecture None (one shared transform core behind eight thin modules); code quality None (fmt and clippy -D warnings both clean); dependency hygiene None (the manifest declares no dependencies); performance not scored - nothing measured this iteration; observability N/A - a pure conversion library with no I/O, logging, or metrics surface; UX and accessibility N/A - no user-facing surface.

Learnings: the Rust toolchain lives in $HOME/.cargo/bin and is absent from the loop shell's PATH, so every cargo command needs PATH exported first; rustfmt and clippy components were missing and were installed with rustup this iteration, which the Verify command now depends on. The suite's oracle is self-referential - 112 hand-written expected strings this project authored - so a Unicode misreading passes it, which is exactly how both Medium findings survived to 0.5.0.

Next: SIGMA-1, then TITLE-1, then TEST-1; the 12 unswept inventory rows outrank the three Lows.

## iter 2/10 | d6fd570a-000001 | 2026-08-24 | SWEEP | done

Task: Sweep all 12 Surface inventory rows, which the queue puts above every Medium and Low with no open High. Built the kept batteries under .jeffy/probes/ and ran every one of them.

Changed: .jeffy/probes/harness (a reference implementation of the documented segmentation plus Unicode case mappers, an exhaustive ASCII corpus and a Unicode corpus, and 11 battery test files), .jeffy/probes/<row>/run.sh and paths for all 12 rows, BACKLOG.md (FMT-1, DOCS-2 filed), PLAN.md (12 rows recorded as swept).

Checkpoint: 37d3c08678f26e658b665fd6606dfdc6814d2362

Verification: all 12 batteries pass, run one by one from the project root: build-surface ok, and 65 assertions across the other 11 (transform-core 6, case-mapping-helpers 5, crate-root-reexports 6, and 6 each for the eight case rows). The evidence is differential, not liveness: every string of length 0 to 5 over the alphabet `a B C 1 _` - 3906 inputs - is converted by both the crate and an independent reference written from README.md, across all eight conversions, and they agree exactly, zero mismatches. On the Unicode corpus the only disagreements are the ones already filed: the sigma class (SIGMA-1) and the titlecase class (TITLE-1), each listed in the battery that owns it and asserted to still deviate, so fixing either fails its battery and forces the update. build-surface additionally builds the crate on stable, on the 1.56 MSRV toolchain CI pins, and for thumbv6m-none-eabi, which is what makes the no_std claim in Cargo.toml checkable rather than asserted. Verify green (1s, test result: ok. 16 passed) through quiet-verify.sh.

Two findings the sweep surfaced, both filed at rubric severity this iteration: FMT-1 (Medium) - all eight Display wrappers ignore width, alignment and precision, reproduced against std's own padding of the same string, enumerated across all eight impl sites; DOCS-2 (Medium) - the documented boundary rules do not describe the boundary before an uppercase run following a lowercase character, so they predict "parsehttp_response" where the crate returns "parse_http_response".

Learnings: the probe harness is a second cargo package inside .jeffy/probes/harness, and it must never write its build output into the tree - every battery exports CARGO_TARGET_DIR outside the repository, because the checkpoint stages with git add -A and .gitignore is off limits after bootstrap. The reference implementation is what turned a shallow audit into evidence: 3906 exhaustive inputs agreeing exactly is a much stronger statement about the segmentation core than any hand-written table, and it cost one file.

Next: SIGMA-1, the top Medium, with TITLE-1 and FMT-1 behind it; the map is now complete, so nothing outranks the Mediums.

## iter 3/10 | d6fd570a-000001 | 2026-08-24 | SIGMA-1 | done

Task: SIGMA-1 (Medium) - `lowercase` rewrote any word-final capital sigma to its final form, ignoring Unicode's Final_Sigma precondition that a cased character precede it. Closed: `"Σ".to_snake_case()` is now `"σ"` and `"1Σ".to_snake_case()` is `"1σ"`, both matching `str::to_lowercase`, while `"AΣ"` stays `"aς"`.

Changed: src/lib.rs (`lowercase` now delegates to a new `lowercase_after` carrying whether a cased character precedes the slice, plus a `cased` predicate that also recognises titlecase characters), src/snake.rs and src/title.rs (7 new assertions), CHANGELOG.md, the six case batteries and the case-mapping battery, .jeffy/probes/harness/src/lib.rs (corpus), BACKLOG.md, PLAN.md.

Checkpoint: 2efe383f1688ecaba031a36fbb934dc0f8c9d5ee

Verification: the acceptance check was written first and run against the unfixed code, where it failed 4 of its assertions (snake test26, test27, test30, title test11); after the fix the unit suite is 119 passed, 0 failed. One of those four was my expectation, not the crate's defect: `"a1Σ"` segments as `a1` then `Σ`, so the right answer is `"a1_σ"` and the test now says so. Verify green (1s, test result: ok. 16 passed) through quiet-verify.sh. All 12 batteries re-run and green - every battery's paths file names src/lib.rs, so every row was re-run and is re-recorded at this checkpoint.

Contract preserved: `lowercase` and `capitalize` keep their `fn(&str, &mut fmt::Formatter) -> fmt::Result` shape, which is what the five call sites in snake.rs, kebab.rs, lower_camel.rs, title.rs, train.rs and upper_camel.rs pass to `transform`; the sigma behaviour a cased character precedes is unchanged, which is what test9 in every module pins (`"XΣXΣ baﬄe"` still converts to `"xσxς_baﬄe"`). The observable behaviour change is recorded in CHANGELOG.md under unreleased.

Closed this iteration: SIGMA-1 (Medium) - fixed, acceptance check green, deviation entries removed from the seven batteries that pinned it.

Filed this iteration: SIGMA-2 (Low, runtime) - the fix is exact for every character except case-ignorable ones, which `core` exposes no predicate for, so `"AʼΣ".to_snake_case()` is `"aʼσ"` where std gives `"aʼς"`. Reproduced, added to the probe corpus, and pinned in every battery that sees it, so it cannot be forgotten.

Learnings: a battery that asserts a known deviation with assert_ne is what made this fix safe - removing the sigma entries was forced by the batteries going red, not by memory. Write the acceptance test before the fix and run it: it caught a wrong expectation of mine in the same minute rather than after the checkpoint.

Next: TITLE-1, then FMT-1, then TEST-1 and DOCS-2.

## iter 4/10 | d6fd570a-000001 | 2026-08-24 | TITLE-1 | done

Task: TITLE-1 (Medium) - `capitalize` uppercased a word's first character instead of titlecasing it. Closed: a new `titlecase` writes the four Latin digraph groups as their own middle form, leaves Georgian Mkhedruli unchanged because it has no titlecase, and lowercases an expanding uppercase mapping after its first cased character.

Changed: src/lib.rs (`titlecase`, called from `capitalize`), src/title.rs and src/upper_camel.rs (6 new assertions), CHANGELOG.md, .jeffy/probes/harness/src/lib.rs (two transcribed Unicode tables and an authoritative reference titlecase), .jeffy/probes/harness/tests/case_mapping_helpers.rs, the six case batteries, BACKLOG.md, PLAN.md.

Checkpoint: b72b05a71abd070a0f0a6d394d35ae41333b0521

Verification: the six acceptance assertions were written first and all six failed on the unfixed code; after the fix the unit suite is 125 passed, 0 failed. All 12 batteries green. Verify green (1s, test result: ok. 16 passed) through quiet-verify.sh. The mappings were derived, not remembered: UnicodeData.txt field 14 gives 58 characters whose simple titlecase differs from their uppercase - the 12 digraph characters and 59 Georgian letters minus overlap - and SpecialCasing.txt gives 103 unconditional full mappings, both transcribed into the harness so the reference states Unicode's answer rather than mine. Driving all 103 through `to_title_case` deviates on exactly 63 characters, every one inside U+1F80..U+1FFC, and that enumeration is now a battery assertion rather than a sentence.

Contract preserved: `capitalize` keeps its `fn(&str, &mut fmt::Formatter) -> fmt::Result` shape and its four call sites in title.rs, train.rs, upper_camel.rs and lower_camel.rs are untouched; the behaviour change is confined to first characters whose titlecase differs from their uppercase, and is recorded in CHANGELOG.md under unreleased.

Closed this iteration: TITLE-1 (Medium) - fixed, six acceptance assertions green, deviation entries removed from the six batteries that pinned it.

Filed this iteration: TITLE-2 (Low, runtime) - the 63 Greek iota-subscript characters still titlecase to their uppercase expansion rather than the precomposed form, reproduced and enumerated.

A note on the two carried Lows: SIGMA-2 and TITLE-2 share a root cause, that `core` exposes the case mappings but not the properties (Case_Ignorable, the titlecase table) the conditions need. A third finding with that same root cause is not another instance patch - it is one structural task or one Proposed item, per the three-strike rule.

Learnings: the batteries caught my reference sharing the crate's blind spot - both wrote "Ἀιβ" for "ᾀβ", so the differential passed while both were wrong, and only transcribing SpecialCasing.txt exposed it. That also turned up U+0149, whose uppercase mapping begins with an uncased apostrophe: lowercasing after the first character got it wrong and lowercasing after the first cased character gets it right, which is one word of difference in the rule and one character of difference in the output.

Next: FMT-1, then TEST-1 and DOCS-2.

## iter 5/10 | d6fd570a-000001 | 2026-08-24 | FMT-1 | done

Task: FMT-1 (Medium) - the eight `As*Case` `Display` impls wrote straight to the formatter, so width, fill, alignment and precision were silently dropped. Closed class-complete: all eight now route through a shared `pad_with`.

Changed: src/lib.rs (`pad_with`), all eight case modules (the `Display` impl and one `format_parameters_are_honoured` test each), CHANGELOG.md, .jeffy/probes/harness/tests/format_parameters.rs (new), .jeffy/probes/crate-root-reexports/run.sh, .jeffy/probes/harness/tests/crate_root_reexports.rs, BACKLOG.md, PLAN.md.

Checkpoint: dd425445a4c2bd5d74d9d9899aa804bbd62189c4

Verification: the enumeration is `grep -rln 'impl<T: AsRef<str>> fmt::Display' src/`, which returns the eight case modules, and each of the eight got its own test written before the fix; all eight failed on the unfixed code and all eight pass now, unit suite 133 passed, 0 failed. All 12 batteries green. Verify green (2s, test result: ok. 16 passed) through quiet-verify.sh. The new battery also pins the property the fix was shaped around: with a counting global allocator and a fixed-size sink that cannot allocate, `write!(sink, "{}", AsSnakeCase(..))` allocates zero times, while the same write with `{:>40}` allocates at least once, so padding costs a buffer and plain formatting still costs nothing.

Contract preserved: no signature and no public type changed - `pad_with` is private, and each `Display` impl keeps its behaviour exactly when no formatting parameter is set, which is what every existing test and doc example exercises. The behaviour change is recorded in CHANGELOG.md under unreleased.

Closed this iteration: FMT-1 (Medium) - fixed class-complete, recorded under Settled classes with its enumerating command.

Learnings: `fmt::Formatter` cannot be constructed outside core, so padding a streaming `Display` means running the stream through a small `Display` shim and letting `format!` build the buffer, then `f.pad`. Gating that on `width().is_none() && precision().is_none()` is what keeps the zero-allocation path, and the allocation counter is what proves it rather than asserting it.

Next: TEST-1, then DOCS-2; then the ledger holds only Lows.

## iter 6/10 | d6fd570a-000001 | 2026-08-24 | TEST-1 | done

Task: TEST-1 (Medium) - the project's own suite pinned no input without alphanumeric characters, so the empty and separator-only path was uncovered. Closed: each of the eight modules now carries `input_without_words_converts_to_nothing`, driving the trait and its `Display` wrapper over eight such inputs.

Changed: all eight case modules (one test each), BACKLOG.md, PLAN.md.

Checkpoint: 84cc6b36353328d35d2e8b4910f25e1e1df2ee64

Verification: unit suite 141 passed, 0 failed. Verify green (2s, test result: ok. 16 passed) through quiet-verify.sh after `cargo fmt` - the gate's first stage rejected the generated assert lines as too long, which is the whole point of running the gate rather than only the tests. All 12 batteries green.

The tests were shown to have teeth by mutation rather than by assertion. Mutation 1, emitting a word for each empty split segment in `transform` so the `first_word` bookkeeping runs on wordless input: 30 tests fail, and all eight `input_without_words_converts_to_nothing` tests are among them. Mutation 2, replacing `capitalize`'s `if let Some(..)` guard with an `unwrap`: the whole suite still passes, 141 passed, 0 failed. That second result narrows the finding as filed: `capitalize` is never called with an empty word, because `transform` only calls `with_word` from inside a loop that an empty word never enters, so its guard is unreachable from the public API rather than untested. Both mutations were applied to a copy-aside of src/lib.rs and the file was restored from that copy; `git diff --stat src/lib.rs` is empty at the checkpoint.

Closed this iteration: TEST-1 (Medium) - eight tests added, mutation-checked.

Learnings: a test-gap task has no failing acceptance check of its own, so the honest substitute is a mutation: break the path the test claims to cover and watch the test fail. It also priced a claim I had written into the ledger - one of the two paths TEST-1 named turned out to be unreachable, and the mutation is what showed that rather than a reading of the code.

Next: DOCS-2, the last Medium; then a Low, then the closing audit and the evaluator gate.

## iter 7/10 | d6fd570a-000001 | 2026-08-24 | DOCS-2 | done

Task: DOCS-2 (Medium) - the published word boundary rules did not describe the boundary this crate puts before an uppercase run following a lowercase character or a digit, so a reader applying them predicted the wrong output for ordinary identifiers. Closed: rules rewritten in README.md and the crate root, with the examples that distinguish them.

Changed: src/lib.rs (crate root docs), README.md, src/snake.rs (a `documented_segmentations` test), .jeffy/probes/harness/src/lib.rs (the reference doc now cites the published rules), BACKLOG.md, PLAN.md.

Checkpoint: ae56f4f57ea3895778db4711c9036280e597f4fa

Verification: the three rules were applied by hand to the inputs the finding named and now predict what the crate returns - `parseHTTPResponse` gives a boundary before `H` by rule 1, since the last cased character is `e`, and before `R` by rule 2, since `P` is uppercase and `e` follows, so `parse|HTTP|Response`; `abcDEF` gives one boundary before `D` by rule 1, so `abc|DEF`; `abc123DEF456` gives one before `D` by rules 3 and 1 together, since the digits leave `c` standing as the last cased character, so `abc123|DEF456`. All three are asserted in `documented_segmentations`, unit suite 142 passed, 0 failed, and the doc examples still pass. Verify green (1s, test result: ok. 16 passed) through quiet-verify.sh; all 12 batteries green.

The stronger check is structural rather than by hand: the harness reference implements the published rules, transcribed from the documentation and not from src/lib.rs, and the transform-core battery drives 3906 exhaustive inputs through both. Those rules and that implementation agreeing exactly on every one of them is what certifies the documentation, and it is why the reference's doc comment now names the rule numbers it transcribes.

Closed this iteration: DOCS-2 (Medium) - rules rewritten, hand-applied to the three filed inputs, and pinned by an executable test.

Side effect worth recording: rewriting rule 2 removed the "next wo word" line break defect that DOCS-1 also listed, so DOCS-1's line was narrowed from four defects to the three that remain, with its enumeration command updated to match.

Learnings: documentation that no check drives is a claim like any other. The cheap way to hold it honest here was to write the reference implementation from the prose rather than from the code, so a differential over an exhaustive corpus fails when either the code or the prose drifts.

Next: the ledger holds only Lows; API-1 is the top runtime one, then the closing full audit and the evaluator gate.

## iter 8/10 | d6fd570a-000001 | 2026-08-24 | AUDIT | audit

Task: Closing full audit, rescoring every applicable dimension against the rubric and the Operating envelope with fresh evidence. Closeout has begun: the run files no further audit and finishes on what the ledger holds.

Changed: BACKLOG.md (PERF-1 filed), .jeffy/probes/perf/ (a kept benchmark instrument).

Checkpoint: de00e631f7be0529aa022e92f67ebe3da7539015

Verification: re-read the Oracle class and Environment fingerprint and re-ran the exclusion enumeration - `grep -rn '#\[cfg(\|#\[ignore\|target_os\|target_arch\|feature *=' src/ Cargo.toml` still returns nothing but the eight `#[cfg(test)]` module gates, so no test target is excluded on this host and every assertion the suite reports actually ran. Verify green (1s, test result: ok. 16 passed) through quiet-verify.sh. All 12 row batteries green, including build-surface, which builds on stable, on the 1.56 MSRV toolchain and for thumbv6m-none-eabi.

Fresh evidence taken this iteration, on the code this run changed: 0 mismatches against std's own padding across width, precision, fill and alignment over a corpus mixing ASCII, Greek, German, Japanese, empty and separator-only input, with precision cutting on character boundaries and a multi-byte fill character; 53252 alphanumeric characters driven through four conversions with no panic; `to_string` output identical to the trait's; and a throughput comparison against the commit this run started from.

Scores, claiming the whole mapped surface because all 12 inventory rows are swept at the current checkpoint: correctness Low (SIGMA-2, TITLE-2 carried, both enumerated and pinned; no new High or Medium against an authoritative reference); security None (forbid(unsafe_code) present, `grep -rn unsafe src/` outside that attribute returns nothing, no dependencies section in Cargo.toml, no panic across the character scan); testing None (142 unit assertions and 16 doc examples, the wordless-input path pinned in all eight modules and mutation-checked, 12 kept batteries); error handling None; architecture None; code quality None (fmt and clippy -D warnings clean); performance Low (PERF-1, measured); documentation Low (DOCS-1 carried, three doc-comment defects; the boundary rules are now executable); dependency hygiene None (zero dependencies); developer experience Low (API-1, CI-1 carried); observability N/A - a pure conversion library with no I/O, logging or metrics surface; UX and accessibility N/A - no user-facing surface.

Zero High and zero Medium in-envelope. Closeout has begun.

Filed this iteration: PERF-1 (Low, runtime) - this run's own regression, 1.09x to 1.16x the pre-run baseline, because `cased()` runs per character where the value is read only at a word-final sigma. The benchmark is committed as .jeffy/probes/perf/run.sh so the number can be re-derived rather than believed, and it carries no paths file on purpose: it prints a ratio and exits 0, so it is an instrument this iteration, not a gate.

Learnings: a run that changes hot code owes itself a measurement, and the cheap way to get an honest one is to build the commit the run started from beside the working tree and compare with identical checksums. This regression would otherwise have shipped invisibly behind a green suite.

Next: PERF-1, the one task this audit filed, then the evaluator gate and the declaration.

## iter 9/10 | d6fd570a-000001 | 2026-08-24 | PERF-1 | done

Task: PERF-1 (Low, runtime) - the only task the closing audit filed, and this run's own regression: `cased()` ran for every character while its answer is read only at a word-final capital sigma. Closed by asking the question where it is answered.

Changed: src/lib.rs (`lowercase_after` keeps the previous character and calls `cased` lazily), .jeffy/probes/perf/ (corpus widened to 480k identifiers, and the observed noise floor written into the script), BACKLOG.md, PLAN.md.

Checkpoint: 1b2a95675117d29b80d2ce3b848edd581965045b

Verification: unit suite 142 passed, 0 failed, and all 12 row batteries green - the sigma behaviour is unchanged, which is what the case-mapping battery and the six case batteries pin, and the benchmark checksum is identical on both sides at 10546720. Verify green (1s, test result: ok. 16 passed) through quiet-verify.sh.

The measurement, stated in full rather than by its best sample. Before the fix, at 120k identifiers: 1.156x and 1.091x. After the fix, at 120k: 1.021x, 1.054x, 1.026x, 1.000x, 1.063x. After the fix, at 480k: 0.955x, 1.067x, 1.039x. The threshold this task was filed with, at or below 1.05x on a run, turns out to sit inside this host's noise: repeated runs of an unchanged tree straddle it in both directions. What the evidence supports is the qualitative statement instead - before the fix every sample was above 1.05 and all fell the same side of parity, after it three of eight fall below 1.0 - so the consistent slowdown is gone rather than merely smaller, and the residue is not distinguishable from measurement noise on this machine. The noise floor is now written into run.sh so a later run does not chase it.

Closed this iteration: PERF-1 (Low) - fixed, measured across eight samples, and the instrument left sharper than it was found.

Learnings: an acceptance check written as a numeric threshold needs the instrument's resolution checked before the threshold is believed; here the honest close was a direction argument over several samples, not a single ratio under a line. Quoting the favourable run would have been the easy failure.

Next: the evaluator gate and, on a PASS with the closing conditions holding, the declaration.

## iter 10/10 | d6fd570a-000001 | 2026-08-24 | EVALUATOR | audit

Task: Evaluator gate, invocation 1 of at most 2 for this run, with every closing condition holding beforehand: the clean full audit on record from iteration 8, 12 of 12 inventory rows swept at the current src commit, zero open High and zero open Medium, no Declined entry to re-derive, and verify green this iteration.

Changed: BACKLOG.md (NFD-1 filed, SIGMA-2 and TITLE-2 re-scored, one Proposed decision), JOURNAL.md, .jeffy/evaluator/d6fd570a-000001-1.md.

Checkpoint: f947ad24fc97c0330685254e4d5ab36d080c9113

Verification: Evaluator: REJECT - three reasons, all substantiated, artifact at .jeffy/evaluator/d6fd570a-000001-1.md. The run does not converge. The gate re-ran the Verify command (exit 0, 142 unit and 16 doc assertions), all six closed tasks' acceptance checks (all exit 0), all 12 row batteries (all exit 0), and the perf instrument (0.961x, checksums equal), and its own independent work found no defect in `pad_with`, in the lazy `cased`, or in `titlecase`, and no panic across every char in 0..=0x10FFFF in three positions.

Reason 1, and the one that matters: a missed in-envelope finding this run never looked for. `transform` splits on `!c.is_alphanumeric()`, so a combining mark that lacks the Other_Alphabetic property is a word separator: `"cafe\u{301}".to_snake_case()` returns `"cafe"`, dropping the accent, and `"na\u{308}ive".to_snake_case()` returns `"na_ive"`, manufacturing a boundary inside a word. I reproduced both before accepting the reason, and also confirmed the boundary of the class: precomposed forms are unaffected, and Other_Alphabetic marks - Devanagari U+093F, Hebrew U+05C1, the Arabic vowel marks the kebab tests already pin - survive, so the defect is exactly NFD Latin, Greek and Cyrillic text. Filed as NFD-1 at High, above the Medium the gate suggested, because the rubric's High covers data loss and the loss here is silent.

Reasons 2 and 3: SIGMA-2 and TITLE-2 were misscored Low. Accepted and re-scored Medium. The gate's argument is the one I should have applied myself - a wrong output string is not polish, and the rarity rationale I attached to both was an envelope argument, which PLAN.md routes through Proposed rather than through a severity. TITLE-1, the identical defect class on commoner characters, was scored Medium by this run's own first audit.

Why the reference could not catch reason 1: the harness reference splits on the same predicate as the crate, and neither corpus contains a decomposed Latin sequence, so the exhaustive differential certified the blind spot rather than exposing it. This is the second time this run that a shared assumption between reference and implementation hid a defect, and the first time was caught only because an authoritative table was transcribed. The lesson generalises: a differential is only as good as the disagreement it is capable of expressing.

Three-strike rule: NFD-1, SIGMA-2 and TITLE-2 share one root cause - the crate implements Unicode rules with only what `core` exposes, and `core` exposes the case mappings but not the properties the rules need. That ends instance work on this class. One Proposed line now carries the decision - internal table, dependency, or documented limitation - because what it trades is the crate's zero-dependency, table-free stance, which is the owner's call and not a run's.

Run state at close: out of budget at iteration 10 of 10 with one evaluator invocation unspent, so this REJECT is not terminal; convergence waits for the next run's fresh audit and gate.

Learnings: run the gate earlier than the last iteration when the budget allows - the rule says so and this run proves the cost, since a REJECT at iteration 10 has nowhere to spend its findings. Also: when a probe reference and the implementation share a predicate, the differential cannot see past it, so a corpus needs inputs chosen to attack the shared assumption, not only the implementation.

Next: NFD-1 is the next run's first task, after the owner answers the Proposed decision that governs how it can be fixed.

## iter 1/10 | f51f3c1c-005842 | 2026-08-24 | SIGMA-2 | done

Task: SIGMA-2 (Medium) - `lowercase_after` in src/lib.rs computed Unicode's Final_Sigma condition by hand, asking only whether the sigma ended the word and whether the character immediately before it was cased. Closed class-complete: a word carrying a capital sigma is now lowercased through `alloc`'s `str::to_lowercase`, which implements the condition.

Queue disposition before it: NFD-1 (High) sits at the top of Now and is now marked [b]. Its filed reproduction ran first and both halves hold - `"cafe\u{301}".to_snake_case()` is `"cafe"` and `"na\u{308}ive".to_snake_case()` is `"na_ive"` - but the fix needs the Mark property, and the probe that settled the question shows `alloc` does not carry it: `format!("A{}\u{3a3}", c).to_lowercase().ends_with('\u{3c2}')` answers Cased-or-Case_Ignorable, true alike for U+02BC, U+0301, U+05C1 and a plain `x`, so a separator predicate built from it would also stop splitting on apostrophes, periods and colons. That leaves NFD-1 on the Proposed decision and waiting on the owner, so SIGMA-2 was the top unblocked item.

Changed: src/lib.rs (`lowercase_after`), src/snake.rs (four tests), .jeffy/probes/harness/src/lib.rs (three corpus entries), .jeffy/probes/harness/tests/case_mapping_helpers.rs (deviation lists, the Final_Sigma assertions, one new sufficiency test), .jeffy/probes/harness/tests/ for snake, kebab, lower_camel, title, train and upper_camel (deviation lists), CHANGELOG.md, BACKLOG.md, PLAN.md.

Checkpoint: 65502ce054db72370785a36c36cdaa43207d495a

Verification: the class is wider than the instance that was filed. Besides `"A\u{2bc}\u{3a3}"`, the hand-written condition also missed a sigma followed by an uncased non-ignorable character (`"\u{391}\u{3a3}1"` gave `"\u{3b1}\u{3c3}1"` where `str::to_lowercase` gives `"\u{3b1}\u{3c2}1"`) and one followed by a case-ignorable (`"\u{391}\u{3a3}\u{2bc}"` gave `"\u{3b1}\u{3c3}\u{2bc}"` for `"\u{3b1}\u{3c2}\u{2bc}"`). All three were written as tests before the fix and all three failed on the unfixed code; the negative control `"\u{391}\u{3a3}\u{2bc}\u{392}"`, where a cased character after the ignorable keeps the non-final form, passed both before and after. Unit suite 146 passed, 0 failed. Verify green (0s, test result: ok. 16 passed) through quiet-verify.sh. All 13 batteries green.

The guard is checked rather than asserted. `lowercase_after` streams `char::to_lowercase` per character and falls back to `str::to_lowercase` only when the word contains a capital sigma, which is sufficient only if no other character is lowercased contextually. Every scalar value in 0..=0x10FFFF was driven through four contexts and exactly one, `\u{3a3}`, differs; that sweep is now `sigma_is_the_only_context_sensitive_lowercase` in the case-mapping-helpers battery, which it lengthens to about 3s.

Contract preserved: no signature and no public type changed, and `lowercase_after` is private. The only observable change is the sigma output, recorded in CHANGELOG.md under unreleased. Six batteries listed `"A\u{2bc}\u{3a3}"` under KNOWN_DEVIATIONS and failed on the fix exactly as they were built to; each was updated in this iteration, three of them to an empty set, and the harness corpus gained the two shapes it had no input to express plus the negative control.

Cost: the fallback needs one scan per word. Six samples of .jeffy/probes/perf against the pre-change tree read 0.959x, 1.079x, 1.013x, 1.020x, 1.066x and 1.008x - five above parity, but all except one inside the 0.955x-1.067x band the instrument documents for an unchanged tree, so the cost is at most a couple of percent and is not cleanly separable from noise on this host.

Closed this iteration: SIGMA-2 (Medium) - fixed class-complete, recorded under Settled classes with its enumerating commands.

Learnings: `alloc` is Unicode data this crate already links and was not using. `str::to_lowercase` carries Cased and Case_Ignorable, which `core` does not expose, so a rule needing those can be delegated rather than tabulated - and that is what took SIGMA-2 out of the Proposed decision it was filed under, without trading the crate's zero-dependency stance. It does not reach every property: Mark is not derivable from it, which is exactly what keeps NFD-1 blocked. Second: a claim about a context-sensitive mapping cannot be checked one character at a time. The first version of the sufficiency sweep compared `c.to_string().to_lowercase()` against `c.to_lowercase()` and returned an empty set, including for sigma, because a lone sigma is not word-final in the sense the condition means.

Next: TITLE-2, the last open Medium. Its fix needs no property predicate, only the titlecase mapping of 63 characters, which extends the table `titlecase` in src/lib.rs already carries for the Latin digraphs and Georgian.

## iter 2/10 | f51f3c1c-005842 | 2026-08-24 | TITLE-2 | done

Task: TITLE-2 (Medium) - `titlecase` in src/lib.rs carried an explicit titlecase mapping for the Latin digraphs and Georgian but not for the Greek characters with an iota subscript, so it fell through to its uppercase-expansion path and raised the subscript to a capital iota. Closed: the mapping now covers them, and with it the whole titlecase class.

Changed: src/lib.rs (`titlecase` and its doc comment), src/title.rs (seven tests), .jeffy/probes/harness/tests/case_mapping_helpers.rs (the deviating-set test, now asserting the set is empty, and the capitalize deviation list), .jeffy/probes/harness/tests/ for title, train and upper_camel (deviation lists), CHANGELOG.md, BACKLOG.md, PLAN.md.

Checkpoint: a9a75912719a9dc89ccb07e57c09b6954170bc90

Verification: the filed reproduction ran first and holds - `"\u{1f80}\u{3b2}".to_title_case()` gave `"\u{1f08}\u{3b9}\u{3b2}"` where Unicode gives `"\u{1f88}\u{3b2}"` - and it showed one case the filing did not name: `"\u{1f88}"`, which is already a titlecase character, also came back as `"\u{1f08}\u{3b9}"` rather than itself. Seven tests were written before the fix, one per shape the mapping has, and all seven failed on the unfixed code. Unit suite 153 passed, 0 failed. Verify green (1s, test result: ok. 16 passed) through quiet-verify.sh. All 13 batteries green.

The acceptance check is met on both halves: `"\u{1f80}".to_title_case()` is `"\u{1f88}"`, and the battery's deviating set is empty where it was 63. That set is computed over `SPECIAL_TITLECASE`, the harness's transcription of the title column of SpecialCasing.txt, so the check is against the character database rather than against anything this run wrote - which is also why four batteries failed on the fix and had to be updated in this iteration, exactly as they were built to.

Shape of the mapping, and why it is not 63 hand-written entries. Across U+1F80..U+1FAF the titlecase form is the same code point with bit 3 set, which carries the small letters onto their capital-plus-prosgegrammeni forms and leaves those forms fixed; that is 48 of the 63 in one arm, and it was checked before it was used, not assumed. Six more are the U+1FB3/U+1FC3/U+1FF3 pairs, written out. The last nine have no precomposed titlecase form, and rather than transcribe their targets a second time the arm reuses `core`'s uppercase mapping and writes the trailing capital iota as the combining mark U+0345; that all nine uppercase to a sequence ending in U+0399 was measured first. The transcription that would have been error-prone stays in the harness, where it is the independent check.

Contract preserved: no signature and no public type changed, and `titlecase` is private. The observable change is the titlecase output of those 63 characters, which reaches `to_title_case`, `to_upper_camel_case`, `to_train_case` and every non-first word of `to_lower_camel_case`; it is recorded in CHANGELOG.md under unreleased, and the doc comment on `titlecase`, which used to disclose this gap as a known limitation, now describes the mapping instead. U+0345 is alphanumeric, so a subscript written into the output survives the segmentation of any string it is fed back through.

Surface inventory: the diff touches src/lib.rs, src/title.rs and the harness, so every battery declaring those paths was re-run against the changed code in this iteration and all 13 pass. The 12 rows are therefore re-recorded at this checkpoint on executed evidence, not re-stamped.

Closed this iteration: TITLE-2 (Medium) - fixed, and the titlecase class recorded under Settled classes with the two transcribed tables, 161 entries, that enumerate it.

Learnings: the three findings filed as one three-strike class needing Unicode property data were not one class. Two of them needed no new data at all - SIGMA-2 needed a rule `alloc` already implements, TITLE-2 needed more of a mapping table the crate already carried - and only NFD-1 needs a property predicate that nothing in `core` or `alloc` exposes. Grouping by the sentence "core does not expose enough Unicode" put three different problems under one owner decision and would have stalled two of them behind it. The root cause a three-strike rule groups on has to be the mechanism, not the excuse.

Next: the ledger holds three Lows and one blocked High. API-1 is next, then DOCS-1 and CI-1, and then the closing audit and the evaluator gate with budget still in hand.

## iter 3/10 | f51f3c1c-005842 | 2026-08-24 | API-1 | done

Task: API-1 (Low) - the eight `As*Case` wrappers carried no derives, so a caller could not derive `Debug`, `Clone` or `Copy` on any type holding one. Closed class-complete: all eight now derive the three.

Changed: all eight case modules (one derive each), src/lib.rs (a `tests` module holding the check), CHANGELOG.md, BACKLOG.md, PLAN.md.

Checkpoint: 1909388efc677c604dae8e62b37cd6f42cca3890

Verification: the acceptance check is the one the filing names - a single `#[derive(Debug, Clone, Copy)]` struct with one field per wrapper - and it was run against the unfixed code twice. Written before the fix it failed with 17 compile errors naming all eight wrappers for all three traits; and after the fix, with the derives stripped from a copy-aside of src/ and restored from it, the same 17. `git diff --stat src/` at the checkpoint is 9 files changed, 61 insertions, no deletions, so the restore was clean. Unit suite 154 passed, 0 failed. Verify green (2s, test result: ok. 16 passed) through quiet-verify.sh. All 13 batteries green.

Fix attempt 1 was rejected by the gate, and by clippy rather than by a test: the check exercised `Clone` by cloning the eight-field holder, which is `Copy`, and `clippy::clone_on_copy` is denied. Attempt 2 exercises `Clone` where it has work to do, on a wrapper over an owned `String`, and keeps the eight-field holder for what it actually proves - that the derive reaches every wrapper, since a wrapper missing one of the three fails to compile the struct.

Contract preserved: the change is additive. No signature, field or bound changed, and the derives add the standard `T: Debug`, `T: Clone`, `T: Copy` bounds to the generated impls rather than to the types, so nothing that compiled before stops compiling. Recorded in CHANGELOG.md under unreleased.

State-file claims this iteration invalidated and re-ran: the Oracle class assertion count is now 154, and the Environment fingerprint's exclusion derivation returns nine `#[cfg(test)]` module gates rather than eight, because the check needed a test module in src/lib.rs, which had none. Both lines are updated. The Surface inventory rows are re-recorded at this checkpoint, every battery having been re-run against the changed code.

Closed this iteration: API-1 (Low) - fixed class-complete, recorded under Settled classes with its enumerating command.

Learnings: the verify gate earns its place on a task this small. Nothing about adding eight derives suggested a lint failure, and the defect was in the check rather than in the fix - a test that appears to exercise `Clone` while the compiler is quietly using `Copy` proves nothing, which is what clippy said and what the rework fixed.

Next: the ledger holds two open Lows, DOCS-1 then CI-1, and one blocked High. That is fewer than the three that would normally trigger a replenishing partial audit; the run skips it deliberately, because a partial audit never counts toward convergence and the full closing audit is two iterations away and replenishes the ledger anyway. Plan for the remaining budget: DOCS-1, CI-1, the full closing audit, the evaluator gate with iterations still in hand, and the declaration.

## iter 4/10 | f51f3c1c-005842 | 2026-08-24 | DOCS-1 | done

Task: DOCS-1 (Low) - three `As*Case` wrapper doc headlines named the wrong conversion: `AsShoutyKebabCase` said "a kebab case", `AsShoutySnakeCase` had a doubled space, and `AsUpperCamelCase` said "a upper camel case" where its own trait says "an upper camel case". Closed class-complete: every wrapper headline now matches its trait headline word for word.

Changed: src/shouty_kebab.rs, src/shouty_snake.rs, src/upper_camel.rs (one doc line each), BACKLOG.md, PLAN.md.

Checkpoint: 8ff8a109c90fc84091a8467a58f65bc379b09c29

Verification: both halves of the filed acceptance check hold - the three greps it names return no match, and the suite stays green at 154 unit assertions, 0 failed. Verify green (1s, test result: ok. 16 passed) through quiet-verify.sh. All 13 batteries green.

The class check is the enumeration, and getting it right was the work. The class is "a wrapper headline that disagrees with its trait headline", which spans all eight case modules, so the check derives both headlines per module and compares them. Run against HEAD it names exactly the three filed modules; run against the working tree it names none. The command is recorded on the Settled classes line and was extracted from BACKLOG.md and executed verbatim before this entry was written, exit 0 with no output.

The first form of that check was wrong in a way worth recording. It compared two whole grep outputs, one of trait headlines and one of wrapper headlines, and reported only two of the three defects: it dropped the article when capturing, so `a upper camel case` against `an upper camel case` looked identical. Widening the capture to include the article exposed the third - and exposed a second fault at the same time, because the two lists were not even in the same order. `grep` in the loop shell is a shim over ugrep, which parallelises and does not preserve file order across a glob, so pairing two ordered lists is unsound here whatever they contain. The final check pairs inside each file and never depends on output order. Both faults are now in Lessons.

No CHANGELOG entry: the crate's unreleased section records behaviour changes, and this changes rendered documentation only. No public interface, signature or behaviour changed, so there is nothing for a caller to adapt to.

Closed this iteration: DOCS-1 (Low) - fixed class-complete, recorded under Settled classes with its enumerating command.

Learnings: an enumeration that normalises away part of what it is checking will certify the site it cannot see. The article was noise to the regex and the whole defect to the reader, and the check only became honest when it stopped tidying its input. The ordering fault underneath it was invisible until the first fault was fixed, which is the ordinary shape of these things: one weak check hides another.

Next: CI-1, the last open Low, then the full closing audit, the evaluator gate with iterations still in hand, and the declaration. The ledger is down to one open task, below the replenishment threshold, and the run continues to skip the partial audit for the reason recorded last iteration - the closing audit is next but one and both replenishes and counts.

## iter 5/10 | f51f3c1c-005842 | 2026-08-24 | CI-1 | done

Task: CI-1 (Low) - all four CI jobs pinned `actions/checkout@v2`. Closed: all four now pin v7.

Changed: .github/workflows/rust.yml (four pins), BACKLOG.md.

Checkpoint: f996bb3d4b18d5b9f1b9e71bfb93da5a232d9cd4

Verification: both halves of the filed acceptance check hold. The grep it names returns 0, and "every job pins a major GitHub currently supports" is checked by parsing the workflow with PyYAML rather than grepping it - a bare grep for a job key also matches the `on:` triggers, and the first version of this check reported six jobs for that reason. Parsed, the file has four jobs; at HEAD all four pinned v2 and the check exits 1, in the working tree none do and it exits 0. The command is recorded on the Settled classes line and was extracted from BACKLOG.md and run verbatim before this entry, exit 0. Verify green (1s, test result: ok. 16 passed) through quiet-verify.sh. All 13 batteries green, including build-surface, which owns this file and asserts the four jobs still exist by name.

The version choice was measured, not remembered. `actions/checkout` `releases/latest` is v7.0.1, published 2026-07-20; the `action.yml` at the v2 tag declares `using: node12` and at v7 declares `using: node24`, which is the finding's premise and its remedy stated as two facts rather than as recollection. v7's one behavioural change over v6 blocks checking out fork pull requests under `pull_request_target` and `workflow_run`; this workflow triggers on `push` and `pull_request` only, so it does not apply. v5 raised the minimum runner to v2.327.1, which GitHub-hosted `ubuntu-24.04` satisfies. Every major from v2 to v7 received a release on the same day, so v2 is still patched; it is the runtime that is stale, which is what the finding said.

Considered and not filed: the three `dtolnay/rust-toolchain@master` and `@stable` steps pin a third-party action to a mutable ref. That is the usage the action's own documentation prescribes, so filing it would be filing against upstream's published guidance rather than against a defect, and the closing audit will look at build-ci with this noted rather than inheriting a finding from it.

No CHANGELOG entry: this changes CI configuration, not the crate. Nothing a caller compiles against moved.

Closed this iteration: CI-1 (Low) - fixed class-complete across all four jobs, recorded under Settled classes with its enumerating command.

Learnings: the same failure as last iteration, in a different disguise - an enumeration that pattern-matches text where it should parse structure. Yesterday it was two grep outputs that were not in the same order; today it was a job-key regex that matched the workflow's trigger keys. Both times the check looked right and was loose, and both times the fix was to stop reading the file as lines. This one has a parser available, so it uses it. [recurred]

Next: the ledger holds no open task and one blocked High, so the next iteration is the full closing audit with fresh evidence across every dimension. On a clean score the run enters closeout, then the evaluator gate with iterations still in hand, then the declaration.

## iter 6/10 | f51f3c1c-005842 | 2026-08-24 | AUDIT | audit

Task: Full closing audit with fresh evidence, over all 12 Surface inventory rows, none unswept and none stale. Files no new finding, at any severity. Closeout has begun: the run does no further auditing and no replenishment, and finishes by converging.

Changed: PLAN.md only - one stale Environment fingerprint claim corrected, and the inventory rows re-recorded. BACKLOG.md is unchanged, which under the stall check is a no-progress iteration; it is an AUDIT that files nothing, which is the exemption, and it is stated here rather than left to be inferred.

Checkpoint: 9f257c3d3a58fd101116b30ee2487e8c5676603c

Verification: scores below, each from evidence produced this iteration rather than re-read from an earlier one.

- correctness: High, carried, not new. NFD-1 remains the one open in-envelope High and is blocked on the Proposed decision; nothing else surfaced. Fresh evidence: all 13 batteries green, which is exhaustive ASCII differentials over 3906 inputs per conversion against an independent reference plus the Unicode corpus; and a new cross-conversion consistency probe over both corpora, 3947 inputs, checking that conversions differing only in separator agree after substitution - kebab against snake, shouty kebab against shouty snake, train against title, upper camel against title - 0 mismatches on all four. A fifth invariant, shouty snake against snake uppercased word-wise, reported two mismatches at U+0130, and they are the invariant's fault rather than the crate's: `"\u{130}".to_lowercase()` is `"i\u{307}"` and uppercasing that gives `"I\u{307}"`, so `upper(lower(x)) == upper(x)` is simply false in Unicode. heck returns `str::to_uppercase` exactly on both inputs. Not filed.
- security: None. `#![forbid(unsafe_code)]`, `#![no_std]`, and `grep -rn 'std::env|std::fs|std::net|std::io|unsafe' src/` returns only the forbid attribute itself; `cargo tree` is a single node, so there is no third-party code to audit. The adversarial surface is the `&str` argument, and it was swept exhaustively: every one of the 1112064 scalar values, in three shapes each, through all eight conversions - 0 panics.
- error handling: None. The only fallible operation in the crate is writing to the formatter, so the enumeration was built by provoking a failure at every step rather than by reading the source for write calls. A sink that fails on its nth write was run for every n across six inputs and eight conversions, 205 write steps in all, and every one propagated `fmt::Error`. 0 swallowed.
- performance: None. ns per byte is flat from 10k to 1M bytes across five shapes chosen to stress different paths - one long word, all separators, alternating case, all uppercase, and an all-sigma word - so the conversions are linear and there is no algorithmic denial of service on the adversarial surface. The sigma path costs about 2.5x per byte, which is the `str::to_lowercase` fallback and is linear too. The perf battery is at parity.
- testing: None. 154 unit assertions and 16 doc tests. Every case module was run in isolation as well as whole, `lower_camel::` and `shouty_snake::` each 12 passed with 142 filtered out, so nothing in the suite depends on another module having run first.
- documentation: None. 16 doc tests pass. All three documented word-boundary rules appear identically in README.md and the crate root, checked by extracting them from the crate docs and searching the README for each. Every wrapper headline matches its trait headline, by the check settled in DOCS-1.
- dependency hygiene: None. Zero dependencies. `cargo package --list` ships src/, the two licenses, README.md and CHANGELOG.md and nothing else - no state file and no path under .jeffy/ reaches a published crate.
- developer experience: None. The wrappers derive Debug, Clone and Copy; the MSRV 1.56 build and the thumbv6m-none-eabi bare-metal build both run here and both pass; CI pins a current action major.
- architecture: None. Eight modules over one shared `transform` and three case helpers, and clippy `--all-targets -D warnings` is clean, which is also what would flag an unreachable private helper.
- code quality: None. rustfmt and clippy both clean through the gate.
- observability: not applicable. A `no_std` library with no I/O has nothing to instrument, and adding logging would mean adding a dependency and an allocation to a crate whose value is having neither.
- UX and accessibility: not applicable. There is no user-facing surface; the only consumers are Rust callers.

One state-file claim was found stale and corrected rather than filed: the Environment fingerprint said the MSRV 1.56 build is not exercised on this host and only stable is installed. Both are false - `rustup toolchain list` shows 1.56 beside stable, `rustup target list --installed` shows thumbv6m-none-eabi, and build-surface builds with both and fails rather than skips when either is missing. That line governs what a journal entry may claim was green, so it mattered more than its size suggests.

Verify green (1s, test result: ok. 16 passed) through quiet-verify.sh.

Learnings: an invariant is a hypothesis about the domain before it is a check on the code, and this audit's only red result came from a false one. Composing Unicode case mappings is not associative, so any cross-check written as `upper(lower(x))` will accuse a correct implementation at U+0130. The cost of finding out was small only because the next step was to ask which of the two was wrong rather than to file.

Next: the evaluator gate, with four iterations left so a REJECT still has budget to answer. The closing conditions otherwise hold - no unswept row, no open High or Medium task, no Declined entry to re-derive, verify green - with the whole question being whether NFD-1 blocked on an owner decision is a disposition the gate accepts.

## iter 7/10 | f51f3c1c-005842 | 2026-08-24 | EVALUATOR | converged

Task: Evaluator gate, invocation 1 of at most 2 for this run, run at iteration 7 with three iterations still in hand so a REJECT would have had budget to answer. It returned PASS and every closing condition held, so this iteration also declares.

Changed: .jeffy/evaluator/f51f3c1c-005842-1.md (the gate's artifact), JOURNAL.md, BACKLOG.md (the Converged line), PLAN.md (inventory rows re-recorded). No source file changed this iteration.

Checkpoint: e18001132bc18678cf3de529eff9346bf5006d2d

Verification: Evaluator: PASS - all 13 batteries and the Verify command re-run green, every closed task's acceptance check reproduced on both the fixed and the unfixed tree, and the three riskiest claims of this run checked against the Unicode character database rather than against the project's own transcription.

The gate's own evidence, which is stronger than this run's in the one place that matters. The Oracle class line concedes that the Verify command grades the conversions against expectations this project wrote itself, so a shared misreading of Unicode passes it. The gate went around that: it dumped `to_title_case` for all 149106 alphanumeric scalar values and diffed against UnicodeData.txt and SpecialCasing.txt directly, finding 0 mismatches against UCD 17.0, which is the version the installed rustc implements; the 28 apparent mismatches against 16.0 are code points that gained mappings in 17.0. It ran the same sweep for lowercase and uppercase, 0 mismatches. It confirmed `c as u32 | 8` is the titlecase mapping for all 48 code points in U+1F80..U+1FAF. It established that sigma is the only contextually lowercased character by reading `library/alloc/src/str.rs` rather than by sampling, which also settles that `&lowered[1..]` is always a char boundary. It checked the harness's transcriptions entry by entry, 103 and 58, 0 value mismatches. And it verified `cased` in src/lib.rs equals the Unicode Cased property exactly, 4632 against 4632 with an empty symmetric difference.

Closing conditions, each re-checked this iteration rather than carried from the audit: the full fresh-evidence audit at iteration 6 filed nothing; the Surface inventory lists 12 rows, 0 unswept and 0 unreachable, and no row is stale - the gate confirmed `git diff --name-only` over every declared battery path is empty since the audit checkpoint; Now, Next and Later hold no open High and no open Medium; `## Declined` is empty, so there is no recorded Derivation to re-run; the only commit between the clean audit and this iteration is that audit's own bookkeeping commit; the Oracle class and Environment fingerprint were both re-read and re-derived, the exclusion command returning the nine `#[cfg(test)]` module gates it names and `rustup` showing both the 1.56 toolchain and the thumbv6m-none-eabi target the corrected fingerprint claims; all 13 batteries green in this iteration; and Verify green (1s, test result: ok. 16 passed) through quiet-verify.sh.

Carried findings at this declaration: no open Low, in any section - API-1, DOCS-1 and CI-1 were all closed this run. One item is carried, and it is not a Low:

- NFD-1 (High, runtime, correctness), blocked. `transform` splits on `!c.is_alphanumeric()`, so a combining mark without Other_Alphabetic is a word separator and decomposed text silently loses characters: `"cafe\u{301}".to_snake_case()` is `"cafe"`. It is blocked because the fix needs the Unicode Mark property and neither `core` nor `alloc` exposes it, and the remedy is the decision recorded under `## Proposed` - an internal table, a dependency, or a documented limitation - which trades this crate's zero-dependency, table-free character and is therefore the owner's to make. This is a real, reproducible, in-envelope High-severity defect that this convergence does not fix and does not claim to. It is declared under the Definition of done's third disposition, blocked with its reason recorded, and the gate was asked directly whether that disposition was honest or an evasion. It reproduced the defect on five conversions, re-derived the premise itself - a separator predicate built from what `alloc` reveals classifies 1445 non-alphanumeric scalar values as Case_Ignorable, including the apostrophe, the period and the colon, which the crate's documented boundary rule requires it to split on - re-scored the severity as correctly High in both directions, and concluded the marker is honest, noting that this same run pulled SIGMA-2 and TITLE-2 out of that identical Proposed decision and fixed both.

Learnings: the gate is worth more when it is pointed at the run's own weakest premise rather than left to browse. Naming the three claims this run would least like to be wrong about, and the one judgement the run could not make impartially about itself, is what produced an independent UCD diff and an independent derivation of the NFD-1 premise instead of a second reading of the same files.

Next: nothing. The run converges here, and the next run's first task is whatever the owner decides for NFD-1.
