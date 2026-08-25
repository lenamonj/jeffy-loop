# Journal

Append-only. One primary entry per iteration; SALVAGE and ROTATION entries are additional. Never rewrite past entries (filling the current entry's Checkpoint field is completion, not a rewrite).

Heading grammar, exactly (fenced and indented here so this example is never mistaken for an entry by anything that counts or rotates them):

```
  ## iter <i>/<N> | <run-id> | <YYYY-MM-DD> | <task-id or AUDIT or SWEEP or EVALUATOR or RATCHET or WRAPUP or SALVAGE or ROTATION> | <done|blocked|audit|converged|salvage|rotation>
```

Write a real heading at column zero, never indented: the indentation above belongs to the example alone, and an indented heading is invisible to the rotation anchor and to the archive counter, so the entry under it is not counted and not rotated.

A SWEEP entry is an iteration spent sweeping Surface inventory rows and takes status done. SALVAGE entries take status salvage; ROTATION entries take status rotation. An EVALUATOR entry records an evaluator-gate iteration: status audit when the run continues after the verdict, blocked on a terminal REJECT (one with no invocation remaining), converged when that same iteration declares.

run-id is the first 8 characters of the session id, a hyphen, then the HHMMSS of started_at from the loop state frontmatter, so two runs in one session are told apart. Body fields, in order: Task, Changed, Checkpoint (the jeffy checkpoint commit hash, or none with the reason), Verification, Learnings, Next.

The closing entry that declares convergence carries the evaluator verdict in its Verification field: `Evaluator: PASS - <one-line summary>`. `Evaluator: unavailable (<reason>)` is recorded when no sub-agent can be spawned, and it is not a verdict a run declares on: the Stop hook refuses it and the run ends blocked until a relaunch where the gate can run. An earlier EVALUATOR entry records its own verdict the same way and never stands in for the closing one: the Stop hook reads the closing entry alone, so a run that gates early and keeps working re-invokes the gate at the declaration.

Closed tasks are recorded here as one line each (ID, title, closing evidence), because BACKLOG.md deletes them. Rotation: when this file exceeds 500 lines, move all but the last 10 entries to the end of JOURNAL-archive.md, appending to whatever that file already holds and never overwriting it, because the archive accumulates across every rotation and every run; create it only when it does not already exist, and record the rotation as a ROTATION entry.

## iter 1/10 | e0a6bc35-232724 | 2026-08-24 | AUDIT | audit

Task: bootstrap audit of underscore 1.13.8 - fill the Operating envelope, enumerate the artifact-producing channels, fill the Verify command with its Oracle class and Environment fingerprint, enumerate the whole Surface inventory, and probe it breadth-first.

Changed: PLAN.md (envelope surfaces, 23 Surface inventory rows, Verify command block), BACKLOG.md (5 findings, 1 Proposed), .jeffy/probes/proto-key-class/ and .jeffy/probes/publish-channels/ (acceptance batteries), .gitignore (loop state), JOURNAL.md.

Checkpoint: 1edea0f64b879d01b44c080b032b51f277c8917d

Verification: `npm ci` then `npm test` exits 0 in 7.7s with 208 passing assertions, 0 failed, 0 skipped. The tested artifact is the built CommonJS bundle: `require('..')` resolves through the package `exports` map to `underscore-node.cjs`. Confirmed that edits to `modules/` reach it - replacing `modules/identity.js` with a marker implementation and running `npm run bundle` made `require('..').identity('x')` return `JEFFY_PROBE_x`, and restoring the file returned the tree byte-clean, so the bundle step is deterministic and does not dirty the working tree.

Surface inventory: 23 rows written, 0 swept. Verified the map is a clean partition - running every row's own enumeration command covers 161 of 161 files in `modules/` with zero duplicates.

Artifact channels, enumerated by command rather than recall: `package.json` (`files` allowlist) -> npm; `bower.json` (`ignore` denylist) -> bower; `CNAME` plus the `gh-pages` branch -> GitHub Pages; `.github/workflows/*.yml` -> CodeQL analysis only, no publish step; no Dockerfile, MANIFEST.in, pyproject.toml, gemspec or nuspec exists. npm passes: `npm pack --dry-run --json` lists 503 files and none of PLAN.md, BACKLOG.md, JOURNAL.md, JOURNAL-archive.md or `.jeffy/`. bower fails and is filed as U3. GitHub Pages cannot be fixed from `master` and is filed under Proposed.

Dimension scores, claiming only what this audit examined and explicitly not the 23 unswept rows: correctness High (U1), testing Medium (U2), documentation Medium (U3 - the loop's own state shipped to bower consumers is misleading documentation in its most distributed form), dependency hygiene Medium (U4), code quality Low (U5), architecture None, security None (the `__proto__` class is filed for wrong results rather than for a reachable exploit: `_.extend` re-parents only the destination object and never `Object.prototype`, and `_.template` injection is out of envelope by the project's own SECURITY.md), error handling None, performance None, developer experience None. Observability does not apply - a synchronous utility library with no runtime logging or metric surface. UX and accessibility apply only to the `index.html` documentation site, which no row has swept yet.

Evidence for U1: `_.memoize(f)('__proto__')` returns `{}` instead of `f('__proto__')` and re-invokes `f` on every call because assigning a string to `cache['__proto__']` is ignored by the prototype setter and `has(cache, '__proto__')` is therefore never true; `_.groupBy([1,2,3], () => '__proto__')` yields `[3]` instead of `[1,2,3]`; `_.countBy` yields `{}` instead of `3`; `_.invert({a:'__proto__'})` and `_.object(['__proto__'],['x'])` yield objects with no own key. `index.html` mentions `__proto__` zero times, so none of this is documented behaviour.

Both acceptance batteries were observed failing on the unfixed tree before being filed: `.jeffy/probes/proto-key-class/check.js` exits 1 with 8 named failures, `.jeffy/probes/publish-channels/check.js` exits 1 naming all four state files. Each battery records that pre-fix state in its own header and declares its `paths`.

Learnings: never write shell scratch output to a bare `/tmp/<name>.log` - a concurrent session in another project overwrote `/tmp/npmtest.log` between two reads in this iteration, and the second read showed another project's build output under this project's filename. The Node test suite runs against built artifacts, so a fix in `modules/` only takes effect after `npm run bundle`, which `npm test` performs itself via `prepare-tests`. `qunit test/` loads every `.js` under `test/` including `test/vendor/qunit.js` and `test/overrides.js`, in alphabetical order, which is why the `test/overrides.js` DataView replacement lands too late to matter here.

Next: U1, the only open High.

## iter 2/10 | e0a6bc35-232724 | 2026-08-24 | U1 | done

Task: U1 (High, runtime, correctness) - a computed key of `__proto__` resolved to the inherited accessor on `Object.prototype`, so every write of a data-derived key into an object underscore builds re-parented that object instead of recording an entry, and the entry was silently lost.

Changed: new `modules/_setKey.js`; routed the computed-key write through it in `modules/object.js`, `invert.js`, `countBy.js`, `groupBy.js`, `indexBy.js`, `memoize.js`, `mapObject.js`, `pick.js`, `_createAssigner.js` and `bindAll.js`; extended `.jeffy/probes/proto-key-class/` from 15 to 24 checks and widened its `paths`; documented the `_.extend` behaviour in `index.html`; BACKLOG.md (U1 deleted, Settled classes line added); the rollup bundles regenerated by `npm run bundle`.

Checkpoint: b1445708550d48d5c4407c79d5f5aad7c89e55ce

Verification: `.jeffy/probes/proto-key-class/check.js` exits 0 with 24 checks passed. Differential, run by copying the fixed modules aside and restoring the same paths from HEAD rather than by `git checkout`: against the pre-fix tree the same battery exits 1 with 15 named failures - `_.memoize` returning `{}` instead of the memoized value and never caching, `_.groupBy` keeping only the last member, `_.countBy` returning `{}`, and `_.invert`, `_.object`, `_.mapObject`, `_.pick`, `_.extend` and `_.clone` each dropping the entry and re-parenting their result. Verify gate green through quiet-verify at 8s with `# pass 208`, the same count as the previous checkpoint, so no existing assertion changed. `proto-key-class` is the only battery whose `paths` match this diff; `publish-channels` declares `package.json` and `bower.json`, which this diff does not touch.

Three of the new checks initially passed against the broken tree as well, because reading `obj.__proto__` returns whatever object was mistakenly installed as the prototype - a read-back assertion cannot see this defect at all. They were rewritten to assert own keys via `Object.keys` and prototypes via `Object.getPrototypeOf` before the differential was accepted, and the battery header now records that trap.

Class enumeration, produced by command rather than recall: `grep -rnE '\b(result|results|cache|obj|hash|memo)\[[^]]+\] *= *[^=]' modules/*.js` now leaves exactly four raw assignment sites, each settled in BACKLOG.md - `_setKey.js` (its own fallback), `map.js` and `unzip.js` (arrays written at numeric loop indices), and `_collectNonEnumProps.js` (keys drawn from the fixed `nonEnumerableProps` literal). `mixin.js` and `underscore-array-methods.js` write method names onto the `_` namespace rather than into a data accumulator and are settled with them.

Contract preserved: `_setKey` changes nothing for any key other than `__proto__` - it takes the plain-assignment branch - so no existing behaviour of `_.extend`, `_.pick`, `_.groupBy` or the rest moves. For `__proto__` the change makes each function do what its documentation already said: `_.extend` is documented as copying all of the properties in the source over to the destination, and it now copies that one as an own property instead of re-parenting the destination and copying nothing. `_.defaults` is unaffected either way, because it reads `obj[key] === void 0` first and the inherited accessor never returns undefined. The only behaviour a caller could have relied on and lost is using `_.extend` to set a prototype, which was never documented; `index.html` now states the new rule under `_.extend`. No Surface inventory row needed flipping - none is swept yet.

Learnings: a probe that reads a value back cannot detect a mis-set prototype, because the read returns the object that was installed as the prototype; assert own keys and prototypes instead. ES3 support is not an obstacle here - engines without the `__proto__` accessor treat it as an ordinary property name, so the guard is only needed where a feature test says it is.

Next: the queue puts the 23 unswept Surface inventory rows above the three open Mediums, so iteration 3 sweeps rows.

## iter 3/10 | e0a6bc35-232724 | 2026-08-24 | SWEEP | done

Task: sweep Surface inventory rows. The queue puts unswept rows above every open Medium, and 23 rows stood against 8 remaining iterations, so this iteration batched every row it could properly evidence.

Changed: new shared harness `.jeffy/probes/_lib/assert.js` and mutation discriminator `.jeffy/probes/_lib/discriminate.sh` with its manifest; eight new batteries - type-tags-basic, type-collections, type-buffers, deep-equality, object-keys, object-assign, object-paths, object-subset - and the class battery `coercion-safety` for the finding below; PLAN.md (7 rows flipped, recorded in the bookkeeping edit at this iteration's checkpoint hash); BACKLOG.md (U6, U7, U8, U9 filed). No module changed: the discriminator restores every file it mutates and rebuilds.

Checkpoint: 73e68b7a474eefd3147e41c29937b59adc78f9c2

Verification: 7 of 8 new batteries pass - type-collections 18 checks, type-buffers 51, deep-equality 48, object-keys 29, object-assign 37, object-paths 40, object-subset 32. type-tags-basic exits 1 on a real defect and its row stays unswept. Every battery was proven able to fail before its row was flipped: `.jeffy/probes/_lib/discriminate.sh` mutates one module each battery certifies, rebuilds, and requires a non-zero exit - all 8 mutations were CAUGHT, and each battery header now names its own mutation and the failures it produced. Verify gate green through quiet-verify at 7s with `# pass 208`. `proto-key-class` and `publish-channels` both re-ran; `publish-channels` still exits 1, which is open task U3.

Findings this sweep surfaced, filed at rubric severity in this same iteration:

U6 (High, runtime, correctness). `_.isFinite(Object.create(null))` throws `TypeError: Cannot convert object to primitive value`, where `_.isNumber`, `_.isString`, `_.isObject`, `_.isNaN` and every other predicate return an answer for the same value. A type predicate is total by contract, and `index.html` documents this one as returning true or false. The value is ordinary: `require('querystring').parse('a=1')` returns a prototype-less object on this Node, and prototype-less dictionaries are the idiomatic defence against exactly the `__proto__` problem iteration 2 fixed. `_.escape` and `_.unescape` throw on the same values through their own `'' + string` coercion, which makes three instances of one root cause, so it is filed as one class task under the three-strike rule rather than as three patches. The enumeration is produced by driving every exported function against a prototype-less object and its same-content plain counterpart, never by grepping for coercion sites, because a coercion hides behind `+x`, `'' + x` or a call into a global and a name scan sees none of them; `.jeffy/probes/coercion-safety/check.js` exits 1 today naming exactly escape, isFinite and unescape.

U7 (Medium, docs). `index.html` says `_.isFinite` "Returns true if object is a finite Number" while `test/objects.js` pins `_.isFinite('12')` true under the comment "Numeric strings are numbers", and `_.isFinite([1])` is true as well. The coercion is intended; the sentence is what is wrong.

U8 and U9 (Low, docs and test). `test/utility.js` names a test `result does use the fallback ...` while its assertion checks that the fallback is not used, which is what `index.html` and `modules/result.js` both specify. `index.html` calls `_.create` "Basically `Object.create`" while `_.create(null)` returns a plain object. Both are filed Low with the rationale on their ledger lines.

Two of this iteration's own expectations were wrong and were corrected against the pinned contract rather than filed: `_.isFinite([1])` is true because the function coerces, and an object inheriting `Map.prototype` reads as a Map because detection follows the inherited `Symbol.toStringTag`. A third, `_.create(null)`, turned out to be pinned by the suite and became U9 rather than a correction.

Learnings: three of the first batch of checks passed against deliberately broken code, so a battery is not evidence until it has been observed failing - the mutation discriminator now makes that a command rather than a habit. A differential over "throws or not" must hold content constant and vary only the property under test, or it reports every function that merely needs a non-empty argument. Tab-separate any manifest whose fields contain JavaScript, because `||` and `|` are ordinary source text.

Next: U6 is an open High and outranks the remaining 16 unswept rows.

## iter 4/10 | e0a6bc35-232724 | 2026-08-24 | U6 | done

Task: U6 (High, runtime, correctness) - a value with no path to a primitive made `_.isFinite`, `_.escape` and `_.unescape` throw `TypeError: Cannot convert object to primitive value`, where the same call on a plain object of the same shape succeeded.

Changed: new `modules/_safeToString.js`; `modules/_createEscaper.js` routes its string coercion through it; `modules/isFinite.js` guards its numeric coercion and answers `false`; two mutations added to `.jeffy/probes/_lib/mutations.txt`; BACKLOG.md (U6 deleted, Settled classes line added); the rollup bundles regenerated.

Checkpoint: c7ac72b0bad999e8376dc5630a569030f5c933e4

Verification: both acceptance checks pass - `.jeffy/probes/coercion-safety/check.js` 32 checks, `.jeffy/probes/type-tags-basic/check.js` 42 checks. Differential, run by copying the three files aside and restoring the same paths from HEAD: against the pre-fix tree `coercion-safety` exits 1 with 3 failures, and `_.template('<%- x %>')({x: require('querystring').parse('a=1')})` throws `TypeError: Cannot convert object to primitive value`; after the fix that same template renders `[object Object]`, which is what it renders for a plain object. Verify gate green through quiet-verify at 9s with `# pass 208`, unchanged from the previous checkpoint. Every battery whose `paths` file names a path in this diff was re-run - `coercion-safety` and `type-tags-basic`, both green - and a check over the swept rows' `paths` files confirmed none of them declares a changed path, so no swept row went stale. `.jeffy/probes/_lib/discriminate.sh` re-ran the whole set: all 10 batteries CAUGHT their mutation.

Reachability, driven rather than asserted: `require('querystring').parse('a=1')` returns an object whose prototype is `null` on this Node, and `_.template`'s escaping delimiter `<%- %>` calls `_.escape` on the interpolated value, so a template rendering parsed query data threw before this fix. That is the path that makes the class High rather than a robustness nicety.

Contract preserved: `_.isFinite` keeps every answer `test/objects.js` pins - `5` true, `'12'` true, `[1]` true, `Infinity` false, `NaN` false, `null` false, symbols false - and only the throw becomes `false`, which is the answer a predicate documented to return true or false owes. `_.escape` and `_.unescape` are unchanged for strings, their round trip still holds, and a prototype-less object now yields `[object Object]`, byte-identical to what `'' + {}` already produced for a plain object, so the new branch introduces no string the old code could not also emit. No documentation changed: `index.html` documents `_.isFinite` as returning true or false and `_.escape` as taking a string, and both sentences describe the fixed behaviour rather than the old one. The separate wording defect in the `_.isFinite` entry is open as U7 and untouched here.

Learnings: a manifest parsed line by line cannot carry a multi-line anchor - the first attempt at a discriminating mutation for `isFinite` spanned three lines and produced four SETUP-FAIL rows before being rewritten as a single-line anchor.

Next: 16 rows remain unswept and the ledger holds no open High, so the map is top of the queue again.

## iter 5/10 | e0a6bc35-232724 | 2026-08-24 | SWEEP | done

Task: sweep Surface inventory rows. 15 rows stood against 6 remaining iterations, so this iteration batched every row it could properly evidence.

Changed: ten new batteries - iteratee-core, html-escaping, templating, utility-misc, function-limiting, finders, collection-iteration, collection-aggregation, array-slicing, array-sets - each with its `paths` file and its mutation in `.jeffy/probes/_lib/mutations.txt`; `.jeffy/probes/_lib/discriminate.sh` hardened; PLAN.md (10 rows flipped in the bookkeeping edit at this iteration's checkpoint hash). No module changed: the discriminator restores every file it mutates and rebuilds.

Checkpoint: d0be54dd1f2846f7cae1494f94fc4ee594635b5b

Verification: all ten batteries pass - iteratee-core 29 checks, html-escaping 35, templating 30, utility-misc 20, function-limiting 29, finders 45, collection-iteration 45, collection-aggregation 32, array-slicing 51, array-sets 42. Each was proven able to fail before its row was flipped, and `.jeffy/probes/_lib/discriminate.sh` reports CAUGHT for all 20 batteries in the manifest. Verify gate green through quiet-verify at 9s with `# pass 208`. No finding was surfaced by this sweep: every check that failed on first run was my own expectation being wrong, corrected below against the pinned contract.

The discriminator was hardened this iteration because it graded a battery too generously. Mutating `modules/chunk.js` to drop its `count < 1` guard turned `_.chunk(a, 0)` into an unbounded loop, so the battery died and exited non-zero with no named failure - which the script counted as CAUGHT. A battery that dies is not a battery that detected: the script now reports CRASHED separately and fails the run, and array-slicing's mutation was swapped for one in `modules/range.js` that produces two named failures.

Five expectations of mine were wrong and were corrected against the behaviour the suite and the documentation pin, rather than filed as findings. Overriding `_.templateSettings.interpolate` does not make `<%= x %>` literal text: `<%= %>` is a strict prefix of `<% %>`, so the default evaluate delimiter still claims it and compiles it as code, and switching a delimiter off takes an explicit null. A name absent from the template data throws inside `with`, so the pinned empty-string case needs the key present with an undefined value. `_.reduce([], fn)` returns undefined where native `Array.prototype.reduce` throws, and `test/collections.js` pins that while index.html makes no claim. `_.range(5, 0)` counts down, because with no step the direction is inferred from the operands. And `_.sortedIndex` with a different iteratee only means anything over a list sorted by that iteratee - my first version searched a list that was descending under the second key, which is a binary search over unsorted input rather than a defect.

Learnings: when a battery check fails, the first question is whether the expectation or the code is wrong, and the answer lives in the test suite and index.html rather than in recollection - five of this iteration's failures were mine and none were the project's.

Next: 5 rows remain unswept - function-binding, function-timing, collection-misc, oop-chaining, build-packaging - and the map still outranks the four open Mediums.

## iter 6/10 | e0a6bc35-232724 | 2026-08-24 | SWEEP | done

Task: sweep the last 5 Surface inventory rows - function-binding, function-timing, collection-misc, oop-chaining, build-packaging.

Changed: five new batteries with their `paths` files and mutations; `.jeffy/probes/_lib/assert.js` gained a `guard` helper; BACKLOG.md (U10 filed); PLAN.md (5 rows flipped in the bookkeeping edit at this iteration's checkpoint hash). No module changed.

Checkpoint: 9ef5218cab434c9682cfff5ed476d59886c836a0

Verification: all five pass - function-binding 32 checks, function-timing 21, collection-misc 1033, oop-chaining 29, build-packaging 24. Every battery in the tree was re-run: 24 of 25 green, and the one red is `publish-channels`, which is open task U3. `.jeffy/probes/_lib/discriminate.sh` reports CAUGHT for all 25 mutations with no BLIND and no CRASHED. Verify gate green through quiet-verify at 7s with `# pass 208`. The Surface inventory now lists no unswept row.

The CRASHED check added in iteration 5 earned itself immediately. The first mutation for oop-chaining - making `_chainResult` return the raw value - broke `.value()` so thoroughly that the battery died on a TypeError before reporting anything, and the old script would have scored that as CAUGHT. Rather than weaken the mutation, the shared harness gained `guard`, which runs a block of checks and converts an unexpected throw into a named failure; the chaining, array-proxy, mixin and chained-call-survey blocks now run inside it. The battery reports 4 named failures under that mutation instead of dying.

What the last five rows exercise, beyond the obvious: `function-binding` drives `_executeBound` on both its paths, since `bind` behaves differently under `new`, and drives `partial`'s placeholder in several positions because one position hides an off-by-one in the fill loop. `function-timing` drives both settings of every documented option - throttle's `leading` and `trailing`, debounce's `immediate` - because each is invisible at the other setting, with waits at three times the window so the assertions are about behaviour rather than jitter. `collection-misc` checks the samplers by invariant over hundreds of draws: `shuffle` must return a permutation every time and never modify its input, `sample(n)` must return n distinct members of the input, and `sample` must reach every member. `oop-chaining` asserts over the whole exported surface rather than a sample - every exported function must also be a wrapper method - which turned up that `_._` is the one name correctly absent, being the library object re-exported as the default `_.partial` placeholder. `build-packaging` checks the invariants a consumer's install rests on: every concrete path in the `exports` map exists and is inside the tarball, the version agrees across package.json, `_setup.js` and the loaded bundle, every name `modules/index.js` exports is present on the built bundle, and rebuilding a clean tree leaves it clean.

U10 (Low, runtime, error handling) filed: `_.compose()` with no arguments builds a function that throws `TypeError: Cannot read properties of undefined (reading 'apply')` at call time, because `args[args.length - 1]` is `args[-1]`. Neither the documentation nor the suite covers the empty case. The rationale for Low rather than Medium is on the ledger line and rests on the envelope's user-error class for library function arguments. The function-binding battery pins the current behaviour with a comment saying so, rather than pinning the answer the fix will produce, so the row could be swept honestly; the acceptance check requires that battery to be updated in the same iteration as the fix.

Learnings: an instrument that dies under a mutation is reporting the mutation's violence, not its own sensitivity; wrap fragile blocks so a throw becomes a named failure.

Next: the map is complete, so the queue is the four open Mediums - U2, U3, U4, U7 - with U2 at the top.

## iter 7/10 | e0a6bc35-232724 | 2026-08-24 | U2 | done

Task: U2 (Medium, test, testing) - the IE 10 to Edge 13 and IE 11 detection fallbacks had no coverage in the only gate that runs here. `_stringTagBug.js` decides once at module load whether they are needed, so `test/overrides.js`, which exists to force them, cannot reach them in the node runner: it loads alphabetically, long after `test/arrays.js` has already required underscore.

Changed: new `test-legacy/detection.js`, a child-process probe that doctors the environment and reports what the detection answers; new `test/legacy-detection.js`, the QUnit module that spawns it per case and asserts; PLAN.md Environment fingerprint updated, because the fix invalidated its standing claim that those branches are unreachable here. No module changed.

Checkpoint: 57e03a7dbdf068e85ae8644591863128a04c4e92

Verification: `npx qunit test/legacy-detection.js` exits 0 with 3 ok lines and 17 assertions, which is the acceptance check as filed. Verify gate green through quiet-verify at 8s with `# pass 211`, up from 208 at the previous checkpoint by exactly the three new tests. No battery declares any path this diff touched, checked by matching every battery's `paths` file against the changed paths, so no swept row went stale.

The fallbacks now execute and answer correctly. Under the simulated IE 10 to Edge 13 environment - `Symbol.toStringTag` removed from `DataView.prototype` and the global constructor replaced with a non-native one, which is what makes `hasDataViewBug` true - `Object.prototype.toString.call(dataView)` really does report `[object Object]`, and `alternateIsDataView` still accepts a DataView while rejecting a typed array, an ArrayBuffer, a plain object and null. `isEqual` compares DataViews correctly through the `hasDataViewBug` branch it can only reach there. Under the simulated IE 11 environment, `isMap`, `isSet` and `isWeakMap` all answer correctly through `ie11fingerprint`, including the negatives that separate them from one another.

Two faults in the simulation had to be found and fixed before it could say anything, and both would have been reported as product defects by a less careful reading. Deleting the string tags alone made `_.isWeakMap(new WeakMap())` return false, because the fingerprint looks for `WeakMap.prototype.clear`, which IE 11 had and which was removed from the specification afterwards - so the check was being driven against a method surface no IE 11 ever presented. Restoring `clear` with a plain assignment kept it false, because the fingerprint rejects any object with enumerable keys and a plain assignment creates an enumerable one where every native prototype method is non-enumerable. Both corrections are written into `test-legacy/detection.js` beside the code that makes them. `WeakSet` is deliberately left untouched in that mode: IE 11 has none, so underscore keeps `isWeakSet` a plain tag tester with no fingerprint to reach, and doctoring it would have manufactured a third false failure.

Learnings: simulating a legacy environment means reproducing the surface the code under test reads, not only the symptom that triggers it - a tag and a method list here - and every prototype property a simulation adds must be defined non-enumerably, as the real one is.

Next: three Mediums remain - U3, U4, U7 - with three iterations left, so the evaluator gate and any declaration depend on whether U4's dev-toolchain migration can be scoped to one iteration.

## iter 8/10 | e0a6bc35-232724 | 2026-08-24 | U7 | done

Task: U7 (Medium, docs, documentation) - `index.html` documented `_.isFinite` as "Returns true if object is a finite Number", a sentence a reader takes for a type test, while the function coerces and `test/objects.js` pins that deliberately under the comment "Numeric strings are numbers".

Changed: the `_.isFinite` entry in `index.html` now states the coercion rule, steers a reader wanting a type test to `_.isNumber`, and carries six examples instead of two; `.jeffy/probes/type-tags-basic/check.js` gained an assertion per published example. No module changed.

Checkpoint: 58139078b985c82ace21b9177cefddde3cc19ec4

Verification: every example printed in the new entry was run exactly as published and produced exactly the documented answer - `-101` true, `'12'` true, `'1a'` false, `[1]` true, `[]` false, `true` false, `-Infinity` false - and the battery now pins all seven, so the documented answers cannot drift from the real ones. The steer to `_.isNumber` was driven rather than assumed: `_.isNumber('12')` is false where `_.isFinite('12')` is true, which is exactly the distinction the sentence promises. `.jeffy/probes/type-tags-basic/check.js` exits 0 with 49 checks, up from 42. Verify gate green through quiet-verify at 8s with `# pass 211`, unchanged from the previous checkpoint. The only battery owning a path this diff touched is type-tags-basic, which was re-run and whose row is re-recorded at this checkpoint hash in the bookkeeping edit.

The wording had to describe two conditions rather than one, because the implementation is a conjunction: the value's numeric conversion must be finite and its text form must begin with a number. That second clause is not decoration - it is why `[]` is false while `[1]` is true, and why `true` and `null` are false despite converting to 1 and 0. A sentence naming only the first condition would have been a second wrong description rather than a fix.

Learnings: a documentation fix is a publication, so every example it prints is run in the form it is published and its stated output is that run's real output; pinning the examples in a battery is what keeps the two from drifting apart later.

Next: two Mediums remain, U3 and U4, with two iterations left. U3 is a small packaging change. U4 is the dev-toolchain migration, which `npm audit fix --dry-run` shows resolves nothing without breaking changes, so it needs either a split into one-iteration slices or an honest disposition.

## iter 9/10 | e0a6bc35-232724 | 2026-08-24 | U3 | done

Task: U3 (Medium, build-ci, documentation) - only the npm channel excluded the loop's state files. `package.json` uses a `files` allowlist that omits them, but `bower.json` uses an `ignore` denylist that matched none of PLAN.md, BACKLOG.md, JOURNAL.md or JOURNAL-archive.md, so a bower consumer installing from a git tag would receive all four.

Changed: `bower.json` ignore list extended with the four state files and `.jeffy`; `.jeffy/probes/publish-channels/check.js` given gitignore-style ancestor matching and a reverse check; a mutation for that battery added to the manifest. No module changed.

Checkpoint: 7b6a63a0f056e95744b560fe6e73e3b04c90562c

Verification: `.jeffy/probes/publish-channels/check.js` exits 0. Differential, run by copying the fixed `bower.json` aside and restoring the committed one: against the pre-fix file the battery exits 1 naming all four state files, and after restoring the fix it exits 0. Verify gate green through quiet-verify at 8s with `# pass 211`, unchanged. Two batteries own a path this diff touched - `publish-channels` and `build-packaging`, both of which declare `bower.json` - and both were re-run green; the build-packaging row is re-recorded at this checkpoint hash in the bookkeeping edit. `discriminate.sh` reports no BLIND and no CRASHED across all 26 mutations.

The battery was matching patterns against whole paths, which is not what bower does: its ignore patterns are gitignore-like, so a bare directory name excludes everything beneath it. Under the old matching, `.jeffy/probes/proto-key-class/check.js` would have been reported as shipped while `.jeffy` sat in the list. The check now tests every ancestor prefix of a path, which also settles a claim the first audit made without proving it - that `.jeffy/` was already covered by the existing `.*` entry. The pre-fix differential confirms it: only the four `.md` files were ever named.

A denylist fix has a failure mode an allowlist does not, so the battery now also asserts the reverse: that `underscore-umd.js`, `underscore.js`, `modules/index.js`, LICENSE and README.md are still shipped. An ignore list widened until it swallowed the library would satisfy every other check in that file.

Learnings: when a check reimplements another tool's matching rules, it inherits the burden of matching them; gitignore-style patterns apply to ancestor directories, and a whole-path match silently disagrees. A denylist change wants an assertion in both directions.

Next: this is the last iteration of the budget. U4 remains the only open Medium, and its own filing records that `npm audit fix --dry-run` resolves none of the 80 advisories without breaking changes, so it cannot close in one iteration and the run cannot converge; the final iteration is a WRAPUP that scopes U4 into slices a later run can take.

## iter 10/10 | e0a6bc35-232724 | 2026-08-24 | WRAPUP | done

Task: final iteration of the budget. U4 was the only open Medium and could not close in one iteration, so this iteration split it on evidence and wrote the handoff rather than starting work that cannot finish.

Changed: BACKLOG.md - U4 replaced by U4a (open) and U4b (blocked, with its reason), and the browser-toolchain decision added under Proposed. No module changed, no battery changed.

Checkpoint: 9a1aa0981ee2b7ef988cdcca958c11c71d656fc8

Verification: Verify gate green through quiet-verify at 7s with `# pass 211`. The Surface inventory lists no unswept row. This iteration is a WRAPUP and changed only ledger state, which the stall rule exempts; the previous entry records a closed task, so no stall pair exists.

The split rests on two enumerations, both produced by command. Reading `npm test` through `lint`, `prepare-tests`, `bundle`, `bundle-treeshake` and `test-node` shows exactly three devDependencies on the gate's path: eslint, qunit and rollup. Aggregating `npm audit --json` up the effects graph to top-level packages shows where the 80 advisories actually live: karma-sauce-launcher reaches 20, karma 7, eslint 7, cpy-cli and coveralls 6 each, nyc and pretty-bytes-cli 3 each, qunit and patch-package 2 each.

A first attempt at the split was wrong and had to be discarded. Listing devDependencies that no npm script names produced cpy-cli, glob, gzip-size-cli, husky, karma-qunit, karma-sauce-launcher, eslint-plugin-import and pretty-bytes-cli, which reads like a list of removable packages. Every one of them is reached another way: cpy-cli, gzip-size-cli and pretty-bytes-cli by the binaries they install rather than by their package names, glob by an import in `rollup.config.js`, eslint-plugin-import by `modules/.eslintrc`, husky by the `husky` key in package.json, and the karma plugins by karma's own runtime resolution. That is the name-scan failure the Method warns about, met here in the ledger rather than in a fix: there are no unused devDependencies, so no slice of this task is free.

U4b is blocked rather than declined or downgraded, because both ways of closing it belong to the project owner. Retiring the SauceLabs and PhantomJS browser path removes a capability, which the Constraints forbid doing to make a metric pass; replacing it commits the project to a new browser-test toolchain. The Proposed entry states the choice and its cost. U4a is what remains genuinely actionable inside one iteration, and its acceptance check requires proving the ES3 lint gate survived rather than merely that the suite is green - an eslint upgrade that silently stopped enforcing `ecmaVersion: 3` would let ES5-only syntax into the shipped bundle while every test still passed.

Learnings: a list of dependencies no script names is not a list of unused dependencies - binaries, config-file plugin references, framework runtime resolution and package.json keys all reach a package without naming it in a script, so provoke the use rather than scanning for the name.

Next: the run ends out of budget with U4a open and U4b blocked. A relaunch in a fresh session starts on U4a; the four carried Lows and the two Proposed decisions are listed in the run report.

## iter 1/10 | a69c3ba6-002843 | 2026-08-24 | U4a | done

Task: U4a (Medium, build-ci, dependency hygiene) - the three devDependencies the verify gate executes, eslint, qunit and rollup, were all majors behind, and the upgrade had to preserve the ES3 lint contract that keeps ES5-only syntax out of the shipped bundle.

Changed: eslint 6.8.0 to 9.39.5 with `.eslintrc`, `modules/.eslintrc` and `test/.eslintrc` replaced by the flat config in `eslint.config.js`; eslint-plugin-import 2.20.1 to 2.32.0, which eslint 9 requires because 2.20.1 imports `eslint/lib/util/glob-util`, a path eslint 9 no longer exports; `globals` added as a devDependency, the flat-config replacement for the `env` block, and already present in the tree as an eslint dependency; qunit 2.10.1 to 2.26.0, keeping the exact pin the project had rather than adding a caret; rollup 2.40.0 to 4.62.5, with `preserveModules` moved from input to output options in both configs, `--bundleConfigAsCjs` added to the two `rollup -c` invocations in the `bundle` script, and `generatedCode.reservedNamesAsProps` plus a new `quoteEs3ReservedKeys` output plugin added to `rollup.common.js`. `test/utility.js` now calls `assert['throws']`. `bower.json` ignores `eslint.config.js`, keeping the bower channel's contents unchanged. The rebuilt bundles are tracked files and ride along. No module changed.

Checkpoint: 6ad019c94b860c650b1044f5d6c8cf3c3073c837

Verification: Verify gate green through quiet-verify at 8s with `# pass 211`, and all 26 probe batteries green, including the two that own a path this diff touched - build-packaging and publish-channels. The acceptance check holds on all three clauses: `npm test` exits 0 with 211 assertions, `npm audit --omit=dev` reports 0 vulnerabilities, and the ES3 gate rejects ES5-only syntax, tested on four constructs rather than one - a trailing comma in an object literal, an object getter, `{}.default`, and `{class: 1}` - each of which fails `npx eslint` under the new flat config. Total advisories fell from 80 to 70, and eslint, eslint-plugin-import, qunit and rollup no longer appear anywhere in `npm audit --json`.

The contract the rollup upgrade had to preserve is the built bundle, and it was checked rather than assumed. The `allExports` object in `underscore-umd.js` carries exactly the same 147 names before and after, and the runtime function surface of the built UMD bundle is identical at 145 functions, compared by requiring the committed pre-upgrade file and the new one in the same process. What did change is the shape rollup emits, and one of those changes was a real regression: rollup 3 and later emit reserved words as bare keys in their namespace objects, so `'default': _` became `default: _` and no ES3 engine could have parsed the file at all. `generatedCode.reservedNamesAsProps: false` does not reach that code path - it governs generated member access only, and rollup's namespace objects call `stringifyObjectKeyIfNeeded`, which quotes nothing that is a valid identifier. The `quoteEs3ReservedKeys` output plugin parses each rendered chunk with rollup's own `parseAst`, finds non-computed identifier keys that are ES3 reserved words, and quotes them. Its differential: with the plugin removed and the tree rebuilt, `eslint underscore-umd.js` fails with `2109:5 Parsing error: Unexpected keyword 'default'`; restored, it exits 0.

That differential is only available because the eslint upgrade made the gate stricter. Under eslint 6 the ES3 configuration caught a trailing comma and an object getter but accepted both `{}.default` and `{class: 1}`, so the bundle's ES3-ness in this respect was an accident of rollup 2's output rather than something the gate enforced. Eslint 9 rejects all four, which is what turned the rollup regression from something a human had to notice into something `npm run bundle` fails on.

The same new strictness exposed a pre-existing fault in the tests: `test/utility.js` used `assert.throws`, reserved-word dot notation that the file's own ES3 parse level forbids and eslint 6 never flagged. It is the only such site in `test/`, which is what says the ES3 intent for the test files is real and maintained rather than an artifact of `parserOptions: {}` merging with the root. Repaired in this iteration rather than reverted, with the differential recorded: stashing the one-line change and running `npm run test-node` on either side produces byte-identical per-test output and the same 211 assertions, so the change altered nothing that was passing.

The flat config is a translation of the old cascade, not a rewrite of it. The three resolved configurations were captured with `eslint --print-config` on `underscore-umd.js`, `modules/each.js` and `test/objects.js` before the migration, and the new file reproduces each: ES3 script parsing with the browser, node and amd globals everywhere; ES6 modules with the import plugin's five error rules and `no-mixed-operators` for `modules/*.js`; the QUnit global for `test/*.js`. The rule sets match exactly - no rule was enabled or dropped.

Learnings: rollup's `generatedCode` options do not govern its namespace objects, so an ES3 output contract needs its own check on the rendered chunk; and a lint gate that has never been observed rejecting the thing it exists to reject may not be rejecting it - four discriminating inputs found that two of them passed under the old parser.

Next: no open Medium remains; U4b is blocked on the browser-toolchain decision under Proposed. Four Lows are open - U8, U9, U10, U5 - and the Surface inventory has no unswept or stale row. The next iteration is a full fresh-evidence audit, since convergence needs one on this run's record and no audit has run this run.

## iter 2/10 | a69c3ba6-002843 | 2026-08-24 | U10 | done

Task: U10 (Low, runtime, error handling) - `_.compose()` with no arguments returned a function that threw `TypeError: Cannot read properties of undefined (reading 'apply')` when called, because `args[args.length - 1]` is `args[-1]`, deferring the throw to call time so the stack pointed away from the mistake.

Changed: `modules/compose.js` returns `identity` when it is handed no functions; `index.html` documents that case in the `_.compose` entry; `test/functions.js` pins it with one assertion; `.jeffy/probes/function-binding/check.js` replaces the old throws-pin with two guarded checks of the new contract; `.jeffy/probes/_lib/mutations.txt` gains the mutation that discriminates them. PLAN.md's Oracle class and the `Later` ordering in BACKLOG.md were also corrected, both explained below.

Checkpoint: 622d04f7932808e829cf2e702e9ee56c8d5c563d

Verification: Verify gate green through quiet-verify at 8s with `# pass 211`. Acceptance holds on all three clauses: `_.compose()(7)` returns 7, `.jeffy/probes/function-binding/check.js` exits 0 at 33 checks, and `npm test` exits 0. The one battery owning a path this diff touched is function-binding, re-run green and re-recorded at this checkpoint; iteratee-core also declares `modules/identity.js`, which this diff imports but does not modify, and it was re-run green anyway. `discriminate.sh` reports 27 of 27 mutations CAUGHT with no BLIND, CRASHED or SETUP-FAIL.

The contract preserved is the composition itself: every non-empty case still applies right to left, still forwards all call-site arguments to the innermost function, and still calls each function with the caller's `this`; only the empty case changed, from a deferred TypeError to the identity function, which is what composing nothing means. Returning the shared `identity` rather than a fresh closure follows the precedent already in the tree - `modules/_baseIteratee.js` returns the same shared `identity` for a null iteratee - and keeps the branch off the hot path, since it is taken at composition time rather than on every call of a composed function. `_.compose` has no callers inside `modules/`, so the only consumers are external, and the documentation was updated in this same iteration.

The battery's first version of these checks was wrong in a way the discrimination sweep caught. Unguarded, `t.eq('compose of nothing is the identity function', _.compose()(7), 7)` does not fail under the mutation that restores the old behaviour - it dies, because the subject throws before the assertion can record anything, and `discriminate.sh` reported CRASHED rather than CAUGHT. Wrapping both checks in `t.guard` turns that throw into a named failure, and the sweep now reports `FAIL empty composition: block aborted with an unexpected throw - Cannot read properties of undefined (reading 'apply')`. That is the pre-fix state this row's battery is recorded as having been observed failing on.

PLAN.md's Oracle class was wrong about what the verify gate counts, and this iteration is where it showed. Adding one assertion to the existing `compose` test left `# pass 211` unmoved, because QUnit's TAP reporter emits one `ok` line per test and closes with `1..211`: the figure is tests, not assertions. Every earlier entry that called it an assertion count, including this run's own iteration 1 entry, was mislabelling it. The real assertion total is not printed by either built-in reporter and had to be measured by hooking `QUnit.testDone`, which gives 1705 passing assertions across 211 tests; stashing this iteration's one-line test change and re-running moves that to 1704 with the test count unchanged, which is both the correction's evidence and the proof the new assertion executes. The Oracle class now states both figures and says which one the summary pattern reports; U8's acceptance line, which had inherited the same error, now reads tests.

BACKLOG.md's `Later` section was also out of order against its own rule - severity first, then runtime before the other classes - listing the test and docs Lows above the runtime ones. Reordered to U5, U8, U9, which is why U10 rather than U8 was the top unblocked item this iteration.

Learnings: `# pass <n>` from `qunit test/` counts tests and not assertions, so the wrapper's green line must never be quoted as an assertion count; and a check whose subject throws under a mutation needs `t.guard`, or the discrimination sweep reports CRASHED and the check proves nothing.

Next: three Lows remain - U5, U8, U9 - and U4b stays blocked on the browser-toolchain decision under Proposed. The Surface inventory has no unswept or stale row. Working the three Lows first and then running the closing full audit keeps the declaration's "only commits since that clean audit" condition satisfiable; auditing first would strand the Lows.

## iter 3/10 | a69c3ba6-002843 | 2026-08-24 | U5 | done

Task: U5 (Low, runtime, code quality) - `modules/isEqual.js` imported `random` and `uniqueId` and used neither, and nothing in the lint configuration would ever say so.

Changed: the two dead imports removed from `modules/isEqual.js`, and the Map-based cycle tracker's `abort` now takes no parameters; `eslint.config.js` enables `no-unused-vars` for `modules/*.js` and `test/*.js` with `caughtErrors: 'none'`; PLAN.md's Oracle class now names the rules the eslint pass actually runs. The rebuilt bundles ride along.

Checkpoint: fbfbc7f78a0e6353b6582fa7e6d5b5f7d6a48782

Verification: Verify gate green through quiet-verify at 10s with `# pass 211`. Acceptance holds on both clauses: `npx eslint --rule '{"no-unused-vars":["error",{"caughtErrors":"none"}]}' modules/*.js` exits 0 with no output, and `npm test` exits 0. The two batteries owning a path this diff touched, deep-equality for `modules/isEqual.js` and build-packaging for `eslint.config.js`, were re-run green at 48 and 24 checks and are re-recorded at this checkpoint.

The acceptance asks for a scan reporting zero, and a scan that runs once answers for one moment, so the fix is the rule rather than the removal: `no-unused-vars` is now part of `npm run lint`, which `npm test` runs first. Its differential is direct - re-adding `import random from './random.js';` to `modules/isEqual.js` makes `npx eslint modules/*.js` exit 1 with `11:8 error 'random' is defined but never used`, and removing it again returns exit 0.

Enabling the rule surfaced two things the finding had not. Three modules and two test files carry a `catch (e)` whose binding is never read, and that is not dead code: ES3 has no optional catch binding, and ES3 is the level `underscore-umd.js` and every file under `test/` are parsed at, so the binding cannot be dropped. `caughtErrors: 'none'` is the exemption, and it is scoped rather than global. The rule is also not enabled for `underscore-umd.js`, whose configuration deliberately runs no rules and exists only as a parse-level ES3 gate; putting a rule in the base config would have applied it to rollup's generated output.

The second was two dead parameters on the Map-based tracker's `abort`, which the fallback tracker below it declares as `abort: function()` and which every one of the sixteen call sites invokes as `tracker.abort()` with no arguments - `grep -nE "abort\([^)]" modules/isEqual.js` returns nothing. `cycleTracker` is a local function in that module and is not exported, so the signature is internal and the two implementations now agree with each other and with their callers.

The contract preserved is the built bundle. Sorting the non-blank lines of `underscore-umd.js` at HEAD and after the change leaves exactly one difference, the `abort` signature; the 36-line diff is module reordering, because `modules/isEqual.js` no longer pulls `random.js` and `uniqueId.js` in ahead of itself. Both still ship and still work - `_.random(5, 5)` is 5 and `_.uniqueId('a')` is `a1` from the built bundle - and the bundle's function surface is identical to HEAD's at 145 names, compared by requiring both files in one process. The monolithic builds set `treeshake: false`, so nothing was ever being dropped from them; the imports were dead in the source only.

Learnings: `no-unused-vars` on an ES3-targeted tree needs `caughtErrors: 'none'`, because the language has no optional catch binding and every `catch` must name a variable it may never read.

Next: two Lows remain, U8 and U9, and U4b stays blocked on the browser-toolchain decision under Proposed. The Surface inventory has no unswept or stale row. Working U8 and U9 in the next two iterations leaves four for the closing sequence - the full audit, the evaluator gate, and the declaration.

## iter 4/10 | a69c3ba6-002843 | 2026-08-24 | U8 | done

Task: U8 (Low, test, testing) - `test/utility.js` named a test `result does use the fallback when the result of invoking the property is undefined` while its one assertion checks that the fallback is not used, so the label invited a maintainer to change the code to match it.

Changed: that test is now named `result does not use the fallback when a present function returns undefined`. No module, no battery, no documentation changed.

Checkpoint: 8f2776b4bf1b5b6f08d5f065a30820bcfcecfb28

Verification: Verify gate green through quiet-verify at 8s with `# pass 211`. Acceptance holds on both clauses: the name states what the assertion checks, and `npm test` exits 0. The tallies are unmoved on both axes - 211 tests and 1705 assertions, measured through the `QUnit.testDone` hook - which is what a rename should do and is the evidence that nothing but the label moved. The TAP line now reads `ok 202 Utility > result does not use the fallback when a present function returns undefined`. No battery declares `test/utility.js` in its paths file, so none owns this diff; `object-paths`, which owns `modules/result.js`, was run green at 40 checks for context but its subject did not change and its row is not re-recorded.

The behaviour was re-derived rather than taken from the ledger line. `_.result({a: function() {}}, 'a', 'failed')` returns `undefined`, while `_.result({}, 'a', 'failed')` and `_.result({a: undefined}, 'a', 'failed')` both return `'failed'`: the fallback answers a property that is undefined, never a present function whose invocation returns undefined. `modules/result.js` reads the property before invoking it and substitutes the fallback only at that point, and `index.html` says the default is returned when "the property doesn't exist or is undefined", so the module, the published documentation and the assertion all agreed and only the test name dissented.

The replacement wording is the wording `.jeffy/probes/object-paths/check.js` already used for the same behaviour, so the two instruments that pin this case now read identically instead of contradicting each other. The old string appears nowhere else in the tree outside the ledger and the journal, checked across everything but `node_modules`, `.git` and the generated `amd/` and `cjs/` trees.

Learnings: none beyond the entry - a rename that moves neither the test count nor the assertion count is its own evidence that only the label changed.

Next: one Low remains, U9, on the `_.create` entry in `index.html`; U4b stays blocked on the browser-toolchain decision under Proposed. The Surface inventory has no unswept or stale row. Working U9 next leaves five iterations for the closing sequence - the full audit, the evaluator gate, and the declaration.

## iter 5/10 | a69c3ba6-002843 | 2026-08-24 | U9 | done

Task: U9 (Low, docs, documentation) - the `_.create` entry in `index.html` said "Basically, `Object.create`, but without all of the property descriptor jazz" and stopped there, while `_.create(null)` returns a plain object where `Object.create(null)` returns a prototype-less one.

Changed: the `_.create` entry in `index.html` now states where the two part company and carries two worked examples; `.jeffy/probes/object-assign/check.js` drives the whole enumeration behind that sentence and pins both published examples; `.jeffy/probes/_lib/mutations.txt` gains the mutation that discriminates it. No module changed.

Checkpoint: cad4d74b2f716c632e8096d341a0262cd9a3021a

Verification: Verify gate green through quiet-verify at 8s with `# pass 211`. Acceptance holds on both clauses: the entry names the non-object-prototype case, and `npm test` exits 0. No battery declares `index.html` in its paths file, so no module row went stale; `object-assign` is re-recorded because its own battery grew from 37 to 41 checks. `discriminate.sh` reports 28 of 28 mutations CAUGHT with no BLIND, CRASHED or SETUP-FAIL.

The new sentence generalises over every non-object prototype, so the enumeration was produced by running it rather than by reading `modules/_baseCreate.js`. Driving `null`, `undefined`, `0`, `5`, `NaN`, `''`, `'proto'`, `true`, `false` and a `Symbol` through both functions: `_.create` returns an object inheriting `Object.prototype` with no own keys for all ten, while `Object.create` returns a prototype-less object for `null` alone and throws `TypeError` for the other nine. The two agree exactly on real object prototypes - a plain object, an array, a function and `Object.prototype` itself all produce the same prototype from either - and the `props` argument is still attached in the ignored case, `_.create(null, {a: 1})` giving `{a: 1}`. That whole enumeration is now the battery's check rather than this entry's prose, so the claim cannot drift from the code.

Both published examples were run in the exact form they are printed, per the rule this project already learned on the `_.isFinite` entry: `Object.getPrototypeOf(_.create(null)) === Object.prototype` is `true` and `_.create(5)` is `{}`, and the battery now asserts each of them under its own label.

The instruments were already right and only the published page dissented. `test/objects.js` pins `_.create` over `['foo', null, void 0, 1]` returning `{}`, and `.jeffy/probes/object-assign/check.js` already carried the null-prototype divergence; the finding was that a reader of underscorejs.org would not learn it from the page, which is the whole of what changed.

The first version of the new checks was wrong in exactly the way iteration 2's were, and `discriminate.sh` said so again: unguarded, the mutation that makes `_.create` stop ignoring its argument does not fail the block, it kills it, because `Object.create(undefined)` throws. Wrapped in `t.guard` the same mutation now reports `FAIL non-object prototypes: block aborted with an unexpected throw - Object prototype may only be an Object or null: undefined`. That is the second time this run that a new check needed a guard it was not written with, so the Lesson is marked `[recurred]`.

Learnings: a check whose subject can throw under its own mutation belongs inside `t.guard` from the first draft, not after the discrimination sweep reports CRASHED.

Next: the ledger holds no open task. U4b is blocked on the browser-toolchain decision under Proposed, and no Low is carried. The Surface inventory has no unswept or stale row and no full audit has run this run, so the next iteration is the closing full fresh-evidence audit; with four iterations left after it, the evaluator gate can run while its verdict can still be answered.

## iter 6/10 | a69c3ba6-002843 | 2026-08-24 | AUDIT | audit

Task: the ledger held no open task, so this iteration is the full fresh-evidence audit. Closeout has not begun: the audit filed two Mediums, and closeout requires an audit that scores zero High and zero Medium.

Changed: BACKLOG.md gains UA2 and UA1. No module, no battery, no documentation changed.

Checkpoint: 465fd3596090bd1c12d03e99aa5c1955df691820

Verification: Verify gate green through quiet-verify at 9s with `# pass 211`. The map is current - all 23 rows swept, none stale, checked by asking git whether any path in each battery's paths file moved since the commit its row records - and all 26 batteries were re-run green.

Scores, over 23 of 23 swept rows: correctness Medium, documentation Medium, dependency hygiene Medium (U4b, blocked), architecture None, code quality None, security None, testing None, error handling None, performance None, developer experience None. Observability is recorded as not applicable: underscore emits no logs, metrics or traces and has no runtime the term applies to. UX and accessibility are recorded as not probed rather than None - `index.html` is a real user-facing surface and this audit examined only whether its code examples run, never its markup, contrast or keyboard behaviour, so scoring it clean would be silence presented as cleanliness.

Correctness, Medium, filed as UA2. The differential that found it drives 28 exported calls twice, once with a `__proto__` key and once with an ordinary key of the same shape, and compares the shape of the result; `_.defaults` is the only divergence, so the class has exactly one site. `_.defaults({}, JSON.parse('{"__proto__": 1}'))` comes back with no `__proto__` own key, while `_.extend`, `_.extendOwn`, `_.clone` and `_.mapObject` all copy it. The cause is a read rather than a write: `modules/_createAssigner.js` decides absence with `obj[key] === void 0`, and `({})['__proto__']` is `Object.prototype`, not undefined. That is why the settled class does not cover it - that entry is about computed-key assignment and its enumerating grep looks for assignment sites, which this is not - and why filing it is not a re-file inside a settled class. It is the second finding sharing the `__proto__` root cause, so the three-strike rule is not yet reached and an instance fix is still allowed; the acceptance check carries the enumeration anyway.

The first version of that differential was wrong and would have filed nineteen findings. It built its fixture with `o['__proto__'] = 1`, which is a silent no-op - the setter ignores a primitive - so the key never existed and every function that failed to produce it looked broken. Rebuilt with `JSON.parse`, which creates an own data property, and with the fixture asserted before any case ran, the count fell to ten, of which eight were my own shape function reporting key order and the key's own name as differences. One real divergence remained, in two forms of the same call.

Documentation, Medium, filed as UA1. Nothing in this repository executes the examples on `index.html`, so a harness was written for this audit: it extracts every `<pre>` block, pairs each `expr;` with its `=> value`, evaluates both against the built bundle in one shared context so a `var` in an earlier block reaches a later one as a reader would carry it, and deep-compares with `_.isEqual`. Over 131 blocks it compared 96 pairs, declined 53 as prose or unparseable expectations, skipped 11 as nondeterministic or browser-bound, and reported 9 mismatches. Seven of those are harness limits - `listOfPlays` and `isOdd` are illustrative names the page never defines, `window.missingVariable` needs a browser, three `_.iteratee` expectations are descriptive function-valued forms, and one is a chain continuation line. Two are real. `_.isWeakSet(WeakSet())` throws `TypeError: Constructor WeakSet requires 'new'` where the sibling entries for `isMap`, `isWeakMap` and `isSet` all write `new`, so the enumeration over that family of four is complete and only one is wrong. And `_.iteratee()` is documented as returning `_.identity()`, while `_.iteratee() === _.identity` is true and `_.identity()` is `undefined`.

Security scored None on evidence rather than on absence of alarm. The CVE-2021-23358 guard was driven on both sides: `a=1`, `a);process.exit(1);(`, `a b`, `1a` and `a,b` are all rejected, while `data`, `obj` and `$scope` are accepted and render; an empty string is accepted because it is falsy and falls through to the default scoping path, which is the documented no-variable case rather than a bypass. Escaping round-trips. Eleven prototype-pollution sinks were provoked with a parsed `{"__proto__": ...}` payload: no global leak, `Object.prototype` untouched, no object reparented, and the own key written as data everywhere it should be. The settled classes were checked for change rather than assumed clean - the last commit touching `modules/_setKey.js`, `modules/_safeToString.js`, `modules/isFinite.js` and `modules/_createEscaper.js` predates this run - so neither was re-opened.

Testing scored None with the isolation run the Method requires. Every test module was run alone: the eight that define tests all pass, and their counts sum to 31+10+43+40+3+49+2+33 = 211, exactly the whole-suite figure, so no test depends on state another module leaks and none is lost or duplicated when the suite is split. The three that exit non-zero alone - `cross-document.js`, `overrides.js` and `qunit-setup.js` - all fail with QUnit's `No tests were run`, which is what a support file with no test registrations does; `cross-document.js` returning early without a DOM is already recorded in the Environment fingerprint. That fingerprint's load-order claim was re-derived rather than re-read: `ls test/*.js` puts `arrays.js` before `overrides.js`, so underscore is already required when the override file runs.

Error handling scored None over four `catch` sites in `modules/`, every one of them a deliberate fallback with a value - `_safeToString` to `Object.prototype.toString`, `_setKey` to `false` as feature detection, `isFinite` to `false` on a coercion that throws - and `template.js` attaching `e.source` and rethrowing. There is no empty catch anywhere in `modules/` or `test/`.

Dependency hygiene is Medium and unchanged: `npm audit --omit=dev` finds 0, `npm audit` reports 70, and every one of them is attributable to the browser-test and coverage toolchain that U4b is blocked on.

Learnings: build a fixture for a `__proto__` differential with `JSON.parse`, never with assignment, because `o['__proto__'] = v` is a silent no-op for a primitive and the probe then measures a key that was never there.

Next: two Mediums are open, UA2 first as the runtime class. Working UA2 and UA1 in the next two iterations leaves two for the evaluator gate and the declaration, which the gate can still answer.

## iter 7/10 | a69c3ba6-002843 | 2026-08-24 | UA2 | done

Task: UA2 (Medium, runtime, correctness) - `_.defaults` silently dropped a `__proto__` own key, because `modules/_createAssigner.js` decided absence with `obj[key] === void 0` and that read resolves the inherited accessor on `Object.prototype`, so an absent key never looked absent.

Changed: `modules/_createAssigner.js` gains an `absent` helper that asks for the own property first when the key is `__proto__`; `test/objects.js` pins the case in the existing `defaults` test; `.jeffy/probes/proto-key-class/check.js` gains the read side of the class as a 28-call differential; `.jeffy/probes/_lib/mutations.txt` gains a mutation for it and has its `object-assign` anchor repaired. The rebuilt bundles ride along.

Checkpoint: 32c44c8c89ed0ca50126de480e11949a98d97a67

Verification: Verify gate green through quiet-verify at 8s with `# pass 211`, and the assertion tally moved from 1705 to 1706, which is exactly the one assertion added; PLAN.md's Oracle class is updated to match. The filed reproduction was run first and reproduced as filed: `_.defaults({}, JSON.parse('{"__proto__": 1}'))` came back with no own `__proto__`. After the fix it has one, with the value 1, and `Object.prototype` is untouched. The differential enumeration reports 0 divergences over 28 cases where it reported 2 before, both of them `defaults`. Both batteries owning a path this diff touched were re-run green - object-assign at 41 checks and proto-key-class at 28, up from 24 - and the object-assign row is re-recorded at this checkpoint. `discriminate.sh` reports 29 of 29 mutations CAUGHT with no BLIND, CRASHED or SETUP-FAIL.

The instrument had to be repaired before it could be trusted. Its first normaliser sorted object keys before mapping the key to a placeholder, so `__proto__` sorted ahead of `other` while the ordinary key sorted behind it, and it rendered key names appearing as string values verbatim; between them those two flaws reported eight functions as divergent that behave identically. Mapping the name first and sorting afterwards, and normalising string values the same way, brought the count to exactly the two real cases. Its discriminating state is recorded in the battery header and was observed rather than asserted: with the previous `modules/_createAssigner.js` restored from HEAD and the tree rebuilt, the enumeration names both `defaults` cases and the battery exits 1; the mutation manifest reproduces the same failure on demand.

The contract preserved was driven rather than reasoned about. An inherited ordinary key still suppresses the fill - `_.defaults(new Foo(), {bar: 2}).bar` is still 1 with `Foo.prototype.bar = 1`. Falsy own values still win, an absent key is still filled, a key present with the value `undefined` is still filled, and the first source still wins over the second. `_.extend` is untouched. Only the `__proto__` branch of the absence test moved.

One observable behaviour did change beyond the defect, and the Constraints require the rationale here. An object whose custom prototype carries an own `__proto__` data property used to have that inherited value suppress the fill; now it does not, because the new test asks only whether the destination itself has the key. Measured: with `P` carrying an own enumerable `__proto__` of 7 and `o = Object.create(P)`, `_.defaults(o, {"__proto__": 9})` now yields 9 where it previously yielded 7. Distinguishing that case from the ordinary one would mean asking whether the value came from the accessor rather than from a data property, which needs `Object.getPrototypeOf` and its own ES3 fallback for a shape nothing in the tests, the batteries or the documentation contemplates. The simpler test is strictly closer to correct on every input anyone has written down, and the exotic case is recorded here rather than silently traded away.

The fix needs no feature detection, unlike its write-side counterpart in `modules/_setKey.js`. On an ES3 engine `__proto__` is an ordinary property name, so the own check answers the same question a plain read would; on a modern engine the own check is only reached while the key is missing, because once `setKey` has defined an own data property the plain read is correct again. Loose equality mirrors `setKey`, which coerces a key that merely stringifies to `__proto__` the same way.

Repairing the `object-assign` mutation anchor was not optional bookkeeping. That entry quoted the assignment line verbatim, this fix rewrote that line, and `discriminate.sh` answered `SETUP-FAIL object-assign` - a battery whose discrimination silently stops running is exactly the instrument that reads like one that passed.

Learnings: a mutation anchor quotes a source line verbatim, so any fix that rewrites a quoted line must update the manifest in the same iteration or the sweep degrades to SETUP-FAIL.

Next: one Medium remains, UA1, on the two `index.html` examples that do not evaluate as printed. Closing it leaves two iterations for the evaluator gate and the declaration.

## iter 8/10 | a69c3ba6-002843 | 2026-08-24 | UA1 | done

Task: UA1 (Medium, docs, documentation) - two published examples in `index.html` did not evaluate to what they claimed, and nothing in the repository ran the page's examples, which is why both survived.

Changed: `index.html` now prints `_.isWeakSet(new WeakSet());` and documents `_.iteratee()` as returning `_.identity` rather than `_.identity()`; a new battery at `.jeffy/probes/doc-examples` runs the whole page against the built bundle and declares `index.html` in its paths file; `.jeffy/probes/_lib/mutations.txt` gains the mutation that discriminates it. No module changed.

Checkpoint: 78731d11533f801c72f9ff4d623e8bf2cbcf4acb

Verification: Verify gate green through quiet-verify at 9s with `# pass 211`, and every battery green, now 27 of them. Both filed reproductions were run first and reproduced as filed: `_.isWeakSet(WeakSet())` threw `TypeError: Constructor WeakSet requires 'new'`, and `_.iteratee() === _.identity` was true while `_.identity()` was `undefined`. Both replacements were then run in exactly the form they are published, and printed what the page now prints. `discriminate.sh` reports 30 of 30 mutations CAUGHT with no BLIND, CRASHED or SETUP-FAIL.

The battery is the part that matters, because the fix without it would leave the page exactly as unguarded as it was. It pairs every `expr;` with its `=> value` across all 131 `<pre>` blocks and compares them: 101 compared, 43 expectations that are prose rather than JavaScript, 13 nondeterministic or browser-bound, and 3 declined by name. Its discriminating state was observed rather than asserted - restoring either defect makes it exit 1 and name that example, and restoring both makes it name both, which is what the mutation manifest now reproduces on demand.

Getting it to zero mismatches took four rounds, and each round was the instrument being wrong rather than the page. Comparing rendered strings called 76 of 96 pairs mismatched because `[3, 6, 9]` is not the string `[3,6,9]`; evaluating the expected side as JavaScript and deep-comparing brought that to 9. Treating each block as its own scope lost `stooges`, defined in one block and used in four later ones, so the blocks share a context the way a reader carrying the page does. Discarding an expression that had no `=>` after it lost both `_.mixin` calls, so `_("fabio").capitalize()` and the dotted-path `_.get` example failed against a page that is correct - an expression displaced by another line is now run for its side effect first. And a `var x = <expr>;` line followed by `=>` documents that expression's value, so the filters judge the defining statement: `var partners = _.chunk(_.shuffle(kindergarten), 2);` is nondeterministic, which reading only the name `partners` could never tell.

One of those rounds passed all five checks and still exited 1. `_.defer(function(){ alert('deferred'); })` had been run for its side effect, and the timer fired after the assertions were already green, killing the process on a `ReferenceError` from inside underscore's own `delay`. The flush now refuses to run anything the nondeterministic filter matches, so the battery cannot schedule work it will not outlive. A battery that exits non-zero for a reason unrelated to its subject is as useless as one that exits zero for the wrong reason.

The three declined examples are declined by name with their reason, and the battery asserts each is still on the page: `listOfPlays` and `isOdd` are illustrative names the page never defines, and `window.missingVariable` needs a browser. A decline that stops matching anything is reported as a failure rather than passing quietly. Function-valued expectations are not declined - the page documents `_.iteratee('firstName')` as `_.property('firstName')`, which are two different objects, so functions are compared by applying both to six probe values and requiring the same answer or the same error, which turns three would-be declines into real checks.

No Surface inventory row was added. `index.html` is documentation rather than a code surface, and this battery joins `coercion-safety`, `proto-key-class` and `publish-channels` as a class-enumerating battery with a paths file and no row; the row count stays at 23 and its meaning stays the same.

Learnings: run a page's examples in one shared context and execute the ones that carry no expected value, because documentation examples set up the examples that follow them; and never let a probe schedule a timer, or it will fail the process after its own checks have passed.

Next: the ledger holds no open task and no carried Low. U4b remains blocked on the browser-toolchain decision under Proposed. The Surface inventory has no unswept or stale row and this run's full audit is on record, so the next iteration is the evaluator gate, which can declare in the same iteration if it returns PASS.

## iter 9/10 | a69c3ba6-002843 | 2026-08-24 | EVALUATOR | audit

Task: the evaluator gate, invocation 1 of this run. Standing claims were brought current first, then one fresh-context sub-agent was spawned as the adversarial evaluator. It returned REJECT with two reasons, both of which were reproduced here before being filed.

Changed: BACKLOG.md gains UB1 and UB2; the verdict artifact `.jeffy/evaluator/a69c3ba6-002843-1.md` is committed by this iteration's checkpoint. No module, no battery, no documentation changed.

Checkpoint: 554711d6a28ff8728a5699eb0f2367e1f40ccea3

Verification: Verify gate green through quiet-verify at 8s with `# pass 211`. Evaluator: REJECT, two substantiated reasons, both reproduced independently in this iteration before filing. Before the invocation the standing claims were made current: no Surface inventory row is stale, derived per row by asking git whether any path in that battery's paths file moved since the commit the row records; the Declined section is empty, so there was no derivation to re-run; and the Oracle class and Environment fingerprint were re-read against the tree, which is where the first reject reason came from.

The gate confirmed what this run believed about most of its work. `npm test` exits 0 at 211 tests and 1706 assertions, both figures matching the Oracle class. All 27 batteries exit 0 and `discriminate.sh` reports 30 of 30 mutations CAUGHT. Every closed task's acceptance check re-ran green. On the rollup 4 upgrade it went further than this run had: the UMD bundle keeps 147 own keys and 158 prototype keys with none added or removed, fourteen behavioural probes are identical against the pre-run bundle, an AST scan of all 328 built outputs finds no bare reserved-word key and no reserved-word dot access, and `require`, `import`, `underscore/modules/*` and `underscore/amd/*` all resolve in a scratch install. It confirmed the flat config reproduces the old cascade by `--print-config` on all three groups, and that `absent()` breaks no documented `_.defaults` behaviour.

The first reject reason is a false claim this run rewrote three times without checking. PLAN.md's Oracle class says the suite grades the CommonJS bundle that `require("..")` resolves to "via the package `exports` map", naming `underscore-node.cjs`. CommonJS directory resolution uses `main`, not `exports`: `module.createRequire` on a test file resolves `..` to `underscore-umd.js`, and `grep -rn "underscore-node" test/ .jeffy/probes/ test-legacy/` returns nothing. So the gate grades the UMD bundle while the declaration names an artifact no test loads - and that artifact is exactly what a real consumer's `require('underscore')` gets. Filed as UB2. Nothing is broken behind the gap today, but a declaration that asserts coverage it does not have is the failure the Oracle class line exists to prevent, and this run edited that sentence in three separate iterations while reading past its central claim.

The second is worse, because the instrument was built this run and was believed to be discriminating. `.jeffy/probes/doc-examples/check.js` accumulates a multi-line expected value by consuming lines until a blank line or another `=>`, and the page's normal style puts examples adjacent with no blank line between them. The following `expr;` is swallowed into the expectation, the expectation then fails to parse, and both examples are counted as prose and dropped. Reproduced here: publishing `_.map([1, 2, 3], function(num){ return num * 3; });` as `=> [3, 6, 999]` leaves the battery printing `5 checks passed` at exit 0. It compares 101 pairs where an independent extractor compares 136, and its `<pre>` matcher misses two blocks including the `_.VERSION` example. Filed as UB1. The battery had been observed failing, on the `isWeakSet` mutation, and that is precisely why the blindness survived: a mutation that lands on a pair the instrument does happen to compare proves nothing about the pairs it silently drops.

Learnings: an instrument observed failing on one input is evidence about that input and nothing else; discriminate it on the shape it is most likely to skip, not on the one it was written from. And a claim inherited from an earlier run is not evidence - re-derive the Oracle class the first time an iteration edits that line, rather than editing around it.

Next: two gate-filed Mediums are open with one iteration of budget left, so iteration 10 is the one-transaction close the closing rule provides for - both fixes, their acceptance checks, the re-invocation of the gate as invocation 2, and the declaration if it returns PASS. The cap is 2 invocations, because this first one landed after the midpoint of the budget, so the second is the last.

## iter 10/10 | a69c3ba6-002843 | 2026-08-24 | EVALUATOR | converged

Task: the one-transaction close the closing rule provides for when the budget forces it - both fixes for the tasks the gate itself filed, their acceptance checks, the re-invocation as invocation 2, and the declaration.

Changed: `.jeffy/probes/doc-examples/check.js` closes UB1, `.jeffy/probes/build-packaging/check.js` with the new `load-exports.mjs` and the `Oracle class` line in PLAN.md close UB2, `.jeffy/probes/_lib/mutations.txt` gains a mutation for the first and has a malformed entry removed, BACKLOG.md loses UB1 and UB2 and gains the three carried Lows the gate's observations became, and `.jeffy/evaluator/a69c3ba6-002843-2.md` records the verdict.

Checkpoint: 015447f1ffcc7f46ae514eddc4e0c69ea0a771df

Verification: Verify gate green through quiet-verify at 8s with `# pass 211`. All 27 batteries green and `discriminate.sh` reports 31 of 31 mutations CAUGHT with no BLIND, CRASHED or SETUP-FAIL. Evaluator: PASS - invocation 2 perturbed all 156 expected values in `index.html` rather than spot-checking, found no compared pair survived, re-ran the whole suite and every battery, and confirmed the exports-map load check fails on truncated, empty and throwing targets. The fixes and the `build-packaging` row's re-recording were committed before the invocation, so the gate did not read a claim this iteration had already outdated.

UB1's fix is one rule: a continuation line joins the expected value only while that value's brackets are still open. Stopping at a blank line instead swallowed the next example wherever two sit adjacent, which is the page's normal style, and the swallowed pair then failed to parse and was counted as prose. The `<pre>` matcher no longer requires a newline after the tag, which reaches two more blocks, and the one-line `expr => value` form is split into the two-line shape. Compared pairs went from 101 to 135 over 133 blocks, and prose from 43 to 7. The `_.VERSION` example has its own check, because the page prints the version unquoted and that is not a JavaScript expression; it fails both when the version is wrong and when the example is removed. A fourth decline was needed, `isPrime`, the same illustrative-predicate class as `isOdd`.

The mutation that discriminates it was chosen for the shape that was being skipped rather than the shape the fix was written from, which is the lesson the first rejection taught. It falsifies the middle of three adjacent examples - the exact position the old accumulator swallowed - and the sweep reports `_.map({one: 1, two: 2, three: 3}, function(num, key){ return num * 4; }) gave [4,8,12], page says [3, 6, 9]`.

UB2's fix is two things. The `Oracle class` now says what the suite loads and how that was derived: `require("..")` from a file in `test/` is a directory resolution and goes through `main`, so it resolves to `underscore-umd.js`, printed by the `createRequire` command the line quotes. It also names what the gate does not reach - every other built output - rather than leaving that unsaid. And `.jeffy/probes/build-packaging` now loads every concrete target of the exports map and requires each to report the package version, in a child process because the battery is synchronous and the ES module targets need dynamic import. `underscore-esm.js` and `underscore-esm-min.js` are ES modules with a `.js` extension inside a `"type": "commonjs"` package, so Node's own resolution never reaches them; they are loaded from a copy carrying an `.mjs` extension, the same bytes under a name Node parses as a module. Observed failing on a truncated `underscore-esm.js` and again on a truncated `underscore-node.cjs`, and the gate additionally confirmed it fails on an empty target, which resolves and parses and only execution catches.

One rule was broken and caught inside this iteration. The first mutation written for `doc-examples` carried embedded newlines, which the manifest cannot hold - it is read line by line - and PLAN.md already records that lesson from an earlier run. It was removed and replaced with a single-line anchor before the sweep ran.

The gate recorded three observations that are not REJECT reasons, and per the closing rule none was fixed here: a fix after a PASS invalidates that PASS. All three are filed as carried Lows with their rationales and are listed below. UC1 (Low, build-ci): the aliased and minified outputs are tracked but only `npm run build` regenerates them, so `underscore.js` in the tree lacks this run's `_.compose` fix; filed Low because `prepublishOnly` runs the alias step, verified here by running `npm run alias-bundle` and observing the file change and then match `underscore-umd.js` byte for byte, so no consumer receives a stale artifact and the consequence is confined to the tree. UC2 (Low, docs): the `Oracle class` clause "no test and no battery loads them" became false in the same commit that wrote it, because the new `load-exports.mjs` loads both; filed Low because the error understates coverage and no false green can follow. UC3 (Low, dev-tooling): `doc-examples/paths` and the `build-packaging` row's scope line are each narrower than what those batteries touch; no row is stale today.

Closing conditions, each checked rather than assumed: this run's full fresh-evidence audit at iteration 6 is on record and every finding it and the gate filed is closed; the Surface inventory lists 23 rows, all swept and none stale, derived per row from each battery's paths file against the commit the row records; no open High and no open Medium remains in Now, Next or Later, with U4b blocked on a user decision and three Lows carried; the Verify command is green this iteration; the Oracle class and Environment fingerprint were re-read and re-derived; the Declined section is empty, so there was no premise to re-run; and the evaluator returned PASS at invocation 2 of a cap of 2.

Learnings: choose a mutation for the shape an instrument is most likely to skip, not the shape it was written from - the first rejection was a battery that had been observed failing and was still blind to most of its subject.

Next: the run converges here. Three Lows are carried - UC1, UC2, UC3 - U4b stays blocked on the browser-toolchain decision, and two Proposed items await the project owner.
