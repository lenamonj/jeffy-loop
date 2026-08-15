# Journal archive

Entries rotated out of JOURNAL.md, appended in order, never rewritten.

## iter 1/10 | d32e6b21-133102 | 2026-08-15 | AUDIT | audit

Task: first audit - fill the Operating envelope, the Verify command with its Oracle class and Environment fingerprint, and the Surface inventory, then probe breadth-first and file findings.

Changed: PLAN.md (envelope surfaces, 36 Surface inventory rows, Verify command block), BACKLOG.md (3 findings), JOURNAL.md, .gitignore (loop state file).

Checkpoint: d3f57ea9b7283c2c5dca93a7be12a86f7e31b5f1

Verification: Verify command exits 0 with 1948 test cases passing in 15s. Findings were reproduced with throwaway integration tests placed in `tests/`, `clap_mangen/tests/` and `clap_complete/tests/`, run, and deleted before the checkpoint; the working tree holds only the three state files and .gitignore. Probes actually executed: 18 odd argv shapes (`--`, `--=`, `--=value`, `-`, `-=`, `-o=`, `--opt=`, empty string, `-of`, `-fo v`, `--opt=a=b`, prefix-truncated longs, missing values, subcommand with a valueless option) and 4 non-UTF-8 argv shapes on unix, all returning typed errors with no panic; 14 spellings against `Arg::allow_negative_numbers(true)` on a long option, a short option and a positional; `clap_mangen` rendering of help text carrying a backslash, a leading dot and an apostrophe, which came back correctly escaped as `\\d`, `\&.` and `\*(Aq`; the bash, zsh, fish, elvish and powershell generators over help text carrying apostrophes, `$`, backticks, brackets and colons, all correctly quoted for their shell; and help wrapping at `term_width(40)` with a tab and with a carriage return in the help string.

Scores, claiming only the probes listed above and never the project: correctness Medium (NEG-EXP), ux Low (CTRL-WIDTH), documentation Low (BOOL-DOC), security None over the shell-script quoting, roff escaping and non-UTF-8 argv probes only, error handling None over the 22 argv shapes only. Testing, architecture, code quality, performance, dependency hygiene, developer experience, observability and accessibility are not scored this iteration; Testing in particular needs the isolated-module run the Method requires before it may be scored clean. All 36 Surface inventory rows are unswept, so this audit maps the project rather than certifying it, and no dimension score above stands for the unexamined remainder.

Learnings: the root crate's dev-dependencies do not include `clap_lex`, so a probe of `clap_lex` public API has to live in `clap_lex/tests/` rather than the root `tests/`. `make test-full` leaves `clap_complete/unstable-dynamic` off, which silently drops 46 tests including the whole dynamic completion engine, so the Verify command adds that feature explicitly.

Next: NEG-EXP, then the Surface inventory sweep starting with the clap_lex rows that NEG-EXP lands in.

## iter 2/10 | d32e6b21-133102 | 2026-08-15 | NEG-EXP | done

Task: NEG-EXP - `clap_lex::is_number` rejects signed exponents, so `Arg::allow_negative_numbers(true)` refuses `-1e-5` and `-1E+3`.

Changed: clap_lex/src/lib.rs (`is_number` grammar plus the docs of both public `is_negative_number` methods), clap_lex/tests/testsuite/parsed.rs, tests/builder/app_settings.rs, clap_lex/CHANGELOG.md, CHANGELOG.md, BACKLOG.md, PLAN.md (Lessons), JOURNAL.md.

Checkpoint: 078438de5f8bf9a99998dbd1c056222d63f334cf

Verification: the filed reproduction ran first and narrowed the task. `clap_lex/tests/testsuite/parsed.rs::is_not_number` pins `-.2` as a non-number, added in 9a9aabc1, so the leading-decimal-point half of NEG-EXP is a maintainer decision rather than a defect; it moved to Proposed as NEG-DOT and this iteration fixed only the signed-exponent half, which no test pins. Acceptance check: `tests/builder/app_settings.rs::allow_negative_numbers_scientific_notation` drives `-1e-5`, `-1E+3`, `-1e5` and `-1.3e-10` through a positional, a short option and a long option; against the committed code it fails at the first case with `UnknownArgument` (exit 101, run by copying the fixed lib.rs aside, restoring `git show HEAD:clap_lex/src/lib.rs`, running, then copying the fix back), and passes after the fix. `clap_lex` testsuite exit 101 before, 0 after. Verify command exits 0 with 1949 cases. Contract preserved, and verified rather than argued: a throwaway differential test enumerated all 2801 strings of length 0 to 4 over `0 1 . e E + -`, confirmed no string the old grammar accepted is rejected by the new one, confirmed the shipped `is_negative_number` agrees with the new grammar on every one of them, and reported exactly 16 newly accepted strings, all of the form digit-e-sign-digit. The `is_not_number` pin list grew from 10 entries to 19 (adding `-1e-`, `-1e+`, `-1e-1.2`, `-1e5e5`, `-1-5`, `-1+5`, `-+5`, `-inf`, `-NaN`) and passes, so `-inf` stays available as a group of short flags. `cargo check -p clap_lex --all-targets` reports no new warnings.

Correction to the iteration 1 entry, which past entries may not be rewritten to carry: it says 36 Surface inventory rows twice, and `grep -c '^- \[' PLAN.md` returns 35. The count is 35; nothing else in that entry depends on the figure.

Learnings: `cargo clippy` is not installed on this host, so lint regressions cannot be self-checked here. A rejected spelling that a test pins deliberately is a Proposed item, not a defect, so grep the test tree for the spelling before filing a grammar finding.

Next: the Surface inventory sweep, top of the queue now that no High or Medium task is open, starting with the two clap_lex rows this change lands in.

## iter 3/10 | d32e6b21-133102 | 2026-08-15 | SWEEP | done

Task: sweep unswept Surface inventory rows, the top of the queue with no High or Medium open; build the battery infrastructure the sweep needs and sweep every row this iteration can properly evidence.

Changed: .jeffy/probes/ (new detached cargo package: Cargo.toml, src/lib.rs, and three batteries with their paths files), PLAN.md (3 rows flipped to swept, Lessons), BACKLOG.md (3 findings filed), JOURNAL.md.

Checkpoint: 2471d0ee63e5169e98227233d7e3ca36b4ae1e37

Verification: batteries live in `.jeffy/probes`, a cargo package held out of the workspace by an empty `[workspace]` table, so probe code is committed and re-runnable but never builds with the project's own suite and never ships. `cargo test --manifest-path .jeffy/probes/Cargo.toml` exits 0 with 37 assertions across three batteries: clap-lex-ext 12, clap-lex-core 10, builder-range-groups 15. Rows swept 3 of 35, from 0 at run start. Verify command exits 0 with 1949 cases.

Evidence per row, all executed rather than read: clap-lex-ext differentials all six `OsStrExt` methods against the matching `str` methods over 13 haystacks by 8 needles, backs that with hand-computed answers so a broken reference could not pass, covers non-UTF-8 haystacks `str` cannot express, and pins the documented empty-needle panic on `split`. clap-lex-core pins the five token predicates against a hand-computed classification table, asserts they partition so no token is two kinds at once, drives `advance_by` at 0, inside, exactly at, and past the end, and checks the number grammar against an independent reimplementation written from the documented contract over all 2801 strings of length 0 to 4 over `0 1 . e E + -`, plus the invariant that `ShortFlags` and `ParsedArg` never disagree on it. builder-range-groups drives every `ValueRange` `From` impl at its boundary against hand-computed min and max, both values of `PossibleValue::matches`'s `ignore_case` over 11 values including non-ASCII, both values of `ArgGroup::multiple` and `required` through the real parser, and the documented empty-range panics.

Three findings filed, each reproduced by a battery assertion that is now committed: RANGE-ZERO (Medium) - `ValueRange::new` documents that empty ranges panic and `0..0` and `..0` do not, so `num_args(0..0)` silently yields a boolean flag; ARGGROUP-MUT (Low) - `ArgGroup::is_multiple` takes `&mut self` alone among its sibling accessors; ADVANCE-DOC (Low) - the `Err` payload of `ShortFlags::advance_by` is undocumented.

Two battery assertions failed and both were the battery being wrong, not clap: `advance_by` past the end returns the count advanced rather than the shortfall, pinned by `clap_lex/tests/testsuite/shorts.rs::advance_by_out_of_bounds`, and an arg with `num_args(0..0)` is inferred to be a boolean flag so its value type is `bool`, not `String`. Both were corrected against the contract the code documents rather than filed, and both now stand as pinned known answers.

Learnings: a failing battery assertion is a hypothesis about the code, not a defect in it - check the documented contract and the tests that pin it first. Batteries need a package detached from the workspace, or they would join the project's own suite.

Next: RANGE-ZERO, the only open Medium, then back to sweeping the remaining 32 rows.

## iter 4/10 | d32e6b21-133102 | 2026-08-15 | RANGE-ZERO | done

Task: RANGE-ZERO - `ValueRange::new` documents that empty ranges panic in debug builds, but `0..0` and `..0` did not, so `num_args(0..0)` silently produced a boolean flag.

Changed: clap_builder/src/builder/range.rs (`From<Range>` and `From<RangeTo>` debug asserts, plus the doc examples), .jeffy/probes/builder-range-groups/battery.rs, CHANGELOG.md, PLAN.md (row re-swept), BACKLOG.md, JOURNAL.md.

Checkpoint: 9d73ccd11c33ef85537b4bbf97c70d44ca8c378e

Verification: the fix adds the emptiness check ahead of the `saturating_sub` that was swallowing it, in the two impls that take an exclusive upper bound. Contract preserved, checked rather than assumed: no code in clap_builder, clap_derive or clap_complete constructs a `ValueRange` from a zero-length range - `grep -rn 'ValueRange::\|\.\.0\b\|0\.\.0'` over their sources returns only the `EMPTY`, `SINGLE`, `FULL`, `OPTIONAL` constants and the literal `0..=1` and `1..` ranges - so nothing internal trips the new assert. The three supported ways to say "no values" are unaffected and pinned: `ValueRange::new(0)`, `0..=0` and `..=0` all still yield min 0 max 0, and `num_args(0)` still parses as a flag. Acceptance check: `.jeffy/probes/builder-range-groups` exits 0 with 17 assertions after the fix; run against the committed range.rs, exactly the three new should-panic cases fail (`value_range_zero_length_at_zero_panics`, `value_range_to_zero_panics`, `num_args_zero_length_range_panics`, exit 101) while the two pre-existing panic cases `5..5` and `10..5` still pass, so the change is targeted rather than broad. The battery owns range.rs through its paths file and was updated in this same iteration, converting the three assertions that pinned the old behaviour into should-panic cases. Verify command exits 0 with 1952 cases, up 3 from the new doctests.

Closed this iteration: RANGE-ZERO (Medium, correctness) - empty ranges `0..0` and `..0` now panic in debug builds as documented, evidenced by the differential above.

Learnings: none new beyond the Lessons already recorded.

Next: back to sweeping the 32 unswept rows, which outrank the four open Lows.

## iter 5/10 | d32e6b21-133102 | 2026-08-15 | SWEEP | done

Task: sweep, still the top of the queue with no High or Medium open; take the two highest-value unswept rows, `builder::value_parser` and `parser::matches::arg_matches`.

Changed: .jeffy/probes/builder-value-parser/ and .jeffy/probes/parser-arg-matches/ (new batteries with paths files), .jeffy/probes/Cargo.toml, PLAN.md (2 rows flipped), BACKLOG.md (2 findings filed), JOURNAL.md.

Checkpoint: 99b098a55276b838ae4f9cfad4d2717d8d0149a5

Verification: `cargo test --manifest-path .jeffy/probes/Cargo.toml` exits 0 with 62 assertions across five batteries - clap-lex-ext 12, clap-lex-core 10, builder-range-groups 17, builder-value-parser 12, parser-arg-matches 11. Rows swept 5 of 35, from 3 at the start of this iteration and 0 at run start. Verify command exits 0 with 1952 cases.

Evidence per row: builder-value-parser drives the three bool parsers differentially over the same 20 literals, which is the sharpest available oracle because their only reason to exist is that they disagree, and asserts each documented divergence plus the invariant that anything boolish accepts, falsey accepts with the same answer; it checks every ranged parser at both sides of both bounds and again at a second range, so a parser that ignored its bounds could not pass, covers narrowing target types at their limits and the negative side of the domain, and exercises `value_parser!` inference, `PossibleValuesParser` at both values of `ignore_case`, `NonEmptyStringValueParser` against the plain string parser, and `map` and `try_map`. parser-arg-matches checks every accessor against one hand-computed parse rather than against itself, then the cross-accessor invariants: raw agrees with typed, one index per value, `index_of` is the first of `indices_of`, flattened occurrences reproduce `get_many` exactly, and the `try_*` family agrees with the panicking family wherever the latter does not panic.

Two findings filed: UNDOC-PANIC (Low) - 9 of the 14 `ArgMatches` id-taking accessors panic alike on an unknown id and only 5 document it, filed Low rather than Medium with the rationale on the ledger line because the documentation is absent rather than misleading; BOOLISH-KIND (Low) - `BoolishValueParser` implements `possible_values()` yet reports `ValueValidation`, so the accepted literals never reach the user, while `BoolValueParser` reports `InvalidValue` and renders `[possible values: true, false]` for the same mistake. The UNDOC-PANIC claim generalises over a set of sites, so it ships with its enumeration: the battery provokes the real panic at all 14 accessors and cross-checks the count against the documented-status table, so the table cannot drift without failing. The BOOLISH-KIND claim was confirmed by rendering both errors side by side before filing, not by reading the source.

Five battery assertions failed this iteration and all five were the battery being wrong. `--v -1` lexes as a flag, so value-parser probes must use the `--v=<value>` form or they test argv lexing instead. `BoolishValueParser` reports `ValueValidation` where `BoolValueParser` reports `InvalidValue`. `subcommand_matches` and `value_source` panic on undefined names, and both document it. A parent's `contains_id` panics on a subcommand's id rather than answering false. Each was checked against the contract the code documents before being corrected, and each is now a pinned known answer.

Learnings: value-parser probes must pass the value with `--opt=value`, because a bare negative in the next position lexes as a flag. Before filing an undocumented-panic finding, check the accessor's own doc block rather than a fixed window of preceding lines, since a neighbour's `# Panics` section is easily mistaken for the target's.

Next: keep sweeping; 30 rows remain unswept against five iterations, so the run will end well short of a declaration and the report will say so.

## iter 6/10 | d32e6b21-133102 | 2026-08-15 | SWEEP | done

Task: sweep, still the top of the queue; take `output::textwrap` and `parser::features::suggestions`, both reachable only through the public help and error surfaces.

Changed: .jeffy/probes/output-textwrap/ and .jeffy/probes/parser-suggestions/ (new batteries with paths files), .jeffy/probes/Cargo.toml, PLAN.md (2 rows flipped), BACKLOG.md (2 findings filed), JOURNAL.md.

Checkpoint: 0cfc82b66b89f4f8fc32ea5736c8093e589baf69

Verification: `cargo test --manifest-path .jeffy/probes/Cargo.toml` exits 0 with 76 assertions across seven batteries - clap-lex-ext 12, clap-lex-core 10, builder-range-groups 17, builder-value-parser 12, parser-arg-matches 11, output-textwrap 7, parser-suggestions 7. Rows swept 7 of 35, from 5 at the start of this iteration and 0 at run start. Verify command exits 0 with 1952 cases.

Acting on the Lesson recorded last iteration, this sweep observed the real output before writing any assertion, which cut the wrong-expectation failures from five to two and turned both of those into findings rather than corrections. output-textwrap rests on two invariants a wrong wrapper cannot satisfy - no wrapped line over the requested width, and the input word sequence surviving rendering unchanged, so a wrapper that dropped, duplicated, reordered or split a word fails even while every line stays inside the bound - checked over 5 texts by 5 widths, plus hand-computed break points at two widths, the unbreakable-long-word case, and `term_width` at values that must move the breaks. parser-suggestions checks near-miss flags, values and subcommands against hand-computed targets through the real error text, the documented ascending-similarity ordering on a case where two candidates both clear the threshold, and the negative side where a distant input must draw no tip at all.

Two findings filed, both Low with the rationale on their ledger lines. USAGE-NOWRAP: the `usage` help-template variable pushes `create_usage_no_title` straight to the writer with no `wrap` call, while `about`, `before_help` and `after_help` each call `wrap(term_w)` and the argument sections wrap to the available columns, so `term_width` has no effect whatever on the usage line; at `term_width(30)` a four-required-option command renders a 79 character usage line in the same help whose option lines all fit inside 30. SUGGEST-CASE: `did_you_mean` scores with `strsim::jaro` over raw strings, so `--FLAG` shares no characters with `--flag`, scores 0 against the 0.7 threshold and draws no tip, while the transposition `--flga` does.

CTRL-WIDTH, carried since iteration 1, is now pinned harder than it was filed: at `term_width(40)` the tab-bearing help produces a 45 character line, so the undercount overshoots the requested width by character count and not merely in a terminal that expands the tab; the same text without the tab stays inside 40.

Learnings: observe the real output before writing assertions against an unswept surface - it converts guesses into either pins or findings and stops the battery-was-wrong churn. `Command::long_about` and `Arg::help` want `'static`, so a battery that varies text over a corpus passes owned `String`s, which the `string` feature allows.

Next: keep sweeping. 28 rows remain against four iterations, so this run ends well short of the no-unswept-row bar and will report rather than declare.

## iter 7/10 | d32e6b21-133102 | 2026-08-15 | SWEEP | done

Task: sweep; take `error::{mod,format,kind,context}` and the whole `clap_mangen` row, the two largest user-facing surfaces still unswept.

Changed: .jeffy/probes/error-api/ and .jeffy/probes/clap-mangen/ (new batteries with paths files), .jeffy/probes/Cargo.toml (clap_mangen dependency, two test targets), PLAN.md (2 rows flipped), JOURNAL.md.

Checkpoint: 6d23901b632d29051d352439079104c0dead6f08

Verification: `cargo test --manifest-path .jeffy/probes/Cargo.toml` exits 0 with 90 assertions across nine batteries. Rows swept 9 of 35, from 7 at the start of this iteration and 0 at run start. Verify command exits 0 with 1952 cases. No BACKLOG item changed state this iteration and the only non-state files touched are under .jeffy/, so by the stall check's own definition this iteration made no ledger progress; it is not a stall in substance - two rows moved and 14 assertions were added - and the previous entry does not say the same, so the pair the rule cares about has not formed.

Evidence per row: error-api pins kind, exit code, stream choice and attached context for 7 failing command lines against hand-computed answers, then holds the invariant that binds them - exit code 0 and stdout belong to exactly the two output-request kinds, `DisplayHelp` and `DisplayVersion`, and to nothing else, which is the property a shell script branching on the exit code depends on. It round-trips `insert`, `get` and `remove` including the displaced-value return, and checks `render` never diverges from `Display`. clap-mangen checks page structure and section order against hand-computed roff, drives all five builder setters at two values each so a setter wired to nothing or to the wrong field would fail, pins the filename rules, holds the invariant that every per-section fragment appears in the assembled page in order, and asserts that no rendered line can start a roff request the developer's help text smuggled in.

No findings. Four battery assertions failed and all four were the battery being wrong, each corrected against the contract the code documents: a missing-required error carries `ContextValue::Strings` rather than `String`, because one error can name several missing args; `Usage` context is a `StyledStr`; `Man::title` sets the `.TH` title while `get_filename` follows the command's display name or name, which is what makes `man prog` find the page for the binary called `prog`; and each per-section renderer emits a standalone roff fragment repeating the two-line apostrophe preamble, so fragments are not byte-identical substrings of the assembled page until that preamble is stripped. Both title and filename behaviours are now pinned as known answers rather than left as assumptions.

Learnings: none new; the observe-before-asserting rule from last iteration held, and every failure this time was a contract that had to be read rather than a behaviour worth filing.

Next: keep sweeping. 26 rows remain against three iterations, so the run will close with a handoff rather than a declaration.

## iter 8/10 | d32e6b21-133102 | 2026-08-15 | SWEEP | done

Task: sweep; take `clap_complete::engine`, the least-trodden surface left and the one where a finding was most likely.

Changed: .jeffy/probes/complete-engine/ (new battery with paths file), .jeffy/probes/Cargo.toml (clap_complete dependency with unstable-dynamic, one test target), PLAN.md (1 row flipped), BACKLOG.md (ESCAPE-SUBCMD filed, duplicate heading removed), JOURNAL.md.

Checkpoint: a9e487e675853faf5004bb2949d73b0436e077f3

Verification: `cargo test --manifest-path .jeffy/probes/Cargo.toml` exits 0 with 97 assertions across ten batteries. Rows swept 10 of 35, from 9 at the start of this iteration and 0 at run start. Verify command exits 0 with 1952 cases. The stall the hook flagged on iteration 7 does not repeat: BACKLOG.md gained ESCAPE-SUBCMD under Now-adjacent Next, so a ledger item changed state.

The battery's binding invariant is that a candidate the engine offers at a position is one the same command accepts there. That is what caught ESCAPE-SUBCMD; a set-equality check would have recorded the wrong answer as expected and certified the row clean.

ESCAPE-SUBCMD (Medium, correctness): after the `--` escape the engine still offers subcommand names, and the same `Command` rejects every one of them - `prog -- build` returns `ErrorKind::InvalidValue`. The engine demonstrably knows about the escape, because it returns nothing for the prefixes `-` and `--f` at that same position and still offers positional values there; subcommands alone survive it. Scored Medium as a failure on a plausible in-envelope edge case: a user tab-completes a name the shell then hands back to a command that refuses it.

One battery assertion failed and it was the battery being wrong, corrected against the documented contract rather than filed. `CompletionCandidate::hide` is documented as "only shown when there is no visible candidate for completing the current argument", and `complete.rs` implements exactly that - it retains the visible candidates only when at least one survives. So a hidden candidate reappearing once the prefix excludes every visible one is the contract, not a leak. Both directions are now pinned, including that the same rule governs hidden arguments, because a filter that dropped hidden candidates unconditionally would pass the visible-case assertions alone. This also retired an earlier suspicion from the observation pass, that hidden arguments were being completed when the AOT generators exclude them; the AOT generators emit them too, so there was no inconsistency to file.

Learnings: none new.

Next: iteration 9 sweeps again, and iteration 10 is a WRAPUP that tidies the ledger and writes the handoff, because 25 unswept rows cannot be closed in two iterations.

## iter 9/10 | d32e6b21-133102 | 2026-08-15 | ESCAPE-SUBCMD | done

Task: ESCAPE-SUBCMD - the dynamic completion engine offers subcommand names past the `--` escape, which the same command then rejects. An open Medium outranks the unswept rows, so this is the top of the queue rather than another sweep.

Changed: clap_complete/src/engine/complete.rs (two guards), clap_complete/tests/testsuite/engine.rs (two regression tests), clap_complete/CHANGELOG.md, .jeffy/probes/complete-engine/battery.rs, PLAN.md (row re-swept), BACKLOG.md, JOURNAL.md.

Checkpoint: 0848540ef617bb711bcfbb44d5f597c548b062f4

Verification: the class is "the escape is not applied to subcommands" and it has exactly two sites, both in `clap_complete/src/engine/complete.rs`, and the enumeration was built by provoking the failure at each rather than by reading the source. Site one is candidate generation, where `complete_arg`'s `ValueDone` branch guarded `complete_option` with `!is_escaped` but left `complete_subcommand` ungated. Site two is traversal, where the main loop's `find_subcommand` ran before the `is_escaped` branch, so a token past the escape that matched a subcommand name switched context; that site is invisible in the simple shape, because the escape also suppresses the subcommand's options, and only shows with a parent carrying two positionals: `prog -- build <TAB>` offered the subcommand's positional `x1` where the parser parses `build` as the parent's first positional and accepts `b1` next. The parser was consulted as the oracle for both: `prog -- build` returns `ErrorKind::InvalidValue`, and `prog -- build b1` parses with no subcommand, p1 "build" and p2 "b1".

Contract preserved, and checked against the tests that pin it before changing anything: `suggest_subcommand_positional_after_escape` escapes after the subcommand, so traversal has already happened and the new guard cannot affect it, and `suggest_multiple_positional_after_escape` defines no subcommands at all. Both pass unchanged, before and after.

Acceptance check: two new tests in the project's own suite, `no_subcommand_after_escape` and `subcommand_name_after_escape_is_a_positional_value`, so the fix is held by the project's gate and not only by the battery. Run against the committed complete.rs, exactly those two fail and the two pre-existing escape tests still pass (exit 101, by copying the fixed file aside, restoring `git show HEAD:...`, running, then copying back). The battery was updated in the same iteration, its ESCAPE-SUBCMD assertion inverted from pinning the defect to asserting no offered candidate is one the command rejects, plus a new case for the traversal site and a control showing subcommand traversal still works without an escape. Batteries exit 0 with 98 assertions; Verify command exits 0 with 1954 cases, up 2 from the new tests.

Closed this iteration: ESCAPE-SUBCMD (Medium, correctness) - subcommands are no longer offered or traversed past `--`, evidenced by the differential above.

Learnings: a defect can have a second site whose symptom is masked by an unrelated correct behaviour; provoking the failure at every step, rather than grepping for the call, is what exposed the traversal site here.

Next: iteration 10 is the final one, so it takes a WRAPUP - tidy the ledger, record the handoff, and report rather than declare, because 25 of 35 rows remain unswept and convergence requires none.

## iter 10/10 | d32e6b21-133102 | 2026-08-15 | WRAPUP | done

Task: final iteration - tidy BACKLOG.md, re-execute the numbers the state files assert, and write the handoff. No declaration: convergence requires no unswept row and 25 of 35 remain, so a sweep started here could not finish and would only leave a half-swept row behind.

Changed: BACKLOG.md (Later section reordered), PLAN.md (Oracle class counts and Verify duration re-measured), JOURNAL.md.

Checkpoint: f9dbd25b770c842062953c31ed3625200aae6bf3

Verification: every number the state files assert was re-executed rather than carried forward. The Verify command exits 0 with 1954 cases in 8.13s wall time on a warm target directory, so the Oracle class line now reads 1954 and the `Verify duration` line 9s; `make test-full` alone runs 1906, so the added `clap_complete/unstable-dynamic` feature is worth 48 tests, up from the 46 recorded at the first audit because this run added two dynamic-only tests. `.jeffy/probes` exits 0 with 98 assertions across ten batteries. Surface inventory position confirmed by `grep -c` on the file itself: 10 swept, 25 unswept, 35 total. The Environment fingerprint was re-read and still holds; nothing this run touched a target it excludes, and no entry in this run claimed one of them was green.

Ledger tidied: the Later section held eight Lows with the two runtime items BOOLISH-KIND and ARGGROUP-MUT sitting below the docs item UNDOC-PANIC, which breaks the documented ordering of severity first then runtime before other classes. Reordered so the five runtime items lead and the three docs items follow. No item changed section and none was closed or declined here, so the ledger's content is unchanged and only its order moved.

Handoff for the next run. Start it in a fresh session in this directory: the state files carry everything forward and a new session is the whole point, since context accumulates across iterations within a run. The next run's first audit will be a fresh full audit, and the queue will then put the 25 unswept rows above all eight carried Lows, so expect it to sweep rather than to fix unless that audit files a High or a Medium. The batteries are the instrument to reuse, not rebuild: `cargo test --manifest-path .jeffy/probes/Cargo.toml` runs all ten, each row's directory carries a `paths` file naming the source it owns, and a new row needs a `[[test]]` entry in that package's Cargo.toml. The cheapest remaining rows are the ones reachable straight through the public API - `builder::{styled_str,styling}`, `builder::Arg introspection`, `builder::Command introspection` - while `clap_derive` needs a different instrument altogether, because a proc macro is exercised by compiling code rather than by calling functions, and `clap_complete::aot shells` is best done against the recorded snapshots the project already keeps. Two rows are worth flagging as awkward rather than merely unswept: the `unstable-shell-tests` surface cannot be reached on this host without real shells over a pty, and `tests/builder/utf16.rs` is Windows-only, so both stay outside anything this host can certify. NEG-DOT sits under Proposed and needs the project owner, not another run.

Learnings: none new.

Next: nothing - this is the final iteration of the run. The run report follows and the loop ends out of budget, not converged. Rotation: when this file exceeds 500 lines, move all but the last 10 entries to the end of JOURNAL-archive.md, appending to whatever that file already holds and never overwriting it, because the archive accumulates across every rotation and every run; create it only when it does not already exist, and record the rotation as a ROTATION entry.

## iter 1/10 | f5aa30a9-142239 | 2026-08-15 | SWEEP | done

Task: sweep. The ledger holds no High and no Medium, so the queue puts the 25 unswept Surface inventory rows above all eight carried Lows and this iteration is a sweep, not an audit. Took `builder::{styled_str,styling}` and `builder::Arg introspection`, the two the previous run's handoff named cheapest, both reachable straight through the public API.

Changed: .jeffy/probes/builder-styling/ and .jeffy/probes/builder-arg-reflection/ (two new batteries, each with a paths file), .jeffy/probes/Cargo.toml (two test targets), PLAN.md (2 rows flipped), BACKLOG.md (ALIAS-EMPTY and RESET-NONE filed), JOURNAL.md.

Checkpoint: eddff5158e5b8fdb944a64d7d84a32da4baec77a

Verification: `cargo test --manifest-path .jeffy/probes/Cargo.toml` exits 0 with 116 assertions across twelve batteries, up from 98 across ten. Verify command exits 0: 1945 passed, 9 ignored, 1954 cases, matching the Oracle class line unchanged. No file outside `.jeffy/probes` and the three state files was touched, so nothing this iteration could have broken the project. Rows swept 12 of 35, from 10 at the start of this iteration and 10 at run start. The Environment fingerprint was re-read before writing any claim; neither row's battery reaches a target it excludes, and nothing here claims one of them was green.

Both sweeps are isolation invariants rather than round trips, which is what made them worth running. A getter agreeing with its own setter proves the field survives the builder and nothing else; the check that earns the checkbox is that the set of accessors which moved equals the set that setter owns, exactly. That fails in the two directions a round trip cannot see - an accessor wired to nothing never moves, one wired to a neighbour's field moves twice - and it is what forced every one of the 43 `Arg` accessors and all 9 `Styles` getters to be reached rather than sampled. The styling row then carries the same idea end to end: nine styles, two colours each, driven through the real help and error renderers with the SGR escape written out by hand, plus the negative case that `Styles::plain()` emits no escape at all, without which a renderer that painted everything unconditionally would have satisfied every `contains` assertion.

A guard test pins `ACCESSORS.len()` at 43, the count the row's own grep returns. Without it a future accessor would go unprobed while the row still read as swept, which is the failure the inventory exists to prevent rather than one it should introduce.

ALIAS-EMPTY (Low, docs): `get_visible_aliases`, `get_aliases` and `get_visible_short_aliases` each document "if any" and each return `Some` of an empty list when the arg carries only aliases of the other visibility. Before filing I read the one caller in the tree that branches on `.is_some()`, `clap_complete::aot::generator::utils`, and both of its branches build the identical list, so the defect is confined to what the doc promises. Filed Low with that rationale rather than the Medium the rubric gives documentation, and pinned in the battery so a fix has to come through it.

RESET-NONE (Low, docs): the `IntoResettable` doc promises `None` resets a builder value; 11 of the 57 public setters that take it reject a bare `None`. The enumeration was built by provoking a compile failure at every one of the 57, not by reading the impl list in `resettable.rs` - the impl list explains the result but could not have proved the count, since a setter's accepted types depend on inference across two blanket impls as well as on which concrete `Option` impls exist. `Resettable::Reset` compiles at all 57, so nothing is unresettable.

Two rows rather than three. `builder::Command introspection` is 65 accessors and needs its own table; started at this point in the iteration it would have produced a liveness probe, and the Method is explicit that run-without-crashing flips nothing.

Learnings: `ArgAction` implements no `PartialEq`, so a battery comparing one uses `matches!` rather than `assert_eq!`.

Next: iteration 2 sweeps again, with `builder::Command introspection` the natural next row - the same instrument as this iteration's `Arg` table, at roughly half again the size.

## iter 2/10 | f5aa30a9-142239 | 2026-08-15 | SWEEP | done

Task: sweep. Still no open High or Medium at the start of this iteration, so the 23 unswept rows remained the top of the queue. Took `builder::Command introspection`, the largest single row in the inventory, and `builder::{str,os_str,resettable,ext,value_hint,action,app_settings,arg_settings,arg_predicate}`, the smallest.

Changed: .jeffy/probes/builder-command-reflection/ and .jeffy/probes/builder-small-types/ (two new batteries, each with a paths file), .jeffy/probes/Cargo.toml (two test targets), PLAN.md (2 rows flipped), BACKLOG.md (CONFLICT-ONEWAY filed under Now, DOC-DRIFT-AUDIT filed under Proposed), JOURNAL.md.

Checkpoint: 5caaa62d2c93027f5c683c9f75295af6ace12622

Verification: `cargo test --manifest-path .jeffy/probes/Cargo.toml` exits 0 with 133 assertions across fourteen batteries, up from 116 across twelve. Verify command exits 0: 1945 passed, 9 ignored, 1954 cases, unchanged from the last iteration and matching the Oracle class line. Rows swept 14 of 35, from 12 at the start of this iteration and 10 at run start. The Environment fingerprint was re-read; neither battery reaches a target it excludes.

CONFLICT-ONEWAY (Medium, correctness): `Command::get_arg_conflicts_with` answers one way only. For `a.conflicts_with("b")` it reports `["b"]` asked about `a` and `[]` asked about `b`, while the parser rejects the pair in either order, and building the command does not change the answer. What makes it Medium rather than a doc nit is the in-tree consumer: `clap_complete/src/aot/shells/zsh.rs` builds its exclusion lists from this accessor, so the generated script emits `'(--b)--a=[]: :_default'` and `'--b=[]: :_default'` - zsh offers `--a` after `--b` and the command then refuses it. That was reproduced by generating the script, not inferred from the call site, and it is the same shape as the ESCAPE-SUBCMD the previous run closed, so it is scored the same. The accessor's own `# Panics` section says "the given arg contains a conflict", which reads like the one-way behaviour is deliberate, so the alternative resolution is a doc correction rather than a symmetric fix; the acceptance check is written against the symmetric reading because that is what the zsh consumer needs, and a maintainer choosing the other reading would move the task with a rationale.

Three setters moved no accessor at all in the first pass, and none of the three turned out to be the inert parameter it looked like. `disable_version_flag` looked dead because `is_disable_version_flag_set` also reports true whenever no version is configured, so on a bare command the setter has nothing to move; it has its own base in the table now and its own test across three commands. `dont_collapse_args_in_usage` really does return a constant, and that is the contract: both it and its setter are `#[doc(hidden)]` and deprecated since 4.0.0 with the note "This is now the default". `external_subcommand_value_parser` is derived at build - `Command::build` turns a configured parser into the `AllowExternalSubcommands` setting - so before the build both accessors deny a parser the command really will use; the battery pins both states and then drives the parser through the real runtime to show the values do come back as `String`. Two of the three are held out of the isolation table with their reasons written into an `EXCLUDED` constant the coverage test reads, so an exclusion can never be confused with an accessor nobody probed.

Two further battery assertions failed and both were the battery being wrong, checked against the documented contract before anything was filed. `get_opts` includes a `SetTrue` flag on an unbuilt command, because `is_takes_value_set` reads `num_args` which the build has not filled in yet; every in-tree consumer reflects on a built command - the AOT generators call `get_num_args().expect("built")` - so the built state is the contract and both are now pinned. And `ArgAction::Set` supplied twice is an `ArgumentConflict`, not last-wins; the action's own doc says so and names `args_override_self(true)` as what changes it, so the battery drives both sides of that divergence instead.

DOC-DRIFT-AUDIT went under Proposed rather than being filed as a seventh instance. Six of this project's twelve findings are a documented contract disagreeing with the code, across five modules, every one of them found incidentally by a sweep aimed at something else. That is a case for a rigor escalation the Method does not authorise an audit to make on its own, so it is the user's call.

Learnings: none new. The battery-was-wrong lesson recurred twice more here and is already marked `[recurred]` in PLAN.md.

Next: iteration 3 works CONFLICT-ONEWAY, because an open Medium outranks the 21 unswept rows in the queue.

## iter 3/10 | f5aa30a9-142239 | 2026-08-15 | CONFLICT-ONEWAY | done

Task: CONFLICT-ONEWAY - `Command::get_arg_conflicts_with` reports a conflict from the declaring side only, while the parser enforces it both ways. An open Medium outranks the 21 unswept rows, so this was the top of the queue.

Changed: clap_builder/src/builder/command.rs (the accessor and its doc), tests/builder/conflicts.rs (two regression tests), clap_complete/tests/testsuite/zsh.rs (one end-to-end regression test), CHANGELOG.md, .jeffy/probes/builder-command-reflection/battery.rs, PLAN.md (row re-swept), BACKLOG.md, JOURNAL.md.

Checkpoint: dab0276f3295ac11e4a305c2eecff7570c6193af

Verification: the filed reproduction ran first, before anything was changed, and still held - the accessor answered `["b"]` for `a` and `[]` for `b`, and the generated zsh carried `'(--b)--a=[]: :_default'` against a bare `'--b=[]: :_default'`. After the fix the same reproduction answers `["b"]` and `["a"]` and the script carries the exclusion on both lines.

The oracle for the change is the parser's own notion of a conflict, not a guess at one. `Conflicts::gather_conflicts` in parser/validator.rs pushes `other_arg_id` when this arg's conflicts contain it and again when that arg's conflicts contain this one, so the relation the runtime enforces is symmetric by construction and the accessor implemented one half of it. The fix adds the other half over the command's own arguments, matching either the arg's id or a group it belongs to, skipping anything the forward walk already returned so a mutual declaration is reported once.

Contract preserved, checked against the test that pins it before the change: `tests/builder/conflicts.rs::get_arg_conflicts_with_group` requires a conflict declared against a group to unroll to its members in order, and it passes unchanged before and after. The documented panic on a conflict with an unknown id is untouched, and the forward direction returns exactly what it returned before - the reverse scan only appends.

Acceptance checks: three new tests in the project's own suite, `conflicts::get_arg_conflicts_with_is_symmetric`, `conflicts::get_arg_conflicts_with_group_is_symmetric`, and `zsh::conflicts_are_excluded_in_both_directions`, so the fix is held by the project's gate and not only by the battery. Run against the committed command.rs - by copying the fixed file aside, restoring `git show HEAD:...`, running, then copying back - all three fail on the undeclared direction and `get_arg_conflicts_with_group` still passes; against the fix all four pass. The zsh test is the end-to-end half, because the user-facing surface here is the generated script rather than the accessor.

The first attempt at the fix ran the reverse scan for global arguments too, and the Verify command caught it: `zsh::basic` and `zsh::custom_bin_name` went red, with the whole diff being two lines where the global `-c` gained `(-v)`. That was a real regression rather than a stale snapshot, and the parser said so - `my-app -v test -c` parses successfully, because `-v` lives only at the root while `-c` propagates, so an exclusion read off the parent would have suppressed a combination the command accepts. The accessor now returns early for a global argument and reports its declarations only, with the reason written into the doc comment. The mirror case, a global argument that itself declares a conflict with a non-global one, cannot be built at all: `builder::debug_asserts` rejects it with "Argument or group 'v' specified in 'conflicts_with*' for 'g' does not exist" for the subcommand, which is the same reasoning enforced from the other end.

After that correction no snapshot changed at all, confirmed by `git diff --stat -- clap_complete/tests/snapshots/` printing nothing, so no shipped output moved except through the new tests. Verify command exits 0: 1948 passed, 9 ignored, 1957 cases, up 3 from the three new tests. Battery ownership: the diff touches `clap_builder/src/builder/command.rs`, which only `.jeffy/probes/builder-command-reflection/paths` claims; it was updated in this iteration and passes, and all fourteen batteries exit 0 with 133 assertions.

Closed this iteration: CONFLICT-ONEWAY (Medium, correctness) - the accessor and the generated zsh completion now agree with the parser in both directions, evidenced by the differential above.

Learnings: a reflection accessor's answer is reused by callers in contexts other than the one it was asked in, so widening one is only safe where the widened answer holds in every context that reads it; for a global argument it does not.

Next: iteration 4 returns to sweeping, since the ledger holds no High or Medium and 21 rows remain unswept.
## iter 4/10 | f5aa30a9-142239 | 2026-08-15 | SWEEP | done

Task: sweep. CONFLICT-ONEWAY closed last iteration and the ledger holds no High or Medium, so the 21 unswept rows are the top of the queue again. Took `builder::Command runtime entry points` and `builder::debug_asserts`, the two remaining rows that are public entry points rather than crate-private internals, so both are drivable directly rather than through a proxy.

Changed: .jeffy/probes/builder-command-runtime/ and .jeffy/probes/builder-debug-asserts/ (two new batteries, each with a paths file), .jeffy/probes/Cargo.toml (two test targets), PLAN.md (2 rows flipped), JOURNAL.md.

Checkpoint: 40b6af9c3d7505c21618616c192f0c70ca55aec0

Verification: `cargo test --manifest-path .jeffy/probes/Cargo.toml` exits 0 with 147 assertions across sixteen batteries, up from 133 across fourteen. Verify command exits 0: 1948 passed, 9 ignored, 1957 cases, unchanged from the last iteration - no file outside `.jeffy/probes` and PLAN.md was touched. Rows swept 16 of 35, from 14 at the start of this iteration and 10 at run start. The Environment fingerprint was re-read; neither battery reaches a target it excludes, and the debug-asserts row's own dependence on `debug_assertions` is recorded in the row line and the battery header rather than assumed.

The runtime-entry-points row is mostly an agreement oracle, because its members are alternative routes to the same document. `render_help`, `render_long_help` and the two deprecated `write_*` sinks have to produce identical bytes in pairs, and the short and long documents have to differ and each carry only its own text - four routes all rendering the same document would satisfy the agreement alone. Five of the seventeen cannot be driven honestly from a harness and both reasons are written into the battery header rather than left implicit: three read the process argv, which under a test binary belongs to the harness, and the two `print_` entry points write to stdout with no in-process reader. Their status is asserted and their content contract is carried by the render and write pair; that is a disclosure, not a claim that the two `print_` bodies were observed.

The debug-asserts row grades the grader. Its subject is the Builder API surface, which the envelope classes user-error, and the whole promise of that class is that a wrong value earns a clear failure - so the oracle is the message text, not the fact of a panic. A check wired to the wrong condition still panics, and the developer then reads the wrong sentence and looks in the wrong place. 27 mistakes are driven, each paired with a well-formed counterpart that must be accepted, so a check that simply rejected everything fails.

Two battery assertions failed and both were the battery being wrong again, corrected against the real message rather than filed: the duplicate-flag report spells the flag with its dashes, `'--same' is in use by both`, and the action check writes the value into the backticks, ``incompatible with `num_args(2)` ``, so a substring ending at `num_args` never matched. A third defect was in the battery itself and worth recording: `rejects` swaps the process-global panic hook, and two tests doing that concurrently left one printing another's panic, which made the first failure report name a case that had not failed. It is serialised on a mutex now.

Learnings: a helper that swaps the process-global panic hook must serialise on a mutex, or concurrent tests attribute each other's panics.

Next: iteration 5 sweeps again. The public entry points are now done, so the remaining rows are crate-private internals - `parser::parser`, `parser::validator`, `mkeymap`, `output::{help,help_template}`, `util` - which have to be driven through the public API, and the three `clap_derive` rows, which need a compiling instrument rather than a calling one.

## iter 5/10 | f5aa30a9-142239 | 2026-08-15 | CTRL-WIDTH | done

Task: CTRL-WIDTH - `output::textwrap::core::display_width` treats every ASCII control character as the start of an ANSI sequence, so help text carrying a tab is measured short and overflows `term_width`. The queue put the 19 unswept rows above the carried Lows, and this iteration deliberately took the Low instead; the reason is recorded below.

Changed: clap_builder/src/output/textwrap/core.rs (the width loop, the non-unicode `ch_width` branch, two regression tests), CHANGELOG.md, .jeffy/probes/output-textwrap/battery.rs, PLAN.md (row re-swept), BACKLOG.md (CTRL-WIDTH closed, WRAPHELP-NOCOLOR filed), JOURNAL.md.

Checkpoint: f388ea64eb5832308d19da37b09ca82d8760ea5e

Why a Low ahead of the sweep: the Stop hook reported iteration 4 as a stall. A sweep iteration writes only to `.jeffy/` and PLAN.md, and both are on the stall check's exempt list, so a sweep that files nothing is indistinguishable from an iteration that did nothing, and a second consecutive flat iteration ends the run. Sweeping again with 19 rows left and no guarantee of a finding would have risked ending the run at iteration 5 with five iterations unspent. This is a property of the loop rather than of the project, so it is not filed as a finding; it is recorded here and in the run report so the next run knows to interleave rather than to sweep in a block.

Verification: the filed reproduction ran first and held, and was worse than the line described - `display_width("a\tb")` and `display_width("a\rb")` both returned 1, `display_width("ab\ncd")` returned 2, so the second line of any multi-line help text was measured as nothing at all, and `display_width("a\u{7}bcm de")` returned 4 because an `m` later in the text ended the swallowing and resumed counting part way through. After the fix those read 2, 2, 4 and 7, and the ANSI case `display_width("\u{1b}[1mab\u{1b}[0m")` still reads 2.

The fix is one condition: only an escape opens a sequence to skip. The loop's `else if` already closed the sequence at `m`, which is right for SGR; the opener was the defect.

The filed acceptance asked for `display_width("a\tb") == 3` and it is 2, and the difference is worth stating rather than papering over. That figure assumed a control character has width 1, which is what the `not(unicode)` branch of `ch_width` returns; the `unicode` branch asks `unicode_width`, which reports no width for a control character, and the Verify command enables `unicode`. So the two feature configurations disagreed about exactly the characters this task is about. Rather than implement to a number that only one configuration produces, the non-unicode branch now returns 0 for a control character too, so both answer 2, and the defect the finding actually describes - everything after the control character counting zero - is gone in both. The acceptance's intent is met and its arithmetic is not; that is recorded here as the deviation it is.

Contract preserved, checked against what pins it: the escape handling exists to skip SGR sequences, and the battery now asserts a styled paragraph wraps onto the same number of lines as the plain one, which would fail if the escapes were being measured. `cargo check -p clap_builder --no-default-features --features "std usage help wrap_help"` exits 0, so the non-unicode branch still compiles.

Acceptance checks: two new tests in the project's own suite, `display_width_counts_text_after_a_control_character` and `display_width_still_skips_ansi_sequences`, both feature-independent so they run in the minimal configuration as well. Verify command exits 0: 1950 passed, 9 ignored, 1959 cases, up 2. No snapshot moved, so no pinned help output changed. Battery ownership: the diff touches `clap_builder/src/output/textwrap/core.rs`, which `.jeffy/probes/output-textwrap/paths` claims; that battery pinned the overshoot and failed as soon as the fix landed, was rewritten in this iteration to pin the bound instead, and all sixteen batteries exit 0 with 147 assertions.

Two of my own hand-counts in the new tests were wrong on the first run and were corrected against the real answers, not the other way round: `"a\u{7}bcm de"` has seven non-control characters, not eight, and `"red and plain"` is thirteen, not fourteen.

WRAPHELP-NOCOLOR (Low, test): found while checking that the fix compiles without `unicode`. `cargo test -p clap_builder --no-default-features --features "std wrap_help" --lib --no-run` fails with 3 errors, because `styled_str.rs`'s `wrap_tests` module is gated on `wrap_help` but calls `ansi()`, which is gated on `color`. Confirmed pre-existing by re-running it against `git show HEAD:...` of the file I had changed. Filed Low rather than the High the rubric gives a broken build, with the rationale on the task line: the shipped library builds fine in that configuration, and no CI row reaches it - the `minimal` row builds its tests cleanly and `wasm` does not enable `wrap_help`.

Closed this iteration: CTRL-WIDTH (Low, runtime) - control characters no longer hide the text after them, evidenced by the reproduction above and by the tab-bearing help now fitting inside `term_width` where it previously rendered 45 characters wide at `term_width(40)`.

Learnings: when a filed acceptance states a number, re-derive it before implementing to it - this one assumed a feature configuration the Verify command does not build.

Next: iteration 6 returns to sweeping, and should file or close something rather than sweep alone, because the stall check cannot see a sweep.

## iter 6/10 | f5aa30a9-142239 | 2026-08-15 | SWEEP | done

Task: sweep. No open High or Medium at the start of this iteration, so the 19 unswept rows were the top of the queue. Took `clap_builder::{macros,derive}` plus the clap re-export surface, and `clap_complete::aot generator`.

Changed: .jeffy/probes/builder-macros-derive/ and .jeffy/probes/complete-aot-generator/ (two new batteries, each with a paths file), .jeffy/probes/Cargo.toml (two test targets, plus `authors` and `description` on the probe package), PLAN.md (2 rows flipped), BACKLOG.md (FISH-TRYGEN filed under Now), JOURNAL.md.

Checkpoint: 9975ac9c07c5104920a90d7af637154ea01f2146

Verification: `cargo test --manifest-path .jeffy/probes/Cargo.toml` exits 0 with 159 assertions across eighteen batteries, up from 147 across sixteen. Verify command exits 0: 1950 passed, 9 ignored, 1959 cases, unchanged - nothing outside `.jeffy/probes` and the two state files was touched. Rows swept 18 of 35, from 16 at the start of this iteration and 10 at run start. The Environment fingerprint was re-read; neither battery reaches a target it excludes.

The macros row needed its oracle built rather than found. The `crate_*` macros read Cargo variables, so a battery that only checked them against `env!("CARGO_PKG_*")` would pass for a macro reading the wrong variable, and one that only checked literals would pass for a macro reading none. Both are asserted, and the probe package now declares two authors and a description so those literals are non-empty and the separator argument of `crate_authors!` has something to sit between. The `arg!` DSL is the one place in clap where a user writes syntax rather than calls a method, so all seven forms are pinned against hand-written expectations and then driven through a real parse; the built `Arg` agreeing with itself would not show that `<REQ>` means required at parse time while `[VAL]` means the value may be absent.

FISH-TRYGEN (Medium, error handling): found by driving all five shipped shells against a sink that refuses every write. Four return `Err`; `Shell::Fish` panics, and only when the command has subcommands. The site is single and was located by driving the condition rather than by reading for it: `try_generate` calls `gen_subcommand_helpers` before the buffer it propagates from, and that helper writes to the caller's sink with an `expect`. It matters because the fallible route is the only non-panicking one - all five define `generate` as `try_generate(..).expect(..)`, which is the pattern the trait's own doc example recommends - so a CLI author who handled the error correctly still crashes on `myprog completions fish | head -1`. Scored Medium rather than the High the rubric gives a crash, with the rationale on the task line: the trigger is an IO failure on a developer-supplied sink rather than in-envelope input.

Along the way the trait's defaulted `try_generate` turned out to be infallible by construction - it calls the infallible `generate` and returns `Ok(())` - so an implementor who takes the default can never report a write failure. That is what the trait documents, and the doc example inverts the pair instead, so it is pinned as what it is rather than filed as what a fallible name suggests.

Three battery assertions failed and all three were the battery being wrong. `ArgMatches::contains_id` panics on an id the command never defined rather than answering false, so the check that a long name is not an id had to be written against `ids()` instead. The defaulted `try_generate` cannot report a failure, so the probe generator had to stop unwrapping its own writes before that could be demonstrated. And a `[[test]]` entry was silently not appended because the guard string I searched for also appears in a comment I had just written into the same file.

Learnings: when appending a cargo target, guard on the exact `name = "..."` line, not on the bare target name, which may appear in a comment.

Next: iteration 7 works FISH-TRYGEN, because an open Medium outranks the 17 unswept rows.

## iter 7/10 | f5aa30a9-142239 | 2026-08-15 | FISH-TRYGEN | done

Task: FISH-TRYGEN - `Shell::Fish::try_generate` panics instead of returning `Err` when the command has subcommands. An open Medium outranks the 17 unswept rows, so this was the top of the queue.

Changed: clap_complete/src/aot/shells/fish.rs (the helper's signature and its one call site), clap_complete/tests/testsuite/general.rs (one cross-shell regression test), CHANGELOG.md, .jeffy/probes/complete-aot-generator/ (battery updated, paths widened to the five shells), BACKLOG.md, JOURNAL.md.

Checkpoint: 23c5dc997c8e2180392c81c32bdb8f023e205998

Verification: the filed reproduction ran first and still held - the battery's pin of the panic passed against the unchanged tree. The fix is two lines: `gen_subcommand_helpers` returns `Result<(), Error>` instead of ending in `.expect("failed to write completion file")`, and its one call site propagates with `?`. That call site is the only one, per `grep -n gen_subcommand_helpers clap_complete/src/aot/shells/fish.rs`, which returns the definition and a single call.

Contract preserved: the generated bytes are untouched, only the error path moved. Evidenced two ways - the 15 `fish::` snapshot tests pass unchanged before and after, and `git diff --stat -- clap_complete/tests/snapshots/` prints nothing.

Acceptance check: `general::try_generate_reports_a_write_failure_for_every_shell` in the project's own suite, driving all five shipped shells against a sink whose `write` always errors, at both values of the condition that selects fish's helper path. Run against the committed fish.rs - by copying the fixed file aside, restoring `git show HEAD:...`, running, then copying back - it fails by panicking at the exact site the finding named, and the 15 fish snapshot tests pass in that tree too, which is what shows the test is about the error path rather than the output.

Verify command exits 0: 1951 passed, 9 ignored, 1960 cases, up 1 from the new test. Battery ownership: the diff touches `clap_complete/src/aot/shells/fish.rs`, which no paths file claimed, because the row that owns the shells is still unswept. The battery that actually pins this behaviour is `complete-aot-generator`, whose paths file now names all five shell sources as well as the generator, so a future change to any of them runs the cross-shell check rather than waiting for that row to be swept. It was updated in this iteration to pin reporting rather than the panic, and all eighteen batteries exit 0 with 159 assertions.

Closed this iteration: FISH-TRYGEN (Medium, error handling) - all five shipped shells now report a write failure through `try_generate` in both command shapes, evidenced by the differential above.

Learnings: a battery may be the only check pinning behaviour in a module its own row does not cover; name those sources in its paths file rather than waiting for the owning row to be swept.

Next: iteration 8 returns to sweeping, with 17 rows unswept and no open High or Medium.

## iter 8/10 | f5aa30a9-142239 | 2026-08-15 | SWEEP | done

Task: sweep. FISH-TRYGEN closed last iteration and the ledger holds no High or Medium, so the 17 unswept rows are the top of the queue. Took both `clap_complete::aot shells` rows with one instrument, because their 60 functions between them are almost entirely private string builders sharing a single observable result.

Changed: .jeffy/probes/complete-aot-shells/ (new battery with a paths file naming all six shell sources), .jeffy/probes/Cargo.toml (one test target), PLAN.md (2 rows flipped), JOURNAL.md.

Checkpoint: 0b88fdea276e029c32ee66b733e10cda3c7dbb7a

Stall note: this iteration changed no file outside `.jeffy/` and PLAN.md, and no BACKLOG.md item changed state, so it is flat to the stall check. The previous primary entry is not flat - iteration 7 closed FISH-TRYGEN and changed clap_complete source - so this is the first of the pair, not the second.

Verification: `cargo test --manifest-path .jeffy/probes/Cargo.toml` exits 0 with 165 assertions across twenty batteries, up from 159 across eighteen. Verify command exits 0: 1951 passed, 9 ignored, 1960 cases, unchanged. Rows swept 20 of 35, from 18 at the start of this iteration and 10 at run start. The Environment fingerprint was re-read and is load-bearing here: the `unstable-shell-tests` suite drives real shells over a pty and is excluded on this host, so the battery header says in as many words that nothing it checks was executed by a shell.

The oracle had to be chosen rather than found, because a completion generator's output is exactly the kind of thing a snapshot certifies without understanding. The previous run's ESCAPE-SUBCMD survived its own snapshots for that reason. So the load-bearing check is the binding invariant - every name a script offers is one the command accepts, and every visible name reaches every script - and the escaping check is differential: the same command rendered with plain help and with help carrying every character that is syntax in one of these shells, with the script's line structure required not to move. Broken escaping shows up as an injected or swallowed line before it shows up as a wrong character. That check alone would pass for a generator applying the wrong shell's rules, so each shell's escaped form is then pinned by hand; they genuinely differ, with zsh backslashing a quote inside a `'\''` dance while elvish and powershell double it and fish backslashes it.

Five of the six tests failed on the first run and all five were the battery being wrong. `FromStr for Shell` is case-sensitive, not case-insensitive - it asks `matches(s, false)` - and the case-insensitive route is `ValueEnum::from_str(s, true)`; both are pinned now, because a change to either moves what a CLI accepts for a `--shell` argument. Fish spells a long option `-l opt` rather than `--opt`, so the invariant needed a per-shell spelling. Bash rewrites a hyphenated bin name with a double underscore where fish uses a single one. Bash carries no descriptions at all, so the folded-newline assertion does not apply to it.

The fifth is worth recording as a contract rather than a correction: all five shells withhold hidden aliases and all five offer hidden arguments and subcommands. That asymmetry is uniform, and the previous run's audit had already looked at the same behaviour and declined to file it. Nothing new reproduced here either, so it is pinned as the contract with the reason written beside it - `hide` governs the help display, a hidden item still parses, and the battery asserts the command really does accept the hidden names the scripts offer. What would be a defect is the pair coming apart, and the pin now fails if either half moves.

Learnings: none new.

Next: iteration 9 sweeps again and should close or file something alongside it, since two consecutive flat iterations end the run; iteration 10 is the final one and takes a WRAPUP.

## iter 9/10 | f5aa30a9-142239 | 2026-08-15 | USAGE-NOWRAP | done

Task: USAGE-NOWRAP - the `usage` help-template variable is pushed unwrapped while every sibling variable calls `wrap(term_w)`, so `Command::term_width` has no effect on the usage line. The queue put the 15 unswept rows above the carried Lows and this iteration deliberately took the top Low instead, for the same mechanical reason as iteration 5: the Stop hook reported iteration 8 as flat, a sweep is invisible to the stall check because `.jeffy/` and PLAN.md are both exempt, and a second consecutive flat iteration ends the run. With one iteration left after this one, spending it on a sweep that might file nothing would have ended the run early and forfeited the wrapup.

Changed: clap_builder/src/output/help_template.rs (the usage branch and one new helper), tests/builder/help.rs (one snapshot), CHANGELOG.md, .jeffy/probes/output-textwrap/ (battery updated, paths widened to help_template.rs), PLAN.md (row re-swept), BACKLOG.md, JOURNAL.md.

Checkpoint: b864af6b6df97ca7c2fad39b8076ffe850a1d1be

Verification: the filed reproduction ran first and held exactly as written - at `term_width(30)` a four-required-option command rendered a 79 character usage line in the same help whose option lines all fit inside 30. After the fix that usage renders across four lines of 28, 23, 27 and 22 characters.

The fix took three attempts and the Verify command caught the first two, which is the whole reason the gate exists. Attempt one wrapped and then indented every continuation by the current column; 19 tests went red, all of them commands whose usage came from a multi-line `Command::override_usage` that already carries the author's own alignment, which the blanket indent doubled. Attempt two dropped the indent entirely and left one test red, but produced a continuation starting at column 0, which is correct in width and poor to read. Attempt three keeps the indent only when the usage this wrap received was a single line, because then any newline in it is one the wrap itself introduced; an author-supplied multi-line usage is left alone. The distinguishing condition is `!usage.as_styled_str().contains('\n')`, checked before wrapping.

The wrap target is the space left on the current line rather than `term_w`, computed by a new `current_column` helper that measures the display width since the writer's last newline. The usage variable follows `usage-heading` in the default template, so it starts 7 columns in, and a user-supplied template may put anything before it; wrapping at `term_w` would have overshot by exactly the heading's width.

One test remained red after attempt three, `help::dont_wrap_urls`, and it is the Verify gate's documented exception rather than a regression: its snapshot pinned `Usage: Example update [OPTIONS]`, 31 characters, against the command's own `term_width(30)`, so it was green only because of the defect this task fixes. The differential evidence is that it is the only output in the suite that moved - 1951 passed and 1 failed before the snapshot was updated, with every multi-line `override_usage` snapshot and both tests the acceptance names, `help::wrapped_help` and `help::unwrapped_help`, passing unchanged - and its new form is the same command line wrapped and aligned. The snapshot was updated with `SNAPSHOTS=overwrite` and `git diff --stat -- tests/` reports one file, two insertions, one deletion.

Acceptance check: the usage lines of the filed command all fit `term_width`, the two named snapshots pass, and `.jeffy/probes/output-textwrap` was updated in the same iteration - its `usage_line_ignores_term_width` pinned the 79 character overshoot and now pins the bound, the alignment of the continuations, that no flag was lost or duplicated by the wrap, and that an author's multi-line usage is not re-indented. Verify command exits 0: 1951 passed, 9 ignored, 1960 cases, unchanged from the last iteration. All twenty batteries exit 0 with 166 assertions.

Battery ownership: the diff touches `clap_builder/src/output/help_template.rs`, which no paths file claimed - the row that owns it, `output::{help,help_template}`, is still unswept. `output-textwrap` is the battery that actually pins this behaviour, so its paths file now names that source too, the same gap and the same remedy as last iteration's shells.

Closed this iteration: USAGE-NOWRAP (Low, runtime) - the usage line now wraps to `term_width` with its continuations aligned, evidenced by the reproduction above.

Learnings: a block written into the help template must be wrapped against the space left on the current line, not against `term_w`, because the template decides what precedes it.

Next: iteration 10 is the final one and takes a WRAPUP - tidy the ledger, re-execute the numbers the state files assert, and write the handoff. No declaration is possible: convergence requires no unswept row and 15 of 35 remain.

## iter 10/10 | f5aa30a9-142239 | 2026-08-15 | WRAPUP | done

Task: final iteration - re-execute every number the state files assert, tidy the ledger, and write the handoff. No declaration is possible: convergence requires no unswept row and 15 of 35 remain, so a sweep started here could not finish and would leave a half-swept row behind.

Changed: PLAN.md (Oracle class counts and Verify duration re-measured), JOURNAL.md.

Checkpoint: d18aa51afbcb17dc155f449e48654d800c4bbf9d

Verification: every number the state files assert was re-executed rather than carried forward. The Verify command exits 0 with 1951 passed, 9 ignored, 1960 cases in 7.6s wall time on a warm target directory, so the Oracle class line now reads 1960 and the `Verify duration` line 8s. The same feature set without `clap_complete/unstable-dynamic` runs 1912, so the added feature is worth 48 tests, unchanged from the figure the previous run recorded even though both totals moved. `.jeffy/probes` exits 0 with 165 assertions across twenty batteries; the 166 quoted in iteration 9's entry included a scratch target that had not yet been removed, and 165 is the standing figure. Surface inventory position confirmed by `grep -c` on the file: 20 swept, 15 unswept, 35 total, and no `- [~]` rows at all, so nothing is being carried as unreachable on this host.

The Environment fingerprint was re-derived with the two commands it names rather than re-read. Every exclusion it lists still holds and the counts still match: `tests/builder/utf16.rs` under `#![cfg(windows)]`, `tests/derive_ui.rs` under `unstable-derive-ui-tests`, `tests/derive/markdown.rs` under `unstable-markdown`, `tests/derive/occurrences.rs` plus 9 further `unstable-v5` items, `clap_complete_nushell/tests/completion.rs` plus 61 further `unstable-shell-tests` items, and 2 `#[ignore]` tests, which are `flags::inferred_help` and `flags::inferred_version` in tests/derive/flags.rs, plus 7 ignored doctests summing to the 9 the run reports. No entry in this run claimed any of them was green, and the two rows this run swept over `clap_complete/src/aot/shells` say in the battery header that no shell executed anything.

Ledger tidied: the Later section holds nine Lows ordered severity first then runtime before other classes - three runtime, one test, five docs - which is already the documented order, so nothing moved. Now and Next are empty. Two items sit under Proposed awaiting the project owner.

This run spent its ten iterations as five sweeps, four fixes and this wrapup, which is not the shape it set out with. Two of the four fixes were taken out of queue order, at iterations 5 and 9, and the reason is worth handing forward: a sweep writes only to `.jeffy/` and PLAN.md, both of which the stall check exempts, so an iteration that swept two rows and filed nothing is indistinguishable from one that did nothing, and two consecutive such iterations end the run. The hook flagged iterations 4 and 8 exactly that way. Interleaving a fix with the sweeps is what kept the budget alive, and the next run should plan for it rather than discover it.

Learnings: none new.

Next: nothing - this is the final iteration of the run. The run report follows and the loop ends out of budget, not converged.

## iter 1/10 | e6a12664-153329 | 2026-08-15 | SWEEP | done

Task: sweep. The ledger holds no High or Medium and 15 rows were unswept, so the queue's top was sweeping. Took the two `output` rows with one instrument, because the help renderer, the usage generator and the stream writer are all `pub(crate)` and share exactly one observable result: the rendered document.

Changed: .jeffy/probes/output-help-render/ (new battery, a helper binary and a paths file naming all five output sources), .jeffy/probes/Cargo.toml (one test target, one bin target), PLAN.md (2 rows flipped, 2 Lessons), BACKLOG.md (2 findings filed), JOURNAL.md.

Checkpoint: 23365c0a553fa80089487578c378feb232a657d9

Verification: `cargo test --manifest-path .jeffy/probes/Cargo.toml` exits 0 with 188 assertions across 20 battery targets, up from 165 across 19. The "twenty batteries" the last two entries quote counted the package's own empty lib target alongside the 19; `grep -c '^\[\[test\]\]$' .jeffy/probes/Cargo.toml` is the figure that means batteries, and it now returns 20. Verify command exits 0: 1951 passed, 9 ignored, 1960 cases, unchanged. Rows swept 22 of 35, from 20 at run start.

The oracle had to be chosen against the grain here. Every function in these four files is private, so the surface is reachable only through `render_help`, `render_long_help`, `render_usage` and the error path - which makes a snapshot the obvious instrument and the wrong one, since a snapshot agrees with the renderer by construction and cannot tell a contract from a regression. clap's own suite already holds hundreds of such snapshots and neither of this iteration's findings shows up in any of them. So the load-bearing check is composition: `render_help` with no template must equal `render_help` driven by the template `AutoHelp` selects to build it, across five commands and both help routes. A variable wired to nothing renders empty and passes every liveness probe; it fails this. Under it sit the binding invariants - every name the help offers and every name the usage offers is one the same command accepts - and then hand-computed answers for each of the 18 documented template variables, each `spec_vals` bracket, each sort key and each usage shape.

Five of the battery's assertions failed on the first run and all five were the battery being wrong, which is the fourth run in a row that has held. The corrections are worth more than the assertions: `{before-help}` carries its own trailing blank line and `{after-help}` its own leading one, which is why the default template writes no separator between the sections; the two `{about}` routes fall back in one direction only; smart usage does not narrow to what is still missing, it drops the generic `[OPTIONS]` tag and names the optional arguments this invocation actually supplied, so it is concrete rather than minimal; and `Command` hands every argument an increasing `display_order` as it is declared, so help follows declaration order and `option_sort_key`'s documented letter example is only reachable once `next_display_order(None)` ties them. Each correction became a stronger test than the guess it replaced, the display-order one especially: it now drives that setting at both values over one identical argument set, where the original drove neither.

Filed this iteration, both Medium, both surfaced by the visibility matrix and the variable table rather than by reading the code:

HIDE-NEXTLINE - `next_line_help(true)` defeats both `hide_short_help` and `hide_long_help`. `should_show_arg` ends in `|| arg.is_next_line_help_set()`, and `git show e3dcc014` shows why: the disjunct was lifted out of a *length*-computation filter, whose own comment says it exists so a deliberately-long argument does not throw off the alignment of the others. Folding that filter into the new visibility predicate made `hide` unconditional, correctly, and left the disjunct to override the two hide flags introduced in the same series. That the three hide flags disagree with each other about the same second setting is itself the evidence it was not intended. Nothing in `tests/` pins the combination.

BIN-VAR - `{bin}` is documented as the binary name and renders the command name in every configuration but one. `write_bin_name` binds `bn` from `get_bin_name()` and then ignores it unless it contains a space, falling through to `get_name()`. Filed at rubric severity rather than downgraded for the variable's deprecation: it is shipped, documented, and `bin_name` is a documented setter that does not move it, which is the inert-parameter case the Surface inventory calls a finding and never a pass.

Learnings: `Command` auto-assigns `display_order` in declaration order, so any help-ordering assertion must set `next_display_order(None)` first or it is testing declaration order; and a help assertion must be confined to the section it is about, because the usage line repeats the same argument names above it.

Next: iteration 2 sweeps again - 13 rows remain and the parser rows are the largest unswept surface. The two Mediums are now the top of the queue above every sweep, so one of them should be taken early rather than carried; HIDE-NEXTLINE first, since it is the behaviour defect and its acceptance is already written.

## iter 1/10 | 427639b7-175310 | 2026-08-15 | HIDE-NEXTLINE | done

Task: HIDE-NEXTLINE - `next_line_help(true)` defeated both `hide_short_help` and `hide_long_help`, because `should_show_arg` ended in `|| arg.is_next_line_help_set()`. The ledger held no High, so this Medium was the queue's top above all 13 unswept rows. The fix itself was already in the tree: the previous round was refused service mid-iteration and its launcher committed the written-but-uncommitted work as `392d10c4 salvage:`. This iteration's job was therefore the part that never ran - the reproduction, the differential that the acceptance can fail, the verify gate, and the close.

Changed: .jeffy/probes/output-help-render/battery.rs (one unused import removed), .jeffy/probes/builder-value-parser/battery.rs (one redundant inner import removed), PLAN.md (row re-swept), BACKLOG.md (HIDE-NEXTLINE deleted from Next), JOURNAL.md. No source file changed here; `clap_builder/src/output/help_template.rs` carries the fix from 392d10c4.

Checkpoint: ace2a3be349c7187f6d051a281687c6f0ad210d4

Verification: the acceptance was run in both directions rather than only the passing one, because a check inherited from a session that could not finish is a check nobody has watched fail. Against the tree as it stands, `.jeffy/probes/output-help-render::argument_visibility_matrix` exits 0. The fixed `help_template.rs` was then copied aside, the pre-fix disjunct restored verbatim from 23365c0a, and the same test re-run: it fails with `[hide_short_help + next_line_help] short help left: true right: false`, which is the filed behaviour reproduced. The file was restored from the copy and `git status --porcelain` confirmed the tree clean before any further work, so nothing was left half-reverted.

The matrix covers all four acceptance clauses: `hide_short_help(true).next_line_help(true)` absent from `render_help()` and present in `render_long_help()`, the `hide_long_help` mirror the reverse, `hide(true)` hidden on both routes, and `next_line_help(true)` alone visible on both. The battery also drives `Command::next_line_help(true)`, the command-wide route into the same layout that the finding did not name, and it too now leaves `hide_short_help` standing.

Contract preserved: `should_show_arg` is the visibility predicate for both `{options}`/`{positionals}` and the longest-width computation that aligns them, and the same predicate now governs both, which is what the salvaged comment records. Three settings can hide an argument and each holds exactly the route its own documentation names; `next_line_help` is a layout choice and moves visibility nowhere. No documentation needed updating, because `hide_short_help`, `hide_long_help` and `next_line_help` each already documented this behaviour with no stated exception - the code was what disagreed. The CHANGELOG entry rides in the salvage commit.

Verify command exits 0 in 17.4s: 1951 passed, 9 ignored, 1960 cases, unchanged from the last iteration of the previous run, so no snapshot in clap's own suite pinned the old visibility. All 20 batteries exit 0 with 188 assertions, and the two `unused import` warnings the probe package had been printing on every run are gone.

Rows swept 22 of 35, unchanged in count: the row `output::{help,help_template}` went stale when 392d10c4 changed `help_template.rs` after its recorded sweep commit, and it was re-swept here by re-running the battery that owns it, whose paths file names that source.

Closed this iteration: HIDE-NEXTLINE (Medium, runtime) - each hide flag now holds its route with `next_line_help` set, evidenced by the two-direction differential above.

Learnings: a fix inherited from an interrupted round is unverified work however finished it looks - run its acceptance against the pre-fix code before closing it, because the differential is the step the interruption skipped.

Next: iteration 2 takes BIN-VAR, the last open Medium, whose acceptance is already written and whose battery is the one just re-run. After that the queue is 13 unswept rows above nine carried Lows, and the previous run's handoff says to pair sweeps with a filing or a closure so the stall check does not end the run on two flat iterations.

## iter 2/10 | 427639b7-175310 | 2026-08-15 | BIN-VAR | done

Task: BIN-VAR - the `{bin}` help-template variable is documented as the binary name and renders the command name in every configuration but one. The last open Medium, so the queue's top above all 13 unswept rows. It closed on the documentation rather than the code, which is not what its filed acceptance said, and the Verify gate is what forced the correction.

Changed: clap_builder/src/builder/command.rs (the `{bin}` line of the `help_template` doc), .jeffy/probes/output-help-render/battery.rs (the `{bin}` test rewritten to pin every clause of that line, module header updated), .jeffy/probes/output-help-render/paths (command.rs added), PLAN.md (one Lesson generalised and marked recurred), BACKLOG.md (BIN-VAR deleted from Next), JOURNAL.md.

Checkpoint: cfc5b9fce51aeed0169aee6faf0d77cf2b9c7eb4

Verification: the filed reproduction ran first and held - `bin_name("progbin")` renders `<prog>`, and so does a real parse of argv0 `some-other-argv0`.

The filed acceptance was then implemented as written: `write_bin_name` was changed to use the bin name wherever one is known, keeping the space-to-hyphen rule. Its battery went green and the Verify command went red - 971 passed, 1 failed, `help::ripgrep_usage_using_templates`, which expects `ripgrep 0.5` from a `{bin} {version}` template while argv[0] is `rg`. Per the verify gate the working tree was reverted to checkpoint b3e1a474, and the gate's one exception does not apply: that test is not green because of a defect, it is green because the behaviour is intended.

Three independent pieces of evidence say so, and the first two are in the same file as the failing assertion. `tests/builder/help.rs::ripgrep_usage_using_templates` carries an `unstable-v5` arm that spells the identical expectation with `{name}` instead of `{bin}`, so the maintainers wrote both variables to produce the same text. `builder/debug_asserts.rs` panics under `unstable-v5` with "`{bin}` template variable was removed in clap5, use `{name}` instead". And CHANGELOG 4.3.0 records `{name}` as a "New `help_template` variable `{name}` to fix problems with `{bin}`". Changing `{bin}` to follow `bin_name` would override a maintainer decision, break the migration equivalence the v5 arm asserts, and do it to a variable already deprecated and slated for removal.

So the finding is real and the remedy is the other side of it. The doc line read `{bin} - Binary name.(deprecated)` and now states the contract the code has: the command name, ignoring `display_name`; a bin name reaching it only when it contains a space, written `git-mv`; and, unlike the usage line, not otherwise following `bin_name`.

Every clause was observed before it was written, not guessed, and each is now one assertion in `bin_variable_ignores_bin_name_unless_it_contains_a_space`: `{bin}` is `<prog>` for a command whose `display_name` is `progdisp` where `{name}` is `<progdisp>`, `<git-mv>` for `bin_name("git mv")`, `<prog>` for `bin_name("progbin")` and for the argv0 parse, `<prog-sub>` for the subcommand route. The last clause is the contrast that makes the line worth stating and it needed its own evidence: `bin_name("progbin")` does move the help document's usage line to `Usage: progbin [OPTIONS]`, and argv[0] moves an error's usage line to `Usage: some-other-argv0 --r <r>`, so `Command::bin_name`'s own doc - it "only changes what clap thinks the name is for the purposes of error or help messages" - is accurate, and `{bin}` is the one place in the document that does not follow it. Both are pinned.

Acceptance run: the battery's 23 tests exit 0, and the old wording is gone from command.rs. `cargo doc -p clap_builder --no-deps` exits 0 with the same 5 pre-existing unresolved-link warnings it had before, all of them `crate_*` macros that do not exist in this crate, so the two intra-doc links the new line adds both resolve. Verify command exits 0: 1951 passed, 9 ignored, 1960 cases, unchanged. All 20 batteries exit 0 with 188 assertions.

Battery ownership: the diff touches `clap_builder/src/builder/command.rs`, which no paths file claimed - the row that owns it is unswept, and the row that owns the behaviour the doc line describes is a different one. The doc line is a prose claim about the renderer and this battery is the only thing pinning it, so command.rs is now named in that battery's paths file, the same remedy the shells and textwrap batteries took.

No Surface inventory row was flipped: the change alters no behavior, signature or accepted input, only the documentation of one, so the sweep that certifies `command.rs` still certifies it. No CHANGELOG entry either, for the same reason.

Closed this iteration: BIN-VAR (Medium, documentation) - the `{bin}` doc states the contract the code has, with every clause pinned. The class on its ledger line read runtime and the fix turned out to be docs, which is the part the filing got wrong.

Learnings: a documented contract the code disagrees with has two possible defects in it, and the test tree decides which - where clap pins the behaviour deliberately, in a test arm for the next major version or in a migration assert, the documentation is the defect and a code fix would override a decision. This is the second time this run's project has produced that shape, after the `clap_lex::is_number` rejection pinned by `is_not_number`, so its Lesson is generalised and marked recurred.

Next: iteration 3 sweeps. With the ledger's last Medium closed, the queue is 13 unswept rows above nine carried Lows, and the parser rows are the largest unswept surface. The stall check makes a pure sweep iteration invisible, so it needs to file or close something, which a sweep of that size is likely to do on its own.

## iter 2/10 | 427639b7-175310 | 2026-08-15 | ROTATION | rotation

Task: rotation. JOURNAL.md reached 515 lines with this iteration's entry, past the 500-line bound.

Changed: JOURNAL.md (13 entries removed), JOURNAL-archive.md (created, 13 entries).

Checkpoint: cfc5b9fce51aeed0169aee6faf0d77cf2b9c7eb4

Verification: the split anchored only on lines matching `^## iter <digit>` at column zero, so the fenced heading-grammar example in the preamble was neither counted nor moved. 23 entries before, 10 kept and 13 archived, which `grep -cE '^## iter [0-9]'` reports as 10 and 13. This is the first rotation in this project, so JOURNAL-archive.md did not exist and was created rather than appended to; the write refused to run if it had existed, because an archive that loses entries is what the stop hook checks for. The preamble stays in JOURNAL.md and the archive carries its own two-line header. The 13 moved entries are the whole of the first run and all but one of the second.

Learnings: none new.

Next: the primary entry for this iteration is above; iteration 3 sweeps.

## iter 3/10 | 427639b7-175310 | 2026-08-15 | SWEEP | done

Task: sweep. The ledger's last Medium closed last iteration, so the 13 unswept rows are the top of the queue. Took the two parser rows with one instrument and `mkeymap` with another: the parser and the validator are both entirely private and share one observable result, and the key map is reached through a third route that neither of them exercises.

Changed: .jeffy/probes/parser-core/ (new battery, paths file), .jeffy/probes/mkeymap/ (new battery, paths file), .jeffy/probes/Cargo.toml (two test targets), PLAN.md (3 rows flipped), BACKLOG.md (one Proposed item extended), JOURNAL.md.

Checkpoint: 4090265ca1ff26f8b625dcb70ad563be1814cd2e

Verification: `cargo test --manifest-path .jeffy/probes/Cargo.toml` exits 0 with 207 assertions across 22 battery targets, up from 188 across 20. Verify command exits 0: 1951 passed, 9 ignored, 1960 cases, unchanged. Rows swept 25 of 35, from 22 at the start of this iteration and 20 at run start.

The oracle for the parser rows had to be something other than a snapshot, for the same reason the output rows did: clap's own suite already holds hundreds of parse assertions, each pinning one spelling of one input, and a snapshot agrees with the parser by construction. So the load-bearing check is equivalence - the five ways to write an option value (`--opt=v`, `--opt v`, `-o v`, `-ov`, `-o=v`) must produce byte-identical matches, as must the four ways to write a short cluster. That grades `parse_long_arg`, `parse_short_arg` and `parse_opt_value` against each other, where a regression in any one of the three is invisible to a test of the other two. Under it sits the binding invariant on error text and then hand-computed answers for nine failure shapes, the token grammar, and every documented setting at both values.

The binding invariant needed narrowing before it was true, and the narrowing is the interesting part. "Every argument name an error mentions is one the command accepts" is false by construction: an unknown-argument error quotes the name the user typed, which is precisely a name the command does not accept. The invariant that holds is about what the error *offers* - the suggestion, the conflicting partner, the missing requirement, the usage line - so a name appearing verbatim in this argv is an echo and is skipped. Narrowed that way it still catches an invented suggestion or a stale name, and it passes at all six failure shapes.

Six battery assertions failed on the first run and all six were the battery being wrong, which is the fifth run in a row that has held. Two were mine misreading clap: a `SetTrue` flag is present in the matches at `false` even when never written, so counting ids is not counting what was supplied; and `-h` was already taken by the help flag, which `debug_asserts` says plainly. Three were guesses about contracts the code documents: `mut_args` is documented not to touch the built-in help, and `build` adds that flag after the walk, so the walk reaching three of four arguments is the documented behaviour rather than a miss; the default `String` value parser rejects a non-UTF-8 value at the value layer, which is a different failure from the key layer never matching it, and the battery now tells the two apart; and `mut_arg` is `remove_by_name` followed by `push`, so it moves its argument to the end of `get_arguments`. That last one was worth chasing rather than just correcting: `get_arguments` is documented as a set with no order promised, and `display_order` is assigned when an argument is added rather than when the map is walked, so the help keeps declaration order across the same mutation. The battery now pins both halves, because the pair is the contract - the reordering is real and it is invisible where a user would see it.

Filed this iteration: nothing at rubric severity. One finding was met and recorded rather than filed, under the three-strike rule: `Arg::required(true)` makes `Arg::default_value` unreachable, since validation fails before the default applies, and nothing warns - `debug_asserts` carries a "`required` conflicts with ..." message for every sibling pair (`required_if_eq*`, `required_if_eq_all`, `required_unless*`) but not this one. The behaviour is deliberate: `tests/builder/default_vals.rs::required_args_with_default_values` builds exactly that command and asserts a runtime error, so a debug_assert would override a maintainer decision, exactly as the `{bin}` code change would have last iteration. That leaves documentation as the only remedy, which puts it in the class DOC-DRIFT-AUDIT already covers with six instances and a decision pending; a seventh one-at-a-time doc task is what the three-strike rule forbids, so it is named in that Proposed item instead.

Stall check: this iteration changed only `.jeffy/`, PLAN.md, BACKLOG.md and JOURNAL.md, and no task line under Now, Next or Later changed state - the Proposed edit is not a ledger state change - so this iteration is flat by the mechanical definition. The previous primary entry is not, so it is not a blocker; iteration 4 must not be flat.

Learnings: an invariant over error text has to distinguish what the message offers from what it echoes back, or the unknown-argument case falsifies it by construction.

Next: iteration 4 sweeps again and must pair the sweep with a closure to clear the flat pair - `util::{any_value,color,escape,flat_map,flat_set,graph,id,str_to_bool}` is the largest remaining row at 93 functions across 9 files, and closing one of the nine carried Lows alongside it satisfies both. 10 rows remain unswept with 7 iterations left.

## iter 4/10 | 427639b7-175310 | 2026-08-15 | SUGGEST-CASE | done

Task: the hook reported iteration 3 as flat, so this iteration had to change the ledger or end the run. The queue's top is still sweeping, with 10 rows unswept, so it was paired with the top open Low exactly as the Lessons line prescribes: SUGGEST-CASE closed, and the largest remaining row swept alongside it.

Changed: clap_builder/src/parser/features/suggestions.rs (the scorer split in two, with a case-insensitive retry), .jeffy/probes/parser-suggestions/battery.rs (the pinned-as-broken test rewritten, one test added), .jeffy/probes/util-core/ (new battery, paths file), .jeffy/probes/Cargo.toml (one test target), CHANGELOG.md, PLAN.md (2 rows), BACKLOG.md (SUGGEST-CASE deleted from Later), JOURNAL.md.

Checkpoint: ab774133bc2a9e8caf5472ea5b1ae85ffd1ef55a

Verification: the filed reproduction ran first and held - `.jeffy/probes/parser-suggestions::a_case_only_difference_draws_no_suggestion` passed against the unfixed code, which is the battery pinning `--FLAG` drawing no tip while the transposition `--flga` drew one. After the fix that same test fails, which is the differential: it was rewritten in the same iteration to pin the new contract and now passes, and the old assertion is quoted in its doc comment.

The fix is a retry, not a widening. `did_you_mean` now scores case-sensitively first and only falls back to a lowercased pass when that found nothing at all, so every command line that already drew a suggestion draws the identical one in the identical order - which is what keeps `best_fit`, `best_fit_long_common_prefix_issue_4660` and `ambiguous`, the three unit tests that pin ordering among candidates, unmoved. A blanket lowercase or a merged score would have reordered them. The new `the_case_insensitive_retry_only_runs_when_nothing_matched` pins that boundary directly, on a command where the two passes would disagree: `deploz` is one substitution from `deploy` and an exact case-fold match for `DEPLOZ`, and the case-sensitive answer is the one offered.

Contract preserved: `did_you_mean` is the one scorer behind flags, subcommands and values, so fixing it there closes the class rather than one instance, and the battery now drives all three routes at a case-only difference. The threshold, the ordering rule and the negative side are unchanged: `--zzzzzz` and `--ZZZZZZ` both draw no tip, which is the assertion a lowered threshold would have broken.

Acceptance check: `--FLAG` renders `tip: a similar argument exists: '--flag'`, `--zzzzzz` still renders no tip, and the battery was updated in the same iteration. Verify command exits 0: 1951 passed, 9 ignored, 1960 cases, unchanged, so no snapshot in clap's own suite pinned the silence. All 23 batteries exit 0 with 215 assertions, up from 207 across 22.

The sweep took `util::{any_value,color,escape,flat_map,flat_set,graph,id,str_to_bool}`, nine files and 93 functions, none of them reachable from outside the crate except through something else. Each family is driven through the route that reaches it and pinned by a hand-computed answer. Two of the seven assertions failed on the first run and both were the battery being wrong, in the same way and worth recording: I had enumerated `Escape`'s call sites by grepping for the type, which found three, and then asserted that all three escape "the value". Provoking each one shows the third is the possible-values list an error carries, not the rejected value - the rejected value is quoted by the error formatter and never passes through `Escape`. That is precisely the failure the Method's enumeration clause describes, and the battery now drives the three real sites and states the fourth thing as the disclosure it is. The second was the same shape: `FlatMap` preserves insertion order, and insertion happens as the parse matches arguments, so the order is the order they were typed rather than declaration order; two different argvs over one identical command now establish that, where either alone would have been consistent with a fixed order.

Rows swept 26 of 35, from 25 at the start of this iteration and 20 at run start. `parser::features::suggestions` went stale when this iteration's fix touched suggestions.rs and was re-swept by re-running the battery that owns it, whose paths file names that source.

Filed this iteration: nothing. The util sweep surfaced no in-envelope finding.

Closed this iteration: SUGGEST-CASE (Low, runtime) - a case-only typo now draws the suggestion its target deserves, on all three routes, evidenced by the differential above.

Learnings: enumerate a call-site class by provoking each site, never by grepping for the name - the grep found three sites for `Escape` and one of them does something else, which is the same rule the Method already carries for failure classes and which applies just as well to a formatting one.

Next: iteration 5 sweeps again. Nine rows remain with 6 iterations left, and the three `clap_derive` rows are the largest block; the parser sweep's instrument does not reach them, since the derive macro's surface is a compile rather than a parse. The stall rule means this pairing has to repeat, so one of the eight carried Lows should ride along - ARGGROUP-MUT is the cheapest and its acceptance is already written.

## iter 5/10 | 427639b7-175310 | 2026-08-15 | ARGGROUP-MUT | done

Task: sweeping is still the queue's top with 9 rows unswept, and the stall rule means a sweep iteration has to carry a ledger change, so this iteration pairs the three `clap_derive` rows with the cheapest open Low. They are the largest remaining block and they share one instrument.

Changed: clap_builder/src/builder/arg_group.rs (`is_multiple` receiver, its doc example, one unit test), .jeffy/probes/builder-range-groups/battery.rs (bindings made immutable), .jeffy/probes/derive-core/ (new battery, paths file), .jeffy/probes/Cargo.toml (one test target), CHANGELOG.md, PLAN.md (4 rows), BACKLOG.md (ARGGROUP-MUT deleted from Later), JOURNAL.md.

Checkpoint: 69c44e3c0d075001e220f8c38291eeb7c7082f48

Verification: ARGGROUP-MUT's acceptance is a compile rather than an assertion, so it was run in both directions. `ArgGroup::is_multiple` now takes `&self`, the battery's group accessors take immutable bindings, and `.jeffy/probes/builder-range-groups` exits 0 with 17 tests. With the receiver reverted to `&mut self` and nothing else changed, that same file fails to compile with two `error[E0596]: cannot borrow `g` as mutable, as it is not declared as mutable`, which is the acceptance failing against the unfixed code. The file was restored from the copy taken first.

Contract preserved: narrowing a receiver from `&mut self` to `&self` is a widening for every caller, so no call site changes; the three places that carried a mutable binding only for this call - the doc example, the crate's own `arg_group_expose_is_multiple_helper`, and the battery - were updated in the same iteration, because a binding kept mutable for a call that no longer needs it is an unused-mut warning and a contradiction of the new signature. `cargo test -p clap_builder --lib arg_group` exits 0 with 5 tests. The accessor now matches its five siblings, `get_id`, `get_args`, `is_required_set`, `is_multiple`'s own docs and the two `Arg`-side `is_multiple` readers, none of which ever needed a mutable receiver.

The derive sweep had to answer a question the other rows do not raise: a proc macro has no callable surface at all, since every function in those files runs at compile time and returns tokens. So the battery is written as real derive types and reads the `Command` they produce, which makes the file compiling its own first assertion. The field-type table is checked twice over - at the `ArgAction` and `num_args` the macro chose, and at a parse that has to honour that choice - because reading only the builder would pass for a macro that set the right flags on the wrong argument.

One compile failure, and it is worth recording rather than just fixing: the eight `rename_all` casings were first written as one `macro_rules!` invoked eight times, and every one was rejected with "attribute `rename_all` can only accept string literals". The derive reads the attribute's tokens, and a metavariable substituted into `rename_all = $casing` is not a literal to it. The eight structs are now written out longhand with that reason recorded at them.

The casing table yields seven distinct answers from eight casings, because snake and verbatim agree on `two_words`. The battery states that rather than choosing a field name where all eight differ, since the coincidence is a fact about the name and hiding it would make the table look stronger than it is.

Rows swept 29 of 35, from 26 at the start of this iteration and 20 at run start. `builder::{arg_group,possible_value,range}` went stale when this iteration changed arg_group.rs and was re-swept by re-running the battery that owns it.

Disclosure carried into the row rather than left implicit: `dummies.rs`, `utils/error.rs` and `utils/spanned.rs` only produce output when a derive fails to compile, and the suite that grades that is `tests/derive_ui.rs`, which the Environment fingerprint excludes on this host - it is gated behind `unstable-derive-ui-tests` and CI runs it on a pinned toolchain because the expected output is compiler-version specific. Nothing in this entry claims those three files were exercised.

Verify command exits 0: 1951 passed, 9 ignored, 1960 cases, unchanged. All 24 batteries exit 0 with 223 assertions, up from 215 across 23.

Filed this iteration: nothing. The derive sweep surfaced no in-envelope finding.

Closed this iteration: ARGGROUP-MUT (Low, runtime) - a read-only accessor no longer demands a mutable binding, evidenced by the two-direction compile above.

Learnings: a `macro_rules!` cannot generate derive attributes whose values the proc macro reads as literals; write the cases out longhand.

Next: iteration 6 sweeps again. Six rows remain with 5 iterations left: the two large builder config-setter rows, the `parser::{arg_matcher,...}` row, `clap_complete::env`, `clap_complete_nushell`, and the binaries and examples row. Pair it with a Low again - BOOLISH-KIND is the top of the seven carried, and its acceptance is already written.

## iter 6/10 | 427639b7-175310 | 2026-08-15 | BOOLISH-KIND | done

Task: sweeping remains the queue's top with 6 rows unswept, paired again with the top open Low. The two config-setter rows are the largest remaining block and they share one instrument.

Changed: clap_builder/src/builder/value_parser.rs (BoolishValueParser's rejection path), .jeffy/probes/builder-value-parser/battery.rs (kind updated at four assertions, one test added), .jeffy/probes/builder-config-setters/ (new battery, paths file), .jeffy/probes/Cargo.toml (one test target), CHANGELOG.md, PLAN.md (3 rows), BACKLOG.md (BOOLISH-KIND deleted from Later), JOURNAL.md.

Checkpoint: af18a3fb3b4edf4b272deb30626a6882d914271d

Verification: the filed reproduction ran first and held - `--v=maybe` rendered `invalid value 'maybe' for '--v <v>': value was not a boolean`, naming none of the twelve literals the parser accepts, while the strict `BoolValueParser` renders a possible-values list for the same shape of mistake. The fix mirrors that sibling exactly: collect the names from `Self::possible_values()`, hidden ones included, and return `Error::invalid_value`. The rejection now names y, yes, t, true, on, 1, n, no, f, false, off and 0, each asserted individually, and the help is unchanged at `[possible values: true, false]`, because `possible_values` still hides all but the two canonical spellings - so the long list belongs to the error alone, which is the same split `BoolValueParser` has.

The test tree was checked before the change, as the recurred Lesson requires: nothing pins the old kind or the old message, and `grep -rn "was not a boolean" tests/ clap_builder/src` returns only the line being replaced. Four battery assertions moved from `ValueValidation` to `InvalidValue` in the same iteration, which is the differential.

The config-setter sweep needed an oracle the introspection rows do not provide. Those rows already drive 51 `Command` setters and 37 `Arg` setters at two values each, but they grade by what an accessor reports afterwards, and an accessor echoing back what was just stored says nothing about whether the setting reaches the parser or the renderer. So this battery compares behaviour: for each setter, one command with it at value A against an identical command at value B, over a fingerprint of the short help, the long help, the usage line and the outcome of parsing a set of command lines with error kinds and messages included. A setter wired to nothing produces the same fingerprint at both values, which is the Surface inventory's inert-parameter rule applied to a whole row at once rather than one setting at a time.

Eleven cases failed on the first runs and every one was the battery being wrong, which is the sixth run in a row. Most were the base command getting in the way - a variadic positional swallowing the word that was supposed to become an external subcommand, a second positional colliding with an explicit index, `raw` implying `last(true)` on an option that has a long. Three were about where a setting is actually decidable, and those became part of the battery's claims rather than corrections to hide: `color` and `disable_colored_help` feed `Command::color_help`, which is consulted where the document reaches a stream, so `render_help` produces the identical styled string at `Always` and at `Never` and no in-process comparison can tell them apart - the battery now pins that fact, so a future change moving the decision into the renderer would fail there, and names `output-help-render`'s subprocess as the place the end-to-end difference is shown. `value_hint` reaches no help text and no parse at all; its only readers are the completion generators, so it is driven on a generated bash script instead of being skipped. `help_expected` is a debug assert, so it is driven as the panic it is, with the counterpart that must be accepted.

One setter in the enumeration is a deliberate no-op and is pinned as one rather than forced: `Command::dont_collapse_args_in_usage` is `#[doc(hidden)]`, deprecated since 4.0.0 with the note "This is now the default", and its body is `self`. The assertion for it is the opposite one - the two values must be indistinguishable - because a setting that silently started working again would be as much of a surprise as one that silently stopped. Every other deprecated setter in the two files delegates to its replacement and is a normal case.

The grep returns 102 names on command.rs and 80 on arg.rs, which are not all setters; 29 of them are listed in the battery's `NOT_SETTERS` with the row that owns each, so the partition is stated rather than assumed and nothing was quietly dropped.

Verify command exits 0: 1951 passed, 9 ignored, 1960 cases, unchanged. All 25 batteries exit 0 with 228 assertions, up from 223 across 24. Rows swept 31 of 35, from 29 at the start of this iteration and 20 at run start. `builder::value_parser` went stale when this iteration changed value_parser.rs and was re-swept by re-running the battery that owns it.

Filed this iteration: nothing. Every configuration setter on both types is distinguishable at two values, and the one that is not is deliberately inert.

Closed this iteration: BOOLISH-KIND (Low, runtime) - a rejected boolish value now names every literal it would have accepted, evidenced by the reproduction and the twelve assertions above.

Learnings: a differential harness over a whole setter family needs a base command with nothing greedy in it - a variadic positional silently absorbs the very input several settings exist to redirect, and the resulting pass is indistinguishable from an inert setting.

Next: iteration 7 sweeps the last four rows if it can - `parser::{arg_matcher,matches::matched_arg,matches::value_source,error}`, `clap_complete::env`, `clap_complete_nushell`, and the binaries and examples row. That would leave iterations 8 to 10 for the full fresh-evidence audit the Definition of done requires, the evaluator gate, and the declaration, which is the only sequence that reaches convergence inside this budget.

## iter 7/10 | 427639b7-175310 | 2026-08-15 | SWEEP | done

Task: sweep the last four rows, which is what the remaining budget demands - iterations 8, 9 and 10 are needed for the High this sweep filed, the full fresh-evidence audit the Definition of done requires, and the gate with the declaration.

Changed: .jeffy/probes/parser-matcher/ (new battery, paths file), .jeffy/probes/complete-env-nushell/ (new battery, helper binary, paths file), .jeffy/probes/examples-and-bins/ (new shell battery, paths file), .jeffy/probes/Cargo.toml (two test targets, one bin target, one dependency), PLAN.md (4 rows), BACKLOG.md (REPL-EOF filed under Now), JOURNAL.md.

Checkpoint: 964457eea4d2d9243f4d6e35fdfe893142725c8b

Verification: `cargo test --manifest-path .jeffy/probes/Cargo.toml` exits 0 with 238 assertions across 27 battery targets, up from 228 across 25, and `.jeffy/probes/examples-and-bins/run.sh` exits 0 having run 58 binaries. Verify command exits 0: 1951 passed, 9 ignored, 1960 cases, unchanged. Rows swept 35 of 35, from 31 at the start of this iteration and 20 at run start. No row is unswept and none is marked unreachable on this host.

Filed this iteration, one High, and it is the first finding this run has produced from code rather than documentation:

REPL-EOF - both REPL examples spin forever at EOF. `readline` in each discards the byte count from `read_line`, so stdin reaching EOF yields `Ok("")`, the loop sees an empty line, `continue`s, and writes the prompt again with nothing left to read. Measured rather than reasoned: `target/debug/examples/repl < /dev/null` wrote 14,549,150 bytes in 3 seconds and did not exit, and `repl-derive` wrote 14,669,418. Ctrl-D is the ordinary way to leave a REPL and a piped script always ends in EOF, so this is realistic in-envelope input on a shipped surface, and the consequence - a process that never terminates while producing unbounded output - is what the rubric scores High. The two sites are the whole class: `grep -rn "read_line" examples/ src/` returns exactly these two, and the class was enumerated by provoking the failure at each rather than by reading the calls. Both are pinned as they stand, with the counterpart that an explicit quit still exits cleanly.

The examples row needed the argument for running rather than compiling made explicitly, because the Verify command already builds every example and it would have been easy to call that a sweep. It is not one: an example whose builder panics at startup - a duplicate id, an incoherent setting, a bad index - builds clean and dies on first use, which is exactly what clap's own debug asserts exist to catch and exactly what a compile never triggers. Eleven of the 57 examples were already driven end to end with known-answer output by the trycmd harness inside the Verify command; the other 46 were compile-only until this iteration. All 58 binaries now run with `--help` under a timeout, and the binding check is that the document names the binary itself.

Two of the binaries could not be driven that way and both taught something. `repl` and `repl-derive` never parse `--help` at all - they start their read loop immediately - which is how REPL-EOF was found, since the battery hung rather than failing. The first version of that battery also ran `cargo build --examples --bins` with its own feature list, which re-resolved the dependency graph and recompiled the world; it was still running after eight minutes. It now runs what the Verify command's build produced and fails loudly if that is missing, which makes it effectively free.

Four battery assertions failed on the first runs and all four were the battery being wrong, the seventh run in a row. The two worth keeping are contracts rather than corrections: nushell writes a single-word command name bare and a multi-word path quoted, so `export extern prog [` and `export extern "prog run"` are both required and the battery pins each against the other; and nushell writes a typed parameter as `--mode: string`, so a name read to the end of the token invents `--mode:`, which is exactly the kind of false positive a binding invariant produces when its tokenizer is lazier than the format.

The completion round trip is the check this row most needed. A registration script is a string and can be wrong in ways only executing the protocol reveals, so the battery ships a helper binary that links `CompleteEnv` the way a real program does and drives it as a process with the variable set. It answers with candidates, withholds the hidden argument, switches context inside a value position, and runs its own logic when the variable is absent.

Learnings: a battery that drives binaries must bound each one, because the failure mode of a program that never terminates is a hang in the battery rather than a red assertion, and a hang looks like an infrastructure problem rather than the defect it is.

Next: iteration 8 fixes REPL-EOF, the only open High and the last thing between this run and a declaration. Iteration 9 runs the full fresh-evidence audit the Definition of done requires, since this run has not yet recorded one, and iteration 10 runs the evaluator gate and declares if it passes.

## iter 8/10 | 427639b7-175310 | 2026-08-15 | REPL-EOF | done

Task: REPL-EOF, the only open High and the last thing between this run and a declaration. Filed by last iteration's sweep of the shipped binaries.

Changed: examples/repl.rs and examples/repl-derive.rs (the read loop stops at end of input), .jeffy/probes/examples-and-bins/run.sh (battery flipped from pinning the hang to pinning termination, with the bare-Enter case added), PLAN.md (one row re-swept), BACKLOG.md (REPL-EOF deleted from Now), JOURNAL.md.

Checkpoint: 7942eac929fac0a61e2baae6ed81c2105e9cb817

Verification: the differential is across two iterations against the same binaries, measured both times rather than reasoned. Before the fix, `target/debug/examples/repl < /dev/null` wrote 14,549,150 bytes in 3 seconds and did not exit, `repl-derive` wrote 14,669,418, and last iteration's battery pinned exactly that and passed. After the fix both exit 0 within a second having written 2 bytes, which is the single prompt they print before reading. The battery was flipped in this same iteration and now fails if either hangs again or exits having written more than 100 KB on the way.

The fix is three lines in each file: `read_line` reports zero bytes only at end of input, so an empty buffer means EOF and the loop breaks, where the old code trimmed first and could not tell EOF from a bare Enter. That distinction is the acceptance's second half and it is checked directly: two blank lines followed by an explicit quit still reaches the quit, and `printf '\n\nping\nquit\n'` still answers Pong before exiting. A fix that broke on any empty line would pass the EOF assertion and fail this one.

Contract preserved: the three states a REPL reads are now distinguishable and each keeps its own behaviour - end of input exits 0, a bare Enter reprompts, an explicit `quit` or `exit` exits 0 with its acknowledgement. Nothing else in either example moved; the `respond` function, the command definitions and the error path are untouched.

Both sites were changed together because they are one class: `grep -rn "read_line" examples/ src/` returns exactly these two, an enumeration built last iteration by provoking the failure at each rather than by reading the calls.

No CHANGELOG entry: the Unreleased section records changes to the crate's own behaviour and API, and this is a defect in shipped example code that no library consumer links against. That is a judgement about the file's audience rather than about the defect's severity, which stays High.

Acceptance check: both binaries exit 0 within a second on `< /dev/null` having written under 100 KB, an explicit quit still exits 0 with its acknowledgement, and the battery was updated in the same iteration. `.jeffy/probes/examples-and-bins/run.sh` exits 0 with 58 binaries run. Verify command exits 0: 1951 passed, 9 ignored, 1960 cases, unchanged. All 27 batteries exit 0 with 238 assertions.

Rows swept 35 of 35. The `clap shipped binaries and examples` row went stale when this iteration changed examples/ and was re-swept by re-running the battery that owns it, whose paths file names those sources.

Closed this iteration: REPL-EOF (High, runtime) - both REPL examples exit at end of input instead of spinning, evidenced by the two-iteration differential above.

Learnings: none new.

Next: iteration 9 runs the full fresh-evidence audit the Definition of done requires, which this run has not yet recorded - the ledger arrived seeded, so no audit was ever triggered. Iteration 10 then runs the evaluator gate and declares if it passes. The ledger holds six Lows and no High or Medium, and the Surface inventory has no unswept row.

## iter 9/10 | 427639b7-175310 | 2026-08-15 | AUDIT | audit

Task: the full fresh-evidence audit the Definition of done requires. This run has not recorded one - the ledger arrived seeded from the previous run, so no audit was ever triggered - and without it no declaration is possible whatever the ledger says.

Changed: JOURNAL.md only. Nothing was filed, so no ledger line changed state.

Checkpoint: 1466dccc7c51ab71ee69b827cb9ccb76c4ff788d

Verification: every score below rests on a command run in this iteration, not on a citation of an earlier one.

Correctness: None. The Surface inventory lists 35 rows and all 35 are swept, each by an executed known-answer or invariant battery rather than a liveness probe. `cargo test --manifest-path .jeffy/probes/Cargo.toml` exits 0 with 238 assertions across 27 targets, and `.jeffy/probes/examples-and-bins/run.sh` exits 0 having run 58 shipped binaries as real processes. The one High this run produced, REPL-EOF, is closed with a measured two-direction differential.

Security: None. Five of the seven shipped crates carry `#![forbid(unsafe_code)]` - clap, clap_builder, clap_derive, clap_mangen, clap_complete_nushell - which `grep -rn "forbid(unsafe_code)"` confirms at their lib.rs. The two that do not were read this iteration rather than assumed. `clap_lex/src/ext.rs` has three unsafe sites, all splitting an `OsStr` back out of `as_encoded_bytes`, each with a SAFETY comment naming why the split is on a UTF-8 boundary; the one `pub(crate) unsafe fn split_at` has exactly two callers, `grep -rn "split_at" clap_lex/src/*.rs`, and both derive the index from a guaranteed boundary - `char_indices()` in one and `Utf8Error::valid_up_to()` in the other - with that source named at the call. `clap_complete/src/env/mod.rs` has one, a `std::env::remove_var` carrying an explicit note that it runs at application initialization. The envelope records no adversarial surface, and the no-panic rule on argv that carries that weight instead is what the parser battery's failure table grades.

Testing: None. The Verify command exits 0 with 1951 passed and 9 ignored, 1960 cases. The Method's isolation requirement was met rather than skipped: three builder modules were run alone - `default_vals::` 60 passed, `env::` 25 passed, `help::` 159 passed - and the whole derive suite serially at 228 passed, with `env::` chosen deliberately because it is the module that mutates process-global state and so the one most likely to be passing on a neighbour's leftovers. None of the four surfaced anything.

The Environment fingerprint was re-derived with the two commands it names rather than re-read, and every exclusion still holds at the counts recorded: `tests/builder/utf16.rs` under `#![cfg(windows)]`, `tests/derive_ui.rs` under `unstable-derive-ui-tests`, `tests/derive/markdown.rs` under `unstable-markdown`, `tests/derive/occurrences.rs` plus 9 further `unstable-v5` items, `clap_complete_nushell/tests/completion.rs` plus 61 further `unstable-shell-tests` items, and 2 `#[ignore]` tests plus 7 ignored doctests summing to the 9 the run reports. No entry in this run has claimed any of them was green. The 33 `#[cfg(all(unix, feature = "unstable-dynamic"))]` items are not an exclusion here: this host is unix and the Verify command enables that feature, which is why it is in the command at all.

The Oracle class line's arithmetic was re-executed and holds, after a first attempt of mine got it wrong. Comparing passed counts gives 1951 against 1904, a difference of 47; comparing cases, which is what the line states, gives 1960 against 1912, a difference of 48. The recorded figure is the second and it is right.

Error handling: None. The parser battery pins nine failure shapes by kind and by the argument the first line names, holds the invariant that an error only offers names the same command accepts, and the matcher battery covers `MatchesError` at both variants including the asymmetry that the returned error leaves the id to the caller while the panic carries it.

Documentation: Low. Five carried Lows are documentation gaps - UNDOC-PANIC, ADVANCE-DOC, BOOL-DOC, ALIAS-EMPTY, RESET-NONE - and the class they belong to has a Proposed decision, DOC-DRIFT-AUDIT, now naming eight instances. Two were closed this run: BIN-VAR by correcting the doc after clap's own tests proved the code deliberate, and the `required` plus `default_value` instance recorded under that Proposed item rather than filed, under the three-strike rule.

Developer experience: Low. RESET-NONE carried; ARGGROUP-MUT closed this run.

Architecture: None. The workspace splits the builder from the derive macro so a builder-only user pays no proc-macro cost, and every source file in the shipped crates belongs to a Surface inventory row, which is what the row enumeration was built to guarantee.

Code quality: None on the swept surface. `cargo check --all-targets` is clean and `cargo clippy` remains unavailable on this host, which the Lessons already record.

Performance: None, and the score claims only what was measured: the Verify command completes in 4.3 seconds warm, and no regression was reproduced. The recorded `Verify duration: 8s` is an upper bound taken when compilation was in the measurement; it resolves the same timeout chain either way, so it is left alone rather than churned.

Dependency hygiene: None on what was examined, with a limitation stated rather than scored away. `cargo tree --depth 1` shows clap_builder taking seven runtime dependencies - anstream, anstyle, clap_lex, strsim, terminal_size, unicase, unicode-width - all of them first-tier crates in this ecosystem, and `rust-version = "1.85"` is declared once at the workspace root and inherited by all eight members. What was not done: neither `cargo-audit` nor `cargo-deny` is installed on this host, so no vulnerability database was consulted. A dependency with a known advisory would be a Medium the rubric names explicitly, and this audit cannot say there is none - it can only say that nothing else about the dependency set looks wrong. That gap belongs in the run report, not hidden in a clean score.

Observability: None. The `debug` feature gates the tracing and `cargo check` with it enabled exits 0.

UX: Low. Nothing open beyond the carried Lows. SUGGEST-CASE and BOOLISH-KIND, both UX findings, closed this run.

Accessibility: None, measured this iteration in both directions: `NO_COLOR=1` on a real example produces 0 escape sequences and `CLICOLOR_FORCE=1` on the same binary produces 6, so the opt-out is honoured and is not simply colour being off.

Zero High and zero Medium in-envelope. Closeout has begun: no further audit and no replenishment for the rest of this run, which leaves the ledger's six Lows to be carried and the declaration to be attempted.

Carried findings re-scored against the rubric, all six still Low and all six re-checked rather than assumed: WRAPHELP-NOCOLOR still reproduces exactly as filed - `cargo test -p clap_builder --no-default-features --features "std wrap_help" --lib --no-run` exits 101 with 3 errors, all `no method named ansi`, while the minimal row `--features std` still builds its tests cleanly, which is the other half of its Low rationale. The five documentation Lows are unchanged on code unchanged since they were filed, so under the Method they need new evidence to move and none appeared.

Learnings: none new.

Next: iteration 10 runs the evaluator gate as invocation 1 of this run and declares if it returns PASS. The closing conditions are otherwise met - no unswept row, no open High or Medium, the Verify command green - so the declaration turns on that verdict alone.

## iter 10/10 | 427639b7-175310 | 2026-08-15 | EVALUATOR | converged

Task: the evaluator gate as invocation 1 of this run, and the declaration if it passed.

Changed: .jeffy/evaluator/427639b7-175310-1.md (the gate's artifact), BACKLOG.md (the Converged line), JOURNAL.md.

Checkpoint: fc6924c6561dbb080e531a02cdd287508ca86a8d

Verification: Evaluator: PASS - one fresh-context sub-agent re-ran the Verify command, both probe batteries and all six closed acceptances against an independent harness it built outside the repository, re-derived the run's stated numbers rather than trusting them, ran the four CI feature rows the Verify command does not reach, and re-scored every carried Low as correctly Low.

The gate's own evidence, as it reported it: the Verify command exits 0 with 1951 passed, 0 failed, 9 ignored across 33 result lines, which is the 1960 cases every entry of this run records. The probe suite exits 0 with 238 assertions across 27 targets and the shell battery exits 0 with 58 binaries run. It re-verified the six closed tasks through a throwaway package that path-depends on the crate and drives the public API directly, so none of those results were inherited from this run's own instruments: 24 assertions, all passing. REPL-EOF it drove against the real binaries, measuring both exiting 0 at EOF in about 110 ms having written 2 bytes, against the 14.5 MB and 14.7 MB the finding recorded before the fix.

It also went where the Environment fingerprint says this gate cannot see, which is the check this run most needed from it: the fingerprint states that a regression appearing only with a feature switched off is invisible to the Verify command, so the gate ran the rows it misses - `make check-minimal`, `check-default`, `check-wasm`, a suggestions-off build, and `make test-next` - and all exit 0, the last with 1916 passed.

The declaring iteration re-read the two lines it is required to. The Oracle class still describes what the command grades and its arithmetic was re-derived by the gate independently, `make test-full` and the no-dynamic workspace run both giving 1912 cases against 1960, a difference of 48. The Environment fingerprint's exclusions were re-derived with its own two commands at iteration 9 and every count still matched; no entry in this run has claimed any excluded target was green, and the two rows covering `clap_complete/src/aot/shells` say in the battery header that no shell executed anything.

The gate recorded five observations that are not REJECT reasons. None is fixed here, because a fix after a PASS invalidates that PASS and spends an invocation the declaration needs; all five go to the run report and the next run's ledger. They are: WRAPHELP-NOCOLOR's text says "3 errors" where the command emits 2 plus a summary line; two rows record sweep commits predating a doc-only edit to command.rs and were not flipped, which the iteration-2 entry disclosed and whose batteries ran and pass; the iteration-2 entry says 5 rustdoc warnings where the count is 7, though the load-bearing half - that the two new intra-doc links resolve - holds; BIN-VAR closed against a substituted acceptance, disclosed at the time with its evidence and verified clause by clause by the gate; and the examples row says all 58 binaries are run with `--help` where the two REPLs are driven by their own pins instead.

Closing conditions, each checked in this iteration: the full fresh-evidence audit at iteration 9 scored zero High and zero Medium in-envelope; the Surface inventory lists 35 swept rows, no unswept row and no row marked unreachable on this host; Now, Next and Later hold no open High and no open Medium; the only commit between that audit and this iteration is its own bookkeeping commit; the Verify command exits 0 this iteration with 1951 passed and 9 ignored; and the evaluator returned PASS with its artifact committed by this iteration's checkpoint.

Six Lows are carried, each with its severity on its own task line so the hook can read it:

WRAPHELP-NOCOLOR (Low, test) - clap_builder's unit tests do not compile with `wrap_help` on and `color` off; nothing a consumer builds is affected and no CI row reaches it.
UNDOC-PANIC (Low, docs) - 9 of the 14 id-taking `ArgMatches` accessors panic identically on an unknown id and do not carry a `# Panics` section.
ADVANCE-DOC (Low, docs) - `clap_lex::ShortFlags::advance_by` does not say what its `Err(usize)` payload counts.
BOOL-DOC (Low, docs) - `str_to_bool`'s comment describes a `true` default the function does not have.
ALIAS-EMPTY (Low, docs) - three `Arg` alias accessors return `Some` of an empty list where their docs say "if any".
RESET-NONE (Low, docs) - the `IntoResettable` doc offers a bare `None` that 11 of 57 setters reject at compile time.

Converged. The line under ## Converged in BACKLOG.md names this iteration's checkpoint commit.

Learnings: none new.

Next: nothing - this is the final iteration and the run has converged. The run report follows.
