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

## iter 1/10 | cd1add0d-183544 | 2026-09-03 | AUDIT | audit

Task: First audit of the RubyMoney money gem. Filled the Operating envelope, the Surface inventory, and the Verify command block in PLAN.md, then probed the whole public surface breadth-first and filed what the probes reproduced.

Changed: PLAN.md (envelope surfaces, 20 inventory rows, Command / Oracle class / Environment fingerprint / Verify duration / Verify summary pattern / Verify count, Lessons), BACKLOG.md (F001-F006), JOURNAL.md, .gitignore (loop state).

Checkpoint: 31dd8e6b5aacd27d820b4fc0026bc07bb380ac34

Verification: `bash <jeffy>/hooks/lib/quiet-verify.sh PLAN.md` green - `499 examples, 0 failures`, matching the Verify count cell. `bundle exec rspec --dry-run` reports the same total, so no example is skipped on this host. Each of F001-F004 carries a one-line acceptance command that was executed against the unfixed tree and observed to exit 1; F005's checker was executed in draft form and exits 1 today; F006 was reproduced by appending a deliberately failing example and observing `rake spec` exit 0 while `bundle exec rspec` exited 1, then restoring the spec file.

Artifact-producing channels, enumerated by command rather than recall: `ls *.gemspec package.json MANIFEST.in pyproject.toml Cargo.toml Dockerfile 2>/dev/null` finds only money.gemspec, and `find .github -type f` finds dependabot.yml, workflows/ruby.yml and workflows/lint.yml - neither workflow archives or publishes the tree. money.gemspec builds its file list from `git ls-files -z -- config/* lib/* sig/* CHANGELOG.md LICENSE money.gemspec README.md`, an explicit allowlist; running that command and grepping it for PLAN, BACKLOG, JOURNAL and .jeffy returns nothing, so no loop state file can reach the published gem. Channel verified, nothing filed.

Audit scores, by highest severity found, claiming only what this audit actually examined: security High (F001), error handling Medium (F003), correctness Medium (F002, F004), documentation Low (F005), code quality Low, developer experience Low (F006), testing Low, architecture None, performance None. Observability and UX/accessibility do not apply - this is a library with no runtime surface a person operates. Dependency hygiene is unassessed rather than clean: the gem depends only on bigdecimal and i18n and Dependabot is configured, but no advisory database was consulted on this host. These scores are not a clean bill of health for the project: all 20 Surface inventory rows are still unswept, no probe battery is committed under .jeffy/probes yet, and every row named in that table remains to be certified by an executed known-answer battery.

Learnings: `rake spec` and the default `rake` task exit 0 over a red suite here, so the verify gate must be `bundle exec rspec`. `bin/rbs --no-collection -r money validate` is the RBS gate CI runs and it passes; `bundle exec rbs -I sig validate` fails on unresolved stdlib types and is the wrong invocation. `Money::Currency` uses class variables for its instance cache, so probes that register or unregister currencies must call `Money::Currency.reset!` afterwards or they leak into later checks in the same process.

Next: F001 - replace `JSON.load` in `import_rates` with a parse that does not honour `json_class`, keeping the `:ruby` warning intact.

## iter 2/10 | cd1add0d-183544 | 2026-09-03 | F001 | done

Task: F001 (High, runtime, security) - `Money::Bank::VariableExchange#import_rates(:json, str)` deserialized with `JSON.load`, which honours `json_class` keys and instantiates arbitrary classes carrying a `json_create` hook, while the method's own warning offers `:json` as one of the "safe alternatives" to `:ruby`. Closed: `import_rates` now parses JSON with `JSON.parse`, which never consults `json_class`; the `:ruby` Marshal warning is unchanged and `:yaml` already refused arbitrary classes under Psych 4.

Changed: lib/money/bank/variable_exchange.rb (import_rates deserialization branch), spec/money/bank/variable_exchange_spec.rb (regression example), BACKLOG.md (F001 deleted), PLAN.md (Verify count 499 -> 500), JOURNAL.md.

Checkpoint: c383f39594c52b7815f6d1a004f04136ff510c87

Verification: the filed reproduction was the first command of this iteration and still printed `GADGET RAN` and exited 1 against the pre-fix tree; after the fix the same command exits 0 and `get_rate("USD","CAD")` returns the raw Hash instead of a gadget instance. The new example `does not instantiate objects named by a json_class key` was run against the unfixed lib - stashed for that one run and restored - and failed with `json_create must never be called while importing rates`, then passed with the fix, so it is an instrument observed to fail. Export/import round trips still return the documented rates for all three formats (json, yaml, ruby: 1.24515 and 0.803115). `bundle exec rubocop` reports no offenses over 48 files and `bin/rbs --no-collection -r money validate` exits 0, the two commands CI runs for lint. Verify gate green via quiet-verify.sh: `500 examples, 0 failures`, and the Verify count cell was moved to 500 to match.

Contract preserved: `import_rates` accepts the same documented flat `{"FROM_TO_TO": rate}` document and stores the same Numeric rates; only `JSON.load`'s undocumented `json_class` instantiation is gone. One behaviour did shift and is deliberate - an empty JSON string used to set `data` to nil and then die with `NoMethodError: undefined method 'each' for nil`, and now raises `JSON::ParserError`. Both are errors on input the method never documented as valid, and the new one names the real problem. No documentation contradicts the change: the method's docstring lists only the three formats, and the warning's claim that `:json` is a safe alternative is true for the first time.

Learnings: none new this iteration.

Next: F002 - move `alias eql? ==` in lib/money/currency.rb below the `def ==` it is meant to alias.

## iter 3/10 | cd1add0d-183544 | 2026-09-03 | SWEEP | done

Task: Sweep the Surface inventory. The ledger held no open High, so the map was top of the queue: build a known-answer battery for every one of the 20 rows, run each one, and flip the rows the evidence supports.

Changed: .jeffy/probes/ (a shared harness plus 20 batteries, each with check.rb, paths, README.md and claims), BACKLOG.md (F007 and F008 filed), JOURNAL.md, PLAN.md (Surface inventory rows). Gemfile.lock was rewritten by bundler during the mutation pass and regenerated with bundle install; it is gitignored and untracked, so nothing about it is committed.

Checkpoint: 5579e724eda919aa97f7c20ea84e73bb9be0c518

Verification: 20 batteries built and executed through run-probe.sh. 18 are green and their rows are flipped; 2 are red on findings this run has filed and their rows stay unswept - currency-instance at 46/49 on F002, bank-variable-exchange at 35/36 on F008. Every battery was observed failing before it was trusted, by mutating the code it covers and re-running it: to_d multiplying instead of dividing reddens 8 checks in money-value-api, dropping .abs reddens 2 in money-arithmetic-operators, truncate to round reddens 1 in money-allocation, ca_dollar building USD reddens 2 in money-constructors, dropping the thousands separator reddens 6 in formatter-assembly and 9 in formatter-rules, disabling the separator alias reddens 2 in formatting-rules, dropping the stringified_keys reset reddens 1 in currency-registry, skipping the backwards-compatible currency file reddens 5 in currency-loader, removing the deprecation raise reddens 5 in currency-heuristics, same_currency? always true reddens 2 in bank-base, dropping the subunit scaling reddens 6 in bank-variable-exchange and 1 in money-exchange, changing SERIALIZER_SEPARATOR reddens 5 in bank-serialization and restoring JSON.load reddens 2, removing .upcase from rate_key_for reddens 1 in rates-store-memory, a nil currency lookup reddens 8 in locale-backend, inverting nonzero? reddens money-arithmetic-comparison, and moving VERSION off the newest CHANGELOG heading reddens 1 in package-entrypoint. Every lib file was restored with git checkout after its mutation and `git status --porcelain -- lib/` is empty. check-claims.sh reports 18 checked, 0 mismatched, 0 errored, 0 skipped. rubocop reports no offenses over 48 files. Verify gate green via quiet-verify.sh: 500 examples, 0 failures.

Two findings the sweep surfaced, both filed at rubric severity this iteration. F008 (Medium): set_rate documents its rate as [Numeric] and accepts a Rational, which then dies inside exchange with ArgumentError from BigDecimal("1/3"); Float, Integer and BigDecimal all work. F007 (Low): the exponent docstring still calls MGA an exception rounded to 1, but commit b91c02c deliberately made MGA zero-decimal and the CHANGELOG records it as a breaking change, so it returns 0 while MRU returns 1.

Three of my own expectations were wrong rather than the code, and each was corrected by derivation rather than by copying the observed output: allocation of a negative Integer amount floors rather than truncates, because Integer division floors; Currency.all sorts by priority alone while <=> breaks ties by id, so the ordering property belongs on a list sorted by <=>; and html_wrap prefers a currency's html_entity over its symbol. Two data invariants I wrote were too strong and were replaced with the real contracts: the backwards-compatible currency file exists to alias retired keys (ghc to GHS, yen to JPY), and ISO reassigned numeric 532 from the retired ANG to its replacement XCG, which is the only shared iso_numeric and resolves to the live currency.

Learnings: Gemfile.lock is gitignored here and bundler rewrites the path gem's version into it on every load, so a version assertion against the lockfile can never fail and any edit to lib/money/version.rb leaves the lockfile stale until bundle install. Battery checks must not evaluate a subject that can raise outside a guard, or one broken expectation takes the whole battery down and it reports nothing.

Next: F008 - convert a Rational rate through BigDecimal properly in Money::Bank::VariableExchange#exchange.

## iter 4/10 | cd1add0d-183544 | 2026-09-03 | F008 | done

Task: F008 (Medium, runtime, error handling) - `Money::Bank::VariableExchange#exchange` converted the rate with `BigDecimal(rate.to_s)`, which cannot parse a Rational, so a rate documented as `@param [Numeric]` was accepted by `set_rate`, returned by `get_rate`, and then died at every `exchange_with` with `ArgumentError: invalid value for BigDecimal(): "5/4"`. Closed: a private `rate_as_decimal` converts a Rational through `#to_d(Money.conversion_precision)` and leaves every other Numeric on the existing String path. Both unswept rows were blocked on open findings rather than on missing instruments, so the top actionable item was this Medium, which unblocks one of them.

Changed: lib/money/bank/variable_exchange.rb (rate_as_decimal), spec/money/bank/variable_exchange_spec.rb (regression example), .jeffy/probes/bank-variable-exchange/ (README and claims now record a green measurement), BACKLOG.md (F008 deleted), PLAN.md (Verify count 500 -> 501, Surface inventory rows), JOURNAL.md.

Checkpoint: 92439a0f49f675f6c57ff0c7e8351c3fe7776d58

Verification: the filed reproduction was the first command of this iteration and exited 1 against the pre-fix tree with the BigDecimal ArgumentError; after the fix it exits 0. The new example `handles every Numeric kind the rate is documented to accept` was run against the stashed unfixed lib and failed with `invalid value for BigDecimal(): "5/4"`, then passed with the fix. The other three Numeric kinds are unchanged and were re-measured directly: Float(1.25) and BigDecimal(1.25) still give 125, Integer(2) still gives 200, Float(0.803115) still gives 80, and the two Rational rates now give 125 and 33. Battery ownership: the diff touched lib/money/bank/variable_exchange.rb, and `grep -l` over the probes' paths files names bank-variable-exchange and bank-serialization as its owners; both were re-run through run-probe.sh, at 36/36 and 22/22, so bank-variable-exchange is green for the first time and its row is swept, and the bank-serialization row is re-recorded at this checkpoint because its declared paths include the changed file. check-claims.sh reports 19 checked, 0 mismatched, 0 errored, 0 skipped. rubocop reports no offenses over 48 files and `bin/rbs --no-collection -r money validate` exits 0. Verify gate green via quiet-verify.sh: 501 examples, 0 failures, and the Verify count cell was moved to 501 to match.

Contract preserved: `exchange` keeps its signature and its block and rounding_method behaviour, and every Numeric kind that worked before still takes the identical `BigDecimal(rate.to_s)` path, so no previously-passing conversion changed. The only behaviour that moved is the Rational case, which previously raised. The conversion follows the gem's own existing convention for Rationals rather than inventing one: `Money#as_d` already routes a Rational through `#to_d(conversion_precision)`, so a Rational rate and a Rational amount are now converted the same way. No documentation contradicts the change - `@param [Numeric] rate` is now true at all three sites that state it, and the RBS signature for `exchange` is `untyped` and unaffected.

Learnings: none new this iteration.

Next: F002 - move `alias eql? ==` in lib/money/currency.rb below the `def ==` it is meant to alias, which unblocks the last unswept row.

## iter 5/10 | cd1add0d-183544 | 2026-09-03 | F002 | done

Task: F002 (Medium, runtime, correctness) - `alias eql? ==` sat above the `def ==` it names, and `alias` resolves the method as the class body is read, so `Money::Currency#eql?` bound to `Comparable#==` and dispatched through `#<=>`, raising `NoMethodError: undefined method 'priority' for an instance of String` for every argument that is not a Currency, where the sibling `==` answered correctly. Closed: the alias moved below `def ==`, with a comment saying why the position is load-bearing.

Changed: lib/money/currency.rb (alias moved), sig/lib/money/currency.rbs (same move, so the signature file keeps mirroring the source it describes), spec/money/currency_spec.rb (regression example), .jeffy/probes/currency-instance/ (corrected expectation, README and claims now record a green measurement), .jeffy/probes/_lib.rb (report prints its failing-check count), BACKLOG.md (F002 deleted), PLAN.md (Verify count 501 -> 502, Lessons, Surface inventory rows), JOURNAL.md.

Checkpoint: f85aa12ae55bd7aa39468294c892666251d0e519

Verification: the filed reproduction was the first command of this iteration and exited 1 against the pre-fix tree with the NoMethodError; after the fix it exits 0. The new example `agrees with #== for every kind of argument` was run against the stashed unfixed lib and failed with NoMethodError, then passed with the fix. The alias's contract is that eql? answers what == answers, so it was checked by enumerating the argument kinds rather than asserting the class in prose: Currency, matching String, matching Symbol, other Currency, nil and Integer, with `==` and `eql?` agreeing on all six, and `method(:eql?).original_name` now resolving inside Money::Currency rather than Comparable. Hash-key behaviour is unchanged - `{currency => 1}[Money::Currency.new(:usd)]` still returns 1 - because `hash` is `id.hash` and was never touched. Battery ownership: the diff touched lib/money/currency.rb, whose owners per the probes' paths files are currency-instance and currency-registry; both were re-run at 51/51 and 34/34 and both rows are re-recorded at this checkpoint. All 20 batteries were then re-run and every one is green. check-claims.sh reports 20 checked, 0 mismatched, 0 errored, 0 skipped. rubocop reports no offenses over 48 files and `bin/rbs --no-collection -r money validate` exits 0. Verify gate green via quiet-verify.sh: 502 examples, 0 failures, and the Verify count cell was moved to 502 to match.

Contract preserved: `==`, `<=>` and `hash` are untouched, and the only behaviour that moved is `eql?`, which now answers rather than raises for a non-Currency argument. The existing spec pinned eql? only for Currency-to-Currency pairs, which passed either way, so nothing that previously passed changed.

Correction to this run's own record: fixing the alias let two checks run that had been failing since the battery was written, and I had not seen them because I was reading battery output through `tail`. `Money::Currency#symbol_first?` is true for EUR, not false as the battery asserted - 102 of the shipped currencies return false and AWG is one of them - so the expectation was mine to fix, not the code's. The battery now checks AWG and adds an invariant that symbol_first? mirrors the underlying attribute across every shipped currency. No row was ever flipped on that battery while it was red, so nothing was certified on the bad expectation.

Learnings: never read a probe battery's output through tail - a battery reports every failing check and truncating hides the ones above the last, which is how two wrong expectations sat unnoticed for two iterations. Probe.report now prints its failing-check count first so a truncated read is self-evidently incomplete.

Next: F003 - Money::Currency.unregister reads @table instead of the memoizing table reader.

## iter 6/10 | cd1add0d-183544 | 2026-09-03 | F003 | done

Task: F003 (Medium, runtime, error handling) - `Money::Currency.unregister` read the raw `@table` instead of the memoizing `table` reader, so the first call in a process raised `NoMethodError: undefined method 'delete' for nil`. Closed: it now reads through `table`, and it maintains the same three caches its sibling `register` maintains rather than only one of them.

Changed: lib/money/currency.rb (unregister), spec/money/currency_spec.rb (two regression examples in their own context), BACKLOG.md (F003 deleted, F009 filed), PLAN.md (Verify count 502 -> 504, Lessons), JOURNAL.md.

Checkpoint: 7926ccd9b245e888b04b0236e6a2562c15b8cdcb

Verification: the filed reproduction was the first command of this iteration and exited 1 against the pre-fix tree with the NoMethodError; after the fix it exits 0. The two new examples were run against the stashed unfixed lib, where both failed, and both pass with the fix. The isolated module run - `bundle exec rspec spec/money/currency_spec.rb` alone - is 57 examples, 0 failures, which matters here because these examples mutate the shared currency table. Battery ownership: the diff touched lib/money/currency.rb, whose owners are currency-registry and currency-instance; both re-run at 34/34 and 51/51 and both rows are re-recorded at this checkpoint. rubocop reports no offenses over 48 files, `bin/rbs --no-collection -r money validate` exits 0, and the verify gate is green at 504 examples, 0 failures, with the Verify count cell moved to 504.

Scope of the fix, by enumeration rather than by assertion: `register` maintains three pieces of memoized state - the `_instances` cache under the mutex, `@stringified_keys`, and the iso_numeric index - and `unregister` maintained only `@stringified_keys`. Rather than patch the one crash, the same iteration made the two methods mirror, and each of the three was then checked by execution: the table entry is gone, `stringified_keys` no longer admits the id, `find_by_iso_numeric(532)` returns ANG once XCG is dropped instead of the nil a stale index produced, and `_instances` no longer holds the removed id. A miss still returns false and leaves the table at its previous size. This is one root cause in one method, not three symptoms.

A High this enumeration surfaced, filed as F009 and not worked here because the iteration executes one task: `Money::Currency.reset!` reloads `@table` and clears the instance and iso_numeric caches but never clears `@stringified_keys`. After `register`, then any lookup that memoizes the key set, then `reset!`, the gate still admits the removed id while the table no longer holds it, and `initialize_data!` dereferences nil - so `Money::Currency.new("ZZZ")` and `Money::Currency.find(:zzz)` raise `NoMethodError: undefined method '[]' for nil` rather than `UnknownCurrency`, and `find` does not rescue a NoMethodError. It was reproduced against this run's base commit 4f107ec and against HEAD with this iteration's fix stashed, identically, so it predates the run and this fix neither caused nor changed it. The memoizing read is what makes it reachable: without a lookup between `register` and `reset!` the key set is already nil and recomputes cleanly, which is why an isolated first attempt at the reproduction did not crash and had to be tightened.

Contract preserved: `unregister` keeps its signature, its Hash-or-ISO-code argument handling, and its documented true/false return; the existing examples that pin those still pass. The only behaviour that moved is that it no longer crashes on an unread table and no longer leaves two caches stale.

Learnings: a spec that unregisters a real currency breaks the suite-wide `before` hook setting Money.default_currency to USD, and the next example then fails with UnknownCurrency far from the cause - scope such examples in a context with `after { Money::Currency.reset! }`. A reproduction that depends on memoized state must force the memoization explicitly, or it silently tests the un-memoized path instead.

Next: F009 - clear @stringified_keys in Money::Currency.reset!.

## iter 7/10 | cd1add0d-183544 | 2026-09-03 | F009 | done

Task: F009 (High, runtime, correctness) - `Money::Currency.reset!` replaced the table and cleared the instance and iso_numeric caches but never cleared `@stringified_keys`, the memoized set `Currency.new` gates on, so after register, then any lookup, then reset!, the gate still admitted the removed id while the table no longer held it and `initialize_data!` dereferenced nil, raising `NoMethodError: undefined method '[]' for nil` where `UnknownCurrency` was due - and `find` rescues only `UnknownCurrency`, so it escaped. Closed: reset! now clears the key set with the other two caches.

Changed: lib/money/currency.rb (reset!), spec/money/currency_spec.rb (two regression examples), .jeffy/probes/currency-registry/ (five checks pinning the reset! cache contract, README and claims at the new total), BACKLOG.md (F009 deleted, the cache-invalidation class settled), PLAN.md (Verify count 504 -> 506, Lessons, Surface inventory rows), JOURNAL.md.

Checkpoint: 1ef30e29e9ba18c8dcd17d639bc29ecf63be412b

Verification: the filed reproduction was the first command of this iteration and exited 1 against the pre-fix tree with the NoMethodError; after the fix it exits 0. Both new examples were run against the stashed unfixed lib, where both failed, and both pass with the fix. The currency-registry battery crashed outright against the unfixed lib with the same NoMethodError and is 39/39 with the fix. A seven-check cycle drove the whole contract by execution - find and new after register/lookup/reset!, the rebuilt key set, shipped currencies surviving, an unregistered currency restored, Money.new working again, and the iso_numeric index restored - and all seven pass. The isolated module run is 59 examples, 0 failures, which matters because these examples mutate the shared currency table. All 20 batteries were then run individually with their real exit statuses read: every one exits 0. check-claims.sh reports 20 checked, 0 mismatched, 0 errored, 0 skipped. rubocop reports no offenses over 48 files, `bin/rbs --no-collection -r money validate` exits 0, and the verify gate is green at 506 examples, 0 failures with the Verify count cell moved to 506.

Class settled rather than patched twice. F003 and F009 are the same root cause at two sites: a method that mutates the currency table must drop every cache derived from it. The class is enumerated by a command rather than by reading, and that command is recorded on the Settled line: it lists table-mutating methods that fail to drop all three caches, returns no lines on this tree, and names unregister and reset! when run against this run's base commit 4f107ec. Three sites exist - register, unregister and reset! - and all three are now complete, so no third instance can be patched.

Contract preserved: reset!'s signature and its documented job of restoring the shipped table are unchanged, and the existing example that pins it - resetting a modified CAD - still passes. The only behaviour that moved is that a stale key set no longer survives the reload, so `new` and `find` answer for the table that actually exists.

Learnings: a shell check that reports pass or fail through a `grep ... || echo ok` fallback reports ok when the grep itself errors, which it did here on a backreference the shell's grep does not support, printing "all batteries green" without having read a single exit status; loop over the subjects and read each real exit status instead. A spec asserting a cache was invalidated must force the memoization first, or it passes on both trees - the second example was rewritten after it passed pre-fix for exactly that reason.

Next: F004 - Money::Allocation.generate breaks its documented sum invariant on a negative weight.

## iter 8/10 | cd1add0d-183544 | 2026-09-03 | F004 | done

Task: F004 (Medium, runtime, correctness) - `Money::Allocation.generate` documents that the allocated parts always total the original amount, and a negative proportion broke that silently: `generate(100, [-1, 2])` returned parts summing to 200, `[-1, 1]` summed to 0, and `[-5]` turned an amount of 100 into 0. Closed: a negative proportion now raises ArgumentError, matching how a negative Numeric part count already behaved.

Changed: lib/money/money/allocation.rb (normalize_parts extracted, negative proportions rejected, docstring's raise clause updated), spec/money/allocation_spec.rb (two examples), .jeffy/probes/money-allocation/ (six raise checks and a wide-shape invariant, README and claims at the new total), BACKLOG.md (F004 deleted), PLAN.md (Verify count 506 -> 508, Surface inventory row), JOURNAL.md.

Checkpoint: 534ba1efc937dbae17048368f218a2a220387659

Verification: the filed reproduction was the first command of this iteration and exited 1 against the pre-fix tree, printing `parts=[0, 200] sum=200`; after the fix it exits 0. The new example `rejects a negative proportion` failed against the stashed unfixed lib and passes with the fix, and the money-allocation battery was 21/27 there with six failing checks and is 27/27 now. The choice to reject rather than redistribute was decided by measurement, not by taste: with non-negative weights the guard the defect hid behind is already correct, verified by driving every leading, trailing and interior zero shape - [3,0,0], [0,3], [0,0,5], [5,0], [1,1,0] - all of which total correctly, so the guard only ever misbehaves on the negative input now refused. The total is held across 176 amount-and-weight shapes with zero violations, including negative amounts and seven-way splits, and all six negative-weight shapes raise. The isolated module run is 24 examples, 0 failures. rubocop reports no offenses over 48 files, `bin/rbs --no-collection -r money validate` exits 0, and the verify gate is green at 508 examples, 0 failures with the Verify count cell moved to 508.

The added guard first pushed `generate` past four Metrics thresholds it already sat at - AbcSize, CyclomaticComplexity, MethodLength and PerceivedComplexity, each pinned in .rubocop_todo.yml at the value the method had. Raising those pins to fit one more line would have moved the project's own ceiling to accommodate this change, so the parts normalisation and both guards were extracted into a private `normalize_parts` instead, which puts every metric back under its existing pin and leaves .rubocop_todo.yml untouched.

Contract preserved: `generate` keeps its signature, its three documented `decimal_cutoff` values and its behaviour for every non-negative input - the 176-shape check covers the shapes the existing specs pin and more, and the suite's own allocation examples still pass. The only behaviour that moved is that a negative proportion raises where it used to return a wrong total, and the docstring's `@raise` clause was updated in the same iteration to say so. `normalize_parts` is private, so the public surface is unchanged and the RBS signature needed no edit.

Learnings: none new this iteration.

Next: the ledger is at the severity floor - F005, F006 and F007 are all Low - and the map is swept, so the closing sequence is the remaining work: a full fresh-evidence audit, then the evaluator gate.

## iter 9/10 | cd1add0d-183544 | 2026-09-03 | AUDIT | audit

Task: Closing full audit. The ledger is at the severity floor and the map is fully swept, so this is the audit a declaration has to cite, and it had to land here because the closing extension never admits one.

Changed: JOURNAL.md only. No file outside the state files changed and no BACKLOG item changed state, which is the stall shape - but this is an AUDIT entry, one of the ceremony entries that never form a stall pair, and the previous primary entry closed F004.

Checkpoint: 84af8586e50228751a7f367629bf50b90e67f24a

Verification, all re-run this iteration rather than carried forward: all 20 probe batteries executed through run-probe.sh with their real exit statuses read, every one exiting 0, covering 638 checks across the whole inventory. The settled-class enumeration for currency-table cache invalidation returns no lines, so no table-mutating site fails to drop all three derived caches. The verify gate is green at 508 examples, 0 failures, matching the Verify count cell. check-claims.sh reports 20 checked, 0 mismatched, 0 errored, 0 skipped. rubocop reports no offenses over 48 files and `bin/rbs --no-collection -r money validate` exits 0. The Oracle class and Environment fingerprint were re-read and the fingerprint's own exclusion command re-run: its only hits remain a spec_helper comment about the :focus filter and a helper's `skip:` keyword argument, no example is skipped, focused or platform-gated, and `--dry-run` reports the same total as a real run, so the gate grades everything it claims to.

Packaging channel re-verified by building the artifact rather than reading the manifest, because .jeffy/ is now committed and carries the loop's own memory: `gem build money.gemspec` exits 0 and the built money-7.1.1.gem carries 44 files and no PLAN, BACKLOG, JOURNAL or .jeffy path. The gemspec's `git ls-files` allowlist was also grepped directly and returns none of them.

Security, the one surface the envelope classifies adversarial, re-probed fresh: `import_rates(:json, ...)` no longer calls `json_create` and stores the plain Hash, `:yaml` refuses an arbitrary class with Psych::DisallowedClass, `:ruby` is Marshal by design and warns about remote code execution, and the export/import round trip still returns the stored rate.

Testing, meeting the Method's requirement to run modules in isolation before scoring it: every spec module was run alone and none failed, and a full `--order defined` run is 508 examples, 0 failures, so no order dependence and no leaked-state dependence was found.

A fresh wrong-number hunt over the swept surface found nothing: amounts at 10**30 format and round trip exactly, KWD and BTC render at their own precision, allocation of 1 cent three ways and of 10**9 cents seven ways both total exactly, a reciprocal exchange chain returns the original, the divmod identity holds at 10**12, Money sorts, sums, hashes and dedupes correctly, a frozen Money still formats, and neither a caller's rules hash nor Money.default_formatting_rules nor the currency table is mutated by formatting.

Scores, claiming the whole project because the Surface inventory now lists no unswept row: security None, correctness None, error handling None, architecture None, performance None, testing None, code quality Low (F005), documentation Low (F005, F007), developer experience Low (F006). Dependency hygiene is scored on what was examined and not on advisory status: the gem has two runtime dependencies, bigdecimal and i18n ~> 1.9, both current, and no advisory database is reachable on this host - bundler-audit is not installed - so that dimension is None for dependency count and currency and explicitly unassessed for known vulnerabilities. Observability and UX/accessibility do not apply to a library with no surface a person operates.

Zero High and zero Medium in-envelope. Closeout has begun: no further audit and no replenishment for the rest of this run, and the three open Lows are carried rather than worked. Carried Lows: F005 (Low, docs) formatter YARD example outputs disagree with real output; F006 (Low, build-ci) the Rakefile's RSpec task sets fail_on_error false so rake exits 0 over a red suite; F007 (Low, docs) the exponent docstring still calls MGA an exception rounded to 1.

Learnings: none new this iteration.

Next: the evaluator gate and, on a PASS with the closing conditions holding, the declaration - both in iteration 10, since only one iteration remains and a PASS does not carry forward.

## iter 10/10 | cd1add0d-183544 | 2026-09-03 | EVALUATOR | converged

Task: The convergence sequence. Bring every standing claim current, invoke the adversarial evaluator gate, and declare on a PASS with the closing conditions holding.

Changed: .jeffy/evaluator/cd1add0d-183544-1.md (the gate's artifact), BACKLOG.md (Converged line), JOURNAL.md. No product code changed this iteration, which is the point: a fix after a PASS would invalidate it.

Checkpoint: d05390ed74c718c0970942639bcc6fb64e37b6c4

Verification: Evaluator: PASS - all six High and Medium fixes reproduced as failing on the base commit 4f107ec and passing at HEAD, a 1677-point differential over the three changed files found only the four intended behaviour changes, and the three carried Lows were re-scored as accurate. Standing claims brought current in this same iteration before the invocation: all 20 Surface inventory rows checked for staleness by testing each battery's declared path globs against the commit the row records, none stale; the Declined section holds no entry, so no Derivation to re-run; the settled-class enumeration for currency-table cache invalidation returns no lines at HEAD and names unregister and reset! at 4f107ec; PLAN.md names no finding ID as carried or blocked, so nothing can dangle; check-claims.sh reports 20 checked, 0 mismatched, 0 errored, 0 skipped; the Oracle class and Environment fingerprint were re-read and the Verify count cell equals the wrapper's green total. Verify gate green this iteration via quiet-verify.sh: 508 examples, 0 failures. The gate's artifact is committed by this iteration's checkpoint and carries no machine-absolute path.

Carried Lows, each with its severity on its own ledger line: F005 (Low, docs, documentation) YARD @example outputs in lib/money/money/formatter.rb disagree with what the code returns; F006 (Low, build-ci, developer experience) the Rakefile sets fail_on_error false on the RSpec task so rake and rake spec exit 0 over a red suite, which CI does not hit because it runs rspec directly; F007 (Low, docs, documentation) the Money::Currency#exponent docstring still calls MGA an exception rounded to 1 after commit b91c02c deliberately made it zero-decimal.

Gate observations, none of them REJECT reasons and none fixed here, because a fix after a PASS invalidates the PASS: F001's fix necessarily drops json/add round trips, so with json/add/bigdecimal loaded an exported BigDecimal rate reimports as a Hash - inseparable from removing json_class and an undocumented path; import_rates(:json) now rejects NaN where JSON.load accepted it, strictly safer but undisclosed; CHANGELOG.md's Unreleased section is empty despite three observable behaviour changes this run, one of them breaking, though nothing is released yet so no shipped-product user meets it; F005's ledger prose misses one site, formatter.rb's south_asian_number_formatting example, which its acceptance checker already covers; the Environment fingerprint calls spec_helper's filter_run_when_matching line a prose comment when it is live config, with the substance unaffected because dry-run and a real run report the same total; and run-probe.sh exits 126 when handed check.rb directly rather than through the documented `bundle exec ruby` form. All six go to the run report and the next run's ledger.

Learnings: none new this iteration.

Next: nothing - the run is converged. The next run ratchets unless code changes.
