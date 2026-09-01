# Jeffy eval: sqlfluff/sqlfluff

The dialect-flexible SQL linter and auto-formatter: 28 dialects, a rule
engine that rewrites files in place, a Jinja/dbt templating layer, and a
Rust parser extension behind a PyO3 bridge. Run 2026-08-31 as wave 5 of the
merged-PR campaign (COHORT-WAVE5.md). **4 runs, 35 iterations, converged**
in run 4 at `2d9093eeb45aaa94cc7c784419443667e318773f`, inside a
**pre-registered budget of 5 rounds of 10**.

Picked deliberately as the largest surface the loop has ever run - 51
inventory rows against the previous maximum of 29 - to buy depth rather
than a fast convergence. It cost what that predicts: 4 rounds and roughly
8 hours of wall clock, most of it sweeping the map before the deepest
findings surfaced.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `6d88cb1456a04b3888ad4bc2783a3214489522a0` (main; upstream CI at pin: 83 success + 4 skipped + 10 pending + 3 failures, all three failures Dependabot jobs, declared before launch) |
| Findings closed | **12** - 6 High, 5 Medium, 1 Low as first filed |
| Shipped-code change | 29 files, **+902 / -91** |
| Surface inventory | **51 of 51 rows swept** |
| Ledger at convergence | 4 Lows carried (SF-013, SF-005, SF-010, SF-012) |
| Evaluator | **2 invocations: REJECT, then PASS** |
| Suite at convergence | 13562 passed, 3 skipped, 2 xfailed (~171 s, venv pytest; up two from 13560 by the SF-018 boundary tests added in the closing window) |

## What the loop found

- **`SF-001` (High)** - the reflow engine
  (`src/sqlfluff/utils/reflow/respace.py` and neighbours) deleted the
  whitespace between two adjacent operator tokens without checking that the
  concatenation still lexes the same way. `sqlfluff fix` rewrote
  `SELECT 1 * - - 5;` to `SELECT 1 * --5;`, where `--` opens a comment and
  the rest of the statement is silently discarded; the postgres idiom
  `LIKE ~ ~ 5` collapsed to `~~` the same way.
- **`SF-006` (High)** - `sqlfluff.fix(sql, fix_even_unparsable=True)` in
  `src/sqlfluff/api/simple.py` raised a bare
  `AssertionError("Fixing a string requires successful templating.")` on
  any SQL that fails to parse - the only case the parameter exists for.
- **`SF-008` (High)** - `ST04`'s flattening of a single-line nested `CASE`
  deleted the spacing before the outer `END` without putting anything back,
  so `sqlfluff fix` exited 0 and left `... THEN 2END ...`, output the
  dialect cannot parse.
- **`SF-009` (High)** - a Jinja template whose rendering raises outside
  `(TemplateError, TypeError, ValueError)` escaped `JinjaTemplater.process`
  and crashed `sqlfluff lint` with a raw Python traceback;
  `{{ total / count }}` with a count rendering to zero is an ordinary dbt
  shape.
- **`SF-014` (High)** - the Rust parser's iteration-limit guard in
  `sqlfluffrs_parser/src/parser/table_driven/iterative.rs` called `panic!`,
  so a valid but very complex file crashed `sqlfluff lint` with
  `pyo3_runtime.PanicException` - which derives from `BaseException`, so an
  integrating caller's `except Exception` does not catch it either. The
  default CLI path is shielded by `large_file_skip_byte_limit`, but the
  skip warning sqlfluff prints tells the user to raise or zero exactly that
  limit. The sibling `max_parse_depth` guard ten lines above already
  returned an ordinary parse error; the fix makes the two match.
- **`SF-017` (High)** - `ST07` rewrote a DuckDB ASOF join's `USING` list
  into all-equality `ON` conditions, turning the join's inequality into an
  equality and changing which rows the query returns. Found only when the
  audit's corpus sweep widened from 219 to 421 fixtures.
- **`SF-002` (Medium)** - `sqlfluff fix` never reached a fixed point on a
  mysql fixture: LT05 wrapped a long `SELECT` line whose wrapped form was
  still over the limit, LT09 pulled it back up, and the pair alternated
  between two outputs forever. LT09 now reports but withholds the fix when
  the merge would exceed `max_line_length`.
- **`SF-003` (Medium)** - `ST07`'s `USING`-to-`ON` rewrite deleted an
  indent meta without its matching dedents, so one `fix` pass over a duckdb
  fixture reported success while leaving LT02 violations a second pass then
  fixed - every statement after the join was indented one level too
  shallow.
- **`SF-007` (Medium)** - a config mistake the placeholder templater
  catches reached the user as a raw Python traceback instead of the
  one-line error every other config mistake produces; closed as a class,
  which turned up a fourth instance in the Jinja templater's macro-path
  loading that a grep-shaped enumeration would have missed.
- **`SF-015` (Medium)** - `sqlfluff fix` reported fixable LT01 violations
  on flink and soql fixtures and changed nothing. The violations were
  spurious: flink parsed the hyphen in `execution.runtime-mode` as a binary
  operator and soql spaced the colon inside `LAST_N_WEEKS:5`, and the
  linter's unparsable-fix guard rightly refused the resulting rewrites.
- **`SF-016` (Medium)** - `FunctionNameSegment`'s grammar could not rematch
  the naked identifier RF06's own fix constructs, so `apply_fixes`'
  revalidation refused the unquoting fix and left the file byte-identical
  while `fix` still reported the violation as fixable.

## The evaluator gate

The gate ran twice. Its first invocation REJECTed on an off-by-one the run
itself had introduced: `LT09._merge_would_exceed_line_length`, added for
SF-002, counted the line's trailing newline, so a merge landing at exactly
`max_line_length` was refused as unfixable - input the previous release
handled, and a contradiction of the very docstring the fix added. Seven
regression tests, the 13560-case suite and a clean full audit had all
passed over it, because nothing pinned the boundary itself. The gate filed
it as SF-018 (Medium), the next iteration fixed it with a test on each side
of the boundary, and the second invocation independently re-ran the suite,
reproduced SF-018 at the pre-fix commit, drove 520 cases over eight shapes
against the fix, and returned PASS. The run converged only because a second
invocation remained; had the first REJECT landed one iteration later, the
declaration path would have ended there.

Run 4 ran 12 iterations: the 10 budgeted, plus the engine's closing
extension - a +2 window that admits only the evaluator gate and the
declaration, never product work or audits. The SF-018 fix inside that
window was legal because the gate itself filed it as the condition of a
re-invocation.

One scope note the journal is explicit about: the audit's fix-idempotency
corpus sweep - 421 fixtures, 16 per dialect across all 28 by a seeded
shuffle - is a claim about those 421 fixtures, not about the whole
2257-fixture corpus. Widening it from 219 is what found SF-017; a sample
that finds nothing is a statement about the sample.

## Environment

WSL2 x86_64, venv pytest. Engine 1.20.0 on Claude Code 2.1.232, model
`opus[1m]`. Oracle sabotage-proven before launch: neutering the rule crawl
reddened **1377 tests**, with revert restoring exactly the 4-test baseline.
Flake gate 10/10 with an identical failing-set md5 on every run; the 4
failing `diff_cover` tests are the declared-red baseline, recorded before
launch.

Full iteration record: [journal.md](journal.md). Complete shipped diff:
[fixes.patch](fixes.patch).
