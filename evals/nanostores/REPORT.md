# Jeffy eval: nanostores/nanostores

The 7,590-star framework-agnostic state manager (React, Vue, Svelte,
Solid, vanilla), from the same author as nanoid, which converged in
wave 7. Run 2026-09-01/02 as wave 11 (COHORT-WAVE11.md). **2 runs, 18
iterations, converged** in round 2 at
`5d2c0e8cb20a4b4fb9e5acba8fc8ba4833b094dc`, within a **pre-registered
budget of 5 rounds of 10**.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `8f65da3cab6a74255d29d9907e07ccc1679ba265` (1.5.2) |
| Findings closed | **12** - 2 High, 9 Medium, 1 Low |
| Shipped-code change | 26 files, **+698 / -56** |
| Surface inventory | **20 of 20 rows swept** |
| Ledger at convergence | 5 Lows carried |
| Evaluator | **1 invocation: PASS** |
| Suite at convergence | `pnpm test` green, `test:coverage: pass 80`, `check-claims` 26 checked / 0 mismatched |
| Upstream | [PR #425](https://github.com/nanostores/nanostores/pull/425) (NS-1) and [PR #426](https://github.com/nanostores/nanostores/pull/426) (NS-2), both **merged 2026-09-02** by the maintainer as `95cf91b` and `9ec8262`, slated for the next minor release |

## What the loop found

- **`NS-1` (High, correctness)** - `batch()` called from inside a store
  listener re-invoked listeners that had already run in the same flush.
  Reproduction: two listeners on one atom, the first calls `batch()`,
  output `A,A,B`. The listener queue was drained by index and `batch()`
  re-entered `drainQueue` from its `finally` block before the index had
  moved past the entry being run. The fix advances `lqIndex` before the
  listener is called and resets it only after the queue empties. Filed
  upstream as PR #425.
- **`NS-2` (High, correctness)** - the unbind returned by lifecycle `on()`
  was not idempotent: a second call got `indexOf` -1, and `splice(-1, 1)`
  silently detached a different listener; a third threw `TypeError` on the
  already-deleted event list. `atom.listen()`'s unbind is already a no-op
  on repeat, so the two now match. Filed upstream as PR #426.
- **`NS-3` (Medium)** - `effect()` never cleared `lastRunUnbind` after
  running it, so disposing twice ran the cleanup twice.
- **`NS-4` (Medium)** - `listenKeys` missed a nested-path key when its
  parent was replaced through `setKey`.
- **`NS-5` (Medium)** - `cleanTasks()` zeroed the counter but never
  settled outstanding `allTasks()` waiters, and an end function called
  after a clean drove the counter negative so every later `allTasks()`
  hung.
- **`NS-6`, `NS-15` (Medium)** - `map().setKey` and `getPath` read
  caller-supplied keys through the prototype chain, so a key named
  `constructor` or `toString` behaved as though the inherited value were
  the store's own.
- **`NS-7` (Medium)** - two throwing listeners in one flush: the first
  error was discarded unlogged.
- **`NS-12` (Medium)** - `setPath({a:'ab'}, 'a.b', 1)` spread the string
  leaf into indexed character keys instead of replacing it.
- **`NS-14` (Medium)** - `onMount` and `effect` stored whatever the
  callback returned and called it later, where the documented contract is
  a cleanup function or nothing.
- **`NS-8` (Medium, packaging)** - `npm pack` shipped the loop's own state
  files, because `.npmignore` named no such file and npm ignores
  `.gitignore` entirely once `.npmignore` exists. This one the loop
  caused; see below.
- **`NS-9` (Low)** - `deepMap().setKey` compared with `!==` instead of the
  store's own `eq`, so NaN over NaN notified every time.

Five Lows are carried: a `batched()` recompute scheduled on a timer that
mount teardown never clears; `warn()` calling `console.groupCollapsed`
after guarding only `console.warn`; three non-deprecated exports absent
from the README guide; and two about the run's own notes and batteries.

## What the loop got wrong

`NS-8` is a defect the loop introduced into the tree it was auditing:
with `.npmignore` present, npm ignores `.gitignore`, so a pack from the
working tree carried 71 loop paths. The loop found it on its own sweep of
the packaging row, fixed it, and the evaluator installed the packed
tarball into a fresh package and exercised all 28 exports to confirm.
Same class as memchr's "crate shipped loop state"; the engine's own
ignore-file handling is the root and is on the backlog.

## Two PRs, both proved before filing

Both Highs were reproduced red at upstream HEAD in a fresh clone with the
new tests alone, then green with the one-file fix, under `pnpm test` and
`pnpm bnt`. The in-tree fixes were rewritten to the smallest diff before
filing; the loop's versions carry more tests and comments than a
maintainer needs.
