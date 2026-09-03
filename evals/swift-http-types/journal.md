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

## iter 1/10 | c1c38f98-163952 | 2026-09-03 | AUDIT | audit

Task: First audit. Fill the Operating envelope, the Surface inventory, the Verify command block and the Stated counts table; probe the whole public surface breadth-first; file findings.

Changed: PLAN.md (envelope surfaces, 30 inventory rows, verify command block, two Stated counts rows), BACKLOG.md (HT-1, HT-2 in Now; HT-4 in Next; HT-5, HT-3, HT-6 in Later), .gitignore (bootstrap entry for the transient loop state file).

Checkpoint: a1b5bb19099b920549254268525640fefcbbf2a2

Verification: `swift test -Xswiftc -warnings-as-errors` through quiet-verify.sh - green (4s, `✘ Test run with 44 tests passed after 0.007 seconds with 1 known issue.`). check-claims.sh: 2 checked, 0 mismatched, 0 errored, 0 skipped.

Scores, from breadth-first probes run against a scratch SwiftPM package that links the two library products; 0 of 30 inventory rows are swept, so every None below claims only what those probes reached and not the unexamined remainder:
- correctness: High - HT-1. Also probed clean here: `HTTPFields ==` agreed with an independent grouping reference on 20000 random small lists and 2000 random 100-160 field lists, the latter exercising the `isEqualByNameIndex` fallback; setFields shrink/grow/delete, cookie splitting and joining, value legalization and lenient cleanup, name validation and case-insensitivity, status kinds and reason-phrase legalization, HTTP/2 and HTTP/3 error code raw values, and parsed-field ingestion all returned their hand-computed answers.
- error handling: High - HT-2.
- security: None on the probed surface. The library performs no I/O; `grep -rnE 'FileManager|ProcessInfo|CommandLine|getenv\(|NIOSocket' Sources/ --include='*.swift'` returns nothing.
- architecture: None on the probed surface.
- code quality: Low - HT-6.
- testing: Low. The suite's own `withKnownIssue` in `hashMatchesEqualityForDifferentOrder` records HT-1 rather than fixing it; no finding beyond HT-1 itself.
- performance: None on the probed surface. Equality carries an explicit linear fallback and the repository has a Benchmarks package.
- documentation: Low - HT-3.
- dependency hygiene: None. The package declares no external dependencies.
- developer experience: None on the probed surface.
- packaging: Medium - HT-4. Channels enumerated by command: `git ls-files | grep -Ei '(^|/)(Package\.swift|Cargo\.toml|package\.json|MANIFEST\.in|pyproject\.toml|.*\.gemspec|.*\.nuspec|Dockerfile.*|.*\.podspec)$'` returns the three SwiftPM manifests and nothing else - no container build and no publish workflow that archives the tree; `find .github -type f` returns one release-notes config and three workflow files, all of which delegate to shared swift-nio and swiftlang workflows and none of which uploads the tree. That leaves two channels: a consumer's `git clone`, where nothing can keep a repository-root file out of the checkout, and the source archive (`git archive`, GitHub source tarballs, `swift package archive-source`), where `.gitattributes` export-ignore can and currently does not.
- observability: not applicable - a currency-type library with no telemetry surface.
- UX and accessibility: not applicable - no user-facing surface.

Learnings: CI compiles with `-Xswiftc -warnings-as-errors` in every job under `.github/workflows/`, so the Verify command carries the same flag; a warning that passes a bare `swift test` would still break the project's own gate. The repository's soundness job also runs `swift-format lint --strict`, which is not part of the Verify command and has to be run by hand when touching Swift sources. Reproductions against this package need their own scratch SwiftPM package that depends on it by path, because the library targets expose no executable.

Next: HT-1, the top of the queue.

## iter 2/10 | c1c38f98-163952 | 2026-09-03 | HT-1 | done

Task: HT-1 (High, runtime, correctness) - `HTTPFields.hash(into:)` was order-sensitive while `==` is not, so equal values hashed differently and hashed collections misbehaved. Closed.

Changed: Sources/HTTPTypes/HTTPFields.swift (`hash(into:)` rewritten), Tests/HTTPTypesTests/HTTPTypesTests.swift (`withKnownIssue` wrapper removed from `hashMatchesEqualityForDifferentOrder`; three regression tests added: `equalFieldsCollapseInHashedCollections`, `hashMatchesEqualityUnderRepeatedReordering`, `hashDistinguishesOrderWithinOneName`), PLAN.md (Verify count 44 to 47; the Environment fingerprint no longer claims a `withKnownIssue` exemption that no longer exists), BACKLOG.md (HT-1 deleted).

Checkpoint: 17d5cf24d681c0619700f89528c17f8490dc19e0

Verification: filed reproduction first, against the unfixed tree - a `Set` holding two equal, differently-interleaved `HTTPFields` printed 1 on 14 of 30 runs, 2 on 11, and trapped with "Fatal error: Duplicate elements of type 'HTTPFields' were found in a Set" on 5. Against the fixed tree the same binary printed 1 on 30 of 30 runs, which is the filed Acceptance. The three new tests were run against the unfixed `hash(into:)` by copying the fixed file aside, restoring the old body, running `swift test --filter` over them, and restoring the fixed file byte-for-byte (`diff -q` reports identical): all three failed there, so they are strong enough to fail. Verify gate through quiet-verify.sh - green (2s, `✔ Test run with 47 tests passed after 0.012 seconds.`); the summary line no longer carries "with 1 known issue". `swift-format lint --recursive --strict Sources Tests Benchmarks` reports only the two pre-existing HT-6 warnings, none from this diff. check-claims.sh: 2 checked, 0 mismatched, 0 errored, 0 skipped.

Contract preserved: `==` is untouched, and the new hash keeps the two properties the conformance owes - equal values hash equally, and the hash still separates values that differ. Fields sharing a name are hashed as an ordered group so order within a name still counts, and the group hashes are combined with wrapping addition so the interleaving of different names, which `==` ignores, cannot reach the result. `hashDistinguishesOrderWithinOneName` pins that reordering same-named fields is genuinely a different value rather than a hash the fix made lossy. No benchmark measures hashing (`grep -n 'hash\|Hash' Benchmarks/Benchmarks/HTTPFieldsBenchmarks/*.swift` returns nothing), so the dictionary the new implementation builds regresses no measured figure.

Learnings: `swift test` reports a `withKnownIssue` failure as `✘ ... with 1 known issue` on the summary line while still exiting 0, so a summary pattern that only matches the line, as this project's does, keeps reporting a real number across that change - but the Environment fingerprint has to be re-read when such a wrapper is added or removed, because it is the line that says which assertions the exit status covers.

Next: HT-2, the remaining open High.

## iter 3/10 | c1c38f98-163952 | 2026-09-03 | HT-2 | done

Task: HT-2 (High, runtime, error handling) - the `Optional`-returning Foundation bridges trapped instead of returning nil when the URL carried no scheme. Closed.

Changed: Sources/HTTPTypesFoundation/URLRequest+HTTPTypes.swift (`httpRequest` now rejects a schemeless URL in its existing guard, and its doc comment states the three cases it answers nil for; an import of `URL`'s defining module added because `MemberImportVisibility` is on), Tests/HTTPTypesFoundationTests/HTTPTypesFoundationTests.swift (`schemelessRequestFromFoundationIsNil` added), PLAN.md (Verify count 47 to 48; one Lesson), BACKLOG.md (HT-2 deleted).

Checkpoint: 0fdf4edcfd996201d02d39e0422d515bef73533a

Verification: the failure set was built by provoking the failure, not by reading the source - 14 URL shapes were driven through `URLRequest(url:).httpRequest`, one process each so a trap could not hide the rest. Against the unfixed tree six trapped: a relative path, a bare relative string, `foo/bar`, a protocol-relative URL, a query-only URL and a fragment-only URL; each of the six named the same site, `HTTPTypes/HTTPRequest+URL.swift: Fatal error: Schemeless URL is not supported`, read off that run rather than assumed. The other eight converted or were rejected by `URL(string:)` itself. Across all 14, `url.scheme == nil` held exactly on the six that trapped and on none that did not, which is what makes the guard the same question the trap asks. Against the fixed tree all 14 return: the six answer nil and the other eight produce byte-identical results to their pre-fix output, which is the differential evidence that the guard altered nothing that previously worked - a relative URL resolved against a base still carries a scheme and still converts. The new test was run against the unguarded bridge by copying the fixed file aside and removing the guard: the test process died with `Exited with unexpected signal code 4` on that same fatal error, and the file was restored byte-for-byte (`diff -q` identical). Verify gate through quiet-verify.sh - green (1s, `✔ Test run with 48 tests passed after 0.016 seconds.`). `swift-format lint --recursive --strict Sources Tests Benchmarks` reports only the two pre-existing HT-6 warnings. check-claims.sh: 2 checked, 0 mismatched, 0 errored, 0 skipped.

Contract preserved: `httpRequest` is documented as a conversion that answers nil when it cannot convert, and a URL with no scheme has no value for the ":scheme" pseudo header field, so nil is the answer the type already promised. No public signature changed. The two remaining callers of `httpRequestComponents` are the non-failable `HTTPRequest(method:url:)` and the `HTTPRequest.url` setter, enumerated by `grep -rn 'httpRequestComponents' Sources/ --include='*.swift'`; both still trap by design and HT-3 covers saying so in their documentation. The guard was verified on this host only, where the `URLComponents` branch of `httpRequestComponents` compiles; the CoreFoundation branch that Darwin builds asks the same question of the same URL but was not reachable from here.

Learnings: `MemberImportVisibility` is enabled for every target in Package.swift, so reaching a member of a Foundation type needs that member's defining module imported in the file even when another Foundation module already re-exports the type - `url.scheme` failed to compile in a file that imports only FoundationNetworking.

Next: no open High remains, so the queue's top is the 30 unswept Surface inventory rows.

## iter 4/10 | c1c38f98-163952 | 2026-09-03 | SWEEP | done

Task: Sweep Surface inventory rows. The map is the top of the queue with no open High left. Built the battery infrastructure and swept the HTTPField, HTTPField.Name, HTTPField.Value and HTTPFields rows - 13 of the 30.

Changed: .jeffy/probes/run-suite.sh (shared runner), .jeffy/probes/httpfield-value/, .jeffy/probes/httpfield-name/ (including check-constants.py), .jeffy/probes/httpfields/ (paths, claims, README each), Tests/HTTPTypesTests/ProbeHTTPFieldValueTests.swift, Tests/HTTPTypesTests/ProbeHTTPFieldNameTests.swift, Tests/HTTPTypesTests/ProbeHTTPFieldsTests.swift, PLAN.md (Verify count 48 to 76; 13 rows flipped in the bookkeeping edit).

Checkpoint: 6def1e500cb7386a09a883f343ecf338e0f55194

Verification: the batteries are known-answer instruments, not liveness probes - every expectation is a value computed by hand from RFC 9110's grammar or from the type's own doc comment, and equality is compared differentially against a reference implementation written straight from that doc comment, over short lists where the lock-step walk runs and long reordered ones where the by-name-index fallback takes over, with `isEqualByNameIndex` pinned against the same reference. Each battery was observed failing before it was trusted, and each mutated file was restored byte-for-byte with `diff -q` confirming it: widening the legal field-value byte range to admit DEL reddens three named checks in `ProbeHTTPFieldValue`; dropping the backtick from the tchar lists reddens `tokenCharacterSetMatchesTheGrammar`; mistyping one constant's canonicalName makes check-constants.py name that constant and exit non-zero; restoring the pre-fix order-sensitive `hash(into:)` reddens `hashHoldsUnderReordering` and `hashedCollectionsBehave`. The runner itself was caught over-counting: `grep -c '^✔ Test '` also matched the `Test run with N tests passed` summary line, so every battery read one check high, which the first claims check surfaced as a MISMATCH before any row was flipped. Verify gate through quiet-verify.sh - green (3s, `✔ Test run with 76 tests passed after 0.113 seconds.`). `swift-format lint --recursive --strict Sources Tests Benchmarks` reports only the two pre-existing HT-6 warnings. check-claims.sh: 6 checked, 0 mismatched, 0 errored, 0 skipped.

The batteries live as swift-testing suites under Tests/ rather than as a private harness, so the project's own Verify command and its CI run them too and a battery can never certify a contract the shipped suite does not also hold. Each battery's paths file names the source files its rows cover, so an edit to any of them staleens exactly the rows that edit could invalidate.

Learnings: a probe runner that counts result lines must exclude the run summary - swift test prints `✔ Test run with N tests passed`, which matches a naive `^✔ Test ` count and inflates every battery by one. Batteries added as test files change the Verify count, so PLAN.md's Verify count line is updated in the same iteration.

Next: sweeping continues - 17 rows remain unswept, led by HTTPRequest, HTTPResponse, HTTPParsedFields and the URL bridge.

## iter 5/10 | c1c38f98-163952 | 2026-09-03 | SWEEP | done

Task: Sweep Surface inventory rows, continued. Swept the HTTPRequest, HTTPResponse, HTTPParsedFields and error code rows - 8 more, taking the map to 21 of 30. Filed HT-7, which the HTTPResponse sweep surfaced.

Changed: .jeffy/probes/httprequest/, .jeffy/probes/httpresponse/, .jeffy/probes/httpparsedfields/, .jeffy/probes/error-codes/ (including check-error-codes.py) with paths, claims and README each; Tests/HTTPTypesTests/ProbeHTTPMessageTests.swift; Tests/HTTPTypesTests/ProbeParsedAndErrorCodeTests.swift; PLAN.md (Verify count 76 to 94; 8 rows flipped in the bookkeeping edit); BACKLOG.md (HT-7 filed under Next).

Checkpoint: 3dcbbf397ce56152185cd96d8b3049c7aefd9180

Verification: every battery was observed failing before it was trusted, and every mutated file was restored byte-for-byte with `diff -q` confirming it. Removing the `isKnownUniquelyReferenced` copy from the `scheme` setter reddens `pseudoHeaderFieldsAreCopyOnWrite`; narrowing the `serverError` range to `500...598` reddens `kindPartitionsAtEveryBoundary`; disabling the pseudo-fields-must-come-first check reddens `requestRulesAreEnforced`; renaming HTTP/2 `0x08` in the description switch reddens `http2CodesCarryTheirRegisteredValues`; deleting the `H3_VERSION_FALLBACK` arm makes check-error-codes.py name `versionFallback (0x110)` and exit non-zero. Verify gate through quiet-verify.sh - green (1s, `✔ Test run with 94 tests passed after 0.108 seconds.`). `swift-format lint --recursive --strict Sources Tests Benchmarks` reports only the two pre-existing HT-6 warnings. check-claims.sh: 11 checked, 0 mismatched, 0 errored, 0 skipped.

HT-7 filed (Medium, runtime, correctness): two of this sweep's hand-computed expectations disagreed with the implementation, and one of the two was the implementation's fault. `HTTPResponse.Status` documents that characters not representable in ISO Latin 1 become spaces, but `legalizingReasonPhrase` decides validity over UTF-8 bytes rather than scalars, and every non-ASCII scalar encodes to bytes inside the accepted `0x80...0xFF` range, so the fast path returns them unchanged. Reproduced in a scratch program printing the scalar values: `"emoji \u{1F600}"` comes back carrying U+1F600, and `"\u{4F60}\u{597D}"` comes back unchanged, while `"emoji \u{0}\u{1F600}"` - the same emoji with one control byte added - takes the slow path and comes back as spaces. The battery deliberately does not pin the current behaviour for those inputs; the README says so, so the row is swept without certifying the gap as correct. The other disagreement was mine: `HTTPResponse.debugDescription` renders as its status, `200 OK`, not the shape I guessed, and the expectation was corrected to the observed contract.

Learnings: a hand-computed expectation that disagrees with the code is a fork, not a failure - one branch is a defect to file and the other is a wrong guess to correct, and the sweep has to decide which before touching either. A battery must not pin behaviour it has just filed as a defect; naming the finding ID in the battery README is how the row stays swept without certifying the gap.

Next: sweeping continues - 9 rows remain, the URL bridge, the four HTTPTypesFoundation rows, and the Benchmarks, linkage test and packaging rows.

## iter 6/10 | c1c38f98-163952 | 2026-09-03 | SWEEP | done

Task: Sweep Surface inventory rows, continued. Swept the URL bridge, all five HTTPTypesFoundation rows, the linkage test package and the repository packaging rows, and disclosed the Benchmarks row as unreachable on this host. The map is now complete: 29 of 30 swept, 1 disclosed.

Changed: .jeffy/probes/httprequest-url/, .jeffy/probes/foundation-bridge/, .jeffy/probes/repository-integration/ (run-linkage.sh, check-packaging.py, paths, claims, README each); .jeffy/probes/httprequest/claims (filter anchored); Tests/HTTPTypesTests/ProbeHTTPRequestURLTests.swift; Tests/HTTPTypesFoundationTests/ProbeFoundationBridgeTests.swift; PLAN.md (Verify count 94 to 104; one Lesson; 8 rows flipped and 1 disclosed in the bookkeeping edit).

Checkpoint: 38131b0c893a05f2fba42fb0d1b4dc30d3128e65

Verification: every instrument was observed failing before it was trusted, and every mutated file was restored byte-for-byte with `diff -q` confirming it. Taking the request path from `pathRange` rather than `requestPathRange`, which silently drops the query from every request built out of a URL, reddens two checks in `ProbeHTTPRequestURL`; replacing the Cookie separator with the comma every other field uses reddens `repeatedFieldsJoinWithTheRightSeparator`; enabling the `FoundationURL` trait in the linkage test package makes the repository's own linkage script find a Foundation library and exit non-zero; dropping `HTTPTypesFoundation` from `.spi.yml` makes check-packaging.py name that invariant and exit non-zero. Verify gate through quiet-verify.sh - green (1s, `✔ Test run with 104 tests passed after 0.125 seconds.`). `swift-format lint --recursive --strict Sources Tests Benchmarks` reports only the two pre-existing HT-6 warnings. check-claims.sh: 15 checked, 0 mismatched, 0 errored, 0 skipped.

Two instrument defects were caught by the claims check rather than by inspection. The `httprequest` battery's filter, the bare suite name `ProbeHTTPRequest`, also matched the new `ProbeHTTPRequestURL` suite, so the battery reported 8 checks where it owns 5; the filter is now anchored with a trailing slash. And the `httprequest-url` claim was written at 7 before the suite was counted, where the two suites together hold 6. Neither reached a flipped row: both were MISMATCHes before any bookkeeping.

The Benchmarks row is disclosed as `[~]` rather than swept. `swift build --package-path Benchmarks` fails on this host with `error: could not build C module 'jemalloc'`, inside the package-benchmark dependency and before any of this project's benchmark sources are compiled, so the row is unreachable here rather than failing. `swift package --package-path Benchmarks resolve` succeeds, so the obstacle is the missing jemalloc headers on this host and not the manifest.

The URLSession conveniences row is swept only as far as this host reaches: the checks drive the conversion failure that happens before any request is issued, and the battery README says so. No network transport is exercised by this battery or by the project's own suite.

Learnings: a probe battery's `swift test --filter` regex must be anchored - an unanchored suite name also matches every sibling suite whose name extends it, and the battery silently counts the sibling's checks as its own. A battery claim written before the suite is counted is a guess; measure first, then record.

Next: the ledger. Two Mediums, HT-7 then HT-4, then the three Lows.

## iter 7/10 | c1c38f98-163952 | 2026-09-03 | HT-7 | done

Task: HT-7 (Medium, runtime, correctness) - the reason phrase's validity was judged per UTF-8 byte, so every non-ASCII scalar passed unchanged and the documented ISO Latin 1 promise was not kept. Closed.

Changed: Sources/HTTPTypes/HTTPResponse.swift (`isValidReasonPhrase` now judges per unicode scalar), Tests/HTTPTypesTests/ProbeHTTPMessageTests.swift (four legalization cases added and `codableAgreesWithLegalization` added), .jeffy/probes/httpresponse/README.md and claims (the caveat replaced by what the battery now pins; 6 checks to 7), PLAN.md (Verify count 104 to 105; two rows re-recorded in the bookkeeping edit), BACKLOG.md (HT-7 deleted).

Checkpoint: 401b656ac5464276cdf3a454a80888029a1edd54

Verification: the filed Acceptance, run in a scratch program that prints scalar values - `"emoji \u{1F600}"` legalizes to `"emoji  "` with every scalar at most 0xFF, `"\u{4F60}\u{597D}"` to two spaces, `"caf\u{E9}"` unchanged, and the same scalar now legalizes identically whether or not a control byte forces the slower path. The two new checks were run against the restored byte-wise predicate by copying the fixed file aside: `reasonPhraseIsLegalized` and `codableAgreesWithLegalization` both failed there, and the file was restored byte-for-byte (`diff -q` identical). One check of the pair was written wrong first and would have passed vacuously: the smuggled Codable payload used a pseudo header shape the encoder does not emit, so the decode failed on a missing key rather than on the reason phrase. The payload is now copied from a real encoding and the test asserts that the valid form decodes before asserting the tampered one does not. Battery ownership: the diff touches `Sources/HTTPTypes/HTTPResponse.swift`, which only `.jeffy/probes/httpresponse` declares; re-run through the runner at 7/7. Verify gate through quiet-verify.sh - green (1s, `✔ Test run with 105 tests passed after 0.112 seconds.`). `swift-format lint --recursive --strict Sources Tests Benchmarks` reports only the two pre-existing HT-6 warnings. check-claims.sh: 15 checked, 0 mismatched, 0 errored, 0 skipped.

Contract preserved, and one observable behaviour deliberately changed, recorded here as the Constraints require. The fix makes one definition of validity serve both callers, enumerated by `grep -rn 'isValidReasonPhrase' Sources/ --include='*.swift'`: the initializer, which legalizes, and `HTTPResponse.init(from:)`, which rejects. Before the fix a phrase carrying a scalar above U+00FF was accepted by both; now the initializer replaces it with a space and the decoder rejects it. That asymmetry between the two callers is pre-existing and intended - decoding is strict where construction legalizes - and the change closes the round trip rather than opening it: after the fix the encoder can only emit scalars at most 0xFF, so everything this library encodes still decodes, which `codableAgreesWithLegalization` drives over every legalization case. The compatibility cost is real and narrow: a document written by an earlier version whose reason phrase carries such a scalar now fails to decode instead of decoding a value the type says is invalid. Equality and hashing ignore the reason phrase, so nothing about response identity moves.

Learnings: a negative Codable check must first assert that the untampered payload decodes, or a payload whose shape is wrong throws for the wrong reason and the check passes over any implementation at all.

Next: HT-4, the remaining Medium.

## iter 8/10 | c1c38f98-163952 | 2026-09-03 | HT-4 | done

Task: HT-4 (Medium, build-ci, dependency hygiene) - the loop's own state files reached this package's source-archive channel. Closed.

Changed: .gitattributes (new; PLAN.md, BACKLOG.md, JOURNAL.md, JOURNAL-archive.md and .jeffy marked export-ignore), .jeffy/probes/repository-integration/check-archive.sh (new), .jeffy/probes/repository-integration/paths, claims and README, BACKLOG.md (HT-4 deleted).

Checkpoint: 09680dcf0f4a09a6cd680d375c34f5bc6645fa61

Verification: the filed Acceptance, `git archive HEAD | tar t | grep -cE '^(PLAN|BACKLOG|JOURNAL(-archive)?)\.md$|^\.jeffy/'`, prints 0 at this checkpoint and 53 against the commit before it, so the reproduction failed on the base commit and passes now. Extracting the archived tree to a scratch directory and running `swift test -Xswiftc -warnings-as-errors` there passes 105 tests, which is what shows export-ignore removed nothing the package needs rather than only that it removed something. The two other publishing channels named in the finding were each measured rather than assumed: `swift package archive-source` produces a zip carrying no loop-state entry now that `.gitattributes` is committed - an earlier run against the same file staged but uncommitted still carried all 53, which is the behaviour to expect since export-ignore is read from the tree being archived, and it is why check-archive.sh reads HEAD rather than the working tree. A consumer's `git clone` is unchanged and cannot be changed; the `.gitattributes` comment says so, and the finding never claimed otherwise. The new instrument was exercised on its failure branch in a scratch clone checked out at the pre-fix commit, where it reported `53 loop-state paths reach git archive` and exited 1. Battery ownership: no existing battery declared `.gitattributes`, so the check joined `.jeffy/probes/repository-integration`, which owns repository packaging, and that path is now in its paths file; the battery runs 3 claims, all MATCH. Verify gate through quiet-verify.sh - green (0s, `✔ Test run with 105 tests passed after 0.116 seconds.`). check-claims.sh: 15 checked, 0 mismatched, 0 errored, 0 skipped.

Contract preserved: `.gitattributes` carries only `export-ignore` lines, no `text` or `eol` attribute, so no file's line endings change and no build input moves. The 13 root entries the archive keeps are the package's own - the manifest, the README, the licence and notice files, the editor and format configs, `.spi.yml` and `.gitignore`.

Learnings: `export-ignore` is read from the tree being archived, so a `.gitattributes` change has no effect until it is committed - a check written against the working tree would have reported the fix working while it was not, and a check written against HEAD reports it correctly. A probe that reads HEAD must be exercised on its failure branch in a scratch clone at the pre-fix commit; checking out the pre-fix commit in place removes the probe script itself and the run exits 127 rather than failing.

Next: the three carried Lows - HT-5, HT-3, HT-6 - or the evaluator gate. The ledger is at the severity floor and the map is swept, but no full audit this run has scored clean, so the closing audit still has to happen before any declaration.

## iter 9/10 | c1c38f98-163952 | 2026-09-03 | AUDIT | audit

Task: The closing full audit. Rescore every applicable dimension against the rubric and the Operating envelope with fresh evidence, re-read the Oracle class and Environment fingerprint, re-score the three carried Lows, and decide whether the run may reach a declaration.

Changed: JOURNAL.md and PLAN.md only. No file outside the state files changed and no BACKLOG.md item changed state; this is an AUDIT that files nothing, which the stall rule exempts, and the previous primary entry is HT-4 done, so no pair forms.

Checkpoint: 9f29cea011817a20c8495d0c1d2a6e483e1f83b6

Verification: Verify gate through quiet-verify.sh - green (1s, `✔ Test run with 105 tests passed after 0.117 seconds.`). check-claims.sh over all eleven batteries and the two Stated counts rows: 16 checked, 0 mismatched, 0 errored, 0 skipped. The Environment fingerprint's own derivation was re-run rather than re-read: `grep -rnE '#if|@available|withKnownIssue|\.disabled' Tests/ --include='*.swift'` returns only FoundationEssentials and FoundationNetworking selections, no `withKnownIssue` and no disabled test, and `git ls-files '*/Package.swift'` still returns the Benchmarks and LinkageTest manifests the fingerprint names as outside the command. The Oracle class still describes what the command grades. Verify count reads 105, which is the total the wrapper's green line reports. There are no Declined entries and no Settled classes, so there was no Derivation or enumeration to re-run.

Scores. All 30 inventory rows are accounted for: 29 swept with batteries, 1 disclosed `[~]` - the Benchmarks package, unreachable on this host because package-benchmark's jemalloc module will not build here. Nothing below claims that row.
- correctness: None. Every battery re-run green this iteration. The two correctness defects this run found, HT-1 and HT-7, are closed with regression checks that were each observed failing against the pre-fix code.
- security: None on the swept surface. The library performs no I/O. Every unsafe construct in the shipped sources was enumerated by `grep -rnE 'withUnsafeTemporaryAllocation|unsafeBitCast|UnsafeMutableBufferPointer|UnsafeRawBufferPointer|unsafeUninitializedCapacity|assumingMemoryBound|\.baseAddress' Sources/ --include='*.swift'`, and each of the four temporary allocations in the value path sizes itself from the input's `count` and writes at most once per iterated element. That bound was driven rather than reasoned about: the value path was fed an Array, an ArraySlice, a String and Substring UTF8View, a lazy map, a ContiguousArray, a Data and an empty collection, and every one returned the hand-computed legalization. The `String(unsafeUninitializedCapacity: 3)` in the status field value is safe because the only writer of that field, the public `PseudoHeaderFields.status` setter, carries `precondition(Status.isValidStatus(...))` and the decoder re-checks it. The CoreFoundation branch of the URL bridge is not compiled on this host and is not claimed.
- error handling: None on the swept surface. The adversarial Codable surface was driven with 14 hostile payloads, each in its own process so a trap would be visible: none trapped, twelve were rejected with a DecodingError - a short, non-digit, empty or repeated `:status`, a non-token or missing `:method`, a non-pseudo field in the pseudo list, a pseudo field inside the header fields, an invalid field name, a control byte in a value, and a scalar above 0xFF - and two were accepted with defined tolerant behaviour: an unknown pseudo name is dropped, and an out-of-range indexingStrategy falls back to `.automatic`. Both tolerances are written into the decoders deliberately, neither produces a wrong result a user meets, and neither is filed.
- architecture, developer experience: None on the swept surface.
- testing: Low, and it is the suite's own gap rather than the product's: the Verify command grades no benchmark and no network transport. Named, not filed, because class test is Low by the rubric's ceiling and nothing here names something a user of the shipped product meets.
- performance: None on the swept surface. Equality keeps its adaptive lock-step and by-name-index paths, both now pinned differentially. HT-1's fix allocates a dictionary per hash where the old one allocated nothing; no benchmark measures hashing, so no measured figure regressed, and the run does not claim an unmeasured one.
- documentation: Low - HT-3.
- dependency hygiene: None. The package declares no external dependency; the three `dependencies:` occurrences in Package.swift are all intra-package target edges.
- code quality: Low - HT-6.
- observability, UX and accessibility: not applicable, unchanged from the first audit.

Zero High and zero Medium in-envelope. Closeout has begun: this run stops auditing from here, works or carries what is on the ledger, and finishes with the evaluator gate and the declaration.

Carried Lows, each re-scored against the rubric and the envelope this iteration and each priced as fixable inside one iteration, so none is Declined:
- HT-5 (Low, runtime, correctness): `HTTPField.Name(parsed:)` accepts a name that is not lowercased. Low because the Operating envelope classifies parsed-field ingestion machine-generated and the documented contract is decoder output, which lowercases.
- HT-3 (Low, docs, documentation): the two non-failable URL entry points trap on a schemeless URL without saying so. Low by the severity ceiling by class: it names no consequence beyond the documentation itself, since the Optional-returning paths were the ones a user meets and HT-2 closed those.
- HT-6 (Low, dev-tooling, code quality): two swift-format lint warnings. Low always by the ceiling for class dev-tooling.

Learnings: an audit that has already swept its whole map earns its fresh evidence by driving the surface again rather than by re-reading it - the hostile Codable pass and the collection-kind pass were both new this iteration and both were cheap.

Next: the evaluator gate and, on a PASS, the declaration, in iteration 10.

## iter 10/10 | c1c38f98-163952 | 2026-09-03 | EVALUATOR | audit

Task: The evaluator gate, invocation 1 of this run. Standing claims brought current first, then one fresh-context sub-agent invoked. Verdict REJECT. No declaration.

Changed: .jeffy/evaluator/c1c38f98-163952-1.md (the gate's artifact), BACKLOG.md (HT-8 filed under Now; HT-9 and HT-10 filed under Later).

Checkpoint: e39ba6dd09552b308d9ba4cff5a37472dd6ab3c0

Verification: standing claims brought current in this iteration before the invocation - check-claims.sh over all eleven batteries and both Stated counts rows reports 16 checked, 0 mismatched, 0 errored, 0 skipped; no Surface inventory row is stale, derived by walking every row's recorded commit against its battery's declared paths with `git diff --name-only`; there are no Declined Derivations and no Settled classes to re-run; PLAN.md names no finding ID as carried or blocked; the Oracle class and Environment fingerprint were re-read and Verify count reads 105, the total the wrapper's green line reports. Verify gate through quiet-verify.sh - green (1s, `✔ Test run with 105 tests passed after 0.112 seconds.`).

Evaluator: REJECT - the lock-step branch of `HTTPFields.==` ignores `indexingStrategy` while every other branch and the hash compare whole fields, so the Hashable violation HT-1 closed is still open on a second axis.

The gate's reason was reproduced here before being filed rather than taken on trust. `Sources/HTTPTypes/HTTPFields.swift`, in the branch guarded by `pendingLeft.isEmpty`, compares `lhs._fields[index].name` and `.value` and returns early; the pending branch and `isEqualByNameIndex` both compare whole `HTTPField` values, and `hash(into:)` combines whole fields. Driving it: two single-field lists differing only in `indexingStrategy` report `HTTPField ==` false, `HTTPFields ==` true, `isEqualByNameIndex` false and hashes unequal; adding one differently-named field makes `==` answer false when that field is interleaved and true when it is not, so `==` disagrees with itself on the same pair of values; and inserting both into a `Set` trapped with `Fatal error: Duplicate elements of type 'HTTPFields' were found in a Set.` on 2 of 8 runs, reporting count 1 on three of the rest and 2 on the others. Filed as HT-8 at High, and as a structural task rather than an instance patch: this is the second finding whose root cause is that the equality and hashing family carries no single definition of field identity, and the fix is one definition used by every branch and by the hash.

The defect is pre-existing - it is in the lock-step walk that predates this run's first checkpoint - so it is a missed finding rather than a regression this run introduced. That does not soften it. It sits in the exact function pair this run rewrote and certified, and iteration 9's closing audit scored correctness None over it. That score is now falsified, and the audit that produced it was not wrong about its method but about its coverage: the battery pinning that row varies names, values and order but never `indexingStrategy`, so its differential and its reference agreed because both were blind on the same axis. Filed as HT-9.

The gate's other observation, that HT-1's fix costs roughly twice the previous hashing time in a release build, is filed as HT-10 at Low: no benchmark measures hashing, so no measured figure regressed, and the run never claimed an unmeasured one.

One evaluator invocation remains, the cap being 2 because the first landed past the midpoint of the budget. The run is out of budget at iteration 10 of 10 and does not declare. Nothing about the closing conditions is asserted here beyond what was measured: the Verify command is green, the map is swept, and the ledger now holds an open High, so convergence is not available to this run.

Learnings: a differential test is only as strong as the axes its generator varies - the reference implementation and the implementation agreed here because both ignored the same property, and no amount of random volume on the other axes would have found it. A battery that certifies a type's equality must vary every stored property of that type, not only the ones its doc comment discusses.

Next: HT-8 is the next run's first task. Its acceptance check is written and its reproduction is in this entry.

## iter 1/10 | 72d2e6e2-174500 | 2026-09-03 | HT-8 | done

Task: HT-8 (High, runtime, correctness) - the lock-step branch of `HTTPFields.==` decided field identity from a projection of `HTTPField` while every other branch and the hash compared whole fields. Closed.

Changed: Sources/HTTPTypes/HTTPFields.swift (the lock-step branch now compares whole fields), Tests/HTTPTypesTests/ProbeHTTPFieldsTests.swift (new check `equalityComparesWholeFields`), .jeffy/probes/httpfields/claims (12/12 to 13/13) and README.md (the new check and its observed-failing procedure), BACKLOG.md (HT-8 deleted, HT-9 restated, Settled classes line added), PLAN.md (Verify count 105 to 106, one Lesson).

Checkpoint: 5011a07c52bd623178ca146ceccf8716f88d3cb2

Verification: the filed reproduction was run first, against the unfixed code, from a scratch SwiftPM package depending on this one by path. It reported `HTTPField ==` false, lock-step `HTTPFields ==` true, `isEqualByNameIndex` false, hashes unequal, interleaved `==` false and `Set` count 1 - `==` disagreeing with itself, with `isEqualByNameIndex` and with the hash on the same pair of values. Against the fixed code the same binary reports `==` false on both orderings, agreeing with `isEqualByNameIndex` and with `HTTPField ==`, and `Set` count 2 on 30 consecutive runs, 30 as expected and 0 unexpected, which is the filed Acceptance in full.

Driving the reproduction surfaced a second axis of the same root cause rather than only the filed one: the branch compared `.value`, the lossy UTF-8 String view of `HTTPField.Value`, while that type's own `==` compares raw bytes. Two fields carrying the single bytes 0xFE and 0xFF have distinct raw values, both decode to the same replacement character, and the pre-fix branch called them equal while `HTTPField ==`, `isEqualByNameIndex` and the hash all called them different - so a `Set` held both while `==` said they were one value. Both axes are one defect and both close under the one fix.

The fix is the structural one the task asked for, not an instance patch: the branch's hand-rolled `name`-and-`value` comparison is deleted, so every site that decides identity names a whole `HTTPField` and the hash combines whole fields. Enumerated by `grep -nE '(==|!=) (lhs|rhs)\._fields\[[^]]*\] \{|!= field \{|\.combine\(field\)$' Sources/HTTPTypes/HTTPFields.swift`, which returns five lines - three comparisons inside `==`, one inside `isEqualByNameIndex`, the `combine(field)` inside `hash(into:)` - and `grep -nE '\.(value|rawValue|indexingStrategy) *(==|!=)' Sources/HTTPTypes/HTTPFields.swift` returns nothing. Recorded under Settled classes with that enumeration.

The new check was observed failing before it was trusted: with `Sources/HTTPTypes/HTTPFields.swift` restored from 045920fcdd65a7b39980d77960c0893a29073217 - the working file copied aside first and diffed back afterwards to confirm the restore was byte-identical - `ProbeHTTPFields` reports `equalityComparesWholeFields` failed with 3 issues and the other 12 checks green, naming `(lockStepLeft → [Accept: 1]) != (lockStepRight → [Accept: 1])`, `(set.count → 1) == 2` and the byte-storage pair. Battery ownership: `.jeffy/probes/httpfields/paths` is the only paths file declaring `Sources/HTTPTypes/HTTPFields.swift`; that battery ran green at 13/13 and its claims and README were updated in this iteration. Verify gate through quiet-verify.sh - green (1s, `✔ Test run with 106 tests passed after 0.130 seconds.`), and Verify count moved from 105 to the 106 the wrapper reports. check-claims.sh: 16 checked, 0 mismatched, 0 errored, 0 skipped. `swift-format lint --recursive --strict Sources Tests Benchmarks` reports the same 2 warnings as before, both HT-6's, so the change adds none.

Contract preserved: the documented meaning of `==` is unchanged - for every name, the same fields in the same order, with different names free to interleave - and the reference implementation in the battery, written from that sentence, still agrees with the implementation on every random list it drives. What changed is which fields count as the same field, and that moved to agree with `HTTPField`'s own `==` rather than away from it, so the only pairs whose answer changed are pairs the type already called unequal. The fast path was also reordered to compare the whole field first and consult the names only on a mismatch, so the common equal case now costs one comparison where it cost two; no measurement is claimed beyond that shape, and the Benchmarks package is unreachable on this host.

Learnings: an optimised fast path is a second definition of the thing it optimises, and it drifts silently - the branch compared `name` and `value` where the type compares `name`, `indexingStrategy` and `rawValue`, and nothing in the suite noticed because the differential's generator moved neither of the two axes that differed. Comparing the whole value first and falling back to the projection only to classify a mismatch is both correct and cheaper here, which is the shape to prefer.

Next: HT-9 - widen the differential generator so it, and not only the targeted check, would redden on this defect - then the other carried Lows - HT-10, HT-5, HT-3 and HT-6 - and a full audit before any declaration.

## iter 2/10 | 72d2e6e2-174500 | 2026-09-03 | HT-5 | done

Task: HT-5 (Low, runtime, correctness) - `HTTPField.Name(parsed:)` stored a name verbatim as `canonicalName`, so a name that was not lowercased produced a field no name-keyed lookup could reach. Closed.

Changed: Sources/HTTPTypes/HTTPFieldName.swift (`init?(parsed:)` canonicalizes, doc comment restated), Tests/HTTPTypesTests/ProbeHTTPFieldNameTests.swift (new check `parsedCanonicalizesNamesThatAreNotLowercased`), .jeffy/probes/httpfield-name/claims (6/6 to 7/7) and README.md, BACKLOG.md (HT-5 deleted; the Later section reordered so the two runtime Lows sit above the test, docs and dev-tooling ones, which the section's own ordering rule asks for and the ledger did not follow), PLAN.md (Verify count 106 to 107).

Checkpoint: 62d1f891154b7d0f600602729f1c905ac4955a0e

Verification: the filed reproduction was run first against the unfixed code from a scratch SwiftPM package depending on this one by path. It reported `HTTPField.Name(parsed: "Content-Type")` non-nil with `canonicalName` "Content-Type", unequal to `HTTPField.Name("content-type")`, and a field carrying it reading back as nil through `fields[.contentType]` - the finding as filed. Against the fixed code the same binary reports `canonicalName` "content-type", `rawName` "Content-Type", equality with `HTTPField.Name("content-type")` true, and `fields[.contentType]` returning "text/plain", which is the filed Acceptance's second branch. The same run confirms what the fix must not disturb: `HTTPField.Name(parsed: "content-type")` still stores "content-type", `HTTPField.Name(parsed: "content type")` is still nil, and `:Method` and `:method` now denote one name.

Of the two branches the Acceptance offered - return nil, or canonicalize - canonicalizing is the one taken, because the sibling `init?(_:)` already accepts "Content-Type" and canonicalizes it through `validatedCanonicalName`, so rejecting there would have made the decoder-facing initializer stricter about case than the general one for no stated reason. It is also the smaller change to accepted input: nothing that succeeds today begins to fail, where returning nil would have turned today's silently-broken value into a nil that the callers in this tree force-unwrap.

The new check was observed failing before it was trusted: with `Sources/HTTPTypes/HTTPFieldName.swift` restored from 21729759e92b62d2498ba5718746e0bed29cf68f - the working file copied aside first and diffed back afterwards to confirm the restore was byte-identical - `ProbeHTTPFieldName` reports `parsedCanonicalizesNamesThatAreNotLowercased` failed with 10 issues and the other 6 checks green, the first reading `(name.canonicalName → "Content-Type") == (canonical → "content-type")`. Battery ownership: `.jeffy/probes/httpfield-name/paths` is the only paths file declaring `Sources/HTTPTypes/HTTPFieldName.swift`; that battery ran green at 7/7 and its constants instrument at 82/82, and its claims and README were updated in this iteration. Verify gate through quiet-verify.sh - green (1s, `✔ Test run with 107 tests passed after 0.118 seconds.`), Verify count moved 106 to 107. check-claims.sh: 16 checked, 0 mismatched, 0 errored, 0 skipped. `swift-format lint --recursive --strict Sources Tests Benchmarks` reports the same 2 warnings as before, both HT-6's.

Contract preserved: `rawName` still carries the spelling as given, `canonicalName` is still the lowercased form used for hashing and comparison, and the token grammar is unchanged - the switch reads the same `tokenValidity` the initializer's `isValidToken` already computed, so the `.canonical` path allocates nothing and only an off-contract name pays for a `lowercased()`. The doc comment no longer states a precondition the code does not enforce; it says what the initializer does with a name that is not lowercased. One asymmetry is left standing deliberately and is not a finding: `JSONDecoder` still rejects an uppercased pseudo name such as ":Method" while `init(parsed:)` now canonicalizes it. The Operating envelope classifies Codable decoding adversarial and parsed-field ingestion machine-generated, so the stricter answer on the adversarial surface is the intended one, and widening it was not this task.

Learnings: two initializers of one type that differ in what they validate will drift, and the drift is invisible until something compares their outputs - here `init(parsed:)` skipped the canonicalisation `init(_:)` performs, and the only symptom was a lookup returning nil. `TokenValidity` already distinguished `.canonical` from `.valid`, so the fix was to consume a classification the code was throwing away rather than to add a rule.

Next: HT-10, the remaining runtime Low, then HT-9, HT-3 and HT-6, then the closing full audit and the evaluator gate.

## iter 3/10 | 72d2e6e2-174500 | 2026-09-03 | HT-10 | done

Task: HT-10 (Low, runtime, performance) - whether `HTTPFields.hash(into:)` should stop building a dictionary per hash. Measured, and moved to Declined: the allocation is not what the hash costs.

Changed: .jeffy/probes/hash-allocation/ (new: compare-hash-implementations.swift, compare-hash-implementations.sh, README.md, claims reading none), BACKLOG.md (HT-10 deleted from Later and recorded under Declined with its Derivation), PLAN.md (two Lessons). No shipped source changed this iteration; a BACKLOG item changed state, so this is not a stall.

Checkpoint: cde52c290272b1e76671456f88883d86080f9759

Verification: the finding proposed a remedy, so the remedy was timed before it was written. A release build in a scratch SwiftPM package depending on this one by path times four implementations over seven list sizes, and the harness refuses to time anything until the candidate is shown to hold the Hashable contract - twenty thousand random lists each against a shuffled copy, any equal pair whose hashes differ aborting the run, and the run reporting how many equal and unequal pairs it drove so a generator that stopped producing equal pairs cannot pass silently. The run behind this entry reported 15550 equal and 4450 unequal pairs, then:

    fields  distinctNames    current ns    candidate ns    cand/cur  preHT1 ns    cur/preHT1  intKey ns   int/cur
    2       2                344.5         281.5           0.8x     202.9        1.7x        391.6       1.1x
    8       4                1084.4        962.0           0.9x     650.2        1.7x        1079.7      1.0x
    16      8                1939.2        1845.8          1.0x     1204.0       1.6x        1940.4      1.0x
    32      8                3322.5        3915.8          1.2x     2332.4       1.4x        3583.6      1.1x
    64      16               6173.5        7876.1          1.3x     4960.5       1.2x        7221.4      1.2x
    256     32               31318.9       40477.7         1.3x     18398.2      1.7x        25707.9     0.8x
    1024    64               98467.6       90690.5         0.9x     77218.0      1.3x        109057.4    1.1x

The allocation-free candidate - each field's ordinal within its name group derived from a `withUnsafeTemporaryAllocation` stack buffer rather than a dictionary - lands in a 0.8x to 1.6x band across four runs of the harness, faster only at the two extremes of the size range and slower through all of its middle. A variant keeping one allocation but keying the groups by the name's hash rather than the name lands in a 0.8x to 1.2x band. Neither is an improvement, so the remedy the finding proposed does not achieve its purpose and the finding is Declined on a measurement rather than deferred: severity is unchanged at Low, and the Derivation on the Declined line re-runs the whole comparison.

The finding's own premise was checked rather than assumed. It is directionally right and overstated: the shipped hash measures 1.2x to 2.0x the pre-HT-1 implementation, not roughly twice throughout. That baseline is also not an alternative - it is the order-sensitive `for field in fields { hasher.combine(field) }` that HT-1 removed, which violates the contract `==` requires - so the multiple is the price of correctness, not of the dictionary.

Two corrections were made to the instrument before its numbers were used. An earlier revision timed one constant value and measured a 64-field list hashing faster than a 32-field one, which is the optimiser hoisting the call out of the loop; the loop now cycles sixteen distinct values and the anomaly is gone. And the README's first draft claimed the contract check would redden if the candidate dropped its per-field ordinal - it does not, and cannot: a coarser hash is a legal hash, since the contract binds equal values to equal hashes and says nothing about unequal ones. The mutation that does redden it is folding the group hashes order-sensitively, `combined = combined &* 31 &+ group.finalize()`, which reports `CANDIDATE VIOLATES THE HASHABLE CONTRACT` and exits 1; that was run, and the file restored byte-for-byte and diffed to confirm it.

The instrument is deliberately not given a `paths` file. A battery named there runs whenever its declared files change and its failure counts as a Verify failure, and a noisy timing harness in that role would fail iterations for reasons that are not defects; its claims file reads `none` for the same reason, since nothing it prints is a standing claim.

Battery ownership: this diff touched no path any battery declares, so none was triggered; the new directory declares none. Verify gate through quiet-verify.sh - green (1s, `✔ Test run with 107 tests passed after 0.117 seconds.`). check-claims.sh: 16 checked, 0 mismatched, 0 errored, 0 skipped. `swift-format lint --recursive --strict Sources Tests Benchmarks` reports the same 2 warnings, both HT-6's.

Learnings: a performance finding names a remedy, and the remedy is a hypothesis - timing it against the shipped code first is what stopped an iteration being spent adding a second hash path for a loss, in the one function that has already produced two Hashable defects here. And an instrument that can only fail one way needs its failure named precisely: "the check would catch X" was wrong about this harness in a way that reading it could not reveal and running it settled in a minute.

Next: HT-9, then HT-3 and HT-6, then the closing full audit and the evaluator gate.

## iter 4/10 | 72d2e6e2-174500 | 2026-09-03 | HT-9 | done

Task: HT-9 (Low, test, testing) - the differential generator held two of `HTTPField`'s stored properties constant, so the differential and its reference agreed on those axes for the wrong reason, which is how HT-8 survived a sweep that certified the row. Closed.

Changed: Tests/HTTPTypesTests/ProbeHTTPFieldsTests.swift (`randomFields` now varies `indexingStrategy` over all four values and draws byte storage as well as String storage), .jeffy/probes/httpfields/README.md, BACKLOG.md (HT-9 deleted), PLAN.md (one Lesson).

Checkpoint: cd58486b8622e8e9d48b7637eff7f3e14b641321

Verification: the finding's premise was established before the fix, not asserted. With `Sources/HTTPTypes/HTTPFields.swift` restored from 045920fcdd65a7b39980d77960c0893a29073217, the pre-HT-8 file, the suite reported `equalityAgreesWithTheReferenceOnShortLists`, `equalityAgreesWithTheReferenceOnLongLists` and `hashHoldsUnderReordering` all green and only `equalityComparesWholeFields` red - the differential was blind, exactly as filed.

With the generator widened and the same file restored, the named check reddens: run in isolation through `--filter 'ProbeHTTPFields/equalityAgreesWithTheReferenceOnShortLists'` it reported `((left == right) → true) == (self.referenceEqual(lhs, rhs) → false)` in 8 of 8 runs. That is the filed Acceptance, and both of its clauses hold.

The rate was quoted from the isolated run for a reason worth recording. Run whole against that same file, the suite reddened in 4 of 5 runs, and the fifth looked like a miss until its output was read: it died with `Fatal error: Duplicate elements of type 'HTTPFields' were found in a Set.`, the standard library detecting the contract violation while `equalityComparesWholeFields` inserted into a `Set`, which killed the process before the differential ran. A run that dies before a check reports is indistinguishable, in a pass count, from a run where that check found nothing. `swift test` exits non-zero either way, so the battery is red in 5 of 5, but the detection rate of this particular check is only measurable with the process to itself.

No shipped source changed this iteration; the restores were copied aside first and diffed back byte-identical each time. Battery ownership: the diff touches no path any battery's `paths` file declares - `.jeffy/probes/httpfields/paths` names `Sources/HTTPTypes/HTTPFields.swift`, which this iteration did not modify - but the battery itself changed, so it was run: 13/13, unchanged in count since the widening added no check. Its four Surface inventory rows are re-recorded at this checkpoint because the instrument behind them is now stronger than the one they named. Verify gate through quiet-verify.sh - green (0s, `✔ Test run with 107 tests passed after 0.186 seconds.`). check-claims.sh: 16 checked, 0 mismatched, 0 errored, 0 skipped. `swift-format lint --recursive --strict Sources Tests Benchmarks` reports the same 2 warnings, both HT-6's.

Both instruments over this row are kept rather than one replacing the other. They fail differently: the differential finds what nobody thought to name, at a rate that depends on what the generator draws, and the known-answer check names two inputs and fails on them every run. HT-8 is the case for the second; HT-9 is the case for the first.

The ledger now holds two open tasks, below the three that would normally call for a replenishing partial audit. No partial audit is run: HT-3 and HT-6 are queued for the next two iterations, so the run is not idle, and the closing full audit that follows them is the same replenishment in its strongest form. Running a partial one first would spend an iteration on a weaker version of a step already scheduled.

Learnings: a probabilistic check's detection rate has to be measured with that check alone in the process, because a sibling check can trap first and a dead run reads exactly like a clean one. And widening a generator is worth more than it looks: the same edit that closed this finding also put `hashHoldsUnderReordering` on the two axes it was blind to, without a line being written for it.

Next: HT-3, then HT-6, then the closing full audit and the evaluator gate.

## iter 5/10 | 72d2e6e2-174500 | 2026-09-03 | HT-3 | done

Task: HT-3 (Low, docs, documentation) - the two non-failable URL entry points trap on a schemeless URL and neither doc comment said so. Closed.

Changed: Sources/HTTPTypes/HTTPRequest+URL.swift (doc comments only; no code), BACKLOG.md (HT-3 deleted).

Checkpoint: 0a0aed71d5f8cc61f5d9518d4af5d7cf3c11921c

Verification: the trap was reproduced before being documented, each shape in its own process so a trap would be visible rather than swallowed. `HTTPRequest(method: .get, url: URL(string: "example.com/path")!)`, the same URL assigned through the `url` setter, and a path-only `URL(string: "/just/a/path")` each died with `HTTPTypes/HTTPRequest+URL.swift:179: Fatal error: Schemeless URL is not supported` and exit 132. Both URL strings used as examples in the new prose were checked rather than assumed: each reports `scheme: nil`.

The filed Acceptance is an observable fact about both doc comments, so it was checked by extracting each declaration's own comment block and testing it, rather than by reading: the `url` property and `init(method:url:headerFields:)` each now state that the URL must carry a scheme, that a schemeless one is a programmer error, and the message it traps with. That check caught a real defect in the first draft - the property's precondition wrapped `Schemeless URL is not supported` across a line break, so the message was not greppable in the file that contains it - and the line was reflowed.

Only the FoundationEssentials branch of `httpRequestComponents` is compiled on this host, which is the one the reproduction executed and the one the trap's line number names. The CoreFoundation branch is not claimed as executed; its guard is a `precondition` rather than a `fatalError` and carries the same message literal, which is why the doc comments quote the message without naming a platform.

The getter's own behaviour is documented in the same edit, because a precondition on the setter sitting above a property whose getter returns nil for three separate reasons reads as a contradiction otherwise. Nothing about the getter changed; the three nil cases were read off the existing branches - a CONNECT without an extended connect protocol, an OPTIONS whose path is "*", and a missing pseudo header field.

Contract preserved: no code changed, so no behaviour did. This is why the finding is class docs and Low: the code already does what a caller who reads it would expect, and what was missing was the reader's warning. Battery ownership: `.jeffy/probes/httprequest-url/paths` declares this file, so that battery ran - `HTTPTypesURLTests|ProbeHTTPRequestURL: 6/6 checks passed` - and its Surface inventory row is re-recorded at this checkpoint. Verify gate through quiet-verify.sh - green (1s, `✔ Test run with 107 tests passed after 0.164 seconds.`). check-claims.sh: 16 checked, 0 mismatched, 0 errored, 0 skipped. `swift-format lint --recursive --strict Sources Tests Benchmarks` reports the same 2 warnings, both HT-6's.

Learnings: an acceptance about documentation is still an executable check - extracting the declaration's comment block and testing it found a wrapped string that reading the diff had passed over twice.

Next: HT-6, the last open task, then the closing full audit and the evaluator gate.

## iter 6/10 | 72d2e6e2-174500 | 2026-09-03 | HT-6 | done

Task: HT-6 (Low, dev-tooling, code quality) - two `DontRepeatTypeInStaticProperties` warnings from the linter the repository's own soundness workflow runs. Closed. The ledger is now empty.

Changed: Sources/HTTPTypes/HTTPFields.swift (`maxPendingFieldsBeforeIndexing` renamed to `maxPendingBeforeIndexing`, `minFieldsToIndexByName` to `minRemainingToIndexByName`, with the two doc comments and the algorithm comment that name them updated in the same edit), BACKLOG.md (HT-6 deleted).

Checkpoint: eaec28ca1b1eca004c95b109e70ce523e4444b9c

Verification: the filed Acceptance is `swift-format lint --recursive --strict Sources Tests Benchmarks 2>&1 | grep -c warning` printing 0, and it does; before the rename the same command printed 2, naming both properties. Both are `private static var` used only inside their own file, so the rename is contained: `grep -rn 'maxPendingFieldsBeforeIndexing\|minFieldsToIndexByName' . --include='*.swift' --include='*.md'` now returns nothing outside the journal, and the three plus four occurrences it did return were all rewritten together, the algorithm comment above `==` included.

The rename was preferred to the two alternatives - a suppression comment, or turning the rule off in `.swift-format` - because both of those answer a linter rather than the code, and the repository configured this rule deliberately. The names keep their meaning without the type's own word in them, and the doc comments still say "fields" where the sentence needs it.

Claims this diff could invalidate were re-run rather than reasoned about. The Settled classes enumeration over this same file still returns its five lines - the three whole-field comparisons in `==`, the one in `isEqualByNameIndex`, the `combine(field)` in `hash(into:)` - and still no line naming `.name`, `.value`, `.rawValue` or `.indexingStrategy`, so that standing claim holds across the rename. Battery ownership: `.jeffy/probes/httpfields/paths` declares this file, so that battery ran - 13/13 - and its four Surface inventory rows are re-recorded at this checkpoint. Verify gate through quiet-verify.sh - green (1s, `✔ Test run with 107 tests passed after 0.174 seconds.`). check-claims.sh: 16 checked, 0 mismatched, 0 errored, 0 skipped.

Contract preserved: the two properties are private and their values are unchanged at 32 and 64, so the adaptive handoff from the lock-step walk to `isEqualByNameIndex` happens at exactly the same points. Nothing public moved and no behaviour did.

Learnings: none new; this was a contained rename with its references enumerated first.

Next: the ledger is empty and no full audit has been recorded this run, so iteration 7 is the closing full audit. The evaluator gate does not run early here - the rule that brings it forward requires a clean full audit already on this run's record, and there is none yet. On a clean audit, the gate and, if its verdict and the closing conditions allow, the declaration follow in iteration 8.

## iter 7/10 | 72d2e6e2-174500 | 2026-09-03 | AUDIT | audit

Task: The closing full audit. Rescore every applicable dimension against the rubric and the Operating envelope with fresh evidence, re-run every standing claim, and decide whether this run may reach a declaration.

Changed: JOURNAL.md and PLAN.md only. No file outside the state files changed, no BACKLOG.md item changed state and no Surface inventory row changed state; this is an AUDIT that files nothing, which the stall rule exempts, and the previous primary entry is HT-6 done, so no pair forms.

Checkpoint: 55405f77d17c49b38f411a4d9cbaf873e6570733

Verification: Verify gate through quiet-verify.sh - green (1s, `✔ Test run with 107 tests passed after 0.153 seconds.`), and Verify count reads 107, the total the wrapper's green line reports. check-claims.sh over all eleven batteries and both Stated counts rows: 16 checked, 0 mismatched, 0 errored, 0 skipped. `swift-format lint --recursive --strict Sources Tests Benchmarks` reports 0 warnings.

Standing claims were re-derived rather than re-read. The Surface inventory was walked mechanically - every row's recorded commit against its battery's declared paths through `git diff --name-only` - and reports 30 rows, none unswept, none stale, one `[~]`: the Benchmarks package, still unreachable here because package-benchmark's jemalloc module will not build on this host. The Settled classes enumeration returns its five lines and no projection comparison. The envelope's own derivation, `grep -rnE 'FileManager|ProcessInfo|CommandLine|getenv\(|NIOSocket' Sources/ --include='*.swift'`, returns nothing. The Environment fingerprint's derivation was re-run: the only `#if` in the test tree selects between FoundationEssentials and FoundationNetworking implementations, `grep -rn 'withKnownIssue\|\.disabled' Tests/ --include='*.swift'` returns nothing, and `git ls-files '*/Package.swift'` still returns the two separate manifests the fingerprint names as outside the command. The Oracle class still describes what the command grades. PLAN.md names no finding ID as carried or blocked. The one Declined Derivation, HT-10's, was re-run in full and its bands hold: the allocation-free candidate measured 0.9x to 1.6x and the int-keyed variant 1.0x to 1.1x against the shipped hash, with the pre-HT-1 baseline 1.2x to 1.8x faster, all inside the ranges the Declined line states.

Fresh evidence was driven rather than re-read, and aimed at properties nothing in this project pins. `HTTPFields.==` was driven as an equivalence relation over 400 generated values: reflexivity on each, symmetry on every ordered pair, and transitivity across 124974 triples reached through 2588 equal pairs, with equal values required to hash equally throughout. Transitivity is the property no battery checks and the one a "same fields per name in order, interleaved freely across names" comparison could plausibly lose; it holds. The two branches of `==` were driven against each other on 20000 independent pairs, 402 of them equal, and agreed on every one. `HTTPRequest` was driven over 5000 pairs to confirm it inherits the fixed equality and hash rather than shadowing them. The two name initializers were driven differentially over 40000 generated strings from a charset mixing tchars, the colon, the slash and the space: 20693 were accepted by both and agreed on `canonicalName` and on `==` every time, 873 were accepted only by `init(parsed:)` and every one of those was a leading colon followed by a token, and on every acceptance `canonicalName` was lowercased and `rawName` was the input unchanged. The adversarial name-decoding surface was driven with six payloads, each in its own process so a trap would show as a signal: an uppercased pseudo name, an embedded colon, an empty name and a spaced name were each rejected with a DecodingError, `Content-Type` and `:method` were accepted with `canonicalName` lowercased and a round trip comparing equal, and none trapped.

Scores. All 30 rows are accounted for: 29 swept with batteries, 1 disclosed `[~]`. Nothing below claims that row.
- correctness: None. The equivalence relation, both equality branches, the inheritance into `HTTPRequest`, and the agreement of the two name initializers were all driven this iteration on the current code.
- security: None on the swept surface. The library performs no I/O. Every unsafe construct in the shipped sources was re-enumerated and totals 16 across four files, and this run added none - `git diff` from the run's base commit over `Sources/` contains no added line matching that enumeration. The four temporary allocations in the value path were driven last run and their code is unchanged since.
- error handling: None on the swept surface, on the six-payload adversarial pass above.
- architecture, developer experience: None on the swept surface.
- testing: None on the swept surface. Four suites were run in isolation rather than only as part of the whole - ProbeErrorCodes 2/2, ProbeHTTPParsedFields 5/5, ProbeHTTPResponse 7/7, ProbeHTTPFieldValue 10/10 - so the score does not rest on a whole-suite run that could hide order dependence. What the command does not grade is disclosed where it belongs rather than filed as a finding: the Oracle class says it is not a conformance corpus, the Environment fingerprint names the two packages outside it, and the Benchmarks row carries its own reason.
- performance: None on the swept surface. HT-10 was measured and Declined this run, and its derivation was re-run above.
- documentation: None. HT-3 closed: both URL entry points now state that the URL must carry a scheme, that a schemeless one is a programmer error, and the message it traps with, checked by extracting each declaration's comment block rather than by reading.
- dependency hygiene: None. `grep -c '\.package(' Package.swift` returns 0; the three `dependencies:` occurrences are intra-package target edges.
- code quality: None. HT-6 closed and the linter the repository's own soundness workflow runs reports 0 warnings.
- observability, UX and accessibility: not applicable, unchanged from the first audit.

Zero High and zero Medium in-envelope. Closeout has begun: this run stops auditing from here, and finishes with the evaluator gate and, if its verdict and the closing conditions allow, the declaration. The ledger is empty, so no Low is carried into that declaration and none has to be listed in it.

Learnings: an audit whose map is already swept earns its evidence by driving properties the batteries do not pin, not by re-driving the ones they do - transitivity and the agreement of two sibling initializers were both cheap, both new, and both things no committed check would have caught if they had broken.

Next: the evaluator gate in iteration 8, invocation 1 of this run, with the standing claims already brought current in this iteration.

## iter 8/10 | 72d2e6e2-174500 | 2026-09-03 | EVALUATOR | converged

Task: The evaluator gate, invocation 1 of this run, and the declaration. Standing claims brought current in this iteration first, then one fresh-context sub-agent invoked. Verdict PASS.

Changed: .jeffy/evaluator/72d2e6e2-174500-1.md (the gate's artifact), BACKLOG.md (the HT-10 Declined line restated, and the Converged line appended).

Checkpoint: 4181d60256510e7f7e102f518e59c0c55e15fe69

Verification: standing claims were brought current in this iteration before the invocation, not carried from the audit. check-claims.sh over all eleven batteries and both Stated counts rows reports 16 checked, 0 mismatched, 0 errored, 0 skipped. The Surface inventory was re-walked mechanically - each row's recorded commit against its battery's declared paths through `git diff --name-only` - and reports 30 rows, none unswept, none stale, one `[~]`. The Settled classes enumeration returns its five identity and hash sites and no projection comparison. PLAN.md names no finding ID as carried or blocked. The Oracle class and Environment fingerprint were re-read and their derivations re-run: no `withKnownIssue`, no disabled test, the same two separate packages outside the command. Verify count reads 107, the total the wrapper's green line reports. Verify gate through quiet-verify.sh - green (1s, `✔ Test run with 107 tests passed after 0.178 seconds.`), re-run after the gate's own file restores with `git status --porcelain Sources/ Tests/` empty.

Bringing the claims current caught one that had gone stale, which is the reason the rule puts this before the invocation rather than after. Re-running HT-10's Declined Derivation in this iteration returned 2.1x at the smallest list size, where the Declined line stated a 1.2x to 2.0x band for the same ratio. A stated extent its own command contradicts reopens the entry, so the line was restated before the gate ever saw it: the ratios move run to run, the smallest sizes are hundreds of nanoseconds and the noisiest, and what the line now states is the conclusion those runs keep returning - no correct alternative is materially faster, and the pre-HT-1 baseline that is faster is the order-sensitive hash HT-1 removed and so not an alternative at all. Had that gone to the gate unfixed it would have spent the invocation the declaration needed.

Evaluator: PASS - HT-8's filed reproduction fails on the base commit and passes at HEAD, its Acceptance re-executed at 30 of 30 runs, and 27000 generated pairs found 6732 equality violations on the base tree and none at HEAD.

The gate did its own work rather than taking the run's account: it built the reproduction as a scratch package against a worktree of the base commit and against HEAD separately, re-executed every closed task's acceptance check, reproduced both batteries' recorded "Observed failing" states and restored the files byte-identically, forced the by-name-index fallback with 200 names and 100-to-300-field lists, and drove 3000 order-preserving reinterleavings each followed by an `indexingStrategy` flip. It also checked the argument behind the lock-step branch's early `return false`, that both pending arrays being empty makes the two fields the same per-name occurrence, rather than accepting the comment that asserts it.

Two observations the gate recorded, neither a REJECT reason and neither fixed here, because a fix after a PASS invalidates the PASS and spends an invocation the declaration needs. Both go to the run report and to the next run's ledger. First: iteration 1's entry says the pre-fix reproduction reported `Set` count 1, and on the base commit it reports 2 as often as not - the hash there already combined whole fields, so the Set clause alone does not discriminate, and it is the `==` clauses that do. The Acceptance as a whole discriminates, which is what the gate confirmed; the entry recorded one observed run of a clause that is nondeterministic by construction, since a broken Hashable's Set behaviour is exactly what HT-8's original filing had already seen vary across eight runs. Second: HT-5's fix makes `HTTPParsedFields` accept `:Method` as `:method` where it previously threw `invalidPseudoName`. That widening was recorded in iteration 2's entry as a consequence of canonicalising; the envelope classifies that surface machine-generated and the gate judged it the safer direction.

Closing conditions, each checked rather than assumed: the full fresh-evidence audit in iteration 7 scored zero High and zero Medium in-envelope; the Surface inventory lists no unswept row; Now, Next and Later hold no open task at all, so no Low is carried and none needs listing; every path changed since that clean audit is a loop state file - JOURNAL.md, BACKLOG.md, `.jeffy/metrics/` and the gate's own artifact - with no product code touched, which `git diff --name-only` against the audit checkpoint confirms; the Verify command is green this iteration; and the evaluator returned PASS with its artifact written, carrying no machine-absolute path and committed by this iteration's checkpoint.

Learnings: the rule that standing claims are brought current in the same iteration as the invocation is not bookkeeping - a numeric band this run had itself written three iterations earlier had already drifted out of what its own command returns, and re-running it before the gate rather than after is the difference between restating a line and losing the declaration.

Next: none. The run is converged and the Converged line names this iteration's checkpoint.
