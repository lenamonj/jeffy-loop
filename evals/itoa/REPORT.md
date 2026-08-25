# Jeffy eval: dtolnay/itoa

The integer-to-string crate beside ryu - same author, the other half of
the number printing under serde_json - run in the 2026-08-25 acceptance
cohort for engine 1.17.0, the corpus's second dtolnay crate and its
seventh Rust convergence. **2 runs, 16 iterations, converged** at
`ecbcb0e5bb02a0c1dcc907077caac1d4b59ece2f`, in round 2 of a
**pre-registered budget of 3 rounds of 10** - the spare round was never
needed. Run 1 ended blocked on a High it could not close in three
attempts; run 2 closed it in one iteration by testing the hypothesis
run 1 left behind.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `1577ed901354d0d7448ac162328f9dbf5183124c` |
| Findings closed | **7** - 1 High, 6 Medium |
| Shipped-code change | 4 files, **+397 / -8** |
| Surface inventory | **14 of 14 rows swept** |
| Ledger at convergence | **4 Lows carried** (IT-9, IT-10, IT-11, IT-12) |
| Evaluator | **2 invocations: REJECT, then PASS** |

## What the loop found

- **`IT-5` (High)** - with the `no-panic` feature on, a downstream
  release build failed to link for a runtime `i32`, `i64` or `isize`.
  The signed `write` reached its digit buffer through a range bounds
  check and a fallible array conversion, both provably infallible, and
  a third bounds check on the sign byte. `no-panic` exists to make a
  link failure out of exactly that, and it did. Fixed with the pointer
  cast `Buffer::format` already uses for the same reason. Run 1 had
  filed this as IT-4 and spent three attempts on the wrong hypothesis
  before running out of budget.
- **`IT-3` (Medium)** - `Buffer::format` cast its byte array to
  `I::Buffer` and wrote through it with nothing enforcing that the
  target fits; a const assertion now makes a mismatch a compile error.
- **`IT-2` (Medium)** - `cargo package` shipped the loop's own state
  files inside the published crate. The packaging-channel class the
  ryu run first caught, on the sibling crate.
- **`IT-1` (Medium)** - `tests/test.rs` executed no case for seven of
  the twelve integer types, and its thirteen fixed cases caught 5 of 10
  seeded single-token defects. After the fix the suite catches all 10.
- **`IT-8` (Medium)** - filed by the gate's REJECT: the SAFETY comment
  written on the unchecked sign write in iteration 2 stated a premise
  that is false at every signed type's `MIN`, the one value it exists
  to justify. The fix states the true bound and commits its enumeration
  as a test.

## The gate

Two invocations. The first REJECTed on IT-8 alone: it enumerated the
five signed instantiations and showed `digits(T::MIN.unsigned_abs())`
equals `MAX_STR_LEN - 1` exactly for each, contradicting the sentence
the loop had written to justify an unchecked write. The second PASSed:
all 14 batteries re-run (35,390,598 checks, 0 failures), every closed
task's acceptance re-executed as written, both historical `no-panic`
link counts re-derived, miri clean under strict provenance and Tree
Borrows, MSRV 1.68 green on forced recompiles, and the new
README-claims enumerator deliberately provoked into its MISMATCH path
to confirm it can fail. Its three non-blocking observations were filed
as IT-12 rather than fixed, because a fix inside the convergence
sequence would have spent an invocation the run no longer had.

## Declared limits

- Graded on rustc 1.97.1 stable, x86_64 linux under WSL2, run headless
  as a systemd user unit by `claude -p` on **claude-opus-5 (1M
  context)**, engine **1.17.0**. The 16-bit `target_pointer_width` arm
  is unreachable on any installable stable target and is declared so in
  the environment fingerprint; the 32-bit arm is build-checked on
  `thumbv6m-none-eabi`, not executed.

## Nothing was sent upstream

Every finding rests on tests this loop wrote; no existing test was
deleted, disabled or weakened. Whether the `no-panic` fix goes upstream
is a separate decision, made one finding at a time.
