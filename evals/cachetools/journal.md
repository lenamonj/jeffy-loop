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

## iter 1/10 | 467a4cf7-014604 | 2026-09-01 | AUDIT | audit

Task: first full audit of cachetools 7.1.8. Filled the Operating envelope, the Surface inventory and the Verify command block in PLAN.md, then probed every inventory row breadth-first before filing.

Changed: PLAN.md (envelope surfaces, 14 inventory rows, Command/Oracle class/Environment fingerprint/summary pattern/count), BACKLOG.md (M1, M2, L1), .gitignore (loop state file).

Checkpoint: 8e42bc86fbd15d4ae42e2e12f8f7d76e0a5e5b2b. Not a stall: BACKLOG.md gained three task lines, and an AUDIT entry is exempt regardless.

Verification:
- Verify command established and green through the wrapper: `verify: green (4s, oracle=unit tests..., 333 passed in 4.24s)`.
- Project's own gates, all run once during this audit: pytest 333 passed; `ruff check .` clean; `ruff format --diff -q .` clean; `sphinx-build -W -b html` succeeded; `sphinx-build -W -b doctest` 58 tests, 0 failures; `pyright` 0 errors (11 warnings, 17 informations, all pre-existing and configured as non-errors in pyproject.toml).
- Test isolation, required before scoring Testing clean: test_cache, test_ttl, test_tlru, test_threading, test_keys and test_classmethod each pass run alone, and the whole suite passes with modules given in a different order. No order dependence found.
- Coverage: `coverage run --source=cachetools -m pytest` reports 99% with two unexecuted lines in `_cachedmethod.py`, both on the classmethod-descriptor-chaining path that only Python before 3.13 takes. That is the Environment fingerprint's exclusion, not a test gap.
- Breadth-first probes, executed against every inventory row, all green after their own defects were fixed: known-answer checks over the mapping protocol, all seven cache classes, both decorators in every lock/condition/info combination, the key functions and the func module; a differential fuzz of LRU and FIFO against independent reference models plus a size/length/bound invariant sweep across all seven classes; a TTL differential against a reference model with a moving clock; LFU doubly-linked-list structural invariants and an eviction-picks-a-least-used-key check; pickle, deepcopy and copy round-trips for every class; recursion under all five func decorators; condition-variable stampede prevention for both `cached` and `cachedmethod`; and the documented `__missing__`, `popitem` and `expire` subclass hooks.
- Three probe results that looked like defects were my instruments, not the product, and are recorded so they are not re-filed: expiry is `time < expires`, so an item is gone exactly at its expiry instant; `dict(cache)` calls `__getitem__` and therefore mutates LFU counts and LRU order, so an invariant check must read keys through `iter()`; and `_Timer.__reduce__` pickles the timer by value, so a pickled cache carries a snapshot of a stateful clock object.
- Findings filed: M1 reproduced by building the sdist and listing the tarball - `PLAN.md`, `BACKLOG.md` and `JOURNAL.md` sit at the archive root. M2 reproduced by holding `it = iter(cache); next(it)` and advancing the clock: `timer()` stays at 0, `len()` still reports 3 with every item expired, and a value written during that window is unreadable the moment the iterator is dropped. L1 reproduced with `gc.disable()` and weak references.
- Artifact channel enumeration, by command rather than recall: the tree's only artifact-producing channels are `pyproject.toml` (setuptools sdist and wheel) with `MANIFEST.in`, and `.github/workflows/ci.yml`, which runs tox and uploads coverage and publishes nothing. The wheel carries only `src/cachetools`, so the state files cannot reach it; the sdist does carry them, which is M1.

Scores, claiming only what was probed - all 14 inventory rows were probed shallowly, none is swept with a committed battery yet, so these are audit scores and not sweep certificates: architecture None, code quality None, security None (no adversarial surface exists: no endpoint, no parser, no deserializer of foreign data, no privileged operation), testing None, error handling None, performance None, documentation Low, dependency hygiene Medium, developer experience None, correctness Medium, observability not applicable (a pure in-process library with no logging or metrics surface), UX and accessibility not applicable (no user-facing surface). Zero High.

Learnings: cachetools is a mature, tightly-tested library and the cheap defect classes are already closed - the audit's yield came from the packaging channel and from the lifetime of an object the API hands out, not from the cache algorithms, which survived differential fuzzing against reference models. An invariant probe over these classes must read keys through `iter()`, never `dict()`, because `__getitem__` is a mutating operation on LFU and LRU.

Next: M1, then M2, then the inventory sweep.

## iter 2/10 | 467a4cf7-014604 | 2026-09-01 | SWEEP | done

Task: sweep the Surface inventory. With no open High and 14 unswept rows, the map outranked both open Mediums, so this iteration built and executed a known-answer or invariant battery for every row.

Changed: .jeffy/probes/ (a shared harness, a mutation runner, and 14 batteries each with probe.py, mutation.py, paths, claims and README.md), PLAN.md (14 inventory rows flipped, three Lessons), JOURNAL.md.

Checkpoint: a36929ded929d267a2390710bbdde9d49fcbfa3d. All 14 Surface inventory rows are recorded at that hash in the same edit.

Verification:
- Verify command green through the wrapper: `verify: green (5s, oracle=unit tests..., 333 passed in 4.20s)`. No product file was changed this iteration, so the suite grades the same code it graded at the last checkpoint.
- Every battery was executed against the real tree and reports all checks passed: cache-base 51, fifo-lru 22, lfu 16, rr 19, timed-machinery 57, ttl 32, tlru 37, cached 125, cachedmethod 134, cachedmethod-deprecated 18, keys 41, func 140, stubs 98, packaging 42.
- Every battery has been observed failing. Each records a discriminating mutation applied to a scratch copy of the tree, and `check-claims.sh` re-executes all of it: `claims: 42 checked, 0 mismatched, 0 errored, 0 skipped`, three claims per battery - the pass count, `--control` green with the mutation withheld, and `red` with it applied. The control claim exists because a battery that goes red in the harness for its own reasons proves nothing about the mutation.
- The mutations are chosen to be invisible to a liveness probe: LRU and LFU stop recording use, RRCache's swap-remove index stops being repaired, TTLCache stops expiring, TLRUCache goes back to keeping a stale value on an expired overwrite, `cached` stops writing to its cache, `typedkey` and `func`'s `typed` parameter go inert, `cachedmethod` stops caching its per-instance wrapper, the deprecation warnings fall silent, `__all__` and the stubs drift apart, and `MANIFEST.in` stops pruning `.github/`. Every one of them stores, retrieves and returns without raising; only a known-answer or invariant check separates them from the real implementation.
- Every documented parameter of a swept surface is exercised at two or more values that must change the output: `getsizeof` default against `len`; `maxsize` negative, zero, two bounds and `None`; `choice` at two functions that pick different victims and at the default; `ttl` and `ttu` short against long and at the exact expiry instant; `key` at `hashkey` against `typedkey`; `typed` True against False; `info` on and off across all four lock and condition combinations for both decorators. No inert parameter was found.
- Rows swept this iteration: 14 of 14, from 0 at run start.
- Closed no backlog task; M1, M2 and L1 remain open and untouched.
- Not a stall: 14 Surface inventory rows changed state.

Three instrument defects were found and corrected while building the batteries, none of them a product finding:
- The `cachedmethod` mutation first tried dropping the assignment back from `obj.__dict__.setdefault(...)`. The battery stayed green, because the wrapper still landed in the instance dict. A mutation the battery survives is not evidence, so it was replaced with one that stops the storage entirely.
- `mutate.sh` first excluded `.git` from its scratch copy. setuptools-scm enumerates the sdist from `git ls-files`, so the packaging battery went red on a tree with no mutation at all. `.git` is now copied.
- The packaging probe resolved its interpreter as `<root>/.venv/bin/python`, which does not exist in a scratch copy, so it raised `FileNotFoundError` there and the runner reported `red` for every mutation including none. It now uses `sys.executable`, and the `--control` claim was added to every battery so this class of false evidence cannot recur unnoticed.

Two probe expectations were wrong about the product and were corrected rather than filed, both in the deprecated `cachedmethod` paths: a warning has to be provoked inside `warnings.catch_warnings`, not while evaluating a call argument; and a descriptor that never received `__set_name__` does not raise on the no-`info` path, because those variants derive from `_DeprecatedDescriptorBase` and take the deprecated branch, while only the `info` variants raise.

One check was written, found unfalsifiable, and replaced: the `keys` battery originally asserted `isinstance(merged, set)`, which is true whatever the key functions do. It is now a pairwise comparison of key equality against argument equality, which the `typedkey` mutation reddens.

Learnings: a mutation runner needs a control arm. Two of the three instrument defects above produced a confident `red` from a battery that was not detecting anything, and only running the same scratch tree with the mutation withheld distinguished them; every battery now pins that control as a claim. Sweeping the whole map in one iteration was affordable here because the breadth-first audit in iteration 1 had already written and executed most of the checks - the sweep's cost was turning them into kept instruments with recorded discriminating inputs, not discovering what to check.

Next: M1, the sdist carrying the loop's state files.

## iter 3/10 | 467a4cf7-014604 | 2026-09-01 | M1 | done

Task: M1 - the built sdist carried the loop's own state files. Closed.

Changed: MANIFEST.in (prune .jeffy/, exclude PLAN.md, BACKLOG.md and JOURNAL*.md), .jeffy/probes/packaging/ (probe, mutation, claims, README), BACKLOG.md, JOURNAL.md.

Checkpoint: 84aa7b7d7f6f43a685c461dc34182720b1419530. The Packaging and distribution row is re-recorded at that hash in this same edit, because MANIFEST.in is in its battery's paths and changed this iteration. Not a stall: MANIFEST.in changed and M1 left the ledger.

Verification:
- The filed reproduction was run first, against the unfixed tree, and failed there as filed - and worse than filed. `python -m build --sdist` produced a tarball whose grep for the state paths exited 0, listing PLAN.md, BACKLOG.md, JOURNAL.md and, because iteration 2 committed the probe batteries, the entire `.jeffy/` tree including the engine's own metrics jsonl.
- Fixed as a class, not an instance. The class is every path the loop writes that setuptools-scm's git file finder would add, and it is enumerated by command, not by recall: `git ls-files | grep -E '^(PLAN|BACKLOG|JOURNAL)[^/]*\.md$|^\.jeffy/|^\.claude/'`. Every path that enumeration returns was then driven through the executing check - build the sdist, list it, and ask of each enumerated path whether it appears. All are excluded and none leaked. `.claude/` appears in the enumeration pattern but returns nothing, because the loop state file is gitignored at bootstrap and the directory is untracked.
- Acceptance as written: `tar tzf ... | grep -E 'PLAN\.md|BACKLOG\.md|JOURNAL(-archive)?\.md|\.jeffy/'` exits 1 with no output, and the tarball still contains src/cachetools/__init__.py, src/cachetools/py.typed, tests/, docs/index.rst, README.rst, LICENSE, CHANGELOG.rst, pyproject.toml, tox.ini and MANIFEST.in.
- Stronger than the acceptance: the fixed sdist was installed into a clean virtualenv and imported. Version 7.1.8, nine exports, a TTLCache round trip, and both `py.typed` and all three `.pyi` stubs present in the installed package. Excluding files from an sdist can break the artifact, and a name listing alone would not have caught that.
- Verify gate green through the wrapper: `verify: green (4s, oracle=unit tests..., 333 passed in 4.22s)`.
- Battery ownership: `MANIFEST.in` is declared by exactly one battery, `.jeffy/probes/packaging/paths`. It was re-run through the installed run-probe.sh and reports 51/51 checks passed, and `check-claims.sh . packaging` returns `3 checked, 0 mismatched, 0 errored, 0 skipped`.
- The battery was updated in the same iteration, because the fix changes behaviour it pins. Its scope note that deliberately withheld the sdist assertions while M1 was open is gone, replaced by the class-complete check described above, which reads the enumeration from git rather than a hardcoded list, asserts the enumeration is non-empty, and asserts the intersection with each archive is empty. Its mutation is now the pre-fix MANIFEST.in itself - the exact state the battery was observed failing on. Control green, mutant red.

Rationale for the observable change, per the Constraints: the sdist's contents change for anyone who downloads it. Nothing the build, the tests, the docs or the install needs was removed; what left the artifact is only the loop's own memory, plus the directories the file already denied. No CHANGELOG.rst entry was added, because that file is organised by released version and there is no unreleased section to append to; inventing one would claim a release that has not happened.

A third defect in my own instrument was found and fixed here, and it is worth recording because it is the same shape as iteration 2's two. I added a check that no MANIFEST.in directive matches nothing - it had just caught a `prune .claude/` line I wrote for a directory git never tracked, which warned on every build. The check then reported all seven directives as dead on a correct tree, because a bare `python -m build` builds the wheel from the unpacked sdist, and on that second pass every directive matches nothing by construction. The probe now builds the two artifacts with separate invocations and reads only the sdist build's output.

Closed this run: M1 (Medium, build-ci, dependency hygiene) - sdist no longer carries PLAN.md, BACKLOG.md, JOURNAL.md or .jeffy/, verified by the class enumeration, by the filed acceptance check, and by installing the resulting sdist.

Learnings: a packaging denylist over a git-file-finder source is a standing hazard - setuptools-scm adds every tracked path, so anything new at the project root joins the sdist until someone denies it by name. The check that keeps this honest is the class enumeration read from git at probe time, not the list of names anyone happened to think of. And an exclusion fix is not verified by listing archive names: install the artifact and import it, because excluding one file too many produces a tarball that still lists correctly and no longer works.

Next: M2, the timed caches' clock freezing while an iterator is held.

## iter 4/10 | 467a4cf7-014604 | 2026-09-01 | M2 | done

Task: M2 - a held iterator froze the timed caches' clock. Closed, with one clause of the filed acceptance replaced on recorded evidence.

Changed: src/cachetools/__init__.py (_TimedCache._Timer gains a second, read-only freeze; TTLCache.__iter__ and TLRUCache.__iter__ use it), tests/test_ttl.py and tests/test_tlru.py (three regression tests each), docs/index.rst (a note stating the iteration freeze), .jeffy/probes/timed-machinery/ (probe, mutation, claims, README), PLAN.md (Verify count, Lessons), BACKLOG.md (M2 closed; M3 and L2 filed), JOURNAL.md.

Checkpoint: 8eba478c968ca2c7122bfd905cb99f0ecc63bbf5. The eleven rows whose batteries declare `src/cachetools/__init__.py` are re-recorded at that hash in this same edit. Not a stall: source, tests and docs changed, and M2 left the ledger while M3 and L2 joined it.

Verification:
- The filed reproduction ran first and failed on all three clauses: `timer()` returned 0 at real time 1000, `len()` returned 3 with every item expired, and a value written during the window was gone the moment the iterator was dropped.
- The contract the change preserves, stated before touching shared code: reading a key an iterator has just yielded must not raise. `_TimedCache._Timer` now carries two independent freezes instead of one. The operation freeze is unchanged - one cache operation sees one instant and calls the user's timer once, which matters because a timer may be stateful and the suite has tests with an auto-advancing one. The new iteration freeze is entered per step of `__iter__`, is honoured by `__call__` and therefore by `__getitem__` and `__contains__`, and is ignored by `__enter__` and therefore by `__setitem__`, `__len__`, `currsize`, `get`, `pop`, `setdefault`, `popitem` and `__repr__`. No extra timer call is made anywhere.
- Clause 3 (a write during the window survives) and clause 2 (`len()` is 0) now pass. Clause 1 - `timer()` returning live time while an iterator is held - was not implemented, and the reason is measured rather than argued. Two arms were built, differing only in whether `__iter__` holds the freeze across its yield, and selected by PYTHONPATH alone. With the freeze removed, which is what clause 1 requires, `for key in cache: cache[key]` raised KeyError at ttl 8 and 10, and so did `items()` and `dict()`; with it, both are clean at every ttl tried. Clause 1 is therefore not a defect to fix but a consistency guarantee to keep, and it is now documented instead. The two `read_during_iteration` tests added this iteration pin it.
- The four behaviour-changing regression tests were run against the pre-fix module - the tree copied to a scratch directory with `src/cachetools/__init__.py` restored from HEAD - and all four failed there; against the fix all six pass. The two consistency guards pass on both, which is what a guard should do, and they fail on the freeze-removed arm.
- Verify gate green through the wrapper: `verify: green (4s, oracle=unit tests..., 339 passed in 4.21s)`. Verify count in PLAN.md updated from 333 to 339.
- Battery ownership: eleven batteries declare `src/cachetools/__init__.py` - cache-base, cached, cachedmethod, fifo-lru, func, lfu, rr, stubs, timed-machinery, tlru, ttl. All eleven were re-run through the installed run-probe.sh and all pass. `check-claims.sh` over the whole tree returns `42 checked, 0 mismatched, 0 errored, 0 skipped`.
- `timed-machinery` was updated in the same iteration, because the fix changes behaviour it pins. Its scope note that withheld this while M2 was open is gone; it now certifies both halves - a held iterator pins reads at its step's instant and `items()` survives a timer that advances on every call, while `len`, `currsize`, expiry and writes keep following the clock and a write during an iteration expires on its own schedule. Its mutation is the pre-fix `_Timer` and the pre-fix `__iter__` bodies, restored verbatim: the exact state it was observed failing on. 73/73, control green, mutant red.
- Project gates re-run because source and docs changed: `ruff check src tests docs` clean, `ruff format --diff -q src tests docs` clean, `pyright src tests` 0 errors with 11 warnings and 17 informations, the same as the iteration 1 baseline; `sphinx-build -W -b html` succeeded and `sphinx-build -W -b doctest` reports 0 failures.

An instrument defect that invalidated an earlier experiment, and the fourth of this run: my first attempt at the two-arm comparison put the mutated copy of the package in the same directory as the experiment script. `sys.path[0]` is the script's own directory and wins over PYTHONPATH, so both arms silently ran the mutated code and I read the result as evidence that the freeze was not load-bearing. The corrected experiment keeps the script in a directory with no copy of the package and asserts that at import time. This is the same failure shape as iteration 2's control-arm defects, and the rule it produced is in PLAN.md.

Two findings discovered while working M2 and filed rather than folded in:
- M3 (Medium, runtime, correctness): `dict(ttl_cache)` can raise KeyError where `items()` and `for key in cache: cache[key]` cannot, because `dict()` materialises `keys()` first and exhausts the iterator before reading any value, so no read sees the per-step freeze. Measured with a real clock, not a pathological one: `TTLCache(maxsize=200, ttl=0.0005, timer=time.monotonic)` holding 120 items raised in 1 of 300 `dict(cache)` trials and 0 of 300 for each of the other two forms. Same class as M2, different site - M2 was the freeze lasting too long, M3 is a read path it never reaches.
- L2 (Low, build-ci, developer experience): the loop's own files under `.jeffy/` are linted and type-checked as the product, because `tox -e ruff` and `tox -e pyright` take no path argument. Every one of the findings is under `.jeffy/probes/`; the product is clean. Low by the rubric's class ceiling, which puts lint and type-checker output there however many there are.

Closed this run: M2 (Medium, runtime, correctness) - a held iterator no longer stops expiry and no longer backdates writes, with six regression tests, four of which fail on the pre-fix module.

Learnings: an experiment that selects between two versions of a package must keep its script out of any directory containing a copy, because `sys.path[0]` is the script's directory and silently outranks PYTHONPATH - assert the arm's `__file__` inside the experiment. And when a filed acceptance turns out to demand something incompatible with a guarantee the code deliberately provides, the answer is to measure the tradeoff on two real arms and record which one the project keeps, not to quietly satisfy the easier reading of the line.

Next: M3, then L1 and L2.

## iter 5/10 | 467a4cf7-014604 | 2026-09-01 | M3 | done

Task: M3 - `dict(ttl_cache)` can raise KeyError where `items()` cannot. Closed by documenting the hazard and the atomic alternative, with the affected set established by provoking a failure at every form.

Changed: docs/index.rst (the copy paragraph), tests/test_ttl.py and tests/test_tlru.py (one regression test each), .jeffy/probes/timed-machinery/ (probe, claims, README), PLAN.md (Verify count), BACKLOG.md (M3 closed), JOURNAL.md.

Checkpoint: f5075778537d4ba2de962f5a6ce25785ee3b04b9. The Timed-cache machinery row is re-recorded at that hash in this same edit, because its battery was re-run and extended. Not a stall: docs and tests changed, and M3 left the ledger.

Verification:
- The affected set was enumerated by provoking a failure at each form, never by reading which C API each one calls. Twelve forms were run against both timed classes with a real `time.monotonic` clock, a 0.5 ms ttl and 150 items. Over 400 trials each: `dict.update(cache)` raised on both classes and `dict(cache)` raised on TLRUCache; every form reading through `items()`, `values()`, `keys()` or a suspended iterator raised on neither, and so did `copy.copy`, `copy.deepcopy`, `expire()` and `len()`. The three merge forms were then re-run at 2000 trials to settle the class: `dict(cache)` raised on both, `{**cache}` raised on TTLCache, `dict.update(cache)` raised on both, and `dict(cache.items())` raised on neither in 2000 trials per class.
- That is the whole class and its boundary: the forms that fail are exactly the ones that build a copy by asking for `keys()` and only then reading each value, so the iteration is over before the first read and nothing sees the per-step freeze M2 established. The forms that read a value while the iterator that yielded its key is still suspended are consistent.
- No code fix was made, and the reason is structural rather than a preference. Making `dict(cache)` atomic requires a read after the iterator has closed to see the instant that iteration used, which is exactly the freeze lifetime M2 removed for causing silent data loss. The two cannot both hold. What the library can do is state the hazard and name the alternative it does guarantee, which is what the stdlib does for the same shape in `weakref`. The documentation now says so and shows `dict(cache.items())`.
- Regression tests added for both classes pin the alternative rather than the defect: under `Timer(auto=True)`, where the clock advances on every call and items expire during the copy, `dict(cache.items())` returns the whole cache. A test asserting that `dict(cache)` raises was deliberately not written - it would pin a defect as intended behaviour, and the rate of a race is not a stable measurement.
- Verify gate green through the wrapper: `verify: green (5s, oracle=unit tests..., 341 passed in 4.21s)`. Verify count in PLAN.md updated from 339 to 341.
- Battery ownership: this iteration changed `docs/index.rst`, `tests/test_ttl.py` and `tests/test_tlru.py`. No battery declares any of them, and no file under `src/` changed, so no row went stale. `timed-machinery` was extended anyway, because the documentation now makes a claim about which copy forms are consistent and a claim in the docs with no executing check behind it is the thing this loop keeps finding. It now drives all five safe forms on both classes under an advancing clock. Re-run through the installed run-probe.sh: 83/83. `check-claims.sh` over the whole tree: `42 checked, 0 mismatched, 0 errored, 0 skipped`, control green and mutant red for every battery.
- Docs gates re-run because docs changed: `sphinx-build -W -b html` succeeded, `sphinx-build -W -b doctest` reports 58 tests and 0 failures, `ruff check src tests docs` and `ruff format --diff -q src tests docs` clean.

Closed this run: M3 (Medium, runtime, correctness) - the copy hazard is documented with its measured boundary, the atomic form is named and tested, and the battery drives every form the documentation calls consistent.

Learnings: when a fix and a guarantee are in genuine tension, say which one the project keeps and why, and put the measurement behind it - M2 and M3 are the same mechanism seen from two sides, and the freeze that makes `items()` consistent is the same freeze that cannot reach `dict()`. A documented hazard is only worth the check that drives it: the paragraph naming five consistent copy forms ships with a battery that executes all five, because an unchecked sentence about a set of sites is how this project's docs would drift.

Next: L1, then L2, then the closing full audit.

## iter 6/10 | 467a4cf7-014604 | 2026-09-01 | L1 | done

Task: L1 - the documentation did not mention that `@cachedmethod` makes its instances cycle-collected. Closed.

Changed: docs/index.rst (a note in the cachedmethod section), .jeffy/probes/cachedmethod/ (probe, claims, README), BACKLOG.md (L1 closed), JOURNAL.md.

Checkpoint: 2671436ebd83cdacd811d6f499cc8188c1eb3fd9. The cachedmethod decorator row is re-recorded at that hash in this same edit, because its battery was re-run and extended. Not a stall: docs changed and L1 left the ledger.

Verification:
- The filed reproduction ran first and still holds. Under `gc.disable()`, an instance whose decorated method has been called survives the dropping of its last reference; an undecorated class of the same shape does not.
- The claim generalises over every wrapper `_cachedmethod._wrapper` builds, so it was enumerated rather than asserted: all eight `info` x `lock` x `condition` variants were measured, and all eight agree - the instance survives reference counting after one call and is freed by reference counting when the method was never called. The undecorated baseline is freed either way. The enumeration is now an executing check in the `cachedmethod` battery, which drives every one of the eight and the baseline.
- The documentation states exactly what was measured and no more: the wrapper is stored in the instance's `__dict__` on first access and holds a reference back, so a called instance is reclaimed by the cyclic collector rather than by reference counting; this matters where collection is disabled or deferred; an instance whose decorated method was never called is not affected.
- Battery ownership: this iteration changed `docs/index.rst`, which no battery declares, and nothing under `src/`. The `cachedmethod` battery was extended anyway, because the new documentation sentence is a claim about a set of sites and this loop keeps finding that an unchecked sentence is how docs drift. Re-run through the installed run-probe.sh: 151/151, control green, mutant red. `check-claims.sh` over the whole tree: `42 checked, 0 mismatched, 0 errored, 0 skipped`.
- Gates: `sphinx-build -W -b html` succeeded, `sphinx-build -W -b doctest` reports 58 tests and 0 failures. Verify gate green through the wrapper: `verify: green (5s, oracle=unit tests..., 341 passed in 4.20s)`. No source changed, so the count is unchanged at 341 and no inventory row went stale.
- An instrument slip, caught by running the probe rather than trusting it: the first version of the lifetime check called `obj.m(1)` while the battery's own factory names the method `double`, so it raised AttributeError and the mutation runner printed `red` for both arms. The control arm is what exposed it - a battery that is red with the mutation withheld is broken, not discriminating.

Closed this run: L1 (Low, docs, documentation) - the cachedmethod lifetime consequence is documented and its enumeration over all eight wrapper variants is executed by the battery.

Learnings: the control arm has now caught three separate cases in this run where a battery was red for its own reasons rather than the mutation's. It is worth more than the mutation itself: a mutation proves the battery can fail, and the control proves it fails for the right reason.

Next: L2, then the closing full audit, then the evaluator gate and the declaration.

## iter 7/10 | 467a4cf7-014604 | 2026-09-01 | L2 | done

Task: L2 - the project's own lint and type-check gates, run from the project root as tox runs them, no longer report on files that are not the product. Closed, with the finding's own attribution corrected on measurement.

Changed: pyproject.toml (ruff extend-exclude, pyright exclude), .jeffy/probes/packaging/ (probe, claims, README), PLAN.md (a Lesson), BACKLOG.md (L2 closed), JOURNAL.md.

Checkpoint: 73655ec39965a0312e51a091312e252f73cb0314. The Packaging and distribution row is re-recorded at that hash in this same edit, because pyproject.toml is in its battery's paths and changed this iteration. Not a stall: pyproject.toml changed and L2 left the ledger.

Verification:
- The filed acceptance ran first against the unfixed configuration and failed on all four conditions: `ruff check .` exited 1, `ruff format --diff -q .` reported 27 files, and `pyright` from the root reported 22 warnings and 34 informations where `pyright src tests` reported 11 and 17.
- Half of the finding as filed was wrong, and executing it is what showed that. L2 attributed the pyright difference to `.jeffy/`. The diagnostics were only ever in two files, `_cached.py` and `_cachedmethod.py`, and the root run's counts were exactly double the `src tests` run's. Listing the distinct paths gave the real cause: a leftover `build/lib/cachetools/` holding a second copy of every module, which pyright analysed alongside `src/`. No `.jeffy` file produced a pyright diagnostic at all. The ruff half of the attribution was correct - `.jeffy/` is tracked, so a fresh clone has it and `ruff check .` fails there.
- Both causes are now fixed for their real reasons. `[tool.ruff] extend-exclude = [".jeffy"]` keeps ruff's defaults and adds the loop's directory, which is the same thing `MANIFEST.in` already does for the sdist. `[tool.pyright] exclude` names pyright's own defaults plus `build` and `dist`; the first version of that line replaced the defaults instead of extending them, which let pyright into `.venv` and produced 3506 errors, and the measurement caught it before it was committed.
- The `build/` half is a real developer-experience issue independent of this loop: any maintainer who runs `python -m build` locally and then `tox -e pyright` gets every diagnostic twice. The exclusion fixes that for them too.
- Acceptance as written, re-run after the fix: `ruff check .` exits 0, `ruff format --diff -q .` exits 0, and `pyright` from the root reports `0 errors, 11 warnings, 17 informations`, identical to `pyright src tests`. Checked with a `build/` tree present, which is the state that used to break it. The product is still analysed - both source files still appear in the root run's diagnostics, so the exclusion narrowed the scan without blinding it.
- A third defect in the loop's own instrument, found by this task rather than by a probe: the packaging battery left `build/` behind on every run, because setuptools writes its intermediate tree to `<root>/build` whatever `--outdir` says. That is what put the stale copy there in the first place. The probe now removes it when it created it and asserts that it did, and the rule is in PLAN.md.
- Battery ownership: this iteration changed `pyproject.toml`, which `.jeffy/probes/packaging/paths` declares. That battery was re-run through the installed run-probe.sh: 52/52, control green, mutant red. `check-claims.sh` over the whole tree: `42 checked, 0 mismatched, 0 errored, 0 skipped`.
- Every project gate green: `ruff check .`, `ruff format --diff -q .`, `pyright` from the root, `sphinx-build -W -b html`, `sphinx-build -W -b doctest` with 58 tests, and the Verify command through the wrapper - `verify: green (5s, oracle=unit tests..., 341 passed in 4.20s)`. No file under `src/` changed, so the count is unchanged at 341 and no inventory row went stale on source.

Closed this run: L2 (Low, build-ci, developer experience) - `ruff` and `pyright` run from the project root now report on the product alone, with the exclusion covering both the loop's directory and stale build trees.

Learnings: a finding's stated cause is a hypothesis like any other, and the fix iteration is where it gets tested - L2 named `.jeffy/` for both halves and was right about one. Listing the distinct files behind a count is cheap and it is what separated a real cause from a plausible one. And a tool exclusion must extend the tool's defaults rather than replace them: replacing pyright's `exclude` silently pulled `.venv` into the scan and turned 11 warnings into 3506 errors.

Next: the closing full audit.

## iter 8/10 | 467a4cf7-014604 | 2026-09-01 | AUDIT | audit

Task: the closing full audit. Every dimension rescored against the severity rubric and the Operating envelope with fresh evidence. Closeout begins.

Changed: BACKLOG.md (L3 filed), JOURNAL.md.

Checkpoint: 31d68607597ec1a807ffa386afd6bc35bbf30b28. No inventory row was re-recorded: no battery's declared paths changed this iteration, and the staleness check reports 0 stale rows. Not a stall: BACKLOG.md gained L3, and an AUDIT entry is exempt regardless.

Verification, all of it executed this iteration:
- The whole map is current, not merely marked swept. Each of the 14 rows was checked mechanically by asking git whether any path its battery declares changed since the commit the row records: 0 stale rows. All 14 batteries were re-run through the installed run-probe.sh and every one passes - cache-base 51, fifo-lru 22, lfu 16, rr 19, timed-machinery 83, ttl 32, tlru 37, cached 125, cachedmethod 151, cachedmethod-deprecated 18, keys 41, func 140, stubs 98, packaging 52. `check-claims.sh` over the whole tree returns `42 checked, 0 mismatched, 0 errored, 0 skipped`, which re-proves for every battery that it still passes, that it is still green with its mutation withheld, and that it still goes red with the mutation applied.
- Fresh evidence rather than a re-read of swept lines. A differential and invariant sweep was run at a seed no battery uses, 1200 trials over all seven cache classes: LRU differential 0, FIFO differential 0, invariant violations 0.
- The code this run changed was probed adversarially on its own terms. The two-counter timer was driven through two concurrent iterators nesting to depth two and unwinding to zero, an exception raised in a loop body, a `break`, full consumption, an explicit `close()`, repeated iteration, a user timer object carrying attributes named like the new private methods, a pickle round trip, two caches with separate clocks, and a decorator wrapping a TTLCache. All clean. One failure in that probe was my own instrument - a single clock shared between the two classes, where the first pass advanced it past the second pass's inserts - and it was corrected, not filed.
- Testing was not scored before running modules in isolation: test_ttl, test_tlru, test_cache, test_threading and test_cachedmethod each pass run alone. No order dependence.
- Every project gate: `ruff check .` clean, `ruff format --diff -q .` clean, `pyright` from the root `0 errors, 11 warnings, 17 informations`, `sphinx-build -W -b html` succeeded, `sphinx-build -W -b doctest` 58 tests and 0 failures. Verify gate green through the wrapper: `verify: green (5s, oracle=unit tests..., 341 passed in 4.22s)`, matching the Verify count line.
- The Oracle class and Environment fingerprint were re-read and the fingerprint's exclusion list re-derived by its own command: `grep -rnE 'skipif|pytest\.skip|xfail|sys\.version_info|sys\.platform' tests/` returns no match, so nothing in the test tree is skipped or gated. The exclusions the fingerprint names remain the CI matrix's other interpreters and the tox envs outside the Verify command, and every one of those envs was run by hand this iteration anyway.
- The published artifact was verified end to end, not by listing names: the sdist builds, carries no PLAN.md, BACKLOG.md, JOURNAL.md, `.jeffy/` or `.claude/` path, installs into a clean virtualenv, and the installed package imports, serves a TTLCache round trip, and ships `py.typed` and all three stubs.
- Dependency hygiene: the distribution declares no runtime requirements, confirmed from the installed metadata rather than by reading pyproject.toml, and dependabot is configured.

Scores. Every one of the 14 inventory rows is swept and current, so these claim the whole mapped surface rather than a part of it: architecture None, code quality None, security None, testing Low, error handling None, performance None, documentation None, dependency hygiene None, developer experience None, correctness None, observability not applicable (a pure in-process library with no logging or metrics surface), UX and accessibility not applicable (no user-facing surface). Zero High and zero Medium in-envelope.

Security is scored None on the same basis the envelope states and this audit re-checked: nothing untrusted reaches this library. There is no endpoint, no parser, no deserializer of foreign data and no privileged operation, so the only pickle surface is state-at-rest the project writes and reads back.

Closeout has begun. This audit found no High and no Medium, so the run stops auditing for the rest of the budget - no replenishment and no further full audit - and finishes by working or carrying what is on the ledger and then converging.

Filed by this audit: L3 (Low, test, testing) - the nested-iteration branch of `_enter_iteration` is unexecuted by the suite. Coverage reports one unexecuted statement in `src/cachetools/__init__.py`; the branch is correct, since this audit's own probe drives it to depth two and back on both timed classes, but nothing in `tests/` reaches it. Class test, so Low by the rubric's class ceiling, and it is carried rather than worked: two iterations remain and they belong to the evaluator gate and the declaration.

Learnings: a closing audit is worth only the freshness of its evidence, and the cheap way to keep it honest here was to change the seed - the batteries pin fixed seeds by design, so a sweep at a new one is the part that could still find something. Checking row staleness by asking git about each battery's declared paths, rather than trusting the checkbox, is what makes "the map is current" a measurement instead of a claim.

Next: the evaluator gate, and the declaration if it returns PASS.

## iter 9/10 | 467a4cf7-014604 | 2026-09-01 | EVALUATOR | audit

Task: the adversarial evaluator gate, invocation 1 of this run. Verdict REJECT. The run continues.

Changed: .jeffy/evaluator/467a4cf7-014604-1.md (the gate's artifact), BACKLOG.md (M4 filed), JOURNAL.md.

Checkpoint: 9733830df9eee5ea95ea179da95323220445de7f, which commits the gate's artifact. No inventory row was re-recorded: no battery's declared paths changed this iteration and the staleness check reports 0 stale rows. Not a stall: BACKLOG.md gained M4, and an EVALUATOR entry is exempt regardless.

Verification:
- Standing claims were brought current before the invocation, and each was executed rather than asserted. Row staleness derived by asking git whether any path a battery declares changed since the commit its row records: 0 stale of 14, 0 unswept. No Declined entries and no Settled classes exist, so no Derivation and no enumeration had to be re-run. PLAN.md names no finding ID, so nothing is carried or blocked there and nothing can dangle. The Stated counts table holds no rows and neither state file writes a count in `returns <count>` form. `check-claims.sh` over the whole tree: `42 checked, 0 mismatched, 0 errored, 0 skipped`. The Oracle class and Environment fingerprint were re-read and the fingerprint's exclusion command re-run, which still returns no match. Verify green through the wrapper at 341, matching the Verify count line.
- The gate ran as exactly one fresh-context sub-agent and wrote its artifact at .jeffy/evaluator/467a4cf7-014604-1.md before returning, naming the run-id, the ordinal and the iteration, listing every command it ran with real exit statuses, and closing with the verdict.
- Evaluator: REJECT - one reason. `_TimedCache.get` was left outside the iteration read-freeze that M2 introduced, so inside one step of `for key in cache:` the cache reports `key in cache` True and `cache[key]` returns the value while `cache.get(key)` returns the default. The gate reproduced it against HEAD and showed the base commit agreeing on every row, and measured 128 of 500 trials diverging at a 0.0005s ttl on a real monotonic clock against 0 of 500 at base.
- I reproduced the reason independently before accepting it, rather than taking the verdict on trust. With a timer that advances on every call, HEAD prints the disagreement on both TTLCache and TLRUCache; the identical script against 4500e3d agrees on all six rows. The gate is right, and this is a regression this run introduced in the code its own fix touched.
- What the gate confirmed holds: the Verify command at 341; check-claims clean; M1 reproduced at base and its acceptance passing at HEAD with a wheel built from the sdist installing and importing; M2's clauses 2 and 3 failing at base and passing at HEAD, with the four behaviour-changing regression tests failing against the pre-fix module, and clause 1's replacement independently re-derived on the gate's own freeze-removed arm; M3's structural argument holding more strongly than the run stated, since `dict(cache)` raises at essentially the same rate at base as at HEAD, so no freeze lifetime could have fixed it; L1 and L2 acceptances passing; and L3 accurately scored Low.

Filed by the gate: M4 (Medium, runtime, correctness) - `_TimedCache.get` does not honour the iteration read-freeze, so `in`, `[]` and `get` disagree within one iteration step. Scored Medium by the gate and filed at that severity.

Two observations the gate recorded, neither a REJECT reason, both carried rather than fixed inside this sequence: M3 was recorded closed although the second clause of its filed acceptance does not hold at HEAD, and the unfixable residue belongs on a Declined line with a Derivation the declaration re-runs rather than living only in the journal and the docs; and the timed-machinery battery never drives `get`, `pop` or `setdefault` while an iterator is live, which is exactly why it passed 83 of 83 over this defect.

Learnings: the gate earned its invocation. M2's fix moved the boundary between what follows the clock and what follows the iteration, and I enumerated the operations on the write side of that boundary while never enumerating the ones on the read side - the battery I extended in the same iteration drives `__getitem__` and `__contains__` during iteration but not `get`, so the instrument agreed with the mistake. A claim about which operations honour a rule needs the enumeration driven at every site on both sides of it, not only the side the fix was thinking about.

Next: fix M4, re-invoke the gate under the one-transaction rule, and declare if it returns PASS. One budgeted iteration remains, so the fix, its acceptance check, the re-invocation and the declaration ride together.

## iter 10/10 | 467a4cf7-014604 | 2026-09-01 | M4 | done

Task: M4, the finding the evaluator gate filed at invocation 1, fixed under the one-transaction rule together with its acceptance check, the gate's re-invocation and the declaration. The budget forces the combination: this is the last budgeted iteration.

Changed: src/cachetools/__init__.py (a read-scoped freeze and a write instant on _TimedCache._Timer; get, pop and setdefault use the first, both __setitem__ implementations use the second), tests/test_ttl.py and tests/test_tlru.py (two regression tests each), docs/index.rst (the enumeration replacing the earlier sentence), .jeffy/probes/timed-machinery/ (probe, mutation, claims, README), .jeffy/probes/tlru/mutation.py, PLAN.md (Verify count), BACKLOG.md (M4 closed), JOURNAL.md.

Checkpoint: 01d8cfcb95e4022c1d574d6cfe8418726d405f3b. All 14 Surface inventory rows are re-recorded at that hash in this same edit, before the gate is re-invoked: every battery was re-run this iteration and the module eleven of them declare was changed. Not a stall: source, tests and docs changed, and M4 left the ledger.

Verification:
- The gate's reason was reproduced before it was accepted and again before the fix: with a timer that advances on every call, `for key in cache:` reported `key in cache` True and `cache[key]` returning the value while `cache.get(key)` returned the default, on both timed classes, where the base commit agreed on every row.
- The contract the change preserves, stated before touching shared code: one cache operation still sees one instant and still reads the user's timer exactly once, and a write is still never dated from an iteration's instant. `_Timer` gains `_enter_read`, which freezes a lookup at the in-flight iteration's instant when there is one and at now when there is not, and `_write_time`, which returns a fresh reading when the current freeze was inherited from an iteration and the operation's own instant otherwise. `get`, `pop` and `setdefault` use the first; the expiry stamped by `TTLCache.__setitem__` and `TLRUCache.__setitem__` uses the second, which is what keeps `setdefault` from storing an item that is already expired now that its lookup can inherit.
- The fix was enumerated at every site on both sides of the boundary, which is the discipline whose absence caused M4: `in`, `[]`, `get`, `pop` and `setdefault` see the iteration's instant; `len`, `currsize`, `expire`, `popitem` and the expiry a write stamps follow the clock; a write during an iteration survives the iterator and expires on its own schedule whether it was written directly or through `setdefault`; and `get`, `pop` and `setdefault` each still read the timer exactly once outside an iteration, because a timer is allowed to be stateful. Every one of those is driven on both classes by the timed-machinery battery, and the documentation states the same enumeration.
- M2 was re-checked and has not regressed: its clauses 2 and 3 still hold, and clause 1 is still deliberately unchanged.
- Verify gate green through the wrapper: `verify: green (5s, oracle=unit tests..., 345 passed in 4.25s)`. Verify count in PLAN.md updated from 341 to 345.
- Battery ownership: the diff touches `src/cachetools/__init__.py`, which eleven batteries declare, and all fourteen were re-run through the installed run-probe.sh with every one passing - cache-base 51, fifo-lru 22, lfu 16, rr 19, timed-machinery 115, ttl 32, tlru 37, cached 125, cachedmethod 151, cachedmethod-deprecated 18, keys 41, func 140, stubs 98, packaging 52.
- Two instrument defects were found and fixed here, both by running the checks rather than trusting them. `check-claims.sh` reported `1 errored`: the tlru battery's mutation no longer matched the source, because this fix renamed the local the TLRU expiry comparison uses, so the mutation could not apply at all. And the timed-machinery mutation, which patched only the timer, left the mutant raising on methods the old timer never had - red for the wrong reason. It now restores `src/cachetools/__init__.py` from the commit that preceded this run, so the mutant exhibits the pre-fix behaviour and fails on `a write during iteration is dated from the write` with the item born already expired.
- `pyright` caught two type errors in the regression tests I had just written, where a string was passed as `setdefault`'s default on an int-valued cache. Fixed before the checkpoint; `pyright` is back at `0 errors, 11 warnings, 17 informations`, the run's baseline. `ruff check .`, `ruff format --diff -q .`, `sphinx-build -W -b html` and `sphinx-build -W -b doctest` with 0 failures all pass.
- `check-claims.sh` over the whole tree after both instrument fixes: `42 checked, 0 mismatched, 0 errored, 0 skipped`.

Closed this run: M4 (Medium, runtime, correctness) - `in`, `[]`, `get`, `pop` and `setdefault` now agree inside one iteration step, writes are still never backdated, and the boundary is enumerated in the documentation and driven at every site by the battery.

Evaluator: REJECT at invocation 2, and terminal - the cap is 2 because invocation 1 landed at iteration 9, after the midpoint of the budget, so no invocation remains. The gate confirmed the M4 fix holds: invocation 1's reproduction now passes at HEAD and still fails against the pre-M4 tree, the two lookups-agree tests fail against that tree, 52 adversarial checks over nested iterators, exceptions mid-iteration, a storing setdefault under a held iterator, pickling and deepcopy found nothing, timer-call counts are unchanged from the base commit, and M1, M2 and M3 are not regressed. It rejected on one reason I reproduced independently before accepting: the enumeration this iteration added to docs/index.rst puts `expire` among the operations that follow the clock, and it does not - with an iterator held, `cache.expire()` returns nothing and removes nothing on both classes while `len(cache)` in the same instant reports 0 and empties the cache, because `expire`'s default instant is `self.timer()` and takes the iteration branch. The behaviour predates this run; the false claim about it is mine, and it defeats M4's own acceptance clause that the docs enumerate the boundary exactly. Filed as M5 (Medium, docs) with its Consequence stated.

The run therefore ends blocked rather than converged, at budget exhaustion with a terminal REJECT. One gate-filed finding was closed this run (M4) and one is open (M5); convergence waits for the next run's fresh gate.

A state-file corruption happened in this closing sequence and is recorded because the record is the point. The script that filed M5 and the observations edited BACKLOG.md and PLAN.md in turn but reused one path variable, so PLAN.md's contents were written over BACKLOG.md and PLAN.md never received its new Lessons. The corruption was committed, then caught by reading the ledger back rather than trusting the write, and recovered from the previous commit with `git show <checkpoint>:BACKLOG.md`, which is safe here only because the tree was clean; both edits were then re-applied and both files verified by reading them. Nothing was lost - every ledger line and every journal entry is intact - and the rule is now in PLAN.md.

Three observations the gate recorded, filed so they are not lost: L4, the timed-machinery `expire follows the clock` check asserts an empty result after `len` and `currsize` have already emptied the cache, so it cannot fail and that is why it passed over M5; L5, the two setdefault-during-iteration tests pass against the pre-M4 module, so half the tests added for M4 do not discriminate; L6, M3's residue still has no Declined line with a Derivation.

Learnings: a fix that moves a boundary has two sides, and enumerating only the side the fix was thinking about is how M2 shipped with `get` on the wrong one. The battery that certified M2 drove `__getitem__` and `__contains__` during iteration and never `get`, so the instrument agreed with the mistake and passed 83 of 83 over it. And a mutation must be restored from the real pre-fix commit rather than hand-patched, or it stops applying the moment the code around it moves - both failure modes appeared in this single iteration, one as a claims ERROR and one as a mutant that crashed instead of regressing.

Next: the gate's re-invocation, and the declaration if it returns PASS.

## iter 1/10 | bbe97bf0-033030 | 2026-09-01 | M5 | done

Task: M5, the finding the previous run's evaluator gate filed at its terminal invocation - the freeze enumeration in docs/index.rst puts `expire` among the operations that follow the clock during an iteration, and it did not. Fixed on the code side: `expire()` now follows the clock, so the enumeration became true rather than being weakened to match the defect.

Changed: src/cachetools/__init__.py (`_Timer._clock_time`, and both `expire` implementations taking their default instant from it), tests/test_ttl.py and tests/test_tlru.py (one regression test each), docs/index.rst (the enumeration narrowed to the operations actually driven), .jeffy/probes/timed-machinery/ (probe, claims, README), PLAN.md (Verify count, one Lesson), BACKLOG.md, JOURNAL.md.

Checkpoint: 702c34c54d1e622a9993f279eecb6b7dbb72c4d7. Not a stall: source, tests and documentation changed, M5 and L4 left the ledger and M6 entered it. The eleven Surface inventory rows whose batteries declare `src/cachetools/__init__.py` are re-recorded at that hash in this same edit; the three whose batteries declare only untouched paths - cachedmethod-deprecated, keys and packaging - keep their earlier commit.

Verification:
- The filed reproduction ran first, before anything was changed, and reproduced exactly as filed: with an iterator held and the clock advanced past every expiry, `cache.expire()` returned `[]` and removed nothing on both timed classes - the underlying store still held both items - while `len(cache)` in the same instant reported 0 and emptied it.
- Which fix: the ledger line offered either making `expire(None)` read the clock or moving `expire` to the frozen side of the documentation. The first is right and the second would have documented a defect. `expire()` is the documented way to reclaim memory; every internal caller (`len`, `currsize`, `popitem`, `__repr__`, both `__setitem__`s) already passes a clock-derived instant, so only the argumentless public call diverged, and it diverged because this loop added the iteration freeze - before it, `expire()` read the clock like everything else.
- The contract the change preserves, stated before touching shared code: one cache operation still sees one instant and still calls the user's timer exactly once. `_write_time()` is unchanged and still used by both writes; `_clock_time()` is defined on top of it as "the operation's instant when an operation is in flight, the clock otherwise", so an argumentless `expire()` reached from inside a cache operation still sees that operation's instant, and one outside any operation reads the clock.
- That contract was measured, not assumed, and it caught a defect in my own first attempt. Generalising `_write_time` into a single method broke it: `TTLCache.__setitem__` stamps its expiry just *outside* its own `with self.timer` block and depends on the instant that block left behind, so the generalised version read the clock a second time and one TTL write called a stateful timer twice. Counting timer calls found it; the returned instants looked right. `_write_time` was restored verbatim and `_clock_time` layered on it - measured again at 1 call per evicting write on both classes.
- The boundary was enumerated by execution on both sides and on both classes, which is the discipline whose absence produced M2 and then M5: `in`, `[]`, `get`, `pop`, `setdefault` see the iteration instant; `len`, `currsize`, `expire`, `popitem`, `repr` and the expiry a write stamps follow the clock. That enumeration also surfaced M6 below, which is why the documentation note no longer claims to cover "exactly" the lookups or "everything else" - it now lists the operations that were actually driven, and nothing wider.
- Regression tests: one per timed class, asserting `expire()` returns both expired pairs while an iterator is held and that a second `expire()` then returns nothing, so removal is pinned and not just reporting. Both were run against the pre-fix module (`src/cachetools/__init__.py` from d4dfd5b, copied aside and restored, never `git checkout`) and observed to fail there with `[(1, 1), (2, 2)] != []`, and to pass against the fix.
- Battery: the timed-machinery `expire follows the clock` check could not fail - it asserted an empty result after `len` and `currsize` in the same block had already emptied the cache, which is why it passed over M5 - and that is L4. It now runs on a cache of its own before anything can empty it, asserts the expired pairs, and a second check asserts they were removed. 115 checks to 117; against the pre-M5 tree the battery prints `115/117` failing exactly `TTLCache expire follows the clock` and `TLRUCache expire follows the clock` and nothing else, and that discriminating state is recorded in the battery README.
- Verify gate green through the wrapper: `verify: green (4s, oracle=unit tests..., 347 passed in 4.31s)`. Verify count in PLAN.md updated from 345 to 347.
- Battery ownership: the diff touches `src/cachetools/__init__.py`, declared by eleven batteries, and all eleven were re-run through the installed run-probe.sh, every one green - cache-base 51, fifo-lru 22, lfu 16, rr 19, timed-machinery 117, ttl 32, tlru 37, cached 125, cachedmethod 151, func 140, stubs 98. Their eleven Surface inventory rows are re-recorded at this iteration's checkpoint in the bookkeeping edit.
- `check-claims.sh` over the whole tree: `42 checked, 0 mismatched, 0 errored, 0 skipped`. `ruff check`, `ruff format --diff`, `sphinx-build -W -b html` and `-W -b doctest` all clean, and `pyright` at `0 errors, 11 warnings, 17 informations`, the recorded baseline.

Closed this run: M5 (Medium, docs, documentation) - `expire()` follows the clock, so the documented enumeration is true rather than the documentation being bent to the code. L4 (Low, test, testing) - closed by the same work, because M5's acceptance required exactly the repair L4 asked for: the check now runs before anything empties the cache and fails when `expire` is on the wrong side.

Filed this iteration: M6 (Medium, runtime, correctness) - the same enumeration, driven at every operation rather than at the ones the fix was thinking about, showed `del cache[key]` disagreeing with `key in cache` and `cache[key]` in the same iteration step, and the two timed classes disagreeing with each other: TTLCache deletes silently, TLRUCache raises KeyError, because `TTLCache.__delitem__` compares against `self.timer()` and `TLRUCache.__delitem__` against the instant its own `with self.timer` block read. `pop` is unaffected on both, so only a bare `del` diverges. Reproduced standalone before filing.

Learnings: a contract about how often a stateful callback is called is not visible in the values it returns, so a refactor of the timer has to be measured by call count as well - the generalisation that broke it returned correct instants everywhere. And the enumeration that proves a documentation claim is worth running past the operation under test: driving every public operation on both sides of the freeze cost one script and found M6, where driving only `expire` would have closed M5 and left the enumeration false in a second place.

Next: M6, the top of the ledger - decide which side `del cache[key]` belongs on, make both classes agree, and put it in the documentation enumeration with the battery driving it.

## iter 2/10 | bbe97bf0-033030 | 2026-09-01 | M6 | done

Task: M6, filed last iteration by the enumeration that closed M5 - `del cache[key]` disagreed with `key in cache` and `cache[key]` inside one iteration step, and the two timed classes disagreed with each other. Fixed by putting `del` on the lookup side on both classes, which is where `pop` already was.

Changed: src/cachetools/__init__.py (`TLRUCache.__delitem__` dates its expiry check from the read instant, as TTLCache already did), tests/test_ttl.py and tests/test_tlru.py (one regression test each), docs/index.rst (the enumeration's lookup list), .jeffy/probes/timed-machinery/ (probe, claims, README), PLAN.md (Verify count, two Lessons), BACKLOG.md, JOURNAL.md.

Checkpoint: ccedf787b1789794182c6c8cd22fd4b88ebf640d. Not a stall: source, tests and documentation changed and M6 left the ledger. The eleven Surface inventory rows whose batteries declare `src/cachetools/__init__.py` are re-recorded at that hash in this same edit.

Verification:
- The filed reproduction ran first and reproduced as filed: with an iterator held and the clock advanced past every expiry, `in` and `[]` reported the key live on both classes, while `del cache[key]` deleted silently on TTLCache and raised `KeyError` on TLRUCache.
- Which side `del` belongs on: the lookup side. `pop` is documented as frozen and is `[]` followed by `__delitem__`, and it already behaved frozen on both classes because it enters the read freeze first and `__delitem__` inherits that instant - so only a bare `del` diverged, and putting it on the clock side would have made `del cache[key]` and `cache.pop(key)` disagree for the same key in the same instant. The freeze exists so a key the iterator has just yielded can still be used; deleting it is using it.
- The fix is the smaller half of a symmetry: `TLRUCache.__delitem__` took its instant from its own `with self.timer` block, which reads the clock at nesting zero, while `TTLCache.__delitem__` compares against `self.timer()`. Dropping the `with` and comparing against `self.timer()` makes the two methods structurally identical. The block was only ever a way to read the instant once - nothing inside it consults the timer - so nothing else changed.
- The contract the change preserves, checked by measurement rather than assumed, because last iteration's near-miss was exactly here: the user's timer is still called once per delete on both classes, and an expired key deleted outside any iteration still raises `KeyError` on both, which is what `tests/test_ttl.py` and `tests/test_tlru.py` already pinned. Both measured directly - 1 timer call per delete, `KeyError` still raised - and the whole suite is green.
- Regression tests: one per class, holding an iterator, advancing the clock past every expiry, asserting the key is `in` the cache and then deleting it. Against the pre-fix module (`src/cachetools/__init__.py` from d4dfd5b, copied aside and restored, never `git checkout`) the TLRU test fails with `KeyError: 0` and the TTL test passes. That is honest rather than ideal: TTLCache was already on the correct side, so its test discriminates against a future regression, not against the code M6 was filed on. The TLRU test is the discriminator.
- Battery: three checks per class added - `in` before the delete, the delete's outcome, and the key gone afterwards - on a cache of their own, with the delete's outcome captured rather than left to propagate, because an exception in the probe body kills the run before its summary line and every claim keyed to that line would error instead of failing. 117 checks to 123.
- Instrument defect of my own, reported by the Stop hook at the start of this iteration and fixed here: last iteration's README stated `115/117` for the pre-fix shadow with no claims line executing it, so the number was remembered rather than derived. The `claims` file now carries a fourth line that rebuilds the shadow in a scratch directory - `src/cachetools/__init__.py` from d4dfd5b shadowed onto the interpreter through PYTHONPATH, the way `mutate.sh` does it, with the real tree never touched - runs the battery and prints its summary. Re-measured after this iteration's checks: `timed-machinery: 120/123 checks passed`, the three failures being both `expire follows the clock` checks and `TLRUCache del deletes what the iterator yielded`, which are exactly the two defects this run has fixed. README and claims agree, and `check-claims.sh` executes it.
- Verify gate green through the wrapper: `verify: green (4s, oracle=unit tests..., 349 passed in 4.20s)`. Verify count in PLAN.md updated from 347 to 349.
- Battery ownership: the diff touches `src/cachetools/__init__.py`, declared by eleven batteries, all eleven re-run through the installed run-probe.sh and green - cache-base 51, fifo-lru 22, lfu 16, rr 19, timed-machinery 123, ttl 32, tlru 37, cached 125, cachedmethod 151, func 140, stubs 98. Their rows are re-recorded at this iteration's checkpoint in the bookkeeping edit.
- `check-claims.sh` over the whole tree: `43 checked, 0 mismatched, 0 errored, 0 skipped`. `ruff check`, `ruff format --diff`, `sphinx-build -W -b html` and `-W -b doctest` clean, `pyright` at `0 errors, 11 warnings, 17 informations`, the recorded baseline.

Closed this run: M6 (Medium, runtime, correctness) - `del cache[key]` now sees the instant its iteration step began on both timed classes, agreeing with `in`, `[]`, `get`, `pop` and `setdefault`, and the documentation enumerates it there.

Learnings: a documentation claim that enumerates a set is worth driving one operation past the ones the fix was about - the enumeration written for M5 found M6 for free, and M6 was a divergence between two sibling classes that no test in the suite covered. And an instrument's number is only as good as the command that reproduces it: the README count I wrote last iteration was correct and still wrong to state, because nothing executed it.

Next: the ledger is at the severity floor - L3, L5 and L6, all Low - and no full audit has run this run. The next iteration audits the project fresh against the Method and the rubric, which is the precondition every later step of the closing rule rests on.

## iter 3/10 | bbe97bf0-033030 | 2026-09-01 | L3 | done

Task: L3, the top of the ledger now that nothing above Low is open - the nested-iteration branch of `_TimedCache._Timer._enter_iteration`, taken when a second iterator is opened on a cache that already has one suspended, was reached by no test in the suite.

Changed: tests/test_ttl.py and tests/test_tlru.py (one test each), PLAN.md (Verify count, one Lesson), BACKLOG.md, JOURNAL.md. No source file changed, so no Surface inventory row went stale and no battery is owed a run - `grep -l '^tests/' .jeffy/probes/*/paths` returns nothing.

Checkpoint: 5959bc577f06eb2ef61a2c61b7af2146690cda69. Not a stall: two test files changed and L3 left the ledger. No Surface inventory row is re-recorded, because no file any battery declares was touched.

Verification:
- The gap was reproduced first: `coverage run --source=cachetools -m pytest` then `coverage report -m` reported `577 statements, 1 missed` in `src/cachetools/__init__.py`, the missed statement being the `else` arm of `_enter_iteration`.
- Acceptance met: after the two tests, the same pair of commands reports `577 statements, 0 missed, 100%` for `src/cachetools/__init__.py`. The two statements still unexecuted in `src/cachetools/_cachedmethod.py` are the pre-3.13 classmethod-descriptor path that PLAN.md's Environment fingerprint already records as unreachable on this interpreter, and are outside this task.
- The first version of the test asserted the wrong thing and failed, which is worth recording because the failure was mine and the code was right: it drained one iterator to exhaustion and then expected the second to still be pinned. It is not. The freeze is held by a step suspended at its `yield`, not by a live iterator object, so when the last suspended step resumes the depth reaches zero and the following step reads the clock again. The corrected tests interleave the two iterators, so one is always suspended, and both then walk the whole cache at the instant the first step began.
- The tests discriminate. There is no pre-fix module for a coverage gap, so the equivalent evidence is a mutant: shadowing a copy of the tree whose nested branch starts a fresh freeze from the wrapped clock instead of joining the one in flight, both tests fail with `StopIteration` - the second iterator sees a clock 100 ticks past every expiry and yields nothing. Mutating to `self()` would have proved nothing, since `__call__` already returns the frozen instant while iterating; the mutation has to reach past it to the wrapped timer. The real tree was never touched: the mutant lives in a scratch copy on `PYTHONPATH`.
- Verify gate green through the wrapper: `verify: green (4s, oracle=unit tests..., 351 passed in 4.21s)`. Verify count in PLAN.md updated from 349 to 351.
- `ruff check`, `ruff format --diff` clean and `pyright` at `0 errors, 11 warnings, 17 informations`, the recorded baseline.

Closed this run: L3 (Low, test, testing) - two iterators held on one timed cache at once, both yielding consistently, and `src/cachetools/__init__.py` at 100% statement coverage.

Learnings: the freeze's lifetime is a suspended step, not a live iterator, and a test that reads it the other way asserts something the code never promised - interleave the iterators so the depth never returns to zero. And a mutation aimed at a branch has to reach past the layer that would mask it: patching the nested branch to call `self()` reproduces the correct behaviour exactly, because `__call__` consults the same freeze.

Next: L5, which asks that each test added for a finding be observed failing against that finding's pre-fix module, and replaces the two `setdefault_during_iteration_is_not_backdated` tests that do not.

## iter 4/10 | bbe97bf0-033030 | 2026-09-01 | L5 | done

Task: L5 - the two `setdefault_during_iteration_is_not_backdated` tests passed against the module M4 was filed on, so half the tests added for M4 proved nothing about M4. Replaced with tests that fail there, and the class behind the instance was enumerated and settled.

Changed: tests/test_ttl.py and tests/test_tlru.py (one test replaced in each), PLAN.md (one Lesson), BACKLOG.md (L5 closed, one Settled class line), JOURNAL.md. No source file changed, so no Surface inventory row went stale and no battery is owed a run.

Checkpoint: c7be6958407f5adc242c107adb7196fa9c8c5cd6. Not a stall: two test files changed, L5 left the ledger and a Settled classes line was added. No Surface inventory row is re-recorded, because no file any battery declares was touched.

Verification:
- L5 reproduced first: shadowing `src/cachetools/__init__.py` from 7762fa7, the commit that precedes M4's fix, the two setdefault tests pass. The shadow itself was checked in the same command - the two `lookups_agree_during_iteration` tests fail there, which is the M4 defect - so the pass is the tests' fault and not the harness's.
- Why they could not fail: pre-M4 `setdefault` entered no read freeze at all, so the item it stored was dated from the clock for the plain reason that nothing had frozen it. The backdating hazard those tests guard is one M4's own fix created, by letting `setdefault` inherit the iteration's instant, and `_write_time` is what prevents it. A test guarding a hazard the fix introduced has no pre-fix tree to fail on.
- The replacements assert both halves of the boundary in one test - the lookup half, that a key the iterator has just yielded is returned rather than overwritten, and the write half, that an item stored during the iteration survives the iterator. They fail against 7762fa7 on the lookup half with `AssertionError: 1 != -1`, and against a mutant whose `_write_time` drops its inheritance guard on the write half with `99 not found in TTLCache({}, maxsize=20, currsize=0)`. Both classes, both mutants.
- The class, not the instance: `grep -h 'def test_.*\(iterat\|freeze\|copy_through_items\)' tests/test_ttl.py tests/test_tlru.py | wc -l` returns 18, and every one of those 18 was run against the three pre-fix trees in range. 11 fail on at least one - 8 on 4500e3d, 3 more first failing on 7762fa7, none newly on d4dfd5b. The remaining 7 had never been seen to fail, so their evidence was produced here: a mutant whose `_Timer.__call__` ignores the iteration freeze fails all four `read_during_iteration` and `copy_through_items` tests, a mutant whose `TTLCache.__delitem__` dates from its own operation freeze fails `ttl_delete_during_iteration_agrees_with_lookups` - the one I recorded last iteration as a guard rather than a discriminator - and the two `second_iterator_joins_the_freeze_in_flight` tests already had the nested-branch mutant recorded at L3. 11 plus 4 plus 1 plus 2 is 18, so the class is closed rather than sampled, and the Settled classes line records the enumerating command.
- What the enumeration shows about the freeze's history, worth stating because it corrects a reading in this run's own notes: the per-step freeze is upstream, not this loop's. At 4500e3d `__iter__` already pinned reads through the operation freeze, which is why the `read_during_iteration` tests pass there. M2 separated the read freeze from the write freeze; it did not introduce freezing.
- Verify gate green through the wrapper: `verify: green (5s, oracle=unit tests..., 351 passed in 4.19s)`. Verify count unchanged at 351, since two tests were replaced rather than added.
- `ruff check`, `ruff format --diff` clean and `pyright` at `0 errors, 11 warnings, 17 informations`, the recorded baseline.

Closed this run: L5 (Low, test, testing) - the two setdefault tests now fail on the code M4 was filed on, and every test over the freeze surface has a recorded state it was observed failing on.

Learnings: "run it against the pre-fix module" is the right rule with a blind spot, and this is the shape of the blind spot - a test that guards a hazard the fix itself introduced has no pre-fix tree where it can fail, so demanding one either licenses deleting a good test or invites a weaker one that happens to fail for an unrelated reason. The evidence such a test needs is a mutant of the property it guards, produced when the test is written. And an enumeration over a test surface is cheap in a way it is easy to forget: three shadowed trees and two mutants covered all 18 tests in one iteration, where checking them one finding at a time would have taken the rest of the budget.

Next: L6, the last open task - M3's unfixable residue has no Declined line with a `Derivation:`, which the declaration re-runs. After that the ledger is empty and the closing full audit is the precondition the rest of the closing rule waits on.

## iter 5/10 | bbe97bf0-033030 | 2026-09-01 | L6 | done

Task: L6, the last open task - M3's residue was documented in the journal and the docs but never recorded under Declined with a `Derivation:` the declaration re-runs, so the premise the project rests on was memory rather than a command.

Changed: BACKLOG.md (L6 closed, the Declined line written), .jeffy/probes/timed-machinery/residue.py (new, the derivation) and its README, JOURNAL.md. No source, test or documentation file changed, so no Surface inventory row went stale and no battery is owed a run beyond the one whose directory this touched.

Checkpoint: 2790d1d09c42db80e88ac76f50c0a076d4f270ff. Not a stall: L6 left the ledger and the Declined section gained the entry it names. No Surface inventory row is re-recorded, because no file any battery declares as covered was touched.

Verification:
- The residue reproduced: `dict(cache)`, `{**cache}` and `dict.update(cache)` build a copy by asking for `keys()` and only then reading each value, so nothing is left suspended to hold the per-step freeze and a key handed over live is read after it expired.
- The first derivation I wrote was wrong in a way worth recording, because it printed a stable number that meant something else. With a timer advancing one tick per call, `merge forms raise 3/6` every run - but the three that did not raise were TTLCache's, and they did not raise because every item was long expired by the time iteration began, so the copy came back empty. An empty copy of a wholly expired cache is correct behaviour, not the residue, and a premise resting on that number would have been resting on a coincidence.
- The derivation now calibrates instead of tuning a ttl to straddle the race: a first pass counts the timer calls spent building the cache and collecting its keys, and the measured pass holds that instant for exactly that many calls and then jumps past every expiry. Every key is therefore live when it is handed over and expired when its value is read, on both classes, with no magic constant. It returns `residue: merge forms raise 6/6, read-through forms raise 0/6` - all three merge forms on both classes, and none of `dict(cache.items())`, `list(cache.values())` or a comprehension over a suspended iterator - identically on repeated runs and under `PYTHONHASHSEED` 0, 1, 42 and 12345.
- Determinism is the point rather than a nicety. M3 measured the residue with a real clock over 2000 trials, and the journal for that iteration says outright that the rate of a race is not a stable measurement. A Declined premise is re-run by the declaring iteration and by the evaluator, so a derivation that answers differently each time would reopen the finding at random; the calibrated clock turns the race into a fact.
- The derivation is deliberately not a claims line. `check-claims.sh` failures on battery lines are scored as instrument drift, Low, while a Declined premise that stops holding must reopen the finding - so it stays where the framework puts it, on the Declined line, and the battery README says what `residue.py` is without restating its numbers.
- Verify gate green through the wrapper: `verify: green (5s, oracle=unit tests..., 351 passed in 4.22s)`. Verify count unchanged at 351.
- timed-machinery re-run through the installed run-probe.sh because its directory changed: 123/123. `check-claims.sh` over the whole tree: `43 checked, 0 mismatched, 0 errored, 0 skipped`. `ruff check` and `ruff format --diff` clean over the new file.

Closed this run: L6 (Low, docs, documentation) - the residue is on the Declined line with a derivation that reproduces it deterministically, so the premise is re-checkable rather than remembered.

Learnings: a derivation that returns the same number every run is not yet a derivation that measures the right thing - the first version here was perfectly stable and stable for the wrong reason, and only breaking the total down per class and per form showed that half of it was an empty copy rather than a raise. Calibrating an instrument off the system under test - counting the calls the real path makes, then replaying against that count - beats choosing a constant that happens to straddle the window, because the constant silently stops straddling the moment the path changes.

Next: the ledger is empty and every Surface inventory row is swept. The closing full audit comes next - fresh evidence, every applicable dimension rescored against the rubric and the Operating envelope - and it is the precondition the evaluator gate and any declaration wait on.

## iter 6/10 | bbe97bf0-033030 | 2026-09-01 | AUDIT | audit

Task: the closing full audit - every applicable dimension rescored with fresh evidence against the severity rubric and the Operating envelope, with the ledger empty and all 14 Surface inventory rows swept.

Changed: BACKLOG.md (one Low filed), JOURNAL.md. No source, test, documentation or probe file changed.

Checkpoint: 0aebb9d61e1666413d70637e7a94a7d275c96cda. Not a stall: L7 entered the ledger, which is a BACKLOG item changing state. No Surface inventory row is re-recorded, because this iteration changed no file any battery declares.

Verification: every figure below is from a command run this iteration, not from an earlier entry.
- All 14 batteries re-run through the installed run-probe.sh, every one green: cache-base 51, cached 125, cachedmethod 151, cachedmethod-deprecated 18, fifo-lru 22, func 140, keys 41, lfu 16, packaging 52, rr 19, stubs 98, timed-machinery 123, tlru 37, ttl 32.
- Standing claims re-derived: the Declined M3 residue derivation returns `residue: merge forms raise 6/6, read-through forms raise 0/6`, exactly what its line states; the Settled-class enumeration returns 18, exactly what its line states; `check-claims.sh` over the tree reports `43 checked, 0 mismatched, 0 errored, 0 skipped`. PLAN.md names no finding ID as carried or blocked, so nothing dangles.
- Oracle class and Environment fingerprint re-read and re-derived rather than trusted: the exclusion command `grep -rnE 'skipif|pytest\.skip|xfail|sys\.version_info|sys\.platform' tests/` still returns nothing, so no test is skipped or platform-guarded; the toolchain is CPython 3.14.4 and pytest 9.1.1, as the fingerprint records. Verify count 351 equals the wrapper's green line.
- Verify gate green: `verify: green (5s, oracle=unit tests..., 351 passed in 4.21s)`.
- Testing was not scored clean until a module ran in isolation, per the Method. All 13 test modules were run one at a time and each passed, and their counts sum to 351, the whole-suite total, so nothing is order-dependent, leaked or double-counted.

Scores, over all 14 rows, none unswept:
- Correctness: None. 841 battery checks over the whole map, 351 tests, and 100% statement coverage of `__init__.py`, `_cached.py`, `func.py` and `keys.py`.
- Security: None. The envelope records no adversarial surface, and nothing in the shipped source reaches one: `eval`, `exec`, `pickle.loads`, `subprocess`, `os.system`, `__import__`, `marshal` and `shelve` appear nowhere under `src/cachetools/`. Pickle support is `__reduce__`/`__setstate__` over the project's own caches, which the envelope classifies state-at-rest.
- Error handling: Low. Filed as L7 - `Cache.popitem()` on an empty cache raises a bare `KeyError` while every subclass names the class. Every other failure path was driven fresh and behaves: negative maxsize, an oversized value, an unhashable key, a missing key, and a user callable that raises inside `timer`, `ttu`, `choice` or `getsizeof` all raise the right exception and propagate rather than being swallowed.
- Performance: None. A churn workload with forced eviction was timed at 20000 and 80000 operations on all six cache classes; every ratio is between 3.7 and 4.5 for a fourfold workload, so all six are linear and none degrades.
- Documentation: None. `sphinx-build -W -b html` and `-W -b doctest` both exit 0, the doctest summary reports 58 tests and 0 failures, and all 18 names in the three `__all__` lists appear in `docs/index.rst`.
- Dependency hygiene: None. Zero runtime dependencies - `pip show` reports `Requires:` empty and every import in the shipped source is stdlib. `requires-python = ">= 3.10"` matches the floor of the CI matrix.
- Testing: None. 351 tests, every module green in isolation, and the freeze surface's 18 tests each have a recorded state they were observed failing on.
- Architecture and code quality: None. No dead code - coverage reaches every statement of four modules, and the two it does not reach in `_cachedmethod.py` are the pre-3.13 classmethod-descriptor path the fingerprint already records as unreachable on this interpreter. `ruff check`, `ruff format --diff` clean and `pyright` at `0 errors, 11 warnings, 17 informations`, the run's baseline.
- Developer experience: None. The tox envs, the CI matrix and the linters are configured and pass here.
- Observability: not applicable. A synchronous in-process data-structure library with no I/O, no logging surface and no metrics to emit; the one introspection surface is `cache_info()` on the decorators, which the cached, cachedmethod and func batteries drive.
- UX and accessibility: not applicable. No user-facing surface - the envelope's five surfaces are all in-process API.

Zero High and zero Medium in-envelope. Closeout has begun: this run stops auditing from here, works what is on the ledger, and converges. The single Low filed by this audit does not block a declaration; it is either fixed in the next iteration or carried by ID.

Learnings: an audit that only re-runs the instruments the run itself built is partly self-confirming, so the dimensions no battery covers were driven directly this iteration - failure paths by provoking each one, performance by timing two workload sizes and comparing the ratio rather than asserting a bound, dependency hygiene by asking pip and the import lines rather than reading the manifest. The one finding came from that part, not from the batteries.

Next: L7, the only open task, and then the evaluator gate and the declaration in the same iteration, which leaves iterations 9 and 10 as reserve should the gate reject.

## iter 7/10 | bbe97bf0-033030 | 2026-09-01 | L7 | done

Task: L7, the only finding the closing audit filed - `Cache.popitem()` on an empty cache raised a bare `KeyError` while every subclass named the class.

Changed: src/cachetools/__init__.py (`Cache.popitem`), tests/__init__.py (the shared mixin's `test_popitem`), docs/index.rst (`popitem` added to the `Cache` autoclass members), .jeffy/probes/cache-base/ (probe, claims, README), BACKLOG.md, JOURNAL.md.

Checkpoint: 3160796d6521ca46421fe100bb9bc26e670e5480. Not a stall: source, tests, documentation and a battery changed, and L7 left the ledger. The eleven Surface inventory rows whose batteries declare `src/cachetools/__init__.py` are re-recorded at that hash in this same edit.

Verification:
- The finding reproduced first: `Cache(1).popitem()` on empty raised `KeyError` whose `args` was the empty tuple, while `FIFOCache`, `LFUCache`, `LRUCache`, `RRCache`, `TTLCache` and `TLRUCache` each raised `KeyError('<Class> is empty')`.
- Blast radius established before touching shared code, by asking the classes rather than reading them: of the seven public cache classes, only `Cache` itself resolved `popitem` to `MutableMapping.popitem`; all six subclasses define their own. So the override changes the base class alone.
- The contract the change preserves: `Cache.__setitem__`'s eviction loop calls `self.popitem()` twice, and the victim it picks must not move. The new implementation takes `next(iter(self.__data))` where `MutableMapping.popitem` took `next(iter(self))`, and `Cache.__iter__` returns `iter(self.__data)`, so they are the same key. Checked differentially rather than argued: against the pre-fix module a two-item base cache evicts `('a', 1)` leaving `{'b': 2}` and an evicting write leaves `['b', 'c']`; against the fix, identically. The suite's `test_popitem_exception_context`, which pins `__cause__ is None` and `__suppress_context__`, still passes because the raise uses `from None`.
- The test went into the shared `CacheTestMixin`, not into `test_cache.py`, so the contract is pinned for all seven classes at once rather than for the one that was broken. Against the pre-fix module it fails on `CacheTest::test_popitem` with `IndexError` from `e.args[0]` and passes for the other six - one failure, on the one class that had the defect.
- Battery: the cache-base check `popitem on empty` asserted only the exception type, so it passed over this defect. It now drives all seven classes and compares the message, 51 checks to 58, and against the pre-fix tree the battery prints `57/58` failing exactly `Cache popitem on empty names the class`. The README says so and states no count of its own.
- Typing needed no change: the stub declares `Cache(MutableMapping[_KT, _VT])` and `popitem` comes from the stubbed base, which is why `pyright` stays at `0 errors, 11 warnings, 17 informations` and the stubs battery is unmoved at 98.
- Verify gate green through the wrapper: `verify: green (5s, oracle=unit tests..., 351 passed in 4.20s)`. Verify count unchanged at 351, because an existing test was strengthened rather than a new one added.
- Battery ownership: the diff touches `src/cachetools/__init__.py`, declared by eleven batteries, all re-run through the installed run-probe.sh and green - cache-base 58, fifo-lru 22, lfu 16, rr 19, timed-machinery 123, ttl 32, tlru 37, cached 125, cachedmethod 151, func 140, stubs 98. Their rows are re-recorded at this iteration's checkpoint in the bookkeeping edit.
- `check-claims.sh` over the whole tree: `43 checked, 0 mismatched, 0 errored, 0 skipped`. `ruff check`, `ruff format --diff`, `sphinx-build -W -b html` and `-W -b doctest` clean, the doctest summary again 58 tests and 0 failures.

Closed this run: L7 (Low, runtime, error handling) - every cache class now names itself when `popitem` finds nothing to remove, the base class included, and the battery compares the message rather than the exception type.

Learnings: a check that asserts only an exception type will pass over a message defect forever, and the cache-base battery had been doing exactly that since it was written - `b.raises(..., KeyError, ...)` is satisfied by the bare one and by the named one alike. When the contract is the message, the check has to read the message. And the cheapest way to bound a change to a shared base class is to ask the subclasses which of them resolve the method to the base, rather than reading each one.

Next: the evaluator gate and, if it returns PASS, the declaration in that same iteration - the ledger is empty, all 14 rows are swept and re-recorded, and the closing audit is on this run's record from before any extension window.

## iter 8/10 | bbe97bf0-033030 | 2026-09-01 | EVALUATOR | converged

Task: the evaluator gate, invocation 1 of this run, and the declaration in the same iteration on its PASS.

Changed: BACKLOG.md (four carried Lows filed from the gate's observations, and the Converged line), .jeffy/evaluator/bbe97bf0-033030-1.md (the gate's artifact), JOURNAL.md. No source, test, documentation or probe file changed.

Checkpoint: f8e4c03679a29bcbfbb4b5c81c5bb38915a758ab, which commits the evaluator artifact. Not a stall: four items entered the ledger. No Surface inventory row is re-recorded, because this iteration changed no file any battery declares.

Verification:
- Standing claims were brought current before the invocation, not after it. The eleven Surface inventory rows whose batteries declare `src/cachetools/__init__.py` already point at 3160796, the commit that file last changed in; the three rows still recorded at 01d8cfc were checked rather than assumed, and `git log 01d8cfc..HEAD` over `_cachedmethod.py`, `keys.py`, `pyproject.toml`, `MANIFEST.in`, `tox.ini` and `.github/workflows/ci.yml` is empty, so none is stale. The Declined M3 Derivation returns `residue: merge forms raise 6/6, read-through forms raise 0/6` and the Settled-class enumeration returns 18, both exactly what their lines state. `check-claims.sh` reports `43 checked, 0 mismatched, 0 errored, 0 skipped`. PLAN.md names no finding ID as carried or blocked. The Environment fingerprint's exclusion command still returns nothing, and Verify count 351 equals the wrapper's green line.
- Evaluator: PASS at invocation 1, on a fresh-context sub-agent given the run-id, the iteration and the ordinal. It reproduced M5 and M6 itself against d4dfd5b rather than reading this journal - M5 failing there with `expire() -> []` and the store still holding both items, M6 failing there with TLRUCache raising `KeyError` where TTLCache deleted - confirmed both pass at HEAD, re-executed both acceptance checks including the pre-fix battery shadow at `120/123`, and ran a 20-probe differential across both timed classes and the base `Cache` covering timer call counts, expired deletes, the expired-overwrite path, pickling, the eviction victim and the popitem exception context: it differs between d4dfd5b and HEAD on exactly one line, L7's intended `KeyError(())` to `KeyError('Cache is empty')`. Verify green at 351 through the wrapper.
- The artifact is at `.jeffy/evaluator/bbe97bf0-033030-1.md`, opens by naming run-id bbe97bf0-033030, invocation 1 and iteration 8 of 10, lists every command with its real exit status, closes with PASS, and carries no machine-absolute path - `grep -nE '/home/|/tmp/|C:\\'` over it returns nothing. This iteration's checkpoint commits it.
- The gate recorded four observations, none a REJECT reason and each scored Low. They were filed to the ledger and deliberately not fixed: a fix after a PASS invalidates that PASS and spends an invocation the declaration needs, which is a sequence two runs have died on.
- Closing conditions checked one by one: the full fresh-evidence audit at iteration 6 scored zero High and zero Medium in-envelope; the Surface inventory lists no unswept row, 14 of 14; no open High or Medium remains in Now, Next or Later; the only commits since that clean audit are L7's fix, which that audit filed, plus loop state file edits; the Verify command is green this iteration; and the evaluator returned PASS.

Carried Lows, each open with its severity on its own task line, none blocking:
- L8 (Low, runtime, documentation): `_clock_time`'s docstring overstates what it lends an in-flight read that inherited an iteration's instant; internal docstring only, no shipped call site reaches the combination.
- L9 (Low, dev-tooling, testing): the cache-base battery's pre-L7 shadow is stated in prose with no claims line rebuilding it, where timed-machinery carries one.
- L10 (Low, dev-tooling, testing): two battery READMEs state historical counts - "passed 83 of 83" and "failed 76 differential trials" - that no command reproduces.
- L11 (Low, dev-tooling, testing): timed-machinery's paths file omits `docs/index.rst`, so a docs-only edit to the freeze enumeration would not trigger the battery that certifies it.

Learnings: the gate is worth more when the run has already spent its own effort making every premise re-runnable - this invocation reproduced both Mediums from scratch and re-derived every standing claim, and it found nothing in the product because those claims were already commands rather than sentences. Its four observations are all about the loop's own instruments, which is where the remaining softness in this tree actually is.

Next: nothing in this run. The four carried Lows are the next run's first tasks, and the next run ratchets rather than re-audits if nothing but loop state moves.
