# Jeffy eval: dtolnay/semver

The semantic-versioning parser under Cargo's own dependency resolution and
half the Rust ecosystem's version checks, and the second of three targets
in the 2026-08-23 cohort - the first cohort run on engine 1.15.2. **2
runs, 16 iterations, converged** at
`9390aa1d96cd54260b56744db90a0165660efee0`, against a **pre-registered
budget of 2 rounds of 10 iterations declared in the cohort file before the
launch command existed**. Not the npm `node-semver` the corpus already
holds as a non-convergence: different project, different language, never
pooled.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `280ebcb6edac3aa4cdc545dbff8a26c5ac4861fe` |
| Upstream CI on the base | **793 of 796 concluded check-runs green**, 3 with no conclusion recorded |
| Findings closed | **8** filed by audits - 2 Medium, 6 Low - plus the 2 the gate itself filed, closed in run 1's final iteration |
| Shipped-code change | 8 files, **+319 / -39** (manifest, CI workflow, display path, and the tests that pin each fix) |
| Surface inventory | **12 of 12 rows swept** |
| Ledger at convergence | **empty** - nothing carried at any severity |
| Evaluator | **3 invocations: REJECT, REJECT, PASS** |

## What the loop found

A crate this load-bearing turned out to hold no runtime High - what it
held was published contracts with no tests behind them:

- **`T1`** - the six serde `Serialize`/`Deserialize` impls were never
  executed by any test, so the wire format of `Version`, `VersionReq` and
  `Comparator` was a published contract with no regression test; the serde
  feature also ran in no CI job.
- **`T2`** - four branches of `Ord` for `BuildMetadata` had never
  executed: the zero-padding tiebreak, both numeric-versus-non-numeric
  arms, and the longer-set arm. The documented precedence chain
  `demo < demo.85 < demo.90 < demo.090 < demo.200 < demo.1a0 < demo.a < memo`
  had no test behind it.

The six Lows: `Display` honoured width, fill and alignment for `Version`
and silently dropped them for the four other types (`T5`, all five now
share one pad helper); clippy pedantic failing on the unlinted serde
module (`T3`); `FromIterator<Comparator>` untested (`T4`); the
npm-semver differential runnable on the host and never run (`T6`, now a
committed battery); the fuzz battery that type-checked its targets but
never fuzzed (`T7`, now carries a deterministic randomized driver); and
the CI workflow owned by no battery (`T8`).

## The gate is the story here

Run 1 reached its first invocation at iteration 9 with a swept map and an
empty ledger, and was **rejected twice**:

- **REJECT 1** found a Medium the run had missed and could not have seen
  through its own instruments: `Cargo.toml`'s `exclude` list was never
  updated for the loop's presence in the tree, so **`cargo package` would
  have shipped the run's audit ledger, probe harness and metrics inside
  the published crate tarball** - 69 files packaged where the base commit
  packages 21. The packaging probe that let it through was liveness-only
  (`cargo package` exits 0 either way), which the gate named as the
  instrument defect it was. It also falsified a journal claim by
  one-command reproduction (a bare `cargo test` does compile the
  `serde_test` rlib; `required-features` excludes the test target, not the
  dev-dependency) and caught the environment fingerprint declaring one
  installed toolchain when the run's own record shows it using a second.
- **REJECT 2**, after the final iteration fixed all of that, found exactly
  one thing: the build-config inventory row still recorded its sweep at a
  commit predating the manifest it certifies - a stale hash on a declaring
  artifact, the class the engine treats as misleading documentation.

Run 1 ended blocked at its cap. Run 2 opened with a fresh full audit on
the swept map, closed `T6`/`T7`/`T8`, and its invocation - the third
overall - PASSed at iteration 4 with five iterations in hand. The
declaration followed in the same iteration, with nothing carried: the only
target of the three, and one of very few in the corpus, to converge on an
**empty ledger**.

## Declared limits

- The oracle is the crate's own 49 hand-written assertions plus doctests
  under `--all-features`; not a conformance corpus. The npm-semver
  differential added by `T6` is a battery, not part of the Verify command.
- Graded on rustc 1.97.1, x86_64 linux under WSL2, run headless by
  `claude -p` on **claude-opus-5 (1M context)**, driven by
  `jeffy-campaign.sh`.

## Nothing was sent upstream

Every finding rests on tests this loop wrote; no existing test was
deleted, disabled or weakened. Whether any of this goes upstream is a
separate decision, made one finding at a time.
