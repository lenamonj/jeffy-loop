# Journal archive

Rotated entries, appended in order and never rewritten.

## iter 1/10 | 5c45e1c8-165536 | 2026-08-16 | AUDIT | audit

Task: First audit of a fresh Jeffy bootstrap over zod 4.4.3. Filled the Operating envelope, the Verify command block and the Surface inventory, then probed breadth-first across the whole library before any deep dive.

Changed: PLAN.md (envelope surfaces, 28 inventory rows, Verify command / Oracle class / Environment fingerprint / Verify duration, 5 Lessons), BACKLOG.md (5 findings), .gitignore (loop state), .jeffy/probes/ (5 batteries with paths files).

Checkpoint: 40707333c78d0f6fdb7cf59d32a5fd547680572f

Verification: Verify command `export PATH="$HOME/.nvm/versions/node/v24.17.0/bin:$PATH" && ./node_modules/.bin/vitest run` exits 0 - 339 test files, 3811 tests, no type errors, 29s. The first run of the day used a bare `./node_modules/.bin/vitest run` and came back red on `packages/resolution/attw.test.ts`; that was isolated to this shell's PATH (the test shells out to `pnpm attw`) and not to anything this iteration changed - the same tree with `pnpm` on PATH is green, and the tracked diff is state files only. The PATH prefix is now part of the recorded Verify command, and the underlying test defect is filed as ATTW-1. Also run green by hand, none of them covered by the Verify command: `pnpm build`, `pnpm format:check`, `pnpm lint:check`, `pnpm check:circular`. Ran `packages/zod/src/v4/classic/tests/string.test.ts` in isolation (94 tests, green) per the Method's isolated-module rule.

Scores, claiming only the 5 of 28 inventory rows actually swept (core-regexes, core-registries, core-standard-schema, classic-from-json-schema, v4-locales) - the other 23 rows are unswept and these scores say nothing about them: correctness High (SLUG-1, EMOJI-1, LOCALE-1); documentation Medium (DOCS-1); testing Medium (ATTW-1, plus the three runtime findings each exist because no test covered them); error handling None; security, performance, architecture, code quality, dependency hygiene, developer experience and observability unscored - no probe was run for them this iteration, and `recheck` sits in devDependencies with no script wiring it to the regex surface, which is where a security sweep should start. UX and accessibility do not apply: zod has no user-facing rendered surface.

Filed: SLUG-1 (High) `z.string().slugify()` deletes every non-ASCII letter - "Café Déjà" -> "caf-dj", "über cool" -> "ber-cool", CJK -> "". EMOJI-1 (Medium) `z.emoji()` accepts `#`, `*`, `0`-`9`, lone ZWJ and lone VS16. LOCALE-1 (Medium) `hy.ts` reads `issue.values[1]` in the length-1 branch, so Armenian `invalid_value` says "expected undefined". ATTW-1 (Medium) `attw.test.ts` asserts nothing on an unbuilt checkout and its `console.warn` skip path always throws. DOCS-1 (Medium) the docs call `z.emoji()` a single-character validator while the suite pins multi-emoji strings as valid.

Learnings: `pnpm` is absent from this shell's default PATH but present at `$HOME/.nvm/versions/node/v24.17.0/bin`, and both the husky pre-commit hook and `packages/resolution/attw.test.ts` shell out to it - every checkpoint and every verify run needs the prefix. Probes must live under `.jeffy/probes/` inside the repo; run from `/tmp` they cannot resolve `zod`. Running `pnpm build` as an audit probe populates gitignored artifacts that change which branch `attw.test.ts` takes, so a verify baseline measured before a build is not comparable to one measured after.

Next: SLUG-1, the only High.
## iter 2/10 | 5c45e1c8-165536 | 2026-08-16 | SLUG-1 | done

Task: SLUG-1 (High) - `z.string().slugify()` silently deleted every non-ASCII letter.

Changed: `packages/zod/src/v4/core/util.ts` (slugify now runs `.normalize("NFKD").replace(/\p{M}/gu, "")` before the existing pipeline), `packages/zod/src/v4/classic/tests/string.test.ts` (6 assertions added to the existing `slugify` test), BACKLOG.md (SLUG-1 closed, SLUG-2 filed), PLAN.md (2 Lessons), `.jeffy/probes/core-util-slugify/enumerate-dropped.ts` (new), three probe files reformatted by biome.

Checkpoint: d727b19024b63e979098175e3ae5c57a7a7308e4

Verification: Ran the filed reproduction first, unfixed: `"Café Déjà"` -> `"caf-dj"`, `"über cool"` -> `"ber-cool"`, `"Ünïcödé"` -> `"ncd"`. After the fix the acceptance check passes on all 7 known-answer cases - `"Café Déjà"` -> `"cafe-deja"`, `"über cool"` -> `"uber-cool"`, `"Ünïcödé"` -> `"unicode"`, `"Tiếng Việt"` -> `"tieng-viet"`, `"ﬁle ①"` -> `"file-1"`, `"日本語 text"` -> `"text"`, `"Hello World"` -> `"hello-world"`. Verify command exits 0: 339 files, 3811 tests, no type errors. `vitest run packages/zod/src/v4/classic/tests/string.test.ts` green at 94 tests. No battery's `paths` file matches this diff (`core/util.ts` and `classic/tests/string.test.ts` are declared by none), and all four green batteries were run anyway and stayed green; the v4-locales battery is still red on LOCALE-1 as filed. Also run by hand because the Verify command does not cover them: `pnpm format:check`, `pnpm lint:check`, `pnpm check:circular` - all clean.

Two lint failures were introduced and fixed inside this iteration rather than reverted, neither of them a test regression. The probe files added in iteration 1 were not biome-clean, so `pnpm format:check` was already red before this iteration's code change - a pre-existing fault this iteration exposed by running a check the Verify command excludes, not one it introduced; `biome check --write .jeffy` fixed it and the zod source was untouched by that pass. Then biome's `noMisleadingCharacterClass` rejected the first form of the fix, `[̀-ͯ]`, even with the `u` flag; it was replaced with `\p{M}`, which is equivalent here because anything NFKD leaves behind that `\p{M}` does not match is removed by the following `[^\w\s-]` anyway - the 7 acceptance cases and the 23-character residual enumeration return identical results under both forms.

Change discipline: `util.slugify` is shared code reachable as `z.core.util.slugify`. Its callers enumerate to exactly three sites - `_slugify()` in `core/api.ts`, the `.slugify()` method and the `z.slugify()` check export in `v4/classic` - and mini does not expose it. The contract preserved is the signature `(string) => string` and all 8 pre-existing ASCII assertions in the `slugify` test, every one of which still passes; the only behavior change is that a character with a canonical NFKD decomposition now contributes its ASCII base instead of vanishing. `grep -rn slugify packages/docs/content/` returns nothing, so no documentation contradicts the new behavior and none is due. No swept Surface inventory row's implementing source is in this diff, so no row went stale.

Closed: SLUG-1 (High) - fixed in `core/util.ts`, pinned by 6 new assertions in `string.test.ts`.
Filed: SLUG-2 (Medium) - the 23 Latin letters with no canonical decomposition are still dropped, enumerated by `.jeffy/probes/core-util-slugify/enumerate-dropped.ts` as `Æ Ð Ø Þ ß æ ð ø þ Đ đ Ħ ħ ı ĸ Ł ł Ŋ ŋ Œ œ Ŧ ŧ`; non-Latin scripts are out of scope and stay dropped.

Learnings: `biome check .` includes `.jeffy/`, so probe files break `pnpm format:check` and `pnpm lint:check` if they are not biome-clean, and neither command is in the Verify command - an iteration that adds a probe has to run both by hand. Biome's `noMisleadingCharacterClass` rejects a combining-mark range in a character class even under the `u` flag; `\p{M}` is the form it accepts.

Next: EMOJI-1, the top Medium.
## iter 3/10 | 5c45e1c8-165536 | 2026-08-16 | SLUG-2 | done

Task: SLUG-2 (Medium) - `z.string().slugify()` still dropped the 23 Latin letters that NFKD cannot decompose.

Changed: `packages/zod/src/v4/core/util.ts` (module-scope `latinFold` table of 13 lowercase entries, applied after `.toLowerCase()`), `packages/zod/src/v4/classic/tests/string.test.ts` (7 assertions added), BACKLOG.md (SLUG-2 closed, one Settled class, one Declined line), `.jeffy/probes/core-util-slugify/` (the one-off enumeration script replaced by a real battery with a `paths` file).

Checkpoint: 1a37e91123e98654472b7681c10a294f47875b24

Verification: Ran the filed reproduction first, unfixed - the U+00C0-U+017F sweep returned the 23 letters `Æ Ð Ø Þ ß æ ð ø þ Đ đ Ħ ħ ı ĸ Ł ł Ŋ ŋ Œ œ Ŧ ŧ` and `"Søren"` -> `"sren"`, `"Łódź"` -> `"odz"`, `"Straße"` -> `"strae"`, `"Đà Nẵng"` -> `"a-nang"`. After the fix that sweep returns empty and the same inputs give `"soren"`, `"lodz"`, `"strasse"`, `"da-nang"`; the battery's 25 known-answer cases all pass. Verify command exits 0: 339 files, 3811 tests, no type errors. `vitest run packages/zod/src/v4/classic/tests/string.test.ts` green at 94 tests. This diff touches `packages/zod/src/v4/core/util.ts`, which exactly one battery's `paths` file claims (`.jeffy/probes/core-util-slugify/paths`, found by `grep -rl "core/util.ts" .jeffy/probes/*/paths`); that battery was run in this iteration and passes. Also run by hand because the Verify command excludes them: `pnpm format:check` and `pnpm lint:check`, both clean at 362 files.

Three-strike rule applied. SLUG-1, SLUG-2 and the Latin Extended-B remainder are three findings on one root cause - an ASCII-only `\w` filter with no fold in front of it - so instance work stops here and the class is closed at a boundary instead of patched a third time. The boundary is the fold chain in `slugify` itself, and the enumerating check that defines it sweeps every letter in U+00C0-U+017F. What the boundary deliberately excludes is recorded as a Declined line, priced rather than felt: 107 Latin Extended-B letters (IPA extensions, African and historic orthographies) plus every non-Latin script, `cost: exceeds one iteration`, because folding them needs a transliteration table an order of magnitude larger than the 13 entries that cover the living Latin orthographies. The battery reports that Extended-B count on every run and fails if it ever reaches zero, so the Declined line cannot go stale without something failing.

Change discipline: `util.slugify` keeps the signature `(string) => string` and all 8 original ASCII assertions plus the 6 added in iteration 2 still pass; the only behavior change is that the 23 enumerated letters now fold to an ASCII base instead of vanishing. `grep -rn slugify packages/docs/content/` still returns nothing, so no documentation contradicts the new behavior. No swept Surface inventory row's implementing source is in this diff - the swept rows cover `regexes.ts`, `registries.ts`, `standard-schema.ts`, `from-json-schema.ts` and `locales/*.ts`, none of which changed - so no row went stale.

Closed: SLUG-2 (Medium) - fixed in `core/util.ts`, pinned by 7 new assertions in `string.test.ts` and a 25-case battery.

Learnings: none new this iteration; the probe directory for a row should carry a `paths` file from the moment it is created, which `core-util-slugify` was missing until now.

Next: EMOJI-1, the top remaining Medium.
## iter 4/10 | 5c45e1c8-165536 | 2026-08-16 | EMOJI-1 | done

Task: EMOJI-1 (Medium) - `z.emoji()` accepted bare Emoji_Component characters.

Changed: `packages/zod/src/v4/core/regexes.ts` and `packages/zod/src/v3/types.ts` (a lookahead requiring at least one pictograph, regional indicator or keycap), `packages/zod/src/v4/classic/tests/string.test.ts` and `packages/zod/src/v3/tests/string.test.ts` (keycap acceptance plus an 8-character rejection loop each), two inline snapshots regenerated, `.jeffy/probes/core-regexes/probe.ts` (emoji row rewritten), PLAN.md (core-regexes row re-swept), BACKLOG.md (EMOJI-1 closed, TL-1 filed).

Checkpoint: 01ea8ad43d618f81b1a22509fa9895ffcb58992b

Verification: Ran the filed reproduction first, unfixed - `#`, `*`, `0`, `1`, `9`, `1234567890`, a lone ZWJ, a lone VS16 and a ZWJ+VS16 pair were all accepted, while `1️⃣` and `#️⃣` were also accepted and had to stay so. After the fix all 15 rejection cases are rejected and all 12 acceptance cases still pass, on all three surfaces - v4 classic, v4 mini and v3 - checked in one differential loop rather than on classic alone. Verify command exits 0: 339 files, 3811 tests, no type errors. `pnpm format:check` and `pnpm lint:check` clean at 362 files. This diff touches `packages/zod/src/v4/core/regexes.ts`, claimed by `.jeffy/probes/core-regexes/paths`; that battery was updated in this iteration to pin the new contract and passes. Every other battery was run too: only v4-locales is red, on LOCALE-1 as filed.

Two inline snapshots in `continuability.test.ts` and `to-json-schema.test.ts` went red because both record the emoji pattern source verbatim. They were regenerated with `vitest run <files> --update`, and the whole diff to both files is the one pattern string in each - no assertion changed meaning.

The class enumerates to exactly two sites. `grep -rn '\\p{Extended_Pictographic}' packages/zod/src` returns `v4/core/regexes.ts` and `v3/types.ts`, which carried byte-identical patterns; both are fixed rather than one, so no site is left behind and none had to be settled. v3 is legacy but ships as `zod/v3`, and a wrong verdict there is the same wrong verdict.

TL-1 filed at High, discovered while verifying this fix and not caused by it. `z.templateLiteral` rebuilds its parts' pattern sources with `new RegExp(...)` and no flags, so the `u` flag `\p{...}` needs is dropped and the composed schema rejects everything. The differential evidence is recorded: with the tree restored to HEAD by copying the fixed files aside first, `z.templateLiteral([z.string().emoji()])` rejected `"😀"`, `"1"`, `"p"`, `"pExtended_Pictographic"` and `"👋👋"` exactly as it does after the fix, and the composed pattern's flags read `""` in both runs. So the template-literal path was already dead and this iteration neither broke nor repaired it. Of the 25 string-format factories probed, `emoji` is the only one whose pattern source contains `\p{`, so it is the only part affected today; the repo's own `template-literal.test.ts` builds this exact schema and never parses with it, which is why 3811 green tests never noticed.

Change discipline: the emoji pattern is shared by `_emoji` in `core/api.ts` (reached by `z.emoji()`, `z.string().emoji()` and mini's `emoji()`), by `from-json-schema.ts` for `format: "emoji"`, and by the v3 `emoji` check. The contract preserved is that every string the old pattern accepted which contains a pictograph, a regional indicator or a keycap is still accepted - all 6 pre-existing acceptance cases in each of the two test files pass unchanged, including the 4000-character emoji corpus in the v3 test. What narrows is only the set of strings made exclusively of standalone Emoji_Component characters. `packages/docs/content/api.mdx` documents `z.emoji()` as "validates a single emoji character", which was already wrong before this change and is filed as DOCS-1; this change does not make it more wrong, and DOCS-1 still owns it.

Closed: EMOJI-1 (Medium) - fixed in `v4/core/regexes.ts` and `v3/types.ts`, pinned by rejection loops in both test suites and by the core-regexes battery.
Filed: TL-1 (High) - `z.templateLiteral` drops the `u` flag when composing part patterns, so any emoji part makes the schema reject all input.

Learnings: a pattern that only ever gets `.test()`ed directly can be dead in every composed context and still pass a full suite; when changing a `_zod.pattern`, exercise it through `z.templateLiteral` and `z.toJSONSchema` as well, because both re-emit the source into a place that cannot carry the flags.

Next: TL-1, now the only High.
## iter 5/10 | 5c45e1c8-165536 | 2026-08-16 | TL-1 | done

Task: TL-1 (High) - `z.templateLiteral` dropped the unicode flag when composing its parts' patterns, so any emoji part produced a schema that rejected every input.

Changed: `packages/zod/src/v4/core/schemas.ts` (`$ZodTemplateLiteral` now tracks whether any part's pattern carries `u` or `v` and compiles the composed regex with `u` when one does), `packages/zod/src/v4/classic/tests/template-literal.test.ts` (new test with 11 assertions), BACKLOG.md (TL-1 closed, TLI-1 filed).

Checkpoint: e1a9be5757188fd0bfc0dc4e35a52da7c107e27e

Verification: Ran the filed reproduction first, unfixed - composed flags `""`, and `z.templateLiteral([z.string().emoji()])` rejected `"😀"` while `z.templateLiteral(["a", z.string().emoji()])` rejected `"a😀"`. After the fix the composed flags read `"u"` and all 13 checks pass: `"😀"` and `"👋👋"` accepted, `"1"` and `"a"` rejected, `"a😀"` accepted, `"a1"` and a bare `"😀"` rejected against the prefixed form, and `z.templateLiteral(["id-", z.number(), "-", z.string().emoji()])` accepting `"id-12-😀"` and rejecting `"id-12-x"`. Verify command exits 0: 339 files, 3813 tests (up 2), no type errors. No battery declares `core/schemas.ts` in its `paths`, but all six were run: only v4-locales is red, on LOCALE-1 as filed. `pnpm format:check`, `pnpm lint:check` clean at 362 files, `pnpm check:circular` clean.

Unioning `u` onto the whole composed pattern is safe rather than merely convenient, and that was checked rather than assumed: compiling the pattern source of all 29 probed factories with the `u` flag raises no error, so no zod-generated sibling part can be broken by the flag, and a part that never needed it does not acquire it - `z.templateLiteral(["v", z.number()])` still reports flags `""`.

One behavior change worth naming. A part carrying a hand-written regex that is legal without `u` but not under it - `z.string().regex(/a{/)` is the canonical shape - now throws at schema construction when combined with an emoji part, where before it constructed silently and rejected every input. That trade is deliberate: both states are broken, and a loud definition-time error naming the offending regex is what the envelope prescribes for the user-error surface that schema definitions live on, where the old behavior was a silent total failure indistinguishable from a strict schema.

TLI-1 filed at Medium, found while fixing this and deliberately not folded in. The same composition also drops a part's `i` flag: `z.boolean()`'s pattern is `/^(?:true|false)$/i` and matches `"TRUE"` alone, but `z.templateLiteral(["v=", z.boolean()])` rejects `"v=TRUE"` while accepting `"v=true"`. It is the same site and the same root cause, but not the same fix, which is the whole reason it is a separate task: `u` may be unioned across the composed pattern because it only tightens siblings, whereas unioning `i` would loosen them - `z.templateLiteral([z.literal("ABC"), z.boolean()])` rejects `"abctrue"` today and must keep rejecting it. Scoping case-insensitivity to a single part needs either `(?i:...)` modifier groups, too new to require of a library that runs on old browsers, or a source rewrite that folds letters without corrupting escapes like `\d`. Two findings now share this composition site; a third ends instance work and closes the class at the boundary instead.

Change discipline: `$ZodTemplateLiteral` is core, reached by `z.templateLiteral` in classic and mini and by nothing else. The contract preserved is that a composed pattern's source is byte-identical to before - only the flags argument changed - so the `pattern` string in `invalid_format` issues and in emitted JSON Schema is unchanged, and the 16 pre-existing template-literal assertions all still pass. No documentation states the flag behavior, and no swept Surface inventory row's implementing source is in this diff.

Closed: TL-1 (High) - fixed in `core/schemas.ts`, pinned by 11 assertions in `template-literal.test.ts`.
Filed: TLI-1 (Medium) - the same composition drops a part's `i` flag, narrowing what the schema accepts.

Learnings: when a composed regex is built from other patterns' `.source`, the flags are the part of the contract that silently disappears; check `.flags` on both sides, not just the source.

Next: TLI-1 or LOCALE-1, the top Mediums.
## iter 6/10 | 5c45e1c8-165536 | 2026-08-16 | TLI-1 | done

Task: TLI-1 (Medium) - `$ZodTemplateLiteral` dropped a part's `i` flag when composing.

Changed: `packages/zod/src/v4/core/regexes.ts` (the `boolean`, `null` and `undefined` patterns lost their `i` flag), `packages/zod/src/v4/core/schemas.ts` (the composition now refuses a flag it cannot scope), `packages/zod/src/v4/classic/tests/template-literal.test.ts` (new test, 7 assertions), `.jeffy/probes/core-regexes/probe.ts` (flag assertions added), PLAN.md (core-regexes re-swept), BACKLOG.md (TLI-1 closed, one Settled class, one Proposed item).

Checkpoint: aa53e822d1415a03bee8255dfcbe4da47645ce18

Verification: Verify command exits 0: 339 files, 3815 tests (up 2), no type errors. `pnpm format:check` and `pnpm lint:check` clean at 362 files. This diff touches `core/regexes.ts`, claimed by `.jeffy/probes/core-regexes/paths`; that battery was extended this iteration and passes, and all six were run - only v4-locales is red, on LOCALE-1 as filed. The whole diff to the repo's snapshots is empty: every composed pattern source is byte-identical to before, which is the clearest evidence that only flags changed.

I filed TLI-1 with the wrong acceptance check and it did not survive contact with the evidence. The task asserted that `z.templateLiteral(["v=", z.boolean()]).safeParse("v=TRUE")` should become true. It should not. `template-literal.test.ts` pins `z.infer<typeof bool>` as `` `true` | `false` `` and `z.infer<typeof anotherNull>` as `` `null` ``, so a case-insensitive runtime would accept strings the static type rejects, in a library whose premise is that the two agree. Dropping `i` during composition was accidentally producing the correct result. The real defect is narrower than filed: a flag that changes how a source matches was being discarded in silence, and for a hand-written part like `z.string().regex(/abc/i)` that silently narrows what the author asked for.

So the fix runs the other way. The three built-in patterns that carried `i` now spell out the case-sensitive form their template-literal type already required, and the composition refuses `i` and `s` with an error naming the flag rather than dropping it. My first attempt did the opposite - it rewrote those patterns as character classes to preserve case-insensitivity through composition - and it was the two snapshot failures on `^null$` that exposed the type contract and sent me to read the type assertions. That attempt is not in the diff.

The enumeration was also wrong the first time and had to be rebuilt by provoking the failure rather than by listing factories. Iteration 5 enumerated 29 factories from memory and concluded `boolean` was the only `i`-carrying pattern; the verify gate then failed at `z.templateLiteral(["", z.undefined()])`, because `null` and `undefined` carry it too. The enumeration that stands is a sweep over every part shape the test file actually builds, cross-checked against `grep -rnE '/[imsu]*i[imsu]*;$' packages/zod/src/v4 --include='*.ts'`, and both agree on exactly three sites, all in `core/regexes.ts`.

Equivalence was measured, not assumed, for the intermediate character-class form: 244 inputs for `boolean`, 24 for `null`, 520 for `undefined`, including every case variant of each word and single-character mutations over an alphabet holding the long s and the Kelvin sign, with zero divergences from the original `i`-flagged regexes. That measurement is what let me discard the approach on type grounds rather than on doubt about its correctness.

This closes the class rather than a third instance. TL-1 and TLI-1 both came from `$ZodTemplateLiteral` discarding its parts' flags, so the boundary is the composition itself: `u`/`v` propagate, `i`/`s` are refused, and no built-in pattern carries either. The enumerating check lives in the core-regexes battery and asserts that `emoji` is the only built-in pattern with any flag at all.

Change discipline: `regexes.boolean`, `regexes.null` and `regexes.undefined` have exactly one consumer each, the `_zod.pattern` assignments in `core/schemas.ts`, which feed template-literal composition and JSON Schema emission. The dynamic `core.regexes[format]` lookups in classic and mini reach only `${alg}_${enc}` hash formats and cannot select these. The contract preserved is every pattern's source, unchanged byte for byte, so issue `pattern` fields and emitted JSON Schema are untouched; what changes is that a standalone `z.boolean()._zod.pattern` no longer matches `"TRUE"`. Whether that standalone case-insensitivity was wanted anywhere is a decision for the user, filed under Proposed rather than settled by me.

Closed: TLI-1 (Medium) - resolved against the type contract rather than as filed, pinned by 7 assertions in `template-literal.test.ts` and by the core-regexes battery.

Learnings: build the enumeration by provoking the failure, not by listing call sites from memory - the factory list written from memory missed two of three sites and the verify gate found them. When a fix changes a value's string form, read the inferred type the tests pin before deciding which direction is correct; the type is the contract.

Next: LOCALE-1.
## iter 7/10 | 5c45e1c8-165536 | 2026-08-16 | LOCALE-1 | done

Task: LOCALE-1 (Medium) - the Armenian locale read `issue.values[1]` inside the branch guarded by `issue.values.length === 1`, so every single-value `invalid_value` message rendered "expected undefined".

Changed: `packages/zod/src/v4/locales/hy.ts` (one index), `packages/zod/src/v4/core/tests/locales/hy.test.ts` (new, matching the shape of the eleven locale tests already in that directory), PLAN.md (v4-locales row re-swept), BACKLOG.md (LOCALE-1 closed).

Checkpoint: afc86edd01ea5941f59d038befa4a8d444612e71

Verification: Ran the filed reproduction first, unfixed - the v4-locales battery reported `FAIL hy invalid_value did not interpolate qqq: "Սխալ մուտքագրում․ սպասվում էր undefined"`. Both acceptance conditions now hold: the battery exits 0 with `LOCALES OK (52 locales x 11 codes)`, and the class enumeration `grep -rn 'issue.values\[' packages/zod/src/v4/locales/*.ts packages/zod/src/v3/locales/*.ts | grep -v 'values\[0\]'` returns nothing, so no sibling locale carries the same off-by-one. This diff touches `packages/zod/src/v4/locales/hy.ts`, claimed by `.jeffy/probes/v4-locales/paths`; that battery is the acceptance check and passes. Verify command exits 0: 341 files, 3817 tests, no type errors. `pnpm format:check` and `pnpm lint:check` clean at 363 files.

The new test pins both branches, not just the fixed one: `z.literal("blue")` against `"red"` takes the single-value branch and must name `"blue"`, and `z.enum(["red", "green"])` against `"blue"` takes the multi-value branch and must list both. A test covering only the first would pass against an implementation that deleted the second.

Replenishment deferred, and the reason is recorded rather than left implicit. Closing this task leaves 2 open items, below the threshold of 3 that normally triggers a partial audit, and the run is not in closeout - the iteration 1 audit found both High and Medium. The queue is not short of work: it holds 23 unswept Surface inventory rows, which outrank every open Low, so there is no risk of the loop idling. With 3 iterations left, a partial audit would spend one of them filing findings the run has no budget to close, while ATTW-1, DOCS-1 and a sweep are already scheduled and reachable.

Change discipline: `hy.ts` is a leaf module with one consumer, the locale registry reached by `z.config(hy())`; no other module imports it. The contract preserved is the message text of all ten other issue codes, unchanged, and both `invalid_value` branches keep their original wording - only the index moved. No documentation states locale message content, and the only swept Surface inventory row whose source this diff touches is v4-locales, re-swept in this same iteration by the battery that owns it.

Closed: LOCALE-1 (Medium) - fixed in `v4/locales/hy.ts`, pinned by the new `hy.test.ts` and by the v4-locales battery, which is green for the first time this run.

Learnings: none new this iteration.

Next: ATTW-1.
## iter 8/10 | 5c45e1c8-165536 | 2026-08-16 | ATTW-1 | done

Task: ATTW-1 (Medium) - `packages/resolution/attw.test.ts` asserted nothing on an unbuilt checkout and could not skip when `pnpm` was off the child process PATH.

Changed: `packages/resolution/attw.test.ts` (both bail-outs now call `ctx.skip(...)`), PLAN.md (Environment fingerprint re-derived), BACKLOG.md (ATTW-1 closed, one Settled class).

Checkpoint: b3e0a4935e4c4196e94b2b8b1eee01b3e0c9bf5d

Verification: Both failure modes were reproduced before the fix and re-run after it, on the real command rather than by reading the code. With `pnpm` off the default PATH and zod built, the unfixed test failed with `Unexpected console.warn call: attw not available, skipping test`; it now reports `Tests 1 skipped` and exits 0. With `packages/zod/index.js` moved aside so the `existsSync` guard fires, the unfixed test reported `Tests 1 passed` having asserted nothing; it now reports `Tests 1 skipped`. With both present it reports `Tests 1 passed` and runs the snapshot for real. `index.js` is a gitignored build artifact and was restored immediately in both directions; `git status` is clean.

The third mode needed proof that the pass is not vacuous, so the inline snapshot was mutated - one `🟢` changed to `🔴` - and the suite went red with `Snapshot ... mismatched`, exit 1, then went green again when the file was restored from the copy taken before the mutation. A check that cannot fail proves nothing, and this one fails.

The class enumeration now returns one site instead of two. `grep -rn 'console\.\(warn\|log\|error\)' --include='*.test.ts' packages | grep -v node_modules | grep -vE ':\s*//'` returns only `to-json-schema.test.ts`, whose `console.error` is deliberate - its own comment says it should make vitest throw - so no site is left unsettled.

The fingerprint claim this fix invalidated was re-executed rather than left standing. PLAN.md previously recorded that "no skip marker or platform guard exists in the test tree", derived from a command that greps for `\.(skip|todo|skipIf|runIf)\(`. That command now returns the two `ctx.skip(...)` calls this fix introduced, so the Environment fingerprint was rewritten to name them and to state the condition under which they fire. It also now says what a skip would mean: under the recorded Verify command both conditions hold, so a run that reports this test skipped has not checked package resolution at all.

Verify command exits 0: 341 files, 3817 tests, no type errors, with attw asserting rather than skipping because the Verify command carries `pnpm` on PATH. `pnpm format:check` and `pnpm lint:check` clean at 363 files. All six batteries pass, the first iteration in this run where none is red.

Change discipline: `attw.test.ts` is a leaf test file with no importers. The contract preserved is the assertion itself - the inline snapshot is untouched, as is the 120s timeout and the `execa` invocation - and only the two bail-out paths changed shape. `ctx.skip()` is typed to return `never`, so the code after each guard still narrows correctly and no type error appears. No Surface inventory row covers `packages/resolution`, and no battery declares that path.

Closed: ATTW-1 (Medium) - fixed in `packages/resolution/attw.test.ts`, evidenced by running all three environment combinations before and after and by a mutation check on the snapshot.

Learnings: a test that bails with `return` reports a pass, and under `scripts/fail-on-console.ts` a `console.warn` bail reports a failure; `ctx.skip(reason)` is the only one of the three that reports what actually happened.

Next: DOCS-1, the last open item.
## iter 9/10 | 5c45e1c8-165536 | 2026-08-16 | DOCS-1 | done

Task: DOCS-1 (Medium) - the docs described `z.emoji()` as validating "a single emoji character" while the suite pins multi-emoji strings as valid.

Changed: `packages/docs/content/api.mdx` and `packages/docs/content/v4/changelog.mdx` (one comment each, now reading `// one or more emoji, nothing else`), BACKLOG.md (DOCS-1 closed).

Checkpoint: a396b60c5f689930db67715812a02669e7fb52e4

Verification: The acceptance grep `grep -rn 'single emoji character' packages/docs/content` returned both sites before the change and returns nothing after. The replacement wording was checked against the running code rather than against the old sentence, both halves of it: "one or more emoji" holds for a single pictograph, four repeated ones, a ZWJ family sequence, a regional-indicator flag and a keycap, all accepted; "nothing else" holds for `"😀stuff"`, `"😀 is an emoji"`, `"1"` and `":-)"`, all rejected. Every one of those nine cases is also pinned by an assertion in `string.test.ts`, so the sentence and the test suite now say the same thing. Verify command exits 0: 341 files, 3817 tests, no type errors. `packages/docs/api.test.ts`, which compares code-fence heights between the Zod and Zod Mini tabs, passes - the edit changed a comment's text and not any line count. `pnpm format:check` and `pnpm lint:check` clean at 363 files. No battery declares a path under `packages/docs`.

Both sites were edited rather than only the api.mdx one. The changelog occurrence is not a historical statement being rewritten; it sits inside a code block that lists the string-format API, the same list api.mdx carries, and it was describing current behavior incorrectly in exactly the same way.

The wording also had to absorb what iteration 4 changed. Before that fix `z.emoji()` accepted bare `#`, `*`, digits, a lone ZWJ and a lone VS16, so "nothing else" would have been false then; it is true now, and the docs sentence would have been wrong in a second way if it had been written before that iteration.

Replenishment deferred again, with the reason recorded. Closing this empties the ledger, and the run is not in closeout - the iteration 1 audit found both High and Medium, so no clean full audit exists this run and convergence is not reachable regardless: the Definition of done also requires no unswept Surface inventory row, and 23 of 28 are unswept. One iteration remains, so a partial audit would file findings nothing can close, while the queue already holds those 23 rows as scheduled work that outranks any Low such an audit would produce.

Change discipline: both files are documentation with no importers. The contract preserved is the code sample itself - every `z.*()` call in both lists is unchanged, only a trailing comment differs - and the tabbed-example height test that guards api.mdx still passes. No Surface inventory row covers `packages/docs`.

Closed: DOCS-1 (Medium) - fixed in `api.mdx` and `v4/changelog.mdx`, evidenced by the acceptance grep and by nine behavioral checks that the new sentence describes.

Learnings: none new this iteration.

Next: final iteration - a WRAPUP with a handoff, and a sweep of whatever inventory rows can carry real evidence inside it.

## iter 10/10 | 5c45e1c8-165536 | 2026-08-16 | WRAPUP | done

Task: final iteration. The ledger was empty and 23 of 28 Surface inventory rows were unswept, so sweeping was the top of the queue; this entry is the sweep plus the handoff.

Changed: `.jeffy/probes/core-schemas-primitives/`, `.jeffy/probes/core-schemas-collections/`, `.jeffy/probes/core-schemas-wrappers/` and `.jeffy/probes/core-errors/` (four new batteries, each with a `paths` file), PLAN.md (four rows flipped), BACKLOG.md (SUCCESS-1 filed).

Checkpoint: 9d190fa82eda49eb971b3bc8a8dc8d47011215d3

Verification: Four rows swept, taking the inventory from 5 of 28 to 9 of 28. Each battery is known-answer, not liveness: primitives covers 13 type gates with accept and reject sets and every documented numeric, string and date check at both sides of its boundary, plus all six coercions shown changing the accepted set relative to their uncoerced form; collections shows the three object unknown-key policies differing on one input, the exhaustive-enum-key record rule, and file mime/min/max; wrappers carries a 12-row absent-object-key matrix whose outcomes must differ from one another; errors pins one known answer per issue code plus the field-versus-form split in `flattenError` and a locale swap that changes the message and restores it. Verify command exits 0: 341 files, 3817 tests, no type errors. `pnpm format:check` and `pnpm lint:check` clean at 367 files, after `biome check --write .jeffy` fixed formatting in the four new probes. Nine of the ten batteries pass; core-schemas-wrappers is red and reproduces SUCCESS-1.

The sweep found one High. `z.success(schema)` can never return `false`: `$ZodSuccess` sets `payload.value = result.issues.length === 0` but never clears `payload.issues`, and because `innerType._zod.run` mutates the same payload object the inner issues survive and the parse fails instead of yielding the boolean. `z.success(z.string()).safeParse(1)` returns `{success: false, issues: ["invalid_type"]}` where the contract calls for `{success: true, data: false}`; the true half works. It is the same on mini, and inside an object the field takes the whole parse down. This is exactly the defect class the inventory exists to catch - the only coverage `z.success` has is three type-level `satisfies` assertions, so its entire failure branch was dead code that 3817 green tests walked past. Filed as SUCCESS-1 at High and left open: it arrived on the final iteration with no budget to fix it, and the battery that found it stays red so the next run reproduces it as its first command.

Two expectations of mine were wrong and were corrected against the code rather than filed as findings. A set propagates its element's own issue rather than wrapping it in `invalid_element`, with an empty path because a set has no index; `invalid_element` is emitted by the map value path instead, for keys that are not property-key types. Both readings are now pinned in the errors battery as the real contract.

Convergence is not reachable this run and no declaration is attempted. The Definition of done requires a full fresh-evidence audit scoring zero High and zero Medium, and the only full audit this run is iteration 1, which found both. It also requires no unswept inventory row, and 19 remain. The evaluator gate was therefore not invoked: it exists to guard a declaration, and there is no declaration to guard.

Handoff for the next run. The queue starts with SUCCESS-1, the one open High, whose reproduction is `./node_modules/.bin/tsx --conditions @zod/source .jeffy/probes/core-schemas-wrappers/probe.ts`. After it, 19 unswept rows outrank any Low; the heaviest unmapped surface is `v3/types.ts` at 5138 lines across three rows, and `core/api.ts`, `core/checks.ts` and `core/util.ts` are each a row of their own. One Proposed item awaits a decision. Reaching convergence needs enough budget to sweep 19 rows and then run one clean full audit, which is several runs at this pace, not one.

Learnings: a battery written for a sweep found a High that the project's own 3817 tests did not, because those tests assert types where behavior was never exercised - a `satisfies` assertion proves a shape compiles, never that the function computes anything.

Next: SUCCESS-1, then the 19 remaining inventory rows.
## iter 1/10 | 21291e32-175119 | 2026-08-16 | SUCCESS-1 | done

Task: SUCCESS-1 (High) - `z.success(schema)` could never return `false`. Fixed class-complete: the same root cause was live in `$ZodCatch` as well.

Changed: `packages/zod/src/v4/core/schemas.ts` (`$ZodSuccess` and `$ZodCatch`), `packages/zod/src/v4/classic/tests/success.test.ts` (new), `packages/zod/src/v4/classic/tests/catch.test.ts`, `packages/zod/src/v4/mini/tests/index.test.ts`, `.jeffy/probes/core-schemas-wrappers/probe.ts`, PLAN.md, BACKLOG.md.

Checkpoint: 89ad80e35a70a7d1dce923f97fc6960ad11aa92a

Verification: The filed reproduction ran first and failed as filed - `.jeffy/probes/core-schemas-wrappers/probe.ts` exited 1 with `FAIL success is false for invalid input: got "THREW:invalid_type" want false`. It exits 0 after the fix.

The root cause is that `innerType._zod.run(payload, ctx)` mutates the payload it is handed rather than returning a fresh one, so a wrapper that means to swallow the inner failure has to clear what the inner wrote. `$ZodSuccess` set `payload.value` and cleared nothing, which is why the `false` branch was unreachable. Clearing `payload.issues` alone is not enough: `handlePipeResult` and `handleCodecAResult` set `payload.aborted = true` on that same object, and `util.aborted` short-circuits `runChecks`, so a pipe or codec inner disables the wrapper's own checks without any issue to show for it.

That second half is what made this a class rather than an instance. The enumeration is `grep -n 'issues = \[\]' packages/zod/src/v4/core/schemas.ts`, which returns four sites - the sync and async branches of `$ZodSuccess` and `$ZodCatch`, the only two failure-absorbing wrappers in the tree, with no counterpart in `v3`. Each of the four was driven by provoking a failure through a plain inner and through a pipe inner, not by reading the source: before the fix, `z.catch(z.string().pipe(z.transform(...)), 99).refine(() => false)` returned `{success: true, data: 99}` with the refinement never called, while the same schema over a plain `z.string()` inner reported the refinement failure. A wrapper whose checks fire or not depending on the inner schema's internal representation is the defect, and both wrappers now clear `aborted` alongside `issues`.

The acceptance checks were run against the unfixed code to confirm they can fail, by copying the fixed `schemas.ts` aside and restoring `git show HEAD:` over it - never `git checkout`, which would have deleted the fix. Unfixed: 5 of the new tests fail and the battery reports 5 failures. Fixed: 46 passed in those two test files, battery `WRAPPERS OK`. The restore was confirmed byte-identical with `diff -q` both times.

One of my own checks was too weak and was caught by exactly that step. `expect(plain.safeParse(1).success).toBe(false)` passes on the broken code too, because the leaked `invalid_type` also makes the parse fail - the assertion cannot tell a refinement that ran from an inner issue that leaked. Both the test and the battery now assert the issue's `message`, which is what makes them discriminating.

Verify command exits 0: 343 files, 3829 tests, no type errors, up from 341 and 3817 by the six new runtime tests and their typecheck passes. All 10 batteries pass. `pnpm format:check` and `pnpm lint:check` clean at 368 files.

Change discipline: `$ZodSuccess` and `$ZodCatch` are public through `z.success`, `z.catch` and `.catch()` on both classic and mini. The contract preserved is every documented behaviour of both - catch still returns its fallback on failure, still leaves a valid value untouched, still passes the finalized issues to a fallback function, and still sets `fallback = true`; success still throws `$ZodEncodeError` on encode and still yields `true` on a valid inner parse. What changed is only the failure state left on the returned payload, which no documented behaviour describes. The full `catch.test.ts` and `codec.test.ts` suites pass unchanged. Neither wrapper's documentation states anything about the payload, so no docs edit was owed; that `z.success` has no prose documentation at all is filed separately as SUCCESS-DOC-1.

Three Surface inventory rows record sweeps of `packages/zod/src/v4/core/schemas.ts` and this iteration changed that file, which makes them stale. Rather than flip them to unswept, their batteries were re-run green against the fixed code in this same iteration - primitives, collections and wrappers - which is a re-sweep, so the three rows carry this iteration's checkpoint instead. The wrappers battery was extended in the same iteration as the behaviour it pins, with the four-site enumeration and the object-nesting case.

Closed: SUCCESS-1 (High) - fixed in `packages/zod/src/v4/core/schemas.ts`, evidenced by the filed reproduction failing first and passing after, by a differential run of all five new assertions against unfixed code, and by the four-site enumeration driven at every site.

Filed: SUCCESS-DOC-1 (Low, docs) - the Success section of `packages/docs/content/codecs.mdx` is inside an MDX comment, so `z.success` is undocumented on the published page.

Learnings: an assertion that a parse merely failed is satisfied by the wrong issue, so a check meant to pin which check ran has to assert the issue's code or message; and a payload-mutating `run` means a wrapper that absorbs an inner failure must clear `aborted` as well as `issues`.

Next: the 19 unswept Surface inventory rows, which outrank the one open Low.
## iter 2/10 | 21291e32-175119 | 2026-08-16 | SWEEP | done

Task: sweeping. No High and no Medium were open, so 19 unswept Surface inventory rows were the top of the queue; four were swept with new known-answer batteries.

Changed: `.jeffy/probes/core-schemas-string-formats/`, `.jeffy/probes/core-schemas-composites/`, `.jeffy/probes/core-checks/` and `.jeffy/probes/core-util/` (four new batteries, each with a `paths` file), PLAN.md (four rows flipped), BACKLOG.md (FUNC-ERR-1 and CYCLE-1 filed).

Checkpoint: 78ad0823789218f10ed563756da7ed67832385ec

Verification: The inventory moves from 9 of 28 to 13 of 28. Each battery is known-answer rather than liveness. String formats drives all 24 concrete classes with an accept and a reject apiece and every documented parameter at values that must split the accepted set - `uuid({version})` at v4 and v7 against UUIDs that differ in one nibble, `iso.datetime` at precision 0 and 3 and at both `offset` and `local`, `iso.time` precision, `jwt({alg})`, and `hash(alg, {enc})` where alg sets the digest length and enc the alphabet. Composites drives all eight classes: union branch order and the `invalid_union` shape, discriminated-union routing including that a matched member reports its own field error rather than a union of complaints, intersection merge and the unmergable case, lazy recursion with the full issue path, promise, function, template literal with a part's own constraint reaching the composed pattern, and custom including `z.instanceof`. Checks drives all 21 live check classes at both sides of every boundary, each substring needle at two values that split one input, and `$ZodCheckOverwrite` shown feeding the checks after it. Util pins the pure functions with known answers and round trips - the three byte codecs over all 256 byte values, `+`/`/` against `-`/`_` to tell base64 from base64url, `floatSafeRemainder` on both sides of its contract, and the numeric format ranges.

Verify command exits 0: 343 files, 3829 tests, no type errors. `pnpm format:check` and `pnpm lint:check` clean at 372 files, after `biome check --write .jeffy` formatted the four new probes. Thirteen of the fourteen batteries pass; core-schemas-composites is red and reproduces both findings this sweep filed.

Two findings, both filed at Medium. `z.function(...).implement()` throws core's `$ZodError` rather than the classic `ZodError`, so the idiomatic `e instanceof z.ZodError` handler misses it and `.flatten()`/`.format()` are absent on what it does catch; the cause is that `core/schemas.ts` imports `parse`/`parseAsync` from `core/parse.js`, which is bound to core's error class, while every other classic entry point goes through `classic/parse.ts`. Three sites, enumerated by provoking a failure at each rather than by reading imports: bad argument, bad return value, and the same through `implementAsync`. The existing `function.test.ts` cases assert a bare `.toThrow()`, which any error satisfies, which is why 3829 green tests never saw it. Separately, `safeParse` throws `RangeError` on a value containing a reference cycle - `z.json()`, a `z.lazy()` schema and `z.record(z.string(), z.json())` all do, while a non-recursive schema over the same value and a 500-deep finite value both return normally, so the trigger is the cycle rather than depth. CYCLE-1 is filed below the High the rubric gives a crash on in-envelope input, and the rationale is on its task line: no deserialization boundary can produce a cycle, so the input has to be constructed in memory by the calling program rather than arriving from the adversarial surface.

Five expectations of mine were wrong and were corrected against the code rather than filed. `z.xid()` accepts uppercase because its regex spells out `A-V` beside `a-v` - a deliberate choice, not an omission, and no doc claims otherwise. String length is `String.prototype.length`, so UTF-16 code units rather than code points. `floatSafeRemainder` despite its name returns `ratio - round(ratio)`, so the only usable contract is zero-iff-multiple, and that is what the battery now pins on both sides. `normalizeParams` turns a string into an error thunk, not an error string. And `.finite()` is a documented v4 no-op, which the battery now records as a no-op on both sides instead of claiming the check does something.

The checks row's scope line greps `export const $ZodCheck` unanchored, which also matches commented-out code. Anchoring it splits 27 into 22 live exports and 5 classes commented out in full - `$ZodCheckFinite`, `$ZodCheckJSONString`, `$ZodCheckFileName`, `$ZodCheckTrim`, `$ZodCheckNormalize`. Trim and normalize survive as `_overwrite` shorthands and are driven through `$ZodCheckOverwrite`; the other three have no live surface. The row and the battery header both say so now, so the count is not silently inflated by dead code.

Change discipline: this iteration changed no source file. Four probe directories were added under `.jeffy/probes/` and the three state files were edited, so no public contract was touched and no battery pins behaviour that changed. `gh` is not installed on this host, so the upstream stance on cyclic input could not be checked; both findings rest on behaviour reproduced here.

Closed: none. This was a sweep iteration.

Filed: FUNC-ERR-1 (Medium, runtime) and CYCLE-1 (Medium, runtime), both reproduced by the composites battery.

Learnings: an unanchored `grep 'export const X'` counts commented-out code as live surface, so a scope line that defines a row has to anchor at `^`; and a battery assertion written from what a function's name implies rather than from what it returns produced three of this iteration's five wrong expectations.

Next: FUNC-ERR-1, then CYCLE-1, then the 15 remaining unswept rows.
## iter 3/10 | 21291e32-175119 | 2026-08-16 | FUNC-ERR-1 | done

Task: FUNC-ERR-1 (Medium) - `z.function(...).implement()` and `.implementAsync()` threw core's `$ZodError` instead of the classic `ZodError`, so `catch (e) { if (e instanceof z.ZodError) ... }` did not match and `.flatten()`/`.format()` were absent on what it did catch.

Changed: `packages/zod/src/v4/core/schemas.ts` (`$ZodFunctionInternals` gains an optional `Err`, and `implement`/`implementAsync` pass it through), `packages/zod/src/v4/core/parse.ts` (the two `_params` types widened to `Err?: $ZodErrorClass | undefined`), `packages/zod/src/v4/classic/schemas.ts` (`ZodFunction` sets `inst._zod.Err = ZodRealError`), `packages/zod/src/v4/classic/tests/function.test.ts`, BACKLOG.md.

Checkpoint: d16c5c5ea2230fea6bd5f050f5a94c6c4c053083

Verification: The filed reproduction ran first and failed as filed, all three sites. `core/parse.ts` already accepted an `Err` override on `_parse`/`_parseAsync` and simply had no caller; the four call sites at issue are the only places in `core/schemas.ts` that reach for the top-level `parse`/`parseAsync` rather than `_zod.run`, which is why this one schema is the only one that hardcoded an error class. The fix routes the class through the instance instead of the module, so each entry point keeps its own: classic now throws `ZodError` with `.flatten()` present, and mini is deliberately untouched - it re-exports core's `parse`, so `z.function` and `z.string().parse(1)` both throw `$ZodError` there and mini stays internally consistent, which was already true before this change.

The new test fails against unfixed code and so does the battery: with the three source files swapped back to `git show HEAD:` and restored byte-identically after, the test reports 1 failed of 38 and the battery reports the three `function` labels. Verify command exits 0: 343 files, 3831 tests, no type errors, up from 3829 by the new test and its typecheck pass. All 14 batteries run; 13 pass and core-schemas-composites is red on exactly the three CYCLE-1 labels, which is the next task. `pnpm format:check`, `pnpm lint:check` clean at 372 files, `pnpm check:circular` reports no cycle - worth running because this iteration added a `classic/schemas.ts -> classic/errors.js` edge that did not exist - and `pnpm build` exits 0.

A type error surfaced that a runtime-only check would have missed. Under `exactOptionalPropertyTypes: true`, passing `{ Err: inst._zod.Err }` where `Err` is `$ZodErrorClass | undefined` does not satisfy `Err?: $ZodErrorClass`. The two `_params` declarations in `core/parse.ts` now read `Err?: $ZodErrorClass | undefined`, which is the idiom the codebase already uses elsewhere (`alg?: util.JWTAlgorithm | undefined`), and no runtime behaviour changes because `_params?.Err ?? _Err` already handled undefined.

I destroyed a file mid-iteration and the verify gate caught it. The differential step copied three files aside as `/tmp/<basename>.fixed`, and two of them are named `schemas.ts` - `core/schemas.ts` and `classic/schemas.ts` - so the second copy overwrote the first and the restore wrote classic's content over core's. The verify run went from green to 174 failed files with `Cannot find module core/iso.js`, which is what a classic file sitting in core's directory looks like. Recovery was to restore `core/schemas.ts` from `git show HEAD:` and re-apply the four edits from a script that asserts each old string occurs exactly once, then re-read the whole diff before continuing. Nothing was lost and no checkpoint was made in the broken state.

Change discipline: `$ZodFunction` is public through `z.function` on classic and mini. The contract preserved is every documented behaviour - argument and return validation still run, still in the same order, `implement()` still rejects a non-function with a plain `Error`, and the async variants still await. What changed is only which error class is constructed on failure, and only for the classic entry point, whose own `.parse` already threw that class. The existing `function.test.ts` assertions are untouched and still pass; they used a bare `.toThrow()`, which any error satisfies, and that is why this went unnoticed. No documentation states the error class for `implement`, so none needed updating. The Surface inventory row core-schemas-composites covers this code and is re-swept at this iteration's checkpoint rather than flipped to unswept, because its battery was re-run against the fixed code in this same iteration.

Closed: FUNC-ERR-1 (Medium) - fixed across `core/schemas.ts`, `core/parse.ts` and `classic/schemas.ts`, evidenced by the reproduction failing first, by a differential run of the new test and the battery against unfixed code, and by mini's behaviour shown unchanged.

Learnings: when copying several files aside for a differential run, key the copies by their full path and not by basename - two files in this repo are named `schemas.ts` and the collision silently overwrote a 6800-line source file with a different one.

Next: CYCLE-1, then the 15 remaining unswept rows.
## iter 4/10 | 21291e32-175119 | 2026-08-16 | CYCLE-1 | done

Task: CYCLE-1 (Medium) - `safeParse` threw `RangeError: Maximum call stack size exceeded` on a value containing a reference cycle, instead of returning a result.

Changed: `packages/zod/src/v4/core/parse.ts` (a `runOrOverflow` helper on the four boundary entry points), `packages/zod/src/v4/core/schemas.ts` (`$ZodLazy` marks the context, `ParseContextInternal` gains the marker), `packages/zod/src/v4/classic/tests/lazy.test.ts`, BACKLOG.md.

Checkpoint: 1a20a66bf280332fba2ee37ede17fb67ba739b98

Verification: The filed reproduction ran first and failed as filed, all three sites.

The first fix I wrote was wrong and measuring it is what showed that. It tracked the objects on the current recursion path in `$ZodLazy`, adding on the way in and deleting on the way out, which rejects a true cycle while accepting a DAG. It passed the battery and then failed a case I wrote to check for false positives: a node referenced by two sibling keys, parsed asynchronously, came back rejected. Async array elements are all started before any is awaited, so both sibling frames are open at once and a flat path set cannot tell a sibling from an ancestor. A wrongly rejected valid value is worse than the crash being fixed, so that approach was abandoned rather than patched.

What shipped instead converts the overflow at the parse boundary. `$ZodLazy` is the only recursion point in the schema tree, so it sets `ctx.recursive`, and `runOrOverflow` converts a `RangeError` into an issue only when that marker is set - no message matching, so it does not depend on an engine's wording. It costs nothing on the hot path: a try/catch that never fires and one property write per lazy parse.

Behaviour was checked on both sides of every distinction the fix draws, all by running it. Cycles are rejected at depth 1, depth 3, through an object and through an array, in `z.json()`, in a `z.lazy()` schema and through `z.record(z.string(), z.json())`. DAGs are accepted - a node under two keys and a node repeated in an array - which is correct because `JSON.stringify` serializes them. 200-deep finite input is accepted, so depth is not what is being rejected. `parse()` now throws a `ZodError` rather than a `RangeError`. A `RangeError` thrown by user code inside a `.refine()` still propagates untouched, because the marker is not set for a non-recursive schema. Async is covered too: the helper attaches a `.catch` as well as a try/catch, since the overflow can surface after the first await, and the async cyclic case is rejected while the async sibling DAG and the async deep-finite case are accepted. `safeEncode` and `safeDecode` on a cyclic value are also rejected rather than throwing.

The new test fails against unfixed code and so does the battery: with `core/schemas.ts` and `core/parse.ts` swapped back to `git show HEAD:` and restored byte-identically after, the test reports 1 failed of 20 and the battery reports its three cycle labels. This time the copies were keyed by full path, which is the lesson from iteration 3.

Verify command exits 0: 343 files, 3833 tests, no type errors, up from 3831 by the new test and its typecheck pass. All 14 batteries pass, the first iteration this run where none is red. `pnpm format:check` and `pnpm lint:check` clean at 372 files, `pnpm check:circular` reports no cycle, `pnpm build` exits 0.

Change discipline: `parse`, `safeParse` and their async and codec variants are the library's primary public surface, and `$ZodLazy` backs `z.lazy` and `z.json`. The contract preserved is every existing verdict: the full suite's 3831 pre-existing tests pass unchanged, so no previously-accepted value is now rejected and no previously-rejected value is now accepted. What changed is one case that previously produced no verdict at all because it threw. This is observable behaviour changing, so the rationale is here: `safeParse` is documented in `basics.mdx` as the way to avoid a try/catch, and an escaping `RangeError` breaks exactly that. The issue uses the existing `custom` code rather than a new one, so no public issue code is added and no locale needs a new entry; the tradeoff is that the message is not localizable, which is the same tradeoff every internal `custom` issue in the tree already makes. The Surface inventory row core-schemas-composites covers `$ZodLazy` and is re-swept at this checkpoint, its battery having been re-run green here.

Closed: CYCLE-1 (Medium) - fixed in `core/parse.ts` and `core/schemas.ts`, evidenced by the reproduction failing first, by a differential run of the new test and the battery against unfixed code, and by nine behavioural checks covering cycles, DAGs, depth, the throwing variant, the codec directions, the async path and an unrelated RangeError.

Learnings: a fix that changes which values are rejected needs a false-positive check written before it is believed - the path-tracking version passed the battery that motivated it and only failed a case built to attack it, and the case that broke it was async, where sibling parses overlap in time and no flat per-parse state can distinguish a sibling from an ancestor.

Next: the 15 unswept Surface inventory rows, which outrank the one open Low.
## iter 5/10 | 21291e32-175119 | 2026-08-16 | SWEEP | done

Task: sweeping. The ledger held no High and no Medium, so the 15 unswept Surface inventory rows were the top of the queue; four were swept with new known-answer batteries.

Changed: `.jeffy/probes/core-api/`, `.jeffy/probes/core-parse-config/`, `.jeffy/probes/core-zsf/` and `.jeffy/probes/entrypoints-exports/` (four new batteries, each with a `paths` file), PLAN.md (four rows flipped), BACKLOG.md (one Proposed item).

Checkpoint: cd6d35f5fa77f8033482f3430de4857ef781794e

Verification: The inventory moves from 13 of 28 to 17 of 28. Each battery targets what its row computes and what nothing else pins.

core-api covers the `_x(Class, params)` layer that classic and mini both wrap. What that layer produces is a `def` object, and no existing test looks at it: the wrapper suites see only the finished schema, so a factory that dropped a def field or ignored its params would still hand back a working schema of the right type. The battery asserts known answers for the def of every primitive family, the three fields a string format needs, and that params thread through `normalizeParams` - a string param becoming an error thunk whose message reaches the issue, and `_uuid({version})` at v4 and v7 both landing in the def and changing which UUID is accepted. It also asserts the factory count against the row's own scope grep, because a factory quietly disappearing is invisible to a wrapper test that would disappear with it.

core-parse-config covers the twelve parse entry points in four shapes crossed with three directions. Each is driven on a passing and a failing value, decode and encode are shown running different transforms rather than being aliases, and both sync entry points are shown throwing `$ZodAsyncError` on an async schema rather than returning a pending promise as data. It also drives `config()` through set-and-restore on a custom error map, the `Doc` codegen helper on a nested block, and asserts the core barrel actually re-exports each of the twelve modules it names - a dropped `export *` line would leave those names missing at runtime while every deep-import test kept passing.

entrypoints-exports resolves all eleven `exports` keys and asks each for a name only that entry point provides, then shows the entry points are distinct rather than aliases: classic carries `.min()` as a method where mini does not and supplies `minLength` standalone instead, and v3 carries its own `ZodError` class. The wildcard locale key is resolved concretely and the locale is checked to supply a non-English message, because a locale that resolves but returns an empty map leaves every issue on the English fallback while looking installed. This surface is otherwise unchecked here: the suite imports through the `@zod/source` condition and the workspace alias, not through the published map.

core-zsf is a different kind of row and the sweep's finding is what the module is. `core/zsf.ts` is 323 lines of pure type declarations - 18 interfaces and one type alias - with zero runtime exports, imported by no file under `packages/zod/src`, absent from the `zod/v4/core` barrel, and named by no `exports` key. It has been in the tree since the Zod 4 commit. That is the orphaned-module case the Surface inventory preamble exists to catch, and the battery asserts all four reachability facts from the module graph rather than from a grep over source text, which a comment could satisfy. The type declarations themselves are pinned with typed literals so a breaking edit to an interface fails typecheck.

Whether to delete it is a maintainer decision, not mine, so it went to Proposed rather than onto the ledger as a Low. It ships no runtime code and no entry point reaches it, so removing it costs users nothing; but if it is staged work toward a published interchange format then it should stay and the sweep should stop calling it dead. Filing it as a task would have committed the run to one of those answers.

Verify command exits 0: 343 files, 3833 tests, no type errors. All 18 batteries pass. `pnpm format:check` and `pnpm lint:check` clean at 376 files, after `biome check --write .jeffy` formatted the four new probes.

Change discipline: this iteration changed no source file. Four probe directories were added under `.jeffy/probes/` and the three state files were edited, so no public contract was touched and no battery pins behaviour that changed. No finding was filed at rubric severity, because the sweep surfaced none: every assertion written from the code's actual contract passed on the first or second run, and the two that did not were my own misreadings, corrected below.

Two expectations of mine were wrong and were corrected against the code. `_refine` is a `_x(Class, ...)` factory like the rest and cannot be called with only a predicate, so the async schema in the parse battery is built through classic instead. And a `core.$ZodCodec` has to be constructed directly with its `transform`/`reverseTransform`, not assembled from `_pipe`, which is what makes encode and decode distinguishable at all.

Closed: none. This was a sweep iteration.

Filed: one Proposed item - whether `core/zsf.ts` should stay in the tree.

Learnings: none new this iteration.

Next: the 11 remaining unswept rows - core-to-json-schema, the two classic-schemas rows, classic-surface, the two mini rows, and the five v3 rows.
## iter 6/10 | 21291e32-175119 | 2026-08-16 | SWEEP | done

Task: sweeping. The ledger held no High and no Medium at the start, so the 15 unswept Surface inventory rows were the top of the queue; four were swept and the sweep surfaced two findings.

Changed: `.jeffy/probes/classic-schemas-methods/`, `.jeffy/probes/classic-schemas-factories/`, `.jeffy/probes/mini-schemas/` and `.jeffy/probes/mini-surface/` (four new batteries, each with a `paths` file), PLAN.md (four rows flipped), BACKLOG.md (LOOSEREC-1 and MINI-SLUG-1 filed).

Checkpoint: fdf3feeef0d787a5a5626f30652eb6029e89b970

Verification: The inventory moves from 17 of 28 to 21 of 28.

classic-schemas-methods drives the ~90 distinct method names the row's scope grep returns, each at a value it must accept and one it must reject, or on a known output. The risk this surface carries is a method that returns a schema of the right type while enforcing nothing, so a no-op method returns [true, true] and a live one [true, false]; the three object unknown-key policies are shown differing on one input, and the twelve parse-family methods on the instance are each driven.

classic-schemas-factories does the same for the 100 exported `z.*` factories, with attention to the near-identical siblings: object against looseObject against strictObject, record against partialRecord, union against xor. mini-schemas is differential rather than standalone - for 55 factory pairs the mini and classic schemas must return the same verdict on the same inputs, and each pair is additionally required to discriminate, so a pair agreeing only because both accept everything is caught rather than counted. mini-surface drives the re-export barrels by exercising every aliased check rather than looking it up, including `maximum`/`minimum` shown behaving as `lte`/`gte`, all five coercions shown widening the accepted set, and mini and classic shown to share one core representation by parsing each other's schemas.

The sweep found two things, both by provoking rather than by reading.

`z.looseRecord()` silently ignores its own `mode: "loose"` whenever the key schema exposes enumerable `values`. `$ZodRecord` consults `def.mode` only on the branch it takes when `def.keyType._zod.values` is undefined; the exhaustive branch pushes `unrecognized_keys` without reading `mode` at all. The docs state the contract unconditionally - "By default, `z.record()` errors on keys that don't match the key schema. Use `z.looseRecord()` to pass through non-matching keys unchanged" - and that sentence is false for five key-schema kinds. The enumeration was built by provoking a non-matching key at every kind `z.record` accepts: honoured for a regex key, a min-length key, a template-literal key and a number key; ignored for `z.enum`, `z.nativeEnum`, a single literal, a multi-value literal and a union of literals. Filed as LOOSEREC-1 at Medium; the factories battery is red on it and carries the four honoured kinds as controls, so it discriminates rather than just failing.

The `slugify` check is exported by `classic/checks.ts` and by no module under `packages/zod/src/v4/mini`, so `m.slugify` is undefined while `z.string().slugify()` works. `comm` over the aliased exports of the two check barrels returns `slugify` on the classic side only, and `maximum`/`minimum` on the mini side only, which are additive aliases rather than a gap. `mini.mdx` says Zod Mini "implements the exact same functionality as `zod`". Filed as MINI-SLUG-1 at Low rather than the Medium the rubric gives misleading documentation, and the rationale is on the task line: `slugify` appears nowhere in the docs so no reader is directed to it, the parity sentence is general framing rather than a specific promise, and the check is reachable on mini today through `m.core._slugify()`, which the battery runs and asserts alongside the failing one.

Verify command exits 0: 343 files, 3833 tests, no type errors. `pnpm format:check` and `pnpm lint:check` clean at 380 files. Twenty of the twenty-two batteries pass; classic-schemas-factories and mini-surface are red and reproduce the two findings this sweep filed.

Three expectations of mine were wrong and were corrected against the code. `z.never()` rejects `undefined` as well as everything else, which is what `never` means, so it is pinned as rejecting both sides rather than forced into the accept/reject shape. `z.promise()` cannot be parsed by the sync entry point at all. And `.toJSONSchema()` emits a `$schema` dialect key, which my expected object omitted.

Change discipline: this iteration changed no source file. Four probe directories were added under `.jeffy/probes/` and the three state files were edited, so no public contract was touched and no battery pins behaviour that changed. The stall note the hook raised for iteration 5 does not apply here: two task lines were added under Next and Later, so the ledger changed state.

Closed: none. This was a sweep iteration.

Filed: LOOSEREC-1 (Medium, runtime) and MINI-SLUG-1 (Low, runtime), both reproduced by the batteries that found them.

Learnings: a sweep-only iteration is flat by the stall check's definition, because probe files and inventory rows are both excluded from it - so a run that has several sweep iterations left has to expect the sweep itself to surface ledger work, or interleave a task.

Next: LOOSEREC-1, then the seven remaining unswept rows - core-to-json-schema, classic-surface, and the five v3 rows.
## iter 7/10 | 21291e32-175119 | 2026-08-16 | LOOSEREC-1 | done

Task: LOOSEREC-1 (Medium) - `z.looseRecord()` silently ignored its own `mode: "loose"` whenever the key schema exposed enumerable `values`.

Changed: `packages/zod/src/v4/core/schemas.ts` (`$ZodRecord`'s exhaustive branch now consults `def.mode`), `packages/zod/src/v4/classic/tests/record.test.ts`, BACKLOG.md.

Checkpoint: 529fad0cdf4eb299b578bcb6a330a7a77a640bd0

Verification: The filed reproduction ran first and failed as filed, on all five key-schema kinds. `$ZodRecord` splits on whether `def.keyType._zod.values` is set; only the non-exhaustive branch read `def.mode`, so the exhaustive branch collected every key outside the enum into `unrecognized_keys` and never looked. The fix is the same three lines that branch already uses, placed in the loop that builds `unrecognized`.

I introduced a regression inside this task and caught it by checking the path I had not changed on purpose. My first version guarded `__proto__` before the mode test, which meant a strict record stopped reporting an unexpected `__proto__` key: `git show HEAD:` on the unfixed file reported `unrecognized_keys: ["__proto__"]` where my version accepted the object silently. That is a security-relevant loosening of a path this task had no business touching, so the guard was moved inside the loose branch, where it matches what the non-exhaustive branch already does - never assign `__proto__`, and say nothing about it. Both branches now produce the same output for the same polluted input, which is asserted.

The behaviour was checked on both sides of every distinction. Strict records are unchanged in all four cases that matter: complete input accepted, a missing known key rejected with `invalid_type`, an extra key rejected with `unrecognized_keys`, and an unexpected `__proto__` still reported by name. Loose records now pass the extra key through for all five previously-ignored kinds while still validating the known keys and still requiring them - `{ a: "x", b: 2, z: 3 }` and `{ a: 1, z: 3 }` both still fail. The pass-through is not a pollution vector: `Object.prototype` is untouched, the output's prototype is `Object.prototype`, and `__proto__` never reaches the output.

The new test fails against unfixed code and so does the battery: with `core/schemas.ts` swapped back to `git show HEAD:` and restored byte-identically after, the test reports 1 failed of 50 and the battery reports the nine-kind assertion with its four honoured controls still true. Verify command exits 0: 343 files, 3835 tests, no type errors, up from 3833 by the new test and its typecheck pass. Every battery whose `paths` file names `core/schemas.ts` was re-run and passes; mini-surface is still red on MINI-SLUG-1, which is a separate open Low. `pnpm format:check` and `pnpm lint:check` clean at 380 files, `pnpm check:circular` reports no cycle, `pnpm build` exits 0.

One of my own test inputs was wrong and the test caught it before the checkpoint. I reused `{ nope: "v" }` as the non-matching input for all three pattern key schemas, but `"nope"` is four characters and satisfies `z.string().min(3)`, so that row asserted the opposite of what it meant. Each pattern kind now carries its own non-matching input, which is what the battery already did.

Change discipline: `z.record`, `z.looseRecord` and `z.partialRecord` are public on classic and mini. The contract preserved is every verdict the strict and partial forms give - the full suite's 3833 pre-existing tests pass unchanged, so no previously-accepted value is now rejected and none previously-rejected is now accepted outside `looseRecord` itself. What changed is `looseRecord` on five key-schema kinds, which is the documented behaviour it was failing to deliver. No documentation edit was owed: the `api.mdx` sentence stating that `z.looseRecord()` passes non-matching keys through was already the intended contract, and this fix makes it true rather than changing it. The Surface inventory rows core-schemas-collections and classic-schemas-factories both cover this code and are re-swept at this checkpoint, their batteries having been re-run green here.

Closed: LOOSEREC-1 (Medium) - fixed in `packages/zod/src/v4/core/schemas.ts`, evidenced by the reproduction failing first across all five kinds, by a differential run of the new test and the battery against unfixed code, and by the strict path shown byte-for-byte unchanged including its `__proto__` reporting.

Learnings: when a fix adds a write into a loop that previously only read, the guards that loop needs are the ones the sibling write path already has - copying the guard to the wrong side of the branch silently relaxed a path the task never intended to touch, and only checking the untouched path revealed it.

Next: the seven remaining unswept rows - core-to-json-schema, classic-surface, and the five v3 rows - then MINI-SLUG-1 and SUCCESS-DOC-1.

## iter 8/10 | 21291e32-175119 | 2026-08-16 | SWEEP | done

Task: sweeping. The ledger held no High and no Medium at the start, so the seven remaining unswept Surface inventory rows were the top of the queue; all seven were swept and the sweep surfaced one finding.

Changed: `.jeffy/probes/v3-types-primitives/`, `.jeffy/probes/v3-types-collections/`, `.jeffy/probes/v3-types-composites-wrappers/`, `.jeffy/probes/v3-errors-locales/`, `.jeffy/probes/v3-helpers/`, `.jeffy/probes/classic-surface/` and `.jeffy/probes/core-to-json-schema/` (seven new batteries, each with a `paths` file), PLAN.md (seven rows flipped), BACKLOG.md (TUPLEJS-1 filed).

Checkpoint: 13cd6711efd93058d5fb73bc62567eba1fb7713e

Verification: The Surface inventory is complete - 28 of 28 rows swept, from 21 at the start of this iteration and 5 at the start of the run.

The five v3 rows cover a frozen major that consumers still import as `zod/v3`, so what matters is that its verdicts have not drifted: every type gate at both sides, every documented check at both sides of its boundary, the six collection classes each driven at a value the container accepts and the inner schema rejects, and the fourteen composite and wrapper classes on known outputs as well as accept/reject pairs. v3-errors-locales pins one known answer per issue code including the message text, because asserting only the code would let a blank or wrong message through, plus the three shaping helpers and the full error-map override chain. v3-helpers drives `getParsedType` over sixteen runtime shapes, the `ParseStatus` machine including that an abort is never upgraded by a later dirty, and `makeIssue`'s precedence of an explicit message over the map.

classic-surface drives every aliased check rather than looking it up, all twelve top-level parse entry points, both throwing entry points shown throwing the classic `ZodError`, and the compat aliases. core-to-json-schema is the one row where the output is a document rather than a verdict, so a wrong answer is silent: a dropped constraint still emits valid JSON Schema that simply permits more than the schema does. Every row there is a known-answer comparison against the exact document, and the round trip through `z.fromJSONSchema` is checked behaviourally over eight schemas - the emitted document must agree with the original on which values are valid, and each row must also discriminate, so agreement by both accepting everything is caught rather than counted.

That row found one thing. `z.toJSONSchema(z.tuple([...]))` emits no `minItems` or `maxItems`, so the document leaves the array length unbounded and an external validator accepts `["a", 1, "extra"]` and `["a"]` where zod rejects both. It is not a dialect limitation: the `openapi-3.0` branch of the same `tupleProcessor` emits `minItems` always and `maxItems` when there is no rest, and that branch is the control in the battery. zod's own round trip is unaffected because `z.fromJSONSchema` treats `prefixItems` as exhaustive, which is why no existing test sees it. Filed as TUPLEJS-1 at Medium rather than High, with the rationale on the task line: no zod user gets a wrong parse verdict, and the divergence appears only once a third party consumes the document - which is nonetheless what `toJSONSchema` exists to produce.

Verify command exits 0: 343 files, 3835 tests, no type errors. `pnpm format:check` and `pnpm lint:check` clean at 387 files. Twenty-seven of the twenty-nine batteries pass; core-to-json-schema is red on TUPLEJS-1 and mini-surface on MINI-SLUG-1.

Five expectations of mine were wrong and were corrected against the code. `z.iso.time()` deliberately emits no `format` key, and the processor says why in its own comment - the JSON Schema `time` format requires an offset or Z, which `z.iso.time()` does not accept, so claiming it would be false; the pattern carries the whole constraint and that is what the battery now asserts. v3's `z.promise()` validates lazily, handing back a promise that rejects when awaited, where v4 validates eagerly; that is a deliberate difference between majors and both halves are now pinned. `invalid_intersection_types` needs both sides to parse and disagree, not merely to reject the input. `errorUtil` is not a type-only helper - it exports the two functions that normalize the `string | {message}` error argument, which are now driven. And my key-order-sensitive comparison flagged three emitted documents whose content was correct, so the battery now compares with keys sorted.

Change discipline: this iteration changed no source file. Seven probe directories were added under `.jeffy/probes/` and the three state files were edited, so no public contract was touched and no battery pins behaviour that changed. The iteration is not flat: a task line was added under Next.

Closed: none. This was a sweep iteration.

Filed: TUPLEJS-1 (Medium, runtime), reproduced by the battery that found it.

Learnings: comparing emitted documents with JSON.stringify makes key order part of the assertion, which produced three false failures on correct output - sort keys before comparing anything whose shape is a document rather than a sequence.

Next: TUPLEJS-1, then the two carried Lows. The inventory is complete, so no sweep work remains.
## iter 9/10 | 21291e32-175119 | 2026-08-16 | TUPLEJS-1 | done

Task: TUPLEJS-1 (Medium) - `z.toJSONSchema(z.tuple([...]))` emitted no `minItems` or `maxItems`, so the document left the array length unbounded and an external validator accepted arrays the tuple rejects.

Changed: `packages/zod/src/v4/core/json-schema-processors.ts` (the length bounds now apply on every target), `packages/zod/src/v4/classic/tests/to-json-schema.test.ts` (five snapshots updated, one behavioural test added), BACKLOG.md.

Checkpoint: 730f19f349bc8619aba5fdf128a118dc6d4a722d

Verification: The filed reproduction ran first and failed as filed, on both the fixed tuple and the tuple with rest. The fix moves the two lines the `openapi-3.0` branch already had out of that branch, so every target derives the bounds the same way, and it leaves them before the existing block that lets an explicit bound from the schema's bag override them.

Five snapshot tests went red, all of them tuple cases in `to-json-schema.test.ts`. They were green only because they encoded the missing bounds, which is the exception the verify gate allows, and the differential evidence is that across all five diffs the only changed lines are additions: four `minItems`, two `maxItems`, one `minItems: 1`, and zero removals or modifications. The same holds of the file after updating: `git diff` on the test file shows seven added lines and nothing else. The `issue #5151` regression test keeps its purpose - it asserts captured override paths as well as the snapshot, and the path assertion is untouched.

Writing the test found a second defect, which is filed rather than fixed here. The `openapi-3.0` branch reports `minItems` one too high for a tuple with a rest element: it assigns `json.items = { anyOf: prefixItems }` and then pushes the rest schema onto `json.items.anyOf`, which is the same array object `prefixItems` names, so the later length read counts the rest schema as a required prefix element. `z.toJSONSchema(z.tuple([z.string()], z.number()), {target: "openapi-3.0"})` emits `minItems: 2` where draft-2020-12 and draft-7 now emit 1. It is pre-existing, not introduced here: running the same command against `git show HEAD:` of the processor produces `minItems: 2` identically, and the fix moved the computation without changing its position relative to the push. Filed as OPENAPI-MIN-1 at Medium. This is where the never-batch rule binds - it is a one-line fix in the function I was already editing, and it still takes its own iteration.

That also corrected my own framing. I had called the `openapi-3.0` branch the control that proved the omission was not a dialect limitation. It proves that for the fixed-tuple case, which is what the battery asserts; for the rest case that branch is itself wrong, so the battery and the new test pin its current value explicitly with the reason rather than treating it as correct.

The new test fails against unfixed code and so does the battery: with the processor swapped back to `git show HEAD:` and restored byte-identically after, the test reports 1 failed and the battery reports both tuple labels. Verify command exits 0: 343 files, 3837 tests, no type errors, up from 3835 by the new test and its typecheck pass. Both batteries whose `paths` file names a json-schema module pass. `pnpm format:check` and `pnpm lint:check` clean at 387 files, `pnpm check:circular` reports no cycle, `pnpm build` exits 0.

Change discipline: `toJSONSchema` is public on classic, mini and core. The contract preserved is every other emitted construct - the only diff across the whole suite is seven added bound lines on tuple documents, and the round trip through `z.fromJSONSchema` still agrees with the original schema on which values are valid for all eight schemas the battery drives, including the tuple. No documentation states the emitted tuple shape, so none needed updating. The Surface inventory row core-to-json-schema covers this code and is re-swept at this checkpoint, its battery having been re-run green here.

Closed: TUPLEJS-1 (Medium) - fixed in `packages/zod/src/v4/core/json-schema-processors.ts`, evidenced by the reproduction failing first, by a differential run of the new test and the battery against unfixed code, and by the whole-suite diff being seven added lines and no removals.

Filed: OPENAPI-MIN-1 (Medium, runtime) - the openapi-3.0 `minItems` off-by-one, shown pre-existing by running the reproduction against the previous commit.

Learnings: assigning an array into a document node and then pushing onto it through the node aliases the original, so a later length read on that array counts what was pushed - the openapi-3.0 branch derived its own `minItems` from a list it had already appended to.

Next: OPENAPI-MIN-1 is the top of the queue, then the two carried Lows. This is the last working iteration; the next one is the final and goes to WRAPUP.

## iter 9/10 | 21291e32-175119 | 2026-08-16 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines after this iteration's entry, so the nine oldest entries were moved to JOURNAL-archive.md.

Changed: JOURNAL.md (296 lines, 10 entries), JOURNAL-archive.md (created, 204 lines, 9 entries).

Checkpoint: 730f19f349bc8619aba5fdf128a118dc6d4a722d

Verification: 19 entries were on record, split only on lines matching `^## iter \d`, so the heading-grammar example in the preamble was never counted or moved. The nine oldest went to the archive - the previous run's iterations 1 through 9, from its AUDIT through DOCS-1 - and the ten most recent stayed, beginning with that run's WRAPUP. `grep -c '^## iter [0-9]'` returns 10 in JOURNAL.md and 9 in the archive, which is the 19 on record before the split. The archive did not exist, so it was created with a header and the moved entries appended; nothing was overwritten and no entry text was edited.

Learnings: none new this iteration.

Next: the primary entry above.

## iter 10/10 | 21291e32-175119 | 2026-08-16 | OPENAPI-MIN-1 | done

Task: OPENAPI-MIN-1 (Medium) - the `openapi-3.0` branch of `tupleProcessor` reported `minItems` one too high for a tuple with a rest element. This is the final iteration; the task was executed rather than deferred to a WRAPUP because it is a one-line fix whose acceptance check and pinning test were already written, so it could finish inside the iteration.

Changed: `packages/zod/src/v4/core/json-schema-processors.ts` (the openapi-3.0 branch copies the prefix list instead of aliasing it), `packages/zod/src/v4/classic/tests/to-json-schema.test.ts` (one snapshot corrected, the pinned assertion replaced), BACKLOG.md.

Checkpoint: 8dadb3020d0cdafa736fcf476dc081ca2a305302

Verification: The filed reproduction ran first and reported `minItems: 2` for `z.tuple([z.string()], z.number())` on the openapi-3.0 target, where the other two targets report 1. The cause was `json.items = { anyOf: prefixItems }` followed by `json.items.anyOf.push(rest)`: `anyOf` named the same array object as `prefixItems`, so the length read below counted the rest schema as a required prefix element. The fix copies the list into `anyOf` rather than aliasing it, which removes the aliasing rather than working around it, so any future length read on `prefixItems` is safe.

The three targets now agree, checked by running all six combinations: `minItems` equals the prefix length on draft-2020-12, draft-7 and openapi-3.0 alike, and `maxItems` is present only when there is no rest. A two-prefix tuple with rest reports 2, which shows the count is the prefix length rather than a coincidence at length one, and that case is what the new assertion pins. The `items.anyOf` content is unchanged and still carries the rest schema.

One snapshot went red: `tuple with rest openapi-3.0`, for `z.tuple([z.string(), z.number()]).rest(z.boolean())`, which had `minItems: 3` pinned for a two-element prefix. The differential evidence is that the whole-suite diff for this change is that single line, 3 to 2, and that test also runs `validateOpenAPI30Schema` over the document, which still passes. The test file's other changes are mine from the previous iteration: the openapi-3.0 target moved into the loop that asserts 1, and the assertion that pinned the old 2 was replaced with the two-prefix case.

The new test fails against unfixed code: with the processor swapped back to `git show HEAD:` and restored byte-identically after, `tuple emits length bounds on every target` reports 1 failed. Verify command exits 0: 343 files, 3837 tests, no type errors. All 29 batteries were run; 28 pass and mini-surface is red on MINI-SLUG-1, a carried Low. `pnpm format:check` and `pnpm lint:check` clean at 387 files, `pnpm check:circular` reports no cycle, `pnpm build` exits 0.

Change discipline: `toJSONSchema` is public on classic, mini and core. The contract preserved is every other emitted construct - the whole-suite diff is one line - and the openapi-3.0 document still validates against `validateOpenAPI30Schema`. No documentation states the emitted tuple shape, so none needed updating. The Surface inventory row core-to-json-schema covers this code and is re-swept at this checkpoint, its battery having been re-run green here.

Closed: OPENAPI-MIN-1 (Medium) - fixed in `packages/zod/src/v4/core/json-schema-processors.ts`, evidenced by the reproduction failing first, by the three targets shown agreeing across six combinations, and by the whole-suite diff being one line.

Handoff for the next run. The ledger holds two Lows and no High or Medium: MINI-SLUG-1, the `slugify` check missing from mini's standalone surface, whose battery `.jeffy/probes/mini-surface/probe.ts` is red on it; and SUCCESS-DOC-1, `z.success()` undocumented because the Success section of `codecs.mdx` sits inside an MDX comment. Two Proposed items await a user decision: whether `core/zsf.ts` should stay in the tree, and whether the `boolean`, `null` and `undefined` patterns should have kept their case-insensitive flag. The Surface inventory is complete at 28 of 28, so a relaunch starts with no sweep work and the queue is the two Lows.

Convergence was not reachable this run and no declaration was attempted. The Definition of done requires a full fresh-evidence audit scoring zero High and zero Medium, and this run recorded no full audit at all: it opened with SUCCESS-1 already on the ledger from the previous run, so every iteration executed a task or swept rows. The evaluator gate was therefore not invoked - it exists to guard a declaration, and there was none to guard. A relaunch now is well placed to converge: the map is complete, the ledger holds only Lows, and one clean full audit followed by the gate is the whole remaining sequence.

Learnings: none new this iteration.

Next: a fresh run - one full audit over the completed map, then the evaluator gate, then the declaration if the audit comes back clean.

## iter 1/10 | 8e137b16-185920 | 2026-08-16 | SWEEP | done

Task: SWEEP - re-sweep the four Surface inventory rows whose implementing module, `packages/zod/src/v4/core/schemas.ts`, was edited after the commit each row recorded. Sweeping outranks the two open Lows in the queue, and no High or Medium was open at run start.

Changed: PLAN.md (four inventory rows re-swept, three Lessons lines), BACKLOG.md (CYCLE-FP-1 filed under Next). No source file touched.

Checkpoint: 9f7994cef61dc5fb6b7eed06a0bef385fe7ed775

Verification: The staleness question was settled mechanically rather than by reading. For every one of the 26 inventory rows, `git log <row-commit>..HEAD -- <the row's own files>` was run; 22 returned nothing and four returned the three commits that edited `core/schemas.ts` after they were swept - d16c5c5e (FUNC-ERR-1), 1a20a66b (CYCLE-1), 529fad0c (LOOSEREC-1). Those four rows are core-schemas-primitives, core-schemas-string-formats, core-schemas-wrappers and core-schemas-composites. Their batteries were re-run against the current tree and all four exit 0: PRIMITIVES OK, STRING-FORMATS OK, WRAPPERS OK, COMPOSITES OK. That is what flips the rows, not the argument that the hunks fall in other export groups.

The interesting result came from reading what those three commits changed rather than only that they changed something. CYCLE-1 added `ctx.recursive`, a flag `$ZodLazy` writes onto the shared parse context so that `runOrOverflow` in `core/parse.ts` knows a `RangeError` came from schema recursion. Nothing clears it. PLAN.md's own Lessons already carried the rule that per-parse mutable state cannot distinguish a sibling from an ancestor, and this is that shape again, so it was attacked directly: `z.object({a: z.lazy(() => z.string()), b: z.custom(() => { throw new RangeError("...") })}).safeParse({a: "ok", b: 1})` returns `success: false` carrying `{"code":"custom","message":"Recursion limit exceeded","path":[]}`. The control - the identical schema with the lazy branch removed - lets the `RangeError` escape as it should, which is the differential that makes this a defect and not a design choice. The async path reproduces identically through `safeParseAsync`. Filed as CYCLE-FP-1 at Medium: a genuine error is swallowed and replaced with a fabricated reason, which is the rubric's silently swallowed error, and it is not High because it returns a wrong failure rather than a wrong success.

The CYCLE-1 entry states that "a `RangeError` thrown by user code inside a `.refine()` still propagates untouched, because the marker is not set for a non-recursive schema". That sentence is true as written and its scope is the whole problem: it was verified on a schema with no lazy in it, which is the one arrangement where the flag cannot misfire. The combination that breaks it was never run.

Verify command exits 0: 343 files, 3837 tests, no type errors, 12s. No battery declares a path this diff touches, since the diff is state files only.

Change discipline: no public interface and no observable behaviour changed this iteration - the diff is PLAN.md and BACKLOG.md. The four re-swept rows now name this checkpoint and the edits they were re-swept against, so the next audit reads a table whose commits match the code.

Closed: none. One finding filed.

Learnings: a flag written onto the shared parse context is scoped to the parse, never to the subtree that set it, so the check that matters is the error arriving from a sibling rather than from the marked subtree. Settling row staleness by re-running the row's battery costs one command and produces evidence, where arguing from hunk positions produces only an argument.

Next: CYCLE-FP-1 is the only open Medium and outranks both open Lows.

## iter 2/10 | 8e137b16-185920 | 2026-08-16 | CYCLE-FP-1 | done

Task: CYCLE-FP-1 (Medium) - `$ZodLazy` marked the shared parse context with `ctx.recursive` and nothing cleared it, so the parse boundary relabelled every later `RangeError` in that parse as `Recursion limit exceeded`.

Changed: `packages/zod/src/v4/core/schemas.ts` (the conversion moves into `$ZodLazy`, `ParseContextInternal` loses the marker), `packages/zod/src/v4/core/parse.ts` (`runOrOverflow` deleted, the four entry points call `run` directly again), `packages/zod/src/v4/classic/tests/lazy.test.ts`, `.jeffy/probes/core-schemas-composites/probe.ts`, PLAN.md, BACKLOG.md.

Checkpoint: 11478f272c92a3073e9f80e07d4ab28600381872

Verification: The filed reproduction ran first and reproduced as filed, sync and async. Running it also widened the finding: the same relabelling happens to a `RangeError` thrown inside a lazy subtree that never recursed, so the defect is not only about siblings and was fixed as a class rather than as the one instance filed.

The root cause is that a flag on the parse context records that a lazy was entered somewhere, which is not the same question as whether this error came from recursion. The call stack already answers that question exactly, so the conversion moved to where it is structurally true: `$ZodLazy` catches around its own `inner._zod.run`, counts the frames of that instance currently on the stack, and converts only when the error is a `RangeError`, the instance actually re-entered (`peak > 1`), and this is the outermost frame unwinding (`depth === 1`). An error that never crossed a lazy frame is never seen; a lazy entered exactly once does not convert; converting at the outermost frame keeps the issue path pointing at the lazy instead of at the deepest frame reached. `ctx.recursive` and the whole `runOrOverflow` wrapper are deleted, so the fix is a net removal at the boundary: 31 insertions, 44 deletions across the two core files.

The async concern that killed the first CYCLE-1 attempt does not apply to these counters. The descent through `$ZodLazy` is synchronous even in async mode - object properties are started, not awaited, inside it - so the increment and the matching decrement never span an await and concurrent parses of one schema cannot interleave between them. That was checked rather than assumed: `Promise.all` of a 200-deep finite value and a cyclic value through one `Tree` schema returns accepted and rejected respectively, and it is in both the test and the battery.

Twelve behaviours were driven, on both sides of every distinction the fix draws. Preserved: a cycle is rejected sync, async, under mutual recursion between two lazy instances, and through `parse()` as a `ZodError`; a DAG and a 500-deep finite value are accepted. Fixed: a `RangeError` propagates when thrown beside a lazy branch (sync and async), inside a non-recursive lazy subtree, and with no lazy present.

Differential against unfixed code, with both core files swapped back to `git show HEAD:` and restored byte-identically after - `git diff --stat` confirms the fix returned - the battery reports 3 failures naming all three propagation sites and `lazy.test.ts` reports 1 failed of 22. The copies were keyed by full path.

Verify command exits 0: 343 files, 3839 tests, no type errors, 23s, up from 3837 by the new test and its typecheck pass. All six batteries owning the touched paths pass: core-schemas-primitives, core-schemas-string-formats, core-schemas-collections, core-schemas-composites, core-schemas-wrappers, core-parse-config. `pnpm lint:check` clean at 387 files; `pnpm format:check` went red on the probe alone and was fixed with `biome format --write` on that file, then clean.

Change discipline: `$ZodLazy` backs `z.lazy` and `z.json`, and the parse boundary is the library's primary public surface, so the contract preserved was checked as a whole - the suite's 3837 pre-existing tests pass unchanged, so no previously-accepted value is now rejected and none previously-rejected is now accepted. Observable behaviour does change in one direction and the rationale is that it restores an older one: a `RangeError` thrown by user code propagates again, as it did before CYCLE-1, instead of being reported as a validation issue that blames recursion. Nothing in `packages/docs/content/` mentions the message, so no documentation contradicts the change. The six Surface inventory rows over the two touched modules are re-swept at this checkpoint with their batteries re-run green, and the composites row now records the propagation pins.

Closed: CYCLE-FP-1 (Medium) - fixed in `core/schemas.ts` and `core/parse.ts`, evidenced by the reproduction failing first, by a differential run of both checks against unfixed code, and by twelve behavioural checks. Recorded as a Settled class, whose enumerating check is the set of places a `RangeError` can enter a parse, built by provoking one at each.

Learnings: the scoping a call stack gives is exact where a flag on shared state is not, so catch where the condition is structurally true rather than recording that it was true somewhere. A counter touched only during a synchronous descent is safe under concurrent async parses because nothing awaits between its increment and decrement, which is what separates it from the per-parse state that failed here before.

Next: no High or Medium is open and no inventory row is unswept, so the queue is the two carried Lows - MINI-SLUG-1 then SUCCESS-DOC-1.

## iter 3/10 | 8e137b16-185920 | 2026-08-16 | MINI-SLUG-1 | done

Task: MINI-SLUG-1 (Low) - the `slugify` check was exported by classic's check barrel and by no module under `packages/zod/src/v4/mini`, so `m.slugify` was undefined while `z.string().slugify()` worked.

Changed: `packages/zod/src/v4/mini/checks.ts` (one re-export line), `packages/zod/src/v4/mini/tests/checks.test.ts`, `.jeffy/probes/mini-surface/probe.ts`, PLAN.md, BACKLOG.md.

Checkpoint: b4aee7b43ecee29c2c5d6aa9e5419ca1989f1b93

Verification: The filed reproduction ran first and failed as filed - the battery reported `slugify is on mini's check surface: got "undefined" want "function"`.

The finding's enumeration was re-run rather than trusted, since it was written a run ago: `comm` over the aliased exports of the two barrels returned `slugify` on the classic side alone, with `maximum` and `minimum` on the mini side, which are the deliberate mini-only bound aliases the battery already pins as `lte` and `gte`. So the gap was exactly one name, and the fix is the one line that closes it - `_slugify as slugify` in mini's barrel, in the position its siblings use. After the fix that same `comm` returns nothing on the classic side, which is the check that the parity claim now holds rather than that one symbol was added.

The battery asserted `typeof m.slugify` rather than driving it, which is the weakness this row's own scope line forbids - every aliased check driven, not looked up. It now parses `"Héllo Wörld"` to `"hello-world"` through `m.slugify()` and pins mini's output against `z.string().slugify()` on the same input, so a future divergence in either barrel fails rather than a missing name alone. A repo test went in too, because the battery is not part of the Verify command: `z.slugify` in `mini/tests/checks.test.ts`, in the file's existing style, sitting in the commented list of checks where its siblings are named.

Differential against unfixed code, with `mini/checks.ts` swapped back to `git show HEAD:` and restored byte-identically after: the battery dies with `TypeError: m.slugify is not a function` and the mini checks spec reports 2 failed of 36 with 1 type error, so both checks fail without the fix for the right reason.

Verify command exits 0: 343 files, 3841 tests, no type errors, 24s, up from 3839 by the new test and its typecheck pass. The one battery declaring `mini/checks.ts` is mini-surface and it passes. `pnpm lint:check` clean at 387 files; `pnpm format:check` went red on the probe alone, fixed with `biome format --write` on that file, then clean.

Change discipline: this adds a name to mini's public surface and removes none, so no existing call can break; the export is an alias of the same `_slugify` classic already re-exports, so both barrels resolve to one implementation and cannot drift in behaviour. `mini.mdx` says Zod Mini "implements the exact same functionality as `zod`", and that sentence is now true of this check where it was not before. The mini-surface row is re-swept at this checkpoint and no longer carries its red note.

Filed: SLUG-DOC-1 (Low, docs) - `grep -rni slugify packages/docs/` returns nothing, while the four siblings of the same overwrite family are each listed twice in the "simple string transforms" block of `api.mdx`, once as a classic method and once as a mini standalone check. Noticed while confirming that adding the mini export contradicted no page. It is a gap rather than a contradiction, so Low.

Closed: MINI-SLUG-1 (Low) - fixed in `mini/checks.ts`, evidenced by the reproduction failing first, by the barrel `comm` returning empty after, and by a differential run of both the battery and the new spec against unfixed code.

Learnings: an acceptance check written as `typeof x === "function"` certifies that a name exists and nothing about what it does; where a row's scope already says every alias is driven, the fix iteration is the place to make the check match that promise.

Next: SUCCESS-DOC-1 and SLUG-DOC-1, both Low and both docs; no High or Medium is open and no inventory row is unswept.

## iter 4/10 | 8e137b16-185920 | 2026-08-16 | SLUG-DOC-1 | done

Task: SLUG-DOC-1 (Low) - the `slugify` check shipped in both classic and mini and appeared on no documentation page.

Changed: `packages/docs/content/api.mdx` (one line in each tab of the "simple string transforms" block), BACKLOG.md.

Checkpoint: 7776289adb9370657c931652ae2390a167f7cbb8

Verification: The filed reproduction ran first and reproduced: `grep -c slugify packages/docs/content/api.mdx` returned 0. It now returns 2, the acceptance check.

The fix is deliberately the shape its siblings already have rather than a new section. `trim`, `toLowerCase`, `toUpperCase` and `normalize` are each one commented line in the Zod tab and one in the Zod Mini tab of that block, so `slugify` is documented the same way in both, which is also what keeps the mini form discoverable now that iteration 3 put it on mini's surface.

Both published lines were run exactly as written before shipping them, because the comment states an output: `z.string().slugify().parse("Héllo Wörld!")` returns `"hello-world"` and `m.parse(m.string().check(m.slugify()), "Héllo Wörld!")` returns `"hello-world"`. The documented arrow is that real output, not a plausible one.

The docs suite has an assertion that owns exactly this edit - `packages/docs/content/api.test.ts` compares the line count of the Zod and Zod Mini code fences in every tabbed block - so its teeth were checked rather than assumed. With both lines present it exits 0; with the mini line deleted and the classic one left, it fails naming the block and reporting 5 Zod lines against 4 Zod Mini lines. The file was restored from a copy and `grep -c` confirms 2 again. That is what makes this acceptance check strong enough to fail: a half-finished edit is caught by the Verify command itself, not only by the grep.

Verify command exits 0: 343 files, 3841 tests, no type errors, 27s - unchanged from the previous checkpoint, as expected for a documentation-only diff that adds no test. No battery declares a path under `packages/docs`, so none was triggered. `pnpm format:check` and `pnpm lint:check` both clean.

Change discipline: no source file changed, so no public interface or observable behaviour moved and no Surface inventory row went stale. The change makes an existing shipped API discoverable; it removes nothing and contradicts no other page, which was checked in iteration 3 when the same grep came back empty across the whole docs package.

Closed: SLUG-DOC-1 (Low) - fixed in `api.mdx`, evidenced by the reproduction returning 0 first and 2 after, by both published examples executed as written and returning the documented output, and by a differential that shows the docs suite catches a one-sided edit.

Learnings: a documentation example that states an output is code leaving the project, so it runs in exactly its published form before it ships; a plausible-looking arrow in a comment is the cheapest place for a wrong claim to hide.

Next: SUCCESS-DOC-1, the last open task and the only carried Low; no High or Medium is open and no inventory row is unswept, so the ledger empties after it and the run reaches its full audit.

## iter 5/10 | 8e137b16-185920 | 2026-08-16 | SUCCESS-DOC-1 | done

Task: SUCCESS-DOC-1 (Low) - the Success section of `codecs.mdx` sat inside an MDX `{/* ... */}` comment, so `z.success()` appeared on no published page, and the commented text covered only the encode error rather than the true/false contract the schema exists for.

Changed: `packages/docs/content/codecs.mdx` (the section is restored and rewritten), BACKLOG.md.

Checkpoint: 5c1f09728cab3e04302a3cf22fa033203bc0d81e

Verification: The filed reproduction ran first and reproduced: `grep -c '{/\* ### Success' packages/docs/content/codecs.mdx` returned 1, and `grep -rn 'z.success(' packages/docs/content/` returned exactly that one line inside the comment, so the API really was reachable from no published page. The acceptance grep now returns 0.

`git log -S` dates the comment to the Zod 4.1 release commit 019c370f, so this has been dark for a release cycle rather than being a recent slip.

Every line of the restored section was run exactly as published before shipping, and the section states three things the old comment did not state together. `z.decode(successSchema, "hello")` returns `true` and `z.decode(successSchema, 123)` returns `false` - that second branch is the whole point of the schema and the comment never mentioned it, which matters here because a prior run's SUCCESS-1 fix is what made it reachable at all. `z.encode(successSchema, true)` throws with the message the section prints, verified to be the real thrown text rather than a paraphrase.

One sentence was cut rather than shipped. The first draft read "so it never fails", which generalises over every input, so it was tested instead of trusted: a symbol, `null`, `{}` and `NaN` all decode to `false`, but an async inner schema under a sync decode throws `$ZodAsyncError`. The claim is therefore false as written. It was dropped rather than caveated, because the sync-versus-async rule is universal to every schema and not a property of `z.success`; nothing is filed, since zod is behaving as designed. The published sentence now claims only what was driven.

Verify command exits 0: 343 files, 3841 tests, no type errors, 23s - unchanged, as expected for a documentation-only diff. No battery declares a path under `packages/docs`. `pnpm format:check` and `pnpm lint:check` both clean. `packages/docs/content/api.test.ts` reads `api.mdx` alone, so no automated check covers `codecs.mdx`; the executed examples are the evidence here, not a suite.

Change discipline: no source file changed, so no public interface moved and no Surface inventory row went stale. The section is placed where it already was, directly after Transforms, which is the sibling section on unidirectional behaviour, and it borrows that section's phrasing for the runtime-error warning so the two read as a pair.

Closed: SUCCESS-DOC-1 (Low) - fixed in `codecs.mdx`, evidenced by the acceptance grep going 1 to 0, by all three published examples executed as written returning the documented values, and by a fourth claim being tested, falsified, and removed before it shipped.

Learnings: test the sentence, not just the code sample - "it never fails" was the only unverified clause in the draft and it was the one that was wrong; a generalising clause in prose earns the same enumeration a generalising claim in a state file does.

Next: the ledger is empty and no inventory row is unswept, so the next iteration is the run's full fresh-evidence audit.

# Journal

Append-only. One primary entry per iteration; SALVAGE and ROTATION entries are additional. Never rewrite past entries (filling the current entry's Checkpoint field is completion, not a rewrite).

Heading grammar, exactly (fenced and indented here so this example is never mistaken for an entry by anything that counts or rotates them):

```
  ## iter <i>/<N> | <run-id> | <YYYY-MM-DD> | <task-id or AUDIT or EVALUATOR or RATCHET or WRAPUP or SALVAGE or ROTATION> | <done|blocked|audit|converged|salvage|rotation>
```

Write a real heading at column zero, never indented: the indentation above belongs to the example alone, and an indented heading is invisible to the rotation anchor and to the archive counter, so the entry under it is not counted and not rotated.

SALVAGE entries take status salvage; ROTATION entries take status rotation. An EVALUATOR entry records an evaluator-gate iteration: status audit when the run continues after the verdict, blocked on a terminal second REJECT, converged when that same iteration declares.

run-id is the first 8 characters of the session id, a hyphen, then the HHMMSS of started_at from the loop state frontmatter, so two runs in one session are told apart. Body fields, in order: Task, Changed, Checkpoint (the jeffy checkpoint commit hash, or none with the reason), Verification, Learnings, Next.

The closing entry that declares convergence carries the evaluator verdict in its Verification field: `Evaluator: PASS - <one-line summary>`, or `Evaluator: unavailable (<reason>)`. An earlier EVALUATOR entry records its own verdict the same way and never stands in for the closing one: the Stop hook reads the closing entry alone, so a run that gates early and keeps working re-invokes the gate at the declaration.

Closed tasks are recorded here as one line each (ID, title, closing evidence), because BACKLOG.md deletes them. Rotation: when this file exceeds 500 lines, move all but the last 10 entries to the end of JOURNAL-archive.md, appending to whatever that file already holds and never overwriting it, because the archive accumulates across every rotation and every run; create it only when it does not already exist, and record the rotation as a ROTATION entry.
## iter 6/10 | 8e137b16-185920 | 2026-08-16 | AUDIT | audit

Task: AUDIT - the run's full fresh-evidence audit, run because the ledger emptied. Closeout begins with this entry: zero High and zero Medium in-envelope, so the run stops auditing and finishes by working or declining what is on the ledger.

Changed: PLAN.md (Oracle class and Environment fingerprint counts refreshed), BACKLOG.md (DOCS-COVERAGE-1 filed).

Checkpoint: 9726bed6ee90b25546e4ea6e81b910ca894bda4c

Verification: Scores claim all 26 Surface inventory rows, because none is unswept and all 29 batteries were re-run green in this iteration - that is the run's correctness evidence and it is executed, not cited.

Verify command exits 0: 343 files, 3841 tests, no type errors, 20s. The five things the Oracle class says it does not cover were all run by hand and all exit 0: `pnpm build`, `pnpm format:check`, `pnpm lint:check`, `pnpm check:circular` (no circular dependency found), and both cross-package suites, `@zod/resolution test:all` and `@zod/integration test:all`.

Both Verify-command lines were re-read as the declaring path requires, and both had drifted. The Environment fingerprint said 170 `.test.ts` files were collected; `find` returns 172 and the exclusion `comm` still returns empty, so nothing is excluded but the count was two runs stale. The Oracle class said 339 files and 168 runtime specs; the real figures are 343 and 170. `git ls-tree` dates the drift to the previous run rather than this one - 170 at 1fb56a5c, 172 at 3a493287 - so no iteration this run introduced it. Both lines are corrected, with the 1fb56a5c baseline kept as history.

Testing was not scored clean from the whole-suite run alone. Four modules that mutate global state were run in isolation - `global-config`, `jitless-allows-eval`, and the `uz` and `hy` locales - and all pass alone, so nothing here depends on state another module leaks. The only conditional skips in the tree are the two `ctx.skip` calls in `packages/resolution/attw.test.ts`, and neither fired under the recorded command, so that test asserted its snapshot rather than skipping.

Security was probed fresh rather than assumed from a prior sweep. All 53 built-in patterns were driven with long near-miss inputs at two lengths and four attack shapes; the worst raw pattern is `extendedDuration` at 0.35ms and the worst through the public parse surface is `email` at 1.05ms on a 5001-character adversarial string, so there is no catastrophic backtracking on the surface the envelope calls adversarial.

Dependency hygiene needed scoping rather than a headline. `pnpm audit` exits 1 with 97 advisories, 2 critical and 59 high, which sounds severe and reaches no consumer: `packages/zod` declares zero `dependencies`, `peerDependencies` and `optionalDependencies`, and zero advisory paths are rooted in `packages__zod`. The four roots are the repo root, `packages__bench`, `packages__docs` and `packages__treeshake`, all dev and tooling workspaces, and no workflow in `.github/workflows` deploys the docs site from this repo. Dev-tooling advisories are not an enumerated input surface, so this is out of envelope and no finding is filed; the numbers are recorded here so the next audit does not have to rediscover them.

Error handling: every `catch` in core was read. The two that swallow - `String(payload.value)` and `Number(payload.value)` under `def.coerce` - are correct fall-through, since letting a `Symbol` conversion throw would replace a clean `invalid_type` issue with an escaping `TypeError`. The one generic wrapper, `throw new Error("Error converting schema to JSON.")` in `to-json-schema.ts`, was attacked with six schemas and could not be provoked: `bigint`, `date`, `symbol`, a transform and a custom type all deliver their own specific unrepresentable message to the caller intact. Nothing is filed, because the evidence rule forbids a speculative finding, and this entry names the site so a later audit starts from where this one stopped rather than from scratch.

Scores, all claiming the whole mapped surface: architecture None, code quality None, security None, testing None, error handling None, performance None on the ReDoS axis only (the benchmark suite was not run, so no throughput claim is made), documentation Low, dependency hygiene None for the shipped artifact with the dev-tooling exclusion stated above, developer experience None, correctness None, observability None. UX and accessibility do not apply: the library ships no user interface, and the docs site, though user-facing, is deployed by no workflow in this repository.

Filed: DOCS-COVERAGE-1 (Low, docs). This is the third finding sharing one root cause with SUCCESS-DOC-1 and SLUG-DOC-1 - a shipped public API that no page mentions, found only when somebody happens to look - so under the three-strike rule it replaces instance patching with one structural task rather than a third instance fix. The enumeration is executed, not asserted: `z.xid()` and `z.ksuid()` have zero docs mentions while every sibling string format has three or four, and six of the twelve codec entry points have zero while `decode` and `encode` have twelve and sixteen. It stays Low because an absent page misleads nobody, which is the same rubric reading its two predecessors were filed under.

Closed: none. This iteration audits.

Learnings: an audit headline can be the opposite of its finding - 97 advisories with 2 critical scoped down to nothing shipped, because the published package declares no dependencies at all and every advisory path roots in a tooling workspace; scope the paths before scoring the count. A state file's own measured numbers drift silently across runs, so the declaring path re-reading them is what catches it.

Next: the ledger holds one carried Low and no High or Medium, the inventory has no unswept row, and closeout is in force, so the next iteration runs the evaluator gate with 3 iterations remaining after it.

## iter 6/10 | 8e137b16-185920 | 2026-08-16 | ROTATION | rotation

Task: ROTATION - JOURNAL.md reached 502 lines after this iteration's AUDIT entry, past the 500-line bound.

Changed: JOURNAL.md (8 oldest entries removed), JOURNAL-archive.md (the same 8 appended).

Checkpoint: ea83ab3d1cb818d5fbfb2f46a3594b28c5d0d721

Verification: Split on lines beginning `## iter` followed by a digit, so the heading-grammar example in the preamble is not counted as an entry and is not moved. 18 entries were present and the 10 most recent are kept, so 8 moved. The archive was appended to and never rewritten: its entry count went 9 to 17, and 17 plus the 10 kept is 27, which is the 18 plus 9 held before the move. JOURNAL.md is now 282 lines.

Learnings: none beyond the mechanical step.

Next: unchanged by this entry - the evaluator gate runs next iteration.

## iter 7/10 | 8e137b16-185920 | 2026-08-16 | EVALUATOR | audit

Task: EVALUATOR gate, invocation 1 of this run, run at iteration 7 with 3 iterations left so a rejection could still be answered. Verdict: REJECT. The run does not converge.

Changed: BACKLOG.md (CYCLE-FP-2 filed, the false Settled class line removed, DOCS-COVERAGE-1's enumeration corrected), PLAN.md (the composites row's propagation claim narrowed, two Lessons added), `.jeffy/evaluator/8e137b16-185920-1.md` written by the evaluator.

Checkpoint: af4e14eb36319f902a3069c3aedd0dd8afcbfe0d

Verification: Evaluator: REJECT - the iteration 2 fix for CYCLE-FP-1 narrowed the false positive without closing it, and three state-file claims written around that fix are false.

The gate's central finding was reproduced here before being accepted, and the first attempt to reproduce it failed, which is worth recording. Building the schema with `createdAt` before `children` in the shape, both the flat and the nested value threw `RangeError` correctly - the throw simply happened before the lazy ever re-entered. Putting `children` first reproduces it exactly: with `Node = z.lazy(() => z.object({children: z.optional(z.array(Node)), createdAt: z.string().transform(s => new Date(s).toISOString())}))`, the value `{createdAt: "not-a-date"}` throws `RangeError: Invalid time value` and `{children: [{createdAt: "2020-01-01"}], createdAt: "not-a-date"}` returns `success: false` carrying `custom: Recursion limit exceeded`. The only difference between the two is whether the lazy recursed first. Filed as CYCLE-FP-2 at Medium, the same swallowed-error consequence its predecessor carried.

The root cause is one I wrote into the fix: `peak` is a high-water mark cleared only when `depth` returns to 0, so it answers "did this lazy ever re-enter during this parse" when the conversion needs "is this error coming out of that recursion". My enumeration hid it. I enumerated the class by where the `RangeError` is thrown - beside the lazy, inside its subtree, with no lazy at all - and all three of those arrangements share `peak === 1`, so the enumeration was complete along an axis the code does not branch on and empty along the one it does. The evaluator found it by reading the branch instead of the list.

Three false claims were corrected rather than left to a later iteration, because a false settlement is actively harmful: it bars future audits from re-filing a reproduced Medium. The Settled classes line asserting the class was fixed class-complete is removed, since it is not. The core-schemas-composites row in PLAN.md claimed its battery pins propagation "at each place it can enter"; it drives only the three peak-1 arrangements, and the row now says so and names CYCLE-FP-2.

The gate also corrected DOCS-COVERAGE-1's own enumeration, which I got wrong when filing it. `safeDecode`, `decodeAsync` and `safeDecodeAsync` are shown in `codecs.mdx` in method form, so my "0 mentions" was an artifact of counting only the `z.`-prefixed spelling, and no counting form yields the "12 and 16" I wrote. Re-measured with `grep -rhow`: the encode half - `safeEncode`, `encodeAsync`, `safeEncodeAsync` - is genuinely absent at 0, each decode counterpart appears once, and bare `decode` and `encode` appear 75 and 79 times. The finding survives at Low, smaller and differently shaped than filed; the evaluator explicitly confirmed Low is the correct score and is not a reject reason.

What the gate confirmed held: Verify exits 0 at 343 files and 3841 tests; all four closed tasks' acceptance checks pass; cycles are still rejected rather than thrown through the sync, async, safe and codec entry points, under mutual recursion and through `z.json()`; DAGs and deep-but-finite values are still accepted; the counters do not leak across parses, with alternating cyclic and clean parses giving false, true, false, true, false, true, and four interleaved concurrent async parses giving true, false, true, false. Both documentation edits were executed verbatim and every stated output matched.

Verify command exits 0 this iteration: 343 files, 3841 tests, no type errors. This iteration changed only state files and the evaluator artifact, but the ledger changed state - CYCLE-FP-2 was added - so it is not a stall, and an EVALUATOR entry is a ceremony entry in any case.

Invocation accounting: the cap is 2 for this run, not 3, because the first invocation landed at iteration 7 and the budget midpoint is 5. One invocation remains and it is the last.

Learnings: enumerate over the axis the code branches on, not the axis that is easy to name - three arrangements that all shared one value of the deciding variable read as a complete class. A high-water mark is not a scope: a counter that resets only at zero keeps reporting the peak for the rest of the operation.

Next: CYCLE-FP-2 is the only open Medium and takes iteration 8. That leaves iteration 9 spare and iteration 10 for the final invocation and, on a PASS, the declaration.

## iter 8/10 | 8e137b16-185920 | 2026-08-16 | CYCLE-FP-2 | done

Task: CYCLE-FP-2 (Medium) - the iteration 2 fix cleared `peak` only when `depth` fell to 0, so once a lazy had re-entered anywhere in a parse, every later `RangeError` reaching the outermost frame was relabelled `Recursion limit exceeded`.

Changed: `packages/zod/src/v4/core/util.ts` (new `isStackOverflow`), `packages/zod/src/v4/core/schemas.ts` (`$ZodLazy` drops `peak` and gates on the error instead), `packages/zod/src/v4/classic/tests/lazy.test.ts`, `.jeffy/probes/core-schemas-composites/probe.ts`, PLAN.md, BACKLOG.md.

Checkpoint: c1c90b0caa4daa44dfedb85735c552570168df8e

Verification: The filed reproduction ran first and reproduced: `{createdAt: "not-a-date"}` threw `RangeError: Invalid time value` while `{children: [...], createdAt: "not-a-date"}` returned `success: false` carrying `Recursion limit exceeded`.

The third attempt at this class is the first that does not infer the overflow from the parse's recursion history. Both earlier attempts asked a question about the parse - has a lazy been entered, has this lazy re-entered - when the question that matters is about the error. `isStackOverflow` answers it directly by matching only the whole message a real engine emits, and `depth` survives with its role reduced to choosing which frame converts so the issue path stays at the lazy; it no longer decides whether to convert. That also removes a variable rather than adding one.

Nineteen behaviours were driven on both sides of every distinction. A user `RangeError` now propagates whether the lazy never recursed, recursed once, recursed twice, or the throw came from inside the recursion, and in the three arrangements the previous fix already handled, on the sync and async paths. Cycles still convert through `safeParse`, `safeParseAsync`, `z.json()`, `safeEncode`, mutual recursion between two lazy instances, and as a `ZodError` from `parse()`. DAGs, a 500-deep finite value, interleaved concurrent parses and alternating cyclic and clean parses of one schema are all unchanged.

One regression was introduced and caught inside this iteration. The first pattern carried a bare `stack overflow` alternative I added speculatively without attributing it to any engine, and it matched the battery's own fixture message `"not a stack overflow"`, converting the very case the fixture exists to pin. The pattern is now anchored to the whole message and lists only wordings a real engine emits - V8, JavaScriptCore and Hermes say "Maximum call stack size exceeded", SpiderMonkey says "too much recursion". An unrecognised engine makes the helper return false and the `RangeError` propagate, which is the safe direction: a real error reaching the caller beats a fabricated one.

The enumeration was rebuilt over the axis the code branches on, which is the lesson the gate taught. The previous one enumerated by where the throw sits and every case in it shared `peak === 1`; this one enumerates by recursion depth at the moment of the throw, the variable both failed attempts were wrong about.

Differential against unfixed code, with `core/schemas.ts` and `core/util.ts` swapped back to `git show HEAD:` and restored byte-identically after, keyed by full path: the battery reports 4 failures naming the recursed-once, recursed-twice, thrown-from-inside and async cases, and `lazy.test.ts` reports 1 failed of 22. A type error the new test hit under `exactOptionalPropertyTypes` was fixed in the type rather than worked around.

Verify command exits 0: 343 files, 3841 tests, no type errors, 17s. The test count is unchanged because the new assertions extend an existing test. All seven batteries owning the touched paths pass: the five over `core/schemas.ts`, plus core-util and core-util-slugify over `core/util.ts`. `pnpm format:check` and `pnpm lint:check` both clean.

Change discipline: `$ZodLazy` backs `z.lazy` and `z.json` and the change alters which errors surface as issues, so the contract was checked whole - the 3841 pre-existing tests pass unchanged. Observable behaviour moves in one direction only, toward propagating errors that were previously absorbed; nothing that was converted before and should have been is converted any less. `isStackOverflow` is a new export on `core/util.ts`, so the core-util row is re-swept at this checkpoint with its battery green, as is core-schemas-composites whose battery changed. No documentation mentions the message.

Closed: CYCLE-FP-2 (Medium) - fixed in `core/schemas.ts` and `core/util.ts`, evidenced by the reproduction failing first, by nineteen driven behaviours, and by a differential run of both checks against unfixed code. The Settled classes line is restored with the corrected enumeration axis and now records both failed attempts, so a future audit can see which inferences were tried and why they were wrong.

Learnings: detect the condition, not the history that usually accompanies it - two attempts inferred a stack overflow from recursion state and each converted whatever that state shadowed. A message pattern used as a discriminator must be anchored to the whole message; an unanchored alternative matched a fixture that merely mentioned the phrase.

Next: no High or Medium is open, no inventory row is unswept, and one Low is carried. Iteration 9 is spare and iteration 10 holds the final evaluator invocation and, on a PASS, the declaration.

## iter 9/10 | 8e137b16-185920 | 2026-08-16 | EVALUATOR | blocked

Task: EVALUATOR gate, invocation 2 of 2, run at iteration 9 rather than 10 so that a rejection would still leave an iteration to answer it. Verdict: REJECT. This is a terminal REJECT - the cap is 2 for this run because the first invocation landed after the budget midpoint - so the run enters gate salvage: it works only findings this gate filed, never re-invokes, never audits, never declares, and ends blocked.

Changed: BACKLOG.md (LAZY-ABSORB-1, COMPOSITES-DAG-1 and UTIL-SWEEP-1 filed), PLAN.md (two false row claims corrected, two Lessons added), `.jeffy/evaluator/8e137b16-185920-2.md` written by the evaluator.

Checkpoint: 3dd00272aa7adb4d8e3a38f49567de6a61902958

Verification: Evaluator: REJECT with three reasons, all three reproduced here before being accepted.

The central one is a regression my own iteration 8 introduced and neither the suite nor the battery caught. Moving the overflow conversion into `$ZodLazy` put the resulting issue below every wrapper between the lazy and the parse boundary, so a wrapper absorbs it. Differential against `3a493287`, swapping `core/schemas.ts` and `core/parse.ts` back and restoring them: `z.catch(Rec, "fb")` on a cyclic value now returns `success: true data: "fb"` where it returned rejected, `z.success(Rec)` returns `success: true data: false` where it returned rejected, and `z.object({a: z.catch(Rec, "fb")})` returns `success: true` where it returned rejected. The bare schema still rejects, which is exactly why 3841 tests stayed green - every test drives the unwrapped shape.

The same root cause is a cost multiplier, which I did not anticipate at all. Converting at the lazy ends one subtree where converting at the boundary ended the parse, so each sibling now exhausts and unwinds the whole stack in turn: `z.array(Rec).safeParse` over 1000 cyclic elements measures 2350ms at HEAD against 4ms pre-run.

My iteration 8 entry claimed "Observable behaviour moves in one direction only, toward propagating errors that were previously absorbed". That is false, and the reproduction above is what falsifies it. Past entries are never rewritten, so the correction is recorded here: the change moved behaviour in both directions, and the direction I did not check is the one that broke. I asserted a one-directional claim without enumerating what sat between the new conversion site and the boundary.

The two smaller reasons are false certifications, both mine. The composites row claimed its battery pins that a DAG is accepted; `grep -c DAG` on that battery returns 0 and it builds no shared-reference value, so the claim was decoration - and a wrongly rejected DAG is precisely the false positive the first CYCLE-1 attempt was abandoned for, which makes the missing coverage worse than incidental. The core-util row was marked re-swept "after `isStackOverflow` was added" while `grep -rn isStackOverflow .jeffy/probes/` returns nothing and the battery header still declares a 64-export scope against the 65 the scope grep now returns. Both row texts are corrected in this iteration so they stop asserting coverage that does not exist, and the missing coverage is filed as COMPOSITES-DAG-1 and UTIL-SWEEP-1.

What the gate confirmed held: Verify exits 0 at 343 files and 3841 tests with no type errors; all four earlier acceptance checks pass; `pnpm format:check` and `pnpm lint:check` exit 0 at 387 files; seven batteries owning the touched paths pass. CYCLE-FP-2 itself is genuinely closed - the gate drove the invocation-1 reproduction at depths 0, 1, 2, 3, 10 and 50, from inside the recursion, async, in a sibling and under mutual recursion, and all propagate; cycles still convert through all eight decode and encode variants, `z.json()` and a self-referential lazy; `depth` does not desynchronize across shared instances, `.describe()` clones, or a parse that threw mid-descent; `isStackOverflow` answered correctly on 15 hand-built cases plus a real engine overflow. DOCS-COVERAGE-1 re-scored Low with every number in it re-measuring exactly, and every Settled-classes enumerating check and the Declined slugify count re-run true.

Verify command exits 0 this iteration: 343 files, 3841 tests, no type errors. The ledger changed state - three tasks added - so this is not a stall, and an EVALUATOR entry is a ceremony entry in any case.

Learnings: moving a conversion deeper into the tree changes who can absorb its result, so enumerate what sits between the new site and the boundary before moving one; a suite that only ever drives the unwrapped shape cannot see a wrapper regression. Converting at the point of failure ends one subtree while converting at the boundary ends the parse, which is a per-sibling cost multiplier wherever reaching the failure is expensive.

Next: gate salvage with one iteration left. Iteration 10 works LAZY-ABSORB-1, the only Medium the gate filed, and the run then ends blocked with COMPOSITES-DAG-1, UTIL-SWEEP-1 and DOCS-COVERAGE-1 carried to the next run.

## iter 10/10 | 8e137b16-185920 | 2026-08-16 | LAZY-ABSORB-1 | done

Task: LAZY-ABSORB-1 (Medium), worked under gate salvage after the terminal REJECT - converting the overflow inside `$ZodLazy` put the issue below every wrapper, so `catch` and `success` absorbed it and a cyclic value validated, and each sibling unwound the whole stack instead of the first ending the parse.

Changed: `packages/zod/src/v4/core/parse.ts` (`runOrOverflow` restored at the four boundary entry points, now gated on `isStackOverflow`), `packages/zod/src/v4/core/schemas.ts` (`$ZodLazy` back to three lines, counter and catch removed), `.jeffy/probes/core-schemas-composites/probe.ts`, PLAN.md, BACKLOG.md.

Checkpoint: 268adac9215dba6d92ade300ce6212a3e06571b9

Verification: The filed reproduction ran first and reproduced every arrangement.

The fix is the synthesis the three previous attempts each held half of. CYCLE-1 had the right location and the wrong discriminator; iteration 8 had the right discriminator and the wrong location. Converting at the boundary is what keeps the issue out of reach of the wrappers and ends the parse at the first exhausted sibling; `isStackOverflow` is what keeps a user `RangeError` propagating. Neither works alone, and putting them together deletes rather than adds - `$ZodLazy` returns to its original three lines with no counter and no catch, and the whole mechanism is one wrapper in `parse.ts`.

Every verdict now matches the pre-run baseline while the two earlier fixes stay fixed. Restored to pre-run: `z.catch(Rec, fb)`, `z.success(Rec)` and `z.object({a: z.catch(Rec, fb)})` on a cyclic value all reject where iteration 8 returned success, and `z.array(Rec)` over 1000 cyclic elements takes 2ms against the 2350ms it cost at HEAD and 4ms pre-run. Still fixed: a user `RangeError` propagates when the lazy never recursed, recursed first, and when thrown from inside the recursion, sync and async. Still correct: cycles convert through `safeParse`, `safeParseAsync` and `z.json()`, DAGs and a 500-deep finite value are accepted.

One thing only the boundary can do turned up by accident. While the wrapper was briefly self-recursive, the failure was `SyntaxError: Invalid regular expression: ...: Stack overflow` raised from inside `isStackOverflow` - at true stack exhaustion even evaluating the regex can fail. Converting at the boundary runs that test after the stack has fully unwound, so the discriminator is never asked to work in the condition it detects. Inside `$ZodLazy` it was being asked exactly that.

The battery now covers what it missed. It drives the three wrapper arrangements and the 1000-sibling cost with a deliberately loose 400ms bound, so only that regression trips it. Differential against the iteration 8 code, swapped back with `git show HEAD:` and restored byte-identically: the battery reports 2 failures naming the wrapper absorption and the cost, so the check that would have caught this now exists. Nothing in the 3841-test suite fails either way, which is the point - every test drives the unwrapped shape.

A claim in this iteration's own settled-class line was wrong on first writing and corrected before the checkpoint: it said the enumerating grep returns three lines, all in `util.ts`; it returns five, three in `util.ts` and two in `parse.ts`, of which one is an expression and four are comments.

Verify command exits 0: 343 files, 3841 tests, no type errors. All eight batteries owning the touched paths pass. `pnpm format:check`, `pnpm lint:check` and `pnpm check:circular` all exit 0.

Change discipline: the contract preserved is every verdict the pre-run tree gave, which is what the differential checks directly rather than by proxy - all four wrapper arrangements and the cost now agree with `3a493287`, and the suite's 3841 tests pass unchanged. The core-parse-config row is re-swept at this checkpoint because `core/parse.ts` gained the wrapper back, and core-schemas-composites because its battery changed.

Closed: LAZY-ABSORB-1 (Medium) - fixed in `core/parse.ts` and `core/schemas.ts`, evidenced by the reproduction failing first, by every verdict matching the pre-run baseline, and by a differential showing the new battery cases fail against the code they were written for. The settled-class line is rewritten to record all three attempts and both enumeration axes, since each attempt failed on the axis it did not enumerate.

Learnings: when two fixes each solve half a problem, check whether the halves compose before writing a third mechanism - here they did, and composing them removed code that both had added. A discriminator must be evaluated somewhere it can still run: testing a regex at stack exhaustion can itself throw.

Next: budget is exhausted. Gate salvage closed the one Medium the gate filed; COMPOSITES-DAG-1, UTIL-SWEEP-1 and DOCS-COVERAGE-1 are carried, all Low, and the declaration waits for the next run's fresh gate.

## iter 1/10 | 9b564ec0-201434 | 2026-08-16 | COMPOSITES-DAG-1 | done

Task: COMPOSITES-DAG-1 (Low) - the composites battery asserted nothing about a DAG while the row it certifies had claimed it did, and a wrongly rejected DAG is the false positive the first CYCLE-1 attempt was abandoned for.

Changed: `.jeffy/probes/core-schemas-composites/probe.ts` (three DAG cases), `.jeffy/probes/core-schemas-composites/paths` (parse.ts and util.ts added), PLAN.md, BACKLOG.md.

Checkpoint: 8cd321db43f73add35b5ce5dbce0f9fe6ad4755d

Verification: The filed reproduction ran first: `grep -c DAG .jeffy/probes/core-schemas-composites/probe.ts` returns 0 at the previous checkpoint.

The battery now builds a diamond - one node reachable through two paths, `{v:1, kids:[{v:2, kids:[shared]}, shared]}` - and asserts it is accepted under `z.lazy`, and a second one under `z.json` where the shared node appears in an object, an array and a nested object. A third case sends the same diamond with an invalid shared node and requires rejection, so the accepting pair cannot be satisfied by a check that stopped descending at the second reference.

Strength was proved against the defect, not asserted. `core/schemas.ts` was copied aside by full path, `$ZodLazy` was patched with a cycle check keyed on a `WeakSet` of seen objects, and the battery was re-run: both DAG cases fail, `rejected` where they want `ACCEPTED`. The first patch written for this differential was wrong in an instructive way - it deleted from the set in a `finally`, which makes the check path-scoped and therefore correct, and every DAG case passed against it. Only the variant that never removes - "have I ever seen this object" rather than "is this object on the path above me" - is the false positive, and that is the one the cases now discriminate against. The invalid-shared-node case passes under both, as it should; it guards vacuity, not the cycle axis. `core/schemas.ts` was restored and `git diff` on it is empty.

The battery's `paths` file declared only `core/schemas.ts` while the mechanism it pins - the wrapper-absorption cases and the 1000-sibling cost bound - moved to `runOrOverflow` in `core/parse.ts` at iteration 10, with the discriminator in `core/util.ts`. An edit to either file alone would not have run this battery, which is exactly the gap the paths mechanism exists to close, so both are declared now.

Verify command exits 0: 343 files, 3841 tests, no type errors, 21s. `pnpm format:check` and `pnpm lint:check` exit 0 at 387 files. No source file changed this iteration, so no other battery owns a touched path; the composites battery itself is green.

Queue position: no Surface inventory row is stale. Since each row's recorded commit the only change inside a shared module is a single hunk in `core/schemas.ts`, `git diff 11478f27 HEAD -- packages/zod/src/v4/core/schemas.ts` returning exactly one `@@` header and it inside `$ZodLazy`, whose row is recorded at HEAD; every other row's own files are unchanged since its commit. So the top of the queue was the first open Low. The ledger changed state, so this is not a stall.

Learnings: a differential that proves a check is strong has to carry the defect the check names, not a nearby one - a seen-set that deletes on unwind is a correct cycle detector and passes everything, and only the variant that never removes reproduces the false positive. A battery's `paths` file has to move when the behaviour it pins moves modules, or it silently stops owning the code it tests.

Next: UTIL-SWEEP-1 is the top open Low - the core-util battery does not reach `isStackOverflow` and its header scope count is one short of the module's exports.

## iter 2/10 | 9b564ec0-201434 | 2026-08-16 | UTIL-SWEEP-1 | done

Task: UTIL-SWEEP-1 (Low) - the core-util row was marked re-swept for `isStackOverflow` while no battery mentioned it, and the battery header declared a 64-export scope against the 65 the scope grep returns.

Changed: `.jeffy/probes/core-util/probe.ts` (four `isStackOverflow` cases, header corrected), PLAN.md (core-util row rewritten, three Lessons), BACKLOG.md (UTIL-SWEEP-1 closed, SCOPE-COVERAGE-1 filed).

Checkpoint: 8501ba22f700a5d9b1d9d5ad2773d1dbb0a89ce6

Verification: The filed reproduction ran first and reproduced: `grep -rn isStackOverflow .jeffy/probes/` exits 1 with no output, and the scope grep returns 65 against the header's 64.

The battery now drives both halves of the conjunction and both sides of the anchor: a real engine overflow provoked by unbounded self-recursion is recognised and reported as a `RangeError`, both wordings a shipping engine emits are recognised with and without the trailing period, a user `RangeError` whose message merely mentions an overflow is not, and neither is a plain `Error` carrying the exact engine text, a bare string, or `undefined`.

Strength was proved against the defect. `core/util.ts` was copied aside by full path and `isStackOverflow` was replaced with the shape iteration 8 first wrote - an unanchored pattern with a bare `stack overflow` alternative, and no `instanceof RangeError` guard. Against it the near-miss case fails `[true,true]` where it wants `[false,false]` and the type case fails `[true,false,false]`, so both new discriminating cases fail on the code they exist to catch. The engine case passes under both, as a positive control should. `core/util.ts` was restored and `git diff` on it is empty.

Sweeping the row surfaced a third instance of one root cause, so the three-strike rule applies. Enumerating the scope grep against `grep -qw <name>` over the battery returns 24 exports the battery never names, while the row asserted it drove 64 of the 65. Both that claim and the header are corrected to the measured numbers - 65 in scope, 41 named - and the 24 are listed by name in the row, with the object-shape helpers among them noted as driven through the public methods in the collections and classic batteries rather than here. Instance patching stops there: SCOPE-COVERAGE-1 replaces it with one structural task, a checker that re-runs each row's scope enumeration and fails when a symbol is neither named by that row's battery nor disclosed as a gap in the row text. It is filed Low, class test, matching the severity the evaluator gate itself gave UTIL-SWEEP-1 for the same class of defect: the consequence falls on the honesty of the loop's own certification, not on anything a zod caller can reach.

Verify command exits 0: 343 files, 3841 tests, no type errors. `pnpm format:check` and `pnpm lint:check` exit 0 at 387 files. The final diff touches no source path, so no battery is triggered by ownership; the core-util battery changed and is green, and core-util-slugify, the other battery declaring `core/util.ts`, is unaffected because the file is byte-identical to its checkpoint.

The ledger changed state twice - one task closed, one filed - so this is not a stall.

Learnings: a differential proves strength only when it carries the exact defect the check names; the first variant written for iteration 1's DAG differential was a correct detector and passed everything. A row's coverage claim is checkable in one line by diffing its scope enumeration against a word-grep over its battery, and that check is what turned two instances into a class.

Next: two Lows are open, below the replenishment floor, and this run still needs a full fresh-evidence audit before any declaration is possible. Iteration 3 runs that audit, which subsumes the replenishment.

## iter 3/10 | 9b564ec0-201434 | 2026-08-16 | AUDIT | audit

Task: AUDIT - this run's full fresh-evidence audit, run because the ledger had fallen below the replenishment floor and no declaration is possible without one. Closeout does NOT begin: the audit scored one in-envelope Medium.

Changed: BACKLOG.md (JSONSCHEMA-DEPTH-1 and OVERFLOW-I18N-1 filed).

Checkpoint: 25c15820b2dce80e20ce32383bc58e57a6e1def4

Verification: Scores claim all 28 Surface inventory rows. None is unswept, none is stale, and all 29 batteries were re-run green in this iteration, so the correctness evidence is executed rather than cited.

Verify exits 0 at 343 files, 3841 tests, no type errors. The five things the Oracle class says it does not cover were run by hand and all exit 0: `pnpm build`, `pnpm format:check`, `pnpm lint:check`, `pnpm check:circular` (no circular dependency found), and both cross-package suites. Testing was not scored from the whole-suite run alone: `global-config` and `from-json-schema` were each run alone and pass, so neither depends on state another module leaks.

The changed surface was probed rather than assumed. Everything this run and the last one touched sits at the parse boundary, so all twelve entry points were driven with a cyclic value: the six safe forms reject, the six throwing forms throw a classic `ZodError` carrying a `custom` issue, and mini agrees. The eight encode and decode entry points are covered because each delegates to one of the four `runOrOverflow` wraps rather than calling `_zod.run` itself, which was read off the delegation rather than assumed. The converted issue also survives every error-shaping path: it finalizes to `code,message,path` with the cyclic input dropped, so `JSON.stringify(error)`, `prettifyError`, `treeifyError` and `flattenError` all complete where a retained cyclic input would have thrown.

Security was probed fresh. All 53 built-in patterns were driven with four attack shapes at 1000 and 5000 characters: worst raw pattern `md5_hex` at 0.23ms, worst through the public parse surface `email` at 0.42ms, so there is no catastrophic backtracking on the surface the envelope calls adversarial. Hostile-value shapes were driven too - throwing getters, a Proxy that throws on `ownKeys`, a throwing `Symbol.toPrimitive`, a `__proto__` payload, throwing iterators. The coercions reject cleanly and `__proto__` does not pollute; the getter and Proxy shapes propagate the caller's own exception out of `safeParse`, and nothing is filed for them because an untrusted value arriving as JSON, form data or query parameters cannot carry a getter or a Proxy - reaching that requires already executing code in the process, which is out of envelope, and propagating a real error beats fabricating one, exactly as the settled overflow class concluded.

Performance was measured on the one piece of new hot-path code. A/B of `runOrOverflow` by removing the wrapper from `core/parse.ts` and restoring it byte-identically: 0.2108 us/op with it against 0.2080 without, best of five runs of 200k parses of a three-field object, so the boundary try/catch costs about 1.3 percent.

Dependency hygiene re-scoped rather than re-headlined. `pnpm audit` exits 1 with 97 advisories, 2 critical and 59 high, and reaches no consumer: `packages/zod` declares zero `dependencies`, `peerDependencies` and `optionalDependencies`, and every advisory path roots in `.`, `packages__docs`, `packages__treeshake` or `packages__bench`, all dev and tooling workspaces. Out of envelope, nothing filed.

Scores, all claiming the whole mapped surface: architecture None, code quality None, security None, testing None, error handling Medium (JSONSCHEMA-DEPTH-1), performance None, documentation Low (DOCS-COVERAGE-1 carried), dependency hygiene None for the shipped artifact with the tooling exclusion above, developer experience None, correctness None, observability Low (OVERFLOW-I18N-1). UX and accessibility do not apply: the library ships no user interface and no workflow in this repository deploys the docs site.

Filed: JSONSCHEMA-DEPTH-1 (Medium) - both JSON Schema conversion boundaries let an engine `RangeError` reach the caller. Bisected on this host, `z.fromJSONSchema` throws at depth 1250 and `JSON.parse` accepts to 2228, so there is a band of roughly a thousand depths where a document arrives intact and then crashes the compiler; `z.toJSONSchema` throws at 1562. It is Medium rather than Low because the envelope classes JSON Schema documents as adversarial and admits hostile hand-crafted input there, and rather than High because it fails fast, corrupts nothing, returns no wrong verdict, and needs input no legitimate producer emits. The `toJSONSchema` half is Low on its own, being user-error surface, and rides the same fix. This is not inside the settled overflow class: that settlement is scoped to mislabelling and wrapper absorption at the four parse entry points, and these two boundaries have no conversion at all. OVERFLOW-I18N-1 (Low) - the overflow message is the single hardcoded issue message in core and bypasses the locale chain, reproduced by a German-locale parse returning English.

Closed: none. This iteration audits.

Learnings: a boundary that already fixed a class does not generalise to its siblings by itself - the parse family converts engine overflows at four entry points while the two JSON Schema conversions, which walk a caller-supplied tree just as recursively, never got the same guard. Comparing a limit against the gate upstream of it is what turns a stack-depth curiosity into a finding: an overflow deeper than `JSON.parse` tolerates is unreachable over the wire, and one shallower than that is not.

Next: iteration 4 fixes JSONSCHEMA-DEPTH-1, the only open Medium. Iteration 5 then runs the second full audit that a declaration needs, since this one did not come back clean, leaving iteration 6 for the evaluator gate with four iterations behind it to answer a rejection.

## iter 4/10 | 9b564ec0-201434 | 2026-08-16 | JSONSCHEMA-DEPTH-1 | done

Task: JSONSCHEMA-DEPTH-1 (Medium) - the two JSON Schema conversion boundaries walk a caller-supplied tree recursively with no guard, so an engine `RangeError` reached the caller unconverted on a surface the envelope calls adversarial.

Changed: `packages/zod/src/v4/core/json-schema-processors.ts` (`toJSONSchema` split into a guarding wrapper and `_toJSONSchema`), `packages/zod/src/v4/classic/from-json-schema.ts` (both walks discriminated, shared message constant), `packages/zod/src/v4/classic/tests/{from,to}-json-schema.test.ts`, `.jeffy/probes/classic-from-json-schema/probe.ts`, `.jeffy/probes/core-to-json-schema/probe.ts`, PLAN.md, BACKLOG.md.

4089072fdc3b642bd294913067b33d2fb18a65eb

Verification: The filed reproduction ran first and reproduced, and running it also corrected the finding. `fromJSONSchema` has two failure bands, not one. Between depth 1250 and 2228 the normalizing JSON round trip succeeds and the conversion walk overflows, so a raw `RangeError` escaped. Past 2228 `JSON.stringify` overflows inside a bare `catch` whose only message is "not valid JSON (possibly cyclic); use $defs/$ref for recursive schemas" - so the deeper document was not merely unhandled, it was misdiagnosed as cyclic, which is the worse of the two because it names a cause that is not there. The filing had only the first band.

The enumeration was built by provoking a failure at every user-facing walk over a caller-supplied tree, never by grepping for recursive calls. Fourteen were driven at depths of 3000: `fromJSONSchema` and `toJSONSchema` in both its schema and `io: "input"` forms overflow; parsing a 3000-deep value does not, because the parse boundary already converts; and building a 3000-deep schema, `.describe()` over it, `treeifyError`, `prettifyError`, `flattenError`, `JSON.stringify` of the value, a 3000-part template literal, a 3000-member union, a 3000-deep intersection chain and a 3000-deep pipe chain all complete. So the class is exactly three boundaries and two of them were unguarded.

Both fixes convert at the outermost frame rather than inside the walk. That is the constraint iteration 10 discovered the hard way: at true exhaustion even evaluating the discriminator can throw, and only a frame that runs after the stack unwinds can be trusted to ask the question. `toJSONSchema` therefore keeps its overloads and delegates to `_toJSONSchema`, whose body is unchanged, so the guard covers the registry branch as well as the single-schema one.

Executed after the fix: at depths 1200, 1500, 2000, 2500, 5000 and 20000 `fromJSONSchema` reports nesting, and at 1600, 2000, 5000 and 20000 so does `toJSONSchema`, including through a registry. A genuinely cyclic document still reports "possibly cyclic", so the two diagnoses stay distinct. Shallow documents and schemas are unchanged and a 3-deep document still round trips.

Differential against unfixed code, both source files swapped back with `git show HEAD:` keyed by full path and restored: the two new project tests report 2 failed of 308, one on `'Maximum call stack size exceeded'` where it wants `/nested too deeply/` and one on the "possibly cyclic" text. Both fail on the code they were written for.

Verify command exits 0: 343 files, 3845 tests, no type errors; the count moves by four because each new test carries its typecheck pass. `pnpm format:check` failed on the two probe files and was fixed with `pnpm format` before the checkpoint - biome walks `.jeffy/` and neither check is in the Verify command. `pnpm lint:check` and `pnpm check:circular` exit 0, the latter confirming the new `core/util.js` import into `classic/from-json-schema.ts` introduces no cycle. Both batteries owning the touched paths pass.

Change discipline: the contract preserved is every verdict and every emitted document at depths a caller can actually use - the suite's 3841 pre-existing tests pass unchanged, and the only observable change is at depths where the previous behaviour was an escaping `RangeError` or a false cycle diagnosis. No documentation page mentions either error message, so nothing there contradicts the change. The `core-to-json-schema` and `classic-from-json-schema` rows are re-recorded at this checkpoint with their batteries extended and green, rather than flipped unswept, because the probe that certifies them ran in this same iteration.

Closed: JSONSCHEMA-DEPTH-1 (Medium) - fixed at both boundaries, evidenced by the reproduction failing first, by the two-band characterization, by six depths per boundary after the fix, and by a differential showing both new tests fail against the unfixed code. Recorded as a settled class covering all three tree-walking boundaries, with the walks that cannot overflow named so a later audit does not re-derive them.

Learnings: a bare `catch` that relabels every failure will relabel a stack overflow too, and the resulting message is worse than no message because it names a cause that is not present. A finding's filed shape is a hypothesis - running the reproduction first turned one band into two and found the misdiagnosis that the filing had missed entirely.

Next: no High or Medium is open and three Lows are carried. Iteration 5 runs the second full fresh-evidence audit, which a declaration needs because the iteration 3 audit did not come back clean, leaving iteration 6 for the evaluator gate with four iterations behind it.

## iter 4/10 | 9b564ec0-201434 | 2026-08-16 | ROTATION | rotation

Task: ROTATION - JOURNAL.md passed 500 lines at 516 after this iteration's entry.

Changed: JOURNAL.md, JOURNAL-archive.md.

4089072fdc3b642bd294913067b33d2fb18a65eb

Verification: 19 entries were split on lines beginning `## iter` followed by a digit, so the heading-grammar example in the preamble is neither counted nor moved. The 9 oldest were appended to the end of JOURNAL-archive.md, which already held 17 and now holds 26, and the 10 newest stay in JOURNAL.md, which is now 284 lines. The archive was appended to, never overwritten, and its entry count is asserted to have grown by exactly the number moved.

Learnings: none.

Next: the checkpoint for this iteration covers both the fix and the rotation.

## iter 5/10 | 9b564ec0-201434 | 2026-08-16 | AUDIT | audit

Task: AUDIT - the second full fresh-evidence audit of this run, needed because the iteration 3 audit filed a Medium and so cannot support a declaration. It comes back clean: zero High and zero Medium in-envelope. Closeout begins with this entry - the run stops auditing, works or declines what is on the ledger, and converges.

Changed: BACKLOG.md (TOJSON-MISATTRIB-1 filed, Later reordered runtime-first per the ledger's own rule).

Checkpoint: d8544969c305c4d85c99b44b6ade4085fe0bf962

Verification: Scores claim all 28 Surface inventory rows. None is unswept, none is stale, and all 29 batteries were re-run green in this iteration against the tree iteration 4 changed, so the evidence is executed rather than carried over from the earlier audit.

Verify exits 0 at 343 files, 3845 tests, no type errors. The five things the Oracle class says it does not cover were run again and all exit 0: `pnpm build`, `pnpm format:check`, `pnpm lint:check`, `pnpm check:circular`, and both cross-package suites. Three modules were run alone - `to-json-schema`, `from-json-schema` and `global-config` - and pass in isolation, which matters more this iteration than usual because two of them gained tests.

The code this run changed was attacked rather than admired. The two new guards convert only what they detect: an `override` callback throwing its own `RangeError("my own range problem")` propagates unchanged, `z.bigint()` still reports "BigInt cannot be represented in JSON Schema", and a dangling `$ref` still reports "Reference not found". One misattribution did turn up and is filed: an `override` that overflows its own stack over a shallow two-key schema is reported as the schema being nested too deeply, which is a cause the guard has not established.

Security re-probed fresh: 53 built-in patterns driven with four attack shapes at 1000 and 5000 characters, every one under a millisecond both raw and through the public parse surface. Which pattern comes out worst moves between runs - `md5_hex` and `email` in iteration 3, `idnEmail` at 0.76ms and `cidrv4` at 0.96ms here - so the claim is the bound, not the ranking.

Performance measured on the changed surface, and the first measurement was wrong. A single A/B suggested `fromJSONSchema` had slowed 23 percent, 54.8us against 44.5us. Repeating it across three processes per version gave 46.2, 52.9 and 59.3 with the guards and 46.3, 46.5 and 55.4 without: the within-version spread exceeds the between-version gap, and the best observations are 46.2 against 46.3, so the guard's cost is below this host's noise floor on this benchmark. `toJSONSchema` is 5.5us per call either way.

Dependency hygiene unchanged and unchanged in scope: `pnpm audit` exits 1 with the same 97 advisories, 2 critical and 59 high, every path rooted in `.`, `packages__docs`, `packages__treeshake` or `packages__bench`, while `packages/zod` still declares zero dependencies of any kind. Out of envelope, nothing filed.

Scores, all claiming the whole mapped surface: architecture None, code quality None, security None, testing None, error handling Low (TOJSON-MISATTRIB-1), performance None, documentation Low (DOCS-COVERAGE-1), dependency hygiene None for the shipped artifact with the tooling exclusion above, developer experience None, correctness None, observability Low (OVERFLOW-I18N-1). UX and accessibility do not apply.

Filed: TOJSON-MISATTRIB-1 (Low, runtime) - the iteration 4 guard names a cause it has not established. It is Low rather than the Medium its predecessor carried because the ordinary case is described correctly and only caller-supplied recursion is misattributed, where the predecessor misdescribed the common case; the rationale is on the ledger line as severity discipline requires.

Closed: none. This iteration audits.

Learnings: a single A/B measurement is not a measurement - the noise on this host spans 20 percent on a 46us operation, so a difference smaller than the within-version spread is not a result. A guard that converts an error class rather than a condition inherits every cause of that class, so its message should name what was exhausted rather than which input it blames.

Next: closeout is in force with four carried Lows and no High or Medium anywhere. Iteration 6 runs the evaluator gate, invocation 1 of at most 2 - the cap is 2 because the first invocation lands past the budget midpoint of 5 - and declares in that same iteration if the verdict is PASS, since every other closing condition already holds. A REJECT leaves iterations 7 to 9 to close what it files and iteration 10 for the final invocation.

## iter 6/10 | 9b564ec0-201434 | 2026-08-16 | EVALUATOR | audit

Task: EVALUATOR gate, invocation 1 of at most 2 for this run, run at iteration 6 with four iterations left so a rejection could still be answered. Verdict: REJECT. The run does not converge here.

Changed: BACKLOG.md (JSONSCHEMA-METHODS-1 filed, the false settled-class line removed), PLAN.md and `.jeffy/probes/core-util/probe.ts` (the core-util coverage counts corrected to distinct names), `.jeffy/evaluator/9b564ec0-201434-1.md` written by the evaluator.

Checkpoint: 8a097254fce949ea5b6c9b729176519f1e126495

Verification: Evaluator: REJECT - the class iteration 4 recorded as complete is not, because three public entry points reach the same conversion walk without passing the guard.

The finding was reproduced here before being accepted. On a 20000-deep schema `z.toJSONSchema(s)` reports `Error: Schema is nested too deeply to convert to JSON Schema`, while `s.toJSONSchema()`, `s["~standard"].jsonSchema.input()` and `s["~standard"].jsonSchema.output()` each escape `RangeError: Maximum call stack size exceeded`. They are wired by `createToJSONSchemaMethod` and `createStandardJSONSchemaMethod` in `core/to-json-schema.ts` and reach `process`, `extractDefs` and `finalize` directly, never through the guarded function in `core/json-schema-processors.ts`.

My iteration 4 enumeration is what failed, and it failed in a way the Lessons already warn about. I built it by provoking a failure at every *walk* I could name and concluded the class was exactly three boundaries. The axis that decides the behaviour is not which walk recurses but which entry point reaches it, and along that axis the enumeration was never complete - `ZodType.toJSONSchema` is a declared public method that the classic-schemas-methods battery already drives, so the missed surface was inside ground the loop had mapped. Enumerating over the wrong axis is the same mistake that cost the previous run its iteration 8.

The settled-class line is removed rather than amended, because a false settlement is worse than none: PLAN.md bars an audit from filing inside a settled class, so leaving it would have shielded these three entry points from every future audit. The class returns to the ledger as JSONSCHEMA-METHODS-1, filed Low because a schema is developer-authored and the envelope classes that user-error, which is the same reasoning the guarded half was scored under and which the evaluator independently reached.

What the gate confirmed held: Verify exits 0 at 343 files and 3845 tests; all three closed tasks' acceptance checks pass, each re-run with its own differential - the DAG cases fail against a never-removing `WeakSet` cycle check, the `isStackOverflow` cases fail against the unanchored no-`instanceof` variant, and both conversion boundaries report nesting at six depths apiece in fresh processes; all 29 batteries exit 0; every settled-class enumerating grep returns what the ledger says; and all four open Lows reproduce and are accurately scored, which the gate stated explicitly is not a rejection reason. It also confirmed the guards convert only what they detect: a user `RangeError`, the unrepresentable-BigInt message, `Reference not found` and the cyclic-document diagnosis all still propagate unrewritten.

One gate observation was accurate and is corrected here rather than filed: the core-util header and row said the scope grep returns 65 exports of which 41 are named, mixing lines with names. It returns 65 lines over 63 distinct names because `issue` carries three overload signatures, and the battery names 39 of those; the 24 unnamed are unchanged. The gate's other observation - that the classic-schemas-methods battery never names `exactOptional` - is inside the class SCOPE-COVERAGE-1 already owns and predates this run, so it goes to that task rather than becoming a new one.

Verify exits 0 this iteration and `pnpm format:check` and `pnpm lint:check` exit 0. The ledger changed state - one task filed - so this is not a stall, and an EVALUATOR entry is a ceremony entry in any case.

Invocation accounting: the cap is 2 for this run, because the first invocation landed at iteration 6 and the budget midpoint is 5. One invocation remains and it is the last, so a second REJECT would be terminal.

Learnings: enumerate over entry points, not over walks. A walk is reached by every public name bound to it, and a class closed at one name leaves the others open while reading as complete. Remove a settled-class line the moment it is falsified rather than amending it, because the settlement's only effect is to bar future audits from the ground it covers.

Next: iteration 7 closes JSONSCHEMA-METHODS-1 at all four entry points, iteration 8 closes TOJSON-MISATTRIB-1, which the clean audit filed and which touches the same messages, and iteration 9 spends the final invocation and declares on a PASS, leaving iteration 10 in reserve.

## iter 7/10 | 9b564ec0-201434 | 2026-08-16 | JSONSCHEMA-METHODS-1 | done

Task: JSONSCHEMA-METHODS-1 (Low) - the evaluator gate's rejection reason: the JSON Schema conversion was guarded at the free function while every method form reaching the same walkers escaped a bare `RangeError`.

Changed: `packages/zod/src/v4/core/to-json-schema.ts` (new `convertOrTooDeep`, applied at both method factories), `packages/zod/src/v4/core/json-schema-generator.ts` (`process` and `emit` routed through it), `packages/zod/src/v4/core/json-schema-processors.ts` (the iteration 4 inline catch replaced by the shared frame), `packages/zod/src/v4/classic/tests/to-json-schema.test.ts`, `.jeffy/probes/core-to-json-schema/probe.ts`, PLAN.md, BACKLOG.md.

Checkpoint: d32bcf967a660330d3882dbef7e5a29c47bd1971

Verification: The reproduction ran first and reproduced, and running it enumerated the class properly for the first time. Enumerating over public entry points rather than over walks turned up five unguarded names, not the three the gate reported: `schema.toJSONSchema()`, both `~standard` jsonSchema accessors, and `JSONSchemaGenerator.process` and `.emit`, the last two reachable because `core/index.ts` exports the class. The guarded set was the free `toJSONSchema` in all its spellings - classic, `zod/v4/core` and `zod/mini` share one function - on both its schema and registry branches. Mini has no method form and no `~standard.jsonSchema`, checked rather than assumed, so it contributes no entry point.

The fix is one frame, not five guards. `convertOrTooDeep` in `core/to-json-schema.ts` holds the single try/catch and the single message, and every entry point that reaches `process`, `extractDefs` or `finalize` now routes through it, including the free function, whose iteration 4 inline catch is deleted in favour of it. Scattered per-site guards are what produced this finding in the first place, and PLAN.md's own binding rules call for one validation boundary rather than per-site guards.

Executed after the fix: all six conversion entry points report the nesting on a 20000-deep schema, all six are unchanged on a shallow one, and an `override` throwing `RangeError("my own range problem")` still propagates unrewritten through both the free function and the method.

Differential against the pre-fix tree, all three source files swapped back with `git show HEAD:` keyed by full path and restored: the battery reports `[true,true,false,false,false,false]` where it wants six trues, so exactly the two entry points that were already guarded pass and the four new ones fail, and the project test fails on `'Maximum call stack size exceeded'`. Both checks fail on the code they were written for.

Verify command exits 0: 343 files, 3845 tests, no type errors. `pnpm build`, `pnpm format:check`, `pnpm lint:check` and `pnpm check:circular` all exit 0, the last confirming the new `core/util.js` import into `to-json-schema.ts` closes no cycle. Both batteries owning the touched paths pass.

Change discipline: the contract preserved is every emitted document at every entry point - the shallow assertions above compare all six against their previous output and the suite's 3845 tests pass unchanged - and the only observable change is at depths where the previous behaviour was an escaping `RangeError`. `convertOrTooDeep` is a new export on a module the core barrel re-exports, which widens `zod/v4/core` by one internal helper, consistent with `process`, `extractDefs`, `finalize` and `initializeContext` already sitting there. The `core-to-json-schema` row is re-recorded at this checkpoint with its battery extended and green.

Closed: JSONSCHEMA-METHODS-1 (Low) - fixed at all six entry points through one shared frame, evidenced by the enumeration by execution, by six deep and six shallow drives, and by a differential in which precisely the previously-guarded pair passes. The settled class is restored with its enumeration axis corrected to entry points and both failed attempts recorded.

Learnings: when a class is closed at a boundary, the boundary is the set of public names that reach the work, and the cheapest way to enumerate it is to call every one of them rather than to read the call graph. Replacing a per-site guard with a single shared frame made the second attempt smaller than the first: the iteration 4 catch was deleted, not added to.

Next: iteration 8 closes TOJSON-MISATTRIB-1, which the clean audit filed and which is now a single message constant in `convertOrTooDeep`. Iteration 9 spends the final evaluator invocation and declares on a PASS.

## iter 8/10 | 9b564ec0-201434 | 2026-08-16 | TOJSON-MISATTRIB-1 | done

Task: TOJSON-MISATTRIB-1 (Low) - the conversion guard reported every stack exhaustion as the schema being nested too deeply, a cause it had not established.

Changed: `packages/zod/src/v4/core/to-json-schema.ts` (the message in `convertOrTooDeep`), `packages/zod/src/v4/classic/tests/to-json-schema.test.ts`, `.jeffy/probes/core-to-json-schema/probe.ts`, PLAN.md, BACKLOG.md.

Checkpoint: 87a4aca507271ae337784e335d96c0d4656009c5

Verification: The filed reproduction ran first and reproduced: a two-key schema with an `override` that recurses unboundedly, and a genuinely 20000-deep schema, returned byte-identical messages asserting the schema was nested too deeply. One of those two statements was false.

The message now names what ran out and offers both causes without asserting either: "JSON Schema conversion exhausted this runtime's call stack; the schema may be nested too deeply, or an override may recurse". Because iteration 7 collapsed five guards into one frame, this was a single string to change and all six entry points moved together, which is the payoff of that consolidation rather than a coincidence.

The sibling message in `fromJSONSchema` was checked and deliberately left alone. `FromJSONSchemaParams` declares exactly two fields, `defaultTarget` and `registry`, and neither is a callback, so no caller code runs inside that conversion and "input is nested too deeply" is the only cause its guard can be reporting. Changing it to match would have traded an accurate message for a vaguer one.

Differential against the previous message, with `core/to-json-schema.ts` swapped back by full path and restored: the battery reports two failures, the six entry points returning `[false,false,false,false,false,false]` against the new assertion, and the misattribution row returning `[false,true]` where it wants `[true,false]` - it did not say what was exhausted, and it did say the schema was too deep, which is precisely the defect. The project test fails 1 of 162 the same way.

Verify command exits 0: 343 files, 3845 tests, no type errors. `pnpm format:check`, `pnpm lint:check` and `pnpm check:circular` exit 0. The core-to-json-schema battery, which owns the touched path, passes. No documentation page mentions either message, checked by grep over `packages/docs/content`.

Change discipline: the contract preserved is every successful conversion - the suite's 3845 tests pass unchanged and the battery's known-answer documents are untouched - and the only observable change is the text of one error that no test outside this run's own additions asserted on.

Closed: TOJSON-MISATTRIB-1 (Low) - fixed in `convertOrTooDeep`, evidenced by the reproduction of two contradictory-cause cases sharing one message, and by a differential in which the old message fails the new assertion in both directions.

Learnings: consolidating five guards into one frame in the previous iteration turned this fix into a one-line change with no risk of partial application - the cost of a scattered mechanism is paid again every time its behaviour is corrected, not only when it is first written. A message that names a cause is a claim like any other, and it is checkable: provoke the failure by a second cause and read what it says.

Next: iteration 9 spends the final evaluator invocation, the second of two, and declares on a PASS. Three Lows remain carried and none blocks a declaration: OVERFLOW-I18N-1, SCOPE-COVERAGE-1 and DOCS-COVERAGE-1.

## iter 9/10 | 9b564ec0-201434 | 2026-08-16 | EVALUATOR | converged

Task: EVALUATOR gate, invocation 2 of 2, the run's final invocation, run at iteration 9 so a rejection would still have left an iteration. Verdict: PASS. Every closing condition holds, so this iteration declares.

Changed: BACKLOG.md (three gate observations filed, Converged line appended), PLAN.md (Oracle class and Environment fingerprint re-read and their measured counts refreshed), `.jeffy/evaluator/9b564ec0-201434-2.md` written by the evaluator.

Checkpoint: e316d0e1d4f2c3e5d8300789c90abe179a547b33

Verification: Evaluator: PASS - Verify green at 343 files and 3845 tests, all five closed tasks' acceptance checks re-run with their strength differentials reproducing, iteration 7's answer to the first rejection confirmed by enumerating conversion names from the module objects, and all three carried Lows re-scored accurate.

The declaring iteration re-read both Verify command lines, as the closing path requires, and both were re-derived rather than trusted. The exclusion `comm` returns empty against 172 `.test.ts` files, 170 of them under `packages/zod/src`, and the only conditional skips in the tree remain the two `ctx.skip` calls in `packages/resolution/attw.test.ts`. Neither fired: the suite reports no skips, and running that file alone passes 1 test, so the attw snapshot was asserted rather than skipped - the exclusion the fingerprint exists to catch is not present. The Oracle class's measured counts had drifted from 3841 to 3845, accounted for by the two test blocks this run added and their typecheck passes, and the line now carries both measurements with the commit each was taken at. Verify duration measured 12s this iteration, so the recorded range widens to 12-29s and stays far under the hook's 240s floor.

The gate recorded three observations that are not rejection reasons, and none was fixed here. A fix after a PASS invalidates the PASS and spends an invocation the declaration needs, and this run has one invocation and no successor; the observations go to the ledger instead, which is where the next run will meet them. They are CORE-PROCESS-1, the `zod/v4/core` `process` export that still escapes a bare `RangeError` because it is the recursive walk rather than an entry point onto it, and whose task text also carries the narrowing the settled-class sentence needs; FROMJS-BIGINT-1, a BigInt-bearing document reported as possibly cyclic, which predates this run; and PROBE-PATHS-1, two batteries whose `paths` files omit `core/util.ts`. Filing CORE-PROCESS-1 is what keeps the settled class honest in the meantime: an open task naming the exact gap is visible to the next audit in a way an overbroad settled sentence alone would have hidden.

Carried Lows at declaration, each open with its severity on its ledger line: CORE-PROCESS-1, the core `process` export unguarded on a deep schema; FROMJS-BIGINT-1, the BigInt document misdiagnosed as cyclic; OVERFLOW-I18N-1, the one issue message core hardcodes, which bypasses the locale chain; PROBE-PATHS-1, two batteries not declaring a module they depend on; SCOPE-COVERAGE-1, the structural checker for rows asserting battery coverage they lack; DOCS-COVERAGE-1, the structural check for shipped public APIs no page documents.

Verify command exits 0 this iteration: 343 files, 3845 tests, no type errors, 12s. The Surface inventory lists no unswept and no stale row, and no High or Medium task is open anywhere in Now, Next or Later. The only commits since this run's clean audit at iteration 5 are the two fixes for tasks that audit and the gate filed, the gate ceremonies themselves, and state-file bookkeeping.

Learnings: run the gate early enough that its rejection is answerable - this run's first invocation at iteration 6 cost three iterations to answer and still left room, where the previous run spent its first at iteration 7 and died holding reproduced findings it was forbidden to work. A rejection reason and a fix that deletes code are compatible: answering the first REJECT removed the iteration 4 guard rather than adding a fifth.

Next: the run is converged. The six carried Lows and the Proposed items are the next run's opening ledger.
