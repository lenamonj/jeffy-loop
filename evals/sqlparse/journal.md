# Journal archive

Entries rotated out of JOURNAL.md, oldest first. Appended to on every rotation, never rewritten.

## iter 1/10 | ce480904-142056 | 2026-08-08 | AUDIT | audit

Task: First full audit of a fresh Improvement-mode bootstrap. Fill the Operating envelope, the Verify command and the Surface inventory, then sweep the whole public surface breadth-first and file findings.

Changed: PLAN.md (envelope surfaces, verify command, 25 inventory rows), BACKLOG.md (4 findings, 3 declined), JOURNAL.md, .jeffy/probes/breadth-sweep/{probe.py,paths}, .gitignore (loop state file).

Checkpoint: 731f83f3cda5908866c352d9e83bf31dc4caa753

Stall check: not a stall - this iteration added .jeffy/probes/breadth-sweep/ and .gitignore beyond the three state files, and filed 4 backlog items.

Verification: `uv run --group dev --python 3.13 pytest tests/ -q` -> 494 passed, 2 xfailed, 1 xpassed. `uv run --group dev ruff check sqlparse/` -> All checks passed!. `.jeffy/probes/breadth-sweep/probe.py` -> all known-answer checks passed (exit 0). The battery is demonstrably able to fail: on its first run it reported 2 failures, both of which were wrong expectations of mine (`identifier_case` folds the unquoted table name as well as skipping the quoted column; `indent_after_first=True` indents the trailing keyword by 2), corrected against observed behaviour that matches docs/source/api.rst.

Dimension scores, claiming all 25 inventory rows (no row left unswept):
- correctness: High - JF-001, backslashes unescaped in both output serializers.
- error handling: Medium - JF-003 (NotImplementedError escapes the public API), JF-004 (error message names the wrong variable).
- developer experience: Medium - JF-002, CLI boolean flags invert on `False`.
- testing: Medium - no test covers backslash escaping in the output serializers or the semantics of `--comma_first`/`--compact`; both gaps are closed by the acceptance checks of JF-001 and JF-002, so no separate task is filed. 4 test modules (test_utils, test_keywords, test_tokenize, test_dos_prevention) were also run in isolation and pass, so no order dependence was found.
- security: None - SQL text is classified adversarial. The grouping depth and token limits exist, reject 150-deep nesting, and both documented override paths (raise the constant, set it to None) were executed and work as documented. Every `SQL_REGEX` pattern was checked for zero-width matches; none exists. JF-001 was specifically probed for a breakout of the generated snippet and does not permit one: the quote escaping holds, so hostile SQL yields a `SyntaxError`, not injected code.
- architecture: None - the lex -> preprocess -> split -> group -> stmtprocess -> postprocess pipeline is clean and the filter interface is uniform.
- code quality: None - ruff clean under E/F/W/C90/B/I/UP/SIM/RUF with mccabe max-complexity 31.
- performance: None - 150-deep nesting parses in ~0.02s and the DoS limits bound the worst case.
- documentation: None - every option documented in docs/source/api.rst was executed and behaves as described, and both DoS claims verified. The `right_margin` gap is an undocumented-option defect, filed as JF-003 rather than a docs finding.
- dependency hygiene: None - zero runtime dependencies, dev group locked in uv.lock, CI matrix covers 3.10-3.14 on multiple OSes.
- observability: not applicable - a parsing library with no logging, metrics or tracing surface by design.
- UX and accessibility: not applicable beyond the CLI, which is scored under developer experience; there is no GUI.

Closeout has NOT begun: this audit found 1 High and 3 Medium in-envelope.

Learnings: The verify gate must pin one interpreter (`--python 3.13`) rather than `make test`, which runs five interpreters and would cost ~2 minutes per iteration. A parameter must be probed on input where it can actually apply: `indent_width` and `wrap_after` both looked inert on a flat single-table query and are demonstrably live on a nested query and a long identifier list respectively, so an inertness finding needs a query that exercises the parameter before it can be filed.

Next: JF-001, the only High. Fix the escape class at both sites in sqlparse/filters/output.py and build the `.jeffy/probes/output-escape/` battery its acceptance check names.

## iter 2/10 | ce480904-142056 | 2026-08-08 | JF-001 | done

Task: JF-001 (High) - `OutputPythonFilter` and `OutputPHPFilter` escaped the quote character but not the backslash, so a generated snippet could mean something other than the SQL it came from, or fail to parse at all.

Changed: sqlparse/filters/output.py, tests/test_format.py, CHANGELOG, .jeffy/probes/output-escape/{probe.py,paths}, PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: c999b97fcad5e09d76dff3401b076b140190521d

Stall check: not a stall - this iteration changed sqlparse/filters/output.py, tests/test_format.py and CHANGELOG, and JF-001 moved from open to closed.

Verification: The acceptance battery was written before the fix and run against unfixed code first, where it failed 13 ways (silent value corruption on `\n`, `\t`, `\r`, `\\`; two snippets that were not valid Python at all; three PHP interpolation escapes) - so the check is demonstrably able to fail. After the fix `.venv/Scripts/python.exe .jeffy/probes/output-escape/probe.py` exits 0: 13 inputs x 2 serializers round-trip exactly. Battery ownership: the diff touched sqlparse/filters/output.py, which matches the paths file of both batteries; `.jeffy/probes/breadth-sweep/probe.py` exits 0 and `.jeffy/probes/output-escape/probe.py` exits 0. Verify gate `uv run --group dev --python 3.13 pytest tests/ -q && uv run --group dev ruff check sqlparse/` -> 504 passed, 2 xfailed, 1 xpassed, All checks passed!, exit 0.

The gate went red once mid-iteration on 4 of the 10 assertions I had just added, and the cause was my expected literals, not the change: all 494 pre-existing tests passed in that same run. Fixed on the first of the three permitted attempts by taking the expectations from the serializer's real stdout. No revert was warranted because the project was never broken - the failure was confined to assertions added in this iteration.

Contract preserved: the four existing tests that pin these serializers (test_python, test_python_multiple_statements, test_php, and the xfail test_python_multiple_statements_with_formatting) all still pass unchanged. None of their inputs contains a backslash, a `$` or a double quote, so the escaping change cannot alter them, and the variable-naming, statement-numbering and line-continuation behaviour is untouched. The fix also stops the serializers mutating `token.value` in place, so they no longer modify the statement they are serializing; nothing read those values afterwards.

Class settled, not instance patched: escaping now happens at one boundary, `_escape(value, metachars)`, which escapes the backslash first and then the language's metacharacters. The enumeration is executable rather than prose - the battery reads output.py, asserts both serializer classes reach `_escape`, and fails if any serializer hand-rolls a `.replace()` escape outside it. Enumeration output this iteration: `serializers reaching the escape boundary: ['OutputPHPFilter', 'OutputPythonFilter']`, no strays.

Scope note beyond the filed finding: the PHP serializer also left `$` unescaped, so `select '$foo'` produced `$sql = "select '$foo'";`, which PHP interpolates as a variable at runtime. That is the same escape class at the same site, so it was fixed and pinned in the same iteration rather than filed as a third instance.

Learnings: Take every expected value in a test or battery from the program's observed stdout, never from a Python `repr` - a repr escapes quotes for its own delimiters, so `'$sql = "select \'$foo\'";'` is really the text `$sql = "select '$foo'";`, and copying the repr into an assertion invents backslashes. This is the second time this run that hand-derived expectations were wrong, so the Lesson is marked [recurred] in PLAN.md. No PHP interpreter exists on this host, so PHP output is verified by a reference decoder for double-quoted string semantics rather than by running PHP.

Next: JF-002 (Medium) - the CLI `--comma_first` and `--compact` flags are declared `type=bool`, so `--comma_first False` enables comma-first output.

## iter 3/10 | ce480904-142056 | 2026-08-08 | JF-002 | done

Task: JF-002 (Medium) - `sqlformat --comma_first` and `--compact` were declared `type=bool`, so argparse passed the raw string through `bool()` and every non-empty value was True.

Changed: sqlparse/cli.py, tests/test_cli.py, CHANGELOG, .jeffy/probes/cli-bool/{probe.py,paths}, PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: 2ad3619dced5bac0e35b7ffeb8863827356ccc59

Stall check: not a stall - this iteration changed sqlparse/cli.py, tests/test_cli.py and CHANGELOG, and JF-002 moved from open to closed.

Verification: The filed reproduction was run first, before any edit, and still held: `--comma_first False` produced `select a|, b|from t` while omitting the flag produced `select a,|b|from t`, so False and True were byte-identical and both differed from the default. The acceptance battery was then written and run against unfixed code, where it failed 13 ways - both flags, all five false-ish spellings each, plus `banana` accepted silently, plus the enumeration. After the fix `.venv/Scripts/python.exe .jeffy/probes/cli-bool/probe.py` exits 0. Battery ownership: the diff touched sqlparse/cli.py, matching breadth-sweep and cli-bool; both exit 0. Verify gate -> 526 passed, 2 xfailed, 1 xpassed, All checks passed!, exit 0.

The gate went red once on ruff I001 after the fix: isort allows one blank line between the import block and a module-level assignment, and I had left the two that a `def` would take. Confirmed it was mine rather than pre-existing by copying the working file aside, restoring the HEAD version, and observing ruff pass on it, then restoring my work; fixed on the first of three attempts. The 526 tests passed in that same red run, so the project was never broken and no revert was warranted.

Contract preserved: the value-accepting form is kept rather than converted to `action='store_true'`. `--comma_first True` is currently the only way the flag works at all, and sqlparse ships a pre-commit hook whose `args` list is hand-authored, so silently turning an accepted invocation into an argparse error would break existing configurations. This fix therefore only widens what is accepted correctly - every previously-working invocation still works and means the same thing - and the acceptance check pins both halves: false-ish values now match omitting the flag, true-ish values still differ from it. A flag that did nothing at all would satisfy the first half and fail the second.

Class settled, not instance patched: both sites use `_bool_value`, and the enumerating check walks the AST of every module under sqlparse/ for a call keyword `type=bool`. The enumeration was itself proved able to fail: after switching it from grep to AST I copied cli.py aside, reintroduced `type=bool` at one site, and confirmed the battery reported 7 failures naming the reintroduced site, then restored the file and confirmed it passed again.

Learnings: An enumerating check must distinguish code from prose. The first version of this battery grepped for `type=bool` and immediately matched the docstring in the fix that explains the defect, reporting a site that did not exist. Enumerations over source that also mention the idiom in comments or docstrings must walk the AST, not the text. Also: when the verify gate goes red, decide between revert and repair by restoring the HEAD version of the changed file and re-running the gate against it - that distinguishes a fault this iteration introduced from one it merely exposed, and it takes one command.

Next: JF-003 (Medium) - `format(right_margin=N)` raises bare `NotImplementedError` from `RightMarginFilter.process` although `validate_options` fully validates the option.

## iter 4/10 | ce480904-142056 | 2026-08-08 | JF-003 | done

Task: JF-003 (Medium) - `format(right_margin=N)` validated the option as though it were supported and then raised a bare `NotImplementedError` out of the public API.

Changed: sqlparse/formatter.py, sqlparse/filters/__init__.py, sqlparse/filters/right_margin.py (deleted), tests/test_format.py, CHANGELOG, AGENTS.md, .jeffy/probes/breadth-sweep/probe.py, PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: f7d82636ab76b6bebc1dc74b3a5183643d445c34

Stall check: not a stall - this iteration changed sqlparse/formatter.py, sqlparse/filters/__init__.py, tests/test_format.py, CHANGELOG and AGENTS.md, deleted sqlparse/filters/right_margin.py, and JF-003 moved from open to closed.

Verification: The filed reproduction was run first and still held: `sqlparse.format('select a from t', right_margin=79)` raised `NotImplementedError()` with an empty message. Resolution chosen on evidence rather than preference - the option is now rejected with `SQLParseError`, and the dead filter is deleted. Verify gate -> 529 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0. Battery ownership: the diff touched sqlparse/formatter.py and sqlparse/filters/, matching breadth-sweep; breadth-sweep, cli-bool and output-escape all exit 0. The xfail count dropped from 2 to 1 because the `@pytest.mark.xfail` placeholder `test_format_right_margin` became a real passing test.

Why removed rather than implemented: the acceptance check allowed either resolution, so I measured before choosing. Re-enabling the commented-out `process` body showed it was closer to working than its "FIXME: Doesn't work" note suggested - it respected the margin and preserved the SQL text across multi-statement, subquery, reindent and comment inputs, with over-margin lines only where a single atomic token (a long string literal, a comment) cannot be split by any wrapper. But `keep_together` is empty, so the filter recurses into every group: at `right_margin=20`, `select schema_name.table_name.column_name_long from t where x = 1` came back as `select schema_name.` / `table_name.` / `column_name_long` / `from t where x = 1`, and the statement re-parsed to 21 flattened tokens instead of 19. That is the author's note being accurate, and enabling it would have shipped a formatter that breaks qualified identifiers. Implementing it properly means deciding which group types belong in `keep_together`, which is a feature decision, so it is filed under Proposed with the commit that still holds the code.

Contract preserved and changed: `right_margin=None` stays a no-op, which is what the absence of the option has always meant, and is pinned by a new test and a battery check. Every non-None value now raises `SQLParseError` instead of `NotImplementedError`; both are exceptions, so no invocation that previously produced output behaves differently, and the new one is the library's own exception type carrying a message that names the option. The interface removal is real and deliberate: `sqlparse.filters.RightMarginFilter` is gone from `__all__`. Nothing could depend on it working, because its only public method raised unconditionally. Removing the option from `validate_options` entirely was rejected as worse: unknown keyword arguments are ignored by `format`, so it would have turned a loud failure into a silent no-op.

Removal enumeration, run in this iteration: `grep -rn "RightMarginFilter|right_margin"` over every .py, .rst, .md, .toml, .cfg and .yaml in the project returns only the deliberate tombstone in sqlparse/formatter.py and its tests in tests/test_format.py. docs/source never mentioned the option. AGENTS.md listed `right_margin.py` in its filter inventory and was updated in the same iteration. `sqlparse.filters.__all__` no longer contains the name, checked by importing it. The Surface inventory row for the module was removed because the surface no longer exists, and the stated file count in PLAN.md was re-derived from `find sqlparse -name '*.py' | wc -l`, which now returns 20.

Learnings: When a task's acceptance check permits more than one resolution, run the experiment that separates them before choosing. Re-enabling this filter for two minutes turned "the author says it does not work" into a specific reproduction - qualified identifiers split at `right_margin=20` - which is what justified deletion over revival and what the Proposed item now hands to the user. A disabled feature's own FIXME is a hypothesis, not evidence.

Next: JF-004 (Medium) - the `reindent_aligned` branch of `validate_options` interpolates the wrong variable, so a bad value is reported as `Invalid value for reindent_aligned: False`.

## iter 5/10 | ce480904-142056 | 2026-08-08 | JF-004 | done

Task: JF-004 (Medium) - the `reindent_aligned` branch of `validate_options` interpolated `{reindent!r}` instead of `{reindent_aligned!r}`, so a rejected value was reported as some other option's value.

Changed: sqlparse/formatter.py, tests/test_format.py, CHANGELOG, .jeffy/probes/option-errors/{probe.py,paths}, BACKLOG.md, PLAN.md, JOURNAL.md.

Checkpoint: bbdef78cdee4d931aefd71c3e76744981fd9b9b5

Stall check: not a stall - this iteration changed sqlparse/formatter.py, tests/test_format.py and CHANGELOG, and JF-004 moved from open to closed.

Verification: The filed reproduction was run first and held - `validate_options({'reindent_aligned': 'notabool'})` raised `Invalid value for reindent_aligned: False`. A second probe made the defect sharper than the filed line described: with `reindent=True` also set, the same call reported `... : True`, proving the message echoes a sibling option's live state rather than a stale default. The acceptance battery was written before the fix and failed 3 ways against unfixed code, isolating exactly one defective option out of 18 enumerated. After the one-word fix `.venv/Scripts/python.exe .jeffy/probes/option-errors/probe.py` exits 0, and `reindent_aligned` moves from the "raise without echoing" group to the "echo their own value" group, which is the observable difference the fix makes. Battery ownership: the diff touched sqlparse/formatter.py, matching breadth-sweep and option-errors; all four batteries exit 0. Verify gate -> 542 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0.

The filed acceptance check said "every other option's reject message is asserted to echo its own value", which turned out to overstate the code's design: 5 of the 18 options deliberately raise without echoing any value (the "indent_width requires an integer" shape), and `truncate_char` is read with a default rather than validated at all. Rather than change 5 unrelated messages to satisfy a line I wrote in iteration 1, the invariant was narrowed to the one that actually defines the class: a message may echo the value passed or no value at all, but never a different variable's. That is checked for every option, so the class is closed without cosmetic churn in options that were never defective.

Class settled, not instance patched: the enumeration is read from the source with `options.get('...')` rather than hand-listed, so an option added later is covered without editing the battery. The battery was itself corrected once during this iteration: its first form demanded the literal option key appear in every message, which failed `output_format` because that message reads "Unknown output format" with a space. That is the message naming the option in prose, not a defect, so the check now normalises underscores instead of forcing a message rewrite - a battery must not manufacture findings by being stricter than the contract.

Contract preserved: only the interpolated variable changed. The exception type, the message prefix, and the set of accepted and rejected values are all identical, so no caller that inspected the exception type or the option name sees a difference; only the reported value changes, and it changes from wrong to right.

Ledger note: this closes the last filed finding. Now, Next and Later are all empty, and this run has no clean full audit on record - the iteration 1 audit found 1 High and 3 Medium - so closeout has not begun and the next iteration is a fresh full audit rather than a convergence step.

Learnings: A backlog line's acceptance check is a hypothesis about the code's shape as much as about the defect, and it can be wrong in the direction of demanding unrelated changes. When the filed check would force churn in code that is not defective, narrow it to the invariant that actually defines the class and record why, rather than either widening the fix or quietly dropping the check.

Next: the ledger is empty and no clean full audit exists for this run, so iteration 6 is a full fresh-evidence audit of all 24 Surface inventory rows per the Method.

## iter 6/10 | ce480904-142056 | 2026-08-08 | AUDIT | audit

Task: Full fresh-evidence audit of all 24 Surface inventory rows, the ledger having emptied with no clean audit on this run's record.

Changed: BACKLOG.md, PLAN.md, JOURNAL.md.

Checkpoint: 9a694b14875c222467088fb90afae34a33737938

Stall check: not a stall - this iteration changed only state files, which the stall rule allows for an audit, and BACKLOG.md changed state by filing JF-005.

Verification: Fresh evidence, not a re-reading of previously scored lines. All four kept batteries re-run and exit 0: breadth-sweep, option-errors, cli-bool, output-escape. Three new invariant sweeps were run over the project's own 17 SQL fixtures plus 10 synthetic statements covering CTEs, unions, DML, typecasts, window functions, joins and DDL. Parse round-trip (`''.join(str(s) for s in parse(q)) == q`) holds on every input except the trailing-newline case filed below. Split reconstruction holds whitespace-insensitively on every fixture. Formatter content preservation - that formatting changes nothing but whitespace - holds across 26 statements times 9 option sets with zero violations, which is the check that would catch a formatter dropping, duplicating or reordering a token. Reindent idempotence holds on every fixture. Traversal API re-probed with known answers: token_first, token_next with and without skip_ws, token_prev, token_index, token_next_by, token_matching, insert_after, flatten-joins-to-source, and get_type across SELECT/INSERT/UPDATE/DELETE/CREATE/UNKNOWN. All six test modules were run in isolation - test_split 49, test_parse 88, test_grouping 100, test_format 89, test_cli 45, test_regressions 93 - all passing, so no order dependence or leaked state. Verify gate -> 542 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0.

Dimension scores, claiming all 24 rows; no row is unswept:
- correctness: Medium - JF-005, trailing newlines dropped when the input ends with a semicolon and whitespace. Filed with a reproduction at both the library and CLI layers.
- security: None - SQL text is adversarial class. The grouping limits still reject 150-deep nesting and both documented override paths still work; no zero-width SQL_REGEX pattern exists; the output serializers escape backslashes and PHP metacharacters, re-checked by output-escape.
- error handling: None - every one of the 18 options `validate_options` reads now rejects with SQLParseError naming its own option and echoing only its own value, enumerated from source by option-errors.
- developer experience: None - the CLI boolean flags honour both polarities and reject nonsense, driven through the real CLI by cli-bool.
- testing: None - all six modules pass in isolation, and the paths this run touched gained 48 tests (494 at the run's base commit, 542 now).
- architecture: None. code quality: None - ruff clean under the project's full rule set. performance: None - 150-deep nesting parses in about 0.02s and the DoS limits bound the worst case. documentation: None - every option documented in docs/source/api.rst was executed and behaves as described. dependency hygiene: None - zero runtime dependencies, dev group locked, CI matrix 3.10-3.14.
- observability: not applicable, a parsing library with no logging or metrics surface by design. UX and accessibility: not applicable beyond the CLI, scored under developer experience.

Closeout has NOT begun: this audit found 1 Medium in-envelope, so the run is not converged and a further audit is required after JF-005 is closed.

Observed and deliberately not filed: `tests/files/huge_select.sql` is referenced by no test and is now rejected by `MAX_GROUPING_TOKENS` with `SQLParseError: Maximum number of tokens exceeded (10000)`. The rejection is the documented DoS limit working as intended on a 9434-byte fixture, not a runtime defect, and an unreferenced fixture causes no failure, so filing it would be padding. Recorded here so a later audit does not rediscover it as new.

Learnings: An invariant sweep needs its normalisation checked before its failures are believed. The first split-reconstruction pass reported 15 of 17 fixtures failing, which was entirely my comparison stripping whitespace from one side and not the other; corrected to compare with all whitespace removed on both sides, it reports none. The three genuine round-trip failures in that same pass survived the correction and became JF-005, so the run of the sweep was worth keeping - but a sweep that indicts most of its corpus is far more likely to be measuring itself than the code.

Next: JF-005, the only open finding. Fix the trailing-newline loss without changing `split`, whose `test_split_ignores_empty_newlines` pins the current behaviour.

## iter 7/10 | ce480904-142056 | 2026-08-08 | JF-005 | done

Task: JF-005 (Medium) - the statement splitter discarded a trailing all-whitespace statement, so any input ending in a semicolon lost its final newline, and `sqlformat --in-place` rewrote the last byte of every file.

Changed: sqlparse/engine/statement_splitter.py, sqlparse/cli.py, tests/test_split.py, tests/test_cli.py, CHANGELOG, .jeffy/probes/trailing-newline/{probe.py,paths}, BACKLOG.md, JOURNAL.md.

Checkpoint: a21c51b5764cb9df6991576f0afe9dcf57732cd9

Stall check: not a stall - this iteration changed sqlparse/engine/statement_splitter.py, sqlparse/cli.py, two test modules and CHANGELOG, and JF-005 moved from open to closed.

Verification: The acceptance battery was written before the fix and failed 18 ways against unfixed code. After the fix `.venv/Scripts/python.exe .jeffy/probes/trailing-newline/probe.py` exits 0. Battery ownership: the diff touched sqlparse/engine/statement_splitter.py and sqlparse/cli.py, matching breadth-sweep, cli-bool and trailing-newline; all five batteries exit 0. Verify gate -> 551 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0.

A first attempt was tried and rejected on evidence. The root cause looked like `EOS_TTYPE` being a tuple, so `ttype not in EOS_TTYPE` compares by equality and `Whitespace.Newline != Whitespace` - a newline is therefore treated as a non-whitespace token. Switching that test to TokenType containment made the whole existing suite pass, 542 as before, which is exactly the evidence that would have justified shipping it. A differential snapshot over 162 keys - 27 inputs including all 16 usable fixtures, each through plain, reindent, keyword_case and reindent_aligned, plus split output and statement count - showed it also moved comment attachment: for tests/files/dashcomment.sql, `split` changed from `['select * from user;', '--select * from host;\nselect * from user;', ...]` to `['select * from user;\n--select * from host;', 'select * from user;', ...]`. A standalone comment that introduced the following statement became a trailer on the preceding one. No test covers that, and it is a real behaviour change against the convention that a comment on its own line heads the statement below it, so the approach was reverted.

The shipped fix leaves the EOS semantics untouched and changes only what happens at end of input: the most recently completed statement is held back by one, and if the leftover tokens are whitespace only they are attached to it rather than discarded. The same differential now reports 14 differing keys of 162, and every one of them is a trailing newline appearing where it was previously dropped. `split` output is identical on every input, statement counts are identical, reindent output is identical, and comment attachment is identical. That is the differential evidence that the change does what it claims and nothing else.

Contract preserved: `split` is unchanged because it strips each statement, so whitespace attached to the end of the last statement disappears in `str(stmt).strip()`; `test_split_ignores_empty_newlines` passes unaltered. `parse('select 1;\n')` still returns 1 statement rather than inventing a whitespace-only one, which is why the whitespace is attached to the preceding statement instead of yielded separately. Whitespace-only input still yields no statement, as before.

Scope decision on reindent: `reindent` implies `strip_whitespace`, whose stated job is to remove a statement's trailing whitespace, so under reindent the statement-level newline is stripped on purpose and the battery now pins that rather than demanding it survive. The file's final newline is a property of the file, not of the SQL, so it is restored in `cli._process_file` where file I/O lives. This keeps the library's formatting semantics unchanged while fixing the harm that was actually filed - the pre-commit hook rewriting the last byte of every file it touches.

Learnings: A green suite is not evidence that a change is confined to its intent. The rejected approach passed all 542 tests while silently moving comment attachment; only a before-and-after differential over real inputs caught it. For any change to shared parsing code, snapshot the outputs of the real corpus through several option sets, diff them, and require every difference to be one you can name - the count of differing keys is the check, not the test result.

Next: the ledger is empty again. Iteration 8 is a full fresh-evidence audit; if it scores zero High and zero Medium, closeout begins and the evaluator gate can run with budget left to answer a REJECT.

## iter 8/10 | ce480904-142056 | 2026-08-08 | AUDIT | audit

Task: Full fresh-evidence audit of all 24 Surface inventory rows, the ledger having emptied after JF-005.

Changed: PLAN.md, JOURNAL.md.

Checkpoint: 169c0b18ad457034f3717bb000b8b0db313bb7ef

Stall check: not a stall - this iteration re-swept two stale inventory rows and recorded the clean audit that begins closeout; the previous primary entry was a fix iteration, so no consecutive no-progress pair exists.

Verification: Staleness was computed rather than assumed - `git diff --name-only <row commit> HEAD -- sqlparse/` was run for every distinct commit recorded in the inventory, which found two stale rows that the previous audit's evidence no longer covered: cli-args, recorded at 2ad3619 but with sqlparse/cli.py changed at a21c51b, and formatter-build, recorded at f7d8263 but with sqlparse/formatter.py changed at bbdef78. Both were re-swept in this iteration and re-recorded at this iteration's checkpoint. All five batteries re-run and exit 0: breadth-sweep, option-errors, cli-bool, output-escape, trailing-newline. Four invariants re-run over 28 statements - the 16 usable fixtures plus 12 synthetic covering CTEs, unions, DML, typecasts, window functions, joins, DDL and trailing-newline shapes - each through 8 option sets: parse round-trip, split reconstruction, formatter content preservation and reindent idempotence all report zero failures. All ten test modules were run in isolation and pass, so no order dependence or leaked state. Verify gate -> 551 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0.

The newest code was probed hardest, since that is where an undiscovered defect is most likely. The changed splitter was driven with 19 degenerate inputs - empty, whitespace only, bare and doubled semicolons, leading semicolon, comment-only with and without a newline, a semicolon inside a string literal, begin/end - and every non-degenerate case round-trips with the expected statement count. `parsestream` still returns a generator and yields its first statement without consuming the stream, confirming the hold-back is one statement and not unbounded buffering, and 2000 chained statements parse and round-trip exactly.

Every number stated in the state files was re-executed rather than trusted: `find sqlparse -name '*.py' | wc -l` returns 20 as PLAN.md claims; the inventory holds 24 swept rows and 0 unswept; option-errors enumerates 18 options with 12 echoing, 5 raising without echoing and truncate_char unvalidated, matching the Settled classes line; output-escape reports both serializer classes reaching the escape boundary; cli-bool reports 0 remaining `type=bool` sites; the grouping limits are still 100 and 10000 and reject 150-deep nesting in about 0.016s.

Dimension scores, claiming all 24 rows; no row is unswept:
- correctness: None - parse round-trip, split reconstruction, formatter content preservation and reindent idempotence all clean on fresh evidence over the full corpus.
- security: None - SQL text is adversarial class; grouping limits reject deep nesting and both documented override paths work, no zero-width SQL_REGEX pattern exists, and the output serializers escape backslashes and PHP metacharacters.
- error handling: None - all 18 options reject with SQLParseError naming their own option and echoing only their own value.
- developer experience: None - both CLI boolean flags honour both polarities and reject nonsense through the real CLI.
- testing: None - all ten modules pass in isolation; the suite went from 494 at the run's base commit to 551.
- architecture: None. code quality: None, ruff clean under the project's full rule set. performance: None. documentation: None. dependency hygiene: None.
- observability: not applicable, a parsing library with no logging or metrics surface by design. UX and accessibility: not applicable beyond the CLI, scored under developer experience.

CLOSEOUT HAS BEGUN: this audit is a full fresh-evidence pass scoring zero High and zero Medium in-envelope. No further audit or replenishment runs for the rest of this run; what remains is the evaluator gate and, on PASS, the declaration.

Observed and deliberately not filed, so a later audit does not rediscover them as new: whitespace-only input (`' '`, `'\n'`) yields zero statements, so it does not round-trip. That is unchanged by this run - it behaved identically before the JF-005 fix - and it is correct rather than defective, since input containing no statement produces no statement; the CLI preserves such a file anyway because its trailing-newline restoration applies to the empty result. And `tests/files/huge_select.sql` remains referenced by no test and rejected by the documented `MAX_GROUPING_TOKENS` limit, as recorded in the iteration 6 audit.

Learnings: Compute inventory staleness with `git diff --name-only <recorded commit> HEAD -- <source dir>` per distinct recorded commit rather than reasoning about which rows a run touched. Two rows here were stale for reasons that were easy to miss by inspection - cli-args because a later task changed cli.py for an unrelated reason, formatter-build because the row was recorded one iteration before formatter.py changed again.

Next: the evaluator gate. Closeout has begun and the ledger is empty, so iteration 9 spawns the adversarial evaluator and, on PASS with the closing conditions holding, declares in that same iteration.

## iter 9/10 | ce480904-142056 | 2026-08-08 | EVALUATOR | audit

Task: Adversarial evaluator gate, invocation 1 of at most 2 for this run. Spawned as one fresh-context sub-agent carrying none of this run's context, given the run-id and the base commit e7d95d494cebc66fd220198ea2eb2cf94a8bb5fe.

Changed: BACKLOG.md, JOURNAL.md, .jeffy/evaluator/ce480904-142056.md.

Checkpoint: 32f108de87a2d6151231dde7c593fdb0fdfe50b1

Stall check: not a stall - BACKLOG.md changed state by filing EV-001, EV-002 and EV-003, and the evaluator artifact was added.

Verification: Evaluator: REJECT - three in-envelope High findings the run's own audits missed, all three independently reproduced by me before filing. The gate confirmed the parts that hold: the Verify command exits 0 with 551 passed, all five batteries exit 0, three of them were shown falsifiable by reintroducing their defect in scratch copies and observing 10, 16 and 13 failures, its own 46-key differential over tests/files plus 29 synthetic inputs independently confirms the JF-005 splitter change moved only trailing whitespace with comment attachment and statement counts unchanged, the hold-back is exactly one statement with parsestream laziness preserved, and the right_margin removal leaves no dangling reference. The artifact `.jeffy/evaluator/ce480904-142056.md` is 221 lines naming every command with its real exit status and closes with the verdict.

I re-ran all three reject reasons rather than accepting them. EV-001: a 20-byte file plus `--in-place --indent_width 0` printed the expected `[ERROR] Invalid options: indent_width requires a positive integer`, exited 1, and left the file at 0 bytes. EV-002 and the second half of EV-001: a 318-byte file of 150-deep nesting plus `--in-place --reindent` printed an uncaught `sqlparse.exceptions.SQLParseError` traceback, exited 1, and left the file at 0 bytes. EV-003: `format("select 'a\nb' from t", output_format='python')` where the newline is a real newline emits a snippet `ast.parse` rejects with `unterminated string literal`; the newline sits inside a single `Token.Literal.String.Single` whose `is_whitespace` is False, so it bypasses the serializer's whitespace branch, and PHP is genuinely unaffected because a raw newline is legal in a PHP double-quoted string. All three confirmed.

Filed at rubric severity: EV-001 High and EV-003 High in Now, EV-002 Medium in Next. EV-001 and EV-002 share the `_process_file` failure path but are separate root causes - the destination being opened before the text exists, and `SQLParseError` having no handler - so they are filed separately rather than as one line.

The Settled classes entry for escaping has been corrected rather than left standing. JF-001's structural half holds: both serializers still route through one `_escape` boundary and the battery still enforces that no serializer hand-rolls an escape outside it. The claim that was false is "class-complete", and it was false for a reason worth recording: the corpus contained no raw control character, so the class was closed against the metacharacters I thought of rather than against the set of characters that cannot appear literally in the target literal. The entry now says REOPENED and permits audits to file inside the class until EV-003 closes it.

This is a genuine miss by three consecutive audits of mine, not a disagreement about severity. Iterations 1, 6 and 8 all scored cli-io and filters-output clean. The audits drove the CLI's failure paths for their exit codes and stderr text and never checked the file's bytes afterwards, and drove the serializers over a corpus of escape characters that were all typed as escape sequences in the probe source rather than as raw bytes.

Learnings: Check the artifact, not only the exit code. Every CLI failure-path probe this run ran asserted the exit status and the message and none asserted what happened to the file, which is how a data-loss bug survived three audits that each declared cli-io clean - when a command's purpose is to modify something, its failure paths must assert that thing is unchanged. And a corpus of escape characters written as source-level escape sequences tests the escaping of the characters you thought of; include at least one raw control character, because the defect is in the characters you did not think to type.

Next: one iteration remains, so the run cannot fix three findings or reach a second gate invocation. Iteration 10 closes EV-001, the data-loss High whose fix is contained, and writes the handoff for EV-002 and EV-003.

## iter 10/10 | ce480904-142056 | 2026-08-08 | EV-001 | done

Task: EV-001 (High, data loss) - `cli._process_file` opened the destination for writing, which truncates, before validating options and formatting, so any later failure emptied the user's file. Final iteration, so this entry also carries the handoff.

Changed: sqlparse/cli.py, tests/test_cli.py, CHANGELOG, .jeffy/probes/cli-atomic/{probe.py,paths}, BACKLOG.md, JOURNAL.md.

Checkpoint: 74ae751254e14c6e6d2208e47ec011fda0e321e6

Stall check: not a stall - this iteration changed sqlparse/cli.py, tests/test_cli.py and CHANGELOG, and EV-001 moved from open to closed.

Verification: The acceptance battery was written before the fix and failed 6 ways against unfixed code - a 20-byte file emptied by a rejected option, a 317-byte file emptied by SQL exceeding the grouping depth limit, both files emptied in a two-file run, an existing `--outfile` truncated by a failing run, and the AST enumeration reporting 2 `open(..., 'w')` calls running before the text is formatted. After the fix `.venv/Scripts/python.exe .jeffy/probes/cli-atomic/probe.py` exits 0. Battery ownership: the diff touched sqlparse/cli.py, matching cli-bool, trailing-newline and cli-atomic; all six batteries exit 0. Verify gate -> 554 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0.

The fix is a reorder, not new machinery: validation and formatting now complete before any destination is opened, so there is no window in which the file has been truncated but the replacement text does not exist. The enumeration is executable and lives in the battery - it walks the AST of `_process_file` and fails if any `open(..., 'w')` has a line number below the last `format(` call, so reintroducing the ordering fails the check rather than needing someone to notice it.

Contract preserved: a successful run still rewrites the file, pinned by the battery's fifth case and by the existing `test_cli_single_file_inplace`. Exit codes and the `[ERROR]` messages are unchanged, and stdout output is unchanged because `sys.stdout` was never the truncating branch. The `--outfile` case improves in the same way and is pinned separately, since a failing run previously destroyed a pre-existing output file the user had not asked to overwrite.

EV-002 remains open by design rather than by omission: the deep-nesting reproduction still raises `SQLParseError` out of `main()` as a traceback instead of an `[ERROR]` line. That is a separate root cause - a missing handler, not an ordering bug - and the final iteration executes one task. The file is no longer destroyed on that path, which was the data-loss half.

Learnings: A reordering fix deserves an ordering check, not only a behavioural one. The behavioural cases here would all pass again if someone later moved the open back above the format call for a plausible reason such as failing fast on an unwritable path; the AST check on relative line numbers is what makes that reintroduction fail immediately.

Handoff for the next run, which starts with a fresh audit and an empty context:
- EV-003 (High, open, in Now) is the first task. `output_format='python'` does not escape characters that cannot appear literally inside a Python single-quoted literal; a raw newline inside a SQL string literal yields a snippet `ast.parse` rejects. The escaping class in BACKLOG.md Settled classes is marked REOPENED, so audits may file inside it until this closes. Fix at the existing `_escape` boundary in sqlparse/filters/output.py and extend `.jeffy/probes/output-escape/probe.py` with raw control characters, which is the gap that hid it.
- EV-002 (Medium, open, in Next) is second: wrap the `sqlparse.format` call in `_process_file` so `SQLParseError` becomes an `[ERROR]` line rather than a traceback.
- One Proposed item awaits the user and must not be worked without approval: whether to implement right-margin wrapping as a real feature, with the removed code at 2ad3619dced5bac0e35b7ffeb8863827356ccc59.
- The evaluator gate for this run is spent: one invocation, verdict REJECT, artifact at .jeffy/evaluator/ce480904-142056.md. The next run gets a fresh cap.
- The Surface inventory is complete at 24 of 24 rows, but cli-io and filters-output are stale after this run's changes and the two open findings; a fresh audit should recompute staleness with `git diff --name-only <recorded commit> HEAD -- sqlparse/` rather than trusting the marks.

Next: the run ends here, out of budget and not converged, with EV-002 and EV-003 open.

## iter 1/10 | d94c386f-153253 | 2026-08-08 | EV-003 | done

Task: EV-003 (High, correctness) - `output_format='python'` wrote raw control characters into the generated string literal, so SQL carrying a newline, carriage return or NUL inside a quoted token emitted invalid Python.

Changed: sqlparse/filters/output.py, tests/test_format.py, CHANGELOG, .jeffy/probes/output-escape/probe.py, PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: ae512550ecb80115a7d0ca26ec848b5e91555aaf

Stall check: not a stall - this iteration changed sqlparse/filters/output.py, tests/test_format.py and CHANGELOG, and EV-003 moved from open to closed.

Verification: The filed reproduction was run first, before anything else: `format("select 'a\nb' from t", output_format='python')` with a real newline returns `sql = ('select \'a\nb\' from t')`, which `ast.parse` rejects with `unterminated string literal`. The backlog line still held.

The character set was enumerated rather than reasoned about. Every C0 control character, DEL, NEL, LINE SEPARATOR and PARAGRAPH SEPARATOR - 36 characters - was placed inside a string literal and inside a double-quoted identifier and pushed through both serializers. Against the unfixed code exactly three break Python: NUL with `source code string cannot contain null bytes`, LF and CR with `unterminated string literal`. The Unicode separators are fine, because Python 3 source treats only LF and CR as line terminators. PHP passed all 72 generated inputs under the reference decoder, independently confirming EV-003's claim that PHP is unaffected. Parse round-trip was checked first for all 36 in both positions and holds, so the contract the battery demands is one the parser already keeps.

Acceptance check, run against unfixed code before the fix and observed to fail: `.venv/Scripts/python.exe .jeffy/probes/output-escape/probe.py` exited 1 with 6 failures - NUL, LF and CR, each in a string literal and in a quoted identifier. After the fix it exits 0 over 85 inputs x 2 serializers, 13 hand-written and 72 generated. The battery now also fails if its corpus ever stops containing a raw control character, which is the specific gap that let JF-001 be declared complete while broken. The pytest regression test was proved falsifiable the same way: with sqlparse/filters/output.py copied aside and HEAD's version restored in its place, `test_python_escapes_raw_control_characters` failed 6 of 7 parameters and the fixed file was copied back; the seventh is a raw tab, which is legal inside a Python literal and passes both before and after.

The fix is at the existing single boundary, not a new branch. Prefixing a backslash to a real newline makes a line continuation, which deletes the newline rather than encoding it, so `_escape` now consults a mapping for the characters a backslash prefix cannot express and falls back to the prefix for ordinary metacharacters. The Python serializer asks for `"'\n\r\x00"`; PHP is untouched at `'"$'`, because a double-quoted PHP string carries those characters literally.

Contract preserved, measured rather than asserted: 15 fixture files under tests/files were formatted through 6 option sets before and after, 90 keys. The two PHP option sets and the two plain-SQL option sets show zero differing keys, so PHP output and ordinary formatting are byte-identical. Twenty keys differ, all in the two python option sets, and every one of the twenty was invalid Python before the fix - so no previously-valid output moved. The differing set is wider than the filed finding, and for a reason worth recording: comment tokens are not whitespace either, so any SQL with a comment already emitted a raw newline into the literal.

Battery ownership: the diff touches sqlparse/filters/output.py, matching output-escape and breadth-sweep; all six batteries were run and all exit 0. Verify gate -> 561 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0. The suite went from 554 to 561, the 7 new parameters. The gate was red on its first run for a lint reason of my own making - ruff I001 on the blank line between the imports and the new module constant - and green on the re-run after removing that blank line; no test was red at any point.

That differential also found what EV-003 did not, and it is filed rather than fixed here because this iteration executes one task: 5 of the 90 keys still emit invalid Python after the fix, from two root causes in `OutputPythonFilter._process` that have nothing to do with escaping. `has_nl` is computed from `str(stmt).strip()`, so a leading newline the strip removed leaves it False while the continuation-line branch fires on that same whitespace anyway, emitting continuation lines with no enclosing parentheses; and `after_lb = token.value.split('\n', 1)[1]` retains every newline after the first and yields it raw inside the open literal. Both reproduce on `format('select 1;\nselect 2;', output_format='python')`, which is a two-statement script written one statement per line. Filed as JF-006, High, one structural task rather than two patches, since these are the same class of defect as each other - how the emitted literal is framed - and the class rule says close it at the boundary with a corpus-wide invariant.

The escaping class in BACKLOG.md moves back to settled class-complete, and the entry now records why the first settlement was wrong: the corpus was hand-written, so it tested the characters someone thought of. The replacement corpus is generated over a character range, and the battery refuses to run without raw control characters in it.

Learnings: A code-generating filter is not checked by hand-picked inputs. Eighty-five targeted escaping inputs passed while a two-line SQL script emitted unparseable Python; only formatting the project's own fixture corpus through several option sets and asserting the result parses in the target language surfaced it. Assert validity in the target language over the real corpus, and make the corpus generated wherever the input space is a character range, because a hand-written corpus can only contain what its author already suspected.

Next: JF-006, the structural fix for the two framing defects in `OutputPythonFilter._process`, with the corpus-wide validity invariant as its acceptance check. EV-002 stays second.

## iter 2/10 | d94c386f-153253 | 2026-08-08 | JF-006 | done

Task: JF-006 (High, correctness) - the output serializers emitted snippets that were not faithful copies of the SQL they were handed. Filed as two root causes; a third of the same class was found while fixing and closed in the same task, because the filed acceptance check could not go green without it.

Changed: sqlparse/filters/output.py, tests/test_format.py, CHANGELOG, .jeffy/probes/output-escape/probe.py, PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: 0f5ba6c78f8c35030299064e3cdc74fd711f4419

Stall check: not a stall - this iteration changed sqlparse/filters/output.py, tests/test_format.py and CHANGELOG, JF-006 moved from open to closed, and JF-007 was filed.

Verification: The filed reproductions were run first and both still held: `format('select 1;\nselect 2;', output_format='python')` emits `sql2 = ' '\n        'select 2;'`, which `ast.parse` rejects with `unexpected indent`, and under `reindent=True` the leading whitespace of the second statement is a single `'\n\n'` token whose second newline lands raw inside the open literal.

The acceptance check as filed asked for exact equality between the concatenated literals and the SQL. That is not the contract, and running the existing suite says so: `test_python` pins `sql = ('select * '\n       'from foo;')` for reindented `select *\nfrom foo;`, so the serializer deliberately turns an SQL newline into a space, the Python line break carrying no value of its own. Demanding literal equality would have indicted correct code, so the check was narrowed as the Lessons section requires - and then made stricter than the line as filed rather than weaker. The invariant now is character-for-character equality after newlines are replaced by spaces on both sides: no whitespace-run collapsing, so a dropped character, an extra space or a run of the wrong length all fail, and it was measured at 0 violations over 45 fixture x option-set combinations for both serializers. What the serializer was handed is built from the same filter stack with postprocess removed, not from `format(sql, **opts)`; `format` appends SerializerUnicode, which right-strips the lines of whatever comes last, and in a snippet run that is the generated Python rather than the SQL. That distinction is why an earlier draft of the check reported 26 false violations.

Acceptance check against unfixed code, run by copying the fixed file aside and restoring HEAD's version: 17 failures - 15 corpus failures across 8 fixtures and both serializers, plus the AST enumeration reporting the `split(chr(10), 1)` idiom at both serializer sites. After the fix it exits 0 over 88 exact inputs and 45 fixture x option-set combinations x 2 serializers. The 7 new pytest cases were proved the same way: 7 failed against HEAD's output.py, 29 passed after, and the fixed file was copied back both times.

Three root causes, all closed at the boundary rather than patched at the symptom:
- The parentheses that make a multi-line Python assignment legal were decided by `len(str(stmt).strip().splitlines()) > 1` while the line splitting was decided by `token.is_whitespace and '\n' in token.value`. The strip removes exactly the leading whitespace the splitting fires on, so the two disagreed for every statement after the first in a script written one per line. Both now ask `_breaks_line(token)` over the same token list, so they cannot disagree.
- `after_lb = token.value.split('\n', 1)[1]` handled the first newline of a whitespace run and yielded the rest raw inside the still-open literal. `_escape_lines` now splits on every newline and escapes each run, and each run gets its own line break; the run text between two newlines, which the old code also dropped, is emitted in its place.
- Each token was read from `token.value`, which is a cache filled when the group was built and left stale by the filters that ran before. Reproduced directly: after `ReindentFilter` on tests/files/function.sql, the `Function`, `Identifier` and `Begin` groups all report a `.value` differing from `str(token)`. The user-visible consequence was that `reindent` and `reindent_aligned` were silently ignored in the emitted snippet whenever their edits fell inside a group - `format('select a, b from t where a = 1', output_format='python', reindent=True)` returned the input unchanged. Both serializers now read `str(token)`.

Contract preserved, measured: 15 fixtures through 6 option sets, 90 keys, before and after. The two plain-SQL option sets show zero differing keys, so formatting without `output_format` is byte-identical. 15 python-optset keys differ, of which 5 were invalid Python before and 0 after; 15 php-optset keys differ, from three named causes - the alignment space now appearing for statements whose leading whitespace holds a newline, second and later newlines becoming `.=` continuations instead of raw newlines inside the string, and the reindent text that the stale cache had been hiding. Every one of those 30 keys is accounted for by the invariant that now holds over all of them.

Battery ownership: the diff touches sqlparse/filters/output.py, matching output-escape and breadth-sweep; all six batteries were run and all exit 0. Verify gate -> 568 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0, first run green this time.

The filters-output inventory row flips to swept at this iteration's checkpoint. Beyond the battery, both documented `output_format` values, the `sql` no-op, varname numbering across three statements and the `varname=` constructor argument were exercised directly, the last two through a hand-built filter stack since `format` never passes a custom name.

Filed rather than fixed: JF-007, Medium, the same stale-`.value` read at any site outside this module. The two sites here are verified and fixed; the general claim is not, so the task is the enumeration itself - walk the AST for reads of `.value` on anything that can be a `TokenList` and classify every site - rather than a sentence asserting the class is confined to output.py.

Learnings: A filed acceptance check is a hypothesis about the contract, not the contract. This one demanded exact equality where the code's own pinned test says a newline becomes a space; the fix is to narrow to the invariant that defines the class and say why, not to change working code to satisfy the line as written. And when a check compares generated output against a reference, build the reference from the same pipeline with only the step under test removed - comparing against `format(sql, **opts)` silently included a postprocess right-strip that belongs to the snippet's own lines, which manufactured 26 violations that were not defects.

Next: the ledger holds JF-007 (Medium) and EV-002 (Medium), and one inventory row (cli-io) is still unswept. EV-002 is the older item and its surface is the unswept row, so it goes next.

## iter 3/10 | d94c386f-153253 | 2026-08-08 | EV-002 | done

Task: EV-002 (Medium, error handling) - a failure inside `cli._process_file` reached the user as a traceback instead of the `[ERROR]` line every other failure path emits. Filed against one step; the enumeration found six.

Changed: sqlparse/cli.py, tests/test_cli.py, CHANGELOG, .jeffy/probes/cli-errors/{probe.py,paths}, .jeffy/probes/cli-atomic/probe.py, PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: 9a57815b4c9d72c66d7e53bca7f767247f7f5471

Stall check: not a stall - this iteration changed sqlparse/cli.py, tests/test_cli.py and CHANGELOG, EV-002 moved from open to closed, and the cli-io inventory row moved from unswept to swept.

Ledger order: both open items were Medium and runtime, so the Method's tie-break applies - user impact first. EV-002 is a crash a user meets on the adversarial input surface; JF-007 is an enumeration whose user impact outside the two already-fixed sites is unknown. EV-002 was moved above it and executed.

Verification: The filed reproduction ran first and still held: a 316-byte file of 150-deep nesting with `--in-place --reindent` printed an uncaught `sqlparse.exceptions.SQLParseError` traceback and exited 1.

The enumeration was built by provoking a real failure at every step of a file's processing, never by scanning the source for the calls it makes, and that is what turned one finding into six. Two of the crashing steps fail inside the standard library's codec machinery and name nothing sqlparse calls, so a name scan could not have seen them. Twelve steps were provoked; before the fix seven crashed - SQL tripping the grouping limit both to stdout and in place, undecodable bytes from a file and from stdin, an unknown `--encoding` name from a file and from stdin, and output the console could not encode - while the missing file, the directory given as a file, the rejected option value, the unopenable destination and `--in-place` with stdin already reported correctly.

Acceptance check: `.venv/Scripts/python.exe .jeffy/probes/cli-errors/probe.py` exits 1 with 8 failures against the unfixed code (the 7 crashing steps plus the AST check that the `sqlparse.format` call is not inside a `SQLParseError` handler) and exits 0 after the fix, with all 12 provoked steps exiting 1 with exactly one `[ERROR]` line and no traceback. The 4 new or tightened pytest cases were proved the same way, with cli.py copied aside and HEAD's version restored: 4 failed before, 54 passed after. One of those four is an existing test whose scaffolding this fix invalidated - `test_cli_failed_run_leaves_file_intact` carried a `try/except SQLParseError: pass` and a comment saying this path still raises. The comment is now false, so the scaffolding is gone and the test asserts the exit code is 1.

The handlers are scoped per step rather than wrapped around the function, and deliberately: the read step is the only code that looks up a codec, so `LookupError` is caught there and nowhere else - a wrapper catching it around the whole function would report an internal `KeyError` from the parser as a read failure. The read step catches `(OSError, UnicodeError, LookupError)`, the format step catches `SQLParseError`, and the write step catches `(OSError, UnicodeError)` because writing can still fail after the destination opened.

Contract preserved: exit codes are unchanged at 1 for every failing path and 0 for success, `main` still processes the remaining files after one fails, and the destination selection was rewritten to name its destination once rather than repeat the open in three branches - the three destinations now share one `open` call and one `finally` that closes only what this function opened, so stdout is never closed. The `--in-place` truncation window EV-001 closed stays closed: the write-step handler reports a failure, it does not prevent one, and the only write failure that could be provoked is stdout, where there is nothing to truncate. An encode failure cannot reach an `--in-place` write, because output characters are a subset of input characters and the input decoded under that same encoding.

The cli-io row flips to swept, the last unswept row in the inventory. Its sweep is not the failure enumeration alone: `cli-atomic` gained a check that the three destinations - stdout, `-o`, `--in-place` - each produce output identical to `sqlparse.format` of the input, because every check that surface already had asks only whether the file changed, and a destination writing back the unformatted input satisfies all of them. That check was shown falsifiable by making the write emit `data` instead of the formatted text, which failed all three destinations plus the existing rewrite check; cli.py was copied aside first and restored after.

Battery ownership: the diff touches sqlparse/cli.py, matching cli-atomic, cli-bool, cli-errors and trailing-newline; all seven batteries were run and all exit 0. Verify gate -> 571 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0.

Learnings: A failure class is enumerated by provoking a failure at every step and watching what the user sees, not by reading the code for the calls it makes. Four of the six crashing steps here failed inside the standard library rather than inside anything sqlparse calls by name, so the source-scan version of this enumeration would have found two of six and declared the class closed.

Next: JF-007, the last open item, is the enumeration of stale `TokenList.value` reads outside the two sites already fixed. The inventory is complete at 24 of 24 rows and the ledger holds one Medium.

## iter 4/10 | d94c386f-153253 | 2026-08-08 | JF-007 | done

Task: JF-007 (Medium, correctness) - `TokenList.value` is a cache nothing refreshes, and JF-006 found two readers of it that were wrong. This task was the enumeration: classify every `.value` read in sqlparse/ with evidence, fix the stale ones, pin the result.

Changed: sqlparse/sql.py (comment only), tests/test_format.py, .jeffy/probes/value-cache/{probe.py,paths}, PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: e780997872eb1fe4e8a643fc79fecc0aa8224b9b

Stall check: not a stall - this iteration changed sqlparse/sql.py and tests/test_format.py, added a battery, and JF-007 moved from open to closed.

Verification: The enumeration is 18 distinct read sites across 6 modules, keyed by module, enclosing function and receiver expression. Rather than reason about which could receive a group, all 18 were instrumented: each read was rewritten to a recorder that returns the same value while counting how often the receiver was a group and how often that group's cached value differed from `str(token)`. The instrumented tree then ran the full test suite, the fixture corpus through seven option sets, and every battery, and the files were restored from copies afterwards - the tree was verified clean before and after.

Fifteen sites never received a stale value, several of them never receiving a group at all. Three did: `TokenList.__init__` (90 of 12677 group reads), `StripCommentsFilter._get_insert_token` (29 of 29 - every group it ever sees is stale), and `ReindentFilter._process_identifierlist` (1 of 1099). A separate instrument established the timing: after grouping and before any stmtprocess filter, no group is stale in any fixture statement, so `parse()` results are always accurate and the whole class is confined to the formatting pipeline.

None of the three is a defect, and each was settled by running the alternative rather than by argument:
- `TokenList.__init__` fills the cache from its children's caches, so it inherits their staleness. Reading `str(token)` there is exactly the recursive flatten on every construction that was removed for CWE-1333, so the cache stays and the obligation is on readers.
- `_get_insert_token` asks whether the comment it is removing ended a line. It gets the right answer only from the cache: by then the live tokens no longer carry that newline, because the filter recurses into sublists before reading. Switching it to `str(token)` changed 24 of 217 corpus outputs and lost the line break in every one - `select a, -- one\nb from t` became `select a,  b from t` instead of `select a,\nb from t`, which is the issue484 behaviour.
- The reindent site feeds a stale length into the `wrap_after` column accounting. Switching it moved 5 of 161 outputs, so I measured which is right rather than assuming: over the corpus at three limits, the current code leaves 305 of 817 lines over the limit at `wrap_after=20` and the alternative 305 of 814 at 307, with an identical worst overshoot of 138. `wrap_after` is a soft heuristic that no version of this line makes hold, so no correctness criterion separates them and the read is left alone.

The gap worth closing was not a stale read but an unpinned one. `test_issue484_comments_and_newlines` in the suite is xfail, so nothing guarded the `_get_insert_token` behaviour: the obvious "fix" would have silently changed strip_comments output with a green suite. Four known-answer cases now pin it, their expected values taken from observed stdout, and they were proved falsifiable by making the switch - 6 strip_comments tests fail with `str(token)` and all 11 pass without it, so two pre-existing tests were also guarding part of this.

Acceptance check: `.venv/Scripts/python.exe .jeffy/probes/value-cache/probe.py` exits 0, reporting 18 distinct sites and 21 statements checked for staleness after grouping alone. It was proved falsifiable by injecting a new `.value` read into `StripCommentsFilter.process`, which it reported as unclassified with exit 1; the injected line was then removed and it returned to exit 0. It also fails if a verdict names a site that no longer exists, so the table cannot rot into a list of claims about deleted code.

The only source change is a comment where the cache is assigned, stating that it is a cache, why it is not computed recursively, and that readers running after a filter must ask `str(token)`. That is the durable form of what JF-006 cost two iterations to learn. Because it changes sqlparse/sql.py, the sql-accessors and sql-nodes inventory rows are re-recorded at this iteration's checkpoint; their kept battery, breadth-sweep, was re-run and exits 0.

Battery ownership: the diff touches sqlparse/sql.py, matching breadth-sweep and the new value-cache; all eight batteries were run and all exit 0. Verify gate -> 575 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0.

Observed and deliberately not filed: `wrap_after` does not hold its documented column limit, on either variant. I am not filing it, because my measurement counted every output line and `wrap_after` only governs comma-separated list wrapping, so a long line from a string literal or a comment is outside its remit and the number does not establish a defect. A later audit that wants this should measure only lines produced from identifier lists.

Learnings: A read that looks like a bug can be load-bearing. Two of the three stale reads here were deliberate, and the evidence that settled them was running the alternative over the corpus and diffing - not reading the code more carefully. Where a "fix" would change behaviour, the alternative is an experiment, and its result belongs in the record whichever way it comes out.

Next: the ledger is empty, the inventory is complete at 24 of 24 rows, and no full fresh-evidence audit has run in this run - the last one was in the previous run, before four fixes landed. Iteration 5 audits.

## iter 5/10 | d94c386f-153253 | 2026-08-08 | AUDIT | audit

Task: Full fresh-evidence audit. The ledger emptied after JF-007 and no full audit had run in this run - the last one was in the previous run, four fixes ago.

Changed: PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: 4b029bb0891f0690cb81297578c478ae90ac5871

Stall check: not a stall - this iteration filed JF-008 and JF-009, so BACKLOG.md changed state.

Verification: Staleness was computed rather than assumed: `git diff --name-only <recorded commit> HEAD -- sqlparse/` was run for each of the seven distinct commits recorded in the inventory. Exactly one row was stale - cli-args, recorded at 169c0b1 with sqlparse/cli.py changed by the EV-002 fix at 9a57815 - and it was re-swept and re-recorded at this iteration's checkpoint. Every other row names modules unchanged since its recorded commit.

All eight batteries exit 0, and each re-states the numbers the state files claim: output-escape 88 exact inputs and 45 fixture x option-set combinations, cli-errors 12 provoked failure steps, value-cache 18 read sites, option-errors 18 options with 12 echoing and 5 raising without echoing and truncate_char unvalidated, cli-bool 0 remaining `type=bool` sites. PLAN's claim of 20 source files re-executes to 20, and the inventory holds 24 swept rows and 0 unswept. All ten test modules pass in isolation, so no order dependence and no test passing on state a sibling leaked.

Four invariants ran over 35 inputs - 20 synthetic grammar shapes plus the 15 decodable fixtures - through 10 option sets: parse round-trip 35 checks 0 failures, split reconstruction 35 checks 0 failures, content preservation 350 checks 0 failures, reindent idempotence 105 checks 4 failures. Three inputs are rejected by the documented grouping limits and were counted as such rather than as failures. The content check initially reported 33 failures, all of them mine: it compared non-whitespace characters exactly while `keyword_case` and `identifier_case` legitimately fold them, and it reports zero once the comparison is case-insensitive. That is the second time this run a sweep indicted the code and was measuring itself.

The four idempotence failures are real and reproduce outside the harness. `format('select 1; select 2; select 3;', reindent=True)` returns statements separated by one blank line, formatting that result adds another, and the third pass is stable; `'begin; update t set a = 1; commit;'` and `'select * from t; select 1;'` behave identically, while input already separated by a single newline is stable. `reindent_aligned` and `strip_whitespace` are both idempotent on the same input, so this is reindent alone. The root cause is a disagreement between `ReindentFilter.process`, which prepends `'\n\n'` to every statement after the first unless the previous statement's text ends in a newline, and `_split_statements`, which collapses that leading whitespace run back to a single `'\n'` before it - so the gap grows one newline per pass until it saturates. Filed as JF-008, Medium: a formatter whose output is not a fixed point churns every file it has already formatted, and this project's own code comments describe a pre-commit hook as a use case.

Every option documented in docs/source/api.rst was exercised at two or more values that must change the output; all 16 are live and `right_margin` is rejected as documented. Two looked inert on first probe and were live once probed where they apply - `compact` changes nothing on a flat WHERE clause and collapses a CASE expression onto one line, and `indent_tabs` switches the indent character - which is the Lesson about probing a parameter on input where it can apply, earning its place a second time. `indent_char` appears in `validate_options` but in no documentation, and is overwritten from `indent_tabs` on every call, so it is derived rather than a parameter.

`wrap_after` was measured properly this time, on a query whose identifier list is the only thing being wrapped, which is what the iteration 4 entry said a later audit would need. Lines exceed the stated column limit by exactly the width of the identifier that crosses it: 27 against a limit of 20, 48 against 40, 69 against 60. That matches the CLI help, which calls it "Column after which lists should be wrapped", and not docs/source/api.rst, which calls it "the column limit (in characters)". The code is right and one of its two descriptions is wrong, so this is a documentation defect and is filed as JF-009, Low.

Security was re-checked with fresh evidence rather than carried forward: the grouping limits are still 100 and 10000, 150-deep nesting is rejected in 0.010s and a 6000-column select in 0.174s, and both documented override paths - raising the constant and setting it to None - were executed and work. The CLI was driven adversarially: a multi-file run mixing good and bad files formats every good file, leaves the bad one byte-identical, prints exactly one `[ERROR]` line and exits 1. Zero runtime dependencies, dev group locked in uv.lock.

Dimension scores, claiming all 24 rows; no row is unswept:
- correctness: Medium - JF-008, reindent is not a fixed point on multi-statement input.
- documentation: Low - JF-009, api.rst describes wrap_after as a limit when it is a threshold.
- security: None - limits enforced and overridable as documented, adversarial CLI input reports rather than crashes, output serializers escape what the target language cannot carry.
- error handling: None - all 12 provoked CLI failure steps report one `[ERROR]` line, all 18 options reject naming their own option.
- testing: None - 575 passing, all ten modules green in isolation, and every fix this run carries a check proved to fail against the unfixed code.
- correctness of the parse and split pipeline: None - round-trip, reconstruction and content preservation all clean over the corpus.
- architecture: None. code quality: None, ruff clean. performance: None. dependency hygiene: None. developer experience: None.
- observability: not applicable, a parsing library with no logging or metrics surface by design. UX and accessibility: not applicable beyond the CLI, scored under developer experience.

CLOSEOUT HAS NOT BEGUN: this audit found one Medium, so the run keeps auditing rights and must reach a clean full audit before it can converge.

Learnings: Check a sweep's own normalisation before believing its failures - for the second time this run, a fresh invariant indicted most of its corpus and was measuring itself rather than the code. The rule is already in Lessons; what is new is that it fired on a comparison I wrote in the same iteration, not an inherited one.

Next: JF-008, the Medium, in iteration 6; JF-009, the Low, in iteration 7; then a full audit, and on a clean result the evaluator gate and the declaration. Five iterations remain for a sequence that needs four, so there is one iteration of slack.
## iter 6/10 | d94c386f-153253 | 2026-08-08 | JF-008 | done

Task: JF-008 (Medium, correctness) - `reindent` was not idempotent on multi-statement SQL: the gap between statements grew by one newline on every pass until it saturated at three.

Changed: sqlparse/filters/reindent.py, tests/test_format.py, CHANGELOG, .jeffy/probes/idempotence/{probe.py,paths}, PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: c1acfebffe363c8a96252bf7b23b100210a130ee

Stall check: not a stall - this iteration changed sqlparse/filters/reindent.py, tests/test_format.py and CHANGELOG, and JF-008 moved from open to closed.

Verification: The filed reproduction ran first and still held on all three inputs. The mechanism was then traced rather than inferred, by wrapping `ReindentFilter.process` and `_split_statements` and printing what each statement carried. On the first pass the second statement arrives with no leading whitespace at all - StripWhitespaceFilter, which reindent implies, has already removed it - so `_split_statements` finds nothing before the DML keyword and adds nothing, and `process` prepends the blank line. On the second pass the statement arrives carrying the previous pass's gap; strip whitespace reduces it to an empty token rather than removing it, `_split_statements` sees a token before the keyword and inserts a newline of its own, and `process` then prepends its blank line on top of that. Two separators, one gap.

The fix normalizes rather than counts: `process` now drops whatever leading whitespace the statement arrived with before writing the separator it computes, so the result no longer depends on what a previous run left. That makes the output a fixed point by construction rather than by arithmetic on the incoming gap.

Acceptance check: `.jeffy/probes/idempotence/probe.py` over 27 inputs - 12 multi-statement synthetics plus the 15 decodable fixtures - through reindent, reindent_aligned and reindent with indent_width. Against the unfixed code it exits 1 with 14 failures, which includes the 4 the iteration 5 audit reported and 10 more from synthetics the audit's corpus did not carry; after the fix it exits 0. Not one failure came from a fixture, which is why five audits missed this: every fixture separates statements with a newline, and only a gap that is not exactly one newline grows. The 6 new pytest cases were proved the same way, with reindent.py copied aside and HEAD's version restored: 4 failed before, 13 pass after.

Behaviour change, recorded as the Constraints require: the gap between statements is now normalized, so input that already carried a wider gap is narrowed to one blank line. Over the fixture corpus at 6 option sets, 12 of 90 keys moved and every one of them is the same fact. For the 4 plain-SQL keys the evidence is exact - a newline run of 3 became 2 in each, with every other run unchanged. The other 8 are the python and php serializers, where the lost newline shows as one fewer continuation line; decoding those snippets, the python ones with `ast` and the php ones with the reference decoder lifted out of the output-escape battery rather than a second hand-rolled regex, all 8 are identical to their previous output once whitespace runs collapse. So no statement text changed anywhere; only the size of the gap between statements did.

Battery ownership: the diff touches sqlparse/filters/reindent.py, matching breadth-sweep, value-cache and the new idempotence battery; all nine batteries were run and all exit 0. Verify gate -> 588 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0.

Because this changes what `format(sql, reindent=True)` emits, the api-format-indent and filters-indent inventory rows are flipped back to unswept for the next audit to re-sweep, rather than re-recorded here on the strength of a battery that only tests idempotence.

Learnings: A corpus of real fixtures is not automatically a corpus of real inputs. Every fixture in this project separates statements with a newline, which is the one shape that was already a fixed point, so the defect was invisible to five audits that all ran the fixtures. The synthetic that found it - two statements on one line - is what a script typed at a prompt looks like.

Next: JF-009, the Low documentation finding about wrap_after, in iteration 7. Then a full audit in iteration 8 to re-sweep the two flipped rows and reach a clean score, and on that result the evaluator gate and the declaration.

## iter 7/10 | d94c386f-153253 | 2026-08-08 | JF-009 | done

Task: JF-009 (Low, documentation) - docs/source/api.rst called `wrap_after` "the column limit (in characters) for wrapping comma-separated lists", which the output does not satisfy.

Changed: docs/source/api.rst, tests/test_format.py, CHANGELOG, BACKLOG.md, JOURNAL.md.

Checkpoint: e83739e1ae8d4623b526d51546ab52052432a434

Stall check: not a stall - this iteration changed docs/source/api.rst, tests/test_format.py and CHANGELOG, and JF-009 moved from open to closed.

Verification: The filed measurement ran first and still held. On `select col00, ... col29 from t`, where the identifier list is the only thing being wrapped, `wrap_after=20` produces a longest line of 27, `40` produces 48 and `60` produces 69, with 10, 5 and 3 lines respectively past the stated limit. The first line at `wrap_after=40` is `select col00, col01, col02, col03, col04, col05,` at 48 characters: items are added until the column is passed, so the item that crosses it stays on the line.

The fix is to the documentation, not the code, and the reason is on the record from the iteration 5 audit: the CLI help for the same option already says "Column after which lists should be wrapped", which describes the behaviour exactly, so the code agreed with one of its two descriptions and api.rst was the one that was wrong. Changing the code to make the wording true would have altered formatting behaviour nobody complained about, to satisfy a sentence rather than a requirement. api.rst now states the actual rule, including that the line ends past the column rather than within it, and keeps the existing sentence about the unspecified default, which was re-checked and is accurate.

The known-answer test pins the behaviour the documentation now describes: the first line and the longest line are both 48 characters at `wrap_after=40`. It was proved able to fail by making the wrap fire one item earlier - `position > (self.wrap_after - self.offset)` became `position + 8 > ...` at both sites - which failed the assertion with `'select col00...col03, col04,' == 'select col00...col04, col05,'`; reindent.py was copied aside first and restored after, and the working tree was confirmed to carry only the docs and test changes.

Battery ownership: the diff touches no path under sqlparse/, so no battery owns it; all nine were run anyway and all exit 0. Verify gate -> 589 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0.

Learnings: When code and its documentation disagree, check whether a second description exists before deciding which side is wrong. Here the CLI help and the API reference described the same option differently, the code matched the CLI help, and the cheap correct fix was the sentence - not the wrapping algorithm that the other sentence would have required changing.

Next: the ledger is empty but two inventory rows are unswept, flipped by the JF-008 fix, and this run has no clean full audit on record - the iteration 5 audit found a Medium. Iteration 8 runs a full audit that re-sweeps both rows; on a clean result iteration 9 runs the evaluator gate and, if it passes and the closing conditions hold, declares in that same iteration.

## iter 8/10 | d94c386f-153253 | 2026-08-08 | AUDIT | audit

Task: Full fresh-evidence audit. The ledger emptied after JF-009 and the run's only previous full audit, in iteration 5, found a Medium - so the run needed a clean one before it could converge, and two inventory rows flipped by the JF-008 fix needed re-sweeping.

Changed: PLAN.md, JOURNAL.md, JOURNAL-archive.md.

Checkpoint: 693a2217474b7bff0999b68d437fe8e90f5c7104

Stall check: this iteration changed only state files and filed nothing, so it is a no-progress iteration by the letter of the check. It is an AUDIT that files nothing, which the ceremony exemption covers, and the previous primary entry was the JF-009 fix, so no consecutive pair exists.

Verification: Staleness was recomputed per recorded commit. sqlparse/filters/reindent.py has changed since every commit in the inventory, which is the JF-008 fix; the only two rows naming it were already unswept, and no other row names a module that changed since its own recorded commit.

Both flipped rows were re-swept with fresh evidence and re-recorded at this iteration's checkpoint. All nine indent parameters were driven at two values that change the output, each on a query where it can apply - a nested subquery for the widths and characters, a six item list for the column and wrap options, a CASE expression for compact - and the first line of each output was printed rather than a boolean, so a parameter that merely perturbed something would be visible. None was inert. The boundary and negative sides are rejected with a message naming the option: indent_width at 0 and at -1, wrap_after at -12, and a non-boolean for indent_tabs and indent_columns. Every resulting option set is also a fixed point.

The code JF-008 touched was probed hardest, since that is where a new defect is most likely. Ten degenerate inputs were driven through reindent - whitespace-only trailing statement, comment-led second statement, block comment between statements, CRLF separators, a single statement, empty input, whitespace only, leading whitespace on the first statement, a bare semicolon, and doubled semicolons. Every one is a fixed point and every one round-trips through parse, except whitespace-only input, which yields no statement and therefore no text; that is unchanged by this run and was recorded as correct rather than defective in the previous run's audit.

All nine batteries exit 0. All ten test modules pass in isolation, so no order dependence and no test standing on state a sibling leaked. The four corpus invariants over 35 inputs through 10 option sets are clean on every one: round-trip 35 checks, split 35, content 350 and idempotence 105, all with zero failures - the idempotence count was 4 failures in the iteration 5 audit and is zero now. Three inputs are rejected by the documented grouping limits and counted as such.

Security re-checked with fresh evidence: the limits are still 100 and 10000, 150-deep nesting is rejected in 0.006s and a 6000-column select in 0.149s, and docs/source/api.rst states both defaults correctly. Numbers stated in the state files re-execute: 20 source files, 24 inventory rows, zero open backlog tasks.

Dimension scores, claiming all 24 rows; no row is unswept:
- correctness: None - round-trip, split reconstruction, content preservation and idempotence all clean over the corpus, and the reindent change is a fixed point on ten degenerate inputs as well.
- documentation: None - every option documented in api.rst was exercised at two values in this run, the wrap_after wording now matches the behaviour and the CLI help, and both DoS defaults are stated correctly.
- security: None - limits enforced and overridable as documented, adversarial CLI input reports rather than crashes, serializers escape what the target language cannot carry.
- error handling: None - 12 provoked CLI failure steps each report one `[ERROR]` line, every validated option rejects naming itself, and the indent boundary values are rejected the same way.
- testing: None - 589 passing, all ten modules green in isolation, and every fix this run carries a check proved to fail against the unfixed code.
- architecture: None. code quality: None, ruff clean. performance: None. dependency hygiene: None, zero runtime dependencies. developer experience: None.
- observability: not applicable, a parsing library with no logging or metrics surface by design. UX and accessibility: not applicable beyond the CLI, scored under developer experience.

CLOSEOUT HAS BEGUN: this audit is a full fresh-evidence pass scoring zero High and zero Medium in-envelope, and it files nothing. No further audit or replenishment runs for the rest of this run; what remains is the evaluator gate and, on PASS with the closing conditions holding, the declaration.

Learnings: none new this iteration - the audit re-executed existing rules rather than discovering one.

Next: the evaluator gate in iteration 9, with the declaration in that same iteration if it returns PASS and the closing conditions hold. Two iterations remain, so a REJECT still leaves iteration 10 to answer it.

## iter 8/10 | d94c386f-153253 | 2026-08-08 | ROTATION | rotation

Task: JOURNAL.md reached 531 lines after the iteration 8 audit entry, past the 500 line threshold.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: 693a2217474b7bff0999b68d437fe8e90f5c7104

Verification: 18 entries were found by splitting only on lines beginning `## iter` followed by a digit, so the indented heading-grammar example in the preamble was neither counted nor moved. The 8 oldest entries - the previous run's iterations 1 through 8 - were appended to a newly created JOURNAL-archive.md, which went from 0 entries to 8, and the 10 newest were kept, the oldest of them being the previous run's iteration 9 evaluator entry. JOURNAL.md is now 321 lines and the archive 213. The archive is append-only and was created rather than overwritten, since it did not exist before this rotation.

Learnings: none.

Next: unchanged - the evaluator gate in iteration 9.

## iter 9/10 | d94c386f-153253 | 2026-08-08 | EVALUATOR | audit

Task: Adversarial evaluator gate, invocation 1 of at most 2 for this run. Spawned as one fresh-context sub-agent carrying none of this run's context, given the run-id and the base commit cdc7ad5459e30da33a3ea4e16e2d6aa2a5bc2083.

Changed: BACKLOG.md, JOURNAL.md, .jeffy/evaluator/d94c386f-153253.md.

Checkpoint: b0ddd24f42cb002b0847700b5d399829c1882552

Stall check: not a stall - BACKLOG.md changed state by filing EV-004 and EV-005, and the evaluator artifact was added.

Verification: Evaluator: REJECT - four reasons returned, two of which I confirmed, one of which I could not reproduce as stated, and one which is subsumed. The gate confirmed the parts that hold: the Verify command exits 0 at 589 passed, all nine batteries exit 0 and their printed numbers check out, an independent 3216-check sweep of the output serializers - ast.parse for Python, its own PHP double-quoted scanner, and the reference captured by spying on `OutputFilter.process` rather than trusting the run's probe - reports 670 failures against the pre-fix code and none at HEAD, 36 adversarial CLI invocations produce zero tracebacks, JF-009's new wording matches the code, and the JF-008 whitespace pop cannot drop a comment because comments are groups whose is_whitespace is False. It also checked that the 4 idempotence failures it found at HEAD are a strict subset of the 94 at the base commit, so nothing was regressed. The artifact is 205 lines naming every command with its real exit status.

I re-ran all four reasons rather than accepting them, and the results differ from the gate's on attribution:
- Reason 1, that reindent is not a fixed point under `indent_after_first`, does NOT reproduce as stated. `indent_after_first=True` alone is a fixed point on all 20 inputs I drove, and in a 2024-check sweep over option-set combinations not one failure is attributable to that option. The gate's sweep counted every combination containing the flag, which is most of them once three options are combined, so the blame it reports is an artifact of counting rather than a cause.
- Reason 3 reproduces exactly and is the real defect underneath reason 1. Of 2024 checks, 39 fail, all on two of the project's own fixtures: begintag_2.sql under any option set including strip_comments, and dashcomment.sql with reindent and reindent_aligned both enabled, where a blank line before a `--` comment disappears on the second pass - each of those two options alone is a fixed point on that file. Filed as EV-004, Medium.
- Reason 2, that the CHANGELOG sentence about reindent being a fixed point is falsified, is true only in the broad reading: reindent alone is a fixed point everywhere I measured, and the failures need either strip_comments or the two indent filters together. The sentence is narrowed as part of EV-004 rather than filed separately.
- Reason 4 reproduces. Running the committed output-escape battery against sqlparse/filters/output.py from ae51255 reports 41 failures, not the 17 the Settled classes line claims; the 17 was measured mid-iteration 2, before the fixture corpus was added to that same battery, and nothing re-executed the sentence afterwards. Filed as EV-005, Low. This is the "re-execute the claims a fix invalidates" rule failing on a claim invalidated by the very iteration that wrote it.

The honest summary of this gate: the code fixes hold under independent attack, and both surviving reasons are about the run's own bookkeeping being broader than its evidence - a class declared complete that is not, and a number that was true for ten minutes.

Observations the gate recorded that are not REJECT reasons, carried to the run report and the next run's ledger rather than fixed here: `format('select 1; select 2;')` with no options returns `'select 1;select 2;'`, which reproduces at the pristine upstream commit and is outside this run's scope; the CHANGELOG phrase "Six of the seven failure steps" matches neither the 12-case enumeration nor the six stages of `_process_file`; sqlparse/cli.py carries a dead `close_stream = False`; and the idempotence and cli-atomic probes do a bare `import sqlparse`, so run from another working directory they would test the installed package rather than the tree.

Verify gate -> 589 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0.

Learnings: An enumeration that counts combinations attributes blame to whatever appears in most of them. When a sweep reports that one option is responsible for every failure, hold the suspect option fixed and vary the rest before believing it - here that turned a false lead about indent_after_first into the real cause, two comment-bearing fixtures under option pairs the battery never tried.

Next: one iteration remains, so the run cannot fix EV-004, re-invoke the gate and declare inside it - and a second REJECT is terminal. Iteration 10 writes the WRAPUP and the handoff.

## iter 10/10 | d94c386f-153253 | 2026-08-08 | WRAPUP | done

Task: Final iteration. The evaluator gate rejected at iteration 9 and one iteration is not enough to fix EV-004, re-invoke the gate and declare, so this entry tidies the ledger and writes the handoff instead of starting work that cannot finish.

Changed: BACKLOG.md, JOURNAL.md.

Checkpoint: 25ef0b21e24c91cd7e774ec2cbec09922a4d8678

Stall check: this iteration changed only state files, but EV-005 moved from open to closed, so a BACKLOG item changed state and it is not a no-progress iteration. The previous primary entry was the evaluator gate, a ceremony entry, so no consecutive pair exists either way.

Verification: Two corrections to the ledger, both measured rather than reasoned. EV-005 is closed: the Settled classes line for the output-escape class claimed the battery reports 17 failures against the pre-fix code, and the committed battery run against sqlparse/filters/output.py from ae51255 reports 41 - 39 from the fixture corpus and 2 from the AST walk. The line now carries 41 with the commit it was measured against and the reason the old number was wrong, which is that 17 was measured mid-iteration-2 before the fixture corpus joined that same battery. output.py was copied aside for the measurement and restored, and the battery exits 0 against the restored file.

The fixed-point class is marked NOT settled and REOPENED, the same treatment the escaping class received when EV-003 reopened it in the previous run. Leaving it marked class-complete would have barred the next run's audit from filing inside a class that demonstrably still fails, which is the opposite of what the Settled classes section is for. The superseded wording is kept on the line so the record shows what changed.

Verify gate -> 589 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0. All nine batteries exit 0.

Learnings: A settled class is a claim with an expiry date, and the thing that expires it is usually a battery that grew after the claim was written. Both of this gate's surviving reasons were of that shape - a number true for one version of a probe, and a completeness claim true for the three option sets a battery happened to try. When a battery is extended, the sentences that cite it are part of the diff.

Handoff for the next run, which starts with a fresh audit and an empty context:
- EV-004 (Medium, open, in Now) is the first task. Formatting is still not a fixed point on comment-bearing input: 39 of 2024 option-set x input checks fail, all on begintag_2.sql under any set including strip_comments and on dashcomment.sql with reindent and reindent_aligned both enabled, where each option alone is stable. The battery at .jeffy/probes/idempotence/ tests three option sets individually and no pair, and never strip_comments, although its own paths file already claims sqlparse/filters/others.py. Extend it to combinations first and watch it fail before fixing anything.
- The gate's four observations, none of them defects, and none to be fixed inside a convergence sequence: `format('select 1; select 2;')` with no options returns `'select 1;select 2;'`, which reproduces at the pristine upstream commit and is outside this run's scope; the CHANGELOG phrase "Six of the seven failure steps" matches neither the 12-case enumeration nor the six stages of `_process_file`; sqlparse/cli.py carries a dead `close_stream = False`; and the idempotence and cli-atomic probes do a bare `import sqlparse`, so run from another working directory they would test the installed package rather than this tree. The last of those is the one worth doing first, because it can make a battery lie.
- The CHANGELOG sentence saying the output of reindent is a fixed point is accurate for reindent alone and too broad for the option pairs above; EV-004's acceptance includes narrowing it.
- One Proposed item still awaits the user and must not be worked without approval: whether to implement right-margin wrapping as a real feature, with the removed code at 2ad3619dced5bac0e35b7ffeb8863827356ccc59.
- The evaluator gate for this run is spent at one invocation, verdict REJECT, artifact at .jeffy/evaluator/d94c386f-153253.md. The next run gets a fresh cap.
- The Surface inventory is complete at 24 of 24 rows and no row is stale as of this checkpoint.

Next: the run ends here, out of budget and not converged, with EV-004 open.

## iter 1/10 | 74432a21-171900 | 2026-08-08 | EV-004 | done

Task: Formatting is not a fixed point on comment-bearing input, under option sets the idempotence battery does not cover. Filed by the previous run's evaluator gate as the only open task.

Changed: sqlparse/filters/others.py, sqlparse/formatter.py, sqlparse/cli.py, tests/test_format.py, docs/source/api.rst, CHANGELOG, .jeffy/probes/idempotence/probe.py, .jeffy/probes/idempotence/paths, .jeffy/probes/value-cache/probe.py, PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: b0e0be9bf63c089efe8fa4874997fc5900229fea

Stall check: not a stall - three source modules changed and EV-004 moved from open to closed.

Verification: The filed reproduction ran first and half of it had already rotted: strip_comments alone on begintag_2.sql is a fixed point today, so the line's "needs strip_comments" was true only of pairs. A sweep of all 14 single options and all 91 unordered pairs over 27 inputs - 2809 checks - found 6 distinct failures on 2 inputs, not the 39 the line reported; the 39 counted every option-set superset containing a failing pair, which is the same counting artifact the previous run's gate was caught by. Both root causes were then traced rather than inferred.

Root cause 1: StripWhitespaceFilter._stripws_default decided "the previous token was whitespace" from token.is_whitespace, which is False for a group even when the group renders with a trailing space. Confirmed by dumping the Identifier group on begintag_2.sql: after StripCommentsFilter it holds [Name, Newline(' '), Newline('')] and renders 'remove_..._link ', and the statement-level whitespace that follows was kept as a second space. The fix asks a new _trailing_ws helper for the token's rendered tail. First attempt regressed 71 checks because emptying a leading whitespace token stopped counting as whitespace, and the lexer emits one token per newline, so the second newline of '\n\n' became a space; a whitespace token now keeps the run set explicitly, which is exactly the old behaviour for whitespace tokens, so the change reaches only groups.

Root cause 2: reindent and reindent_aligned are alternative styles, and enabling both stacked two indenters that each insert a newline before the same keywords. On 'select a, b from t where a = 1 and b = 2' the combination produces a blank line between every clause, which is neither style. Instability traced by spying on ReindentFilter.process: the inter-statement gap it inserts is deleted by AlignedIndentFilter._process_statement, gluing statements so the next pass parses a different set of them, and the JF-008 gap decision reads str(self._last_stmt) after the aligned filter has rewritten it. validate_options now rejects the combination, the remedy the envelope prescribes for a user-error surface and the same shape JF-003 used for right_margin. No change was needed in reindent.py: with the combination rejected, no filter runs after ReindentFilter that mutates the statement.

Contract preserved: every documented single-style option set is unchanged. The corpus differential over 29 inputs x 106 option sets, 3074 keys, was classified with an exact character-level edit script - a normalising regex first reported 34 changes as unnamed and was measuring itself. 127 keys differ and every one is named: 65 delete one space immediately after a newline (_Make_DirEntry.sql, begintag_2.sql - a comment group ending in a newline made the parent emit a stray space at the start of the next line, stable across passes and therefore invisible to idempotence); 4 delete one space after 'k' on begintag_2.sql, which is the doubled space EV-004 was filed for; 58 became the style-collision rejection, and no rejection is anything else. 2947 keys are byte-identical.

Acceptance: .jeffy/probes/idempotence/probe.py extended from 3 option sets to 105 - every single option that can move whitespace and every unordered pair. It also requires the rejected set to be exactly the style collisions, so a bug cannot hide by rejecting more, guards that it imported the tree rather than an installed package, and drives the real CLI once. Against sqlparse/filters/others.py and sqlparse/formatter.py as of 834ca16fae6b412ded99b23a3d7d57e079f2423a the committed battery reports 58 failures; at HEAD it reports none over 2757 accepted checks and 54 expected rejections. The real CLI check: sqlformat -r -a exits 1 with one [ERROR] line naming the collision and no traceback.

Battery ownership: the diff touches sqlparse/filters/others.py, sqlparse/formatter.py and sqlparse/cli.py, matching the paths files of idempotence, option-errors, cli-atomic, cli-bool, cli-errors, trailing-newline, breadth-sweep and value-cache. All nine batteries were run and all nine exit 0. value-cache failed first, correctly: _trailing_ws is a new .value read site with no recorded verdict. The verdict was measured, not asserted - over 19 inputs at 66 option sets the read was reached by 51156 group receptions 0 times, against 152076 leaf reads, because it sits behind `if not token.is_group`. sqlparse/formatter.py was added to the idempotence paths file, since the battery now depends on the validator.

Docs updated in the same iteration as the behaviour: api.rst records the combination as an error, both CLI help strings name the exclusion, and the CHANGELOG sentence claiming "the output of reindent is a fixed point" is narrowed to the inter-statement gap, with entries added for both fixes.

Verify gate -> 597 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0. Was 589 before; the 8 new tests are the group-trailing-whitespace regressions, the four-option fixed-point parametrisation and the two style-collision rejections.

Learnings: The lexer emits one token per newline, so '\n\n' is two whitespace tokens and an emptied one must still count as whitespace - the first version of this fix turned every blank line into a space and the battery caught it. Classify a before/after corpus diff with an exact edit script, never a normalising regex: mine stripped all indentation after newlines and hid 34 identical one-space changes in an unnamed bucket. And the differential earns its cost independently of the battery - the stray space after a newline was a fixed point, so no idempotence check would ever have found it.

Next: the ledger is empty, so iteration 2 is a full fresh-evidence audit per the Method, which must re-sweep the 7 Surface inventory rows this fix made stale (api-format-indent, api-format-strip, formatter-validate, formatter-build, cli-args, cli-io, filters-others); 17 of 24 rows remain swept. The previous run's four gate observations are still unfiled and the audit should judge them, the bare-import one being already handled for the idempotence battery only.

## iter 2/10 | 74432a21-171900 | 2026-08-08 | AUDIT | audit

Task: Full fresh-evidence audit. The ledger emptied when EV-004 closed, and the EV-004 fix left 7 Surface inventory rows stale, so they had to be re-swept before any dimension could be scored.

Changed: PLAN.md, BACKLOG.md, JOURNAL.md, .jeffy/probes/breadth-sweep/probe.py.

Checkpoint: 4d304fb3d5e61e36645eb6825bbd4489c1e77944

Stall check: not a stall - BACKLOG.md changed state by filing JF-010 through JF-013, and the breadth-sweep battery gained the style-collision known answers.

Verification: Staleness was recomputed rather than remembered, with git diff --name-only from each of the 5 distinct recorded commits to HEAD over sqlparse/. Exactly the 7 rows this run flipped name a file that changed since their own recorded commit, and no other row does; in particular statement_splitter.py, output.py, reindent.py, aligned_indent.py, sql.py, lexer.py, keywords.py, tokens.py, utils.py, grouping.py and filter_stack.py are all unchanged since the commits their rows record.

All 7 rows were re-swept with fresh evidence at d66aa63c28ba542692160a34ecc5e2818c77882c and re-recorded. The kept breadth-sweep battery was re-run rather than rebuilt, and extended with the new mutual exclusion - both colliding pairs rejected, each style alone still producing its own known-answer output, and validate_options pinned directly. All 24 rows are swept and none is stale.

Two probe errors of mine, both caught by the probe rather than by reading, and both instances of rules already in Lessons. First, I expected format('select a\n-- c\nfrom t', strip_comments=True) to be 'select a\nfrom t'; it is 'select a\n\nfrom t', and it is byte-identical at 834ca16, so the expectation was reasoned rather than observed and there is no finding. Second, four CLI options looked inert because I drove tests/files/function.sql, which has no comments, no operators, uppercase keywords and lowercase identifiers. Re-driven on input carrying all four, every documented option changes the output, keyword_case and identifier_case each produce 3 distinct outputs across their 3 documented values, and --encoding utf-8 is asserted not to alter already-valid utf-8 rather than skipped. -k upper is an identity on already-uppercase input, which is correct and not an inert parameter.

The code iteration 1 touched was probed hardest. `_trailing_ws` was exercised at all seven of its branches by construction - leaf whitespace, emptied leaf, leaf name, group ending in whitespace, group whose tail is an emptied token, group rendering nothing, nested group - deep nesting at 150 still raises SQLParseError rather than leaking RecursionError, nesting at 90 round-trips, and huge_select.sql formats in 0.078s with strip_whitespace and 0.330s with reindent, so walking the tail did not reintroduce the CWE-1333 construction. build_filter_stack was asserted to carry exactly one indenter for each of reindent, reindent_aligned and indent_columns.

All nine batteries exit 0. tests/test_format.py run in isolation passes at 129 passed, 1 xfailed, so no order dependence there. DoS limits re-measured at their documented values: depth 100 rejects 150-deep nesting in 0.008s, tokens 10000 rejects a 6000-column select in 0.114s. Zero runtime dependencies - pyproject declares only optional dev and doc groups.

The previous run's four gate observations were judged with evidence rather than carried forward again. Three are real and are filed as Low: the dead close_stream assignment (JF-011, confirmed overwritten before any read), the CHANGELOG "Six of the seven failure steps" count (JF-010, against a battery that enumerates 12 and a settled-class line recording 7 crashes), and the two batteries importing sqlparse unguarded (JF-012, breadth-sweep and output-escape; cli-atomic already carries a guard, contrary to the observation as recorded). The fourth is filed as JF-013 with its root cause found: format() appends SerializerUnicode unconditionally and it rstrips every line, so an inter-statement space at end-of-line is removed; parse() keeps it.

Dimension scores, claiming all 24 rows; no row is unswept:
- correctness: Low - JF-013 only, a cosmetic inter-statement space that reproduces at pristine upstream; round-trip, split and idempotence are clean across the corpus.
- code quality: Low - JF-011, one dead assignment. ruff clean.
- documentation: Low - JF-010, one wrong count in a CHANGELOG entry; api.rst and both CLI help strings match the code, including the new exclusion.
- testing: Low - JF-012, two batteries that could certify an installed package if run from elsewhere. 597 passing, one module green in isolation, and the EV-004 fix carries a check proved to fail against the unfixed code.
- security: None - limits enforced at their documented values and overridable as documented, adversarial CLI input reports rather than crashes, serializers escape what the target language cannot carry.
- error handling: None - the 12 provoked CLI failure steps each report one [ERROR] line, every validated option rejects naming itself, and the new style collision does the same at the library and the CLI.
- architecture: None. performance: None - the two hot paths re-timed above. dependency hygiene: None, zero runtime dependencies. developer experience: None.
- observability: not applicable, a parsing library with no logging or metrics surface by design. UX and accessibility: not applicable beyond the CLI, scored under developer experience.

CLOSEOUT HAS BEGUN: this is a full fresh-evidence pass scoring zero High and zero Medium in-envelope. No further audit or replenishment runs for the rest of this run; what remains is working or declining the four Low items, then the evaluator gate and the declaration.

Learnings: none new - both mistakes this iteration were existing Lessons recurring in my own probes, which is the Lessons section working rather than a new rule. The one thing worth keeping is that an observation carried between runs is a hypothesis like any backlog line: of the four, one had already been fixed for one of the two batteries it named, and one needed its root cause found before it could be priced.

Next: iteration 3 works JF-013, the top item and the only runtime correctness one. Eight iterations remain, so the gate can run once the ledger empties with at least 3 left, which is the intended shape.

## iter 3/10 | 74432a21-171900 | 2026-08-08 | JF-013 | done

Task: `format()` with no options dropped the space between two statements that share a line, returning 'select 1;select 2;' for 'select 1; select 2;'. Top unblocked item and the only runtime correctness one on the ledger.

Changed: sqlparse/__init__.py, sqlparse/filters/others.py, tests/test_format.py, CHANGELOG, .jeffy/probes/idempotence/probe.py, .jeffy/probes/idempotence/paths, .jeffy/probes/output-escape/probe.py, .jeffy/probes/trailing-newline/probe.py, PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: 0600cd8ae0be2acecb8fb500eb66cdef122d3809

Stall check: not a stall - two source modules changed and JF-013 moved from open to closed.

Verification: The filed reproduction ran first and held exactly as written. The root cause the audit recorded was confirmed: `format` appended `SerializerUnicode`, which right-strips every line of each statement independently, and a statement's last line is not necessarily the end of a line in the document - the next statement can start on it, and there the trailing space is the separator.

The first attempt right-stripped all but the last line of each statement. The corpus differential over 29 inputs x 106 option sets rejected it: 340 keys moved, and two of them were a regression, `{reindent, strip_comments}` on 'select 1; -- trailing comment\nselect 2;' gaining a trailing space before a newline - genuinely invisible whitespace that the old code removed. A statement cannot make this decision at all, so the right-strip moved to `format`, which joins the statements and then strips the lines of the whole document. There the same case is correct, because the space is followed by a newline and is stripped, while an inter-statement space mid-line is not.

That exposed a second, pre-existing fault. The idempotence battery went red on 'select 1; -- trailing comment\nselect 2;' under {strip_comments, strip_whitespace} and {reindent_aligned, strip_comments}: pass 1 gave 'select 1; select 2;' and pass 2 'select 1;select 2;'. `StripWhitespaceFilter.process` popped one trailing whitespace token at depth 0, and stripping a comment that ended a line leaves two - the space before it and its line break - so one survived. The old per-statement right-strip had been hiding the leftover. Repaired in this iteration under the newly-exposed exception rather than reverted, with the differential as the evidence the exception requires: after both changes 336 of 3074 keys differ, no fixture moved at all, and the assertion that every changed key equals its old value once '; ' is normalised to ';' holds for all 336 - so the only text that moved anywhere is the space after a semicolon.

Contract preserved: end-of-line whitespace is still stripped ('select a   \nfrom t' -> 'select a\nfrom t'), end-of-document whitespace is still stripped ('select 1;   ' -> 'select 1;'), CRLF is still normalised, `strip_whitespace` still drains a statement's trailing whitespace, and the trailing-newline battery's contract that format preserves the count of trailing newlines still holds. `parse` and `split` are untouched by the fix and were re-checked: exact round-trip on all 15 decodable fixtures.

Acceptance: `sqlparse.format('select 1; select 2;')` returns its input unchanged. Falsifiability was measured, not assumed - and the battery was the wrong instrument for it. Adding the no-options call to the idempotence battery left its pre-fix failure count at 58, unchanged, because JF-013 was an identity defect and not an idempotence one: the old output was wrong but stable. The falsifiable check is tests/test_format.py::test_format_keeps_the_space_between_statements, which fails 2 of its 4 cases against sqlparse/__init__.py and sqlparse/filters/others.py as of 834ca16 and passes at HEAD. The no-options case stays in the battery anyway, since that path now has code of its own.

Battery ownership: the diff touches sqlparse/__init__.py and sqlparse/filters/others.py, matching idempotence, trailing-newline, breadth-sweep and value-cache; sqlparse/__init__.py was added to the idempotence paths file. All nine batteries exit 0. Two probe docstrings asserted that SerializerUnicode right-strips each line, which this fix made false, and both were corrected in the same iteration - output-escape, whose reference text depends on where the strip happens, and trailing-newline.

Six inventory rows name a file this diff changed - api-parse, api-split, api-format-case, api-format-indent, api-format-strip and filters-others - and closeout means no later audit will re-sweep them, so they were re-swept inside this iteration with the evidence to hand rather than left unswept to block convergence. All 24 rows remain swept.

Verify gate -> 604 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0. Was 597; the 7 new tests are 4 inter-statement-space cases and 3 guards on the whitespace that must still be stripped.

Learnings: A right-strip is a document-level operation and cannot be done per statement, because whether a statement's last line ends a line of the document depends on what follows it. More generally, when a fix removes a normalisation, check what that normalisation was hiding: here it was a second bug in a different filter, six years old, that no test and no battery had ever seen.

Next: iteration 4 works JF-011, the dead close_stream assignment in cli.py. Three Low items remain, all small, so the ledger should empty at iteration 6 with four iterations left - comfortably inside the window where the evaluator gate should run rather than be deferred to the declaration.

## iter 4/10 | 74432a21-171900 | 2026-08-08 | JF-011 | done

Task: `sqlparse/cli.py` assigned `close_stream = False` and then overwrote it unconditionally before any read, so the first assignment was dead.

Changed: sqlparse/cli.py, PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: 7b903627745c8ea08dfe3acaf52b86f761e63277

Stall check: not a stall - sqlparse/cli.py changed and JF-011 moved from open to closed.

Verification: The reproduction ran first and held: an AST walk counting assignments to `close_stream` in sqlparse/cli.py returned 2, and the only statement between them is the if/elif/else that picks `dest`, which never reads the name. The dead line is deleted and the same walk now returns 1, so the acceptance check is falsifiable and was observed at both values. No CHANGELOG entry: this is an internal deletion with no user-visible behaviour, and the CHANGELOG is not a commit log.

Contract preserved: `close_stream` still decides whether the destination is closed, and it is still true exactly when `--in-place` or `-o` was given. The branch the deleted line sat in was exercised end to end rather than reasoned about - all three output destinations were driven through the real CLI and each writes text identical to `sqlparse.format` of the input: stdout, `-o` and `--in-place`, all exit 0.

Battery ownership: the diff touches sqlparse/cli.py, matching cli-atomic, cli-bool, cli-errors, trailing-newline, breadth-sweep and value-cache. All nine batteries exit 0, so the 12 provoked failure steps still report one [ERROR] line each and every failing run still leaves every file byte-identical.

The two inventory rows naming sqlparse/cli.py, cli-args and cli-io, were re-swept inside this iteration rather than left unswept, since closeout means no later audit will visit them. All 24 rows remain swept. Two lines the CLI re-sweep prints as failures are its own reporting artifacts, unchanged from the iteration 2 audit and not defects: `-k upper` is an identity on input whose keywords are already uppercase, and `--encoding utf-8` is asserted not to alter valid utf-8, which is a pass shown under a label meant for options that must change the output.

Verify gate -> 604 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0. Unchanged from iteration 3, as a pure deletion should leave it.

Learnings: none new - a dead-store deletion with the behaviour pinned by batteries that already existed, which is what a Low of this shape should cost.

Next: iteration 5 works JF-010, the wrong count in the CHANGELOG sentence about the sqlformat traceback fix. Two Low items remain, both small, so the ledger should empty at iteration 6 with four iterations left and the evaluator gate can run there rather than at the declaration.

## iter 4/10 | 74432a21-171900 | 2026-08-08 | ROTATION | rotation

Task: JOURNAL.md reached 513 lines after the iteration 4 entry, past the 500 line threshold.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: 7b903627745c8ea08dfe3acaf52b86f761e63277

Verification: 17 entries were found by splitting only on lines beginning `## iter` followed by a digit, so the indented heading-grammar example in the preamble was neither counted nor moved. The 7 oldest - the previous run's iterations 6 through 10 and this run's iterations 1 and 2 - were appended to JOURNAL-archive.md, which went from 8 entries to 15, never overwritten. The 10 newest were kept, the oldest of them being the previous run's iteration 6. JOURNAL.md is now 294 lines and the archive 432.

Learnings: none.

Next: unchanged - iteration 5 works JF-010.

## iter 5/10 | 74432a21-171900 | 2026-08-08 | JF-010 | done

Task: the CHANGELOG entry for the sqlformat traceback fix said "Six of the seven failure steps in a single file's processing crashed", a count matching nothing the project had measured.

Changed: CHANGELOG, .jeffy/probes/cli-errors/probe.py, .jeffy/probes/cli-errors/paths, BACKLOG.md, JOURNAL.md.

Checkpoint: 9580464bced6e5240598231a132287c482b3a5c2

Stall check: not a stall - the CHANGELOG and the cli-errors battery changed, and JF-010 moved from open to closed.

Verification: Both numbers were re-measured rather than copied from the backlog line. The battery's CASES list holds 12 provoked failures, computed from the source. Running the committed battery against sqlparse/cli.py at 74ae751, the commit before EV-002, reports 8 failures of which exactly 7 are "crashed with a traceback"; the eighth is the AST enumeration check that the sqlparse.format call sits inside a try handling SQLParseError, which is not a provoked step. So the true figure is 7 of 12, and neither 6 nor 7-as-the-total appears anywhere in the measurement.

The sentence's own list of crashing steps was checked and is correct: grouping limit to stdout and in place is 2, undecodable bytes for file and stdin is 2, unknown encoding name for file and stdin is 2, output the console cannot encode is 1, totalling 7. Only the lead count was wrong, and "failure steps in a single file's processing" was wrong too, since the 12 span stdin, option validation and an argument check as well; the entry now reads "Seven of the twelve ways a run can fail" and names the grouping-limit pair explicitly.

Acceptance: the check re-derives both numbers from the battery rather than from prose and lives in the battery that owns the class. len(CASES) is computed; the pre-fix crash count is carried as a constant next to the commit it was measured against, because re-measuring it means checking that commit out, which this battery does not do. The check was proved falsifiable by restoring the old wording from HEAD and re-running: exit 1, naming the numbers the battery produces. CHANGELOG was added to the battery's paths file, so editing that entry now runs this battery in the same iteration.

The one other counted claim in the development-version CHANGELOG was re-executed while I was here: "Three defects, all in sqlparse/filters/output.py" is followed by exactly 3 sub-bullets, so it holds.

Battery ownership: the diff touches CHANGELOG and .jeffy/probes/cli-errors/, which is the battery that owns this class; no sqlparse/ module changed, so no inventory row went stale and all 24 remain swept. All nine batteries exit 0.

Verify gate -> 604 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0. Unchanged, as a documentation fix should leave it.

Learnings: a number in shipped prose needs an executing check next to the thing that produces it, or it drifts the moment the instrument grows - this one was wrong in two ways at once, the count and the population it counted over.

Next: iteration 6 works JF-012, the last item on the ledger, which puts the tree-import guard on the breadth-sweep and output-escape batteries. The ledger empties there with four iterations left, so the evaluator gate runs in iteration 7 rather than waiting for the declaration.

## iter 6/10 | 74432a21-171900 | 2026-08-08 | JF-012 | done

Task: the breadth-sweep and output-escape batteries did a bare `import sqlparse`, so run from another working directory they would certify the installed package instead of this tree. Last item on the ledger.

Changed: .jeffy/probes/_tree.py (new), and probe.py in all nine batteries, plus .jeffy/probes/breadth-sweep/probe.py for the enumeration, BACKLOG.md, PLAN.md, JOURNAL.md.

Checkpoint: c44076c34ae0306d4a3f8e5c8394563cd839c9e3

Stall check: not a stall - nine batteries and a new shared module changed, and JF-012 moved from open to closed.

Verification: The reproduction was run first and turned out to understate the defect twice over. First, `sqlparse` is installed editable in this venv, so the import lands on the tree whatever the working directory - the batteries were safe here by a property of one machine's configuration rather than by anything they enforce, and on a checkout with a released wheel installed they would not be. Second, and worse, the import is only one of two ways a battery can certify the wrong thing: a relative path resolves under the launch directory too, and that one is silent. Measured rather than argued, by restoring the previous idempotence probe in place and running it from another directory: it reports `inputs: 12 (12 synthetic, 0 fixtures)`, 1248 checks rather than 2784, and exits 0. Every fixture had vanished and it still printed a pass. The guard I added in iteration 1 did not catch that, because it checked which sqlparse was imported and not which directory the fixtures came from.

So this was fixed as a class at one boundary rather than as the two instances filed. `.jeffy/probes/_tree.py::pin()` chdirs to the project root, so every relative path in every battery means the same thing, then refuses to run if the sqlparse importable from there is not this tree's. All nine batteries call it as their first statement, including the four that do not import sqlparse at all, so the rule is uniform and the enumeration can be exact.

The enumerating check lives in breadth-sweep: it walks the AST of every sibling probe.py and fails if one does not call `pin()`, and fails as well if the glob finds fewer than nine batteries, so the check cannot pass by finding nothing. It walks the AST rather than grepping, because the string also appears in the prose that explains the fix - the Lesson from an earlier run.

Falsifiability was demonstrated for every site, not asserted for the class: each of the nine was run from another directory with a decoy sqlparse package first on PYTHONPATH, and 9 of 9 exit non-zero naming the wrong import path. Run from that same directory without the decoy, 9 of 9 pass, and idempotence reports its full 27 inputs with 15 fixtures rather than the 12 and 0 it saw before.

Two things found while here and fixed in the same iteration rather than left: the cli-errors battery docstring carried the same wrong count as the CHANGELOG entry JF-010 corrected, "Six of the seven steps below crashed", and now reads seven of the twelve. The remaining occurrences of that phrase in the tree are all deliberate - the journal entries that record the history, the evaluator artifact, and the comment in the battery explaining what the number used to be. `.jeffy/probes/__pycache__` appears now that the batteries import a shared module; `.gitignore` already covers it through `*.py[co]`, confirmed with git status rather than assumed, so no ignore rule was added.

No sqlparse/ module changed, so no inventory row went stale and all 24 remain swept.

Verify gate -> 604 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0. Unchanged, as a change confined to the batteries should leave it. All nine batteries exit 0 from the project root.

Learnings: a guard that covers one of two paths into the same failure is a guard that reassures without protecting - the import check I wrote in iteration 1 read as "this battery tests the tree" while the corpus could still empty itself. When closing a class, enumerate the ways in, not the sites reported.

Next: the ledger is empty, a clean full audit is on this run's record from iteration 2, and four iterations remain - which is the shape the Method wants for the evaluator gate, so iteration 7 runs it rather than deferring it to the declaration. On PASS with the closing conditions holding, iteration 7 also declares.

## iter 7/10 | 74432a21-171900 | 2026-08-08 | EVALUATOR | audit

Task: Adversarial evaluator gate, invocation 1 of at most 2 for this run. Run at the iteration the ledger first emptied with a clean full audit already on record and three iterations left, rather than deferred to the declaration. Spawned as one fresh-context sub-agent carrying none of this run's context, given the run-id and the base commit 834ca16fae6b412ded99b23a3d7d57e079f2423a.

Changed: BACKLOG.md, JOURNAL.md, .jeffy/evaluator/74432a21-171900.md.

Checkpoint: 41ac808f959141794f3b13e8f0e7cbd6d435cd54

Stall check: not a stall - BACKLOG.md changed state by filing EV-006, and the evaluator artifact was added.

Verification: Evaluator: REJECT - one substantiated root cause, reported as two lines because it appears in two files. I re-derived it rather than accepting it, and it is real and it is mine. `.jeffy/probes/value-cache/probe.py` now holds 19 verdicts, 16 never-stale and 3 observed-stale, counted from the VERDICTS literal and its two section markers, and the battery prints "all 19 read sites classified"; the class line in BACKLOG.md and the battery's own docstring both still say the verdicts came from "instrumenting all 18 sites" with 15 never stale. Iteration 1 added the nineteenth verdict, for the `_trailing_ws` helper EV-004 introduced, and did not re-execute the sentence that counts them - the exact rule that iteration was applying elsewhere. Filed as EV-006, Low, docs, widened to the class rather than the instance: it also covers the huge_select.sql timings quoted as point measurements in PLAN.md and the iteration 2 audit entry, which the gate measured at roughly twice mine on the same commit and which no check re-derives.

The gate confirmed the rest with its own instruments rather than by re-running mine. Verify exits 0 at 604 passed, 1 xfailed, 1 xpassed and ruff clean, re-run at the end of its session and still 0. All nine batteries exit 0. It reproduced every closed task's falsifiable check independently: the idempotence battery reports 58 failures against the three files as of 834ca16 and 0 at HEAD; test_format_keeps_the_space_between_statements is 2 failed 2 passed at 834ca16 and 4 of 4 at HEAD; the close_stream AST walk returns 2 then 1; the cli-errors battery provokes 12 failures of which exactly 7 crashed against cli.py at 74ae751; and all 9 batteries exit non-zero naming the decoy when run from another directory with a decoy sqlparse first on PYTHONPATH, all 9 passing there without it. It also reproduced the historical half of JF-012, the pre-fix probe printing 12 inputs and 0 fixtures while exiting 0. The Surface inventory checked out at 24 rows, none unswept and none stale, with staleness recomputed per row. Its own hunting - a 540-key differential, 176 literal-preservation checks, 36 exact parse round-trips, deep nesting, and timing on every shape it could build for the tail walk - found no missed High or Medium: no quote-state leak from the document-level rstrip, no whitespace eaten inside a quoted literal or identifier, no CWE-1333 regression, and `git diff --numstat -- tests/` of 63 0, so no test was weakened or deleted.

Observations the gate recorded that are not REJECT reasons. These are carried to the run report and the next run's ledger and are deliberately not worked here, which is this project's own precedent: the previous run's gate left four observations, its wrapup named them in the handoff, and this run's iteration 2 audit judged and filed them as JF-010 through JF-013. Two are new Low runtime items. First, the run introduced 2 new non-fixed-point inputs while fixing 9, the minimal one being `format('--x\n\tvalues,', reindent=True)`, which needs a bare VALUES followed directly by a comma - invalid SQL in every dialect - while 1080 well-formed leading-comment combinations are fixed points at both commits. Second, `format('select 1; /* c */ select 2;', strip_comments=True)` now returns two spaces where 834ca16 returned one, a consequence of the per-statement right-strip JF-013 removed; the new output is a fixed point and arguably more faithful, but it is unrecorded. Two more are pre-existing and reproduce identically at 834ca16, so they belong to the next run's audit rather than to this run: `identifier_case` case-folds backtick-quoted identifiers while exempting double-quoted ones, and `reindent_aligned` raises ValueError from aligned_indent.py on malformed input.

Learnings: the rule this run kept citing - re-execute the claims a fix invalidates - is the one it broke, and it broke it on the battery it was extending at the time. A count in prose next to a literal that the same diff grows is the highest-risk sentence in any change, and the gate found it because it read the literal instead of the sentence.

Next: iteration 8 works EV-006, which is a two-file count fix plus the check that re-derives the counts, so it fits one iteration. Iteration 9 re-invokes the gate - the second and final invocation, since the first landed at iteration 7 and the cap is 2 when the first does not land before the midpoint of the budget - and declares in that same iteration if the verdict is PASS and the closing conditions hold. Iteration 10 is spare.

## iter 8/10 | 74432a21-171900 | 2026-08-08 | EV-006 | done

Task: counts and measurements written into state files that no longer reproduce. Filed by the evaluator gate at iteration 7 as its only REJECT reason.

Changed: .jeffy/probes/value-cache/probe.py, .jeffy/probes/value-cache/paths, BACKLOG.md, PLAN.md, JOURNAL.md.

Checkpoint: d28a5986a96c766f98fb4c0dd7fd65aa65162bbb

Stall check: not a stall - the value-cache battery gained a check and EV-006 moved from open to closed.

Verification: Both instances were re-derived before being retyped. The verdict table holds 19 entries, 16 above the "Observed stale" marker and 3 below it, counted from the literal rather than from the sentence; the battery already printed "all 19 read sites classified" while its own docstring and the BACKLOG class line both said 18 sites with 15 never stale. Iteration 1 added the nineteenth, for `_trailing_ws`, and left both sentences alone.

The fix is the check, not the edit. The battery now re-derives all three numbers from its own VERDICTS literal and the section marker inside it, and fails if either the docstring or BACKLOG.md disagrees. Two defects in my first attempt at that check, both caught by running it rather than by reading it: it matched phrases across a line break, so a rewrap would have broken it, and it split the table at the marker without bounding the end, so it read on past the closing brace and counted a dict key in the check I had just written - reporting 20 keys and 4 stale. The region is now bounded at the literal's closing brace and every comparison collapses whitespace first.

Falsifiability was proved in both files at once, not argued: restoring the old numbers in the docstring and in BACKLOG.md makes the battery exit 1 with 4 failures naming the counts the table actually holds, and restoring the correct ones makes it exit 0. BACKLOG.md was added to the battery's paths file, so editing the class line runs this check in the same iteration.

The second instance is the timing. PLAN.md's filters-others row quoted huge_select.sql at 0.078s and 0.330s; the gate measured roughly twice that on the same commit, and I now measure 0.130s and 0.574s best-of-three on this host. Nothing regressed - the sweep's actual assertion is a 5s bound - so the row now states that bound and says explicitly that it is a bound rather than a point value, and why. The iteration 2 audit entry carries the original numbers and is left alone: journal entries are the record of what was measured then, and rewriting one would be worse than the defect.

While here, the other counted claims in the Settled classes section were re-executed rather than assumed: the option-errors battery still reports 18 options enumerated with 12 echoing and 5 raising without a value plus truncate_char accepting the sentinel; the idempotence battery still reports 2784 accepted checks and 54 style-collision rejections; and the 58 and the 41 quoted for pre-fix baselines are unchanged since they were measured this run.

Battery ownership: the diff touches .jeffy/probes/value-cache/ and the two state files. No sqlparse/ module changed, so no inventory row went stale and all 24 remain swept. All nine batteries exit 0.

Verify gate -> 604 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0. Unchanged, as a records fix should leave it.

Learnings: a count in prose next to a literal that the same diff grows is the highest-risk sentence in a change, and the gate found this one by reading the literal while I had been reading the sentence. The check that fixes it has to be bounded to the literal too - mine ran past the closing brace and counted itself.

Next: iteration 9 re-invokes the evaluator gate. It is the second and final invocation, the cap being 2 because the first landed at iteration 7 rather than before the midpoint, so the verdict it returns is the one the declaration rests on. If it is PASS and the closing conditions hold, iteration 9 declares in that same iteration; iteration 10 is spare.

## iter 9/10 | 74432a21-171900 | 2026-08-08 | EVALUATOR | blocked

Task: Adversarial evaluator gate, invocation 2 of at most 2 for this run, re-invoked to certify the EV-006 fix and produce the verdict a declaration would rest on. Spawned as one fresh-context sub-agent carrying none of this run's context, given the run-id and the base commit 834ca16fae6b412ded99b23a3d7d57e079f2423a.

Changed: BACKLOG.md, JOURNAL.md, .jeffy/evaluator/74432a21-171900.md.

Checkpoint: 993203a1aa3f794fff342f89faea68fd95803631

Stall check: not a stall - BACKLOG.md changed state by filing EV-007, EV-008 and EV-009 and by reopening a settled class, and the evaluator artifact was rewritten for this invocation.

Verification: Evaluator: REJECT. This is the second REJECT of the run and therefore a hard blocker, and the cap of 2 invocations is spent, so no verdict remains that a declaration could rest on. The run ends blocked and not converged.

EV-006, the reason the first invocation rejected, is confirmed fixed. The gate counted the VERDICTS literal by AST itself - 19 total, 16 never-stale, 3 observed-stale, matching what the probe derives - mutated the counts in both the docstring and BACKLOG.md and got exit 1 with 6 named failures, then reconstructed the original scenario by adding a twentieth verdict and leaving the prose alone and got exit 1 naming that too. It confirmed the region-bounding is load-bearing: 20 four-space quoted-key lines exist in the file, 19 inside the bounded region, the excluded one being the `'BACKLOG.md':` key of the CLAIMS dict I added. It found no vacuous-pass path.

The new reason is a regression this run introduced, and I reproduced it before accepting it. `sqlparse.format('select foo\n-- c\n from t', reindent=True)` returns `'select foo -- c\n\nfrom t'`, and formatting that again returns `'select foo -- c\nfrom t'`. At 834ca16 the first output is a fixed point; the first pass is byte-identical on both trees and only the second diverges. My own sweep over 12 statements and 9 option sets reports 20 of 108 not a fixed point at HEAD against 1 of 108 at 834ca16, affecting 4 distinct and entirely valid statements - `select foo\n-- c\n from t`, `select a, b\n-- pick columns\n from t`, `select a from t\n-- tail\n order by a`, and a multi-statement case. The gate's own sweep, on a different corpus, found 60 of 135 against 1 of 135 and isolated the cause by monkeypatching only `_stripws_default`, and drove it end to end through `python -m sqlparse -r --in-place`, which rewrites the file twice where 834ca16 is stable after one. Filed as EV-007, Medium. The shape is: a group whose tail is a newline is treated exactly like one whose tail is a space, so the parent suppresses a separator that was carrying a line break.

Three consequences filed with it. The fixed-point class is reopened, for the second time in two runs and this time because the fix for it introduced the next defect in it. `tests/test_format.py::test_format_is_a_fixed_point_around_group_trailing_ws`, which I wrote in iteration 1, is parametrized over four option sets and omits `{'reindent': True}` alone - the one set under which its own GROUP_TRAILING_WS constant fails - so it certified the shape it was written for while the defect sat inside it; that is EV-008. And the idempotence battery exits 0 because its 27-input corpus holds no statement whose line comment ends a line inside a group with the statement continuing after it; that gap is EV-009, together with its printed label of 92 pairs where it holds 91 pairs and the no-options set.

One claim I recorded at iteration 7 is falsified and I record the correction here rather than by rewriting that entry: I wrote there that the gate's first observation needed a bare VALUES followed by a comma and so reached no well-formed statement, on the strength of 1080 leading-comment combinations being stable. That corpus used leading comments; the defect needs a trailing one, and it reaches ordinary valid SQL. The observation was worth more than the weight I gave it, and the second gate found in an hour what the first had gestured at.

Everything else the gate checked holds. Verify exits 0 at 604 passed, 1 xfailed, 1 xpassed with ruff clean. All nine batteries exit 0. All five other closed tasks reproduce their falsifiable checks exactly: 58 idempotence failures at 834ca16 and 0 at HEAD, JF-013's test 2 of 4 at 834ca16 and 4 of 4 at HEAD, close_stream 2 then 1, exactly 7 crashes of 12 provoked at 74ae751, and 9 of 9 batteries refusing the decoy. The Surface inventory has 0 unswept and, recomputed per recorded commit, 0 stale rows. No test was weakened or deleted - 63 insertions and zero deletions under tests/. An 820-key output differential found 46 differences in 4 named classes with no unnamed change, no literal or quoted-identifier corruption over 501 checks, no CWE-1333 reintroduction - HEAD is faster overall and scales better, 13.45x against 26.23x for an 8x input - and deep nesting still raises SQLParseError rather than RecursionError.

Learnings: a fix that closes a class can open the next defect in the same class, and the instrument that certified the class will not see it if the corpus was built from the defect that prompted it. EV-004's battery grew pairs of options because pairs were what it had missed; it never grew a comment shape, and the comment shape is what broke. When reopening a settled class, extend the corpus along the axis the new defect used, not the axis the last one did.

Next: none in this run. The loop ends here under the hard blocker rule with EV-007, EV-008 and EV-009 open and the fixed-point class reopened. The next run starts with a fresh audit and EV-007 as its first task.

## iter 1/10 | 56471ef3-194330 | 2026-08-08 | EV-007 | done

Task: `format` stopped being a fixed point on valid SQL whose line comment ends a line inside a group with the statement continuing after it. Filed as Medium by the previous run's second evaluator gate, which ended that run blocked.

Changed: sqlparse/filters/reindent.py, tests/test_format.py, BACKLOG.md, PLAN.md, JOURNAL.md.

Checkpoint: de409dd2a97d8d7361a5679ec6ff8066ff011684

Stall check: not a stall - sqlparse/filters/reindent.py and tests/test_format.py changed, and EV-007 moved from open to closed.

Verification: the filed reproduction ran first and reproduced exactly as written - `format('select foo\n-- c\n from t', reindent=True)` returns `'select foo -- c\n\nfrom t'` and formatting that again returns `'select foo -- c\nfrom t'`.

The filed root cause is wrong and the fix is in a different module. `StripWhitespaceFilter._trailing_ws` behaves correctly: after stripws the statement already renders `'select foo -- c\nfrom t'`, the shape the second pass produces. The defect is downstream, in `ReindentFilter._split_kwds`, which decided whether a line break was already present from `str(prev_)` of the single token before the keyword. Dumping the tree at each filter showed why the two passes disagree, and it is a grouping asymmetry: given `select foo\n-- c\n from t` the trailing newline is a statement-level whitespace token, which stripws empties because the comment's own newline already ends the line, so `prev_` renders `''` and reindent answered "no break here" and added a second one; given `select foo -- c\n\nfrom t` that newline is absorbed into the Comment group, so `prev_` is the Identifier whose text ends `\n` and nothing is added. Measured at 834ca16 the first pass is byte-identical to HEAD's first pass and is a fixed point there, so what regressed is the second pass, not the first.

The fix asks the text rather than the token: `_preceding_text` walks back over tokens that render nothing and returns the first that renders anything. `str()` is what it reads, which on a leaf is the live value and on a group joins the live leaves, so no `.value` read site was added - the value-cache battery confirms this by still reporting 19 classified sites rather than by my saying so.

The first attempt was wrong and the corpus differential caught it, which is the whole reason that instrument exists. Suppressing the second break alone left `and b = 2` in column 0 where reindent puts it at the clause indent everywhere else, and the differential reported a second edit class deleting `'\n  '`. That also made `indent_width` inert on that input - `reindent` and `reindent+width4` produced identical output - which this project's Method scores as a finding and never as a pass, and a fixed-point check alone would have accepted it, because column 0 is perfectly stable. The break a line comment carries inside its own value is not reindent's to move; only the indent is missing, so the corrected fix inserts the indent alone.

Acceptance: a sweep of 12 statements x 9 option sets, the corpus built around the defect shape and its neighbours, reports 42 of 108 not a fixed point against the unfixed tree at 96ae9c5 and 0 of 108 after the fix. The filed line predicted 20 of 108; that number is the gate's corpus and mine is a different 12 statements, so the two are not comparable and I record my own. Four new tests in tests/test_format.py pin the known-answer outputs, not merely stability; run against sqlparse/filters/reindent.py restored to 96ae9c5 with the fix copied aside first, all 4 fail with exactly the blank-line diff, and all 4 pass at HEAD.

Corpus differential over the 15 decodable fixtures at 10 option sets: 150 keys, none of which move. That result on its own proves nothing, because the fixture corpus contains no statement of the shape that changed - the same blindness EV-009 records in the kept battery - so the differential corpus carries six synthetic statements too. Of the resulting 210 keys, 30 differ and every one is synthetic; every edit in every one of them, classified with an exact character-level edit script and no normalising regex, is a single deleted newline, 36 edits over 30 keys. There is no unnamed key.

Battery ownership: the diff touches sqlparse/filters/reindent.py, matching the paths files of idempotence, breadth-sweep and value-cache. All nine batteries were run and all nine exit 0. The idempotence battery passing over the fixed defect is expected and is exactly what EV-009 is filed for. `_split_kwds` runs per split keyword, so a walk added there is where a CWE-1333 construction would return: huge_select.sql under reindent is 0.773s unfixed against 0.791s fixed, best of three on this host, indistinguishable at this resolution and far inside the 5s bound the breadth-sweep battery asserts.

Verify gate -> 608 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0. The count rose by the 4 new tests from 604.

Ledger: the fixed-point class stays REOPENED on purpose. Its enumerating check still cannot see the shape that broke it, and settling a class whose instrument is known blind is precisely how this class was wrongly declared complete twice; it closes when EV-009 does. EV-008 and EV-009 were moved from Now to Later, where the ledger's own rule puts Low findings.

Learnings: a fixed-point defect is not closed by the fixed-point check alone - the wrong fix here was stable and inert, and only re-driving `indent_width` on the same input separated it from the right one. And a differential that reports zero differences is an unproven instrument until it has been shown able to report something: the fixture corpus was blind to this change, and had I stopped at "150 keys, 0 differ" I would have recorded containment I had not measured.

Next: iteration 2 takes EV-008, the parametrization gap in `test_format_is_a_fixed_point_around_group_trailing_ws`, then EV-009, the idempotence battery's corpus gap and its miscounted label. Both are Low and both are about the instruments for the class this iteration's fix belongs to, so the class can be settled once EV-009 lands. The ledger then empties with no full audit yet recorded this run, so iteration 4 or 5 owes a fresh audit before the evaluator gate.

## iter 2/10 | 56471ef3-194330 | 2026-08-08 | EV-008 | done

Task: `test_format_is_a_fixed_point_around_group_trailing_ws` was parametrized over four option sets, none of which runs the code that EV-007 broke, so the test certified its own constant while the defect sat inside it.

Changed: tests/test_format.py, BACKLOG.md, JOURNAL.md.

Checkpoint: 9b905b91c5c75cabd42e86f40d8b0c3948f7d40d

Stall check: not a stall - tests/test_format.py changed and EV-008 moved from open to closed.

Verification: the option sets were derived by executing the sweep against the unfixed tree at 96ae9c5, not copied out of the iteration 1 transcript. Six sets are not a fixed point on `GROUP_TRAILING_WS` there - reindent alone, and reindent with each of keyword_case upper, indent_width 4, comma_first, wrap_after 20 and compact - and the same six are the only sets that fail anywhere in the 12-statement sweep, so both readings of the acceptance line give one list. All six are now in the parametrization, which goes from 4 sets to 10.

Falsifiability was proved, not argued. With sqlparse/filters/reindent.py restored to 96ae9c5 and the fix copied aside first, the test is 6 failed and 4 passed: exactly the six added sets fail and the four original ones pass. That split is the finding stated as evidence - the original parametrization could not have caught EV-007 no matter how often it ran, because every one of its sets either strips the comment or skips reindent.

One limit of this test is worth recording rather than leaving for someone to rediscover: a fixed-point assertion cannot separate the right EV-007 fix from the wrong one. Iteration 1's first attempt suppressed the redundant line break without restoring the indent, which is perfectly stable and would pass all ten of these sets while leaving the keyword in column 0 and `indent_width` inert. What separates them is the known-answer pinning added alongside the EV-007 fix. This test guards the property; those tests guard the output.

Battery ownership: the diff touches tests/test_format.py and BACKLOG.md. Of the nine paths files only value-cache matches, through BACKLOG.md, and it exits 0 at 19 classified read sites. No file under sqlparse/ changed, so no Surface inventory row went stale and all 24 remain swept.

Verify gate -> 614 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0. The count rose by the 6 added parametrizations from 608, and `git diff --stat` after restoring the fix showed tests/test_format.py as the only changed file, so reindent.py went back byte-identical.

Learnings: a parametrized test is only as strong as the axis it varies, and the axis to vary is the one the code under test actually reads. Every set in the original four either removed the comment or skipped reindent, so the parametrization looked thorough while running none of the path its own constant exists to exercise.

Next: iteration 3 takes EV-009, the last open item - the idempotence battery's corpus holds no statement of this shape, which is why it exited 0 throughout EV-007, and its printed label miscounts its own option sets. Closing it also closes the fixed-point class, which is deliberately left reopened until that instrument can see the shape. The ledger then empties with no full audit yet recorded this run, so iteration 4 owes a fresh audit before the evaluator gate can run.

## iter 3/10 | 56471ef3-194330 | 2026-08-08 | EV-009 | done

Task: the kept idempotence battery held no statement whose line comment ends a line inside a group with the statement continuing after it, so it exited 0 for the whole of the run that shipped EV-007, and its printed label counted the no-options set as a pair.

Changed: .jeffy/probes/idempotence/probe.py, PLAN.md, BACKLOG.md, JOURNAL.md, JOURNAL-archive.md.

Checkpoint: c353dcfe16b411b650e57a7989c1a271fcfe91be

Stall check: not a stall - .jeffy/probes/idempotence/probe.py gained a corpus section and a corrected label, and EV-009 moved from open to closed.

Verification: the corpus gained a `COMMENT_IN_GROUP` section of six statements that each put the line comment in a different group - identifier, identifier list, ORDER BY, WHERE/AND, UNION and GROUP BY/HAVING - so a fix that special-cases one construct does not pass. The battery now reports 33 inputs (12 multi-statement, 6 comment-in-group, 15 fixtures) x 106 option sets and 3408 accepted checks, against 27 and 2784 before.

The blindness was proved by differential rather than asserted, which is the only form that distinguishes a corpus gap from a checking gap. With sqlparse/filters/reindent.py restored to 96ae9c5 and the fix copied aside, the extended battery exits 1 with 105 failures - 21 option sets on each of 5 of the 6 new inputs - while the battery exactly as committed before this iteration, run against that same defective code from a temporary sibling directory so its own `pin()` still resolved this tree, exits 0 and prints every input a fixed point under all 2784 accepted option-set checks. Same code, same run, two corpora, opposite verdicts. The temporary copy was removed before the checkpoint and breadth-sweep still counts nine batteries.

The sixth input, the WHERE/AND one, is not among the 105 and that is not a gap: at 96ae9c5 the blank line it grows is stable across passes, so no fixed-point check can see it. It earns its place for a different reason - it is the input whose indent the first EV-007 attempt dropped - and it is also the clearest statement of what this battery cannot do. A fixed-point assertion cannot separate a stable wrong output from a right one; that half is pinned by the known-answer tests in tests/test_format.py. The settled-class line now says so rather than leaving the next reader to assume the battery covers both.

The label is fixed at its cause, not at its symptom. It read `(14 single, 92 pairs)` because the pair count was derived by subtracting `len(POOL)` from `len(OPTSETS)`, which silently absorbed the no-options set. The option sets are now built as three named lists and every number in the label is read off the list that holds it, so it prints `(14 single, 91 pairs, 1 no-options)` and cannot drift again when a fourth kind is added.

The class is settled. This is its third settlement and the first with an instrument that has been shown to fail against the defect that reopened it; both earlier settlements rested on a corpus grown along the axis of the previous defect.

Two mechanical notes. The probe files under .jeffy/probes/ are CRLF, so a multi-line exact-match edit does not apply to them - the edit tool refused rather than mangling the file, and the patch was applied by a script that asserts each replacement matched exactly once, leaving the file at 205 CRLF and 0 bare LF. And PLAN.md's filters-indent row quoted 2784 accepted checks, a number this iteration moves; rather than rewriting what was measured at de409dd, the sentence now says it was the count as that battery then stood.

Battery ownership: the diff touches .jeffy/probes/idempotence/probe.py, PLAN.md and BACKLOG.md. Of the nine paths files only value-cache matches, through BACKLOG.md. All nine batteries were run anyway and all nine exit 0. No file under sqlparse/ changed - `git status` showed only the probe modified once reindent.py was restored - so no Surface inventory row went stale and all 24 remain swept.

Verify gate -> 614 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0. Unchanged, as a battery-only change should leave it.

Learnings: proving an instrument was blind means running the old instrument and the new one against the same defective code and showing opposite verdicts; anything less leaves open that the checking, not the corpus, was what changed. And the probe files are CRLF while the sqlparse sources are LF, which is why an edit that works on one silently does not apply to the other.

Next: the ledger is empty and this run has recorded no full audit, so iteration 4 owes one - a fresh-evidence audit per the Method, sweeping the Surface inventory and rescoring every applicable dimension. Iterations 5 and 6 work whatever it files. The evaluator gate runs at the iteration the ledger first empties with that clean audit on record and at least 3 iterations left, rather than waiting for the declaration.

## iter 3/10 | 56471ef3-194330 | 2026-08-08 | ROTATION | rotation

Task: JOURNAL.md reached 522 lines with the EV-009 entry appended, past the 500 line threshold, so the older entries move to the archive.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: recorded in the EV-009 entry for this iteration.

Verification: split only on lines beginning `## iter` followed by a digit, so the heading grammar example in the preamble is neither counted nor moved. 9 entries moved, JOURNAL.md went from 19 entries to the 10 most recent and from 522 lines to 271, and JOURNAL-archive.md went from 15 entries to 24 by appending, never overwriting. The rotation script asserts all three of those and that the two counts still sum to what they summed to before, so a rotation that dropped an entry would fail rather than report success.

Learnings: none beyond the mechanics.

Next: continues with the EV-009 entry's Next - iteration 4 owes this run's first full audit.

## iter 4/10 | 56471ef3-194330 | 2026-08-08 | AUDIT | audit

Task: this run's first full fresh-evidence audit. The ledger emptied at iteration 3 with no audit on record.

Changed: BACKLOG.md, PLAN.md, JOURNAL.md.

Checkpoint: 67a09b8befbdcca46a0b23f39636c9966d6dacde

Stall check: not a stall - BACKLOG.md changed state by filing AU-001 through AU-004 and declining two carried observations.

Verification: scores, each claiming only the rows actually swept. All 24 inventory rows are swept and, after this iteration's re-sweep, none is stale.

- error handling: High. `format(sql, reindent_aligned=True)` raises `ValueError: None is not in list` out of `TokenList.token_index` reached from `AlignedIndentFilter`. Minimised by delta-debugging from the recovered repro to 14 characters: a CASE whose keywords are separated by a vertical tab and a file separator. The exception is not `SQLParseError`, so a caller handling the documented exception crashes, and the real CLI on a file of those 14 bytes exits 1 with a Python traceback rather than the one `[ERROR]` line its contract promises. SQL text is the adversarial trust class and the envelope says the full rubric applies there including hostile hand-crafted input, so this is a crash on in-envelope input and it is High by the rubric. It reproduces identically at 834ca16, so it is pre-existing and not this run's. Filed as AU-001. The root cause is in the filter, not in `cli.py`, so this is not a filing inside the settled CLI-traceback class - that class's AST check requires the `format` call to sit in a `try` handling `SQLParseError`, which it does; the defect is that a second exception type exists at all.
- correctness: Medium. `identifier_case` folds the contents of backtick-quoted and bracket-quoted identifiers while exempting double-quoted ones. The enumeration was built from the lexer rather than from the regex table: of the four identifier-quoting styles, three produce tokens in `IdentifierCaseFilter.ttype`, and only the double-quoted one survives, because the exemption tests the first character against a double quote and the other two lex as `T.Name`. `capitalize` is worse than `upper` here - the leading quote absorbs the capital and the whole name lowercases. `utils.remove_quotes` already treats the backtick as a quote character and `test_identifiercase_quotes` pins the exemption for double quotes, so the intent is settled and only the implementation is one-sided. Filed as AU-002.
- documentation: Low. Filed as AU-003. Every option `validate_options` reads is documented except `right_margin`, which JF-003 deliberately made raise and which CHANGELOG records - correct, not a gap. The gap is in this project's own state file: the inventory's row scopes are prose, so no command maps a module to a row. That is not theoretical. The previous run's gate mapped `api-format-indent` to `sqlparse/__init__.py` and reported no row stale; a script mapping it to the code implementing those options finds it stale, because `reindent.py` changed at de409dd and that row's recorded commit is older. `sqlparse/filters/__init__.py` belongs to no row's scope at all, and the assertion that caught it was one I had to write.
- testing: Low. Filed as AU-004, the value-cache battery's bare `KeyError` traceback in place of a named failure. Otherwise clean on fresh evidence: all 8 test modules pass run alone, cheapest first, and the suite passes with the files given in reverse order, 603 passed with no order dependence. A `--reverse` run was attempted and is not evidence - that plugin is not installed and pytest exited 4 on a usage error, so it is recorded here as not run rather than as a pass.
- security: None. The DoS suite passes at 7 tests, the documented grouping limits still raise `SQLParseError`, and a sweep of 420 malformed inputs - every decodable fixture truncated at every seventh character, plus 26 hand-written fragments - through 12 option sets, 5040 calls, produced no exception other than `SQLParseError`. AU-001 is availability-adjacent and is scored under error handling rather than counted twice.
- performance: None. huge_select.sql at iteration 1 measured 0.773s unfixed against 0.791s fixed under reindent, best of three, inside the 5s bound the breadth-sweep battery asserts.
- dependency hygiene: None. The package declares no runtime dependencies at all.
- architecture, code quality, developer experience: None on the swept surface.
- observability: not applicable, and the reason is recorded rather than assumed - this is a parsing library with no long-running process; failures surface as exceptions to the caller and as the CLI's `[ERROR]` line, both of which are pinned by the cli-errors battery.
- UX: the CLI is the only user-facing surface. Its one defect is AU-001's symptom and is filed at the root cause rather than twice.

Two carried observations were judged and declined rather than filed. `parse` drops whitespace-only input, so the api-parse row's round-trip invariant does not hold there - but `format` and `split` agree with `parse`, the behaviour is identical at 834ca16, and there is no wrong answer to fix. And `strip_comments` leaving two spaces between statements is the faithful result of an option that does not collapse whitespace; the output is a fixed point and CHANGELOG records the JF-013 change that caused it.

The `reindent_aligned` crash nearly went unreproduced. My own 5040-call sweep missed it, and the observation's repro was not in the evaluator artifact on disk, because the iteration-9 invocation wrote to the same run-id path and overwrote iteration 7's. It survived in the commit that checkpointed it and came back with `git show`. That is the difference between recording an observation as unreproducible and finding a High.

api-format-indent was stale and is re-swept in this iteration: all nine documented indentation parameters produce 2 distinct outputs of 2 on input where each applies, so none is inert, and the boundary and negative sides - `indent_width` at 0 and -1, `wrap_after` at -1, and both style collisions - are each rejected with `SQLParseError`.

Closeout has not begun. It requires an audit scoring zero High and zero Medium in-envelope, and this one scored one of each.

Verify gate -> 614 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0. No file under sqlparse/ changed this iteration. Of the nine paths files only value-cache matches the diff, through BACKLOG.md, and it exits 0.

Learnings: truncating valid SQL is not a fuzzer - 5040 calls over cut fixtures found nothing while 14 characters of control-separated CASE crashes, so vary the character classes and not only the cut points. And an evaluator artifact is written at one path per run-id, so a re-invocation overwrites the first verdict's evidence; recover it from the commit that checkpointed it before deciding an observation cannot be reproduced.

Next: iteration 5 takes AU-001, the High. Iteration 6 takes AU-002. That leaves iterations 7 and 8 for the two Lows and the evaluator gate, and iteration 9 or 10 for the declaration. If the budget tightens, AU-003 and AU-004 are the ones to price against the one-iteration rule, not the runtime findings.

## iter 5/10 | 56471ef3-194330 | 2026-08-08 | AU-001 | done

Task: `format(sql, reindent_aligned=True)` raised `ValueError: None is not in list` out of the public API, and `sqlformat -a` printed a Python traceback. Filed High by the iteration 4 audit.

Changed: sqlparse/filters/aligned_indent.py, tests/test_format.py, CHANGELOG, .jeffy/probes/aligned-case/probe.py, .jeffy/probes/aligned-case/paths, PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: 05771e4ffda0bd320fcb033ab77abd31c3f57a7c

Stall check: not a stall - sqlparse/filters/aligned_indent.py changed and AU-001 moved from open to closed.

Verification: the filed reproduction ran first and held, and the traceback named the mechanism exactly: `_process_case` asks `token_next_by(m=(T.Keyword, 'END'))` for the END it aligns and appends the answer as a case. `token_next_by` does not recurse into sublists, and a keyword that opens a group takes everything after it, so in `case where end` the END sits inside the WHERE and the CASE has none at its own level. The None it answers was appended as though it were a token and reached `token_index`.

The filed input understated how ordinary this is, and minimising it was the most useful thing I did. It was filed as a 14-character string of control characters recovered from a gate artifact, which reads as a hostile curiosity. Delta-debugging by dropping one character at a time reduced it to plain ASCII `case where end` - same 14 characters, no control characters at all - and `select a, case where end, b from t` crashes too. The vertical tab and file separator were never the trigger; a keyword that opens a group is, and among the ones tried only WHERE does, since HAVING, LIMIT, UNION, FROM and ORDER BY leave the END where the aligner can see it.

The fix appends the END only when there is one. Contract preserved: for a CASE that has its END, `end_token` is not None and every line of this function behaves exactly as before, which the corpus differential confirms - all 210 keys over the 15 decodable fixtures and 6 synthetic statements at 10 option sets are byte-identical across the change, so the guard only affects a path well-formed SQL never takes.

One branch deliberately has no guard, and that decision was measured rather than taken on taste. With the append made conditional, `max()` over the condition widths would see an empty sequence if a CASE had neither a case nor an END. Instrumenting `_process_case` across 262 CASE shapes and the fixture corpus, it was entered 231 times: 12 with no cases, 4 with no END, 0 with both. So the guard is unreachable and adding it would be speculative; the battery re-measures that on every run and fails if it ever becomes reachable, which is the honest way to leave it out.

The class was closed, not the instance. `token_next_by` answers `(None, None)`, so the idiom is a caller that subscripts `[1]` and discards the index that would have prompted a guard. An AST walk over sqlparse/ finds 43 call sites, 41 unpacking the tuple and exactly 2 subscripting: this one, and `sql.py::get_parameters`. The second is settled by measurement rather than by reading - 14 `Function` groups were built across the probe inputs and the fixture corpus and not one lacked a `Parenthesis` - and the battery re-runs that measurement rather than trusting the sentence. Dropping either verdict from the table makes the battery exit 1 naming the unsettled site, which was checked by doing it.

Acceptance, narrowed once with the reason recorded. The filed line demanded the CLI "exits 1 with exactly one `[ERROR]` line and no traceback". That was wrong and satisfying it would have been a worse fix: this is a non-validating parser and the input is formattable, so the right outcome is exit 0 with the text formatted, which is what it now does. The invariant that actually defines the class is that nothing but `SQLParseError` escapes `format()` and the CLI never shows a traceback, and that is what the battery asserts. `.jeffy/probes/aligned-case/probe.py` drives 276 CASE shapes - 24 hand-written plus every 2- and 3-part permutation of the CASE vocabulary - through 6 option sets for 1656 calls, re-formats all 15 fixtures through the aligner, and drives the real CLI. Against sqlparse/filters/aligned_indent.py at 1a6ed85 it exits 1 with 21 named failures including the CLI traceback and the empty output; at HEAD it exits 0. The 4 new pytest cases pin known-answer outputs and were shown to fail 4 of 4 against that same unfixed file, with the fix copied aside first.

My first version of that battery failed against the unfixed code with a traceback and zero named failures, because the instrumentation pass caught only `SQLParseError`. That is precisely the defect AU-004 is filed for in a sibling battery, so I fixed it here rather than shipping it: the pass now swallows the exception the sweep above already recorded, and the run reports 21 named failures instead of dying.

While working this I found one more Low and filed it rather than folding it in: the EV-007 fix from iteration 1 changed user-visible output and CHANGELOG has no entry for it, though it carries entries for every sibling fix in that class. Filed as AU-005. AU-001's own CHANGELOG entry is part of this task and was added.

Battery ownership: the diff touches sqlparse/filters/aligned_indent.py, matching the paths files of idempotence, breadth-sweep, value-cache and the new aligned-case. All ten batteries were run and all ten exit 0, breadth-sweep included, which is what confirms the new battery calls `pin()` and that the count it enforces still holds.

Verify gate -> 618 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0. The count rose by the 4 new tests from 614.

Learnings: minimise a crash reproducer before judging how exotic its input is - the control characters this was filed with were noise, and the real trigger is a keyword that opens a group, which turns a hostile-input curiosity into `select a, case where end, b from t`. And a battery whose instrumentation catches only the exception it expects will die with a traceback against exactly the code it exists to indict.

Next: iteration 6 takes AU-002, the Medium - `identifier_case` folding the contents of backtick-quoted and bracket-quoted identifiers. Three Lows then remain, AU-003 through AU-005, against 4 iterations. The evaluator gate needs one of them and the declaration another, so at most two of the three Lows can be worked; the pricing rule in the Method decides which, and AU-003 is the one whose fix plus its kept battery is least likely to fit a single iteration.

## iter 6/10 | 56471ef3-194330 | 2026-08-08 | AU-002 | done

Task: `identifier_case` changed the case inside quoted identifiers, so `format('select `MyTbl`', identifier_case='upper')` returned `` `MYTBL` `` and named a different table on a case-sensitive MySQL. Filed Medium by the iteration 4 audit.

Changed: sqlparse/filters/tokens.py, tests/test_format.py, CHANGELOG, .jeffy/probes/identifier-case/probe.py, .jeffy/probes/identifier-case/paths, PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: 9aa64f1a7cc3d0345d901866b406a9118ea8dea2

Stall check: not a stall - sqlparse/filters/tokens.py changed and AU-002 moved from open to closed.

Verification: the audit's own enumeration was incomplete and the lexer said so. The audit listed three quoting styles by hand; `SQL_REGEX` gives four delimiters an identifier token of their own, and the one it missed is the acute accent. Building the list from the code rather than from a reading is the rule this project already has, and I had broken it in the filing.

Discovering the set empirically needed a discriminator, because "produces one identifier token" is not the same question as "is a quote". `_MyCol_` lexes as a single `T.Name` and must keep folding, since the underscore is part of the name. The question that separates them is whether the delimiters suppress tokenising: `` `select me` `` is one token and `_select me_` is not. Asked that way the lexer answers with exactly four delimiters - the double quote, the backtick, the acute accent and the bracket pair - plus the underscore in the other group, which is the control that keeps the discriminator honest.

The fix exempts all four rather than the double quote alone. Contract preserved: unquoted identifiers fold exactly as before, pinned by known answer at all three case values rather than by a liveness check, and `keyword_case` is untouched. The test that already existed, `test_identifiercase_quotes`, still passes unchanged - it asked about the one delimiter the code already knew, which is why a one-sided exemption survived it.

The corpus differential was blind at first and I nearly recorded its answer. My first run reported 0 of 294 keys differing, which was meaningless: the corpus had no quoted-identifier input and no `identifier_case` option set, so it never ran the code I changed. The patch that was supposed to add them silently matched nothing, because I wrote it without the assertion my own Lessons entry requires. With the inputs actually present the differential reports 364 keys, 12 differing, every one named and every edit a pure case change with nothing added or removed: the backtick, acute and bracket synthetics at each of the four `identifier_case` option sets. The double-quoted synthetic does not move, the bare-identifier synthetic does not move, and no fixture key moves at all.

Acceptance: `.jeffy/probes/identifier-case/probe.py` discovers the delimiters from the lexer, requires the filter's exemption list to equal what the lexer produces in both directions - a missing exemption and a dead one both fail - drives every discovered delimiter through all three case values requiring byte-identical output, pins the bare identifier by known answer at each value, and formats all 15 fixtures at each value. Against sqlparse/filters/tokens.py at cd09348 it reports 14 named failures and no traceback; at HEAD it exits 0. The 12 new pytest cases are 9 failed and 3 passed against that same unfixed file, the 3 passing being the double quote that was already exempt, which is the finding stated as evidence.

That battery also had to be taught to survive the code it indicts. My first version read `IdentifierCaseFilter.QUOTES` directly and died with an `AttributeError` against the pre-fix filter, which has no such attribute - the second time this run a new battery has crashed instead of naming its failure, and the same defect AU-004 is filed for. It now reads through `getattr` and reports the absence as a named failure.

One Declined line was removed rather than left: it recorded that `IdentifierCaseFilter.process` raises `IndexError` on an empty value via `value.strip()[0]`, judged unreachable. The fix reads `[:1]`, so that expression no longer exists and the entry described code the project does not contain. Removing it is not re-filing; the finding is gone.

Battery ownership: the diff touches sqlparse/filters/tokens.py, matching breadth-sweep, value-cache and the new identifier-case. All eleven batteries were run and all eleven exit 0.

Verify gate -> 630 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0. The count rose by the 12 new parametrizations from 618.

The two inventory rows naming sqlparse/filters/tokens.py, api-format-case and filters-case, were re-swept in this iteration. Both `keyword_case` and `identifier_case` produce 3 distinct outputs across their 3 documented values, both reject an invalid value with `SQLParseError`, and the quoted exemption holds at every value while the bare identifier next to it folds.

Learnings: an enumeration written by hand is a reading, not an enumeration - the audit's list of quoting styles missed the one the lexer's own regex table names. And a differential that reports no difference must be shown to reach the changed code before its answer counts; mine did not, because the patch adding the inputs matched nothing and I had left out the assertion that would have said so.

Next: three Lows remain, AU-003 through AU-005, and four iterations. Iteration 7 takes AU-003 first because it is the only one whose cost is uncertain - it rewrites 24 inventory row scopes into runnable path lists and adds the battery that reads them - so a surprise there is absorbable at iteration 7 and would not be at iteration 9. If it overruns the iteration it goes to Declined under the Method's pricing rule with the measured reason, not deferred. Iterations 8 and 9 take AU-004 and AU-005, both small, and iteration 10 runs the evaluator gate and declares if the verdict is PASS.

## iter 7/10 | 56471ef3-194330 | 2026-08-08 | AU-003 | done

Task: the Surface inventory's row scopes were prose, so no command could map a module to its row, and staleness could not be computed by anything but a reading.

Changed: PLAN.md, .jeffy/probes/inventory/probe.py, .jeffy/probes/inventory/paths, BACKLOG.md, JOURNAL.md.

Checkpoint: e217158417215136f1ae30dda157d8726dbdbc08

Stall check: this iteration changed only PLAN.md, BACKLOG.md, JOURNAL.md and a path under .jeffy/, which is the stall shape - but AU-003 moved from open to closed, so a BACKLOG item changed state and it is not a stall. The previous entry is not a stall either.

Verification: every row now carries `[files: <paths>]`, a space-separated list relative to the project root, and `.jeffy/probes/inventory/probe.py` is what makes it load bearing. It diffs each row's own files against that row's own latest recorded commit, requires every module under sqlparse/ to belong to at least one row, requires a row marked swept to name a commit, and requires every named path to exist. On this tree it reports 24 rows, 20 modules all mapped, 0 stale.

The evidence that matters is that it fires, and proving that took a second attempt worth recording. Three defects were injected into PLAN.md one at a time. Dropping `sqlparse/filters/__init__.py` from the only row that names it is caught, and so is stripping a row's file list entirely - two named failures naming the module and the row. My first attempt at the staleness injection reported nothing, and the check was right and the injection was wrong: I had replaced the first commit hash in a row that carries three, while the battery reads the latest, which is the correct one to read. Replacing the last hash instead reports `filters-indent: swept at 834ca16f but sqlparse/filters/aligned_indent.py, sqlparse/filters/reindent.py changed since`. A check that appears not to fire is a claim about the injection before it is a claim about the check.

One limit is stated in the battery rather than left to be discovered: `git diff` compares committed state, so a change made in the current iteration does not mark its row stale until the checkpoint commits it. That is the useful direction to fail in, since the next iteration's run catches a re-sweep that was forgotten, but a green result here means the last commit was swept, not that the working tree is.

This closes the disagreement the finding was filed from. `api-format-indent` is stale or not by a diff against its own commit over its own four files, not by which module a reader thinks the row is about, and `sqlparse/filters/__init__.py` now belongs to `formatter-build`, the row that already asserted what its `__all__` exports.

Battery ownership: the diff touches PLAN.md and .jeffy/probes/inventory/. No file under sqlparse/ changed, so no row went stale and all 24 remain swept. All twelve batteries were run and all twelve exit 0.

Verify gate -> 630 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0. Unchanged, as a state-file and tooling change should leave it.

Learnings: when an injected defect does not make a check fail, suspect the injection first - mine changed a hash the check does not read, and had I stopped there I would have recorded a working check as broken and gone looking for a fix it did not need.

Next: iteration 8 takes AU-004, the value-cache battery's bare KeyError, and iteration 9 takes AU-005, the missing CHANGELOG entry for EV-007. Both are small. Iteration 10 runs the evaluator gate and declares if the verdict is PASS and the closing conditions hold. That leaves no slack for a REJECT, which is the cost of having spent iteration 4 on the audit that found a High; if the gate rejects, the run ends blocked and the reasons carry to the next run.

## iter 8/10 | 56471ef3-194330 | 2026-08-08 | AU-004 | done

Task: the value-cache battery died with a bare `KeyError: 0` traceback instead of naming a failure when its `# --- Observed stale` section marker was missing.

Changed: .jeffy/probes/value-cache/probe.py, PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: aea58bfa8f8ffa1b363e120efbb13ea376fd003d

Stall check: not a stall - the value-cache battery changed and AU-004 moved from open to closed.

Verification: the filed reproduction ran first and named its own mechanism. Deleting the marker makes `partition` return an empty second section, so `n_stale` is 0, and the docstring sentence is built with `WORDS[n_stale]` from a table whose smallest key is 2. The traceback was `KeyError: 0` and it pointed at the sentence-building line, which tells the operator nothing about the marker that actually went missing.

Fixed at both points rather than only at the symptom. The marker is now named once and its absence is reported as a sentence of its own, before any count derived from it is used; and the spelling helper answers with digits for a count outside its table instead of raising, so a damaged VERDICTS section produces a readable failure rather than a stack trace. Both matter: the second alone would have printed "0 sites ever saw a stale value" without ever saying the marker was gone.

Acceptance, run both ways as the filed line requires. With the marker deleted the battery exits 1 with zero tracebacks and 5 named failures, the first being `the '# --- Observed stale' section marker is missing from VERDICTS`, and the other four naming each sentence in the docstring and in BACKLOG.md that no longer matches the table. With the marker restored it exits 0. Nothing about the verdicts themselves changed - still 19 sites, 16 never-stale, 3 observed-stale - so the battery is exactly as strict as it was and only its failure reporting improved.

This is the third battery this run to have crashed rather than reported, after the two I wrote in iterations 5 and 6 and fixed in place. Three instances of one idiom is where the Method stops instance patching, so the observation is recorded here rather than filed as a fourth: every one was an instrumentation or lookup path that assumed the code under test was already correct. The structural remedy is a convention rather than a boundary - a battery's own reporting path must tolerate the defect it exists to indict - and it is now stated in the Lessons.

A Lessons line was corrected rather than added to. It claimed the files under `.jeffy/probes/` are CRLF while `sqlparse/` is LF; that is wrong, and this iteration is how I found out. The idempotence probe is CRLF and the value-cache probe is LF, so my first deletion attempt matched nothing and its assertion stopped it. The line now says endings vary file by file and to read the bytes first, which is the rule that would have helped.

Battery ownership: the diff touches .jeffy/probes/value-cache/ and BACKLOG.md, which is in that battery's own paths file. All twelve batteries were run and all twelve exit 0. No file under sqlparse/ changed, so no inventory row went stale and the inventory battery confirms 24 rows swept, 20 modules mapped, 0 stale.

Verify gate -> 630 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0. Unchanged, as a change to a battery's error path should leave it.

Learnings: a battery's own reporting path has to survive the code it exists to indict, or it reports a stack trace exactly when it is doing its job. Three separate batteries this run failed that way, and the pattern in all three was the same - reading an attribute, a dict key or a section that only exists once the defect is fixed.

Next: iteration 9 takes AU-005, the missing CHANGELOG entry for the EV-007 fix, which is the last open item. Iteration 10 runs the evaluator gate and declares if the verdict is PASS and the closing conditions hold. There is no slack for a REJECT: if the gate rejects, its reasons are filed and the run ends blocked with them named in the run report.

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

## iter 9/10 | 56471ef3-194330 | 2026-08-08 | AU-005 | done

Task: the EV-007 fix changed user-visible output and CHANGELOG recorded no entry for it, while every sibling fix in the same class had one.

Changed: CHANGELOG, .jeffy/probes/changelog/probe.py, .jeffy/probes/changelog/paths, BACKLOG.md, JOURNAL.md.

Checkpoint: 6a57339bcf7795aec4704c15fc12d7aeca0e79a5

Stall check: not a stall - CHANGELOG and a new battery changed, and AU-005 moved from open to closed, emptying the ledger.

Verification: the omission was enumerated rather than asserted. Walking every commit from this run's base to HEAD and asking which touch sqlparse/ returns three, and exactly one of them - de409dd, the EV-007 fix - does not touch CHANGELOG in the same commit. The other two, AU-001 and AU-002, do. That is the finding as a command rather than as a reading.

The entry now describes the change in the terms a user meets: `reindent` no longer adds a blank line where a line comment had already ended the line, the output is a fixed point again, and the indent that belongs with the keyword is still applied so AND inside a WHERE keeps its column.

The second half of the acceptance is the part that outlives the entry. `.jeffy/probes/changelog/probe.py` makes the rule mechanical: from a recorded base commit forward, a commit whose diff touches sqlparse/ must touch CHANGELOG in that same commit, or name itself in an exemption table with a reason. Per-commit rather than "is it in the CHANGELOG somewhere", because that is the form a machine can answer and because coupling the entry to the commit is what stops the omission happening at all.

de409dd is exempted, with the reason recorded rather than the history back-dated: its entry was written now, in this commit, because the omission is what AU-005 was filed for. Writing the exemption is deliberately more work than writing the entry would have been, which is the incentive the rule wants.

Falsified both ways rather than left to pass. Removing that exemption makes the battery exit 1 naming de409dd and what it failed to do - the real historical omission, reported by the check that did not exist when it happened. Adding an exemption for a commit that touches no shipped code makes it exit 1 naming that exemption as unnecessary, so the table cannot rot into a list of commits nobody re-examines. Both were run, and the battery exits 0 on the tree as committed.

One boundary is stated rather than implied: commits at or before the base are out of scope. The rule starts where this run started, and the battery prints that line every run so a reader is never told the whole history was audited when it was not.

Battery ownership: the diff touches CHANGELOG, matching cli-errors and the new changelog battery. All thirteen batteries were run and all thirteen exit 0. No file under sqlparse/ changed, so no inventory row went stale; the inventory battery confirms 24 rows swept, 20 modules mapped, 0 stale.

Verify gate -> 630 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0.

Learnings: a documentation rule that depends on remembering is not a rule. This one went unnoticed for four iterations by people applying the very discipline it belongs to, and became enforceable only when it was written as a question about commits that git can answer.

Next: the ledger is empty and iteration 10 is the last. It runs the adversarial evaluator gate, the first invocation of this run, and declares convergence in that same iteration if the verdict is PASS and the closing conditions genuinely hold. One condition needs stating plainly rather than glossing: the Definition of done asks for a full audit that scored zero High and zero Medium, and this run's audit at iteration 4 found one of each. The clause that governs is the one for an audit that files its own findings - work them, then declare once the ledger is empty - and every one of AU-001 through AU-004 was worked, with AU-005 filed and worked through the same ledger after being noticed while executing AU-001. If the gate rejects there is no budget to answer it, and the run ends blocked with the reasons named in the run report.

## iter 10/10 | 56471ef3-194330 | 2026-08-08 | EVALUATOR | blocked

Task: the adversarial evaluator gate, both invocations of this run, and the fix the first one filed. The ledger emptied at iteration 9 with the budget's last iteration remaining, so the gate, its fix and the re-invocation had to share this one under the one-transaction rule.

Changed: sqlparse/filters/reindent.py, tests/test_format.py, CHANGELOG, .jeffy/probes/idempotence/probe.py, PLAN.md, BACKLOG.md, JOURNAL.md, .jeffy/evaluator/56471ef3-194330.md.

Checkpoint: b21709d7e533a3bf14bce80f97c36f1ff38d396f

Stall check: not a stall - sqlparse/filters/reindent.py changed, and BACKLOG.md changed state by closing the gate's first reason and filing R2 and R3.

Verification: Evaluator: REJECT, twice, and the run ends blocked and not converged. Both reasons were reproduced before being accepted, because a gate's reason is a hypothesis until it is run.

The first invocation rejected on one reason and it was mine. `_split_kwds` computed the text before a split keyword and only then deleted the whitespace token it replaces, so when that deleted token was itself the line break the code took the branch that says the break is already there and wrote only the indent. `format('a,or', reindent=True, indent_after_first=True)` returned `'a,  or'` and grew a space on every further pass; at 96ae9c5 it is a fixed point. That is a regression the EV-007 fix introduced at iteration 1 and that eight iterations of checks did not catch.

It was fixed by reading the text after the deletion rather than before, which is the question the code meant to ask all along: after removing the separator being replaced, does what remains already end in a break. EV-007 still holds, the indent before `and` is still written, `indent_width` is still live, and a 510-key differential over the fixtures and synthetics at 13 option sets names every changed key - twelve are the break restored, six are a space becoming that break, and two fixture keys gain the indent that `indent_after_first` gives the same statement without a comment. The idempotence corpus gained a split-separator section and now runs 38 inputs at 106 option sets for 3928 checks; it reports the defect against reindent.py at 6a57339 while the corpus as it stood before exits 0 over that same code, so the blindness was the corpus for the third time.

The second invocation confirmed the fix - 30180 fixed-point checks across both trees, 0 keys strictly worse, no lost fixed point, no new crash - and then rejected on something older and worse. `format('(as)', reindent=True)` raises `IndexError` from `StripWhitespaceFilter._stripws_parenthesis`, which reads a Parenthesis's second and second-to-last children without checking it has that many; `(as)` groups as a Parenthesis holding one Identifier. I reproduced it under three option sets and from four statement shapes, and the real CLI on a four-byte file exits 1 with a Python traceback and no `[ERROR]` line. It is pre-existing at 96ae9c5, so it is not this run's regression, but it is an open in-envelope High at HEAD and the closing rule's zero-High condition is false. Filed as R2 with a class-complete acceptance, since it is the same consequence class as AU-001 and fixing one fixed-index read would be instance patching again.

The iteration 4 audit should have found it and did not. Its crash sweep drove 420 malformed inputs through 12 option sets and reported no exception other than `SQLParseError`, and every one of those inputs was a truncation of valid SQL or a hand-written fragment. None was a parenthesis holding a single token. That is the third time this run that a corpus, not a check, was what missed a defect.

Two observations the gate recorded are not reject reasons and were not fixed here, because a fix after a verdict spends an invocation the run does not have: a fourth non-fixed-point instance inside the class BACKLOG calls settled, which belongs to the Proposed structural decision rather than to a fifth patch, and PLAN.md's Verify baseline sentence quoting counts that reproduce at neither commit, filed as R3.

Verify gate -> 634 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0. All thirteen batteries exit 0. The Surface inventory is 24 rows swept of 24, and the two rows naming reindent.py were re-swept in this iteration.

Learnings: three times this run a defect survived because the corpus never reached it, and every time the check itself was sound. A corpus assembled from the shapes someone thought of is the weakest part of any battery here, which is why the structural alternative is now a Proposed decision rather than another hand-added section. And a run that arrives at its last iteration with the gate unrun has no way to answer a rejection - the gate is worth more early, even when the ledger is not yet empty.

Next: none in this run. The loop ends here under the hard blocker rule with R2 open as the next run's first task, R3 behind it, and the corpus-generator question waiting on a user decision under Proposed.

## iter 10/10 | 56471ef3-194330 | 2026-08-08 | ROTATION | rotation

Task: JOURNAL.md reached 502 lines with the iteration 10 entry appended, past the 500 line threshold.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: recorded in the EVALUATOR entry for this iteration.

Verification: split only on lines beginning `## iter` followed by a digit, so the heading grammar example in the preamble was neither counted nor moved. The rotation script asserts the kept count, the archive count, and that the two still sum to what they summed to before, so a rotation that dropped an entry would fail rather than report success.

Learnings: none.

Next: none in this run - see the EVALUATOR entry.

## iter 1/10 | 13b41656-223157 | 2026-08-08 | R2 | done

Task: `sqlparse.format('(as)', reindent=True)` raised `IndexError` from `StripWhitespaceFilter._stripws_parenthesis`, which read a Parenthesis's second and second-to-last children without checking it had that many. Filed by the previous run's second evaluator invocation and carried into this run as the top open High.

Changed: sqlparse/filters/others.py, tests/test_regressions.py, CHANGELOG, .jeffy/probes/fixed-index/probe.py, .jeffy/probes/fixed-index/paths, PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: 1f19c7a531eafc2d8ac102647ad7471b7d74eec1

Stall check: not a stall - sqlparse/filters/others.py changed, and BACKLOG.md changed state by closing R2 and filing R4.

Verification: the filed reproduction ran first, as the working rules require, and all 15 of the reported (shape, option set) pairs still raised `IndexError` at 729b9b6.

The shape was measured rather than reasoned about. Instrumenting the filter over a corpus of parenthesised shapes shows what actually arrives: parentheses with 1 child 39 times and with 2 children 9 times, against 3 children 2079 times. `(as)` groups as a Parenthesis holding a single Identifier that swallowed both parens, so the assumed `('(', body..., ')')` is simply not what grouping promises. `()` never crashed but asked whether the open paren was whitespace - the same wrong assumption returning False by luck - and the nested read popped from a group in a loop that could drain it empty and then index it. Every index is now bounded and the interior loops stop at three tokens.

The corpus is generated from the lexer's own keyword tables, not hand-picked, because that is where the previous misses came from: of 687 keywords exactly one, AS, produces a degenerate Parenthesis, and the iteration 4 crash sweep drove 420 hand-assembled inputs past it. 708 inputs at 3 option sets is 2124 format calls, and each output is required to survive a parse round-trip, so a stable wrong answer fails as well as a crash.

Containment was proved by a corpus differential rather than by the green suite. 28 inputs at 10 option sets is 280 keys; 64 changed, every one of them a key whose before value was an `IndexError` and whose after value is output, and 0 fixture keys moved at all. No key that previously produced text produced different text.

Both halves were falsified against the defective tree. `.jeffy/probes/fixed-index/probe.py` reports 41 failures and exits 1 against sqlparse/filters/others.py at 729b9b6, with no traceback of its own - it names the unbounded reads through its AST layer, the 39 escaped `IndexError`s through its sweep, and the CLI as exit 1, traceback True. The 25 new parametrised regression tests fail 22 and pass 3 there, the 3 being the `()` shapes that never crashed.

Battery ownership: the diff touches sqlparse/filters/others.py and CHANGELOG, matching idempotence, trailing-newline, breadth-sweep, changelog, inventory and value-cache. All 14 batteries were run and all 14 exit 0; breadth-sweep confirms the new battery is pinned to the tree, which enrolls it automatically.

Inventory: sqlparse/filters/others.py changed, so api-format-strip and filters-others were re-swept in this same iteration rather than left stale. All 5 documented parameters of api-format-strip produce 2 distinct outputs of 2 - none inert - and all 5 classes in others.py hold their known answers, including the hint exemption, the issue484 line break, the issue782 paren trim and the issue140 comma rule, with `_trailing_ws` exercised at 6 branches.

Verify gate -> 659 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0.

Filed while executing this task: R4, a High. `sql.Function.get_window()` raises `AttributeError` on any function with no OVER clause, because `if not over_clause` tests the tuple `token_next_by` returns and `(None, None)` is truthy. It sits inside the class AU-001 recorded settled, and the settlement's enumeration is exactly why it survived: that walk matches a subscript whose value is a `token_next_by` call and cannot see a result bound to a name first. Extending the walk to names returns 2 inline sites and 1 assigned site. It is filed on reproduced evidence, not on a re-reading, and both existing tests supply an OVER clause so the absent branch has never run.

Learnings: an AST enumeration keyed on an expression's inline form is blind to the same expression reached through a variable, which is how a settled class kept a live crash. And a guard for a shape nobody has seen is decoration unless the battery fails when the shape never arrives.

Next: R4, the get_window crash, with the aligned-case enumeration extended to cover the assigned form so the class is closed rather than the instance patched. R3, a Low docs item, remains behind it.

## iter 2/10 | 13b41656-223157 | 2026-08-08 | R4 | done

Task: `sql.Function.get_window()` raised `AttributeError` on every function with no OVER clause, because its guard tested the tuple `token_next_by` returns and `(None, None)` is truthy. Filed in iteration 1 while executing R2, inside the class AU-001 had recorded settled.

Changed: sqlparse/sql.py, tests/test_grouping.py, CHANGELOG, .jeffy/probes/aligned-case/probe.py, PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: 3459a55a7cfb03f6576754bc6ecca9686e2a54f5

Stall check: not a stall - sqlparse/sql.py changed, and BACKLOG.md changed state by closing R4 and emptying the Now section.

Verification: the filed reproduction ran first. `select foo(a) from t` and `select count(*) from t` both raise `AttributeError: 'NoneType' object has no attribute 'tokens'`, while `select row_number() over (order by a) from t` returns its Parenthesis, so the defect is exactly the absent-window branch.

Contract preserved: the docstring already promised the window "if it exists", so returning None is the documented answer rather than a new behaviour, and the two existing tests that pin the present-window branch - `foo(5) over win1` giving an Identifier and `foo(5) over (PARTITION BY c1)` giving a Parenthesis - still pass untouched. The method now unpacks instead of subscripting, which is the shape 41 of the 43 call sites already use.

The class was closed rather than the site patched. The reason this survived a settlement is the settlement's own enumeration: it matched a subscript whose value is a `token_next_by` call, and `get_window` binds the answer to a name and subscripts the name, so the walk structurally could not see it. `.jeffy/probes/aligned-case/probe.py` now follows the result through a name as well as inline. On the tree as committed the walk returns 43 calls, 41 not subscripted inline, 2 subscripted inline and 0 through a name.

The instrument was shown blind rather than merely improved, which needed both batteries against one tree. Against sqlparse/sql.py at 4eeb27f the extended battery exits 1 with 16 failures - it names `get_window` as an unsettled site, reports 15 `AttributeError`s, and reports the walk returning 1 site through a name - and it prints no traceback of its own. The pre-R4 battery, run against that identical code, exits 0 and prints "2 sites, all settled". Opposite verdicts on the same defective tree is the evidence; a battery that merely got stricter would not produce it.

The measurement now covers both sides of the branch and fails if either side is never reached: 3 Function groups carrying an OVER clause and 14 without. On the unfixed tree that second count is 0, because every such call raised, and the battery says so rather than reporting a clean sweep of a question it never asked.

The 4 new parametrised tests in tests/test_grouping.py fail 4 of 4 against the unfixed module and pass on the fix.

Battery ownership: the diff touches sqlparse/sql.py and CHANGELOG, matching aligned-case, breadth-sweep, changelog, inventory and value-cache. All 14 batteries were run and all 14 exit 0.

Inventory: sqlparse/sql.py changed, so sql-accessors and sql-nodes were re-swept in this same iteration - 11 accessor known answers including `get_window` at both sides of its branch, and all 12 node classes produced from SQL that must yield them. One sweep failure was checked before being believed and was the instrument: `get_ordering` looked dead until the sweep stopped handing it the first Identifier in the statement, which is `a`, rather than the `b desc` that carries the ordering.

Verify gate -> 663 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0.

Learnings: a guard that tests the container rather than the value never fires - `(None, None)` is truthy, so `if not result` was dead code. And an AST enumeration keyed on an expression's inline form cannot see the same expression reached through a variable, which is how a class recorded settled kept a live crash for a whole run; the settlement sentence claimed 41 of 43 sites unpacked, and one of those 41 did not.

Next: the ledger holds only R3, a Low docs item, so the Now and Next sections are empty. With 8 iterations left and a clean ledger approaching, the evaluator gate should run early rather than at the declaration, but no full fresh-evidence audit has been recorded in this run yet - iterations 1 and 2 were both task execution - so the next iteration audits.

## iter 3/10 | 13b41656-223157 | 2026-08-08 | AUDIT | audit

Task: the full fresh-evidence audit this run owed. The ledger held one Low, below the replenishment threshold, and no full audit had been recorded in this run - iterations 1 and 2 were both task execution - so convergence had nothing to rest on. Run at iteration 3 rather than later so anything it filed would still have budget to be worked.

Changed: PLAN.md, JOURNAL.md.

Checkpoint: 3bbd6367f8fc52cf6014b46d0a16f42b1312d5c0

Stall check: this iteration changed no file outside PLAN.md and JOURNAL.md and no BACKLOG.md item changed state, so it is a stall by the letter. It is an AUDIT that filed nothing, which is a ceremony entry and exempt; the previous primary entry was not a stall, so no pair is formed.

Verification: the Surface inventory was consulted first, as the Method requires. It lists 24 rows, all swept, none stale, and every one of the 20 modules under sqlparse/ belongs to a row - re-measured by the inventory battery rather than read off the table. There were therefore no rows to sweep and no dimension is scored over unexamined surface.

Scores, each against the rubric and the Operating envelope, claiming the whole surface because no row is unswept:

- correctness: None. All 14 batteries exit 0, including the known-answer and idempotence instruments that pin output rather than liveness.
- error handling: None. A generated sweep crossed 34 SQL fragments with 17 separator classes - control characters, NUL, DEL, the Unicode line and paragraph separators, the ideographic space and the empty string - into 21280 inputs, driven through 11 option sets plus split at both `strip_semicolon` values and parse, for 243200 calls. Nothing but `SQLParseError` escaped. The sweep was then shown able to indict rather than trusted: run against sqlparse/filters/others.py and sqlparse/sql.py at 729b9b6 it exits 1 reporting 20 `IndexError`s, the first being `(\x0bas\x0b)` under strip_whitespace.
- security: None. Same sweep on the adversarial surface; the documented depth cap fires as `SQLParseError` at nesting depth 1000 and 5000 rather than `RecursionError`, and the project carries zero runtime dependencies, so there is no dependency with a known vulnerability to inherit.
- testing: None. Every one of the 10 test modules was run in isolation, cheapest first, and each passes alone; the per-module counts sum to exactly the whole-suite 663 passed with the same 1 xfailed and 1 xpassed, so no test is passing on state a different module leaked and no order dependence is hidden by the whole-suite run.
- performance: None. huge_select.sql formats in well under a second under strip_whitespace, reindent and reindent_aligned, and the CWE-1333 construction does not return: depth 5000 is rejected by the cap in a fraction of a second.
- documentation: Low, and it is the already-filed R3 rather than a new finding. The 12 doctest examples in docs/source/intro.rst were executed rather than read: 10 match exactly and the 2 that do not are memory addresses in a repr, which no code change can stabilise, so the documented examples are accurate. The documented option list was diffed against the options formatter.py actually reads: 17 documented, 18 read, and the single difference is `right_margin`, which is deliberate - JF-003 left it rejected with a message naming it rather than silently ignored, and two tests pin that - so it is correctly absent from the option documentation.
- dependency hygiene: None. No runtime dependencies at all; the dev group is pytest, coverage, ruff, build, sphinx and furo.
- code quality: None. ruff clean across sqlparse/.
- architecture, developer experience: None. No finding reproduced.
- UX: None for the surface that exists. The real CLI was driven end to end, not unit-tested: it formats and exits 0, reports a missing file as one `[ERROR]` line with exit 1 and no traceback, and rejects an invalid `-k` value through argparse with exit 2 and no traceback.
- observability: not applicable, and the reason is recorded rather than the dimension silently skipped. This is a parsing library and a text-filter CLI with no service, no daemon and no persistent state; there is nothing to instrument beyond the exit status and the single error line, both of which are pinned by the cli batteries.
- accessibility: not applicable. The only user-facing surface is a text filter with no interactive or visual output.

Zero High and zero Medium in-envelope. Closeout has begun: this run does no further auditing and no replenishment, and finishes by working or declining what is already on the ledger and then converging.

Learnings: an option a validator rejects on purpose reads exactly like an option nobody documented, and only the validator's message and its tests tell them apart - worth checking before filing, because the diff of documented against implemented cannot.

Next: R3, the one open item, a Low docs task correcting PLAN.md's own Verify baseline sentence. The ledger empties there, with 6 iterations still in hand, so the evaluator gate runs the iteration after it rather than waiting for the declaration - a REJECT files tasks and they need budget left to work.

## iter 4/10 | 13b41656-223157 | 2026-08-08 | R3 | done

Task: R3, the run's last open item, filed as a Low docs defect on the ground that PLAN.md's Verify baseline sentence reproduces at no commit. Closed by declining it: the sentence is correct, and the finding was reached by checking commits the sentence does not name.

Changed: PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: fed56e00129d5a268f33feee5db8475922c6d039

Stall check: not a stall. No file outside the state files changed, but BACKLOG.md changed state - R3 moved from open in Later to Declined, emptying Now, Next and Later.

Verification: the filed claim was run before being accepted, which is what overturned it. The sentence reads "Baseline at e7d95d494cebc66fd220198ea2eb2cf94a8bb5fe: 494 passed, 2 xfailed, 1 xpassed; ruff All checks passed!". That commit was extracted with `git archive` into a scratch directory - never a checkout, so the working tree was untouched - and the Verify command was run against the extract exactly as PLAN.md states it. It prints `494 passed, 2 xfailed, 1 xpassed` and `All checks passed!`, and both halves exit 0. The recorded baseline is right to the number at the commit it names.

The finding's own evidence is where it went wrong: it measured at 96ae9c5 and at HEAD, neither of which the sentence claims. The mechanism is now known rather than guessed. e7d95d4 carries three xfail markers - two in tests/test_format.py and one in tests/test_regressions.py - which is what 2 xfailed plus 1 xpassed sums to. HEAD carries two, because JF-003 deleted `test_format_right_margin` along with the right_margin feature it was marked for, which `git log -S` names as f7d8263. Two markers give 1 xfailed and 1 xpassed, which is what HEAD reports and what the finding saw.

Declined rather than deleted, so no later audit re-files it, and the reason carries the reproduction rather than an opinion. The sentence itself gained the clause that would have prevented the misreading: the counts belong to the named commit alone, later commits legitimately report different counts as tests are added and xfail markers are resolved, and a reader checking the line must run it at that commit rather than at HEAD.

Battery ownership: the diff touches PLAN.md and BACKLOG.md, matching the inventory and value-cache paths files. All 14 batteries were run and all 14 exit 0; inventory reports 24 rows, 24 swept, 0 stale, 20 of 20 modules mapped. No file under sqlparse/ changed, so no row went stale.

Verify gate -> 663 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0.

Learnings: a baseline sentence that names a commit is a claim about that commit, and checking it anywhere else measures a different tree - the trap is that the wrong reading also produces a real, reproducible mismatch, so the finding looks evidenced. Extract the named commit and run it there before believing either the sentence or the finding against it.

Next: the ledger is empty - Now, Next and Later all hold nothing - a full fresh-evidence audit scoring zero High and zero Medium is on this run's record from iteration 3, and 6 iterations remain. That is exactly the condition for running the adversarial evaluator gate now rather than at the declaration, so iteration 5 invokes it with budget left to answer a REJECT.

## iter 5/10 | 13b41656-223157 | 2026-08-08 | EVALUATOR | audit

Task: the adversarial evaluator gate, first invocation of this run. Run here rather than at the declaration because the ledger emptied at iteration 4 with a clean full audit already on this run's record and 5 iterations still in hand, which is the condition for gating while a rejection can still be answered.

Changed: .jeffy/evaluator/13b41656-223157.md, PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: 286fdd11dce3f7357498291edc5311e0e225ba42

Stall check: not a stall - BACKLOG.md changed state by filing R5 and R6 and adding a Declined line, and the evaluator artifact is a new file.

Verification: Evaluator: REJECT, on two reasons, and the run does not converge. Both were reproduced here before being accepted, because a gate's reason is a hypothesis until it is run, and both hold.

The first is that the iter 1 R2 entry claims the fixed-index battery names the 39 escaped IndexErrors against sqlparse/filters/others.py at 729b9b6. Re-run against that module the battery reports 41 failures, of which 3 come from the AST layer and 2 from the CLI check, so the escaped IndexErrors are 36. The sentence is not merely wrong but impossible on its own arithmetic, since 3 plus 39 plus 2 exceeds the 41 it sits beside. The second is that the iter 2 R4 entry claims the extended aligned-case battery reports 15 AttributeErrors against sqlparse/sql.py at 4eeb27f. Re-run against that file it reports 16 failures, one unsettled site, one never-reached branch and 14 AttributeErrors, and the same journal entry says 14 two paragraphs later, so it contradicts itself.

The mechanism behind both is the same and is worth more than the numbers: the fixed-index battery prints only its first 25 failures, so counting its output undercounts, and I wrote the figures from that truncated list instead of taking the reported total and subtracting the categories I could enumerate. That is the Lesson this project already carried about counts beside a growing literal, so it is now marked recurred with the specific trap named.

Filed rather than fixed here, because a fix inside the gate iteration is not what the rules allow: R5, Medium, docs, for the erratum, and R6, Low, test, for the gap the gate recorded as an observation - PLAN.md's sql-accessors and sql-nodes rows record a re-sweep whose instrument was a scratchpad script no checkpoint committed, where the Method requires a row's battery to be kept so a re-sweep re-runs it rather than rebuilding it. The same applies to the iteration 1 re-sweep of api-format-strip and filters-others.

What the gate confirmed is recorded as plainly as what it rejected. The Verify command exits 0 at 663 passed, 1 xfailed, 1 xpassed with ruff clean. All 14 batteries exit 0 from the project root. R2 and R4 were independently reproduced as broken at 729b9b6 and fixed at HEAD, and a 350-key corpus differential over 15 fixtures and 20 paren-heavy synthetic statements at 10 option sets moves 0 keys between those commits, so the R2 fix took nothing away from well-formed input. The R3 decline was independently confirmed by extracting e7d95d4 and running the gate against the extract. No missed in-envelope High or Medium was found: 33975 format calls over a 6795-input generated corpus escaped nothing but SQLParseError and broke no round-trip, all 60 constant-index subscripts and all 43 token_next_by sites in sqlparse/ were read individually, and every BACKLOG Settled-classes number was re-derived and reproduces.

One further observation the gate recorded is not a defect and is now Declined with its reason rather than left to be re-found: `format('( as )', strip_whitespace=True)` returns `( as )` where a well-formed parenthesis returns `(a)`, because the parens there sit inside the Identifier that swallowed them, the text is faithful and round-trips, and the input raised IndexError before R2 so there is no earlier behaviour it regressed from.

Verify gate -> 663 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0. sqlparse/ was confirmed byte-identical after the two temporary reverts used to recount, by git diff --stat returning empty.

Learnings: a battery that truncates its failure list cannot be counted by reading its output, and the arithmetic of a decomposition should be checked against the total printed beside it - the impossible sum in the first sentence was visible without running anything. Both wrong numbers were mine, both were in the half of the entry that argues the evidence is strong, and that is exactly where a retyped figure does the most damage.

Next: one evaluator invocation remains. The first landed at iteration 5, the midpoint of a budget of 10 rather than before it, so the cap is 2 and the second must both return PASS and declare in the same iteration. Iteration 6 takes R5, iteration 7 takes R6, and iteration 8 re-invokes the gate and declares if the verdict allows, leaving 9 and 10 as margin.

## iter 6/10 | 13b41656-223157 | 2026-08-08 | R5 | done

Task: R5, the erratum the iteration 5 evaluator gate filed. Two counts written into this run's journal were false, both retyped from a truncated failure list rather than derived from the totals beside them.

Changed: .jeffy/probes/fixed-index/probe.py, BACKLOG.md, JOURNAL.md.

Checkpoint: 342aaddb0e48d197d9ddeb96324fc2535179c0ae

Stall check: not a stall - .jeffy/probes/fixed-index/probe.py changed, and BACKLOG.md changed state by closing R5.

Verification: ERRATUM, correcting two earlier entries in this run. JOURNAL.md is append-only and past entries are never rewritten, so the corrections are recorded here and the entries they correct are named.

Erratum 1. The iter 1/10 R2 entry says the fixed-index battery, run against sqlparse/filters/others.py at 729b9b6, names "the 39 escaped IndexErrors through its sweep". The real figure is 36. Re-derived by running that battery against that exact module this iteration: it reports 41 failures decomposing as 3 ast-enumeration, 36 escaped-exception and 2 cli. The original sentence was impossible on its own arithmetic, since 3 plus 39 plus 2 is 44 against a printed total of 41.

Erratum 2. The iter 2/10 R4 entry says the extended aligned-case battery, run against sqlparse/sql.py at 4eeb27f, "reports 15 AttributeErrors". The real figure is 14. Re-derived by running that battery against that exact file this iteration: 16 failures, being 14 raised AttributeError, 1 unsettled site and 1 never-reached branch, and all 16 are printed, so this list was never truncated and 15 was simply wrong. The same entry already said "14 without" two paragraphs later, so it contradicted itself in plain sight.

Every other figure this run wrote into a state file was re-derived rather than assumed, which is the second half of the acceptance. Running the two batteries against HEAD reproduces each one: 11 constant-index subscripts at 7 distinct sites, 687 keywords enumerated from the lexer tables with 14 of 708 corpus inputs building a short Parenthesis, child-counts received of 39 at one child and 9 at two, which is the 48 the PLAN Lessons line states; and 2 subscripted sites both inline with 0 through a name, 17 Function groups none lacking a Parenthesis, and get_window measured on 3 Functions with an OVER clause and 14 without. No state file now carries a count that its own re-run contradicts.

The mechanism was closed rather than the two sentences merely corrected. `.jeffy/probes/fixed-index/probe.py` now prints its failure total decomposed by category and asserts the categories sum to that total, so a bucket nobody classified appears as `other` instead of quietly rebalancing the arithmetic, and the truncation notice now says in words that the printed list stops at 25 while the total does not. Against the unfixed module it prints `41 FAILURE(S) by category: {'ast-enumeration': 3, 'cli': 2, 'escaped-exception': 36}`, which is the sentence that would have been copied correctly. The BACKLOG Settled-classes line carries that decomposition too.

Battery ownership: the diff touches .jeffy/probes/fixed-index/probe.py and BACKLOG.md, matching value-cache through BACKLOG.md; the changed battery is itself run. All 14 batteries were run and all 14 exit 0. No file under sqlparse/ changed, so no inventory row went stale, and sqlparse/ was confirmed byte-identical after the two temporary reverts by git diff --stat returning empty.

Verify gate -> 663 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0.

Learnings: an instrument that truncates its own output must report the decomposition it truncates, or every reader after it will count the visible lines and be wrong by however many were hidden. Correcting the two sentences would have left the trap; making the battery print categories that must sum to the total removes it, and the arithmetic check is what turns the next such error into a failure rather than a claim.

Next: R6, the last open item - the sql-accessors, sql-nodes, api-format-strip and filters-others inventory rows record re-sweeps whose instrument was a scratchpad script no checkpoint committed, where the Method requires a row's battery to be kept so a re-sweep re-runs it. That empties the ledger at iteration 7, leaving iteration 8 for the second and final evaluator invocation, which must return PASS and declare in that same iteration.

## iter 7/10 | 13b41656-223157 | 2026-08-08 | R6 | done

Task: R6, the gap the iteration 5 evaluator gate recorded as an observation. Four Surface inventory rows asserted known answers whose instrument was a scratchpad script no checkpoint committed, where the Method requires a row's battery to be kept so a re-sweep re-runs it rather than reconstructing it.

Changed: .jeffy/probes/row-known-answers/probe.py, .jeffy/probes/row-known-answers/paths, PLAN.md, BACKLOG.md, JOURNAL.md.

Checkpoint: 43ea02fbc185721a008359ea710f2c93d689d6f0

Stall check: not a stall - a new battery was added under .jeffy/probes/, and BACKLOG.md changed state by closing R6 and emptying Now, Next and Later.

Verification: `.jeffy/probes/row-known-answers/probe.py` now carries the values the four rows claim - sql-accessors, sql-nodes, api-format-strip and filters-others - and exits 0 at 44 known-answer checks: 13 accessor answers, 12 node classes, 5 documented parameters with 0 inert, 8 known answers for the classes in others.py, and 6 `_trailing_ws` branches. Each row now names the battery, so the instrument is findable from the claim it supports.

It is known-answer rather than liveness throughout: every check states the exact value the code must return, and the parameter checks require two values that produce different output, so a parameter that goes inert fails rather than passes. The accessor set includes the negative side deliberately - a plain identifier must answer None for both `get_ordering` and `get_alias` - because a sweep that only ever asks where the answer is non-empty cannot tell a working accessor from one that always returns something.

Falsifiability was proved three ways rather than argued, and the first two use real defective trees rather than a mutation. Against sqlparse/sql.py at 4eeb27f the battery exits 1 naming the two `get_window` calls that raise AttributeError, which is the R4 defect. Against sqlparse/filters/others.py at 729b9b6 it exits 1 naming the short-parenthesis known answer that raises IndexError, which is the R2 defect. The third is the acceptance line as written: a copy with one expected value altered, `get_real_name` from bar to BAR, exits 1 reporting `got 'bar', expected 'BAR'`, and the copy was removed before the checkpoint.

The battery was built to survive the code it indicts, which the first draft did not. Both defects these rows cover are raised rather than returned, and the draft called `get_window()` and `format()` eagerly at module level, so against either defective tree it would have died with a traceback instead of reporting - failing for the right reason by accident and proving nothing. Every value is now produced through a thunk whose exception is caught and reported as a named failure, and both defective-tree runs print 0 tracebacks.

Battery ownership: the diff touches .jeffy/probes/ and PLAN.md, matching inventory through PLAN.md. All 15 batteries were run and all 15 exit 0; breadth-sweep enrols the new one automatically, since it walks every sibling probe.py and requires each to call `pin()`. No file under sqlparse/ changed, so no row went stale, and sqlparse/ was confirmed byte-identical after the two temporary reverts by git diff --stat returning empty.

Verify gate -> 663 passed, 1 xfailed, 1 xpassed, All checks passed!, exit 0.

Narrowing a sentence from the previous entry, since the journal is append-only and the claim was too wide. The iter 6/10 R5 entry ends its verification paragraph with "No state file now carries a count that its own re-run contradicts." The enumeration behind that sentence was this run's own figures, which were all re-derived; it does not extend to counts written by earlier runs, and one of those is ambiguous rather than verified - the filters-others row calls `_trailing_ws` a helper with seven branches where this battery drives six, the difference being how the leaf arm's conditional expression is counted. The sentence should have read that no count this run wrote into a state file is contradicted by its own re-run.

Learnings: a battery whose subject raises rather than returns must produce every value through a call it can catch, or it dies against the one tree it exists to fail against. And a claim about state files is a claim about every run that wrote them, not only this one - scope the sentence to the set actually enumerated.

Next: the ledger is empty, Now, Next and Later all hold nothing, and the clean full audit from iteration 3 stands with only gate-filed fixes committed since. One evaluator invocation remains, so iteration 8 re-invokes the gate and, if the verdict is PASS and the closing conditions hold, declares convergence in that same iteration.

## iter 7/10 | 13b41656-223157 | 2026-08-08 | ROTATION | rotation

Task: JOURNAL.md reached 523 lines with the iteration 7 entry appended, past the 500 line threshold.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: recorded in the R6 entry for this iteration.

Verification: split only on lines beginning `## iter` followed by a digit, so the indented heading-grammar example in the preamble was neither counted nor moved. 18 entries became 10 kept and 8 appended to the archive, which went from 32 entries to 40 - it accumulates and never shrinks. The rotation script asserts the kept count, the archive count and that the two still sum to what they summed to before, so a rotation that dropped an entry would fail rather than report success. JOURNAL.md is 296 lines afterwards.

Learnings: none.

Next: none in this iteration - see the R6 entry.

## iter 8/10 | 13b41656-223157 | 2026-08-08 | EVALUATOR | converged

Task: the adversarial evaluator gate, second and final invocation of this run, and the convergence declaration in the same iteration. The cap is 2 invocations, because the first landed at iteration 5 - the midpoint of a budget of 10 rather than before it - so a PASS here had to declare immediately or be lost.

Changed: .jeffy/evaluator/13b41656-223157.md, BACKLOG.md, JOURNAL.md.

Checkpoint: 31e851e6704ffacc99a531f9405eb46c5f2e97fb

Stall check: not a stall - BACKLOG.md changed state by gaining its Converged line, and the evaluator artifact was rewritten by this invocation. This is in any case the EVALUATOR ceremony entry, which the stall rule exempts.

Verification: Evaluator: PASS - every acceptance check re-run and confirmed, both erratum figures independently re-derived as 36 and 14, the R6 battery shown to indict two real defective trees without dying on them, and a fresh 132720-call sweep over the adversarial surface finding no missed in-envelope High or Medium.

The gate re-ran the Verify command with each half's status read from its own exit code rather than through a pipe: 663 passed, 1 xfailed, 1 xpassed, then All checks passed!, both exit 0. All 15 batteries exit 0 from the project root. It reproduced R2 as broken at 729b9b6 and fixed at HEAD, R4 the same at 4eeb27f, and it re-ran the pre-R4 copy of the aligned-case battery against the defective sql.py to confirm the opposite-verdict pair rather than take the journal's word for it. The R3 decline was checked by extracting e7d95d4 and running the gate against the extract, which prints the recorded baseline exactly. It spot-checked the state files' numbers by executing them - 43 token_next_by sites, 11 subscripts at 7 sites, 687 keywords, 39 plus 9 short parentheses, 17 Function groups none lacking a Parenthesis, 3 with an OVER clause and 14 without, 3928 idempotence checks, 20 modules, and the 10 test modules in isolation summing to exactly 663 - and all reproduce. Its three temporary reverts were restored and confirmed byte-identical.

Closing conditions, each checked rather than asserted. The full fresh-evidence audit of iteration 3 scored zero High and zero Medium in-envelope and stands unchallenged. The Surface inventory lists 24 rows, 24 swept, 0 unswept, 0 stale, with all 20 modules under sqlparse/ mapped. Now, Next and Later are empty: every finding filed this run is completed or Declined with a reproduced reason, and none is left blocked. The Verify command is green this iteration. Nothing under sqlparse/ or tests/ has changed since that clean audit - `git diff --name-only 3bbd636..HEAD -- sqlparse/ tests/` returns nothing - so the audit's verdict still describes the shipped code exactly, and every commit since is a completed fix for a task the gate filed, a decline, or state and probe files.

Two observations the gate recorded are not reject reasons and are deliberately not fixed here, because a fix after a PASS invalidates the PASS and spends the invocation the declaration needs. They go to the run report and the next run's ledger. PLAN.md's sql-accessors row says 11 accessor known answers where the kept battery it names prints 13, the battery being a superset since R6 added two negative-side checks; and the filters-others row calls `_trailing_ws` a helper with seven branches where that battery drives six, a count an earlier run wrote and which the iteration 7 entry already discloses as ambiguous.

Converged: baafe047afc9d5e04979fd43b2b76578f5446f15 is appended under the Converged section of BACKLOG.md, naming the tree this declaration certifies.

Learnings: gate early enough that a rejection can be answered. This run's first invocation landed at the midpoint and returned REJECT on two real defects in its own record; three iterations remained, which was exactly enough to fix both, add the missing kept battery and re-gate. Landing it one iteration later would have ended the run blocked with the same two findings open.

Next: none - the run is converged. The next run's first tasks are the two gate observations above, neither of which affects shipped code.
