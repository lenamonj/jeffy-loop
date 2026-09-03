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

## iter 1/10 | 6153c97f-183542 | 2026-09-03 | AUDIT | audit

Task: First audit of a fresh Jeffy project. Fill the Operating envelope, the artifact-channel enumeration, the Verify command block and the Surface inventory, then probe every inventory row breadth-first and file what the probes reproduce.

Changed: PLAN.md (envelope surfaces, artifact channels, ten inventory rows, Verify command block, two Lessons), BACKLOG.md (OH-1, OH-2, OH-3 filed; OH-D1 declined), JOURNAL.md, .gitignore (loop state file).

Checkpoint: ff0a313f3fab782651cfabbf6bc321095186a4f6

Verification: `bash <jeffy>/hooks/lib/quiet-verify.sh PLAN.md .` -> `verify: green (6s, oracle=unit and behaviour tests plus a bundle-size budget..., Tests 90 passed (90))`. Verify count recorded as 90 from that wrapper line; Verify duration recorded as 6s from the same timed run. Artifact channels enumerated by `npm pack --dry-run --json`: the npm tarball is the only channel and it carries LICENSE, README.md, package.json and dist/** only, so no state file can reach a published artifact. Row probes (shallow, breadth-first, against dist built from HEAD): scalars, plain objects, key ordering, built-in handlers, both digest implementations, hash/isEqual, diff traversal, diff entry rendering, package entry points. Differential of the JS digest against `node:crypto` over 500 generated strings: zero mismatches. Known-answer digest vectors (empty, "abc", 55/56/64/1000-byte, unicode, emoji) all match `createHash("sha256").update(s,"utf8").digest("base64url")`. README's own `hash({foo:"bar"})` example reproduces exactly.

Scores, claiming only what was probed - all ten rows were probed shallowly, none was swept with a committed battery, so every row remains `- [ ]` and these scores are not the whole project: correctness High (OH-2), error handling High (OH-1), documentation Medium (OH-3), testing Low (neither OH-1 nor OH-2 has any case in the suite), security None on what was probed (the `__proto__` exclusion in diff holds; serialize emits `__proto__` only as an inert key string), architecture None, code quality None, performance None, dependency hygiene None (no runtime dependencies), developer experience None. Observability and UX/accessibility do not apply: this is a dependency-free library with no user-facing surface and no logging.

Learnings: the PLAN.md `Command:` payload must be written bare - the installed quiet-verify.sh does not strip wrapping backticks the way the Stop hook does, so a backticked line runs the suite inside a command substitution and then executes its output (exit 127, `Checking: command not found`). The `Cannot serialize <type>` throws are deliberate and pinned by existing tests (Blob, WeakMap, WeakSet, WeakRef, Generator, AsyncGenerator, Promise), so the missing DataView handler is a design question and not a defect to file. `ohash/crypto` resolves by export condition, so the JS implementation is what browser and edge builds get and the Node one never runs there - a defect in either is a defect on a whole class of runtimes.

Next: OH-1, the top unblocked item.

## iter 2/10 | 6153c97f-183542 | 2026-09-03 | OH-1 | done

Task: OH-1 (High, runtime, error handling) - the pure-JS `digest` threw `URIError: URI malformed` on any string containing a lone surrogate, so `hash()` crashed in every browser, bundler and edge build for input that hashed fine on Node.

Changed: src/crypto/js/index.ts (`WordArray.fromUtf8` now encodes through a hoisted `TextEncoder` instead of `unescape(encodeURIComponent(input))`), test/crypto.test.ts (four lone-surrogate cases and a 200-string differential against `node:crypto`, both running against each implementation), BACKLOG.md (OH-1 deleted), PLAN.md (Verify count 90 -> 100, two Lessons), JOURNAL.md.

Checkpoint: ed2bb1866161d0980afc27b2f1edd7265fbee401

Verification: filed reproduction run first, against dist built from the previous checkpoint - `node -e "import('./dist/crypto/js/index.mjs').then(m=>m.digest('\uD800'))"` threw `URIError: URI malformed` while the Node implementation returned `g9VEzMIjwFfSv4DT8qMpgsMsPA244mdIINpQZHg_sJc`. Acceptance as filed: `npx vitest run test/crypto.test.ts` -> `Test Files 1 passed (1) / Tests 12 passed (12)`. Strength of the check confirmed by restoring the pre-fix `src/crypto/js/index.ts` from HEAD into place (file copied aside first, restored after, diff against HEAD confirming the fix came back) and re-running it: `Tests 4 failed | 8 passed (12)`, every failure `URIError: URI malformed`, so the four lone-surrogate cases are the discriminating ones and the 200-string differential passes either way. Verify gate: `verify: green (8s, oracle=unit and behaviour tests plus a bundle-size budget..., Tests 100 passed (100))`. Against the rebuilt dist both implementations now return the same `g9VEzMIjwFfSv4DT8qMpgsMsPA244mdIINpQZHg_sJc` for `"\uD800"`.

Contract preserved: `TextEncoder` and `unescape(encodeURIComponent(...))` produce identical UTF-8 bytes for every well-formed string, so no previously-working hash changed - the 200-string differential over mixed ASCII, Latin-1, CJK and astral input passed against both the old and the new implementation, and the existing `"Hello World"` and empty-string vectors are unchanged. The only behaviour change is that input the old code rejected now hashes, matching `node:crypto`. The bundle budget was the binding constraint and it moved the right way: the esbuild-minified `digest (js)` bundle went from 3179 bytes / 1702 gzip to 3156 bytes / 1683 gzip, against limits of 3200 and 1750.

Learnings: eslint-config-unjs enables `unicorn/no-for-loop`, which errors on a counting `for` loop that indexes an array-like even when the index is also used for arithmetic - `for (const byte of bytes)` with a manual counter is the shape that passes. Iteration 1's journal heading carried run-id `6153c97f-143540`, derived from the shell clock instead of from `started_at` in the loop state file; the Stop hook reported the entry as missing, and the heading's run-id field was corrected to `6153c97f-183542` this iteration - the entry's body is untouched and this line is the disclosure.

Next: OH-2, the remaining open High.

## iter 3/10 | 6153c97f-183542 | 2026-09-03 | OH-2 | done

Task: OH-2 (High, runtime, correctness) - `diff` silently reported no change when a key moved between a leaf and a non-empty container, so a real difference was dropped from the returned array entirely.

Changed: src/utils/diff.ts (the mixed leaf/container branch now builds a hashed node per side and emits the `changed` entry instead of returning early when either side has enumerable keys), test/utils.test.ts (the characterization assertion that pinned the drop is replaced by cases asserting the entry, plus a case pinning the container side's hash and props), BACKLOG.md (OH-2 deleted), PLAN.md (Verify count 100 -> 102), JOURNAL.md.

Checkpoint: 4b81b23b69834a02d2bad296149c88f2efa93aaa

Verification: filed reproduction run first - `diff({a:1},{a:{b:2}})`, its reverse, `diff({a:1},{a:[1]})` and `diff({a:null},{a:{b:1}})` each returned `[]` against the previous checkpoint. Acceptance as filed: `npx vitest run test/utils.test.ts` -> `Test Files 1 passed (1) / Tests 18 passed (18)`; against the restored pre-fix `src/utils/diff.ts` the same file reports `Tests 2 failed | 16 passed (18)`, so the new cases are discriminating. Verify gate: `verify: green (7s, oracle=unit and behaviour tests plus a bundle-size budget..., Tests 102 passed (102))`. The diff bundle measures 4936 bytes / 2041 gzip against the suite's limits of 5000 and 2100.

Rationale for the observable behaviour change, per Constraints: `diff` now returns an entry where it previously returned none. The dropped case was pinned by an assertion added in b08d280 (`git log -S` over test/utils.test.ts returns that commit alone), the perf commit that preserved the behaviour it found - the pre-b08d280 implementation dropped the same case through its `allProps.size === 0` guard - so the assertion characterized a long-standing defect rather than recording a design decision, and a comparison function that reports nothing when a value changed contradicts the README's "Returns an array of changes".

Differential evidence that no previously-passing output changed: HEAD's own test/utils.test.ts run against the fixed source reports `Tests 1 failed | 15 passed (16)`, the single failure being `diffs an empty container against a leaf`, the test carrying that pinning assertion. Across a matrix of 588 value pairs - eight leaves and six containers, each pair at top level, one level deep and two levels deep - the old entry list is preserved as an ordered subsequence of the new one in every pair (old-output-not-preserved: 0), the new list adds 204 entries in total, and every added entry is a `Changed` entry (extra entries that are not `Changed`: 0). The README's `diff` example still prints its three documented lines unchanged.

Learnings: a characterization test can pin a defect rather than a decision, and `git log -S` over the test file is what tells the two apart - here the assertion and the perf refactor that wrote it arrived in the same commit, so nothing upstream ever chose the behaviour. The 588-pair old-versus-new matrix, bundled with esbuild from the two source revisions side by side, is the cheap way to show a fix only adds output; a passing suite alone would not have.

Next: OH-3 (Medium, docs), then the ten unswept Surface inventory rows.

## iter 4/10 | 6153c97f-183542 | 2026-09-03 | SWEEP | done

Task: sweep the Surface inventory. Ten rows were unswept with seven iterations left, and the map outranks everything but an open High, so this iteration built and executed a known-answer battery for every row.

Changed: .jeffy/probes/ - a shared loader and harness under _lib, and ten batteries (serialize-scalars, serialize-plain-objects, serialize-key-ordering, serialize-built-ins, crypto-js-digest, crypto-node-digest, hash-and-isequal, diff-traversal, diff-entry-rendering, package-entry-points), each with check.mjs, paths, mutation.json, claims and README.md; PLAN.md (all ten rows flipped to swept, three Lessons); JOURNAL.md. No src or test file changed.

Checkpoint: abac6778feb293fca7607e93e6150d0ef809850f

Verification: every battery green, and every one observed red on a recorded discriminating mutation before its row was flipped - serialize-scalars 25/25 green against 22/25 with the bigint `n` suffix dropped; serialize-plain-objects 19/19 against 17/19 with key sorting removed; serialize-key-ordering 10/10 against 8/10 with the case tie-breaker inverted; serialize-built-ins 49/49 against 47/49 with the BigInt array suffix dropped; crypto-js-digest 37/37 against 3/37 with the first SHA-256 round constant off by one; crypto-node-digest 22/22 against 2/22 with base64 substituted for base64url; hash-and-isequal 28/28 against 20/28 with isEqual always true; diff-traversal 37/37 against 32/37 with the pre-OH-2 early return restored; diff-entry-rendering 25/25 against 24/25 with the `Added` label's padding removed; package-entry-points 26/26 against 23/26 with PLAN.md added to the files allowlist. `.jeffy/probes/_lib/mutate.mjs <battery>` re-derives each red line by applying the mutation, running the battery and restoring the file, and both lines per battery are recorded in that battery's claims file: `check-claims.sh` reports `claims: 20 checked, 0 mismatched, 0 errored, 0 skipped`. Verify gate: `verify: green (9s, oracle=unit and behaviour tests plus a bundle-size budget..., Tests 102 passed (102))`.

The batteries load the library by bundling src with esbuild rather than importing dist, because dist is gitignored and can lag src by a whole iteration. Correctness rather than liveness throughout: published SHA-256 vectors including the one-million-character case, block-boundary lengths, an every-ordered-pair check that the ASCII weight table really does reproduce localeCompare order as the source comment claims, isEqual's reflexivity, symmetry and agreement with serialize over a value pool, and the export map checked against the real `npm pack --dry-run` file list. The node-crypto battery reaches both branches: this process takes the `getBuiltinModule` fast path, and the `createHash` fallback is exercised in a child process with that lookup deleted.

No in-envelope finding surfaced. Two behaviours were pinned as known answers rather than filed: a key containing the form's own separators can reproduce another object's serialization (`serialize({"a:1,b":2})` equals `serialize({a:1,b:2})`), which the README documents as the collision caveat, and `serialize(-0)` equals `serialize(0)`, which follows from `String(-0)`.

Learnings: `eslint .` covers `.jeffy/probes/`, so probe files are graded by the project's own config and had to be made clean rather than the config made to ignore them - the loop's instruments should be invisible to the project's tooling, not the other way round. A known answer must not depend on the probe file's own formatting: `prettier -w` reflowed a function literal whose source text was the expected value and turned a green battery red, so such fixtures are now built with `new Function(...)`, whose source form the language fixes.

Next: OH-3, the one open Medium.

## iter 5/10 | 6153c97f-183542 | 2026-09-03 | OH-3 | done

Task: OH-3 (Medium, docs, documentation) - README documented `diff` entries as carrying `$key`, `$hash`, `$value` and `$props`, none of which exist, so all four documented reads returned `undefined`.

Changed: README.md (the `diff` section now documents the real entry and node shape), .jeffy/probes/package-entry-points/paths (README.md added, since that battery asserts the tarball's root contents and README.md is one of them), BACKLOG.md (OH-3 deleted, OH-4 filed under Later), JOURNAL.md.

Checkpoint: d22aa683d18120ef811b303eb04d8045f8fd6bd0

Verification: filed reproduction run first - `grep -nE '\$key|\$hash|\$value|\$props' README.md` printed the documented line, and reading `entry.$key`, `entry.$hash`, `entry.$value`, `entry.$props` off a real diff entry returned four undefineds while `Object.keys` reported `["key","type","newValue","oldValue"]` on the entry and `["key","value","hash","props"]` on its node. Acceptance as filed: the grep now prints nothing and exits 1, and every field name the rewritten section documents - key, type, newValue, oldValue, value, hash, props - is present on the entry or on its node, with none absent. Against the restored HEAD README the same check exits 1 and extracts no documented names, so it is discriminating. Every sentence the new text adds was driven against the running API rather than read off the source: the dotted key path, the empty key at the root, the three type values, newValue absent on removed and oldValue absent on added, both present on changed, `value` being the value itself, a leaf `hash` equal to `serialize` of that value across nine scalar types with zero mismatches, a container `hash` matching the brace summary, `props` mapping each key to its own node with the child's own dotted key, no `props` on a leaf, and the rendered one-line form. Battery ownership: the diff touches README.md, now declared by package-entry-points, so that battery was re-run through run-probe.sh - `package-entry-points: 26/26 checks passed`. `check-claims.sh` reports `claims: 20 checked, 0 mismatched, 0 errored, 0 skipped`. Verify gate: `verify: green (8s, oracle=unit and behaviour tests plus a bundle-size budget..., Tests 102 passed (102))`.

Filed while executing this task: OH-4 (Low, docs) - the `diff` section's link to `#serializeinput-options` names an anchor no heading produces, a leftover from when `serialize` took an options argument. Enumerated rather than spotted: every `](#target)` in the file was compared against the slug of every heading, and this is the only broken one, so the finding is the instance and the class at once. Scored Low because a dead in-page link is minor docs polish under the rubric, not a promise the code fails to keep.

Learnings: quoting a nested single-quoted string inside `node -e '...'` silently produced a false failure on the leaf-hash check; a check whose expected value contains quotes belongs in a file, not in a shell one-liner. A battery's paths file is a claim about what its row covers, and the packaging battery's tarball assertions covered README.md without declaring it - a paths file is worth re-reading whenever a diff touches a file the battery already checks.

Next: OH-4 is the only open item and it is a Low, so the ledger is at the severity floor with the map swept and no clean full audit yet on this run's record.

## iter 6/10 | 6153c97f-183542 | 2026-09-03 | OH-4 | done

Task: OH-4 (Low, docs, documentation) - the README's `diff` section linked to `#serializeinput-options`, an anchor no heading in the file produces, so the link landed nowhere in the shipped README.

Changed: README.md (the link now names `#serializeinput`, the anchor the `## serialize(input)` heading actually produces), BACKLOG.md (OH-4 deleted), JOURNAL.md.

Checkpoint: 2487b5867731030dbb3c4d2e4673b8cd4aa58e84

Verification: filed reproduction run first, and it is the acceptance check itself - the enumeration that compares every `](#target)` in the file against the slug of every heading printed `['serializeinput-options']` and exited 1 before the change, prints `[]` and exits 0 after it, so the same command is both the reproduction and the discriminating check. The heading it now names exists in the file. Battery ownership: the diff touches README.md, which package-entry-points declares, so that battery was re-run through run-probe.sh - `package-entry-points: 26/26 checks passed`. `check-claims.sh` reports `claims: 20 checked, 0 mismatched, 0 errored, 0 skipped`. Verify gate: `verify: green (6s, oracle=unit and behaviour tests plus a bundle-size budget..., Tests 102 passed (102))`.

The ledger is now empty: no open task in Now, Next or Later, nothing carried, nothing blocked, and no Proposed item awaiting a decision.

Learnings: none beyond what is already recorded - the enumeration written into the finding when it was filed was exactly the check that closed it, which is what an acceptance check that is a runnable enumeration buys.

Next: the closing full audit, which is what the ledger being empty calls for and what the declaration needs on this run's record.

## iter 7/10 | 6153c97f-183542 | 2026-09-03 | AUDIT | audit

Task: the closing full audit - rescore every applicable dimension against the severity rubric and the Operating envelope with fresh evidence, over a Surface inventory with no unswept row.

Changed: .jeffy/probes/serialize-plain-objects/ (three checks pinning cycle aliasing, with its claims and README re-measured), BACKLOG.md (OH-5 and OH-6 filed under Later), JOURNAL.md.

Checkpoint: bfa9dce793c7d995612bf24e8f0d28f2d27f715f

Verification: fresh evidence, all of it executed this iteration. All ten batteries re-run through run-probe.sh and green - serialize-scalars 25/25, serialize-plain-objects 22/22 after the additions, serialize-key-ordering 10/10, serialize-built-ins 49/49, crypto-js-digest 37/37, crypto-node-digest 22/22, hash-and-isequal 28/28, diff-traversal 37/37, diff-entry-rendering 25/25, package-entry-points 26/26. `check-claims.sh` reports `claims: 20 checked, 0 mismatched, 0 errored, 0 skipped`. The one Declined derivation, OH-D1, re-runs and still holds: the JSON.stringify depth bisection returns 4457, the same magnitude as the serialize ceiling it is compared against. No Settled classes are recorded, so there is no settled enumeration to re-run. Oracle class and Environment fingerprint re-read against the tree: the fingerprint's exclusion command re-derives exactly the two `it.runIf` guards in test/serialize.test.ts and test/benchmarks.bench.ts, which `vitest run` still does not collect, so nothing in this entry claims the benchmark file was graded. Verify count reads 102 and the wrapper's green line reports `Tests 102 passed (102)`. Every test module was also run in isolation, cheapest first, all green and summing to the same 102: crypto 12, utils 18, hash 1, bundle 4, serialize 67 - so no module depends on state another leaks. Coverage 95.34% statements, 87.42% branches. The only regex in the shipped code, `/\s*\n\s*/g` over a function's own source, was measured against whitespace-heavy sources from 1000 to 16000 newline pairs and stayed at or under a tenth of a millisecond throughout, so it is not a backtracking hazard. Verify gate: `verify: green (6s, oracle=unit and behaviour tests plus a bundle-size budget..., Tests 102 passed (102))`.

Scores, over a map with no unswept row, so these claim the whole public surface rather than a sampled part of it: correctness None, error handling None, security None in-envelope for the shipped product, architecture None, code quality None, performance None, documentation None, developer experience None, testing Low (OH-6), dependency hygiene Low (OH-5). Observability does not apply - the library logs nothing and holds no state across calls - and UX and accessibility do not apply, since there is no user-facing surface. Zero High and zero Medium in-envelope, so closeout has begun: no further audit and no replenishment for the rest of this run.

Filed: OH-5 (Low, dev-tooling) - two vite advisories reachable only through vitest, scored Low rather than the rubric's Medium for a vulnerable dependency because the severity ceiling by class puts dev-tooling at Low always, and because `dependencies` is empty and `files` is `["dist"]`, so an installed ohash pulls in no vite at all. OH-6 (Low, test) - the `createHash` fallback in the node digest is never reached by the suite, which leaves that file at 25% branch coverage; the battery reaches it in a child process, the suite does not.

Characterized rather than filed, and now pinned in the serialize-plain-objects battery: aliasing is visible for cycles and invisible otherwise. One cycle referenced twice serializes as `{p:{a:1,self:#1},q:{a:1,self:#1}}` while two structurally equal cycles serialize as `{p:{a:1,self:#1},q:{a:1,self:#2}}`, so `isEqual` reports them unequal, whereas two equal acyclic objects serialize identically whether shared or duplicated. This is not filed because no documented promise is broken - `serialize` promises stable output and delivers it, `isEqual` promises exactly reference equality then serialized-form equality and delivers that - and the two inputs really are different object graphs; the suite's own `circular references` block shows the placeholder scheme is deliberate. Pinning it in the battery is what stops the next audit rediscovering it as a finding.

Learnings: none new this iteration.

Next: the evaluator gate, with two Lows carried.

## iter 8/10 | 6153c97f-183542 | 2026-09-03 | EVALUATOR | audit

Task: the evaluator gate, invocation 1 of this run, spawned after bringing every standing claim current.

Changed: .jeffy/evaluator/6153c97f-183542-1.md (the verdict artifact), BACKLOG.md (OH-7, OH-8, OH-9 filed), JOURNAL.md.

Checkpoint: 0f3953dc1fe435adbf84a2e6040ed3a6239ade7b

Verification: standing claims brought current before the invocation, all mechanically. No Surface inventory row is stale: for each of the ten rows, `git diff --name-only <recorded commit> HEAD --` over that battery's declared paths returns nothing. The one Declined derivation, OH-D1, re-runs and returns 4457. No Settled classes are recorded, so there is no settled enumeration to re-run. `check-claims.sh` reports `claims: 20 checked, 0 mismatched, 0 errored, 0 skipped`. PLAN.md names no finding ID as carried or blocked, so there is nothing to resolve. Oracle class and Environment fingerprint re-read. Verify count reads 102 and the wrapper's green line reports `Tests 102 passed (102)`. The only commit between the clean audit at bfa9dce and the invocation was `0ed0387 jeffy: iter 7/10 bookkeeping`, touching JOURNAL.md alone.

Evaluator: REJECT - two substantiated reasons, both independently reproduced here before filing, and both confirmed against the run's base commit 764b0a32 by bundling that revision of src/utils/diff.ts side by side with the current one.

Reason 1, filed as OH-7 (High, runtime, correctness): `_toHashedObject` walks `for..in` with no cycle guard, so `diff` overflows the stack on cyclic input while `serialize` handles cycles by design. Against the base revision, `diff({a:1},{a:o})`, `diff({a:o},{a:1})` and `diff(1,o)` returned `[]`; against HEAD all three throw `RangeError`. The other three cyclic shapes - the added path, the removed path, and container against container - already threw at base, so the missing guard pre-exists and the OH-2 fix routed three more shapes into it. OH-D1 does not cover this: its premise is that JSON.stringify fails the same way, and on a cycle JSON.stringify throws a clean TypeError while serialize returns `{a:1,self:#0}`, so the premise does not reach here. The iteration-3 differential that certified "no previously-passing output changed" ran a 588-pair matrix of acyclic values only, and the iteration-7 closing audit scored correctness and error handling None over a fully swept map without meeting this - the diff-traversal battery contains no cyclic case, and neither does test/utils.test.ts.

Reason 2, filed as OH-8 (Medium, runtime, error handling): `DiffHashedObject.toString()` renders a leaf with `JSON.stringify(this.value)`, which throws on a BigInt that `_leafHash` accepts, so `diff({a:1n},{a:2n}).join("\n")` throws `TypeError: Do not know how to serialize a BigInt`. This throws at base too, so it is pre-existing rather than introduced; what is new is that the README sentence this run added while closing OH-3 promises entries stringify to a readable line, which makes it a documented promise the code does not keep. Filed as runtime rather than docs because the root cause is the renderer, not the sentence, and with the Consequence stated on its line.

Also filed: OH-9 (Low, docs) from the gate's observations - the rewritten README says `newValue` is absent on a removed entry, where the property is present with the value `undefined`. The gate's remaining observations are recorded here rather than filed: hoisting `new TextEncoder()` to module scope moves failure from call time to import time on a runtime lacking it; `vitest run --coverage` instruments dist/crypto/node alongside src/crypto/node; and PLAN.md's Stated counts table carries no rows, which is correct because no prose count in `returns <count>` form exists in either governance file.

The verify gate is green this iteration - `Tests 102 passed (102)` - which is the floor the gate required and not a defence of anything it found. One evaluator invocation remains: the cap is 2 because this first invocation landed at iteration 8, past the midpoint of a 10-iteration budget.

Learnings: an acyclic differential matrix cannot certify a change to a traversal that recurses, and this one certified exactly the wrong thing - the OH-2 fix's own receipt said no previously-passing output changed while three cyclic shapes went from `[]` to a stack overflow. A differential over a recursive function must include the shapes that make it recurse without end.

Next: OH-7, the open High, then OH-8 combined with the gate re-invocation and the declaration under the one-transaction rule, which the remaining budget forces.

## iter 9/10 | 6153c97f-183542 | 2026-09-03 | OH-7 | done

Task: OH-7 (High, runtime, correctness), filed by the evaluator gate - `diff` overflowed the stack on cyclic input, because neither the fused traversal nor `_toHashedObject` tracked what it was already walking.

Changed: src/utils/diff.ts (a pair-scoped cycle guard in `_diff` and an ancestor-scoped one in `_toHashedObject`), test/utils.test.ts (three cases covering all six cyclic shapes, differences inside cycles, and the `[Circular]` hash), test/bundle.test.ts (the diff budget raised, with the reason and the measured before and after in the file), .jeffy/probes/diff-traversal/ (eleven cyclic checks added, claims and README re-measured), BACKLOG.md (OH-7 deleted), PLAN.md (Verify count 102 -> 105), JOURNAL.md.

Checkpoint: 487e8ff8c43bc1d667ba7ed5633aa463bc2d345e

Verification: filed reproduction run first - all six cyclic shapes threw `RangeError: Maximum call stack size exceeded`; all six now return a diff. Acceptance as filed: `npx vitest run test/utils.test.ts` green at 21 tests, and against the restored pre-fix src/utils/diff.ts the same file reports three failures, each a RangeError, so the cases are discriminating. The battery extension is part of the acceptance: diff-traversal goes from 37/37 to 48/48 green, and 40/48 under its recorded mutation, both re-recorded in its claims file. `check-claims.sh` reports `claims: 20 checked, 0 mismatched, 0 errored, 0 skipped`. diff-entry-rendering, the other battery declaring src/utils/diff.ts, re-run green at 25/25 through run-probe.sh. Verify gate: `verify: green (6s, oracle=unit and behaviour tests plus a bundle-size budget..., Tests 105 passed (105))`.

Contract preserved, and checked rather than asserted: the guard removes each pair from the path on the way out, so an object reachable by two sibling routes is still compared on each - `diff({x:s,y:s},{x:{s:1},y:{s:2}})` still reports the `y.s` change. Differences inside cycles are still found: two self-referential objects differing in one field report that field, and two mutually cyclic pairs report `other.n`. The pair-scoped structure is what makes this correct rather than a v1-only ancestor set, which would cut a comparison of a cyclic value against a deep finite one while it still had differences to report. A cyclic subtree hashes to `[Circular]` rather than recursing, so an added or removed cyclic value now yields an entry instead of a crash.

The bundle budget was raised deliberately and is recorded in test/bundle.test.ts beside the numbers: the diff bundle measured 4936 bytes and 2041 gzip before the guard and 5109 and 2123 after, against limits that were 5000 and 2100, so the correct guard does not fit under the old budget. Two compaction attempts were measured and neither recovered the difference - the second was three bytes worse than the first. Raising the limits to 5300 and 2200 buys a stack-overflow fix for 173 minified bytes; the alternative was a v1-only guard that fits but under-reports, which is trading a crash for silence.

Learnings: none new beyond the differential lesson already recorded at iteration 8, which this iteration is the consequence of.

Next: OH-8, the open Medium the gate filed, combined with the gate re-invocation and the declaration under the one-transaction rule, which the last remaining iteration forces.

## iter 10/10 | 6153c97f-183542 | 2026-09-03 | EVALUATOR | converged

Task: close OH-8, the second finding the evaluator gate filed, then re-invoke the gate and declare. The last iteration of the budget forces the combination the one-transaction rule allows; the fix and the inventory row re-recording both landed before the re-invocation.

Changed: src/utils/diff.ts (`DiffHashedObject.toString` renders a BigInt leaf as `serialize` renders it instead of handing it to `JSON.stringify`), test/utils.test.ts (a case asserting the rendered line and that no other leaf type throws), .jeffy/probes/diff-entry-rendering/ (four checks added, claims and README re-measured), PLAN.md (Verify count 105 -> 106, the two diff rows re-recorded at c84576d), BACKLOG.md (OH-8 deleted, Converged line appended), .jeffy/evaluator/6153c97f-183542-2.md, JOURNAL.md.

Checkpoint: cce1ac76b94185fae221cda5dd15a396fd80ae59

Verification: OH-8's filed reproduction run first - `diff({a:1n},{a:2n}).join("\n")` threw `TypeError: Do not know how to serialize a BigInt`, and now renders `Changed `a` from `1n` to `2n``. The class was enumerated by provoking rather than by reading: every leaf type the traversal can produce was rendered through `DiffHashedObject.toString`, and BigInt is the only one that threw, so the fix is the class and not an instance. Acceptance as filed: `npx vitest run test/utils.test.ts` green at 22 tests, and one failure with that TypeError against the restored pre-fix source. diff-entry-rendering goes to 29/29 green and 28/29 under its mutation, both re-recorded; diff-traversal, the other battery declaring src/utils/diff.ts, re-run green at 48/48 through run-probe.sh.

Standing claims brought current before the re-invocation: no Surface inventory row is stale, checked per row with `git diff --name-only <recorded commit> HEAD --` over that battery's declared paths; OH-D1's derivation re-runs and returns 4457; no Settled classes are recorded; `check-claims.sh` reports `claims: 20 checked, 0 mismatched, 0 errored, 0 skipped`; PLAN.md names no finding ID as carried or blocked; Oracle class and Environment fingerprint re-read; Verify count reads 106 against the wrapper's `Tests 106 passed (106)`.

Evaluator: PASS - invocation 2 re-ran the verify gate, every battery and every acceptance, confirmed each closed High and Medium fails at the base commit and passes at HEAD, and cleared the cycle guard with a 1024-pair acyclic differential showing zero deltas against the pre-guard revision, zero duplicated comparisons across that matrix and 400 random cyclic graph pairs, and the cyclic-versus-deep-finite case a weaker guard would have cut still reporting its differences.

Verify gate this iteration: `verify: green (11s, oracle=unit and behaviour tests plus a bundle-size budget..., Tests 106 passed (106))`.

Carried Lows, open at the declaration and none of them blocking it: OH-5 (dev-tooling) - two vite advisories reachable only through vitest, with no runtime dependency and a `files` allowlist of `["dist"]`, so no installed ohash pulls in vite. OH-6 (test) - the `createHash` fallback in src/crypto/node/index.ts is not reached by the suite, leaving that file at 25% branch coverage; the probe battery reaches it in a child process. OH-9 (docs) - the README says `newValue` is absent on a removed entry where the property is present holding `undefined`.

Gate observations recorded and deliberately not fixed inside the convergence sequence, since a fix after a PASS invalidates it: the "5109/2123" figures in test/bundle.test.ts and the iteration-9 entry re-measure as 5102/2120 on this host, with the before figures reproducing exactly and the conclusion unchanged; `_diff` retains its path Map key for the duration of a call; a `[Circular]` node's `toString` throws if called directly, unreachable through `String(entry)`, `toJSON` or `JSON.stringify` across a 625-pair sweep and a `RangeError` at base; `new TextEncoder()` sits at module scope; and symbol, function and undefined leaves render as `-` exactly as they did at base. All go to the run report and the next run's ledger.

Learnings: none new; the run's two lessons are already in PLAN.md.

Next: nothing. The run is converged at 93f7c8daef388ed8363a261e36c9c04af38e2274, the commit the gate certified.
