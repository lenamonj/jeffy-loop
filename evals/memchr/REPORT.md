# Jeffy eval: BurntSushi/memchr

The SIMD-accelerated substring and byte search crate underneath ripgrep
and much of the Rust ecosystem - hand-written SSE2, AVX2, NEON and
wasm32 simd128 kernels behind a runtime-dispatch layer, `no_std` capable,
zero default dependencies. Run 2026-08-31 as wave 6 of the merged-PR
campaign (COHORT-WAVE6.md). **1 run, 8 iterations, converged** in round 1
at `fcffdfbbe0f6229b86a8a76e4beda48546d339c0`, within a **pre-registered
budget of 5 rounds of 10**, with two iterations held in reserve against a
REJECT that did not come.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `bd6068c30e9074a90c285e47912fa0b047d07597` (master, v2.8.3) |
| Findings closed | **3** - 1 Medium, 2 Low |
| Shipped-code change | 4 files, **+25 / -13** |
| Surface inventory | **18 of 18 sweepable rows swept** (a 19th, executing aarch64 NEON, recorded unreachable on this host) |
| Ledger at convergence | 3 Lows carried, 2 Declined |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | 660 tests green across four feature configurations |

The scarcity of findings is itself the measurement. The sweep executed
roughly 2.5 million differential checks against naive reference
implementations - five alphabets, 130 haystack lengths straddling every
vector boundary, 13 start alignments, across three x86_64 dispatch arms
and two wasm32 configurations under wasmtime - and every one agreed with
the references. The audit also timed the vector paths rather than
trusting them: 16.3 GiB/s for `memchr` against 3.6 for a naive scan, so
the SIMD is live, not silently falling back to scalar.

## What the loop found

- **`PKG-1` (Medium)** - the published crate carried the loop's own
  state files, and the cause was structural: `Cargo.toml` used an
  `exclude` denylist, so every new top-level path shipped by default.
  Fixed by replacing it with an `include` allowlist - a path nobody names
  no longer ships. Verified by building the package from its own tarball,
  with a plain file planted under the probe directory first, because
  cargo omits any subdirectory carrying its own Cargo.toml from
  `cargo package --list` and a probe crate can hide its whole parent
  directory from the answer.
- **`QUAL-1` (Low)** - `src/cow.rs` carried a dead `cfg(not(alloc))`
  block inside a function already gated on `alloc` - unreachable code
  wearing a conditional that read as if it did something.
- **`DOC-2` (Low)** - the documentation build was not warning-clean;
  fixed as a class (redundant explicit intra-doc link targets), with the
  docs battery strengthened to hold the build clean under `-D warnings`.

Carried, each on its own ledger line: `DOC-1` (a comment in the Shift-Or
constructor states a 7-byte needle bound where the `u16` mask enforces
15), `CI-1` (no CI job grades the declared MSRV of 1.61, and
`--features logging` genuinely fails there on a fresh resolve), `TOOL-1`
(the repository's only script starts `#!/usr/bin/env python` and cannot
run on a python3-only host). Declined with re-runnable derivations:
`LINT-1` (clippy, on price) and `MIRI-1` (no UB checker runs here).

## What the gate added

The PASS was not a rubber stamp. The gate re-ran PKG-1's reproduction
against the base manifest swapped into the present tree, diffed the full
base and HEAD package listings - 148 paths against 59 - and confirmed the
only paths that stopped shipping are the loop's own. It also caught the
run's one overclaim, in the run's own record rather than the product:
MIRI-1's Declined line said miri "cannot be installed on this toolchain
at all" where the recorded command had only asked about stable - miri is
present on this host's nightly. The declaration does not rest on it, and
the correction is the next run's first task.

## AI usage disclosure

memchr's CONTRIBUTING points at an AI policy that welcomes AI coding
tools but requires any comments to maintainers to be written by a human,
and requires the contributor to be able to explain the change.

Nothing was filed upstream from this run: the campaign's bar for a PR is
a novel, genuinely High finding, and this run's ceiling was one Medium
whose fix (the packaging allowlist) embeds a maintainer's judgement about
what a published crate should contain. Anything filed here in the future
will be written and reviewed by a person, per the policy.
