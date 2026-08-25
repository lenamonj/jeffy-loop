# Jeffy eval: vavr (Java)

`vavr-io/vavr` - the persistent-collections and functional-control
library for Java - run in the 2026-08-25 diverse-language wave on
engine 1.16.0, the corpus's second Java target after gson. **2 runs,
13 iterations, converged** at
`731982b2883b648a38dd5a144e5f0422ba97ab8d`, in round 2 of a
**pre-registered budget of 3 rounds of 10** - the spare round was
never needed.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `6c0e0ed1c58511352d3ee7888fbd8f1e2878b478` |
| Findings closed | **3** - 1 High, 2 Medium |
| Shipped-code change | 3 files, **+22 / -3** |
| Surface inventory | **30 of 30 rows swept** |
| Ledger at convergence | **2 Lows carried** + 1 Low declined with its derivation |
| Evaluator | **1 invocation, PASS** |

## What the loop found

- **`V-5` (High)** - `BitSet.removeAll` wrote each element into the
  receiver's word array with no bound check, so removing an element
  past the receiver's last bit word threw
  `ArrayIndexOutOfBoundsException` on two valid BitSets.
- **`V-2` (Medium)** - the loop's own state files shipped to consumers
  through the git-archive channel - what GitHub attaches to every
  release tag as Source code. The **sixth distinct packaging channel**
  the artifact-channel class has caught, and the gate verified the fix
  as a set comparison (286 files against 286), not a count.
- **`V-1` (Medium)** - `Iterator.narrow` documented `@throws
  NullPointerException` while its body is a bare cast that returns
  null; one of 319 javadoc NPE claims the run resolved, the other 318
  honoured.
- **`V-6` (Low, declined)** - 100 javadoc warnings spanning the Scala
  generator, an annotation processor and eighteen hand-written sources:
  priced out under the one-iteration rule, with the derivation recorded
  so the next audit re-runs it instead of re-filing it.

A 23,174-test suite that was already green is why the shipped diff is
22 lines: most of the budget went to sweeping 30 rows with 3,536
known-answer battery checks, which is what certifying a mature tree
costs.

## The gate

One invocation, PASS. It re-ran the suite raw (23,174 / 0 failures),
re-derived the toolchain claim from the build's own invocation, re-ran
all 3,536 battery checks, checked the staleness test was not vacuous
by expanding every battery's path globs against its row's file list,
and re-scored both carried Lows.

## Declared limits

- Graded on OpenJDK 21.0.11, linux under WSL2, run headless as a
  systemd user unit by `claude -p` on **claude-opus-5 (1M context)**,
  engine **1.16.0**.

## Nothing was sent upstream

Every finding rests on tests this loop wrote; no existing test was
deleted, disabled or weakened. Whether the BitSet fix goes upstream is
a separate decision, made one finding at a time.
