# Journal archive

Entries rotated out of JOURNAL.md, oldest first. Appended to, never overwritten.
## iter 1/10 | fb65c6fc-055411 | 2026-08-09 | AUDIT | audit

Task: First full audit of nikic/PHP-Parser at v5.8.0-5-gfbd47f7e. Filled the Operating envelope, the Surface inventory, and the Verify command block, then probed breadth-first before any deep dive.

Changed: PLAN.md (envelope surfaces, 26 inventory rows, Verify command with Oracle class and Environment fingerprint), BACKLOG.md (T1, T2), JOURNAL.md, .jeffy/probes/ (21 batteries, a shared harness, run-all.sh, coverage.sh), .gitignore (loop state file).

Checkpoint: ea2cb26871715efcdc084f29b1995613912393c5

Verification: `php vendor/bin/phpunit` exits 0, 1895 tests, 2766 assertions. `bash .jeffy/probes/run-all.sh` exits 1: 314 checks pass and the 2 that fail are the ones pinning T1, which is what an acceptance check strong enough to fail looks like. Out-of-suite evidence the Verify command cannot reach: `php test_old/run.php --no-progress --php-version=7.4 PHP ./data/php-src` exit 0 over 14695 files (parse, clone, format-preserving print, pretty print, reparse, compare); `php tools/vendor/bin/phpstan` exit 0, level 6, no errors; `composer audit` reports no advisories; `php grammar/rebuildParsers.php` regenerates both committed parsers byte-for-byte with a clean tree afterwards. Test modules run in isolation, all exit 0: LexerTest 10, NodeTraverserTest 23, PrettyPrinterTest 650, DifferTest 12, ConstExprEvaluatorTest 60.

Scores, claiming only the 24 swept rows of 26 (1 unswept, 1 unreachable on this host): correctness Medium (T1); architecture None; code quality None; security None - the adversarial surface is the source text handed to the parser, and 14695 real files plus 281 fixtures produced no crash, no wrong tree and no unbounded behaviour; testing None - 1895 tests, five modules confirmed green in isolation, and the fixture corpus covers the grammar densely; error handling Medium (T1 is an error-position defect); performance None - the corpus run took 48.6s wall for 14695 files at 26MB peak; documentation Low (T2); dependency hygiene None - no advisories, and PHPUnit is held at ^9 because composer.json requires PHP >= 7.4 and PHPUnit 10+ needs 8.1, which is deliberate rather than stale; developer experience None; observability not applicable, this is a library with no runtime surface of its own, and it reports through exceptions and the ErrorHandler interface instead; UX and accessibility not applicable, there is no user-facing surface beyond the CLI, which was swept.

Two rows are not swept and the scores above do not speak for them: lexer-emulators (16 files; iteration 1 exercised 6 forward features and 4 reverse keywords through the parser, which is not per-emulator coverage) and fuzzing-tooling (needs php-fuzzer.phar, not installed here). token-polyfill is marked `[~]`: its body is behind `if (\PHP_VERSION_ID >= 80000)` and is dead code on PHP 8.5.4.

Learnings: Four probe expectations were wrong before the code was, and each cost a cycle. Format-preserving printing needs the new AST to come from `NodeVisitor\CloningVisitor` over the old one; re-parsing the same source produces unrelated nodes and the printer correctly reformats everything. `PhpVersion` gates lexer emulation, not grammar acceptance, so the parser accepts nullsafe, attributes, first-class callables and property hooks on a 7.4 target by design. `Token::getEndPos()` is documented as exclusive, and `Stmt\Nop` from `maybeCreateZeroLengthNop` deliberately carries `endFilePos = startFilePos - 1` as a zero-length node - neither is an off-by-one. And an exit code read through a pipe into `head` is the pager's, which briefly made a correctly-behaved CLI look like it swallowed every failure.

Next: T1, correcting the two LexerTest assertions and the two lexerErrors.test expectations that pin the off-by-one alongside the fix.

## iter 2/10 | fb65c6fc-055411 | 2026-08-09 | T1 | done

Task: T1 (Medium, runtime, correctness) - the unterminated-comment error reported an exclusive `endFilePos` where the rest of the library uses an inclusive one. Closed: the reported range now ends on the comment's last content character, and every column it produces is a valid 1-based column.

Changed: lib/PhpParser/Lexer.php, test/PhpParser/LexerTest.php (3 expectations), test/code/parser/errorHandling/lexerErrors.test (2 expectations), .jeffy/probes/lexer-core/probe.php, .jeffy/probes/error-handling/probe.php, PLAN.md (Lessons, lexer-core row re-swept), BACKLOG.md (T1 deleted), JOURNAL.md. Also corrected the run-id in the iteration 1 heading from fb65c6fc-005651 to fb65c6fc-055411, the value `started_at` in the loop state actually carries; nothing else in that entry was touched.

Checkpoint: ba3a43c978ffbf5eeeb22dd7ad9bd9c2f6d7645e

Verification: `php vendor/bin/phpunit` exit 0, 1895 tests, 2766 assertions. `bash .jeffy/probes/run-all.sh` exit 0, 334 checks across 21 batteries. Battery ownership: the diff touches `lib/PhpParser/Lexer.php`, which only `.jeffy/probes/lexer-core/paths` claims; that battery and its sibling error-handling battery both pass. Acceptance strength proved in both directions - with the committed Lexer.php copied back over the fix, lexer-core fails 5 of 20 and error-handling fails 1 of 23; with the fix restored, both exit 0. Out-of-suite: `php test_old/run.php --no-progress --php-version=7.4 PHP ./data/php-src` exit 0 over 14695 files, and `php tools/vendor/bin/phpstan` exit 0.

Contract preserved and contract changed: `Error` keeps its attribute shape and every consumer of `startFilePos`, `startLine` and the message text is unaffected. What changes is observable and deliberate - for an unterminated comment, `endFilePos` now indexes the last character of the comment instead of the byte after it, and when the comment runs to a trailing newline both `endFilePos` and `endLine` stop at the last content character rather than the line terminator. The rationale is that `Error::toColumn()` is documented to return a 1-based column and cannot do so for a position that is itself a newline: leaving `endLine` on the following line yielded column 0, and the pre-fix exclusive value yielded column 13 on a 12-character line. Five of the six affected inputs now match an oracle derived independently from `PhpToken::tokenize`; the sixth, `<?php /*\n`, reports 1:8 (the `*`) rather than the oracle's 1:9 (the newline), which is the deliberate choice above.

The three LexerTest expectations and two lexerErrors.test expectations that changed were pinning the defect, not guarding against it. No test was weakened or removed: LexerTest still asserts the exact message for all six inputs, the fixture still asserts the full error list, and both batteries gained cases that fail against the old code.

Enumeration behind the prose claims: every `'endFilePos'` assignment and every `getEndPos()` call in `lib/` was listed, and the inclusive convention holds at all of them - `ParserAbstract` and `CommentAnnotatingVisitor` each pass `getEndPos() - 1`, the bad-character path passes a single token position, and `Lexer.php` was the only site passing the exclusive value where an inclusive one was required. The 1-based-column claim in `doc/component/Error_handling.markdown` is now driven by an executing check that provokes 12 inputs covering 4 distinct error kinds and asserts every reported line and column is at least 1; the same check confirms the documented EOF placement, one past the last byte, still holds.

Learnings: The run-id comes from `started_at` in the loop state frontmatter, not from reconstructing the time. When a fix changes reported positions, derive the expected values from the raw input rather than from the code being fixed, since the tests being updated are exactly the ones that pinned the defect. Fixing `endFilePos` alone was not enough - pairing an inclusive end position with `getEndLine()`, which counts newlines and so is exclusive, produced column 0, so the end line had to move with the end position.

Next: T2, the only remaining open task, a Low dev-tooling message defect in tools/fuzzing/target.php.

## iter 3/10 | fb65c6fc-055411 | 2026-08-09 | T2 | done

Task: T2 (Low, dev-tooling, docs) - `tools/fuzzing/target.php` named a path its autoload guard never tested. Closed: the message now names `$autoload`, the exact string passed to `file_exists()`.

Changed: tools/fuzzing/target.php, .jeffy/probes/fuzzing-tooling/probe.php (new battery), PLAN.md (fuzzing-tooling row scope), BACKLOG.md (T2 deleted), JOURNAL.md.

Checkpoint: 370b2a8feefad08814c98266cb5248f10be480e2

Verification: `php vendor/bin/phpunit` exit 0, 1895 tests, 2766 assertions. `bash .jeffy/probes/run-all.sh` exit 0, 335 checks across 22 batteries. Battery ownership: the diff touches `tools/fuzzing/target.php`, which only `.jeffy/probes/fuzzing-tooling/paths` claims, and that battery passes. Acceptance strength proved in both directions - with the committed target.php copied back over the fix the battery fails 2 of 7, naming `/tmp/.../a/b/PHP-Parser`, a directory the script never probes; with the fix restored it exits 0. The battery provokes the guard for real rather than reasoning about it: it copies the script to a directory whose `../../vendor/autoload.php` does not exist, runs it, reads the printed path back, then creates exactly that file and confirms the guard is satisfied. It also drives the second startup guard by requiring the project's own autoloader first, and confirms that path exits 1 naming php-fuzzer.phar.

The message deliberately prints the unresolved `$autoload` string, `<dir>/../../vendor/autoload.php`, rather than a canonicalised path: it is the literal value tested, so it cannot drift from the check, and `realpath()` returns false for a file that does not exist, which is precisely the case the message reports.

Correction to the record: the iteration 2 entry states 334 checks across 21 batteries. Re-running that iteration's own saved output gives 328 passed, 0 failed across 21 batteries. The pass and fail status recorded there was right and every other figure in that entry stands; only the total was miscounted. That entry is left as written, per the rule against rewriting past entries.

Learnings: When a battery asserts on a path a script prints, assert on the literal string the script tests, not on a canonicalised form - `realpath()` cannot normalise a path whose whole point is that it is absent.

Next: the ledger is now empty and this run has no clean full audit on record - the iteration 1 audit filed a Medium - so the next iteration audits rather than gating, sweeping the two remaining unswept rows first: lexer-emulators, and the rest of fuzzing-tooling.

## iter 4/10 | fb65c6fc-055411 | 2026-08-09 | AUDIT | audit

Task: Full fresh-evidence audit with an empty ledger. Swept the two rows iteration 1 left unswept, split one of them once the evidence showed why it could not be swept whole, and rescored every dimension.

Changed: PLAN.md (Surface inventory rows for the emulators, fuzzing, format-preserving and a new docs-examples row; Environment fingerprint gained the forward-emulation exclusion), BACKLOG.md (T3, T4), JOURNAL.md, .jeffy/probes/ (lexer-emulators-reverse, lexer-emulators-forward, docs-examples batteries; fuzzing-tooling and format-preserving extended; staleness.sh added; run-all.sh now prints its own total).

Checkpoint: 181d5a17b0bda6acb5d49452055e6b8eb17c7745

Verification: `php vendor/bin/phpunit` exit 0, 1895 tests, 2766 assertions, and also exit 0 under `--order-by=reverse` and `--order-by=random --random-order-seed=4242`, which is the order-dependence check the Method asks for before scoring Testing. Five further modules run in isolation, all exit 0: EmulativeTest 276, CodeParsingTest 280, NodeDumperTest 6, Builder/ClassTest 11, JsonDecoderTest 6. `bash .jeffy/probes/run-all.sh` reports 399 passed, 1 failed across 25 batteries; the single failure is the docs-examples check that is T3 and T4's acceptance check. `php test_old/run.php --no-progress --php-version=7.4 PHP ./data/php-src` exit 0 over 14695 files. `php tools/vendor/bin/phpstan` exit 0, no errors. `composer audit` reports no advisories. `bash .jeffy/probes/coverage.sh` reports 279 of 279 source files claimed by a row. `bash .jeffy/probes/staleness.sh` exit 0: all 23 rows recording a sweep commit are fresh, each checked by comparing its recorded hash against `git log -1` over the row's own path globs.

Scores, over 25 swept rows of 27, with 1 unreachable on this host and 1 that is swept-with-findings: correctness None; security None; architecture None; code quality None; testing None; error handling None; performance None; dependency hygiene None; developer experience None; documentation Medium (T3) and Low (T4); observability not applicable, a library reporting through exceptions and the ErrorHandler interface; UX and accessibility not applicable beyond the CLI, which is swept. Closeout has NOT begun: this audit filed a Medium, so the run keeps auditing when the ledger next empties.

Evidence behind the None scores, beyond the suites above. Robustness on the adversarial surface: genuinely nesting constructs - nested arrays, nested binary operations and nested if blocks - were parsed, pretty printed, dumped, json encoded and traversed at depths of 500, 2000 and 10000, with no crash and no stack exhaustion at any depth; the only failures at 10000 are memory exhaustion in NodeDumper and a timeout printing 10000 nested if blocks, both inherent to the output size rather than defects. Format-preserving printing under modification, which the php-src corpus does not cover because it modifies nothing: all 270 files under `lib/` were put through 4 mechanical AST mutations each - rename every variable, increment every integer, prepend a statement to every function body, drop the first statement of every function body - then printed format-preserving and reparsed, and all 1080 pairs reparsed to the modified AST. That sweep is now a permanent battery and runs in about ten seconds.

Two rows changed shape because the evidence demanded it. lexer-emulators could not be swept as one row: `Emulative` selects an emulator's forward `emulate()` body only when the host tokenizer predates the feature, and every emulator targets PHP 8.5 or older while this host is 8.5.4, so measuring the selection across 9 target versions returns 0 forward selections and 12 reverse ones. The reverse direction is now swept in full; the forward direction is marked unreachable on this host with that command as its evidence. This also corrects the Environment fingerprint: EmulativeTest's 276 tests pass here without executing any emulator body at all, because a target equal to the host selects none and `Emulative::tokenize` takes its no-emulation path. fuzzing-tooling turned out to be sweepable after all - `generateCorpus.php` runs here and produces 337 files - so the row iteration 3 left open is now closed with a determinism check rather than deferred.

Findings. T3 (Medium, docs): the headline NodeVisitor example in `doc/2_Usage_of_basic_components.markdown` is missing the closing parenthesis of a `str_replace` call and does not parse. T4 (Low, docs): a visitor call-order trace in `doc/component/Walking_the_AST.markdown` is fenced as php but is not PHP. Both were found by extracting all 54 php-fenced blocks from the documentation and parsing them, after teaching the extractor about the two shapes the docs legitimately use - elision markers and class-body excerpts - which is what separated 2 real defects from the 13 false positives the naive version reported. The same pass checked every namespaced PhpParser symbol the documentation names, and all of them resolve.

Learnings: A row that cannot be swept whole is a sign the row is drawn wrong, not that the work is impossible - splitting lexer-emulators by direction turned one permanently-blocked row into one swept row and one honest disclosure. Summing battery output with a hand-rolled awk over every line counts the FAIL detail lines too and inflates the total, which is how the iteration 2 entry got its number wrong; `run-all.sh` now prints its own total and future entries should quote that line rather than recomputing it.

Next: T3, the Medium documentation defect, then T4.

## iter 5/10 | fb65c6fc-055411 | 2026-08-09 | T3 | done

Task: T3 (Medium, docs, documentation) - the namespace-converter example in `doc/2_Usage_of_basic_components.markdown` did not parse. Closed, and it was broken in two ways rather than one: the missing closing parenthesis the backlog named, and, underneath it, assignment of a raw string to properties typed `Identifier` in 5.x, which made the example fatal at runtime even once it parsed.

Changed: doc/2_Usage_of_basic_components.markdown, .jeffy/probes/docs-examples/probe.php, PLAN.md (Lessons; docs-examples row re-recorded), BACKLOG.md (T3 deleted), JOURNAL.md.

Checkpoint: 11edce9052fb2d4252e1b58b1c20a771887c6f01

Verification: `php vendor/bin/phpunit` exit 0, 1895 tests, 2766 assertions. Battery ownership: the diff touches `doc/2_Usage_of_basic_components.markdown`, claimed only by `.jeffy/probes/docs-examples/paths`. That battery now reports 9 passed, 1 failed, and the single remaining failure is the `Walking_the_AST.markdown` trace listing, which is T4. Every check belonging to T3 passes: no unparseable block comes from the edited file, and the example defines, runs, flattens namespaced names with underscores, removes the namespace and use statements, resolves the aliased interface, and produces output that reparses. Acceptance strength proved by restoring the committed document over the fix, where the battery drops to 3 passed, 2 failed and reports both `Syntax error, unexpected ';', expecting ')'` and `ParseError` from the eval.

The acceptance line filed for T3 was written too coarsely - it asked for the battery to exit 0, but T3 and T4 share that battery, so its exit code cannot certify either one alone. T3 is reported here against its own checks instead, and T4 will clear the battery.

Class enumeration for the second defect: every property assignment inside every php-fenced block in `doc/`, `doc/component/` and `README.md` was listed - 8 of them - and each checked against the declared type of the property it targets. Four were the string-to-`Identifier` defect, appearing twice each because the guide shows the visitor twice, once as a partial build-up and once complete; all four are fixed. The other four assign to properties declared `string` or `array` and are correct. The class is closed with that enumeration rather than by patching the one line the backlog named.

The example now produces what the prose around it describes: `const Foo_Bar_C`, `class Foo_Bar_Baz implements Iterator`, `function Foo_Bar_qux`, with the namespace and use statements gone.

Learnings: A documentation example that parses is not an example that works - the parenthesis was the visible defect and the type error underneath it was the one that would have wasted a reader's afternoon, and only executing the example surfaced it. When a probe evals a documentation block, keep the block's own use statements: stripping them left every `instanceof Stmt\Class_` silently false, which looked exactly like a broken example and was a broken harness. Give each task its own acceptance check rather than two tasks sharing one battery's exit code.

Next: T4, the mis-fenced call-order listing in `doc/component/Walking_the_AST.markdown`, which is the last open task and the last failing battery check.

## iter 6/10 | fb65c6fc-055411 | 2026-08-09 | T4 | done

Task: T4 (Low, docs, documentation) - the visitor call-order listing in `doc/component/Walking_the_AST.markdown` was fenced as php but is a call trace, not PHP. Closed: it now carries a plain fence, matching the AST dump four lines above it in the same document.

Changed: doc/component/Walking_the_AST.markdown, PLAN.md (docs-examples row re-recorded, block count refreshed), BACKLOG.md (T4 deleted), JOURNAL.md.

Checkpoint: 68d77f0800918bc26304515ddda7ae373f6b40f4

Verification: `php .jeffy/probes/docs-examples/probe.php` exit 0, 10 passed, 0 failed, reporting 53 php blocks with 0 unparseable. Acceptance strength proved by restoring the committed document over the fix, where the battery drops to 9 passed, 1 failed naming this file and `Syntax error, unexpected T_VARIABLE`. `php vendor/bin/phpunit` exit 0, 1895 tests, 2766 assertions. `bash .jeffy/probes/run-all.sh` exit 0, TOTAL 407 passed, 0 failed across 25 batteries - the first iteration of this run in which every battery is green. Battery ownership: the diff touches `doc/component/Walking_the_AST.markdown`, claimed only by `.jeffy/probes/docs-examples/paths`.

The fence choice follows the document's own convention rather than an invented one: counting fences across `doc/`, `doc/component/` and `README.md` gives 71 plain, 53 php, 1 sh, 1 json, and the plain fence is what every other non-PHP listing uses, including the AST dump immediately preceding this one.

Numbers this change invalidated and re-executed: the docs-examples row in PLAN.md said 54 php-fenced blocks, which is now 53 because this block stopped being one. The row is re-recorded at this iteration's checkpoint with the corrected count, since the document it covers changed.

Learnings: none new this iteration.

Next: the ledger is empty and this run still has no clean full audit on record - the iteration 4 audit filed T3 at Medium - so the next iteration runs a full fresh-evidence audit. If that audit comes back with zero High and zero Medium, closeout begins and the evaluator gate can run the iteration after it, which is where the remaining budget is aimed.

## iter 7/10 | fb65c6fc-055411 | 2026-08-09 | AUDIT | audit

Task: Full fresh-evidence audit with an empty ledger and every inventory row swept or disclosed. Closed a gap in the evidence that the previous audit had not noticed, rescored every dimension, and filed one Low.

Changed: PLAN.md (cross-cutting battery note), BACKLOG.md (T5), JOURNAL.md, .jeffy/probes/modern-syntax-roundtrip (new battery).

Checkpoint: 6cb338e1ba36e45856a1dd33b194e8fceb123532

Verification: `php vendor/bin/phpunit` exit 0, 1895 tests, 2766 assertions, and exit 0 again under `--order-by=reverse`. Five further modules run in isolation, all exit 0: NameContextTest 23, BuilderFactoryTest 30, NodeAbstractTest 7, CompatibilityTest 2, Parser/Php8Test 54. `bash .jeffy/probes/run-all.sh` exit 0, TOTAL 415 passed, 0 failed across 26 batteries. `php test_old/run.php --no-progress --php-version=7.4 PHP ./data/php-src` exit 0 over 14695 files. `php tools/vendor/bin/phpstan` exit 0, no errors. `composer audit` reports no advisories. `bash .jeffy/probes/coverage.sh` reports 279 of 279 source files claimed by a row. `bash .jeffy/probes/staleness.sh` exit 0, 26 rows fresh, 0 stale.

The gap this audit closed: the php-src corpus that carries most of this project's differential evidence is PHP 7.4 source. Grepping `data/php-src` for enum declarations, readonly, `?->`, attributes or match returns 0 files, so 14695 files of round-tripping say nothing about any PHP 8 construct. A new battery covers exactly that: 36 snippets spanning PHP 8.0 through 8.5 - nullsafe, named arguments, attributes in four positions, constructor promotion, match, union, intersection and DNF types, throw expressions, enums pure and backed, readonly properties and classes, first-class callables, new in initializers, never, explicit octals, typed class constants, dynamic class constants, property hooks, asymmetric visibility, new without parentheses, the pipe operator and the void cast - each put through print then reparse then structural compare, print idempotence, byte-exact format-preserving printing, format-preserving printing under two mutations for 72 pairs, and a JSON round-trip. All five sweeps pass. A sixth check asserts the snippets really produce the node types they name, 17 of them by name across 51 distinct types with no error node, so a snippet that silently degenerated could not certify the rest.

Scores, over 26 swept rows of 27 with 1 unreachable on this host: correctness None; security None; architecture None; code quality None; testing None; error handling None; performance None; documentation None; dependency hygiene None; observability not applicable, a library reporting through exceptions and the ErrorHandler interface; UX and accessibility not applicable beyond the CLI, which is swept; developer experience Low (T5). Zero High and zero Medium in-envelope, so closeout begins: this run does no further auditing and no replenishment, and finishes by working what is on the ledger and then converging.

Performance, measured rather than assumed: parsing all 270 files under `lib/`, 948 KB of source, takes 0.672s at about 1.4 MB/s, pretty printing them takes 0.128s at about 7.4 MB/s, peak memory 90 MB. The php-src corpus run puts 14695 files through parse, clone, format-preserving print, pretty print, reparse and compare in about 49s at 27 MB peak. Nothing here is a finding; it is recorded so a later run has a baseline.

Finding. T5 (Low, build-ci): `git archive HEAD` ships 89 entries under `.jeffy/` plus PLAN.md, BACKLOG.md and JOURNAL.md, because `.gitattributes` export-ignores every other non-shipping path but not these. The project's own packaging hygiene is exact - `test/`, `doc/`, `tools/`, `grammar/` and `test_old/` all resolve to 0 entries in the archive - so the only leakage is the files this run itself added. It is filed rather than quietly fixed because it is a real consequence of the work, and it is Low because it changes nothing about the library's behaviour, only the size of a released archive.

Learnings: An audit's evidence is only as broad as its corpus, and a corpus can be large enough to feel conclusive while being systematically blind - 14695 files of PHP 7.4 cannot speak for a single PHP 8 construct, and three earlier iterations cited that corpus without noticing. Check what a corpus does not contain, not only what it does.

Next: T5, the only open task, then the evaluator gate and the declaration, which is what the remaining budget is for.

## iter 8/10 | fb65c6fc-055411 | 2026-08-09 | T5 | done

Task: T5 (Low, build-ci, developer experience) - this run's own state files shipped in release archives. Closed: `.gitattributes` now export-ignores `/.jeffy`, PLAN.md, BACKLOG.md, JOURNAL.md and JOURNAL-archive.md, matching the pattern style the file already uses for `/doc`, `/test`, `/tools`, `/grammar`, `/test_old`, the Makefile and the phpstan configs.

Changed: .gitattributes, .jeffy/probes/packaging (new battery), BACKLOG.md (T5 deleted), JOURNAL.md.

Checkpoint: b989ff701ced72b1e45e1c21895dacb666e402d2

Verification: `php vendor/bin/phpunit` exit 0, 1895 tests, 2766 assertions. `bash .jeffy/probes/run-all.sh` exit 0, TOTAL 441 passed, 0 failed across 27 batteries. Battery ownership: the diff touches `.gitattributes`, claimed by `.jeffy/probes/packaging/paths`, and that battery passes 26 of 26. Acceptance strength proved by restoring the committed `.gitattributes` over the fix, where the battery drops to 21 passed, 5 failed and reports 92 entries under `.jeffy/` plus each of the three state files. The archive built from the fixed tree contains exactly LICENSE, README.md, bin, composer.json and lib.

The battery builds the archive from the current working tree using a throwaway `GIT_INDEX_FILE`, not from HEAD, so it reports the state about to be committed rather than the previous commit; the real index is left untouched, confirmed by `git status --porcelain` still showing only the intended modification. This matters because `git check-attr` cannot answer the question at all: a directory pattern such as `/test` or `/.jeffy` does not report as set on the files inside it, so checking attributes file by file would have declared the fix ineffective while the archive was in fact clean.

The battery also pins the project's pre-existing packaging hygiene rather than only the new rules: it asserts that test, test_old, doc, tools, grammar, .github, the Makefile, the phpunit and phpstan configs, CHANGELOG.md and CONTRIBUTING.md all stay out, that lib, bin, LICENSE, README.md and composer.json stay in, that the top-level set is exactly those five, and that every path composer.json declares - the `bin` entry and the psr-4 autoload root - is present in the archive. A broken pattern anywhere in that file would now fail loudly instead of silently shipping or silently dropping code.

Learnings: `git check-attr` reports a directory-level export-ignore as unspecified on the files inside that directory, so it cannot verify a directory pattern; build a tree and list `git archive` instead. A probe that needs the working tree rather than HEAD can build one with `GIT_INDEX_FILE=<tmp> git read-tree HEAD && git add -A && git write-tree`, which leaves the real index alone.

Next: the ledger is empty, the iteration 7 audit scored zero High and zero Medium and put the run in closeout, and the Verify command is green, so the next iteration runs the adversarial evaluator gate and, on a PASS with the closing conditions holding, declares convergence in that same iteration.

## iter 9/10 | fb65c6fc-055411 | 2026-08-09 | EVALUATOR | audit

Task: Adversarial evaluator gate, invocation 1 of this run, run in the iteration the ledger stood empty with a clean full audit on record. Verdict REJECT. Five findings filed as G1 through G5; the run does not converge.

Changed: BACKLOG.md (G1 through G5), PLAN.md (Lessons), JOURNAL.md, .jeffy/evaluator/fb65c6fc-055411-1.md (the gate's artifact).

Checkpoint: 1fc8caea9457be993ee6b9979f2d1c21b54c53e9

Verification: Evaluator: REJECT - `Error::getEndColumn()` returns 0 on any error range ending at a newline, which is the class iteration 2 fixed at the Lexer site only. Before invoking, the closing conditions were checked and all held: zero open tasks in Now, Next and Later; zero unswept rows, with two `[~]` rows disclosed (lexer-emulators-forward, token-polyfill); the only commits since the clean audit at 6cb338e1 were that iteration's bookkeeping, T5 - a task that audit filed - and its bookkeeping; the Verify command re-read as `php vendor/bin/phpunit` with its Oracle class and Environment fingerprint intact; and `php vendor/bin/phpunit` exit 0, 1895 tests, 2766 assertions.

What the gate confirmed held, from its own re-runs rather than this run's claims: the Verify command exit 0 at 1895 of 1895; all five closed tasks' acceptance checks exit 0, lexer-core 20/0, error-handling 23/0, fuzzing-tooling 18/0, docs-examples 10/0, packaging 26/0; `run-all.sh` exit 0 at TOTAL 441 passed, 0 failed across 27 batteries; each of those checks proved able to fail against the pre-run code; T1's new positions correct on 13 cases the gate derived from `PhpToken::tokenize` rather than from the code, with all five changed test expectations right and no other site in `lib/` mixing end-position conventions; phpstan exit 0; and every re-derivable number in the Environment fingerprint matching, including the 0-forward-emulators claim on an 80500 host.

Every rejection reason was reproduced here before filing rather than taken on the gate's word. G1: `php bin/php-parse -c` on `<?php a<<<X` plus a newline prints `from 1:8 to 2:0`, and the direct call confirms `endFilePos` indexes the newline byte and `getEndColumn` returns 0, against a docblock that says 1-based and a documentation sentence that says the same. G2: the error-handling battery's own `>= 1` assertion does fail on that 12-byte input, so the assertion was right and its 12-input enumeration was too narrow, while its comment claimed every error kind. G3: the parser-grammar battery certifies inclusivity from one input and passes over G1 although it claims `ParserAbstract.php`. G4: `## Settled classes` is empty while two classes were closed with enumerations this run. G5: `.jeffy/probes/packaging/` has no inventory row, so staleness.sh never checks it.

Invocation accounting: 1 of at most 2. The cap is 2 rather than 3 because this first invocation landed at iteration 9, past the midpoint of a 10-iteration budget. One invocation remains but only one iteration does, so the fix for G1 and a re-invocation cannot both fit; the run will end out of budget rather than converged, and convergence falls to the next run's fresh audit and gate.

Learnings: When a defect class is about a position landing on a particular byte, enumerate by the byte the position can land on, not by the convention the code uses. Iteration 2 enumerated every inclusive-versus-exclusive site in `lib/` and closed the class on that basis, and every site whose end position can be a newline went unexamined - which is exactly where the same defect survived. A gate that re-derives expected values independently found in one invocation what four iterations of self-checking had not.

Next: the final iteration. G1 is a Medium whose fix touches error positions library-wide and needs its own iteration plus a re-invocation to certify, neither of which the budget holds, so iteration 10 tidies the ledger and writes the handoff rather than starting work it cannot finish.

## iter 10/10 | fb65c6fc-055411 | 2026-08-09 | WRAPUP | done

Task: Final iteration. The gate rejected at iteration 9 and G1 is a Medium whose fix touches error positions across the library and would need both its own iteration and a re-invocation to certify, so this iteration tidies the ledger and writes the handoff rather than starting work it cannot finish. The run ends out of budget, not converged.

Changed: BACKLOG.md (Settled classes recorded, G4 and G5 closed as tidying), PLAN.md (packaging inventory row), JOURNAL.md.

Checkpoint: 92805f21408cfebb3a8fa83ce7d20ba3e8ef4719

Verification: `php vendor/bin/phpunit` exit 0, 1895 tests, 2766 assertions. `bash .jeffy/probes/run-all.sh` exit 0, TOTAL 441 passed, 0 failed across 27 batteries. `bash .jeffy/probes/coverage.sh` reports 279 of 279 source files claimed by a row. `php .jeffy/probes/packaging/probe.php` exit 0, 26 of 26, which is the sweep the new row records.

G4 and G5 were closed here because both are tidying of the loop's own records, which is what a WRAPUP is for. G4: the two classes this run closed are now recorded under Settled classes, each with the command that enumerates it. Before recording the end-position class, both were re-derived - `grep -rn "getEndPos()" lib/` returns four consumer sites, all using `getEndPos() - 1`, plus the sentinel token which legitimately uses the exclusive value as a start - so that class is genuinely settled. It is deliberately recorded as being about which convention a site uses, and as NOT covering the class G1 names, which is about the byte an end position lands on; without that distinction the settled-class rule would block the next audit from working G1. G5: `packaging` now has its own Surface inventory row, swept at this iteration's checkpoint, so `staleness.sh` checks it and its 26 checks count toward the rows-swept figure.

Handoff for the next run. Three tasks are open and each carries a runnable acceptance check: G1 (Medium, runtime) is the substantive one and should be first; G2 and G3 (Low, test) are the two batteries that pass over G1 and should be strengthened in the same run, after G1 rather than before, since their corrected forms cannot pass until G1 is fixed. G1's fix is not a one-line change: `Error::toColumn` returning 0 for a position that is itself a newline is the shared root, and the sites that can produce such a position are `ParserAbstract::getAttributesAt` at its `$afterEndToken->pos - 1` and any caller whose offending token ends a line. Whoever takes it should decide deliberately between correcting `toColumn` - which changes columns library-wide and needs the fixture corpus re-checked - and stopping the range at the last content byte the way `Lexer` now does, which is local but must then be applied at every such site rather than one. The enumeration to build first is not of end-position conventions, which iteration 2 already closed, but of the tokens whose text ends with a newline and can end an error range.

The run leaves the project's own Verify command green and every battery green; the open work is a defect the batteries do not yet catch, which is precisely why G2 and G3 exist.

Learnings: none new this iteration.

Next: a fresh session in this directory. The state files carry the run forward: BACKLOG.md holds G1 through G3 with their acceptance checks, PLAN.md holds the envelope, the 28-row inventory and the Lessons, and `git log` holds the checkpoints.

## iter 1/10 | 29e4bbb1-072001 | 2026-08-09 | G1 | done

Task: G1 (Medium, runtime, correctness) - an error range that ends on a line terminator reports a column of 0 and a line one past the byte it names. Closed. The filed reproduction was run first: `php bin/php-parse -c` on `<?php a<<<X` plus newline printed `from 1:8 to 2:0` and on `<?php $a = ?>` plus newline printed `from 1:12 to 2:0`.

Changed: lib/PhpParser/ParserAbstract.php, test/code/parser/errorHandling/errorRangeOnNewline.test (new), test/code/parser/scalar/flexibleDocStringErrors.test, .jeffy/probes/error-range-columns/ (new battery), PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: eda014103bad3c692cb8d2962f1258beaaae0acc

Verification: `php vendor/bin/phpunit` exit 0, 1901 tests, 2769 assertions. `bash .jeffy/probes/run-all.sh` exit 0, TOTAL 2162 passed, 0 failed across 28 batteries. `php tools/vendor/bin/phpstan` exit 0, no errors over 270 files. `php test_old/run.php --no-progress --php-version=7.4 PHP ./data/php-src` exit 0, all 14695 files parsed, cloned, format-preserving printed, pretty printed, reparsed and compared. `php grammar/rebuildParsers.php` exit 0 and `cmp` reports both committed parsers reproduced byte-for-byte. Acceptance check is `.jeffy/probes/error-range-columns/probe.php`, 1721 passed 0 failed; its strength was proved by restoring the committed `ParserAbstract.php` over the fix with `git show HEAD:<path>`, where it drops to 1664 passed 57 failed and the whole PHPUnit suite drops to 4 failures - all three cases of the new fixture plus the two pre-existing `flexibleDocStringErrors` lines - after which the fix was copied back and both went green again.

Where the fix went, and why not the two places the handoff proposed. The handoff named `Error::toColumn` as the shared root. It is not the whole root: `toColumn` returning 0 for a terminator byte is one half, and the other half is `getAttributes`, whose `endLine` is the line of the byte *after* the range while its `endFilePos` is the last byte *of* it. Those two agree on every content byte and diverge on a terminator, so correcting `toColumn` alone would have printed `1:8 to 2:12` - a column on a line that has none. Correcting `getAttributes` instead was measured rather than guessed: patched experimentally, the whole suite showed exactly one failing fixture, the two `flexibleDocStringErrors` lines that are the defect itself. It was still rejected, because `doc/component/Lexer.markdown` defines `endFilePos` as the offset of the last character that is part of the node, and for a statement terminated by `?>` plus a newline that character genuinely is the newline; trimming it would break `substr($code, $startFilePos, $endFilePos - $startFilePos + 1)` as a way to recover a node's source text. A node range and an error range are different contracts: the node range is the node's text, the error range is a pointer a human reads. So the trimming happens at `ParserAbstract::emitError`, the one choke point every parser error passes through, and node attributes are untouched. `Lexer` already made the same choice for the unterminated-comment error at iteration 2. The one parser error that bypassed `emitError`, the empty-array-element error in `parse()`, now goes through it.

Contract preserved: `doc/component/Error_handling.markdown` says both line and column numbers are 1-based and that EOF errors sit one past the end of the file. The fix makes the first true where it was not; the second is preserved by returning early when the range is at or past the end of the source, which is the sentinel token's position. No documentation changed, because nothing documented changed - a documented promise started being kept.

Enumeration behind the class claim. The class is the byte a boundary lands on, so it was enumerated by that byte and not by grepping for calls: tokenizing all 647 `<?php` chunks of the project's own fixture corpus and collecting every parser-visible token kind whose text starts or ends with a terminator returns T_START_HEREDOC, T_ENCAPSED_AND_WHITESPACE, T_CLOSE_TAG and T_INLINE_HTML on the end side, and T_ENCAPSED_AND_WHITESPACE and T_INLINE_HTML on the start side. The battery drives an error at each of the six and asserts, per error, that the boundary byte is not a terminator and that the reported line and column equal ones derived independently from the raw bytes rather than from `Error::toColumn`. It then applies the same invariant to every error the whole fixture corpus produces, and fails if any enumerated kind was not exercised, so a future PHP version adding a seventh kind fails the battery rather than passing silently.

The corpus sweep surfaced one error that carries no range at all, `Invalid UTF-8 codepoint escape sequence: Codepoint too large`, thrown bare from `Node/Scalar/String_.php`. That is documented behaviour - `Error_handling.markdown` says column information is not always available - so it is not part of this fix; it is filed as G4, and the battery asserts that it stays the only such message.

Learnings: A `.test` fixture's code chunk carries no trailing newline, because `CodeTestParser` splits on `\n-----\n` after `canonicalize` stripped the file's trailing newlines; a case needing a token that ends at a line terminator must put content on the next line instead. `set_error_handler` cannot intercept `E_COMPILE_WARNING`, which is what `PhpToken::tokenize` emits for the `"\400"` escape one fixture contains, so the probe masks it with `error_reporting` instead.

Next: the ledger holds G4, G2 and G3, all Low. G2 and G3 are the two batteries that passed over G1 and can now be strengthened, since their corrected forms fail against the pre-G1 code and pass against this one.

## iter 2/10 | 29e4bbb1-072001 | 2026-08-09 | G4 | done

Task: G4 (Low, runtime, error handling) - the codepoint error thrown from `Node\Scalar\String_` reached the handler with no position at all. Closed. The filed reproduction ran first: `php bin/php-parse -c` on `<?php "\u{110000}";` printed `Codepoint too large on line 1`, with no range where every neighbouring error prints one.

Changed: lib/PhpParser/ParserAbstract.php, test/code/parser/scalar/unicodeEscape.test, .jeffy/probes/error-range-columns/probe.php, BACKLOG.md, PLAN.md, JOURNAL.md.

Checkpoint: 7eacd4898f2fdb31e864f044e99941c55d33b1c9

Verification: `php vendor/bin/phpunit` exit 0, 1901 tests, 2769 assertions. `bash .jeffy/probes/run-all.sh` exit 0, TOTAL 2179 passed, 0 failed across 28 batteries. `php tools/vendor/bin/phpstan` exit 0, no errors. `php test_old/run.php --no-progress --php-version=7.4 PHP ./data/php-src` exit 0, all 14695 files. `php grammar/rebuildParsers.php` exit 0 with `cmp` reporting both committed parsers reproduced byte-for-byte. Acceptance check is the two `unicodeEscape.test` cases under `php vendor/bin/phpunit`; strength proved by restoring the committed `ParserAbstract.php` with `git show HEAD:<path>`, where the suite fails exactly those two and the error-range-columns battery drops to 1719 passed 1 failed on its no-attribute-less-errors check, both green again after copying the fix back.

Fixed at the boundary, not the site. G4 named one throw site, but the site cannot fix itself: `String_::parseEscapeSequences` and `String_::parse` are `@internal` public statics a caller can invoke directly, so they have no attributes to attach, and `String_::fromString` is only one of three call paths into them - `ParserAbstract::parseDocString` reaches `parseEscapeSequences` twice more, once for a plain heredoc body and once per interpolated part. All three paths run inside a reduce callback, and every reduce callback is wrapped by one `catch (Error $e)` in `doParse`. That catch now fills an attribute-less error with the attributes of the production being reduced, which is the construct the error is about. The guard is `$ruleLength > 0` because the span is read from `tokenStartStack[$stackPos - $ruleLength + 1]`, an index an empty production does not have.

Contract preserved: an error that already carries attributes is untouched, so `Int_`'s numeric-literal error and the five `Modifiers` errors that `checkModifier` positions keep exactly the attributes they had; only the empty case is filled. `doc/component/Error_handling.markdown` says how much location information is available depends on the origin of the error and that availability must be checked with `hasColumnInfo()`. That stays true - a caller invoking `String_::fromString` outside the parser still gets a bare error - so no documentation changed; what changed is that the parser no longer produces one.

The new ranges were checked as known answers, not accepted from the code. All four paths were driven - double-quoted string, plain heredoc, interpolated string, interpolated heredoc - and in each the byte slice `substr($code, $startFilePos, $endFilePos - $startFilePos + 1)` reproduces the whole literal exactly. The two fixture expectations were derived independently by locating the literal in the raw source with a byte scan and computing its 1-based span by hand: `"\u{FFFFFFFFFFFFFFFF}"` is 22 bytes at column 1 of line 2, and `"\u{110000}"` is 12, which is what the fixture now records.

Battery ownership: the diff touches `lib/PhpParser/ParserAbstract.php`, claimed by parser-grammar, modern-syntax-roundtrip and error-range-columns; all three ran green. The error-range-columns battery pinned the old behaviour by name - it asserted that the codepoint message stayed the only attribute-less one - so it was updated in this iteration to assert the contract that now holds: no error the corpus produces reaches the handler without column information. The parser-grammar row was re-swept in full at this checkpoint, battery plus the 14695-file corpus plus the regeneration, because its code moved again.

Learnings: none new this iteration.

Next: the ledger holds G2 and G3, both Low and both about batteries that passed over G1. Two open tasks is below the replenishment threshold of three, so the next iteration either works G2 and leaves replenishment to the one after, or runs a partial audit first; it is not a closeout, since no full fresh-evidence audit has run in this run yet.

## iter 3/10 | 29e4bbb1-072001 | 2026-08-09 | G2 | done

Task: G2 (Low, test, testing) - the error-handling battery claimed its input set was "built by provoking an error of every kind the lexer and parser emit" while being twelve hand-picked inputs, none of whose ranges touched a line terminator, so its own 1-based-column assertion passed straight over G1. Closed.

Changed: .jeffy/probes/error-handling/probe.php, PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: 84132f256582d5ab09c55d10cb3eeac7647591fb

Verification: `php .jeffy/probes/error-handling/probe.php` exit 0, 26 passed 0 failed, up from 24. `php vendor/bin/phpunit` exit 0, 1901 tests, 2769 assertions. `bash .jeffy/probes/run-all.sh` exit 0, TOTAL 2182 passed, 0 failed across 28 batteries. Acceptance strength proved against the pre-G1 code by restoring `git show c53d1358:lib/PhpParser/ParserAbstract.php`, where the battery fails on `range ends in T_START_HEREDOC: endColumn 0 < 1`, `end byte is a line terminator` and the same pair for T_CLOSE_TAG, and passes again once the current file is copied back.

The false sentence was replaced rather than softened, and what replaced it says what the set is and where its exhaustive counterpart lives: the three error kinds Lexer emits, a spread of parser error shapes covering every way a range can meet a line terminator at either end, and a pointer to `.jeffy/probes/error-range-columns`, which applies the same invariant to the whole fixture corpus. The comment now also records why the old claim was wrong, so the next reader does not restore it.

The clause about Lexer's three error kinds is backed by a check rather than asserted. Each of the three is provoked directly against a bare Lexer - an invalid byte, a null byte, an unterminated comment - and the observed set is compared for equality, not containment, against `Unexpected character <char>`, `Unexpected null byte` and `Unterminated comment`. What makes that an enumeration instead of an assertion is the second half: every `<?php` chunk of every fixture under `test/code` goes through the same bare Lexer, 647 of them, and a fourth kind appearing anywhere in the corpus fails the check.

Six inputs were added, each named by the token kind whose text carries the terminator: T_START_HEREDOC, T_CLOSE_TAG, a heredoc body at both ends, T_INLINE_HTML wrapped on both sides, and a CRLF close tag. The per-error assertion was strengthened from "column is at least 1" to the full invariant - the byte the range names is not a terminator, and the reported line and column equal ones derived from the raw source rather than from the same `Error` accessors that report them - with the documented EOF placement excluded by its own branch and still checked separately. A count assertion keeps at least five of the inputs genuinely abutting a terminator, so the set cannot be quietly hollowed out later.

Learnings: none new this iteration.

Next: G3 is the last open task, the parser-grammar battery's single-input inclusivity claim. That leaves the ledger empty afterwards, so the iteration after it is the run's first full fresh-evidence audit.

# Journal

Append-only. One primary entry per iteration; SALVAGE and ROTATION entries are additional. Never rewrite past entries (filling the current entry's Checkpoint field is completion, not a rewrite).

Heading grammar, exactly (fenced and indented here so this example is never mistaken for an entry by anything that counts or rotates them):

```
  ## iter <i>/<N> | <run-id> | <YYYY-MM-DD> | <task-id or AUDIT or EVALUATOR or RATCHET or WRAPUP or SALVAGE or ROTATION> | <done|blocked|audit|converged|salvage|rotation>
```

Write a real heading at column zero, never indented: the indentation above belongs to the example alone, and an indented heading is invisible to the rotation anchor and to the archive counter, so the entry under it is not counted and not rotated.

SALVAGE entries take status salvage; ROTATION entries take status rotation. An EVALUATOR entry records an evaluator-gate iteration: status audit when the run continues after the verdict, blocked on a terminal second REJECT, converged when that same iteration declares.

run-id is the first 8 characters of the session id, a hyphen, then the HHMMSS of started_at from the loop state frontmatter, so two runs in one session are told apart. Body fields, in order: Task, Changed, Checkpoint (the jeffy checkpoint commit hash, or none with the reason), Verification, Learnings, Next.

The closing entry that declares convergence carries the evaluator verdict in its Verification field: `Evaluator: PASS - <one-line summary>`, or `Evaluator: unavailable (<reason>)`. An earlier EVALUATOR entry records its own verdict the same way and never stands in for the closing one: the Stop hook reads the closing entry alone, so a run that gates early and keeps working re-invokes the gate at the declaration.

Closed tasks are recorded here as one line each (ID, title, closing evidence), because BACKLOG.md deletes them. Rotation: when this file exceeds 500 lines, move all but the last 10 entries to the end of JOURNAL-archive.md, appending to whatever that file already holds and never overwriting it, because the archive accumulates across every rotation and every run; create it only when it does not already exist, and record the rotation as a ROTATION entry.

## iter 4/10 | 29e4bbb1-072001 | 2026-08-09 | G3 | done

Task: G3 (Low, test, testing) - the parser-grammar battery certified that "endFilePos is inclusive and delimits the offending token exactly" from a single mid-line token, and passed over G1 although `lib/PhpParser/ParserAbstract.php` is a path its row claims. Closed.

Changed: .jeffy/probes/parser-grammar/probe.php, PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: c9d4bcc869a9c9da52f4bccac62c47f595401c68

Verification: `php .jeffy/probes/parser-grammar/probe.php` exit 0, 22 passed 0 failed, up from 15. `php vendor/bin/phpunit` exit 0, 1901 tests, 2769 assertions. `bash .jeffy/probes/run-all.sh` exit 0, TOTAL 2191 passed, 0 failed across 28 batteries. Acceptance strength proved against the pre-G1 code by restoring `git show c53d1358:lib/PhpParser/ParserAbstract.php`, where the battery reports 14 passed 7 failed - the heredoc-start slice comes back as `"<<<X\n"` at `1:8 to 2:0`, the close tag as `"?>\n"` at `1:12 to 2:0`, the inline-HTML range as `"\nfoo\n"` at `2:0 to 4:0`, and the three-line range carries no column information at all - and 22 passed 0 failed once the current file is copied back.

The single case became a table of five error-range shapes, each a hand-written known answer rather than a value read back from the parser: the exact source slice the inclusive range must cover, and its 1-based line and column span. The shapes are a mid-line token, a token whose own text ends at a line terminator (T_START_HEREDOC), a close tag, a range spanning three lines, and a range whose start byte is a line terminator (T_INLINE_HTML after a close tag ate the first newline). All five known answers were computed by hand from the byte layout before the battery was run, and all five passed on the first run. The documented EOF placement, the one range that legitimately leaves the source, was split out into its own check asserting both boundaries sit exactly one past the last byte, so the slice assertion above never has to make an exception for it.

That is what makes the row's claim answerable: a slice comparison over five shapes fails loudly when a boundary drifts by a byte, where the previous single mid-line token could not distinguish inclusive from exclusive at a line terminator at all.

Learnings: none new this iteration.

Next: the ledger is empty for the first time in this run. No full fresh-evidence audit has run yet in this run, so the next iteration is that audit, per the Method and the Operating envelope, sweeping the inventory rows least recently swept first.

## iter 5/10 | 29e4bbb1-072001 | 2026-08-09 | AUDIT | audit

Task: Full fresh-evidence audit, the first of this run, run because the ledger emptied at iteration 4 and BACKLOG.md carries no Converged line, so the ratchet does not apply. Scores below claim the 26 swept rows only; the 2 disclosed unreachable rows are named at the end. Closeout has NOT begun: this audit found two Mediums.

Changed: BACKLOG.md (S1 and S2 filed, the iteration 1 settled-class line amended), PLAN.md (Lessons), JOURNAL.md.

Checkpoint: 3d410a27bc59ed7c5a13cdc72c484b187d65b1ad

Verification: `php vendor/bin/phpunit` exit 0, 1901 tests, 2769 assertions. `bash .jeffy/probes/run-all.sh` exit 0, TOTAL 2191 passed, 0 failed across 28 batteries. `php tools/vendor/bin/phpstan` exit 0. `composer audit` exit 0, no advisories. `php test_old/run.php --no-progress --php-version=7.4 PHP ./data/php-src` exit 0, all 14695 files. `bash .jeffy/probes/coverage.sh` 279 of 279 source files claimed. `bash .jeffy/probes/staleness.sh` exit 0, 27 rows fresh. Fingerprint re-derived and unchanged: 282 `.test` fixtures (179 parser, 71 prettyPrinter, 32 formatPreservation), PHP 8.5.4, PHPUnit 9.6.35, Composer 2.9.5, one `<directory>./test/</directory>` suite root, 2 skip guards neither of which fires here, and `php .jeffy/probes/lexer-emulators-forward/probe.php` still reports 0 forward emulator selections on an 80500 host.

Scores: correctness Medium, error handling Medium, testing Medium, developer experience Medium, architecture None, code quality None, security None, performance None, documentation None, dependency hygiene None, observability None. UX and accessibility do not apply and are skipped: the only user-facing surface is `bin/php-parse`, a non-interactive developer CLI with no rendered output. The correctness, error handling, testing and developer experience scores are carried by exactly two findings, S1 and S2; nothing else in-envelope reached Medium.

S1 is filed as one structural task under the three-strike rule rather than as two instance patches, because it is the third finding sharing a root with G1: the library's column arithmetic and PHP's tokenizer disagree about what a line is and where a terminator byte belongs. Both halves reproduce through the real CLI. `php bin/php-parse -c` on `<?php switch (1) { ?>` plus two newlines plus `<?php }` prints `from 2:0 to 3:0`, because the offending T_INLINE_HTML token is a single newline, the trim added at iteration 1 has no content byte to move to and returns the range untouched, and `Error::toColumn` gives a terminator byte a column of 0. The same CLI on `<?php` CR `$a = ;` CR `foo();` prints `from 2:12 to 2:12`, where `;` is the 6th character of line 2: `PhpToken` counts a lone CR as a line break, confirmed by tokenizing CR-separated source and reading the token lines, while `toColumn` searches only for "\n" and so counts the column from the start of the file. The second half predates this run entirely; the first is the residue of iteration 1's own fix.

That residue also means iteration 1's settled-class line overstated its case, so the line was amended in place rather than left standing: its enumeration covered every token kind that can carry a terminator but never the degenerate member of the set, the range that is nothing but terminators. The amendment names S1 as the open work, which is what keeps the settled-class rule from blocking it.

S2 came out of the Method's requirement to run a test module in isolation before scoring Testing clean, and it is the reason that rule exists. `php vendor/bin/phpunit --filter ModifiersTest` prints `OK (2 tests, 3 assertions)` and then exits 255: the static provider `provideTestInvalidReturn` builds ten `NodeVisitorForTesting` objects, PHPUnit runs every provider while building the suite even under a filter, the filtered-out test never consumes them, and each destructor throws `Expected event did not occur`. Running the same file directly, `php vendor/bin/phpunit test/PhpParser/ErrorTest.php`, exits 0, as does `--filter NodeTraverserTest`, which is what isolates the cause to the unconsumed provider objects rather than to any leaked state between modules. Four modules were run this way - ErrorTest 17 tests, LexerTest 10, NodeTraverserTest 23, NameResolverTest 16 - and all four passed on their assertions, so no order dependence surfaced beyond the exit status itself.

Nothing was filed inside a settled class without new evidence, and nothing was filed on a dimension a previous audit scored clean without a reproduced failure: S1's two reproductions and S2's exit status are all commands run in this iteration.

Learnings: An enumeration that certifies a fix must include the degenerate member of the set, not only its typical members. Iteration 1 enumerated every token kind that can carry a line terminator and still missed the range that is nothing but terminators, where the fix has nothing to move to.

Next: S1 is the top item and needs its own iteration, S2 the one after. That leaves iterations 8 through 10 for the evaluator gate and the declaration, which fits the budget.

## iter 6/10 | 29e4bbb1-072001 | 2026-08-09 | S1 | done

Task: S1 (Medium, runtime, correctness) - the library's column arithmetic and PHP's tokenizer disagreed about what a line is and where a terminator belongs. Closed. Both filed reproductions ran first and both reproduced: `php bin/php-parse -c` printed `from 2:0 to 3:0` for the all-terminator range and `from 2:6 to 2:6` was not what the CR-only source got, it printed `from 2:12 to 2:12`.

Changed: lib/PhpParser/Error.php, lib/PhpParser/ParserAbstract.php, test/code/parser/errorHandling/errorRangeOnNewline.test, .jeffy/probes/error-range-columns/probe.php, PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: 0b047af1fec264487a7314d20dea54b6bff01768

Verification: `php vendor/bin/phpunit` exit 0, 1905 tests, 2771 assertions, up from 1901 and 2769. `bash .jeffy/probes/run-all.sh` exit 0, TOTAL 2271 passed, 0 failed across 28 batteries. `php tools/vendor/bin/phpstan` exit 0. `php test_old/run.php --no-progress --php-version=7.4 PHP ./data/php-src` exit 0, all 14695 files. `php grammar/rebuildParsers.php` exit 0 with `cmp` reporting both committed parsers reproduced byte-for-byte. Acceptance strength proved by restoring both files with `git show HEAD:<path>`: the error-range-columns battery drops to 1792 passed 26 failed and the suite to 2 failures, both of them the new fixture cases, and both go green again once the fixes are copied back. After the fix the two reproductions read `from 2:1 to 2:1` and `from 2:6 to 2:6`.

One line model now serves both halves. `Error::toColumn` searched only for "\n" and treated a terminator at the queried position as the start of its own line; it now searches strictly before the position for either "\n" or "\r", with one branch for the case where the position is the second byte of a "\r\n" pair, since that pair is a single terminator ending a single line. `ParserAbstract::trimErrorRange` counted "\n" bytes when adjusting the reported line; it now counts line breaks that end inside the range it gives up, where "\r\n" counts once and a lone "\r" counts. The degenerate case changed shape rather than being skipped: a range that is nothing but terminators keeps its bytes, because there is no content byte to move to, but its `endLine` is still corrected, so it reports the terminator's own position instead of column 0 on the following line.

The independent derivation in the battery was rewritten from the same definition but not the same algorithm - a forward scan for the line and a backward scan for the column, against `Error`'s strrpos arithmetic - so their agreement is evidence rather than an echo. Nine cases were added: three all-terminator ranges including a CRLF one, and six CR-only sources covering a heredoc start, a close tag, a plain syntax error and a three-line range. All nine passed on the first run, as did the two hand-derived fixture expectations: `;` really is the 6th character of line 2 in the CR-only source, checked by splitting that source on `/\r\n|\n|\r/` and reading the offset within line 2.

Contract preserved: the documented promise in `doc/component/Error_handling.markdown` that both line and column numbers are 1-based, and that EOF errors sit one past the end of the file. The first is now true where it was not, the second is untouched, since the trim still returns early for a range at or past the end of the source. No documentation changed, because nothing documented changed. The trim's invariant assertion in the battery was narrowed to match reality rather than relaxed: a range holding at least one content byte must still have been trimmed onto it at both ends, and only a range holding none is exempt.

Battery ownership: the diff touches `lib/PhpParser/Error.php` and `lib/PhpParser/ParserAbstract.php`, claimed by error-handling, error-range-columns, parser-grammar and modern-syntax-roundtrip; all ran green inside run-all. Both the parser-grammar and error-handling rows were re-swept in full at this checkpoint, the first including the 14695-file corpus and the regeneration.

Learnings: To put a lone CR into a `.test` fixture, inject it with the harness's own eval, because `canonicalize` rewrites every `\r\n` to `\n` before splitting and a CR typed directly into the file does not survive that.

Next: S2 is the last open task, the filtered-run exit status. That leaves iterations 8 through 10 for the evaluator gate and the declaration.

## iter 7/10 | 29e4bbb1-072001 | 2026-08-09 | S2 | done

Task: S2 (Medium, test, testing) - a filtered run of the project's own gate printed OK and then exited 255. Closed. The filed reproduction ran first and reproduced: `php vendor/bin/phpunit --filter ModifiersTest` printed `OK (2 tests, 3 assertions)` and exited 255 with eleven `Expected event did not occur` lines.

Changed: test/PhpParser/NodeVisitorForTesting.php, test/PhpParser/NodeTraverserTest.php, BACKLOG.md, JOURNAL.md.

Checkpoint: 6295fa2d5c2930aa4e02ca57846875c6c15d3ffb

Verification: `php vendor/bin/phpunit --filter ModifiersTest` exit 0, which is the acceptance check, and the whole suite exit 0 at 1905 tests and 2793 assertions, up from 2771 because the check this fix moved is now 22 real assertions instead of an out-of-band destructor. Every other filtered form checked and all exit 0: ErrorTest 17, LexerTest 10, NodeTraverserTest 23, NameResolverTest 16, CodeParsingTest 285, and the single-file form `php vendor/bin/phpunit test/PhpParser/NodeTraverserTest.php`. `bash .jeffy/probes/run-all.sh` exit 0, TOTAL 2271 passed, 0 failed across 28 batteries. `php tools/vendor/bin/phpstan` exit 0. `php tools/vendor/bin/php-cs-fixer fix --dry-run --diff --config=.php-cs-fixer.dist.php` exit 0, 0 of 333 files needing a fix, so the new code matches the project's own style rules.

The root cause was the throwing destructor, not the provider. `NodeVisitorForTesting::__destruct()` raised an exception whenever its scripted returns had not all been consumed, and a destructor fires whenever PHP happens to collect the object - at shutdown, after the report is printed, with no test to attribute it to. PHPUnit builds every data provider while assembling the suite, so `provideTestInvalidReturn`'s ten visitors exist in every run and are consumed only when `testInvalidReturn` actually executes; under a filter they are not, and ten destructors turned a passing run into a fatal. Building fixtures in a provider is ordinary PHPUnit; tolerating never being consumed is what the helper owed.

So the check moved rather than disappeared. The destructor is gone; instances register themselves on construction, `NodeTraverserTest::setUp` drops whatever the providers built, and `assertPostConditions` asserts that every visitor the test itself created consumed its whole script. That runs only when the test body did not already fail, so an early failure no longer drags an unrelated fatal behind it, and a failure now names the test that caused it. The provider's own visitors lose nothing by being dropped: the scripted return each carries is what produces the `LogicException` message that `testInvalidReturn` expects, so it is pinned by that expectation.

Both halves were proved rather than assumed. Scripting one visitor in `testNonModifying` with a return no event can consume makes the new assertion fail - `visitor #0 was scripted with a return that no event ever consumed`, 23 tests 1 failure, attributed to the test rather than to shutdown - and restoring both files from HEAD puts `--filter ModifiersTest` back at exit 255 with its eleven destructor exceptions.

Learnings: none new this iteration.

Next: the ledger is empty. The iteration 5 audit is on record but it filed two Mediums and `lib/` changed materially since, so its evidence no longer covers the current tree. Iteration 8 therefore runs a fresh full audit; on a clean result iteration 9 runs the evaluator gate and declares in that same iteration if the closing conditions hold, leaving iteration 10 as the margin a REJECT would need. Replenishment is skipped in favour of that audit, which supersedes it.

## iter 8/10 | 29e4bbb1-072001 | 2026-08-09 | AUDIT | audit

Task: Full fresh-evidence audit, the second of this run, run because the ledger emptied at iteration 7 and because the iteration 5 audit filed two Mediums and `lib/` changed materially after it, so its evidence no longer covered this tree. Scores claim the 26 swept rows only; the 2 unreachable rows are named below. Closeout has NOT begun: this audit found one Medium.

Changed: BACKLOG.md (A1 and A2 filed), PLAN.md (Lessons), JOURNAL.md.

Checkpoint: 73c3e647bd78f85554af44d09d80df5e4b132bd3

Verification: `php vendor/bin/phpunit` exit 0, 1905 tests, 2793 assertions. `bash .jeffy/probes/run-all.sh` exit 0, TOTAL 2271 passed, 0 failed across 28 batteries. `php tools/vendor/bin/phpstan` exit 0. `php tools/vendor/bin/php-cs-fixer fix --dry-run --config=.php-cs-fixer.dist.php` exit 0, 0 of 333 files needing a fix. `composer audit` no advisories. `php test_old/run.php --no-progress --php-version=7.4 PHP ./data/php-src` exit 0, all 14695 files. `bash .jeffy/probes/coverage.sh` 279 of 279. `bash .jeffy/probes/staleness.sh` exit 0.

Fresh evidence beyond the standing gates, aimed at the code this run changed. A direct known-answer probe of the public column API, driven by constructing `Error` objects rather than through the parser, passed 36 of 36 over every terminator shape - LF, CRLF at both of its bytes, a lone CR, a blank line's own terminator, the empty source, the documented one-past-the-end position, and a sweep of every position in a mixed-terminator source. Error ranges under reverse token emulation were checked across all 7 target versions on 6 sources, 42 errors, every reported line and column equal to an independent terminator-aware derivation, which is what confirms the trim reads the original source rather than the rewritten token stream. Isolation was re-checked now that S2 is closed: six modules run alone all exit 0, and the whole suite exits 0 under `--order-by=reverse` and `--order-by=random`, so no order dependence surfaced. Performance was measured rather than assumed, with the pre-run library and the current one benchmarked through the same loader over the same 270 files, best of three, twice: 545.3 then 501.9 ms for the pre-run library against 601.5 then 442.9 ms for the current one. The ordering flips between the pairs, so the difference is noise and no regression is measurable, which is what the shape of the change predicts - one O(1) assignment on the hot path and everything else on the error path.

Node attributes were proved unchanged rather than argued to be: the pre-run library and the current one were both driven over a close-tag-terminated statement, a heredoc and a CR-only source with `dumpPositions`, and the two dumps are byte-identical.

A1 came out of asking what would have caught it if they had not been. Patching `getAttributes` to give up a trailing line terminator - the exact change this run considered and rejected at iteration 1 - now leaves the entire apparatus silent: `php vendor/bin/phpunit` still OK at 1905 tests, `run-all.sh` still TOTAL 2271 passed 0 failed. At iteration 1 that same mutation broke two lines of `flexibleDocStringErrors`, and this run's own error-range trim removed that detector, because the error lines it used to move are now trimmed either way. So a documented public contract - `endFilePos` is the offset of the last character that is part of the node - is pinned by nothing, and the enumeration says why: no `!!positions` fixture in the corpus contains a close tag at all. The control for that mutation test is a blanket one-byte shift of the same attributes, which is caught loudly at 179 errors, 103 failures and 246 battery failures, so the apparatus is not blind to node positions in general, only to the terminator at their end.

A2 is the docblock this run wrote for `trimErrorRange` promising a postcondition the method stopped establishing when S1 gave it the degenerate case.

Scores: testing Medium, documentation Low, correctness None, error handling None, architecture None, code quality None, security None, performance None, dependency hygiene None, developer experience None, observability None. UX and accessibility do not apply and are skipped: the only user-facing surface is `bin/php-parse`, a non-interactive developer CLI. The two unreachable rows stand as disclosed, lexer-emulators-forward and token-polyfill, both needing a host older than PHP 8.5.

Nothing was filed inside a settled class without new evidence and nothing rests on a previous audit's reading: every claim above is a command run in this iteration.

Learnings: A fix that corrects an output can delete the only detector some other contract had. Before the checkpoint, re-run the mutation that the removed symptom used to catch.

Next: A1 is a Medium and takes iteration 9; A2 is a two-line docblock correction and takes iteration 10, which is the final iteration. That leaves no room for the evaluator gate, so this run will end out of budget rather than converged, with an empty ledger and a clean tree for the next run's fresh audit and gate to close from.

## iter 9/10 | 29e4bbb1-072001 | 2026-08-09 | A1 | done

Task: A1 (Medium, test, testing) - node end attributes that cover a trailing line terminator were pinned by nothing. Closed. The filed reproduction ran first and still held: with `getAttributes` patched to give up that terminator, `php vendor/bin/phpunit` stayed at OK, 1905 tests, and `bash .jeffy/probes/run-all.sh` at TOTAL 2271 passed 0 failed - the whole apparatus silent.

Changed: test/code/parser/nodePositionsAtLineEnd.test (new), PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: 9a48ba70b014627911bfb1e8c9f7d67ab2a1ec3e

Verification: `php vendor/bin/phpunit` exit 0, 1907 tests, 2795 assertions. `bash .jeffy/probes/run-all.sh` exit 0, TOTAL 2271 passed, 0 failed across 28 batteries. `php tools/vendor/bin/phpstan` exit 0. Acceptance strength proved by re-running the same mutation with the fixture in place: the suite now fails, exactly once, on `nodePositionsAtLineEnd.test`, with `Stmt_Expression[1:7 - 2:0]` becoming `[1:7 - 1:15]`. Nothing else in the suite reacts, which is the point - the new fixture is the only detector that shape has.

The fixture is a `!!positions` case over three node shapes whose last token carries a terminator or spans lines: a statement closed by `?>` plus a newline, an inline-HTML block ending in a newline, and a heredoc assignment. Two of those are the discriminating ones; the heredoc is there because A1 named it. The enumeration behind the finding still returns nothing - no other `!!positions` fixture in the corpus contains a close tag - so this is the first.

The fixture records the dumper's output as it stands today, including the `2:0` and `3:0` columns, which is not an endorsement of them. Writing it is what exposed A3.

A3 filed while executing this task. `NodeDumper::toColumn` is a verbatim copy of the pre-S1 `Error::toColumn`, carrying the comment `// Copied from Error class`, so S1 corrected the original and left the duplicate in place. It reproduces through the real CLI: `php bin/php-parse -c -P` on `<?php $a = 1 ?>` plus a newline plus `inline` prints `Stmt_Expression[1:7 - 2:0]`, a column no 1-based scheme can express, on the line after the byte it names. It is the same class S1 was filed as a structural task for, so it is filed as one Medium whose fix removes the duplication rather than patching the copy.

Two stated numbers in PLAN.md were re-derived and corrected while here: the test and fixture counts, and the error-handling row's claim about "all 647 fixture code chunks", which went stale at iteration 6 when two chunks were appended to a fixture and again here. The count was replaced with the enumeration itself rather than a fresh number, so it cannot drift again.

Learnings: none new this iteration.

Next: the final iteration. A3 is a Medium that fits one iteration and outranks A2, the Low docblock correction, so iteration 10 works A3 and the run ends out of budget with A2 open. Convergence falls to the next run, which starts from a clean tree with a fresh audit and the evaluator gate.

## iter 10/10 | 29e4bbb1-072001 | 2026-08-09 | WRAPUP | done

Task: Final iteration. A3 was attempted and reverted under the verify gate, so this entry closes no task; it re-scopes A3 with what the attempt established and writes the handoff. The run ends out of budget, not converged: the evaluator gate never ran, because the iteration 8 audit filed a Medium and the two iterations after it went to A1 and to this attempt.

Changed: BACKLOG.md (A3 re-scoped), PLAN.md (Lessons), JOURNAL.md. The A3 code change was reverted and is not in this checkpoint.

Checkpoint: 9e0cc3a4ef73926365a4cf450dab479f59bb0dcf

Verification: `php vendor/bin/phpunit` exit 0, 1907 tests, 2795 assertions. `bash .jeffy/probes/run-all.sh` exit 0, TOTAL 2271 passed, 0 failed across 28 batteries. `php tools/vendor/bin/phpstan` exit 0. `bash .jeffy/probes/staleness.sh` exit 0. `bash .jeffy/probes/coverage.sh` 279 of 279. The A3 reproduction ran first and still holds: `php bin/php-parse -c -P` prints `Stmt_Expression[1:7 - 2:0]`.

What the A3 attempt established, which is why it is worth more re-scoped than half-landed. Replacing `NodeDumper`'s copied arithmetic with a call to one shared `Error::posToColumn` does collapse the enumeration to a single implementation site and moves exactly two fixtures, `nopPositions.test#1` and the `nodePositionsAtLineEnd.test` written at iteration 9. But the result on the close-tag statement is `[1:7 - 2:16]`: the column is now right for the byte and the line beside it is still `getEndLine()`, and those two name different lines precisely when the end byte is a terminator. Column 16 does not exist on line 2. That is not an improvement on `2:0`, it is a different wrong answer, so the suite was left red by the change and the change was reverted rather than pinned into the fixtures.

The second fixture is the corroborating one: `Stmt_Nop[3:0 - 3:17]` became `[3:18 - 3:17]`, which is the same empty-range shape its sibling case already records as `[2:14 - 2:13]`. That half of the change is unambiguously right; it is only the line-versus-column pairing that needs deciding.

The decision A3 now carries is concrete: derive both halves of the pair from the file position, which is coherent but scans from the start of the file per node and is therefore quadratic in file size for a large dump, or keep the attribute line and accept the pair as an honest rendering of two different attributes. Removing the duplicated arithmetic is right either way. That is a design call worth an iteration of its own rather than a rushed one at budget exhaustion.

Ledger at handoff: A3 (Medium, runtime) and A2 (Low, runtime, documentation), both with acceptance checks written, both reproducible today. No Proposed items. No blocked items. The Surface inventory has no unswept row; the two unreachable rows, lexer-emulators-forward and token-polyfill, both need a host older than PHP 8.5.

Learnings: A duplicated implementation is not fixed by pointing the copy at the original when the copy's caller combines it with a second source. `NodeDumper` pairs a column from `endFilePos` with a line from `getEndLine()`, so sharing the corrected arithmetic alone moved a column of 0 to a column that does not exist on the line printed beside it.

Next: a fresh session in this directory. The next run's first task is A3, then A2, and with both closed the ledger is empty and a full fresh-evidence audit plus the evaluator gate can close the run. The state files carry it: BACKLOG.md holds both tasks, PLAN.md holds the envelope, the 28-row inventory, the Verify command with its Oracle class and Environment fingerprint, and the Lessons.

## iter 1/10 | abb98afc-123108 | 2026-08-09 | A3 | done

Task: A3 (Medium, runtime, correctness) - `NodeDumper` carried a verbatim pre-S1 copy of the offset-to-column arithmetic, marked `// Copied from Error class`, so S1 corrected the original and left the copy behind. Closed. The filed reproduction ran first and still held: `php bin/php-parse -c -P` over `<?php $a = 1 ?>` plus a newline plus `inline` printed `Stmt_Expression[1:7 - 2:0]`.

Changed: lib/PhpParser/Internal/Columns.php (new), lib/PhpParser/Error.php, lib/PhpParser/NodeDumper.php, test/code/parser/nodePositionsAtLineEnd.test, test/code/parser/nopPositions.test, .jeffy/probes/node-dumper/probe.php, .jeffy/probes/node-dumper/paths, .jeffy/probes/error-handling/paths, .jeffy/probes/error-range-columns/paths, .jeffy/probes/coverage.sh, PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: 5485f3f8fddc9f6ee3c7150c0ed57c634f9b82e0

Verification: `php vendor/bin/phpunit` exit 0, 1907 tests, 2795 assertions. `bash .jeffy/probes/run-all.sh` exit 0, TOTAL 2284 passed, 0 failed across 28 batteries. `php tools/vendor/bin/phpstan` exit 0, no errors. `php tools/vendor/bin/php-cs-fixer fix --dry-run --config=.php-cs-fixer.dist.php` exit 0, 0 of 334 files needing a fix. `bash .jeffy/probes/coverage.sh` 280 of 280.

Acceptance strength proved by restoring the committed `NodeDumper.php` over the fix with `git show HEAD:` after copying the fix aside: the battery fails 8 checks, naming every wrong bracket. The decisive one is the CR-only source, where the committed code prints `[2:15 - 2:16]`, `[3:23 - 3:24]` and the rest counted from the start of the file, because its `strrpos` searched only for `"\n"`; the fix prints `[2:1 - 2:2]`, `[3:1 - 3:2]`. Restoring the fix returns 24 passed, 0 failed.

The open decision A3 carried was settled by the code rather than by preference. `ParserAbstract::trimErrorRange` already records the project's position in its docblock: node ranges keep a trailing line terminator because it really is part of the node's source text, while error ranges trim onto a content byte, and `endLine` is then the line after the range. So the dumper pairing a column from `endFilePos` with a line from `getEndLine()` is the documented model, not an incoherence to design away, and the fix is the one A3 called unambiguously right either way - one shared implementation - with the pair left as it is and that reasoning written into `dumpPosition`'s docblock.

The other half of the decision was priced by measurement rather than argued. Across `lib/`, 270 files and 131989 nodes, zero nodes end on a line terminator; across the 531 parseable fixture code chunks, 10 do (5 InterpolatedStringPart, 2 Stmt_HaltCompiler, 2 Stmt_InlineHTML, 1 Stmt_Expression) and 24 start on one (22 Stmt_Nop, 2 InterpolatedStringPart). So the line-versus-column pairing the iteration 10 attempt reverted over is a corner that real source never reaches, while the start-position columns and the CR-only columns it also fixes are wrong on every occurrence. That is what made deriving both halves from the file position - a scan per node, quadratic in file size - the wrong trade.

Two fixtures moved, both derived independently from the raw source before being accepted rather than copied from what the code printed. Line 1 of `nodePositionsAtLineEnd.test` is 15 characters, so its terminator is column 16 and `Stmt_Expression` ends at `2:16`; line 2 is `inline`, 6 characters, so `Stmt_InlineHTML` ends at `3:7`; line 3 of the `nopPositions.test` block case is 17 characters, so the `Stmt_Nop` that starts on its terminator starts at `3:18`, giving `[3:18 - 3:17]`, the same empty-range shape its sibling case already records as `[2:14 - 2:13]`.

Battery ownership: the diff touches `lib/PhpParser/Error.php` and `lib/PhpParser/NodeDumper.php`, so `error-handling` (26 passed), `error-range-columns` (1818 passed) and `node-dumper` (24 passed) all ran in this iteration and pass. The new file is claimed by all three paths files and by `coverage.sh`, which is why coverage moved from 279 to 280 with none uncovered.

Contract preserved: `Error::getStartColumn` and `getEndColumn` compute exactly what they did before - the arithmetic moved file without changing a byte - and the suite's error-column expectations are unchanged. What changes observably is `NodeDumper` output, and only for a position that lands on a line terminator: those columns were 0 or file-relative and are now the true 1-based column of the byte. `NodeDumper` is a public class, so the rationale is recorded here per the Constraints.

Claims re-executed before the checkpoint: the fixture counts in the Verify command's Oracle class re-derived as 283 total, 180 parser, 71 prettyPrinter, 32 formatPreservation, all unchanged; the test count still 1907; the settled-class line naming `Error::toColumn` corrected to name the arithmetic rather than the moved symbol; the superseded Lesson about pointing a copy at the original rewritten, because this iteration did exactly what it warned against and was right to.

Learnings: When two attributes rendered side by side disagree, look for a decision the project already recorded in the code before designing one. Price a rendering decision by measuring how often each case occurs in real input before choosing between designs.

Next: A2 (Low, runtime, documentation), the `trimErrorRange` docblock promising a postcondition the method does not always establish. With it closed the ledger is empty, and a full fresh-evidence audit plus the evaluator gate can close the run with 7 iterations still in hand.

## iter 2/10 | abb98afc-123108 | 2026-08-09 | A2 | done

Task: A2 (Low, runtime, documentation) - the docblock on `ParserAbstract::trimErrorRange` promised a postcondition the method does not always establish, saying an error range "stops at the last content byte instead" when a range holding no content byte at all keeps its bytes and corrects only endLine. Closed. The filed reproduction ran first and still held: `grep -c "stops at the last content byte" lib/PhpParser/ParserAbstract.php` returned 1.

Changed: lib/PhpParser/ParserAbstract.php, PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: 1c3cea4dfe17483b08f73e4bda9e485d4c24083c

Verification: `php vendor/bin/phpunit` exit 0, 1907 tests, 2795 assertions. `bash .jeffy/probes/run-all.sh` exit 0, TOTAL 2284 passed, 0 failed across 28 batteries. `php test_old/run.php --no-progress --php-version=7.4 PHP ./data/php-src` exit 0, 14695 files tested. Acceptance: the grep now returns 0 and the docblock states both behaviours.

The two behaviours were driven rather than read off the source before being written down. `<?php switch (1) { ?>` followed by two newlines and `<?php }` gives an error whose whole range is the single newline at 22, reported startLine 2, endLine 2, columns 1..1; the three-newline variant gives 22..24, startLine 2, endLine 4, columns 1..1, each boundary naming its own line; the CRLF variant gives 23..24, startLine 2, endLine 2, columns 1..2, the pair counted as one break. Against those, the ordinary case `<?php $a = ?>` plus a newline and `foo` trims its close tag from 11..13 down to 11..12, giving up the terminator and landing on `?>` at columns 12..13. So the docblock now says the range shrinks onto content when it holds any, and that when it holds none the bytes stay and only endLine is corrected down onto the line its own last byte terminates.

Contract preserved: the change is a comment. No executable byte of `ParserAbstract` moved, which `php vendor/bin/phpunit` and the 1818-check error-range-columns battery both confirm unchanged, and the behaviour the new text describes is already pinned by that battery's three all-terminator cases, which is why it needed no new assertion of its own.

Battery ownership: the diff touches `lib/PhpParser/ParserAbstract.php`, so `parser-grammar` (22 passed), `modern-syntax-roundtrip` (8 passed) and `error-range-columns` (1818 passed) all ran in this iteration and pass.

The parser-grammar row is re-swept at this commit because a path it claims moved. What this re-sweep ran is the row battery, the two cross-cutting batteries above and the 14695-file php-src corpus. It did not re-run the parser regeneration: `kmyacc` is not installed on this host and `KMYACC` is unset, and the regeneration's subjects are unchanged anyway - `git diff --name-only 0b047af1 -- lib/PhpParser/Parser/ grammar/` is empty, so the generated parsers are byte-identical to the ones the sweep at that commit reproduced. The row text records that split rather than implying this sweep repeated the regeneration.

Learnings: none new this iteration.

Next: the ledger is empty and this run has recorded no audit yet, so iteration 3 is a full fresh-evidence audit per the Method. With 8 iterations remaining after this one, a clean audit leaves ample budget to run the evaluator gate the moment the ledger is empty rather than deferring it to a declaration.

## iter 3/10 | abb98afc-123108 | 2026-08-09 | AUDIT | audit

Task: Full fresh-evidence audit, the first of this run, run because the ledger emptied at iteration 2 and this run had recorded no audit. Scores claim the 26 swept rows only; the 2 unreachable rows are named below. Closeout has begun: this audit found zero High and zero Medium in-envelope, so the run stops auditing, works or declines what is on the ledger, and converges.

Changed: BACKLOG.md (B1 and B2 filed), PLAN.md (Lessons), JOURNAL.md.

Checkpoint: 2ce0a9e47be6d8c81a22bc93c747b1522f7c2126

Verification: `php vendor/bin/phpunit` exit 0, 1907 tests, 2795 assertions. `bash .jeffy/probes/run-all.sh` exit 0, TOTAL 2284 passed, 0 failed across 28 batteries. `php tools/vendor/bin/phpstan` exit 0. `php tools/vendor/bin/php-cs-fixer fix --dry-run --config=.php-cs-fixer.dist.php` exit 0, 0 of 334 files. `composer audit` no advisories. `bash .jeffy/probes/coverage.sh` 280 of 280. `bash .jeffy/probes/staleness.sh` exit 0, no stale row.

Fresh evidence beyond the standing gates, aimed at the code this run changed. The pre-run library was materialised as a git worktree at 1d4ed3f2 and driven beside the current one through one harness over every parseable code chunk of all 283 fixtures, recording every dumped position and every error message with column info: 43005 lines each. Exactly 41 lines differ, and a line-by-line classification of the difference says every one of them is a column of 0 becoming a real column with both line numbers unchanged, with zero error lines changed anywhere. That is the whole blast radius of the run, measured rather than argued: node dumps gained real columns where they printed 0, and error reporting is byte-identical.

The user-visible half was driven end to end through the real CLI. `php bin/php-parse -c -P` over a CR-only source now prints `[2:1 - 2:7]` and `[3:1 - 3:7]`; the pre-run library prints `[2:15 - 2:21]` and `[3:23 - 3:29]` for the same bytes, columns counted from the start of the file because its search looked only for `"\n"`.

Testing was checked in isolation before being scored: NodeDumperTest, ErrorTest, CodeParsingTest, PrettyPrinterTest and LexerTest each run alone exit 0, and the whole suite exits 0 under `--order-by=reverse` and `--order-by=random`, so no order dependence and no leaked state surfaced. The battery added at iteration 1 was re-checked for strength rather than assumed: restoring the committed dumper over it fails 8 checks.

Packaging was checked because this run added a file to a shipped namespace, which is the shape of defect that reaches users as a fatal error rather than a wrong number: `git archive HEAD` contains `lib/PhpParser/Internal/Columns.php`, and no `.gitattributes` export-ignore rule covers it.

B1 came out of measuring rather than assuming the cost of the correctness this run bought. Dumping with positions is about 1.5x slower than the pre-run library at every size tested, and the growth curves match, so it is a constant factor. The cause was isolated in a scratch harness timing three implementations over the same 8668 positions in one process - the pre-run single search at 0.59 ms, the shipped two-search version at 3.55 ms, a version bounding the `"\r"` search to the region after the last `"\n"` at 1.19 ms - with the bounded one agreeing with the shipped one at all 8668 positions. So the finding names a root cause whose fix is verified to recover the cost before it was filed, which is what keeps it a finding rather than a complaint.

B2 is an asymmetric guard in the same helper, found by probing the edges of what this run consolidated: a position past the end throws, a negative position returns column 0. The dumper's behaviour there changed this run, from a `ValueError` out of `strrpos` to an impossible column, while `Error` has returned 0 for it since before the run. It is reachable only from a hand-built node or `Error`, which is the user-error surface: across the corpus all 208 parser errors carry column information and none has a negative file position, which is what caps it at Low and what makes changing it safe.

Scores: performance Low, error handling Low, correctness None, testing None, documentation None, architecture None, code quality None, security None, dependency hygiene None, developer experience None, observability None. UX and accessibility do not apply and are skipped: the only user-facing surface is `bin/php-parse`, a non-interactive developer CLI. The two unreachable rows stand as disclosed, lexer-emulators-forward and token-polyfill, both needing a host older than PHP 8.5.

Nothing was filed inside a settled class without new evidence: B1 and B2 are about the cost and the input guard of the shared helper, not about the line model the terminator class settled, and that helper's code moved this run. Every claim above is a command run in this iteration.

Learnings: Before filing a performance finding, implement the candidate fix in a scratch harness and time it beside the current implementation and a baseline in one process; a slowdown whose proposed fix does not recover it is not a finding.

Next: B1 at iteration 4 and B2 at iteration 5, both Low and both one-iteration fixes with acceptance checks already written. That empties the ledger with 5 iterations left, so the evaluator gate runs at iteration 6 rather than being deferred to the declaration, leaving room to work anything it files.

## iter 3/10 | abb98afc-123108 | 2026-08-09 | ROTATION | rotation

Task: JOURNAL.md reached 513 lines with the audit entry appended, over the 500-line threshold, so the 13 oldest entries moved to JOURNAL-archive.md and the last 10 stayed.

Changed: JOURNAL.md, JOURNAL-archive.md (new).

Checkpoint: 2ce0a9e47be6d8c81a22bc93c747b1522f7c2126

Verification: JOURNAL.md now holds 253 lines and 10 entries, the oldest being iter 4/10 of run 29e4bbb1-072001; JOURNAL-archive.md holds 263 lines and 13 entries; 13 plus 10 is the 23 that were there before the split. The file's preamble stayed in JOURNAL.md and was not counted or moved, because the split was taken only on lines beginning `## iter` followed by a digit. The archive did not exist before this rotation and was created with a two-line header above the first moved entry.

Learnings: none new this iteration.

Next: as recorded in the audit entry, B1 at iteration 4.

## iter 4/10 | abb98afc-123108 | 2026-08-09 | B1 | done

Task: B1 (Low, runtime, performance) - `Internal\Columns::lastLineTerminatorBefore` searched backwards for `"\r"` across the whole prefix before the position, so in any source without a CR byte that search ran to offset 0 on every call. Closed. The filed reproduction ran first and still held: over 8668 positions of a 2000-statement source the single-search baseline measured 0.58 ms, the shipped two-search version 3.14 ms and a bounded version 1.29 ms.

Changed: lib/PhpParser/Internal/Columns.php, .jeffy/probes/node-dumper/probe.php, PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: 2eac7c96395f04baac0c56de2ade4c1a5f8a251a

Verification: `php vendor/bin/phpunit` exit 0, 1907 tests, 2795 assertions. `bash .jeffy/probes/run-all.sh` exit 0, TOTAL 2288 passed, 0 failed across 28 batteries. `php tools/vendor/bin/phpstan` exit 0. `php tools/vendor/bin/php-cs-fixer fix --dry-run --config=.php-cs-fixer.dist.php` exit 0, 0 of 334 files.

The fix changes no output at all, which is the first thing it had to prove. Re-running the audit's corpus driver over every parseable chunk of all 283 fixtures produced 43005 lines byte-identical to the recording made before it.

The obvious form of the fix was wrong and measurement caught it. Bounding the `"\r"` search to the stretch after the last `"\n"` by copying that stretch is 3.3x faster on an ordinary multi-line source, but 2.55x slower on a lone-CR source and 2.81x slower on a source that is one very long line - in both of those there is no preceding `"\n"`, so the copied stretch is the whole prefix. What shipped therefore caps the copy: stretches up to 4096 bytes are copied and searched, longer ones fall back to the unbounded scan the code already did, so no shape is slower than before and the ordinary one is much faster. Across six source shapes - multi-line, one huge line, CRLF, lone CR, a CR run and mixed terminators - the capped version disagrees with the unbounded one at zero positions.

An earlier claim of this run is corrected here. The iteration 3 audit said the slowdown was a constant factor and not a complexity change, on the strength of sources from 7 to 60 KB whose curves matched. That was too small a range to see it. The wasted scan is linear in the prefix, so the cost per call grows with the file: at 38 KB the unbounded search is 1.98x the baseline, at 418 KB it is 16.48x, at 858 KB it is 29.49x. End to end on a realistic 794 KB file, dumping with positions takes 2877.8 ms with the unbounded search this run shipped at iteration 1, 754.5 ms with the fix, against 559.5 ms for the pre-run library - so this run had introduced a 3.8x regression there, not the 1.5x the audit measured at 60 KB, and the fix removes most of it. The residual 1.35x over the pre-run baseline is the price of looking for a lone `"\r"` at all, which is the correctness the pre-run library lacked.

The severity stands at Low and closeout stands with it, which is a judgement worth stating rather than assuming. The rubric sets Medium at a failure, a swallowed error, missing tests, misleading documentation or a vulnerable dependency; this returns correct output on every input and is slow, which the rubric places at Low. Nothing is deferred by that call either way, because the fix landed in this iteration and the evaluator gate still re-checks it independently.

Designing the acceptance check exposed a defect in the check itself. Timed at 60 KB the unbounded reference measured 5.51x, 7.27x, 9.17x and then 2.17x the baseline across four runs, a spread wide enough to make the assertion fail at random in later runs. The answer was to make the effect large rather than the measurement tight: the battery now times all three implementations round robin over an 858 KB source, where the unbounded reference sits near 26x and the shipped one near 2x, and asserts the shipped one stays under 4x while the unbounded one exceeds 8x. Five consecutive runs pass; with the committed helper restored over the fix the battery fails on the shipped-implementation assertion at 25.97x, which is the acceptance proved able to fail.

Contract preserved: `Columns::toColumn` returns what it returned for every input, proved by exhaustive equivalence at every position of 14 sources including empty, bare-terminator, CRLF-pair and CR-run cases, by the 1818-check error-range-columns battery, and by the byte-identical corpus output above. No public signature or documented behaviour changed, so no Surface inventory row flips for a contract change; the two rows claiming this file are re-swept below because its code moved.

Battery ownership: the diff touches `lib/PhpParser/Internal/Columns.php`, claimed by the `node-dumper`, `error-handling` and `error-range-columns` paths files, and all three ran in this iteration - 28, 26 and 1818 checks, all passing.

Learnings: Measure a performance claim across a range of input sizes before characterising it; a cost that is linear per call hides inside the noise at one size. When a timing assertion is unstable, enlarge the effect rather than tighten the measurement.

Next: B2 at iteration 5, the negative-position guard, which is the last item on the ledger. That empties it with 5 iterations left, so the evaluator gate runs at iteration 6 rather than being deferred to the declaration.

## iter 5/10 | abb98afc-123108 | 2026-08-09 | B2 | done

Task: B2 (Low, runtime, error handling) - `Internal\Columns::toColumn` rejected one out-of-range side and not the other, throwing for a position past the end of the code while a negative position fell through and returned column 0. Closed. The filed reproduction ran first and still held: a node given a `startFilePos` of -1 dumped as `Stmt_Expression[1:0 - 1:8]`, and `Error::getStartColumn` returned 0 for the same.

Changed: lib/PhpParser/Internal/Columns.php, lib/PhpParser/Error.php, .jeffy/probes/node-dumper/probe.php, BACKLOG.md, JOURNAL.md.

Checkpoint: 23abeca039fffcf6b9a7cc93aaca7f0b9161566b

Verification: `php vendor/bin/phpunit` exit 0, 1907 tests, 2795 assertions. `bash .jeffy/probes/run-all.sh` exit 0, TOTAL 2297 passed, 0 failed across 28 batteries. `php tools/vendor/bin/phpstan` exit 0. `php tools/vendor/bin/php-cs-fixer fix --dry-run --config=.php-cs-fixer.dist.php` exit 0, 0 of 334 files. Acceptance: the battery drives both public routes into the arithmetic - the dumper and `Error::getStartColumn` - at -1, -100 and PHP_INT_MIN, asserting each raises `Invalid position information`, and it fails 6 ways with the committed guard restored over the fix.

The guard now reads `$pos < 0 || $pos > strlen($code)`, so both sides raise the message the past-the-end side already raised. Three positions that must keep working are asserted alongside it and do: 0, the length itself - which is legal, because an end position may sit one past the last byte - and every position the corpus produces.

This changes public behaviour, so the rationale is recorded here per the Constraints. `Error::getStartColumn` and `getEndColumn` return a column for a negative recorded position today, which is column 0, a value no 1-based scheme can produce and which no caller can act on. The surface is user-error, where the envelope asks for a clear failure message rather than a wrong value, and `testInvalidPosInfo` already pins exactly that message for the other side, so the change makes the pair symmetric rather than inventing a convention. It is safe to make: across the fixture corpus all 208 parser errors carry column information and none has a negative file position, no test pins the old return, and the whole 43005-line corpus recording is byte-identical after the change. Only a hand-built node or a hand-built `Error` can reach it. Both `Error` methods and `Columns::toColumn` gained an `@throws` line naming the new case, so no documentation now contradicts the code.

Battery ownership: the diff touches `lib/PhpParser/Internal/Columns.php` and `lib/PhpParser/Error.php`, claimed by the `node-dumper`, `error-handling` and `error-range-columns` paths files; all three ran here at 37, 26 and 1818 checks and pass.

One self-inflicted defect was caught and fixed inside the iteration. The B1 timing loop introduced at iteration 4 used `$p` as its loop variable, which is the battery's parser, so the new B2 block died with a fatal error on first run rather than reporting anything. The loop variable is now `$perfPos`. It is worth noting because the battery had passed five consecutive times at iteration 4 while carrying it: nothing after that point in the file used `$p`, so the clobber was invisible until something did.

Learnings: none new this iteration.

Next: the ledger is empty. Five iterations remain, so the evaluator gate runs at iteration 6 rather than being deferred to the declaration, which leaves budget to work whatever a REJECT files.

## iter 6/10 | abb98afc-123108 | 2026-08-09 | EVALUATOR | audit

Task: Evaluator gate, invocation 1 of this run, run here rather than at the declaration because the ledger emptied at iteration 5 with the iteration 3 audit already on record and 4 iterations still in hand. Verdict REJECT. Three reasons, all substantiated, filed as C1 and C2; the run continues.

Changed: BACKLOG.md (C1 and C2 filed), .jeffy/evaluator/abb98afc-123108-1.md (the gate's artifact), JOURNAL.md.

Checkpoint: fb4c78c816cecce05d5f43ed7f2596a5dfdf2cda

Verification: Evaluator: REJECT, three reasons - the dumped end position naming a byte the node does not contain, A3's acceptance check never asserting the property it was filed to assert, and B1's fallback branch being unexecuted by every gate. The gate's own re-runs were all green and none of them is a reason: `php vendor/bin/phpunit` exit 0 at 1907 tests, `bash .jeffy/probes/run-all.sh` exit 0 at 2297, coverage 280 of 280, staleness exit 0, phpstan exit 0, php-cs-fixer exit 0, the php-src corpus exit 0, the timing assertions stable over 13 runs including 5 under full-core load, the bounded column path matching an unbounded reference at 494268 positions with 0 mismatches, and B2's new throw unreachable through the parse path across 11185 nodes and 208 errors. The artifact records 41 commands with their exit statuses.

The first reason was reproduced here before being filed, and it is worse than the gate's own example. On an ordinary five-line template the dumper prints `Stmt_InlineHTML[4:1 - 5:12]`; line 4 is `<p>body</p>` and the node's last byte is the newline that ends it, while line 5 column 12 is the `;` of `endif;`. The printed pair names a real byte belonging to a different statement. Before this run the same node printed `5:0`, which no 1-based scheme can produce and which therefore announced itself as broken.

That falsifies the reasoning this run used at iteration 1. The measurement behind it counted nodes ending on a line terminator across `lib/` and found zero in 131989, and concluded the case was one real source never reaches. `lib/` is pure PHP and contains no inline HTML at all, so the measurement could not have found one; templates are where these nodes live, and they are ordinary input. The decision that followed from it - that the mismatched pair is the documented model rather than a defect - does not survive, and the previous run's iteration 10, which reverted a fix for exactly this reason, was right to.

The second reason is the same root cause seen from the test side and is filed with it as one task: the acceptance check written at iteration 1 builds its expected bracket from `getEndLine()` paired with a column derived from `endFilePos`, which is the implementation's own pairing, so it asserts that the dumper agrees with itself and can never fail on the property A3 asked for. A check that mirrors the code it checks is not a check. C1 therefore carries an acceptance built from the source text alone.

The third reason is separate and is C2. The `$span > CR_SEARCH_LIMIT` fallback added at iteration 4 is dead to every gate: verified here independently, the longest line under `test/code` is 168 bytes and under `lib/` is 477, against a limit of 4096, so no test input can reach the branch. Long lines are real input, though the count differs from the gate's: 15 files under `data/php-src` carry a line over 4096 bytes, not 53, and the smaller number is the one used in the filed task.

The gate's recorded observation is accepted rather than argued with: this run deleted the Lesson warning that sharing the arithmetic alone "moved a column of 0 to a column that does not exist on the line printed beside it" and replaced it with one asserting that pairing is the documented model. The reproduction above is exactly the outcome the deleted Lesson described. Correcting that Lesson, the `dumpPosition` docblock and the Settled-classes line that repeats the claim is part of C1 rather than a separate task, because all three state the same conclusion.

Invocation budget: this gate landed at iteration 6, after the midpoint of a 10-iteration budget, so the cap is 2 and one invocation remains. It has to be spent in the iteration that declares, because a PASS does not carry forward. C1 takes iteration 7 and C2 iteration 8, leaving iteration 9 for the re-invocation and the declaration and iteration 10 as slack.

Learnings: A measurement that finds zero occurrences is only as good as the corpus it searched. Counting inline-HTML-terminated nodes across `lib/` found none because `lib/` is pure PHP, and the conclusion drawn from that zero was wrong for every template.

Next: C1 at iteration 7 - derive both halves of the dumped position from the file position, with a line index built once per dump so the change stays linear.

## iter 7/10 | abb98afc-123108 | 2026-08-09 | C1 | done

Task: C1 (Medium, runtime, correctness) - the first two reasons of the evaluator's REJECT, filed as one task because they share a root cause: `NodeDumper::dumpPosition` paired a line from `getEndLine()` with a column from `endFilePos`, so a node ending at a line terminator printed a position naming a byte it does not contain, and the acceptance check written for A3 could not detect it because it built its expected value from the same mismatched pair. Closed. The filed reproduction ran first and still held: the five-line template dumped `Stmt_InlineHTML[4:1 - 5:12]`, where line 5 column 12 is the `;` of `endif;`.

Changed: lib/PhpParser/NodeDumper.php, test/code/parser/nodePositionsAtLineEnd.test, .jeffy/probes/node-dumper/probe.php, PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: b352b50f8d6d752f581f770f447940962767c9b1

Verification: `php vendor/bin/phpunit` exit 0, 1907 tests, 2795 assertions. `bash .jeffy/probes/run-all.sh` exit 0, TOTAL 2307 passed, 0 failed across 28 batteries. `php tools/vendor/bin/phpstan` exit 0. `php tools/vendor/bin/php-cs-fixer fix --dry-run --config=.php-cs-fixer.dist.php` exit 0, 0 of 334 files. Driven end to end through the real CLI, `php bin/php-parse -c -P` on the template now prints `Stmt_InlineHTML[2:1 - 2:15]` and `[4:1 - 4:12]`, each naming its own line's terminator.

When the code is available both halves of a printed position now come from the file position; without it the dump is lines only, from the attributes, exactly as before. The line is found without scanning: the column already counts from the start of its line, so `$pos - $column + 1` is that line's first byte, and a map from line-start offset to line number is built once per `dump()` and looked up. That map is the only new state and it is reset per call.

The acceptance check was rebuilt so it cannot mirror the implementation, which was the evaluator's second reason. Expected brackets are now derived from the source text and the node's file positions alone, with no reference to `getStartLine()` or `getEndLine()`, and a second assertion runs the other way: every printed `line:column` is resolved back to a byte offset through an independently written line scan, and the multiset of results must equal the multiset of file positions the nodes carry. Against the committed dumper the battery fails 6 ways across three sources; with the fix it passes. A third assertion guards the new lookup itself rather than its output, asserting over every position of 14 mixed-terminator sources that `$pos - $column + 1` always lands on a real line start, because a position where it did not would be a missing key rather than a wrong number.

Blast radius, measured rather than asserted. Against the recording made before this fix, the whole 283-fixture corpus moves 16 dump lines, every one an end line corrected downward, with every column and every start line unchanged and zero error lines changed. Against the pre-run library the run now totals 41 changed dump lines and still zero changed error lines. One fixture moved, `nodePositionsAtLineEnd.test`, whose two cases are exactly the shape this task is about; the values were derived from the raw source before being accepted, line 1 being 15 bytes so its terminator is column 16 of line 1, and line 2 being `inline` so its terminator is column 7 of line 2.

Performance was checked because C1's fix could have undone B1's. The first implementation binary searched a line-start array and cost 25 to 30 percent over the previous dumper on a 794 KB file; replacing the search with the offset lookup described above brought that to about 5 percent, measured by alternating the three libraries in one loop across three rounds. That is the price of the correction and it is far below what B1 removed.

Contract preserved: no public signature changed, and the no-code dump is byte-identical. What changed observably is the line printed beside a column when a position sits on a line terminator, which is the defect. The `dumpPosition` docblock now states that both halves come from the file position and why, replacing text that presented the mismatch as intentional.

Three prose claims this run wrote and this task falsifies were corrected rather than left standing: the PLAN.md Lesson asserting the pairing was the documented model, the Lesson citing the `lib/`-only measurement as the reason the case was a corner, and the Settled-classes line for the duplicated-arithmetic class that repeated the same conclusion. The settled class itself stands - it is about one implementation of the arithmetic, which is still true - and its line now records C1 as the separate defect it was.

Learnings: Two numbers printed side by side are read as one position, so derive both from one source. An impossible value is cheaper than a plausible wrong one: the dumper printed column 0 before it printed a wrong column, and only the first announced itself.

Next: C2 at iteration 8, the untested `CR_SEARCH_LIMIT` fallback branch. Then the second and last evaluator invocation at iteration 9, which must declare in the same iteration if it passes.

## iter 8/10 | abb98afc-123108 | 2026-08-09 | C2 | done

Task: C2 (Medium, test, testing) - the third reason of the evaluator's REJECT: the `$span > self::CR_SEARCH_LIMIT` fallback that B1 added to `Internal\Columns::lastLineTerminatorBefore` was executed by nothing. Closed. The filed reproduction ran first and still held: with that branch mutated to return -1, `php vendor/bin/phpunit` stayed at OK with 1907 tests and `bash .jeffy/probes/run-all.sh` at TOTAL 2307 passed, 0 failed.

Changed: .jeffy/probes/node-dumper/probe.php, BACKLOG.md, JOURNAL.md.

Checkpoint: e59dd53d87cdc6d1eec4ca005b97d2d9dde03c15

Verification: `php vendor/bin/phpunit` exit 0, 1907 tests, 2795 assertions. `bash .jeffy/probes/run-all.sh` exit 0, TOTAL 2307 passed, 0 failed across 28 batteries. `php tools/vendor/bin/phpstan` exit 0. `php tools/vendor/bin/php-cs-fixer fix --dry-run --config=.php-cs-fixer.dist.php` exit 0, 0 of 334 files. `bash .jeffy/probes/coverage.sh` 280 of 280. `bash .jeffy/probes/staleness.sh` exit 0.

Five sources were added to the battery's exhaustive equivalence sweep, all with a stretch longer than the 4096-byte limit since their last newline. Four of them put a real line terminator before that stretch, which is the part that matters: a source with no terminator anywhere answers -1 from both paths and would pass a completely broken fallback, so it proves nothing on its own and is present only as the degenerate member. Two straddle the limit exactly, one with a `"\r\n"` pair across it, so the boundary itself is a tested position rather than an untested edge.

The branch is now executed, counted rather than assumed. Instrumenting the two paths and running the battery reports 53532 executions of the copied-stretch path, 8614 of the scanning fallback and 12 at a span of exactly 4096. The same instrumentation against the previous battery reports 0 fallback executions out of 12162, and against the whole test suite 0 out of 498, which is the finding reproduced as a number.

Acceptance: with the same mutant reinstalled, the battery now fails, reporting that 2401 of 26570 swept positions disagree with the unbounded reference; restoring the real implementation returns 47 passed, 0 failed. So the branch is not merely reached, it is pinned - a wrong answer from it is now caught.

No library code changed this iteration, so no Surface inventory row went stale and the dumper's own behaviour is untouched. The battery still runs in about 0.17 seconds despite sweeping 26570 positions, so nothing was traded for the coverage.

This iteration changed only a file under `.jeffy/`, but it is not a stall: C2 moved out of the Now section, which is a ledger state change.

Learnings: A boundary constant creates two paths, and the corpus that exercises one may be unable to reach the other. Prove the second path runs by counting its executions, and prove it is pinned by mutating it, because a branch that is reached but unasserted fails the same way as one that is never reached.

Next: iteration 9 spends the run's last evaluator invocation. Both REJECT findings are closed and the ledger is empty, so if that gate passes, the declaration happens in the same iteration, since a PASS does not carry forward.

## iter 9/10 | abb98afc-123108 | 2026-08-09 | EVALUATOR | converged

Task: Evaluator gate, invocation 2 and the last this run may spend, followed by the declaration in the same iteration because a PASS does not carry forward. Verdict PASS. The run converges.

Changed: .jeffy/evaluator/abb98afc-123108-2.md (the gate's artifact), BACKLOG.md (the Converged line), JOURNAL.md.

Checkpoint: 6574f88081c2bf0f115d8e52aea710c0f2dffe4e

Verification: `php vendor/bin/phpunit` exit 0, 1907 tests, 2795 assertions, run in this iteration before the gate and again by the gate. Evaluator: PASS - the gate reproduced all three fixes it had rejected at invocation 1 and found nothing new, recording 47 passed in the dumper battery, TOTAL 2307 passed across 28 batteries, coverage 280 of 280, staleness all fresh, phpstan clean, php-cs-fixer 0 of 334, and `php test_old/run.php` exit 0 over 14695 files. Its artifact is `.jeffy/evaluator/abb98afc-123108-2.md` and this iteration's checkpoint commits it.

What the gate verified against the code rather than against this journal is what makes the PASS worth having. The `toLine` lookup key was never missing across 30921 random positions, 1074889 synthetic positions straddling the 4096 boundary with every terminator shape, and 225536 real node positions from `data/php-src`; hand-built nodes at every position of nine pathological sources dump cleanly, with only the past-the-end case throwing, as before the run. An independent derivation of every dumped position over the whole fixture corpus - 11077 nodes across 642 chunks - found 0 mismatches. Reusing one `NodeDumper` instance across three sources in three orders is byte-identical to fresh instances, so the line map does not go stale between calls. The claim that no error output changed was checked end to end at three PHP versions over 783 error records covering raw message, both lines, both columns and both formatted messages: 0 of 783 differ from the pre-run library. And C2 was checked by instrumentation, not by its own assertion: the fallback executes 8614 times under the battery and a mutant in it makes both the battery and `run-all.sh` fail.

The declaring iteration re-read the Verify command's Oracle class and Environment fingerprint and re-derived their claims rather than trusting them: the suite still has the single root `./test/`, the same two skip guards in `LexerTest` and `BuilderHelpersTest` neither of which fires on PHP 8.5.4, the same entry points outside the suite, the fixture counts still 283 total with 180, 71 and 32 in the three directories, and forward token emulation still selecting 0 emulators on this host. Nothing this run claimed was green sits behind an exclusion the fingerprint names.

Closing conditions, each checked in this iteration: the iteration 3 full fresh-evidence audit scored zero High and zero Medium in-envelope; the Surface inventory lists no unswept row, 27 swept and 2 unreachable; Now, Next and Later are empty, with every filed finding completed and none declined or blocked; the only commits since that audit are the fixes for the two tasks it filed, the gate entry, the fixes for the two tasks the gate filed, and bookkeeping; the Verify command is green here; and the gate returned PASS.

The gate recorded four observations that are not REJECT reasons. Per the closing rule they are not fixed inside the convergence sequence, because a fix after a PASS invalidates it; they go to the run report and to the next run. They are: a Surface inventory row that says six sources where the battery now sweeps seven, a pair of blast-radius counts in earlier entries of this journal that reproduce as 20 and 50 rather than 16 and 41 under a different fixture extraction while the qualitative claim holds exactly either way, the fact that `php vendor/bin/phpunit` alone still does not reach the CR_SEARCH_LIMIT fallback which only the battery covers, and a stale `.git/worktrees/prerun` registration left by this run's own differential experiments, which is untracked git admin state affecting no clone.

Learnings: none new this iteration.

Next: the run is converged. The next run starts from a clean tree with the four gate observations as its first material.
