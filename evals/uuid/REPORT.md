# Jeffy eval: uuid-rs/uuid

The 1,235-star Rust `uuid` crate, the UUID implementation that serde, sqlx, diesel and
postgres-types expose behind an optional feature. Run 2026-09-02 as wave 13
(COHORT-WAVE13.md). **1
run, 10 iterations, converged** in round 1 at
`46630fc1b3816d6632701c5847cb81940d386003`, within a **pre-registered
budget of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `cdc96a87bddc38d0eb8f894c764e151d2299b4b3` (main, at v1.26.0) |
| Findings closed | **5** - 1 High, 4 Medium |
| Shipped-code change | 7 files, **+286 / -72** (one line of it is loop housekeeping, see below) |
| Surface inventory | **22 of 22 rows swept**; one row (`rng-wasm`) disclosed unreachable, no wasm target on the host |
| Ledger at convergence | 4 Lows carried (`F3`, `F4` docs, `F7` a coarser error message on an over-length URN, `F9` three clippy warnings) |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | `cargo test --all-features`: 226 passed, 0 failed (219 at base) |
| Upstream | [#907](https://github.com/uuid-rs/uuid/pull/907) (F5), filed 2026-09-02 |

## What the loop found

- **`F5` (High, correctness)** - `Uuid::new_v7` shifted the counter so
  its most significant bit landed at bit 127 of the value handed to
  `Builder::from_unix_timestamp_millis`, where the version nibble
  overwrites it, so the top four bits of any counter never reached the
  UUID. With a 42-bit counter, setting any of bits 38-41 produced the same
  `rand_a`/`rand_b` as a counter of zero; a counter stepping from
  `0x3fffffffff` to `0x4000000000` produced a UUID that sorted lower; and
  under `ContextV7::new().with_additional_precision()` the lost bits are
  the sub-millisecond ones, so of 53 pairs of instants ordered forward
  inside one millisecond, 29 pairs of UUIDs sorted backwards. The fix
  seats the counter at bit 123, the top of `rand_a`, and opens the
  variant gap only when the counter reaches past it. Two regression
  tests, both failing at base.
- **`F1` (Medium)** - `#[serde(with = "uuid::serde::bytes")]` serialized
  through serde_json as a sequence of integers and could not read its own
  output back (`invalid type: sequence, expected a 16 byte array`). The
  byte visitor now implements `visit_seq`, sharing the helper the readable
  visitor already used.
- **`F2` (Medium)** - the parse diagnostic for a wrong-length final group
  measured the group against the whole input, so the same value reported
  `found 11` bare, `found 13` braced and `found 20` as a URN. One
  expression in `InvalidUuid::into_err`.
- **`F6` (Medium, docs)** - `Builder::from_unix_timestamp_millis` told
  callers to keep significant data out of "the 2 least significant bits
  of the 3rd byte"; measured, those two bits survive and it is the 4 most
  significant bits of the 1st byte and the 2 most significant of the 3rd
  that the version and variant overwrite. Rewritten with an executable
  doc example.
- **`F8` (Medium, packaging)** - the crate's `include` list in Cargo.toml
  carried an unanchored `README.md`, which Cargo matches at any depth, so
  `cargo package --list` shipped 22 of this run's own probe READMEs. The
  patterns are now anchored to the package root. The defect is the
  crate's (any nested file of that name would have shipped), but nothing
  had matched it until this run added such files, which is why it is
  scored at the packaging channel and disclosed here.

## What the loop got wrong

Nothing that reached the product. The `.gitignore` gained one line for the
loop's own state file; that line is in `fixes.patch` and counted in the
numbers above. F8 is a defect this run made visible rather than caused,
but a reader should know the run is the reason it surfaced.

## Upstream

`F5` is [#907](https://github.com/uuid-rs/uuid/pull/907), verified on a
fresh clone at upstream HEAD against every CI target the host can run
(`cargo test --all-features`, `--doc`, `cargo hack test --lib
--each-feature` and `--all-features`, the examples crate, the 1.85.0
MSRV smoke build; wasm not run). `F1` and `F2` are Mediums and stay in
the receipt.

## Files

- [journal.md](journal.md) - the full loop journal, every iteration
- [fixes.patch](fixes.patch) - the product diff, base to converged HEAD, loop state excluded
