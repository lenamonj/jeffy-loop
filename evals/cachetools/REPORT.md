# Jeffy eval: tkem/cachetools

The extensible memoizing collections library - LRU, LFU, TTL and friends,
the `@cached` decorator half the Python ecosystem reaches for - written in
pure Python with zero runtime dependencies. Run 2026-09-01 as wave 6 of
the merged-PR campaign (COHORT-WAVE6.md). **2 runs, 18 iterations,
converged** in run 2 at `f8e4c03679a29bcbfbb4b5c81c5bb38915a758ab`, within
a **pre-registered budget of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `4500e3d04288738d25acbb4973eb3c3e1bf41db9` (master, v7.1.8) |
| Findings closed | **12** - 6 Medium, 6 Low (a 13th ledger item, L4, was closed by M5's own repair) |
| Shipped-code change | 8 files, **+503 / -19** |
| Surface inventory | **14 of 14 rows swept** |
| Ledger at convergence | 4 Lows carried |
| Evaluator | **3 invocations: REJECT, REJECT, PASS** |
| Suite at convergence | 351 passed (~4.2 s), 100% statement coverage of `__init__.py` |

No High was found. cachetools is a mature, tightly-tested library whose
cache algorithms survived differential fuzzing against independent
reference models; the yield came from the packaging channel and from one
deep seam - what a timed cache's clock means while an iterator is held -
which produced five of the six Mediums.

## What the loop found

- **`M2` (Medium)** - holding an iterator froze the timed caches' clock
  for everything. `len()` reported 3 with every item expired, `timer()`
  stood still, and a value written during the window was silently gone
  the moment the iterator was dropped - a backdated write. The fix
  separates the read freeze from the write path: a key the iterator just
  yielded stays readable, while writes and expiry follow the real clock.
- **`M4` (Medium, filed by the evaluator gate)** - the M2 fix left
  `get()` outside the new read freeze, so within one iteration step
  `key in cache` said True and `cache[key]` returned the value while
  `cache.get(key)` returned the default. The gate measured 128 of 500
  trials diverging on a real monotonic clock against 0 of 500 at base -
  a regression this run introduced and its own 83-check battery passed
  over, because the battery drove only the operations the fix was
  thinking about.
- **`M5` (Medium, filed by the gate's terminal REJECT)** - with an
  iterator held, `cache.expire()` returned nothing and removed nothing
  while `len(cache)` in the same instant reported 0 and emptied the
  cache. Fixed on the code side: `expire()` follows the clock, so the
  documented enumeration became true rather than being bent to the code.
- **`M6` (Medium)** - the enumeration that closed M5, driven at every
  operation instead of the ones under repair, found `del cache[key]`
  disagreeing with `in` and `[]` in the same step - and the two timed
  classes disagreeing with each other: TTLCache deleted silently,
  TLRUCache raised KeyError.
- **`M1` (Medium)** - the sdist carried the loop's own state files:
  setuptools-scm enumerates from `git ls-files`, so every new tracked
  root path ships until someone denies it by name. Fixed as a class with
  the enumeration read from git at probe time, and verified by installing
  the resulting sdist, not by listing its names.
- **`M3` (Medium)** - `dict(ttl_cache)` can raise KeyError where
  `dict(cache.items())` cannot, because the merge forms exhaust `keys()`
  before reading any value, so no read sees the per-step freeze. Measured
  over 2000 trials per form to establish the exact boundary, then
  documented with the atomic alternative - making it atomic would require
  precisely the freeze lifetime M2 removed for causing data loss.
- **`L7` (Low)** - `Cache.popitem()` on an empty cache raised a bare
  `KeyError` while all six subclasses named the class.

## What the gate earned

The evaluator was invoked three times and paid for all three. Invocation
1 rejected on M4 with a from-scratch reproduction and a measured rate.
Invocation 2 confirmed the M4 fix held, then rejected on M5 - a false
sentence in the documentation enumeration the run had just written - which
ended run 1 blocked at budget exhaustion. Run 2's fresh gate reproduced
both Mediums from scratch against the pre-fix tree, ran a 20-probe
differential that differs from base on exactly the one line L7 intended,
and passed. Both REJECTs caught defects the run's own instruments agreed
with: the battery certifying M2 drove `__getitem__` and `__contains__`
during iteration but never `get`, so the instrument shared the blind spot
of the fix it certified.

Also on the record, because the record is the point: run 1's closing
script reused a path variable and overwrote BACKLOG.md with PLAN.md's
contents - committed, then caught by reading the ledger back rather than
trusting the write, and recovered from the prior checkpoint with nothing
lost.

## Upstream

Nothing filed. The campaign's bar for an upstream PR is a novel,
genuinely High finding with an amazingly simple fix; this run's ceiling
was Medium, and the iterator-freeze Mediums are behaviour-boundary
decisions that belong to the maintainer, not drive-by patches.
