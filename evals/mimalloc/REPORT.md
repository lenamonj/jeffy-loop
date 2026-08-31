# Jeffy eval: microsoft/mimalloc

Microsoft's general-purpose allocator, run 2026-08-30 as one of three
targets in wave 2 of the merged-PR campaign (COHORT-WAVE2.md), alongside
`CLI11` and `typer` - the target whose own readme credits three releases to
LLM audits, and the grindiest of the wave. **3 runs, 28 iterations,
converged** at `41ad01a66dbea484eb9ecd06ae978afdc2016275`, in round 3 of a
**pre-registered budget of 3 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `cd69707c3ca01a4c5fb358e8b92a710554f15356` (main3 HEAD; upstream CI 18 success on this exact commit) |
| Findings closed | **16** - 4 High, 7 Medium, 5 Low (a fifth High, H2, was re-scored to Medium mid-run with its derivation published; counted here as it closed) |
| Shipped-code change | 14 files, **+280 / -43** |
| Surface inventory | **26 of 26 rows swept** |
| Ledger at convergence | 4 Lows carried, named in the closing entry |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | 7 CTest tests green (~13 s) |

## What the loop found

- **`H1` (High)** - `mi_theap_zalloc_csize` delegated its large-size branch
  to the plain malloc path, so a **documented zeroing allocator returned
  uninitialized heap memory** for every size above the small-size
  threshold.
- **`H3` (High)** - `mi_stats_merge` and `mi_collect_reduce` were declared
  `mi_decl_export` in the public header but absent from the library: any
  program calling either fails to link.
- **`H4` (High)** - a weak `_ZSt15get_new_handlerv` definition in
  `src/alloc.c` preempted the standard library's for the whole program, so
  a C++ program statically linking mimalloc saw its own
  `std::get_new_handler()` return null.
- **`H5` (High)** - the generated `mimalloc.pc` pointed `includedir` at
  `${prefix}/include` while the default install layout puts headers in
  `${prefix}/include/mimalloc-<version>/`, so `pkg-config --cflags` built
  nothing.
- **`H2 -> M4`, published re-score** - the `u`-API block-size out-parameter
  reports more bytes than are usable at the returned pointer. Filed High as
  a heap-overflow-in-waiting; investigation showed no configuration
  implements the premised contract (with `MI_PADDING` every entry point
  reports more than `mi_usable_size`), so the run withdrew the High with
  its derivation and closed the survivor as a documentation Medium. The
  receipt keeps both halves visible because a re-score is a claim too.
- **`M1`/`M7` (Medium)** - an empty `MIMALLOC_*` environment value read as
  boolean 1, so `MIMALLOC_ARENA_RESERVE=` collapsed the arena reservation
  from a gigabyte to one KiB; the follow-up closed the same class for
  numeric options whose compiled default is 0 or 1.
- **`M3` (Medium)** - no `export-ignore` anywhere, so `git archive` shipped
  the loop's state into the source tarball - the ninth packaging channel
  caught in the corpus.
- **`M2`, `M5`, `M6` (Medium)** - enum comments stating defaults
  `mi_option_get` does not return (seven options); allocation stats whose
  `current` never fell on free; API documentation naming functions and
  options the library does not have.
- **`L1`-`L5` (Low)** - printf divergences in `_mi_vsnprintf`, a chunkmap
  bit left clear on ranges starting mid-chunk, a wrong fragmentation
  comment, and doc declarations rendered with no description.

## Run shape

Run 1 (9 iterations): audit, H1, the H2 investigation and re-score, H3,
H4. Run 2 (10): H5, the Medium ledger, and the sweep to 16 of 26. Run 3
(9): the last ten rows swept, M7 and the Low tail closed, the closing
audit, one gate invocation, PASS, declared. No run ended blocked.

## Environment

WSL2 x86_64, cmake + gcc, CTest. Engine 1.20.0 on Claude Code 2.1.232,
model `opus[1m]`. Oracle sabotage-proven before launch: `mi_malloc` forced
to return NULL reddened `test-api`, green restored on revert - after a
first sabotage attempt hit a wrapper the suite never calls, which is
recorded in COHORT-WAVE2.md and the backlog.

Full iteration record: [journal.md](journal.md). Complete shipped diff:
[fixes.patch](fixes.patch).
