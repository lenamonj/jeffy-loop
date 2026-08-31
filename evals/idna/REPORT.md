# Jeffy eval: kjd/idna

The IDNA 2008 implementation behind `requests`, `httpx` and most of
Python's networking stack. Run 2026-08-31 in wave 3 of the merged-PR
campaign (COHORT-WAVE3.md). **1 run, 10 iterations, converged** at
`65f620c04360129a3e5f34196a554e73c24dd4ad`, in round 1 of a
**pre-registered budget of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `e2073db14d28d1c3299649dd0c2dd4205b43ebfd` (master; upstream CI 22 success + 2 skipped on this exact commit) |
| Findings closed | **4** - 3 Medium, 1 Low |
| Shipped-code change | 6 files, **+78 / -6** |
| Surface inventory | **17 of 17 rows swept** |
| Ledger at convergence | 2 Lows carried |
| Evaluator | **2 invocations: REJECT, PASS** |
| Suite at convergence | 6,444 tests green (~5 s) |

## What the loop found

- **`F1` (Medium)** - `check_bidi("", check_ltr=True)` raised `IndexError`
  instead of the library's own `IDNAError`, so a caller catching the
  documented exception type still crashed. An empty label now returns True
  whichever way `check_ltr` is set, the docstring says so, and three
  harnesses pin it.
- **`F4` (Medium)** - `README.md` stated "capital letters are not allowed"
  and demonstrated `idna.encode` rejecting one, while an all-ASCII label
  carries its case straight through - and the `alabel` docstring called
  such labels "already valid IDNA labels" where `check_label` rejects them.
  Two documents disagreeing with the code and with each other.
- **`F2` (Medium)** - the `IDNAError` docstring told readers "the full list
  is documented in the README", and the README's Exceptions section names
  two codes as examples and carries no list. The false pointer was removed
  and replaced with where the codes actually are.
- **`F3` (Low)** - the README documented no `idna2008` codec, and
  `codecs.encode(s, "idna2008")` raises `LookupError` until `idna.codec` is
  imported, so a shipped and tested surface was undiscoverable from the
  documentation. Closed with a README section whose example is executed.

Nothing here reached the High bar, so nothing was filed upstream.

## Environment

WSL2, python3 venv. Engine 1.20.0 on Claude Code 2.1.232, model
`opus[1m]`. **Oracle note**: the suite cannot even collect without
`hypothesis` installed, so the venv carries it - a run staged without it
would have read the collection error as a red baseline. The sabotage proof
for this target was cut short when the wave was launched early; the flake
gate passed 10/10 with an empty failing-set signature across every run.

Full iteration record: [journal.md](journal.md). Complete shipped diff:
[fixes.patch](fixes.patch).
