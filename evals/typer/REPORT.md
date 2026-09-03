# Jeffy eval: fastapi/typer

The CLI framework of the FastAPI family, run 2026-08-30 as one of three
targets in wave 2 of the merged-PR campaign (COHORT-WAVE2.md), alongside
`CLI11` and `mimalloc`. **1 run, 11 iterations, converged** at
`2030a66e2396bc82df722372864a203e05b19a29`, in round 1 of a
**pre-registered budget of 3 rounds of 10**, using the one-time closing
extension for the gate-and-declare sequence.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `99eb220df7c69a0f14a0b69214042677e0760b9d` (master, release 0.27.2; upstream CI 29 success + 2 declared reds, both the scheduled CPython-nightly canary) |
| Declared host baseline | 1 red test (`test_file_error`, OS error-text assert), stable 10/10 in the pre-launch probe |
| Findings closed | **3** - 2 High, 1 Medium |
| Shipped-code change | 13 files, **+157 / -73** |
| Surface inventory | **25 of 25 rows swept** |
| Ledger at convergence | 5 Lows carried, named in the closing entry |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | pytest 1372 passed + the 1 declared baseline red |
| Upstream | [#1946](https://github.com/fastapi/typer/pull/1946) (T2, `docs --output` encoding) closed 2026-08-31 as a duplicate of the open [#1881](https://github.com/fastapi/typer/pull/1881), which the pre-filing search missed; T1 held |

## What the loop found

- **`T1` (High)** - the `typer` command chose which app or function to run
  by iterating a **set** of module names, so the choice depended on the
  process hash seed: nondeterministic across invocations, and not the
  priority order `docs/tutorial/typer-command.md` documents.
- **`T2` (High, closed as a class)** - filesystem text IO in the shipped
  package named no encoding, so it went through the process locale:
  `typer <script> utils docs --output FILE` died with `UnicodeEncodeError`
  on help text the locale could not encode. Every unencoded IO site in the
  package closed together.
- **`T7` (Medium)** - `chain` was a documented parameter of `Typer()`,
  `Typer.callback()` and `Typer.add_typer()` whose value changed nothing -
  the inert-documented-parameter class the sweep rule exists to catch.

## Run shape

Iteration 1 audited and filed the map; 2-3 closed the two Highs; 4-8 swept
all 25 surface rows; 9 closed T7; 10 was the closing full fresh-evidence
audit; 11 (the closing extension) brought standing claims current, invoked
the gate, PASS, declared.

## Environment

WSL2, python3 venv, pytest via PEP 735 `--group tests`. Engine 1.20.0 on
Claude Code 2.1.232, model `opus[1m]`. Oracle sabotage-proven before
launch: discarding command registration reddened 1207 of 1373 tests, the
declared baseline restored on revert. The four extra first-run failures
seen once after the fresh venv install never recurred (10/10 probe
signature `de692ab6`) and are recorded in COHORT-WAVE2.md as a first-run
artifact.

Full iteration record: [journal.md](journal.md). Complete shipped diff:
[fixes.patch](fixes.patch).
