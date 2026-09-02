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

## iter 1/10 | efdb1582-222823 | 2026-09-01 | AUDIT | audit

Task: First audit of natsort. Filled the Operating envelope, the Surface inventory, and the Verify command block in PLAN.md, enumerated the packaging channels, and scored the project breadth-first.

Changed: PLAN.md (envelope surfaces, 22 inventory rows, Verify command / Oracle class / Environment fingerprint / summary pattern / count / duration), BACKLOG.md (10 findings plus 1 Declined), JOURNAL.md, .gitignore (loop state file).

Checkpoint: 5484ed6fc459dd2f3efe8c02325c7b952f6d2142

Verification: `bash <jeffy>/hooks/lib/quiet-verify.sh PLAN.md .` returned `verify: green (3s, oracle=..., 369 passed, 1 warning in 3.26s)`. Verify count recorded as 369 from that run, not typed.

Scores, from a breadth-first shallow probe of the public surface; zero of the 22 Surface inventory rows are formally swept with a committed battery, so these claim only what the probe reached and not the unexamined remainder:
- correctness: High - NS-1, the PyICU NUMAFTER sentinel; also NS-3, the CLI blank line on empty stdin.
- error handling: Medium - NS-2 console-script traceback; NS-6 and NS-7 at Low.
- documentation: Medium - NS-4, the os_sorted str-coercion promise the POSIX fallback does not keep.
- dependency hygiene: Medium - NS-5, the sdist carrying the loop's state files. The two optional dependencies are both version-gated at import.
- testing: Low - NS-9 and NS-10. The suite runs 369 checks and passes; no test was found to be order-dependent in the modules run in isolation.
- developer experience: Low - NS-8.
- architecture, code quality, security, performance: None on what the probe reached. The shipped package opens no network socket, spawns no subprocess and deserializes nothing; the number regexes are flat alternations with fixed-width lookbehinds, so no catastrophic backtracking path was found.
- observability: not applicable - a sorting library and a stdout filter with no logging or metrics surface.
- UX and accessibility: the CLI is the only user-facing surface and its defects are scored under correctness and error handling above; accessibility does not apply to a stdout filter.

Packaging channels, enumerated by command rather than recall: `git ls-files | grep -iE "manifest|Dockerfile|\.gemspec|nuspec|Cargo.toml|package.json"` returns nothing, `ls MANIFEST.in` fails, and `.github/workflows/deploy.yml` publishes with `python -m build`. Both artifacts were built and read. The wheel carries only the natsort package and its dist-info. The sdist, built with PLAN.md, BACKLOG.md and JOURNAL.md staged, carried all three - filed as NS-5 at Medium with its Consequence.

Learnings: PyICU cannot be installed on this host (no libicu-dev and no way to add it), so the ICU half of natsort/compat/locale.py and the ICU branch of os_sort_keygen cannot be exercised end to end. They are still reachable for inspection: loading natsort/compat/locale.py through `importlib.util.spec_from_file_location` with a stub `icu` in `sys.modules` executes the ICU branch and is how NS-1 was reproduced. Loading it by `import natsort.compat.locale` does not work, because natsort/__init__.py imports natsort.natsort, which builds a real collator at module scope.

Next: NS-1, the highest open finding.

## iter 2/10 | efdb1582-222823 | 2026-09-01 | NS-1 | done

Task: NS-1 (High, runtime, correctness) - the PyICU sentinel `null_string_locale_max` in natsort/compat/locale.py held `b"x7f" * 50`, the three ASCII characters x, 7, f, rather than the maximum byte its own comment claims. Under `alg=ns.NUMAFTER|ns.LOCALE` natsort prepends that sentinel to every number, so on a machine with PyICU any string whose collation key begins above byte 0x78 sorted after the numbers instead of before them, inverting the one thing NUMAFTER exists to do. Fixed to `b"\xff" * 50`. Closed and deleted from BACKLOG.md.

Changed: natsort/compat/locale.py (one constant), tests/test_compat_locale.py (new), CHANGELOG.md (Unreleased/Fixed), PLAN.md (Verify count 369 to 378; the Environment fingerprint clause that said ruff and mypy were absent from the venv, now installed and passing but still outside the oracle; one Lessons line that carried a test count), BACKLOG.md (NS-1 deleted, NS-11 filed).

Checkpoint: c3c106fb165ed51e6024113577b1a96e5e06a7d6

Verification: acceptance check run against unfixed code first, per the rule - the fixed file was copied aside, `git show HEAD:natsort/compat/locale.py` restored the old content, and `pytest tests/test_compat_locale.py` exited 1 with `FAILED test_icu_null_string_locale_max_is_the_maximum_byte_string`; the fixed file was restored and the same command exited 0 with 9 passed. Verify gate: `quiet-verify.sh PLAN.md .` returned `verify: green (3s, oracle=..., 378 passed, 1 warning in 3.28s)`. `mypy --strict natsort tests` reports success on 32 source files and `ruff format --check` exits 0. Claims re-executed before the checkpoint: the Environment fingerprint's skip-marker enumeration still returns only the three locale fixtures in tests/conftest.py, `import icu` still fails and /usr/include/unicode/uvernum.h is still absent, and the sibling claim behind NS-7 still reproduces.

Contract preserved: the constant is private to natsort.compat and is read at one site, natsort/natsort.py's NUMAFTER branch, where it is used only as an ordering sentinel prepended to numbers; its type (bytes) and its role are unchanged, so no public signature, documented behaviour or non-PyICU result moves. The eight non-PyICU cases in tests/test_natsorted.py that pin `ns.LOCALE | ns.NUMAFTER` orderings are unaffected and still pass, because the POSIX branch binds a different name.

New finding filed while working the task: NS-11 (Low, build-ci) - pyproject.toml sets ruff `select = ["ALL"]` against an unpinned ruff, so ruff 0.16.5 reports CPY001 on every file in the tree plus a few newer rules; the new test file adds nothing above that baseline, which was confirmed per-rule before and after.

Learnings: the project's own CI gate is wider than the Verify command - tox also runs `ruff format --check`, `ruff check` and `mypy --strict natsort tests`. mypy and ruff are now installed in the venv so every iteration can check its own diff against them, and a new test must clear mypy --strict, which rules out bare `Any` in fixtures: annotate a module-loading fixture as `Iterator[types.ModuleType]` and keep imports at module scope or ruff's PLC0415 and ANN401 fire.

Next: NS-2, the top open Medium - the console script's missing error handlers.

## iter 3/10 | efdb1582-222823 | 2026-09-01 | SWEEP | done

Task: Sweep. The queue orders open High tasks, then unswept Surface inventory rows, then Medium, then Low, so with the ledger's only High closed the map outranks the four open Mediums. Built the battery framework and swept ten of the twenty-two rows: utils-regex, utils-path-splitter, utils-helpers, utils-parse-factories, utils-transform-factories, api-keygen, api-sorters, api-index, api-decoders, ns-enum.

Changed: .jeffy/probes/_harness.py (new, shared), ten new battery directories each holding probe.py, paths, claims and README.md, and PLAN.md (ten inventory rows flipped in the bookkeeping edit below).

Checkpoint: 6df4d249ef63587912fab129096d87af62d0a226

Verification: every battery was executed through the installed run-probe.sh and all pass. `check-claims.sh .` reports `claims: 47 checked, 0 mismatched, 0 errored, 0 skipped`. Verify gate: `quiet-verify.sh PLAN.md .` returned `verify: green (4s, oracle=..., 378 passed, 1 warning in 3.69s)`. The sweep surfaced no in-envelope finding: every documented behaviour these ten rows cover matched its known answer.

Evidence bar: these are known-answer and invariant batteries, never run-without-crash. Each pins fixed inputs to fixed outputs, exercises every documented parameter it covers at two or more values and asserts those values change the output, and was run against a deliberate defect and observed to redden - each battery's mutation keys and the number of checks each reddens are recorded as claims lines and re-executed by check-claims.sh, so the instruments are known to be capable of failing rather than merely known to be green. The mutations model the real failure shapes: a flag that stops reaching its factory, a sentinel that stops distinguishing None from NaN, an argument silently dropped, and for path_splitter the actual pre-PR-191 behaviour that stripped extension text from the middle of a stem.

Learnings: a probe that resolves its own imports with `__file__.rsplit("/", 2)[0]` breaks when the caller passes a path with a doubled separator, which is exactly what a `for d in .jeffy/probes/*/` loop produces; the claims files generated that way all recorded an empty expected value because the import error went to stderr. Resolve with `pathlib.Path(__file__).resolve().parent.parent` instead. Two mutation shapes are also unusable: one that raises inside a check (the harness evaluates arguments before it can catch anything) and one that recurses without bound. A mutation has to fail the comparison, not the interpreter.

Next: twelve rows remain unswept - api-exports, api-os-sorted, cli-main, cli-filters, unicode-numbers, compat-fastnumbers, compat-fake-fastnumbers, compat-locale-posix, compat-locale-icu, packaging, dev-scripts, version-module - and they stay above the open Mediums in the queue.

## iter 4/10 | efdb1582-222823 | 2026-09-01 | SWEEP | done

Task: Sweep. The map still outranked the four open Mediums, so this iteration swept the remaining twelve rows: compat-fake-fastnumbers, compat-fastnumbers, compat-locale-posix, compat-locale-icu, unicode-numbers, api-exports, api-os-sorted, cli-main, cli-filters, packaging, dev-scripts, version-module. The Surface inventory now lists no unswept row.

Changed: twelve new battery directories under .jeffy/probes/, each with probe.py, paths, claims and README.md, and PLAN.md (twelve inventory rows flipped in the bookkeeping edit below).

Checkpoint: 9eee92b07d61ed3e21dfdf6170cbb71276574eb6

Verification: every battery executed through the installed run-probe.sh and all pass. `check-claims.sh .` reports `claims: 96 checked, 0 mismatched, 0 errored, 0 skipped`, up from 47 rows last iteration. Verify gate: `quiet-verify.sh PLAN.md .` returned `verify: green (4s, oracle=..., 378 passed in 3.32s)`. The sweep surfaced no new in-envelope finding; the two observations it printed are the already-filed NS-5 and NS-8 and are recorded as notes on stderr rather than as assertions, so closing either will not redden its battery.

Coverage notes worth keeping. The compat-locale-icu battery reaches the PyICU branch that PyICU's absence makes unreachable, by loading natsort/compat/locale.py through importlib with a stub icu in sys.modules; its sentinel-is-x7f mutation is the exact pre-fix state of NS-1, so that row's instrument has been observed failing on the real defect rather than on an invented one. The cli-main and cli-filters batteries drive the installed CLI as a subprocess rather than calling main() in-process, which is what the Method requires of a user-facing surface. The packaging battery builds both artifacts for real into a temporary directory and reads them; it asserts the wheel carries no loop state and prints the sdist's loop-state entry count as an observation, because that outcome is NS-5's to change. The dev-scripts battery runs the unicode generator against a throwaway tree and asserts the shipped table is a subset of a freshly generated one, which separates a stale table that would change behaviour from one that differs only in formatting - the shipped table is a subset, so it is not stale in any way a user meets.

Learnings: a mutation that only mutates an observation the battery prints rather than a check it asserts reddens nothing, and reads as a working discriminator until the count is looked at; check the reddened count of every mutation, never just that the mutation exists. Two more mutation shapes are unusable for the same reason the earlier ones were: assigning a wrongly typed value to something a later check indexes or measures raises instead of failing, so mutate to a wrong value of the right type.

Next: the map is clear at twenty-two of twenty-two rows, so the queue falls to the open Mediums. NS-2, the console script's missing error handlers, is the top item.

## iter 5/10 | efdb1582-222823 | 2026-09-01 | NS-REGRESSION | done

Task: Repair a regression this run introduced, ahead of the ledger. The Stop hook reported the utils-regex row stale because natsort/unicode_numeric_hex.py had changed since it was swept. It had: iteration 4's dev-scripts battery carried a mutation, generator-runs-anywhere, that ran dev/generate_new_unicode_numbers.py with its working directory set to the real project root. That script writes natsort/unicode_numeric_hex.py relative to its cwd, so the probe overwrote shipped source, and the iteration 4 checkpoint's git add -A committed it. The file gained the eighty Unicode 16.0 characters this Python knows about and lost its module docstring and its required `from __future__ import annotations`, which is a ruff I002 and D200 failure in the project's own Code Quality workflow. The Verify command never saw it, because that command grades behaviour and the table was still valid.

Changed: natsort/unicode_numeric_hex.py restored byte for byte to its upstream content, verified by `git diff --stat e90771d7c39157d079425b655763938c2709d486 -- natsort/unicode_numeric_hex.py` returning empty; .jeffy/probes/dev-scripts/probe.py hardened so the class cannot recur; pyproject.toml adds .jeffy to ruff's extend-exclude; PLAN.md gains three Lessons.

Checkpoint: 5aaaddf6d0afbffc0c27abb4462950ee980dd2a7

Verification: the blast radius was bounded by command, not by memory - `git diff --stat <base> HEAD` over natsort/, tests/, dev/, docs/, pyproject.toml, tox.ini, CHANGELOG.md and README.rst named exactly four files, three of them this run's intended work and natsort/unicode_numeric_hex.py the one unintended change, and `git diff --stat <base> 6df4d249` over that path was empty, which places the damage in iteration 4 alone. After the restore, `ruff format --check` reports 45 files already formatted and `ruff check` reports 38 errors in the same three rule families it reported at iteration 2 - CPY001, RUF036, PLR0917 - which is NS-11's ruff-version drift and not this diff. `mypy --strict natsort tests` succeeds on 32 source files. Every battery whose paths file matches the diff was re-run through run-probe.sh and passes: utils-regex, unicode-numbers and dev-scripts for the source file and the probe, packaging and version-module for pyproject.toml. `check-claims.sh .` reports `claims: 96 checked, 0 mismatched, 0 errored, 0 skipped`. NS-D1's Declined derivation was re-run against the restored table and still returns 0. Verify gate: `verify: green (3s, oracle=..., 378 passed, 1 warning in 3.25s)`.

The fix is to the class rather than the instance. Every generator invocation in that battery now goes through one helper that resolves its working directory and exits if it equals the project root, is inside it, or contains it; the mutation that caused the damage now points at a sandbox that merely looks like a project root, so it still reddens the two checks it is there to discriminate while being unable to touch the real tree. The second half of the class is the lint gate: .jeffy is committed, and tox's lint environment and the ruff GitHub action both walk the whole tree, so twenty-two probe files were being graded as project source and contributed 439 of 477 ruff findings and 22 of 22 unformatted files. .jeffy now sits in extend-exclude beside build, dist, docs and mypy_stubs, which is the same category of entry: tooling state, not shipped source.

Learnings: the Verify command is a behaviour oracle and nothing else, so a change that only breaks formatting, typing or lint passes it silently - the Environment fingerprint says as much, and this iteration is what that sentence was warning about. Run ruff and mypy before every checkpoint rather than only when the diff looks relevant. And an instrument that executes project tooling is itself a way to write to the project: bound its working directory explicitly instead of assuming a mutation is read-only.

Next: NS-2, the console script's missing error handlers, is the top open item.

## iter 6/10 | efdb1582-222823 | 2026-09-01 | NS-2 | done

Task: NS-2 (Medium, runtime, error handling) - the installed `natsort` console script printed a full traceback where `python -m natsort` printed one line, because the ValueError and KeyboardInterrupt handlers lived inside the `if __name__ == "__main__"` block and `[project.scripts]` pointed straight at `main`. Added `cli(*arguments)` to natsort/__main__.py, which wraps `main` in those two handlers, repointed the entry point at it, and reduced the `__main__` block to a call to the same function so both ways of starting the tool go through one place. Closed and deleted from BACKLOG.md.

Changed: natsort/__main__.py (new `cli`, the duplicated handler block removed), pyproject.toml (entry point `natsort.__main__:cli`), tests/test_main.py (four tests), CHANGELOG.md, PLAN.md (Verify count 378 to 382), BACKLOG.md (NS-2 deleted), and two batteries updated for the behaviour they pin.

Checkpoint: bc042946957c7e6f92652bff9f13a447f753082f

Verification: the filed reproduction ran first - `.venv/bin/natsort -f 10 5 a1 2>&1 | grep -c Traceback` returned 1 before the fix and 0 after, and the command now prints `Error in --filter: low >= high` and exits 1 through both entry points. The four new tests were run against unfixed code by restoring natsort/__main__.py from HEAD: pytest exited 2 with `ImportError: cannot import name 'cli' from 'natsort.__main__'`, and 4 passed once the fix was restored. `ruff format --check` exits 0, `ruff check` reports the same three rule families as at iteration 2 - CPY001, RUF036, PLR0917 - and `mypy --strict natsort tests` succeeds on 32 source files. `check-claims.sh .` reports `claims: 97 checked, 0 mismatched, 0 errored, 0 skipped`. Verify gate: `verify: green (4s, oracle=..., 382 passed, 1 warning in 3.28s)`.

Contract preserved: `main` is unchanged and still raises, which is what keeps it callable as a function - tests/test_main.py calls it directly in two places and a new test pins that it still raises rather than exiting, so the separation is asserted rather than assumed. The new behaviour is confined to the console-script path, which previously had no handler at all.

Battery ownership worked as designed here. Four batteries declare the touched paths; running them found `packaging` at 46 of 47, failing on the check that pinned the entry point as `natsort.__main__:main`. That is the battery catching its own contract change rather than a defect, so it was updated in this iteration to pin the new target, and its claims were re-measured. `cli-filters` gained end-to-end coverage of the installed console script - no traceback, one line on stderr, non-zero exit, no entries on stdout, and both entry points reporting the same string - with a new mutation, console-script-bypasses-cli, that models the pre-fix wiring and reddens those checks. `cli-main`'s README no longer says the traceback behaviour is unpinned, because it now is, in the sibling battery that owns the same source file.

Learnings: repointing a console script in pyproject.toml does not change an already-installed wrapper, so `.venv/bin/natsort` keeps calling the old target until the package is reinstalled; run `pip install -e .` in the same iteration or the acceptance check measures the previous build. A test that imports a name the fix introduces discriminates by collection error rather than by assertion failure - that is a real failure against unfixed code and worth recording as such, but it says nothing about the assertion itself, so pin the behaviour separately where it can fail on its own.

Next: NS-3, the CLI emitting a blank line for empty stdin, is the top open item.

## iter 7/10 | efdb1582-222823 | 2026-09-01 | NS-3 | done

Task: NS-3 (Medium, runtime, correctness) - with no entries on the command line, get_entries read stdin, stripped the trailing separators and split the result, and splitting an empty string yields one empty entry, so `printf '' | natsort` printed a blank line where `sort` prints nothing and anything reading the output next received a phantom element. get_entries now returns no entries when the stripped stream is empty, in both the newline and the NUL separator mode. Closed and deleted from BACKLOG.md.

Changed: natsort/__main__.py (get_entries), tests/test_main.py (the existing empty-stdin test updated and a separators-only test added), CHANGELOG.md, PLAN.md (Verify count 382 to 386), BACKLOG.md (NS-3 deleted), .jeffy/probes/cli-main (end-to-end coverage, a new mutation, README).

Checkpoint: a81f7e41be13f1f59918679636110c57990efe8b

Verification: the filed reproduction ran first - `printf '' | python -m natsort | wc -c` returned 1 in both separator modes before the fix and 0 after, and the installed console script agrees. The updated tests were run against unfixed code by restoring natsort/__main__.py from HEAD: 6 failed with `AssertionError: assert [''] == []`, and 6 passed once the fix was restored. `ruff format --check` exits 0, `ruff check` reports the same three rule families as at iteration 2, and `mypy --strict natsort tests` succeeds on 32 source files. Both batteries declaring natsort/__main__.py were re-run through run-probe.sh and pass. `check-claims.sh .` reports `claims: 98 checked, 0 mismatched, 0 errored, 0 skipped`. Verify gate: `verify: green (4s, oracle=..., 386 passed, 1 warning in 3.29s)`.

A maintainer's test was changed, so the reasoning is on the record. tests/test_main.py carried test_get_entries_with_empty_stdin asserting `entries == [""]` with the docstring "Test that empty stdin yields a single empty entry". `git log -S` places it in commit 5a0fbb3, the same commit that introduced the rstrip, and that commit's own message states the separators are removed "so they do not produce empty entries" - which empty input contradicts, because it produces exactly one. The test therefore characterises an oversight in that change rather than asserting an intended contract, so it was updated rather than deleted, and its docstring now says what the code does.

Contract preserved elsewhere: the rstrip of trailing separators is deliberate and was left exactly as it was, so `printf 'a\n\n\n'` still yields one entry; a blank line between two entries still survives as an empty entry, which the battery now pins. Only the wholly-empty case changed, which is what the finding named.

Learnings: when a test pins the behaviour a finding calls a defect, check `git log -S` for the commit that introduced it before touching it - here the commit message stated the opposite of what its own test asserted, which settled the question in one command and belongs in the journal rather than in a judgement call.

Next: NS-4, the os_sorted str-coercion promise the POSIX fallback does not keep, is the top open item.

## iter 8/10 | efdb1582-222823 | 2026-09-01 | NS-4 | done

Task: NS-4 (Medium, runtime, documentation) - os_sorted and os_sort_keygen both document that every input is coerced to str before collating, and the Windows and PyICU branches did so through _split_apply, but the PyICU-absent POSIX branch returned natsort_keygen unwrapped and coerced nothing. The same non-string input therefore sorted one way on a host with PyICU and another way without it: os_sorted([None, "a"]) returned [None, "a"] while os_sorted(["None", "a"]) returned ["a", "None"]. All three branches now share one coercion step. Closed and deleted from BACKLOG.md.

Changed: natsort/natsort.py (new _coerce_to_path_like, used by both _split_apply and the POSIX branch of os_sort_keygen; os_sort_keygen's Notes no longer says the coercion is Windows-only), tests/test_os_sorted.py (nine tests), CHANGELOG.md, PLAN.md (Verify count 386 to 395), BACKLOG.md (NS-4 deleted), .jeffy/probes/api-os-sorted (coercion checks, a new mutation, README).

Checkpoint: dcf2a2cd22b1be662b5646452cf288ed330bb195

Verification: the filed acceptance ran first and failed - `python -c "from natsort import os_sort_keygen; k=os_sort_keygen(); assert k(None)==k('None'); assert k(1.5)==k('1.5')"` exited 1 on an AssertionError before the fix and exits 0 after. The nine new tests were run against unfixed code by restoring natsort/natsort.py from HEAD: 7 failed, the first with `AssertionError: assert [None, 'a'] == ['a', None]`, and 9 passed once the fix was restored - the two that passed either way are the ones that only assert agreement between two calls of the fixed keygen. `ruff format --check` exits 0, `ruff check` reports the same three rule families as at iteration 2, `mypy --strict natsort tests` succeeds on 32 source files. All six batteries declaring natsort/natsort.py were re-run through run-probe.sh and pass. `check-claims.sh .` reports `claims: 99 checked, 0 mismatched, 0 errored, 0 skipped`. Verify gate: `verify: green (4s, oracle=..., 395 passed, 1 warning in 3.31s)`.

Public behaviour changed, so the rationale is on the record per the Constraints. os_sorted now orders a non-string as its str form on every platform rather than only on Windows and under PyICU. Nothing changes for str or PurePath input, which is what the Parameters section says the function takes, and the existing test_os_sorted_misc_no_fail, which feeds it 9, 4.3, None and a NaN, still passes. The alternative was to narrow the documentation instead, which the finding's own acceptance check ruled out and which would have left the same input sorting differently on two hosts - the docs were right and the code was wrong, not the other way round.

Fixed as a class rather than an instance: the coercion rule now exists once, in _coerce_to_path_like, and the three branches reach it either directly or through _split_apply, so a fourth branch cannot quietly disagree. The enumeration of those branches is the shape `grep -n "def os_sort_keygen" natsort/natsort.py` returns - three definitions, one per platform and PyICU condition - and each was read; the Windows branch reaches the helper through _split_apply, the PyICU branch likewise, and the POSIX branch now calls it directly.

Learnings: ruff's ANN401 forbids `typing.Any` in a test parameter annotation even where the values really are heterogeneous; annotate such a parameter `object` instead, which mypy --strict also accepts. And `from __future__ import annotations` makes an unimported name in an annotation invisible at runtime, so a missing import passes the suite and fails only the type checker - another reason the pre-checkpoint ruff and mypy runs are not optional.

Next: NS-5, the sdist carrying the loop's state files, is the last open Medium.

## iter 9/10 | efdb1582-222823 | 2026-09-01 | NS-5 | done

Task: NS-5 (Medium, build-ci, dependency hygiene) - the project has no MANIFEST.in, and setuptools-scm's file finder puts every git-tracked file into the sdist, so once a checkpoint committed them the loop's own PLAN.md, BACKLOG.md, JOURNAL.md and the whole .jeffy directory shipped inside the published source distribution. Consequence: a user installing natsort from the PyPI sdist, or running pip download --no-binary, received this loop's state files as part of the package. Added a MANIFEST.in that excludes the four ledger files and prunes .jeffy. Closed and deleted from BACKLOG.md - the ledger now holds no open High or Medium.

Changed: MANIFEST.in (new), CHANGELOG.md, BACKLOG.md (NS-5 deleted), PLAN.md (one Lesson), .jeffy/probes/packaging (the observation became an assertion, the mutation wiring was rewritten, paths and README updated).

Checkpoint: 8665f6fb6cb387a0b91367e6cc04093256427382

Verification: the filed reproduction ran first - `tar tzf` over a freshly built sdist matched 119 loop-state paths before the fix and 0 after, and the acceptance check as written in the ledger now exits 0. Pruning an sdist can quietly remove something the build needs, so that was checked rather than assumed: the new sdist was extracted and a wheel built from it, and that wheel carries every shipped module, the typing marker and no loop state, while the sdist's own tests directory holds the same number of files as the working tree's. `ruff format --check` exits 0, `ruff check` reports the same three rule families as at iteration 2, `mypy --strict natsort tests` succeeds on 32 source files. Both batteries declaring the touched paths were re-run through run-probe.sh and pass. `check-claims.sh .` reports `claims: 100 checked, 0 mismatched, 0 errored, 0 skipped`. Verify gate: `verify: green (3s, oracle=..., 395 passed, 1 warning in 3.18s)`.

The packaging battery no longer merely observes. It had printed the sdist's loop-state entry count as a note, because the outcome belonged to this finding; it now asserts the count is zero, asserts MANIFEST.in is itself shipped, and reads the four directives back out of the file, so the pruning cannot be silently reverted. Its paths file gained MANIFEST.in, which is what makes a future edit to that file re-run this battery.

A mutation was found not to discriminate, which is the second time this run. The new sdist-carries-loop-state branch was inserted against an anchor that did not match - the surrounding chain had been rewritten in an earlier iteration from elif to a fresh if - so the branch was never added and the mutation reported MUTATION REDDENS 0. The whole wiring block was rewritten as one chain and every mutation re-run; all four now redden. The check that caught it was reading the count rather than the exit status.

Learnings: after editing a probe's mutation wiring, re-run every mutation and read its reddened count, because a branch whose anchor failed to match is added silently and reads like a working discriminator. And when pruning a published artifact, rebuild from the pruned artifact rather than inspecting its file list - a list can look complete while the build it feeds is not.

Next: the ledger is at the severity floor with six Lows open and no High or Medium, the map is swept at twenty-two of twenty-two rows, and no full audit this run has scored clean, so iteration 10 spends itself on the closing full audit rather than on a WRAPUP.

## iter 10/10 | efdb1582-222823 | 2026-09-01 | AUDIT | audit

Task: The closing full audit. The ledger was at the severity floor with six Lows and no High or Medium, the map was swept at twenty-two of twenty-two rows, and no full audit this run had scored clean, so this final iteration went to the audit rather than to a WRAPUP - the closing extension can hold the gate and the declaration but never an audit, so a WRAPUP here would have handed the window a sequence it could not legally complete. This audit files nothing. Closeout has begun.

Changed: JOURNAL.md, and PLAN.md re-recording all twenty-two Surface inventory rows at this iteration's checkpoint, because every battery was re-executed here.

Checkpoint: ee72b4fe617c182d5bb4bf0a684a0a83cc10b543

Verification: fresh evidence, not a re-reading. All twenty-two batteries were re-executed through the installed run-probe.sh and every one is green; their per-battery totals are the values in their claims files and `check-claims.sh .` reports `claims: 100 checked, 0 mismatched, 0 errored, 0 skipped`. NS-D1's Declined derivation was re-run and still returns 0. The Settled classes section holds no line, so there is no enumeration to re-run. The Environment fingerprint was re-derived rather than re-read: the skip-marker enumeration still returns only the three locale fixtures in tests/conftest.py, `import icu` still fails, /usr/include/unicode/uvernum.h is still absent, the toolchain is still CPython 3.14.4 with pytest 9.1.1, hypothesis 6.167.1 and fastnumbers 5.2.0, and tests/profile_natsorted.py still breaks a --doctest-modules collection, so the --ignore in the Verify command is still needed. The Oracle class still describes what the command grades. Verify gate: `verify: green (4s, oracle=..., 395 passed, 1 warning in 3.32s)`, and the Verify count cell reads 395, the figure the wrapper reported. `ruff format --check` exits 0, `ruff check` reports the same three rule families it reported at iteration 2, `mypy --strict natsort tests` succeeds on 32 source files.

Two further instruments were run because a clean score should not rest only on instruments this run wrote. Every test module was executed in isolation and all pass, so nothing in the suite depends on state a sibling module leaks; the two locale-touching modules were also run in both orders against a locale-free one with the same result. And the whole public API was compared differentially against the commit that preceded this run: fifty comparison keys covering fourteen algorithm combinations - sorted output, generated keys, indices, bytes input, nested input, numeric input and the regex strings - of which exactly two differ, both of them the os_sorted non-string cases the NS-4 fix names. That includes one case NS-4's entry did not spell out: os_sorted over bytes now orders naturally rather than ordinally, because bytes are not path-like and so become their str form, which is precisely what the Windows and PyICU branches already did and what both docstrings promise.

Scores. All twenty-two inventory rows are swept, so these claim the whole mapped public surface rather than a sampled part of it.
- correctness: None. Every battery green on fresh execution, and the differential above isolates this run's only behavioural change to the one finding that intended it.
- security: None. The shipped package opens no socket, spawns no subprocess and deserializes nothing; the number regexes are flat alternations with fixed-width lookbehinds, so no catastrophic backtracking path exists to find.
- error handling: None in-envelope above Low. Both CLI entry points now answer bad input with one line and a non-zero exit; NS-6 and NS-7 remain open Lows.
- documentation: None. The os_sorted and os_sort_keygen docstrings now match the code on every platform, docs/api.rst renders them by autofunction so it cannot drift, and the README doctests execute as part of the gate.
- dependency hygiene: None. Both optional dependencies are version-gated at import, and the sdist and wheel were built and read this iteration and carry only what they should.
- testing: Low - NS-9 and NS-10. The suite passes whole and every module passes alone.
- developer experience: Low - NS-8 and NS-11.
- architecture, code quality, performance: None on the swept surface.
- observability: not applicable, and recorded as such - a sorting library and a stdout filter have no logging or metrics surface.
- UX and accessibility: the CLI is the only user-facing surface and is scored under correctness and error handling above; accessibility does not apply to a stdout filter.

The six open Lows were re-scored against the rubric rather than carried on their original labels. NS-6 is a confusing exception type where the call fails either way, so no user gets a wrong result or an unexpected success. NS-7 is unreachable with any released fastnumbers version, all of which carry three components, and the Operating envelope classes that surface machine-generated. NS-8 is dev-tooling and NS-9 is test, both of which the severity ceiling by class fixes at Low because a user of the shipped product never runs them. NS-10 and NS-11 are build-ci: a gate step that grades nothing and a lint configuration that a newer ruff turns red, neither of which a user meets. None of the six hides something a user meets.

Stall check: this iteration changed no file outside PLAN.md, JOURNAL.md and .jeffy, no BACKLOG.md item changed state, and no inventory row flipped between swept and unswept - only the commit each row records was refreshed. That is a stall by the definition and is recorded as one; it is also a ceremony entry, an AUDIT that files nothing, which never forms the blocking pair.

Learnings: a closing audit that only re-runs the instruments the same run wrote is grading its own homework. Two independent checks are cheap and worth making routine - every test module in isolation, which no battery covers because batteries do not import the suite, and a differential of the whole public API against the commit the run started from, which turns "the fixes did what they said and nothing else" from an assertion into a measurement.

Next: the closing conditions all hold except the adversarial evaluator gate, which this budget has no iteration left for. The closing extension can legally carry the gate and the declaration because the clean audit predates the window.

## iter 11/12 | efdb1582-222823 | 2026-09-01 | EVALUATOR | converged

Task: The evaluator gate and, on its PASS, the declaration. This is the closing extension, which admits only the gate, gate-filed fixes and the declaration; no audit was run here, and the clean full audit the declaration cites is iteration 10's, which predates the window.

Changed: .jeffy/evaluator/efdb1582-222823-1.md (the gate's artifact), JOURNAL.md, and BACKLOG.md gains its Converged line in the bookkeeping edit below.

Checkpoint: 2021d3af9a7ffdf87f61ec51580c2b5b9edd60e5

Verification: Evaluator: PASS - invocation 1 of this run, spawned fresh-context, reproduced all five closed findings on the base commit and confirmed each fixed at HEAD, re-ran every acceptance as filed, re-scored the six carried Lows as accurate, and recorded 57 commands with their real exit statuses in .jeffy/evaluator/efdb1582-222823-1.md. Standing claims were brought current in this same iteration before the invocation: no Surface inventory row is stale (only JOURNAL.md and PLAN.md changed after the sweep commit ee72b4f), NS-D1's Declined derivation still returns 0, the Settled classes section holds no line so there is no enumeration to re-run, `check-claims.sh .` reports `claims: 100 checked, 0 mismatched, 0 errored, 0 skipped`, PLAN.md names no finding ID as carried or blocked, and the Oracle class and Environment fingerprint were re-read and re-derived. Verify gate this iteration: `verify: green (4s, oracle=..., 395 passed, 1 warning in 3.32s)`, and the Verify count cell reads 395, the figure the wrapper reported.

Carried Lows, each open with its severity on its own line, none of which blocks a declaration:
- NS-6 (Low, runtime, error handling): only natsort_keygen validates its alg argument, so the six wrapper functions raise a raw TypeError instead of the intended ValueError. The call fails either way; no caller gets a wrong result or an unexpected success.
- NS-7 (Low, runtime, error handling): is_supported_fastnumbers calls int() on an optional regex group, so a two-component version string raises TypeError. Unreachable with any released fastnumbers version, all of which carry three components, on a surface the Operating envelope classes machine-generated.
- NS-8 (Low, dev-tooling, developer experience): dev/generate_new_unicode_numbers.py emits a header the project's own ruff configuration rejects. Class dev-tooling, which a user of the shipped product never runs.
- NS-9 (Low, test, testing): tests/profile_natsorted.py profiles at import and raises NameError, so a --doctest-modules collection over tests needs an --ignore. Class test.
- NS-10 (Low, build-ci, testing): two of tox's four gate steps point at rst files that were moved to the wiki and now hold no doctests, so those steps grade nothing.
- NS-11 (Low, build-ci, developer experience): pyproject.toml sets ruff select = ALL against an unpinned ruff, so a ruff release that adds a rule can turn the Code Quality job red with no source change.

Gate observations, none of them a REJECT reason and none fixed here, because a fix after a PASS invalidates that PASS: NS-11's own line names an ANN401 hit that no longer occurs, the run's noqa having removed it, so its prose is stale on an open Low; the CLI's -z splits input on NUL but still writes newline-separated output, which is pre-existing, outside this run's changes, and not promised otherwise by the flag's help text; NS-5's defect existed only because the loop's checkpoints tracked its own state files, so the Medium sat on an artifact the loop itself contaminated even though the fix is real and general; and os_sorted over bytes now collates the repr form on POSIX as it already did on Windows and under PyICU, which is the documented behaviour but has no CHANGELOG line. These belong to the next run's ledger and are repeated in the run report.

Closing conditions, each checked rather than assumed: the full fresh-evidence audit at iteration 10 scored zero High and zero Medium in-envelope; the Surface inventory lists twenty-two rows and no unswept one; Now, Next and Later hold no open High or Medium; the only commit between that audit and this declaration is iteration 10's bookkeeping, which touched JOURNAL.md and PLAN.md alone; the Verify command is green this iteration; the evaluator returned PASS in this same iteration; and the Converged line is appended below with the hash rev-parse returned for this iteration's checkpoint.

Learnings: run the gate in the first iteration of the closing window rather than the second. A PASS does not carry forward, so a gate run at the last iteration would have to re-invoke itself to declare, and with the cap at two invocations past the budget midpoint that leaves no invocation for a REJECT to answer.

Next: nothing. The run is converged.
