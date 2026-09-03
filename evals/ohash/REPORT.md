# Jeffy eval: unjs/ohash

The UnJS object hasher: `hash`, `serialize`, `digest`, `isEqual` and `diff`,
with a pure-JS SHA-256 for browser and edge builds. Run 2026-09-03 as wave
18 (COHORT-WAVE17.md). **1 run, 10 iterations, converged** in round 1 at
`93f7c8daef388ed8363a261e36c9c04af38e2274`, within a **pre-registered budget
of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `764b0a3203308956ef07597612af5ad59f36c791` (main) |
| Findings closed | **6** - 3 High, 2 Medium, 1 Low; 3 Lows carried (see below); one declined on a derivation |
| Shipped-code change | 7 files, **+240 / -28** |
| Surface inventory | **10 of 10 rows swept** |
| Ledger at convergence | 3 Lows carried, 0 blocked |
| Evaluator | **2 invocations: REJECT, PASS** (both in round 1; the second inside the declaring iteration) |
| Suite at convergence | `pnpm build && pnpm vitest run`: 106 tests, 0 failures (90 at base) |
| Upstream | two PRs prepared (OH-1, OH-2), see below |

## What the loop found

- **`OH-1`** (High) - the pure-JS `digest` encoded input through
  `unescape(encodeURIComponent(input))`, which throws `URIError: URI
  malformed` on any string holding a lone surrogate, so `hash()` crashed in
  every browser, bundler and edge build on input that hashed fine on Node
  (`ohash/crypto` resolves by export condition, so the Node implementation
  never runs there). It now encodes with `TextEncoder`, which substitutes
  U+FFFD as `node:crypto` does; the regression test compares four
  lone-surrogate inputs against `node:crypto`, and 200 well-formed strings
  across the code-point ranges still hash byte-identically.
- **`OH-2`** (High) - `diff` silently reported no change when a key moved
  between a leaf and a non-empty container: `diff({a: 1}, {a: {b: 2}})`
  returned `[]`. A characterization test pinned that, and `git log -S`
  showed the assertion and the perf refactor that wrote it arrived in one
  commit, so nothing upstream ever chose the behaviour. A 588-pair matrix
  bundled from the two source revisions side by side shows the fix only
  adds output.
- **`OH-7`** (High, filed by the evaluator's REJECT) - `diff` overflowed
  the stack on any cyclic input, because neither the fused traversal nor
  `_toHashedObject` tracked what it was already walking. Both now carry the
  path being walked; a cyclic subtree hashes as `[Circular]`, mirrored
  cycles compare once, and a value reachable by two routes is still
  compared on each.
- **`OH-8`** (Medium, filed by the gate) - `DiffHashedObject.toString()`
  rendered a leaf with `JSON.stringify`, which throws on a BigInt that
  `_leafHash` accepts, so `diff({a: 1n}, {a: 2n}).join("\n")` threw. A
  BigInt now renders as `serialize` renders it.
- **`OH-3`** (Medium, docs) - the README documented `diff` entries as
  carrying `$key`, `$hash`, `$value` and `$props`; none exist. Rewritten to
  the real `DiffEntry` shape.
- **`OH-4`** (Low, docs) - a README anchor no heading produces.
- **`OH-D1`** (declined) - a design question about `DataView`
  serialization, recorded with a re-runnable derivation rather than a fix.

**Carried Lows (3), not blocking**: `OH-5` two vite advisories reachable
only through vitest; `OH-6` the `createHash` fallback in the Node crypto
path is never reached by the suite on this host; `OH-9` the rewritten
README says `newValue` is "absent" on a removed entry where the property
exists holding `undefined`.

## What the loop got wrong

**The OH-2 receipt certified the wrong thing.** Its 588-pair differential
matrix was acyclic, so it said "no previously passing output changed"
while three cyclic shapes went from `[]` to a stack overflow. The evaluator
rejected the first declaration on exactly that, and OH-7 is the
consequence. The lesson in the journal: a differential over a recursive
function must include the shapes that make it recurse without end.

**The bundle-size budget was raised** from 5000/2100 to 5300/2200 bytes for
the cycle guard, with the before and after measurements written beside the
assertion. The gate re-measured independently (4936/2041 before, 5102/2120
with the guard) and judged the raise legitimate: the alternative was
shipping the overflow or a v1-only guard that loses comparisons with real
differences. It is disclosed here because a loop that loosens a project's
own threshold has to say so.

**Host limits, disclosed**: Node 24.17.0 only; CI runs Node 22. The
`createHash` fallback path is unexercised (OH-6).

## Upstream

Two PRs are prepared on main `764b0a32` (still the tip): `OH-1` as
`digest-lone-surrogate` and `OH-2` as `diff-leaf-vs-container`, each
verified red-then-green in a fresh clone with the project's lint, prettier
and type checks green, under the original bundle budget. `OH-7` and `OH-8`
stay in the receipt: the cycle guard is a larger change that raises the
project's size budget, which is the maintainers' call.

## Files

- [journal.md](journal.md) - the full loop journal, every iteration
- [fixes.patch](fixes.patch) - the product diff, base to converged HEAD, loop state excluded
