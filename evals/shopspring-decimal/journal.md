# Engineering log - shopspring/decimal audit

Date: 2026-07-27. Workspace: scratch clone only; nothing in the upstream repo touched, nothing pushed.

## Setup
- `go version go1.26.2 windows/amd64`, `git 2.50.1`, `gh 2.89.0`. Toolchain present, proceeded.
- Cloned `https://github.com/shopspring/decimal.git`. HEAD `3090cc487febd78d6016c2859c66308328a40e99`, 2026-06-29, "fix: NumDigits underreports for some exact powers of ten (#425)".
- `gh api repos/shopspring/decimal --jq .stargazers_count` -> `7457`.
- Last tag `v1.4.0` = `a1bdfc355e9c71119322b748c95f7d6b82566e30`, 2024-04-12. Seven commits on master since; none touch rounding.
- `go test ./...` at HEAD, verbatim: `ok  	github.com/shopspring/decimal	5.982s`. `-v` count: 115 `--- PASS`, 0 `--- FAIL`.

## Lead triage
- Pulled the seven issue bodies with `gh api repos/.../issues/N` rather than trusting the summaries. #385's snippet does not compile (`DivRound` takes two arguments) - first sign the report may be mistaken.
- Wrote one probe covering all seven leads and ran it at HEAD. Then added a `git worktree` at the `v1.4.0` tag and ran the same probe there. Output byte-identical. Killed the "fixed in main, unreleased" hypothesis with evidence rather than assuming it.
- `git blame` on `RoundUp`/`RoundDown`: the `d.Equal(rescaled)` guard is from `99f4d74c` (2021-01-18); the only later touch is `6540310` (2026-03-08), a mechanical `d.value` -> `d.getValue()` nil-safety refactor. So #388 was already impossible when it was filed.

## Class audit
- Built an exact-rational oracle over `big.Rat` and drove `Round`/`RoundUp`/`RoundDown`/`RoundCeil`/`RoundFloor`/`RoundBank` against it. Fixed corpus first (40 money-shaped and pathological strings x 8 places): 0 value mismatches. Then 40,000 random decimals x 6 methods = 240,000 checks, coefficients to 10^25, exponents -20..0, places -8..16: 0 value mismatches. `DivRound` separately: 19,877 checks, 0 mismatches.
- That result reframed the whole audit. The family's arithmetic is right. The divergence is the exponent of the result.
- Scale sweep, 20,000 random inputs: `Round` and `RoundBank` return exponent `-places` every time; `RoundUp`/`RoundDown`/`RoundCeil`/`RoundFloor` return something else 6,482 times each (identical count - same two early-return paths, same root cause). Filed as one class, not four instances.
- Enumerated every call site before touching anything. Confirmed the `Round`/`RoundUp`/`RoundDown` in `rounding.go` and `decimal-go.go` are on the unexported `decimal` shortest-float helper, not on `Decimal`, so they are outside the class. No internal caller uses the four directional rounders.
- Checked all 29 `// output:` doc-comment examples in the rounding and division comments execute as documented. All pass at HEAD, and still pass after the fix. This is what settled #375: the negative behaviour the reporter objects to is printed in the doc comment itself.
- Separate probe on `RoundCash` across `DivisionPrecision` values found the hidden coupling: correct at 16/4/2, wrong at 1 (3.45 -> 3.5) and 0 (3.45 -> 3).

## Fixes
- D1: four methods, same two-line shape each. `d.exp >= -places` -> `d.exp == -places`; `return d` -> `return rescaled` in the `Equal` branch. `RoundDown` then reduced to `return d.rescale(-places)` because truncation toward zero already is round-down - the guard there was dead weight.
- D2: `Div(dVal)` -> `DivRound(dVal, 2)`. Dropped the now-provably-dead `Truncate(2)`.
- Verification: full upstream suite `ok ... 12.141s`, `go vet` clean, 240,000-check value oracle still 0 mismatches, all doc examples still pass, scale sweep now 0 violations for all six methods.
- Non-breaking proof for D2: reconstructed the pre-fix expression through the public API and compared 100,000 random inputs x 5 intervals at `DivisionPrecision` in {2,3,4,8,16,30}. 600,000 comparisons, 0 differences in value or exponent.
- Cost check for D1: `RoundUp(100000)` on "1" now pads like `Round` does - 1.85ms vs `Round`'s 1.28ms. Same cost class, disclosed anyway because those four methods did not have that path before.

## Round-trip check on the deliverable
- Fresh `git worktree` pinned at HEAD, dropped in `repro_test.go`, ran unpatched: `TestJeffyD1_ScaleContract`, `TestJeffyD1_SerialisationConsequence`, `TestJeffyD1_ScaleContractSweep`, `TestJeffyD2_RoundCashIgnoresDivisionPrecision` all FAIL with expected-vs-actual; the four `NotRepro`/`Documented` cases and both guards PASS.
- `git apply fixes.patch` on the same worktree, reran: `go test -run Jeffy .` ok, `go test ./...` ok, `go vet ./...` clean.
- `gofmt -l repro_test.go` clean.

## Judgement calls I want on the record
- Did not score D1 or D2 High. Neither produces a wrong magnitude under default settings. High in this rubric means users get wrong results; a wrong *scale* on a correct amount is Medium.
- Did not file #375, #394, #380 or #411 as defects. All four behave exactly as their doc comments say. Reporting a documented convention as a bug would have made the count look better and the audit worse.
- Did not seize the D1 adoption decision. The patch is right, but it changes bytes that downstream golden tests may pin, so the maintainer decides. Wrote the narrower alternative into the report so the decision is a real choice and not a take-it-or-leave-it.
