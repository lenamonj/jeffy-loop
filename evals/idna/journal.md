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

## iter 1/10 | e33d6b6d-074054 | 2026-08-31 | AUDIT | audit

Task: first audit. Fill the Operating envelope, the Surface inventory, the Verify command block and the Stated counts table, verify the artifact-producing channels, probe the whole public surface breadth-first, and file what that finds.

Changed: PLAN.md (envelope surfaces, 17 inventory rows, Verify command / Oracle class / Environment fingerprint / duration / summary pattern / count, 3 Stated counts rows), BACKLOG.md (F1, F2, F3, one Proposed item), .gitignore (loop state file).

Checkpoint: 6f549e05c687ae6b5be51c6dcbd464da1e73e2b9

Verification: verify green through quiet-verify.sh - `6444 passed, 1 skipped, 56 subtests passed`, 6s, matching the Verify count cell. check-claims.sh: 3 checked, 0 mismatched, 0 errored. Every test module also run in isolation (test_intranges, test_idna_compat, test_idna_errors, test_idna_concurrency, test_idna_codec, test_idna_cli, test_idna_properties, test_idna_fuzz_targets) - all pass alone, so no order dependence. Artifact channels enumerated by command, not recall: the only packaging manifest is pyproject.toml (flit_core), and the only publishing workflow is .github/workflows/deploy.yml, which archives dist/ alone. Built both artifacts with flit_core 4.0.2 and listed them: the sdist carries only the module, tests, tools, README.md, LICENSE.md, HISTORY.md and pyproject.toml, and the wheel only the module - PLAN.md, BACKLOG.md, JOURNAL.md and .jeffy/ cannot reach either. The discriminating evidence that this is an allowlist rather than an accident: SECURITY.md is committed at the repository root and is absent from the sdist too.

Audit scores, claiming only what this breadth-first pass actually exercised - no inventory row is swept, so every dimension score below is bounded by a shallow probe and none of them stands for the project: correctness Medium (F1), documentation Medium (F2, F3), error handling Medium (F1), security None observed, architecture None observed, code quality None observed, testing None observed (suite green, every module green in isolation, 6333-case conformance corpus runs here), performance None observed, dependency hygiene None observed (zero runtime dependencies; dev requirements pinned with hashes), developer experience None observed, observability not applicable (a pure library with no logging surface), UX not applicable beyond the CLI, accessibility not applicable. Zero High.

The probe that produced those scores drove, in one pass: the length helpers at and past their boundaries; check_bidi over LTR, RTL, mixed and empty labels; check_nfc, check_hyphen_ok and check_initial_combiner; valid_contextj and valid_contexto including the KATAKANA MIDDLE DOT and Arabic-Indic digit rules; alabel and ulabel round trips against known answers, the fake-A-label rejection (xn---bbk) and the empty and bare-prefix cases; encode and decode over known answers, empty input, bare and trailing dots, and display=True recovery; uts46_remap over the ASCII fast path, mapped, ignored and disallowed statuses with std3_rules both ways; the idna2008 codec one-shot, incremental character-by-character against the one-shot result, StreamReader, StreamWriter and the rejection of non-strict error handlers; the CLI through both python -m idna and the installed console script, over arguments, piped stdin, --strict, --version and a failing conversion; and the generated tables' shape (starts, statuses and replacements are equal length; the sub-256 identity the mapping fast path indexes on holds with no exception).

Learnings: the conformance oracle is narrower than its case count suggests - tools/idna-data drops 58 IdnaTestV2 vectors before generating tests, and the largest group is the cross-label bidi vectors now filed as a Proposed item, so a green corpus does not certify that behaviour. Run the suite with `.venv/bin/python`, never a bare `python`: the project is installed editable into .venv and the system interpreter has no pytest. Building the artifacts needs flit_core, which is not in the venv by default; it was installed for the channel check.

Next: F1, the check_bidi IndexError, then F2. Both are one-iteration fixes. After them the queue is the 17 unswept inventory rows, which is the bulk of this run; the conversion, mapping and bidi rows deserve known-answer batteries under .jeffy/probes/ before the cheaper ones.

## iter 2/10 | e33d6b6d-074054 | 2026-08-31 | SWEEP | done

Task: sweep Surface inventory rows. The queue puts unswept rows above every open Medium, and 17 of 17 were unswept, so this iteration built known-answer batteries and swept the eight rows they can properly evidence.

Changed: .jeffy/probes/_harness.py and .jeffy/probes/_mutate.sh (shared instrument), eight batteries under .jeffy/probes/ (core-conversion, core-bidi, core-context, core-uts46, core-domain, core-length, core-structural, intranges), each with probe.py, paths, claims, mutation and README.md; PLAN.md (eight inventory rows flipped, in the bookkeeping edit).

Checkpoint: 05a3d9a084e396c37f907fbc8fb33bcf491a9e41

Verification: verify green through quiet-verify.sh - `6444 passed, 1 skipped, 56 subtests passed`, 5s. check-claims.sh: 19 checked, 0 mismatched, 0 errored, which is two claims per battery plus the three PLAN.md Stated counts rows. Every battery is green on the tree and was observed failing against a mutated copy of the package: dropping RFC 5891 5.3's canonical-Punycode re-encode reddens 4 core-conversion checks and makes the mutant return '北京' for the fake A-label xn---1lq90i; dropping EN from the rule 4 numeral set reddens 4 core-bidi checks; giving ZWJ the ZWNJ joining-type clause reddens 1 core-context check; skipping the STD3 test on the all-ASCII fast path reddens 11 core-uts46 checks; dropping the length check on the encoded domain reddens 4 core-domain checks; moving the label limit to 64 reddens 4 core-length checks; disabling the third-and-fourth-position hyphen test reddens 6 core-structural checks; treating the intranges as closed rather than half-open reddens 8 intranges checks. Mutations run against a copy under PYTHONPATH, never against the tree.

The sweep filed nothing new. One candidate was chased to the reference and dropped: uts46_remap silently removes U+200B ZERO WIDTH SPACE, which looked like a disallowed codepoint being swallowed, but the UTS #46 IdnaMappingTable for Unicode 17.0.0 records `200B ; ignored`, so the behaviour is correct and the battery now pins it. Three findings from iteration 1 remain open and untouched, which is what the queue ordering asks for.

Learnings: a battery must be run against a mutated copy of the package, not against a mutated tree - copy idna/ aside, mutate the copy, and run the probe with PYTHONPATH pointing at it; because a probe lives in a directory holding no idna, the copy wins over the editable install on sys.path, and the tree is never at risk. Score a battery's error-code check unconditionally rather than only when the raise arrived, or the denominator moves with the numerator and the reddened count stops meaning anything. Verify a status against the published Unicode data file before filing a table finding: one candidate this iteration was memory, not evidence.

Next: nine rows remain unswept - core-validation, core-exceptions, codec-stateless, codec-incremental, cli, compat, tables, package, generator. Sweeping continues to outrank the two open Mediums, so the next iterations take the rest of the map before F1 and F2.

## iter 3/10 | e33d6b6d-074054 | 2026-08-31 | SWEEP | done

Task: sweep the remaining Surface inventory rows. Nine of 17 were unswept at the start of this iteration and all nine are swept now, so the map is complete.

Changed: nine batteries under .jeffy/probes/ (core-validation, core-exceptions, codec-stateless, codec-incremental, cli, compat, package, tables, generator), each with probe.py, paths, claims, mutation and README.md, plus .jeffy/probes/generator/regen-diff.sh; PLAN.md (nine inventory rows flipped, in the bookkeeping edit).

Checkpoint: cf1983613dda5d1c9b244966bd95c0b5cab7fcf7

Verification: verify green through quiet-verify.sh - `6444 passed, 1 skipped, 56 subtests passed`, 5s. check-claims.sh: 38 checked, 0 mismatched, 0 errored, which is two claims per battery across all 17 rows, the generator's third claim, and the three PLAN.md Stated counts rows. Each new battery was observed failing against a mutated copy of the package: dropping the leading-combining-mark rule from the validity chain reddens 3 core-validation checks; misspelling one raise site's error code reddens 4 core-exceptions checks; answering the codec search for every name reddens 5 codec-stateless checks; dropping the incremental encoder's accumulated-length ceiling reddens 2 codec-incremental checks; inverting the CLI's A-label heuristic reddens 7 cli checks; turning the nameprep stub into a no-op reddens 6 compat checks; dropping one name from the package re-exports reddens 2 package checks; stamping the tables with a different Unicode release than the generator pins reddens 1 tables check; reassigning one RFC 5892 exception in the generator without regenerating reddens 1 generator check.

The strongest evidence this iteration is the generator round trip: regenerating idna/idnadata.py, idna/uts46data.py and tests/test_idna_uts46.py from the published Unicode 17.0.0 data into a scratch copy of the tree reproduces all three checked-in files byte for byte, which is CI's own tables job run here. It is recorded as a claim rather than as prose, and it answers `unavailable:` on a host that can reach neither the generator's cache nor unicode.org. The core-exceptions battery also establishes something the ledger will need at the close: the 27 codes idna declares and the 27 reachable through a real reproduction are the same set, and the code literals in the shipped source are exactly that set too.

The sweep filed nothing new. Two candidate findings were chased and dropped as battery defects rather than product defects: an error-code enumeration built by grep missed bidi_rule_6, which one raise site selects with a conditional expression, and the fix was to enumerate from the AST; and a check on idna.compat's public names counted typing.Any, which the module imports.

Learnings: enumerate source literals from the AST, never by grep, when a value can be chosen by an expression rather than written as a constant - a grep-built enumeration silently omits the branch it cannot see. A battery that drives a subprocess must run it from a neutral working directory, or sys.path[0] is the project root and the subprocess re-imports the real package instead of the one under test. Re-measure every mutation count in one pass after the batteries are green, because a count taken while its battery was red is a count of the wrong thing.

Next: the map is complete at 17 of 17, so the queue falls to the two open Mediums, F1 then F2, followed by the Low F3. After those the ledger is empty with iterations left, which is where the evaluator gate runs early rather than at the declaration.

## iter 4/10 | e33d6b6d-074054 | 2026-08-31 | F1 | done

Task: F1 (Medium, runtime, error handling) - check_bidi("", check_ltr=True) raised IndexError instead of an IDNAError. Closed: an empty label now returns True whichever way check_ltr is set, the docstring says so, and three harnesses pin it.

Changed: idna/core.py (an empty-label guard in check_bidi, and its docstring), tests/test_idna.py (regression assertions beside the other check_bidi cases), tests/test_idna_properties.py and tests/fuzz_idna_api.py (both now drive check_ltr at its non-default value), .jeffy/probes/core-bidi (the empty label pinned at both values, README and claims updated); PLAN.md (a Lessons line, and nine inventory rows re-recorded in the bookkeeping edit).

Checkpoint: 407b4bfa72726f8c8459a2a42b36e5ebec46251a

Verification: the filed reproduction was this iteration's first command and failed on HEAD - IndexError at the label[0] index in check_bidi. After the fix, `idna.check_bidi('', check_ltr=True)` returns True, as does the default path. The acceptance check was then run against the unfixed code to prove it can fail: with a copy of the package carrying the pre-fix core.py on PYTHONPATH, both new checks fail - test_check_bidi with the IndexError, and the property test's test_label_helpers, which Hypothesis shrank to the empty label on its own. Verify green through quiet-verify.sh - `6444 passed, 1 skipped, 56 subtests passed`, 6s; the total is unchanged because the new assertions live inside existing test methods. check-claims.sh: 38 checked, 0 mismatched, 0 errored. Every battery declaring idna/core.py was re-run through run-probe.sh in this iteration and is green: core-conversion 67/67, core-bidi 72/72, core-context 55/55, core-uts46 65/65, core-domain 85/85, core-length 29/29, core-structural 42/42, core-validation 68/68, core-exceptions 81/81.

Contract preserved: check_bidi's only in-library caller is check_label, which rejects an empty label with code empty_label before it ever reaches the bidi check, so no internal path changes. For external callers the default path is untouched - check_bidi("") returned True before this change and returns True after it - and the only behaviour that changed is the check_ltr path on an empty label, which raised an undocumented IndexError and now agrees with the default. The docstring records the reasoning: an empty label has no first character to be of the wrong directionality, no disallowed character and no illegal final one, so no condition can be violated.

Learnings: a documented parameter that no harness ever passes is where a crash survives - check_bidi was in both the property test's and the fuzz target's function lists, but only ever called with check_ltr at its default, so neither could reach the branch that crashed. Both now drive it, which is why the property test rediscovers F1 on the unfixed copy without being told what to look for. Prove an acceptance check against a copy of the package on PYTHONPATH with pytest --import-mode=importlib rather than by reverting files in the tree, because the tree carries the fix being proved.

Next: F2, the IDNAError docstring pointing at a list the README does not carry, then the Low F3. After those the ledger is empty with iterations left, which is where the evaluator gate runs early rather than at the declaration.

## iter 5/10 | e33d6b6d-074054 | 2026-08-31 | F2 | done

Task: F2 (Medium, docs, documentation) - the IDNAError docstring told readers "the full list is documented in the README", and README.md's Exceptions section names two codes as examples and carries no list. Closed by removing the false pointer and naming where the codes actually are.

Changed: idna/core.py (the `code` bullet in the IDNAError docstring), .jeffy/probes/core-exceptions (a check on the docstring's own promise, README.md added to the row's paths, README and claims updated), .jeffy/probes/_mutate.sh (carries README.md into the mutated copy, so the new check reads the file under test rather than an absent one); PLAN.md (nine inventory rows re-recorded in the bookkeeping edit).

Checkpoint: cd0907c0ce7520e47ffa5ff5193f4eb9c2d164e2

Verification: the check was written before the fix and observed failing on the unfixed tree, naming the 25 of 27 declared codes the README does not contain - only disallowed_codepoint and label_too_long appear there, as examples. After the fix the docstring no longer mentions the README and names the _ErrorCode alias, which typing.get_args enumerates as 27 codes, the same set the battery already proves reachable. Verify green through quiet-verify.sh - `6444 passed, 1 skipped, 56 subtests passed`, 6s. check-claims.sh: 38 checked, 0 mismatched, 0 errored. Every battery declaring idna/core.py re-run through run-probe.sh and green: core-conversion 67/67, core-bidi 72/72, core-context 55/55, core-uts46 65/65, core-domain 85/85, core-length 29/29, core-structural 42/42, core-validation 68/68, core-exceptions 82/82.

Which way to fix it was the whole decision, and the git history settled it: d7b6f05 condensed the README's exception section and cba1f53 dropped the test that cross-checked the README table, "now that the code list is not documented there". Restoring the list would undo a deliberate change from the merge immediately before this run started, so the docstring gave way instead. It now points at the _ErrorCode alias in the same module - a private name in a public docstring, which is a real cost, but it is the one place the list exists, it ships in the source the reader already has, and it turns a dangling promise into one a command can check. The new battery check is deliberately written as an implication rather than as an assertion about the current wording: if the docstring points at the README, the README must carry every code. It holds under either resolution, so a future run that decides to restore the list instead is not fighting the instrument.

Contract preserved: no behaviour changed. The docstring is the only edit to shipped code, the codes themselves are untouched, and the battery's set-equality checks between the declared codes, the reachable codes and the code literals in the source all still hold.

Learnings: write a docs check as the implication the documentation owes rather than as a copy of the wording chosen today, or the check has to be rewritten by whoever changes their mind later. When a battery reads a file outside the package, the mutation runner has to carry that file into the copy too, or the check silently reads nothing and passes.

Next: F3, the Low - README.md documents no idna2008 codec example and codecs.encode raises LookupError until idna.codec is imported. That empties the ledger with four iterations left, which is where the evaluator gate runs early rather than at the declaration.

## iter 6/10 | e33d6b6d-074054 | 2026-08-31 | F3 | done

Task: F3 (Low, docs, documentation) - README.md documented no idna2008 codec, and codecs.encode(s, "idna2008") raises LookupError until idna.codec is imported, so a shipped and tested surface was undiscoverable from the documentation. Closed with a README section whose example is executed as published and pinned as a standing check.

Changed: README.md (a Codec subsection under Usage), .jeffy/probes/codec-stateless (the README example held to the publication rule, the registration claim checked in fresh interpreters, README.md added to the row's paths, README and claims updated); PLAN.md (three inventory rows re-recorded in the bookkeeping edit).

Checkpoint: 8376264a72ffe952e7fe9a5fed0f81c70ede1b23

Verification: the published example was run exactly as written before it was committed - doctest reports 5 of 5 passing - and it is now a standing check rather than a one-time observation: the battery extracts the pycon block from README.md and runs it, so a README that states an output the code does not produce fails. That check was observed failing against a copy of the tree whose README claimed b'xn--eckwd4c7c.xn--zckzah1', one character off the real value. The section's claim about registration is checked too, in two fresh interpreters: `import idna` alone leaves idna2008 unknown to codecs.lookup, and `import idna.codec` registers it. Verify green through quiet-verify.sh - `6444 passed, 1 skipped, 56 subtests passed`, 6s. check-claims.sh: 38 checked, 0 mismatched, 0 errored. Every battery declaring README.md or idna/codec.py re-run through run-probe.sh and green: codec-stateless 79/79, codec-incremental 134/134, core-exceptions 82/82.

Contract preserved: no code changed. The README gained a section; the codec it documents is the one the battery has pinned since iteration 3, and the two prose claims it makes - that only the strict error handler is supported, and that the incremental and stream forms exist - are both already pinned by codec-stateless and codec-incremental rather than asserted here for the first time.

The ledger is now empty: F1, F2 and F3 are all closed, no Proposed item has been worked, and the map stands at 17 of 17 rows swept.

Learnings: a published example belongs in a battery, not in a journal entry - executing it once proves it was true on the day it was written, while extracting and running it on every check keeps it true. Hold a README's prose claims with the same instrument as its code: the registration sentence in this section is exactly the sort of statement that quietly stops being true, and it costs two subprocesses to keep honest.

Next: the closing full audit, with fresh evidence across all 17 swept rows and the empty ledger. If it scores zero High and zero Medium in-envelope, closeout begins and the following iteration runs the evaluator gate and declares in that same iteration, leaving two iterations of slack for a REJECT.

## iter 7/10 | e33d6b6d-074054 | 2026-08-31 | AUDIT | audit

Task: the closing full audit. The ledger was empty and all 17 inventory rows swept, so this iteration re-scored every applicable dimension against the rubric and the Operating envelope with fresh evidence.

Changed: BACKLOG.md (F4 filed Medium, F5 filed Low, one Proposed item); no code.

Checkpoint: debbe6b4c41824e6c67e8f0fe44df164f755a551

Verification: no inventory row is stale - each row's battery paths were diffed against the commit that row records, and none has moved. All 17 batteries re-run through run-probe.sh and green, 1086 checks. Verify green through quiet-verify.sh - `6444 passed, 1 skipped, 56 subtests passed`, 6s. check-claims.sh: 38 checked, 0 mismatched, 0 errored. Oracle class and Environment fingerprint re-read and re-derived: the exclusion enumeration still returns 1 guard, the free-threaded GIL check in tests/test_idna_concurrency.py, and nothing else is excluded on this host.

Fresh evidence taken this iteration rather than restated from earlier ones. Artifact channels re-enumerated by command - the only packaging manifest is pyproject.toml and the only publishing workflow is deploy.yml, which archives dist/ alone - and both artifacts rebuilt: the sdist carries 31 entries and the wheel 16, and neither contains PLAN.md, BACKLOG.md, JOURNAL.md or any .jeffy/ path, with the discriminator still holding that committed SECURITY.md is absent from the sdist too, so the include list is an allowlist rather than an accident. Dependency hygiene: zero runtime dependencies, and the two dev requirement files are hash-pinned. Coverage measured at 97 percent against the project's own floor of 95. A differential sweep of 4000 Hypothesis examples per property, 16000 cases in all, established that only IDNAError escapes encode and decode under every flag combination, that decoding and re-encoding an encoded name reproduces it up to case, that the incremental codec matches the one-shot functions for every chunking of non-empty input across 3991 comparisons, and that uts46_remap is idempotent.

Scores, claiming all 17 swept rows: architecture None, code quality None, security None, correctness None, error handling None, performance None, dependency hygiene None, developer experience None, UX None (the CLI row is swept end to end), documentation Medium (F4), testing Low (F5), observability not applicable to a library with no logging surface, accessibility not applicable. Zero High. Closeout does NOT begin, because this audit did not come back clean: it found one Medium.

F4 is the sweep's doing. The round-trip property failed on the single character 'A': idna.encode('A') returns b'A', while idna.check_label('A') raises disallowed_codepoint and idna.decode(b'A') returns 'a'. So encode accepts what the same library's validator rejects, and the README's stated rule - "capital letters are not allowed", demonstrated with an encode that raises - does not hold for an all-ASCII label. No test pins the passthrough; the conformance corpus only ever exercises uppercase with uts46=True, where it is mapped away. Two candidate findings beside it were dropped as my property being wrong rather than the code: the codec returning b"" for empty input where idna.encode raises empty_domain is the deliberate codec-protocol shortcut, explicit in the source and already pinned; and the round trip holds up to case once F4 itself is accounted for.

What F4 does not decide is whether encode should reject uppercase, case-fold it, or keep passing it through. That is a public behaviour change on the function requests and urllib3 call on hostnames, so it is filed as a Proposed item for the owner and F4 is scoped to the contradiction that needs no such decision: the documentation says one thing and the code does another.

Learnings: a differential property is worth more than another known-answer check once the known answers are all green - 1086 battery checks were passing over this surface and none of them compared encode against check_label, which is the comparison that found F4. When a property fails, decide whether the code or the property is wrong before filing: two of the three failures this sweep produced were the property overreaching.

Next: F4, which is a documentation fix and fits one iteration. Then the evaluator gate and the declaration in a single iteration, leaving iteration 10 as slack for a REJECT. F5 is a Low and rides to the declaration as a carried finding.

## iter 8/10 | e33d6b6d-074054 | 2026-08-31 | F4 | done

Task: F4 (Medium, docs, documentation) - README.md stated "capital letters are not allowed" and demonstrated idna.encode rejecting one, while an all-ASCII label carries its case straight through, and the alabel docstring called such labels "already valid IDNA labels" when check_label rejects them. Closed by documenting the rule the code actually keeps.

Changed: README.md (an ASCII labels and case subsection with a runnable example), idna/core.py (the alabel and encode docstrings), .jeffy/probes/core-conversion (twelve checks pinning the behaviour and the three documents that now describe it, README.md added to the row's paths, README and claims updated); PLAN.md (ten inventory rows re-recorded in the bookkeeping edit).

Checkpoint: 7e9d373f48181c85e52e7a7d7154649337f24028

Verification: the new checks were run against a copy of the package carrying the pre-fix core.py and README.md, and five of them fail there - the alabel docstring still claiming "already valid IDNA labels", both docstrings missing the case rule, and the README carrying no such section for the example extractor to find. Against the fixed tree all pass, and the README's example is executed as published by doctest, 3 of 3. Verify green through quiet-verify.sh - `6444 passed, 1 skipped, 56 subtests passed`, 6s. check-claims.sh: 38 checked, 0 mismatched, 0 errored. Every battery declaring idna/core.py or README.md re-run through run-probe.sh and green: core-conversion 79/79, core-bidi 72/72, core-context 55/55, core-uts46 65/65, core-domain 85/85, core-length 29/29, core-structural 42/42, core-validation 68/68, core-exceptions 82/82, codec-stateless 79/79.

Contract preserved: no behaviour changed. idna.encode("EXAMPLE.COM") returned b"EXAMPLE.COM" before this iteration and returns it after; what changed is that three documents now say so. The battery pins the whole disagreement rather than one side of it - alabel keeps ASCII case, ulabel folds it, check_label rejects it, and uts46=True folds it - so a future change to any one of them fails here rather than quietly re-opening the contradiction.

Why documentation and not behaviour: making encode reject or case-fold an all-ASCII uppercase label would align it with check_label and with IDNA 2008's DISALLOWED class, but idna.encode is the function requests and urllib3 call on hostnames, so a name that encodes today would start raising or start returning different bytes. That blast radius is the owner's call, and it is filed under Proposed. F4 was scoped from the start to the part that needs no such decision: the documentation said one thing and the code did another, and only one of them could be true.

Learnings: when a finding is a contradiction between a document and a behaviour, fix the one that is wrong rather than the one that is easier to change, and say in the ledger which is which before starting - the alternative is discovering at the fix that the task was a behaviour change in disguise. A README anchor for an extractor should be a heading, not a paragraph: matching on prose broke twice this iteration because the surrounding blank lines were not what I remembered, and a heading is the one line in a markdown file that is stable enough to key on.

Next: the ledger holds only the carried Low F5. The evaluator gate and, on a PASS, the declaration, both in iteration 9, leaving iteration 10 as slack for a REJECT.

## iter 9/10 | e33d6b6d-074054 | 2026-08-31 | EVALUATOR | audit

Task: the evaluator gate, invocation 1 of this run, and the declaration if it passed. It did not pass.

Changed: BACKLOG.md (F6 and F7 filed, both Low), PLAN.md (one Lessons line de-referenced so it names no finding ID), .jeffy/evaluator/e33d6b6d-074054-1.md (the gate's artifact).

Checkpoint: 6cd054350bc78711a628fe1abe01b803e42b64ad

Verification: standing claims were brought current before the invocation - no inventory row is stale, all 17 rows swept, check-claims.sh 38 checked with 0 mismatched and 0 errored, the Verify count cell equal to the wrapper's total, no Declined Derivation and no Settled class to re-run, and PLAN.md naming no finding ID as carried or blocked once its Lessons line was reworded. Verify green through quiet-verify.sh - `6444 passed, 1 skipped, 56 subtests passed`. Evaluator: REJECT, one substantiated reason, artifact at .jeffy/evaluator/e33d6b6d-074054-1.md.

The reason is fair and is filed as F6. F1's Acceptance, as written in iteration 1, required check_bidi("", check_ltr=True) to raise an IDNAError subclass. Iteration 4 chose the other resolution - return True, so both values of check_ltr agree and the default path is untouched - and argued for it at length, but never amended the acceptance line, so iteration 4's entry recorded F1 done against a check its own fix cannot pass and quietly put the regression test in its place. The defect in the product is genuinely fixed and the gate confirmed that; what failed is the ledger's own definition of done, which PLAN.md states as evidence over assertion. The gate was right to refuse on it.

The gate also recorded three observations, none a REJECT reason. One of them is a regression this run introduced and is filed as F7: the ASCII labels and case section landed above the decode(display=True) paragraph, which had belonged to the UTS #46 section and now reads as part of the case section. The other two are not this run's to fix inside the convergence sequence - the Königsgäßchen pycon block has failed doctest since before the run, and the docstring pointing at the private _ErrorCode alias is a cost iteration 5 priced deliberately - and they go to the run report.

Invocation accounting: this was invocation 1, and it landed at iteration 9 of a 10-iteration budget, which is past the midpoint, so the cap is 2 and exactly one invocation remains. A second REJECT is therefore terminal. Iteration 10 closes both gate-filed findings, re-invokes the gate as invocation 2, and declares only on a PASS; the budget forces that combination rather than choosing it, which is what the one-transaction rule exists for.

Learnings: an acceptance check written before the resolution is chosen is a hypothesis about the fix, not a test of it - when the fix takes a different shape, amend the ledger line in the same iteration and say so, because substituting a different check silently is exactly what the gate reads as assertion over evidence. Bring standing claims current before invoking, not after: the Lessons line naming a closed finding would have been a dangling reference the gate had to resolve, and it cost one edit to remove beforehand rather than one invocation to argue afterwards.

Next: iteration 10 closes F6 and F7, re-invokes the gate as invocation 2, and declares on a PASS. F5 rides to the declaration as a carried Low.

## Note - 2026-08-31 - correction to the record of F1

The evaluator gate's first invocation refused this run's declaration on a
defect in this journal, and this note is the disclosure it is owed.

F1 was filed in iteration 1 with this Acceptance, quoted from BACKLOG.md as
it stood at commit 6f549e0: `python -c "import idna;
idna.check_bidi('', check_ltr=True)"` raises an idna.IDNAError subclass,
never IndexError, and a regression test in tests/test_idna.py asserts it.

That acceptance presupposed a resolution the fix did not take. Iteration 4
chose the other one: an empty label returns True whichever way check_ltr is
set, so the two values of the parameter agree and the default path -
check_bidi("") returning True since long before this run - is untouched. The
entry argued for that choice at length and the choice stands. What it failed
to do was amend the acceptance line to match, so the entry recorded F1 done
against a check its own fix cannot pass, and put the regression test in its
place without saying so. PLAN.md's Constraints require the opposite: a task is
done only when its acceptance check has been run and observed to pass.

The acceptance that actually governs F1, executed in iteration 10 and recorded
here: `.venv/bin/python -c "import idna; assert
idna.check_bidi(chr(0)[:0], check_ltr=True) is True"` exits 0 at HEAD, and the
same command against a copy of the package carrying the base commit's
idna/core.py raises IndexError. Both halves were run; the second is what makes
the check able to fail.

The iteration-4 entry stands unedited, as every entry does. This note is the
amendment.

## iter 10/10 | e33d6b6d-074054 | 2026-08-31 | EVALUATOR | converged

Task: close the two findings the evaluator gate filed, re-invoke the gate as invocation 2, and declare on a PASS. The budget forced the combination rather than my choosing it: one iteration remained, and the one-transaction rule exists for exactly that.

Changed: README.md (F7 - the decode-for-display paragraph put back under Compatibility Mapping, with the ASCII labels and case section following it), JOURNAL.md (F6 - a dated Note disclosing the substitution in F1's record), BACKLOG.md (F6 and F7 closed, F8 filed Low, the Converged line appended), PLAN.md (three inventory rows re-recorded before the re-invocation), .jeffy/evaluator/e33d6b6d-074054-2.md.

Checkpoint: 58eb2c9c8ff0f6b8e6b6d0eb0e07e9e6c0e2d1a7 for the fixes, then 65f620c04360129a3e5f34196a554e73c24dd4ad for the row re-record, which is the tree the gate adjudicated and the hash the Converged line names.

Verification: F7's acceptance - the nearest heading preceding the decode-for-display paragraph - reports "### Compatibility Mapping (UTS #46)". F6's corrected acceptance was executed both ways: `.venv/bin/python -c "import idna; assert idna.check_bidi(chr(0)[:0], check_ltr=True) is True"` exits 0 at HEAD and raises IndexError against a copy of the package carrying the base commit's core.py, so the check can fail and does. Verify green through quiet-verify.sh - `6444 passed, 1 skipped, 56 subtests passed`, 7s, equal to the Verify count cell. check-claims.sh: 38 checked, 0 mismatched, 0 errored, all three Stated counts rows matching. Every battery declaring README.md re-run through run-probe.sh and green: core-conversion 79/79, core-exceptions 82/82, codec-stateless 79/79. All 17 Surface inventory rows fresh against the commits they record, checked by diffing each battery's declared paths, and re-recorded before the invocation rather than after it. Evaluator: PASS - invocation 2 re-derived the three closed Mediums as failing at the base commit and passing at HEAD, re-executed F6's corrected check both ways itself, confirmed F7's placement and that both added pycon blocks still pass doctest, and swept 195 differential calls across the public API between base and HEAD finding exactly one behavioural difference, F1's fix.

Closing conditions, each verified this iteration: the full fresh-evidence audit of iteration 7 is on the record and the only commits since it are the fixes for what it filed (F4) and what the gate filed (F6, F7) plus loop state edits; the Surface inventory lists no unswept row; no High and no Medium is open; the Verify command is green; the gate returned PASS at the highest ordinal on record, with its artifact committed by this iteration's checkpoint.

Carried Lows, open by design and named here as the closing rule requires: F5 - the shipped suite leaves the defensive error paths in idna/core.py and idna/codec.py unexecuted, so a regression in any of them is invisible to CI, while the probe batteries reach them but are loop memory rather than shipped tests. F8 - one clause of PLAN.md's Environment fingerprint is false, claiming the interpreter's unicodedata matches the table version when it measures 16.0.0 against tables at 17.0.0; the load-bearing half of that line, the exclusion enumeration and the corpus running in full, is true and was re-derived at this declaration.

F8 is the gate's own observation and it is filed, not fixed. A fix after a PASS invalidates that PASS and spends an invocation the declaration needs, and no invocation remained: the first landed at iteration 9, past the midpoint of a ten-iteration budget, so the cap was two and both are spent. The next run's fresh audit takes it.

Learnings: re-record the inventory rows and land the fixes before invoking the gate, never in the checkpoint edit after it, or the gate reads rows the fix has just outdated and refuses on bookkeeping instead of on the work. A gate that refuses on the ledger's own definition of done is doing its job: the product defect F1 named was fixed correctly in iteration 4, and what the run got wrong was writing down that it had met a check it had replaced.

Next: nothing in this run. Two carried Lows and one Proposed decision wait for the next one.
