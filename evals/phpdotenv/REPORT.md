# Jeffy eval: phpdotenv (PHP)

`vlucas/phpdotenv` - the `.env` loader in a vast share of PHP dependency
trees - run in the 2026-08-25 diverse-language wave on engine 1.16.0, the
corpus's second PHP target after PHP-Parser. **1 run, 10 iterations,
converged**
at `79798ecd0097c55ee1f2632d14e90d6fb0b73888`, in round 1 of a
**pre-registered budget of 3 rounds of 10** - the spare rounds were
never needed. Never pooled with this corpus's converged Go `godotenv`:
different project, different language, both receipts say so.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `301c07936b16d88628b126b01d082ba153cf4c40` |
| Findings closed | **6** - 2 High, 3 Medium, 1 Low |
| Shipped-code change | 8 files, **+248 / -12** |
| Surface inventory | **18 of 18 rows swept** |
| Ledger at convergence | **3 Lows carried** with acceptance lines |
| Evaluator | **2 invocations: REJECT, then PASS** |

## What the loop found

- **`P1` (High)** - an unterminated multiline value made
  `Dotenv::parse("FOO=\"bar\nAPP_ENV=prod")` return `[]` - the parser
  buffered everything after the unclosed quote and then silently
  discarded it, where the single-quoted sibling correctly raises
  `InvalidFileException`.
- **`P8` (High)** - the same silent-loss class by a second route,
  surfaced by the evaluator's REJECT: the multiline stop test could not
  see a closing `"` at offset 0 of its line, so a value whose closing
  line carried a trailing comment swallowed every following variable
  (`FOO="one\n" # done\nBAR=baz` returned only FOO).
- **`P2` (Medium)** - the composer dist archive shipped whatever the
  tree carries: `.gitattributes` had no `export-ignore` for the loop's
  own state files. The **fifth distinct packaging channel** this
  engine's artifact-channel class has caught, after crates.io, npm, Go
  module zips and bower.
- The other Mediums: `P5`, an `="` inside an ordinary value read as the
  opening of a multiline one, and `P3`, `ReplacingWriter` - public API
  that UPGRADING.md names as the supported pre-5.0 migration path - with
  no test anywhere referencing it. The suite grew from 280 to 299 tests
  (580 to 615 assertions) across the run.

## The gate

Invocation 1 REJECTed with three reasons and reproduced each before
filing - the High above, its whitespace sibling (one root cause, one
fix), and a false mutation count in the run's own probe battery README,
refiled at Low and corrected with measured numbers. Invocation 2
PASSed on independent evidence: a parity reference agreeing with the
fixed line-classifier on 19,046 lines with zero mismatches while
disagreeing with the old one on 1,608, and differentials over 1,819
structured inputs plus 29,497 fuzzed files showing zero changed values.

## Declared limits

- Graded on PHP 8.5.4 / composer 2.9.5, linux under WSL2, run headless
  as a systemd user unit by `claude -p` on **claude-opus-5 (1M
  context)**, engine **1.16.0**.
- No network and no advisory database in the run environment: an
  unpatched published dependency vulnerability is not something this
  run ruled out, and its own journal says so.

## Nothing was sent upstream

Every finding rests on tests this loop wrote; no existing test was
deleted, disabled or weakened. Whether the multiline fixes go upstream
is a separate decision, made one finding at a time.
