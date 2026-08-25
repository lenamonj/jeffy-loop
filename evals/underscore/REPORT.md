# Jeffy eval: underscore

The functional-utilities library that taught JavaScript half its idioms,
and at 27,330 stars the highest-starred convergence in this corpus. Run
in the 2026-08-24/25 JavaScript wave on engine 1.16.0 with a
**width-differentiated budget declared before launch** - 3 rounds of 10
for its wide surface where its wave-mates got 2. **2 runs, 20
iterations, converged** at `015447f1ffcc7f46ae514eddc4e0c69ea0a771df` -
the third round was never needed.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `e70d5bd070f1d883b40e786a955a61e4f4b3c2c6` |
| Findings closed | **11** - 2 High, 5 Medium, 4 Low |
| Shipped-code change | 42 files, **+6,066 / -2,277** (the bulk is the toolchain majors of U4a and the rebuilt tracked bundles they regenerate) |
| Surface inventory | **23 of 23 rows swept in round 1** |
| Ledger at convergence | 3 Lows carried; **1 Medium blocked with its reason recorded** (U4b, below) |
| Evaluator | **2 invocations: REJECT, PASS** |

## What the loop found

- **`U1` (High)** - a computed key of `__proto__` resolved to the
  inherited accessor on `Object.prototype`, so a data-derived key wrote
  through the prototype chain - the prototype-pollution shape, in the
  utility library half the ecosystem copies patterns from. `UA2`
  extended the class: `_.defaults` silently dropped a `__proto__` own
  key because absence was decided with `obj[key] === undefined`.
- **`U6` (High)** - a value with no path to a primitive made
  `_.isFinite`, `_.escape` and `_.unescape` throw `TypeError` instead of
  answering.
- **`U3` (Medium)** - the packaging-channel enumeration found that
  **only the npm channel excluded the loop's state**: `package.json`
  carries a `files` allowlist, but the bower channel had no such guard -
  the fourth distinct packaging channel (crates, npm, Go modules, bower)
  this engine release's discipline has caught in three waves.
- The rest: dead IE-detection fallbacks with no coverage in any gate
  that runs (`U2`), toolchain majors behind (`U4a`), `_.compose()`
  misbehaving with no arguments, a documented `_.isFinite` sentence a
  reader takes for a type test, and two published `index.html` examples
  that did not evaluate to what they claimed - with nothing in the
  repository ever running the page's own examples (`UA1`).

## The gate

REJECT 1 is a finding about what the tests actually test: PLAN.md's
Oracle class claimed `npm test` grades the bundle the package `exports`
map serves to Node consumers - and the gate proved by module resolution
that **every test file and every battery loads `underscore-umd.js`
instead**, while a real install serves `underscore-node.cjs`. The
packaging battery's own header claimed three entry points "must all load
and agree" while loading the same file twice. The run repaired the
claims and the coverage; invocation 2 PASSed.

## Carried at convergence, published rather than netted

Three Lows (a build step regenerating tracked bundles that `npm test`
does not run; an Oracle-class caveat; two battery scope declarations
narrower than what the batteries touch) and **U4b, a Medium blocked with
its reason recorded**: 70 remaining `npm audit` advisories concentrated
in the browser-test and publishing toolchain (karma, coveralls), whose
remediation is upstream major migrations beyond a run's remit. The gate
countersigned over it under the engine's blocked-with-reason
disposition, and the receipt says so up front.

## Declared limits

- Graded on Node v24.17.0, linux under WSL2, run headless as a systemd
  user unit by `claude -p` on **claude-opus-5 (1M context)**, engine
  **1.16.0**.
- The large diff is mostly regenerated tracked build artifacts riding
  the U4a toolchain upgrade; the hand-written library changes are a
  small fraction of it, visible in fixes.patch.

## Nothing was sent upstream

Every finding rests on tests this loop wrote; no existing test was
deleted, disabled or weakened. Whether U1/UA2's `__proto__` class goes
upstream is a separate decision, made one finding at a time.
