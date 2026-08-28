# Jeffy eval: go-viper/mapstructure

The Go library that decodes generic maps into structs (the maintained fork
of mitchellh/mapstructure, under viper), run 2026-08-27 as one of the two
targets in the acceptance cohort for engine 1.19.1, alongside
`python-slugify`. **3 runs, 25 iterations, converged** at
`80d9f046984c6efd72b5fadaec2629c665f4b38d`, in round 3 of a
**pre-registered budget of 3 rounds of 10**. Run 1 filed the map and
closed the three Highs; run 2 closed out at iteration 7 with the ledger
down to three; run 3 swept the last row, closed the last two Mediums, and
passed the gate twice.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `9aa3f77c68e2a56222ea436c1bfa631f1b1072d5` (tag v2.5.0) |
| Findings closed | **17** - 3 High, 8 Medium, 6 Low |
| Shipped-code change | 10 files, **+1656 / -126** |
| Surface inventory | **16 of 16 rows swept** (14 at run start, two added by the sweep) |
| Ledger at convergence | 7 Lows carried, named in the closing entry |
| Evaluator | **2 invocations: PASS, PASS** |
| Suite at convergence | `go test ./...` green |

## What the loop found

- **`F1` (High)** - numeric decoding silently truncated or saturated on
  overflow: an int, uint or float that did not fit the target type was
  written anyway. Every scalar assignment is now range-checked against the
  target and out-of-range input returns a `ParseError`.
- **`F2` (High)** - decoding a map with a non-string key into a struct
  panicked when `Metadata` was set or `ErrorUnused` was true. Closed as a
  class: every check-the-Kind-then-assert-the-type site in the decoder.
- **`F3` (High)** - `decodeArray` skipped its input-kind and length checks
  whenever the target array was not a zero comparable value, and the Go
  1.19 shim's `isComparable` made that true for every struct.
- **`F4`, `F6`, `F11` (Medium)** - three reflect panics: a struct decoded
  into a map with a non-string key type, a composed decode hook returning
  nil, and squashing an embedded pointer to an unexported struct.
- **`F5`, `F10`, `F16` (Medium)** - float32 values formatted at float64
  width under weak typing; a named pointer-to-struct field bypassing
  `decodePtr` so `ZeroFields` never applied to it; `errors.As` and
  `errors.Is` behaviour on the Go versions the module declares.
- **`F7`, `F17` (Medium)** - the published module shipped the loop's own
  state files (Consequence: a `go get` user receives them); README's
  migration section promised import-path changes were the whole migration
  after two decoding behaviours had diverged from v1.
- **Six Lows carried** - a gofmt hit inside a battery, a stray comment, the
  nesting bound documented in the wrong units, two battery-README notes,
  a Settled-class remainder count, and a dotted name in the nesting-bound
  error.

## The gate

Two invocations, both PASS, under the 1.19.0 brief: for every closed High
and Medium the evaluator ran the filed reproduction on the base commit and
confirmed it failed there, ran it on HEAD and confirmed it passed, and
re-executed the acceptance as written. Its observations were recorded as
Lows, none a REJECT reason.

One asterisk. The first declaration, at iteration 7 of run 3, was refused
by the Stop hook because a battery README under `.jeffy/` stated
`decoder-core: 205/213 checks passed` and no claims line carried it. The
run fixed the prose and re-declared at iteration 8, where the declaration
was accepted. That refusal is on the loop's notes, not on the product; it
is the third target in two days to lose time to that class, and engine
1.20.0 removes the check from the declaration path (P1-69).

## Status

Fixes live in this eval's artifacts (`fixes.patch`); nothing was pushed
upstream. The three Highs each carry a one-line reproduction in the
journal. Journal at `journal.md`.
