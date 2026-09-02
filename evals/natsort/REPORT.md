# Jeffy eval: SethMMorton/natsort

The natural-sort library for Python - `natsorted` and its key
generators, the locale and PyICU collation paths, `os_sorted` for
filesystem order, and the `natsort` command-line filter. Run 2026-09-01
as wave 10 of the campaign (COHORT-WAVE9.md, which covers waves 9 and
10). **1 run, 11 iterations, converged** in round 1 at
`2021d3af9a7ffdf87f61ec51580c2b5b9edd60e5`, within a **pre-registered
budget of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `e90771d7c39157d079425b655763938c2709d486` |
| Findings closed | **5** - 1 High, 4 Medium (plus 1 regression this run introduced and repaired) |
| Shipped-code change | 10 files, **+219 / -16** |
| Surface inventory | **22 of 22 rows swept** |
| Ledger at convergence | 6 Lows carried |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | green through the verify gate at 395 passed, 22 batteries, 100 claims checked with 0 mismatched |

## What the loop found

- **`NS-1` (High)** - the PyICU sentinel `null_string_locale_max` in
  `natsort/compat/locale.py` held `b"x7f" * 50`, the three ASCII
  characters x, 7, f, rather than the maximum byte its own comment
  claims. `ns.NUMAFTER | ns.LOCALE` prepends that sentinel to every
  number, so **on a machine with PyICU any string whose collation key
  begins above byte 0x78 sorted after the numbers instead of before
  them, inverting the one thing NUMAFTER exists to do.** Fixed to
  `b"\xff" * 50`. PyICU cannot be built on this host, so the branch was
  reproduced by loading the module through
  `importlib.util.spec_from_file_location` with a stub `icu` in
  `sys.modules`; the new test fails on the old constant and passes on
  the new one.
- **`NS-2` (Medium)** - the ValueError and KeyboardInterrupt handlers
  lived inside the `if __name__ == "__main__"` block while
  `[project.scripts]` pointed straight at `main`, so **the installed
  `natsort` console script printed a full traceback where `python -m
  natsort` printed one line.** A new `cli(*arguments)` wraps `main` in
  both handlers and both entry points now route through it.
  `natsort -f 10 5 a1` matched `Traceback` once before the fix and zero
  times after, and now prints `Error in --filter: low >= high` and
  exits 1 from either entry point.
- **`NS-3` (Medium)** - `get_entries` read stdin, stripped trailing
  separators and split the result, and splitting an empty string yields
  one empty entry, so **`printf '' | natsort` printed a blank line
  where `sort` prints nothing and anything reading the output next
  received a phantom element.** Empty input now yields no entries in
  both the newline and the NUL separator mode; `printf '' | python -m
  natsort | wc -c` returned 1 before the fix and 0 after. A
  maintainer's test asserting `entries == [""]` was updated, on the
  evidence of `git log -S`: the commit that introduced it also
  introduced the rstrip and its message states the separators are
  removed so they do not produce empty entries.
- **`NS-4` (Medium)** - `os_sorted` and `os_sort_keygen` both document
  that every input is coerced to `str` before collating, and the
  Windows and PyICU branches did so, but the PyICU-absent POSIX branch
  returned `natsort_keygen` unwrapped and coerced nothing, so **the
  same non-string input sorted one way on a host with PyICU and another
  way without it**: `os_sorted([None, "a"])` returned `[None, "a"]`
  while `os_sorted(["None", "a"])` returned `["a", "None"]`. The
  coercion now exists once, in `_coerce_to_path_like`, which all three
  branches reach, so a fourth branch cannot quietly disagree.
- **`NS-5` (Medium)** - the project has no `MANIFEST.in` and
  setuptools-scm's file finder puts every git-tracked file into the
  sdist, so **a user installing natsort from the PyPI sdist, or running
  `pip download --no-binary`, received the loop's own ledger files as
  part of the package.** A freshly built sdist matched 119 loop-state
  paths before the fix and 0 after. The pruned sdist was extracted and
  a wheel built from it to prove the prune removed nothing the build
  needs.
- **`NS-REGRESSION`** - repaired ahead of the ledger. The dev-scripts
  battery ran `dev/generate_new_unicode_numbers.py` with its working
  directory set to the real project root, and that script writes
  `natsort/unicode_numeric_hex.py` relative to its cwd, so **the probe
  overwrote shipped source and a checkpoint committed it.** The file was
  restored byte for byte against the base commit, every generator
  invocation in that battery now goes through one helper that refuses a
  working directory equal to, inside, or containing the project root,
  and `.jeffy` was added to ruff's `extend-exclude` so probe files stop
  being graded as project source.

## Evaluator

One invocation, PASS. The gate was spawned fresh-context and
reproduced all five closed findings on the base commit, confirmed each
fixed at HEAD, re-ran every acceptance check as filed, re-scored the
six carried Lows as accurate, and recorded 57 commands with their real
exit statuses. Standing claims were brought current before the
invocation: no Surface inventory row stale, `check-claims.sh` at 100
checked and 0 mismatched, and the Oracle class and Environment
fingerprint re-derived rather than re-read.

## Upstream

`NS-1` was filed as
[PR #196](https://github.com/SethMMorton/natsort/pull/196). The change
is one line, `b"x7f" * 50` to `b"\xff" * 50`, with a test that loads
the module under a stub `icu` module and fails on the old constant.
Verified on a fresh clone at upstream HEAD `e90771d` against the
project's tox targets: pytest 355 passed, `ruff format` clean, `ruff
check` with no new findings, `mypy --strict` unchanged. PyICU could not
be built on the host, so the PyICU path was exercised only through the
stub, which the PR body states. CI on the PR is green. The PR is open.

The four Mediums were not filed. The bar for an upstream PR is a
genuine High.
