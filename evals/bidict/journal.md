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

## iter 1/10 | 7f88691b-142345 | 2026-09-01 | AUDIT | audit

Task: first audit. Fill the Operating envelope, the Surface inventory and the Verify command in PLAN.md, enumerate the artifact-producing channels, then audit the project breadth-first and seed BACKLOG.md.

Changed: PLAN.md (envelope surfaces, 16 inventory rows, Command / Oracle class / Environment fingerprint / Verify summary pattern / Verify count), BACKLOG.md (H1 in Now; L1-L4 in Later). No source file touched.

Checkpoint: 94ee76a8c610b47593ac51e5361b90441b66c27f (Lessons relocation folded into the bookkeeping commit below). Not a stall: this iteration is the first audit, it added five backlog items, and an AUDIT entry is a ceremony entry either way.

Verification: verify green via quiet-verify.sh - `317 passed`, 7s, matching the Verify count line. Artifact channels enumerated by command, not recall: `ls MANIFEST.in package.json .npmignore Cargo.toml *.gemspec *.nuspec` finds none, and `grep -rln 'build-backend|uv build|upload-artifact|docker build|tar -c|zip -r' pyproject.toml .github/workflows/ flake.nix` returns pyproject.toml plus the two release workflows and the two benchmark workflows; both release workflows archive the tree only through `uv build`. Built that channel to a scratch dir and listed both artifacts: the sdist holds PKG-INFO, pyproject.toml(.orig), LICENSE, README.rst and bidict/, the wheel holds bidict/ and dist-info only, so PLAN.md, BACKLOG.md, JOURNAL.md and .jeffy/ cannot reach a published artifact. `./check_dist` over those artifacts exits 0 (RECORD validates, twine check PASSED on both).

Dimension scores, on this iteration's exploratory probes and NOT on swept rows - all 16 Surface inventory rows are still unswept, since no kept battery exists yet under .jeffy/probes/, so every None below claims only what these probes touched: architecture None, code quality None, security None, error handling None, correctness None, performance not scored (no measurement taken this iteration), observability n/a (a stdlib-only mapping library with no logging or metrics surface), UX/accessibility n/a (no user-facing surface), testing Low (L3), documentation Low (L1, L2), developer experience Low (L4), dependency hygiene High (H1).

The probes behind the None scores were executed known-answer checks, not liveness checks: forward/inverse lookup and identity, values/keys/items ordering including after an overwrite, duplication policy across all three OnDupActions, rollback atomicity for put/putall/update including a generator that raises mid-stream and a backing mapping that rejects a write or a delete, ordered-bidict insertion order, move_to_end in both directions and through the inverse, popitem(last), mutation-during-iteration detection, 200-item churn with node accounting and fwdm/invm agreement, pickle and deepcopy round trips for all three public types and for a dynamically generated inverse class, view lifetimes outliving their bidict, set operations on all three views, frozenbidict hash/equality consistency, the documented no-reference-cycle promise under a disabled GC, nan keys, equal-but-distinct hashables, and the YoloBidict / YodoBidict / KeySortedBidict / WeakrefBidict recipes from docs/extending.rst. Every one matched its expected answer; coverage of bidict/ under the suite is 100% of statements bar `_typing.py`'s `python_version < '3.12'` import and one weakref-resolution branch in `_base.py`.

H1 is the audit's one High and it was reproduced, not inferred: typing_extensions 4.0.0 and 4.3.0 carry no `override` (checked by downloading both and grepping the module), 4.4.0 does, and installing the built wheel into a Python 3.11 venv at `--resolution lowest` pulls typing_extensions 4.0.0 and makes `import bidict` fail with `ImportError: cannot import name 'override' from 'typing_extensions'`. The same install with typing_extensions 4.4.0 imports and works. CI never sees it because every job installs from uv.lock, which pins typing_extensions 4.16.0 - which is L4.

Learnings: this host has no nix, tox, prek or uv on PATH, so the CONTRIBUTING/CLAUDE workflow of `nix develop --command ...` is unavailable and the gate must be driven from ./.venv directly. `.venv` was missing coverage, ty and pytest-sphinx, all declared in pyproject's test group; installing them left the suite at 317 passed. pytest 9 reads `[tool.pytest]` in pyproject.toml (not only `[tool.pytest.ini_options]`), so the project's addopts, testpaths and filterwarnings are all live - confirmed by `pytest --co` reporting `configfile: pyproject.toml` and `testpaths: bidict, tests, docs`.

Next: H1 - raise the typing_extensions floor to 4.4 and prove it with the recorded reproduction.

## iter 2/10 | 7f88691b-142345 | 2026-09-01 | H1 | done

Task: H1 (High, build-ci, dependency hygiene) - pyproject.toml's `typing_extensions>=4.0; python_version<'3.12'` floor admitted versions with no `override`, which bidict/_typing.py imports on those Pythons, so a permitted resolution produced a package that could not be imported.

Changed: pyproject.toml (floor raised to `>=4.4`, with a comment recording why the floor is load-bearing, in the same style as the neighbouring uv_build pin), uv.lock (the one `requires-dist` specifier that mirrors it), CHANGELOG.rst (new `0.24.2 (not yet released)` section, using the project's own "not yet released" heading convention as seen in the 0.24.1 release commit). docs/changelog.rst is a symlink to CHANGELOG.rst, so it needed no separate edit; confirmed with `git ls-files -s docs/` reporting mode 120000 for it. No source file touched, so no public interface or observable runtime behaviour changed - the contract this preserves is exactly bidict's import-time behaviour on every typing_extensions that could already import it; the change only narrows which typing_extensions a resolver may pair with bidict, and narrows it to the set that already worked.

Checkpoint: ebbe83d6f4f70990ae653ae3f9e9c5f24efdb107. Not a stall: pyproject.toml, uv.lock and CHANGELOG.rst all changed, and H1 left the ledger.

Verification: reproduction first, before the fix, exactly as filed - `uv build` to a scratch dir, `uv venv --python 3.11`, `uv pip install --resolution lowest <wheel>` resolved typing_extensions 4.0.0, and `python -c 'import bidict'` exited 1 with `ImportError: cannot import name 'override' from 'typing_extensions'`. After the fix the same sequence resolves typing_extensions 4.4.0 and `import bidict` plus a forward/inverse round trip exits 0 on CPython 3.11.16. Differential on the other side: `uv pip install <wheel> typing_extensions==4.3.0` is now refused by the resolver ("your requirements are unsatisfiable"), where before the fix it installed and then failed at import. The built wheel and sdist both carry `Requires-Dist: typing-extensions>=4.4 ; python_full_version < '3.12'`. Lockfile consistency checked with the uv version that wrote the lock (0.11.27, per uv.lock's own uv entry): `uv lock --check` exits 0 both before and after the edit, so the hand edit left pyproject.toml and uv.lock in agreement rather than merely looking edited. Verify gate green via quiet-verify.sh: `317 passed`, 7s, matching PLAN.md's Verify count. Re-ran the claims this diff invalidates: `./check_dist` over the rebuilt artifacts exits 0 (RECORD ok, twine check PASSED on wheel and sdist), neither artifact carries PLAN.md, BACKLOG.md, JOURNAL.md or .jeffy/, and update_dev_dependencies' uv_build pin check still holds (uv.lock uv 0.11.27 inside `>=0.8.13,<0.12`). No battery under .jeffy/probes/ exists yet, so battery ownership had nothing to run.

Learnings: uv.lock records the dependency specifier a second time, in `[package.metadata] requires-dist`, so a pyproject.toml floor change that skips uv.lock leaves `uv lock --check` failing and every tox env (runner = uv-venv-lock-runner) resolving the old floor. Check the lock with the uv version uv.lock itself names, not whatever uv is at hand, or the check reports format drift instead of the answer asked for.

Next: the ledger is at the severity floor - four open Lows and no High or Medium - so the queue's next item is the Surface inventory: 16 unswept rows, to be swept with kept known-answer batteries under .jeffy/probes/.

## iter 3/10 | 7f88691b-142345 | 2026-09-01 | SWEEP | done

Task: sweep Surface inventory rows. The ledger holds no High or Medium, so the map is the top of the queue; this iteration builds kept known-answer batteries and flips every row it can properly evidence.

Changed: .jeffy/probes/_lib.py (shared assertion harness) and six new batteries - dup-policy, iter-helpers, base-write-rollback, bidict-mutation-api, base-read-views, base-value-semantics, base-inverse-machinery - each with probe.py, paths, claims and README.md. PLAN.md: the corresponding inventory rows flipped to swept in the bookkeeping edit below. No source file touched, so no battery's declared paths moved under it.

Checkpoint: 32b9a937e38c35f5e03d06ac90cda45b17aa23a1. Not a stall: eight Surface inventory rows changed state and seven batteries were added.

Verification: every battery executed through the installed run-probe.sh and green - dup-policy 36/36, iter-helpers 27/27, base-write-rollback 46/46, bidict-mutation-api 49/49, base-read-views 93/93, base-value-semantics 107/107, base-inverse-machinery 62/62. Each battery also carries a recorded discriminating mutation that was executed and observed red, and both scores - clean and mutant - are claims lines, so check-claims.sh re-derives the instrument's power rather than taking its word: `check-claims.sh .` reports 14 checked, 0 mismatched, 0 errored, 0 skipped. Verify gate green via quiet-verify.sh: `317 passed`, 7s, matching PLAN.md's Verify count.

Two probe expectations were wrong and were corrected rather than filed, because in each case the code was right and the probe was not. First, a check asserting that `inverted()` returns a fresh iterator compared two separately-constructed map objects for identity; replaced with an exhaustion check that actually pins laziness. Second, and more usefully, a check asserted that holding a bidict's inverse keeps the original alive. It does not, and must not: docs/addendum.rst promises exactly the opposite - the reference in the inverse-to-original direction is a weakref precisely so that dropping your last reference to a bidict lets CPython reclaim it immediately rather than waiting for a collection. The battery now pins the documented behaviour from both sides: `inv.inverse is fwd` while a strong reference is held, the original is freed when it is not, and the data survives either way because both objects are views on the same two backing mappings.

No in-envelope finding was surfaced by any of the six sweeps: 418 known-answer and invariant checks across the six rows, all green against unmutated code.

Learnings: a probe that imports a shared harness must set `sys.dont_write_bytecode = True` before the import, or `__pycache__` lands in the tree and every claims run leaves the working tree dirty, which makes the next iteration's salvage check misfire. A battery's mutation should be chosen so the battery body still runs to completion under it - a mutation that makes the body raise part-way records a score that depends on where it aborted rather than on how much the mutation broke.

Next: ten inventory rows remain unswept - the ordered-bidict rows, frozenbidict, the abstract base classes, package exports, value types, and the two non-code rows (published distribution, published prose).

## Note (2026-09-01, run 7f88691b-142345)

Correcting two numbers in the iter 3/10 entry above, by appending rather than by editing it, since entries are append-only. That entry says "six new batteries" and then lists seven; seven is right, and `ls -d .jeffy/probes/*/` returns seven. It also says 418 checks across the six sweeps; the real total is 420, and it covers eight rows rather than six - the batteries and the rows are not one to one, because dup-policy sweeps both the duplication-policy row and the value-types row. Summing the clean scores recorded in the claims files gives 36 + 27 + 46 + 49 + 93 + 107 + 62 = 420, derived by `grep -h '^expect' .jeffy/probes/*/claims | sed -n 's/^expect [a-z-]*: \([0-9]*\)\/\([0-9]*\) checks passed :: \.venv.*/\2/p' | paste -sd+ | bc`. Nothing else in that entry changes: every battery was executed and green, and check-claims.sh reported 14 checked, 0 mismatched.

## iter 4/10 | 7f88691b-142345 | 2026-09-01 | SWEEP | done

Task: continue sweeping the Surface inventory. Six rows remained that could be evidenced from code alone; this iteration builds a kept battery for each.

Changed: six new batteries under .jeffy/probes/ - package-exports, abc-contract, frozen-hashing, ordered-linked-list, orderedbase-semantics, orderedbidict-mutators - each with probe.py, paths, claims and README.md, plus a small simplification to ordered-linked-list's weakref check written earlier in this same iteration. PLAN.md: the six corresponding rows flipped to swept in the bookkeeping edit below. No source file touched.

Checkpoint: 8e0f302209235d45fdedd72972d3f64a25cc091e. Not a stall: six Surface inventory rows changed state and six batteries were added.

Verification: every new battery executed through the installed run-probe.sh and green - package-exports 62/62, abc-contract 28/28, frozen-hashing 30/30, ordered-linked-list 36/36, orderedbase-semantics 58/58, orderedbidict-mutators 48/48. Each carries a recorded discriminating mutation that was executed and observed red, and both scores are claims lines. Across all thirteen batteries now on record, check-claims.sh reports 26 checked, 0 mismatched, 0 errored, 0 skipped. Verify gate green via quiet-verify.sh: `317 passed`, 7s, matching PLAN.md's Verify count.

One probe expectation was wrong in a way worth recording, because the code turned out to be right and the reasoning is not obvious. A check asserted that collapsing two items into one - the key-and-value-duplication branch of OrderedBidictBase._write - leaves the survivor in the same position whether the write goes through the forward mapping or through the inverse. It does not, and should not. The rule the code actually implements is that the node of the key being WRITTEN survives, in the key space of the mapping the write goes through: forward, `ob.forceput('a', 3)` on {a:1, b:2, c:3} keeps a's first position and yields [('a',3), ('b',2)]; through the inverse, `ob.inverse.forceput(3, 'a')` writes inverse key 3, keeps 3's last position, and yields [('b',2), ('a',3)]. Those are mirror images of one rule, not a discrepancy, and the two results hold the same items. The battery now pins the rule from both sides and asserts that the two orders differ while the contents agree, which is a stronger check than the literal answer I first wrote.

A second, smaller correction: a check tried to drive an init-time value-duplication overwrite through an immutable ordered bidict, but the default on_dup raises on a duplicate value, so the construction never reached the branch. It now uses a subclass carrying ON_DUP_DROP_OLD to reach it, and separately asserts that the default subclass still refuses that input.

No in-envelope finding was surfaced by any of the six sweeps: 262 further known-answer and invariant checks, all green against unmutated code, bringing the kept batteries to 682 checks over fourteen rows.

Learnings: when a battery's discriminating mutation makes the body raise part-way, the recorded mutant score reports where it aborted rather than how much the mutation broke; three candidate mutations were measured for orderedbase-semantics and the one that let the body run to completion was kept. This is the rule already in PLAN.md's Lessons, now applied rather than learned.

Next: two rows remain, both non-code - published distribution and published prose. The prose row cannot be evidenced green while L1 stands, since the dead links it would assert against are exactly that finding, so L1 is fixed first and the row swept after it.

## iter 5/10 | 7f88691b-142345 | 2026-09-01 | SWEEP | done

Task: sweep the published-distribution row, the first of the two remaining non-code rows.

Changed: .jeffy/probes/published-distribution/ (probe.py, paths, claims, README.md). PLAN.md: the row flipped to swept in the bookkeeping edit below. No source file touched. Also installed uv 0.11.27 into the untracked ./.venv so the battery runs in a bare shell; that is an environment change, not a tree change.

Checkpoint: eb1e7f8592db230b2e5641879d2a2ed1a1696880. Not a stall: one Surface inventory row changed state and a battery was added.

Verification: published-distribution 46/46 through the installed run-probe.sh, and its recorded discriminating mutation executed and observed red at 43/46. The mutation adds `source-include = ["PLAN.md"]` to [tool.uv.build-backend], which is exactly the leak the battery exists to catch, and it reddens the exact-member check, the tolerated-variance check and the by-name PLAN.md check together. check-claims.sh over the battery reports 2 checked, 0 mismatched, 0 errored. Verify gate green via quiet-verify.sh: `317 passed`, 8s, matching PLAN.md's Verify count.

The battery asserts the sdist and wheel member sets exactly rather than as supersets, because only an exact set catches both directions: a source module that should ship going missing, and something that must not ship being swept in. It then names each forbidden thing separately - PLAN.md, BACKLOG.md, JOURNAL.md, JOURNAL-archive.md, .jeffy, tests, docs, .venv, .git, CHANGELOG, uv.lock, .github - so a failure says what leaked instead of printing two large sets. RECORD is revalidated the way ./check_dist does it, with every hash required to be urlsafe-base64 rather than hex, since 0.24.0 shipped hex-encoded RECORD hashes (issue #406) with every other check green. Finally the wheel is installed --no-deps --offline into a scratch venv and imported, which is the only check here that exercises the artifact the way a user receives it.

One real behaviour of the toolchain came out of writing this and is worth recording rather than hiding behind a tolerant assertion: uv_build 0.12 adds a `pyproject.toml.orig` member to the sdist that 0.11.x does not. uv.lock pins uv 0.11.27 and pyproject's build-system pin caps uv_build below 0.12, so a release is built without it; the battery tolerates that one member while asserting explicitly that it is the only tolerated variance, so a second unexplained member still fails. This is not a finding - nothing a user of the shipped product meets differs - but it is the reason the first run of the battery disagreed with the member set I had recorded from an earlier scratch build made with uv 0.12.8.

No in-envelope finding was surfaced by this sweep.

Learnings: build artifacts vary with the build backend's version, so a member-set assertion must name the backend it was measured against; resolve uv from PATH first, falling back to ./.venv/bin/uv, so a battery runs both inside `nix develop` and in a bare shell.

Next: one row remains, published prose. It cannot be evidenced green while L1 stands, because the dead blob/main links it would assert against are exactly that finding, so L1 is the next task and the row is swept after it.

## iter 6/10 | 7f88691b-142345 | 2026-09-01 | L1 | done

Task: L1 (Low, docs, documentation) - two `blob/main` source links in docs/learning-from-bidict.rst, published at bidict.readthedocs.io, pointed at paths that no longer exist.

Changed: docs/learning-from-bidict.rst only. `bidict/_frozenbidict.py#L8` repointed to `bidict/_frozen.py#L8`, which is where frozenbidict actually lives and where the sibling links' `#L8` anchor convention points. The `test_properties.py` link and its visible link text both repointed to `tests/test_bidict.py`, which is where `test_bidicts_freed_on_zero_refcount` is defined. No source file and no CHANGELOG entry: this repairs published documentation links, and changes no behaviour a release note would describe.

Checkpoint: 911e416e74a5d25e86e84bcc1cbd31f08dc21d85. Not a stall: docs/learning-from-bidict.rst changed and L1 left the ledger.

Verification: the filed acceptance check was run first against the unfixed tree and printed both missing paths, then run again after the fix and printed nothing. The enumeration behind it is the whole set, not a sample: every `blob/main` target in README.rst and docs/*.rst now resolves - bidict/__init__.py, _base.py, _bidict.py, _dup.py, _frozen.py, _orderedbase.py, _orderedbidict.py, tests/ and tests/test_bidict.py. The two links that name a pinned commit rather than main - `blob/356dbe3/bidict/_bidict.py` and `blob/f4823c7/bidict/_named.py` - are deliberately outside that set and were left alone: both point at code that was removed on purpose, and a pinned commit is how the docs keep those references readable. The surrounding prose claim was checked too rather than assumed: `test_bidicts_freed_on_zero_refcount` carries `@skip_if_pypy`, so "is skipped outside CPython" is true of the file the link now points at. Battery ownership: the diff touches only docs/learning-from-bidict.rst, and no battery's paths file matches it, so none needed re-running. Verify gate green via quiet-verify.sh: `317 passed`, 7s, matching PLAN.md's Verify count - the file carries doctests that the suite executes, so the edit was exercised rather than merely inspected.

Learnings: none new; the enumerate-then-check discipline this task used is already in PLAN.md's Method.

Next: the last unswept row, published prose, whose link-resolution invariant is now true and can therefore be pinned by a battery.

## iter 7/10 | 7f88691b-142345 | 2026-09-01 | SWEEP | done

Task: sweep the last unswept row, published prose, whose link-resolution invariant became true when L1 closed.

Changed: .jeffy/probes/published-prose/ (probe.py, paths, claims, README.md). BACKLOG.md: M1 filed under Next, a Medium this sweep surfaced. PLAN.md: the row flipped to swept in the bookkeeping edit below. No source file touched.

Checkpoint: 77d88fa9e779082a5ef611580469006d95e1f4b7. Not a stall: the last Surface inventory row changed state, a battery was added, and M1 entered the ledger.

Verification: published-prose 32/32 through the installed run-probe.sh, with its recorded discriminating mutation - reverting this run's own link repair so `bidict/_frozen.py` points back at the non-existent `bidict/_frozenbidict.py` - executed and observed red at 30/32. check-claims.sh over the battery reports 2 checked, 0 mismatched, 0 errored. Verify gate green via quiet-verify.sh: `317 passed`, 8s, matching PLAN.md's Verify count.

The sweep surfaced one in-envelope finding, filed as M1 (Medium, docs). README.rst's Features list states bidict has "no runtime dependencies outside Python's standard library". pyproject.toml declares `typing_extensions>=4.4; python_version<'3.12'`, and typing_extensions is not in the standard library - `python -c "import sys; print('typing_extensions' in sys.stdlib_module_names)"` prints False - so on Python 3.11, one of the five supported versions, the claim is false. It was checked against a real install rather than inferred: a 3.11 venv with the built wheel holds bidict and typing-extensions 4.4.0 and nothing else. Scored Medium as a documented promise the code does not keep, with the consequence stated on the line, and not downgraded on the grounds that it is only one Python or only one package: README.rst is the wheel's long_description and the PyPI landing page, and a user who chose bidict for having no third-party dependencies is exactly the user this sentence is addressed to. The claim's whole set of sites is enumerated on the task line by command; it returns README.rst plus two lines of CLAUDE.md.

Six checks in the first draft of this battery failed, and every one was the battery being wrong rather than the project. Recording them because four of the six were assertions that looked reasonable and were not. (1) The blob/main link set came up short because the battery skipped docs/changelog.rst as a symlink, which also skipped the `tests/` link that lives in CHANGELOG.rst; it now reads the three symlink targets from the root directly, covering the same bytes exactly once. (2) A pinned-commit link was asserted to name a path absent from the tree. That is not what pinning means: `blob/356dbe3/bidict/_bidict.py` names a file that still exists, and what was removed is an implementation inside it. The check now verifies the documented facts directly - namedbidict is not exported, bidict/_named.py is gone, and the slice-syntax lookup the docs call unsupported really raises KeyError while the ordinary lookup still works. (3) A docstring-coverage check flagged OnDup.__annotate_func__, OnDupAction.__new__ and OnDupAction.__repr__, which are generated or inherited dunders rather than authored API; it now covers non-dunder public members. (4) An assertion that no prose file uses an em or en dash was simply a foreign convention imported from my own instructions - this project's docs use them deliberately - and would have produced a false finding, so it was deleted rather than weakened. (5) A toctree check counted the `:hidden:` option as a document. (6) A helper check about the slice syntax was malformed.

Learnings: a sweep battery must assert the project's conventions, not the author's; an assertion imported from outside the project is a false-finding generator, and the one that reached a first draft here would have filed two. When a documentation link names a pinned commit, the invariant to check is that the documented thing is really gone, never that the path is.

Next: M1 is the only open Medium and the ledger's top item, so it is the next task; the map is now fully swept.

## iter 8/10 | 7f88691b-142345 | 2026-09-01 | M1 | done

Task: M1 (Medium, docs, documentation) - README.rst claimed bidict has "no runtime dependencies outside Python's standard library", but pyproject.toml declares typing_extensions for Python < 3.12 and typing_extensions is not stdlib, so the claim was false on Python 3.11.

Changed: README.rst (the Features bullet now states the 3.12-and-later case and names typing_extensions as the sole 3.11 dependency, with what it supplies), CLAUDE.md (both of the other sites the enumeration returned: the "dependency-free" characterisation in Orientation and the "zero runtime dependencies (standard library only)" instruction, which now says the only runtime dependency is typing_extensions on Python < 3.12 and that there are none on 3.12 and later). .jeffy/probes/published-prose/ gained the regression check described below and its claims and README were re-measured. No source file touched and no CHANGELOG entry: this corrects a statement about the dependency the 0.24.2 section already describes, and changes no behaviour a release note would report.

Checkpoint: 1832bbff0d64f75ebd1a85ef0f88d6b75a897901. Not a stall: README.rst and CLAUDE.md changed and M1 left the ledger.

Verification: the fix covers the whole class, not the instance that was noticed. The enumerating command on the task line - `grep -rn -i 'no runtime dependencies|zero runtime dep|dependency-free|standard library only' README.rst docs/*.rst CLAUDE.md CONTRIBUTING.rst` - returned three sites before the fix (README.rst plus two in CLAUDE.md) and returns three after, all three now accurate; docs/*.rst and CONTRIBUTING.rst never carried the claim.

The acceptance check is executable and now lives in the battery that owns README.rst rather than in this entry: published-prose parses pyproject.toml's own `dependencies` list and requires the README claim to name every declared dependency and every Python bound its environment marker sets. That is a differential check, not an absence-of-badness one - it was run against the pre-fix README in a copy of the tree and failed on exactly the two assertions it should (the dependency name and the 3.12 boundary), and passes on the fixed text. Paired with published-distribution, which already proves the wheel's METADATA matches pyproject, the two chain to README matching what a user actually installs.

Battery ownership: the diff touches README.rst, which .jeffy/probes/published-prose/paths declares, so that battery was re-run in this iteration - 37/37 through the installed run-probe.sh - and its row is re-recorded at this iteration's checkpoint in the bookkeeping edit below. Its recorded discriminating mutation was re-measured against the new total and now reads 35/37. check-claims.sh over all fifteen batteries reports 30 checked, 0 mismatched, 0 errored, 0 skipped. Verify gate green via quiet-verify.sh: `317 passed`, matching PLAN.md's Verify count.

Learnings: when a prose claim and a manifest can disagree, pin the prose against the manifest rather than against a remembered fact, and put the check in the battery that owns the prose file - the row then goes stale automatically the next time that file changes, which is what makes the regression check outlive the iteration that wrote it.

Next: the ledger is at the severity floor with three carried Lows (L2, L3, L4) and the map is fully swept, but no full fresh-evidence audit has scored clean this run, so the next iteration is the closing full audit.

## iter 9/10 | 7f88691b-142345 | 2026-09-01 | AUDIT | audit

Task: the closing full audit - rescore every applicable dimension against the severity rubric and the Operating envelope with fresh evidence taken at HEAD, over a Surface inventory that is now fully swept.

Changed: BACKLOG.md only - L3's wording, so the line stays true now that .jeffy/probes/published-prose executes the README example; the finding it names is unchanged, because the battery is loop memory rather than the project's own gate and disappears with the loop. No task was filed and none closed.

Checkpoint: ef40203a60fdd79a768a8270d3ca7af4834e18f1. Not a stall in substance - this is the closing AUDIT, a ceremony entry - but recording it plainly: the only file this iteration changed was BACKLOG.md, and the change was L3's wording rather than an item changing state.

Verification, all re-derived this iteration rather than carried forward. Surface inventory: 16 rows, all swept, and none stale - staleness was computed rather than trusted, by expanding each row's battery paths file and asking `git diff --name-only <recorded commit> HEAD` over exactly those files; every row came back empty. Batteries: all 15 executed through check-claims.sh, which reports 30 checked, 0 mismatched, 0 errored, 0 skipped - that is every battery's clean score and every battery's recorded discriminating mutation score, so the instruments were re-proved able to fail, not merely re-run. Together they pin 765 known-answer and invariant checks. Verify gate green via quiet-verify.sh: `317 passed`, matching PLAN.md's Verify count, with the Oracle class and Environment fingerprint re-read and the fingerprint's exclusion enumeration re-run - it still returns only PyPy-conditional and runtime-conditional guards, none of which fire on CPython, and the run reports no skipped tests. Artifact channels re-enumerated by command: still no MANIFEST.in, package.json, .npmignore, Cargo.toml, gemspec or nuspec, and the only tree-archiving channel remains `uv build` in the two release workflows, which published-distribution drives directly. BACKLOG.md holds no Declined entry and no Settled class, so there was no recorded Derivation or enumeration to re-run.

Dimension scores, claiming the whole mapped surface because no row is unswept: architecture None, code quality None, correctness None, error handling None, security None, dependency hygiene None, documentation Low (L2), testing Low (L3), developer experience Low (L4), observability not applicable, UX and accessibility not applicable, performance not scored.

The security None is derived, not asserted: a scan of bidict/*.py for eval, exec, compile, __import__, pickle.loads, marshal, os.system, subprocess, socket, urllib, requests and open() returns nothing, and an AST walk of every module reports the whole set of top-level imports as __future__, abc, collections, contextlib, enum, operator, sys, types, typing, weakref and typing_extensions - stdlib throughout, with the single third-party name guarded behind `sys.version_info >= (3, 12)`. The library parses nothing, decodes nothing, touches no filesystem, network or subprocess, and does no I/O at all; the Operating envelope classifies its surfaces user-error for exactly that reason. Observability and UX are recorded not applicable rather than clean: a mapping type has no logging, metric or user-facing surface to score. Performance is recorded not scored rather than None, which is the honest answer: microbenchmarks.py and the benchmark workflow exist but run separately with saved baselines, this host has no baseline to compare against, and no measurement was taken this run, so there is nothing to score from.

One thing that looked like a finding and is not, recorded so the next reader does not re-derive it. `importlib.metadata.distribution('bidict').requires` in ./.venv still reports `typing-extensions>=4.0`, the floor H1 replaced. That is the dev venv's own dist-info, written when ./init_dev_env installed the project and not refreshed since; the tree declares >=4.4, and the freshly built wheel and sdist both carry `Requires-Dist: typing-extensions>=4.4`, which published-distribution asserts against pyproject on every run. Nothing a user installs carries the old floor.

Zero High and zero Medium in-envelope. Closeout has begun: no further audit and no replenishment for the rest of this run.

Learnings: read installed dist metadata as a statement about the environment, never about the tree - an editable dev install pins the requirement text from whenever it was installed, and quoting it as the project's current declaration would have manufactured a false regression against a fix this same run made.

Next: the convergence sequence - bring the standing claims current, invoke the adversarial evaluator gate, and on PASS declare, carrying L2, L3 and L4 as the accurately scored Lows they are.

## Note (2026-09-01, run 7f88691b-142345)

Correcting the iter 8/10 entry above, by appending rather than editing it. That entry says M1's enumerating command "returned three sites before the fix (README.rst plus two in CLAUDE.md) and returns three after". Three before is right; three after is wrong - it returns two after, because rewriting CLAUDE.md's two matching phrases produced wording that matches on one line rather than two. The substantive claim that entry rests on is unaffected: every site the enumeration returns is accurate, and no inaccurate site survives. The evaluator gate flagged this, and a second defect with it: the command as written into M1's task line used unescaped `|` alternation with plain `grep`, which is a basic regular expression, so as recorded it matches nothing at all. The command actually run during iterations 7 and 8 used escaped `\|` and did return the sites quoted; the version that reached the ledger did not. That is filed as L5.

## iter 10/10 | 7f88691b-142345 | 2026-09-01 | EVALUATOR | converged

Task: the convergence sequence - bring every standing claim current, invoke the adversarial evaluator gate, and declare on a PASS.

Changed: .jeffy/evaluator/7f88691b-142345-1.md (the gate's artifact), BACKLOG.md (L5 and L6 filed from the gate's observations, and the Converged line appended below), JOURNAL.md (a Note correcting a number in the iter 8 entry, and this entry). No source file touched.

Checkpoint: 1fd781a27b5632f4a2bff5417afc8608df0688a2. This iteration's primary entry landed in the bookkeeping commit rather than the checkpoint, because the checkpoint had to carry the evaluator artifact before the entry could quote its verdict; the artifact is committed at the hash above and unmodified since.

Verification: Evaluator: PASS - the gate reproduced H1's failure at the base commit and its fix at HEAD, re-ran M1's and L1's acceptance checks as written, derived Surface inventory staleness itself from each battery's paths file, and confirmed the verify gate and all 30 claims green.

Standing claims were brought current before the invocation, not after: the Surface inventory's 16 rows were re-derived stale-or-not by expanding each battery's paths globs and diffing the row's recorded commit against HEAD, and none is stale; BACKLOG.md holds no Declined entry and no Settled class, so there was no recorded Derivation or enumeration to re-run; check-claims.sh reported 30 checked, 0 mismatched, 0 errored, 0 skipped; PLAN.md names no finding ID as carried or blocked; the Oracle class and Environment fingerprint were re-read and the fingerprint's exclusion enumeration re-run; and the Verify count cell still equals the wrapper's green total, `317 passed`.

The gate recorded three observations, none a REJECT reason, and none of them was fixed inside the convergence sequence. Two were verified independently here before being written down rather than taken on the gate's word. O1: M1's recorded enumerating command used unescaped alternation with plain grep, which is a basic regular expression, so as recorded it matches nothing - filed as L5, together with the correction that the iter 8 entry's "returns three after" should read two. O2: pyproject.toml's test dependency group lists typing_extensions with no floor while tests/test_bidict.py imports TypeIs, which typing_extensions first provided in 4.10.0 - confirmed by installing 4.4.0, 4.9.0 and 4.10.0 and grepping each - filed as L6 and scored Low rather than High because it is H1's defect class in the dev group, where a user of the shipped product never meets it. O3 observed that PLAN.md's Stated counts table is empty, which is its correct state here: this run wrote no prose count in the `returns <count>` form.

Carried Lows, each open with its severity on its line and none of them hiding anything a user of the shipped product meets: L2 - the "ktems" typo for "Items" in BidictBase.__init__'s docstring, which ships in the wheel and renders in the API docs. L3 - README.rst's usage example is outside testpaths and the doctest glob, so the project's own suite never executes the one example on the PyPI landing page. L4 - nothing in CI, tox or the suite resolves the declared dependency floors, which is why H1 shipped unnoticed. L5 - the unusable enumerating command described above. L6 - the unpinned dev-group typing_extensions floor described above.

Learnings: verify an evaluator's observations before recording them; two of the three here were right, and confirming them cost three commands each while adopting a wrong one would have put a false finding on the next run's ledger.

Next: nothing in this run. The next run starts from a clean full audit's record with five carried Lows and a fully swept map.
