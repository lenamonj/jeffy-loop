# Jeffy eval: un33k/python-slugify

The slug generator half of Python's CMS ecosystem depends on. Run
2026-09-01 as wave 7 of the campaign: **the controlled engine test**,
re-running previously failed targets unchanged on engine 1.20.0
(COHORT-WAVE7.md). The first attempt (2026-08-27, engine 1.19.1) is the
campaign's sharpest engine-failure record: it ended with a clean
product, a met severity floor, a suite green at 94 and an evaluator
PASS - and the Stop hook refused the declaration twice on the loop's
own record-keeping (P1-68), a check engine 1.20.0 removed from the
declaration path (P1-69). The pre-registered prediction was
"converges, high confidence." The attempt-1 record is preserved
unchanged at `journal-attempt1-2026-08-27.md` and
`fixes-attempt1-2026-08-27.patch`.

**This attempt: 2 runs, 18 iterations, converged** in run 2 at
`35024b59a2fe842dda50a763636a06fa3c34985d` - same repository, same
pinned base (v8.0.4), same standard budget of 5 rounds of 10.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `f85f9488520148d5f6899b5639199882b605e30a` (v8.0.4, unchanged from attempt 1) |
| Findings closed | **12** - 2 High, 5 Medium, 5 Low |
| Shipped-code change | 11 files, **+175 / -33** |
| Surface inventory | **8 of 8 rows swept** |
| Ledger at convergence | 2 Lows carried |
| Evaluator | **2 invocations: PASS, PASS** |
| Suite at convergence | 95 tests green (82 at the pin) |

## What the loop found

- **`J1` (High)** - the CLI parsed `--regex-pattern` and silently
  discarded it: `slugify_params()` never forwarded the keyword, so the
  documented flag changed nothing. The suite could not see it because
  its own comparison helper checked only the keys the expectation
  named - a blindness closed separately as J9.
- **`J2` (High)** - a bare `try/except Exception: pass` wrapped the
  whole numeric-entity substitution, so one out-of-range reference
  (`&#99999999999;`) voided the decoding of every other reference in
  the string. The catch is now `ValueError` at the per-match site,
  chosen by provoking a failure at every step of both conversions and
  observing that all six provocations raise exactly that.
- **`J3` / `J4` (Medium)** - `replacements` rules were applied twice,
  compounding against their own output (`slugify('cat',
  replacements=[['a','ca']])` returned `cccat`); and the slug depended
  on which apostrophe the author typed, fixed by deriving the full set
  of codepoints that transliterate to an apostrophe and widening only
  the pre-process pass - the obvious fix would have broken the
  README's documented Cyrillic example.
- **`J11` (Medium)** - setuptools reuses a stale
  `egg-info/SOURCES.txt` forever, so an sdist built after narrowing
  MANIFEST.in still shipped the old file list. Two other plausible
  fixes were measured and rejected before the manifest fix was chosen.
- **`J12` (Medium)** - `max_length` documented as bounding the output
  while a multi-character separator exceeds it; found by the closing
  audit *after* the severity floor was met, filed at the cost of run
  1's own declaration.

## The engine-test result, and one refusal worth reading

Run 1's gate returned PASS - and the run still did not declare,
because its closing audit had filed J12 and the closing rule requires
the audit on record to be clean. That is the discipline attempt 1's
failure paid for, working as intended this time: nothing was declared
over a known Medium, and run 2 converged cleanly with a second PASS.
The prediction held. Attempt 1 found 13 findings and lost to
bookkeeping; attempt 2 on the fixed engine found 12 more on the same
pin and converged.
