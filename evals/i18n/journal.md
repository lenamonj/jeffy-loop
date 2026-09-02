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

## iter 1/10 | 50c1fbfe-173004 | 2026-09-02 | AUDIT | audit

Task: First audit of ruby-i18n (v1.15.2). Filled the Operating envelope, the Surface inventory, and the Verify command block in PLAN.md; enumerated the artifact channels; probed the whole public surface breadth-first and filed what that pass found.

Changed: PLAN.md (envelope surfaces, 32 inventory rows, Command/Oracle class/Environment fingerprint/Verify summary pattern/Verify count), BACKLOG.md (7 findings).

Checkpoint: 138364fd82b9aaaa966d48f76d7429fdca9a2ba4

Verification: Verify command `bundle exec rake test` through quiet-verify.sh: green (1s, 1607 runs, 2674 assertions, 0 failures, 0 errors, 0 skips). Artifact channels enumerated by command, not recall: the only packaging manifest is i18n.gemspec, whose `s.files = Dir.glob("lib/**/*") + %w(README.md MIT-LICENSE)` cannot reach PLAN.md, BACKLOG.md, JOURNAL.md, JOURNAL-archive.md or .jeffy/; `gem build i18n.gemspec` and listing the resulting data.tar.gz confirmed the only non-lib entries are MIT-LICENSE and README.md, and a grep of the entry list for the state-file names and .jeffy returns nothing. There is no container build; .github/workflows/ holds only ruby.yml, which runs `bundle exec rake` and publishes nothing. No finding filed on this dimension. Every acceptance check below was run against the unfixed tree and observed to fail, which is why each is written the way it is.

Scores from this audit, claiming only what the breadth-first pass actually exercised - no Surface inventory row is swept, so this is not a clean-project claim and the unexamined remainder is the 32 unswept rows themselves:
- correctness: High - I18N-01, I18n.interpolation_keys returns sprintf format specifiers as interpolation keys.
- error handling: High - I18N-02, the two-positional-argument lambda form the public RDoc documents raises ArgumentError with no interpolation values.
- documentation: Medium - I18N-03, the *PLURALIZATION* RDoc documents array-form pluralization the code has not implemented in years; also I18N-05, I18N-06, I18N-07 at Low.
- performance: Medium - I18N-04, InterpolationCompiler compiles nothing for frozen strings, which is every YAML- and JSON-loaded translation.
- testing: Low - class test is Low by the rubric ceiling. On this host the suite grades neither KeyValue nor Cache at all (see the Environment fingerprint), and no test pins the documented lambda arity.
- developer experience: Low - covered by I18N-05 and I18N-07.
- security: None observed in this pass. YAML.unsafe_load_file in Base#load_yml and the `eval` in Base#load_rb both read only translation files on I18n.load_path, which the envelope classifies user-error; they are the library's documented design and are not filed.
- architecture, code quality, dependency hygiene: None observed in this pass. One runtime dependency, concurrent-ruby ~> 1.0.
- observability: not applicable. The library has no logging or metrics surface; the only writes to stderr are the PO parser's fuzzy-message warnings.
- UX and accessibility: not applicable. No user-facing surface; this is a library consumed from Ruby.

Learnings: `ruby -Ilib` alone cannot load this project - lib/i18n.rb requires concurrent/map, so every probe and acceptance check must run under `bundle exec`. The suite's own conditional guards are the thing to read before trusting a green run here: `I18n::TestCase.key_value?` is `defined?(ActiveSupport)`, and with no activesupport in the root Gemfile five test classes are never defined and `require 'i18n/backend/key_value'` raises LoadError outright, so green says nothing about that backend.

Next: I18N-01, the highest-severity open item.

## iter 2/10 | 50c1fbfe-173004 | 2026-09-02 | I18N-01 | done

Task: I18N-01 (High, runtime, correctness) - I18n.interpolation_keys returned the sprintf format specifier alongside the key name for the %<name>fmt interpolation pattern.

Changed: lib/i18n.rb (interpolation_keys_from_translation keeps only the first non-nil capture per match; the interpolation_keys RDoc gains the sprintf example and states the contract), test/i18n_test.rb (4 regression tests), PLAN.md (Verify count 1607 -> 1611), BACKLOG.md (I18N-01 deleted).

Checkpoint: b5c3ed41f1e159b4ff6bad149cbc6e06686987c4

Verification: Ran the filed reproduction first, before any edit: it printed [["count", "d"], ["v", ".2f"], ["a", "b", "d"]] and exited 1. After the fix the same command exits 0. Every example in the interpolation_keys RDoc, executed as written against the data the section shows - including the sprintf example the fix adds - returns the documented value. Verify command through quiet-verify.sh: green (1s, 1611 runs, 2678 assertions, 0 failures, 0 errors, 0 skips), up from 1607 by the four tests added. No battery exists under .jeffy/probes/ yet, so no battery was owed a run.

Contract preserved: interpolation_keys_from_translation is private and its only caller is the public interpolation_keys, whose four existing tests in test/i18n_test.rb (%{} form, none, missing, nested, Array) all still pass unchanged. The new rule - the interpolation key is the first non-nil capture of the match - is the rule interpolate_hash already applies when it picks a key with ($1 || $2 || ...), so the two now read the same pattern set the same way; a custom pattern appended to I18n.config.interpolation_patterns keeps working, verified with /\{\{(\w+)\}\}/ returning ["who", "other"] for "hi {{who}} and %{other}". The change narrows what the method returns and adds nothing, so it cannot break a caller that was reading the key it asked for.

Learnings: This project's public introspection helper and its interpolation engine parse the same configurable pattern list; a change to either has to be checked against a custom entry in I18n.config.interpolation_patterns, not only against the three defaults, because group numbering shifts when a user appends one.

Next: I18N-02, the remaining open High.

## iter 3/10 | 50c1fbfe-173004 | 2026-09-02 | I18N-02 | done

Task: I18N-02 (High, runtime, error-handling) - a translation or default stored as the two-positional-argument lambda that lib/i18n.rb's *LAMBDAS* RDoc documents raised ArgumentError whenever no interpolation values were passed.

Changed: lib/i18n/utils.rb (new Utils.call_translation_proc plus a private required_positional_arity), lib/i18n/backend/base.rb and lib/i18n/backend/fallbacks.rb (both proc-resolution sites now go through it), lib/i18n.rb (*LAMBDAS* RDoc states what a two-parameter lambda receives), lib/i18n/tests/procs.rb (3 shared API-conformance tests), PLAN.md (Verify count 1611 -> 1635), BACKLOG.md (I18N-02 deleted).

Checkpoint: 7ecf0dc317cfc5c5dc1c9b42be3a588dd40cee4d

Verification: Ran the filed reproduction first, before any edit: ArgumentError (given 1, expected 2) from lib/i18n.rb translate_key; the same command exits 0 now. Root cause: Ruby passes an empty keyword splat as no argument at all, while a non-empty one is converted back to a positional Hash for a callable that declares no keyword parameters - so `subject.call(date_or_time, **options)` gave the documented ->(key, options) shape two arguments with values present and one without. Utils.call_translation_proc passes the hash positionally in exactly that case - lambda, no keyword parameters, two or more required positional parameters, empty options - and keeps the keyword splat everywhere else.

The idiom `subject.call(date_or_time, **options)` appears at exactly two sites, enumerated by `grep -rn '\.call(' lib/ --include='*.rb'` and reading each hit: Backend::Base#resolve and Backend::Fallbacks#resolve_entry. The other hits are different contracts with their own documented arities - the exception handler, the Rack app, the pluralizer rule, the transliterator rule, the missing-interpolation handler, and an interpolation value that responds to call. Both sites were routed through the helper, and an executing check drives both: entry-is-a-proc and default-is-a-proc through Base, and entry-is-a-proc under Fallbacks. Only the Base site was ever observed failing; the Fallbacks site could not fail, because Fallbacks#translate merges fallback_original_locale into options before super, so options is never empty there. The class is closed at both rather than patched at one.

Differential evidence, required because the change touches how every translation proc is invoked: the same script was run against `git archive HEAD` of the pre-fix tree in /tmp/i18n-base. Before: the two no-values cases raised ArgumentError, the other eleven cases printed values. After: those two return "Mrs. ", and all eleven other cases print byte-identical values - splat with and without values, one-argument lambda, keyword lambda with and without values, a lambda with an optional second parameter, and a non-lambda proc. Nothing that previously passed changed output. The three new shared tests were then copied into the pre-fix tree and run there: `bundle exec ruby -Ilib -Itest test/api/simple_test.rb` exited 1 with 2 errors, both ArgumentError (given 1, expected 2), so the two no-values tests fail on unfixed code and the third pins a shape that already worked.

Verify command through quiet-verify.sh: green (1s, 1635 runs, 2702 assertions, 0 failures, 0 errors, 0 skips), up from 1611 because the three tests land in lib/i18n/tests/procs.rb and every API test class that includes the module runs them. No battery exists under .jeffy/probes/ yet, so none was owed a run.

Contract preserved: the change only adds an argument where Ruby would otherwise have raised. A callable that accepts keywords still receives keywords; a splat lambda still receives one argument when there are no values, which is what the existing procs.rb tests assert.

Learnings: an empty keyword splat and a non-empty one are not the same call in Ruby 3 - `f(x, **{})` passes one argument where `f(x, **{a: 1})` passes two to a callable with no keyword parameters - so any dispatch through `**options` has to be exercised with the hash empty as well as populated.

Next: I18N-03, the top open Medium, unless the sweep queue takes precedence - the map outranks a Medium, so the next iteration sweeps Surface inventory rows.

## iter 4/10 | 50c1fbfe-173004 | 2026-09-02 | SWEEP | done

Task: Sweep Surface inventory rows. The map outranks every open Medium, and both Highs closed in iterations 2 and 3, so this iteration builds known-answer batteries and flips the rows they certify.

Changed: .jeffy/probes/ - twelve new batteries, each with probe.rb, paths, claims and README.md: utils, interpolate-ruby, i18n-lookup-helpers, i18n-transliterate, locale-tag, locale-fallbacks, backend-flatten, gettext-helpers, i18n-exceptions, backend-cascade, backend-pluralization, backend-memoize. BACKLOG.md (I18N-08 filed). PLAN.md (twelve rows flipped to swept, in the bookkeeping edit that records this Checkpoint).

Checkpoint: fe954273dfb9cfc18c54d1bab26ccc9613e23c43

Verification: Every battery asserts hand-computed answers rather than absence of error, and every documented parameter it covers is driven at two or more values that change the output, boundary and negative sides included - the replacement parameter of transliterate at four values including :none, the separator of normalize_keys and of the memoized lookup at two, the escape and subtree parameters of flatten at both, the step and offset options of cascade at values that change which scopes are tried, the defaults of Locale::Fallbacks at three, and a six-category CLDR-shaped plural rule driven at every category it returns. Each battery was then observed failing: a discriminating mutation was applied to a copy of the tree under a temporary directory and the battery reddened and exited non-zero, with the mutation recorded in that battery's README. `check-claims.sh .` reports every recorded measurement matching, zero mismatched, zero errored, zero skipped. Verify command through quiet-verify.sh: green (1s, 1635 runs, 2702 assertions, 0 failures, 0 errors, 0 skips), unchanged, because this iteration adds no code under lib/.

The gettext-helpers battery is the one that had to be strengthened. Its first version survived the mutation that replaces I18n::Gettext::CONTEXT_SEPARATOR with a pipe in pgettext and npgettext, because join-then-split round-trips under any separator that does not occur in the inputs. Two checks with a literal pipe inside the msgid now distinguish them, and the mutation reddens.

One finding, filed as I18N-08 at Low: the :skip_root key of the :cascade option changes nothing for any step of 1 or more, because the loop consults it only once the scope is already empty and slice! on an empty array ends the loop either way. Derived over steps 1-2 by offsets 1-2 by eight keys against a fixed translation tree, comparing both values of skip_root: zero combinations differ. Two expectations of my own were wrong before that one held up - the offset semantics and the step semantics of cascade both behave differently from my first guess - and each was corrected against observed behaviour rather than written into a finding.

Learnings: a battery that has only ever passed is not evidence; mutate the code it covers and watch it redden before trusting it. The gettext separator check is the concrete case - it passed the mutation until a discriminating input was added. Batteries run from the project root with `bundle exec ruby .jeffy/probes/<slug>/probe.rb`, and their claims lines are executed by check-claims.sh from that same root.

Next: twenty rows remain unswept with six iterations left, so the sweep continues.

## iter 5/10 | 50c1fbfe-173004 | 2026-09-02 | SWEEP | done

Task: Continue sweeping Surface inventory rows. Nine more batteries, taking the map from twelve rows swept to twenty-one of thirty-two.

Changed: .jeffy/probes/ - nine new batteries with probe.rb, paths, claims and README.md: config-object, i18n-config-delegation, middleware, autoload-and-version, backend-simple, backend-base-loading, backend-base-translate, i18n-translate, i18n-localize. The shared check helper in all twenty-one batteries now rescues ScriptError as well as StandardError, so a LoadError inside a check is reported as that check failing rather than aborting the battery. PLAN.md (nine rows flipped, in the bookkeeping edit that records this Checkpoint).

Checkpoint: b31edd35fa760db140cea1c3e75a0b62bc6e37c5

Verification: Every documented parameter these batteries cover is driven at two or more values that change the output: skip_symbolize_keys at both values with the stored key inspected either way, the lookup separator at two values, localize's format at six values including a Proc and a literal string, deep_interpolation and skip_interpolation at both values, and every localized strftime directive Base rewrites paired with its upcase variant and with %p and %P on both sides of noon. Each battery was observed failing under a discriminating mutation applied to a copy of the tree, recorded in its README: the am/pm threshold widened from 12 to 24 reddens localize; removing `entry = entry.dup` reddens base-translate with a FrozenError on the second check; a shallow merge! reddens backend-simple; turning middleware's ensure into a rescue reddens middleware. `check-claims.sh .` reports twenty-one recorded measurements, zero mismatched, zero errored, zero skipped. Verify command through quiet-verify.sh: green (1s, 2702 assertions, 0 failures, 0 errors, 0 skips), unchanged, because this iteration adds no code under lib/.

Three expectations of my own were wrong and were corrected against observed behaviour rather than filed: `reload!` on an eager-loaded Simple backend re-initializes rather than clearing, because Base#reload! calls eager_load! when the backend was eager-loaded; CHANGELOG.md is deliberately a pointer to the GitHub Releases page and carries no version, so a check comparing it to VERSION was wrong and was replaced with one that pins the gemspec files list against lib/ and against the loop's own state files; and `I18n.t(:k, locale: false)` does not raise Disabled, because `locale ||= config.locale` replaces the false before the guard reads it - the guard exists for the ambient `I18n.locale = false` case, which the battery now drives instead, together with the explicit-locale escape the exception message recommends.

Learnings: the battery helper must rescue ScriptError as well as StandardError, or an autoload pointed at a missing file aborts the whole battery instead of failing one check. The mutation harness has to copy every directory a battery reads - lib, .jeffy, test and the gemspec - or unrelated checks fail in the mutated copy and hide what the mutation actually did.

Next: eleven rows remain - chain, fallbacks, metadata, cache, cache-file, interpolation-compiler, gettext, po-parser, lazy-loadable, key-value and the shipped test modules - with five iterations left.

## iter 6/10 | 50c1fbfe-173004 | 2026-09-02 | SWEEP | done

Task: Sweep the remaining eleven Surface inventory rows. The map is now complete: thirty-two of thirty-two rows swept, none unreachable.

Changed: .jeffy/probes/ - eleven new batteries with probe.rb, paths, claims and README.md: backend-chain, backend-fallbacks, backend-metadata, backend-cache, backend-cache-file, backend-interpolation-compiler, backend-gettext, gettext-po-parser, backend-lazy-loadable, backend-key-value (with a shim/oj.rb stand-in), shipped-test-modules. BACKLOG.md (I18N-09 and I18N-10 filed, I18N-04 rewritten with its full enumeration). PLAN.md (eleven rows flipped, in the bookkeeping edit that records this Checkpoint).

Checkpoint: 020fd468b019088db1e4b76f677f72afa91d1703

Verification: check-claims.sh reports thirty-two recorded measurements, zero mismatched, zero errored, zero skipped. Verify command through quiet-verify.sh: green (1635 runs, 2702 assertions, 0 failures, 0 errors, 0 skips), unchanged, because this iteration adds no code under lib/. Each battery was observed failing under a discriminating mutation recorded in its README. The key-value row is swept rather than disclosed unreachable: the backend needs a JSON codec the root Gemfile does not carry, so the battery ships a minimal oj shim over the stdlib JSON in its own shim/ directory, and every assertion exercises the backend's own flattening, subtree merging and SubtreeProxy logic rather than the codec. The shipped-test-modules battery runs the whole conformance suite in process the way a third-party backend author would, and requires every assertion to pass.

Three findings this sweep surfaced, all reproduced:

I18N-09 (Medium): I18n::Backend::Metadata attaches nothing at all to a pluralized translation loaded from YAML or JSON. Base#translate dups the entry before pluralize, so the string pluralize then picks out of the hash is still the frozen one the loader stored, and translation_metadata= is a documented no-op on a frozen receiver. Confirmed against a real temp YAML file: every documented key comes back empty, not just :count.

I18N-10 (Medium): GetText::PoParser#parse mutates the String it is handed and raises FrozenError on a frozen one, because its first statement is str.strip!. Not scored High because no shipped code path reaches it - the only in-library caller passes File.read output - and the rationale is recorded on the ledger line.

I18N-04 was rewritten rather than left as filed. The frozen-string explanation I filed in iteration 1 was true but partial. Driving each entry shape through a backend that traces what reaches #interpolate - the enumeration built by execution, not by reading the source - shows no shape ever arrives compiled: a scalar String is dup'd by Base#translate and dup drops singleton methods; Array elements are never compiled at all, because compile_all_strings_in recurses only into Hashes; and a Hash under deep_interpolation never reaches #interpolate, since deep_interpolate is a separate method the module does not override. The module is inert in the shipped lookup path for every shape, and the ledger line now says so with that enumeration.

One observation, not filed because no consequence could be named: I18n::Backend::LocaleExtractor is a public constant defined in lazy_loadable.rb with no autoload entry of its own, so it resolves only after I18n::Backend::LazyLoadable has been touched.

Learnings: the shipped conformance modules define their own setup and teardown and call super, so a harness that consumes them must put its helpers in a superclass - a setup defined directly on the including class silently shadows theirs and every localization test then fails on missing fixtures. Consuming them also needs date, minitest, mocha/minitest and test_declarative, which is the same set test/test_helper.rb requires.

Next: the map is clear and no High is open, so the queue is the two remaining Mediums, then the Lows.

## iter 7/10 | 50c1fbfe-173004 | 2026-09-02 | I18N-04 | done

Task: I18N-04 (Medium, runtime, performance) - I18n::Backend::InterpolationCompiler never delivered a compiled interpolation through I18n.translate, for any entry shape.

Changed: lib/i18n/backend/interpolation_compiler.rb (compiled copies now live in a per-backend Concurrent::Map keyed by string content instead of on the stored object; store_translations warms it and now walks Arrays as well as Hashes; a new UNCOMPILABLE_PATTERN keeps forms the compiler cannot represent on the interpreted path; the reserved-key branch compares key.to_sym so it can actually fire), test/backend/interpolation_compiler_test.rb (5 regression tests), .jeffy/probes/backend-interpolation-compiler (battery updated for the new behaviour, claims and README re-recorded), PLAN.md (Verify count 1635 -> 1640), BACKLOG.md (I18N-04 deleted; the Next section was also reordered so the runtime Mediums precede the docs one, which the ordering rule requires and the ledger did not have).

Checkpoint: 24a0c0b1c924b7cc6b113419101d65f9ea730fdd

Verification: Ran the filed reproduction first: a backend that traces what reaches #interpolate reported every shape arriving uncompiled - scalar, Array element and frozen entry alike. After the fix the same trace reports all three arriving with a compiled copy. Root cause, stated as the reproduction found it rather than as first filed: the compiled method is a singleton method on a String, Base#translate dups a String entry, and dup drops singleton methods; Array elements were never compiled at all because compile_all_strings_in recursed only into Hashes; and compile_if_an_interpolation dups a frozen receiver and its caller discarded the copy. Keying the compiled copies by content sidesteps all three, because nothing has to survive on the stored object.

The acceptance check is differential and it is what caught the one real risk in this change. Compiling a string the compiler only partly understands would silently change results, and the first version of the fix did exactly that: "100%% of %{name}" returned "100%% of Bo" compiled against "100% of Bo" interpreted, because the tokenizer recognises %% only when it introduces %%{key}. UNCOMPILABLE_PATTERN now covers the bare %% escape and the sprintf %<key>fmt form, and compilation is skipped entirely once the application has appended anything to I18n.config.interpolation_patterns, since a pattern the compiler has never seen cannot be represented by its body. With that guard the compiled and interpreted paths agree on all thirteen shapes the acceptance check drives - scalar, Array, frozen, nested Hash, escaped percent, escaped brace, plain, sprintf, mixed sprintf, trailing percent, deep nesting and a reserved key - including the exception classes raised.

Verify command through quiet-verify.sh: green (1s, 1640 runs, 2714 assertions, 0 failures, 0 errors, 0 skips), up from 1635 by the five tests added. Battery ownership: the diff touched lib/i18n/backend/interpolation_compiler.rb, which the backend-interpolation-compiler battery declares; it was updated in this iteration and re-run through run-probe.sh, and its row is re-recorded at this checkpoint. Emptying UNCOMPILABLE_PATTERN reddens it, so the guard the fix rests on is itself instrumented.

Contract preserved: Compiler.compile_if_an_interpolation and Compiler.interpolated_str? keep their signatures and behaviour, which the existing tests pin. Storing a translation no longer attaches a singleton method to the caller's object at all, where before it did so for unfrozen strings; that is a narrowing, and the new test pins it. Every value the module returns is unchanged - the conformance suite in I18n::Tests::Interpolation runs against this backend in test/backend/interpolation_compiler_test.rb and stayed green throughout.

Learnings: a cache that speeds up a path must be proved to agree with that path on every input shape, not on the happy one; the differential acceptance check found the escaped-percent divergence that the unit tests, the conformance suite and the battery all missed. When a compiled fast path cannot represent an input form, refusing to compile it is the correct answer, and the refusal needs its own instrumented check.

Next: I18N-09, the top open Medium.

## iter 8/10 | 50c1fbfe-173004 | 2026-09-02 | I18N-11 | done

Task: I18N-11 (High, runtime, correctness) - a pluralized lookup returned the stored translation object, so a caller mutating the result corrupted the backend's store. Filed this iteration, from evidence turned up while reproducing I18N-09, and worked immediately because a High outranks everything. The same root-cause fix also satisfies I18N-09 (Medium, runtime, correctness), which is closed with it.

Changed: lib/i18n/backend/base.rb (new protected pluralized_entry helper; Base#pluralize returns through it), lib/i18n/backend/pluralization.rb (its three value-returning branches route through the same helper), lib/i18n/backend/key_value.rb (its subtrees-false branch likewise), lib/i18n/tests/pluralization.rb (2 shared conformance tests), test/backend/metadata_test.rb (1 regression test), .jeffy/probes/backend-base-translate, backend-pluralization and backend-metadata (batteries extended and re-recorded), PLAN.md (Verify count 1640 -> 1657), BACKLOG.md (I18N-11 and I18N-09 deleted).

Checkpoint: 4a3cfe46bd05e5e92358b0e0fc9f075553c3e4cf

Verification: Ran the I18N-09 reproduction first: a Metadata backend over a real temp YAML file returned an empty metadata hash for a pluralized lookup. While confirming why, a second and worse behaviour reproduced: `I18n.t(:apples, count: 1) << '!'` left the store reading "apple!!!" on the next lookup. Base#translate dups a String entry before pluralizing, but a pluralized entry is a Hash at that point, so the value picked out of it was the stored object - the scalar path was protected and the pluralized path was not. That is the root cause of both findings: the stored object is frozen when a file loader produced it, which is why metadata could not attach, and it is the store's own object, which is why mutation corrupted it.

The idiom repeats, so the class was fixed rather than the instance. The set was enumerated by `grep -rn 'def pluralize' lib/`: four definitions, of which Metadata's is a wrapper that delegates and the other three select a value out of the entry hash - Base, Pluralization and KeyValue. All three now return through Base#pluralized_entry, and the acceptance check drives every one of them, including each of Pluralization's four value-returning branches: the legacy :zero key, the explicit "0" and "1" keys, the rule category, and the lateral fall-through to :other. Twelve checks, all passing, none of which passed before.

Differential evidence that nothing previously-passing changed: the same twenty-value script - six pluralized lookups on a Simple backend, a scalar, an Array, a missing key, an InvalidPluralizationData raise, six lookups through Pluralization covering every branch, and a nil count - was run against `git archive HEAD` of the pre-fix tree and against the working tree. The outputs are identical.

Verify command through quiet-verify.sh: green (1657 runs, 2733 assertions, 0 failures, 0 errors, 0 skips), up from 1640 by the two shared conformance tests, which run in every API test class, and the one metadata test. Battery ownership: the diff touched base.rb, pluralization.rb, key_value.rb and metadata.rb; the six batteries declaring those paths - backend-base-translate, backend-base-loading, i18n-localize, backend-pluralization, backend-key-value, backend-metadata - were all re-run through run-probe.sh in this iteration, three of them extended for the new behaviour, and every row they certify is re-recorded at this checkpoint.

Contract preserved: the change adds one String allocation on the pluralized path and returns a copy where it previously returned the store's own object. No returned value changes, which the differential shows; what changes is that the object is now the caller's to mutate, which is what Base#translate already promised for the scalar path and what the shipped test "lookup: a resulting String is not frozen" already assumed.

Learnings: when a protective copy exists on one path, check every sibling path that reaches the same data by a different route - the dup in Base#translate had guarded scalars since long before pluralize was reachable through a Hash, and the gap sat behind a green suite.

Next: I18N-10, the top open Medium.

## iter 9/10 | 50c1fbfe-173004 | 2026-09-02 | SWEEP | done

Task: Re-sweep the one stale Surface inventory row. Iteration 8 added two conformance tests to lib/i18n/tests/pluralization.rb, which the shipped-test-modules battery declares, so that row stopped certifying the code it names. A stale row outranks every open Medium, so this iteration is a sweep.

Changed: PLAN.md only - the shipped-test-modules row re-recorded at this Checkpoint, in the bookkeeping edit. No file under lib/ or test/ changed and no BACKLOG item changed state; the row re-record is this iteration's progress, and the previous entry was not a no-progress entry, so this is not the second of a stalled pair.

Checkpoint: 3150629f16e7471514bda783cec5c063dc388a53

Verification: The stale set was derived rather than trusted, by reading each swept row's recorded commit and its battery's declared paths out of PLAN.md and asking `git diff --quiet <recorded commit> -- <those paths>` for every row: exactly one row came back changed, shipped-test-modules, which is the row the Stop hook had already named. Every one of the thirty-two batteries was then re-run through run-probe.sh against HEAD and all thirty-two exit 0 with their recorded totals, so the whole map certifies the current tree rather than only the row that went stale. The shipped-test-modules battery is the one that matters here: it mixes the whole conformance suite into a Minitest case over a Simple backend and executes it in process, so it ran the two new pluralization tests as part of its own pass. check-claims.sh reports thirty-two recorded measurements matching, zero mismatched, zero errored, zero skipped. Verify command through quiet-verify.sh: green, 1657 runs, 2733 assertions, 0 failures, 0 errors, 0 skips, unchanged from the previous checkpoint because this iteration adds no code.

Learnings: a fix that lands in lib/i18n/tests stales the shipped-test-modules row, because that directory ships and the battery declares it; the row has to be re-recorded in the same run or the next declaration is refused over it.

Next: the final iteration. Two Mediums and four Lows remain open and the budget cannot close them, so iteration 10 is a WRAPUP that tidies the ledger and writes the handoff rather than starting work that cannot finish.

## iter 10/10 | 50c1fbfe-173004 | 2026-09-02 | WRAPUP | done

Task: Final iteration. The ledger is not at the severity floor - two Mediums are open - so the closing-audit exception does not apply and this iteration tidies BACKLOG.md and writes the handoff rather than starting a task that cannot finish.

Changed: JOURNAL.md and PLAN.md only. No BACKLOG.md item changed state and no Surface inventory row changed state, which is the stall shape; the previous primary entry was a SWEEP that re-recorded a row, so this is not the second of a stalled pair, and a WRAPUP is one of the ceremony entries that never forms one.

Checkpoint: 7fe1b3e6879d598ae541c7a99ec017c4d0fec6b3

Verification: Every open item's acceptance check was re-executed against HEAD, because a backlog line is a hypothesis that rots as sibling fixes land around it and the next run should inherit six accurate ones rather than six stale ones. All six still reproduce: the PO parser still raises FrozenError on a frozen source; the array-pluralization RDoc examples still return the whole array for all three counts; skip_root still makes no difference across twenty-four cascade combinations; the README still names test/api/tests and test/core_ext, neither of which exists; Rfc4646.tag still returns nil where its RDoc promises false; and the README still claims Rails 6.0 while the lowest gemfile in the repository is Rails 7.0.x. The ledger's ordering was checked against the Method's rule and is correct - runtime before docs within each severity - and every line carries a parseable severity label. Verify command through quiet-verify.sh: green, 1657 runs, 2733 assertions, 0 failures, 0 errors, 0 skips.

No convergence is declared and none is available. The Definition of done requires zero open Medium tasks and an evaluator PASS; two Mediums remain and the budget is spent, so the evaluator gate was never invoked this run. That is the honest position: the run ends out of budget, not converged, and the next run's fresh audit plus its own gate decide.

Learnings: a run that spends its first six iterations on the audit and the map has four left for findings, which closed two Highs and two Mediums here but could not reach the gate. On a project of this size the map is worth the six iterations - it turned up I18N-09, I18N-10 and the evidence that produced I18N-11 - but a follow-up run inherits a swept map and should reach the declaration inside its own budget.

Next: relaunch in a fresh session. The map is complete and current, so the next run starts at the top of the ledger with I18N-10.

## iter 1/10 | f7bd9f98-182801 | 2026-09-02 | I18N-10 | done

Task: I18N-10 (Medium, runtime, correctness) - GetText::PoParser#parse began `str.strip!`, so it mutated the String the caller handed it and raised FrozenError on a frozen one. Top of the queue: no High was open, the Surface inventory carried no unswept and no stale row, and I18N-10 is the first open Medium of class runtime.

Changed: lib/i18n/gettext/po_parser.rb (`str.strip!` becomes `str = str.strip`), test/gettext/po_parser_test.rb (new, 2 regression tests), test/i18n/interpolate_test.rb (the pre-existing suite order dependence the verify gate exposed), .jeffy/probes/gettext-po-parser (probe and README updated to pin the fixed behaviour instead of the defect), .jeffy/probes/caller-owned-mutation (new class battery, 17 checks), PLAN.md (Verify count 1657 -> 1659, two Lessons), BACKLOG.md (I18N-10 deleted, two Settled classes lines).

Checkpoint: df1afa1d08bb7f921ccdf4cea134951893f41e94

Verification: The filed reproduction ran first and failed as filed - FrozenError at po_parser.rb:123 in `parse`. Both acceptance checks pass after the fix: a frozen PO document parses to `{"a" => "A"}`, and a caller's String is byte-identical after parsing.

The finding is one instance of a repeatable idiom, so the class was fixed rather than the instance. The class is a destructive method called on an object the caller owns, and it was enumerated by `grep -rnE '\.(strip|gsub|sub|chomp|chop|squeeze|upcase|downcase|capitalize|swapcase|slice|replace|concat|insert|prepend|clear|force_encoding|encode|tr|delete|reverse|rstrip|lstrip|succ|next|flatten|compact|uniq|sort|map|select|reject|merge|shift|unshift|push|pop)!' lib/ --include='*.rb'`. Every site it lists is covered by the new `.jeffy/probes/caller-owned-mutation` battery, which drives each one through its public entry point with a caller-owned object rather than reading the code to decide: normalize_keys against a caller's key String and scope Array and against cache corruption, Cascade's `scope.slice!` against a caller's scope, Flatten's `normalize_flat_keys`, Utils.deep_merge against its source hash with deep_merge!'s documented destructive contract pinned beside it, Tag#parent against Tag#to_a, Fallbacks against a caller's Tag and against repeated computes, Tag::Simple#subtags against a caller mutating the array it returned, and the parser itself. `lib/i18n/backend/key_value.rb` is recorded as unreachable on this host rather than green, per the Environment fingerprint. The battery is 17/17 green here and reddens 3 checks on the pre-fix tree, so it has been seen to fail. `parse` was the only member of the class.

The verify gate came back red on the first run, one failure: I18nBackendInterpolationCompilerTest#test_every_entry_shape_reaches_a_compiled_copy, "scalar has no compiled copy". It is a pre-existing fault this iteration exposed rather than introduced, and the evidence is a seed sweep of the pre-fix tree taken from `git archive HEAD`: seeds 1, 4, 5 and 8 fail there with exactly that assertion and exactly that message, while 2, 3, 6 and 7 pass. Minitest shuffles suites, so adding a test file reordered them and moved this run onto the losing side of a coin the suite had been flipping all along. The root cause is in the test, not the runtime: I18nCustomInterpolationPatternTest saved `I18n.config.interpolation_patterns`, which returns the live class-variable array, then appended to that same array and restored it by assigning the object back, so the extra `{{...}}` pattern survived teardown for the rest of the process; `InterpolationCompiler#compilable?` requires the patterns to equal the default, so every compiler test scheduled after it failed. The capture now dups. That class was enumerated too, by `grep -rnE 'I18n\.(config\.)?[a-z_]+ *(<<|\.push\(|\.merge!|\.delete\(|\.clear)' test/ --include='*.rb'`, and it had one member: the remaining sites mutate `I18n.load_path`, which I18n::TestCase#teardown nils, or a cache store the mutating test installs and nils itself. Both classes are recorded under Settled classes with those commands.

Differential evidence that the parser change altered no previously-passing output: a 17-line dump of parse results over every input shape the battery covers - leading whitespace, no trailing newline, empty, blank, comment-only, multi-line concatenation, all four escapes, msgctxt, plural forms, ignore_fuzzy at both values, an empty msgstr, a header entry, an obsolete entry, the repository's de.po, and one parser instance reused across two parses - was run against the pre-fix tree and the working tree with unfrozen sources, which is the previously-passing set. The two outputs are identical. For the test-side fix the differential is the seed sweep: 4 of 8 seeds red before, 10 of 10 green after, with the assertion count moving only by the 2 assertions the 2 new tests add.

Verify command through quiet-verify.sh: green (1659 runs, 2735 assertions, 0 failures, 0 errors, 0 skips), up from 1657 by the two new po_parser regression tests. Battery ownership: the diff touched lib/i18n/gettext/po_parser.rb, declared by gettext-po-parser and by the new caller-owned-mutation battery; both were run through run-probe.sh in this iteration, gettext-po-parser updated in the same iteration as the behaviour it pins, and the gettext-po-parser row re-recorded at this checkpoint. check-claims.sh: 33 checked, 0 mismatched, 0 errored, 0 skipped. The new test module was also run in isolation.

Contract preserved: `parse` returns the same data object filled with the same entries for every input that previously worked; what changes is that it no longer writes to the caller's String, which lets a frozen source through the door it used to raise on. `str` was already rebound throughout the tokenizer loop, so the strip was the only statement reaching the caller's object.

Learnings: a test that saves a config value returned by reference dups it before mutating in place, or its teardown restores the mutation; and a suspected order dependence in a shuffled suite is confirmed by sweeping seeds against the pre-fix tree, which separates exposed from introduced in one command.

Next: I18N-03, the remaining open Medium - the *PLURALIZATION* RDoc in lib/i18n.rb documenting array-form pluralized translations the code has not produced for years.

## iter 2/10 | f7bd9f98-182801 | 2026-09-02 | I18N-03 | done

Task: I18N-03 (Medium, docs, documentation) - the *PLURALIZATION* RDoc of I18n.translate documented pluralized translations as arrays of singular and plural forms and stated four return values the code does not produce. Top of the queue: no High was open, the Surface inventory carried no unswept and no stale row, and I18N-03 was the last open Medium.

Changed: lib/i18n.rb (the *PLURALIZATION* RDoc section rewritten), .jeffy/probes/i18n-translate (7 checks added, claims 26 -> 33, README updated), BACKLOG.md (I18N-03 deleted).

Checkpoint: 4cf76e929e60de756a0028b7e622d80396e07048

Verification: The filed reproduction ran first and reproduced exactly as filed. With `:foo => ['Foo', 'Foos']` stored on a Simple backend, `I18n.t(:foo, count: 1)`, `count: 0` and `count: 2` all return `["Foo", "Foos"]` - the whole array, for every count - and with `['%{count} foo', '%{count} foos']` the count is interpolated into every element, returning `["1 foo", "1 foos"]` where the RDoc promised `'1 foo'`. Base#pluralize returns any non-Hash entry unchanged, so `:count` never selects from an Array. The same probe run against `{ one: 'Foo', other: 'Foos' }` returns the four values the RDoc stated, which is what the section now documents.

The consequence a user meets is what set the severity: a reader following the shipped API documentation stores an array, gets `["Foo", "Foos"]` rendered into their page instead of `Foo`, and nothing raises.

The section now states the Hash form with its categories, says in one sentence that a non-Hash entry is returned unchanged so an Array is not a pluralized translation, and adds the two rules the old text omitted and the code has: a `:zero` key is used for a count of 0 when the translation defines one, and a translation with no key for the selected category raises I18n::InvalidPluralizationData. Both were read out of Base#pluralization_key and Base#pluralize and then executed rather than trusted.

The acceptance check is every example the section states, run against the data the section shows, and it lives in the i18n-translate battery rather than in a throwaway script, because that battery declares lib/i18n.rb and a later doc drift should redden something. Seven checks: the three category selections, the :zero key, the InvalidPluralizationData raise, the count interpolated into the chosen form, and a non-Hash entry returned unchanged with :count passed. All seven pass; the first three and the interpolation one fail against the data the old section documented, which is the reproduction above.

The battery was shown to be discriminating by two mutations applied to a copy of the tree carrying lib, .jeffy, test and the gemspec: removing the `:zero` branch of Base#pluralization_key reddens the :zero check, and collapsing its `:one` category into `:other` reddens three checks. Both exit non-zero.

The claim that no other file documents the array form was enumerated rather than assumed: `grep -rn "singular/plural\|\['Foo', 'Foos'\]\|\["Foo", "Foos"\]" README.md lib/ test/` returned the one line in lib/i18n.rb that this iteration rewrote, and the direct siblings that carry pluralization prose - lib/i18n/backend/base.rb, simple.rb and pluralization.rb - were read and state nothing about entry shape.

Verify command through quiet-verify.sh: green (1659 runs, 2735 assertions, 0 failures, 0 errors, 0 skips), unchanged from the previous checkpoint because this iteration adds no test to the shipped suite. Battery ownership: the diff touched lib/i18n.rb, declared by five batteries - i18n-translate, i18n-lookup-helpers, i18n-config-delegation, i18n-localize and caller-owned-mutation - all five run through run-probe.sh in this iteration and all green, with the four that a Surface inventory row names re-recorded at this checkpoint. check-claims.sh: 33 checked, 0 mismatched, 0 errored, 0 skipped.

Contract preserved: no behaviour changed. This iteration edits comments and a probe only; the RDoc now describes what Base#pluralize has done for years instead of a shape it never supported, so no Surface inventory row is flipped back to unswept for a behaviour change - the rows are re-recorded because the file they cover moved, not because their contract did.

Learnings: none that generalise beyond this task.

Next: the ledger is at the severity floor - four open Lows, nothing above - and no full audit has run this run, so the next iteration is the closing full audit that a declaration needs.

## iter 3/10 | f7bd9f98-182801 | 2026-09-02 | AUDIT | audit

Task: The closing full audit. The ledger was at the severity floor - four open Lows, nothing above - the map carried no unswept and no stale row, and no full audit had scored clean this run, so this iteration is the audit a declaration needs rather than a task.

Changed: BACKLOG.md (I18N-12 filed) and JOURNAL.md. No file under lib/ or test/ changed; a BACKLOG item changed state, so this is not a stall, and an AUDIT entry is a ceremony entry in any case.

Checkpoint: a3aecffab6d74e112fe94c6c51c45667cd52ce2e

Verification: Fresh evidence, not a re-reading. Every one of the 33 batteries under .jeffy/probes was executed through run-probe.sh this iteration and all 33 exit 0, 866 checks in total across the whole mapped surface. check-claims.sh: 33 checked, 0 mismatched, 0 errored, 0 skipped. Verify command through quiet-verify.sh: green, 1659 runs, 2735 assertions, 0 failures, 0 errors, 0 skips, which is the figure the Verify count cell holds.

Standing claims re-derived rather than trusted. Both Settled-class enumerations were re-run: the destructive-call grep over lib/ returns 18 sites, all of them covered by the caller-owned-mutation battery, and the in-place-config-mutation grep over test/ returns the load_path and cache-store sites its line describes. The Declined section is empty, so there was no Derivation to re-run. The Environment fingerprint's exclusion command was re-executed and returns the same set the line states - the five key_value?-guarded classes, the two rescue-LoadError files, and the two Fiber skips that exclude nothing on Ruby 3.3 - and the platform line still matches: ruby 3.3.8 (2025-04-09 revision b200bad6cd) [x86_64-linux-gnu], with neither activesupport nor oj loadable. The Oracle class line was re-read against what the command actually grades and still describes it.

Artifact channels were enumerated by command, not by recall: the tree carries one packaging manifest, i18n.gemspec, and one workflow, .github/workflows/ruby.yml, with no Dockerfile, nuspec, MANIFEST.in, package.json or pyproject. Loading the gemspec and grepping its own files list reports 56 files and zero matches for PLAN, BACKLOG, JOURNAL, .jeffy or test/, because the list is `Dir.glob("lib/**/*") + %w(README.md MIT-LICENSE)`. The workflow contains no upload-artifact, gem push, release, publish or archive step, so it is not an artifact-producing channel. The loop's state cannot reach a published artifact.

Dimension scores, claiming the whole public surface because the map lists no unswept row. Correctness: None - 866 known-answer checks green, and the two Mediums closed this run are pinned by checks that fail against the pre-fix trees. Architecture: None - all 46 files under lib/ load on this host except lib/i18n/backend/key_value.rb, whose LoadError the Environment fingerprint already records, and no file is unreachable. Code quality: None - the one repeatable idiom this run found is settled class-complete with its enumeration. Security: None - the envelope's single adversarial surface is interpolation values, and it was probed fresh with hostile shapes: a value containing %{secret}, a bare %%, a %<num>09999d format spec, and a reserved key name are each substituted verbatim and never re-scanned, because interpolate_hash is one gsub pass over the translation and the substituted text is not revisited, and the sprintf format comes from the owner-authored translation rather than from the value. Error handling: None - 30 exception checks green, and the three interpolation error paths raise typed I18n errors. Testing: None - the order dependence this run found is fixed and the suite is green across eighteen distinct seeds, with test/utils_test.rb and test/backend/interpolation_compiler_test.rb also run in isolation. Performance: Low - I18N-12. Documentation: Low - I18N-05, I18N-06 and I18N-07, with the one Medium closed this iteration before last. Dependency hygiene: None on what is checkable here, and the limit is stated rather than papered over: the gem declares one runtime dependency, concurrent-ruby ~> 1.0, and no advisory database is reachable in this environment, so this is not a clean bill against a CVE feed. Developer experience: None - the CI matrix covers six Ruby versions against six gemfiles with its exclusions written down. Observability: not applicable - a library with no logging, metric or trace surface, which raises typed exceptions and hands handling to the caller's exception_handler. UX and accessibility: not applicable - the project ships a Ruby API and has no user-facing surface.

Zero High and zero Medium in-envelope. Closeout has begun: no further audit and no replenishment for the rest of this run.

One new finding, filed at Low. I18N-12: I18n::Base's @@normalized_key_cache grows one entry per distinct key and is never evicted, measured at 2001 entries after 2000 distinct dynamic keys. The rubric alone would put unbounded process-global growth higher, so the downgrade rationale is recorded here as the severity discipline requires: the Operating envelope classifies translation keys and scopes as user-error and states in its own line that an app routing end-user input into the key position is outside documented usage, so under the envelope the key set is the application's literals and the cache is bounded by them. That is an envelope line, not an opinion about how exotic the input is.

Two behaviours were examined and deliberately not filed. A translation containing %% returns unchanged when no interpolation values are passed, because Base#interpolate returns early on an empty values hash; that is a pinned contract, asserted by the shipped conformance module lib/i18n/tests/interpolation.rb, not a defect. And `I18n.interpolate('%<num>d', num: 'notanumber')` raises ArgumentError from sprintf rather than an I18n error; the format is chosen by the owner-authored translation, nothing documents that slot as accepting arbitrary strings, and the exception names the offending value accurately, so it is sprintf's contract rather than a swallowed or misreported error.

Learnings: none that generalise beyond this task.

Next: the evaluator gate. The closing conditions hold apart from it - a clean full audit is now on this run's record, the map lists no unswept row, no High or Medium is open, and the Verify command is green - so the next iteration invokes the gate and declares on a PASS in that same iteration.

## iter 4/10 | f7bd9f98-182801 | 2026-09-02 | EVALUATOR | converged

Task: The evaluator gate, and the declaration on its verdict. The closing conditions all held coming into this iteration - a clean full audit on this run's record from iteration 3, no unswept and no stale row, no open High or Medium - so the gate was invoked here rather than deferred, and this entry declares.

Changed: BACKLOG.md (I18N-13 and I18N-14 filed from the gate's observations, and the Converged line appended in the bookkeeping edit), JOURNAL.md, and .jeffy/evaluator/f7bd9f98-182801-1.md, which this iteration's checkpoint commits. No file under lib/ or test/ changed; BACKLOG items changed state, and an EVALUATOR entry is a ceremony entry in any case.

Checkpoint: 74fc5dc0fff68d1c75095ecce37c0358452c12d8

Verification: Standing claims were brought current in this same iteration before the invocation, not before it. No Surface inventory row is stale: each of the 32 rows' recorded commit was asked against its battery's declared paths with git diff --quiet and none came back changed. Both Settled-class enumerations were re-run and return the shapes their lines state. The Declined section holds no entry, so there was no Derivation to re-run. PLAN.md names no finding ID as carried or blocked, so nothing can dangle. The Oracle class and Environment fingerprint were re-read and the platform still matches: ruby 3.3.8 (2025-04-09 revision b200bad6cd) [x86_64-linux-gnu]. check-claims.sh: 33 checked, 0 mismatched, 0 errored, 0 skipped. Verify command through quiet-verify.sh: green, 1659 runs, 2735 assertions, 0 failures, 0 errors, 0 skips, which is the figure the Verify count cell holds.

Evaluator: PASS - invocation 1 of this run, artifact .jeffy/evaluator/f7bd9f98-182801-1.md, which confirmed both closed Mediums fail their filed reproductions on d1ed3a4 and pass at HEAD, found the PO parser change byte-identical to the pre-fix parser across 28 input shapes, found the I18N-03 diff comment-only, reproduced the suite order dependence in both directions, and re-scored every open finding as accurately Low.

The gate returned four observations, none of them a REJECT reason, and none is fixed here: a fix after a PASS invalidates that PASS and spends an invocation the declaration needs. Two became ledger lines for the next run. I18N-13: the i18n-translate battery README states that collapsing the :one category into :other reddens three checks, and that figure is wrong. It was re-measured this iteration rather than taken on the gate's word - each mutation applied alone to its own copy of the tree - and the truth is that removing the :zero branch reddens one check for 32/33 and collapsing :one into :other reddens two for 31/33. The three came from a run where the second mutation was applied on top of the first, so the README and the iteration 2/10 entry both state a number no single mutation produces. That is the loop's own instrument drifting, exactly the class PLAN.md warns about, and it is recorded rather than quietly corrected. I18N-14: the caller-owned-mutation probe labels its checks with source line numbers, which the Working rules forbid in loop state because they rot, and they already have. The other two observations need no ledger line and are named in the run report: the caller-owned-mutation battery's key_value.rb check asserts unreachability and would fail on a host carrying ActiveSupport or oj, which its own README discloses, and the new *PLURALIZATION* RDoc sentence about a non-Hash entry is exact for the pluralization step while an Array's elements are still interpolated, which the *INTERPOLATION* section documents and which no stated example contradicts.

Carried Lows, each by ID, one line: I18N-12, the process-global normalized-key cache grows one entry per distinct key and is never evicted, Low because the envelope classifies keys as user-error literals; I18N-08, the :skip_root key of the :cascade option changes nothing across the 32 combinations its derivation drives, Low because the option appears in no shipped RDoc and the behaviour it always takes is the permissive one; I18N-05, the README's Tests section names test/api/tests and test/core_ext, neither of which exists; I18N-06, the RDoc on Rfc4646.tag promises false for an invalid tag where the method returns nil; I18N-07, the README claims Rails support from 6.0 while the lowest gemfile in the repository and in the CI matrix is Rails 7.0.x; I18N-13 and I18N-14 as described above. All seven reproduce as filed, all seven carry a parseable severity on their task line, and none names anything a user of the shipped product meets that the rubric would score higher.

Convergence declared. The Definition of done is met: a full fresh-evidence audit this run scored zero High and zero Medium in-envelope, the Surface inventory lists no unswept row and no stale one, no open High or Medium remains in Now, Next or Later, the only commits since that clean audit are this iteration's own, the Verify command is green this iteration, and the adversarial evaluator returned PASS with its artifact committed by this checkpoint.

Learnings: a battery's Observed failing line records what one mutation does alone, because mutations applied to the same working copy stack and the second one inherits the first one's reddened checks.

Next: nothing in this run. The next run inherits a swept, current map, seven carried Lows, and the ratchet, which will re-declare without a fresh audit if nothing but loop state has changed.
