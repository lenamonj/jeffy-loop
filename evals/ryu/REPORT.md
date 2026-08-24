# Jeffy eval: dtolnay/ryu

The float-to-string crate under serde_json and most of the Rust
ecosystem's number printing, and the first convergence on engine 1.16.0 -
chosen deliberately as the release's own acceptance exerciser, because a
Cargo target drives the new packaging-channel discipline end to end.
**1 run, 10 iterations, converged** at
`30f5cab798b6851cafa1d190b38b22522c7eadbe`, against a **pre-registered
budget of 2 rounds of 10 declared before launch**. The shipped diff is
**4 files, +65/-1**: on a crate this disciplined, the loop's bill is
small and exact.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `75f9e707e77c89717ffb9c2a01fe2c28a016cc82` |
| Findings closed | **2 Medium** |
| Surface inventory | **15 of 15 rows swept** |
| Ledger at convergence | **4 Lows carried**, each with a runnable acceptance line |
| Evaluator | **2 invocations: REJECT, PASS** |

## What the loop found

- **`S2F-1` (Medium)** - `s2f` rejected strings ryu's own f32 formatter
  emits: 7,807 of 119,543 formatter outputs came back `InputTooLong`,
  because trailing zeros were spent against the significant-digit budget.
  Fixed as a class across both parsers (the same idiom sat latent in
  `s2d` behind an arithmetic coincidence), with the invariant stated
  precisely: a held-back zero is returned to the exponent, so the decimal
  magnitude the overflow guards reason about is unchanged. After the fix:
  0 of 119,543 rejected, every accepted input bit-identical to the
  standard library, and the crate's own two `InputTooLong` tests still
  red on their inputs.
- **`PKG-1` (Medium)** - found by the first audit's artifact-channel
  enumeration, the discipline this engine release introduced: `cargo
  package` would have shipped the loop's state files because `exclude`
  is a denylist that admits every new top-level path. The fix converts
  the manifest to an `include` allowlist, so a new file must be named to
  reach crates.io. The gate verified the published artifact
  **byte-identical in contents to the pre-run one**.

## The gate

Invocation 1 REJECTED on one reason, and the reason is worth publishing
plainly: a Settled-classes entry stated its enumerating command "returns
exactly two sites" while the command, run against HEAD, returns four -
the two extra added by the very commit that wrote the sentence. A stale
standing claim, mechanically derivable, costing an invocation: exactly
the defect family this engine release exists to eliminate, on an object
its pre-gate currency set does not yet name. It is filed against the
engine as such, and the cohort's pre-registered acceptance test **fails
on this reason by its own rule** - the record says so here rather than
softening it. The underlying code fix was sound: 0 regressions over
750,660 differential strings.

Invocation 2 PASSED after a one-line ledger correction, on evidence
rather than tenure: a **5,205,856-check differential under live debug
assertions and overflow checks with a verified positive control**, all
fifteen batteries green, both Declined premises re-derived, and the
packaging artifact compared content-for-content against the pre-run
crate.

## Four Lows carried, published rather than dropped

`PROBE-1` (no battery runs the parsers with overflow checks on - the
gate's own instrument had coverage the run's did not); `OVF-1` (the
fix's own `pending_zeros` i32 wraps on a 2 GiB input - the run filed its
own regression honestly and scored it Low under the envelope's
machine-generated surface rule); `DOC-2` (`write_mantissa_long` silently
wrong above 10^8 x 2^32, unreachable from any in-envelope caller, the
boundary measured exactly); `DOC-1` (the crate's strongest correctness
check, the exhaustive test, is invisible - `cargo test` silently skips
it and no documentation names the cfg that runs it).

## Declared limits

- Run 1 of a declared 2x10; round 2 was never needed.
- Graded on rustc 1.97.1, x86_64 linux under WSL2, run headless as a
  systemd user unit by `claude -p` on **claude-opus-5 (1M context)**,
  driven by `jeffy-campaign.sh` under engine **1.16.0**.
- The launch infrastructure fought back before the run began: the full
  incident record (WSL service instability, an OOM-killed sibling
  target's probe) lives in the cohort file, not hidden in this receipt.

## Nothing was sent upstream

Every finding rests on tests this loop wrote; no existing test was
deleted, disabled or weakened. Whether S2F-1's round-trip fix goes
upstream is a separate decision, made one finding at a time.
