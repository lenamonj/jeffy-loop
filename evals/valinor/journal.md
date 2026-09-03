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

## iter 1/10 | 2619d411-230739 | 2026-09-02 | AUDIT | audit

Task: First audit. Fill the Operating envelope, Surface inventory, Verify command block and Stated counts table in PLAN.md, enumerate the artifact-producing channels, probe every inventory row breadth-first, and seed BACKLOG.md.

Changed: PLAN.md (envelope surfaces, 25 inventory rows, verify block, counts table), BACKLOG.md (V-001, V-002, V-003), .gitignore (loop state file), JOURNAL.md.

Checkpoint: 06f6190d2217b40769d2386a8d04a261f12ce3b3

Verification: Verify command established as `XDEBUG_MODE=off php vendor/bin/phpunit`; through the installed quiet-verify.sh it reported `verify: green (2s, oracle=unit and integration tests..., Tests: 2872, Assertions: 10861, Skipped: 3.)`. check-claims.sh: `claims: 1 checked, 0 mismatched, 0 errored, 0 skipped`.

Artifact channels, enumerated by command rather than recall. `ls` for packaging manifests found composer.json and no package.json, MANIFEST.in, pyproject.toml, Cargo.toml, gemspec, nuspec or root Dockerfile; `grep -ln 'actions/upload-artifact|docker build|release|publish' .github/workflows/*.yml` found only docs.yml. Two channels result. (1) The Composer dist archive, which Packagist serves from the GitHub tag tarball filtered by .gitattributes export-ignore: `git check-attr export-ignore` reports `unspecified` for PLAN.md, BACKLOG.md, JOURNAL.md, JOURNAL-archive.md and .jeffy/, and `git archive` over the staged tree listed PLAN.md, BACKLOG.md and JOURNAL.md at the archive root. That channel fails the check and is filed as V-002. (2) The docs site, built by docs.yml with mkdocs/mike from docs/ alone and pushed to the Valinor-Documentation repository; the state files live at the project root, outside docs/, so they cannot reach it. Verified.

Audit scores, from a breadth-first shallow probe of every inventory row. correctness Medium, error handling Medium, dependency hygiene Medium, documentation Low. No dimension is scored None and no dimension is scored clean: not one inventory row is swept, because the probes run this iteration were exploratory rather than kept known-answer batteries, and a None over 25 unswept rows would be silence presented as cleanliness. architecture, code quality, security, testing, performance, developer experience and observability are therefore unscored pending sweeps. UX and accessibility do not apply - the project is a dependency-free PHP library with no user-facing surface.

What the shallow probe exercised, and what it found. Scalar mapping and casting in both strict and allowScalarValueCasting modes, including int/float/bool/string coercion, integer ranges, positive-int, non-empty-string and numeric-string, PHP_INT_MAX overflow and 1e400: behaviour matched the documented strict-by-default contract in every case. Shaped arrays, lists, unions, intersections, callables and 60-deep nesting. Object mapping with promoted readonly constructors, backed enums, nullable sub-objects and DateTimeInterface. JsonSource against invalid, scalar, null, 600-deep, duplicate-key and invalid-UTF-8 payloads; FileSource against a known and an unhandled extension. FileSystemCache written, then corrupted with a syntax error and then overwritten with an attacker-shaped payload - the mapper recovered and returned correct results in both cases rather than executing the tampered entry. The normalizer over scalars, arrays, INF, NAN and a circular reference, plus every one of the 13 JSON options in ACCEPTABLE_JSON_OPTIONS driven on and off against an input designed to reveal it: 12 changed the output, and the 13th, JSON_UNESCAPED_LINE_TERMINATORS, is inert alone by PHP's own documented rule and does change the output when combined with JSON_UNESCAPED_UNICODE, which was confirmed - so no documented parameter is dead. Converters, key converters, interface inference, cache warmup and clearing, the arguments mapper, filterExceptions, the attribute configurators MapArrayToList, MapFromJson and MapFromKey, and the normalizer configurators IgnoreOnNormalization, NormalizeKeyTo and NormalizeKeysToSnakeCase. The type parser over well-formed and malformed signatures, which is where V-001 surfaced.

Filed: V-001 (Medium) `array{` and `list{` parse as the empty sealed shape instead of raising ShapedArrayClosingBracketMissing - reproduced, and the acceptance check was run against the unfixed code and observed to exit 1. V-002 (Medium) loop state files reach the Composer dist archive - reproduced via git archive over the staged tree. V-003 (Low) the withOptions() flag list in the JSON normalization docs omits JSON_FORCE_OBJECT - `grep -c` returns 0 today.

Learnings: The type parser factory is `CuyZ\Valinor\Type\Parser\Factory\TypeParserFactory` with `buildDefaultTypeParser()`; there is no LexingTypeParserFactory. `IgnoreOnNormalization` is inert unless the same instance is registered through `configureWith()`, and the placeholder object it leaves behind is the documented and tested fallback, not a defect - a probe that omits the registration will misread it as one. The 25 inventory rows were checked to partition src exactly: their find expressions return 487 paths, and `find src -name '*.php'` returns 487, with `comm -13` between them empty.

Next: V-001, the only open runtime Medium, then V-002; then begin sweeping the 25 inventory rows with kept known-answer batteries under .jeffy/probes/.

## iter 2/10 | 2619d411-230739 | 2026-09-02 | SWEEP | done

Task: Sweep Surface inventory rows. The queue puts unswept rows above every open Medium, and the run state opened with 25 unswept rows against 9 remaining iterations, so this iteration built the kept battery harness and swept every row it could properly evidence.

Changed: .jeffy/probes/harness.php (new shared runner), .jeffy/probes/{mapper-entry-points,normalizer-entry-points,mapper-configurators,mapper-sources,normalizer-configurators}/ (checks.php, paths, claims, README.md each), PLAN.md (five inventory rows flipped), JOURNAL.md. No file under src/ or tests/ was changed; `git status --porcelain src/` was empty at the checkpoint.

Checkpoint: 7559c0d24e634f0651c211a552e22b770672fcb1

Verification: quiet-verify.sh reported `verify: green (2s, oracle=unit and integration tests..., Tests: 2872, Assertions: 10861, Skipped: 3.)`. check-claims.sh over the whole tree: `claims: 6 checked, 0 mismatched, 0 errored, 0 skipped`, one row per battery plus PLAN.md's skipped-yaml-tests row.

Rows swept, each by an executed known-answer battery rather than a liveness probe. mapper-entry-points, 49 checks. normalizer-entry-points, 36 checks. mapper-configurators, 30 checks. mapper-sources, 30 checks. normalizer-configurators, 18 checks. Every check states a known answer - an exact mapped value or an exact error message - and each battery declares its paths, records its measurement as the value of an `expect` line in its claims file, and carries a README naming what it pins.

Every battery was observed failing before it was accepted, each under a distinct source mutation that leaves the build intact, applied to a copy and reverted immediately: MapperBuilder::allowCastingToInteger with its settings assignment dropped; JsonNormalizer::__construct discarding the caller's options; MapExplodedStringToList always splitting on a comma while still storing its documented separator; PathMapping assigning its source straight through; NormalizeKeysToSnakeCase writing values back under the original key after computing the new one. Each mutation reddened its own battery and nothing else, and each battery returned to green on revert. One of those attempts silently failed to apply - a regex that matched nothing - and the battery passed under what was believed to be a mutation; the second attempt used an exact string replacement and reddened. An instrument that has never been seen to fail reads exactly like an instrument that passed, and so does one whose mutation never landed.

The documented-parameter rule was applied per battery rather than as a formality. allowCastingToBoolean's two token-list parameters are driven at a second value each, asserting both that the custom token is accepted and that the default token it displaces is now rejected. registerConverter's priority is driven at two orderings of the same converter pair. All thirteen accepted JSON encoding options are driven off and on against inputs chosen to reveal them, with JSON_UNESCAPED_LINE_TERMINATORS driven in the pair PHP's own rule requires. MapExplodedStringToList's separator is driven at a comma and a semicolon with a cross check. PathMapping's map is driven at four values plus the empty-map identity. No documented parameter in these five rows was found inert.

Nothing new was filed. Three of this iteration's own expectations were wrong and were corrected to the observed answer after reading the implementation: MapKeysToSnakeCase rewrites input keys toward snake_case so the target carries the snake_case name, the normalizer key configurators rewrite object property names and leave a plain array's keys as data, and NormalizeDateTimeFormat takes a format() string in which a leading `!` is not a directive and is emitted literally. Each was a probe error, not a defect, and each is now pinned as a known answer so the next reader does not repeat it.

Learnings: A battery mutation must be applied by exact string replacement and its effect confirmed in the same command, because a mutation that silently fails to apply produces a green battery that looks like evidence. Valinor's error messages differ between the single-error form, which names the path inline, and the multi-error form, which reports a total; a known-answer check has to pin whichever the input actually produces. The normalizer's key configurators act on object property names only, so a check that feeds them a plain array pins pass-through, not conversion.

Next: continue sweeping. Twenty rows remain unswept, with the type system, the definition repositories, the caches and the compiler nodes still unmapped; the two open Mediums, V-001 and V-002, sit below them in the queue.

## iter 3/10 | 2619d411-230739 | 2026-09-02 | SWEEP | done

Task: Continue sweeping Surface inventory rows. The run state opened with 20 unswept rows against 8 remaining iterations, so the map is still the top of the queue; this iteration took the three type-system rows.

Changed: .jeffy/probes/{type-implementations,type-lexer-tokens,type-parser-core}/ (checks.php, paths, claims, README.md each), .jeffy/probes/type-implementations/integer-subtype-enumeration.php (new, V-004's derivation and reproduction), BACKLOG.md (V-004 filed), PLAN.md (three inventory rows flipped), JOURNAL.md. No file under src/ or tests/ was changed; `git status --porcelain src/` was empty at the checkpoint.

Checkpoint: 93393450cda677fcc5536488fdc02c944d3f46db

Verification: quiet-verify.sh reported `verify: green (2s, oracle=unit and integration tests..., Tests: 2872, Assertions: 10861, Skipped: 3.)`. check-claims.sh over the whole tree: `claims: 9 checked, 0 mismatched, 0 errored, 0 skipped`.

Rows swept. type-implementations, 66 checks. type-lexer-tokens, 63 checks. type-parser-core, 25 checks. Each battery was observed failing under its own source mutation, applied by exact string replacement to a copy and reverted immediately: NonEmptyStringType::accepts reduced to is_string; the stream-done guard removed from ArrayToken's element loop; CachedParser::parse delegating instead of memoising. Each reddened its own battery and nothing else.

The type batteries are built around the shape of this surface rather than around calls. accepts() and matches() are predicates, so each type family is driven over one fixed twelve-value list and the answer rendered as a bit string: a predicate collapsed to always-true reddens on the negative side of the list, one collapsed to always-false reddens on the positive side, and a liveness probe passes over both. The parser never throws on a malformed signature - it returns an UnresolvableType carrying the reason - so the lexer battery states which of the two outcomes each signature produces and the exact text of it, on 63 signatures split between well-formed round-trips and named refusals. The factory's four builders differ only in which specifications they compose, so each is driven on inputs the others answer differently, both of the native-versus-advanced differences at once, alongside the syntax they share.

Filed V-004 (Medium, runtime, correctness): the integer types decide the subtype relation by exact bound equality rather than interval containment. `IntegerRangeType::matches` compares min and max for equality against another range and has no branch for the bounded-sign types, so containment is denied on pairs where it holds. The user-visible consequence is reached through registerConverter, which consumes matches() to decide whether a converter applies: a converter declared `@return int<2, 5>` for a property typed `int<1, 10>` is silently skipped and the mapper returns the unconverted value with no error, while the same converter applies for `int` and for `positive-int`. Both the gap set and the consequence are enumerated by .jeffy/probes/type-implementations/integer-subtype-enumeration.php, which derives containment from each type's interval rather than from a typed list and exits 1 against the unfixed code; that was confirmed before filing.

Three behaviours that read like defects were investigated to a conclusion and pinned rather than filed. A float type does not accept() an int value, because accepts() is exactness while the mapper widens int to float on its own path - `map('float', 1)` returns 1.0. A `string` array-key type does accept int keys, because PHP canonicalises a numeric string key to an int key, so `{"5":1}` decoded from JSON arrives as `[5 => 1]` and no other behaviour could accept it. UnresolvableType::accepts throws a bare LogicException with an empty message, which is an internal invariant guard: an unparseable type in a property docblock is reported before accepts() is reached, with the message naming the parameter and the symbol, so no user meets the LogicException. A fourth, the parser accepting a generic argument outside its declared template bound, is enforced one stage later by the class definition with a named error, and that is pinned instead.

One of this iteration's own claims was wrong before it was checked. The first pass at the integer matrix hand-listed the containment pairs and counted `positive-int -> int<1, 10>` among the gaps, which is not containment at all - [1, PHP_INT_MAX] is not inside [1, 10] - and matches() is right to deny it. The enumeration was rewritten to compute containment from each type's interval, and the derived count is what the filing rests on.

Learnings: Valinor's parser reports a malformed signature by returning UnresolvableType, not by throwing, so a probe that only catches exceptions will read every malformed input as a success. A containment or subtype claim must be derived from the operands rather than hand-listed, because a hand-listed expectation is a second thing that can be wrong and it fails toward over-reporting.

Next: continue sweeping. Seventeen rows remain unswept, including the mapper object binding, the tree builders, the definition repositories, the caches and the compiler nodes; three open Mediums - V-001, V-004, V-002 - sit below the map in the queue.

## iter 4/10 | 2619d411-230739 | 2026-09-02 | SWEEP | done

Task: Continue sweeping Surface inventory rows. Seventeen rows were unswept against seven remaining iterations, so the map is still the top of the queue; this iteration took the HTTP binding row and the three error-message rows, which together hold the largest remaining block of files.

Changed: .jeffy/probes/message-coverage.php (new coverage instrument), .jeffy/probes/{mapper-http,type-parser-errors-a,type-parser-errors-b,mapper-errors}/ (checks.php, paths, claims, README.md each), BACKLOG.md (V-005 filed), PLAN.md (four inventory rows flipped), JOURNAL.md. No file under src/ or tests/ was changed; `git status --porcelain src/` was empty at the checkpoint.

Checkpoint: a99a5101e407eb38d1001fe3cf2315d64b9c0d6a

Verification: quiet-verify.sh reported `verify: green (2s, oracle=unit and integration tests..., Tests: 2872, Assertions: 10861, Skipped: 3.)`. check-claims.sh over the whole tree: `claims: 16 checked, 0 mismatched, 0 errored, 0 skipped`.

Rows swept. mapper-http, 22 checks. type-parser-errors-a, 50 checks. type-parser-errors-b, 33 checks. mapper-errors, 27 checks. Each battery was observed failing under its own source mutation, applied by exact string replacement and reverted: the FromRoute branch in HttpRequestNodeBuilder guarded by false; ReversedValuesForIntegerRange reworded; MissingGenerics reworded; CannotResolveObjectType shortened.

Three of these rows are error-message classes, where the message is the whole of what a user meets, so the message text is the assertion. That raises a coverage question a per-check battery cannot answer on its own, and this iteration built the instrument that does: message-coverage.php reads a battery's own paths file, extracts the longest static run from each class's parent::__construct message - a fragment no sibling produces - and reports every class the battery does not pin. Its answer is a second claims line per battery, so a class added to a row without a check moves the number instead of riding along under a stale checkbox. It earned its place immediately: it found eleven unpinned classes in the first parser-error row and one, EnumHasNoCase, in the second, all of which are now driven. The instrument was itself confirmed by mutation - rewording a class's message both reddens its battery and raises the instrument's count - so it is reading the code rather than agreeing with the battery.

Coverage is complete on both parser-error rows and is not complete on mapper-errors: seven of its forty-two classes were not reachable from the public API inside this iteration, and the row is swept to that bound and no further. The seven are named in the battery README and the residual is the recorded claim value, seven rather than zero, so the gap is a number the next run reads rather than a sentence it has to trust.

The HTTP row is scoped adversarial by the Operating envelope, so its source-scoping checks are differential: each attribute is driven once with its value in the right source and once with the same key present only in a different source, which must fail. Binding a key that merely exists somewhere would pass a positive check and redden here. The documented behaviour of omitting an attribute is driven on both halves of the sentence that states it, and the documented promise that route and query strings cast without any casting setting is pinned alongside its negative side.

Filed V-005 (Low, test, testing): HttpRequest::fromPsr coalesces a null getParsedBody() to an empty array, which PSR-7 explicitly permits, but tests/Fake/Mapper/Source/FakePsrRequest declares that return type as object|array, so no test in the tree can reach the branch - and neither can this battery, which says so rather than certifying it. Scored Low because the class is test: the runtime behaviour is correct and no user of the shipped product meets the gap.

Two of this iteration's own instruments were wrong before they were right. The coverage extractor first took only the static prefix of a message, which reported two pinned classes as uncovered because their messages open with an interpolation; it now takes the longest static run. It then reported two more as uncovered because a battery writes an apostrophe escaped and how many backslashes precede it depends on how the literal was quoted; it now drops backslashes from both sides of the comparison rather than guessing the nesting. Both were found by disbelieving the instrument's own output against a class whose message was visibly present in the battery.

Learnings: An expectation written as a double-quoted PHP literal interpolates any `$name` inside it, so a message quoting a parameter must escape the dollar or the check silently compares against a mangled string. A coverage instrument that searches source text has to normalise escaping on both sides, because the same message is spelled differently in the class that raises it and in the battery that pins it.

Next: continue sweeping. Thirteen rows remain unswept - the mapper object binding, tree builders and message formatters, the normalizer transformers and formatters, the type model core, the definition repositories and cache compilers, the caches, the compiler nodes and the utilities. Three open Mediums - V-001, V-004, V-002 - and two Lows sit below the map in the queue.

## iter 5/10 | 2619d411-230739 | 2026-09-02 | SWEEP | done

Task: Continue sweeping Surface inventory rows. Thirteen rows were unswept against six remaining iterations, so the map is still the top of the queue; this iteration took the two compiler rows and the cache row.

Changed: .jeffy/probes/class-coverage.php (new), .jeffy/probes/{compiler-native-nodes,compiler-core,cache}/ (checks.php, paths, claims, README.md each), .jeffy/probes/cache/clear-wedge-reproduction.php (new, V-006's reproduction), BACKLOG.md (V-006 filed), PLAN.md (three inventory rows flipped), JOURNAL.md. No file under src/ or tests/ was changed; `git status --porcelain src/` was empty at the checkpoint.

Checkpoint: 1346fb7ce5b3c58d1427f5fcb4605b67c2f11c3a

Verification: quiet-verify.sh reported `verify: green (2s, oracle=unit and integration tests..., Tests: 2872, Assertions: 10861, Skipped: 3.)`. check-claims.sh over the whole tree: `claims: 22 checked, 0 mismatched, 0 errored, 0 skipped`.

Rows swept. compiler-native-nodes, 58 checks. compiler-core, 23 checks. cache, 26 checks. Each battery was observed failing under its own source mutation, applied by exact string replacement and reverted: GreaterOrEqualsToNode emitting `>` instead of `>=` - a node that still compiles and still parses; Compiler::code prepending the indent without also applying it after each newline; RuntimeCache::get dropping its memoisation so every read reaches the delegate.

The compiler nodes generate the PHP the mapper and normalizer then execute, so the emitted text is the contract and every node's exact source is pinned, with the seven comparison nodes driven on one operand pair so a node emitting a sibling's operator reddens. Nine further checks evaluate the emitted expression and assert the value it computes, which is what separates a node that reads correctly from one that means what it says. TypeAcceptNode is asserted the same way twice over, and one check evaluates the compiled type check and the original type's own accepts() on the same values and asserts the pair agrees, which is the property the compiled mapper rests on.

Filed V-006 (Low, runtime, error handling): FileSystemCache::clear() deletes a file only when its first line still carries the library's generated-file header, so an entry whose content was damaged is skipped by the very call meant to recover from it. The directory stays wedged and every later map throws CorruptedCompiledPhpCacheFile, including through the documented MapperBuilder::clearCache() remedy, until the directory is deleted by hand. Reproduced in a fresh process by .jeffy/probes/cache/clear-wedge-reproduction.php, which exits non-zero against the unfixed code. Scored Low rather than at the rubric's suggestion, and the rationale is the envelope: PLAN.md classifies the cache directory as state-at-rest and puts external corruption of it out of envelope at Low at most, and the library's own write path is atomic - set() writes a temp file and renames it - so it cannot produce such a file itself.

A claim this run made in iteration 1 was falsified here and is corrected rather than left standing. That entry said the mapper recovered from a corrupted and from a tampered FileSystemCache entry and returned correct results. It does not: it throws CorruptedCompiledPhpCacheFile in both cases. The iteration 1 probe damaged one file out of three and the mapper did not need that one, so the observation was real and the sentence generalising from it was not. The correct behaviour is the loud refusal, which is what the cache battery now pins, and the defect near it is V-006, which the same probe would have found had it damaged every entry.

The class-coverage instrument added here is deliberately weaker than the message coverage used on the error rows: it asks whether each class in a row is named by its battery, not whether its output is pinned, and each README says which of the two its row rests on. Both compiler rows measure zero; the cache row measures two, CompiledPhpCacheFileNotWritten and TypeFilesWatcher, neither reachable without making a directory unwritable mid-run or driving a timed file change, and the row is swept to that stated bound.

Two further behaviours were pinned rather than filed. FileSystemCache refuses unparseable, truncated and substituted entries loudly and by name rather than executing them, which is the right answer for all three. warmupCacheFor validates its signatures only when a cache is configured; without one it is a no-op and validates nothing, which is consistent with there being nothing to warm.

Learnings: RuntimeCache is a memoising decorator and takes a delegate, so a probe constructing it bare fails on arity rather than on behaviour. A claims line whose command exits non-zero is read by check-claims as an instrument error, so a reproduction that must fail against unfixed code belongs in the backlog acceptance check and never in a claims file. A corruption probe must damage every entry the operation needs, because damaging one of several proves only that the others were enough.

Next: continue sweeping. Ten rows remain unswept - the mapper object binding, tree builders and message formatters, the normalizer transformers and formatters, the type model core, the definition model, reflection repositories and cache compilers, and the utilities. Three open Mediums and three Lows sit below the map in the queue.

## iter 6/10 | 2619d411-230739 | 2026-09-02 | SWEEP | done

Task: Continue sweeping Surface inventory rows. Ten rows were unswept against five remaining iterations, so the map is still the top of the queue; this iteration took the utility helpers and the mapper message layer.

Changed: .jeffy/probes/{utility,mapper-messages}/ (checks.php, paths, claims, README.md each), PLAN.md (two inventory rows flipped), JOURNAL.md. No file under src/ or tests/ was changed; `git status --porcelain src/` was empty at the checkpoint. No BACKLOG.md item changed state this iteration and nothing new was filed, but two Surface inventory rows did, so this is not a stall.

Checkpoint: ec8453b604354d9f3e332c9f195d86a21cb323d9

Verification: quiet-verify.sh reported `verify: green (2s, oracle=unit and integration tests..., Tests: 2872, Assertions: 10861, Skipped: 3.)`. check-claims.sh over the whole tree: `claims: 26 checked, 0 mismatched, 0 errored, 0 skipped`.

Rows swept. utility, 56 checks. mapper-messages, 39 checks. Both observed failing under their own source mutation, applied by exact string replacement and reverted: Polyfill::array_any returning true unconditionally; MessageMapFormatter::format returning its argument unchanged. Class coverage over both rows measures zero missing.

The utility row is pure functions over small inputs, the one shape where a liveness probe is worthless because every one of them returns a value and "it returned something" holds even when the value is wrong. Each of the four array polyfills is driven on an empty array, on input the predicate matches and on input it does not; the array_any mutation reddens two of those three and leaves the third passing, which is the reason all three are driven rather than one.

The message row turns on a distinction that is now pinned explicitly: body() returns the template with its placeholders intact, toString() renders it against the node, and a formatter matches on the template while a user reads the rendering. Both are asserted, along with originalMessage() still returning the template after a formatter has rewritten the body. Every formatter is driven twice, on a message it matches and on one it does not, because a formatter that rewrote everything and one that rewrote the right thing are indistinguishable when only the matching case is checked. The fixtures are real mapping failures read off a MappingError rather than messages assembled by hand.

Five of this iteration's own expectations were wrong and were corrected to the observed answer after reading the implementation, none of them a defect. StringCutter::cut takes a byte length and never splits a multibyte character, so four bytes of a two-byte character yields two characters. StringFormatter uses ICU placeholders, so the parameter key is the bare name and not the braced form. ValueDumper renders an object as object(Class) and a backed enum as its backing value, which is what the source data carried. MessageBuilder::from takes the throwable's own message and the default code whatever interfaces the throwable carries. UserlandError is a final class with a static from() that wraps a plain throwable and passes an ErrorMessage straight through, not the marker interface the name suggested.

Recorded as a coverage bound rather than certified: StringFormatter dispatches on whether ext-intl is loaded, and PLAN.md's Environment fingerprint records it as loaded here, so the regex fallback formatWithRegex is unreachable on this host and no check covers it. The ICU path is the one pinned, and the utility battery README says so.

Learnings: A message layer that separates template from rendering needs both pinned, because a check that reads only one of them passes over a formatter matching on the wrong string. Reading the implementation before writing an expectation costs less than the round trip that corrects it, and five of this iteration's corrections were avoidable that way.

Next: continue sweeping. Eight rows remain unswept - the mapper object binding, tree builders, the normalizer transformers and formatters, the type model core, the definition model, reflection repositories and cache compilers. Three open Mediums and three Lows sit below the map in the queue; the run will not reach them all inside this budget.

## iter 7/10 | 2619d411-230739 | 2026-09-02 | SWEEP | done

Task: Continue sweeping Surface inventory rows. Eight rows were unswept against four remaining iterations, so the map is still the top of the queue; this iteration took the normalizer formatter row and the type model core.

Changed: .jeffy/probes/{normalizer-formatters,type-model-core}/ (checks.php, paths, claims, README.md each), PLAN.md (two inventory rows flipped), JOURNAL.md. No file under src/ or tests/ was changed; `git status --porcelain src/` was empty at the checkpoint. No BACKLOG.md item changed state and nothing new was filed, but two Surface inventory rows did change state, so this is not a stall.

Checkpoint: 839c4a82e1b02c31061dc842673ed44145210cca

Verification: quiet-verify.sh reported `verify: green (4s, oracle=unit and integration tests..., Tests: 2872, Assertions: 10861, Skipped: 3.)`. check-claims.sh over the whole tree: `claims: 30 checked, 0 mismatched, 0 errored, 0 skipped`.

Rows swept. normalizer-formatters, 24 checks. type-model-core, 33 checks. Both observed failing under their own source mutation, applied by exact string replacement and reverted: TransformerHasNoParameter's message reworded, which reddens the battery and raises the message-coverage count together; ListType dropping DumpableType from its implements list.

The type model core is the row that most needed a shape other than method calls. Every file in it except the dumper is an interface, and the mapper dispatches on them - instanceof ScalarType and instanceof CompositeType select code paths - so a type that quietly stopped implementing one would still answer every call it had before and pass any battery built from calls. Each concrete type is therefore rendered as the sorted list of core interfaces it satisfies, and the mutation that proves the instrument is exactly that: ListType stops implementing DumpableType, no method changes, no call breaks, and the row reddens. Three further checks assert the partition the dispatch relies on rather than only the memberships.

The dumper is internal and needs a container, so it is driven where a user meets it, in the type descriptions inside mapping error messages, with TypeDumpContext driven directly for accumulation, immutability and object retention.

The normalizer formatter row pins the JSON formatter's own shape decisions rather than describing them: a generator whose first key is zero is written as a list, one whose first key is not is written as an object, and an empty generator is an empty list. That is the documented trade-off in the formatter's own comment, and pinning it is what would catch it changing.

Recorded as a coverage bound rather than certified: message coverage over the normalizer row is one short. CannotFormatInvalidTypeToJson is raised inside JsonFormatter for a value that is neither scalar, null nor iterable, and every such value is refused one stage earlier by the transformer with TypeUnhandledByNormalizer, which this battery does pin. The row is swept to that bound and the battery README names it.

Five expectations about the interface memberships were wrong and were corrected against the code, none of them a defect: an integer range is not dumpable while an array and a list are, a class type is also an ObjectWithGenericType, and an interface type is not a ClassType. Getting those wrong is the ordinary cost of asserting a property that no method call reveals, which is also why it is worth asserting.

Learnings: A row made of interfaces is checked by rendering the interface set each implementation satisfies, because an interface a class stops implementing breaks no call and passes every call-based battery. A message-coverage gap is worth reading before chasing: the uncovered class here is unreachable because a sibling check fires first, which is a fact about the code rather than a hole in the battery.

Next: six rows remain unswept - the mapper object binding and tree builders, the normalizer transformers, the definition model, the reflection repositories and the cache compilers. Three open Mediums and three Lows sit below the map; the run has three iterations left and will not reach them.

## iter 8/10 | 2619d411-230739 | 2026-09-02 | SWEEP | done

Task: Continue sweeping Surface inventory rows. Six rows were unswept against three remaining iterations, so the map is still the top of the queue; this iteration took the two definition rows.

Changed: .jeffy/probes/{definition-model,definition-reflection}/ (checks.php, paths, claims, README.md each), PLAN.md (two inventory rows flipped), JOURNAL.md. No file under src/ or tests/ was changed; `git status --porcelain src/` was empty at the checkpoint. No BACKLOG.md item changed state and nothing new was filed, but two Surface inventory rows did change state, so this is not a stall.

Checkpoint: 55d6b618c613ae5cf3621f858df0809a4ac5ae72

Verification: quiet-verify.sh reported `verify: green (2s, oracle=unit and integration tests..., Tests: 2872, Assertions: 10861, Skipped: 3.)`. check-claims.sh over the whole tree: `claims: 34 checked, 0 mismatched, 0 errored, 0 skipped`.

Rows swept. definition-reflection, 25 checks. definition-model, 35 checks. Both observed failing under their own source mutation, applied by exact string replacement and reverted: ReflectionPropertyDefinitionBuilder taking the native type as the property type and never consulting the resolved one, which reddens the docblock-narrowing and generic-template checks; Attributes::filter returning $this, a filter that runs, returns the right type and filters nothing, which reddens three checks including the one asserting the original collection is undisturbed.

A definition is what the mapper compiles against, so the reflection row states the shape reflection produced rather than that a definition came back: which properties and methods were collected, the resolved type of each, the optionality and default of every constructor parameter, and which attributes survived the allow-list. The method-collection filter is pinned rather than assumed - only map, mapKey, normalize, normalizeKey, anything marked #[Constructor] and the constructor itself are collected, with an ordinary public method on the same class asserted absent - and the allow-list is driven at two values so a repository ignoring it would redden.

The first mutation attempt on the reflection row did not redden anything: it inserted an assignment into a branch the fixtures never reach, so the battery passed under what was believed to be a mutation. The second attempt replaced the resolved type at its source and reddened two checks. This is the second time in this run that a mutation silently failed to apply, and the rule already in Lessons - apply by exact string replacement and confirm the effect in the same command - is what caught it both times.

Class coverage over these two rows is seven and twelve rather than zero, and the numbers are recorded as they stand. They are the definition value objects, the repository interfaces, the three definition builders and the nine type resolvers: collaborators every check here drives but none names. Naming them in a comment would satisfy the instrument's string search without adding any evidence, so it was not done. The number still moves when a class is added to a row, which is what the instrument is for, and it does not pretend those classes are individually pinned.

One expectation was wrong for a reason worth recording: two calls to a repository return equal definitions rather than the identical instance, so an identity check across two calls fails while the same lookup inside one collection holds. The memoisation that matters is the compiled cache one layer up, which the cache battery already pins.

Learnings: A collection is checked at all three outcomes of its filter - narrowing, emptying, keeping everything - plus the assertion that the original is undisturbed, because a filter returning its receiver passes any check that only counts the result of a narrowing call. Identity checks across two repository calls test memoisation that is not there; assert equality across calls and identity only within one returned collection.

Next: four rows remain unswept - the mapper object binding, the mapper tree builders, the normalizer transformers and the definition cache compilers. Two iterations remain, so the map will not clear inside this budget and the three open Mediums and three Lows will carry to the next run.

## iter 9/10 | 2619d411-230739 | 2026-09-02 | SWEEP | done

Task: Continue sweeping Surface inventory rows. Four rows were unswept against two remaining iterations; this iteration took the definition cache compilers and the mapper object binding, and the sweep of the second surfaced a High.

Changed: .jeffy/probes/{definition-cache-compilers,mapper-object-binding}/ (checks.php, paths, claims, README.md each), .jeffy/probes/mapper-object-binding/constructor-return-type-reproduction.php (new, V-007's reproduction), BACKLOG.md (V-007 filed in Now), PLAN.md (two inventory rows flipped), JOURNAL.md. No file under src/ or tests/ was changed; `git status --porcelain src/` was empty at the checkpoint.

Checkpoint: fcfc5920beecc5ecb1d99d771819a9cf202492b3

Verification: quiet-verify.sh reported `verify: green (2s, oracle=unit and integration tests..., Tests: 2872, Assertions: 10861, Skipped: 3.)`. check-claims.sh over the whole tree: `claims: 38 checked, 0 mismatched, 0 errored, 0 skipped`.

Rows swept. definition-cache-compilers, 21 checks. mapper-object-binding, 23 checks. Both observed failing under their own source mutation, applied by exact string replacement and reverted: PropertyDefinitionCompiler compiling the native type where the resolved type belongs, so non-empty-string and positive-int come back as string and int through source that still compiles and still evaluates; ReflectionObjectBuilder::buildObject discarding its arguments before assigning them, so a class with defaults still returns the right class with the wrong values.

The cache compilers row is about a round trip, so the checks compile a definition, evaluate the source back and compare fields against the original rather than asking whether compilation succeeded. A compiler emitting valid-but-different source fails those and passes any did-it-compile check. One check asserts a round-tripped type still accepts and rejects the right values, so a type that survived as a string but not as a predicate would redden.

The object binding row turns on which builder wins, which is invisible in the returned object unless the builders disagree, so every check either drives a class only one builder can handle or makes the builders produce different values - a registered constructor multiplying by ten, a marked static constructor doubling, a native constructor doing neither.

Filed V-007 (High, runtime, correctness): a closure registered through MapperBuilder::registerConstructor can have its return type resolved to a class name that does not exist, built by concatenating an unrelated return type appearing elsewhere in the same source file with the real one. The mapper then raises PHP's own ReflectionException naming a class the caller never wrote - `Class "boolJeffyReturnTypePoint" does not exist` - instead of the ordinary mapping error. Deleting the unrelated `: bool` from the file makes the identical call behave correctly, which is what establishes that the resolution depends on text the caller's file happens to contain rather than on the constructor itself. Scored High under the rubric line for a crash on realistic in-envelope input: the input is ordinary hand-authored application wiring using a documented API, the constructor is correct, and the failure is an uncaught reflection error rather than a mapping message.

The finding was found by accident and then narrowed by hand, and the narrowing is honestly incomplete. It first appeared as a failing check inside the battery, and roughly a dozen reconstructions of the surrounding shape - a preceding closure with a bool return type, a named function, an arrow function, the word in a comment, a use clause, the closure inside an array literal - did not reproduce it in isolation. What does reproduce, reliably and in a fresh process, is the file now committed as constructor-return-type-reproduction.php, which uses only the public API and whose only unusual feature is a closure carrying `: bool` earlier in the same file. The reproduction is real and re-runnable; the minimal trigger is not yet known, and the filing says so rather than inventing one.

Class coverage over these two rows is nine and twenty-five rather than zero, recorded as it stands for the same reason as the earlier rows: those classes are collaborators every check drives but none names, and naming them in a comment would satisfy the instrument without adding evidence.

Learnings: A defect found by a probe's own failing check deserves the same narrowing discipline as one found deliberately, and when the narrowing does not converge the filing says which reproduction is known to work rather than describing a trigger that was never confirmed. A battery whose subject is a choice between implementations must make those implementations disagree; if they all return the same value the battery certifies nothing about the choice.

Next: two rows remain unswept - the mapper tree builders and the normalizer transformers - and one iteration remains, which the closing rule reserves for a WRAPUP entry and a handoff. The ledger carries one High, three Mediums and three Lows to the next run.

## iter 10/10 | 2619d411-230739 | 2026-09-02 | WRAPUP | done

Task: Final iteration. The closing rule reserves it for a WRAPUP over starting work that cannot finish, and its one exception does not apply here: the ledger is not at the severity floor, so the closing full audit is not the right use of this iteration. Tidy the ledger, remove an orphan artefact, and write the handoff.

Changed: .jeffy/probes/normalizer-transformers/ removed (an orphan directory holding a paths file and no battery, created in iteration 9 for a row that was never swept), JOURNAL.md. No file under src/ or tests/ was changed at any point in this run; `git diff --name-only 03a6f34 HEAD -- src tests` is empty.

Checkpoint: 9aba16735a238a9294aa55976eafb072c591db28

Verification: quiet-verify.sh reported `verify: green (2s, oracle=unit and integration tests..., Tests: 2872, Assertions: 10861, Skipped: 3.)`. check-claims.sh over the whole tree: `claims: 38 checked, 0 mismatched, 0 errored, 0 skipped`.

Ledger state at close, already in the order the Method prescribes and left unchanged: Now holds V-007 (High, runtime); Next holds V-001 and V-004 (Medium, runtime) then V-002 (Medium, build-ci); Later holds V-006 (Low, runtime), V-005 (Low, test) and V-003 (Low, docs). Nothing is blocked, nothing is under Proposed, no class is Settled and nothing is Declined.

Not converged, and the reason is not budget alone. Two Surface inventory rows remain unswept - Mapper tree builders and Normalizer transformers and compiler - so the Definition of done cannot be met whatever the ledger says, and one High and three Mediums are open besides. The evaluator gate was never invoked, which is correct: the gate is on the Definition of done path only and none of its preconditions held at any point in this run.

Handoff for the next run, in the order the queue will take them. V-007 is the open High and outranks everything: its reproduction is committed at .jeffy/probes/mapper-object-binding/constructor-return-type-reproduction.php and exits non-zero today, and its trigger is narrowed only as far as this run got - the reproduction is reliable in a fresh process, but a dozen reconstructions of the surrounding shape did not reproduce it in isolation, so the first task is to narrow it before fixing it. Then the two unswept rows, which the queue puts above the Mediums. Then V-001, V-004 and V-002, each with a runnable acceptance check already written. Three batteries pin defective behaviour deliberately - type-lexer-tokens for V-001, type-implementations for V-004, cache for V-006, mapper-object-binding for V-007 - and each says so in its README; fixing any of those findings reddens its battery, and the battery is to be updated in the same iteration as the fix.

Three coverage bounds are recorded rather than hidden, and the next run should read them before trusting a row: mapper-errors leaves seven of its forty-two message classes unpinned, normalizer-formatters leaves one, and the utility row does not cover the ext-intl-free StringFormatter fallback because that path is unreachable on this host. Six batteries record a class-coverage number above zero - definition-model at seven, definition-cache-compilers at nine, definition-reflection at twelve, mapper-object-binding at twenty-five, cache at two - and in every case those are collaborators the checks drive but do not name.

Learnings: A run whose map is not yet complete cannot converge however clean the ledger looks, so the sweep arithmetic in the run state is the number to plan against from the first iteration rather than the ledger depth. An orphan battery directory left by an iteration that started a row and did not finish it is invisible to check-claims, which skips directories with no claims file, so it survives to confuse the next run; the iteration that abandons a row removes the directory it made.

Next: nothing in this run. The next run starts with V-007.

## iter 1/10 | 0821d882-001741 | 2026-09-02 | V-007 | done

Task: V-007, the open High and the top of the queue. A closure registered with `MapperBuilder::registerConstructor` had its return type resolved to a class name that does not exist, and the mapper raised PHP's own `ReflectionException` naming a class the caller never wrote. The previous run filed it honestly incomplete: the reproduction was reliable but a dozen reconstructions had not isolated the trigger, so this iteration narrowed it before fixing it.

Changed: src/Utility/Reflection/TokenParser.php (the fix), tests/Unit/Utility/Reflection/PhpParserTest.php and two new fixtures under tests/Unit/Utility/Reflection/Fixtures/, .jeffy/probes/utility/ (checks.php, claims, README.md), .jeffy/probes/mapper-object-binding/ (checks.php, README.md), PLAN.md (Verify count, two Lessons), BACKLOG.md (V-007 closed, class settled, V-008 filed), JOURNAL.md.

Checkpoint: 5fc455688f7be7a291b47bfa635083ff70b13084

Verification: quiet-verify.sh reported `verify: green (3s, oracle=unit and integration tests..., Tests: 2874, Assertions: 10863, Skipped: 3.)`. The count rose from 2872 by the two new PhpParserTest data sets, and `Verify count` in PLAN.md was moved to 2874 in the same iteration. check-claims.sh over the whole tree after the battery updates. `composer check`'s wider gate: phpstan, both StaticAnalysis phpstan configs, both psalm configs, php-cs-fixer and rector all exit 0; `check-todo` exits 1 and is filed as V-008.

Root cause, narrowed. `TokenParser::parseUseStatements()` called `parseUseStatement()` on every `T_USE` token, and PHP spells three constructs `use`: an import statement, a closure's variable capture, and a trait import inside a class-like body. Only the first imports anything. `parseUseStatement()` is a scanner that consumes tokens until `;` or `,`, so on the other two it swallowed the surrounding code: a `{` set `groupRoot`, every `T_STRING` overwrote the pending class name, and the `,` or `;` committed the pair. `PhpParser::getFileContent()` truncates the file at the reflected symbol's start line, so a closure being reflected sees every earlier closure capture in its own file. The reproduction's `boolJeffyReturnTypePoint` is exactly `groupRoot` from the earlier closure's `: bool` return type concatenated with the `JeffyReturnTypePoint` its body mentions, and `AliasSpecification` then resolved the registered constructor's return type through that alias to a class that does not exist.

What the previous run's dozen reconstructions missed is that the trigger is not the `: bool` alone. It needs the earlier closure to carry a capture clause, a return type before its `{`, and a mention of the target class name followed by a comma or a semicolon. Removing the `: bool` fixed the reproduction not because the return type mattered but because it was `groupRoot`; without it the alias resolved to the class's own name and the lookup was a no-op. That is why reconstructions varying only the closure shape kept coming back clean.

Fix. `parseUseStatements()` now tracks brace depth with a small stack recording whether each open brace opened a class-like body, and treats a `T_USE` as an import only when it is not directly inside such a body and is not followed by `(`. The two discriminators are needed separately: a closure capture at file top level sits at depth zero, and a trait import is token-identical to a real import. `Foo::class` emits `T_CLASS` too, so a class-like keyword opens a body only when the previous significant token is not `T_DOUBLE_COLON`. Braced namespaces still import, because a namespace brace is pushed as not-class-like and the check asks only whether the innermost open brace is a class body.

Class settled rather than instance patched. The enumeration is over PHP's grammar rather than over source sites, because the defect is in a parser and its sites are the forms it can meet. `.jeffy/probes/utility/checks.php` now drives 21 cases: eight that must import - the seven import forms plus a braced namespace - and ten that must import nothing, a closure capture in three variants and a trait import in seven, including inside a trait, an enum and an anonymous class. Two more put a real import before a non-import form, which is the shape the defect took, and one drives `Foo::class`. Against the pre-fix TokenParser the battery reports 65/77: all ten non-import cases redden plus the two mixed ones, twelve in all, and the eight import cases pass on both trees as the regression guard. Recorded in that battery's README as its second observed failure.

Two regression tests went into the project's own suite, since a check that lives only in a battery runs only when someone remembers. Both were run against the unfixed TokenParser and both failed there, with the other eighteen PhpParserTest cases still passing; the fixed file was copied aside for that measurement and restored, never checked out.

The `mapper-object-binding` battery deliberately pinned the defect, as the previous run's handoff warned, so this fix reddened it and it was updated in the same iteration. Its check now pins the ordinary mapping error, and it still reddens against a reverted TokenParser, so it is a guard rather than a comment. What keeps it honest is that its own file carries the `use ($strict): bool` capture at the check that asserts source key order does not change the result - the very closure that produced `boolJeffyBindPoint`.

Learnings: A test fixture whose whole point is a syntactic shape has to survive the project's own rewriters: Rector's ClosureToArrowFunctionRector deletes a single-return closure's `use` clause outright, and PHPStan rejects a body written out of constants as dead code, so such a fixture needs two statements and a condition derived from a parameter. And a fix that lands in shipped code must be followed by check-claims across the whole tree, not only by the batteries whose paths file matches the diff: the battery that pinned this defect declares paths under src/Mapper, which this diff never touched, and only the tree-wide run found it.

Next: the ledger is at zero High. The queue puts the two unswept Surface inventory rows - Mapper tree builders, Normalizer transformers and compiler - above the three open Mediums, so the next iteration sweeps.

## iter 2/10 | 0821d882-001741 | 2026-09-02 | SWEEP | done

Task: The ledger holds no open High, so the queue puts the Surface inventory above the three open Mediums. Two rows were unswept - Mapper tree builders and Normalizer transformers and compiler - and both were swept this iteration, which clears the map.

Changed: .jeffy/probes/mapper-tree-builders/ and .jeffy/probes/normalizer-transformers/ (checks.php, paths, claims, README.md each, all new), PLAN.md (two inventory rows flipped), JOURNAL.md. No file under src/ or tests/ was changed; `git status --porcelain src tests` was empty at the checkpoint, which matters more than usual this iteration because four source mutations were applied and reverted to measure the batteries.

Checkpoint: 73f26479c6f11967e6fdf494b0cbc534aa76bbd6

Verification: quiet-verify.sh reported `verify: green (4s, oracle=unit and integration tests..., Tests: 2874, Assertions: 10863, Skipped: 3.)`. check-claims.sh over the whole tree: `claims: 42 checked, 0 mismatched, 0 errored, 0 skipped`, up from 38 by this iteration's four new claim lines.

Rows swept. mapper-tree-builders, 59 checks. normalizer-transformers, 39 checks.

The tree-builders row is a dispatch: `TypeNodeBuilder` is a `match` over the type's class handing the shell to one of nine builders, and which one it picked is invisible in a value that came back. Asserting that `list<int>` maps to `[1,2,3]` would pass just as well with the array builder holding the list arm. Every type family is therefore driven twice, once on input it must accept and once on input it must refuse, and the refusal message is what names the builder: `Invalid sequential key` belongs to the list builder alone, `Unexpected key` to the shaped-array builder, `does not match any of` to the union builder. Repointing the list arm at the array builder reddens four checks; that mutation is recorded in the battery's README with a second one on the HTTP source isolation that reddens exactly one.

The normalizer row is two implementations of one contract rather than a dispatch, so it needed a different instrument. `RecursiveTransformer` walks the value; `CompiledTransformer` emits PHP source, evaluates it and runs that, and the library picks between them on whether a cache is registered. Every check runs the same value through both and states the answer once: the helper returns the outcome they agree on, or a `DIVERGED` string naming each side. Agreement alone would be satisfied by both being wrong the same way, so the expected value is still the normalized form written out. Both layers were confirmed load-bearing by mutating `EnumFormatter` (the compiled side moves) and then the equivalent line in `RecursiveTransformer` (the reference side moves): the same two checks redden either way and the failure text names whichever implementation drifted.

Two exploration errors are worth recording because both nearly became findings. Key converters are registered with `registerKeyConverter`, not `registerConverter`; passing a one-parameter string closure to the latter registers a value converter for `string`, which never applies to an `array{a: int}`, so the probe read as a documented parameter having no effect. And the HTTP source attributes are `FromRoute`, `FromQuery` and `FromBody`; there is no `Route` or `Query` class, so `#[Route]` was an unknown attribute the builder never matched, and a target that appeared to accept a route value from the query string was only a no-op attribute. In both cases the library was correct and the probe was wrong. Checking the documented API before filing is what kept them out of the ledger.

`HttpRequestNodeBuilder` is scoped to this row rather than to `Mapper HTTP request binding`, whose paths file covers only the four classes under src/Mapper/Http.

Class coverage is zero over the tree-builders row and three over the normalizer row. The three are `TransformerDefinition`, `TransformerDefinitionBuilder` and `TransformerRootNode`, the compiler's own plumbing that every compiled check drives and none names; recorded as it stands rather than satisfied with a comment.

Learnings: A row holding two implementations of one contract is swept by running both and comparing, with the shared answer still written out as a literal - the differential catches one side drifting, the literal catches both drifting together, and reporting which side moved is what makes the failure diagnosable. And a probe that appears to have found an inert parameter or a broken attribute checks the documented API first: two of this iteration's exploration steps used a method and an attribute that do not exist, and each produced behaviour that reads exactly like a defect.

Next: the map is clear - PLAN.md lists no unswept row. The queue now falls to the three open Mediums, V-001, V-004 and V-002, and the next iteration takes V-001.

## iter 3/10 | 0821d882-001741 | 2026-09-02 | V-001 | done

Task: V-001, the top of the queue now that the map is clear. An unterminated shaped-array signature carrying no elements - `array{` or `list{` - resolved to the empty sealed shape instead of raising `ShapedArrayClosingBracketMissing`, while every other truncation was refused. The iteration also corrected three battery READMEs the Stop hook flagged, which is this run's own error rather than a ledger task.

Changed: src/Type/Parser/Lexer/Token/ArrayToken.php (the fix), tests/Unit/Type/Parser/LexingParserTest.php (two regression tests), .jeffy/probes/type-lexer-tokens/ (checks.php, claims, README.md, and the new shaped-truncation-enumeration.php), .jeffy/probes/{utility,mapper-tree-builders,normalizer-transformers}/README.md (measurement wording), PLAN.md (Verify count), BACKLOG.md (V-001 closed, class settled, V-009 filed), JOURNAL.md.

Checkpoint: 1e41d5d677ee31a23222013badf217b4bd02f6f8

Verification: quiet-verify.sh reported `verify: green (4s, oracle=unit and integration tests..., Tests: 2876, Assertions: 10867, Skipped: 3.)`. The count rose from 2874 by the two new LexingParserTest cases, and `Verify count` in PLAN.md was moved to 2876 in the same iteration. check-claims.sh over the whole tree: `claims: 43 checked, 0 mismatched, 0 errored, 0 skipped`. The wider `composer check` gate over a src change: phpstan, both StaticAnalysis phpstan configs, both psalm configs, php-cs-fixer and rector all exit 0; `check-todo` still exits 1 and is still V-008.

Root cause. `ArrayToken::shapedType()` consumes the opening bracket and then enters `while (! $stream->done())`. Every truncation inside that loop throws, but a signature that ends immediately after the bracket never enters it at all, and the method falls through to build a shape from the zero elements it collected. The fix is the guard the sibling `arrayType()` already carries for its own opening bracket: refuse a done stream before the loop. Three lines, and the message `Missing closing curly bracket in `array{`.` comes out of the existing `signature([])` unchanged.

Class settled rather than instance patched, and the enumeration decided the shape of the fix rather than following it. Truncating twelve complete shaped signatures at every prefix holding an opening bracket gives 129 cases; against the unfixed parser exactly two resolve, `array{` and `list{`, and against the fixed one none does. That is what establishes the guard is complete rather than merely sufficient for the two reported spellings: had a third truncation been accepted, one guard would not have covered it. The enumeration is committed as a probe and its summary line is a claims value, so the class is re-checked every run instead of trusted.

The enumeration also drew a boundary this task should not cross. `iterable{` and `non-empty-array{` looked like the same defect at first, but `ArrayToken::$canBeShaped` is true only for `array` and `list`, so those spellings never reach `shapedType()`; they resolve to the native type and the parser simply ignores the tokens that follow. That is the general behaviour - `int zzz` resolves to `int`, `array{a: int}zzz` to `array{a: int}` - and a different class from the one V-001 names. Filed separately as V-009 rather than folded in.

V-009 is scored Low, below what the rubric would suggest for a silently weaker type, on three grounds recorded on its line: the Operating envelope classifies type signatures as user-error, a shaped `iterable` is documented nowhere, and strict mode - the default - refuses the resulting permissive type with `PermissiveTypeNotAllowed` rather than accepting anything. The silent case needs `allowPermissiveTypes`, which is the user opting out of strict typing.

The `type-lexer-tokens` battery deliberately pinned V-001's defect, as the previous run's handoff warned, so this fix reddened it and it was updated in the same iteration. Its two checks now pin the refusal, and two further checks assert `array{}` and `list{}` still resolve, so the fix cannot be satisfied by refusing those too.

The Stop hook flagged that three battery READMEs stated `N/M checks passed` measurements no claims line carried. All three were written by this run. The tree's existing convention, which those READMEs departed from, is to name which checks redden rather than quote a summary count, and they were rewritten that way; the counts are gone rather than backed by a new claims line, because a mutate-run-restore command in a claims file would leave the tree mutated if it died midway.

Learnings: An enumeration is worth building before the fix, not after it, because it decides how wide the fix has to be - here it proved one guard closes the whole class, and it separated two spellings that looked identical from the outside into two different classes. And a battery README names which checks a mutation reddens rather than quoting a summary count, because a count in a README is a measurement the hook requires a claims line to back.

Next: the ledger holds no High, no unswept rows, and two Mediums. The next iteration takes V-004.

## iter 4/10 | 0821d882-001741 | 2026-09-02 | V-004 | done

Task: V-004, the top of the queue. The integer types decided the subtype relation by naming which sibling types they matched, so `Type::matches()` denied pairs whose intervals are contained, and `ValueConverterNodeBuilder` consumes `matches()` to decide whether a registered converter applies, so a converter declared to return a narrower integer type than its target was silently skipped.

Changed: src/Type/IntegerType.php (two bounds methods), src/Type/Types/MatchesIntegerBounds.php (new, the shared relation), src/Type/Types/{Native,Positive,Negative,NonNegative,NonPositive}IntegerType.php and IntegerRangeType.php (hand-listed matches replaced by the trait, bounds added), src/Type/Types/IntegerValueType.php (bounds added, its own matches left alone), tests/Unit/Type/Types/IntegerRangeTypeTest.php and PositiveIntegerTypeTest.php, .jeffy/probes/type-implementations/ (checks.php, claims, README.md, integer-subtype-enumeration.php rewritten), PLAN.md (Verify count), BACKLOG.md (V-004 closed, class settled), JOURNAL.md.

Checkpoint: 3b77da679c17c3b4606d33515589d170ea34671d

Verification: quiet-verify.sh reported `verify: green (3s, oracle=unit and integration tests..., Tests: 2881, Assertions: 10877, Skipped: 3.)`, and `Verify count` in PLAN.md was moved to 2881 in the same iteration. check-claims.sh over the whole tree: `claims: 44 checked, 0 mismatched, 0 errored, 0 skipped`. The wider `composer check` gate: phpstan, both StaticAnalysis phpstan configs, both psalm configs, php-cs-fixer and rector all exit 0; `check-todo` still exits 1 and is still V-008.

The enumeration was widened before the fix and that is what found the second defect. The filed reproduction only asked whether a contained pair was denied. Rewriting it to require `matches()` to agree with containment in both directions over all 121 ordered pairs surfaced the opposite fault: `int<1, 10>` matched the literal `5`, and two more ranges matched a literal inside them. That is over-permissive rather than under-permissive, and it is the more dangerous direction, because `matches()` is what admits a converter - a converter declared to return `int<1, 10>` was eligible for a target of exactly `5` and free to return 7. A one-directional check would have fixed half the defect and certified the rest.

The contract decided both. `Type::matches()` documents subtype compatibility in its own docblock: `string` matches `non-empty-string` is false "because a string is not necessarily non-empty". By that same sentence an `int<42, 1337>` is not necessarily 42, so a range must not match a literal it contains.

Fix. `IntegerType` gains `min()` and `max()`, and one trait decides the relation as containment of one interval in another. What the change preserves: the non-integer arms are unchanged - a union still delegates to `isMatchedBy`, an array key type still delegates, and `ScalarConcreteType` and `MixedType` still match - and `IntegerValueType::matches()` is left exactly as it was, because `{v}` is contained in `B` precisely when `B` accepts `v`, which was already right for every other type. The hand-listed sibling tables are gone, which is where the defect lived: every pair nobody thought to list was silently denied.

Verify gate exception, with the differential evidence it requires. The first green run after the fix reported `Tests: 2876, Assertions: 10867, Failures: 2`, and both failures were in IntegerRangeTypeTest: `test_does_not_match_same_type_with_different_range`, asserting `int<-42, 42>` does not match the wider `int<-1337, 42>`, and `test_matches_integer_value_when_value_is_in_range`, asserting a range matches a literal inside it. Both are assertions of the pre-fix relation and both contradict the documented contract; nothing else in 2876 tests moved. They were repaired rather than reverted, and the repair strengthened the class rather than deleting it: the range-versus-range pair is now driven at wider, narrower and merely-overlapping, the range-versus-literal case is pinned false beside the literal-versus-range case that is still true, and non-negative and non-positive ranges gained the pairs the old code had no arm for. `PositiveIntegerTypeTest` gained the containment against `non-negative-int` in both directions. Five tests net.

An accident worth recording: `git stash push --keep-index -- src`, reached for to measure the pre-fix tree, left a stash behind that a later restore made redundant. It was confirmed byte-identical to the working tree by diffing `git stash show -p` against `git diff` over the same paths before being dropped. The restore path used elsewhere in this run - copy aside, `git checkout` the committed files, copy back - does not need a stash at all, and the stash only added a second copy that could have been mistaken for unmerged work.

The `type-implementations` battery deliberately pinned V-004's two denied pairs, so this fix reddened it and it was updated in the same iteration. Its two checks became eight, driving both directions of each corrected pair including the over-permissive one, and the enumeration's summary line joined its claims file so the relation is re-checked every run rather than trusted.

Learnings: A subtype or containment relation is enumerated in both directions, because a relation can be wrong by denying what holds and by allowing what does not, and only the second direction lets a converter return a value its target rejects. And a probe's expected answer is re-read against the contract before it is trusted: this reproduction asserted that a converter returning `non-negative-int` should apply to an `int<1, 10>` target, which the contract forbids, and satisfying it would have meant making the code wrong.

Next: the ledger holds no High, no unswept rows, and one Medium. The next iteration takes V-002.

## iter 5/10 | 0821d882-001741 | 2026-09-02 | V-002 | done

Task: V-002, the last open Medium. The loop's own state files carried no `export-ignore`, so the Composer dist archive that Packagist serves shipped PLAN.md, BACKLOG.md, JOURNAL.md and the whole of `.jeffy/` - 141 paths - into `vendor/cuyz/valinor/` of every project that requires the library.

Changed: .gitattributes (the fix), .jeffy/probes/dist-archive-enumeration.sh (new, the class enumeration), BACKLOG.md (V-002 closed, class settled, V-010 filed), JOURNAL.md. No file under src/ or tests/ was changed; `git status --porcelain src tests` was empty at the checkpoint.

Checkpoint: e2ffa56c09b5f6ae053ab87798fc6e170d61cdba

Verification: quiet-verify.sh reported `verify: green (2s, oracle=unit and integration tests..., Tests: 2881, Assertions: 10877, Skipped: 3.)`, unchanged from the previous checkpoint because this iteration touched no PHP. check-claims.sh over the whole tree: `claims: 44 checked, 0 mismatched, 0 errored, 0 skipped`. No battery declares `.gitattributes` in its paths file, so none was owed a re-run. The acceptance check ran against a staged tree before the checkpoint - `git add -A` then `git write-tree`, and `git archive` over that tree object - because `git archive HEAD` reads `.gitattributes` from the commit it archives, so an uncommitted fix is invisible to it and the check would have read as failing until after the commit it was meant to gate.

Channels enumerated by command rather than by recall, which is what bounds this class. The tree has three artifact-producing channels: `composer.json` published through `git archive`, the `docs.yml` release workflow, and `docs/Dockerfile`. Only the first reaches the repository root. `docs.yml` runs mkdocs with `docs_dir: pages` and deploys to a separate repository, so nothing above `docs/pages/` can reach the documentation site, and the Dockerfile copies `requirements.txt` and nothing else. No workflow uploads or publishes a tree archive of its own. So the dist archive was the whole class, and closing it closes the class.

The fix follows the file's existing shape: `/.jeffy/` joins the export-ignored directories and the three state files join the export-ignored files, with `JOURNAL-archive.md` listed too. That last one names a path the tree does not have yet - the loop creates it on rotation - which is deliberate rather than an oversight, because the leak it prevents would appear exactly when a future run rotates the journal and nobody is looking at packaging.

The archive is now LICENSE.md, README.md, SECURITY.md, composer.json, `qa/` and `src/`, 567 entries against 708 before. `qa/` shipping is correct and was checked rather than assumed: what remains after the existing ignores is `qa/PHPStan/Extension` and `qa/Psalm/Plugin`, the static-analysis extension and plugin that consumers install.

The enumeration asserts both directions. A probe that only grepped for the loop's own paths would stay green over an archive that had stopped shipping `src/`, and this project's own probe corpus already records a packaging probe sitting green over a tarball that shipped the loop's state, so the library's presence is checked as explicitly as the state's absence. Against the pre-fix HEAD it exits 1 and reports 141 violations.

A pipe hid that exit status on the first attempt. Reading the enumeration's result through `tail` reported success while the script had failed, because a pipeline carries the last command's status - the same trap the Method names for the Verify command, met here on an ordinary probe. The status was re-read by redirecting to a file.

Filed V-010, noticed while editing `.gitattributes`: it carries `/psalm.xml export-ignore` for a file the tree no longer has, the Psalm configs having moved under `tests/`, which `/tests/` already ignores. The line is inert so nothing ships wrongly, and it is scored Low by the severity ceiling as class dev-tooling. It was filed rather than folded into this diff, because deleting an unrelated dead line in a file the task happens to open is a second change wearing the first one's cover.

Learnings: A packaging fix is verified against a tree object rather than the working tree, because `git archive` reads `export-ignore` from the tree it archives and never from uncommitted files; `git add -A` followed by `git write-tree` gives a testable tree without making a commit. And a probe's exit status is read by redirecting to a file, never through a pipe to `head` or `tail`, which is a rule the Method states for the Verify command and which cost a wrong reading here on a probe.

Next: the ledger holds no High, no Medium and no unswept row, so the closing conditions are within reach. The next iteration runs the evaluator gate, which the rules put at the first empty-of-Medium point with budget left to answer a REJECT.

## iter 6/10 | 0821d882-001741 | 2026-09-02 | AUDIT | audit

Task: The closing full audit. The ledger reached the severity floor at the previous iteration and the map has been clear since iteration 2, but no full fresh-evidence audit was on this run's record, and the Definition of done requires one before any declaration. This iteration rescored every applicable dimension against the rubric and the Operating envelope, with fresh evidence rather than a reading of earlier entries.

Changed: JOURNAL.md only. No file under src/ or tests/ was changed, no BACKLOG.md item changed state, and no Surface inventory row changed state, so this iteration is a no-progress iteration by the mechanical definition; it is an AUDIT that files nothing, which the stall rule names as a ceremony entry and exempts from forming a stall pair.

Checkpoint: 266eea988374ca6c7b9535a290a5dc174c6d366d

Verification: check-claims.sh over the whole tree: `claims: 44 checked, 0 mismatched, 0 errored, 0 skipped`. All four Settled-class enumerations re-run and still hold: the `use` forms return 21, the shaped truncations report 129 driven and 0 accepted, the integer subtype relation reports 121 ordered pairs and 0 disagreements, and the dist archive reports 567 entries and 0 violations. The Declined section is empty, so there was no premise to re-derive. The full static analysis set - phpstan at three configurations, psalm at two, php-cs-fixer and rector - exits 0 at every one.

Scores. Every one of the 25 Surface inventory rows is swept, so these claim the whole mapped surface rather than a remainder.

- architecture: None. Static analysis is clean at every configuration and the run's two structural changes both removed duplication rather than adding indirection.
- code quality: None.
- security: None. `composer audit` reports no vulnerability advisories, and the lock file carries zero runtime packages - the library requires only `php`, so nothing a user installs can carry a transitive vulnerability. The shipped source has no `eval`, `extract`, `shell_exec` or process call; the one `unserialize` compiles a constructor's own default value into the cache and never sees mapped input, and the one `require` loads the library's own compiled cache, which the envelope classifies state-at-rest.
- testing: Low. V-005 is open. Four modules were run in isolation before scoring, per the Method, cheapest first: tests/Unit/Utility, tests/Unit/Type/Types, tests/Unit/Mapper/Http and tests/Integration/Mapping/Object, all green alone, so the suite hides no order dependence or leaked state among them.
- error handling: Low. V-006 and V-009 are open. The shipped source has no empty catch block, and every one of the nine suppressed calls is a filesystem or yaml operation whose result is checked on the next line and raised as a named error, except the best-effort chmod, unlink and rmdir of cache cleanup, which is the ground V-006 already covers.
- performance: None.
- documentation: Low. V-003 is open. 576 builder-chain calls across 87 documentation pages were checked against the union of the library's public methods; 14 names resolved to nothing in the library and each was read rather than counted. All fourteen are correct: illustrative application code in the reader's own domain, PSR-7 methods on a request object, or changelog and upgrade-guide entries naming an API that release removed - `enableFlexibleCasting` appears under the heading `Removed MapperBuilder::enableFlexibleCasting()`. No documentation defect beyond V-003.
- dependency hygiene: None. Zero runtime packages. `composer audit` reports one abandoned package, doctrine/annotations, which is dev-only and transitive through phpbench and cannot reach a user of the shipped product; it is not this project's dependency to replace and is recorded here rather than filed.
- developer experience: Low. V-008 and V-010 are open.
- correctness: None over the swept map.
- observability: None. A library's observable surface is its error messages, and those are pinned by the mapper-errors and normalizer-formatters batteries, whose recorded coverage bounds - seven message classes and one - are standing measurements rather than new findings.
- UX and accessibility: not applicable. The project is a library with no user-facing surface; the Goal makes those dimensions conditional on one existing.

Zero High and zero Medium in-envelope. Closeout has begun: the run stops auditing for the rest of the budget, files no replenishment, and finishes by working or declining what is already on the ledger and then converging. Six Lows are carried, all with severity on their task lines: V-003 documentation, V-005 test, V-006 error handling, V-008 dev-tooling, V-009 error handling, V-010 dev-tooling.

One check in this audit was rewritten because its first form proved nothing. The documentation pass initially reported zero missing over zero call sites - PHP's `glob` does not expand `**`, so it had examined no file at all, and a vacuous pass reads exactly like a clean one. It was rebuilt to walk the pages recursively and to extract calls from fenced blocks, and only then did it check 576 call sites and surface the fourteen names worth reading.

Learnings: A check that reports zero problems states how many sites it examined, because zero-of-zero and zero-of-576 are the same sentence and only one of them is evidence. That is the same failure the Method warns about for absence-of-badness assertions, met here in an audit's own instrument rather than in a probe.

Next: closeout. The ledger holds no High and no Medium, the map is clear, and a clean full audit is now on this run's record with four iterations left, so the next iteration runs the evaluator gate and declares in that same iteration if it returns PASS and the closing conditions still hold.

## iter 7/10 | 0821d882-001741 | 2026-09-02 | EVALUATOR | converged

Task: The evaluator gate, and the declaration in the same iteration because its verdict was PASS and every closing condition held. The standing claims were brought current before the invocation, since a REJECT spent on a claim this run had already outdated is an invocation the declaration then lacks.

Changed: BACKLOG.md (V-011 filed, Converged line appended), JOURNAL.md, and .jeffy/evaluator/0821d882-001741-1.md written by the evaluator. No file under src/ or tests/ was changed this iteration. No product code moved after the PASS.

Checkpoint: b66802b091df7a1eeeb3d1a06488082c64999d20

Verification: quiet-verify.sh reported `verify: green (3s, oracle=unit and integration tests..., Tests: 2881, Assertions: 10877, Skipped: 3.)`, equal to the `Verify count: 2881` cell in PLAN.md. check-claims.sh over the whole tree: `claims: 44 checked, 0 mismatched, 0 errored, 0 skipped`. Evaluator: PASS - invocation 1 of this run, artifact at .jeffy/evaluator/0821d882-001741-1.md, which re-ran every closed task's reproduction against the base commit and against HEAD, re-derived all four Settled-class enumerations, and re-checked all 25 inventory rows against their batteries' paths files.

Standing claims brought current in this same iteration, before the invocation. All 25 swept rows re-checked with `git diff --name-only <recorded commit> HEAD` over each battery's declared paths: none stale, none missing a paths file. All four Settled-class enumerations re-run: the `use` forms return 21, the shaped truncations 129 driven and 0 accepted, the integer subtype relation 121 ordered pairs and 0 disagreements, the dist archive 567 entries and 0 violations. The Declined section is empty, so no premise needed re-deriving. PLAN.md names no finding ID as carried or blocked, so there is no dangling reference to resolve. The Oracle class and Environment fingerprint were re-read: the fingerprint's exclusion list is derived by a command and its one exclusion, the three YamlSourceTest cases skipped for the absent ext-yaml, is the `skipped-yaml-tests` row check-claims executes and matches at 3, so no journal entry in this run claimed a test asset green that the command cannot reach.

What the gate independently established, rather than accepted. Each of the four closed findings reproduced at the base commit and passes at HEAD: V-007 raised `ReflectionException: Class "boolJeffyReturnTypePoint" does not exist` at base; V-001 accepted `array{` and `list{` at base; V-004's enumeration reported 10 disagreements at base against 0 at HEAD; V-002's base archive carried the loop's state and HEAD's does not, while `src/MapperBuilder.php` still ships. The gate then went past the filed checks on the riskiest change, the `TokenParser` rewrite, driving 33 hand-built source shapes including nowdoc, string interpolation, first-class callables, `insteadof` blocks and two namespaces in one file, and taking a key-by-key differential of `parseUseStatements` over every PHP file in src, tests and qa at base against HEAD: 121 base-side alias entries corrected or removed, and zero genuine imports dropped. That is stronger evidence for that fix than this run produced for it.

Two observations the gate recorded, neither a REJECT reason, and neither fixed here. A fix after a PASS invalidates the PASS and spends an invocation the declaration needs, so both go to the record instead. The first is that the Settled classes line for the integer relation says the seven integer types share one `matches()` when six share the trait and `IntegerValueType` keeps its own; the line's checkable part holds and only its sentence overstates, and it is filed as V-011. The second is that V-004 was carried and closed as Medium where a silently skipped converter returning an unconverted value reads as the rubric's High line, users get wrong results. The observation is fair. It was inherited at Medium from the run that filed it, and the closing audit did not re-score it because the task was already closed by then; it changed nothing material, since the finding was worked before any Low and the ordering would have been identical at either severity, and the gate said so itself. It is recorded here and in the run report rather than quietly left in the ledger's history.

Carried Lows, each with its severity on its task line, none blocking the declaration:
- V-003 (Low, docs): the `JsonNormalizer::withOptions()` flag list omits `JSON_FORCE_OBJECT`, which the code accepts - the documentation promises less than the code delivers, not more.
- V-005 (Low, test): `FakePsrRequest` types its parsed body as `object|array`, so no test can reach the null branch PSR-7 permits.
- V-006 (Low, runtime): `FileSystemCache::clear()` skips an entry whose header was damaged, so a wedged directory stays wedged; the library's own write path is atomic and cannot produce such a file, and the envelope classifies the cache directory state-at-rest.
- V-008 (Low, dev-tooling): `composer check-todo` fails on the loop's own state files, so `composer check` cannot pass while they sit in the tree.
- V-009 (Low, runtime): the parser stops at the first complete type and ignores what follows, so `iterable{a: int}` reads as a bare `iterable`; strict mode still refuses the resulting permissive type.
- V-010 (Low, dev-tooling): `.gitattributes` carries an `export-ignore` for a `psalm.xml` the tree no longer has.
- V-011 (Low, docs): the integer Settled classes line overstates how many types share the new trait.

Learnings: The gate earns its cost when it goes past the filed acceptance checks rather than re-running them - its differential of the alias map over every file in the tree tested the TokenParser fix in a way this run's own enumeration, scoped to PHP's grammar, did not. And an observation returned with a PASS is recorded, not fixed: the value of the verdict is that nothing moved after it, so the honest response to a fair observation is a ledger line and a sentence in the receipt.

Next: nothing. The run is converged and the Converged line is appended under ## Converged in BACKLOG.md.
