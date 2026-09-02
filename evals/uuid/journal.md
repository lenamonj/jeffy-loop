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

## iter 1/10 | f60feaff-141833 | 2026-09-02 | AUDIT | audit

Task: first audit of a fresh Jeffy project - enumerate the input surfaces, verify the publication channels, fill the Verify command block, map the whole public surface into the Surface inventory, then probe breadth-first and file what the probes found.

Changed: PLAN.md (Operating envelope surfaces, 23 Surface inventory rows, Verify command block, two Stated counts rows), BACKLOG.md (F1 and F2 under Next, F3 and F4 under Later, one Proposed item), JOURNAL.md.

Checkpoint: 742b58735654eebc1a5d59ca943f4ca2d3ad52b2

Verification:
- Publication channels enumerated by command, not recall: the manifests are `./Cargo.toml`, `./rng/Cargo.toml`, `./examples/Cargo.toml`, `./fuzz/Cargo.toml`, `./tests/smoke-test/Cargo.toml` and `./tests/wasm32-getrandom-test/Cargo.toml` (`find . -name Cargo.toml -not -path './target/*'`), and only the first two are published crates. `cargo package --list --allow-dirty` on each lists src plus README and the two licences for `uuid`, and Cargo.toml plus src/lib.rs for `uuid-rng-internal`; neither lists PLAN.md, BACKLOG.md, JOURNAL.md or any path under .jeffy/, because the root manifest carries an `include` allow-list. The two workflows in .github/workflows are ci.yml and outdated.yml and neither archives the tree, so there is no third channel. Nothing to file.
- Verify command filled and run through the wrapper: green (3s), `verify totals: 219 passed, 0 failed, 0 ignored`. The Verify count cell holds that 219.
- Probes executed against a scratch crate with a path dependency on this tree, exercising: the endianness roundtrips in both directions for fields, bytes, u128, the u64 pair and both slice constructors; `Builder::with_version` over all ten `Version` values and `with_variant` over all four `Variant` values, each read back through `get_version_num` and `get_variant`; a hand-built gregorian tick count through `from_gregorian_timestamp` and `from_sorted_gregorian_timestamp` and back out through `get_timestamp().to_gregorian()` and `get_node_id()`; a known millisecond through `from_unix_timestamp_millis` and back; 1000 consecutive `new_v7` calls against one `ContextV7` at a fixed timestamp, each strictly greater than the last; the four format wrappers in both cases against hand-written expected strings; the four typed `FromStr` parsers accepting only their own shape; and the six `uuid::serde::*` adapters through serde_json. All held except the two filed below.
- F1 reproduced: `#[serde(with = "uuid::serde::bytes")]` serializes to `{"b":[249,22,...]}` and deserializing that same string back fails with `invalid type: sequence, expected a 16 byte array at line 1 column 6`. `uuid::serde::compact` round-trips in the same test, so the failure is the adapter, not serde_json.
- F2 reproduced: `Uuid::parse_str("F9168C5E-CEB2-4faa-B6BF-329BF39FA1E")` reports `found 11`, while the braced form of the same value reports `found 13` and the URN form `found 20`. The deltas are exactly the two braces and the nine characters of `urn:uuid:`.
- Scores, claiming only what was examined: correctness Medium (F1, F2), error handling Medium (F2), documentation Low (F3, F4), testing Low - the suite is green over both Mediums, and that gap is carried by F1's and F2's acceptance checks rather than filed a second time - architecture None, code quality None, security None, performance None, developer experience None. Observability and UX/accessibility do not apply: this is a no-std library with no user-facing surface and no logging of its own beyond the slog integration. Dependency hygiene is not scored: neither cargo-audit nor cargo-deny is installed on this host, so nothing here has checked the dependency set against an advisory database.
- The Surface inventory lists 23 rows and every one of them is unswept. These scores are therefore a first pass over a shallow read plus the probes above, not a certificate over the map: no row carries a battery yet, and the sweep is what the remaining iterations owe.

Learnings: `cargo test` prints one `test result:` line per target and no aggregate, so a Verify summary pattern matching `test result:` would quote whichever target ran last - here the 93 doc tests, not the 219 total. The Command line sums the three lines itself and prints `verify totals:` for the wrapper to match.

Next: F1, the serde byte-string round trip, is the top of the queue.

## iter 2/10 | f60feaff-141833 | 2026-09-02 | SWEEP | done

Task: sweep the Surface inventory. The ledger held no open High, so the map was the top of the queue; this iteration built the probe batteries and swept every row it could properly evidence.

Changed: .jeffy/probes/battery-crate (a single Cargo package holding thirteen battery binaries and the shared check harness, detached from the uuid workspace by its own `[workspace]` key and ignoring its own build directory), thirteen battery directories under .jeffy/probes/ each with paths, claims, README.md and run.sh, PLAN.md (thirteen inventory rows flipped, in the bookkeeping edit below), BACKLOG.md (F5 filed under Now), JOURNAL.md.

Checkpoint: 9568492225292c14a93fed2045532fccd0e25f02

Verification:
- Thirteen batteries, 2369 checks in total, all green: uuid-inspect 576, uuid-convert 46, uuid-ctors 30, builder-api 80, parser 605, error-diagnostics 24, fmt-adapters 43, fmt-encode 62, fmt-fromstr 153, timestamp-core 332, version-v1-v6 160, version-v3-v5 65, non-nil 33. `check-claims.sh` reports 15 checked, 0 mismatched, 0 errored, 0 skipped, which is the thirteen battery claims plus the two PLAN.md Stated counts rows.
- Every battery was run against a deliberately broken tree before it was trusted, one mutation per battery, each recorded in that battery's README under "What it was observed failing on". Each mutation reddened its own battery and each was reverted with `git checkout -- src`; the tree was verified clean before and after every one. The counts observed under mutation, in the order above: 544/576, 44/46, 29/30, 67/80, 91/605, 20/24, 41/43, 53/62, 119/153, 316/332, 159/160, 56/65, 32/33.
- The evidence bar per row was a known-answer or invariant check, never a liveness probe. The version-3 and version-5 answers come from an independent MD5 and SHA-1 implementation and from the RFC 9562 appendix A.1 and A.2 vectors; the version 1, 6 and 7 encodings come from the RFC 9562 field layout computed outside this crate, including the appendix A.6 version 7 example; the variant and version readers are checked over their entire one-byte domain rather than on samples.
- Documented parameters were exercised at two or more values that must change the output: `with_version` at all ten `Version` values, `with_variant` at all four `Variant` values from two starting bytes, the node ID at three values, the version 1 and 6 counter at four values, the tick count at each of its sixty bit positions, and both digest arguments independently.
- Verify green through the wrapper (3s), `verify totals: 219 passed, 0 failed, 0 ignored`.
- F5 filed at High. The sweep of the version 7 surface surfaced it, and the finding is a placement error rather than a rounding one: `mask_counter_into_random` shifts the counter by `128 - counter_bits` so its most significant bit lands at bit 127 of the u128, but `encode_unix_timestamp_millis` takes the top ten bytes of that value and spends the first four bits on the version nibble, so the counter needs to start at bit 123. Measured consequences, from a scratch crate with a path dependency on this tree: with a 42-bit counter, setting any of bits 41, 40, 39 or 38 produces a UUID whose `rand_a` and the top of whose `rand_b` are identical to those for a counter of zero, so those four bits are lost; the all-ones 42-bit counter yields `rand_a` = 0xff3 rather than 0xfff, the two zero bits being the misplaced variant gap; incrementing a counter from 0x3fffffffff to 0x4000000000 makes the UUID sort lower rather than higher; and over a sweep of 53 pairs of instants ordered forward inside one millisecond through one `ContextV7::new().with_additional_precision()`, 29 pairs produced UUIDs that sort backwards. With 12 bits of additional precision only 8 of them reach the UUID, and because the dropped bits are the most significant ones the surviving value wraps: a sub-millisecond offset of 250us gives the top eight bits 0xfc and one of 500us gives 0xf8.
- Ten rows remain unswept. Two of them - timestamp-context and version-v4-v7-v8 - are deliberately left for the iteration that fixes F5: a battery written now could only pin the broken placement or sit red in the tree, and neither is an instrument. The other eight are uuid-traits, rng-native, rng-wasm, macro-uuid, serde-uuid, serde-adapters, external-traits and dev-surfaces.

Learnings: the batteries share one Cargo package under .jeffy/probes/battery-crate so thirteen binaries share one compile of `uuid`; its `[workspace]` key detaches it from the uuid workspace, which lists its members explicitly and would otherwise refuse to build a package inside its own directory, and its own .gitignore covers its build directory because the root .gitignore anchors `/target/` to the repository root. Sorting claims about version 1 need a tick pair that crosses a time_low boundary: adding 2^32 or 2^40 to a tick count leaves time_low unchanged, so version 1 appears to sort correctly over any such sequence, and two batteries asserted the opposite before that was measured.

Next: F5 is an open High and outranks the remaining rows.

## iter 3/10 | f60feaff-141833 | 2026-09-02 | F5 | done

Task: F5, the version 7 counter placement. Closed: `Uuid::new_v7` now seats the counter at the top of the UUID's payload instead of at the top of the intermediate `u128`, so the four bits the version nibble was eating survive and the variant gap lands on the variant.

Changed: src/v7.rs (the counter placement in `new_v7`, its `# Counter treatment` documentation, and two regression tests), PLAN.md (Verify count 219 to 221, four Lessons lines), BACKLOG.md (F5 deleted, F6 filed under Next), JOURNAL.md.

Checkpoint: 43f1e24afe0d5bc7e920701cabd7f996d0794f9b

Verification:
- The filed reproduction ran first, against the tree as it stood: `out-of-order pairs within one millisecond: 29/53`, and the top four bits of a 42-bit counter gave `rand_a` 0x000 for both a counter of zero and a counter of 0b1111 << 38. After the fix the same program reports `0/53` and 0x000 against 0xf00.
- Contract preserved: `new_v7` keeps its signature, its version and variant fields, and its timestamp encoding; what moved is where the counter bits land inside the payload, which no test pinned as a literal. The documented contract - at most 74 counter bits used, the rest random - was not true before and is now, and the documentation was extended in the same iteration to say which 74 bits a wider counter contributes, because that behaviour changed from the low bits after shifting to the most significant ones.
- Two regression tests added to src/v7.rs. `test_counter_reaches_the_uuid` drives each of the 42 counter bit positions and asserts the counter-owned field changes, asserts an all-ones counter fills `rand_a` with ones and keeps the RFC variant, and asserts a carry from 0x3f_ffff_ffff to 0x40_0000_0000 sorts upwards. `test_additional_precision_sorts_within_a_millisecond` drives the same 53 instant pairs as the filed reproduction through one context.
- Differential evidence that both checks are strong enough to fail: the fixed src/v7.rs was copied aside, the implementation alone was reverted with the new tests left in place, and `cargo test --lib --features v7 v7::` then reported `FAILED. 7 passed; 2 failed` with both new tests named; restoring the copy returned it to `ok. 9 passed; 0 failed`. The first form of `test_counter_reaches_the_uuid` also failed against the fix, because it inspected only `rand_a` and two bytes while a 42-bit counter reaches down to byte 11; the check was widened to the whole counter-owned field rather than weakened.
- Battery ownership: `grep -l 'src/v7.rs' .jeffy/probes/*/paths` returns nothing, so no row's battery covers this diff and no row went stale. All thirteen batteries were re-run anyway through check-claims.sh: 15 checked, 0 mismatched, 0 errored, 0 skipped.
- Verify green through the wrapper, `verify totals: 221 passed, 0 failed, 0 ignored`, and the Verify count cell was moved to 221 in the same iteration.
- F6 filed at Medium while reading the encoder this fix depends on. `Builder::from_unix_timestamp_millis` tells callers not to store significant data in "the 2 least significant bits of the 3rd byte"; measured against the shipped encoder, setting those two bits changes the UUID, while setting the 2 most significant bits of the 3rd byte or the 4 most significant bits of the 1st byte does not. It is scored Medium as a docs-class finding with its Consequence written on the line: a caller who follows the advice still loses the four highest bits of their counter silently.

Learnings: to show an acceptance check fails on the unfixed code, copy the fixed file aside, revert only the implementation while keeping the new tests, run, then restore from the copy; `git checkout` on a path carrying the fix would delete the thing being proved. The verify command sums cargo's per-target result lines, so adding a test moves the `Verify count` cell and it has to move in the same iteration.

Next: the queue has no open High, so the ten unswept Surface inventory rows come next, and two of them - timestamp-context and version-v4-v7-v8 - are now unblocked because the placement they would have pinned is fixed.

## iter 4/10 | f60feaff-141833 | 2026-09-02 | SWEEP | done

Task: sweep the remaining Surface inventory rows. Nine were swept with new batteries and one was disclosed as unreachable on this host.

Changed: nine new batteries under .jeffy/probes/ (uuid-traits, timestamp-context, version-v4-v7-v8, rng-native, macro-uuid, serde-uuid, serde-adapters, external-traits, dev-surfaces) with their sources under .jeffy/probes/battery-crate/src/bin, a `no_panic` check added to the shared harness, PLAN.md (nine rows flipped in the bookkeeping edit below, rng-wasm marked unreachable, the dev-surfaces scope narrowed), JOURNAL.md.

Checkpoint: 90d1ed8cbc31708b181ee1704c2549e0c8d674a2

Verification:
- Nine batteries, 348 checks, all green: uuid-traits 35, timestamp-context 55, version-v4-v7-v8 80, rng-native 14, macro-uuid 20, serde-uuid 68, serde-adapters 36, external-traits 28, dev-surfaces 12. `check-claims.sh` now reports 24 checked, 0 mismatched, 0 errored, 0 skipped, which is twenty-two battery claims plus the two PLAN.md Stated counts rows.
- Every one was run against a deliberately broken tree first, one recorded mutation each, reverted with `git checkout -- src` and the product tree verified clean before and after. The counts observed under mutation, in the order above: 33/35, 49/55, 78/80, 13/14, 8/20, 65/68, 32/36, 26/28, 10/12.
- Two of those mutation runs printed nothing on the first attempt: `serde_test`'s assertions and an unwrapped `from_str` abort the process, so a red battery lost its summary line instead of reporting one. The harness gained a `no_panic` check that counts a panic as one failed check, the serde batteries were moved onto it, and both then reported a real count under mutation. An instrument that dies instead of reporting is an instrument that cannot be graded.
- The evidence bar per row was a known-answer or invariant check. The randomness row has no known answer, so it is checked on the invariants a stubbed source breaks: 4096 version 4 draws distinct, exactly the six version and variant bits fixed and no others, no free bit outside a tenth of an even split, and the same over 4096 version 7 payloads.
- Documented parameters were exercised at two or more values that change the output: `with_additional_precision_bits` at six widths against the precision formula written out independently, `with_adjust_by_millis` at five values, `ContextV1::new` at five seeds, all 42 version 7 counter bit positions, and the four textual serde adapters over the full four-by-four grid of wrapper against shape.
- The F5 fix is now pinned from a second direction: with twelve bits of additional precision, `rand_a` equals the precision value exactly, which is what the row's battery asserts at six widths and five instants.
- rng-wasm is disclosed rather than swept: `rustup target list --installed` does not list wasm32-unknown-unknown and wasm-pack is not on PATH, so neither the WebCrypto backend nor the `uuid-rng-internal` re-exports can be built or driven here. The row carries that reason. The `tests/wasm32-getrandom-test` crate moved from the dev-surfaces scope into that row in the same edit, because it is a test of exactly the surface that is unreachable, and leaving it under a row this host can sweep would have let a swept row cover code nothing ran.
- Two environment facts the dev-surfaces battery had to accommodate, both recorded in its script rather than worked around silently: four benchmark targets carry `#![feature(test)]` and so build only on nightly, which is installed here; and the fuzz crate is its own workspace whose optional `afl` dependency is not in this tree's lock file, so its check is the one that needs the registry reachable.
- No new finding. The nine sweeps surfaced nothing in envelope: every check either passed or, in three cases, showed my own expectation to be wrong - the group-length error text, the json array spacing, and the width of the counter-owned field - and each expectation was corrected against the shipped behaviour rather than the other way round.
- Verify green through the wrapper, `verify totals: 221 passed, 0 failed, 0 ignored`.

Learnings: a battery must not abort on a failing check. `serde_test`'s assertions panic and an unwrapped deserialize panics, so both belong behind the harness's `no_panic` check; a battery that dies under mutation cannot be shown to fail and therefore cannot be trusted when it passes. A `git status --porcelain -- src` guard run from inside .jeffy/probes/battery-crate matches that crate's own src directory rather than the product's, so mutation scripts have to use `git -C <project root>`.

Next: the ledger is at F1, F6 and F2 in Next and F3, F4 in Later, with 22 of 23 rows swept and one disclosed unreachable. F1, the serde byte-string roundtrip, is the top of the queue.

## iter 5/10 | f60feaff-141833 | 2026-09-02 | F1 | done

Task: F1, the serde byte-string roundtrip. Closed: `UuidBytesVisitor` now implements `visit_seq`, so both of its construction sites read back the sequence of integers a format without a dedicated byte string type writes for `serialize_bytes`.

Changed: src/external/serde_support.rs (a shared `visit_seq_of_bytes` helper, `visit_seq` on the byte visitor, three regression tests), PLAN.md (Verify count 221 to 224), BACKLOG.md (F1 deleted), .jeffy/probes/battery-crate/src/bin/serde-adapters.rs and the serde-adapters claims and README, JOURNAL.md.

Checkpoint: 14222fb0bdbc5959b74e893e7b55a0bc5f4b7dc9

Verification:
- The filed reproduction ran first, against the tree as it stood: `#[serde(with = "uuid::serde::bytes")]` wrote `{"id":[249,22,...]}` and reading that same string back failed with `invalid type: sequence, expected a 16 byte array at line 1 column 7`. After the fix the same program reads back `f9168c5e-ceb2-4faa-b6bf-329bf39fa1e4`.
- The generalising claim in the filed line was that one visitor backs two `deserialize_bytes` call sites. That enumeration is `grep -n 'UuidBytesVisitor {' src/external/serde_support.rs`, which returns two construction sites, and this iteration drives both rather than the one the filing reproduced: `test_bytes_roundtrip_through_a_sequence` covers the `serde::bytes` adapter through serde_json, and `test_deserialize_non_human_readable_from_a_sequence` covers `Deserialize for Uuid`'s compact branch through serde_test's `Compact` configuration. A third test pins the length error a short sequence produces.
- Differential evidence: the fixed file was copied aside, the `visit_seq` method alone was removed with the three tests left in place, and `cargo test --all-features --lib serde` then reported `FAILED. 24 passed; 3 failed` naming all three; restoring the copy returned it to `ok. 27 passed; 0 failed`.
- Contract preserved: no public signature changed and no accepted input was narrowed. What widened is that the byte visitor now also accepts a 16 element sequence, which is exactly what the readable visitor beside it already accepted and exactly what this crate's own serializer produces in such a format. A sequence of any other length is refused by length, which the third test pins.
- The sixteen unrolled `match seq.next_element()?` arms in the readable visitor were replaced by the shared helper the byte visitor now also calls. The helper returns `invalid_length(index, expecting)` at the same index the unrolled form did, so the readable visitor's errors are unchanged, and the two visitors can no longer drift apart - which is how this defect existed at all.
- Battery ownership: `grep -l 'src/external/serde_support.rs' .jeffy/probes/*/paths` returns serde-uuid and serde-adapters. Both were re-run through the installed run-probe.sh: 68/68 and 39/39. serde-adapters gained three checks for the behaviour this fix restores - the json roundtrip, the same for the nil value, and a fifteen element sequence refused by length - so its claims line and README were updated in the same iteration, and its recorded mutation still reddens it.
- check-claims.sh: 24 checked, 0 mismatched, 0 errored, 0 skipped.
- Verify green through the wrapper, `verify totals: 224 passed, 0 failed, 0 ignored`, and the Verify count cell moved to 224 in the same iteration.

Learnings: none beyond the rules already recorded.

Next: F2, the parse diagnostic that measures the final group against the whole input, is the top of the queue.

## iter 6/10 | f60feaff-141833 | 2026-09-02 | F2 | done

Task: F2, the parse diagnostic that measured the final group against the whole input. Closed: `InvalidUuid::into_err` now measures it against the hyphenated slice, so a braced or URN input reports the group's real length instead of one inflated by its wrapper. F2 was taken ahead of F6 although the ledger listed F6 first, because both are Medium and the ordering rule puts runtime before docs.

Changed: src/error.rs (one expression), src/parser.rs (one regression test), PLAN.md (Verify count 224 to 225), BACKLOG.md (F2 deleted, F7 filed under Later), .jeffy/probes/battery-crate/src/bin/error-diagnostics.rs with its claims and README, JOURNAL.md.

Checkpoint: 8fbe908c07137b99665a6c2e25333327962fc157

Verification:
- The filed reproduction ran first, against the tree as it stood: the same value with a too-short last group reported `found 11` bare, `found 13` braced and `found 20` as a URN. After the fix all three report `found 11`.
- Contract preserved: no signature changed and no input's accepted or rejected status changed. Only the `len` field of one error kind moved, and only for inputs carrying a wrapper; for a bare input `bounds` spans the whole string, so the expression returns exactly what it returned before, which is why the crate's existing assertions on the bare form are untouched. The `index` field was deliberately left alone: it is already whole-input relative, it is not in the Display output, and `ErrorKind` is crate-private.
- Regression test in src/parser.rs drives five inputs across the three wrappers and both directions of wrongness, and also the typed `Braced` and `Urn` parsers, which reach the same code with their wrapper already stripped. Differential evidence: the fixed src/error.rs was copied aside, the one expression was reverted with the test left in place, and `cargo test --all-features --lib parser` then reported `FAILED. 10 passed; 1 failed` naming it; restoring the copy returned it to `ok. 11 passed; 0 failed`.
- F7 filed at Low. Writing the test surfaced it: the over-length URN case cannot be asserted at all, because `urn:uuid:` plus a thirteen character last group is 46 bytes and `into_err` short-circuits above 45 to a bare length error. The cap is deliberate and the parse still fails correctly, so the consequence is a less specific message on an error path rather than a wrong result, which is Low under the rubric rather than the Medium F2 carried; what distinguishes it from F2 is that F2 reported a wrong number while F7 reports a correct but coarser one. The test says so where the case would otherwise look forgotten.
- Battery ownership: `grep -l 'src/error.rs\|src/parser.rs' .jeffy/probes/*/paths` returns error-diagnostics, parser, fmt-fromstr and macro-uuid. All four were re-run through the installed run-probe.sh and were green before any battery edit: 24/24, 605/605, 153/153, 20/20. error-diagnostics then gained six checks for the behaviour this fix restores plus one recording the shape F7 describes, so its claims line and README moved in the same iteration.
- check-claims.sh: 24 checked, 0 mismatched, 0 errored, 0 skipped.
- Verify green through the wrapper, `verify totals: 225 passed, 0 failed, 0 ignored`, and the Verify count cell moved to 225 in the same iteration.

Learnings: none beyond the rules already recorded.

Next: F6, the `from_unix_timestamp_millis` documentation, is the last open Medium.

## iter 7/10 | f60feaff-141833 | 2026-09-02 | F6 | done

Task: F6, the `Builder::from_unix_timestamp_millis` documentation. Closed: the method now names the two runs of bits its encoder actually overwrites, and carries an executable example that proves it.

Changed: src/builder.rs (the `# Counter treatment` prose on `from_unix_timestamp_millis` and a new doc example), PLAN.md (Verify count 225 to 226), BACKLOG.md (F6 deleted), JOURNAL.md.

Checkpoint: c9c78d1e8ac31c3821deff931804e1a3bab1d3ef

Verification:
- The filed measurement was re-run before the edit and still holds: with all-zero counter bytes as the baseline, setting the 2 least significant bits of the 3rd byte changes the UUID, while setting the 2 most significant bits of that byte or the 4 most significant bits of the 1st byte does not. The old sentence named the two bits that survive and said nothing about the six that do not.
- The replacement names both runs - the 4 most significant bits of the 1st byte, taken by the version nibble, and the 2 most significant bits of the 3rd byte, taken by the variant - says every other bit is carried through, and points a caller who needs a monotonic counter at `Uuid::new_v7` with a `Timestamp`, which shifts the counter around both fields instead of overwriting it.
- The acceptance check is the documentation itself: the new example asserts the two overwritten runs give the same UUID as all-zero bytes and that four other bit patterns, including the rest of those same two bytes, do not. Documentation and its check are one artifact here, so they cannot drift apart, which is the failure this finding was.
- Differential evidence that the example is strong enough to fail: the encoder in src/timestamp.rs was mutated so it no longer matches the documented bits, changing `(counter_random_bytes[2] & 0x3F) | 0x80` to `& 0xFC`, and `cargo test --all-features --doc from_unix_timestamp_millis` then reported `FAILED. 0 passed; 2 failed`; restoring src/timestamp.rs from the copy returned it to `ok. 2 passed; 0 failed`.
- Contract preserved: no code changed. The method's behaviour, signature and accepted inputs are exactly as they were; only the description of them moved, from wrong to measured.
- Battery ownership: `grep -l 'src/builder.rs' .jeffy/probes/*/paths` returns builder-api, uuid-ctors, timestamp-core, version-v1-v6, version-v3-v5 and version-v4-v7-v8. All six were re-run through the installed run-probe.sh and are green: 80/80, 30/30, 332/332, 160/160, 65/65, 80/80. No battery was edited, because no behaviour a battery pins changed.
- check-claims.sh: 24 checked, 0 mismatched, 0 errored, 0 skipped.
- Verify green through the wrapper, `verify totals: 226 passed, 0 failed, 0 ignored`, and the Verify count cell moved to 226 in the same iteration.

Learnings: a documentation finding is best closed by making the documentation executable. The example that describes which bits survive is the same artifact that checks it, so the two cannot drift, which is the only reason this finding existed.

Next: the ledger is at the severity floor - F3, F4 and F7 are open and all Low, with no High and no Medium anywhere. No full fresh-evidence audit has scored clean this run, so the closing audit is what the Definition of done still needs; three iterations remain.

## iter 8/10 | f60feaff-141833 | 2026-09-02 | AUDIT | audit

Task: the closing full audit. Every dimension rescored against the rubric and the Operating envelope with fresh evidence, over a Surface inventory with no unswept row. It is not clean: one Medium and one Low were filed, so the run is not converged and the following iterations execute what this audit found.

Changed: BACKLOG.md (F8 filed under Next, F9 under Later), JOURNAL.md. No source file changed this iteration; the Surface inventory did not move; BACKLOG items did change state, so this is not a stall.

Checkpoint: 835c813d850b2fe7c0329991a05d4f7afe661643

Verification, all of it executed this iteration:
- Instruments: check-claims.sh reports 24 checked, 0 mismatched, 0 errored, 0 skipped, which runs all twenty-two batteries and both PLAN.md Stated counts rows.
- Verify green through the wrapper, `verify totals: 226 passed, 0 failed, 0 ignored`, and the Verify count cell holds 226.
- Test isolation, which the Method requires before scoring Testing clean: every module was run alone - v7 9, parser 11, fmt 18, timestamp 14, external 33, non_nil 4 - and the whole suite was run with `--test-threads=1`, giving `131 passed; 0 failed`. The three `test_now` cases that share the process-wide v1 and v7 contexts were each run alone as well. No order dependence and no leaked state. `builder::` and `rng::` report zero unit tests, which is not a gap: builder.rs is covered by its doc tests and the builder-api battery's 80 checks, and src/rng.rs is private and covered by the rng-native battery.
- Environment fingerprint re-derived by its own command and still correct: the wasm32 arms, the `target_feature = "atomics"` arms, the `uuid_unstable` arms, the miri clock, and four of the five workspace packages remain outside what the Verify command reaches. Toolchain unchanged at cargo 1.97.1 and rustc 1.97.1. Installed targets unchanged, so rng-wasm remains unreachable.
- Oracle class re-read and still accurate for what the command grades.
- Publication channels re-enumerated by command rather than recalled, and this is where the audit failed: `cargo package --list` on the root manifest now returns 52 entries, 22 of which are `.jeffy/probes/*/README.md`. Cargo's `include` patterns follow gitignore semantics, so the unanchored `README.md` in the list matches at any depth. The underlying defect is the crate's own - an unanchored include list would ship any nested file of a matching name - but nothing matched it until this run committed battery READMEs, so this run made a latent packaging defect real. Filed as F8 at Medium with its Consequence, exactly as the channel rule requires. The `uuid-rng-internal` manifest is unaffected: its package root is rng/ and it carries no state files.
- No Declined entries and no Settled classes exist, so there were no recorded Derivations or enumerations to re-run.
- Dependency hygiene, scorable for the first time this run: cargo-audit was installed and `cargo audit` exits 0 having loaded 1239 advisories and scanned 114 crate dependencies, reporting none.
- Lint: `cargo clippy --all-features --lib` reports three warnings on shipped source. Filed as one Low, F9, because lint output is Low at most by the rubric and is reported rather than chased.
- Unsafe surface read rather than counted: the `unsafe` occurrences live in src/macros.rs (the two transmute macros and their zerocopy-checked counterparts), src/fmt.rs (the uninitialized-buffer encoders), src/non_nil.rs (`new_unchecked`, whose safety condition is documented) and src/builder.rs (one transmute for `from_bytes_ref`). Each is a `#[repr(transparent)]` reinterpretation or a fully-initialized ASCII buffer, and the fmt-encode battery drives the uninit paths over all four wrappers and asserts the untouched tail.

Scores, claiming the whole map because the Surface inventory now lists 22 swept rows and one `- [~]` row - rng-wasm, unreachable here because wasm32-unknown-unknown is not installed and wasm-pack is absent:
- correctness: None. Fresh evidence is the twenty-two batteries plus the suite, including the RFC 9562 A.1, A.2 and A.6 vectors and an independent MD5 and SHA-1 reference.
- security: None. No new unsafe, no advisory against any dependency.
- error handling: None in envelope. F7 is carried at Low.
- architecture: Medium - F8.
- code quality: Low - F9.
- testing: None. Isolation and single-threaded runs both clean.
- performance: None. The three code fixes this run are constant-time bit arithmetic of the same shape as what they replaced, and one of them removed sixteen unrolled match arms.
- documentation: None in envelope. F3 and F4 are carried at Low.
- dependency hygiene: None, derived by `cargo audit`.
- developer experience: Low, not filed separately: the benches need a nightly toolchain and the fuzz crate needs the registry reachable. Both are recorded in the dev-surfaces battery script where they are enforced rather than assumed.
- observability and UX/accessibility: not applicable. This is a no-std library with no user-facing surface and no logging of its own beyond the slog integration it exposes for its callers.

Closeout has not begun: it requires an audit scoring zero High and zero Medium, and this one scored a Medium.

Learnings: a packaging channel has to be re-checked whenever the run adds files to the tree, not only at the first audit. Cargo's `include` list follows gitignore semantics, so an unanchored `README.md` matches at any depth, and the first audit's clean result was true only of a tree that had no nested files of that name yet.

Next: F8 is the only open Medium and the only thing between this audit and a declaration. It is the whole of the next iteration; the gate and the declaration follow it.

## iter 9/10 | f60feaff-141833 | 2026-09-02 | F8 | done

Task: F8, the published crate carrying this loop's own working notes. Closed: the `include` patterns in Cargo.toml are anchored to the package root, and the dev-surfaces battery now checks what the package contains so the defect cannot return unobserved.

Changed: Cargo.toml (four include patterns anchored, with a comment naming why), .jeffy/probes/dev-surfaces/run.sh, paths, claims and README, BACKLOG.md (F8 deleted), JOURNAL.md.

Checkpoint: a312ea0b83584f62c526608e2727dbcb14bca8de

Verification:
- The filed acceptance check ran before and after. Before: `cargo package --list --allow-dirty` returned 52 entries of which 22 matched `^\.jeffy/`. After: 30 entries, 0 matching, with README.md, LICENSE-APACHE, LICENSE-MIT and all 23 src entries still listed. The 30 entries are exactly what the manifest listed before this run added any nested file of a matching name.
- Contract preserved: nothing about the library changed. The published file set returns to what the manifest intended; no source, no feature, no dependency and no public item moved.
- The fix is the crate's own defect rather than cleanup after the loop. Cargo's `include` follows gitignore semantics, so the unanchored `README.md` matched at any depth; any nested file of that name would have shipped the same way, whoever added it. Anchoring with a leading slash is what the manifest meant all along.
- A durable check replaces the one-off command: the dev-surfaces battery now asserts the package carries no `.jeffy/`, PLAN.md, BACKLOG.md or JOURNAL entry, and that it does carry the crate's README, both licences and src/lib.rs - so a future change cannot quietly empty the package either. Its paths file gained Cargo.toml, so any edit to the manifest makes that row stale until the battery is re-run.
- Differential evidence that the new checks are strong enough to fail: removing the leading slash from `"/README.md"` alone put the 22 files back and the battery reported `15/16` with `the package carries no loop state: got '22', want '0'`; restoring the anchor returned it to `16/16`. That is recorded in the battery's README beside its original mutation, because the packaging checks are not reachable by the mutation that reddens the rest of it.
- Battery ownership: `grep -lx 'Cargo.toml' .jeffy/probes/*/paths` returns dev-surfaces alone, and it was re-run through the installed run-probe.sh at 16/16.
- check-claims.sh: 24 checked, 0 mismatched, 0 errored, 0 skipped.
- Verify green through the wrapper, `verify totals: 226 passed, 0 failed, 0 ignored`. The Verify count cell is unchanged at 226 because no test was added; the new checks live in a battery rather than in the suite, since packaging is not something `cargo test` selects.

Learnings: none beyond the lesson already recorded in PLAN.md after the audit that found this.

Next: no High and no Medium remain open. Four Lows are carried - F3, F4, F7 and F9 - and the closing sequence is what is left: bring the standing claims current, invoke the adversarial evaluator as invocation 1 of this run, and declare on a PASS in that same iteration.

## iter 10/10 | f60feaff-141833 | 2026-09-02 | EVALUATOR | converged

Task: the closing sequence. Standing claims brought current, the adversarial evaluator invoked as invocation 1 of this run, and convergence declared on its PASS in this same iteration.

Changed: PLAN.md (the Oracle class and Environment fingerprint corrected, see below), BACKLOG.md (the Converged line appended in the bookkeeping edit), .jeffy/evaluator/f60feaff-141833-1.md written by the evaluator, JOURNAL.md.

Checkpoint: 46630fc1b3816d6632701c5847cb81940d386003

Verification:
- Standing claims brought current before the invocation. All 22 swept Surface inventory rows re-checked for staleness by asking git whether any path in each battery's own paths file changed after the commit that row records: 22 checked, 0 stale. No Declined entries and no Settled classes exist, so there were no recorded Derivations or enumerations to re-run; the single grep hit is the section's own template prose and the single `F[0-9]+` hit in PLAN.md is the word non-UTF8, so no finding ID is named there as carried or blocked. check-claims.sh: 24 checked, 0 mismatched, 0 errored, 0 skipped. The Verify count cell holds 226, which is the figure the wrapper's green line reports.
- Re-reading the Oracle class, as the declaring iteration must, found it overstating and it was corrected before anything else. It claimed the command grades the trybuild compile-fail cases; tests/macros.rs guards `t.compile_fail` behind `rustversion::cfg!(nightly)`, and `cargo test --all-features --test macros` on this stable toolchain lists only the three `tests/ui/compile_pass/*.rs` cases. The Oracle class now says so and the Environment fingerprint names the exclusion with the command that derives it. The excluded asset was then executed once rather than assumed: `cargo +nightly test --all-features --test macros` runs `tests/ui/compile_fail/invalid_parse.rs [should fail to compile] ... ok`. So the corpus is green, and the state files no longer claim the Verify command is what proved it.
- Verify green through the wrapper this iteration, `verify totals: 226 passed, 0 failed, 0 ignored`.
- Evaluator: PASS - invocation 1 of this run, artifact .jeffy/evaluator/f60feaff-141833-1.md, which carries no machine-absolute path and closes with VERDICT: PASS on its own line. It re-ran each closed High and Medium against cdc96a8 and against HEAD, and reported base failures and HEAD passes for all five; on F5 it went further than this run did, sweeping every declared counter width 0 to 255 and every bit placement for widths 1 to 74, reporting 2721 failures at base and 0 at HEAD.
- Two corrections the evaluator's observations require, recorded here because past entries are never rewritten. First: the 29 of 53 figure this run has quoted for F5 is the shape where each pair gets a fresh `ContextV7`; a single shared context over the same pairs gives 14 of 53. Both are non-zero at the base commit and both are 0 of 53 at HEAD, so the finding and the fix stand, but the iteration 2 and 3 entries describe the sweep as running through one context when the program built one per pair. Second: F8's acceptance check cannot fail at cdc96a8, because that commit predates the .jeffy tree entirely; its discriminating control is the one iteration 9 actually ran, the un-anchored manifest against HEAD's tree, which put 22 files back and reddened the battery at 15/16.
- Closing conditions, each checked rather than asserted: the full fresh-evidence audit of iteration 8 is on this run's record and predates this window; it filed F8 at Medium, which iteration 9 closed, and the only commits since that audit are that fix and loop state edits. The Surface inventory lists 22 swept rows, 0 unswept and one `- [~]` row, rng-wasm, unreachable here because wasm32-unknown-unknown is not an installed target and wasm-pack is absent. Now, Next and Later hold no open High and no open Medium.
- Carried Lows, each with its severity written on its own ledger line: F3 - eight doc comments in src/fmt.rs close with a stray `/// */` that renders as a literal `*/` in the published docs. F4 - two typos in shipped text, `the system tie` in the `InvalidSystemTime` message and `when ading` in a src/lib.rs comment. F7 - `InvalidUuid::into_err` short-circuits above 45 bytes, so an over-length URN gets a correct but coarser length error instead of a group error. F9 - three clippy warnings on shipped source, including a missing `Default` for `ContextV7`.
- One Proposed item awaits a user decision and does not block: the `urn:uuid:` prefix is matched case-sensitively, so `URN:UUID:...` is rejected, where RFC 8141 makes both the scheme and the namespace identifier case-insensitive. Accepting it widens the set of inputs the parser accepts, which is a public behaviour change.

Learnings: re-reading the Oracle class at the declaration is not a formality. This one claimed a corpus the Verify command never compiled, and the only reason that did not become a false green is that the declaring iteration is required to read it again and did.

Next: nothing. The run is converged and the Converged line names this iteration's checkpoint.
