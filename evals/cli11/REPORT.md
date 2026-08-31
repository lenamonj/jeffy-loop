# Jeffy eval: CLIUtils/CLI11

The header-only C++ command-line parser, run 2026-08-30 as one of three
targets in wave 2 of the merged-PR campaign (COHORT-WAVE2.md), alongside
`mimalloc` and `typer`. **1 run, 9 iterations, converged** at
`17d77aab6fe6e07fc0c7e6f120aa77a4d6ab2179`, in round 1 of a
**pre-registered budget of 3 rounds of 10** - the cheapest convergence in
the campaign so far.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `c1cfe00d2f3d862aecfe6e69ec810414d5f4c906` (main; upstream CI 77 success on this exact commit) |
| Findings closed | **3** - 3 Medium |
| Shipped-code change | 5 files, **+102 / -3** |
| Surface inventory | **23 of 23 rows swept** |
| Ledger at convergence | 4 Lows carried, named in the closing entry |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | 82 CTest tests green (~13 s) |

## What the loop found

- **`T1` (Medium)** - a `strtoX` result was accepted as a complete
  conversion at five sites where nothing was consumed, so an input the
  C library rejected outright could still be read as a value.
- **`T2` (Medium)** - the CPack source package uploaded as the
  `CLI11-Source` release artifact carried the loop's own state files - the
  eighth packaging channel caught in the corpus, and the second time the
  channel was a *release artifact* rather than a registry package.
- **`T3` (Medium)** - the published `CLI11-Source` release archive omitted
  `meson.build`, so the meson build the project documents could not be run
  from its own source release.

## Run shape

Iteration 1 audited breadth-first and filed the map plus T1/T2; iterations
2-4 swept all 23 surface rows (the queue holds the map above open Mediums);
5-7 closed T2, T3, T1 - the packaging pair first because the last unswept
row's battery was blocked on it; 8 was the closing full fresh-evidence
audit (required because iteration 1's audit had filed findings); 9 invoked
the gate, PASS, and declared.

## Environment

WSL2 x86_64, cmake + gcc, CTest. Engine 1.20.0 on Claude Code 2.1.232,
model `opus[1m]`. Oracle sabotage-proven before launch: an `_add_result`
miscount reddened 7 of 82 tests after a rebuild, green restored on revert
(and the first two instrument attempts that failed to redden are recorded
in COHORT-WAVE2.md).

Full iteration record: [journal.md](journal.md). Complete shipped diff:
[fixes.patch](fixes.patch).
