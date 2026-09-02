# Journal archive

Entries rotated out of JOURNAL.md, oldest first. Appended to, never rewritten.

## iter 1/10 | 8bd0ee5e-173008 | 2026-09-02 | AUDIT | audit

Task: First audit of a fresh Jeffy project on league/csv 9.x. Fill the Operating envelope, enumerate the artifact-producing channels, fill the Verify command block, build the Surface inventory, probe every row shallowly, and file findings.

Changed: PLAN.md (envelope surfaces, 22 Surface inventory rows, Verify command block, 4 Lessons), BACKLOG.md (7 findings), JOURNAL.md, .gitignore (loop state file).

Checkpoint: 8be69e5f008bb30785e115a636ed587972f820d5

Verification:
- Envelope: 11 input surfaces enumerated and classified. CSV document content, written field values, RFC 7111 fragment identifiers and Schema sample values are adversarial; factory arguments, control characters, callbacks, encoding names, serializer attribute metadata and the HttpHeaders filename are user-error; RDBMS result objects are machine-generated. The package has no network endpoint, CLI, environment or config surface - it declares no `bin` in composer.json.
- Artifact channels, enumerated by command rather than recall: `ls package.json Cargo.toml MANIFEST.in pyproject.toml Dockerfile *.gemspec *.nuspec` finds none, and `grep -n "release\|publish\|archive\|upload" .github/workflows/*.yml` finds no publishing step. The single channel is the Packagist dist tarball, built with `git archive` semantics honouring `.gitattributes`. That channel FAILS the check: `git check-attr export-ignore -- PLAN.md BACKLOG.md JOURNAL.md JOURNAL-archive.md .jeffy/probes/x` reports `unspecified` for all five, so the loop's state files would ship inside the published package once a checkpoint commits them. Filed as CSV-7 at Medium with its Consequence.
- Verify command: `vendor/bin/phpunit --no-coverage`, run through quiet-verify.sh. It is RED at this checkpoint, exit 1 in 0s, with exactly three failures, all in StreamTest, all asserting UnavailableFeature on a stream the test assumed was non-seekable. Root cause reproduced both ways: under a pipe the same filter run reports `OK (19 tests, 27 assertions)`; with stdout redirected to a regular file the three fail, because STDOUT is then seekable. The wrapper redirects to a regular file, so the gate stays red until CSV-5 lands. Verify count is therefore left empty - the wrapper has produced no green line to copy a total from, and a typed number is not a measurement.
- Static gates are green on this tree and are this run's baseline: `vendor/bin/phpstan analyse -c phpstan.neon` exits 0 with "No errors", `vendor/bin/php-cs-fixer fix --dry-run --allow-risky=yes` exits 0 with "Found 0 of 161 files that can be fixed".
- Test isolation, per the Method's rule before scoring Testing: `--filter BomTest` alone reports `OK (16 tests, 30 assertions)` and `--filter SchemaTest` alone reports `OK (13 tests, 17 assertions)`. No order dependence surfaced.
- Shallow breadth-first probe over all 22 inventory rows, four known-answer scripts under /tmp: probe1 23/24, probe2 partial, probe3 diagnostic, probe4 17/18. The two non-passing checks were both defects in my probe (wrong FragmentFinder argument order, and HttpHeaders::forFileDownload is `@internal`, returns void and takes a filename string rather than a Reader), not in the library. The genuine failures that survived re-checking are the seven filed findings.
- Every filed acceptance check was run against the unfixed code and observed to fail: CSV-1 exit 1, CSV-2 exit 1, CSV-4 exit 1, CSV-3 grep finds 2 sites, CSV-6 grep finds 1 site, CSV-7 reports 5 paths not set, CSV-5 is the red verify above.

Scores (this audit claims the shallow probe across all 22 rows and nothing deeper; zero rows are swept, so every None below is silence on unprobed depth, not cleanliness, and this entry is not a convergence-grade full audit):
- correctness: Medium - CSV-1.
- documentation: Medium - CSV-2, CSV-3, CSV-4, CSV-6.
- dependency hygiene: Medium - CSV-7.
- testing: Low - CSV-5.
- security: None on what was probed. EscapeFormula escape/unescape round-trips correctly on the `=` prefix and leaves plain fields untouched; no injection path surfaced at this depth.
- architecture, code quality, error handling, performance, observability, developer experience: None on what was probed.
- UX and accessibility: not applicable - the package is a library with no user-facing surface and no executable entry point.

Learnings: The verify gate is red for an environment reason, not a product one, and the two readings are distinguished only by what stdout is attached to; any future iteration reading a red gate must check whether the failures are the three StreamTest cases before concluding it broke something. Probe scripts must use the non-deprecated constructors or their real output drowns in deprecation notices.

Next: The queue's top is the Surface inventory - 0 of 22 rows swept, no open High. Iteration 2 starts sweeping rows with known-answer batteries under .jeffy/probes/, beginning with the rows carrying the filed findings (schema-core, info-functions, markup-conversion, charset-escape) so the sweep and the fixes reinforce each other.

## iter 2/10 | 8bd0ee5e-173008 | 2026-09-02 | SWEEP | done

Task: Sweep Surface inventory rows. The queue's top was the map - no open High, 22 unswept rows - so this iteration built known-answer batteries and swept every row it could properly evidence.

Changed: .jeffy/probes/_harness.php (new shared assertion harness), .jeffy/probes/{csv-core,reader,writer,statement-resultset}/ (run.php, paths, claims, README.md each), PLAN.md (4 rows flipped), BACKLOG.md (CSV-8 filed), JOURNAL.md.

Checkpoint: 9217d0477c050a7e5896cf7d7f58c495fe826855

Verification:
- Four rows swept, each by an executed battery run through run-probe.sh, none by a run-without-crash probe: csv-core 78/78, reader 65/65, writer 47/47, statement-resultset 55/55. Every battery carries a paths file, a claims line the hook can execute, and a README naming what it grades.
- Every battery was observed failing before it was trusted, each against a mutation applied to the real source and then reverted, with git diff confirming the revert: Bom::length() forced to the constant 3 reddens the csv-core length family; Reader::nth() forced to 0 reddens five checks across the positional family; Writer::setEndOfLine() forced to "\n" reddens the end-of-line family including its live-parameter check; Statement::limit() forced to -1 reddens nine checks across four families. Each mutant exited 1 and each restored tree returned to its full green count.
- Documented parameters were exercised at two or more values that must change the output, per the sweep rule, not merely called: delimiter, enclosure, escape, output BOM, input BOM mode, chunk length, open mode, header offset, column index, slice offset and length, chunkBy size, empty-record mode, end-of-line, enclosure policy, flush threshold, column-consistency width, comparison operator, offset, limit, sort direction and the when condition. Invariants carry the families where a literal answer would be weak: chunk and chunkBy reassembly, the write-then-read round trip over six awkward records, select and selectAllExcept as complements, whereNot as a complement, eq and neq as a partition, asc and desc as reverses.
- New finding, surfaced by the statement-resultset sweep and filed at rubric severity in this same iteration: CSV-8, High. `ResultSet::fetchColumn()` and `fetchPairs()` return an empty iterator on a directly constructed `new ResultSet($records, $header)`. Root cause read from the source: both filter the raw constructor records with `isset($record[$offset])` where `$offset` is the header column name, but those records are still positional lists at that point - the header mapping is applied later, in getRecords(). Reproduced on the library's own ResultSetTest::tabularDataWithHeader() fixture shape, where count() reports 2 and getRecords() returns both mapped records while fetchColumn('place') and fetchPairs('date','place') both return nothing. The suite never sees it because every fetchColumn and fetchPairs test runs a Statement over a Reader, whose records are already mapped. The acceptance check was run against the unfixed code and exits 1.
- The two assertions that would pin CSV-8 are knowingly absent from the statement-resultset battery, and the README says so: a battery that fails on an open finding would be read as a broken Verify by every later iteration. The battery does assert both methods on a ResultSet::from() over a Reader, where they work, so the contrast that isolates CSV-8 is on the record.
- Verify: still red, exit 1, the same three StreamTest failures and nothing else, unchanged from the iteration 1 checkpoint. Nothing this iteration touched src/, so the gate could not have moved; the mutation probes were each reverted and `git status --porcelain` showed no src/ path before the checkpoint.
- No stall: four Surface inventory rows changed state and one BACKLOG.md item was added.

Learnings: A battery must be observed failing against a real mutation of the code it pins, not merely written and seen green - three of the four batteries here contain a live-parameter check that exists only because the mutation walked past the literal assertion beside it. When a sweep surfaces a finding, the battery pins the surrounding correct behaviour and leaves the defect to the finding's own acceptance check, or the battery becomes a permanent red that later iterations must reason around.

Next: CSV-8 is an open High, so it outranks the remaining 18 unswept rows. Iteration 3 fixes CSV-8 and moves its two assertions into the statement-resultset battery.

## iter 3/10 | 8bd0ee5e-173008 | 2026-09-02 | CSV-8 | done

Task: CSV-8 (High) - ResultSet::fetchColumn() and fetchPairs() return an empty iterator on a directly constructed ResultSet carrying a header.

Changed: src/ResultSet.php (three read sites), .jeffy/probes/statement-resultset/ (run.php, claims, README.md), PLAN.md (Lesson, row re-recorded), BACKLOG.md (CSV-8 deleted), JOURNAL.md.

Checkpoint: d7c74492a6aa6454d6514d423acd71951e0c28b3

Verification:
- The filed reproduction was the first command of the iteration and exited 1, as filed. After the fix the acceptance check exits 0.
- Root cause, read from the source rather than guessed: yieldColumn() and fetchPairs() filtered $this->records with isset($record[$offset]) where $offset is the header column name, but $this->records holds the constructor's records untouched - positional lists in the direct-construction case. The header is only applied by combineHeader(), which getRecords() calls. A ResultSet built from a Reader is handed records that are already header-mapped, which is why that shape always worked.
- Class fix, not instance patching. The idiom is a read of $this->records where header-mapped records are required, and the enumeration is `grep -n 'this->records' src/ResultSet.php`. It returned seven sites before the fix. Three were the defect - yieldColumn, fetchPairs, and jsonSerialize, which returned raw positional records while getRecords() on the same object returned mapped ones - and all three now read getRecords(). The remaining four are settled as correct: the constructor assignment and the destructor unset are not reads, combineHeader is the mapper itself and must read raw, and count() counts rows, which the mapping preserves one-to-one. That last one is not left as an assertion: the battery cross-checks count() against iterator_count(getRecords()) on both construction shapes, which is what licenses count() to keep reading raw records.
- The contract the change preserves: docs/9.0/reader/tabular-data-reader.md documents Reader and ResultSet as offering the same TabularDataReader surface, and Reader::jsonSerialize() already read getRecords(). The fix moves ResultSet onto the contract its sibling already implements rather than inventing one, so no documentation needed updating - grep over docs/9.0 found no page stating the previous behaviour.
- Differential evidence that the fix altered no previously-passing output: with src/ResultSet.php restored to its pre-fix content from HEAD and the extended battery run against it, exactly five checks went red - fetchColumn by name, fetchColumn by offset, fetchPairs and jsonSerialize on the direct shape, plus the live-header comparison - and every check on the Reader-built shape and on the headerless shape passed both before and after. The fixed file was copied aside first and restored afterwards; no git checkout ran over uncommitted work.
- Scope confirmed rather than assumed: all four RdbmsResult drivers yield associative rows (PDO FETCH_ASSOC, pg_fetch_assoc, mysqli fetch_assoc, SQLITE3_ASSOC), so ResultSet::from() over a database result was never affected. Executed against real SQLite3 and PDO result objects: fetchColumn('label') returned ["x","y"] on both before the fix.
- Battery ownership: the diff touched src/ResultSet.php, which .jeffy/probes/statement-resultset/paths declares. That battery was extended in this same iteration to pin the corrected behaviour and re-run green at 73/73, and its row is re-recorded at this checkpoint. The other three batteries were re-run as a regression check and are unchanged - csv-core 78/78, reader 65/65, writer 47/47 - which matters because Reader delegates nth, fetchColumn and fetchPairs to ResultSet even though its paths file does not name that file. check-claims.sh reports 4 checked, 0 mismatched, 0 errored after the claims line was updated to the new total.
- Verify: exit 1, unchanged from the previous checkpoint - Tests: 1009, Failures: 3, the same three StreamTest cases and no others. The gate was already red for CSV-5 before this iteration, so this is not a break introduced here and no revert applies. phpstan exits 0 with "No errors" and php-cs-fixer exits 0 with "Found 0 of 161 files that can be fixed", both unchanged from the iteration 1 baseline.
- No stall: src/ResultSet.php changed and a BACKLOG.md item was removed.

Closed this run: CSV-8 (High) - ResultSet header mapping applied to fetchColumn, fetchPairs and jsonSerialize; acceptance check exits 0, five battery checks moved red to green, Reader and headerless shapes unchanged.

Learnings: A battery must assert every construction shape of an object side by side; the ResultSet defect was invisible from the Reader-built shape, which is the only shape the project's own fetchColumn tests exercise. When a fix touches a file another battery's surface depends on without declaring it in paths, run that battery anyway and say so - the paths file bounds what the hook can check, not what the change can break.

Next: No open High. The queue's top returns to the map - 18 of 22 rows unswept. Iteration 4 resumes sweeping.

## iter 4/10 | 8bd0ee5e-173008 | 2026-09-02 | SWEEP | done

Task: Sweep Surface inventory rows. No open High at the start of the iteration, so the map was the top of the queue with 18 rows unswept.

Changed: .jeffy/probes/{schema-scalar-fields,schema-core,query-constraint,query-ordering}/ (run.php, paths, claims, README.md each), PLAN.md (4 rows flipped, 1 Lesson), BACKLOG.md (CSV-9 filed), JOURNAL.md. No src/ path changed.

Checkpoint: d76cf740fd89d057f6216a82bb26b5c2e856f9f4

Verification:
- Four rows swept by executed batteries through run-probe.sh: schema-scalar-fields 113/113, schema-core 82/82, query-constraint 81/81, query-ordering 57/57. Inventory now stands at 8 of 22 rows swept, from 4 at the start of this iteration. check-claims.sh reports 8 checked, 0 mismatched, 0 errored.
- Each battery was observed failing against a mutation of the code it pins, applied to the real source and reverted with git diff confirming an empty diff: the min bound removed from NumericField::parse reddens seven checks across four factory families; Schema::remove made to discard its arguments reddens the removal family; Comparison::NotEquals delegated to Equals reddens both != answers and the complement check; Ordering\Column::__invoke made to ignore its direction reddens six checks across the direction and MultiSort families.
- Documented parameters were driven at two or more values that must change the output: every bound factory on NumericField and StringField at boundary and past it, the confidence threshold at both ends of its range, Inspector's sampleLimit at 3 and 4 - chosen so the fourth sample changes the inferred column type from numeric to string rather than only changing an internal count - Inspector's fieldList at default and empty, all sixteen comparison operators, the sort column, direction and comparator, and Limit's offset and length. Invariants carry the families where literals are weak: any and none partitioning the record set, TwoColumns as a trichotomy, asc and desc as exact reverses, five operator complement pairs.
- New finding, surfaced by the query-ordering sweep and filed at rubric severity in this same iteration: CSV-9, High. Query\Limit::slice() passes its arguments to PHP's LimitIterator, which raises OutOfBoundsException when the length is 0 or when it must seek past the end of a seekable inner iterator. The enumeration was built by provoking the failure at each public entry point rather than by grepping for callers: Statement::limit(0), Statement::offset(1)->limit(0), Reader::slice(0, 0), ResultSet::slice(0, 0) on both construction shapes and Query\Limit(0, 0)->slice() over any iterable all raise it; ResultSet::slice(99, -1) on an array-backed ResultSet raises it while the same call over a generator returns nothing, so the iterable's type decides between a crash and an empty result. Statement::offset(4) and Reader::slice(99, -1) are unaffected, and that was verified rather than assumed. The exception is neither QueryException nor League\Csv\Exception, so the package's documented catch blocks do not catch it. Statement::limit validates only >= -1 and Limit::__construct only > -2, so 0 is accepted by the same class that cannot execute it. The acceptance check exercises all seven sites and exits 1 against the unfixed code.
- Two probe expectations were wrong rather than the library: a live-parameter check compared two columns that happened to hold the same value in the row it selected, and Criteria::xany was expected to be a symmetric difference when it selects records matching exactly one predicate. Both were corrected in the probe and the corrected forms are asserted; neither is a finding.
- CSV-1 in schema-core and CSV-9 in query-ordering are knowingly not asserted by their batteries, and both READMEs say so with the reason. Each battery does assert the neighbouring behaviour that isolates the defect - the other two FieldList removers emptying correctly, and the offset and length either side of the Limit boundary.
- Verify: exit 1, unchanged from the previous checkpoint - Tests: 1009, Failures: 3, the same three StreamTest cases. No src/ path changed this iteration, so the gate could not have moved; every mutation was reverted and git diff over src/ was empty before the checkpoint.
- No stall: four Surface inventory rows changed state and one BACKLOG.md item was added.

Learnings: A probe fixture must be built to discriminate the parameter under test - a live-parameter check passes by accident when two columns happen to hold the same value in the row it selects. When a battery's own assertion crashes rather than fails, that is a finding about the product surfacing through the instrument, and the crash trace names the entry point to enumerate from.

Next: CSV-9 is an open High and outranks the 14 remaining unswept rows. Iteration 5 fixes CSV-9.

## iter 5/10 | 8bd0ee5e-173008 | 2026-09-02 | CSV-9 | done

Task: CSV-9 (High) - Query\Limit::slice() raises OutOfBoundsException, a class outside the package's exception hierarchy, on a zero length and on an offset past the end of a seekable iterable.

Changed: src/Query/Limit.php, .jeffy/probes/query-ordering/ (run.php, claims, README.md), PLAN.md (Lesson, row re-recorded), BACKLOG.md (CSV-9 deleted, one Proposed item added), JOURNAL.md.

Checkpoint: 28621112232c2394c6fd983d10cca602c12250cc

Verification:
- The filed reproduction was the first command of the iteration and exited 1, as filed.
- The fix ships narrower than the finding, and that is the substance of this iteration. The first attempt fixed both halves - zero length returning an empty iterator, and the seek defeated by an IteratorIterator wrap - and the verify gate went from 3 failures to 4. The new failure was StatementTest::testIntervalThrowException, which asserts OutOfBoundsException for offset(1)->limit(0). That test pins the zero-length behaviour deliberately, so rewriting it to match the fix would have turned the suite from evidence into decoration. The zero-length half was backed out and filed under Proposed for the maintainer; the fix that shipped is the seek half alone, which no test pins.
- What shipped: slice() wraps its iterator in an IteratorIterator so LimitIterator can never seek. The contract this preserves is the one the package already implemented everywhere else - an offset past the end selects nothing - which Statement::offset(4) and Reader::slice(99, -1) already did because those paths carry a non-seekable iterator, and which ResultSet::nth() reaches by catching this very OutOfBoundsException. Keys are still preserved, as docs/9.0/reader/tabular-data-reader.md requires of slice: Limit(1, 2) over an array returns keys 1 and 2, checked after the change. The public signature is unchanged; slice() still returns LimitIterator.
- Enumeration re-provoked at every site after the change rather than reasoned about: Limit(99,-1) and Limit(4,-1) over an array, an ArrayIterator and a generator, ResultSet::slice(99,-1) on a directly constructed ResultSet, and Reader::slice(99,-1) all return 0 records; Limit(1,2) still returns 2. Statement::limit(0) still raises OutOfBoundsException, unchanged and now pinned by the battery.
- Differential evidence that the change altered no previously-passing output: the query-ordering battery as it stood at the previous checkpoint, 57 checks, runs 57/57 against the fixed code. Against the pre-fix code the extended battery does not merely fail, it aborts at exit 255 with the uncaught OutOfBoundsException on the first array-shaped offset-past-end assertion. The fixed file was copied aside and restored around each run; no git checkout ran over uncommitted work.
- Verify: exit 1 with Tests: 1009, Failures: 3 - the same three StreamTest cases as every previous checkpoint, back from the 4 the first attempt produced. phpstan exits 0 with "No errors". php-cs-fixer flagged the new import ordering in src/Query/Limit.php; it was run in fix mode over that file and now exits 0 with "Found 0 of 161 files that can be fixed".
- Battery ownership: the diff touched src/Query/Limit.php, declared by .jeffy/probes/query-ordering/paths. That battery was extended to 77/77 and its row re-recorded at this checkpoint. All eight batteries were re-run green, which matters because Reader, Statement and ResultSet all route their slicing through the changed file without declaring it in their own paths files. check-claims.sh reports 8 checked, 0 mismatched, 0 errored.
- No stall: src/Query/Limit.php changed, one BACKLOG.md item was removed and one Proposed item was added.

Closed this run: CSV-9 (High) - offset past the end now selects nothing over every iterable shape rather than raising OutOfBoundsException over seekable ones; the zero-length half is deferred to Proposed with its pinning test named.

Learnings: When a fix turns a green test red, read that test before touching it - if it deliberately asserts the behaviour being changed, narrow the fix to the part no test pins and send the rest to Proposed. A finding with two manifestations of one root cause can need two different dispositions, and closing it wholesale would have meant either a rewritten test or an unfixed divergence.

Next: No open High. The map is the top of the queue again with 14 of 22 rows unswept and 5 iterations left. Iteration 6 resumes sweeping.

## iter 6/10 | 8bd0ee5e-173008 | 2026-09-02 | SWEEP | done

Task: Sweep Surface inventory rows. No open High at the start of the iteration, so the map was the top of the queue with 14 rows unswept.

Changed: .jeffy/probes/{charset-escape,json-conversion,markup-conversion}/ (run.php, paths, claims, README.md each), PLAN.md (3 rows flipped, 1 Lesson), BACKLOG.md (CSV-10 filed), JOURNAL.md. No src/ path changed.

Checkpoint: 1c69536b7bbb7d9e0ad51f9badee897adfc9ac15

Verification:
- Three rows swept by executed batteries through run-probe.sh: charset-escape 44/44, json-conversion 48/48, markup-conversion 44/44. Inventory now stands at 11 of 22 rows swept, from 8 at the start of this iteration. check-claims.sh reports 11 checked, 0 mismatched, 0 errored.
- Each battery was observed failing against a mutation of the code it pins, applied to the real source and reverted with git diff over src/ confirming an empty diff: EscapeFormula::escapeField() returning the field unprefixed reddens fourteen checks; JsonConverter::depth() forced to 512 reddens both depth-boundary checks; XMLConverter::rootElement() forced to 'csv' reddens six checks across the renaming family.
- Two batteries deliberately assert structure rather than strings. The markup battery parses both converters' output back into a DOM and queries it by XPath, so no assertion can pass on a coincidental substring, and each renamed element is asserted present under the new name, absent under the old, and still carrying its field values - the third check is what a converter that renames elements but drops their contents fails. The charset battery compares transcoded bytes in hex against mb_convert_encoding's own output rather than by eye.
- New finding, surfaced by the charset-escape sweep and filed at rubric severity in this same iteration: CSV-10, High. EscapeFormula::escapeField() reads $strOrNull[0] before checking the string is non-empty, so escaping an empty-string field emits PHP Warning: Uninitialized string offset 0. The sibling unescapeField() already guards the identical read, which is what makes this an oversight rather than a design. Reproduced three ways: directly through escapeRecord(['']), through escapeRecord(['a','','b']) where the warning fires once for the empty field, and through a Writer with the formatter registered, where writing name,,=1 emits it. Under a handler that converts warnings to exceptions the same call throws ErrorException, executed and confirmed. The project's own suite already reports it - vendor/bin/phpunit --display-warnings prints "6 tests triggered 1 PHP warning" naming EscapeFormula.php - so it has been visible in the suite output without failing it. The acceptance check exits 1 against the unfixed code.
- Two probe expectations were wrong rather than the library, and both were corrected in the probe: CharsetConverter::convert() returns an iterable rather than an array, and an unsupported charset raises OutOfRangeException, which the @throws annotation on filterEncoding() states. That second one is worth distinguishing from CSV-9: the same shape of exception outside the package's hierarchy, but documented and not dependent on the argument's type, so it is the contract rather than a defect. The battery now asserts the documented type.
- Verify: exit 1, unchanged from the previous checkpoint - Tests: 1009, Failures: 3, the same three StreamTest cases. No src/ path changed this iteration; every mutation was reverted and git diff over src/ was empty before the checkpoint.
- No stall: three Surface inventory rows changed state and one BACKLOG.md item was added.

Learnings: Run vendor/bin/phpunit --display-warnings when hunting for defects the suite already sees but does not fail on - CSV-10 sat in the suite's own warning output while the exit status stayed at its usual three failures. An SPL exception escaping a package's own hierarchy is only a finding when it is undocumented or type-dependent; CharsetConverter documents its OutOfRangeException in a @throws tag and raises it consistently, so it is a contract, while CSV-9 did neither.

Next: CSV-10 is an open High and outranks the 11 remaining unswept rows. Iteration 7 fixes CSV-10.

## iter 7/10 | 8bd0ee5e-173008 | 2026-09-02 | CSV-10 | done

Task: CSV-10 (High) - EscapeFormula::escapeField() emits PHP Warning: Uninitialized string offset 0 for every empty-string field.

Changed: src/EscapeFormula.php, .jeffy/probes/charset-escape/ (run.php, claims, README.md), PLAN.md (Lesson, row re-recorded), BACKLOG.md (CSV-10 deleted), JOURNAL.md.

Checkpoint: 1ffb2eae5c50b0bb796685f8ab18005c9da6cba9

Verification:
- The filed reproduction was the first command of the iteration and exited 1, as filed. After the fix the acceptance check exits 0.
- The fix adds one arm, `!isset($strOrNull[0])`, to the existing match in escapeField(), before the arm that reads offset 0. The form is deliberate rather than incidental: the sibling unescapeField() in the same file already guards its own offset read with `!isset($strOrNull[strlen($this->escape)])`, so the two methods now carry the same guard shape and a reader comparing them sees one idiom, not two.
- The contract this preserves: an empty field has no leading character, so it needs no escaping, and returning it unchanged is what the method already did. The change removes a diagnostic, not a behaviour - escapeRecord([''])[0] was '' before and is '' after. Nothing in docs/9.0 states anything about empty fields through this formatter, so no documentation needed updating.
- The class is closed by measurement rather than by grep. The enumerating instrument is the suite's own warning report, which lists every PHP diagnostic any test triggers: before the fix `vendor/bin/phpunit --display-warnings` printed "6 tests triggered 1 PHP warning" naming EscapeFormula.php, and after it prints none. The verify wrapper's own summary line records the same transition - it read "Failures: 3, Warnings: 1, Deprecations: 17" at the previous checkpoint and reads "Failures: 3, Deprecations: 17" now, with the Warnings term gone.
- Behaviour re-checked across the field domain under a handler that promotes warnings to ErrorException, since that is the condition under which the defect was a crash rather than a log line: the empty string, a space, "0", a plain word, a formula, an already-escaped field, and the non-string values 42, null, 4.5 and true all return what they returned before, and the empty field still round trips through unescapeRecord.
- Differential evidence that the change altered no previously-passing output: the charset-escape battery as it stood at the previous checkpoint, 44 checks, runs 44/44 against the fixed code. Against the pre-fix code the extended battery does not merely fail, it aborts at exit 255 with the ErrorException raised at src/EscapeFormula.php inside the first strict-handler check. The fixed file was copied aside and restored around each run; no git checkout ran over uncommitted work.
- Verify: exit 1 with Tests: 1009, Failures: 3 - the same three StreamTest cases as every previous checkpoint, unchanged. phpstan exits 0 with "No errors" and php-cs-fixer exits 0 with "Found 0 of 161 files that can be fixed".
- Battery ownership: the diff touched src/EscapeFormula.php, declared by .jeffy/probes/charset-escape/paths. That battery was extended to 61/61 and its row re-recorded at this checkpoint. All eleven batteries were re-run green. check-claims.sh reports 11 checked, 0 mismatched, 0 errored.
- No stall: src/EscapeFormula.php changed and one BACKLOG.md item was removed.

Closed this run: CSV-10 (High) - empty fields no longer raise a PHP diagnostic through the formula-injection formatter; the suite's warning count went from one to zero and the escaped values are unchanged.

Learnings: A defect that shows only as a PHP diagnostic needs a probe that promotes warnings to exceptions - the return value was already correct, so no equality check could see it, and the battery's strict-handler wrapper is what turns the diagnostic into a failure. A suite's warning report is a usable enumeration instrument for a whole class: it lists every diagnostic any test triggers, so driving that count to zero closes the class without a grep that could miss a site.

Next: No open High. The map is the top of the queue again with 11 of 22 rows unswept and 3 iterations left. Iteration 8 resumes sweeping.

## iter 8/10 | 8bd0ee5e-173008 | 2026-09-02 | SWEEP | done

Task: Sweep Surface inventory rows. No open High at the start of the iteration, so the map was the top of the queue with 11 rows unswept.

Changed: .jeffy/probes/{exceptions-warning,info-functions,buffer,fragment-finder}/ (run.php, paths, claims, README.md each), PLAN.md (4 rows flipped, 1 Lesson), BACKLOG.md (CSV-11 filed), JOURNAL.md. No src/ path changed.

Checkpoint: 0d0672ac170c45779d5ee2d71359bfdf71450f22

Verification:
- Four rows swept by executed batteries through run-probe.sh: exceptions-warning 105/105, info-functions 36/36, buffer 48/48, fragment-finder 32/32. Inventory now stands at 15 of 22 rows swept, from 11 at the start of this iteration. check-claims.sh reports 15 checked, 0 mismatched, 0 errored.
- Each battery was observed failing against a mutation applied to the real source and reverted, with git diff over src/ confirming an empty diff: SyntaxError::duplicateColumnNames() returning an empty array reddens the duplicate-name family; Info::getDelimiterStats() discarding its limit reddens three checks; Buffer::truncate() returning without clearing reddens the truncate family; and the row filter's <= weakened to < aborts the fragment-finder battery outright, because a bare index sets end equal to start so the strict comparison excludes the very row it names.
- Two mutation attempts failed honestly and were redone rather than recorded. The first Info mutation did not match its anchor and never applied; the first FragmentFinder mutation changed the selection's length field, which the row path does not read. Both left their battery green, and a green under a mutation that never took effect is not evidence, so both were discarded and replaced with mutations that actually redden.
- New finding, surfaced by the fragment-finder sweep and filed at rubric severity in this same iteration: CSV-11, High. FragmentFinder::parseRowColumnSelection() ends with a guard rejecting an end less than or equal to the start and returning the -1 sentinel that means select nothing, so a single-element RFC 7111 range selects nothing: row=2-2, row=1-1 and col=2-2 all return null from findFirst while row=2, row=1 and col=2 return the row or column. Mapped systematically across row, col and cell before filing - proper ranges work, inverted ranges correctly select nothing, and the cell parser already handles cell=2,2-2,2 correctly, so the two selector families disagree on the same shape. The Operating envelope classifies fragment identifiers as adversarial because they arrive in URLs. The acceptance check exits 1 against the unfixed code and asserts the four equivalences, the two inverted forms that must stay empty, and one proper range that must not change.
- The acceptance check for CSV-11 was first written as a path under /tmp and then rewritten inline as a php -r one-liner, because a check living outside the repository is one the evaluator and the next run cannot execute.
- Three probe expectations were wrong rather than the library, and all three were corrected in the probe: duplicate header names are rejected where the header is applied to records rather than by getHeader(), which reports the raw row; Buffer::insert() with no records throws rather than returning zero, a guarded call the battery now asserts alongside Writer::insertAll([]) returning 0; and multiple fragment selections are separated by a semicolon inside one expression, row=1;3, not by repeating the selector.
- Verify: exit 1, unchanged from the previous checkpoint - Tests: 1009, Failures: 3, the same three StreamTest cases. No src/ path changed this iteration; every mutation was reverted and git diff over src/ was empty before the checkpoint.
- No stall: four Surface inventory rows changed state and one BACKLOG.md item was added.

Learnings: A mutation that fails to apply, or that changes a field the code path does not read, leaves the battery green and proves nothing - check the mutant actually reddens before recording a battery as observed failing. An acceptance check must live inside the repository; one written against a scratch path cannot be run by the evaluator or by the next run.

Next: CSV-11 is an open High and outranks the 7 remaining unswept rows. With two iterations left the map cannot clear this run, so convergence falls to a later run; iteration 9 fixes CSV-11 and iteration 10 writes the handoff.

## iter 9/10 | 8bd0ee5e-173008 | 2026-09-02 | CSV-11 | done

Task: CSV-11 (High) - a single-element RFC 7111 range such as row=2-2 or col=2-2 selects nothing, where the bare row=2 or col=2 selects the row or column.

Changed: src/FragmentFinder.php, .jeffy/probes/fragment-finder/ (run.php, claims, README.md), PLAN.md (row re-recorded), BACKLOG.md (CSV-11 deleted), JOURNAL.md.

Checkpoint: ca4157f8cc05c5c3dcfd5e51cd4ed6bfa89f1b72

Verification:
- The filed reproduction was the first command of the iteration and exited 1, as filed. After the fix the acceptance check exits 0.
- The fix changes one comparison in parseRowColumnSelection, from rejecting an end less than or equal to the start to rejecting only an end before it. An end before the start is malformed; an end equal to it is the RFC 7111 spelling of a single-element range, and rejecting it returned the -1 sentinel that means select nothing. The comment records that reasoning at the site rather than only here.
- The contract this preserves: RFC 7111 section 2 writes a row range as start-end and does not exclude start equal to end, and the package's own cell parser, which uses a different regex and does not route through this helper, already returned the cell for cell=2,2-2,2. The change makes the row and column families agree with the cell family and with the bare-index form; it does not invent a reading.
- Nothing pinned the old behaviour. FragmentFinder has no test file, and grepping the whole test surface for FragmentFinder, matching, matchingFirst and for any row=, col= or cell= expression returns nothing, so the class and the three Reader methods that route through it are entirely untested by the suite. That is why the defect survived, and it is also why no test needed changing.
- The full selector matrix was re-provoked after the change rather than reasoned about: row=2, row=2-2, row=1-1, row=3-3 and row=2-3 all return their rows; col=2, col=2-2 and col=2-3 their columns; cell=2,2 and cell=2,2-2,2 the cell; row=3-2 and col=3-2 still return null; row=99 and row=99-99 still return null; and row=1-* is unchanged. Both the fixed shape and every boundary that had to stay put were checked.
- Differential evidence that the change altered no previously-passing output: the fragment-finder battery as it stood at the previous checkpoint, 32 checks, runs 32/32 against the fixed code. Against the pre-fix code the extended battery reddens exactly eight checks - the four row and three column single-element ranges and the explicit non-empty assertion - and no others, which is the shape a defect confined to one guard should have.
- Verify: exit 1 with Tests: 1009, Failures: 3 - the same three StreamTest cases as every previous checkpoint, unchanged. phpstan exits 0 with "No errors" and php-cs-fixer exits 0 with "Found 0 of 161 files that can be fixed".
- Battery ownership: the diff touched src/FragmentFinder.php, declared by .jeffy/probes/fragment-finder/paths. That battery was extended to 44/44 and its row re-recorded at this checkpoint. All fifteen batteries were re-run green. check-claims.sh reports 15 checked, 0 mismatched, 0 errored.
- No stall: src/FragmentFinder.php changed and one BACKLOG.md item was removed.

Closed this run: CSV-11 (High) - single-element row and column ranges now select what their bare-index form selects; eight battery checks moved red to green, the inverted and out-of-range forms are unchanged, and the whole FragmentFinder surface now has the coverage the suite never had.

Learnings: A surface with no test file at all is where a silent wrong answer survives longest - grepping the test tree for the class and for its expression syntax took one command and explained both why the defect existed and why fixing it broke nothing.

Next: No open High. Seven rows remain unswept and this is the last budgeted iteration, so iteration 10 writes a WRAPUP handoff rather than starting a sweep it cannot finish. Convergence falls to the next run: the map is not clear, so the Definition of done cannot be met this run whatever else happens.

## iter 1/10 | 45f883c4-182339 | 2026-09-02 | SWEEP | done

Task: Sweep Surface inventory rows. No open High at the start of the iteration and seven rows unswept, so the map was the top of the queue.

Changed: .jeffy/probes/{schema-structured-fields,tabular-contracts,rdbms-result}/ (run.php, paths, claims, README.md each), PLAN.md (3 rows flipped), BACKLOG.md (CSV-12 through CSV-17 filed), JOURNAL.md. No src/ path changed.

Checkpoint: f2523bcd49092b655e66eca92642941887978752

Verification:
- Three rows swept, each by a known-answer battery kept under .jeffy/probes and each observed to redden under a discriminating mutation that was applied, measured and reverted.
- schema-structured-fields, 188 checks. Every field's parse is graded against hand-written answers with its rejecting side beside it, and every documented parameter is driven at two or more values that must change the output: DateTimeField's format, timezone and output class; TimeField's precision, padding and separator; JsonField's depth (with the boundary pinned at 4 and 5 on a four-deep document) and flags; SetField's separator; CustomField's two parser shapes. evaluate() is asserted as a tri-state on every family, so a field answering null for both absent and invalid could not pass. Observed failing: mutating the padded branch of generatePattern from \d{2} to \d{1,2} reddens exactly two checks, one of them the differential that reports the parameter changed nothing.
- tabular-contracts, 95 checks. The four interfaces hold no behaviour, so the row is swept by driving the promises in their docblocks against every implementer, both sets enumerated by command rather than recalled. One ragged document exercises both stated repairs at once - missing field filled with null, extra field stripped - on Reader, ResultSet and Buffer, which are then cross-checked against each other record for record. count() excluding the header is asserted differentially rather than as a number. All sixteen entry points that accept a TabularDataProvider are driven twice, once with a provider and once with the reader it wraps, and asserted equal, with a separate check that the provider path carries all four records so the equality cannot be satisfied by two empty results. Observed failing: mutating Reader::combineHeader's `?? null` to `?? ''` reddens nine checks across all three implementers.
- rdbms-result, 38 checks. The same table is loaded through PDO-sqlite and ext-sqlite3 and the two branches are cross-checked against each other rather than each against its own expectation: column names, order, aliases, a result with no rows that must still name its columns, and the records themselves. The falsy values are pinned deliberately - a NULL field, an empty-string field, a whole column of zeros - because a loop testing a field rather than a row would drop or truncate on any of them, and integer typing is asserted on both drivers because that is the fact CSV-13 turns on. The documented RuntimeException is provoked on an unexecuted statement. Observed failing: mutating the PDO fetch mode to FETCH_NUM reddens five checks.
- This host reaches two of RdbmsResult's four driver branches. ext-mysqli and ext-pgsql are absent, which the battery asserts rather than assumes, and it reads the parameter's type union back through reflection so a branch dropped from the union would redden a check on a host that cannot execute it. The row records that limit.
- Six findings filed, each with its acceptance check run against the unfixed code first and observed to fail: CSV-12, CSV-13 and CSV-14 High; CSV-15, CSV-16 and CSV-17 Medium. CSV-13 was reproduced end to end twice, through Schema::parse over a Buffer and through a ResultSet built from a real SQLite3 INTEGER column, because the severity rests on a non-string field arriving from a real source rather than on a hand-passed value. CSV-12 was reproduced through Reader::inferRecords with the package's own DateTimeField::machine list, which returned the CSV value 2024-01-01 as 2024-01-01 18:30:16.
- Severity reasoning for CSV-14, the one finding whose input is partly developer-authored: the separator is configuration and the value parsed is adversarial, and the envelope classifies sample values reaching the Schema field evaluators adversarial. A `.` separator passes the constructor's own validation and the package ships `d.m.Y` as a built-in date format, so the configuration is legitimate and the wrong result comes from the data, which keeps it at rubric severity rather than at the user-error ceiling.
- Verify: exit 1 with Tests: 1009, Failures: 3 - the same three StreamTest cases as every previous checkpoint, unchanged and tracked as CSV-5. No src/ path changed this iteration; every mutation was reverted and git diff over src/ was empty before the checkpoint.
- Battery ownership: the diff touches no declared path of any battery, so none was owed a re-run by the diff; all eighteen were run anyway through check-claims.sh, which reports 18 checked, 0 mismatched, 0 errored.
- No stall: three Surface inventory rows changed state and six BACKLOG.md items were added.

Learnings: A `differs` check is what catches an inert parameter, and it has to be written per parameter rather than per function - SetField's limit is accepted, stored and reported in metadata, and only a check comparing two limits could see that parse never passes it to explode. Driving an interface row means driving every implementer against the same fixture and then cross-checking the implementers against each other; a promise checked on one implementer proves nothing about the interface.

Next: Four rows remain unswept - stream, stream-filters, serializer-casters and serializer-core - but three open High tasks now outrank them. Iteration 2 takes CSV-12, the widest of the three.

## iter 2/10 | 45f883c4-182339 | 2026-09-02 | CSV-12 | done

Task: CSV-12 (High) - a date-only format takes its time of day from the wall clock, so the CSV value 2024-01-01 parses to 2024-01-01 at whatever time the parse ran.

Changed: src/Schema/DateTimeField.php, .jeffy/probes/schema-structured-fields/ (run.php, claims, README.md), BACKLOG.md (CSV-12 deleted), PLAN.md (row re-recorded), JOURNAL.md.

Checkpoint: f5c57ffd36124e7d8d138e9533b07e631f3202ea

Verification:
- The filed reproduction was the first command of the iteration and exited 1, as filed. After the fix the acceptance check exits 0.
- The fix appends PHP's `|` reset modifier to a private parseFormat used only at the createFromFormat call. `|` resets every field the format did not parse, which is exactly the set the clock was filling; a format that parses a time, an offset, microseconds or a whole timestamp reaches the modifier with nothing left to reset. The public $format property, metadata() and name() keep the caller's own spelling, so nothing the caller can observe about the field's identity changed.
- The contract this preserves: parse() still returns the caller's outputClass in the field's own timezone, still returns null for a value the format cannot read, and still rejects a date whose warning count is non-zero - 2020-02-30 is refused after the fix exactly as before, and so is a value carrying a remainder the format did not ask for. The reset was checked not to reach the timezone, which was the one real risk: a date-only field built on Asia/Tokyo still returns midnight in Tokyo rather than midnight in UTC.
- Nothing in the suite pinned the old behaviour. DateTimeFieldTest asserts only format('Y-m-d') on its results, and grepping the test tree and docs/9.0 for a parsed datetime carrying a time returns nothing. The page documenting the feature calls the inference deterministic, which the fix makes true rather than contradicts.
- Every format the class ships was re-provoked after the change rather than reasoned about: all seven date-only formats - Y-m-d from the machine list and all six localized formats - now start the day at midnight, while RFC3339 keeps its parsed offset, RFC3339_EXTENDED keeps its microseconds, ISO8601_EXPANDED keeps its instant, U is unchanged at the epoch and at a known timestamp, and a format the caller already wrote with `!` or with a trailing `|` still parses.
- Differential evidence that the change altered no previously-passing output: the schema-structured-fields battery as it stood at the previous checkpoint, 188 checks, runs 188/188 against the fixed code. Against the pre-fix code the extended battery reddens exactly sixteen checks - the seven date-only known answers, the seven built-in date-only formats driven one by one, the equality against the date the value states, and the timezone check - and no others, which is the shape a defect confined to unparsed fields should have. The fixed file was copied aside and restored around that run; no git checkout ran over uncommitted work.
- End to end: Reader::inferRecords with the package's own DateTimeField::machine list returned 2024-01-01 18:30:16 for the CSV value 2024-01-01 before the fix and returns 2024-01-01 00:00:00 after it, and the parsed value now equals new DateTimeImmutable('2024-01-01').
- Verify: exit 1 with Tests: 1009, Failures: 3 - the same three StreamTest cases as every previous checkpoint, unchanged. phpstan exits 0 with "No errors" and php-cs-fixer exits 0 with "Found 0 of 161 files that can be fixed".
- Battery ownership: the diff touched src/Schema/DateTimeField.php, declared by .jeffy/probes/schema-structured-fields/paths. That battery was extended to 211/211 and its row re-recorded at this checkpoint. All eighteen batteries were re-run green; check-claims.sh reports 18 checked, 0 mismatched, 0 errored.
- No stall: src/Schema/DateTimeField.php changed and one BACKLOG.md item was removed.

Closed this run: CSV-12 (High) - a date-only format now returns the date the CSV states rather than that date carrying the clock's time; sixteen battery checks moved red to green and every format that parses a time is unchanged.

Learnings: PHP's `|` reset modifier is the narrow fix for createFromFormat borrowing from the clock, because it touches only the fields the format did not parse - appending it left the timezone argument, parsed offsets, microseconds and `U` alone, all of which a `!` prefix or a post-hoc setTime would have had to be reasoned about separately. Where a fix normalises an argument, keep the caller's spelling on the public property and normalise into a private one, or the field starts reporting a format its caller never wrote.

Next: CSV-13 and CSV-14 remain open High. Iteration 3 takes CSV-13, the uncaught TypeError, because a crash outranks a wrong value that only a non-default separator reaches.

## iter 3/10 | 45f883c4-182339 | 2026-09-02 | CSV-13 | done

Task: CSV-13 (High) - EnumField::parse() raises an uncaught TypeError for an int value against a string-backed enum, where its contract is to return null.

Changed: src/Schema/EnumField.php, .jeffy/probes/schema-structured-fields/ (run.php, claims, README.md), BACKLOG.md (CSV-13 deleted), PLAN.md (row re-recorded), JOURNAL.md.

Checkpoint: 850ed03c03761b2e72433a8cba01ab337d4ffd21

Verification:
- The filed reproduction was the first command of the iteration and exited 255 with the TypeError, as filed. After the fix the acceptance check exits 0.
- The fix adds the mirror of the branch already sitting above it: that branch converts a string to an int for an int-backed enum, and this one converts an int to its string form for a string-backed enum. The two spellings of one value now resolve alike in both directions, which is the intent the existing branch already expressed.
- The contract this preserves: parse() still returns null for anything the enum does not hold, still returns a matching instance by identity, still refuses an instance of another enum, a float, a bool and an array, and the pure-enum and int-backed paths are untouched. What changed is that a value the method's own guard admits now produces a verdict instead of a fatal.
- This is one site, not a class. Every backed-enum from/tryFrom call in the tree was enumerated by `grep -rn "tryFrom(\|::from(\$" --include='*.php' src | grep -v Test`: apart from this one they are all on the package's internal enums - Type, ArrayShape, Comparison, Bom, MapRecord - reached with statically typed string arguments. The nearest sibling, Serializer\CastToEnum::cast(), takes mixed and guards it with `is_string($value) || throw`, so a non-string there is a documented TypeCastingFailed rather than a crash; its contract differs and it needs no change.
- Nothing in the suite pinned the old behaviour: EnumFieldTest drives parse() with strings, an int against an int-backed enum, an array and an empty string, and never an int against a string-backed enum.
- Differential evidence that the change altered no previously-passing output: the schema-structured-fields battery as it stood at the previous checkpoint, 211 checks, runs 211/211 against the fixed code. Against the pre-fix code the extended battery does not merely fail, it aborts at exit 255 inside the first int-against-a-string-backed-enum check, which is the shape a crash defect has from inside an instrument. The fixed file was copied aside and restored around that run; no git checkout ran over uncommitted work.
- End to end: both reproductions filed with the finding now return a record instead of a fatal - Schema::parse over a Buffer holding an int, and over a ResultSet built from a real SQLite3 INTEGER column, each yielding ['colour' => null].
- Verify: exit 1 with Tests: 1009, Failures: 3 - the same three StreamTest cases as every previous checkpoint, unchanged. phpstan exits 0 with "No errors" and php-cs-fixer exits 0 with "Found 0 of 161 files that can be fixed".
- Battery ownership: the diff touched src/Schema/EnumField.php, declared by .jeffy/probes/schema-structured-fields/paths. That battery was extended to 224/224 and its row re-recorded at this checkpoint. All eighteen batteries were re-run green; check-claims.sh reports 18 checked, 0 mismatched, 0 errored.
- No stall: src/Schema/EnumField.php changed and one BACKLOG.md item was removed.

Closed this run: CSV-13 (High) - an int reaching a string-backed EnumField now answers rather than raising, and an int whose string form is a case value resolves to that case.

Learnings: When a method's own type guard admits a value its body cannot handle, the fix belongs at the conversion the sibling branch already performs rather than at the guard - narrowing the guard would have made an integer column unreadable for enums whose case values are digit strings, which the int-backed direction already supports.

Next: CSV-14 is the last open High. Iteration 4 takes it.

## iter 4/10 | 45f883c4-182339 | 2026-09-02 | CSV-14 | done

Task: CSV-14 (High) - TimeField interpolates the caller's separator into a regex unquoted, so a `.` separator reads any byte as a separator and a `/` separator breaks the pattern outright.

Changed: src/Schema/TimeField.php, .jeffy/probes/schema-structured-fields/ (run.php, claims, README.md), BACKLOG.md (CSV-14 deleted), PLAN.md (row re-recorded), JOURNAL.md.

Checkpoint: 672de1a7668deaddec235693d1dafc4312cad66b

Verification:
- The filed reproduction was the first command of the iteration and exited 1, as filed. After the fix the acceptance check exits 0 and raises no PHP diagnostic.
- The fix quotes the separator at the one site that builds the pattern, `preg_quote($this->separator, '/')`, naming the delimiter so a `/` separator is escaped rather than closing the expression. Nothing else moved: the raw byte is still what the field reports through its public separator property and its name(), and still what parse() emits between the time parts, so the quoting is invisible from outside.
- The contract this preserves: a separator still has to be a single non-digit byte, the constructor's rejections are unchanged, and the padded and unpadded digit patterns, the three precisions and the hour, minute and second boundaries all behave as before. What changed is that the separator now means itself.
- The class is closed by driving its whole domain rather than by grepping for metacharacters. The constructor admits every single byte that is not a digit, so the battery builds a field for each of those 246 bytes, asserts it reads its own shape, asserts it refuses a shape it does not separate, and runs the loop under a handler that promotes any PHP diagnostic to an exception. Measured with that loop, the pre-fix code left 11 bytes unable to read their own shape, 2 matching a shape they do not separate, and 5 raising a diagnostic; the fixed code leaves none in any of the three. A grep for metacharacters would have found the first class and missed that `/` fails for a different reason than `.` does.
- Nothing in the suite pinned the old behaviour: TimeFieldTest drives the default `:` separator only, which quoting leaves untouched.
- Differential evidence that the change altered no previously-passing output: the schema-structured-fields battery as it stood at the previous checkpoint, 224 checks, runs 224/224 against the fixed code. Against the pre-fix code the extended battery reddens exactly sixteen checks, every one of them in the separator family, and no others.
- Verify: exit 1 with Tests: 1009, Failures: 3 - the same three StreamTest cases as every previous checkpoint, unchanged. phpstan exits 0 with "No errors" and php-cs-fixer exits 0 with "Found 0 of 161 files that can be fixed".
- Battery ownership: the diff touched src/Schema/TimeField.php, declared by .jeffy/probes/schema-structured-fields/paths. That battery was extended to 258/258 and its row re-recorded at this checkpoint. All eighteen batteries were re-run green; check-claims.sh reports 18 checked, 0 mismatched, 0 errored.
- No stall: src/Schema/TimeField.php changed and one BACKLOG.md item was removed.

Closed this run: CSV-14 (High) - a caller-supplied separator now means itself inside the pattern; every byte the constructor admits reads its own shape, refuses another, and raises nothing.

Learnings: Where a caller-supplied byte reaches a regex, drive the whole admitted domain rather than a list of metacharacters - the byte that broke the pattern by closing it early is not a metacharacter in the usual sense, and a sample-based check would have fixed the matching class while leaving the delimiter class in place.

Next: No open High. The map is the top of the queue again with 4 rows unswept - stream, stream-filters, serializer-casters and serializer-core - and 6 iterations left. Iteration 5 resumes sweeping.

## iter 5/10 | 45f883c4-182339 | 2026-09-02 | SWEEP | done

Task: Sweep Surface inventory rows. No open High at the start of the iteration and four rows unswept, so the map was the top of the queue.

Changed: .jeffy/probes/stream/ (run.php, paths, claims, README.md), BACKLOG.md (CSV-18, CSV-19, CSV-20 filed), PLAN.md (1 row flipped), JOURNAL.md. No src/ path changed.

Checkpoint: 91d80c4b6b9c3eec4d72903623b784c87a1196ba

Verification:
- One row swept this iteration, stream, by a 96-check known-answer battery. The row is heavier than a row's worth of ordinary surface: Stream is the wrapper every read and write in the package goes through, and its filter side turned out to hold two user-facing defects that took provoking rather than reading to find, so the iteration went to evidence rather than to breadth.
- Every read flag is asserted live rather than merely exercised: READ_CSV against no flag, DROP_NEW_LINE against no flag, SKIP_EMPTY against its absence, each with a known answer and a differential. The delimiter is asserted to reach the parser by reading one document under two delimiters, and fputcsv's delimiter, enclosure and end-of-line are each asserted against a second value.
- The non-seekable stream in this battery is a stream_socket_pair, whose non-seekability the battery asserts before relying on it. That is the instrument the project's own three failing StreamTest cases lack: STDOUT is non-seekable only when it happens to be a pipe or a tty, which is why those tests pass in CI and fail under quiet-verify.sh. CSV-5 now has a demonstrated fix path, recorded here rather than filed again.
- Observed failing: mutating setMaxLineLen to store 0 instead of its argument reddens three checks, including the liveness differential. That differential is the check that catches it, and an earlier draft of this battery compared two literals rather than the two reads, so the mutation left it green; the draft check was replaced before the mutation was recorded.
- Three findings filed, each with its acceptance check run against the code first and observed to fail. CSV-18 and CSV-19 are Medium and were reproduced through the public API; CSV-20 is Low.
- CSV-18: stream_get_filters() reports wildcard families, so in_array with strict comparison can never match a concrete member. Driven rather than argued: zlib.deflate and convert.iconv.UTF-8/ISO-8859-15 are accepted by AbstractCsv::appendStreamFilterOnRead and refused by StreamFilter::appendOnReadTo on the same document, while string.toupper - a name that appears literally in stream_get_filters() - works through both.
- CSV-19: found by provoking the failure rather than by reading the call. convert.base64-encode is refused by both library entry points but accepted by raw PHP, and the difference is the params argument: measured across six filter names, convert.base64-encode, convert.base64-decode and convert.quoted-printable-encode each accept the call with params omitted or an empty array and refuse it with an explicit null, which is what Stream::appendFilter always passes. The file already builds argument arrays conditionally for fgets and fwrite, so the fix has an idiom in place.
- CSV-20 was scored Low with its rationale on the ledger line rather than filed at the severity the divergence alone might suggest: Reader::last() and nth() were compared across a Stream-backed and an SplFileObject-backed document over four document shapes with and without a header offset, and agreed every time, so no consequence a user of the shipped product meets has been reproduced. The severity ceiling by class requires a Medium to name one.
- Verify: exit 1 with Tests: 1009, Failures: 3 - the same three StreamTest cases as every previous checkpoint, unchanged. No src/ path changed this iteration; the mutation was reverted and git diff over src/ was empty before the checkpoint.
- Battery ownership: the diff touches no declared path of any battery. All nineteen were run through check-claims.sh, which reports 19 checked, 0 mismatched, 0 errored.
- No stall: one Surface inventory row changed state and three BACKLOG.md items were added.

Learnings: A defect in how a call is made, rather than in which call is made, is invisible to a source read and to a grep - the explicit null params behind CSV-19 was only found by provoking the failure with the same filter name through raw PHP and through the library and comparing. And a liveness differential written against two literals is not a check at all; compare the two computed values or the mutation walks straight past it.

Next: Three rows remain unswept - stream-filters, serializer-casters and serializer-core - and no open High. Iteration 6 continues sweeping.

## iter 6/10 | 45f883c4-182339 | 2026-09-02 | SWEEP | done

Task: Sweep Surface inventory rows. No open High at the start of the iteration and three rows unswept, so the map was the top of the queue.

Changed: .jeffy/probes/stream-filters/ (run.php, paths, claims, README.md), BACKLOG.md (CSV-21, CSV-22, CSV-23 filed), PLAN.md (1 row flipped), JOURNAL.md. No src/ path changed.

Checkpoint: 2d3c65c6764bab39ff320c9415a79c9efdceebe8

Verification:
- One row swept, stream-filters, by a 51-check battery grading each of the four filter classes by the document the filter actually produced rather than by inspecting the filter object. Every documented argument is driven at two values: the callback's params, SwapDelimiter's input delimiter, EncloseField's sequence, RFC4180Field's whitespace replacement, each with a differential against the unfiltered document.
- Two of my own expectations in the first draft were wrong rather than the code's: RFC4180Field's whitespace replacement exists to avoid enclosure, not to add it, and addFormatterTo leaves the substituted sequence in the document. Both were corrected against the real output before anything was filed, and the corrected checks now pin the feature by what it is for - a field holding a space written unenclosed, and read back whole.
- Observed failing: mutating SwapDelimiter's MODE_WRITE arm to use the read order reddens exactly two checks, both on the write side, with every read-side check green.
- Three findings filed, each acceptance check run first and observed to fail. CSV-21 is High, CSV-22 and CSV-23 Medium.
- CSV-21 is a class, and its enumeration was built by provoking the failure at every site rather than by grepping for the call. All five php_user_filter subclasses in the tree were attached on the write side of a php://temp that nothing closes, with the attachment confirmed by is_resource on the filter each time: SwapDelimiter, CallbackStreamFilter, RFC4180Field and EncloseField all exit 255 with an uncaught TypeError from stream_bucket_new, and only CharsetConverter survives - its bucket creation is the one that sits inside a catch (Throwable). Two earlier attempts at this enumeration were discarded because EncloseField and RFC4180Field silently failed to attach with the parameters I first passed, and a filter that never attached proves nothing about the site; the counts here are from the run where every filter was confirmed attached.
- CSV-22 was driven rather than read: with a marker filter attached first, prependTo and appendTo produce identical bytes while a raw stream_filter_prepend with the same parameters produces the swapped ones.
- CSV-23 came out of CSV-22's fixture. The direction is decided by a substring test on the stream's reported mode, and php://temp opened r+ reports w+b, so a readable stream is classified write-only and the swap silently does nothing; the same call against a real file opened r+ works, which is why the battery drives appendTo on a file. Stream::fromString builds exactly the misclassified kind of stream.
- Verify: exit 1 with Tests: 1009, Failures: 3 - the same three StreamTest cases as every previous checkpoint, unchanged. No src/ path changed this iteration; the mutation was reverted and git diff over src/ was empty before the checkpoint.
- Battery ownership: the diff touches no declared path of any battery. All twenty were run through check-claims.sh, which reports 20 checked, 0 mismatched, 0 errored.
- No stall: one Surface inventory row changed state and three BACKLOG.md items were added.

Learnings: A probe that attaches a stream filter must assert the filter attached - stream_filter_append returns false when onCreate rejects its parameters, and a site that never attached reads exactly like a site that passed. That is the same failure as a mutation that fails to apply, met from the other direction.

Next: Two rows remain unswept - serializer-casters and serializer-core - with four iterations left, and CSV-21 is now an open High that outranks them. Iteration 7 takes CSV-21.

## iter 7/10 | 45f883c4-182339 | 2026-09-02 | CSV-21 | done

Task: CSV-21 (High) - a stream filter attached on the write side of a stream nothing closes explicitly raises an uncaught TypeError at PHP's shutdown flush, so the process exits 255 after its work is done.

Changed: src/SwapDelimiter.php, src/CallbackStreamFilter.php, src/RFC4180Field.php, src/EncloseField.php, .jeffy/probes/stream-filters/ (run.php, shutdown-probe.php, claims, README.md), BACKLOG.md (CSV-21 deleted, the class settled, and the CSV-21 line restored first - see below), PLAN.md (row re-recorded), JOURNAL.md.

Checkpoint: 8d8ea4ff84e9873fd1942d24da59c4e0512ba64e

Verification:
- Correction first: the previous iteration reported CSV-21 as filed and it was not. The edit that was supposed to write it under Now did not match the section - Now held two blank lines rather than one - and the script printed its success message without checking. The line was restored at the start of this iteration from the finding as previously reported, and the two Medium findings from that iteration, which anchored on a different line, had landed correctly. Nothing else in that entry is affected.
- The filed reproduction was the first command run against the restored line and exited 255, as filed. After the fix the acceptance check exits 0 for all four classes.
- The fix guards the bucket creation with is_resource($this->stream) at the four sites that lacked one. The condition is measured rather than assumed: instrumenting the failing site printed `is_resource=false type=resource (closed)` at the shutdown call, so the stream is a closed resource by then and stream_bucket_new is typed to reject it. Skipping is the answer rather than throwing, because there is no consumer left to pass a bucket to.
- The contract this preserves: in every normal call the stream is open and the branch is not taken, so the filters transform exactly as before - the battery as it stood at the previous checkpoint, 51 checks, runs 51/51 against the fixed code.
- The class is closed class-complete and its enumeration was built by provoking the failure at every site rather than by grepping for the call. All five php_user_filter subclasses were driven with the filter's attachment asserted inside the probe: the four patched classes each exited 255 before and exit 0 after, and CharsetConverter never fataled because its bucket creation already sits inside a catch (Throwable), so it is unchanged. The Settled classes line records that enumerating command, which prints nothing today.
- Differential evidence: against the pre-fix code the extended battery reddens exactly four checks, one per class, and no others.
- The new family cannot be asserted in-process, because the failure happens as the process ends. Each class is driven in its own child through .jeffy/probes/stream-filters/shutdown-probe.php, which lives in the repository so the evaluator and the next run can run it, and which exits 9 rather than 0 when the filter it was asked to attach did not attach - the battery asserts that guard on a bogus class name, so a probe that silently stopped attaching anything could not read as four passes.
- Verify: exit 1 with Tests: 1009, Failures: 3 - the same three StreamTest cases as every previous checkpoint, unchanged. phpstan exits 0 with "No errors" and php-cs-fixer exits 0 with "Found 0 of 161 files that can be fixed".
- Battery ownership: the diff touched all four paths declared by .jeffy/probes/stream-filters/paths. That battery was extended to 56/56 and its row re-recorded at this checkpoint. All twenty batteries were re-run green; check-claims.sh reports 20 checked, 0 mismatched, 0 errored.
- No stall: four src/ files changed and two BACKLOG.md items changed state.

Closed this run: CSV-21 (High) - the four filter classes that fataled at PHP's shutdown flush now skip the bucket when the stream is already closed; four sites moved from exit 255 to exit 0 and the class is settled with its enumerating command on record.

Learnings: A script that edits a state file must assert its own edit landed - a replace that silently matches nothing prints whatever success message follows it, and a finding reported as filed but absent from the ledger is worse than one never found. Assert the ledger holds what the entry claims before writing the entry.

Next: No open High. Two rows remain unswept, serializer-casters and serializer-core, with three iterations left. Iteration 8 resumes sweeping.

## iter 8/10 | 45f883c4-182339 | 2026-09-02 | SWEEP | done

Task: Sweep Surface inventory rows. No open High at the start of the iteration and two rows unswept, so the map was the top of the queue.

Changed: .jeffy/probes/serializer-casters/ (run.php, paths, claims, README.md), BACKLOG.md (CSV-24, CSV-25 filed), PLAN.md (1 row flipped), JOURNAL.md. No src/ path changed.

Checkpoint: a59e367a9a741b5a37b97d4ef913becea9c5eae6

Verification:
- One row swept, serializer-casters, by a 117-check battery. Each caster is constructed against a real ReflectionProperty on a probe class carrying one property per type it has to read, so the caster resolves its type exactly as it does inside the serializer rather than from a hand-built stub.
- Every caster carries three families: known answers, the refusals it documents, and the nullable contract driven on both sides. Every option that decides a reading is asserted live at two values - the date format read day-first and month-first over one string, the date timezone compared on the timestamp, the list separator, the list value type and the csv delimiter each against the default, and every caster's default option shown to produce two answers and not to displace a real value.
- Five of my own first-draft expectations were wrong rather than the code's, and each was corrected against the real behaviour before anything was filed: CastToString passes strings through rather than stringifying scalars, the csv shape returns a list of records rather than one record, the json depth option is named depth rather than jsonDepth, aliases() is keyed by alias rather than a list, and register() with an alias joins only the alias table. The last one is now pinned as its own check, because two registries that look like one is exactly what a reader would get wrong.
- Observed failing: mutating CastToInt::setOptions to store null instead of its default argument reddens exactly two checks, one of them the liveness differential.
- Two findings filed, each acceptance check run first and observed to fail. CSV-24 is Medium and was reproduced end to end through Denormalizer::assignAll over a ResultSet built from a real SQLite INTEGER column, where a ?string property is silently set to null instead of "42"; the same value on a non-nullable property raises TypeCastingFailed, and the battery pins that loud side so the two can be compared once the fix lands. CSV-25 is Low: CastToFloat names int in the failure message for a non-scalar where the branch below it names float.
- Verify: exit 1 with Tests: 1009, Failures: 3 - the same three StreamTest cases as every previous checkpoint, unchanged. No src/ path changed this iteration; the mutation was reverted and git diff over src/ was empty before the checkpoint.
- Battery ownership: the diff touches no declared path of any battery. All twenty-one were run through check-claims.sh, which reports 21 checked, 0 mismatched, 0 errored.
- No stall: one Surface inventory row changed state and two BACKLOG.md items were added.

Learnings: When a battery's first draft fails, read the code before changing the check - five of the six failures here were my expectation being wrong, and each one taught the row something worth pinning. A check corrected into agreement with the code is only honest when the code was read first.

Next: One row remains unswept, serializer-core, with two iterations left. Iteration 9 sweeps it, which clears the map; iteration 10 writes the handoff.

## iter 9/10 | 45f883c4-182339 | 2026-09-02 | SWEEP | done

Task: Sweep the last unswept Surface inventory row, serializer-core. No open High at the start of the iteration, so the map was the top of the queue.

Changed: .jeffy/probes/serializer-core/ (run.php, paths, claims, README.md), PLAN.md (1 row flipped), JOURNAL.md. No src/ path changed and no finding filed.

Checkpoint: 4aca32a6d582d237adfa1a796dad21c351ac55f5

Verification:
- The row is swept by a 69-check battery driven through the documented entry points - assign, assignAll, denormalizeAll, denormalize, and the Reader's getRecordsAsObject, firstAsObject and nthAsObject - and graded by the objects the serializer produced from real records rather than by inspecting its mapping tables.
- Every documented mapping shape is driven: property targets, a constructor target with promoted parameters, a setter target whose column name is derived from the method name, MapCell renaming and ignoring and per-cell casting with options, MapRecord and AfterMapping. Each carries its failure side, and the property-name list, the MapCell options, the registry and the empty-string switch are each asserted live at two values.
- The map is now clear: this was the last of the twenty-two rows.
- Observed failing: two mutations to Denormalizer were applied, measured and reverted. Passing an empty property-name list to setPropertySetters aborts the battery at exit 255 on the positional-record checks, and making MapCell::ignore inert aborts it at 255 as well, because an ignored property the record does not carry becomes a missing value and surfaces as a thrown mapping error rather than as a reddened count. Both are recorded as aborts rather than as counts, which is what they were.
- Four of my first-draft expectations were wrong rather than the code's and each was corrected after reading the code: AfterMapping validates its method name where it is used rather than in its constructor, TypeCastingInfo exposes source, targetName, targetClassName, targetMethodName and targetType rather than a targetPropertyName, the target-kind enum case is PropertyName, and fromAccessor on a ReflectionParameter derives the column from the method name, so it needs a setter rather than a constructor.
- That last one is recorded in the battery README rather than filed: TypeCastingInfo::fromAccessor raises a raw ValueError for a __construct parameter, but no path inside the serializer reaches it that way - constructor targets resolve as promoted properties, which this battery drives and which pass - so nothing a user of the shipped product meets was reproduced, and the severity ceiling by class requires a Medium to name one.
- Verify: exit 1 with Tests: 1009, Failures: 3 - the same three StreamTest cases as every previous checkpoint, unchanged. No src/ path changed this iteration; both mutations were reverted and git diff over src/ was empty before the checkpoint.
- Battery ownership: the diff touches no declared path of any battery. All twenty-two were run through check-claims.sh, which reports 22 checked, 0 mismatched, 0 errored.
- No stall: one Surface inventory row changed state.

Learnings: A battery that aborts under a mutation is weaker evidence than one that reddens a counted set, and sometimes it is all the surface allows - when a mutation turns a mapped value into a missing one, the failure arrives as a thrown error rather than as a wrong answer. Record the abort as an abort rather than inventing a count for it.

Next: The map is clear at twenty-two of twenty-two rows and no High is open, but thirteen Medium tasks remain on the ledger, so the Definition of done is not met and this run cannot converge. Iteration 10 is the last budgeted one and writes the handoff.

## iter 10/10 | 45f883c4-182339 | 2026-09-02 | WRAPUP | done

Task: Final budgeted iteration. The ledger is not at the severity floor - thirteen Medium tasks are open - so the closing full audit is not the legal shape here and this iteration tidies the ledger and writes the handoff instead.

Changed: BACKLOG.md (Later reordered), JOURNAL.md.

Checkpoint: 05c47b18f59899d25ddd24ccb7dec2b0e76d6ae8

Verification:
- The run cannot converge and the reason is one line: the Definition of done requires zero open High and zero open Medium, and thirteen Mediums are open. The map is clear at twenty-two of twenty-two rows and no High remains, so the two conditions this run could reach, it reached.
- Ledger tidied to the ordering the Method prescribes. Next was already correct - eight runtime Mediums, then the build-ci one, then four docs ones. Later held its four Lows out of order and now reads runtime first: CSV-20, CSV-25, then CSV-5 (test) and CSV-6 (docs).
- Every open task carries a severity, a class and a runnable acceptance check, and every acceptance check filed this run was executed against the unfixed code and observed to fail before it was written down.
- No standing claim is stale: check-claims.sh reports 22 checked, 0 mismatched, 0 errored, and every Surface inventory row records the checkpoint hash of the commit its battery was last run against.
- Verify: exit 1 with Tests: 1009, Failures: 3 - the same three StreamTest cases as every checkpoint of this run and the last, tracked as CSV-5. The suite is red for that one reason and nothing this run did moved it.
- No stall: four BACKLOG.md items changed position and the entry records the run's close.

Handoff for the next run, in the order the queue will take them:
- No open High. The queue opens on the eight runtime Mediums, and CSV-24 is the one to take first: a nullable string property silently discards a non-string scalar, which is the only open finding that loses data without saying so.
- CSV-18, CSV-19, CSV-22 and CSV-23 are four independent defects in the stream-filter surface, all reproduced through the public API and all with one-line fixes; taking them in one run would leave that surface clean.
- CSV-5 is a Low but it is the reason the verify gate is red on every run, and the stream battery now demonstrates its fix path: a stream_socket_pair is non-seekable in-process whatever stdout happens to be, where the three failing tests use STDOUT and pass only under a pipe or a tty.
- The Proposed item about a zero-length limit raising OutOfBoundsException is still awaiting a user decision and blocks nothing.
- Convergence needs the evaluator gate, which this run never reached. A next run of ten iterations that closes the thirteen Mediums has the budget to reach it; a shorter run should expect to hand the gate on again.

Learnings: A run that clears the map does not thereby get closer to converging - sweeping is what makes the ledger honest, and an honest ledger on an unexamined project grows before it shrinks. This run swept seven rows and filed fourteen findings; the next run inherits a map with no blind spots and a queue of reproduced defects, which is the position the sweep exists to produce.

Next: The run ends out of budget with the map clear and thirteen Mediums and four Lows open. Relaunch in a fresh session to work the ledger down; the state files carry everything forward.

## iter 1/10 | 59a2fdbf-191704 | 2026-09-02 | CSV-1 | done

Task: CSV-1 (Medium) - `FieldList::removeByOffset()` returns the unmodified list whenever the removal would empty it, so a caller who removes every field still holds them all and an Inspector built on that list keeps inferring the types the caller removed.

Changed: src/Schema/FieldList.php, src/Schema/FieldListTest.php, .jeffy/probes/schema-core/ (run.php, claims, README.md), BACKLOG.md (CSV-1 deleted), PLAN.md (row re-recorded, 1 Lesson), JOURNAL.md.

Checkpoint: ad3fdd2c398413294bef6135f1fc20a1583576e3

Verification:
- The filed reproduction was the first command of the iteration and exited 1, as filed. After the fix the acceptance check exits 0.
- The fix deletes one ternary. `removeByOffset` ended with `return [] === $fields ? $this : new self(...$fields)`, applying to its own result an idiom the class uses elsewhere on its input. `append` and `prepend` ask whether there is anything to add; asking the same question of a removal's result confuses "removed nothing" with "removed everything". The method already returns `$this` earlier when no offset was valid, which is the real no-op, so the trailing guard could only ever fire on the emptying case. The site is singular, not a class: `grep -rn '? \$this :' --include='*.php' src | grep -v Test` returns six sites, and the other five test the input or compare the receiver to the result - `append` and `prepend` on the flattened input, `removeByType` and `removeByName` on `$this->fields === $fields`, and `Inspector::sampleLimit` on the argument - so none of them can misread an empty result.
- The contract this preserves: both no-op paths still hand back the receiver itself, asserted by identity - `removeByOffset()` with no arguments and `removeByOffset(99)` on a three-field list both return the same instance, which is what `testRemoveByOffsetInvalidReturnsSameInstance` pins. The receiver is still never mutated. The whole removal matrix was re-provoked after the change rather than reasoned about: partial removals at one and two offsets, removal by negative offsets, duplicate offsets, valid offsets mixed with an out-of-range one, an already-empty list, and the field names left behind after removing the middle field. Only the emptying case moved.
- Nothing in the suite pinned the old behaviour. `FieldListTest` drives `removeByOffset` at a single offset, at two offsets, and at an out-of-range offset, and never to empty; `grep -rn removeByOffset src docs` finds no other caller and no documentation of it, so the fix contradicts no written promise.
- Differential evidence that the change altered no previously-passing output: the schema-core battery as it stood at the previous checkpoint, 82 checks, runs 82/82 against the fixed code. Against the pre-fix code the extended battery reddens exactly six checks - the five empty-result assertions and the cross-remover agreement - and no others, with both same-instance checks passing on both sides, which is the shape a defect confined to one return statement should have. The fixed file was copied aside and the pre-fix version restored from `git show HEAD:src/Schema/FieldList.php` over it, then the copy restored; no git checkout ran over uncommitted work.
- A regression test was added to the project's own suite rather than left to the battery alone, because the battery is loop memory and the suite is what a maintainer runs: `testRemoveByOffsetCanEmptyTheList` asserts the emptying case by positive offsets, by negative offsets and with an out-of-range offset mixed in, and asserts the receiver still holds three fields.
- Verify: exit 1 with Tests: 1010, Failures: 3 - the same three StreamTest cases as every previous checkpoint, tracked as CSV-5 and unmoved by this iteration. The total rose by one, which is the added test passing. phpstan exits 0 with "No errors" and php-cs-fixer exits 0 with "Found 0 of 161 files that can be fixed".
- Battery ownership: the diff touched src/Schema/FieldList.php, declared by .jeffy/probes/schema-core/paths and by no other battery's paths file. That battery was extended from 82 to 90 checks and its row re-recorded at this checkpoint. check-claims.sh reports 22 checked, 0 mismatched, 0 errored.
- The battery's README claim was re-measured in this same iteration rather than carried: the `Schema::remove()` mutation it records still reddens exactly three checks against the extended battery, printing 87/90, and the mutation was reverted with `git diff src/Schema/Schema.php` empty. The README now records the pre-fix tree as a second observed failure with its six named checks.
- No stall: src/Schema/FieldList.php changed and one BACKLOG.md item was removed.

Closed this run: CSV-1 (Medium) - removing every field from a FieldList now yields an empty list, agreeing with removeByType and removeByName; six battery checks moved red to green and both no-op paths still return the receiver.

Learnings: php-cs-fixer must be run with `--allow-risky=yes`, the flag the project's own composer `phpcs` script carries; without it the tool exits 16 on a configuration error having checked nothing, which reads at a glance like a lint failure rather than a command that never ran. Where a class uses one guard idiom for several methods, check what each instance is asking about - the same `[] === $x ? $this` line is correct on an operation's input and wrong on its result, and the two spellings sit four lines apart here.

Next: No open High and the map is clear at 22 of 22 rows, so the queue opens on the eleven remaining runtime and build-ci Mediums. Iteration 2 takes CSV-15, the inert `limit` on SetField::parse.

## iter 1/10 | 59a2fdbf-191704 | 2026-09-02 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines after this iteration's entry, so the ten oldest entries were moved to JOURNAL-archive.md.

Changed: JOURNAL.md, JOURNAL-archive.md (created).

Checkpoint: ad3fdd2c398413294bef6135f1fc20a1583576e3

Verification:
- Twenty entries stood before the rotation; ten remain in JOURNAL.md, from `iter 2/10 | 45f883c4-182339 | CSV-12` to this run's `iter 1/10 | 59a2fdbf-191704 | CSV-1`, and ten are in the archive, from `iter 1/10 | 8bd0ee5e-173008 | AUDIT` to `iter 1/10 | 45f883c4-182339 | SWEEP`. The two counts sum to the twenty that existed, so nothing was dropped.
- The split was taken only on lines matching `^## iter \d`, so the heading-grammar example in the preamble was neither counted as an entry nor moved, and the preamble stayed in JOURNAL.md.
- The archive did not exist before this rotation and was created; every later rotation appends to it.

Learnings: none.

Next: unchanged - iteration 2 takes CSV-15.

## iter 2/10 | 59a2fdbf-191704 | 2026-09-02 | CSV-15 | done

Task: CSV-15 (Medium) - `SetField::parse()` calls `explode()` without the `$limit` the constructor accepts, stores and `metadata()` reports, so the parameter is inert.

Changed: src/Schema/SetField.php, src/Schema/SetFieldTest.php, .jeffy/probes/schema-structured-fields/ (run.php, claims, README.md, observed-failing-setfield-limit.sh), .jeffy/probes/schema-core/ (claims, README.md, two observed-failing scripts), BACKLOG.md (CSV-15 deleted), PLAN.md (2 Lessons, rows re-recorded), JOURNAL.md.

Checkpoint: fab95baf4dd1cbe7e4f3f1c35197d83cfc66b165

Verification:
- The filed reproduction was the first command of the iteration and exited 1, as filed. After the fix the acceptance check exits 0.
- The parameter was measured inert across its whole domain before the fix rather than at one value: `PHP_INT_MAX`, 3, 2, 1, 0, -1 and -2 all returned the same three members for `read,write,delete`, where `explode()` at those same limits returns seven different splits. After the fix `parse()` tracks `explode()` at every one of them, and the default is unchanged.
- The fix passes `$this->limit` as `explode()`'s third argument at the single call site. The limit's semantics are therefore `explode()`'s, which is the reading the constructor's own signature already commits to: it bounds the number of parts and the last part keeps the remainder, so a truncated tail is no enum case and drops. That is what the filed acceptance check encodes - limit 2 over three members yields one member, not two.
- The contract this preserves: the default `PHP_INT_MAX` splits everything exactly as before, so no caller who never passed a limit sees a change; trimming, de-duplication, the skipping of empty and unknown members, the null for a non-string and for the empty string, `name()`, `type()`, `metadata()` and the inherited confidence threshold are all untouched and were re-provoked after the change.
- One test went red and it was repaired rather than reverted, under the verify gate's stated exception. `SetFieldTest::test_it_respects_the_limit` built a field with `limit: 2` and asserted that parsing `read,write,delete` returns all three members - it asserted the limit is ignored, under a name saying it is respected. A test whose name states the contract and whose body denies it pins no behaviour: the suite there contradicts itself rather than speaking for the maintainer, which is what distinguishes it from `StatementTest::testIntervalThrowException`, where the name and the assertion agree and the loop left the behaviour alone. Nothing else pins the limit: `git log` shows the whole feature arrived in one commit, `grep -rn SetField src docs` finds no other caller, and no page documents the parameter.
- Differential evidence that the change altered no previously-passing output: across the whole suite the failure set moved from three to four and back to three, and the one test that moved is the one named above. The extended battery run against the pre-fix code reddens exactly four checks - the three limit known answers and the `set-limit-is-live` differential - while `set-limit-default-keeps-every-member` and `set-metadata-limit` stay green, which is the shape an inert-parameter defect should have.
- The repaired test asserts what its name says, at three limits that must disagree, and a second test was added pinning the default: `test_the_default_limit_keeps_every_member` asserts the stored limit is `PHP_INT_MAX` and that every member survives, so a future change to the default cannot pass silently.
- Verify: exit 1 with Tests: 1011, Failures: 3 - the same three StreamTest cases as every previous checkpoint, tracked as CSV-5 and unmoved. The total rose by one, the added default-limit test. phpstan exits 0 with "No errors" and php-cs-fixer exits 0 with "Found 0 of 161 files that can be fixed".
- Battery ownership: the diff touched src/Schema/SetField.php, declared by .jeffy/probes/schema-structured-fields/paths and by no other battery's paths file. That battery was extended from 258 to 264 checks and its row re-recorded at this checkpoint. check-claims.sh reports 25 checked, 0 mismatched, 0 errored.
- The Stop hook's P1-68 was resolved first, before the task: the schema-core README written last iteration stated `schema-core: 84/90 checks passed` and `87/90` as prose, and a battery README may state a measurement only as the value of a line its claims file executes. Both are now claims lines backed by committed procedures - `observed-failing-removebyoffset.sh` restores the pre-CSV-1 shape of `removeByOffset`, `observed-failing-schema-remove.sh` mutates `Schema::remove()` - each copying the file aside, mutating, running the battery, restoring, and printing the summary line. Both reproduce their recorded figures through check-claims.sh. The same form was used for this iteration's own measurement rather than prose.
- Both mutation scripts refuse to report a figure they did not measure: they print `mutation did not apply` when the file is unchanged and `mutant did not run` when the mutant produced no summary line, because the first draft of one script mutated successfully into PHP that would not parse and printed nothing at all.
- No stall: src/Schema/SetField.php changed and one BACKLOG.md item was removed.

Closed this run: CSV-15 (Medium) - `SetField`'s `limit` now reaches `explode()`, so a documented, stored and reported parameter changes the output at every value in its domain; four battery checks moved red to green and the default is unchanged.

Learnings: A test whose name states a contract its body denies pins nothing - read the name against the assertion before deferring to a green test, because deferring to that one would have left a documented parameter dead. In a `perl -pi` replacement, a PHP `$variable` must be written `\$variable` or perl interpolates it away; the mutation then applies cleanly and produces source that will not parse, which a "did not apply" guard cannot see, so a mutation script must also assert the mutant actually ran.

Next: Ten Mediums and four Lows remain. Iteration 3 takes CSV-16, the hard-coded `H:i:s` in `TimeField::parse()`, which is the same battery and the last finding that sweep filed.

## iter 3/10 | 59a2fdbf-191704 | 2026-09-02 | CSV-16 | done

Task: CSV-16 (Medium) - `TimeField::parse()` renders a `DateTimeInterface` with a hard-coded `H:i:s`, ignoring the configured separator, so one field returns `12-30-45` for the string and `12:30:45` for the equivalent `DateTimeImmutable`.

Changed: src/Schema/TimeField.php, .jeffy/probes/schema-structured-fields/ (run.php, claims, README.md, observed-failing-timefield-separator.sh), BACKLOG.md (CSV-16 deleted), PLAN.md (row re-recorded, 1 Lesson), JOURNAL.md.

Checkpoint: 55a428370e8a348f8eb15c9f9de36f5cae03730c

Verification:
- The filed reproduction was the first command of the iteration and exited 1, as filed. After the fix the acceptance check exits 0.
- The fix gives both `parse()` paths one composer. The string path already built its answer as part, separator, part, separator, part; that composition moved into a private `formatTime()` and the `DateTimeInterface` path now calls it with the instant's hour, minute and second. The two paths can no longer spell an answer differently because there is one place that spells it.
- The separator is deliberately not fed to `format()`. Building `format('H'.$separator.'i'.$separator.'s')` would have passed the acceptance check and been wrong for a whole class of separators the constructor admits: `d`, `Y` and `a` are format characters, so a field configured with one would have emitted a day number, a year or `am` in place of its separator. Composing from three single-character formats and joining with the raw byte cannot do that, and the battery pins it with a `d` separator returning `12d30d45`.
- The contract this preserves: the default colon separator returns exactly what it returned before, which is what keeps `time-reads-a-DateTimeInterface` and the suite green; the string path is byte-identical, since it now calls the composer it used to inline; three-part normalisation is unchanged, so an `hours` or `minutes` field still renders a full `hh<sep>mm<sep>ss` from an object exactly as it does from a string; and single-digit parts are still zero-padded.
- Checked across the whole separator domain rather than at one value: for `:`, `-`, `.`, `/`, `|`, `a`, `d`, `Y` and a space, the object path and the string path now return the same answer for the same time, and did not before. A mutable `DateTime` and a zoned `DateTimeImmutable` were driven beside the immutable one.
- Nothing pinned the old behaviour. `grep -rn TimeField src docs` finds the class, its test file and one documentation table entry; `TimeFieldTest` never constructs a `DateTimeInterface` at all, so the object path was entirely untested by the suite, and no page documents it.
- Differential evidence that the change altered no previously-passing output: the battery run with the hard-coded format restored reddens exactly five checks, every one involving a separator other than the default colon, and no others. The two that stay green do so honestly - one uses the default colon where the defect is invisible, the other compares two object inputs which agreed with each other before the fix as well - and both are called out in the battery README rather than counted as coverage.
- Verify: exit 1 with Tests: 1011, Failures: 3 - the same three StreamTest cases as every previous checkpoint, tracked as CSV-5 and unmoved. phpstan exits 0 with "No errors" and php-cs-fixer exits 0 with "Found 0 of 161 files that can be fixed".
- Battery ownership: the diff touched src/Schema/TimeField.php, declared by .jeffy/probes/schema-structured-fields/paths and by no other battery's paths file. That battery was extended from 264 to 270 checks and its row re-recorded at this checkpoint. check-claims.sh reports 26 checked, 0 mismatched, 0 errored.
- A claim this iteration invalidated was re-measured rather than carried: last iteration's CSV-15 procedure recorded `260/264`, and growing the battery to 270 moved that figure to `266/270` without the defect it measures changing at all. Both observed-failing procedures were re-run and both claims lines rewritten from what they printed.
- No stall: src/Schema/TimeField.php changed and one BACKLOG.md item was removed.

Closed this run: CSV-16 (Medium) - a `DateTimeInterface` now renders with the field's own separator, so a column holding both shapes normalises to one spelling; five battery checks moved red to green and the default separator is byte-identical.

Learnings: A caller-supplied byte that will sit inside a format string is the same hazard as one that will sit inside a regex - the fix is to keep it out of the string the formatter interprets, not to escape it, which is why the two paths compose rather than build a format. A battery claim stated as `x/y` is invalidated by growing the battery even when the defect it measures is untouched, so every observed-failing procedure in a battery must be re-run in the iteration that adds checks to it.

Next: Nine Mediums and four Lows remain. Iteration 4 takes CSV-18, the first of the four stream-filter defects the last run's handoff grouped together.

## iter 4/10 | 59a2fdbf-191704 | 2026-09-02 | CSV-18 | done

Task: CSV-18 (Medium) - `StreamFilter`'s name check compares against `stream_get_filters()` exactly, but PHP lists whole families there, so no concrete member ever matches and `zlib.deflate` is refused where the sibling `AbstractCsv::appendStreamFilterOnRead()` accepts it.

Changed: src/StreamFilter.php, src/StreamFilterTest.php (new), .jeffy/probes/stream/ (run.php, claims, README.md, two observed-failing scripts), BACKLOG.md (CSV-18 deleted), PLAN.md (rows re-recorded, 2 Lessons), JOURNAL.md.

Checkpoint: 3b145d6513b47e74eb236dfac141712ca485493c

Verification:
- The filed reproduction was the first command of the iteration and exited 255 with the LogicException, as filed. After the fix the acceptance check exits 0.
- The disagreement between the two entry points was reproduced before the fix rather than taken from the filing: `Reader::fromString(...)->appendStreamFilterOnRead('zlib.deflate')` returned normally on the same tree where `StreamFilter::appendOnReadTo($stream, 'zlib.deflate')` threw.
- The fix reads a listed `<prefix>.*` entry as covering its members: an exact match still passes, and a name is also accepted when some listed entry ends in `.*` and the name starts with that entry's prefix. `stream_get_filters()` on this host returns eight entries and three of them are families - `zlib.*`, `convert.*`, `convert.iconv.*` - and no concrete member of any family is listed on its own, which is why the exact check refused every one.
- The whole name domain was driven rather than the two names in the filing: `string.rot13`, `string.toupper`, `string.tolower`, `consumed` and `dechunk` are listed by name and still attach; `zlib.deflate`, `zlib.inflate` and `convert.iconv.UTF-8/ISO-8859-15` now attach; `no.such.filter`, `zlibdeflate`, `zlib` and the empty string are still refused with the same LogicException.
- The contract this preserves: the refusal is unchanged for every name no family covers, which is what the battery's existing `an-unregistered-name-is-refused` check and two new prefix checks pin, and the failure mode for a name whose family exists but whose member PHP cannot build is the RuntimeException the method already documented rather than the LogicException, which is the honest classification - the name is registered, the filter could not be created.
- This fix does not close CSV-19 and was checked not to: `convert.base64-encode` now passes the name check and still fails at `stream_filter_append`, so its filed reproduction still exits 255. The two findings are independent and CSV-19 stays open.
- Nothing pinned the old behaviour: `grep -rn "is not registered" src` outside the class itself returns nothing, and the class had no test file at all.
- A test file was added for the class, `src/StreamFilterTest.php`, because the defect is one a user of the shipped product meets and the suite could not see it: it pins a family member attaching, the two entry points agreeing on the same name, and two names that must still be refused.
- Differential evidence that the change altered no previously-passing output: the stream battery run with the family branch made unreachable - which is exactly the exact-match-only check the fix replaced - reddens two checks, the zlib member and the iconv member, and no others. `an-exactly-listed-name-is-still-accepted` stays green under that mutation, honestly, because `string.toupper` is listed by name and only family members were ever refused.
- Two instrument defects were found and fixed while writing those checks, both of which would have made the battery lie. Passing `$resource()` straight into the assertion freed the stream before `is_resource()` read the filter it returned, so every check failed against correct code; and writing the acceptance checks as bare calls made the first refused name abort the whole battery under the mutation, producing no count at all rather than a red check. The checks now hold the handle in a local and answer a bool.
- Verify: exit 1 with Tests: 1015, Failures: 3 - the same three StreamTest cases as every previous checkpoint, tracked as CSV-5 and unmoved. The total rose by four, the new test file. phpstan exits 0 with "No errors" and php-cs-fixer exits 0 with "Found 0 of 162 files that can be fixed".
- phpstan caught nine errors in the new test file on its first draft, every one `fopen()` returning `resource|false` where a `resource` is wanted. Narrowed with `assertIsResource` in one helper rather than suppressed.
- Battery ownership: the diff touched src/StreamFilter.php, declared by .jeffy/probes/stream/paths and .jeffy/probes/stream-filters/paths. Both were run - stream extended from 96 to 103 checks, stream-filters unchanged at 56/56 - and both rows re-recorded at this checkpoint. check-claims.sh reports 28 checked, 0 mismatched, 0 errored.
- The stream README's existing `setMaxLineLen` measurement was stated as a prose count with no executable derivation, which is the same defect the Stop hook named as P1-68 last iteration. Since this iteration edits that README it now carries a procedure too, and both of its figures are claims values check-claims.sh re-derives.
- No stall: src/StreamFilter.php changed and one BACKLOG.md item was removed.

Closed this run: CSV-18 (Medium) - a member of a registered filter family now attaches through `StreamFilter`, so its four entry points accept the names their `AbstractCsv` siblings already accepted; two battery checks moved red to green and every refusal is unchanged.

Learnings: A probe holding a resource only as a call argument loses it before the assertion runs - the filter resource a stream returns dies with the stream, and the check then fails against correct code. An acceptance check whose defect raises must answer a bool rather than call bare, or the first failure aborts the battery and the mutation yields an abort where a count was wanted.

Next: Eight Mediums and four Lows remain. Iteration 5 takes CSV-19, the explicit null params that PHP's convert filters refuse, which is the next of the four stream-filter defects.

## iter 5/10 | 59a2fdbf-191704 | 2026-09-02 | CSV-19 | done

Task: CSV-19 (Medium) - a null `$params` passed positionally to `stream_filter_append()`, which PHP's `convert.base64` and `convert.quoted-printable` filters refuse while accepting the same call with the argument omitted, so those filters could not be attached to a CSV document through any entry point.

Changed: src/Stream.php, src/StreamFilter.php, src/StreamTest.php, src/StreamFilterTest.php, .jeffy/probes/stream/ (run.php, claims, README.md, enumerate-null-params-sites.php, observed-failing-null-params.sh), BACKLOG.md (CSV-19 deleted, one Settled class added), PLAN.md (rows re-recorded, 1 Lesson), JOURNAL.md.

Checkpoint: d40ce65992a1c769fa9dc3ae4a3afb92c639ef63

Verification:
- The filed reproduction was the first command of the iteration and exited 255, as filed. After the fix the acceptance check exits 0.
- This was filed as one site and is a class of four, so it was fixed as a class. The two behaviours were separated by measurement first: every registered filter on this host was attached twice on a bare stream, once with the params argument omitted and once with an explicit null, which found four filters that accept the first and refuse the second - `convert.base64-encode`, `convert.base64-decode`, `convert.quoted-printable-encode` and `convert.quoted-printable-decode`. The filing named three; the fourth is the decode half of the quoted-printable pair and was found by the enumeration rather than by reading the filing.
- The call sites were enumerated by command: `grep -rn 'stream_filter_append(\|stream_filter_prepend(' --include='*.php' src` returns six creation sites. Four pass a nullable `$params` positionally - `Stream::appendFilter`, `Stream::prependFilter`, `StreamFilter::appendFilter`, `StreamFilter::prependFilter` - and all four are fixed. The other two are not in the class and were checked rather than assumed: `SwapDelimiter` passes a real array by name at both of its sites, and `CharsetConverter` omits the argument entirely at both of its own.
- The class enumeration is behavioural, not textual, and it had to be: a grep on the call shape cannot tell a guarded site from an unguarded one, because the guarded form still passes `$params` positionally on its non-null branch. `.jeffy/probes/stream/enumerate-null-params-sites.php` therefore provokes the failure at every public entry point that reaches one of the four sites - the four `AbstractCsv` stream-filter methods, the deprecated `addStreamFilter`, and `StreamFilter`'s four - with every member of the derived filter set. It prints nothing and exits 0 on the fixed tree, and printed 36 lines, one per failing combination, against the pre-fix tree. That command is recorded on the Settled classes line.
- The contract this preserves: a non-null params still reaches the filter, checked differentially rather than assumed - `zlib.deflate` at level 1 produces 64 bytes and at level 9 produces 53 for the same document, so the argument is demonstrably read. Every filter that already attached still attaches, and the InvalidArgument for a filter PHP cannot build is unchanged.
- Nothing pinned the old behaviour: `StreamTest::testAppendStreamFilterThrowsException` asserts the refusal for `foo.bar`, a name no family covers, which is unaffected.
- Differential evidence that the change altered no previously-passing output: restoring the unguarded positional form at all four sites reddens exactly one battery check, the class check that collects every failing site, and no others. One check is the right shape for a class - it names all thirty-two combinations in its failure message rather than spreading them over thirty-two assertions.
- Two regression tests were added to the project's own suite, one per class touched: `StreamTest` drives `appendFilter` and `prependFilter` with the two affected filter families and asserts a params array still changes the document, and `StreamFilterTest` drives all four of its entry points.
- A claim was corrected by measurement rather than by arithmetic: the CSV-18 procedure recorded `101/103`, and adding this iteration's class check moved it to `103/106` rather than the `104/106` a naive re-count gives, because the mutation that breaks the name check also breaks every `convert.*` name and so reddens the new class check too. check-claims.sh caught the typed number; the recorded value is now what the procedure printed.
- Verify: exit 1 with Tests: 1017, Failures: 3 - the same three StreamTest cases as every previous checkpoint, tracked as CSV-5 and unmoved. The total rose by two, the added regression tests. phpstan exits 0 with "No errors" and php-cs-fixer exits 0 with "Found 0 of 162 files that can be fixed".
- Battery ownership: the diff touched src/Stream.php, declared by .jeffy/probes/stream/paths and .jeffy/probes/exceptions-warning/paths, and src/StreamFilter.php, declared by .jeffy/probes/stream/paths and .jeffy/probes/stream-filters/paths. All three were run - stream extended from 103 to 106 checks, exceptions-warning 105/105, stream-filters 56/56 - and all three rows re-recorded at this checkpoint. check-claims.sh reports 29 checked, 0 mismatched, 0 errored.
- No stall: two src/ files changed and one BACKLOG.md item was removed.

Closed this run: CSV-19 (Medium) - the four filters PHP refuses an explicit null params for now attach through all nine public entry points that reach the four call sites, and the class is recorded as settled with a command that re-derives it.

Learnings: A class whose members are call sites cannot be enumerated by grepping the call shape once the fix is in, because the guarded and unguarded forms share it - enumerate by provoking the failure at every entry point instead, which is also the only enumeration that stays true as the code moves. Re-count a battery claim by running the procedure, never by adding the checks you just wrote: a mutation that breaks one thing often breaks a second check for a reason the arithmetic does not know about.

Next: Seven Mediums and four Lows remain. Iteration 6 takes CSV-22, the third of the four stream-filter defects, where `SwapDelimiter::prependTo()` appends.

## iter 6/10 | 59a2fdbf-191704 | 2026-09-02 | CSV-22 | done

Task: CSV-22 (Medium) - `SwapDelimiter::prependTo()` calls `stream_filter_append()`, so it appends where its whole purpose is to place the swap ahead of filters already attached. Closed together with CSV-23 (Medium), because CSV-22's filed acceptance check cannot pass without it.

Changed: src/SwapDelimiter.php, .jeffy/probes/stream-filters/ (run.php, claims, README.md, two observed-failing scripts), BACKLOG.md (CSV-22 and CSV-23 deleted), PLAN.md (row re-recorded, 1 Lesson), JOURNAL.md.

Checkpoint: db3d56b474c11487a55154cfafb336840371f5a8

Verification:
- The filed reproduction was the first command of the iteration and exited 1, printing `aSb` where `a,b` was wanted.
- Two tasks were closed in one iteration, which is a deviation from executing exactly one, and the reason is specific rather than convenient: CSV-22's filed acceptance check drives `prependTo` on a `php://temp` stream, and CSV-23 is precisely the finding that a `php://temp` stream is misclassified as write-only, so the swap does nothing on the read side whatever `prependTo` does with placement. The prepend fix alone was applied and its own acceptance check re-run: still `aSb`, still exit 1. The check the previous run filed for CSV-22 is a joint check over both findings, and satisfying it is what closing CSV-22 means.
- The prepend fix was nonetheless proven in isolation before CSV-23 was touched, on a real file opened `r+` where the mode classification was already correct: with a marker filter attached first, `prependTo` produced `a,b` and `appendTo` produced `aSb`, where before the fix both produced `aSb`. A raw `stream_filter_prepend` with the same parameters was driven beside them as the reference answer. So the two fixes are separately evidenced even though they close together.
- CSV-23's premise was measured rather than taken from the filing: `php://temp` and `php://memory` report their mode as `w+b` whatever mode they were opened with, while a real file reports what it was opened with. `str_contains($mode, 'r')` is therefore false for the package's own scratch document, which `Stream::fromString()` builds.
- The fix reads a `+` as readable too, in one private `modeFor()` both methods call. That is the whole domain: every PHP mode carrying `+` is read-write, so `r`, `r+`, `w+`, `a+`, `x+` and `c+` are readable and `w`, `a`, `x` and `c` are not.
- The contract this preserves, checked in both directions rather than one: after the fix `prependTo` and `appendTo` give the same two answers on a real file, on `php://temp` and on `php://memory`, where before they agreed only on the file; and a stream opened write-only still swaps the write direction, asserted by writing `a,b` through `appendTo` on a `w` handle and reading `a;b` back off disk. `addTo()` sets the mode explicitly and never routed through the probe, and its Reader and Writer paths were re-driven unchanged.
- Nothing pinned the old behaviour: `SwapDelimiterTest` drives `addTo` only, and the battery drove `appendTo` on a real file, the one shape where the classification happened to be right.
- Differential evidence that the changes altered no previously-passing output, taken per fix rather than jointly: making `prependTo` append again reddens all six placement checks across the three stream shapes and nothing else; restoring the `r`-only mode probe reddens exactly the four `php://` checks and leaves the two file ones green. That asymmetry is each defect's own shape, and it is what shows the two fixes are independent rather than one change wearing two names.
- Verify: exit 1 with Tests: 1017, Failures: 3 - the same three StreamTest cases as every previous checkpoint, tracked as CSV-5 and unmoved. phpstan exits 0 with "No errors" and php-cs-fixer exits 0 with "Found 0 of 162 files that can be fixed"; it also reordered the `use function` block after the new imports, which is its call rather than mine.
- Battery ownership: the diff touched src/SwapDelimiter.php, declared by .jeffy/probes/stream-filters/paths and by no other battery's paths file. That battery was extended from 56 to 66 checks and its row re-recorded at this checkpoint. check-claims.sh reports 31 checked, 0 mismatched, 0 errored.
- No stall: src/SwapDelimiter.php changed and two BACKLOG.md items were removed.

Closed this run: CSV-22 (Medium) - `prependTo` now prepends, so it can place the swap ahead of a filter already attached. CSV-23 (Medium) - a readable `php://temp` or `php://memory` is no longer classified write-only, so the swap works on the read side of the package's own scratch document.

Learnings: An acceptance check filed for one finding can silently depend on another still open beside it, and the only way to find out is to apply the fix and run the check - reasoning about the check would have produced a confident wrong answer either way. When two findings must close together, evidence them apart anyway: a mutation per fix, each reddening its own checks, is what distinguishes two defects from one defect filed twice.

Next: Six Mediums and four Lows remain. Iteration 7 takes CSV-24, the nullable string property that silently discards a non-string scalar.
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

## iter 7/10 | 59a2fdbf-191704 | 2026-09-02 | CSV-24 | done

Task: CSV-24 (Medium) - `CastToString::toVariable()` accepts only `is_string($value)`, so on a nullable property every other value falls to the nullable arm and is silently replaced by the default; a non-string scalar read from a tabular source is discarded without a word.

Changed: src/Serializer/CastToString.php, src/Serializer/CastToStringTest.php, .jeffy/probes/serializer-casters/ (run.php, claims, README.md, two observed-failing scripts), BACKLOG.md (CSV-24 deleted), PLAN.md (row re-recorded, 1 Lesson), JOURNAL.md.

Checkpoint: 647f9dc9e315ee6bfe788e3355221faf53306a03

Verification:
- The filed reproduction was the first command of the iteration and exited 1, as filed. After the fix the acceptance check exits 0.
- The fix is the sibling casters' own arm order rather than an invention. `CastToInt`, `CastToFloat` and `CastToBool` all treat null as the nullable case and every non-null scalar as convertible, refusing a non-scalar with `dueToInvalidValue`; `CastToString` was the one caster that treated every non-string as the nullable case. Its arms now read: a string passes through, any other non-null scalar converts, a non-null non-scalar is refused, and only then the nullable and not-nullable arms, which only a null can now reach.
- That ordering fixes a second silent loss the filing did not name: an array or an object on a nullable string property also fell to the nullable arm and became the default. Both are now refused, and both refusals are pinned.
- The contract this preserves, driven across the whole value domain on three property shapes - plain `string`, `?string`, and `mixed`: a string is unchanged including the empty string and surrounding space; null still throws on the non-nullable property and still answers the default on the nullable one; the default is still live at two values; and the default is no longer reachable by a non-null value, which is what the discarding was.
- The end-to-end reproduction the finding names was run against both trees rather than reasoned about: `Denormalizer::assignAll` over a `ResultSet` built from a real SQLite INTEGER column returns `qty=NULL` on the pre-fix tree and `qty='42'` after.
- One behaviour changed beyond the filing and is disclosed rather than buried: on a property typed `null`, a non-null scalar now raises `dueToInvalidValue` where it used to be quietly replaced by null. That is the same answer the property already gave for a non-null string, so the fix makes the two agree; nothing pinned the old answer, since `CastToStringTest`'s data provider is typed `?string $input` and the battery drove that property only with null and with a string.
- Differential evidence that the change altered no previously-passing output: removing the two new arms reddens exactly twelve checks, every one of them written this iteration for this behaviour, and no check that existed before this iteration moves.
- The battery's three `refuses-an-int/float/bool` checks pinned the pre-fix behaviour deliberately - the sweep that filed CSV-24 wrote them with a comment naming the finding - so they were replaced in the same iteration as the behaviour they pinned, not left to contradict the code.
- The conversion checks route through a helper that catches, because the defect they pin raises: written bare, the mutation aborted the battery on the first of them and produced no count at all. That is the second time this run has hit that trap, and the Lesson recorded at iteration 4 is what named it.
- Two regression tests were added to the project's own suite: one asserting a scalar converts identically on the plain and nullable shapes with a default set, one asserting a non-scalar is refused rather than discarded.
- Verify: exit 1 with Tests: 1019, Failures: 3 - the same three StreamTest cases as every previous checkpoint, tracked as CSV-5 and unmoved. phpstan exits 0 with "No errors" and php-cs-fixer exits 0 with "Found 0 of 162 files that can be fixed".
- Battery ownership: the diff touched src/Serializer/CastToString.php, declared by .jeffy/probes/serializer-casters/paths and by no other battery's paths file. That battery was extended from 117 to 127 checks and its row re-recorded at this checkpoint; serializer-core was run beside it at 69/69. The battery's existing CastToInt default measurement was also given a procedure, since this iteration edits that README. check-claims.sh reports 33 checked, 0 mismatched, 0 errored.
- No stall: src/Serializer/CastToString.php changed and one BACKLOG.md item was removed.

Closed this run: CSV-24 (Medium) - a non-string scalar reaching a string property is converted rather than discarded, on the nullable shape as well as the plain one, and a non-scalar is refused rather than silently replaced by the default.

Learnings: When one member of a family of near-identical classes misbehaves, read the siblings before designing the fix - the correct arm order was already written three times over, and inventing one would have risked a fourth spelling of the same contract. A battery check written to pin a known defect must name the finding in its label or its comment, because the iteration that fixes the defect has to find and replace it, and a check that merely looks wrong is one a later reader may restore.

Next: Five Mediums and four Lows remain. Iteration 8 takes CSV-7, the packaging finding, which is the last non-docs Medium and the only one whose consequence reaches every consumer of the package.

## iter 8/10 | 59a2fdbf-191704 | 2026-09-02 | CSV-7 | done

Task: CSV-7 (Medium, build-ci) - `.gitattributes` marks no `export-ignore` for the loop's state files, so PLAN.md, BACKLOG.md, JOURNAL.md, JOURNAL-archive.md and `.jeffy/` ship inside the published package. Consequence: every consumer of `composer require league/csv` unpacks them into `vendor/league/csv`.

Changed: .gitattributes, .jeffy/probes/packaging/ (new battery: run.php, paths, claims, README.md, observed-failing-state-files.sh), BACKLOG.md (CSV-7 deleted, CSV-26 filed), PLAN.md (1 Lesson), JOURNAL.md.

Checkpoint: f0972424b3f28f9f04b85cf1d76138e64c91d7a4

Verification:
- The filed reproduction was the first command of the iteration and printed 5, one per unspecified path.
- The consequence was confirmed against the real artifact rather than inferred from the attribute: `git archive HEAD | tar -t` listed `.jeffy/`, `PLAN.md`, `BACKLOG.md`, `JOURNAL.md` and `JOURNAL-archive.md` among the top-level entries it ships. That is the check that matters, because it is the tarball a consumer unpacks.
- The full set was enumerated by command rather than taken from the filing: every tracked top-level path was run through `git check-attr export-ignore`, which returned eleven unspecified - the five state paths, plus LICENSE, autoload.php, composer.json, polyfill, rector.php and src, which the package is supposed to carry. One of those, `rector.php`, is a dev-tool config whose four siblings are all export-ignored; it is filed as CSV-26 (Low) rather than fixed here, because it is a different finding from the one this task names.
- The fix adds five `export-ignore` lines in the file's existing style. After it the archive ships 106 files: 102 sources under `src/`, the composer manifest, the licence, the autoloader, the polyfill and `rector.php`, with zero `*Test.php`, `*TestCase.php` or `*Bench.php` entries. Nothing the package needs was lost.
- The acceptance check needed one pattern more than the finding implied, and the reason is worth recording: `git check-attr` reports a directory pattern as `set` for the directory and `unspecified` for paths inside it, which is true of the project's own `/docs` pattern too - `docs/index.md` reports unspecified while the whole subtree is excluded from the archive. `/.jeffy` alone therefore satisfied the archive but not the filed check, which asks about `.jeffy/probes/x`; `/.jeffy/**` was added beside it so both agree.
- A new battery was written for this surface, and it grades the tarball rather than the attribute for exactly that reason: the two do not agree path by path in either direction, and the corpus records a packaging probe that sat green over a tarball shipping the loop's own state. It asserts the library's sources, manifest, licence and autoloader are present before asserting anything absent, because an empty archive satisfies every absence check at once.
- Differential evidence: removing the five lines the fix added reddens exactly the five absence checks for the loop's state and leaves the four presence checks and every pre-existing exclusion green.
- Verify: exit 1 with Tests: 1019, Failures: 3 - the same three StreamTest cases as every previous checkpoint, tracked as CSV-5 and unmoved. No PHP source changed this iteration.
- Battery ownership: the diff touched .gitattributes, declared by .jeffy/probes/packaging/paths and by no other battery's paths file. That battery is new and green at 20/20. check-claims.sh reports 35 checked, 0 mismatched, 0 errored.
- No stall: .gitattributes changed and two BACKLOG.md items changed state.

Closed this run: CSV-7 (Medium, build-ci) - the published archive no longer carries the loop's state files, verified by listing the archive rather than by reading the attribute.

Learnings: `git check-attr` and `git archive` disagree by design - a directory pattern excludes a whole subtree from the archive while reporting `unspecified` for every path inside it - so a packaging claim has to be graded on the artifact the command produces, never on the attribute that was set. A probe made only of absence assertions is satisfied by an empty artifact, so assert the artifact is real before asserting what it lacks.

Next: Four Mediums remain, all class docs, and five Lows. Iteration 9 takes CSV-2, the deprecation message naming a method that does not exist.

## iter 9/10 | 59a2fdbf-191704 | 2026-09-02 | CSV-2 | done

Task: CSV-2 (Medium, docs) - the `#[Deprecated]` message and `@deprecated` annotation on `XMLConverter::convert()` both name `XMLConverter::impoprt()`, which does not exist. Consequence: a user migrating off the deprecated method follows the notice PHP prints and gets a fatal `Error: Call to undefined method`.

Changed: src/XMLConverter.php, src/CharsetConverter.php, src/TabularDataReader.php, src/Query/Limit.php, .jeffy/probes/deprecations/ (new battery: run.php, paths, claims, README.md, observed-failing-notice-targets.sh), BACKLOG.md (CSV-2 deleted, one Settled class added), PLAN.md (2 Lessons), JOURNAL.md.

Checkpoint: ffe58ea37a7b6ad830ebf8caba4559049b6512be

Verification:
- The filed reproduction was the first command of the iteration and exited 1, printing the name the message carries: `impoprt`. After the fix the acceptance check exits 0.
- CSV-2 was filed as one site and is a class of four, found by enumerating rather than by reading the filing. Every `#[Deprecated]` attribute and every `@deprecated` annotation in `src/` was resolved against the real class: `XMLConverter::convert` naming `impoprt()`; `CharsetConverter::appendTo` and `::prependTo` naming a misspelled `CharserConverter` in both carriers, six references in all; `TabularDataReader::fetchOne` naming `TabularDataReader::nth()`, which that interface does not declare; and `Query\Limit::new` naming `JsonConverter::__construct()`.
- The three kinds of defect have three different consequences and all four are fixed. The two typos give a fatal, since neither target resolves. The interface one resolves at runtime on every shipped implementer but not on the named type, so a user following it fails static analysis rather than crashing; its message now names the method without claiming the interface carries it. The `Limit` one resolves and is simply wrong - it sends a user migrating off a limit helper to construct a JSON converter - and the file itself carried the answer, a `@see Limit::__construct()` two lines above the attribute that contradicts it.
- The enumeration is kept as a battery rather than run once, because the class reopens the moment someone writes the next notice. It resolves both carriers separately, compares them per method, and asserts a constructor notice names its own class.
- The instrument was wrong three times before it was right, and every one of those was a false positive on correct code: `method_exists()` answers no for `__construct` on a class with no declared constructor, so five sound notices read as broken; reading a whole docblock rather than its `@deprecated` lines picked up `@see` targets and manufactured disagreements; and treating an unqualified name as fully qualified made every same-namespace reference look like a missing class. Each was checked against the code before being called a finding, and none was filed.
- One check was written and then narrowed rather than kept: set equality between the attribute and annotation sets across the whole package is not a defect - a method may legitimately carry one carrier and not the other - so it became a per-method comparison, where a disagreement is the real defect shape.
- The contract this preserves: no behaviour changed, only the text of four notices. The `since` versions, the deprecation attributes themselves and every method signature are untouched, and all four sites still emit a deprecation.
- Differential evidence: restoring the four notices reddens exactly three checks - both resolution checks and the constructor-notice invariant - and no others.
- Verify: exit 1 with Tests: 1019, Failures: 3 - the same three StreamTest cases as every previous checkpoint, tracked as CSV-5 and unmoved, with Deprecations: 17 unchanged. phpstan exits 0 with "No errors" and php-cs-fixer exits 0 with "Found 0 of 162 files that can be fixed".
- Battery ownership: the diff touched four sources, declared by markup-conversion, charset-escape, tabular-contracts and query-ordering. All four were run green - 44/44, 61/61, 95/95, 77/77 - and their rows re-recorded at this checkpoint, and the new deprecations battery is green at 8/8. check-claims.sh reports 37 checked, 0 mismatched, 0 errored.
- No stall: four src/ files changed and two BACKLOG.md items changed state.

Closed this run: CSV-2 (Medium, docs) - every deprecation notice in the package now names a target a user can actually reach, closed class-complete across four sites with a battery that re-derives the enumeration.

Learnings: An instrument that reports a finding on correct code is the cheap failure and an instrument that misses one is the expensive failure, but the first still costs an iteration if its output is believed - read the code at every reported site before filing, because three of this iteration's first eight reports were the instrument's fault. A defect that resolves is invisible to a resolution check: `Query\Limit::new` named a real method on the wrong class and passed every check the class was built around, and only a hand-read of the file next to its own `@see` line found it.

Next: This is the last budgeted iteration but one. Three Mediums remain, all docs - CSV-3, CSV-4 and CSV-17 - and five Lows. Iteration 10 writes the WRAPUP handoff, since the ledger is not at the severity floor and a closing audit is not the legal shape here.

## iter 10/10 | 59a2fdbf-191704 | 2026-09-02 | WRAPUP | done

Task: Final budgeted iteration. The ledger is not at the severity floor - three Mediums are open - so the closing full audit is not the legal shape here, and this iteration tidies the ledger and writes the handoff instead.

Changed: JOURNAL.md.

Checkpoint: 551ccf46d0c5ca4eb581eece159a27563e106ae7

Verification:
- The run cannot converge and the reason is one line: the Definition of done requires zero open Medium, and three remain. The other closing conditions this run could reach, it reached - the map is clear at twenty-two of twenty-two rows, no High is open, and every standing claim re-derives.
- The ledger needs no reordering. Next holds three Mediums, all class docs, because every runtime and build-ci Medium was closed this run; Later holds five Lows with the two runtime ones first, which is the ordering the Method prescribes.
- Every standing claim was re-run rather than assumed. check-claims.sh reports 37 checked, 0 mismatched, 0 errored, across nineteen batteries. All three Settled classes re-derive from their own recorded commands: the php_user_filter shutdown enumeration prints nothing, the null-params enumeration exits 0 with no failing site, and the deprecations battery passes 8/8. The Declined section is empty, so there is no Derivation to re-run.
- Every open task carries a severity, a class and a runnable acceptance check, and every acceptance check this run filed was executed against the unfixed code and observed to fail before it was written down.
- Verify: exit 1 with Tests: 1019, Failures: 3 - the same three StreamTest cases as every checkpoint of this run and the two before it, tracked as CSV-5. The suite is red for that one reason and nothing this run did moved it. The total rose from 1009 to 1019 across the run: ten tests added beside the fixes that needed them.
- No stall: the entry records the run's close, and the previous entry closed a task.

Handoff for the next run, in the order the queue will take them:
- No open High, and the three open Mediums are all documentation, all in `docs/9.0/`. CSV-3 is the one to take first: `Info::getDelimiterStats()` is documented as returning a field count and returns fields plus records, and the suite pins the behaviour, so the documentation is what changes. CSV-4 and CSV-17 are both worked examples that do not run as written - the escape-formula page states output the code does not produce, and the record-type-inference page spells a class the autoloader cannot resolve and calls a private constructor.
- All three are docs fixes with runnable acceptance checks, so a run of five iterations closes the Medium tier and reaches the evaluator gate with budget to spare. That gate has never been invoked on this project: no run has yet reached a state where it could be.
- Five Lows are carried, none blocking: CSV-20 (Stream::seek leaves key() one behind SplFileObject, no public divergence found), CSV-25 (CastToFloat names `int` in one failure message), CSV-26 (rector.php ships in the published archive where its four sibling dev configs do not), CSV-5 (three StreamTest cases assume STDOUT is non-seekable, which is why the gate is red on every run), and CSV-6 (a misspelled class name and a missing semicolon in one docs page).
- CSV-5 deserves attention out of severity order at some point: it is a Low by the rubric, since a user never runs the suite, but it is the single reason the verify gate has never been green on this project, and the stream battery already demonstrates its fix path - a stream_socket_pair is non-seekable in-process whatever stdout happens to be.
- The Proposed item about a zero-length limit raising OutOfBoundsException is still awaiting a user decision and blocks nothing.
- Two new batteries this run are worth knowing about: `packaging` grades what `git archive` actually ships, and `deprecations` resolves every deprecation notice's target. Both guard classes that were closed rather than instances.

Learnings: A run that spends every iteration on the ledger clears more than one that alternates, but only because an earlier run had already cleared the map - this run started with twenty-two of twenty-two rows swept and a queue of reproduced defects, and spent all ten iterations closing them. That is the position the sweep exists to produce, and it took two earlier runs to reach it.

Next: The run ends out of budget with ten Mediums closed, three Mediums and five Lows open, and the map clear. Relaunch in a fresh session to close the docs tier and reach the evaluator gate; the state files carry everything forward.

## iter 1/10 | d739363f-200416 | 2026-09-02 | CSV-3 | done

Task: CSV-3 (Medium, docs) - `Info::getDelimiterStats()` is documented as returning the number of CSV fields found, but it counts with `COUNT_RECURSIVE` and returns fields plus records. Consequence: a user reading the value as a field count gets a number inflated by the record count - one 3-field record reports 4.

Changed: src/Info.php, src/functions.php, docs/9.0/connections/controls.md, .jeffy/probes/info-functions/ (run.php, paths, claims, README.md), BACKLOG.md (CSV-3 deleted), JOURNAL.md.

Checkpoint: d116e361769f23f67d9c93270f5c9fc3b115821a

Verification:
- The filed reproduction was the first command of the iteration: the grep printed the claim at two sites and `Info::getDelimiterStats(Reader::fromString("a;b;c\nd;e;f\n"), [";"], -1)` returned 8 for a document holding 6 fields.
- The suite pins the behaviour rather than the wording, so the documentation is what changed: `InfoTest::testDetectDelimiterListWithInconsistentCSV` asserts `['|' => 12, ';' => 4]` for three pipe records and one semicolon record of three fields each - 9 fields plus 3 records, and 3 fields plus 1 record - and `testExpectedLimitIsUsedIssue366` asserts 4 for one 3-field record. Both are the real formula, hand-checked here against the code.
- CSV-3 was filed as two sites and the enumeration found four: the same claim stands in `Info::getDelimiterStats`'s docblock, in the deprecated `delimiter_detect` docblock that delegates to it, in the prose sentence on the docs page and again in the sentence describing the return value, with the page's worked example stating a number as well. `docs/9.0/upgrading.md` names the function twice but makes no claim about the value, so it is outside the class.
- The behaviour behind the new wording was measured before it was written, not after: 2 records x 3 fields scores 8; the same document at limit 1 scores 4; a document of single-field records scores 0; a mixed document counts only the records the delimiter split; an absent delimiter and a multi-byte candidate both score 0.
- The first replacement wording was rejected by the acceptance check and correctly so. It read "the number of CSV fields found plus the number of records", which is accurate but still carries the phrase that misleads, and in `src/Info.php` it only escaped the grep because a line break fell between "CSV" and "fields". Passing a check on a line wrap is not passing it. The wording now says "the number of fields the delimiter produced, plus the number of records those fields came from" at all four sites.
- The docs example stated `'|' => 20` over 10 records against an unspecified file, which is a number that document cannot produce: for R records of k fields the score is R(1+k), so 20 over 10 records requires k=1, and single-field records are the ones the method filters out. The example now names the document it describes - 10 records of 5 fields - and states 60, which was measured by running it.
- Acceptance: the filed grep over `src/Info.php` and the docs page exits 1 with no output, and the battery asserts the filed value `[";"] === 8`.
- The replacement wording is pinned rather than trusted. Seven checks were added to the info-functions battery: both docblocks read back through reflection must not describe the value as a bare field count and must name the record term, and the docs page is graded by parsing the score out of the page, checking it against the document the page describes in words (10 x 5 fields, so 50 + 10) and checking it again against a real run of that document.
- The battery's first draft failed on the new checks and the code was read before the check was changed: `array_fill_keys($delimiters, 0)` seeds the result in submission order, so `[' ', '|']` returns `' '` first. The expectation was wrong, not the code.
- Differential evidence: restoring the pre-fix text at all four claim sites reddens exactly four checks - both docblock checks, the page's stated score against the document it describes, and that score against a real run - and leaves the other 39 green. The battery grew from 36 to 43 checks, so the README's observed-failing procedure was re-run: the `$limit`-discarding mutation still reddens exactly three checks and exits 1, unchanged, because none of the new checks reads `$limit`.
- Verify: exit 1 with Tests: 1019, Failures: 3 - the same three StreamTest cases as every previous checkpoint, tracked as CSV-5 and unmoved. No PHP behaviour changed this iteration; the only src edits are docblock text. phpstan exits 0 with "No errors" and php-cs-fixer exits 0 with "Found 0 of 162 files that can be fixed".
- Battery ownership: the diff touched src/Info.php, src/functions.php and the docs page, all three declared by .jeffy/probes/info-functions/paths and by no other battery's paths file. The docs page was added to that paths file in this iteration, because a check now reads it and a claim nothing re-runs is a claim nobody checks. The battery is green at 43/43 and its claims line was updated in the same edit. check-claims.sh reports 37 checked, 0 mismatched, 0 errored.
- A zero `$limit` raises `OutOfBoundsException` through `slice(0, 0)`, met while measuring the boundaries. That is the standing Proposed item about a zero-length limit, reached through a different caller, so it is not filed again.
- No stall: three product files changed and one BACKLOG.md item changed state.

Closed this run: CSV-3 (Medium, docs) - the delimiter-stats score is described as what it is at all four sites that claimed otherwise, with the docs page's worked example corrected to a number a real document produces.

Learnings: An acceptance check that greps for the misleading phrase is not satisfied by a correct sentence that still contains it; when a replacement fails such a check, reword rather than argue, because the phrase is what misled the reader in the first place. A documented example number is a standing claim like any other: grade it by parsing the number out of the page and running the document the page describes, which catches both a wrong number and a document shape that cannot produce it.

Next: Two Mediums remain, CSV-4 and CSV-17, both docs examples that do not run as written. Iteration 2 takes CSV-4.

## iter 2/10 | d739363f-200416 | 2026-09-02 | CSV-4 | done

Task: CSV-4 (Medium, docs) - the worked example in `docs/9.0/interoperability/escape-formula-injection.md` states the output `2,2017-07-25,"Important Client","\t=2+5",240,` but `new EscapeFormula()` prepends the default `'`. Consequence: a developer hardening a CSV export against formula injection compares their real output against the documented output, sees a different escape character, and cannot tell whether the defence applied.

Changed: docs/9.0/interoperability/escape-formula-injection.md, .jeffy/probes/charset-escape/ (run.php, paths, claims, README.md), BACKLOG.md (CSV-4 deleted), JOURNAL.md.

Checkpoint: c99386517a8596797250be138192a43c1170876a

Verification:
- The filed reproduction was the first command of the iteration: the documented example run verbatim produced `2,2017-07-25,"Important Client",'=2+5,240,` against the page's `2,2017-07-25,"Important Client","\t=2+5",240,`.
- The documented string is what `EscapeFormula` produced before 9.7.4, which the page's own warning at the top says changed the constructor defaults to comply with OWASP. The page was updated in one place and not the other, so the fix is the stated output, not the code.
- Every stated output on the page was enumerated rather than only the one filed, because a page that is stale in one example is a candidate for being stale in all of them. There are two: this writer example and the reader example that states `['2', '2017-07-25', 'Important Client', '=2+5', '240', '']`. The second was run against the document the writer example now produces and returns exactly that, so the class holds one instance and it is fixed.
- Acceptance as filed - running the documented example verbatim produces exactly the string the page states - passes with exit 0. The same check against the pre-fix page exits 1 and prints both strings, so the check is strong enough to fail.
- The check is kept rather than run once: the charset-escape battery now extracts the writer example's code from the page, executes it as a script, and compares its real output against the output parsed out of the same page. Neither side is retyped in the battery, so the check reddens for a wrong page and for a broken escape alike.
- Differential evidence, page side: restoring the pre-fix documented output reddens exactly two checks - the example's real output against the stated one, and the assertion that the stated output carries the default escape character.
- Differential evidence, code side: the battery's recorded observed-failing mutation was re-run because the battery grew from 61 to 67 checks. With the `default` arm of `escapeField()`'s return match changed from `$this->escape.$strOrNull` to `$cell`, the battery goes red on 17 checks including the new docs-page one, and exits 1. `git diff src/EscapeFormula.php` is empty afterwards.
- That re-measurement did not reproduce the figure the README stated. The file said fourteen checks for a mutation described only in prose; only one of the six checks added this iteration depends on the prefix, so fourteen cannot become 17 by growth alone and the earlier number was taken against some other mutant. This is the loop's own instrument drifting rather than a defect in the product, so it is recorded here and the README now names the exact line the mutation edits instead of describing the behaviour.
- Verify: exit 1 with Tests: 1019, Failures: 3 - the same three StreamTest cases as every previous checkpoint, tracked as CSV-5 and unmoved. No PHP source changed this iteration; the EscapeFormula mutation was applied and reverted inside it and the tree is clean of it.
- Battery ownership: the diff touched the docs page and the charset-escape battery. That page was added to .jeffy/probes/charset-escape/paths in this iteration because a check now reads it, and no other battery's paths file matches any changed path. The battery is green at 67/67 and its claims line was updated in the same edit. check-claims.sh reports 37 checked, 0 mismatched, 0 errored.
- No stall: a product file changed and one BACKLOG.md item changed state.

Closed this run: CSV-3 (Medium, docs), CSV-4 (Medium, docs) - the formula-injection page now states the output its own example produces, pinned by a battery that runs the example rather than trusting it.

Learnings: A battery's observed-failing procedure has to name the edit, not the behaviour. "Mutated to return the field without prefixing the escape" reads unambiguous and was not: re-running it against the same description gave 17 reddened checks where the file claimed fourteen, and there is no way to tell now which mutant produced the old number. Record the line and the replacement text.

Next: One Medium remains, CSV-17, the record-type-inference page whose field-list example cannot run. Iteration 3 takes it.

## iter 3/10 | d739363f-200416 | 2026-09-02 | CSV-17 | done

Task: CSV-17 (Medium, docs) - the field-list example in `docs/9.0/reader/record-type-inference.md` cannot run: it spells the class `DatetimeField`, calls it with no argument where `$format` is required, and calls `new TimeField()` whose constructor is private. Consequence: a user following the documented way to add date and time inference gets three fatal errors in sequence.

Changed: docs/9.0/reader/record-type-inference.md, .jeffy/probes/schema-structured-fields/ (run.php, paths, claims, README.md), BACKLOG.md (CSV-17 deleted, CSV-27 filed, one Proposed item), JOURNAL.md.

Checkpoint: 7273bb8271e9605e1b80bbb8d5cdedaab4f38e5e

Verification:
- The filed reproduction was the first command of the iteration and all three failures were provoked in sequence rather than taken from the filing: `Class "League\Csv\Schema\DatetimeField" not found`, then `ArgumentCountError: Too few arguments to ... DateTimeField::__construct(), 0 passed`, then `Error: Call to private League\Csv\Schema\TimeField::__construct()`.
- One nuance the filing does not carry and the fix depends on: the misspelling breaks only the autoloader path. PHP matches class names case-insensitively, so with `use League\Csv\Schema\DateTimeField;` in scope, `new DatetimeField()` resolves and the user meets the constructor error instead. Written fully-qualified, which is what a reader copying a snippet from a page that shows no imports does, the PSR-4 lookup is case-sensitive on the filesystem and the class is not found. Both paths were broken and both were driven.
- The correct API was read from the source rather than guessed: `DateTimeField::__construct` requires a format; `::common()`, `::machine()`, `::localized()` and `::fromFormat()` return a `FieldList`; `::timestamp()` returns one field; `TimeField`'s constructor is private and `::seconds()`, `::minutes()` and `::hours()` are the entry points. `FieldList::append(Field|self ...$items)` is variadic and flattens a list, which is what lets the corrected example pass `DateTimeField::common()` straight in.
- The example now reads `FieldList::default()->append(DateTimeField::common(), TimeField::seconds())` and runs, producing sixteen fields - the three defaults, twelve datetime formats and one time field. Four sentences were added naming the named constructors, because an example that silently switches from `new X()` to `X::common()` leaves the reader wondering why.
- Acceptance as filed, both halves: `grep -c DatetimeField docs/9.0/reader/record-type-inference.md` prints 0, and the example extracted verbatim from the page and run under `vendor/autoload.php` exits 0. The same extraction against the pre-fix page exits 255.
- The class was enumerated rather than assumed. Every CamelCase class name and every `Class::method(` the page shows was resolved against the real code, and every named argument it uses - `Inspector::default(sampleLimit:)`, `new CustomField(fieldParser:, fieldTypeName:)`, `new EnumField(enumClass:, confidenceThreshold:)`, `StringField::builtIns(confidenceThreshold:)`, `new Inspector(fieldList:)` - was constructed. `DatetimeField` was the only unresolved name and every named argument holds.
- That enumeration surfaced a second, different defect on the same page, filed as CSV-27 (Medium, docs) rather than fixed here: the worked scenario builds a `;`-delimited document and never calls `setDelimiter(';')`, so the reader splits on the default comma and every stated output on the rest of the page - the header, record 4, both `types()` listings, the comparison table - disagrees with what the code prints. Reproduced: the header comes back as the single column `name;age;city;id;gender`, and adding `setDelimiter(';')` makes every documented output correct.
- Three findings this run share one root cause - the documentation's examples are never executed - so per the three-strike rule the answer is one structural item rather than a fourth instance patch. It is filed under Proposed, because a docs-example harness is a new dev-tooling surface and needs a docs convention marking which blocks are self-contained; that is the maintainer's call.
- The page is now graded rather than read: seven checks were added to the schema-structured-fields battery. Every field class the page names in backticks must have its PSR-4 file under `src/Schema/`, and the field-list example is extracted from the page, executed, and required both to run clean and to add a datetime and a time field. The by-file check exists because `class_exists()` is case-insensitive and passes on `DatetimeField`; that check is kept alongside it and stays green on the pre-fix page, which is the instrument disclosing its own blind spot rather than hiding it.
- Differential evidence: against the pre-fix page exactly three of the seven redden - the PSR-4 file check naming `DatetimeField`, the example's execution, and the two field kinds it fails to add.
- The battery grew from 270 to 277 checks, so both recorded observed-failing procedures were re-run in this iteration: `observed-failing-setfield-limit.sh` prints 273/277 and `observed-failing-timefield-separator.sh` prints 272/277, the same four and five reddened checks as before, and the claims file and the two figures the README states were updated to match. `git status --porcelain src/` is empty afterwards.
- Verify: exit 1 with Tests: 1019, Failures: 3 - the same three StreamTest cases as every previous checkpoint, tracked as CSV-5 and unmoved. No PHP source changed this iteration.
- Battery ownership: the diff touched the docs page and the schema-structured-fields battery. That page was added to that battery's paths file in this iteration because a check now reads it, and no other battery's paths file matches any changed path. The battery is green at 277/277. check-claims.sh reports 37 checked, 0 mismatched, 0 errored.
- No stall: a product file changed and three BACKLOG.md items changed state.

Closed this run: CSV-3 (Medium, docs), CSV-4 (Medium, docs), CSV-17 (Medium, docs) - the record-type-inference page's field-list example now runs, pinned by a battery that executes it.

Learnings: `class_exists()` is the wrong instrument for a misspelled class name, because PHP resolves class names case-insensitively once one is loaded or aliased and it will answer true for a spelling the PSR-4 autoloader cannot find on disk; check for the file the autoloader would look up. Enumerating a page's whole API surface costs one command and found a second defect worth more than the one filed.

Next: One Medium remains, CSV-27, filed this iteration on the same page. Iteration 4 takes it.

## iter 4/10 | d739363f-200416 | 2026-09-02 | CSV-27 | done

Task: CSV-27 (Medium, docs) - the worked scenario in `docs/9.0/reader/record-type-inference.md` builds its `;`-delimited document with `Reader::fromString($doc)` and `setHeaderOffset(0)` and never calls `setDelimiter(';')`. Consequence: a reader who copies the setup gets a single-column schema, and every output the rest of the page states disagrees with what their code prints.

Changed: docs/9.0/reader/record-type-inference.md, .jeffy/probes/schema-structured-fields/ (run.php, claims, README.md), BACKLOG.md (CSV-27 deleted), JOURNAL.md.

Checkpoint: 01e009f9f5effaa1e759ef0cce97d438e7585942

Verification:
- The filed reproduction was the first command of the iteration and printed the header `["name;age;city;id;gender"]` where the page states `["name","age","city","id","gender"]`.
- The fix is one line, `$document->setDelimiter(';');`, placed before `setHeaderOffset(0)`. Both orders were checked against a small document first and give the same header, so the order is a readability choice and not a contract.
- The finding's Consequence generalises over every output the page states, so that set was enumerated and every member driven rather than sampled. There are six: the header, `getRecords()` record 4, `inferRecords()` record 4, the default `types()` listing, the custom inspector's `types()` listing, and the custom `inferRecords()` record 4 whose gender is null, plus the stated failure of `getRecordsAsObject(Poi::class)`. With the one-line fix all six match the page exactly and the object mapping fails as described. Nothing else on the page was wrong.
- Differential evidence: with the `setDelimiter` line removed, five of the six stated outputs mismatch and the sixth - the object mapping - still throws, but as `MappingFailed` rather than the `TypeCastingFailed` the page describes, which is the right colour for the wrong reason. The battery check therefore asserts the exception class rather than the fact of throwing, and all seven checks redden without the fix.
- Acceptance as filed passes: the setup extracted from the page produces `getHeader()` equal to `['name','age','city','id','gender']` and `inferSchema()->types()['age']` equal to `numeric`. Extracted from the pre-fix page the same check exits 1.
- The scenario is pinned rather than run once: seven checks were added to the schema-structured-fields battery, which already owns this page. The setup block is extracted from the page and executed, so a future edit that drops the delimiter again reddens them; the seven expectations are the outputs the page states in prose beside each snippet.
- The battery grew from 277 to 286 checks, so both recorded observed-failing procedures were re-run in this iteration: `observed-failing-setfield-limit.sh` prints 282/286 and `observed-failing-timefield-separator.sh` prints 281/286 - the same four and five reddened checks as before - and the claims file and the two figures the README states were updated to match. `git status --porcelain src/` is empty afterwards.
- Verify: exit 1 with Tests: 1019, Failures: 3 - the same three StreamTest cases as every previous checkpoint, tracked as CSV-5 and unmoved. No PHP source changed this iteration.
- Battery ownership: the diff touched the docs page and the schema-structured-fields battery, which is the only battery whose paths file matches. It is green at 286/286. check-claims.sh reports 37 checked, 0 mismatched, 0 errored.
- No stall: a product file changed and one BACKLOG.md item changed state.

Closed this run: CSV-3 (Medium, docs), CSV-4 (Medium, docs), CSV-17 (Medium, docs), CSV-27 (Medium, docs) - the record-type-inference page's worked scenario now reads its own document, with all six of its stated outputs driven from the page's own setup.

Learnings: Never build a check with `php -r` when the code carries a regex: the shell eats the backslashes and the extraction silently matches nothing, which reads exactly like a page that does not carry the block. This cost a wasted run in iteration 2 and again here; write the check to a file and run the file.

Next: The Medium tier is empty for the first time on this project. Five Lows remain and the ledger is at the severity floor, but no full audit has been run this run, so the Definition of done is not yet reachable. Iteration 5 runs the full fresh-evidence audit, which is what the closing conditions require before the evaluator gate can be invoked with budget left to answer a REJECT.

## iter 5/10 | d739363f-200416 | 2026-09-02 | CSV-5 | done

Task: CSV-5 (Low, test) - `StreamTest::testFSeekThrowsExceptionOnNonSeakableResource`, `::testRewindThrowsException` and `::testCreateStreamWithNonSeekableStream` use `STDOUT` and `php://stdout` as stand-ins for a non-seekable stream, so all three fail whenever stdout is a regular file.

Changed: src/StreamTest.php, PLAN.md (Environment fingerprint, Verify count, two Lessons), .jeffy/probes/stream/README.md, BACKLOG.md (CSV-5 deleted), JOURNAL.md.

Checkpoint: 579d3070186b968edacfb01ed8ada225636fec42

Verification:
- Taken out of severity order deliberately, and the reason is a closing condition rather than a preference: the Definition of done requires the Verify command green in the declaring iteration, and these three failures were the only thing keeping it red on this project across three runs. Two runtime Lows sit above it in the queue and stay open; they are carried, this one was not carryable. The severity is unchanged - a user never runs the suite, so it is a Low by the rubric and was not promoted to justify working it.
- The filed reproduction was the first command of the iteration: `phpunit --filter StreamTest` with stdout redirected to a regular file exits 1 with exactly those three failures, and the same command under a pipe exits 0.
- The class was enumerated by provoking the failure rather than by grepping for `STDOUT`. There are eight `STDOUT` or `php://stdout` sites in the test tree and only three depend on non-seekability; the other five - a clone refusal, a filter-resource fixture, an fputcsv write, a var_dump and a negative-offset rejection that is argument validation - are unaffected and were left alone. A grep would have rewritten all eight.
- The fix gives the three tests a `stream_socket_pair`, which is never seekable, through one private helper that asserts `stream_get_meta_data(...)['seekable']` is false before handing the stream over. Both ends are held in locals, because closing one end closes the other.
- The tests were not weakened, which is the constraint that matters when a fix edits a test: the count is unchanged at 1019 and assertions rose from 2031 to 2037, the six the fixture's own non-seekability check adds. Proved by mutation rather than asserted: with `Stream::from()` changed to report every stream seekable, all three tests fail again. They still pin exactly what their names claim, and now they pin it however the suite is invoked rather than only under a pipe.
- Acceptance as filed passes: `vendor/bin/phpunit --no-coverage > /tmp/csv-verify.txt 2>&1` exits 0.
- Verify: green for the first time on this project - exit 0, Tests: 1019, Assertions: 2037, Deprecations: 17, Skipped: 3, through the wrapper.
- Two standing claims this fix invalidated were re-derived in the same iteration rather than left. The Environment fingerprint said the gate was red for a fourth reason tracked as CSV-5; both its derivation commands were re-run, the skip markers still enumerate to the same three xdebug-guarded header tests and ext-mysqli and ext-pgsql are still absent, so the sentence now records the three skips as the whole exclusion list and the gate as green. `Verify count` was an unfilled placeholder and is now 1019, the figure the wrapper's own green line reports.
- phpstan and php-cs-fixer both went red on my change and both were fixed inside the iteration: the `array{resource, resource}` annotation overstated what `stream_socket_pair()` returns, and the two new imports were out of alphabetical order. Both are green again - "No errors" and "Found 0 of 162 files that can be fixed".
- The stream battery's README described CSV-5 as an open contrast to its own socket-pair fixture; that sentence is now past tense. The battery itself is unchanged and green at 106/106. check-claims.sh reports 37 checked, 0 mismatched, 0 errored.
- Battery ownership: the diff touched src/StreamTest.php, which no battery's paths file declares. The stream battery was run anyway as the nearest instrument to the code under test.
- No stall: a product file changed and one BACKLOG.md item changed state.

Closed this run: CSV-3 (Medium, docs), CSV-4 (Medium, docs), CSV-17 (Medium, docs), CSV-27 (Medium, docs), CSV-5 (Low, test) - the suite is green whichever way it is invoked, which is the first time the verify gate has passed on this project.

Learnings: A Low can be a hard precondition for convergence without being a higher severity. CSV-5 was correctly scored - no user runs the suite - and it still blocked every declaration this project could ever make, because the closing rule requires a green gate. Severity orders the queue; it does not decide what unblocks the run, and reading the closing conditions for mechanical blockers is worth doing before planning the last iterations.

Next: The ledger is at the severity floor with four Lows carried, the map is clear at 22 of 22 rows, and the gate is green. Iteration 6 runs the full fresh-evidence closing audit, which the Definition of done requires before the evaluator gate can be invoked.

## iter 6/10 | d739363f-200416 | 2026-09-02 | AUDIT | audit

Task: The full fresh-evidence closing audit the Definition of done requires, over a map that lists no unswept row.

Changed: PLAN.md (Verify command, Verify count), BACKLOG.md (CSV-6 re-scored Medium and moved to Next, one Declined entry), JOURNAL.md.

Checkpoint: a99e5c5fbb0a1ac45a307be6aab982a5e9e57743

Verification:
- Scores, claiming all 22 of 22 inventory rows, every one of them current: architecture None, code quality None, security None, testing None, error handling None, performance None, documentation Medium, dependency hygiene Low, developer experience Low, correctness Low, observability None. UX and accessibility do not apply - the Operating envelope records no CLI, no bin entry and no user-facing surface. This audit is not clean: it files one Medium, so closeout has not begun.
- Fresh evidence, not a restatement of the ledger: all 24 batteries were executed this iteration and all are green, 1918 checks in total across them. Every inventory row was re-derived against its battery's paths file and none is stale.
- All three Settled classes re-derive from their own recorded commands: the null-params enumeration prints nothing and exits 0, the deprecations battery passes 8/8, and the php_user_filter shutdown probe prints nothing for all four filter classes. The Declined section was empty at the start of this audit, so there was no Derivation to re-run; it now holds one, whose derivation was run when it was written.
- The Oracle class and the Environment fingerprint were both re-read and the fingerprint's two derivation commands re-run: the skip enumeration still returns the same six xdebug-guarded lines in three test files, giving the three skips the suite reports, and ext-mysqli and ext-pgsql are still absent. No test asset the fingerprint excludes is claimed green anywhere.
- The Verify count cell disagreed with the wrapper and the cause was fixed rather than the cell. The wrapper reads the first integer on the line matching the summary pattern, and PHPUnit's ANSI colour codes put `30` there, so the cell could only ever have held a colour code. The Verify command now carries `--colors=never`, the wrapper's green line reads `Tests: 1019, Assertions: 2037, Deprecations: 17, Skipped: 3.`, and the cell holds 1019, which is now the wrapper's own figure rather than a typed one. The flag changes formatting only; the same 1019 tests run.
- Error handling was probed rather than assumed, and the probe's output was read before anything was filed. An AST pass found four empty `catch (Throwable)` bodies in `Serializer/CallbackCasting.php` and a grep found three `@` suppressions. All seven are correct: each empty catch either falls straight through to `throw new MappingFailed` or means "this candidate type is not a class, try the next" in a loop that ends in a throw, and each `@` is immediately followed by an explicit throw - `@fopen` into `UnavailableStream::dueToPathNotFound`, both `@preg_match` calls into a `ValueError` or a `QueryException`. Nothing was filed, which is the point of reading first.
- The 17 deprecations the suite reports were traced rather than tolerated. They come from the library's own `#[Deprecated]` constants in `EncloseField` and `RFC4180Field`, both of which are themselves deprecated classes, exercised by the tests that cover them. No non-deprecated code references either constant, and driving the supported replacements - `Writer::forceEnclosure()` and `setEscape()` - under a handler that promotes diagnostics emits nothing. A user on the supported path meets no deprecation.
- Security and dependency hygiene: `composer audit` reports no advisory. Runtime requirements are `php ^8.2.0` and `ext-filter` only. The one abandoned package it names, `doctrine/annotations`, is a transitive dev dependency of phpbench that the archive does not carry; it is Declined with that derivation rather than filed, because no user of the shipped product meets it and the choice is phpbench's.
- Packaging was graded on the artifact: `git archive HEAD` ships 107 files - 102 under `src/`, plus the manifest, the licence, the autoloader, the polyfill and `rector.php` - and zero `*Test.php`, `*TestCase.php`, `*Bench.php`, `PLAN`, `BACKLOG`, `JOURNAL` or `.jeffy` entries. `rector.php` is the open CSV-26.
- Testing was probed in isolation before being scored, as the Method requires: `InfoTest`, `BufferTest` and `StreamTest` each pass run alone, so the suite's green is not standing on state another module leaks.
- Performance is scored None on the swept map with the limit stated: no benchmark baseline is stored in the repository, so there is nothing to compare against, and no pathology was reproduced in the code this run touched. That is a narrower claim than "performance is fine".
- Every carried Low was re-run and re-scored, and one moved. CSV-20, CSV-25 and CSV-26 all still reproduce and all three stay Low: CSV-20's own line records that no public path was found to diverge, CSV-25 is a wrong type name inside an exception message that is still raised with the right class and subject, and CSV-26 puts one 1KB dev config into `vendor/` where four siblings are excluded. CSV-6 does not stay Low. Its reader example was extracted and run through `php -l`, which exits 255 with `syntax error, unexpected variable "$reader"`, so it is a documented example a reader cannot run - the same class as CSV-4 and CSV-17, both of which this run scored Medium. It is re-scored Medium with its Consequence stated. Raising it is the same discipline as refusing to lower one: the closing audit re-reads these lines precisely so a convenient Low does not survive the declaration.
- No stall: one BACKLOG.md item changed state and one Declined entry was added.

Learnings: A count cell that will not match is a signal about the measuring instrument, not about the number - PHPUnit's ANSI colour codes made the first integer on the summary line a colour code, so no honest value could ever have satisfied the check, and the fix was to stop colouring the output. When a closing audit re-reads severities, the pressure runs toward leaving an under-scored finding alone, because raising it costs the run an iteration; CSV-6 sat at Low for three runs because it was filed as two typos rather than as an example that does not parse.

Next: Documentation is Medium, so the run is not converged. Iteration 7 fixes CSV-6, the last Medium, and iteration 8 invokes the evaluator gate with two iterations still in reserve for a REJECT.

## iter 6/10 | d739363f-200416 | 2026-09-02 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines, so all but the last 10 entries move to the archive.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: a99e5c5fbb0a1ac45a307be6aab982a5e9e57743

Verification:
- JOURNAL.md held 26 entries over 705 lines. The split was taken only on lines beginning `## iter` followed by a digit, so the heading-grammar example in the preamble was neither counted nor moved, and the preamble is kept in place.
- 16 entries moved. The archive grew from 10 entries to 26 and was appended to, never overwritten; JOURNAL.md now holds 10 entries over 297 lines.
- No entry text was altered in either file.

Learnings: none.

Next: as the AUDIT entry above records.

## iter 7/10 | d739363f-200416 | 2026-09-02 | CSV-6 | done

Task: CSV-6 (Medium, docs) - the reader example in `docs/9.0/interoperability/escape-formula-injection.md` omits the statement terminator after `$reader->addFormatter($formatter->unescapeRecord(...))`, so the block does not parse, and the prose above it misspells the class as `Esca[eFormula::unescapeRecord`. Consequence: a user copying the documented way to unescape a formula-protected CSV gets a PHP parse error.

Changed: docs/9.0/interoperability/escape-formula-injection.md, .jeffy/probes/charset-escape/ (run.php, claims, README.md), BACKLOG.md (CSV-6 deleted), JOURNAL.md.

Checkpoint: 9e05e896801e03f3b7e9c96303ac96469db8aa3c

Verification:
- Both halves of the filed reproduction were the first commands of the iteration: the reader example extracted from the page fails `php -l` with `syntax error, unexpected variable "$reader"` at exit 255, and the misspelling greps to one occurrence.
- The class was enumerated before the fix, not after: every fenced `php` block on the page was extracted and linted. Five blocks, two do not parse - the reader example, and the `EscapeFormula` API signature listing at the top. The second is not a defect and was deliberately left alone: it is three bare declarations used as a signature reference, a documentation convention no reader copies as a script. Fixing it would have meant inventing bodies for it.
- Acceptance as filed passes on both halves: the reader example parses under `php -l` at exit 0, and `grep -c 'Esca\[eFormula'` prints 0. The trailing space after `$reader->first();` went with the same edit.
- The two defects are pinned as classes rather than as the two typos, because the next typo will not be these two. Every `Class::method` the page names must have its PSR-4 file under `src/` and a real method behind it, and every runnable `php` block must pass `php -l`, with a signature listing recognised by its shape - every line a bare declaration with no body - and excluded, and `SplFileObject` allowlisted as a class the page names and this package does not own. Resolution is by file rather than by `class_exists()` for the reason iteration 3 recorded: PHP matches class names case-insensitively and the PSR-4 autoloader does not.
- Differential evidence: against the pre-fix page exactly the two new substantive checks redden, each naming its own defect - `Esca[eFormula::unescapeRecord` in the reference list, and `block 2` with the parse error in the block list.
- The battery grew from 67 to 71 checks, so its recorded observed-failing procedure was re-run: the `escapeField` mutation still reddens exactly 17 checks, unchanged, because the four checks added here read the page rather than the escape. The claims file and the README figure were updated in the same edit.
- Verify: green, Tests: 1019, Assertions: 2037, Deprecations: 17, Skipped: 3.
- Battery ownership: the diff touched the docs page and the charset-escape battery, which is the only battery whose paths file matches. It is green at 71/71. check-claims.sh reports 37 checked, 0 mismatched, 0 errored.
- No stall: a product file changed and one BACKLOG.md item changed state.

Closed this run: CSV-3 (Medium, docs), CSV-4 (Medium, docs), CSV-17 (Medium, docs), CSV-27 (Medium, docs), CSV-5 (Low, test), CSV-6 (Medium, docs) - the formula-injection page's reader example parses and every class reference on it resolves.

Learnings: When a page is graded by linting its code blocks, the grader has to know which blocks are meant to run. A signature listing is not a broken example, and a checker that cannot tell the difference either files a false finding or gets silenced entirely; recognising it by shape - all declarations, no bodies - keeps the check strict everywhere else.

Next: No High and no Medium remain, three Lows are carried, the map is clear at 22 of 22 and the gate is green. Iteration 8 brings the standing claims current and invokes the adversarial evaluator, invocation 1, with two iterations left to answer a REJECT.

## iter 8/10 | d739363f-200416 | 2026-09-02 | EVALUATOR | converged

Task: Bring every standing claim current, invoke the adversarial evaluator as invocation 1 of this run, and declare convergence if it passes and the closing conditions hold.

Changed: .jeffy/evaluator/d739363f-200416-1.md (new), BACKLOG.md (Converged line), JOURNAL.md.

Checkpoint: b8abf4501fb769ed9ff0eb5cfe1834c33fd3534b

Verification:
- The currency set was brought current before the gate was spawned, not after. Every one of the 22 inventory rows was re-derived against its battery's paths file and none is stale. The one Declined entry's Derivation re-runs: `composer why doctrine/annotations` still reports phpbench as the only requirer and `git archive HEAD | tar -t | grep -c doctrine` prints 0. All three Settled-class enumerations re-run clean - the null-params enumeration silent at exit 0, the deprecations battery 8/8, the shutdown probe silent for all four filter classes. check-claims.sh reports 37 checked, 0 mismatched, 0 errored. The Oracle class and Environment fingerprint were re-read and the Verify count cell holds 1019, the figure the wrapper's own green line reports.
- Every finding ID PLAN.md names resolves. CSV-8, CSV-9, CSV-10 and CSV-11 appear only inside inventory row scopes as the names of families a battery pins, and CSV-5 appears in the Environment fingerprint as closed. PLAN.md names no ID as carried or blocked, so nothing dangles.
- Evaluator: PASS. One fresh-context sub-agent, invocation 1 of this run, ran 67 commands and wrote `.jeffy/evaluator/d739363f-200416-1.md` before returning, carrying no machine-absolute path. It confirmed each of the six closed tasks failed at the base commit 58bf377 and passes at HEAD, re-executed every filed Acceptance, and re-drove the fixes' own new claims independently - the corrected delimiter-stats number, the nine named constructors the CSV-17 prose added, all six stated outputs of the record-type-inference scenario, and every php block on the escape-formula page.
- The gate attacked the two places this run was most likely to have fooled itself, and both held. The edited test file lost no test: 18 test methods and 20 StreamTest cases on both sides, assertions 2031 to 2037, the six the new fixture adds; mutating `Stream::from` to report every stream seekable reddens all three edited tests. And `git diff 58bf377..HEAD -- src/` carries no runtime change at all beyond docblock prose and that test file, with phpunit.xml, composer.json and .gitattributes untouched.
- It also confirmed the `--colors=never` flag added in iteration 6 narrowed nothing: the suite reports byte-identical counts with and without it.
- Verify: green in this iteration, Tests: 1019, Assertions: 2037, Deprecations: 17, Skipped: 3.
- The gate recorded five observations, all scored Low, none a REJECT reason, and none is fixed inside the convergence sequence. Two are errors in this run's own journal prose and are reported to the user rather than edited, because past entries are never rewritten: the iteration 6 AUDIT entry says the 24 batteries hold 1918 checks where their claims files sum to 1838 at that commit and 1842 now, and the iteration 3 entry says the corrected example yields sixteen fields where it yields 17. One observation was checked and does not hold: the gate reported that `nonSeekableStreamPair()` leaks three socket pairs per suite run, but 50 iterations of the same construction leave the process's open file descriptors unchanged at 6, because PHP's refcounting closes both ends when the locals leave scope. The remaining two are confirmations rather than findings - the signature-listing block the CSV-6 battery deliberately excludes by shape, and phpstan and php-cs-fixer both exiting 0.
- Carried Lows, each open with its severity on its line, none blocking: CSV-20 - `Stream::seek()` leaves `key()` one behind `SplFileObject::seek()`, with no public path found to diverge across four document shapes, and the gate noted the class is marked `@internal`. CSV-25 - `CastToFloat::toVariable()` names `int` in one failure message where the branch below it names `float`; the exception, its class, its property and its value type are all correct. CSV-26 - `rector.php`, a 165-byte dev config, ships in the published archive where its four siblings are export-ignored.
- Closing conditions, each verified this iteration: the iteration 6 full fresh-evidence audit is on this run's record and the only commits since it are iteration 7's fix for CSV-6, the task that audit itself filed, plus loop state edits; the Surface inventory lists no unswept row at 22 of 22; no High and no Medium is open in Now, Next or Later; the Verify command is green; the evaluator returned PASS in this same iteration; and the Converged line is appended below with the full hash of this iteration's checkpoint.
- No stall: this is the convergence ceremony and it added the evaluator artifact.

Closed this run: CSV-3 (Medium, docs), CSV-4 (Medium, docs), CSV-17 (Medium, docs), CSV-27 (Medium, docs), CSV-6 (Medium, docs), CSV-5 (Low, test).

Learnings: An evaluator observation is evidence, not a verdict on the code - one of this gate's five was wrong, and measuring it took one command where accepting it would have filed a defect that does not exist. Check an observation the same way a finding is checked before carrying it forward.

Next: The run is converged. The next run ratchets unless code changes; three Lows and three Proposed items are carried.
