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

## iter 1/10 | c670883d-200852 | 2026-08-24 | AUDIT | audit

Task: First audit. Filled the Operating envelope, the Verify command with its Oracle class and Environment fingerprint, and the 20-row Surface inventory in PLAN.md; probed every row breadth-first with known-answer checks before filing.

Changed: PLAN.md (envelope surfaces, verify command block, inventory rows), BACKLOG.md (4 Medium, 4 Low), .gitignore (loop state), created .venv (gitignored).

Checkpoint: ff4875a140830fc0c632524dd7eee9e84a5fcd2d

Verification: Baseline suite green before any edit: 1190 passed in 1.42s. Every test module also runs green in isolation (test_utils 19, test_error_store 31, test_exceptions 7, test_registry 10, test_options 10, test_context 12, test_validate 221, test_schema 203, test_fields 108, test_serialization 129, test_deserialization 396, test_decorators 44), so the suite hides no order dependence. mypy exits 0 over 36 source files. Breadth-first known-answer sweep of all 20 rows - 60 assertions across scalar, temporal, container, network, enum, validator, utils, schema, nested, decorator, error-store, registry, orderedset and context surfaces - returned one mismatch against my expectation, `load(partial=True)` not applying `load_default`; reading `Schema._deserialize` shows that is deliberate PATCH semantics (the missing field is skipped before defaults are consulted) and no doc claims otherwise, so it is not filed. Artifact channels enumerated by command: the only packaging manifest is `[tool.flit.sdist]` in pyproject.toml (no MANIFEST.in, package.json, gemspec, nuspec or Dockerfile) and the only workflow artifact is `dist/` from `uv build`; `python -m build` produced marshmallow-4.3.1.tar.gz and the wheel, and grepping both for PLAN/BACKLOG/JOURNAL/.jeffy/.claude returned nothing, so the loop's state files cannot reach a published artifact. Nothing filed there. Verify gate green through quiet-verify.sh: `verify: green (1s, oracle=unit and behaviour tests..., 1190 passed in 0.63s)`. No stall: BACKLOG.md gained 8 task lines and .gitignore changed.

Scores (fresh evidence; every one of the 20 inventory rows is still unswept, so these claim the breadth-first probe above and not the unexamined remainder): architecture None, code quality None, security None (no eval/exec/pickle/subprocess/__import__ anywhere in src by grep; validate.URL and validate.Email timed on adversarial hyphen-repetition input showed no backtracking blowup), testing Low (ML-04), error handling Medium (MM-02, ML-02, ML-03), performance None, documentation Medium (MM-03, MM-04), dependency hygiene None (two conditional deps, both python_version < 3.11 backports), developer experience None, correctness Medium (MM-01, ML-01), observability not applicable (a serialization library with no logging surface; errors are returned as structured messages), UX and accessibility not applicable (no user-facing surface). Zero High.

Learnings: `uv` is not installed on this host, so the project's `uv run tox` entry point is unavailable; the suite runs through `.venv/bin/python -m pytest -q`, created with `python3 -m venv .venv && .venv/bin/pip install -e . pytest simplejson mypy types-simplejson`. Three of the four Mediums trace to two 4.0 removal commits that left their documentation, type surface or error path behind: 747c198b (implicit field creation) and 68c68e3a (Boolean serialization).

Next: MM-01, the top unblocked item.

## iter 2/10 | c670883d-200852 | 2026-08-24 | SWEEP | done

Task: Sweep. The map outranks everything but an open High and the ledger held none, so this iteration built and ran a known-answer battery for all 20 Surface inventory rows.

Changed: .jeffy/probes/ (20 batteries, a shared assertion harness in _lib.py, and run-all.sh), BACKLOG.md (MH-01 High, MM-05 Medium), PLAN.md (20 rows flipped to swept in the bookkeeping edit).

Checkpoint: b128257d1802d69de595578fa456c0a36c91d4ca

Verification: `.jeffy/probes/run-all.sh` exits 0 with 783 checks across the 20 batteries. Every battery is differential by construction: each documented parameter is driven at two or more values with separately hand-computed known answers, so a parameter that stops being read collapses its arms and the battery fails rather than passes. That shape is what earned its keep here - two of the three findings this iteration surfaced came from an arm whose two values gave the same answer. Boundary and negative sides are included throughout (Range at its own bound with min_inclusive both ways, Length at min=0, TimeDelta over all seven precisions, DateTime over all five formats, Url and IP with each parameter judged on an input the two arms must disagree about). Verify gate green through quiet-verify.sh: `verify: green (1s, oracle=unit and behaviour tests..., 1190 passed in 0.62s)`. No stall: 20 inventory rows changed state and BACKLOG.md gained two task lines.

Findings surfaced by the sweep, both filed at rubric severity in this iteration:
MH-01 (High): the fields-base battery asserted that `validate=lambda v: v > 0` rejects -1, as `Field`'s own `:param validate:` docstring says it must. It does not. 1fb712c7 made `And.__call__` read only raised ValidationErrors and never return values, but the API reference still documents the 3.x boolean contract, so a schema written the way the docstring instructs validates nothing at all - `fields.Int(validate=lambda v: v >= 18)` accepts `{"age": 5}` and `Schema.validate` returns `{}` - on the surface the envelope classes adversarial. `docs/upgrading.rst` documents the change correctly; the parameter reference does not. The dead `validator_failed` message still sitting in `Field.default_error_messages` is the rest of that cleanup.
MM-05 (Medium): the class-registry battery asserted `get_class(name, all=True)` returns a list. It returns the bare class whenever exactly one class is registered, because the `all` branch is inside `if len(classes) > 1`, while the typing overload declares `list[SchemaType]`; indexing, len and iteration all raise TypeError, and mypy exits 0 over a file doing exactly that. Filed Medium rather than the rubric's High because class_registry declares itself private API.

Three-strike rule applied: MM-03 (`Meta.additional` declared but read by nothing), MM-04 (Boolean's "(de)serialize" docstring) and MH-01 (the validate docstring plus the dead error message) are three findings sharing one root cause - a 4.0 removal that left its documentation or error surface behind. Instance patching stops here. MH-01 carries the structural acceptance check for the whole class: an enumeration of every documented `:param:`, every `default_error_messages` key and every `Schema.Meta` option against what the code actually reads. Closing it closes MM-03 and MM-04 with it, and no fourth instance is to be patched on its own.

Learnings: batteries pinning behaviour that an open finding will change carry a `# Pinned, open finding <ID>` comment naming the ID, so the iteration that fixes it knows which arm to update in the same iteration. Six arms across five batteries are marked that way today (MH-01, MM-01, MM-02, MM-03, MM-04, MM-05, ML-01, ML-02, ML-03). Differential arms must compare behaviour, not error text: three arms first written as message comparisons passed vacuously because the two parameter values produce the same message.

Next: MH-01, the only open High.

## iter 3/10 | c670883d-200852 | 2026-08-24 | MH-01 | done

Task: MH-01 (High), the only open High and the structural task the three-strike rule assigned to the class "a 4.0 removal left its documentation or error surface behind". Closed class-complete, which closed MM-03 and MM-04 with it.

Changed: src/marshmallow/fields.py, src/marshmallow/schema.py, tests/test_fields.py, tests/mypy_test_cases/test_schema.py, CHANGELOG.rst, .jeffy/probes/documented-surface/ (new battery), and the three probe arms that pinned the old behaviour.

Checkpoint: 7751069f3b8ca45cbfe70895a7e7044fd2181872

Verification: The acceptance check is `.jeffy/probes/documented-surface/check.py`, which enumerates three declared surfaces from the AST rather than from a hand-written list - every `default_error_messages` key on every Field subclass against every key any `make_error` call site can ask for, every option declared on `Schema.Meta` against every option `SchemaOpts.__init__` reads, and every `:param <name>:` in a public field or validator docstring against the parameters that class accepts. Run against the unfixed tree it failed 3 of 5 checks and named four members of the class, two more than the ledger knew about: `validator_failed` on Field, `format` on `_TemporalField`, `Date` and `TimeDelta`, `additional` on `Schema.Meta`, and `default` on `Url`. After the fix it passes 5 of 5. Battery ownership: the diff touched fields.py and schema.py, so every battery was re-run - `.jeffy/probes/run-all.sh` exits 0 with 21 batteries green. Verify gate green through quiet-verify.sh: `verify: green (1s, oracle=unit and behaviour tests..., 1189 passed in 0.71s)`. mypy exits 0 over 36 source files.

The suite count moved from 1190 to 1189 by one case, and that is the whole delta: `TestErrorMessages.error_messages` is a parametrize table and one of its four tuples asserted that `make_error("validator_failed")` returns "Invalid value.". That tuple went with the message it pinned. No test lost an assertion about behaviour that still exists.

Contract preserved and rationale for the observable changes, per the Constraints. `Field.default_error_messages` no longer carries `validator_failed`, and the three temporal fields no longer carry `format`. Both are removals of keys no code path can reach: the AST enumeration above is the evidence, and it is the executing check for that generalisation rather than a claim about it. `validator_failed` became unreachable in 4.0 when 1fb712c7 stopped `And.__call__` reading validator return values; `format` became unreachable in 3.0 when serialization stopped validating, which `docs/upgrading.rst` still shows correctly as a 2.x example. The one behaviour a user could still have depended on is a custom Field subclass calling `self.make_error("validator_failed")` or `self.make_error("format")`, which now raises AssertionError naming the missing key rather than returning a message; that is recorded in CHANGELOG.rst under Other changes. Removing the `additional` declaration from `Schema.Meta` changes no type checking, because mypy does not object to an undeclared attribute on a Meta subclass either way - the same property that makes the mypy test case unable to fail, which is ML-04. No public signature, no accepted input and no serialization behaviour changed, so no Surface inventory row's contract moved; all 20 rows are re-recorded at this checkpoint because their batteries were re-run against the new commit.

Closed this iteration: MH-01 (High) - the `Field` `:param validate:` docstring now states that a validator must raise and that its return value is ignored, with a 4.0.0 versionchanged note, and the unreachable error messages are gone. MM-03 (Medium) - `Schema.Meta.additional` removed from the declaration and from the mypy test case. MM-04 (Medium) - `Boolean`'s `truthy`/`falsy` docs say deserialization only, with a note that serialization passes the value through and a 4.0.0 versionchanged. Settled classes gained one line naming the enumerating check.

Learnings: `.jeffy/probes/documented-surface/` is a cross-cutting battery that no Surface inventory row names, because what it certifies is a property of the whole declared surface rather than one module; `run-all.sh` runs it every iteration, and the closing gate's staleness derivation simply does not apply to it. Anchoring a state-file edit on a sentence retyped from memory failed three times this iteration against text that only looked identical; anchor on a short unique substring or a regex, and assert with a message that names which anchor missed.

Next: MM-01, the top open Medium.

## iter 4/10 | c670883d-200852 | 2026-08-24 | MM-01 | done

Task: MM-01 (Medium) - `class_registry.register` kept the first-registered class under the bare class name when a same-named class from the same module registered again, while replacing the module-qualified entry, so `fields.Nested("Name")` silently used an outdated schema after a module was re-executed.

Changed: src/marshmallow/class_registry.py, tests/test_registry.py, CHANGELOG.rst, .jeffy/probes/class-registry/check.py, PLAN.md (Oracle class).

Checkpoint: 53c0415cedc933592bc790454e3000d4836c3865

Verification: The filed reproduction ran first, against the unfixed tree, and reproduced: bare name gave the class declaring `old`, full path gave the class declaring `new`, `agree: False`. After the fix both keys resolve to the second class and `Nested("Target")` reaches it. Four tests in tests/test_registry.py were then run against the unfixed code by restoring HEAD's class_registry.py over a copy of the fixed file and putting the fixed file back afterwards - never a git checkout over the uncommitted fix - and all four failed; against the fix all twelve pass. Two of those four are pre-existing tests: `test_serializer_class_registry_override_if_same_classname_same_module` and `test_serializer_class_registry_register_same_classname_different_module` both name replacement in their titles and comments but asserted only `len(result)`, which cannot tell replacement from keeping the stale entry, so this iteration gave them the identity assertions they were missing. The two new tests are `test_class_name_and_full_path_agree_after_reregistration` and `test_nested_by_class_name_resolves_to_the_newest_class`; the second drives the real load path rather than reading `.schema` off a `Field`, which is also what mypy requires. Battery ownership: the diff touched class_registry.py, matching the class-registry and fields-nesting batteries; `.jeffy/probes/run-all.sh` exits 0 with all 21 green, and the class-registry battery grew arms covering a second module keeping its own entry and a re-registration replacing only its own. Verify gate green through quiet-verify.sh: `verify: green (1s, oracle=..., 1191 passed in 0.64s)`. mypy exits 0 over 36 source files. No stall: MM-01 left the ledger.

Contract preserved: `register` still keeps at most one entry per (classname, module) pair, still aggregates classes of one name from different modules so the bare name stays ambiguous and `get_class(all=True)` returns both, and still creates a fresh list for an unseen name. What changed is only which entry survives when the module already present registers again - the newest rather than the first - which is what the function's own comment and both existing test names already claimed. The module-qualified branch already behaved this way, so the fix removes a disagreement inside one function rather than introducing a new behaviour. CHANGELOG.rst records it under 4.4.0 bug fixes.

Claims re-executed: PLAN.md's Oracle class stated 1190 pytest cases, which this iteration's two new tests invalidated. Rather than write 1191 and leave the next fix to trip over it, the line now says the count is the one the verify gate's own summary reports - the shape the command returns, not a frozen number.

Closed this iteration: MM-01 (Medium).

Learnings: a test whose name states a contract but whose assertions only count entries cannot fail for the defect it appears to cover; both registry tests here were exactly that, and adding one identity assertion to each turned them into instruments. Before claiming mypy clean, run it: `.venv/bin/mypy --show-error-codes` rejected a first draft of the new test for reading `.schema` off the declared `Field` type, which is not part of the Verify command but is part of CI.

Next: MM-02, the next open Medium.

## iter 5/10 | c670883d-200852 | 2026-08-24 | MM-02 | done

Task: MM-02 (Medium) - `Schema._init_fields` raised a bare `KeyError` when `class Meta.fields` named an undeclared field, where the same mistake through `only` or `exclude` raises `ValueError("Invalid fields for ...")`.

Changed: src/marshmallow/schema.py, tests/test_schema.py, CHANGELOG.rst, .jeffy/probes/schema-options/check.py, BACKLOG.md (ML-05 filed).

Checkpoint: 091a0a566b63cceacd9907c60ac22e60791666a6

Verification: The filed reproduction ran first and reproduced `KeyError('nope')`, with the `only` and `exclude` contrast raising `ValueError` on the same mistake in the same schema. After the fix, `Meta.fields = ("a", "nope")` raises `Invalid fields for <Bad(many=False)>: OrderedSet(['nope'])` at instantiation. Three tests were added to tests/test_schema.py; run against HEAD's schema.py restored over a copy of the fixed file, the two that assert the new error failed and the third - that a `Meta.fields` naming only declared fields still selects and dumps them - passed both ways, which is what it is for. Battery ownership: the diff touched schema.py, so every battery was re-run; `.jeffy/probes/run-all.sh` exits 0 with 21 green, and the schema-options battery's pinned MM-02 arm now asserts ValueError plus three arms on the message and the masked case. mypy exits 0 over 36 source files. Verify gate green through quiet-verify.sh: `verify: green (1s, oracle=..., 1194 passed in 0.63s)`. No stall: MM-02 left the ledger and ML-05 joined it.

Contract preserved, and one deliberate widening. `Meta.fields` still selects the available field set and still composes with `only` and `exclude` exactly as before; every one of the four existing tests that uses `Meta.fields` still passes untouched, and all four happen to name undeclared fields already, which is why they each expect a ValueError today for a different reason. The widening is that an undeclared name in `Meta.fields` is now reported even when `only` masks it so the name is never looked up - previously that combination worked silently. Reporting it is the right reading: implicit field creation was removed in 4.0, so an undeclared name in `Meta.fields` can never bind to anything, and `docs/upgrading.rst` already presents exactly that pattern as the 3.x form with a 4.x replacement. The alternative - reporting only when the name is actually selected - would keep a latent error latent until a later `only` change surfaced it as a KeyError. Recorded in CHANGELOG.rst under 4.4.0 bug fixes.

Filed while executing: ML-05 (Low) - the 4.x snippet in that same upgrading section declares `email = fields.Date()` where the dataclass it converts has `birthdate` and no email. Scored below the rubric's Medium for misleading documentation with the rationale on the task line: the prose and the pattern are correct and only an identifier inside the snippet disagrees with its own setup.

Closed this iteration: MM-02 (Medium).

Learnings: I ran `.venv/bin/python -m pytest -q` directly once this iteration to see the whole suite against the fix, which the iteration prompt forbids - the wrapper exists to bound exactly that output, and a targeted `pytest -k` run against the restored pre-fix file is the only raw invocation an acceptance check needs.

Next: MM-05, the last open Medium.

## iter 6/10 | c670883d-200852 | 2026-08-24 | MM-05 | done

Task: MM-05 (Medium) - `class_registry.get_class(name, all=True)` returned the bare class rather than a list whenever exactly one class was registered under that name, while its `typing.overload` declared `list[SchemaType]`.

Changed: src/marshmallow/class_registry.py, tests/test_registry.py, tests/mypy_test_cases/test_class_registry.py, CHANGELOG.rst, .jeffy/probes/class-registry/check.py.

Checkpoint: 1f538ed6d4e2db12f9f555ef3184e15b9080ede0

Verification: The filed reproduction ran first and reproduced on the unfixed tree: `get_class("SoloRepro", all=True)` returned a `SchemaMeta`, and indexing, `len` and iteration each raised TypeError. The `all` branch sat inside `if len(classes) > 1`, so it was reachable only when the name was ambiguous; it now returns `classes` before the ambiguity check, and the ambiguity check keeps its old job for `all=False`. After the fix a single match gives `[cls]` that indexes, measures and iterates, several matches still give a list, `all=False` still returns the class for one match and still raises RegistryError for several. The second overload also declared a default (`all: typing.Literal[True] = ...`) which it does not have; that default is gone, and a call with no `all` still resolves to the single-class overload, which `tests/mypy_test_cases/test_class_registry.py` exercises. Three tests: `test_single_class_with_all_returns_a_list` fails against HEAD's class_registry.py restored over a copy of the fixed file, `test_all_false_is_unchanged_for_a_single_class` and the strengthened `test_multiple_classes_with_all` pass both ways, which is what they are for. Battery ownership: the diff touched class_registry.py, matching the class-registry and fields-nesting batteries; `.jeffy/probes/run-all.sh` exits 0 with 21 green. mypy exits 0 over 36 source files. Verify gate green through quiet-verify.sh: 1196 passed in 0.74s. No stall: MM-05 left the ledger.

Contract preserved: `all=False` is untouched in both its arms, and `fields.Nested`, the only caller in the library, passes `all=False`. What changed is that `all=True` now honours its declared return type in the single-match case. That is a behaviour change for anyone who relied on the old shape, and CHANGELOG.rst records it under 4.4.0 bug fixes; the old shape could not be relied on in general, since the same call returned a list as soon as a second class of that name was registered.

Honest note on the mypy case: the annotations added to `tests/mypy_test_cases/test_class_registry.py` type-check identically before and after this fix, because the declaration was already right - the defect was the implementation disagreeing with it. Those annotations guard the declaration against a future regression; the runtime test is what discriminates this bug. Saying so matters because the opposite claim is exactly the weakness ML-04 records about these cases.

Closed this iteration: MM-05 (Medium). The ledger is now at the severity floor: zero High, zero Medium, five Low.

Learnings: when a typed overload and its implementation disagree, only a runtime test discriminates; a type-level assertion added in the same iteration proves the declaration, not the behaviour, and claiming otherwise would misreport the evidence.

Next: the ledger holds no High or Medium and the map is swept, but no full fresh-evidence audit this run has scored clean - the iteration 1 audit predates six fixes. With four iterations left, the closing sequence needs a fresh full audit before the evaluator gate, so that audit is next.

## iter 7/10 | c670883d-200852 | 2026-08-24 | AUDIT | audit

Task: Closing full audit. The ledger reached the severity floor at iteration 6 and the map is swept, but the only full audit on this run's record was iteration 1's, which predates six fixes, so a declaration could not stand on it.

Changed: BACKLOG.md (MH-02 and MH-03 filed).

Checkpoint: 6202586363bc57a778aff98aed0820f4c9acb683

Verification: Fresh evidence, every figure from a command run this iteration. All 21 probe batteries green, 802 checks, `run-all.sh` exit 0. Every test module run in isolation, all green (test_utils 19, test_error_store 31, test_exceptions 7, test_registry 14, test_options 10, test_context 12, test_validate 221, test_schema 206, test_fields 107, test_serialization 129, test_deserialization 396, test_decorators 44), so the suite still hides no order dependence. mypy exit 0 over 36 source files. Standing claims re-derived rather than re-read: the Environment fingerprint's exclusion command still returns nothing for skip markers, xfail, platform and version guards, and `norecursedirs` still excludes `tests/mypy_test_cases` alone; the artifact channels are still the flit sdist config and the `dist/` upload, and a fresh `python -m build` produced a tarball and wheel that grep clean for PLAN, BACKLOG, JOURNAL, .jeffy, .claude and .venv, which matters more now that `.jeffy/probes/` holds 21 batteries than it did at iteration 1. The Declined section holds no entries, so there was no Derivation to re-run. Performance measured rather than assumed: load 11.5 us/row at 1k rows and 17.0 us/row at 10k, dump 4.1 and 5.1 us/row, and schema construction 0.05, 0.37 and 0.94 ms at 10, 100 and 400 fields - linear in both, no quadratic path.

The audit is not clean, so closeout does not begin. Three reproduced defects, two root causes, both in schema.py's validator dispatch and both found by driving combinations the batteries had not: `attribute` together with `@validates`, and a collection `pre_load` that changes the item count.

MH-02 (High): a `@validates` validator on a field whose `attribute` contains a dot is never invoked. `_invoke_field_validators` reads `data[field_obj.attribute or field_name]`, but `_deserialize` wrote that value through `set_value`, which turns a dotted attribute into nested dicts, so the lookup raises KeyError into an `except KeyError: pass` and the validator is skipped in silence. Evidence is a call counter, not a reading: with `a = fields.Integer(attribute="x.y")` and a validator that raises unconditionally, `load({"a": 1})` returns `{'x': {'y': 1}}` and the validator records zero invocations, while the same validator on a flat `attribute` and on no `attribute` records one and raises. It holds under `many=True` and with `data_key` set. The second symptom of the same root cause is the pop: on rejection the code pops `field_name` though it read `attribute or field_name`, so with a flat `attribute` the rejected value stays in `ValidationError.valid_data` as `{'z': -1}` where without `attribute` it is removed. Filed as one task because it is one root cause - the function does not use the accessor that wrote the value - and the Method files root causes, not symptoms.

MH-03 (High): `_invoke_schema_validators` pairs items with `zip(data, original_data, strict=True)`, so a `@pre_load(pass_collection=True)` that changes the item count makes `load` raise `ValueError: zip() argument 2 is shorter than argument 1`. Reproduced in both directions, appending and dropping, each with an ordinary non-collection `@validates_schema` present. The documented use of a collection pre_load is envelope unwrapping, and filtering is a step away from it.

Both are in code unchanged since the iteration 1 audit, and both rest on a reproduced failure rather than a closer reading, which is what the Method requires to file there. What the batteries missed was the combination: schema-hooks drove `@validates` with `data_key`, fields-base drove `attribute` through load and dump, and neither crossed them. tests/test_decorators.py covers `attribute="string_name"`, flat, and nothing covers a dotted one.

Scores, fresh evidence, all 20 inventory rows swept at the current commit so these claim the whole mapped surface: architecture None, code quality None, security High (MH-02), testing Low (ML-04), error handling High (MH-03) with Low (ML-02, ML-03), performance None (measured above), documentation Low (ML-05), dependency hygiene None, developer experience None, correctness High (MH-02) with Low (ML-01), observability not applicable (a serialization library with no logging surface), UX and accessibility not applicable (no user-facing surface). Two High, zero Medium.

Learnings: a battery per row certifies each surface and still misses what only appears where two surfaces meet; both Highs here live in the crossing of `attribute` with the validator dispatch and of a collection hook with the per-item one. A row-shaped map has seams, and the closing audit is where they get driven.

Next: MH-02 at iteration 8 and MH-03 at iteration 9, then the evaluator gate and, if it passes, the declaration at iteration 10. That is exactly the remaining budget with no slack: a fix needing a second iteration ends the run out of budget with the findings filed and their acceptance checks written, and the next run closes them.

## iter 8/10 | c670883d-200852 | 2026-08-24 | MH-02 | done

Task: MH-02 (High) - `Schema._invoke_field_validators` read the deserialized mapping with a flat lookup and removed rejected values by field name, while `Schema._deserialize` had written them through `set_value`. Two symptoms, one root cause.

Changed: src/marshmallow/schema.py, tests/test_decorators.py, CHANGELOG.rst, .jeffy/probes/schema-hooks/check.py.

Checkpoint: 798ee4fa163d8be2e23dc96d25ff0e407bebe1e3

Verification: The filed reproduction ran first and reproduced both symptoms on the unfixed tree: with `attribute="x.y"` the load returned `{'x': {'y': 1}}` and the validator recorded zero invocations, and with `attribute="z"` the rejected value survived in `valid_data` as `{'z': 1}`. After the fix all three arms - no attribute, flat attribute, dotted attribute - behave identically: the validator is invoked once, the error is reported under the field name, and `valid_data` is `{}`; under `many=True` the error is indexed and `valid_data` is `[{}]`; and a passing validator leaves a dotted attribute nested as `{'x': {'y': 1}}`. Six tests were run against HEAD's schema.py restored over a copy of the fixed file: three failed - the dotted-attribute validator test and the `valid_data` test at its `string_name` and `nested.name` parameters - and three passed both ways, which is what the `None` parameter, the pre-existing `test_validates_with_attribute` and the passing-validator test are for. Battery ownership: the diff touched schema.py, so every battery was re-run and `.jeffy/probes/run-all.sh` exits 0 with 21 green; schema-hooks gained a loop that drives the seam directly, asserting invocation count, message shape and `valid_data` for all three attribute forms in both the single and many paths. mypy exits 0 over 36 source files. Verify gate green through quiet-verify.sh: 1201 passed in 0.65s. No stall: MH-02 left the ledger.

Contract preserved: the validator dispatch reads the value with `get_value`, the accessor that matches the `set_value` the deserializer used, and skips the field when it is absent exactly as the old `except KeyError: pass` did - `get_value` returns the `missing` sentinel there, and `_deserialize` only writes when the value is not missing, so no legitimate value can be mistaken for absence. Removal now goes through a new module-private `_remove_value` that mirrors `set_value`: a dotted key is a path, and a container the removal leaves empty goes with it, so a rejected value produces the same mapping the field would have produced had it never been written. That is why the flat and dotted cases now agree with the no-attribute case rather than merely with each other. The helper is private to schema.py rather than added beside `set_value` in `marshmallow.utils`, which is a documented module: the fix needs one call site, not new public surface.

Closed this iteration: MH-02 (High), covering both the silent validator bypass and the rejected value surviving in `valid_data`.

Learnings: when two functions address the same mapping, they have to agree on the accessor; here `_deserialize` wrote with a dotted-aware `set_value` and the validator dispatch read with a flat subscript, and the mismatch failed silently because the miss landed in an `except KeyError: pass`. A bare `except KeyError: pass` around a lookup whose key is computed elsewhere is where a bypass hides.

Next: MH-03, the last open High, at iteration 9; then the evaluator gate and, if it passes, the declaration at iteration 10.

## iter 9/10 | c670883d-200852 | 2026-08-24 | MH-03 | done

Task: MH-03 (High) - `Schema._invoke_schema_validators` paired deserialized items with the raw input using `zip(..., strict=True)`, so a `pass_collection` pre-load that changed the item count raised `ValueError` out of `load`.

Changed: src/marshmallow/schema.py, tests/test_decorators.py, CHANGELOG.rst, .jeffy/probes/schema-hooks/check.py.

Checkpoint: d8b58045794fce4630e6fec11a76ae5411987280

Verification: The filed reproduction ran first and reproduced both directions on the unfixed tree, `zip() argument 2 is shorter than argument 1` when a hook appended an item and `longer` when one dropped one, with an ordinary `@validates_schema` that never asked for the original. Probing the documented use of a collection pre-load - envelope unwrapping, the example in the decorators module docstring - found the sharper half: after unwrapping, the raw input is a mapping, so `zip` iterated its keys and a `pass_original` validator was handed the string `'results'` as the original for a one-item payload, silently, and raised ValueError for a two-item one. Enumerating the pairing sites by `grep -n "zip_longest\|zip(" src/marshmallow/schema.py` returned two, and provoking a failure at each confirmed the second: `_invoke_processors` pads with `zip_longest`, so a shrinking pre-load called a `pass_original` post-load hook with `data=None` and `load` returned `[{'a': 1}, None]`, a corrupt result rather than a crash. One root cause, two sites, both fixed here: pairing deserialized items positionally against a raw input whose length and shape a collection hook may have changed.

After the fix, growing and shrinking both load cleanly, the envelope case yields `None` per item instead of the mapping's keys, no hook is called for an item that does not exist, and `load` no longer returns a `None` entry. Four tests were run against HEAD's schema.py restored over a copy of the fixed file: three failed and `test_post_dump_pass_original_pairing_is_unchanged` passed both ways, which is what it is for. Ordinary dump pairing was captured before and after and is byte-identical for a list, a tuple and a generator - the generator already yielded `None` originals, because `dump` exhausts it while serializing, so the new rule reproduces that rather than changing it. Battery ownership: the diff touched schema.py, every battery was re-run, `.jeffy/probes/run-all.sh` exits 0 with 21 green, and schema-hooks gained a loop driving both hook kinds across all three reshapes. mypy exits 0 over 36 source files. Verify gate green through quiet-verify.sh: 1205 passed in 0.67s. No stall: MH-03 left the ledger.

Contract preserved: both sites now go through one module-private `_pair_with_originals`, which iterates the deserialized items - the things being validated or processed - and supplies the positional original where one exists and `None` where none does, treating a non-sequence raw input as having no per-item originals at all. Where the counts and the shape match, which is every case without a reshaping collection hook, the pairs are exactly what `zip` and `zip_longest` produced, so no ordinary load or dump changes. What changes is only the three cases that were a crash, a corrupt result, or a bogus original. `zip_longest` is no longer imported. CHANGELOG.rst records all three under 4.4.0 bug fixes.

Closed this iteration: MH-03 (High). The ledger now holds zero High and zero Medium, and five carried Lows: ML-01 through ML-05.

Learnings: `strict=True` on a zip states that two sequences must correspond; when one of them is user-reshaped input, that is an assertion the caller can violate, and it surfaces as a bare ValueError from a library the caller expected to raise ValidationError. The sibling site padding with `zip_longest` instead was not safer - it turned the same mismatch into a None in the result - so the fix had to be one shared pairing rule rather than making the two sites agree on either extreme.

Next: the evaluator gate at iteration 10 and, if it returns PASS and the closing conditions hold, the declaration in that same iteration.

## iter 10/10 | c670883d-200852 | 2026-08-24 | EVALUATOR | converged

Task: The evaluator gate, and the declaration in the same iteration. Invocation 1 returned REJECT with two substantiated High reasons, both regressions this run had introduced; both were fixed under the one-transaction rule and invocation 2 returned PASS.

Changed: src/marshmallow/schema.py, tests/test_decorators.py, CHANGELOG.rst, .jeffy/probes/schema-hooks/check.py, BACKLOG.md (ML-06 and ML-07 filed and carried), .jeffy/evaluator/ (both artifacts).

Checkpoint: e29ed17e989b572548c277450daab40837cf334b

Verification: Evaluator: PASS - invocation 2 rebuilt both rejection reasons with its own instruments, observed them failing on the rejected tree d8b58045 and passing on HEAD, confirmed the earlier MH-02 and MH-03 fixes still hold, and found no missed in-envelope High or Medium across a 591-line differential harness over attribute, data_key, unknown, many, partial and four payload shapes. Artifacts: `.jeffy/evaluator/c670883d-200852-1.md` (REJECT) and `-2.md` (PASS), both committed, neither carrying a machine-absolute path, and the first unmodified since it was committed.

Before either invocation the standing claims were brought current in this same iteration: all 20 Surface inventory rows re-recorded and mechanically checked for staleness against each battery's own `paths` file (none stale), the Declined section confirmed empty so no `Derivation:` needed re-running, and the Oracle class and Environment fingerprint re-read with the fingerprint's exclusion command re-derived (still no skip marker, xfail, platform or version guard anywhere in the test tree; `tests/mypy_test_cases` remains the sole pytest exclusion).

The two rejection reasons, both mine, both introduced by fixes earlier in this run:
Reason 1 (High): the MH-02 fix reached for `marshmallow.utils.get_value`, whose documented getattr fallback made an absent field named after any public `dict` attribute resolve to a bound method and be validated. A field named `items` with an ordinary length check crashed `load({})` with TypeError. My iteration 8 entry had asserted the opposite - that no legitimate value could be mistaken for absence - as a generalisation I never enumerated. The enumeration exists now and returns 11 names. Fixed by `_lookup_value`, a mapping-only dotted-aware read that mirrors `set_value` and `_remove_value` and never touches attributes.
Reason 2 (High): the MH-03 fix gated originals on `is_sequence_but_not_string`, so `dump(many=True)` with a `pass_original` post-dump hook passed `None` for a set, a `dict` view or an ORM queryset, where `zip_longest` had paired them. My iteration 9 entry claimed dump pairing was byte-identical "for a list, a tuple and a generator" - an enumeration that omitted precisely the class the change moved. Fixed by gating on `is_collection` and materialising once; the generator still yields `None` originals, which invocation 2 verified against the baseline rather than taking on trust.

Both fixes carry tests that were observed failing on the rejected tree: 12 of 13 selected cases failed there, the thirteenth being the arm that must pass either way. The dict-attribute test derives its parameters from `dir(dict)` by command rather than listing names. `.jeffy/probes/run-all.sh` exits 0 with 21 batteries green, mypy exits 0 over 36 source files, and the verify gate is green this iteration through quiet-verify.sh: 1218 passed in 0.69s.

Two gate observations that were not rejection reasons are carried rather than fixed, as the convergence sequence requires: ML-06, where `_remove_value` prunes a container the removal empties and takes a sibling empty mapping with it in `valid_data`; and ML-07, where `unknown=INCLUDE` lets a raw included key occupy the slot a validator reads. ML-07 I re-derived myself against the pre-run baseline before scoring it: the identical schema hands its validator the same raw string on 0c05c83d, so the class is pre-existing and unchanged by this run, and `unknown=INCLUDE` is the author's opt-in to raw keys in the output.

Carried Lows at declaration, each with its severity on its task line: ML-01, `dump(None, many=True)` returns `{}` where every other `many=True` dump returns a list. ML-02, `validate.Length` guards `equal` against `min`/`max` by truthiness, so a zero bound slips past and is then ignored. ML-03, `fields.Tuple._serialize` raises a bare `ValueError` from `zip(strict=True)` on a length mismatch, naming neither field nor length. ML-04, the mypy Meta case lists `ordered`, removed in 4.0, and cannot fail for an unknown option. ML-05, the 4.x snippet in the upgrading guide declares `email` where its dataclass has `birthdate`. ML-06 and ML-07 as above.

Closing conditions, each checked rather than asserted: the iteration 7 full audit is this run's anchoring audit and the only commits since it are the fixes for the two tasks it filed, the fixes for the two tasks the gate filed, and loop state edits, which `git log --oneline 62025863..HEAD` shows; the Surface inventory lists no unswept and no stale row; Now, Next and Later hold zero High and zero Medium; the Verify command exits 0 this iteration; the evaluator returned PASS at invocation 2 of a cap of 2; and a Converged line naming this iteration's checkpoint is appended under `## Converged` in BACKLOG.md.

Learnings: both rejection reasons were prose generalisations I wrote without the enumeration the Method requires - "no legitimate value can be mistaken for absence" and "byte-identical for a list, a tuple and a generator". Each was true of the cases I had run and false of the class. When a fix swaps one accessor for another, the enumeration that has to ship with it is of the inputs the two accessors disagree on, derived by command; `dir(dict)` and the container kinds were both one line of code away.

Next: nothing. The run is converged. The next run inherits seven carried Lows and a swept map.
