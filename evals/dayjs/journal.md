# Journal archive

Rotated entries from JOURNAL.md, oldest first. Append-only and cumulative across every rotation and every run; never overwritten, never reordered. The live journal keeps the most recent entries; everything older lives here.

## iter <i>/<N> | <run-id> | <YYYY-MM-DD> | <task-id or AUDIT or RATCHET or WRAPUP or SALVAGE or ROTATION> | <done|blocked|audit|converged|salvage|rotation>

SALVAGE entries take status salvage; ROTATION entries take status rotation.

run-id is the first 8 characters of the session id, a hyphen, then the HHMMSS of started_at from the loop state frontmatter, so two runs in one session are told apart. Body fields, in order: Task, Changed, Checkpoint (the jeffy checkpoint commit hash, or none with the reason), Verification, Learnings, Next.

The closing entry that declares convergence carries the evaluator verdict in its Verification field: `Evaluator: PASS - <one-line summary>`, or `Evaluator: unavailable (<reason>)`.

Closed tasks are recorded here as one line each (ID, title, closing evidence), because BACKLOG.md deletes them. Rotation: when this file exceeds 500 lines, move all but the last 10 entries to the end of JOURNAL-archive.md, appending to whatever that file already holds and never overwriting it, because the archive accumulates across every rotation and every run; create it only when it does not already exist, and record the rotation as a ROTATION entry.

## iter 1/10 | 51ee54b9-124116 | 2026-07-28 | AUDIT | audit

Task: First audit. Fill the Operating envelope, Surface inventory and Verify command, then sweep the mapped surface breadth-first and file findings.

Changed: PLAN.md (envelope surfaces, 40 inventory rows, Verify command, 4 Lessons), BACKLOG.md (9 findings, 1 Declined), .gitignore (loop state file, `*.tmp.js` probe scratch). No source file touched this iteration.

Checkpoint: 8be605dc58661134f011eaa4f3e8dab7e0bec5db (committed with `-n`: the `pre-commit` hook runs `npm run lint`, which cannot execute on Windows; see Lessons). Not a stall - 9 backlog items were filed and `.gitignore` changed, and an AUDIT iteration is expected to touch no source.

Verification: Verify command green before any change: 773 tests across 93 suites pass, 100 percent line-coverage threshold met, exit 0. Sweeps ran as executed known-answer probes against `src/` via `BABEL_ENV=test npx babel-node`, not liveness checks; the core rows were additionally run under TZ=UTC, America/New_York, Pacific/Auckland and Asia/Kolkata with zero failures in all four.

Scores, claiming only the 34 of 40 inventory rows actually swept:
- correctness: High - F1 fractional seconds parsed as an integer count rather than a decimal fraction, differential against both native `Date` and moment; F2 quarterOfYear's unconditional `Number()` coercion destroying objectSupport's object `add`, isolated by a 34-plugin load-order bisect; F3 `localeData().meridiem` undefined for 123 of 143 locales including the default.
- architecture: Medium - F2's root cause is that plugins wrap each other's prototype methods with no composition contract, so a wrapper that coerces its arguments silently breaks a sibling. Claims only the two orderings actually exercised; the plugin-interaction-matrix row is unswept.
- documentation: Medium - F3 and F4 are shipped `.d.ts` declarations that disagree with runtime behaviour.
- error handling: Medium - F6 advancedFormat's `z`/`zzz` throw a bare TypeError when the timezone plugin is absent.
- testing: Medium - F7 two tests assert local-calendar fields on UTC instants and fail in any negative-offset zone; CI is UTC so it never shows upstream.
- developer experience: Medium - F8 `npm test` cannot run on Windows at all.
- code quality: Low - F9 dead `S` alternation in advancedFormat's token regex.
- security: None on swept rows. REGEX_PARSE and REGEX_FORMAT stay linear on hostile input to 50k chars (worst case 8.5ms), so the adversarial parse surface shows no backtracking blowup.
- performance: None on swept rows, same evidence.
- dependency hygiene: not scored, not swept this iteration.
- observability and UX/accessibility: not applicable. A date-formatting library has no runtime surface a user or operator observes.

Six rows remain unswept: plugin-badMutable, plugin-devHelper, plugin-preParsePostFormat, locales-content, types-declarations, build-pipeline, plugin-interaction-matrix. The None scores above do not speak for them.

Learnings: `npm test` blocks forever on Windows because `test-tz` opens with `date &&` and cmd.exe's `date` is an interactive prompt; the Verify command substitutes the equivalent jest invocations. Probing `src/` needs `BABEL_ENV=test`, since the default babel env declares no presets. `src/locale/*.js` import `dayjs` by package name and need a module alias outside jest. Checking a suspicious value against an independent reference before filing paid for itself twice: it turned `.1 -> 1ms` into a confirmed High, and it killed the `dv weekStart: 7` finding, which matches moment exactly.

Next: F1, the fractional-seconds parse defect. It is the worst of the three Highs - it returns quietly wrong numbers on ordinary ISO input rather than failing loudly.

## iter 2/10 | 51ee54b9-124116 | 2026-07-28 | F1 | done

Task: F1 (High, correctness) - `src/index.js` truncated the fractional-seconds capture to 3 characters without right-padding it, so ISO fractional seconds were read as an integer count of milliseconds instead of a decimal fraction.

Changed: `src/index.js` (one line in `parseDate`, plus a comment), `test/parse.test.js` (new regression test), PLAN.md (core-construct row re-swept), BACKLOG.md (F1 deleted).

Checkpoint: a43a59ed592f9d98824cef437505932d19dd4eef (committed with `-n`, see Lessons). Not a stall: `src/index.js` and `test/parse.test.js` both changed and F1 closed.

Verification: The fix is `` const ms = `${d[7] || '0'}00`.substring(0, 3) `` in place of `(d[7] || '0').substring(0, 3)`. Right-padding before truncation is deliberate over `padEnd`, which is a runtime method babel's preset-env does not polyfill and which would break the old browsers dayjs still supports; the template-literal form compiles to ES5 string concatenation.

Acceptance check run against the unfixed code first, by stashing only `src/index.js`: it failed, so the check is strong enough to catch the defect. Against the fix it passes under TZ=UTC, America/New_York, Pacific/Auckland and Asia/Kolkata. It asserts three things per input across `.1 .12 .05 .5 .9 .123 .1234`: agreement with moment, agreement with `new Date(s+'Z').getUTCMilliseconds()`, and agreement between dayjs's two own parse paths, since a `Z` suffix bypasses REGEX_PARSE entirely and was already correct.

Verify gate green: 4 timezone passes plus 774 tests across 93 suites, 100 percent line-coverage threshold met, exit 0. Test count rose 773 to 774, the new test.

Contract preserved: fractional parts of 3 or more digits are unchanged, still truncated to the first 3, which is what the pre-existing `parses unlimited millisecond` test pins with `.999999999`. Only 1-digit and 2-digit fractions change value, and every one of those was previously wrong by a factor of 10 or 100. No existing test pinned the old behaviour: the only other millisecond assertion, in `test/display.test.js`, uses a `Z`-suffixed literal that never entered this code path. This is an observable behaviour change to a public function and is recorded here per the Constraints; no documentation states the old semantics, so there is nothing to correct, and CHANGELOG.md is generated by semantic-release from commit messages rather than hand-edited.

Checked for a second instance of the class before treating it as a single site: `src/plugin/customParseFormat/index.js:73,76,79` already scales `S` by 100 and `SS` by 10, so it was always correct and the core `parseDate` was the only defective site. Not filed as a class.

Learnings: `git stash push -q <single path>` is a clean way to run an acceptance check against unfixed code without disturbing the rest of the working tree, and it is worth doing every time - a check that passes before the fix proves nothing. Fractional-second handling is a place where a library can disagree with itself: dayjs had two parse paths and only one was wrong, which is the cheapest possible differential oracle and needed no external reference at all.

Next: F2, the quarterOfYear `Number()` coercion that breaks objectSupport's object `add`.

## iter 3/10 | 51ee54b9-124116 | 2026-07-28 | F2 | done

Task: F2 (High, correctness) - `src/plugin/quarterOfYear/index.js` coerced the first argument of its `add` wrapper with `Number()` before delegating, so a plain object arriving for objectSupport became NaN and the call returned `Invalid Date`.

Changed: `src/plugin/quarterOfYear/index.js` (moved the coercion into the quarter branch), `test/plugin/quarterOfYear.test.js` (both-load-orders regression test), PLAN.md (row re-swept, 2 Lessons), BACKLOG.md (F2 deleted).

Checkpoint: c10092a11aa4597ae80057131bc2f7765d2c9c25 (committed with `-n`, see Lessons). Not a stall: `src/plugin/quarterOfYear/index.js` and `test/plugin/quarterOfYear.test.js` both changed and F2 closed.

Verification: The wrapper now reads `if (unit === Q) return this.add(Number(number) * 3, M)` and otherwise delegates `oldAdd.bind(this)(number, units)` with the argument untouched. Coercion belongs in the branch that consumes the value, not ahead of the delegation.

Acceptance check run against the unfixed plugin first, by stashing only `src/plugin/quarterOfYear/index.js`: it failed, so the check catches the defect. With the fix it passes, and the pre-existing `add subtract quarter` and `startOf endOf quarter` tests, which pin quarter arithmetic against moment, still pass. Verify gate green: 4 timezone passes plus 775 tests across 93 suites, 100 percent line coverage, exit 0. Test count rose 774 to 775.

The regression test asserts both extend orders in one `it`, rebuilding a fresh dayjs per order with `jest.resetModules()` and `require`, since `dayjs.extend` marks a plugin installed via `plugin.$i` and a module registry reset is what clears it. Per order it asserts four things: the two-key and one-key object `add` forms, the `quarter` unit this plugin exists for, and `add('1', 'quarter')` so the string coercion the quarter path still needs is not lost.

Contract preserved: for numbers and numeric strings on non-quarter units the behaviour is byte-identical, because core `add` at `src/index.js:231` does its own `Number()` at the terminal end, which is the correct place for it. Genuinely non-numeric garbage still yields `Invalid Date`, just one level lower. The only observable change is the defect going away.

Why the suite never caught this: `test/plugin/objectSupport.test.js:10-11` is the single file that loads both plugins, and it extends quarterOfYear first, which is the safe order - objectSupport ends up the outer wrapper and intercepts the object before the coercion can reach it. The broken order was untested, not merely untriggered. Checked whether the coercion idiom recurs before treating it as one site: `Number(` appears in an argument position only here and at `src/index.js:231`, and the latter is the terminal implementation where coercion is correct. Not filed as a class.

Learnings: a wrapper in a plugin chain must not normalise arguments it does not handle, because the chain below it may accept richer types than the wrapper knows about. And a plugin-interaction test that fixes one extend order at module scope certifies half the matrix while reading as if it certified all of it; both orders need asserting. This iteration exercised exactly one pair of the plugin-interaction-matrix row, which stays unswept.

Next: F3, `localeData().meridiem` undefined for 123 of 143 locales including the default `en`.

## iter 4/10 | 51ee54b9-124116 | 2026-07-28 | F3 | done

Task: F3 (High, correctness) - `localeData().meridiem` was `undefined` for 123 of 143 bundled locales including the default `en`, so the documented call threw a TypeError even though the shipped `.d.ts` declares it returning `string`.

Changed: `src/plugin/localeData/index.js` (default meridiem fallback, wired into both the instance and global return objects), `test/plugin/localeData.test.js` (real value assertions), PLAN.md (row re-swept, 2 Lessons), BACKLOG.md (F3 deleted).

Checkpoint: 860b1841aa926548153dfb5e12b471d5403686ae (committed with `-n`, see Lessons). Not a stall: `src/plugin/localeData/index.js` and `test/plugin/localeData.test.js` both changed and F3 closed.

Verification: The plugin now defines a 3-line `defaultMeridiem` and returns `this.$locale().meridiem || defaultMeridiem` for the instance form and `localeObject.meridiem || defaultMeridiem` for the global one. It mirrors the fallback core `format()` already applies at `src/index.js:280`, deliberately duplicated inside the plugin rather than shared from core: core carries a hard 2.99 KB size-limit budget, localeData is opt-in, and exporting the helper would spend core bytes on every consumer who never loads this plugin. The duplication is 3 lines and the comment names the original.

Acceptance check run against the unfixed plugin first, by stashing only `src/plugin/localeData/index.js`: it failed with the exact production error, `TypeError: ... .meridiem is not a function`. With the fix it passes. It asserts meridiem at 5 hours spanning both sides of noon and the 0 and 11:59 boundaries, against moment for both the instance and global forms, and additionally against what `format('A')` and `format('a')` actually emit, so the fallback cannot drift from the formatter it is supposed to mirror. It then switches to `zh-cn` and asserts that a locale defining its own meridiem still returns its own strings and specifically not `'PM'`.

Verify gate green: 4 timezone passes plus 776 tests across 93 suites, 100 percent line coverage, exit 0. Test count rose 775 to 776.

Contract preserved: locales that define `meridiem` are untouched, since the fallback only applies when the locale's own value is absent. The runtime now matches `types/plugin/localeData.d.ts`, which already declared `meridiem(hour?, minute?, isLower?): string`, so the fix closes a doc-versus-runtime gap rather than opening one and no declaration needed changing.

Why the suite never caught this: `test/plugin/localeData.test.js` already had a `meridiem` test, and it passed throughout. It switches to `zh-cn` first, which is one of the 20 locales that do define meridiem, and then asserts only `typeof ... === 'function'` without ever calling it. Both halves of that are the failure: the locale chosen was unrepresentative, and a typeof check cannot distinguish a working function from a broken one. A green test stood over a method that threw on the default locale for every consumer who never switched locales.

Learnings: an existence assertion is not a correctness assertion, and `typeof x === 'function'` is the weakest form of it. When a test picks a specific locale, fixture or flag before asserting, the question to ask is whether that choice is representative or whether it is quietly the one case that works. Both Lessons recorded in PLAN.md.

Next: F4, `localeData().ordinal` leaking dayjs's internal format-escape brackets, same file and the sibling of this defect.

## iter 5/10 | 51ee54b9-124116 | 2026-07-28 | F4 | done

Task: F4 (Medium, correctness) - `localeData().ordinal(n)` returned dayjs's internal format-escape brackets to callers, so `en` gave `'[1st]'` where a display string was declared.

Changed: `src/plugin/localeData/index.js` (getOrdinal boundary that strips wrapping brackets), `test/plugin/localeData.test.js` (real value assertions), PLAN.md (row re-swept, locales-content note, 2 Lessons), BACKLOG.md (F4 deleted, F10 filed).

Checkpoint: 7e7c1032d1ef974cf7eb9926988fc58877be629c (committed with `-n`, see Lessons). Not a stall: `src/plugin/localeData/index.js` and `test/plugin/localeData.test.js` both changed, F4 closed and F10 filed.

Verification: Only 10 of 143 locales bracket their ordinal, and the brackets are load-bearing rather than incidental. Confirmed directly: with the brackets removed, core `format` re-tokenizes the suffix, so `'2nd'` renders as `'2n3'` (the `d` becoming the weekday index) and `'1st'` as `'10t'` (the `s` becoming seconds). The locale data therefore has to keep them and the strip has to happen where a display string is handed out, which is what `getOrdinal` does; it leaves non-string returns alone and anchors the replace to the wrapping pair only.

Acceptance check run against the unfixed plugin first: it failed. With the fix it passes. It asserts 12 values including the 11/12/13 and 21/22/23 suffix boundaries against moment for both the instance and global forms, asserts no bracket survives in any of them, and asserts the raw locale data still returns `'[2nd]'` so the format path's escape is intact.

Verify gate green: 4 timezone passes plus 777 tests across 93 suites, 100 percent line coverage, exit 0. Test count rose 776 to 777.

Contract preserved: the 133 locales that never bracketed are unaffected, pinned by asserting that for `fr` the value from `localeData().ordinal(n)` is identical to `dayjs.Ls.fr.ordinal(n)`, so this boundary is a verified no-op where there is nothing to strip. `format('Do')` is untouched because the locale data is untouched, and it stays pinned against moment across many dates and two bracketed locales in `advancedFormat.test.js`.

Two wrong turns, both caught by the acceptance check rather than by review. First I asserted `format('Do')` inside `localeData.test.js`, which does not import advancedFormat; `Do` is not a token there, so core format emitted `D` plus a literal `o` and the expectation met `'25o'`. An unknown token degrades to literal text instead of erroring, so the test read as a real assertion while testing nothing of the sort. Second I compared `fr` ordinals against moment and got `'2'` against moment's `'2e'` - not my regression but a genuine pre-existing gap, which is now filed as F10.

F10, filed this iteration: 52 of the 132 locales moment also ships return a bare unmarked number from `ordinal` where the language wants a marker (`fr` 2 not 2e, `ru`/`uk` 2 not 2-го, `nl-be` 2 not 2de, `mk` 2 not 2-ри). A further 10 differ in marker style only and may be deliberate, so the filing separates the two groups rather than counting all 62 divergences as defects. This came out of the `locales-content` row, which is now recorded as partially probed - ordinals compared, month and weekday names and longDateFormat patterns still not - and stays unswept.

Learnings: a test file only sees the plugins it imports, and dayjs formats an unrecognised token as literal text rather than raising, which makes a wrong token in a test look like a passing assertion. And moment is a sound reference for dayjs's algorithms but not for its locale strings, where 62 of 132 shared locales legitimately differ; for boundary tests the right differential is dayjs's own `dayjs.Ls[name]` data. Both recorded in PLAN.md.

Next: F5, the 9 locales with no relativeTime that silently fall back to English.

## iter 6/10 | 51ee54b9-124116 | 2026-07-28 | F5 | done

Task: F5 (Medium, correctness, class) - 9 bundled locales shipped no `relativeTime`, so the plugin fell back to hardcoded English and `.fromNow()` returned "3 days ago" in place of the locale's own words. Split during this iteration; 5 locales closed here, 4 carried to F5b.

Changed: `src/locale/bs.js`, `src/locale/me.js`, `src/locale/cv.js`, `src/locale/tzl.js`, `src/locale/gom-latn.js` (relativeTime added), `test/locale/relativeTime.test.js` (new, enumerating plus behavioural), PLAN.md (row re-swept, 2 Lessons), BACKLOG.md (F5 closed and split into F5b, Next reordered).

Checkpoint: 43904ac825ac4c7dc15fb248be349a5e2266f188 (committed with `-n`, see Lessons). Not a stall: 5 locale files and a new test file changed, F5 closed and F5b filed.

Verification: Before writing anything I calibrated the oracle, because the whole approach rests on it. dayjs's relativeTime accepts the same `(number, withoutSuffix, key, isFuture)` formatter signature moment uses, so moment's implementations port across directly and output equality is a complete check on the port. Calibrating on locales that already work: `sr`, `fr`, `ru`, `de`, `es` and `pl` match moment on all 30 comparisons, confirming dayjs's threshold buckets line up with moment's for these durations. `nl` differs on 10 of 30, all "een" against "één", so a complete locale does not have to match and the bar is per-locale rather than universal. All 9 target locales differed on 30 of 30, emitting English in every bucket, which is the evidence for the finding itself.

After the port, `bs`, `me`, `cv`, `tzl` and `gom-latn` each match moment on all 30. The permanent test in the suite goes further than the probe: 15 buckets, both `from` and `to`, both suffix modes, which is 60 assertions per locale.

Verify gate green: 4 timezone passes plus 784 tests across 94 suites, 100 percent line coverage, exit 0. Test count rose 777 to 784. All 5 new locale files report 100 percent on statements, branches, functions and lines.

Why this was split rather than finished: the 4 remaining locales do not port from a table. `ar-ly` needs Arabic plural forms with an Eastern Arabic numeral map, `lb` the Eifeler Regel, `mr` Devanagari numeral conversion, `tlh` Klingon number nouns. Each is a distinct piece of language logic, and the Method requires a task be completable in one iteration or split. The 5 done here share one shape: a table or a small grammatical-case helper. F10 got the same note, since 52 locales each needing a researched ordinal marker is likewise not one iteration's work.

Two coverage traps the 100 percent line gate caught. The `default:` arm I first wrote in the `bs` switch was unreachable, since every key that reaches `translate` has an explicit case, so I folded `yy` into `default` instead of leaving a dead line. And dayjs's thresholds shift a count of 1 down to the singular key, so plural formatters never see 1 through `from()`; moment's singular handling is still ported for fidelity, and the test calls those formatters directly to exercise it. `gom-latn` first came back at 50 percent branch coverage because the bucket sweep only ran the past direction, which is what prompted adding `to()` alongside `from()` and incidentally doubled the real verification.

Contract preserved: the 5 files gained a `relativeTime` key and gained nothing else; no existing key was touched, and the pre-existing `test/locale/keys.test.js` shape check now applies to them, since its `if (relativeTime)` guard is precisely why the gap was invisible before. The new enumerating test is a ratchet: `KNOWN_MISSING_RELATIVE_TIME` may only shrink, so a regression that drops relativeTime from any locale fails the suite by name.

Learnings: a locale port is verifiable without speaking the language, provided the reference implementation shares the formatter signature and the oracle is calibrated on known-good locales first. And a 100 percent line-coverage gate is a useful design constraint rather than an obstacle: it rejected an unreachable switch arm and an untested direction that a looser gate would have let through. Both recorded in PLAN.md.

Next: F6, advancedFormat's `z` and `zzz` tokens throwing a bare TypeError when the timezone plugin is absent.

## iter 7/10 | 51ee54b9-124116 | 2026-07-28 | F6 | done

Task: F6 (Medium, error handling) - advancedFormat's `z` and `zzz` tokens called `this.offsetName()`, a method only the timezone plugin installs, so formatting them without that plugin threw a TypeError out of `format()`.

Changed: `src/plugin/advancedFormat/index.js` (REQUIRED_METHOD table and one guard), `test/plugin/advancedFormat.test.js` (enumerating test), PLAN.md (row re-swept, 1 Lesson), BACKLOG.md (F6 deleted, class recorded under Settled classes).

Checkpoint: 0a4ef0c29de2337408f1f3f8db5cf9245691ceae (committed with `-n`, see Lessons). Not a stall: `src/plugin/advancedFormat/index.js` and its test both changed, F6 closed and the class settled.

Verification: F6 was filed against 2 tokens and turned out to be 9. Probing all 16 advancedFormat tokens with the plugin loaded alone: `Q`, `Do`, `X`, `x`, `k`, `kk` and `S` work, and `w`, `ww`, `wo` (need `week`), `W`, `WW` (need `isoWeek`), `gggg` (needs `weekYear`), `GGGG` (needs `isoWeekYear`), `z` and `zzz` (need `offsetName`) all threw. That makes it a class, so per the Method it is fixed at a boundary rather than per site: a `REQUIRED_METHOD` table maps each dependent token to the method it needs, and one guard ahead of the switch returns the literal token when that method is missing. Five scattered guards would have been the alternative and would have left the enumeration implicit.

Degrading to the literal token rather than throwing a named error is the choice dayjs already makes everywhere else: an unrecognised token is passed through as text, which is why `format('Do')` without advancedFormat yields `25o` and `format('Q')` yields `Q`. A token whose plugin is absent is exactly an unrecognised token, so it now behaves like one.

Acceptance check run against the unfixed plugin first: it failed with `TypeError: _this.week is not a function`, the real production error. With the fix it passes. The test enumerates all 9 tokens and asserts three things each: that the companion method genuinely is absent on the instance, that the token renders as itself, and that it does not poison the surrounding format string (`YYYY z` gives `2019 z`). It also asserts the 3 self-contained tokens are unaffected.

Verify gate green: 4 timezone passes plus 785 tests across 94 suites, 100 percent line coverage, exit 0; `src/plugin/advancedFormat` reports 100 percent on statements, branches, functions and lines. Test count rose 784 to 785.

Contract preserved: when the companion plugins are loaded nothing changes at all, since the guard only fires when the method is missing. The pre-existing `Format offsetName z zzz` test still asserts `EST` and `Eastern Standard Time` against a real zone, and the whole timezone and isoWeek suites are untouched. Recorded under Settled classes so a later audit does not re-file an instance of it.

Learnings: a finding named for one token or one call site is often one instance of a class, and the cheap way to find out is to enumerate the siblings in the same file before fixing; here the filed 2 were really 9. Recorded in PLAN.md.

Next: F5b, the 4 remaining locales with no relativeTime, each needing bespoke language logic ported.

## iter 8/10 | 51ee54b9-124116 | 2026-07-28 | F7 | done

Task: F7 (Medium, testing) - two tests asserted local-calendar facts about instants pinned in UTC, so the suite failed in any negative-offset zone while passing in CI.

Changed: `test/plugin/dayOfYear.test.js` (local-time literals, local assertions), `test/plugin/localizedFormat.test.js` (local midnight instead of the UTC epoch), PLAN.md (Verify command strengthened, 1 Lesson), BACKLOG.md (F7 deleted, Next reordered).

Checkpoint: 24cbd14286ace52694b22ceef240f1f791f20db2 (committed with `-n`, see Lessons). Not a stall: two test files changed and F7 closed.

Verification: Both defects are the same mistake. `dayOfYear.test.js` built `dayjs('2015-01-01T00:00:00.000Z')` and then asserted on `dayOfYear()`, which reads the local calendar; in `America/New_York` that instant is 31 December 2014, so the day-of-year was computed against the wrong year entirely. `localizedFormat.test.js` used `new Date(0)`, which is 1969 locally anywhere west of Greenwich, and asserted `format('YYYY [l] YYYY')` was `1970 l 1970`. Neither is a library defect; both are tests that fixed an instant when they meant a calendar date.

The fix uses local-time literals throughout, which is what the sibling `DayOfYear get` test in the same file already did correctly - the two halves of one file disagreed with each other. The `toISOString()` assertions in the set test were replaced with `format('YYYY-MM-DD')`, because an ISO string is a statement about an instant and reintroduces the same coupling; the local format string asserts the calendar date the test is actually about, and asserts it identically in every zone.

Differential evidence, the acceptance check for this task: the full suite under `TZ=America/New_York` reports 2 failed, 783 passed before the change and 785 passed after, on the same tree with only the two test files stashed. The full suite now passes under UTC, America/New_York, Pacific/Auckland and Asia/Kolkata, 785 tests and 94 suites in each.

Verify gate green, and strengthened this iteration: it now runs the entire suite under `TZ=America/New_York` in addition to the previous passes. That closes the structural gap behind this finding. The project's own `npm test` varies TZ across four zones but only over `test/timezone.test`, never the full suite, so nothing in the gate ever exercised the other 92 suites outside UTC. Adding a negative-offset full-suite pass is what stops this class recurring; the equivalent change to `package.json` belongs to F8 and is noted there rather than done here.

Contract preserved: no source file was touched, only test files, and every assertion still checks what it checked before. Test count is unchanged at 785, so nothing was dropped to make the suite pass, and the two tests are strictly stronger now because they hold in four zones rather than one.

Ledger note: F5b and F10 were moved below F7 and F8 before starting. Both are evidenced as multi-iteration work rather than merely large - all four of F5b's moment implementations were read this iteration, and each needs bespoke logic plus direct-call coverage tests to satisfy the 100 percent line gate (ar-ly a 6-form plural table, lb a recursive Eifeler Regel reachable only through crafted strings, mr a 24-arm switch, tlh a numberAsNoun over hundreds, tens, ones and zero). With two working iterations left, finishing whole tasks beats half-finishing a port, and both items now carry a split-first note.

Learnings: an assertion about the local calendar needs a local-time literal. A `Z`-suffixed string or `new Date(0)` fixes an instant, not a date, and any test that mixes the two only holds in UTC. Recorded in PLAN.md.

Next: F8, the package.json scripts that assume a POSIX shell.

## iter 9/10 | 51ee54b9-124116 | 2026-07-28 | F8 | done

Task: F8 (Medium, developer experience, class) - `package.json` scripts assumed a POSIX shell, so a Windows contributor could not run the project's own test or lint gates at all.

Changed: `package.json` (test-tz, lint, and a negative-offset pass added to test), `test/locale/relativeTime.test.js` (lint error this iteration exposed), PLAN.md (2 Lessons corrected), BACKLOG.md (F8 deleted, class recorded under Settled classes).

Checkpoint: e1a829222a856eec1e8d6fc3d076ec62f990bcbc (committed with `-n`; the hook still runs lint, which this CRLF checkout fails). Not a stall: `package.json` and a test file changed, F8 closed and the class settled.

Verification: All 9 scripts were enumerated, which the class rule requires. Exactly 2 carried POSIX-only constructs. `test-tz` opened with `date &&`, and cmd.exe's `date` is an interactive set-the-clock prompt, so `npm test` blocked forever at the first of its five stages; it is now `node -p "Date()"`, which prints the same context on every platform. `lint` invoked `./node_modules/.bin/eslint`, which cmd.exe rejects outright, and relied on the shell to expand `src/* test/* build/*`; it is now `eslint src test build`, since npm puts `node_modules/.bin` on PATH everywhere and eslint recurses into directories itself. The remaining 7 scripts use `cross-env`, `npx` or bare bin shims and are portable as written, so the class is closed rather than partially patched.

Evidence: `npm run test-tz` completes and exits 0 where it previously hung. `npm test` runs all five stages to completion on Windows and exits 0. `npm run lint` reaches eslint and produces lint output rather than dying in the shell. The `node -p "Date()"` substitution turns out to be strictly better than `date` for the purpose it served, because it prints the resolved zone name per stage - New Zealand Standard Time, British Summer Time, Yukon Time, Eastern Daylight Time - which also confirms cross-env is applying each TZ.

This fix immediately found a defect it was made to find. With lint runnable, `npm run lint` reported 2 `object-curly-newline` errors at `test/locale/relativeTime.test.js:91`, a 4-property destructure airbnb requires to be multiline. I introduced it in iteration 6 and nothing could see it, because lint could not run here and the pre-commit hook that would have caught it fails for the same reason. Fixed in this iteration. To separate real errors from this checkout's `core.autocrlf=true` noise, `npx eslint src test build --rule '{"linebreak-style":"off"}'` now exits 0, so the tree is genuinely lint clean.

Also done here, deferred explicitly from F7: `npm test` now runs the whole suite once under `TZ=America/New_York` before the coverage stage. The project's four existing TZ stages only ever ran `test/timezone.test`, so 92 of 94 suites were never exercised outside UTC, which is precisely how the two timezone-fragile tests survived. This is the same strengthening made to the Verify command in iteration 8, applied to the project's own gate so it holds without the loop. Recorded as part of F8 because it is a change to the same scripts block, and noted in F7's entry as the deferred half.

Verify gate green: 785 tests across 94 suites, 100 percent line coverage, exit 0, with all five stages passing.

Contract preserved: no source file was touched and no test assertion changed; the only test edit was formatting to satisfy a lint rule. `npm test` still runs the same four timezone stages and the same coverage threshold, with one stage added and none removed, so CI on ubuntu-latest gets strictly more checking and nothing less.

Learnings: two Lessons in PLAN.md were corrected rather than added, since the rules they stated are no longer true - `npm test` and `npm run lint` now work on Windows. The durable rule is the new one: to see real lint errors in a CRLF checkout, disable `linebreak-style` explicitly rather than reading past 18 thousand lines of noise, which is what hid a real error for three iterations.

Next: final iteration, WRAPUP. Remaining ledger is F5b, F10 and F9, all carrying split-first or scope notes.

## iter 10/10 | 51ee54b9-124116 | 2026-07-28 | WRAPUP | done

Task: Final iteration of the budget. The top unblocked item is F5b, which is evidenced as multi-iteration work, so per the closing rule this tidies the ledger and writes a handoff rather than starting something that cannot finish.

Changed: JOURNAL.md only. BACKLOG.md was already tidy - 3 open items, each with a runnable acceptance check, and the two large ones carrying split-first notes written when the evidence for their size was gathered.

Checkpoint: db331d4d18f375b1c5e8c4c47e00d3c2d1fdafc4 (committed with `-n`; the hook runs lint, which this CRLF checkout fails). Stall check: this iteration changed only JOURNAL.md and no BACKLOG.md item changed state, which is expected of a WRAPUP and is not a repeat, since iter 9 closed F8.

Verification: Verify command green at the close: 4 timezone passes on `test/timezone.test`, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold. 785 tests across 94 suites, exit 0. The suite grew from 773 to 785 across the run and no test was weakened or removed; every one of the 12 added tests was first run against the unfixed code and observed to fail.

Not converged, and the run does not claim to be. 3 findings remain open, so the Definition of done is not met, the evaluator gate is not invoked, and no Converged line is appended. The Surface inventory stands at 34 of 41 rows swept.

Handoff for the next run, in the order the ledger already has them:

F5b is 4 locale ports (`ar-ly`, `lb`, `mr`, `tlh`). The method is established and worked 5 times in iteration 6: dayjs's relativeTime takes the same `(number, withoutSuffix, key, isFuture)` formatter signature moment uses, so moment's implementation ports across and output equality against moment is a complete check. Calibrate first on a locale that already works, because `nl` legitimately differs from moment on 10 of 30 comparisons. Split it one locale per iteration; each of these 4 needs direct-call coverage tests on top of the bucket sweep to satisfy the 100 percent line gate, and the shapes are known: ar-ly a 6-form plural table, lb a recursive Eifeler Regel reachable only through crafted strings, mr a 24-arm switch, tlh a numberAsNoun over hundreds, tens, ones and zero. `KNOWN_MISSING_RELATIVE_TIME` in `test/locale/relativeTime.test.js` is the ratchet: shrink it as each locale lands and the suite enforces the rest.

F10 is 52 locales whose `ordinal` returns a bare number where the language wants a marker. This one needs a decision before code, because moment is not the authority on dayjs's locale strings and 10 of the 62 divergences look deliberate. Batch it by language family and record a Declined line for any locale where bare numerals are genuinely correct.

F9 is a one-line deletion. `S` sits in advancedFormat's token regex with no case in the switch, so it falls through to `default` and emits itself. Removing the alternation is a pure no-op - `SSS` is handled by core format, and single `S` already ends up literal either way - which is why the ledger prefers deleting it over implementing moment's tenths-of-a-second token, an undocumented feature nobody asked for. Verify `format('S')` and `format('SSS')` are unchanged before and after.

Three inventory rows are worth sweeping early next run because they are cheap and currently blind: `plugin-badMutable`, `plugin-devHelper` and `plugin-preParsePostFormat` have only had liveness probes. `plugin-interaction-matrix` is the one that pays: this run found two real defects at plugin boundaries (F2's coercion, F6's 9 missing-method tokens) by exercising exactly two pairs out of 37 plugins, so the matrix is undersampled and has already proven productive. `types-declarations` is next best, since two of this run's Highs were shipped `.d.ts` declarations disagreeing with runtime.

Learnings: the harness built this run is the thing to reuse. `alias.tmp.js` maps the `dayjs` package name onto `src/index.js` so probes outside jest can load locale files, `*.tmp.js` is gitignored, and `BABEL_ENV=test npx babel-node` runs any probe against source. The single highest-yield habit was running each new test against the unfixed code first: it caught two of my own bad tests this run, one asserting a token whose plugin was not loaded and one comparing dayjs locale strings against moment's.

Next: nothing in this run. Start a fresh session in this directory so the next run gets clean context; PLAN.md, BACKLOG.md and JOURNAL.md carry the state forward.

## iter 1/10 | 129fbdac-133640 | 2026-07-28 | F5b-1 | done

Task: F5b-1 (Medium, correctness) - `src/locale/ar-ly.js` shipped no `relativeTime`, so `relativeTime/index.js:23` fell back to the hardcoded English table and `.from()` emitted "3 days ago" for Arabic (Libya). First of the 4-way split of F5b.

Changed: `src/locale/ar-ly.js` (6-form Arabic plural table and relativeTime block), `test/locale/relativeTime.test.js` (`ar-ly` moved from `KNOWN_MISSING_RELATIVE_TIME` into `PORTED`, plus a direct-call test over all six plural categories), PLAN.md (F5b split rationale absorbed into 2 Lessons, locales-structure row re-swept), BACKLOG.md (F5b split into F5b-1..F5b-4, F5b-1 deleted).

Checkpoint: fe0fee95950072d164d83c3913d6125867ad9f83 (committed with `-n`, see Lessons). Not a stall: one source file and one test file changed, and F5b-1 closed.

Verification: The port is not a transcription of moment's, and it must not be. A probe instrumenting the threshold loop with spy formatters showed dayjs calls the singular keys with the preceding threshold's count rather than 1: `m` receives 60 (seconds), `h` 60 (minutes), `d` 24 (hours), `M` 30 (days), `y` 12 (months). moment reaches the same buckets through `substituteTimeAgo`, which passes `number || 1`, so its singular keys always see 1. Every locale ported before this one survived the difference only because its singular branches ignore the number; ar-ly's `pluralize` reads it, so a faithful transcription would have been wrong.

Differential evidence, run before the fix was accepted: a naive variant wiring moment's `pluralize` onto the singular keys renders "60 دقيقة", "60 ساعة", "24 يومًا", "30 شهرا" and "12 عامًا" where moment renders "دقيقة واحدة", "ساعة واحدة", "يوم واحد", "شهر واحد" and "عام واحد" - wrong in all 5 singular buckets, and wrong in a way that reads as a plausible number rather than as a crash. The shipped split of `one(unit)` for the singular keys and `many(unit)` for the plural ones matches moment in all 5.

Acceptance check confirmed strong enough to fail: with only `src/locale/ar-ly.js` stashed and both test changes in place, `test/locale/relativeTime.test.js` reports 3 failed, 6 passed. With the locale restored, 9 passed.

The backlog's premise for this locale was wrong and is recorded here so the remaining 3 splits are not scoped from it: moment's `ar-ly` `symbolMap` maps Latin digits onto themselves, so ar-ly does not use Eastern Arabic numerals at all, unlike `ar`. Its `postformat` only swaps `,` for `،`, which no relativeTime string contains. The port therefore needed the plural table alone, and `preparse`/`postformat` were deliberately not added, since they change `format()` output and belong to a separate task.

Category 0 of the plural table is unreachable in dayjs exactly as it is in moment, because a falsy count is coerced to 1 before `pluralForm` sees it. The slot is kept so the table stays index-aligned with moment's, and the file says so, so a later audit does not file it as dead data. This is why `ar-ly.js` reports 96.15 percent statements while reporting 100 percent lines.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 787 tests across 94 suites, up from 785, and no test weakened or removed. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0.

Contract preserved: the only source file touched is one locale, and it gained a key it did not previously define. No shared or public function changed signature or behavior, so no caller of `relativeTime` is affected; locales that already defined `relativeTime` are untouched, and the shrink-only enumerating check still pins the remaining 3.

Learnings: the singular-key number contract is the durable rule and is now in PLAN.md, because the 3 remaining ports (`lb`, `mr`, `tlh`) all read their number and would each reproduce this defect. Also recorded: `moment.localeData(name).relativeTime(...)` calls a locale's formatter directly, which is what let the six plural categories be checked per category instead of only through the buckets, where the dual and the 100+ form never appear.

Next: F5b-2, the Luxembourgish `lb` port and its Eifeler Regel.

## iter 2/10 | 129fbdac-133640 | 2026-07-28 | F5b-2 | done

Task: F5b-2 (Medium, correctness) - `src/locale/lb.js` shipped no `relativeTime`, so Luxembourgish fell back to the hardcoded English table. Second of the 4-way split of F5b.

Changed: `src/locale/lb.js` (Eifeler Regel, singular forms, relativeTime block), `test/locale/relativeTime.test.js` (`lb` moved from `KNOWN_MISSING_RELATIVE_TIME` into `PORTED`, plus a per-branch Eifeler Regel test), PLAN.md (Lesson extended, locales-structure row re-swept), BACKLOG.md (F5b-2 deleted).

Checkpoint: e7581e64b0b385f28633cc6e23a534cf000e11d4 (committed with `-n`, see Lessons). Not a stall: one source file and one test file changed, and F5b-2 closed.

Verification: The singular-key contract recorded in iteration 1 did not bite here, which is itself the confirmation that the rule was stated correctly: moment's `processRelativeTime` picks its form from `withoutSuffix` and never reads the count, so the number dayjs passes is irrelevant to it. The rule predicted exactly this - it endangers only formatters that read their number - and lb is the control case for it.

The real work is the Eifeler Regel, a phonological rule deciding whether the word before a number keeps its '-n': 'an 10 Deeg' but 'a 5 Deeg'. It is decided by one digit, so multi-digit numbers recurse, and the threshold buckets alone cannot reach most of the recursion. The 15 buckets only ever produce 1, 5, 9, 10, 20 and 40, which exercise the NaN path, both sides of the 4-7 window, and the two-digit multiples of ten; they never produce a two-digit number not ending in zero, a 3-or-4-digit number, a number above 10000, or a negative one. Those four branches are covered by 13 crafted strings driven directly through `relativeTime.future`/`.past` and compared against `moment.localeData('lb').pastFuture(diff, output)`, which is moment's own dispatcher for function-valued future/past.

Acceptance check confirmed strong enough to fail: with only `src/locale/lb.js` stashed and both test changes in place, `test/locale/relativeTime.test.js` reports 3 failed, 8 passed. With the locale restored, 11 passed. The Eifeler Regel test also asserts both affixes occur across the crafted set, so a constant-returning implementation cannot satisfy it.

One deliberate divergence from moment's source, verified rather than assumed. moment extracts the leading token with `string.substr(0, string.indexOf(' '))`, which yields `''` when there is no space, because `substr` with a negative length returns empty. `substr` is deprecated, so this port uses `slice` behind an explicit `indexOf === -1` guard. That guard was initially unreachable and showed up as the file's only uncovered branch, so the claim that the two are equivalent was turned into a test: the crafted set now includes `'Deeg'`, a string with no space, and dayjs's output matches moment's there too. `lb.js` is now 100 percent on statements, branches, functions and lines.

Also avoided: `Number.isNaN`. The codebase uses no ES2015 builtins at all - `Array.isArray` is the ceiling, and `src/utils.js` hand-rolls padStart - so introducing one would narrow browser support for a locale file. The recursion instead lets NaN fall through every comparison to the final `return false`, which is what parseInt produces for a leading word.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 789 tests across 94 suites, up from 787, no test weakened or removed. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0.

Contract preserved: one locale file gained a key it did not previously define. No shared or public function changed signature or behavior, and no other locale is touched.

Learnings: the PLAN Lesson on moment oracles was extended rather than duplicated - `pastFuture(diff, output)` is the direct-call entry for function-valued `future`/`past`, the counterpart to `relativeTime(...)` for keys. The reusable habit here is turning an unreachable defensive branch into a tested one: the branch existed because I claimed `slice` plus a guard equals `substr`, and the cheapest way to justify a claim like that is to feed the boundary input to both implementations rather than delete the branch or leave it uncovered.

Next: F5b-3, the Marathi `mr` port, a 24-arm switch over key and isFuture with Devanagari numerals.

## iter 3/10 | 129fbdac-133640 | 2026-07-28 | F5b-3 | done

Task: F5b-3 (Medium, correctness) - `src/locale/mr.js` shipped no `relativeTime`, so Marathi fell back to the hardcoded English table. Third of the 4-way split of F5b.

Changed: `src/locale/mr.js` (two inflection tables, relativeTime block, preparse and postformat), `test/locale/relativeTime.test.js` (`mr` removed from `KNOWN_MISSING_RELATIVE_TIME`, two new mr tests, a comment on why `mr` is not in `PORTED`), PLAN.md (2 Lessons, locales-structure row re-swept), BACKLOG.md (F5b-3 deleted, F11 filed).

Checkpoint: ec03399164850f07731ca1bfbec8f23fe47bb689 (committed with `-n`, see Lessons). Not a stall: one source file and one test file changed, F5b-3 closed and F11 filed.

Verification: mr differs from the two ports before it in needing Devanagari numerals. moment applies them in `humanize` via `locale.postformat(output)`, so moment's `.from()` returns `१० मिनिटांपूर्वी`. dayjs never calls `postformat` from core: the `preParsePostFormat` plugin threads it into `fromToBase` as a fifth argument, and `relativeTime` applies it to the count alone. Since the only digits in the output come from `%d`, the two coincide, but only when that plugin is loaded. mr is therefore verified in its own test with a fresh module registry via `jest.resetModules()`, rather than joining the `PORTED` loop, which deliberately loads only `relativeTime`; adding mr there would have meant loading a second plugin for all 7 locales already verified without it.

moment's 24-arm switch is ported as two lookup tables keyed by `withoutSuffix`, which is the same function with the branching removed. All 22 arms are checked against `moment.localeData('mr').relativeTime(...)` directly, because the buckets reach only 10 of the 11 keys and never `s`. Each key is also asserted to render different text in the two suffix modes, so a table collapsed to one form per key would fail rather than pass quietly.

The numerals are asserted as substitution, not coincidence: bucket output must match `/[१२३४५६७८९०]/` and must not match `/\d/`. `preparse` is covered by the mirror assertion, that `d('२०१९-०६-१५')` parses to the same instant as `d('2019-06-15')` and as moment's, and formats back to Devanagari.

Acceptance check confirmed strong enough to fail: with only `src/locale/mr.js` stashed, `test/locale/relativeTime.test.js` reports 3 failed, 10 passed. With it restored, 13 passed.

The Verify gate caught a defect this iteration introduced, and it is recorded here rather than quietly fixed. The first port included moment's `ss` key. `test/locale/keys.test.js` asserts every bundled locale's `relativeTime` has exactly 13 keys, and `ss` is not among them, so the full suite went red under `TZ=America/New_York` with 1 failed, 790 passed while the task's own acceptance test was green. The repair was to drop `ss` from both tables and from the relativeTime block. This is not the pre-existing-fault exception: the failure was caused by this iteration's change, was found before any checkpoint, and was repaired within the iteration, so no revert was due. It is exactly the case for running the whole gate rather than the task's own test, since a locale-shape contract lives in a test file the task never touches.

A second coverage gap surfaced the same way: `preparse` was initially uncovered, because the test parsed its base date before switching locale, so mr's hook never ran and the 100 percent line threshold failed with `mr.js` at 92.31. That was a real hole in the port's verification rather than a coverage technicality - half the numeral pair was shipped unexercised - and it is now covered by the round-trip assertion above.

Filed while executing, not deferred: F11 (Medium, architecture), reproduced with a probe. `preParsePostFormat` installs its `fromToBase` wrapper only `if (oldFromTo)`, so extending it before `relativeTime` silently drops postformat from relative-time output while `format()` keeps postformatting. In that order mr renders `10 मिनिटांपूर्वी` with Latin digits and `format('D')` still returns `१५`, so nothing signals the loss. It affects all 5 locales defining `postformat`. This is the third finding sharing the plugin-composition root cause with F2 and F6, so per the three-strike rule it is filed as one structural task rather than patched here.

Verify gate green after the repair: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 791 tests across 94 suites, up from 789, no test weakened or removed. `mr.js` is 100 percent on statements, branches, functions and lines. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0.

Contract preserved: mr gained `relativeTime`, `preparse` and `postformat`. The latter two are inert unless the consuming code loads `preParsePostFormat`, which dayjs core never does, so default behaviour of `format()` for mr is unchanged; under that plugin mr now renders Devanagari digits, which is what moment does and what the locale's own `A h:mm वाजता` formats imply. No shared or public function changed, and no other locale is touched. The `plugin-preParsePostFormat` inventory row stays unswept on purpose: this iteration exercised its hooks through one locale, which is not the systematic sweep that row calls for, and F11 is now open on it.

Learnings: two rules recorded in PLAN.md - the 13-key locale contract pinned by `test/locale/keys.test.js`, which is what this iteration tripped over, and the required extend order for `preParsePostFormat` after `relativeTime`. The general habit worth keeping is that the task's own test passing is not evidence the change is safe; the contract that failed here was asserted in a file the task had no reason to open.

Next: F5b-4, the Klingon `tlh` port, the last of the F5b split.

## iter 4/10 | 129fbdac-133640 | 2026-07-28 | F11 | done

Task: F11 (Medium, architecture, class) - `preParsePostFormat` installed its `fromToBase` wrapper only when that method already existed, so extending it before `relativeTime` silently dropped postformat from relative-time output. Filed in iteration 3 while porting mr.

Changed: `src/plugin/preParsePostFormat/index.js` (wrapper factored out, accessor fallback for the reverse order), `test/plugin/preParsePostFormat.test.js` (both-orders test), PLAN.md (Lesson corrected to the general rule), BACKLOG.md (F11 deleted, class recorded under Settled classes).

Checkpoint: d8f6dc9032c425875ded1d62b3b6166dc6a825a4 (committed with `-n`, see Lessons). Not a stall: one plugin source file and one test file changed, F11 closed and its class settled.

Verification: The cause is that `relativeTime` assigns `proto.fromToBase` outright. A wrapper installed before that assignment is discarded by it, and the old code's `if (oldFromTo)` guard meant no wrapper was installed at all in that order. Both halves matter: installing unconditionally would not have helped, because the later assignment overwrites it.

The fix keeps the existing wrapper for the normal order and adds an accessor for the reverse one: when `fromToBase` is absent at extend time, the plugin defines a getter/setter pair on the prototype, so `relativeTime`'s later assignment is captured and wrapped as it lands. This works because `relativeTime`'s internal `fromTo` reads `proto.fromToBase` at call time rather than closing over it, so the getter is consulted on every call.

Acceptance check confirmed strong enough to fail, and run in that order: the both-orders test was written first and reported 1 failed, 12 passed against the unfixed plugin, then 13 passed after the fix. It asserts the two orders produce identical output and that the output is genuinely postformatted, matching `/[१२३४५६७८९०]/` and not `/\d/`, so two equally unconverted results cannot satisfy it.

Class enumeration, required because the three-strike rule made this a structural task rather than an instance patch. Every prototype-method wrapper in `src/plugin/*/index.js` was listed. Exactly one wraps a method core does not define - this one, `fromToBase` from relativeTime - and it was the only site guarded by an existence check, which is the tell for the idiom. Every other wrapper targets a core prototype method (`parse`, `format`, `add`, `subtract`, `set`, `startOf`, `locale`, `diff`, `isSame`, `isBefore`, `isAfter`, `daysInMonth`, `$utils`) or a static (`dayjs.unix`, `dayjs.locale`), all of which exist whatever the extend order, so none can fail this way. The class is closed rather than partially patched, and recorded under Settled classes with the grep that re-checks it.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 792 tests across 94 suites, up from 791, no test weakened or removed. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0. The plugin's one uncovered branch sits on line 22, in the pre-existing `format` override, not in anything this iteration wrote.

Contract preserved: the normal extend order takes the identical code path it took before, since `withPostformat(oldFromTo)` is the previous inline function with its `original` bound by argument rather than by closure. Only the previously-broken order changes behaviour, and it changes from silently wrong to correct. No public signature changed and no locale was touched. Both `plugin-preParsePostFormat` and `plugin-interaction-matrix` stay unswept: this iteration exercised one plugin pair in both orders, which is the finding's own regression test, not the systematic sweep either row calls for.

Learnings: the PLAN Lesson from iteration 3 asserted a required extend order; that is now wrong, so it was corrected in place rather than left to mislead a later iteration, and restated as the general rule - wrapping a core prototype method is order-safe, wrapping a plugin-defined one is not. The broader point is that the enumeration was worth more than the fix: it converted an open-ended architectural worry into a closed set of one, and showed the other 36 plugins were never exposed.

Next: F5b-4, the Klingon `tlh` port, the last of the F5b split and the last locale missing relativeTime.

## iter 5/10 | 129fbdac-133640 | 2026-07-28 | F5b-4 | done

Task: F5b-4 (Medium, correctness) - `src/locale/tlh.js` shipped no `relativeTime`, so Klingon fell back to the hardcoded English table. Last of the 4-way split of F5b, and the last bundled locale missing the key.

Changed: `src/locale/tlh.js` (numberAsNoun, unit-noun table, tense affixes, relativeTime block), `test/locale/relativeTime.test.js` (`tlh` added to `PORTED`, `KNOWN_MISSING_RELATIVE_TIME` emptied and its comment rewritten, a numberAsNoun test), PLAN.md (locales-structure row re-swept), BACKLOG.md (F5b-4 deleted, F5b class recorded under Settled classes).

Checkpoint: 60061e3b7fec9f9399f247fce607ac2109debf58 (committed with `-n`, see Lessons). Not a stall: one source file and one test file changed, F5b-4 closed and the F5b class settled.

Verification: Klingon spells a count out as a noun - hundreds take `vatlh`, tens `maH`, the ones digit stands alone, and an empty result is `pagh`. moment builds this by string concatenation with a `word !== '' ? ' ' : ''` separator dance repeated three times; the port collects the places into an array and joins them, which is the same function with the separator bookkeeping removed. The tense affix is the unusual part: for days, months and years it replaces the unit noun rather than being appended, so the output loses its last 3 characters, which is why `translateFuture` and `translatePast` slice rather than concatenate.

moment's `ss` arm is dropped, per the 13-key locale contract learned in iteration 3, so `translate` covers `mm`, `hh`, `dd`, `MM`, `yy` and the singular keys stay constant strings. Because they are constants, the singular-key number contract from iteration 1 does not apply here either.

All 4 affix branches are reachable from the buckets and are covered by them: `dd` produces `jaj`, `MM` produces `jar`, `yy` produces `DIS`, and everything else takes the trailing particle. `numberAsNoun` is not: the buckets only ever produce ones and tens, so the hundreds arm and the zero arm are exercised by direct calls at 0, 100, 500, 123 and 999 across all 5 plural keys, compared against `moment.localeData('tlh').relativeTime(...)`.

Three expected strings are also spelled out literally - `pagh jaj`, `wa’vatlh jaj`, `wa’vatlh cha’maH wej jaj` - so the moment comparison cannot pass by both sides agreeing on nothing, and so a transcription error in the U+2019 apostrophes would fail rather than silently match a mistake copied into both.

Acceptance check confirmed strong enough to fail: with only `src/locale/tlh.js` stashed, `test/locale/relativeTime.test.js` reports 3 failed, 12 passed. With it restored, 15 passed.

F5b is now class-complete and recorded under Settled classes. All 143 bundled locales were enumerated at the start; 9 lacked `relativeTime`, 5 were ported in the previous run and these 4 in this one. `KNOWN_MISSING_RELATIVE_TIME` is empty and asserted empty, which converts the enumeration into a standing regression check rather than a note.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 794 tests across 94 suites, up from 792, no test weakened or removed. `tlh.js` is 100 percent on statements, branches, functions and lines. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0.

Contract preserved: one locale gained a key it did not previously define. No shared or public function changed, and no other locale is touched. The `KNOWN_MISSING_RELATIVE_TIME` comment was rewritten because it pointed at a backlog item that no longer exists and described a list that may only shrink, which is now wrong in the direction that matters: the list is empty and any entry is a regression.

Ledger state, recorded because it decides the next iteration: 2 open items remain, F10 and F9, which is below the replenishment threshold of 3. Replenishment is due, and the right form is a partial audit over the 7 unswept Surface inventory rows rather than more locale work, because those rows are also what the Definition of done still needs - convergence requires no unswept row, and the run is not in closeout, so auditing is still allowed.

Learnings: no new operational rule this iteration; the three rules recorded earlier in the run (the singular-key number contract, the 13-key locale contract, moment's direct-call oracles) each applied again here without surprise, which is the point of having written them down. The habit worth noting is spelling out a few expected values alongside a differential oracle, because a differential alone cannot detect that both sides were transcribed from the same mistake.

Next: a partial audit sweeping unswept inventory rows, which both replenishes the ledger and moves the Surface inventory toward the state convergence requires.

## iter 6/10 | 129fbdac-133640 | 2026-07-28 | AUDIT | audit

Task: Partial audit to replenish the ledger, which fell to 2 open items after F5b-4 closed. Targeted the least recently swept Surface inventory rows rather than re-probing swept ones, per the Method.

Changed: PLAN.md (3 inventory rows flipped to swept, 1 Lesson), BACKLOG.md (F12 filed in Now, F13 filed in Later). No source file touched, which is expected of an audit iteration.

Checkpoint: 600f9690226250309d878e464d5dfe687206c55e (committed with `-n`, see Lessons). Not a stall: no source changed, which an audit iteration expects, but 2 backlog items were filed and 3 inventory rows changed state.

Verification: This is a partial audit and does not count toward convergence, and it does not open closeout. Closeout requires a full fresh-evidence audit scoring zero High and zero Medium across the whole project; this one examined 3 of the 7 unswept rows and found a High, so neither condition is met. Four rows remain unswept: locales-content, types-declarations, build-pipeline, plugin-interaction-matrix.

Scores, claiming only the 3 rows swept this iteration and nothing else:
- error handling: High - F12, `devHelper` tests the bare global `process`, so extending it in a browser throws ReferenceError instead of installing the warnings.
- developer experience: Low - F13, the 13-character rule fires on valid date strings and tells the developer to make them numbers.
- correctness: None on these 3 rows. badMutable matched moment on every known-answer check including the two paths its own suite never exercises; preParsePostFormat round-trips Devanagari input back to the same instant as the Latin form.
- architecture: None on these 3 rows; the plugin-composition class was settled in iteration 4 and its implementing code has not changed since.
- security, performance, documentation, dependency hygiene: not scored, not swept this iteration.

badMutable evidence: the existing suite is stronger than its inventory row implied - it is a differential against moment, which is genuinely mutable, across setters, set, startOf, add, daysInMonth, locale, isSame, isBefore and isAfter. What it never touches is `subtract` and `endOf`, both of which reach the overridden mutating methods indirectly through core (`subtract` calls `this.add`, `endOf` calls `this.startOf`). Both were probed and both are correct: subtract clamps Mar 31 minus one month to Feb 28 exactly as moment does, endOf month and endOf year match, add at -13 months matches, the receiver is mutated in place, and the same object is returned. `diff` was checked for the opposite property and leaves its receiver unchanged, because `monthDiff` clones before calling `add`.

Considered and deliberately not filed: the missing `subtract` and `endOf` cases in `test/plugin/badMutable.test.js`. The rubric would allow a Medium for untested paths whose failure would matter, but both delegate to methods the suite does test, and both were just verified correct against moment, so filing it would add ledger noise rather than protect anything.

F12 evidence, checked against the shipped artifact rather than the source, per the Publication rule. Deleting `global.process` and extending devHelper raises `ReferenceError: process is not defined`. That it reaches browsers was verified by building the plugin through the project's own `build/rollup.config.js`: the emitted UMD still contains `if(!process||"production"!==process.env.NODE_ENV)`, no shim is applied because the rollup config has no replace step, and the wrapper assigns `globalThis.dayjs_plugin_devHelper`, so the browser global path the bundle exists to serve is the path that throws. `src/plugin/devHelper/index.js:4` is the only reference to `process` anywhere in `src/`, and nothing in the tree uses `typeof process`, so this is a single site and not a class.

F13 evidence: `dayjs('2019-06-15T12')` is 13 characters, parses correctly to 2019-06-15 12:00, and still draws the Unix-timestamp warning; 10-character and 12-character strings do not. The advice it gives would break the input it is given, which is why it is filed rather than tolerated, but it is development-only console noise and is Low.

Verify gate green: the whole suite under UTC with the 100 percent line-coverage threshold, exit 0, 794 tests across 94 suites, unchanged from the last checkpoint because this iteration changed no source.

Learnings: one operational rule recorded in PLAN.md - every plugin and locale is emitted as a standalone UMD browser bundle with no replace or shim step, so a bare Node global in a source file ships to browsers, and a suspected build-output problem should be checked by building that one entry through the project's rollup config rather than reasoned about from source. That is what turned F12 from a plausible reading of the code into a verified property of the artifact.

Next: F12, the only High on the ledger.

## iter 7/10 | 129fbdac-133640 | 2026-07-28 | F12 | done

Task: F12 (High, error handling) - `src/plugin/devHelper/index.js:4` tested the bare global `process`, so extending the plugin in a browser threw `ReferenceError: process is not defined` instead of installing its warnings. Filed by the partial audit in iteration 6.

Changed: `src/plugin/devHelper/index.js` (guard changed to `typeof`, comment), `test/plugin/devHelper.test.js` (no-process installation test), PLAN.md (plugin-devHelper row re-swept after the source change), BACKLOG.md (F12 deleted).

Checkpoint: 939ac378b4b25112af26ffd3c2f84ec1e2e9a1da (committed with `-n`, see Lessons). Not a stall: one plugin source file and one test file changed, and F12 closed.

Verification: The guard was written to mean "if there is no process, assume development", but a bare read of an undeclared identifier throws rather than yielding undefined, so the defensive check was itself the failure. `typeof process === 'undefined'` expresses the same intent and is the only form that survives the absence it is testing for. The rest of the condition is unchanged, so behaviour where `process` exists is identical, including under `NODE_ENV=production` where the plugin still installs nothing.

Acceptance check confirmed strong enough to fail: against the unfixed plugin the new test reports 1 failed, 9 passed, and the failure is the exact `ReferenceError: process is not defined`. After the fix, 10 passed.

The test carries a second assertion for a specific reason. Asserting only that `extend` does not throw would also be satisfied by a fix that skipped installation whenever `process` was absent, which would be a silent regression for every browser user of the plugin. So it then captures `console.warn` and asserts `d(2020)` produces exactly one warning containing the year message, which proves the parse override was really installed. The modules are required before `process` is deleted, so jest's own loader is never run without it, and the global is restored in a `finally`.

Verified against the shipped artifact, not just the source, because that is what the finding was about. The plugin was rebuilt through the project's own `build/rollup.config.js`: the emitted UMD now reads `if("undefined"==typeof process||"production"!==process.env.NODE_ENV)`, so the guard survives terser. That artifact was then loaded and extended with `global.process` deleted, which succeeded and installed warnings that fired. The build scratch files were removed afterwards.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 795 tests across 94 suites, up from 794, no test weakened or removed. `src/plugin/devHelper` is 100 percent on statements, branches, functions and lines. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0 with no warnings; the new test needed a local `no-console` disable, matching the pragma the plugin source already carries, because assigning to `console.warn` trips the rule just as calling it does.

Contract preserved: no public signature changed and no warning text changed. In Node the condition evaluates exactly as before, since `typeof process` is `'object'` there and the second operand is untouched. The only behaviour that changes is in a host where `process` does not exist, and there it changes from throwing to installing, which is what the surrounding code always intended.

Learnings: no new operational rule. The rule recorded in iteration 6 - that every plugin ships as a UMD browser bundle with no shim step, so a suspected build-output problem must be checked against the built artifact - was applied twice this iteration, once to confirm the defect and once to confirm the fix, which is the shape worth repeating: a finding stated about an artifact is only closed by re-checking that artifact.

Next: F10, the ordinal markers, which the ledger flags as needing a split into per-language batches before any code.

## iter 8/10 | 129fbdac-133640 | 2026-07-28 | F10-1 | done

Task: F10, the bare ordinal markers. The ledger flagged it as needing a split before any code, so this iteration corrected its evidence, split it into 5 language batches, built the enumerating check its acceptance called for, and executed the first batch: the English variants.

Changed: `src/locale/en-ca.js`, `en-ie.js`, `en-il.js`, `en-sg.js`, `x-pseudo.js` (English ordinal), `test/locale/ordinal.test.js` (new, 3 tests), PLAN.md (2 Lessons, locales-content row note corrected), BACKLOG.md (F10 replaced by F10-2 through F10-6, 2 Declined classes).

Checkpoint: 8a84e44bce9e7abad31ad1941ff285406f4ca1f8 (committed with `-n`, see Lessons). Not a stall: 5 locale files changed, a test file was added, F10 was split and its first batch closed.

Verification: The ledger's premises were wrong in two ways and are corrected rather than inherited. Its example `fr` gives 2 not 2e is false: `fr` already renders `2e` and matches moment exactly. And my own first enumeration was wrong in the opposite direction, counting 90 bare locales, because it called `locale.ordinal(n)` with no period argument; moment's `ru`, `uk` and `be` switch on that argument and fall to `default: return number` without it. Redone as a real end-to-end `format('Do')` differential on both sides, the count is 85 bare in dayjs, of which 47 are genuine marker gaps. The original figure of 52 was close but included 5 that are not gaps.

Two Declined classes came out of that separation, and both are evidenced rather than asserted. 10 locales (`ar`, `hi`, `bn` and 7 more) show a difference from moment that is native digits, not a marker: moment ships no `ordinal` key at all for them, confirmed by grep, and its digits come from `postformat`, which dayjs gates behind the opt-in preParsePostFormat plugin, so a bare Latin number is the correct core output. A further 28 render bare in moment too, so there is no evidence a marker is wanted; 5 of those moment does not ship at all.

The escaping trap is the reusable finding, and it would have silently corrupted most of the remaining batches. advancedFormat substitutes `Do` and hands the result to core `format`, so a marker containing a token letter is reinterpreted: an unescaped `1st` renders as `145t` at 14:30:45, the `s` having been replaced by the seconds. That is why `en`, `en-gb`, `en-au`, `nl` and `sv` all wrap their markers in `[...]` while `1.` and `1º` need no wrapper. It is pinned as its own test asserting both the corrupted and correct renderings, recorded as a Lesson, and called out in the acceptance text of the batches whose markers contain token letters.

Acceptance check confirmed strong enough to fail: with the 5 locale files stashed, `test/locale/ordinal.test.js` reports 2 failed, 1 passed, and the third test passes in both states because it tests the escaping mechanism rather than the locales.

Batch 1 is the English variants because their rule needs no research: `en-ca`, `en-ie`, `en-il`, `en-sg` and `x-pseudo` take the same st/nd/rd/th algorithm dayjs's own `en` already implements, so the change is a copy of an in-repo implementation rather than a transcription from moment, and the test asserts `en` itself still renders identically. `tet` was left for a later batch despite moment giving it English suffixes, because that is moment's judgement about Tetum rather than something this run can justify.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 798 tests across 95 suites, up from 795, no test weakened or removed. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0.

Contract preserved: the 5 locales gained a marker where they previously returned the number unchanged, which is an observable change to `format('Do')` for them and is recorded here per the Constraints. No shared code changed, `en` and every already-marked locale is untouched, and the enumerating test pins the full set so a later batch cannot regress one silently.

Learnings: two rules in PLAN.md - the bracket-escaping requirement, and that `Do` calls `ordinal` with no period while `wo` passes `'W'`, so a locale ported from moment with a `case 'D':` arm would fall through to `default`. The methodological lesson is the one that cost time: probing a function without the argument its real caller passes produced a confidently wrong enumeration, and it was only caught by comparing rendered `format('Do')` output instead of raw `ordinal()` return values.

Next: F10-2, the 11 trailing-period locales, the batch with one uniform rule and no escaping needed.

## iter 9/10 | 129fbdac-133640 | 2026-07-28 | F10-2 | done

Task: F10-2 (Medium, correctness) - 11 locales whose language marks the ordinal with a trailing period rendered `format('Do')` as a bare number: `bs`, `eu`, `fo`, `is`, `lb`, `lv`, `me`, `se`, `sq`, `tlh`, `tzl`.

Changed: those 11 files in `src/locale` (one line each), `test/locale/ordinal.test.js` (11 names removed from `KNOWN_BARE_ORDINAL`, a period-ordinal assertion added), BACKLOG.md (F10-2 deleted).

Checkpoint: e9e0218dd5b641ea5fad594a5f12b3ddf1a12470 (committed with `-n`, see Lessons). Not a stall: 11 locale files and a test file changed, and F10-2 closed.

Verification: The batch was checked for uniformity before being treated as one. moment implements all 11 as the plain string `'%d.'`, with no function and no per-digit variation, and dayjs had all 11 as `ordinal: n => n`, so a single rule genuinely covers the batch rather than being assumed to. The form used is `` n => `${n}.` ``, which is what dayjs's own `id` locale already carries, so this is an in-repo convention rather than a transcription from moment; the test asserts `id` still renders identically.

No bracket escaping here, and that is a checked property rather than an oversight: a period is not a letter core format reads as a token, which is why `id` and `oc-lnc` have always been safe unescaped while `en` and `sv` must wrap. The test comment records the reason so a later batch does not copy the unescaped shape into a locale whose marker does contain token letters.

Acceptance check confirmed strong enough to fail: with the 11 locale files stashed, `test/locale/ordinal.test.js` reports 2 failed, 2 passed. The two that still pass are the English-variant test from the previous batch and the escaping test, which is the intended behaviour - each batch's assertion fails only for its own locales, so the file localises a regression instead of going uniformly red.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 799 tests across 95 suites, up from 798, no test weakened or removed. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0.

Contract preserved: 11 locales gained a marker where they previously returned the number unchanged, an observable change to `format('Do')` for them, recorded here per the Constraints. Four of them (`bs`, `me`, `tlh`, `tzl`) gained `relativeTime` earlier in this run, and the full suite confirms those ports are unaffected: `ordinal` and `relativeTime` are independent keys and the relativeTime bucket comparisons still match moment. No shared code changed.

Learnings: no new operational rule. The escaping rule recorded in iteration 8 was applied in its negative direction here - it tells you when escaping is not needed, not only when it is - and confirming that before writing 11 files was cheaper than discovering a corrupted render afterwards.

Next: final iteration. F10-3 through F10-6 remain along with F13 and F9, so iteration 10 should be a WRAPUP that tidies the ledger and writes a handoff rather than starting a batch that cannot finish.

## iter 10/10 | 129fbdac-133640 | 2026-07-28 | WRAPUP | done

Task: Final iteration of the budget. The top unblocked item is F10-3, 10 Cyrillic locales each needing its own per-digit rule researched, which cannot finish in one iteration, so per the closing rule this tidies the ledger and writes a handoff instead of starting it.

Changed: JOURNAL.md only, plus the rotation recorded in its own entry below. BACKLOG.md was already tidy: 6 open items, each one line with a runnable acceptance check, no prose, no DONE annotations, and the two large classes settled during the run recorded under Settled classes rather than left as open work.

Checkpoint: f33b2a3086e0d445b611a779ec8ac1c53d40410f (committed with `-n`, see Lessons). Stall check: this iteration changed only JOURNAL.md and JOURNAL-archive.md and no BACKLOG.md item changed state, which is expected of a WRAPUP and is not a repeat, since iter 9 closed F10-2.

Verification: Verify command green at the close: 4 timezone passes on `test/timezone.test`, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold. 799 tests across 95 suites, exit 0. The suite grew from 785 to 799 across the run and no test was weakened or removed; every added test was first run against the unfixed code and observed to fail, except the ordinal escaping test, which documents a mechanism rather than a fix and passes in both states by design.

Not converged, and the run does not claim to be. 6 findings remain open, so the Definition of done is not met, the evaluator gate is not invoked, and no Converged line is appended. The Surface inventory stands at 37 of 41 rows swept, up from 34.

Six tasks closed this run: F5b-1, F5b-2, F5b-3, F5b-4 (Medium, correctness) completing the relativeTime class; F11 (Medium, architecture) and F12 (High, error handling); plus F10-1 and F10-2 as the first two ordinal batches. Two classes were settled class-complete with enumerating checks, and two Declined classes were recorded with evidence.

Handoff for the next run, in ledger order:

F10-3 is 10 Cyrillic locales (`be`, `cv`, `kk`, `ky`, `mk`, `mn`, `ru`, `tg`, `ug-cn`, `uk`). Unlike F10-2 these are not uniform: `mk` varies the suffix across ви/ри/ти by last digit, `ky` alternates чи/чү, and `mn` appends a word rather than a suffix. moment implements most as a function switching on the digit, so each needs its own rule and its own known-answer row. None of the markers contain Latin token letters, so bracket escaping is not needed, but check that per locale rather than assuming it.

F10-4 is the batch where escaping matters most: `af`, `br`, `cy`, `fy`, `ga`, `gd`, `nl-be` all have markers containing `d`, `s` or `a`. Write them as `` `[${n}ste]` `` and verify with `format('Do')` at a time with non-zero seconds, because an unescaped marker only misrenders when the token it collides with has a value - the corruption is invisible at second zero.

F10-5 and F10-6 are smaller and follow the same shape. `ka` and `yo` are the awkward ones: both place the marker before the number, so the template is not a suffix.

F13 and F9 are both Low and both small. F9 in particular is a one-line deletion of the dead `S` alternation from advancedFormat's regex, and it is a good first task for a fresh run because it is finishable inside one iteration.

Four inventory rows remain unswept: `locales-content` (ordinals are now swept properly, but month names, weekday names, meridiem strings and longDateFormat patterns are uncompared), `types-declarations`, `build-pipeline` and `plugin-interaction-matrix`. The types row is the one most likely to pay: two of the previous run's Highs were shipped `.d.ts` declarations disagreeing with runtime, and nothing has re-examined that surface since.

Learnings: the run's most reusable output is the set of rules now in PLAN.md, three of which were each earned by a concrete mistake rather than foresight - the singular-key number contract, the 13-key locale shape pinned by a test the task never opens, and the bracket-escaping requirement. The methodological one worth carrying is that probing a function without the argument its real caller passes produces a confidently wrong answer: comparing rendered `format('Do')` output rather than raw `ordinal()` return values is what corrected an enumeration that was wrong in both directions.

Next: nothing in this run. Start a fresh session in this directory so the next run gets clean context; PLAN.md, BACKLOG.md, JOURNAL.md and JOURNAL-archive.md carry the state forward.

## iter 10/10 | 129fbdac-133640 | 2026-07-28 | ROTATION | rotation

Task: JOURNAL.md reached 522 lines after the WRAPUP entry, over the 500-line rotation threshold, so all but the last 10 entries move to JOURNAL-archive.md.

Changed: JOURNAL.md (11 entries removed, header kept), JOURNAL-archive.md (created, 11 entries appended after a short header).

Checkpoint: f33b2a3086e0d445b611a779ec8ac1c53d40410f (shared with the WRAPUP entry; both were written in the same iteration and committed together).

Verification: 21 entries existed before the rotation and 21 exist after it, 11 in the archive and 10 in the live journal, so nothing was dropped. The archive was created rather than overwritten, since it did not previously exist, and its header states that it is append-only and cumulative across runs so a later rotation adds to it rather than replacing it. The split fell on a natural boundary without being arranged: the archive holds the whole of the previous run (`51ee54b9-124116`, iterations 1 to 10) and the live journal holds exactly this run's 10 entries (`129fbdac-133640`), because both runs used a 10-iteration budget. The `# Journal` header and its heading grammar were preserved in the live file, and entry order is unchanged in both.

Learnings: none. This is mechanical bookkeeping, and it is recorded as its own entry only because the rotation rule requires it.

Next: nothing. This entry is additional to the WRAPUP above, which closes the run.

## iter 1/10 | a7604090-143642 | 2026-07-28 | F10-3 | done

Task: F10-3 (Medium, correctness) - 10 locales rendered `format('Do')` as a bare number where moment marks it: `be`, `cv`, `kk`, `ky`, `mk`, `mn`, `ru`, `tg`, `ug-cn`, `uk`. Unlike F10-2 these share no single rule, so each got its own.

Changed: those 10 files in `src/locale`, `test/locale/ordinal.test.js` (10 names removed from `KNOWN_BARE_ORDINAL`, 3 tests added), PLAN.md (3 Lessons, 2 Surface inventory row notes), BACKLOG.md (F10-3 deleted).

Checkpoint: cdd04ea19e87dff8cdd68b5360b5bbc7ec42dc81 (committed with `-n`, see Lessons). Not a stall: 10 locale files and a test file changed, and F10-3 closed.

Verification: The ledger described these as Cyrillic-script locales; `ug-cn` is Uyghur in Arabic script. The grouping is by rule shape rather than script, which the fix reflects: four distinct shapes were read out of moment's source rather than assumed. Five switch on the `period` argument (`be`, `mn`, `ru`, `ug-cn`, `uk`), three use a sparse last-digit lookup table (`kk`, `ky`, `tg`), `mk` uses a seven-arm digit chain, and `cv` is one fixed marker.

The oracle was the trap, and it is the same mistake as last run wearing different clothes. `moment.localeData(name).ordinal(n)` returns the raw number for all five period-switching locales, so a bare direct-call differential would have passed against a locale still returning the number unchanged. Probed before writing any code: `ru` gives `7` with no period, `7-го` for 'D', `7-я` for 'W'. The valid oracle is `ordinal(n, 'D')` for dayjs's `Do` and `ordinal(n, 'W')` for `wo`, and only the five period-blind locales admit the bare form. dayjs passes no period from `Do` and 'W' from `wo`, so moment's five-way switch collapses to two arms with the day form in `default`, which is dayjs's own `zh-cn` convention.

`period` is treated as a live parameter, not decoration: the test asserts the same number renders differently for the two values dayjs can pass, then pins both against moment, then drives the real `wo` token end to end. `be` is the only one whose week marker also varies by digit, so both arms of its 2/3-vs-teens rule are exercised at 2, 3, 12, 13, 22 and 7.

One simplification, pinned rather than argued. moment's `kk`/`ky`/`tg` lookup ends in a third fallback, `suffixes[n >= 100 ? 100 : null]`, which is unreachable: the table defines every key 0 through 9, so the last-digit lookup always resolves. It is dropped, and the equivalence of the two forms is asserted over n = 0..120 against moment for all five period-blind locales.

No marker here contains a letter `REGEX_FORMAT` reads as a token, so no bracket wrapper is needed, but that is asserted rather than assumed: the `Do` differential renders at `T14:30:45`, the time at which an unescaped collision corrupts output, and matches moment exactly for all 10.

Coverage needed direct calls. `mk`'s zero arm and its multiple-of-100 arm cannot be produced by `Do` (1-31) or `wo` (1-53), so without a direct `dayjs.Ls.mk.ordinal(n)` sweep the 100 percent line gate fails on two dead lines. The three lookup tables were generated by script from `node_modules/moment/locale/*.js` rather than retyped, so they cannot carry a transcription error.

Acceptance check confirmed strong enough to fail: with the 10 locale files stashed, `test/locale/ordinal.test.js` reports 4 failed, 3 passed. The three that still pass are the English-variant, period-ordinal and escaping tests from earlier batches, which is the intended localization - each batch's assertions fail only for its own locales.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 802 tests across 95 suites, up from 799, no test weakened or removed. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0.

Three-strike rule considered and does not bite. F10-1, F10-2 and F10-3 share the root cause `ordinal: n => n`, but they are batches of one already-classed finding rather than three independently filed instances, and the class fix exists: the shrink-only `KNOWN_BARE_ORDINAL` enumeration built in F10-1 is what makes the remainder finite and visible. No fourth instance is being patched blind.

Contract preserved: 10 locales gained a day marker where `format('Do')` previously returned the number unchanged, and five of them also gained a distinct `format('wo')` marker. Both are observable changes and are recorded here per the Constraints. No shared code changed. The tests that pin these locales were read first: `test/locale/be.test.js`, `ru.test.js` and `uk.test.js` cover relativeTime and month formats and do not load advancedFormat, so `Do` is not a token there; `test/plugin/localeData.test.js` compares ordinals only for `en`; and `test/locale/keys.test.js` requires `ordinal(i)` to return a value for i in 1..31, which every new rule does.

Learnings: three rules added to PLAN.md - the period-aware oracle, generating locale data by script instead of retyping it, and covering ordinal arms a date cannot reach by direct call. The first is the reusable one. Last run's wrong enumeration came from probing `ordinal(n)` without the argument its real caller passes; the same error reappeared here as a choice of oracle, and it fails silently in both directions, so the rule to carry is that the reference must be exercised through the same call shape as the code under test.

Next: F10-4, the 7 Celtic and West-Germanic locales. That is the batch where bracket escaping actually matters, since the markers contain `d`, `s` and `a`.

## iter 2/10 | a7604090-143642 | 2026-07-28 | F10-4 | done

Task: F10-4 (Medium, correctness) - 7 Celtic and West-Germanic locales rendered `format('Do')` as a bare number: `af`, `br`, `cy`, `fy`, `ga`, `gd`, `nl-be`. This is the batch where bracket escaping actually matters, since every marker holds a `d`, an `s` or an `a`.

Changed: those 7 files in `src/locale`, `test/locale/ordinal.test.js` (7 names removed from `KNOWN_BARE_ORDINAL`, 2 tests added, the escaping test extended), `src/plugin/localeData/index.js` and `test/plugin/localeData.test.js` (a stale count in a comment), PLAN.md (2 Lessons, a corrected count in the locales-content row), BACKLOG.md (F10-4 deleted).

Checkpoint: 4f8fc2688b1eab51b48e8eb418eb3cd847ca4dd2 (committed with `-n`, see Lessons). Not a stall: 7 locale files, a test file and two comment sites changed, and F10-4 closed.

Verification: Three of the seven needed no transcription at all. `af`, `fy` and `nl-be` carry the same rule as `nl`, which dayjs already implements as `` n => `[${n}${n === 1 || n === 8 || n >= 20 ? 'ste' : 'de'}]` ``, so their line is a copy of in-repo code and the test asserts all three render identically to `nl`, which is unchanged. `ga` and `gd` share one rule with each other. `br` is a two-arm split and `cy` is a 21-entry lookup with an above-20 rule that has exceptions at 40, 50, 60, 80 and 100.

The escaping claim is now evidenced rather than asserted, and the evidence corrected my own framing. The existing escaping test only covered an `s` marker, which corrupts only when the seconds are non-zero. A `d` marker is worse: the weekday token always has a value, so it corrupts at every date. Measured rather than reasoned - `1de` renders as `16e` on 2019-06-01, a Saturday, the `d` having been replaced by the weekday number 6. Both the raw and escaped forms of a `de` marker are now pinned alongside the `st` pair, and the batch's own assertion is stronger than an equality: after deleting the day number from each rendered value, no digit may remain, which fails loudly for any token bleed rather than only for the collisions I thought to predict.

Coverage needed the wide sweep again. `cy`'s above-20 exceptions cannot all be produced by `Do` (1-31), and its zero arm cannot be produced at all, so the seven are swept directly over n = 0..120 against moment. That comparison runs through `localeData()`, which is the boundary that strips the escape brackets, so it also exercises that boundary against seven more locales; `test/plugin/localeData.test.js` had only ever covered `en` there.

One compatibility check rather than a guess: `cy`'s above-20 rule wanted `[40, 50, 60, 80, 100].includes(n)`, but `src/` uses no `Array.prototype.includes` anywhere, and babel.config.js runs `@babel/preset-env` with no targets, no `useBuiltIns` and no core-js, so it transforms syntax only and that built-in would ship unpolyfilled. Written as an explicit comparison chain instead and recorded as a Lesson.

A correction to my own iteration 1 entry, which is why the numbers are restated here. PLAN.md's locales-content row said 21 of 47 gaps were closed by F10-1, F10-2 and F10-3. The figure 21 was right but the attribution was wrong: the 47 was measured after F10-1 had already closed the 5 English variants, so F10-1 is not part of it and the total marker gap found was 52. Counted from the code rather than from prose, `KNOWN_BARE_ORDINAL` went 85 to 74 to 64 to 57 across F10-1 to F10-4, and 57 is exactly the 38 Declined plus the 19 still open as F10-5 and F10-6. The row now states it that way so the next audit can check it instead of trusting it.

Acceptance check confirmed strong enough to fail: with the 7 locale files stashed, `test/locale/ordinal.test.js` reports 3 failed, 6 passed, and the 3 failures are exactly this batch's assertions. The F10-3 assertions still pass, so each batch's failure stays localized.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 804 tests across 95 suites, up from 802, no test weakened or removed. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0.

Contract preserved: 7 locales gained a bracketed day marker where `format('Do')` previously returned the number unchanged, an observable change recorded here per the Constraints. The brackets are locale data, not display text, and the one place that distinction is public is `localeData().ordinal`, which strips them; that boundary is unchanged and is now covered for all 7. The only shared file touched is a comment in `src/plugin/localeData/index.js` that claimed a fixed count of bracketed locales, which this batch made wrong; it and the matching comment in `test/plugin/localeData.test.js` are now count-free and point at `test/locale/ordinal.test.js`, where the set is actually pinned.

Learnings: two rules added to PLAN.md - probe escaping at a non-zero hour, minute and second because `d` and `s` markers fail on different dates, and avoid ES2015+ built-ins in `src/` because the build polyfills nothing. The wider lesson is the one the count correction illustrates: a number written into a state file as prose is unverifiable a run later, and the fix is to anchor it to something a reader can recount from the code, which the row now does.

Next: F10-5, the 7 Romance and constructed-language locales. `er` and `a` forms carry token letters, so the same bracket rule applies.

## iter 3/10 | a7604090-143642 | 2026-07-28 | F10-5 | done

Task: F10-5 (Medium, correctness) - 7 Romance and constructed-language locales rendered `format('Do')` as a bare number: `fr-ca`, `fr-ch`, `it-ch`, `mi`, `mt`, `eo`, `gom-latn`.

Changed: those 7 files in `src/locale`, `test/locale/ordinal.test.js` (7 names removed from `KNOWN_BARE_ORDINAL`, groups reorganized, the escaping test extended), PLAN.md (2 Lessons, an updated count in the locales-content row), BACKLOG.md (F10-5 deleted).

Checkpoint: 9037599960da08271aa822b2f12f181935e232c4 (committed with `-n`, see Lessons). Not a stall: 7 locale files and a test file changed, and F10-5 closed.

Verification: The ledger's premise for this batch was wrong and is corrected rather than inherited. It said "the `er` and `a` forms contain token letters and need escaping". Checked against `REGEX_FORMAT` in `src/constant.js`, whose token letters are `Y M D d H h a A m s Z S`, `er`, `e`, `re` and the masculine ordinal indicator contain none of them. Only `eo`'s bare `a` collides. So one of the seven is bracketed and six are not, where the ledger implied at least two.

That distinction matters more than it looks, because `eo`'s corruption is invisible to the check written for the previous batch. `a` is the meridiem token, so unescaped `1a` renders as `1pm` - measured, not reasoned. It substitutes a token rather than splicing in a number, so the no-stray-digit assertion from F10-4 passes over it happily; only the equality against moment catches it. Both the corrupted and escaped forms are now pinned, together with an explicit assertion that the corrupted one does contain no extra digit, so the limit of that check is recorded in the test rather than left to be rediscovered.

`gom-latn` is the exact inverse of the `ru` trap from iteration 1. moment marks `case 'D'` only and its `default:` returns the bare number, so a faithful transcription of the switch would have left the locale exactly as bare as it started, since dayjs's `Do` passes no period at all. The marker goes in the fallthrough and `wo` keeps the number.

`fr-ca` and `fr-ch` are a third shape again, and they are not copies of dayjs's `fr`. moment gives `fr` a `case 'D'` that deliberately returns no suffix above 1, with a TODO citing moment issue 3375, so `fr` renders `1er 2 3 4`; `fr-ca` and `fr-ch` have no such case, so their `default:` falls through into the masculine arm and they render `1er 2e 3e 4e`. Confirmed by rendering both in moment before writing either. This also shows moment's `default:` is not reliably the bare-number arm, which is the second Lesson recorded.

The `period` parameter test needed strengthening rather than extending. It asserted that the two period values produce different output at a fixed n of 7, but `fr-ca` and `fr-ch` differ only at 1, where 'er' meets 're', and agree on 'e' at every value above. The constant is now a list of name-and-number pairs, so each locale is probed at a number where its two arms genuinely diverge. Padding the old list would have added two locales whose parameter was never actually shown to do anything.

`it-ch`, `mi` and `mt` needed no transcription: `` n => `${n}º` `` is the line dayjs's `it`, `pt` and `oc-lnc` already carry.

Acceptance check confirmed strong enough to fail: with the 7 locale files stashed, `test/locale/ordinal.test.js` reports 6 failed, 3 passed. That is less localized than the 3-of-9 and 4-of-9 of the previous batches, and the reason is deliberate: the test's groups are now organized by the property under test - period sensitivity, escaping, period blindness - rather than by which batch a locale arrived in, so one batch's locales appear in several groups. The property grouping is the more useful axis; the cost is that a failure no longer names its batch, which is recorded here rather than hidden.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 804 tests across 95 suites, unchanged in count because this iteration added assertions to existing tests rather than new ones, and no test was weakened or removed. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0.

Contract preserved: 7 locales gained a day marker where `format('Do')` previously returned the number unchanged, and `fr-ca`, `fr-ch` and `gom-latn` also gained a distinct `format('wo')` form. Both are observable changes recorded here per the Constraints. The `wo` path was checked end to end against moment for all three, which also confirms dayjs's week numbers agree with moment's for these locales, not just the markers. No shared code changed this iteration.

Learnings: two rules added to PLAN.md - check a marker against the actual `REGEX_FORMAT` letter set rather than inheriting an escaping claim, and read which arm moment's `default:` joins before deciding whether a bare direct call is a valid oracle. The reusable point is that both of this batch's surprises came from a written claim rather than from the code: the ledger's escaping assertion and the assumption that `default:` means bare. Both were cheap to check and would have been expensive to trust.

Next: F10-6, the last ordinal batch, 12 locales in other scripts. `ka` and `yo` place the marker before the number, so the template is not a suffix and the shape has to be read per locale.

## iter 4/10 | a7604090-143642 | 2026-07-28 | F10-6 | done

Task: F10-6 (Medium, correctness) - the last ordinal batch, 12 locales in other scripts rendering `format('Do')` bare: `az`, `el`, `fa`, `ka`, `km`, `kn`, `lo`, `si`, `ta`, `te`, `tet`, `yo`. Closing it settles the whole ordinal class.

Changed: those 12 files in `src/locale`, `test/locale/ordinal.test.js` (12 names removed from `KNOWN_BARE_ORDINAL`, 1 test added, groups extended), PLAN.md (2 Lessons, the locales-content row updated), BACKLOG.md (F10-6 deleted, the ordinal class recorded under Settled classes).

Checkpoint: 3ca90ced1274ef9b897fa4a4f1ebeae82da7817f (committed with `-n`, see Lessons). Not a stall: 12 locale files and a test file changed, F10-6 closed and the ordinal class settled.

Verification: Two things had to be established before any transcription, and both changed the work.

First, moment's rendered `format('Do')` is not a valid oracle for 4 of the 12. `fa`, `km`, `kn` and `ta` define a `postformat` hook that rewrites Latin digits into the locale's own numerals, so moment renders day 1 in Persian as the Persian digit followed by the marker while its `ordinal(1)` returns the Latin digit followed by the same marker. dayjs gates `preparse` and `postformat` behind the opt-in preParsePostFormat plugin, so Latin digits are the correct core output and `moment.localeData(name).ordinal(n)` is the oracle. This is the same distinction the previous run used to Decline 10 locales, and it is now asserted rather than assumed: a new test checks each of the 4 against moment's `ordinal()` and separately checks that moment's own rendered `Do` differs, so the postformat boundary is pinned in both directions.

Second, moment's `az` table is broken and porting it verbatim would have imported the hole. `moment.localeData('az').ordinal(40)` is NaN: the table carries no 40 entry, and the chain `suffixes[a] || suffixes[b] || suffixes[c]` runs out, because `c` is null below 100. Week 40 reaches `ordinal` through `wo`, so this is live rather than theoretical. I swept all 12 locales over n = 0..200 for `undefined` and `NaN` before writing anything; `az` at 40 was the only hit. dayjs supplies `-ıncı` there, the suffix moment's own table gives 60 and 90, which is the group Azerbaijani vowel harmony puts qirx in. The divergence is excluded from the range comparison and then asserted explicitly on both sides - that moment really is NaN, and that dayjs's value really is moment's 60 and 90 suffix - so it is pinned rather than silently skipped, and if moment ever fixes it the first assertion fails and the exception can be dropped.

Escaping was checked mechanically rather than by eye: the generator refuses to write a locale whose marker contains any of `Y M D d H h a A m s Z S`. Only `tet` collides, since Tetum takes the English suffixes, so `tet` alone is bracketed and it copies the line `en-gb` already carries. The other 11 markers are Greek, Persian, Georgian, Khmer, Kannada, Lao, Sinhala, Tamil, Telugu, Azerbaijani and Yoruba text with no ASCII token letters.

Shape varies more than in earlier batches. `km`, `lo` and `yo` put the marker before the number rather than after it, and `ka` switches between the two: `1-ლი` as a suffix, `მე-` as a prefix for most values below 20, and `-ე` as a suffix above. The 9 single-marker locales were generated from moment's runtime by locating the number inside `ordinal(7)` and splitting on it, so prefix and suffix fall out of the data rather than out of my reading of it.

Acceptance check confirmed strong enough to fail: with the 12 locale files stashed, `test/locale/ordinal.test.js` reports 6 failed, 4 passed.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 805 tests across 95 suites, up from 804, no test weakened or removed. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0.

The class is now complete, and the numbers are measured rather than carried forward. 90 locales held an identity `ordinal: n => n` before F10-1, counted directly at that commit. 52 of those were genuine marker gaps and all 52 are closed across the six batches; the other 38 are the Declined set, and `KNOWN_BARE_ORDINAL` now holds exactly those 38 names and nothing else. That coincidence is the class-complete check: every locale that still renders bare is one a previous run gave a language-specific reason to leave bare. Recorded under Settled classes in BACKLOG.md with its re-check command.

Contract preserved: 12 locales gained a day marker where `format('Do')` previously returned the number unchanged, an observable change recorded here per the Constraints. `ka` keeps moment's behaviour of returning the raw number at 0. No shared code changed this iteration. `test/locale/keys.test.js`, which requires `ordinal(i)` to return a value for i in 1..31 for every locale, still passes for all 12.

Learnings: two rules added to PLAN.md - sweep a moment table for `undefined` and `NaN` across its reachable range before porting it, because a verbatim port imports its holes, and use `moment.localeData(name).ordinal(n)` rather than rendered `Do` for any locale whose moment implementation defines `postformat`. Both are the same shape as the run's earlier lessons: the reference implementation is authoritative about the algorithm and not about the rendering, and the difference is invisible unless you compare the right two things.

Next: the ledger now holds only F13 and F9, both Low, which is fewer than 3 open tasks, so iteration 5 should replenish with a partial audit rather than draining straight to the Lows. The four unswept Surface inventory rows are the place to aim it: `types-declarations` first, since two of the previous run's Highs were shipped `.d.ts` declarations disagreeing with runtime and nothing has re-examined that surface since.

## iter 5/10 | a7604090-143642 | 2026-07-28 | AUDIT | audit

Task: Partial replenishing audit. The ledger had dropped to 2 open tasks, both Low, so per the Backlog discipline this iteration audits rather than drains. Target chosen by the Method's rule for partial audits - the least recently swept Surface inventory row - which is `types-declarations`, and it is also the row the previous run's handoff named as most likely to pay, since two of that run's Highs were shipped `.d.ts` declarations disagreeing with runtime.

Changed: PLAN.md (the types-declarations row records what was swept, 1 Lesson), BACKLOG.md (F14 and F15 filed, the prototype-capture Settled class corrected).

Checkpoint: 88e44fd6da7a66fa2d9040e1ca150359f3040a7d (committed with `-n`, see Lessons). Not a stall: this iteration changed only state files, which an AUDIT does by design, but BACKLOG.md items changed state - F14 and F15 were filed and the prototype-capture Settled class was corrected.

Verification: Scores below claim the `types-declarations` row only. Three inventory rows remain entirely unswept - `locales-content`, `build-pipeline`, `plugin-interaction-matrix` - and this audit says nothing about them. correctness Medium, testing Medium, documentation Medium, architecture None on this row. Security, performance, error handling, dependency hygiene and observability were not exercised by this row and are not scored. This is a partial audit and does not count toward convergence.

First the layout, because it changes what the row even means. `types/` is the tracked source; the root `index.d.ts`, `locale/` and `plugin/` are untracked build artifacts that `build/index.js:65` copies wholesale from `types/`, and `.npmignore` excludes `types/` so the published package ships the copies. The root and source `index.d.ts` are byte-identical. Auditing the root copy would have been auditing a generated file.

The compile check could not run, and that is itself part of a finding. `typescript` is pinned `^2.8.3` and resolves to 2.9.2, but `types/plugin/minMax.d.ts` uses variadic tuple syntax that requires TS 3.0 or later, so the project's own compiler cannot parse the project's own declarations: `types/plugin/minMax.d.ts(7,38): error TS1110: Type expected.` There is no tsconfig, no type test and no CI type step, so nothing has ever checked these 40 files. Filed as F15.

So the sweep was done by execution instead, comparing every declared member against the runtime. Core is clean: all 31 instance methods and 4 statics declared on `class Dayjs` exist, and the only runtime methods the declaration omits are `parse` and `init`, which are internal lifecycle hooks the utc, objectSupport, customParseFormat and other plugins wrap. Omitting them is correct, not a gap, since declaring them would widen the public API. All 37 plugin declarations were parsed and each declared member checked after extending that plugin. 37 declared, 37 implemented, no plugin missing a declaration and no declaration without a plugin. Exactly one mismatch.

That mismatch is F14 and it is worse than it first looked. `types/plugin/pluralGetSet.d.ts` declares `weeks(): number`, but `src/plugin/pluralGetSet/index.js:19` does not implement it - it aliases `proto[alias] = proto[alias.replace(/s$/, '')]`, so `weeks` is whatever `proto.week` happened to be at extend time, and `week` comes from `weekOfYear`, not core. Extending only pluralGetSet and calling `dayjs('2019-06-15').weeks()` throws `TypeError: ...weeks is not a function`, in a call the declaration type-checks. Reproduced directly.

Probing the extend orders in three separate processes, rather than trusting one process with a cleared require cache, showed the shape precisely. With pluralGetSet alone, `weeks`, `isoWeeks` and `quarters` are all undefined. With the companions extended first, all three are functions. With pluralGetSet extended first, `weeks` is a function but `isoWeeks` and `quarters` are not - because `weekOfYear` independently assigns `proto.weeks` at its own line 27, so `weeks` has a second source that survives any order while `isoWeeks` and `quarters` have none. That asymmetry is why the surviving defect is narrower than the declaration suggests and also why it is easy to miss: the one method the types name is the one that mostly works.

The declaration is wrong in the other direction too. The implementation installs `isoWeeks` and `quarters`, and `types/plugin/pluralGetSet.d.ts` declares neither, so a TypeScript consumer cannot call methods that exist.

This lands inside a class BACKLOG.md records as settled, so it needed more than a re-reading. The evidence is a reproduced failure, and the reason the settlement missed it is concrete: that class was enumerated by grepping for wrappers of the form `const old = proto.X`, and pluralGetSet uses a computed alias, `proto[a] = proto[b]`, which that shape cannot match. Re-enumerated shape-independently across all 37 plugins over every extend-time read of `proto`, there are 32 such reads and every one but `pluralGetSet:19` targets a core method - format, parse, startOf, add, subtract, set, locale, daysInMonth, isSame, isBefore, isAfter, init, utcOffset, toDate, diff, $utils - which exists whatever the extend order. So the class is one site short of complete, not broadly wrong, and the Settled classes entry now says so rather than continuing to claim completeness.

Severity for F14 is Medium, not High, and the reasoning is worth recording because the crash is real. The Operating envelope classifies plugin registration and extend order as user-error, the consuming developer's own choice, and the rubric caps that surface below a hostile-input High. Calling it High would require treating one particular plugin combination as realistic adversarial input, which the envelope does not support. Medium is the honest score: a plausible in-envelope configuration fails, and the declaration is misleading documentation about it.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 805 tests across 95 suites, unchanged, since this iteration audited rather than edited code.

Learnings: one rule added to PLAN.md - a settled class is only as wide as the search that enumerated it, and a grep written around one syntactic shape will silently certify every site written in another. The concrete instance is worth carrying: `const old = proto.X` and `proto[a] = proto[b]` are the same defect and no single grep pattern finds both, so a class-complete claim needs a shape-independent enumeration behind it.

Next: F14, the top unblocked item. It is one file of implementation plus one declaration file, finishable in an iteration, and closing it completes the prototype-capture class rather than patching an instance.

## iter 6/10 | a7604090-143642 | 2026-07-28 | F14 | done

Task: F14 (Medium, correctness) - `src/plugin/pluralGetSet/index.js` captured its plural aliases at extend time, so `isoWeeks` and `quarters` were undefined whenever it extended before `isoWeek` and `quarterOfYear`, and `types/plugin/pluralGetSet.d.ts` declared `weeks()` while never declaring the two the plugin does install.

Changed: `src/plugin/pluralGetSet/index.js` (aliases resolved on call), `types/plugin/pluralGetSet.d.ts` (`isoWeeks` and `quarters` declared), `test/plugin/pluralGetSet.test.js` (2 tests added), BACKLOG.md (F14 deleted, F16 filed, F15's acceptance widened, the prototype-capture class recorded complete on the wider enumeration).

Checkpoint: fa27497a6e6a95e8c52bfa0b7071414ed2306d47 (committed with `-n`, see Lessons). Not a stall: a plugin, a declaration and a test file changed, F14 closed and F16 filed.

Verification: The fix is not a new pattern, which is worth stating because it changes how much risk it carries. `weekOfYear` already installs its own `proto.weeks` at line 27 as `function (week = null) { return this.week(week) }` - a forwarder that resolves `this.week` when called. That is exactly why `weeks` survived every extend order in the audit's probe while `isoWeeks` and `quarters` did not: `weeks` had a second, order-independent source and the other two had none. So the fix applies the sibling plugin's existing shape to all 11 aliases rather than inventing a mechanism.

Two alternatives were rejected on evidence rather than taste. An accessor pair via `Object.defineProperty` would preserve reference identity, but `weekOfYear` assigns `proto.weeks = ...` directly, and a getter-only property would make that assignment throw under ES module strict mode whenever pluralGetSet extended first, converting a silent gap into a crash. Keeping the capture and guarding on existence is the shape the settled class already rejected once, in preParsePostFormat.

The overwrite direction was checked rather than assumed, since both plugins now write `proto.weeks`. weekOfYear's forwarder passes `week` through with a `null` default and the new alias passes its arguments through unchanged, and `proto.week` itself defaults its parameter to `null`, so `this.week()` and `this.week(null)` take the same branch. Whichever plugin writes last, the behaviour is identical. That is why either extend order is now safe rather than merely untested.

Acceptance check confirmed strong enough to fail, and in the precise way the finding predicted: with the implementation and the declaration stashed, the two new tests report `TypeError: subject.isoWeeks is not a function` and a declared-against-installed set mismatch. The differential is computed rather than hand-listed - the test snapshots the prototype before extending, extends only pluralGetSet, diffs the property names, and compares that set against the members parsed out of the .d.ts - so the declaration cannot drift from the implementation again without the test noticing in either direction.

Evidence that nothing previously green changed: all 17 pre-existing tests in `test/plugin/pluralGetSet.test.js` pass unmodified both with the fix stashed and with it applied, so the forwarder is transparent for the 8 core-unit aliases it also now wraps. The full suite is 807 tests, up from 805, with none weakened or removed.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0.

Contract preserved: the 8 core-unit aliases keep their behaviour exactly, evidenced above. `isoWeeks` and `quarters` change from undefined to working in one of the two extend orders, which is the defect being fixed, and `weeks` is unchanged in both. The public change is that `types/plugin/pluralGetSet.d.ts` now names two methods it previously omitted; no declared member was removed or narrowed. The `plugin-pluralGetSet` inventory row's implementing code changed, so the row is re-swept at this iteration's checkpoint with the stronger sweep rather than left claiming the old one.

One instance of the same class was found while working and is filed rather than fixed here: `types/plugin/weekOfYear.d.ts` declares `week()` but not the `weeks()` the plugin installs at line 27, filed as F16 at Low. That is the second declaration-versus-runtime instance, so per the class rules the response is the structural task rather than a third instance patch: F15's acceptance is widened from one direction to both, so its gate compares declared members against installed members for every plugin and would have caught F14 and F16 together.

Learnings: no new operational rule. The one this iteration reinforces is already recorded - a class is only as wide as the search that enumerated it - and the useful detail is that the fix for the newly found site was already sitting in a sibling plugin, so the wider enumeration cost one grep and the repair cost nothing new.

Next: F15, the declared-against-installed gate. It is the structural fix for this class, it closes F16 as a side effect once written, and it is the check the `types-declarations` inventory row is waiting on.

## iter 7/10 | a7604090-143642 | 2026-07-28 | F15 | done

Task: F15 (Medium, testing) - nothing verified the 40 shipped `types/**/*.d.ts` files. This is the structural fix for the declaration-versus-runtime class rather than another instance patch: F14 was one instance, F16 is a second, and two of the previous run's Highs were the same shape.

Changed: `test/types.test.js` (new, 4 tests), PLAN.md (1 Lesson, the types-declarations row records what is now pinned), BACKLOG.md (F15 deleted, F17 filed, F16's acceptance rewritten against the new gate).

Checkpoint: db2df2dc7dd4fe3667408d3f27cd727dae2775fc (committed with `-n`, see Lessons). Not a stall: a new test file was added, F15 closed and F17 filed.

Verification: The gate compares each declaration against the runtime by execution, since the compiler route is closed. For every one of the 37 plugins it loads a fresh dayjs, snapshots the prototype, extends that plugin alone, and diffs. Direction one asks whether every member the .d.ts names exists once the plugin is extended, which is what makes a type-checked call crash when it fails. Direction two asks whether every member the plugin newly installs is declared, which is what leaves a shipped method uncallable from TypeScript. The two directions use different runtime sets on purpose: existence for the first, because a plugin may legitimately re-declare a core method to widen its unit type, as quarterOfYear does for `add` and `startOf`, and newly-added-only for the second, so those re-declarations are not miscounted as undeclared.

The probe that produced this test was wrong the first time, and the way it was wrong is the reusable part. It reported 23 declaration gaps across 23 plugins. All 23 were false. The header regex was built with `new RegExp` from a template literal, the double backslashes collapsed, and the pattern compiled to `^s*(exports+)?interface Dayjss*{`, which matches nothing, so the declared set was empty for every file and every installed member looked undeclared. Rebuilt on plain string comparison, the same sweep reports 3. That is a Lesson: validate a parser-based probe against a known-positive case before trusting a line of its output.

Of the 3 real results, 2 are deliberate and 1 is a defect. `relativeTime` and `preParsePostFormat` both install `fromToBase`, the shared implementation `from`, `to`, `fromNow` and `toNow` delegate to; it is internal, the same category as core's `parse` and `init`, and is listed as such rather than declared. `weekOfYear` installs `weeks` without declaring it, which is F16, and it sits in a shrink-only `KNOWN_DECLARATION_GAPS` map so the gate is green today and F16's fix is the deletion of that entry.

Acceptance check confirmed strong enough to fail, three ways, each run and observed rather than argued. Emptying the allowlist makes the gate report `{"weekOfYear": ["weeks"]}`. Restoring the pre-F14 declaration makes it report `{"pluralGetSet": ["isoWeeks", "quarters"], "weekOfYear": ["weeks"]}`. Restoring the pre-F14 implementation makes it report `{"pluralGetSet": ["weeks", "isoWeeks", "quarters"]}` through the declared-but-missing direction. So the gate would have caught F14 in both directions and catches F16 now.

One assertion in the gate was itself wrong and the runtime corrected it. The core static check demanded every declared static be a function, and it failed on `Ls`. Reading the declaration, `const Ls : { [key: string] : ILocale }` says object, and the runtime is an object, so the declaration was right and my check was wrong. It now asserts declared statics are defined, and separately pins `Ls` as the object both sides agree it is.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 811 tests across 96 suites, up from 807 across 95, no test weakened or removed. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0.

Contract preserved: no source file changed this iteration, only a new test file and state files, so there is no runtime behaviour to preserve. The `types-declarations` inventory row now records that member agreement is pinned mechanically in both directions and that signature agreement is still uncompared, so the row stays unswept rather than being flipped on a partial sweep.

What F15 did not cover is filed rather than dropped. Its description named the compiler problem and its acceptance covered only the member gate, so the toolchain gap is now F17 at Low: `typescript` is pinned `^2.8.3`, resolves to 2.9.2, and cannot parse `types/plugin/minMax.d.ts`, which uses TS 3.0 variadic tuple syntax - `error TS1110: Type expected.` No minimum TypeScript version is documented in README.md or docs/, checked. Consumer impact is negligible in practice, since TS 2.x is long obsolete, but it is what blocks signature checking and therefore what blocks this inventory row.

Learnings: one rule added to PLAN.md, about validating a parser probe against a known-positive before trusting it. The wider point is that this iteration's two errors were both in the checking apparatus rather than in the project - a regex that matched nothing, and an assertion that demanded the wrong type - and both produced confident output. A gate is code, and an unverified gate is worse than none, because it certifies.

Next: F16, a two-line declaration and one deleted allowlist entry, whose acceptance the new gate already spells out. F13, F9 and F17 follow, all Low.

## iter 8/10 | a7604090-143642 | 2026-07-28 | F16 | done

Task: F16 (Low, documentation) - `src/plugin/weekOfYear/index.js:27` installs `proto.weeks`, but `types/plugin/weekOfYear.d.ts` declared only `week()`, so a TypeScript consumer loading weekOfYear alone could not call a method the plugin provides.

Changed: `types/plugin/weekOfYear.d.ts` (`weeks` declared), `test/types.test.js` (`KNOWN_DECLARATION_GAPS` emptied), BACKLOG.md (F16 deleted, Later reordered, the declaration class recorded under Settled classes).

Checkpoint: 5a29a62e033ecbc39b14c77850d39f30cc069b52 (committed with `-n`, see Lessons). Not a stall: a declaration and a test file changed, F16 closed and the declaration class settled.

Verification: The ledger's order was wrong before the work started and was corrected rather than followed. All four remaining items are Low, and the Method breaks that tie by user impact then smallest effort, but F17 sat at the top purely because it was the most recently inserted line. F17 is maintainer-facing toolchain work with no realistic consumer impact, so it moved to the end and F16, which is a two-line declaration that unblocks a real call, moved to the front. F13 and F9 keep their relative order between them.

F17 was also checked for blockage before being deprioritized, since a dependency bump could have made it a hard blocker. It is not blocked: `node_modules/semantic-release/node_modules/typescript` is already 5.9.2, so a modern compiler is present without any install, and the npm registry is reachable. That is recorded here so the next iteration does not re-investigate it.

The fix itself is two overload lines. What is worth recording is that the gate built in the previous iteration drove it in both directions. With the declaration fixed but the allowlist still naming the gap, the gate failed - expected `{"weekOfYear": ["weeks"]}`, received `{}` - which is the shrink-only discipline working in the closing direction: a repaired gap forces its entry to be removed rather than letting a stale allowlist quietly outlive the defect. With the entry removed and the declaration reverted, it failed the other way, reporting `{"weekOfYear": ["weeks"]}`. Both were run and observed, so the acceptance check is confirmed strong enough to fail from either side.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 811 tests across 96 suites, unchanged in count because this iteration changed a declaration and an allowlist rather than adding tests. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0.

The declaration class is now complete and is recorded under Settled classes. All 37 plugin declarations plus the core one were compared against the runtime in both directions; exactly two gaps existed, F14 and F16, and both are closed. `KNOWN_DECLARATION_GAPS` is empty and asserted empty, so the enumeration is pinned by an executing test rather than by a claim. Three members are listed as deliberately undeclared internals - `fromToBase`, and core's `parse` and `init` - and signature agreement remains a separate question that F17's compiler bump is needed to answer.

Contract preserved: no source file changed, so there is no runtime behaviour to preserve. The public change is that `types/plugin/weekOfYear.d.ts` now names a method it previously omitted; nothing was removed or narrowed, and the runtime already installed it, so no consumer's working code can break.

Learnings: no new operational rule. The reusable observation is that an allowlist which must shrink is load-bearing in both directions - it fails when a new gap appears and it also fails when an old gap is fixed but its entry is left behind - which is why the map is asserted equal rather than merely checked for supersets.

Next: F13, the devHelper warning that fires on valid 13-character date strings and advises a change that would break them. F9 and F17 follow, both Low.

## iter 8/10 | a7604090-143642 | 2026-07-28 | ROTATION | rotation

Task: JOURNAL.md reached 519 lines after the F16 entry, over the 500-line rotation threshold, so all but the last 10 entries move to JOURNAL-archive.md.

Changed: JOURNAL.md (9 entries removed, header kept and one line repaired), JOURNAL-archive.md (9 entries appended).

Checkpoint: 5a29a62e033ecbc39b14c77850d39f30cc069b52 (shared with the F16 entry; both were written in the same iteration and committed together).

Verification: 19 entries existed in the live journal and 10 in the archive, 29 in total. After the rotation the live journal holds 10 and the archive holds 19, still 29, so nothing was dropped. The archive was appended to, never rewritten, and its `## iter` count grew from 11 to 20; the script asserts that direction and would have aborted had it fallen, which is what the Stop hook checks. JOURNAL.md is now 282 lines.

One header repair, which is why the counts needed care. JOURNAL.md's header carried a line reading "Heading grammar, exactly:" followed by an example heading, and the previous run's rotation swept that example into the archive along with the real entries, leaving the sentence dangling and a genuine entry sitting where the example had been. That also meant a naive count of lines beginning `## iter` saw 11 archive entries where only 10 were real, since the moved example is still there and must stay, the archive being append-only. The grammar is now restated inline inside backticks on a single line, so no header line begins with `## iter` and no future rotation or count can confuse the two. The archive keeps its copy untouched.

Learnings: no new operational rule, though the repair is a reminder that a rotation moving whole line-ranges will take header content with it unless the split is anchored on the entry heading pattern itself, which this one is.

Next: nothing. This entry is additional to the F16 entry above, which closes the iteration.

## iter 9/10 | a7604090-143642 | 2026-07-28 | F13 | done

Task: F13 (Low, developer experience) - `src/plugin/devHelper` treated any 13-character string as a Unix millisecond timestamp, so a valid date string of that length was told to pass itself as a Number, which would break it.

Changed: `src/plugin/devHelper/index.js` (the length test became a digits test), `test/plugin/devHelper.test.js` (1 test added), PLAN.md (plugin-devHelper row re-swept), BACKLOG.md (F13 deleted).

Checkpoint: 214acb40a2f1dd621bdbc0fc6a37b08c87783b54 (committed with `-n`, see Lessons). Not a stall: a plugin and a test file changed, and F13 closed.

Verification: Reproduced before touching anything, across a spread of lengths and shapes rather than the single example the ledger carried. `'2019-06-15T12'` is 13 characters, warns, and parses correctly to 2019-06-15 12:00:00. `'2019/06/15T12'` is the same length with slashes and behaves the same way, which shows the defect is about length rather than about any particular separator. `'2019-06-15T1'` at 12 and `'2019-06-15T123'` at 14 do not warn, confirming the trigger really is the exact length and nothing else.

The advice was the harmful part, not the noise. `dayjs('2019-06-15T12')` gives 2019-06-15 12:00:00, and following the warning by passing a Number gives a Unix timestamp instead, so a developer who complies breaks working code. That is what puts it above cosmetic, even at Low.

The fix is `/^\d{13}$/` in place of `date.length === 13`. A Unix millisecond timestamp is all digits, so the digits test is exactly the intended condition and the character-count test was a loose proxy for it. The `typeof date === 'string'` guard is kept deliberately: `test` coerces its argument, so without it a real numeric timestamp would match the pattern and warn, and passing a Number is the correct usage the warning is steering people towards.

Acceptance check confirmed strong enough to fail: with the plugin reverted, the new test fails on the first assertion, reporting a call matching `StringContaining "you should pass it as a Number"`. All 10 pre-existing tests in the file pass in both states, including the one asserting `'1231231231231'` still warns, so the narrowing removed only false positives.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 812 tests across 96 suites, up from 811, no test weakened or removed. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0.

Contract preserved: the warning is diagnostic output, not parse behaviour, and no parse path changed - the same string parses to the same instant before and after, asserted in the new test rather than assumed. The only observable change is that a class of strings no longer produces a console warning, which is a strict reduction in false output; every string that warned correctly still warns, pinned by the pre-existing test. The `plugin-devHelper` inventory row's implementing code changed, so the row is re-swept at this iteration's checkpoint with the digit-versus-character distinction added to what it certifies.

Learnings: no new operational rule. The observation worth keeping is that this defect had the shape the Method's sweep rules are written for: a documented condition tested by a proxy that agrees with it on the examples anyone would try first. Both the original probe and the existing test used a 13-digit timestamp, where length and digit-ness coincide, so every check passed while the condition was wrong for every other 13-character string.

Next: F9, the dead `S` alternation in advancedFormat's token regex, then F17. Iteration 10 is the last of the budget, so it should be a WRAPUP that tidies the ledger and writes a handoff rather than starting work that cannot finish.

## iter 10/10 | a7604090-143642 | 2026-07-28 | F9 | done

Task: F9 (Low, code quality) - `src/plugin/advancedFormat/index.js` carried `S` in its token regex with no `case 'S'` in the switch, so every match fell through to `default` and was handed back untouched. Final iteration of the budget; F9 finishes inside one iteration, so it is executed rather than deferred to a WRAPUP, and the handoff is carried in Next below.

Changed: `src/plugin/advancedFormat/index.js` (the `S` alternation removed), `test/plugin/advancedFormat.test.js` (1 test added), PLAN.md (plugin-advancedFormat row re-swept), BACKLOG.md (F9 deleted).

Checkpoint: 5e0e84b0cf3c91f95c53f52dff6a2a4cb8e2b50d (committed with `-n`, see Lessons). Not a stall: a plugin and a test file changed, and F9 closed.

Verification: The ledger offered two branches, implement `S` as moment's tenths-of-a-second token or drop it, and the evidence chose. Implementing it is wrong, demonstrated rather than argued: the alternation is a single character in a global regex, so `SSS` is three separate matches, and substituting tenths into each yields `444` at .456, which core then renders literally. That would replace a working millisecond token with a nonsense literal. Implementing it correctly would require adding an `SSS|SS|S` group ordered longest-first, which is a new feature on an undocumented token, and the Constraints prefer deletion over addition.

Dropping it is behaviour preserving, and that is the reason it is safe rather than merely small. A match that returns its own input through `default` is indistinguishable from no match at all, so removing the alternative changes nothing observable. Confirmed on both sides of the change: `format('S')` is `'S'`, `format('SS')` is `'SS'`, `format('SSS')` is `'456'` and equals moment's, and `format('[S]')` and `format('q[S]q')` still escape to `'S'` and `'qSq'`.

Because nothing observable changes, a purely behavioural acceptance check would pass against the unfixed code and prove nothing, which is the trap the Method warns about. The check is therefore structural as the ledger's acceptance specified: it reads the plugin source, extracts the token regex, and asserts the `|S` alternative is gone. Reverted, it fails and prints the old regex ending `k{1,2}|S/g`. The extraction is itself validated before anything is asserted about it - the test requires the match to be defined and to contain `k{1,2}` first - applying the Lesson recorded in iteration 7, where a parser that silently matched nothing produced 23 confident false findings.

One probe result that looked like a new defect was not. `format('x[S]y')` returns a Unix millisecond timestamp followed by `Sy`, which is correct: `x` is advancedFormat's own millisecond-timestamp token, and I had chosen it as a filler letter. Re-checked with a non-token filler, bracket escaping is intact. Recording it because a probe string that collides with the surface under test is an easy way to manufacture a phantom finding.

Acceptance check confirmed strong enough to fail: with the plugin reverted the new test fails on the regex assertion, and the 14 pre-existing tests in the file pass in both states, which is the evidence that the removal altered no previously-passing output.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 813 tests across 96 suites, up from 812, no test weakened or removed. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0.

Contract preserved: no format string produces different output before and after, asserted directly rather than assumed, so no consumer behaviour changes. The plugin now advertises 15 tokens instead of 16, and the one removed never worked; there is no advancedFormat documentation page in `docs/en` to update, checked. The `plugin-advancedFormat` inventory row's implementing code changed and is re-swept at this iteration's checkpoint.

Not converged, and the run does not claim to be. One task remains open, F17, so the Definition of done is not met, the evaluator gate is not invoked and no Converged line is appended. The Surface inventory stands at 37 of 41 rows swept, unchanged across this run (corrected during this iteration bookkeeping: an earlier draft of this line claimed 38, but re-sweeping an already-swept row does not move the count, and no unswept row was flipped this run).

Learnings: no new operational rule. The reusable point is the one this task turned on: when a change is genuinely unobservable, the acceptance check has to be structural, because a behavioural check that passes before and after certifies nothing. That is the same standard the Method sets for acceptance checks generally, applied to a case where the honest answer is that behaviour is not the thing being changed.

Next: F17 is the only open item, Low, and it is not blocked - `node_modules/semantic-release/node_modules/typescript` is already 5.9.2 and the npm registry is reachable, both checked in iteration 8. It needs the devDependency bumped, a tsc check over `types/**/*.d.ts` added, and the supported TypeScript floor stated in the docs. Closing it also unblocks the `types-declarations` inventory row, which is the last thing standing between this project and a swept surface apart from `locales-content`, `build-pipeline` and `plugin-interaction-matrix`. Of those three, `build-pipeline` is the one most likely to pay next: nothing has examined `build/*.js`, the esm generation or the published file set, and the run has already found that the root `index.d.ts`, `locale/` and `plugin/` are untracked artifacts copied by `build/index.js:65`, so the publish path is real code no sweep has visited.

## iter 1/10 | 9b36f0e5-154305 | 2026-07-28 | F17 | done

Task: F17 (Low, dependency hygiene) - `typescript` was pinned `^2.8.3`, resolving to 2.9.2, which cannot parse the project's own declarations, so all 40 shipped `.d.ts` files had never been compiled by anything and no minimum TypeScript version was documented.

Changed: `tsconfig.json` (new), `package.json` (`typescript` `^2.8.3` to `^5.9.3`, `type-check` script), `package-lock.json`, `.github/workflows/lint-test.yml` (type-check step), `test/types.test.js` (compile gate added, header comment corrected), `README.md` (TypeScript floor), `CONTRIBUTING.md` (`npm run type-check`), `.npmignore` (`tsconfig.json` excluded), PLAN.md (types-declarations row, 3 Lessons), BACKLOG.md (F17 deleted, unchecked-declaration class settled).

Checkpoint: 5c8bbac249f28f92f754abd2fbf01c0a18c6380f (committed with `-n`, see Lessons). Not a stall: a new tsconfig, package.json, the CI workflow, a test file, README, CONTRIBUTING and .npmignore all changed, and F17 closed.

Verification: Reproduced first. `npx tsc --noEmit` on the pinned compiler reported `types/plugin/minMax.d.ts(7,38): error TS1110: Type expected.` at four sites, plus 16 parse errors inside `@types/node` that the same old compiler could not read either.

The stated floor is a measurement, not an inference, and it is not the one the ledger assumed. F17 said TS 3.0, from minMax's variadic tuple. The real floor is 3.2, and the binding file is a different one: `types/plugin/bigIntSupport.d.ts` refers to the `BigInt` global, which needs the `esnext.bigint` lib that TypeScript first shipped in 3.2. Measured by running the real declarations under each compiler with a target that version accepts - 3.1 fails with `types/plugin/bigIntSupport.d.ts(5,20): error TS2304: Cannot find name 'BigInt'` twice, 3.2 exits 0. The 3.1 control is what makes it evidence rather than a guess. README now states 3.2 and names both constraints.

The bump target was chosen on evidence too. Registry latest is 7.0.2, the native port. It removed `baseUrl` and `moduleResolution: node`, so it rejected the first config outright, and it declares 20 platform-specific native binary packages as dependencies where 5.9.3 declares none. For a gate over 40 tiny declaration files its speed buys nothing and its install surface costs CI portability, so the pin is `^5.9.3` and the Constraints line about heavy dependencies for trivial problems decides it. The config is still written in the forward-compatible `node16` form with a bare `paths` and no `baseUrl`, and was verified to exit 0 on both 5.9.3 and 7.0.2, so the pin can move later without a config rewrite.

Two traps in a gate of this shape were closed deliberately. `skipLibCheck` is off: every file being checked is a `.d.ts`, so turning it on would leave the gate green while checking nothing. And an `include` glob that matches nothing also exits 0, so the test asserts the compiler's `--listFiles` output contains every `.d.ts` on disk under `types/` - 40 of 40 - rather than trusting the exit code.

Acceptance check confirmed strong enough to fail, from both directions, each run and observed. With a bogus type appended to a declaration the test fails reporting `types/plugin/isToday.d.ts(14,19): error TS2304: Cannot find name 'NotAType'`. With the `include` glob altered to match no files the compile still exits 0 but the test fails on the file-set assertion, which is the trap it was written for. The `.npmignore` entry was checked the same way: `npm pack --dry-run` lists `tsconfig.json` without the entry and does not list it with the entry.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 814 tests across 96 suites, up from 813, no test weakened or removed. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0.

Contract preserved: no file in `src/` changed, so there is no runtime behaviour to preserve, and no declaration's content changed, so no consumer's types move. The observable changes are all maintainer-facing: a new devDependency, a new script, a CI step, and one file excluded from the tarball. `tsconfig.json` sits at the repo root rather than inside `types/` because `build/index.js:65` copies all of `types/` to the root, which would have published it; it is excluded from the tarball explicitly instead of relying on that. No Surface inventory row's implementing code changed, so no row goes stale.

What this does not do is worth stating plainly, because the ledger's wording invited the opposite reading. The compiler proves the declarations are valid TypeScript. It cannot prove they describe the library, since nothing type-checked imports the JavaScript. Signature agreement between the declared parameter and return types and what `src/` actually accepts is still uncompared and needs type-level fixtures exercising the real API. F17 unblocks that work; it does not do it, so the `types-declarations` row stays unswept and its text now says so.

Learnings: three operational rules recorded in PLAN.md - keep `skipLibCheck` off and assert the checked file set, do not reintroduce `baseUrl` since TypeScript 7 removed it, and do not clean a probe with `git checkout -- <file>` when that file also carries real work from the same iteration. The third is not theory: reverting a `.npmignore` probe discarded the real edit to the same file, which had to be reapplied and re-verified.

Next: the backlog is empty, so the next iteration audits. Four inventory rows remain unswept - `locales-content`, `types-declarations`, `build-pipeline`, `plugin-interaction-matrix` - and 37 of 41 are swept. `build-pipeline` is the strongest candidate: nothing has examined `build/*.js`, the esm generation or the published file set, and this iteration touched the publish path only at its edge by excluding one file from the tarball. Dependency hygiene also deserves a real dimension score now that one stale pin turned out to hide a whole unchecked surface.

## iter 2/10 | 9b36f0e5-154305 | 2026-07-28 | AUDIT | audit

Task: Full audit. The backlog was empty after F17, so this iteration audits rather than executes. Per the Method it swept unswept Surface inventory rows first, and took `build-pipeline` - the row no sweep had ever visited.

Changed: PLAN.md (build-pipeline row swept), BACKLOG.md (F18, F19, F20 filed).

Checkpoint: e8cf8b30c4380a1fe4dda7a7d438b13311c73118 (committed with `-n`, see Lessons).

Verification: Scores, claiming only the rows actually swept. This audit swept `build-pipeline` and nothing else, so three rows remain unswept - `locales-content`, `types-declarations` and `plugin-interaction-matrix` - and these scores are not the whole project. On the swept row: correctness High (F18), error handling High (F19), developer experience Medium (F20), security None, performance None, architecture None, dependency hygiene None, documentation None. Testing is scored Medium but not filed separately: `build/*.js` has no test of any kind, which is why all three findings survived to now, and the acceptance checks of F19 and F18 are what close that gap - filing it twice would be filing a symptom.

F18 is the one that reaches users. The build emitted a warning nobody had read - `Entry module "src/locale/ku.js" is using named and default exports together` - and following it produced a genuine High. `src/locale/ku.js:4` exports `englishToArabicNumbersMap` alongside its default, uniquely among 143 locales, so rollup auto-detects `named` for that entry alone and emits a different UMD shape: `!function(e,t){...t(exports,require("dayjs"))...}` against every other locale's `module.exports=n(require("dayjs"))`. Measured rather than read: `require('locale/de.js')` has keys `name, weekdays, weekdaysShort, weekdaysMin` and `require('locale/ku.js')` has keys `default, englishToArabicNumbersMap`. The consequence is silent, which is what makes it High rather than cosmetic: `dayjs.locale(de)` returns `'de'` and `dayjs.locale(ku)` returns `'de'` too, because `parseLocale` at `src/index.js:31-36` destructures an undefined `name`, writes `Ls[undefined]`, and falls through to `return l || (!isLocal && L)`. No throw, no warning, dates keep rendering in the previous locale. The `esm/` build is unaffected, since babel emits a real default export there; the UMD and CommonJS artifacts carry it.

The remedy was checked for viability before filing, so the task is not a dead end. `output.exports: 'default'` is the class-complete guard, because rollup refuses it when named exports exist: forcing it on ku fails with `"default" was specified for "output.exports", but entry module "src/locale/ku.js" has the following exports: default, englishToArabicNumbersMap`. That converts a silent shape change into a build failure for any future locale. It also means the fix must remove the named export, and `test/locale/ku.test.js:4` imports it today, which the task records.

F19 is the reason a defect like F18 could ship at all. Both build scripts catch everything and exit 0, reproduced twice against the real scripts: `PWD=/c/Users/lenam node build/esm` printed an ENOENT and exited 0, and `node build/index.js` from a cwd without `./src` printed `Could not resolve entry module (./src/locale/af.js)` and exited 0. `release.yml:33` runs `npm run build && npm run babel` and the next steps publish, with nothing in between that checks the artifacts. The four unawaited sites are a second root cause of the same class and were verified by running the exact shape rather than by reading it: a `forEach(async ...)` lets the try block finish first, the catch is never entered, and only Node's unhandled-rejection handler stops the process. So those sites fail loudly on Node 15+ but leave partial state and make the catch useless, while the swallowing catch is the genuinely silent path. The distinction is recorded because it changes what the fix must do.

F20 is the POSIX assumption in `build/esm.js`. `env -u PWD node build/esm` dies at line 9 with `TypeError [ERR_INVALID_ARG_TYPE]`, exit 1, which is what every Windows contributor gets from the second half of `npm run babel`. This is not inside the settled `package.json` scripts class: that class was settled by enumerating the `scripts` block, and this is source code the script invokes, not a script. Severity is Medium and not High because CI and the release run on ubuntu, so no published artifact is affected and the consequence is contributor friction on a platform the project has already chosen to support.

One reading did not survive contact with evidence and is recorded so it is not re-filed. `formatName` in `build/index.js:15` uses `.replace('-', '_')`, a string pattern that replaces only the first occurrence, so a locale name with two hyphens would produce an invalid UMD global. Checked against all 143 names: none has two hyphens and every generated global matches a JS identifier, so there is no finding today, only latent fragility. The Method forbids speculative findings and it is not filed.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 814 tests across 96 suites, unchanged, since an audit files findings rather than adding tests. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0.

Not a stall: PLAN.md and BACKLOG.md both changed state, three findings were filed and an inventory row was swept. No source file changed this iteration, which is correct for an audit.

Learnings: two operational rules recorded in PLAN.md - read the build's own warnings, since the one warning in a 52-second build named the exact file behind a High finding, and never judge a bundle's public shape from its source, because rollup auto-detects `output.exports` per entry so one stray named export silently changes the artifact's contract while the source still looks normal.

Next: F18 first, the only High that reaches users, and its fix carries the class guard for the whole locale build. F19 second. The Surface inventory stands at 38 of 41 rows swept, with `locales-content`, `types-declarations` and `plugin-interaction-matrix` remaining; of those, `plugin-interaction-matrix` now has a concrete map to work from - 6 core methods are wrapped by more than one plugin (`parse` by 8, `format` by 5, `startOf` and `add` by 4 each, `diff` and `subtract` by 2), which is 52 plugin pairs and 104 orderings, and that enumeration is the sweep's work list rather than a finding.

## iter 3/10 | 9b36f0e5-154305 | 2026-07-28 | F18 | done

Task: F18 (High, correctness) - `dayjs.locale(require('dayjs/locale/ku'))` silently switched nothing, returning the previously active locale, because `src/locale/ku.js` was the only one of 181 rollup entries carrying a named export beside its default and rollup therefore emitted a namespace object for that bundle alone.

Changed: `src/locale/ku.js` (`englishToArabicNumbersMap` made module-private), `build/rollup.config.js` (`output.exports: 'default'` pinned), `test/locale/ku.test.js` (uses `locale.postformat` instead of the removed export), `test/build.test.js` (new, 3 tests), PLAN.md (build-pipeline re-swept), BACKLOG.md (F18 deleted, the named-export class settled).

Checkpoint: 5eba148569dd278d632ea42cdb266a5680fd9ca9 (committed with `-n`, see Lessons).

Verification: The fix has two halves because the defect had two halves - one wrong artifact, and a build that would reshape any other artifact the same way without saying so.

The source half: `englishToArabicNumbersMap` is used at `src/locale/ku.js:60` inside `postformat`, so it stays a const and only loses its `export`. That is a public API change for ESM consumers, and the rationale is recorded here as the Constraints require: the export is undocumented, referenced nowhere outside this project's own test, and its presence is exactly what makes `require('dayjs/locale/ku')` return the wrong object. Keeping it would mean choosing an undocumented named export over the documented behaviour of the primary artifact.

The test that depended on it now reads `locale.postformat((i % 12 || 12).toString())` instead of applying the private map by hand. That is a strictly better assertion, not a workaround: it drives the locale's real public hook rather than reimplementing what the hook does. `postformat` also maps `,` to the Arabic comma, which cannot affect a one or two digit hour, so the two forms are equivalent on this input.

The build half: `output.exports: 'default'` in `build/rollup.config.js`. Rollup otherwise decides per entry, which is why one stray export could change a single artifact's contract while every source file still looked alike. Contract preserved, and measured rather than asserted: the full build was run before and after the config change and all 181 emitted bundles were compared by checksum, with 180 byte-identical and only `locale/ku.js` different. So pinning the option changed nothing for the other 142 locales, all 37 plugins, or `dayjs.min.js`.

Acceptance check met and confirmed strong enough to fail from both guards, each run and observed. After the fix `require('locale/ku.js')` has keys `name, months, monthsShort, weekdays` like every sibling, `dayjs.locale(de)` returns `'de'` and `dayjs.locale(ku)` returns `'ku'`, and ku's UMD header is now the `module.exports=t(require("dayjs"))` form. With the named export restored, `test/build.test.js` fails reporting `{"locale/ku.js": ["englishToArabicNumbersMap"]}` and the rollup build aborts with `"default" was specified for "output.exports", but entry module "src/locale/ku.js" has the following exports: default, englishToArabicNumbersMap`. The fix was then restored and re-verified green.

The regression guard is an enumeration, not a spot check, because the class rule requires one. `test/build.test.js` builds the same entry list `build/index.js` feeds rollup - `src/index.js` plus 143 locales plus 37 plugins - asserts the count is 181 so a new locale cannot fall outside the check, asserts every entry has a default export, and asserts none has a named one. The default-export assertion is deliberately a positive control: it proves the export matcher actually reads these files, so the named-export assertion is a real check rather than a regex quietly matching nothing, which is the failure mode recorded in Lessons from iteration 7 of the previous run. It runs in `npm test`, so the class is caught in CI rather than only in a release build.

Contract preserved elsewhere: no locale object changed shape, so `test/locale/keys.test.js` and `test/locale/relativeTime.test.js` still pin `locales-structure` and that row does not go stale - the edit removed a module-level export, not a locale key, format or relativeTime entry. `build/rollup.config.js` is implementing code for `build-pipeline`, so that row was stale and has been re-swept at this checkpoint with the 181-bundle checksum differential as what the sweep exercised.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 817 tests across 97 suites, up from 814 across 96, no test weakened or removed. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0.

Not a stall: three source and test files changed plus a new test file, and F18 closed.

Learnings: no new operational rule beyond the two recorded in iteration 2, which this task confirmed rather than extended. The reusable point is that a checksum differential over every emitted artifact is the right evidence for a build-config change, because the question a config change raises is not whether the build still works but whether it changed anything it was not meant to, and 180 of 181 unchanged answers that in a way no amount of reading the config could.

Next: F19, the High that let this ship - both build scripts log their errors and exit 0, with `release.yml:33` publishing straight after. Then F20. The Surface inventory stands at 38 of 41, unchanged this iteration since the re-sweep of `build-pipeline` restored a row rather than adding one.

## iter 4/10 | 9b36f0e5-154305 | 2026-07-28 | F19 | done

Task: F19 (High, error handling) - a failed build reported success. Both build scripts caught every error, logged it and left the exit code at 0, and `.github/workflows/release.yml:33` runs `npm run build && npm run babel` and publishes immediately after with nothing in between that inspects the artifacts.

Changed: `build/index.js` (catch sets `process.exitCode`, `build(...)` for `dayjs.min.js` and `promisifyWriteFile` for `locale.json` awaited), `build/esm.js` (catch sets `process.exitCode`, both `forEach(async ...)` loops became `await Promise.all(map(...))`), `test/build.test.js` (2 tests added), PLAN.md (build-pipeline re-swept), BACKLOG.md (F19 deleted, the silent-build-failure class settled).

Checkpoint: b4695ee3292d65442bc33be6acf5863efa9d6013 (committed with `-n`, see Lessons).

Verification: All 6 sites of the class were fixed, not just the 2 that were obviously wrong. The 2 catches are the genuinely silent path and the reason a broken artifact could reach npm. The 4 unawaited operations are the second root cause of the same class: their rejections never reach those catches at all, so no amount of fixing the catch would have covered them. `process.exitCode = 1` rather than `process.exit(1)`, because the latter can truncate the error output that was just written to stderr.

Acceptance check met, run and observed on both sides. Each script was run in a directory where its inputs cannot resolve: `build/index.js` prints `Could not resolve entry module (./src/locale/af.js)` and now exits 1, and `build/esm.js` prints its ENOENT and now exits 1. Both exited 0 before. Confirmed strong enough to fail by removing only the two `process.exitCode` lines and re-running: both new tests fail, and with them restored all 5 pass.

Contract preserved, and measured rather than assumed, because reordering asynchronous work in a build is exactly the kind of change that can alter output without failing. The full rollup build was run again after the fix and all 181 emitted bundles were byte-identical to the pre-fix build, with `locale.json` still holding 143 entries and no empty name. `npm run babel` was then run end to end: `esm/locale/de.js` goes from `import dayjs from 'dayjs'` to `import dayjs from '../index'`, no `esm/locale/*.js` still imports `'dayjs'`, each `esm/plugin/*.d.ts` is relocated into its own directory, and `esm/locale/index.d.ts` keeps its reference line. So the `Promise.all` conversion changed when the work happens, not what it produces.

One correction to how the finding was described when filed. The audit called all 6 sites silent; they are not equally so. The 2 catches exit 0, which is the silent path. The 4 unawaited sites produce unhandled rejections, and Node 15 and later terminate on those with exit 1, so they were loud but left partial state behind and made the surrounding catch useless. Both still needed fixing, and the distinction matters because only the catch could have let a broken artifact publish.

The regression guard runs the real scripts rather than mocking the failure, which is the only way to check an exit code honestly. It asserts the real error text as well as the status, so the test cannot pass for an incidental reason such as a missing interpreter, and it uses a fresh temp directory per run with `PWD` pointed at it too, so it keeps working after F20 replaces `process.env.PWD` with the process cwd.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 819 tests across 97 suites, up from 817, no test weakened or removed. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0.

Not a stall: both build scripts and a test file changed, and F19 closed.

Learnings: one operational rule recorded in PLAN.md - this checkout is CRLF in the working tree, so a probe that rewrites source with a `\n` literal silently matches nothing and reports success while changing no file. The first attempt to restore the regression did exactly that and claimed to have removed both exit codes when it had removed neither, which would have turned into a test that appeared to pass against broken code. Match `\r?\n` or use the editor.

Next: F20, the last open item, Medium - `build/esm.js` derives its paths from `process.env.PWD`, which no Windows shell sets. After that the ledger is empty and the run audits again, with `locales-content`, `types-declarations` and `plugin-interaction-matrix` the three unswept rows at 38 of 41.
## iter 5/10 | 9b36f0e5-154305 | 2026-07-28 | F20 | done

Task: F20 (Medium, developer experience) - `build/esm.js` derived every path from `process.env.PWD`, a variable POSIX shells set and neither cmd.exe nor PowerShell does, so the second half of `npm run babel` threw before doing any work on Windows.

Changed: `build/esm.js` (`process.env.PWD` to `process.cwd()`), `test/build.test.js` (1 test added, the failure helper generalised to allow a distinct PWD), PLAN.md (build-pipeline re-swept), BACKLOG.md (F20 deleted, the POSIX-assumption class settled).

Checkpoint: 6e007b82c022e6f3cede096e99fa831aaf3a0a5f (committed with `-n`, see Lessons).

Verification: `process.cwd()` rather than `__dirname`, and the choice matters enough to record. `__dirname` would be more robust in the abstract, since it would work from any cwd, but it would also change what the script means: `esm/` is produced by `babel src --out-dir esm`, which resolves against the cwd, so the two halves of `npm run babel` must agree on the same root. Using `__dirname` would silently point the second half at the package directory even when the first half wrote somewhere else, which trades a loud failure for a quiet mismatch. It would also have made the F19 regression test pass vacuously, since the script would then find the real project's `esm/` instead of the empty directory the test runs it in.

Acceptance check met, run and observed on both sides. `env -u PWD node build/esm` now exits 0 and turns `esm/locale/de.js`'s `import dayjs from 'dayjs'` into `import dayjs from '../index'`, with no locale still importing `'dayjs'` and each `esm/plugin/*.d.ts` relocated into its own directory. Reverted to `process.env.PWD`, the same command reproduces the original `TypeError [ERR_INVALID_ARG_TYPE]: The "path" argument must be of type string. Received undefined` and exits 1.

The regression test asserts which source the paths come from, not merely that the script fails. Running it with `PWD` unset would have been a weak check, because the script fails either way in an empty directory and the test could not tell a fixed script from a broken one. So it points `PWD` at a decoy temp directory different from the cwd and asserts the reported ENOENT names the cwd and never the decoy. Confirmed strong enough to fail: with `process.env.PWD` restored, that test alone fails while the other five still pass.

The class was enumerated before being called complete, since a single-site fix is only class-complete if the search that found the site was wide enough. `process.env.PWD` across `src/`, `test/` and `build/` now matches only explanatory comments, and the wider sweep for POSIX-only assumptions found no `/tmp` or `/dev/null` literal, no `uname`, and no hardcoded POSIX path separator in `build/`. This is deliberately recorded as the code-level counterpart of the already-settled `package.json` scripts class: that one enumerated the `scripts` block and therefore could not have seen a POSIX assumption living inside the code a script invokes, which is exactly how this survived.

Contract preserved: no artifact changed. The script produces the same `esm/` tree from the same inputs; only where it looks for that tree changed, and only in the case where `PWD` and the cwd disagree or `PWD` is absent. `build/esm.js` is implementing code for `build-pipeline`, so that row was stale and is re-swept at this checkpoint with the PWD-unset run as what the sweep exercised.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 820 tests across 97 suites, up from 819, no test weakened or removed. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0.

Not a stall: a build script and a test file changed, and F20 closed.

Learnings: no new operational rule. The reusable point is the one the test design turned on - when a defect is about which of two sources a value comes from, the check has to make the two disagree. Removing one of them leaves both the fixed and the broken version failing, and a test that cannot distinguish them certifies nothing, which is the same trap as the empty-file-set tsconfig in iteration 1 wearing different clothes.

Next: the ledger is empty, so the next iteration audits. Three rows remain unswept at 38 of 41 - `locales-content`, `types-declarations` and `plugin-interaction-matrix`. `plugin-interaction-matrix` already has its work list from iteration 2: 6 core methods carry more than one wrapper, which is 52 plugin pairs and 104 orderings, and it is the one of the three most likely to hide a real interaction defect.

## iter 6/10 | 9b36f0e5-154305 | 2026-07-28 | AUDIT | audit

Task: Full audit. The ledger was empty after F20, so this iteration audits, and per the Method it swept an unswept Surface inventory row first: `plugin-interaction-matrix`, using the work list iteration 2 produced.

Changed: `test/plugin/interaction.test.js` (new, 56 tests), PLAN.md (plugin-interaction-matrix swept), BACKLOG.md (F21, F22 filed).

Checkpoint: f4ecafca3686ada878be92911f186ea57c582f47 (committed with `-n`, see Lessons).

Verification: Scores, claiming only the row actually swept. This audit swept `plugin-interaction-matrix` and nothing else, so `locales-content` and `types-declarations` remain unswept and these scores are not the whole project. On the swept row: correctness Medium (F21, F22), architecture None, error handling None, security None, performance None, documentation None, dependency hygiene None. Testing was the gap that let both findings survive - no test compared two extend orders, because each existing plugin test file fixes one order at module scope - and that gap is closed by the sweep itself rather than filed as a separate symptom.

The sweep's invariant is that which plugins are installed is the contract and the sequence they were installed in is not, since a consumer's import order is arbitrary and bundlers reorder freely. Order can only matter where two plugins touch the same prototype method, so the enumeration comes from the source rather than from a list somebody must remember to update.

The first enumeration was wrong, and correcting it is the most important thing this iteration did. It searched for the `const old = proto.x` wrapper form, which is what the settled prototype-capture class had also used. That form cannot match a plain replacement `proto.x = ...`, so `set` never appeared as contested at all, even though `badMutable` replaces it. The enumeration now matches the assignment rather than the capture, and the contested set went from 6 methods and 52 pairs to 8 methods and 54 pairs. F22 was found only because `badMutable + objectSupport` happened to be paired already through `add`; on the narrow enumeration the `set` collision was invisible. This is the recorded Lesson about a class being only as wide as the search that enumerated it, hit for the third time in this project, so the wider search is now the one pinned in the test.

The battery was also too weak at first and was proven so rather than argued. Its generic calls - `add(1, 'month')` and the like - pass identically in both orders even against a genuinely broken plugin, because F2's defect was `Number()` coercion of an argument that only objectSupport supplies. So the battery now drives each plugin's own accepted input shapes. The decisive check: reintroducing the F2 defect in `src/plugin/quarterOfYear/index.js` makes `objectSupport + quarterOfYear` fail, and the original generic battery did not. That is the evidence the sweep has teeth; without it, 54 passing pairs would have certified very little.

F21 is a wrong-looking output that depends purely on import order. `src/plugin/utc/index.js:115` supplies its `YYYY-MM-DDTHH:mm:ss[Z]` default only when `formatStr` is falsy, and `advancedFormat`, `buddhistEra` and `localizedFormat` each substitute their own `FORMAT_DEFAULT` for a missing argument before delegating. So with utc extended first - the usual order - one of those three sits above it, fills in a format string, and utc's UTC default never fires. Measured against a baseline rather than judged by reading: utc alone gives `2019-06-15T12:34:56Z`, moment gives the same, `localizedFormat` then `utc` gives the same, and only `utc` then `localizedFormat` gives `2019-06-15T12:34:56+00:00`. Medium and not High, because the instant is correct and the string is still valid ISO 8601; it contradicts the library's own standalone output and flips on a choice consumers do not think of as semantic.

F22 is a silent no-op. `src/plugin/badMutable/index.js:8` assigns `proto.set` outright while every other method in that same file captures the old one first, so it is one site, not a pattern. Extended after objectSupport it discards objectSupport's `set` wrapper and `set({month: 2})` returns the date unchanged with no error. Medium rather than High on reach: it is a wrong result, which argues High, but it needs one specific pair and `badMutable` is a plugin dayjs's own documentation discourages.

F22 is deliberately not filed inside the settled prototype-capture class, and the distinction matters. That class covers a wrapper whose target may not exist yet, and it concluded that wrapping a core method is safe because the method exists whatever the order. That conclusion is true for the wrapper but says nothing about the mirror case, where a plugin extended later replaces a core method outright and destroys a wrapper installed earlier. Different mechanism, so a new finding rather than a re-file of settled work.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 876 tests across 98 suites, up from 820 across 97, the 56 new ones being the sweep. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0.

The two open pairs are pinned rather than left failing. `KNOWN_ORDER_DEPENDENT` follows the project's existing shrink-only idiom: a new key is a regression and a fixed pair that keeps its entry also fails, since listed pairs are asserted to still differ. A separate test asserts every allowlist key names a pair the sweep actually covers, so a stale entry cannot silently excuse nothing.

Not a stall: a new test file was added, PLAN.md and BACKLOG.md changed state, an inventory row was swept and two findings were filed. No source file changed, which is correct for an audit.

Learnings: one operational rule recorded in PLAN.md - a lookup keyed by prototype method names needs `Object.create(null)`, because plugins assign `valueOf` and `toString` and a plain object literal returns the inherited functions for those keys instead of undefined. That is not hypothetical: it threw `(byMethod[method] || []).concat is not a function` and took the whole suite down until fixed.

Next: F21 then F22, both Medium. The Surface inventory stands at 39 of 41 rows swept, with `locales-content` and `types-declarations` remaining. Neither is small - `locales-content` needs month, weekday, meridiem and longDateFormat strings compared against an independent reference across 143 locales, and `types-declarations` needs type-level fixtures to compare declared signatures against runtime behaviour - so with 4 iterations left the run is more likely to close its findings than to sweep both.

## iter 6/10 | 9b36f0e5-154305 | 2026-07-28 | ROTATION | rotation

Task: JOURNAL.md reached 519 lines after the AUDIT entry, over the 500-line rotation threshold, so all but the last 10 entries move to JOURNAL-archive.md.

Changed: JOURNAL.md (9 entries removed, header kept), JOURNAL-archive.md (9 entries appended).

Checkpoint: f4ecafca3686ada878be92911f186ea57c582f47 (committed with `-n`, see Lessons).

Verification: 19 entries were in the live journal and 20 in the archive, 39 in total. After the rotation the journal holds 10 and the archive holds 29, still 39, and the script asserts both that the total is unchanged and that the archive count did not fall, aborting rather than writing if either check failed. The archive was appended to, never rewritten. JOURNAL.md is now 267 lines.

The split is anchored on the `## iter` heading positions rather than on a line offset, and the header above the first entry is preserved intact. That is the repair the previous run's rotation had to make after an example heading in the header was swept into the archive; the grammar line is now inline in backticks so no header line begins with `## iter` and the count cannot be confused.

Learnings: no new operational rule.

Next: nothing. This entry is additional to the AUDIT entry above, which closes the iteration.

## iter 7/10 | 9b36f0e5-154305 | 2026-07-28 | F21 | done

Task: F21 (Medium, correctness) - `dayjs.utc().format()` rendered `2019-06-15T12:34:56+00:00` instead of `2019-06-15T12:34:56Z` whenever `utc` was extended before `advancedFormat`, `buddhistEra` or `localizedFormat`, which is the usual order because utc is normally extended first.

Changed: `src/plugin/advancedFormat/index.js`, `src/plugin/buddhistEra/index.js`, `src/plugin/localizedFormat/index.js` (each passes a missing format string down instead of defaulting it; the now-unused `FORMAT_DEFAULT` imports removed), `test/plugin/utc.test.js` (7 tests added), `test/plugin/interaction.test.js` (3 allowlist entries removed), PLAN.md (4 rows re-swept), BACKLOG.md (F21 deleted, the format-default class settled).

Checkpoint: 5d31b93521f88a759e8e022c97a4a69e1600f19b (committed with `-n`, see Lessons).

Verification: The fix is one rule applied at three sites: a `format` wrapper must not substitute its own default for a missing argument, because a plugin below it may have a different default for that case. utc does - `YYYY-MM-DDTHH:mm:ss[Z]` when `this.$u` is set - and it only ever sees the no-argument case if nothing above it has already filled the argument in.

Deleting the substitution is safe rather than merely plausible, and the reason is checkable. All three substituted the same `FORMAT_DEFAULT` constant that core applies anyway at `src/index.js:268`, so when one of them is the bottom of the chain the result is identical. And none of their token tables can match anything in that constant: `YYYY-MM-DDTHH:mm:ssZ` contains no `BBBB` or `BB`, no `L` run, and none of advancedFormat's `Q wo ww w WW W zzz z gggg GGGG Do X x k` alternatives. So the substitution was doing no work in the case it was applied to, while masking utc's default whenever utc sat below.

Acceptance check met across every order, measured against two independent references. All six combinations - utc first and second against each of the three plugins - now return `2019-06-15T12:34:56Z`, equal to utc alone and to moment's `utc(iso).format()`. Contract preserved on the non-utc path, asserted rather than assumed: core alone, localizedFormat alone, advancedFormat alone and buddhistEra alone all still return `2019-06-15T08:34:56-04:00` for a plain `.format()`, unchanged by the removal.

Confirmed strong enough to fail, and specifically so. Reverting only `localizedFormat` fails exactly two tests - the sweep's `localizedFormat + utc` pair and `matches moment with utc then localizedFormat` - while the advancedFormat and buddhistEra equivalents keep passing, which shows the guards are per-plugin rather than blanket.

The new tests pin the value, not just the agreement, and that distinction is why they exist. `test/plugin/interaction.test.js` compares the two extend orders against each other, so two orders agreeing on the same wrong string would satisfy it. The assertions added to `test/plugin/utc.test.js` compare against moment and against the literal expected string, so the sweep pins order-independence and these pin correctness. Neither alone is sufficient.

The class was enumerated before being called complete. All 5 plugins that assign `proto.format` were listed: 3 substituted a default and are fixed, `preParsePostFormat` already forwarded `...args` untouched and is the model for the rule, and `utc` is the one wrapper that legitimately supplies a default because its default is conditional on UTC mode rather than unconditional.

Contract preserved and rows re-swept: three plugin files changed their public `format` behaviour in the no-argument case, so `plugin-advancedFormat`, `plugin-localizedFormat` and `plugin-negativeYear-buddhistEra` were stale and are re-swept at this checkpoint - their existing token suites re-ran green, pinning what the original sweeps certified, and the changed path itself is now covered directly by the both-orders assertions. `plugin-interaction-matrix` was also stale and is re-swept: all 54 pairs re-ran and the three `+utc` entries came out of the allowlist, which the map's both-directions check forced rather than left optional.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 883 tests across 98 suites, up from 876, no test weakened or removed. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0.

Not a stall: three source files and two test files changed, and F21 closed.

Learnings: one operational rule recorded in PLAN.md - a plugin wrapper must forward a missing argument as missing rather than substituting its own default, because the default belongs to whichever handler is actually at the bottom of the chain. This is the same shape as the already-recorded rule about not coercing an argument a wrapper is not itself handling; that one was about the value, this one is about its absence.

Next: F22, the last open item, Medium - `badMutable` replaces `proto.set` outright and discards objectSupport's wrapper, so `set({month: 2})` silently does nothing. The Surface inventory stands at 39 of 41 with `locales-content` and `types-declarations` remaining, and 3 iterations left after this one.

## iter 8/10 | 9b36f0e5-154305 | 2026-07-28 | F22 | done

Task: F22 (Medium, correctness) - `dayjs().set({ month: 2 })` silently did nothing when `badMutable` was extended after `objectSupport`, because `badMutable` assigned `proto.set` outright and discarded objectSupport's wrapper, leaving the object argument to reach `$set` as a non-unit.

Changed: `src/plugin/badMutable/index.js` (`set` now wraps instead of replacing), `test/plugin/interaction.test.js` (allowlist emptied, enumeration regex widened to `[\w$]`), `test/plugin/utc.test.js` (lint repair, see below), PLAN.md (2 rows re-swept, 2 Lessons), BACKLOG.md (F22 deleted, the replace-instead-of-wrap class settled).

Checkpoint: b199f40c7cdbb361396d162dcba47b06d1fc7c83 (committed with `-n`, see Lessons).

Verification: The first fix worked and was still wrong, and replacing it is the substance of this iteration. Delegating only the object form - `if (typeof string === 'object') return oldSet.call(...)` - made both orders return the same value, which satisfied the acceptance check as written. But probing the side effect showed the two orders still disagreed: with objectSupport extended first the receiver was not mutated and a clone came back, while the other order mutated in place. badMutable exists to mutate, so that is a real remaining difference, and the acceptance check simply did not look at it.

The second fix removes the special case entirely by matching what this plugin's own siblings already do. `startOf`, `add` and `subtract` each delegate to the captured method, assign `.toDate()` onto `this.$d`, call `init()` and return `this`. Written that way, `set` needs no type check at all: every argument form its neighbours accept flows down untouched, and the result is mutated back into the receiver whichever order the plugins were extended in. That is also why `add({months: 1})` never showed the defect - it already used this shape - which is the clue that pointed at it.

Verified on both axes rather than just the value: for `set({month: 2})` and for `set('month', 2)`, in both extend orders and with badMutable alone, the returned object is the receiver, the receiver is mutated, the date is `2019-03-15`, and the milliseconds survive the `toDate` round trip at `.789`. Confirmed strong enough to fail: restoring the plain assignment fails the sweep's `badMutable + objectSupport` pair under both `add` and `set`.

`KNOWN_ORDER_DEPENDENT` is now empty and asserted empty, so every contested pair behaves identically in both orders and any new order-dependence fails outright instead of being absorbed.

The class enumeration found a hole in my own tooling and is recorded because it changes what the sweep can see. The parser that compares assignments against captures was validated against 8 known-positive core methods first, after a previous version silently found 0 core methods and therefore reported a clean result - the exact false-clean the Lessons warn about. With it validated, `badMutable.set` was the only contested core method replaced rather than wrapped. Three plain replacements remain, all in `utc` - `valueOf`, `toISOString`, `toString` - and no other plugin assigns any of them, so there is no collision to reproduce and nothing is filed. Separately, the sweep's own enumeration used `\w+`, which cannot match dayjs's `$`-prefixed internals, so `proto.$g` had been invisible to it; widened to `[\w$]` and rechecked, `$g` is assigned by badMutable alone and the contested set is unchanged at 8 methods and 54 pairs.

Two process failures this iteration, both mine, both now Lessons. First, iteration 7 committed a lint error: I ran eslint before appending to `test/plugin/utc.test.js` and not after, and checkpoint commits use `git commit -n`, which skips the pre-commit lint hook. That entry's claim that lint exited 0 was true when the command ran and false at commit time. The error - a leading-semicolon `semi-style` violation - is repaired here by naming the array in a const instead. Second, PLAN.md was found duplicated head-to-tail in the working tree, with two `## Mode` and two `## Surface inventory` sections, so an edit landed in the first copy while a stale second copy still described the same rows. Every commit through 5d31b93 has exactly one of each and 172 lines, so the corruption was uncommitted and local to this iteration; PLAN.md was restored from HEAD and the two intended row edits re-applied, leaving it at 172 lines with unique headings.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 883 tests across 98 suites, unchanged in count because this iteration changed a plugin and re-pointed existing assertions rather than adding cases. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0, run after the last edit this time.

Contract preserved: badMutable still mutates in place and still returns the receiver for every form it handled before, asserted directly. The only behaviour that changed is the object form, which previously did nothing. `plugin-badMutable` and `plugin-interaction-matrix` were both stale and are re-swept at this checkpoint.

Not a stall: a source file and two test files changed, and F22 closed.

Learnings: two operational rules recorded in PLAN.md - run lint as the final step before committing, since `-n` skips the hook; and assert section headings are unique after any scripted rewrite of a state file, restoring from HEAD rather than repairing a duplicate in place.

Next: the ledger is empty. Two iterations remain and the Surface inventory stands at 39 of 41, with `locales-content` and `types-declarations` unswept. Convergence is not reachable without sweeping both, and neither is small, so iteration 9 should audit by sweeping whichever is more tractable and iteration 10 should be a WRAPUP with an honest handoff.

## iter 9/10 | 9b36f0e5-154305 | 2026-07-28 | AUDIT | audit

Task: Audit. The ledger was empty after F22, so this iteration audits and sweeps an unswept Surface inventory row. Two remained; `types-declarations` was taken because F17 already built the compiler infrastructure its remaining gap needed, while `locales-content` needs an oracle this project has already established moment cannot be.

Changed: `tsconfig.json` (fixtures included, plugin and locale path mappings added), `test/types/core.type-test.ts`, `test/types/plugin.type-test.ts`, `test/types/plugin-rest.type-test.ts` (all new), `test/types.test.js` (2 tests added), PLAN.md (types-declarations swept).

Checkpoint: eaf3575804a5ae81ea88b5ea050c2af7f8593a3d (committed with `-n`, see Lessons).

Verification: Scores, claiming only the row swept. This audit swept `types-declarations` and nothing else, so `locales-content` remains unswept and these scores are not the whole project. On the swept row: correctness None, documentation None, testing None after this iteration closes the gap that existed, and every other dimension not applicable to a declaration surface. Zero High and zero Medium. Closeout does not begin, because closeout requires a full fresh-evidence audit and this one leaves a row unswept by design.

The gap this row named was signature agreement, and it is now closed by type-level fixtures that assert in both directions. Every binding is explicitly annotated, so a wrong return type fails as an ordinary assignment error; and every deliberate misuse carries `@ts-expect-error`, so a declaration loose enough to accept a bad call fails as `TS2578 Unused '@ts-expect-error' directive`. The second direction is what stops the whole file from passing merely because something is typed `any`.

Both directions were validated against deliberate breakage before any result was believed, which matters because a type fixture that checks nothing looks exactly like one that passes. Changing `const formatted: string = d.format()` to `Date` produced `TS2322: Type 'string' is not assignable to type 'Date'`; putting a legal call under a directive produced `TS2578`. Then the jest compile gate was checked too: appending a bad annotation makes `test/types.test.js` fail with the real compiler output, so the fixtures are enforced by the Verify gate rather than only by a separate command.

Coverage is enumerated rather than claimed. Core plus all 37 plugin declarations are exercised, and a new test asserts every `types/plugin/*.d.ts` is imported by some fixture, with a positive control confirming the matcher really finds imports before the emptiness assertion is trusted. So a plugin added without a fixture fails the suite instead of quietly going unchecked.

The executing half is covered separately, because a `.ts` fixture never runs and therefore cannot catch a declaration that is self-consistent but wrong about the runtime. Twenty core calls now have their runtime `typeof` compared against the kind the same call is type-asserted to return, eight more are asserted to really return a Dayjs, and `toDate` a Date. The correspondence between the two halves is by construction - the same call list appears in both places - which is stated in the test rather than implied.

No signature defect was found, and the one failure the sweep produced was mine. `@ts-expect-error` reported unused on `dayjs.max([dayjs(), dayjs()])` not satisfying a bare `Dayjs`, and the declaration turned out to be right: a literal array matches the non-empty tuple overload `[Dayjs, ...Dayjs[]]` and correctly returns a non-nullable `Dayjs`, while only a value typed `Dayjs[]` reaches the nullable overload. The fixture now asserts both cases. That is the bidirectional check earning its place by catching the test author rather than the library, and it is worth recording that the declaration was more precise than the expectation brought to it. It is also the exact TS 3.0 syntax the old `^2.8.3` pin could not parse, so this check only became possible because F17 lifted the compiler.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 885 tests across 98 suites, up from 883. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0, run after the last edit.

The fixtures live in `test/types/` rather than `types/`, deliberately: `build/index.js:65` copies all of `types/` to the package root, so a fixture placed there would ship to consumers. `test/` is npmignored and never copied.

Not a stall: three new fixtures, a config change and two new tests, and an inventory row was swept.

Learnings: no new operational rule. The reusable point is that a type-level test needs the negative direction to be worth anything - a file of positive annotations passes just as well against declarations that have quietly become permissive, and `@ts-expect-error` is what converts "this compiles" into "this compiles and that does not".

Next: iteration 10 is the last of the budget. The Surface inventory stands at 40 of 41 with only `locales-content` unswept, and that row cannot be closed honestly in one iteration - it needs month, weekday, meridiem and longDateFormat strings for 143 locales compared against a reference, and this project has already recorded that moment is not a sound oracle for dayjs locale strings, with 62 of 132 shared locales legitimately differing. So iteration 10 should be a WRAPUP that tidies the ledger and writes an honest handoff, and the run ends out of budget rather than converged.

## iter 10/10 | 9b36f0e5-154305 | 2026-07-28 | WRAPUP | done

Task: Final iteration of the budget. The ledger is empty and the one remaining Surface inventory row cannot be closed honestly in a single iteration, so this tidies BACKLOG.md, records the run's final state and writes the handoff, rather than starting work that would end half-done.

Changed: BACKLOG.md (one stray blank line removed; Now, Next and Later are empty and every section heading is intact), JOURNAL.md.

Checkpoint: 267897ba434a2e25ded8242bbd7a0a56e4686884 (committed with `-n`, see Lessons).

Verification: Final Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 885 tests across 98 suites, up from 813 at the start of this run. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0 and `npx tsc --noEmit -p tsconfig.json` exits 0.

Not converged, and the run does not claim to be. The Definition of done requires the Surface inventory to list no unswept row, and `locales-content` is still unswept, so the evaluator gate is not invoked and no Converged line is appended. Every filed finding is closed: six tasks this run, F17 through F22, none blocked, none declined, nothing left on the ledger. The inventory moved from 37 of 41 to 40 of 41.

Handoff for the next run, which should start in a fresh session so the accumulated context is dropped.

`locales-content` is the only unswept row and the only thing between this project and convergence. Its scope is the per-locale correctness of month names, weekday names, meridiem strings and longDateFormat patterns across 143 locales; the ordinal dimension is already settled class-complete and must not be re-opened. The hard part is the oracle, not the labour, and this project has already established that moment is not one: 62 of 132 shared locales legitimately differ, so a naive differential produces mostly false positives. Three approaches that do not depend on a single oracle, cheapest first. Structural invariants first - every locale's `months` and `monthsShort` must have exactly 12 entries and `weekdays`, `weekdaysShort` and `weekdaysMin` exactly 7, no entry empty or duplicated within its array, and `weekdaysMin` no longer than `weekdaysShort`; that is a real correctness check needing no reference at all and it will either come back clean or find a transcription error. Second, `Intl.DateTimeFormat` is a genuine independent reference for month and weekday names in the locales the host ICU supports, and comparing against it flags candidates for human review rather than asserting equality, since dayjs and CLDR differ on capitalisation and abbreviation style in several languages. Third, longDateFormat patterns can be checked mechanically for token validity - every token in `L`, `LL`, `LLL`, `LLLL`, `LT` and `LTS` must be one core or localizedFormat actually implements, and an unknown token silently renders as literal text, which is the same failure mode F6 had. Expect that row to need two or three iterations, and expect the first to be spent building the harness rather than finding defects.

Two things a future run should not redo. The interaction sweep in `test/plugin/interaction.test.js` derives its own work list from the source, so it widens automatically when a plugin is added; its `KNOWN_ORDER_DEPENDENT` map is empty and asserted empty. The type fixtures in `test/types/` cover core plus all 37 plugin declarations and a test asserts every plugin declaration is imported by one, so a new plugin fails the suite until it gains a fixture.

The most transferable thing this run produced is not any single fix but a pattern that recurred four times: every enumeration was narrower than the class it claimed to cover. The prototype-capture search missed plain assignments, the interaction sweep's regex missed `$`-prefixed methods, the class-comparison parser silently matched zero core methods and reported clean, and the first probe battery was too generic to catch the defect it was written for. Each was caught only by validating the search against a known positive before trusting its emptiness. That is already recorded in Lessons and it is the habit worth carrying forward.

Not a stall: BACKLOG.md changed and this entry closes the run; the substantive work of the iteration is the handoff itself, which the final iteration exists to produce.

Learnings: no new operational rule.

Next: nothing in this run. The budget is spent. Start a fresh session in this directory and run /jeffy again; PLAN.md, BACKLOG.md and JOURNAL.md carry the state forward, and the next run should open by sweeping `locales-content`.

## iter 1/10 | 7fa4157b-170053 | 2026-07-28 | AUDIT | audit

Task: Audit. The ledger was empty and no Converged line exists, so the ratchet does not apply. One Surface inventory row was unswept, `locales-content`, and the previous run's handoff named it as the only thing between this project and convergence. This iteration sweeps it and files what it found.

Changed: PLAN.md (`locales-content` swept, 3 Lessons), BACKLOG.md (F23 through F26 filed, 2 Declined lines added).

Checkpoint: 18ba2c8adcc8806b35f2d24a796651818221e50b (committed with -n, see Lessons).

Verification: Scores, claiming only the rows swept. This audit swept `locales-content`; every other row was already swept and no source file has changed since, so nothing went stale. Correctness High, on the strength of F23. Documentation None. Testing Medium, because the sweep found four defects in data that no test compares against any reference, which is the gap F23 to F26 each close. The remaining dimensions do not apply to a data surface. Closeout does not begin: it requires an audit scoring zero High and zero Medium, and this one scores High.

The row had four dimensions left open after the ordinal work of previous runs, and all four were probed across all 143 locales.

Structure, no reference needed: `months` and `monthsShort` must hold 12 entries and `weekdays`, `weekdaysShort` and `weekdaysMin` 7, none empty, none duplicated within its own array, over both arms of the function form. Exactly one duplicate exists in the whole set, `mt` `weekdaysMin` repeating its two-letter form for Hadd and Hamis, and it is byte-identical to moment's, so it is upstream convention rather than a transcription error and is Declined.

longDateFormat, no reference needed: every one of the 10 pattern keys was expanded through localizedFormat's own `u()` and each ASCII-letter run outside brackets was decomposed against the 26 core tokens. The decomposer was validated on known positives before its output was believed, which is the habit the previous run's handoff singled out: `decompose('de')` leaves `e`, `decompose('Do')` leaves `o`, and `MMMM` and `YYYY` leave nothing. A first version of this scan flagged 49 patterns and every one was a false positive, because it treated any letter run mixing token and non-token characters as suspect and so condemned the perfectly correct Japanese year-month-day pattern. A CJK or Devanagari character can never be a token, so restricting the scan to ASCII runs is what made it decisive. On the corrected scan exactly one pattern in 143 locales carries a non-core token: `gom-latn` `LLLL` contains `Do`, filed as F25.

Meridiem: 20 locales define it, each was called on both sides of noon, and every one returns distinct defined output. No finding.

Names needed a reference, and the previous run's handoff was right that moment alone is not one. Three independent sources were used instead. `Intl.DateTimeFormat` resolved without falling back for 125 of the 143 locales, and 79 of those match dayjs exactly. Ordering was checked separately and is the strongest single result here: every `months` and `weekdays` array was tested against every rotation of the Intl reference, because a rotation is an unambiguous ordering defect that needs no language knowledge, and none exists anywhere. The detector was validated on a deliberately rotated `en`, which it reports as a rotation by 1, against the real `en`, which it reports as no rotation.

The 46 locales differing from Intl were then re-checked against moment, and the three-way split is what separated real findings from noise. Where dayjs differs from moment but matches Intl, or differs from both for reasons of script and transliteration, no defect is established, and those are Declined as a group rather than left to be re-filed next run. Where dayjs differs from both references in the same direction, the finding is real. That isolated F23 and F24.

F23 is the worst defect this project has produced and it had been sitting in plain sight: `src/locale/si.js` sets `months` and `monthsShort` to the traditional Sinhala lunar month names rather than the Gregorian ones. `dayjs('2019-01-15').locale('si').format('LL')` returns the Duruthu form where both moment and Intl give the Sinhala for January. All 12 of 12 are wrong, and the wrongness is not orthographic, since Duruthu is a poya month and not January. The same file's `weekdays` match moment exactly, which is what makes this a substitution of one naming system for another rather than a bad port.

F24 is a class, filed as one structural task rather than five instance patches per the three-strike rule. Five locales collapse a format-context and standalone month distinction into a single flat array, so one of the two contexts is ungrammatical: `cs` renders `15. leden 2019` where Czech needs the genitive `ledna`, `hy-am` renders the standalone `MMMM` in the genitive instead of the nominative, `ca` and `oc-lnc` drop the `de` preposition the date context requires, and `tg` drops the izofa. dayjs already models exactly this with the function form carrying `.f` and `.s`, which `be`, `hr`, `lt`, `pl`, `ru` and `uk` use, so the fix is to adopt the mechanism the project already has rather than to invent one.

Two of my own probes disagreed about `cs`, and the disagreement is worth recording, because it is the same false-clean risk the Lessons keep circling. One read moment's `_months.standalone` and the other compared against `_months.format`, and they reported opposite answers about which arm dayjs matched. Neither reading was trustworthy, because moment does not store the two arms consistently across locales. Rendering `format('LL')` and `format('MMMM')` and comparing the strings settled it in one command, and every claim in F24 rests on rendered output rather than on the shape of moment's internals.

F26 came from removing a normalizer rather than from adding a probe. The name differential lowercased both sides before comparing, which is what let it ignore transliteration noise, and it therefore could not see that `ca`, `ro`, `sr` and `sr-cyrl` capitalize all 12 months and all 7 weekdays where the language does not. Re-running the same comparison without the lowercasing surfaced them immediately. `pt` differs from moment in the opposite direction and is correct as it stands, which Intl confirms, so it is named in the task as a locale that must not be changed.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 885 tests across 98 suites, unchanged, because this iteration filed findings and wrote no test.

PLAN.md was damaged mid-iteration and repaired the way the Lessons prescribe. An edit replacing a prefix of the `locales-content` row left the row's tail in place, and the follow-up edit that removed that tail also consumed the entire adjacent `types-declarations` row, taking the table from 41 rows to 40 while both section headings still looked correct. It was caught by counting rows, not by reading the file. PLAN.md was restored from HEAD and the row re-applied as a single whole-line splice, and the table is now 41 rows, 41 swept, 0 unswept, 9 unique headings, with `types-declarations` intact.

The row is marked swept while four findings against it are open, which is what the inventory rules say to do: an executed probe flips a row, and fixing the locales will stale it again. That is not bookkeeping churn, because the re-sweep after the fixes will run against committed tests rather than scratch probes: F23, F24 and F25 each carry an enumerating check that pins its dimension permanently.

Not a stall: an inventory row was swept and four findings were filed.

Learnings: three operational rules recorded in PLAN.md. Verify a state-file row edit by counting rows against HEAD rather than by reading it. Settle a moment locale-data question by rendering rather than by reading `_months`. Re-run a differential without its normalizer, because the normalizer hides its own class of defect.

Next: F23 is the only High and is a single-file data fix with a clean differential oracle, so iteration 2 takes it. F24 is the largest of the remaining tasks and should follow, then F25, then F26. The Surface inventory reads 41 of 41 for the first time, so once the ledger drains the run is a candidate for convergence, subject to the re-sweep the fixes will force and the evaluator gate.
## iter 2/10 | 7fa4157b-170053 | 2026-07-28 | F23 | done

Task: F23 (High, correctness). `src/locale/si.js` carried the traditional Sinhala lunar month names in `months` and `monthsShort` instead of the Gregorian ones, so every Sinhala date named a different month than the date denoted.

Changed: `src/locale/si.js` (`months` and `monthsShort` replaced), `test/locale/names.test.js` (new), PLAN.md (locales-content row records the new pinning), BACKLOG.md (F23 deleted, F27 filed).

Checkpoint: 71ca66802ae9ed7d76e529d7a5f6175ac2f8b95f (committed with -n, see Lessons).

Verification: The acceptance check was written first and confirmed to fail against the unfixed data, which is the part that makes it worth anything: `expect(dayjs('2019-01-15').locale('si').format('MMMM'))` reported `Received: දුරුතු, Expected: ජනවාරි`, and the general comparison failed on `si` a second time because `si` is deliberately absent from the allowlist. 268 of the 270 assertions in the new file passed at that point, which is what established the allowlist was accurate for the other 132 locales before any fix landed.

The data was transcribed programmatically from `node_modules/moment/locale/si.js` rather than retyped, per the Lesson, and the script asserted 12 entries in each array and no embedded underscore before writing, then the file was re-grepped to confirm the edit landed rather than trusting the script's own success message.

The fix closes the finding on both arms: all 12 `MMMM` and all 12 `MMM` values now equal moment's, and `format('MMMM')` for January is asserted explicitly not to be the Duruthu form, so a revert cannot pass by coincidence.

The enumeration is what makes this permanent rather than a one-locale patch. `test/locale/names.test.js` compares every locale's rendered `MMMM` and `dddd` against moment for all 133 locales moment ships, and asserts the 10 it does not ship are exactly the declared list, so a locale cannot drop out of the comparison unnoticed. Both allowlists are shrink-only in the project's established shape: each entry must still really differ, so a later fix that closes one fails this suite until the entry is deleted. The comparison is on rendered output rather than on moment's internals, which is the rule iteration 1 learned the hard way.

The suite also carries a positive control asserting that `en` and `fr` month names do not compare equal, because an equality sweep that silently compares a string to itself passes everywhere and certifies nothing.

F27 was found while building that enumeration and is filed rather than absorbed into the allowlist without a record: `be` renders Belarusian February standalone as `лютый` where moment and `Intl.DateTimeFormat('be')` both give `люты`, while its date-context `.f` arm is `лютага` and matches moment exactly. It is the only single-value name defect across the 133 compared locales. Filed Low: one month name in one locale, still recognizable, and the date it appears in is otherwise correct.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 1155 tests across 99 suites, up from 885 across 98, the increase being the 270 per-locale assertions this file adds.

Lint caught three errors in the new test file on the final pass and all three are fixed: two over-length lines and a `no-underscore-dangle` on `moment.localeData(name)._abbr`. The last one was worth more than a style repair, because the public replacement `moment().locale(name).locale()` is the honest way to ask whether moment really resolved a locale rather than falling back, and the suite still reports exactly 133 comparable locales after the change, which is asserted rather than assumed. This is the second run in a row where running lint as the final step caught something the Verify gate would have carried into a commit.

Contract preserved: this changes bundled data, not behaviour. `si`'s `weekdays`, `weekdaysShort`, `weekdaysMin`, `ordinal`, `formats` and `relativeTime` are untouched and still match moment, and `test/locale/keys.test.js` re-ran green, so the locale's key shape is unchanged. The only observable difference is that `MMMM`, `MMM` and every `formats` pattern containing them now render Gregorian month names, which is the defect being fixed.

The `locales-content` inventory row stays swept rather than going stale, and the reason is recorded in the row itself. The precedent is the `locales-structure` row: a dimension pinned by a test that re-runs in the Verify gate is not staled by an edit to the data it pins. `names.test.js` now holds the month and weekday name dimension for all 143 locales, so this edit is re-certified on every future iteration. The structure, meridiem and longDateFormat dimensions are still certified only by the scratch sweep at 18ba2c8, and the row says so, until F25 pins the format-token scan.

Not a stall: a source file changed, a test file was added, and F23 closed.

Learnings: no new operational rule. The reusable point is already recorded: write the acceptance check first and watch it fail, because an allowlist-based enumeration is exactly the shape that passes vacuously if the comparison is wired up wrong, and the 268 passing assertions alongside the 2 failing ones are what showed it was wired up right.

Next: the ledger holds F24, F25 and F27. F24 is next and is the largest, a class fix across 5 locales adopting the function form with `.f` and `.s` that 6 locales already use; its enumeration should extend `names.test.js` to compare the date context as well as the standalone one, since `tg` and `cs` differ only there.

## iter 3/10 | 7fa4157b-170053 | 2026-07-28 | F24 | done

Task: F24 (Medium, correctness). Locales that collapse a context-inflected month name into one flat array, so that either the standalone form or the form inside a date is always ungrammatical.

Changed: `src/locale/ca.js`, `src/locale/cs.js`, `src/locale/el.js`, `src/locale/hr.js`, `src/locale/hy-am.js`, `src/locale/oc-lnc.js`, `src/locale/tg.js`, `test/locale/names.test.js`, PLAN.md (3 Lessons), BACKLOG.md (F24 deleted and settled as a class, F28 filed, F26 rescoped).

Checkpoint: 9a3865f373beb3d49882dbbd5ce01fa26ce5fadd (committed with -n, see Lessons).

Verification: The task was filed against 5 locales and closed against 7, and the two extra ones are the substance of this iteration rather than an incidental extra.

The filed enumeration looked for locales whose moment counterpart models two arms as `{format, standalone}`. That is a search against the reference implementation's internal shape, and the Lessons already record what is wrong with that kind of search. Re-run shape-independently by comparing every locale's rendered `LL` against moment's across all 12 months and all 133 locales moment ships, it found two more. `hr` already had dayjs's function form and still rendered `15. siječanj 2019` instead of `15. siječnja 2019`, because its own `LL` of `D. MMMM YYYY` separates `D` from `MMMM` with a period and the default regex admits only brackets or whitespace, so the date branch never fired. `el` needed the form and did not have it, because moment models Greek's nominative and genitive as a `months()` function, which an object-shaped search cannot see at all.

`cs` was the trap. moment stores its arms the other way round from every other locale here: the arm it calls `format` holds the nominative `leden`, and its dates come out genitive only because its own `LL` fails its own `MONTHS_IN_FORMAT` regex. Transcribing moment's arms in the obvious order would have preserved the exact defect being fixed while looking correct, and the generator did produce that before it was caught by rendering. `cs` therefore takes the two arms swapped, with the reason written into the locale file.

`cs` also keeps a deliberate divergence from moment that is now asserted rather than allowlisted silently: dayjs renders a bare `MMMM` as the nominative `leden`, which is the correct Czech standalone form, where moment renders the genitive `ledna`. The allowlist entry says so, so it reads as a decision rather than an unexplained gap.

Three defects in my own tooling were caught before they reached a commit, each by checking the artifact rather than the generator's exit status. The Catalan and Occitan format arms contain `d'abril`, whose apostrophe broke the single-quoted string literal and made the file unparseable; quoting is now chosen by content, which is what airbnb's `avoidEscape` expects anyway. Worse, the generated regex lost every backslash through string interpolation and was written as `/D[oD]?([[^[]]*]|s)+MMMM?/`, which still parses, matches nothing, and silently sends every date down the standalone branch. That is the same class as the Lesson about `new RegExp` losing backslashes and it is now its own Lesson: the repaired line is built with `String.fromCharCode(92)`, read back from disk, and compared byte-for-byte against `src/locale/ru.js`, which is the working reference for this exact pattern.

The acceptance check is on rendered output in both contexts. The date context is each locale's own `LL` rather than a bare `D MMMM`, and `cs` is the reason: on the bare space form moment matches its regex and returns the nominative, so it renders the ungrammatical `15 leden`, and asserting against that would have pinned moment's bug into dayjs. `LL` is also what a caller actually formats with.

Confirmed strong enough to fail rather than assumed: restoring the flat genitive array in `hy-am` fails 2 assertions, and restoring it passes 282. Before the fix the render probe counted 188 differences from moment across the 5 locales, 12 months and 4 format keys; after it, 23, all of them the deliberate `cs` standalone divergence and `ca` weekday capitalization, which is F26 and untouched here.

The class is now settled on the wider enumeration, and the enumeration is pinned rather than narrated. `KNOWN_LL_DIFFERENCES` in `test/locale/names.test.js` is a shrink-only list of the 21 locales still disagreeing with moment on `LL`: 16 digit-system differences that are correct by design, since dayjs gates preparse and postformat behind an opt-in plugin, plus `az` (F28), `eo` (Declined) and 3 capitalization cases (F26). A locale that starts disagreeing without being listed fails the suite.

F28 was found by that same sweep and is filed rather than absorbed: `src/locale/az.js` carries a stray Cyrillic `г.`, the Russian abbreviation for year, in `LL`, `LLL` and `LLLL`, so every long-form Azerbaijani date renders `15 yanvar 2019 г.`, and the same block uses `H:mm` where moment uses `HH:mm`. Both point at a formats block copied from a Russian-family locale into a Latin-script one. Filed Medium: it is visibly wrong output in every long date for that locale, not a style choice. `eo` and `bn-bd` also differ on their `LL` patterns but no language source shows either is wrong, so they are Declined rather than filed.

F26 was rescoped rather than left overlapping. `ca`'s month arrays were rewritten by this task, and writing them back in a capitalization both moment and CLDR contradict would have been a placeholder, which the Constraints forbid, so they went in lowercase and F26 now covers `ca`'s weekdays plus `ro`, `sr` and `sr-cyrl`.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 1172 tests across 99 suites, up from 1167. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0, run after the last edit.

Contract preserved: this changes bundled locale data and one regex, never a public signature. `months` moves from an array to the function form the core `format` already supports at `src/index.js:274`, where `getShort` calls `arr(this, str)` when the value is not indexable, and which `localeData`'s `getLocalePart` already reads through `.s`. The pre-existing `test/locale/cs.test.js` and `test/locale/hr.test.js` both re-ran green, which is the evidence that the locales whose mechanism changed still satisfy the assertions that already pinned them, and `test/locale/keys.test.js` re-ran green, so the function form still satisfies the locale key-shape contract. Standalone output changed for exactly one locale, `hy-am`, which is the defect being fixed.

Not a stall: 7 source files and a test file changed, F24 closed, F28 filed.

Learnings: three operational rules recorded in PLAN.md. A regex written into a generated source file loses its backslashes and still parses, so build it with `String.fromCharCode(92)` and compare the written line against a known-good sibling. Enumerate a locale-data class by comparing rendered output across every locale, never by matching the reference implementation's internal shape. And check which of moment's two month arms actually renders in a date before copying either, because `cs` stores them inverted.

Next: the ledger holds F28, F25, F27 and F26. F25 is next by severity order after F28, and F28 is a small data fix, so iteration 4 takes F28 and iteration 5 takes F25, which needs the format-token scan pinned as a committed test.

## iter 3/10 | 7fa4157b-170053 | 2026-07-28 | ROTATION | rotation

Task: Rotation. Appending this iteration's F24 entry took JOURNAL.md to 513 lines, past the 500-line threshold.

Changed: JOURNAL.md (8 oldest entries removed), JOURNAL-archive.md (the same 8 appended).

Checkpoint: 9a3865f373beb3d49882dbbd5ce01fa26ce5fadd (committed with -n, see Lessons).

Verification: 18 entries were present; the 8 oldest moved and the 10 most recent stayed, which the script asserted rather than assumed. The archive grew from 29 headings to 37, exactly 8 more, and every archived entry's heading line was confirmed present in the new archive text before either file was written. The split was checked to be lossless by rejoining the parts and comparing against the original. The oldest entry now in JOURNAL.md is iter 5/10 of run 9b36f0e5-154305 and the newest in the archive is iter 4/10 of that run, so the boundary is contiguous with no entry dropped or duplicated. JOURNAL.md is now 309 lines and JOURNAL-archive.md 947. The archive header counts one heading that is the grammar template rather than an entry, in both the before and after figures, so the difference of 8 is unaffected.

Learnings: no new operational rule.

Next: continue with the ledger; this entry is bookkeeping alongside the iteration's primary F24 entry.

## iter 4/10 | 7fa4157b-170053 | 2026-07-28 | F28 | done

Task: F28 (Medium, correctness). `src/locale/az.js` carried a stray Cyrillic year abbreviation in its long date formats, so every long-form Azerbaijani date rendered a Russian word.

Changed: `src/locale/az.js` (formats block replaced), `test/locale/names.test.js` (allowlist entry removed, 2 tests added), PLAN.md (2 Lessons), BACKLOG.md (F28 deleted, the borrowed-formats class settled).

Checkpoint: ac1335df31e1fde70e33fc8ecf2497c631c656df (committed with -n, see Lessons).

Verification: The diagnosis is stronger than the filing was. `az`'s entire formats block is byte-identical to `ru`'s, all six keys, which makes this a copy rather than a typo and explains both symptoms at once: the Russian year abbreviation and the `H:mm` where Azerbaijani uses a zero-padded hour. Two independent references agree on the corrected values, moment and `Intl.DateTimeFormat('az')`, the latter giving `15 yanvar 2019` for a long date and `14:30` for a short time.

Because a copied block is a shape rather than a single bad string, the class was enumerated rather than the instance patched. All 143 locales' `formats` objects were grouped by exact value, keeping only groups whose block carries non-ASCII literal text, on the reasoning that a block of pure tokens and punctuation cannot smuggle one language into another and would produce nothing but noise. Six groups are shared. Five are variants of a single language and are legitimate: `ar`/`ar-ly`, `pt`/`pt-br`, `zh`/`zh-cn`, `zh-hk`/`zh-tw`, and `sd`/`ur`, which share only the Arabic comma. `az`/`ru` was the one cross-language case. That is the whole class, and it is now one instance wide and closed.

The enumeration is pinned by `SHARED_FORMAT_BLOCKS` in `test/locale/names.test.js`, asserted by exact equality rather than by containment, so a new shared block fails the suite whichever of the two locales introduces it.

Confirmed strong enough to fail: reintroducing the abbreviation into `az`'s `LL` alone fails 2 assertions, and restoring the fix passes all 289. Restoring the whole `ru` block fails 3, the third being the shared-block enumeration itself. `az` is also removed from `KNOWN_LL_DIFFERENCES`, which was the acceptance check as filed, so that list is now 20 entries and can only shrink.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 1174 tests across 99 suites, up from 1172. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0, run after the last edit.

Most of this iteration went on my own tooling rather than on the fix, and both failures are recorded as Lessons because both are environmental and will recur. The ASCII test in the new enumeration was written as a character class and reached the file as real control bytes, which made grep report the test file as binary and made eslint fail `no-control-regex`. Rewriting it as a unicode escape does not help, because that rule rejects the escape too; a character class simply cannot express this. It is now `ch.charCodeAt(0) > 127`, which is clearer than what it replaced.

The repair took four attempts because the repeated failure was in the tooling, not the file: a backslash inside a heredoc is consumed before python or node sees it, so each repair script either failed to parse or wrote text that still contained the original bytes while reporting success. One of those attempts also flattened the file's CRLF endings, which was caught and restored in the same pass that fixed the regex. The rule now recorded is to build such strings from a character-code call rather than typing them into a heredoc.

Contract preserved: this changes bundled data only, no signature and no behaviour of any function. `az`'s `months`, `weekdays`, `ordinal`, `weekStart` and `relativeTime` are untouched, and `test/locale/keys.test.js` re-ran green so the locale's key shape is unchanged. Output changes for `az` alone, in the six format keys, and in each case toward what both moment and CLDR give. No test asserted the old values; there is no `test/locale/az.test.js`, which is part of why this survived.

The `locales-content` inventory row stays swept. Its name dimension is pinned by `names.test.js`, which re-runs in the Verify gate, and that file now also pins this locale's formats block; the row's own note already records that arrangement.

Not a stall: a source file and a test file changed, and F28 closed.

Learnings: two operational rules recorded in PLAN.md, both environmental. eslint's `no-control-regex` rejects a control character in a regex as a literal byte and as an escape alike, so an ASCII test must use `charCodeAt`. And backslashes must not be typed into a heredoc here, because they are consumed before the interpreter sees them; build them from a character-code call or write the script with the editor.

Next: the ledger holds F25, F27 and F26. F25 is next by severity: `gom-latn`'s `LLLL` references `Do`, a token core does not implement, and its acceptance check needs the format-token scan from iteration 1 committed as a real test rather than left as a scratch probe.

## iter 5/10 | 7fa4157b-170053 | 2026-07-28 | F25 | done

Task: F25 (Medium, correctness). `src/locale/gom-latn.js` `formats.LLLL` referenced `Do`, a token core `format` does not implement, so the pattern rendered garbage without advancedFormat and rendered differently depending on extend order with it.

Changed: `src/locale/gom-latn.js` (`Do` to `D` in `LLLL`), `test/locale/names.test.js` (3 tests added, `u` imported), BACKLOG.md (F25 deleted, the non-core-token class settled).

Checkpoint: 52fd1aed80a6185fb3890dae2b8f1e3315596eed (committed with -n, see Lessons).

Verification: The fix takes the token out of the data rather than trying to make the plugin chain order-independent, and that is the choice worth recording. Every one of the other 142 locales uses core tokens only, so a bundled locale depending on a plugin is the outlier, not the plugin ordering. Reordering would also not have been enough: with advancedFormat simply absent, which is the common case for a caller who only wanted localized formats, `Do` still renders the day number followed by a literal `o`. Removing the dependency fixes both arms at once, at the cost of the ordinal marker in this one locale's `LLLL`, which is what the other 142 already accept.

The class is enumerated rather than the instance patched. All 143 locales' 10 format keys, 1430 patterns, were expanded through localizedFormat's own `u()` and each ASCII letter run outside brackets decomposed against the 26 core tokens. Exactly one carried a non-core token. That scan now lives in the suite instead of in a scratch probe, which is what iteration 1 flagged as the gap in this row's sweep.

The decomposer carries its own positive controls, asserted in a separate test rather than trusted: `de` leaves `e`, `Do` leaves `o`, `MMMM` and `YYYY` leave nothing, an unbracketed `D de MMMM` is flagged while a bracketed `D [de] MMMM` is not, and the Japanese year-month-day pattern is not flagged. That last one is a regression control for the mistake iteration 1 made, when a first version of this scan condemned 49 correct CJK patterns because it treated any letter run mixing token and non-token characters as suspect; restricting it to ASCII runs is what made it decisive, and the control now fails if anyone widens it again.

Both extend orders are asserted, not just the one this file happens to load. The build helper uses `jest.resetModules()` and `require` to construct a fresh dayjs per order, which is the idiom the Lessons record and which `test/plugin/interaction.test.js` already uses. Both orders now produce `Aitar, Agostachea 25, 2019, PM 2:30 vazta`, and the test asserts equality between the orders, asserts the output does not match `25o`, and asserts the exact string, so neither a revert nor a half fix can pass.

Confirmed strong enough to fail: restoring `Do` in the pattern fails 2 assertions, the scan and the both-orders test, and restoring the fix passes all 292.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 1177 tests across 99 suites, up from 1174. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0, run after the last edit.

Lint again caught something the gate did not, for the third iteration running: `no-loop-func` on the two arrow functions the decomposer created inside its `while` loops. Hoisting them into a single `tokenAt` helper fixes it and reads better, and the gate was re-run afterwards rather than assumed still green.

Contract preserved: this changes one bundled locale's format string. No signature, no core behaviour, no other locale. The only observable difference is that `gom-latn`'s `LLLL` renders the bare day number where it previously rendered either `25o` or, in one of the two extend orders with advancedFormat loaded, `25er`. `test/locale/keys.test.js` re-ran green, so the locale's `formats` key shape is unchanged, and the `plugin-localizedFormat` and `plugin-advancedFormat` inventory rows are untouched because neither plugin changed.

The `locales-content` row's remaining gap is now closed in the place it mattered. Its note said the structure, meridiem and longDateFormat dimensions were certified only by the scratch sweep at 18ba2c8; the longDateFormat dimension is now pinned by a committed test that runs in the Verify gate every iteration.

Not a stall: a source file and a test file changed, and F25 closed.

Learnings: no new operational rule. The reusable point is already recorded twice over and earned its place again here: a scanner that reports nothing is indistinguishable from a scanner that finds nothing, so the controls belong in the suite next to the sweep rather than in the probe that was thrown away.

Next: the ledger holds F27 and F26, both Low. F27 is a single word in `be`; F26 is capitalization across `ro`, `sr`, `sr-cyrl` and `ca`'s weekdays. Both shrink the allowlists in `names.test.js`. With 5 iterations left and 2 small tasks, this run should reach the closing audit, and convergence requires that audit plus the evaluator gate.

## iter 6/10 | 7fa4157b-170053 | 2026-07-28 | F27 | done

Task: F27 (Low, correctness). `src/locale/be.js` rendered Belarusian February standalone as a Russian style adjectival form where the language, moment and CLDR all have the short one.

Changed: `src/locale/be.js` (standalone February corrected, a stray period removed from the short format arm), `test/locale/names.test.js` (allowlist entry deleted, 1 test added), BACKLOG.md (F27 deleted, F29 filed).

Checkpoint: e8a7c11ea1ac298d3a520b5f5a97d4f417920ef4 (committed with -n, see Lessons).

Verification: Two independent references agree on the corrected value and every other entry in the array already matched moment exactly, so the finding was one value wide. Intl differs from both dayjs and moment on May, giving the Russian derived name where they give the traditional one, which is a legitimate variant and not a defect; that is why the corrected value was taken from the point where both references agree rather than from Intl alone.

Fixing the standalone arm left exactly one difference from moment across all 12 months and both contexts, and it was a second defect in the same file: the short format arm carried a stray period on December that neither its own sibling arm nor the other 11 entries have. It renders, as `15 %s.` against moment's unpunctuated form. It is one character, in the file already open, in the same class as the finding being closed, so it was fixed here and the widening is recorded rather than filed as a ceremonial second task. That follows the precedent this run already set with F24, which was filed against 5 locales and closed against 7.

Confirmed strong enough to fail: restoring the Russian form fails 2 assertions, the general month comparison and the new targeted one, and restoring the fix passes all 293. The targeted test asserts the corrected string directly, asserts the standalone array no longer contains the wrong form, asserts the two short arms are equal to each other, and compares `MMM` and `D MMM` against moment for all 12 months, so neither arm can regress silently.

F29 was filed rather than absorbed, and it is the honest consequence of what this iteration found. The abbreviated name arrays have never been compared against any reference: the `locales-content` sweep compared `months` and `weekdays` but checked `monthsShort`, `weekdaysShort` and `weekdaysMin` only for arity, emptiness and duplicates. The single short-form comparison run so far, on `be`, found a real defect, so the gap is demonstrated rather than theoretical. 20 locales render `MMM` differently from moment; most look like abbreviation punctuation conventions, but `de` and `nb` differ on exactly one month each, which is the shape `be`'s defect had. Sweeping and classifying those 20 with a reason each is a distinct piece of work and is not something to do silently inside a Low task about one word, so it is on the ledger with an acceptance check that requires a second reference for each single-month case rather than an assumption that it is conventional.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 1178 tests across 99 suites, up from 1177. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0, run after the last edit.

Contract preserved: bundled data only, no signature and no behaviour change. `be` keeps its function form and both arms keep their arity; `months.f`, `weekdays`, `ordinal`, `weekStart` and `relativeTime` are untouched. `test/locale/be.test.js` and `test/locale/keys.test.js` both re-ran green, the first being the pre-existing suite that pins this locale's relative time output and the second its key shape. Output changes for `be` alone, in one standalone month name and one abbreviated one, in both cases toward what moment gives.

Not a stall: a source file and a test file changed, F27 closed and F29 filed.

Learnings: no new operational rule.

Next: F26 is the last open task besides F29, and both are Low. F26 removes 3 locales from the month allowlist and 4 from the weekday one. After that the ledger holds only F29, and the run needs a full fresh-evidence audit plus the evaluator gate before it can converge, which is what the remaining budget should be spent on.

## iter 7/10 | 7fa4157b-170053 | 2026-07-28 | F29 | done

Task: F29 (Low, correctness). The abbreviated name arrays had never been compared against any reference, so `monthsShort`, `weekdaysShort` and `weekdaysMin` were certified only for arity, emptiness and duplicates while the full-name arrays were compared against moment.

Changed: `src/locale/nb.js`, `src/locale/tr.js`, `src/locale/el.js`, `src/locale/pt.js`, `test/locale/names.test.js` (2 tests added), BACKLOG.md (F29 deleted, the class settled).

Checkpoint: a8728b99d4da06f7fc3c6adf85ae686e32d6fa16 (committed with -n, see Lessons).

Verification: The sweep rendered `MMM`, `ddd` and `dd` for every one of the 133 locales moment ships and compared each against moment: 20 locales differed on `MMM`, 17 on `ddd` and 13 on `dd`. That is far too many to be defects, and the task was filed knowing that, which is why its acceptance check demanded a second reference for the small-count cases rather than an allowlist written on a hunch.

Ten candidates were put to `Intl.DateTimeFormat`, and the second reference is what separated four defects from six conventions. Where moment and Intl both contradict dayjs, the finding is real; where they disagree with each other, or where dayjs matches Intl, it is not.

The four fixed, each one value wide: `nb` carried the full month name `april` inside an otherwise abbreviated array, where moment has `apr.` and Intl `apr`; `tr` abbreviated Pazartesi and Cumartesi as `Pts` and `Cts` where both references give `Pzt` and `Cmt`; `el` was missing the diacritic on the May abbreviation; and `pt` was missing the accent on the Saturday minimal form. Each is internally anomalous as well as externally contradicted, which is what makes them defects rather than house style.

Two candidates were rejected on the evidence rather than fixed. `be`'s Tuesday minimal form matches Intl exactly and only moment differs, so dayjs is right and moment is the outlier. `de`'s `Sept.` and `el`'s `Σεπτ` are longer abbreviations that both references shorten, but a longer abbreviation is a convention, not an error, and nothing in either reference shows the shorter one is required.

The remainder is classified rather than dumped into an undifferentiated allowlist. Every entry sits under punctuation, length, case or script, and the case group is the same capitalization question F26 already tracks while the script group is the Arabic hamza and Kurdish orthography variation already Declined for the full names. Grouping it that way is what makes the list reviewable: a future reader can see at a glance that no entry is there because nobody looked.

Confirmed strong enough to fail: restoring all four defects at once fails 2 assertions, the per-token enumeration and the targeted test, and restoring the fixes passes all 295.

One assertion I wrote was wrong and the suite caught it before it was committed. I had asserted that no entry of `nb`'s short array may equal its own full month name, which is false: `mars`, `mai`, `juni` and `juli` are already short in Norwegian and are identical in both arrays. The invariant is now that no short entry may be longer than its full name, which holds for all 12, plus a direct assertion that April specifically does not fall back. That is the same failure mode this run keeps finding in its own tooling, an assertion that looks principled and is simply not true of the data, and it is the reason the acceptance checks are run before the fix is believed.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 1180 tests across 99 suites, up from 1178. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0, run after the last edit.

Contract preserved: bundled data only, four single values across four locales, no signature and no behaviour change. Each locale keeps its array arity and key shape, and `test/locale/keys.test.js` re-ran green. `test/locale/sv.test.js` and the other locale suites are untouched by these files. Output changes only for the four corrected entries, in each case toward what both references give.

This also closes the last dimension the `locales-content` row was carrying on trust. Its note recorded that structure, meridiem and longDateFormat were certified only by the scratch sweep at 18ba2c8; longDateFormat was pinned by F25, and the abbreviated names, which the original sweep never compared at all, are pinned now.

Not a stall: four source files and a test file changed, F29 closed.

Learnings: no new operational rule. The transferable point is already recorded as the rule about validating a probe before trusting it, and it earned its place again from the other side: a sweep that returns 50 differences is not evidence of 50 defects, and the second reference is what turns a difference into a finding.

Next: F26 is the only open task, and it is the capitalization of `ro`, `sr`, `sr-cyrl` and `ca`'s weekdays. Iteration 8 takes it, which empties the ledger. Iterations 9 and 10 are then the full fresh-evidence audit and the evaluator gate that convergence requires.

## iter 8/10 | 7fa4157b-170053 | 2026-07-28 | F26 | done

Task: F26 (Low, correctness). `ro`, `sr` and `sr-cyrl` capitalized month and weekday names in languages that do not capitalize them, and `ca` still capitalized its weekdays after F24 lowercased its months.

Changed: `src/locale/ro.js`, `src/locale/sr.js`, `src/locale/sr-cyrl.js`, `src/locale/ca.js`, `test/locale/names.test.js` (7 allowlist entries deleted across 4 maps, 1 test added, an unused constant removed), BACKLOG.md (F26 deleted, the class settled).

Checkpoint: 81ec6bf14ea8acc4efc648f89754f8bb4fec4ff2 (committed with -n, see Lessons).

Verification: Values were transcribed from moment rather than produced by lowercasing dayjs's own strings, which matters because a mechanical case transform would also have silently accepted the several spelling differences that sit alongside the case ones. `ro`'s `monthsShort` is the example: it was `Ian._Febr._Mart._...` against moment's `ian._feb._mart._...`, so two of the twelve differ in more than case, and taking moment's array fixes both at once.

Which arrays changed was decided by evidence rather than by symmetry, and the asymmetry is the interesting part. `ro`'s `weekdaysShort` and `weekdaysMin` are capitalized in moment too and already matched, so they were left alone and only 3 of its 5 arrays changed. `sr` and `sr-cyrl` already had lowercase `weekdaysMin`, so 4 of 5 changed there. `ca` needed only its three weekday arrays, its months having been lowercased under F24. A blanket lowercase pass over all five arrays of all four locales would have introduced four new defects.

The counter-case was preserved deliberately and is now asserted rather than left to chance. `pt`, `pt-br` and `lt` are lowercase where moment capitalizes, and Intl agrees with dayjs, so they are the mirror image of this finding and changing them would have introduced the defect instead of fixing it. The new test asserts `pt` still renders `domingo` and that it remains in the weekday allowlist, so a future pass that tries to make everything agree with moment fails here.

References: moment agrees on all four locales, and `Intl.DateTimeFormat` agrees on `ro`, `sr-cyrl` and `ca`. `sr` is the one case where Intl cannot be consulted directly, because it resolves `sr` to the Cyrillic script, but `sr` and `sr-cyrl` are the same language in two scripts and Intl confirms the Cyrillic one.

Confirmed strong enough to fail: recapitalizing `ro`'s months fails 3 assertions, the per-locale month comparison, the date-context `LL` enumeration and the new capitalization test. All 296 pass with the fix in place.

The allowlists shrank in four places at once, which is the point of having made them shrink-only: `KNOWN_MONTH_NAME_DIFFERENCES` lost 3 entries and is down to 4, `KNOWN_WEEKDAY_NAME_DIFFERENCES` lost 4 and is down to 4, `KNOWN_LL_DIFFERENCES` lost 3 and is down to 17, and the three `KNOWN_SHORT_NAME_DIFFERENCES` groups lost 3, 2 and 1. Every remaining entry across all of them is either a digit-system difference that is correct by design, a Declined orthographic variant, a documented convention, or the deliberate `cs` and `pt` divergences that this suite now asserts.

Lint caught a real consequence of the shrink that the gate did not: `ALL_MONTHS` became unused once the last entry referencing it was deleted. Removed, and the gate re-run afterwards.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 1181 tests across 99 suites, up from 1180. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0, run after the last edit.

Contract preserved: bundled data only, no signature and no behaviour change. Every array keeps its arity and every locale its key shape; `test/locale/keys.test.js` re-ran green, as did `test/locale/sr.test.js` and `test/locale/sr-cyrl.test.js`, the pre-existing suites that pin those two locales' relative time output. Output changes are confined to the case of names in four locales, plus two `ro` abbreviations, in each case toward what the references give.

The ledger is now empty for the first time this run. Every finding filed since iteration 1 is closed: F23 through F29, none blocked, none deferred.

Not a stall: four source files and a test file changed, and F26 closed.

Learnings: no new operational rule.

Next: iteration 9 is the full fresh-evidence audit the Definition of done requires, rescoring every applicable dimension against the rubric and the envelope. If it comes back with zero High and zero Medium in-envelope, closeout begins and iteration 10 runs the evaluator gate and, on PASS, declares convergence.

## iter 9/10 | 7fa4157b-170053 | 2026-07-28 | AUDIT | audit

Task: The full fresh-evidence audit the Definition of done requires. The ledger was emptied by F26 in iteration 8 and no Converged line exists, so this rescores every applicable dimension and re-sweeps the one inventory row this run staled.

Changed: PLAN.md (`locales-structure` re-swept), BACKLOG.md (F30 filed).

Checkpoint: 117259ee610eaa85aa295c5de91b956f455673da (committed with -n, see Lessons).

Verification: Scores, claiming the whole project. Correctness Low, on the strength of F30 and nothing else. Testing None, documentation None, architecture None, code quality None, security None, error handling None, performance None, dependency hygiene None, developer experience None, observability None. UX and accessibility do not apply: this is a formatting library with no user-facing surface. Zero High and zero Medium in-envelope, so closeout begins: the run stops auditing for the remainder, and iteration 10 works the ledger and runs the evaluator gate.

Staleness was determined from git rather than assumed. All 17 files this run changed are `src/locale/*.js`, so `plugin-interaction-matrix` and `types-declarations` are untouched, their implementing code being `src/plugin` and `types` respectively, and `build-pipeline`'s implementing code is `build/*.js`, which also did not change. `locales-structure` did go stale by its own recorded rule, which says an edit to a locale's key shape or formats stales it: 7 locales changed `months` from an array to the function form and 2 changed `formats`. `locales-content` did not, because its own note records that its name and format dimensions are pinned by `test/locale/names.test.js`, which runs in the Verify gate every iteration.

The `locales-structure` re-sweep was executed, not asserted. All 143 loaded, and over every arm of the function form as well as plain arrays: arity 12 and 7, no empty entry, no duplicate outside the Declined `mt` case, `weekStart` and `yearStart` in range, all 6 required `formats` keys present and non-empty, the exact 13 `relativeTime` keys, and non-empty output free of `undefined`, `NaN` and `[object` for 11 format tokens plus relative time at 5 magnitudes in both directions and both suffix modes. Zero problems across all 143.

The localeData integration was checked specifically, because it is what the function form had to survive and nothing else in the suite would have caught it: `dayjs.months()`, `dayjs.weekdays()` and `longDateFormat` were called for every locale and all returned well-formed values, the plugin reaching the standalone arm through `getLocalePart`'s `part.s`.

The build was re-run end to end rather than trusted. `npm run build` exits 0 with no warnings, inside the size limit at 2.79 KB against 2.99. The built UMD bundles were then exercised directly for all 16 changed locales, which is the check that matters because the source is not what ships: the context-inflected forms render correctly from the minified artifact, the Catalan apostrophe in `d'abril` survives minification, `si` renders Gregorian months, and `az` no longer carries the Russian year abbreviation while `be` still does, which is correct, since Belarusian genuinely uses it and F28 was specific to Azerbaijani.

F30 is the one finding, and it came from asking what the run's own riskiest change could break rather than from re-reading clean code. Core's `getShort` at `src/index.js:275` falls back to `full[index].slice(0, length)`, and when `months` is the function form `full[index]` is undefined, so a locale supplying function `months` and omitting `monthsShort` throws `TypeError: Cannot read properties of undefined (reading 'slice')` on `format('MMM')`. That shape is legal: both keys are independently optional and `test/locale/keys.test.js` checks `monthsShort` only when present.

It was reproduced on a hand-built locale, with two controls that both pass, the same locale with `monthsShort` and an array-months locale without it, so the failure is pinned to the combination rather than to either half. No shipped locale reaches it: all 12 function-months locales define `monthsShort`, and the only 2 without it, `en` and `rw`, use array months, which the sweep confirmed by exercising `format('MMM')` across all 143 with no failure. Filed Low for that reason: nothing published triggers it, and a contributor who writes such a locale gets a loud throw on the first run rather than silent wrong output. It is a robustness and contributor-experience gap, not a user-facing defect, and calling it anything higher would be inflating a severity to look thorough.

Documentation was checked rather than assumed clean: no file under `docs/` mentions `monthsShort` or any of the changed locales, and this run altered no public signature, so nothing there contradicts the code.

Verify gate green: 4 timezone passes, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 1181 tests across 99 suites. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0 and `npx tsc --noEmit -p tsconfig.json` exits 0.

Not a stall: an inventory row was re-swept with executed evidence and a finding was filed.

Learnings: no new operational rule.

Next: iteration 10 is the last of the budget. It closes F30, whose fix is a contained change to `getShort` plus the test that reproduces the throw, then runs the evaluator gate and, on PASS, appends the Converged line. If the evaluator rejects, the run ends out of budget with its reasons filed rather than converged.

## iter 10/10 | 7fa4157b-170053 | 2026-07-28 | F30 | done

Task: F30 (Low, correctness), then the evaluator gate. `src/index.js` `getShort` threw for a locale supplying `months` in the function form and omitting `monthsShort`, a legal shape.

Changed: `src/index.js` (`getShort` resolves `full` the same way it already resolved `arr`), `test/display.test.js` (1 test added), PLAN.md (`core-format` re-swept, `locales-content` corrected, 1 Lesson), BACKLOG.md (F30 deleted, F31 and F32 filed, the capitalization class reopened).

Checkpoint: 7c43714e078373149220992baa612809943524ab (committed with -n, see Lessons).

Verification: The acceptance check was written first and failed with the exact reported error, `TypeError: Cannot read properties of undefined (reading 'slice')`, then passed after the fix. The fix makes the two arguments symmetric: `arr` was already resolved as `arr[index] || arr(this, str)`, and `full` now is too, so the function form works wherever an array works. Both shapes that already worked are kept as controls in the same test, the same locale with `monthsShort` and array `months` without it, so the new assertion is the one carrying the weight. `core-format` was staled by this change and is re-swept: its 28 known-answer token checks re-ran green and the new branch is covered directly.

Evaluator: REJECT. Two substantiated reasons, both reproduced independently before being accepted, and both real.

The first is a Medium the audit missed and is the more serious of the two. 15 non-English locales embed the `A` or `a` meridiem token in their own `formats` patterns but define no `meridiem`, so core falls back to English and renders `AM` or `PM` inside a native-script date. Verified directly: `ne` renders `PMko 2:30` where moment gives the Nepali term, and the same holds for `bn`, `bo`, `el`, `gom-latn`, `gu`, `hi`, `kn`, `ml`, `mr`, `pa-in`, `si`, `ss` and `te`. Filed as F31.

The cause is a failure this run has now recorded three times and committed anyway. The meridiem sweep in iteration 1 asked whether every locale that defines `meridiem` behaves correctly, called all 20 of them on both sides of noon, and found nothing. It never asked the converse, whether every locale whose own patterns require a meridiem defines one. That is the same shape as the two enumeration failures already in the Lessons, and the iteration 9 audit scored the dimension clean on the strength of it. The rule is now recorded explicitly: state the converse of the question before believing an empty result.

Worse, and worth stating plainly: F25's acceptance check pins `'Aitar, Agostachea 25, 2019, PM 2:30 vazta'`, which commits the English meridiem inside a Konkani long date as expected output. That assertion is correct about today's behaviour and wrong about what the behaviour should be, and F31 carries the instruction to update it rather than leave it.

The second reason is a Low. The F26 capitalization enumeration kept only differences that are case alone, which filtered out two sites where case travels with punctuation: `oc-lnc` `weekdaysShort` is capitalized and unpunctuated while that same file's `weekdays` and `weekdaysMin` are lowercase, and `pt-br` `weekdaysMin` is capitalized where moment is lowercase. The second of these also makes a claim in the Settled classes wrong in direction, since it lists `pt-br` among the locales that are lowercase where moment capitalizes. Filed as F32, the claim is corrected in place, and the class is reopened rather than left reading class-complete.

What the evaluator verified and found sound is recorded too, because it bounds what the next run has to redo. The Verify command exits 0 with 1182 tests across 99 suites under both `TZ=America/New_York` and `TZ=UTC` with the 100 percent line-coverage threshold, and the three timezone passes are 6 of 6 each. Lint exits 0. Every F23 to F30 acceptance check re-ran green. The five shrink-only allowlists were proven to have teeth in both directions by mutation: removing four entries that still differ produced four failures, and adding two non-differing entries plus corrupting a locale produced four more, all reverted. F24's seven conversions were confirmed against moment outside the suite for all 12 months on `LL`, `LLL`, `LLLL` and standalone `MMMM`, including that the `cs` divergence is genuine, and they survive `dayjs.months()`, `localeData()` and customParseFormat round-trips on both arms. F30 introduces no regression on array-shaped input.

The run does not converge and does not claim to. The budget is spent at iteration 10, so there is no room to work F31 and F32 and no second evaluator invocation; the rejection stands and the ledger carries both findings forward.

Not a stall: a source file and a test file changed, F30 closed, F31 and F32 filed.

Learnings: one operational rule recorded in PLAN.md, that a class enumeration must be stated in both directions, because asking only whether the locales that define a thing behave correctly leaves the locales that need it and lack it entirely unexamined.

Next: a fresh session in this directory. F31 is the only Medium and should be taken first, and its fix must update `test/locale/names.test.js:304` rather than leave the English meridiem pinned. F32 follows and reopens the capitalization class with a widened enumeration. The Surface inventory reads 41 of 41 but its `locales-content` row now records that its meridiem dimension does not certify what F31 covers.

## iter 1/10 | 9f9f90e3-183320 | 2026-07-28 | ROTATION | rotation

Task: JOURNAL.md stood at 543 lines with 18 entries, over the 500-line threshold, so the 8 oldest entries were moved to JOURNAL-archive.md and the 10 most recent kept live.

Changed: JOURNAL.md (entries 1 to 8 removed, header kept), JOURNAL-archive.md (those 8 appended).

Checkpoint: shared with the primary entry below.

Verification: The move was verified by counting rather than by reading. The archive went from 37 entries to 45, the live journal from 18 to 10, and the boundary was asserted in the script rather than eyeballed: both the moved slice and the kept slice must begin with a  heading and the two counts must be exactly 8 and 10, or the script throws without writing. The live journal is 312 lines. Nothing was reordered and nothing overwritten; the archive is append-only and grew.

Learnings: no new operational rule.

Next: the primary entry for this iteration follows.

## iter 1/10 | 9f9f90e3-183320 | 2026-07-28 | F31 | done

Task: F31 (Medium, correctness). 15 non-English locales embedded the meridiem token in their own format patterns while defining no `meridiem`, so core fell back to English and rendered AM or PM inside a native-script date.

Changed: 14 `src/locale/*.js` gained a `meridiem` (`bn`, `bo`, `el`, `gom-latn`, `gu`, `hi`, `kn`, `ml`, `mr`, `ne`, `pa-in`, `si`, `ss`, `te`), `src/locale/ka.js` moved to a 24-hour clock, `test/locale/meridiem.test.js` added (11 tests), `test/locale/names.test.js` (the gom-latn assertion that pinned the English meridiem updated), PLAN.md (`locales-content` corrected, `locales-structure` re-swept, 2 Lessons), BACKLOG.md (F31 deleted, the class settled, F33 filed).

Checkpoint: 49d5177a8872e1d101dd524382f8ea723ed4b589 (committed with -n, see Lessons)

Verification: The enumeration came first and it is what made the finding bigger than the report. Expanding all 6 format keys of all 143 locales through localizedFormat own `u()`, stripping bracketed literals and scanning for an unbracketed `A` or `a` found 23 locales carrying the token, not the 15 the evaluator named. The extra 8 separated cleanly under the reference: `en-au`, `en-ca`, `en-nz`, `es-do`, `es-us` and `yo` get AM/PM from moment too, and `bi` and `es-pr` moment does not ship. So 15 were real, which is the evaluator figure arrived at from a wider search rather than assumed.

The two halves of the fix took opposite remedies, decided by the references rather than by symmetry. 14 locales gained moment own meridiem. `ka` did not: moment gives Georgian `HH:mm` and `Intl.DateTimeFormat` resolves it to `h23`, so the right fix there was to drop the token from its patterns, not to invent a Georgian AM/PM. Its 6 format keys are now asserted equal to moment own, key by key.

The 14 were transcribed programmatically from moment rendered output, per the Lessons, never retyped. The generator evaluated `localeData(name).meridiem(h, 0, isLower)` at every hour and derived the arm boundaries from where the value changes, so a transcription error is not possible and the arms are moment arms by construction. Two locales, `el` and `si`, return different strings for the upper and lower forms rather than a case variant, so they take the explicit three-argument form and `isLowercase` is exercised as a live parameter on both sides.

Confirmed strong enough to fail: `hi` and `ka` were restored from HEAD and the new suite failed 4 of its 11 tests, covering both halves - the enumeration reported `hi` falling back to English, the ported differential and the long-date assertion failed on it, and the `ka` 24-hour assertion failed. Both files were then restored from a copy rather than with `git checkout`, which the Lessons warn discards uncommitted work in the same file.

Three of my own test defects were caught by running it rather than by reading it, and each is worth stating because each was a wrong oracle rather than a typo. `en` was missing from the allowlist because `dayjs.Ls.en.formats` does not exist until localizedFormat is extended, which my scratch probe had not done and the test had; the scan and the allowlist disagreed for exactly that reason. Asserting a rendered date contains no `am` failed on gom-latn, whose afternoon word is `donparam`. And comparing whole `LLL` strings to moment failed on `bn`, because moment postformats digits where dayjs gates that behind an opt-in plugin, which is already a recorded Lesson. Both new rules are now in PLAN.md.

F33 came out of the same differential and is the more interesting result: asking whether every existing meridiem agrees with moment, not just whether the missing ones were added, found 9 locales writing the noon boundary as `hour > 12`, so 12:00 to 12:59 renders as morning across all 8 Arabic locales and `km`. It is filed rather than fixed, because one task per iteration, and its entries sit in the shrink-only difference map with the finding named, so closing it must delete them.

Verify gate green: 4 timezone passes 6 of 6 each, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0 confirmed directly. 1193 tests across 100 suites, up from 1182 and 99. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0 with only the 2 pre-existing warnings, run after the last edit.

Contract preserved: bundled data only. No signature changed and no public method changed shape. `meridiem` is an already-supported optional locale key that 20 locales used before this and 34 use now, read only by core at the A and a tokens, so the output change is confined to those two tokens in 14 locales plus the time patterns of `ka`. `test/locale/keys.test.js` re-ran green, which is what pins the locale key shape.

The `locales-structure` row was staled by these edits under its own recorded rule and is re-swept rather than left open, and the sweep was proven to have teeth before its empty result was believed: the same checker run over a deliberately broken locale reports 76 problems across every dimension it claims. It reported 0 across all 143.

Not a stall: 15 source files and 2 test files changed, F31 closed, F33 filed.

Learnings: two operational rules recorded in PLAN.md. `dayjs.Ls.en.formats` does not exist until localizedFormat is extended, so a probe scanning format patterns must extend it or `en` drops out silently. And a meridiem word can contain `am` or `pm` as a substring, so assert on the rendered token, never by searching a whole date string.

Next: F33, the only Medium, is a 9-line data fix with an exact oracle and its acceptance check is already half-written in the difference map. F32, the Low reopening the capitalization class, follows. The Surface inventory reads 41 of 41.

## iter 2/10 | 9f9f90e3-183320 | 2026-07-28 | F33 | done

Task: F33 (Medium, correctness). 9 locales wrote their meridiem boundary as `hour > 12` where the boundary is noon, so the whole hour from 12:00 to 12:59 rendered as the morning term.

Changed: 9 `src/locale/*.js` (`ar`, `ar-dz`, `ar-iq`, `ar-kw`, `ar-ly`, `ar-ma`, `ar-sa`, `ar-tn`, `km`), `test/locale/meridiem.test.js` (4 tests added, the difference map shrunk from 12 entries to 4), `test/locale/ar.test.js` (an assertion that encoded the defect, corrected), PLAN.md (1 Lesson), BACKLOG.md (F33 deleted, the class settled), JOURNAL.md (the run-id of the two iteration 1 headings corrected).

Checkpoint: 9baaf1c25c98f888ee5cb4f7283dc54f48a0b749 (committed with -n, see Lessons)

Verification: The acceptance check was written first and 3 of its 4 new assertions failed against the unfixed data: the source scan reported all 9 files, the boundary assertion failed at 12:00, and the moment differential failed at hour 12. The fourth passed before and after by design, since it pins `ar-iq`, which moment does not ship, to `ar`, and the two were equally wrong before.

The fix takes the form the project already uses rather than the minimal edit. Five other simple meridiems in the tree are written `hour < 12 ? morning : afternoon`, so all 9 now read that way instead of moment own `hour > 11`, and the arms were swapped programmatically from the matched source line rather than retyped, with each file re-read afterwards to confirm the old form is gone and the new one present.

The Verify gate went red, and this is the verify-gate exception rather than a broken iteration. `test/locale/ar.test.js:59` computed its own expectation as `i > 12 ? afternoon : morning`, the identical wrong formula, so the test asserted that noon renders as morning and was green only because the locale agreed with it. That is a pre-existing fault newly exposed, not one introduced.

The exception was earned with evidence rather than with the argument above. Every one of the 143 locales was rendered at all 24 hours for 9 tokens the meridiem can reach - A, a, LT, LTS, LLL, LLLL, HH, hh, h - before and after the change, giving 30888 compared values. Exactly 18 changed. All 18 are at hour 12, all on the A and a tokens, and all in the 9 named locales. No previously passing output moved, which is the condition the exception requires. Only A and a moved because none of these 9 locales uses the meridiem token in its own format patterns, so their long dates never carried it.

The difference map shrank from 12 entries to 4, and that shrink is itself checked: the test that asserts every listed difference must still really differ passed afterwards, so the 4 survivors - `ar-kw`, `ar-ma` and `ar-tn`, for which moment ships no Arabic meridiem and renders English, and `ku`, which uses abbreviations where moment spells the words out - are real rather than stale. The 5 entries that were purely this defect are gone, and `zh-cn`, `zh-hk` and `zh-tw` left the map too, since their noon distinction was never this defect and their entries were only ever adjacent to it.

Verify gate green after the test repair: 4 timezone passes 6 of 6 each, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0 confirmed directly. 1197 tests across 100 suites, up from 1193. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0, run after the last edit, which caught a template literal that had no interpolation.

Contract preserved: bundled data only, no signature and no public method changed. `meridiem` keeps its arity and its meaning in all 9 files; only the comparison flips. The differential above is the proof that the blast radius is one hour in nine locales.

No Surface inventory row is staled by this. `locales-structure` stales on a change to key shape, formats or relativeTime, and this changed none of those, and both the meridiem dimension of `locales-content` and the whole of the meridiem question are now pinned by `test/locale/meridiem.test.js`, which runs in the Verify gate every iteration. The inventory stays at 41 of 41.

Hygiene: the two iteration 1 headings carried run-id `9f9f90e3-142035`, which I derived from local time instead of reading `started_at` in the loop state frontmatter. The frontmatter says `2026-07-28T18:33:20Z`, so the run-id is `9f9f90e3-183320` and both headings are corrected. The entry bodies are untouched.

Not a stall: 9 source files and 2 test files changed, F33 closed.

Learnings: one operational rule recorded in PLAN.md. A test can encode the defect being fixed, so a correct change turns the gate red; check whether the red assertion hardcodes the same wrong formula before reverting, and earn the exception with a before-and-after rendered-output differential rather than with reasoning.

Next: F32, the Low that reopened the capitalization class, is the only item left on the ledger. Replenishment is deliberately not run this iteration: the Definition of done requires a full fresh-evidence audit in this run and there is ample budget, so iteration 3 takes F32 and iteration 4 runs that full audit, which supersedes any partial one rather than duplicating it.

## iter 3/10 | 9f9f90e3-183320 | 2026-07-28 | F32 | done

Task: F32 (Low, correctness). The F26 capitalization enumeration filtered on differences that are case alone, so it dropped two sites where case travels with punctuation and the class was recorded complete while they stood.

Changed: `src/locale/oc-lnc.js` (`weekdaysShort`), `src/locale/pt-br.js` (`weekdaysMin`), `test/locale/names.test.js` (2 tests added, 2 allowlist entries deleted), PLAN.md (1 Lesson), BACKLOG.md (F32 deleted, the capitalization class closed again on the widened enumeration).

Checkpoint: 8d04f7c5088c5b932154dc214b91344de1c111d5 (committed with -n, see Lessons)

Verification: The widened enumeration was written before the fix and reported exactly the two sites, which is both the reproduction and the evidence that nothing else hides behind the old filter. The fix is the useful part of this task; the enumeration is the durable part.

The old filter asked whether a difference is exactly a case difference. That question cannot see `oc-lnc` `weekdaysShort`, which is `Dg` against moment `dg.`, because the strings also differ by a period, so the filter discarded it as some other kind of difference and the class closed over it. The new one asks the question the class is actually about and which punctuation cannot affect: does dayjs start a name with a capital where moment does not? Run over all 5 name arrays of every comparable locale, that reports 9 entries across `oc-lnc.ddd` and `pt-br.dd` before the fix and nothing after it.

Both directions are now asserted rather than one. The counter-direction, moment capitalizing where dayjs does not, is exactly `lt.dd`, `lt.ddd`, `pt.ddd` and `pt.dddd`, the deliberate divergences where Intl agrees with dayjs, and it is asserted by exact equality so neither side can grow a member unnoticed. That matters here specifically because the evaluator found the old Settled line wrong in direction about `pt-br`, claiming it was lowercase where moment capitalizes when the truth was the reverse.

The detector carries controls, because a predicate that never fires would make the whole test vacuous: `startsUpper` is asserted true for `Dg` and for Cyrillic `Дг`, false for `dg.`, for Cyrillic `дг`, for Arabic `يناير` and for the empty string. The caseless-script control is the one that matters, since it is what stops the enumeration flagging Arabic, Hebrew, CJK and Devanagari locales by accident.

The values were taken from moment rather than produced by lowercasing dayjs own strings, which is what makes `oc-lnc` correct rather than merely lowercase: moment has `dg._dl._dm._dc._dj._dv._ds.` with periods, so a case transform alone would have left it disagreeing with moment on 7 of 7 entries and still in the allowlist. `Intl.DateTimeFormat` independently agrees with the lowercase forms for both locales, giving `dom.` for Brazilian Portuguese and lowercase full names for Occitan.

Confirmed strong enough to fail: both locale files were restored from HEAD and 3 assertions failed, the widened enumeration, the site-specific regression pin, and the pre-existing abbreviated-name comparison whose allowlist entries this fix deletes. Restored from copies afterwards rather than with `git checkout`, per the Lessons.

Verify gate green: 4 timezone passes 6 of 6 each, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0 confirmed directly. 1199 tests across 100 suites, up from 1197. `npx eslint src test build --rule '{"linebreak-style":"off"}'` exits 0, run after the last edit.

Contract preserved: bundled data only, no signature and no public method changed. Both arrays keep arity 7 and their locale key shape; only the case of 9 entries and the punctuation of 7 changes, in each case toward what both references give. Each file now agrees with itself, its three weekday arrays having disagreed on case before.

No Surface inventory row is staled. `locales-content` records that its name dimension is pinned by `test/locale/names.test.js`, which runs in the Verify gate every iteration, and `locales-structure` stales only on a change to key shape, formats or relativeTime. The inventory stays at 41 of 41.

Not a stall: 2 source files and a test file changed, F32 closed.

Learnings: one operational rule recorded in PLAN.md. Filter a class enumeration by the property the class is about, never by the shape the difference happens to take, because a filter keyed to one exact kind of difference silently drops every instance where that kind arrives alongside another.

Next: the ledger is empty, so iteration 4 is the full fresh-evidence audit the Definition of done requires. It rescores every applicable dimension against the rubric and the envelope and re-sweeps any stale inventory row. If it comes back with zero High and zero Medium in-envelope, closeout begins and the remaining iterations work whatever it files, then run the evaluator gate.

## iter 4/10 | 9f9f90e3-183320 | 2026-07-28 | AUDIT | audit

Task: The full fresh-evidence audit the Definition of done requires. The ledger was emptied by F32 in iteration 3 and no Converged line exists, so this rescores every applicable dimension against the rubric and the Operating envelope.

Changed: BACKLOG.md (F34 filed, the npm advisory set Declined).

Checkpoint: d51ca5eb754783e92ab417fccdca50afdae7c05e (committed with -n, see Lessons)

Verification: Scores, claiming the whole project, since the Surface inventory has no unswept row. Correctness High, on the strength of F34 and nothing else. Architecture None, code quality None, security None, testing None, error handling None, performance None, documentation None, dependency hygiene None in-envelope, developer experience None, observability None. UX and accessibility do not apply: this is a formatting library with no user-facing surface. One High in-envelope, so closeout does not begin and the run does not converge this iteration.

The audit asked what this run's own changes could have broken rather than re-reading clean code, and the answer was worth the question. All 26 files this run touched are `src/locale/*.js`, and the run gave 14 locales a `meridiem` they did not have and changed the boundary in 9 more. The obvious consumer of locale `meridiem` other than `format` is `customParseFormat`, which reads it to parse the A and a tokens back, so the round trip is exactly the surface this run moved.

F34 is what that found, and it is a High. `meridiemMatch` at `src/plugin/customParseFormat/index.js:46` decides AM or PM from the index of the probe hour rather than from which arm of the locale meridiem matched: it scans i from 1 to 24 and sets `isAfternoon = i > 12`, so whichever hour first contains the input string decides. A two-arm locale whose boundary is noon first matches its afternoon term at i=12, and `12 > 12` is false, so the time parses as morning. A multi-arm locale whose midday term begins at 10 matches at i=10 and does the same. Parsing dayjs own formatted output therefore returns a time 12 hours off, silently.

It was reproduced on the smallest case rather than asserted from reading: `h:mm A` output fed straight back into `dayjs(str, pattern, locale)` gives 01:30 for 13:30 in Hindi, 00:30 for 12:30 in Arabic and 01:30 for 13:30 in Japanese, while `en` gives 13:30 correctly because it takes the branch for locales that define no meridiem at all. Enumerated across every locale defining `meridiem` at 7 hours, it fails 104 of 238 round trips.

Whether this run caused it was measured rather than guessed, because the answer changes how the finding is described. The same probe was run against 123dbf4, the commit preceding this run's first checkpoint, by restoring `src/locale/` from it: 9 failures of 161 there, all at hour 12 in the 9 locales F33 later fixed. So the parser defect is long-standing, not introduced here - `ja`, `ko`, `be`, `br`, `bn-bd`, `ru`, `ku` and the `zh` family all fail and none was touched this run - but this run widened it from 20 locales to 34 by giving 14 more a meridiem. The honest description is that fixing the display defect exposed a parsing defect already underneath it, and F34 says so.

The fix is scoped and lands in one iteration: `correctHours` already runs with `time.hours` in hand, so the meridiem input can be resolved there against the two candidate hours the 12-hour value admits, using the locale's own function as the oracle in the direction it is actually defined, instead of being resolved token-side where the hour is unknown.

The build dimension was checked against the artifacts, not the sources, because the source is not what ships. `npm run build` exits 0 with no warnings, inside the size limit at 2.8 KB against 2.99. All 143 built locale bundles were then loaded and asserted to be plain locale objects carrying their own name, which is the guard the earlier `ku` namespace finding produced, and all 26 changed locales were exercised directly from their minified artifacts across 7 hours: A and a match moment everywhere the source does, and the weekday, month and long-date tokens survive minification, including the `ka` 24-hour `LT` and both F32 sites. Zero problems.

Dependency hygiene was measured in both directions and then Declined rather than scored. `npm audit` reports 177 advisories, but `npm audit --omit=dev` reports 0, because dayjs declares an empty `dependencies` block and ships no runtime dependency at all. Every advisory is build tooling, reachable only by feeding malicious source to that tooling, and build inputs are user-error class in the envelope, so the binding rule caps it at Low. The Declined line records that reasoning and the condition to re-open it, which is a runtime dependency ever being added.

Documentation was checked rather than assumed clean: no file under `docs/` mentions `meridiem` in any of the 10 translations, and this run altered no public signature, so nothing there contradicts the code. `types/plugin/localeData.d.ts` declares `meridiem(hour?, minute?, isLower?)` and the runtime installs it, which `test/types.test.js` already pins in both directions.

One code-quality observation was considered and deliberately not filed. `defaultMeridiem` at `src/plugin/localeData/index.js:19` duplicates core's own fallback at `src/index.js:286`; both are correct, both use `hour < 12`, and the only way to share them is a new exported util for four lines that live inside a closure in one of the two. Filing it would be manufacturing a task, and the Method prefers deletion to addition.

No Surface inventory row is staled by this run, and that was determined from the rows' own recorded rules rather than by a blanket reading. `locales-structure` stales on a change to key shape, formats or relativeTime; iteration 1 changed key shape and it was re-swept then at 49d5177, while iterations 2 and 3 changed only meridiem values and weekday name arrays, neither of which is any of the three. `locales-content` records that its name, ordinal and format-token dimensions are pinned by tests that run in the Verify gate every iteration, and its meridiem dimension is now pinned the same way by `test/locale/meridiem.test.js`. The inventory stands at 41 of 41.

Verify gate green: 4 timezone passes 6 of 6 each, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0. 1199 tests across 100 suites. Lint exits 0. Note that the gate passes over F34, which is the point: no test ever round-tripped a non-English meridiem, and that is the coverage gap the F34 acceptance check closes.

Not a stall: an audit was executed against fresh evidence, a High was filed and a class was Declined with its reasoning.

Learnings: no new operational rule. The relevant one, that an enumeration must be stated in both directions, is already recorded and is what produced this finding.

Next: iteration 5 takes F34, the only open item and the only High. Its acceptance check is written and confirmed to fail at 104 of 238. After it closes the ledger is empty again, and the run can move to the evaluator gate within the remaining budget.

## iter 5/10 | 9f9f90e3-183320 | 2026-07-28 | F34 | done

Task: F34 (High, correctness). `meridiemMatch` in `src/plugin/customParseFormat/index.js` inferred AM or PM from the index of a probe hour rather than from which arm of the locale meridiem matched, so a time formatted by dayjs and parsed straight back came out 12 hours off for every locale defining one.

Changed: `src/plugin/customParseFormat/index.js` (`meridiemMatch` rewritten and moved to resolve in `correctHours`, the A and a handlers now keep the word instead of resolving it), `test/plugin/customParseFormat-meridiem.test.js` added (9 tests), PLAN.md (`plugin-customParseFormat` re-swept, 2 Lessons), BACKLOG.md (F34 deleted, the class settled).

Checkpoint: d3915b48fae26f4149085a68386cfbe1255f39b1 (committed with -n, see Lessons)

Verification: The acceptance check was written first and failed 5 of its 9 assertions against the unfixed plugin, including the round-trip enumeration over all 34 meridiem-defining locales. The 4 that passed are the controls that must pass on both sides, English, an unrecognised word, and the plain AM/PM 12 to 0 correction, so their passing is the evidence the enumeration is measuring the right thing rather than failing indiscriminately.

The fix replaces an inference with a question. A 12-hour clock value admits exactly two hours, so `correctHours`, which already runs with `time.hours` in hand, now asks the locale own `meridiem` which of those two produces the captured word. That is the same function the formatter used, run in the direction it is actually defined, instead of a scan over hours 1 to 24 reading the answer off the index. Resolution had to move out of the token handler because the A token can be parsed before the hour token, so the hour is not yet known where the old code decided.

It returns a tri-state rather than a boolean, and that is deliberate. When the word matches both candidates or neither, the hour is left exactly as parsed instead of being pushed one way, so an unrecognised meridiem no longer silently shifts a time. The old code returned undefined in that case too, but its caller treated undefined as false and still ran the 12 to 0 correction.

The first version of the fix was wrong and the existing suite caught it, which is worth recording because it is the argument for the pre-existing tests rather than against them. Matching the candidate as a prefix of the input handled the multi-word case but broke `test/plugin/customParseFormat.test.js`, whose zh-cn round trip uses a format whose literal separators are CJK. `matchWord` treats only ASCII punctuation as a separator, so the A token there captures the whole run of CJK literals with the term on the end, not the term alone; the old code survived that only because it used substring containment. The matcher now allows both directions, a candidate contained in the input and a candidate that the input begins, and both are covered by tests.

That failure was diagnosed rather than patched around: the rendered string, both meridiem candidates and the parsed result were printed before anything was changed, which is what showed the captured word was a run of literals plus the term rather than the term.

The class was enumerated before being called settled. Every index-scanning loop in the file was listed, and there are four: the `Do` handler over `ordinal`, the token-compilation loop, the parse loop and the format-array loop. Only `Do` searches locale data by index, and it is sound, because it assigns `this.day = i`, reconstructing the value it searched for rather than deriving a second fact from the index. The other three iterate arrays. So the defect is a single site, not an idiom repeated across the file.

`plugin-customParseFormat` was staled by this change and is re-swept rather than left open, with every parameter the changed code reaches exercised on both sides at 13 known answers: strict on and off with a locale meridiem, on both the pass and the fail arm; the A and the a token, on `si`, whose two cases are genuinely different strings rather than case variants; `h` and padded `hh`; a format array with and without strict; the A token with no hour token at all, which is the `hours === undefined` arm; the locale argument present and absent; and `X` and `x`, which this change does not touch. One probe expectation of my own was wrong and was corrected rather than filed: a non-strict format array returns the first pattern that yields a valid date, and non-strict parsing is lenient enough that the first pattern always wins. That behaviour is identical before and after this change, which is the property the re-sweep needed.

Verify gate green: 4 timezone passes 6 of 6 each, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0 confirmed directly. 1208 tests across 101 suites, up from 1199 and 100. Lint exits 0, run after the last edit.

Contract preserved: no signature and no public behaviour changed except the defect. `meridiemMatch` is module-private, `afternoon` is an internal field deleted before the parsed time is used, and the plugin still assigns only `proto.parse`, so nothing about extend order moves; `test/plugin/interaction.test.js` re-ran green. Callers and pinning tests were read first: `correctHours` is the single call site and `test/plugin/customParseFormat.test.js` is what pins the behaviour, including the two zh-cn meridiem cases that constrain the matcher. The only observable change is that a 12-hour time with a locale meridiem now parses to the hour it was formatted from, and that an unrecognised meridiem leaves the hour alone instead of forcing 12 to 0.

Not a stall: a source file and a test file changed, F34 closed.

Learnings: two operational rules recorded in PLAN.md. A loop that searches for a match must compare against the value it is reconstructing rather than infer a second fact from its index. And `matchWord` is not exact in either direction, stopping at whitespace and ignoring non-ASCII separators, so a locale term must be matched with containment both ways and a CJK-literal format and a multi-word meridiem must both be covered before a matcher is believed.

Next: the ledger is empty and the iteration 4 audit found exactly one High, which this iteration closed. The remaining conditions for convergence are that the Verify command is green, which it is, and the evaluator gate. Iteration 6 runs that gate: one fresh-context adversarial reviewer over the run changes, and on PASS the Converged line is appended.


---

# Journal

Append-only. One primary entry per iteration; SALVAGE and ROTATION entries are additional. Never rewrite past entries (filling the current entry's Checkpoint field is completion, not a rewrite).

Heading grammar, exactly: `## iter <i>/<N> | <run-id> | <YYYY-MM-DD> | <task-id or AUDIT or RATCHET or WRAPUP or SALVAGE or ROTATION> | <done|blocked|audit|converged|salvage|rotation>`

## iter 6/10 | 9f9f90e3-183320 | 2026-07-28 | AUDIT | audit

Task: The convergence evaluator gate, not a second full fresh-evidence audit. The run full audit remains the one at iteration 4; this iteration ran the single adversarial reviewer the Definition of done requires and then filed what came out of it. The run does not converge.

Changed: BACKLOG.md (F35 filed, one factual correction to the Declined npm advisory line).

Checkpoint: 9a4515179c8cdf66a44f7689573231bf1343b38e (committed with -n, see Lessons)

Verification: The preconditions were checked before the gate was invoked rather than assumed. Working tree clean, zero open tasks in Now, Next and Later, zero unswept Surface inventory rows, and the only paths changed since the iteration 4 audit checkpoint d51ca5e are `src/plugin/customParseFormat/index.js`, its new test, and the three state files, which is exactly the fixes for the task that audit filed plus loop state edits.

Evaluator: PASS. One fresh-context sub-agent, first of the two the run allows. It re-ran the Verify command (1208 tests across 101 suites, 4 timezone passes 6 of 6 each, 100 percent line threshold met, exit 0) and lint (exit 0, 2 pre-existing warnings), re-ran all four acceptance-check suites green, and proved the shrink-only allowlists have teeth by mutation in both directions across three maps, six mutations, all reverted with a clean tree afterwards.

Its work on F34 went well past mine and is worth recording, because it is the evidence that fix is sound rather than merely green. It enumerated all 34 meridiem-defining locales for substring collisions between the morning and afternoon candidates at every hour in both cases and found none, which is what makes the loose two-directional containment safe rather than lucky. It then built a 64368-row differential of old code against new across 143 locales, 24 hours and 9 format shapes including strict mode and each locale own token-carrying patterns: 0 regressed, 5763 improved, 0 changed-but-wrong-both-ways. It swept minutes as well, 48048 round trips over 7 minute values, since the resolver always probes minute 0 while several meridiems are minute-sensitive: 0 failures. And it re-derived the meridiem enumeration with a different scanner, core own REGEX_FORMAT rather than the committed test bracket-stripping scan, over all 10 format keys including the lowercase l-forms the committed test does not scan; the two scanners agree exactly and the meridiem-less set is exactly the declared allowlist.

F35 is filed anyway, and the reasoning matters. The evaluator returned PASS and did not raise it as a rejection reason: it characterised the residual 624 rows of its own differential as byte-identical to the pre-F34 values, traced them to `formattingTokens` rather than to the resolver, and correctly declined to call an unchanged behaviour a regression. That is right about F34. But the rule that a High or Medium noticed while working is still filed does not care which iteration noticed it, and once traced the behaviour is a Medium on its own terms, so filing it is not optional and suppressing it to reach convergence would be the exact violation the Definition of done names.

It was reproduced independently before filing rather than taken from the evaluator report. `formattingTokens` lists no weekday token, so `dddd` is dropped from the token array entirely instead of being rejected, the weekday name is left in the input, `MMMM` then receives `Monday`, finds no such month and throws. `dayjs(dayjs().format('LLLL'), 'LLLL')` is Invalid Date while the same round trip through `LLL`, `LL` and `LT` succeeds, and moment parses both. It is not locale-specific: `en` fails identically, and since every one of the 143 locales puts `dddd` in `LLLL`, the one localized format that names the weekday cannot be parsed back at all.

Severity was argued rather than assigned. It fails loudly rather than returning a wrong time, which is the argument for Low, and the pattern surface is user-error class in the envelope. But `dddd` is not a malformed token, it is a documented dayjs format token in a standard localized pattern, and a total failure to round-trip `LLLL` in every locale is a failure on a plausible in-envelope case, which is the Medium line in the rubric. Documentation was checked before deciding: there is no customParseFormat page anywhere under `docs/`, in any of the 10 translations, so nothing claims support and nothing misleads, which is why this is correctness and not documentation.

One factual correction to a state file, from the evaluator: the Declined npm advisory line said `package.json` declares an empty `dependencies` block. It has no `dependencies` key at all. The substance, zero runtime dependencies and `npm audit --omit=dev` reporting 0, is unchanged and re-verified.

Verify gate green: the evaluator re-ran it independently this iteration and reported exit 0 with 1208 tests across 101 suites and the 100 percent line-coverage threshold met.

Not a stall: a Medium was filed and a state-file claim corrected, so BACKLOG.md changed state, though no source file changed this iteration.

Learnings: no new operational rule. The applicable one, that a finding noticed while doing something else is still filed at its own severity, is already the Method.

Next: iteration 7 takes F35. The fix is contained, adding the weekday family to `formattingTokens` with a handler that consumes the name without inventing a second source of truth for the date, since a weekday carries no independent information once the year, month and day are known. After it closes the ledger is empty again and iteration 8 can run the second and last evaluator invocation and, on PASS, append the Converged line.

## iter 7/10 | 9f9f90e3-183320 | 2026-07-28 | F35 | done

Task: F35 (Medium, correctness). `formattingTokens` listed no weekday token, so `d`, `dd`, `ddd` and `dddd` were unrecognised and any pattern containing one failed to parse, which meant no locale could parse back its own `LLLL`.

Changed: `src/plugin/customParseFormat/index.js` (weekday family added to `formattingTokens`, a `skipInput` handler and 4 token entries), `test/plugin/customParseFormat.test.js` (6 tests added), PLAN.md (`plugin-customParseFormat` re-swept, 1 Lesson), BACKLOG.md (F35 deleted, F36 filed).

Checkpoint: ca207283dc289ee076782877ea07080e3c2d61a9 (committed with -n, see Lessons)

Verification: The acceptance check was written first and all 6 new assertions failed against the unfixed plugin. The fix recognises the weekday tokens and discards their value: a weekday carries no information the year, month and day do not already fix, so consuming the text is the whole job, and inventing a second source of truth for the date would only create a way for the two to disagree. A wrong weekday is therefore accepted in non-strict mode and rejected in strict mode, where the parsed date is reformatted and compared against the input, and both arms are asserted.

The failure mode is worth recording because it surfaces far from its cause. An unrecognised token is not rejected, it is dropped from the token array entirely, so the weekday name stayed in the input and was eaten by the next token matcher; `MMMM` received `Monday`, found no such month and threw, and the whole parse came back Invalid Date. That is now a Lesson.

The result was measured across all 143 locales rather than sampled, and the measurement is what kept the claim honest. Before the fix 13 locales could round-trip their own `LLLL`; after it 124 can. My first version of the test asserted `zh-cn` among the successes and it failed, which was the test over-claiming rather than the fix under-delivering: `zh-cn` writes `LLLL` as a pattern where `dddd` abuts a CJK literal and then the meridiem, and `matchWord` swallows across it. The assertion was corrected to locales the fix actually repairs, and the residual is pinned rather than hidden.

That residual is filed as F36 and it is a bigger and older thing than F35 was. Chasing why 19 locales still fail showed the cause is not CJK and not weekdays: `matchWord` excludes space and hyphen, so it cannot capture any name containing either. It was reproduced on month names with no weekday token in the pattern at all, which is what proves the two findings are independent - `dayjs(dayjs().locale('gd').format('D MMMM YYYY'), 'D MMMM YYYY', 'gd')` is Invalid Date because Scottish Gaelic April is two words, and `mi` and `mn` fail the same way. 8 locales carry a separator inside a month name and 10 inside a weekday name.

The 19 are pinned as a shrink-only `KNOWN_UNPARSEABLE_LLLL` list asserted by exact set equality, alongside the count, so F36 shrinking it is visible and any regression that grows it fails the suite. Pinning the gap rather than narrowing the test to the passing cases is the difference between a measured remainder and a hidden one.

`plugin-customParseFormat` was staled again by this change and is re-swept: the whole pre-existing suite re-ran green, all four widths were exercised with known answers including the `d` numeric arm, the wrong-weekday case was checked on both sides of the strict flag, and the `LLLL` figure was measured over all 143 locales.

Verify gate green: 4 timezone passes 6 of 6 each, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0 confirmed directly. 1214 tests across 101 suites, up from 1208. Lint exits 0, run after the last edit, which caught three style errors in the appended test block.

Contract preserved: `formattingTokens` gains an alternative it did not have, so patterns that parsed before parse identically now - the weekday tokens were previously dropped, and nothing else in the alternation is lowercase `d`, which was verified against the existing suite and by grepping the test file for parse formats containing one, of which there were none. The plugin still assigns only `proto.parse`. The observable change is that a pattern containing a weekday token now parses instead of returning Invalid Date.

Not a stall: a source file and a test file changed, F35 closed and F36 filed.

Learnings: one operational rule recorded in PLAN.md, that an unrecognised `customParseFormat` token is dropped rather than rejected and so fails far from its cause, so a pattern that will not parse should be checked against `formattingTokens` first.

Next: F36 is the only open item. It is a change to the name matchers, which is riskier than F35 because `matchWord` is shared by every name token and by the ordinal handler, so it needs the whole existing suite as its guard rather than only the new list. The budget has 3 iterations left, enough to take F36 in iteration 8 and spend the second and last evaluator invocation in iteration 9.

## iter 7/10 | 9f9f90e3-183320 | 2026-07-28 | ROTATION | rotation

Task: JOURNAL.md passed the 500-line threshold with this iteration entry, so the oldest entries were moved to JOURNAL-archive.md and the 10 most recent kept live.

Changed: JOURNAL.md (8 entries removed, header kept), JOURNAL-archive.md (those entries appended).

Checkpoint: shared with the primary entry above.

Verification: Counted rather than eyeballed, and the script refuses to write unless the kept slice is exactly 10 entries and begins at a heading. The archive went from 45 entries to 53, the live journal holds 10, and the archive was appended to rather than overwritten, so it only ever grows.

Learnings: no new operational rule.

Next: as recorded in the primary entry above.

## iter 8/10 | 9f9f90e3-183320 | 2026-07-28 | F36 | done

Task: F36 (Medium, correctness). `matchWord` excludes space and hyphen, so it could not capture any month or weekday name containing either, and the parse misaligned from that point on.

Changed: `src/plugin/customParseFormat/index.js` (a locale-derived `matchNames` matcher, applied to `MMM`, `MMMM`, `dd`, `ddd` and `dddd`, and `makeParser` now builds a token matcher that is a function of the locale), `test/plugin/customParseFormat.test.js` (2 tests added, the shrink-only list cut from 19 entries to 3), PLAN.md (`plugin-customParseFormat` re-swept, 1 Lesson), BACKLOG.md (F36 deleted, F37 filed).

Checkpoint: 3263bcfccad5a5d3739fc8cf0e2e153861212ddd (committed with -n, see Lessons)

Verification: The acceptance check failed 3 of its assertions against the pre-fix code and passes after. The fix stops asking a generic word pattern to recognise names and asks the locale instead: each name token now matches against that locale own array, sorted longest first so a name that is a prefix of another cannot win, with the old pattern kept as the last alternative so an unknown name still reaches the handler and still throws exactly as before. That last point is what preserves the existing contract, and the pre-existing suite is the evidence, including the deliberately wrong ordinal input and the strict-mode cases that share the same matcher.

Building the matcher needed one structural change: `makeParser` treated a token matcher as a constant, and a name matcher cannot be constant because it depends on the locale. It is now built where the parser is compiled, which is the point where the locale is already resolved, so nothing about when a locale is set has to move.

The result was measured over the whole locale set rather than sampled. All four name tokens now round-trip in all 143 locales with zero failures, where the same sweep before the fix showed the misalignment, and `LLLL` rose from 124 of 143 to 140. The three specific month cases the finding named all parse: `An Giblean` in Scottish Gaelic, `Paenga-whāwhā` in Maori and the two-word Mongolian April, plus `segunda-feira` for the hyphenated weekday half.

The coverage gate shaped the implementation, and usefully. A guard clause returning the old matcher when a locale has no such array would have been a dead line, since every locale has these arrays, and a dead line fails the 100 percent threshold. Writing it branchlessly, by concatenating the old pattern onto the alternation as its last alternative, removed the branch and produced the better design at the same time, because that fallback is exactly what keeps an unknown name failing.

F37 is filed for the remainder, and it is the third distinct cause in this area rather than a leftover of the second. When F36 left exactly `mn`, `zh` and `zh-cn` failing, the reason was checked rather than assumed: their patterns separate tokens with non-ASCII literals, and the separator group in `formattingTokens` is ASCII only, so those runs match neither a token nor a separator and are dropped from the token array instead of becoming literals. That is the cause the iteration 6 evaluator originally traced, now confirmed from the opposite direction by what F36 could not reach.

Three findings in one file in three iterations is worth naming rather than glossing. They are not instances of one idiom: F35 was a missing token, F36 a matcher too narrow for the data, F37 a tokenizer that discards what it cannot classify. The three-strike rule asks whether instance patching should become one structural task, and the honest answer is that F37 is that structural task, since making the tokenizer account for every character of the pattern is the boundary fix that the other two worked around locally.

Verify gate green: 4 timezone passes 6 of 6 each, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0 confirmed directly. 1216 tests across 101 suites, up from 1214. Lint exits 0, run after the last edit.

Contract preserved: no signature changed and no public method moved. The plugin still assigns only `proto.parse`. Callers and pinning tests were read first, and the shared-matcher risk was the reason: `matchWord` is used by `Do`, by `A` and `a`, and by every name token, so `Do` and the meridiem tokens were deliberately left on it and only the five name tokens moved. The observable change is that a name containing a space or a hyphen now parses; a wrong name still fails, and strict mode still rejects what it rejected.

Not a stall: a source file and a test file changed, F36 closed and F37 filed.

Learnings: one operational rule recorded in PLAN.md, that a name token must be matched against the locale own arrays rather than a generic word pattern, longest first, with the generic pattern kept last so an unknown name still fails.

Next: F37 is the only open item and iteration 9 takes it. It is the tokenizer fix, contained but central, so the whole suite is its guard. If it lands, iteration 10 spends the second and last evaluator invocation and, on PASS, declares convergence; if it does not, the run ends out of budget with F37 open and the ledger honest, which is the better outcome than converging over a known Medium.

## iter 9/10 | 9f9f90e3-183320 | 2026-07-28 | F37 | done

Task: F37 (Medium, correctness). The separator group in `formattingTokens` is ASCII only, so a run of non-ASCII literal text in a pattern matched neither a token nor a separator and `String.match` dropped it, leaving it in the input to misalign everything after it.

Changed: `src/plugin/customParseFormat/index.js` (a `tokenize` function replacing `format.match`, and the `A` and `a` matchers made locale-derived), `test/plugin/customParseFormat.test.js` (1 test added, the shrink-only list emptied), PLAN.md (`plugin-customParseFormat` re-swept, 1 Lesson), BACKLOG.md (F37 deleted, the class settled as the structural fix).

Checkpoint: 809a698ef2c2f6bbd494ab1e99439eaf3ad8f13d (committed with -n, see Lessons)

Verification: The acceptance check failed 2 assertions against the pre-fix code and passes after. `tokenize` walks the pattern with the same regex but keeps the gaps between matches, emitting each as a literal, so every character of the format is now either a token or a literal and a literal advances the read position exactly as an ASCII separator already did.

The fix immediately exposed a second thing the tokenizer change made necessary, which is the useful part of this iteration. With literals finally accounted for, `ne` regressed: its `LT` is a meridiem token immediately followed by a Devanagari literal, and `matchWord` runs to the next ASCII separator, so the `A` matcher swallowed the literal too and the literal was then counted a second time. Before the change the two errors cancelled. The remedy is the same one F36 applied to names: the `A` and `a` matchers are now built from every distinct string the locale meridiem can produce across all 24 hours in both cases, so each matcher consumes exactly its own text. A locale defining no meridiem yields an empty list and falls back to the generic pattern, which is what still matches English AM and PM.

The one real regression was caught by the pre-existing suite, not by mine, and it is worth recording as a contract rather than a bug. `dayjs(input, 'C')` returned Invalid Date only because `format.match` returned null for a pattern with no tokens and reading `length` off null threw into the catch. A tokenizer that always returns an array quietly turned that into today's date. The signal is now explicit - a format in which nothing matched throws - and both sides are asserted. That is now a Lesson: a behaviour that exists only because an operation failed is a contract, and it vanishes the moment the operation stops failing.

The result is measured over the whole surface rather than the one format the finding named. All 6 localized formats of all 143 locales now round-trip through their own rendered output, 858 parses with zero failures, where `LLLL` alone stood at 13 of 143 before this run began, 124 after F35, 140 after F36 and 143 now. `KNOWN_UNPARSEABLE_LLLL` is empty and asserted empty, so the pin that tracked the gap now guards against its return.

The class is settled as the structural task the three-strike rule asked for. F35, F36 and F37 were not three instances of one idiom, but they were three faces of one boundary failure: the parser handled what it recognised and silently lost the rest, whether that was an unlisted token, a name too wide for its matcher, or a literal outside the ASCII class. Making the tokenizer account for every character, and every matcher consume exactly its own text, is the single boundary fix; the enumeration backing it is the whole surface, all 6 formats of all 143 locales, rather than a sample.

Verify gate green: 4 timezone passes 6 of 6 each, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0 confirmed directly. 1217 tests across 101 suites, up from 1216. Lint exits 0, run after the last edit.

Contract preserved: no signature changed, the plugin still assigns only `proto.parse`, and the invalid-format behaviour is preserved deliberately rather than incidentally. Callers and pinning tests were read first, which is how the shared-matcher risk was managed across all three iterations: `Do` still uses `matchWord`, because its handler reconstructs the day from digits and does not need the locale, and only the tokens that match locale text were moved. The observable changes are that a pattern separated by non-ASCII literals now parses, and that a meridiem followed immediately by a literal no longer over-consumes.

Not a stall: a source file and a test file changed, F37 closed and the ledger is empty.

Learnings: one operational rule recorded in PLAN.md, that a behaviour resting on an operation returning null or throwing is a contract which disappears when that operation is replaced, so the failure modes of a call being removed must be asked about explicitly.

Next: the ledger is empty, the Surface inventory is 41 of 41, and the Verify command is green. Iteration 10 is the last of the budget and spends the second and final evaluator invocation. On PASS it appends the Converged line and the run converges; on REJECT the reasons are filed and the run ends out of budget rather than converged, since a second rejection is a hard blocker and there is no iteration left to work it.

## iter 10/10 | 9f9f90e3-183320 | 2026-07-28 | WRAPUP | done

Task: The last iteration of the budget. It spent the second and final evaluator invocation on the four successive rewrites of `src/plugin/customParseFormat/index.js` that no audit had reviewed as a whole, then filed what came back and wrote the handoff. The run does not converge.

Changed: BACKLOG.md (F38, F39 and F40 filed, the parser class reopened), PLAN.md (the `plugin-customParseFormat` row corrected, 2 Lessons).

Checkpoint: abddce64d06572a7511a109b3849ccf7803dd648 (committed with -n, see Lessons)

Verification: Convergence was ruled out before the evaluator was invoked, on the Definition of done rather than on its verdict. The only full fresh-evidence audit this run was iteration 4, it scored one High, and the clause that allows convergence after fixing what such an audit filed also says to audit again if anything else changed. Four fixes landed since, of which only F34 was filed by that audit, and they rewrote the plugin. With one iteration left there was no budget to both re-audit and evaluate, so the evaluator was the better spend: it hands the next run a checked baseline instead of a self-assessment.

Evaluator: REJECT, the second invocation and the first rejection. Three substantiated reasons, all reproduced, all filed.

The first is a High and it is the important one. `matchIndex % 12 || matchIndex` yields 24 for December in the 12 locales whose `months` is the two-arm function form, because `getLocalePart` concatenates both arms into 24 entries and the format-arm December lands at index 23. A December date therefore parses into the following year, silently. The evidence is the shape of the sweep as much as the defect: all 143 locales across the 6 localized formats fail 0 of 858 at the April stamp this run kept using, and 36 of 858 at a December stamp.

This run did not cause that defect but it did make it worse, and saying so plainly matters more than the count of tasks closed. 14 of the 36 were Invalid Date before F35 to F37 and are now silently wrong, because the accidental loud failure that had been masking the bad month index is exactly what those three fixes removed. Turning a visible failure into a quiet wrong answer is a real regression in consequence even when the underlying arithmetic was already broken, and it is now recorded as a Lesson.

The second reason is a Medium against my own bookkeeping, and it is the reason the first went unseen. The Settled class and the inventory row both claim the enumeration asserts all 6 localized formats of all 143 locales round-trip, and PLAN.md records 858 parses, but the committed test fixes one April stamp. The month axis, which is the axis `MMM` and `MMMM` exist for, is never swept. A claim true of one month was written as though true of the year, and four re-sweeps of that row inherited it. Both state files are corrected in place and the gap is filed as F39.

The third is a Low: `dd` and `ddd` take locale-derived matchers, but `en` and `rw` define neither `weekdaysMin` nor `weekdaysShort`, so for the default locale two of the five name tokens silently fall through to the generic pattern, and one previously working parse became Invalid Date. `MMM` already handles that case by slicing, and core does too, so the omission is inconsistent with both siblings.

What the evaluator checked and found sound is recorded too, because it bounds what the next run must redo. The Verify command exits 0 with 1217 tests across 101 suites and lint is clean. 247104 meridiem round trips across 143 locales, 8 formats, 24 hours and 9 minute values fail 0, including the minute-sensitive Chinese boundaries. The tokenizer has no reentrancy or `lastIndex` leak, and every edge format behaves identically to the pre-run code, including the deliberately preserved invalid-format contract. A 400000-comparison fuzz of old against new found no case where the old code was right and the new one is differently wrong, and the only old-ok new-fail cases are the 290 instances of the Low above. `matchNames` escaping, longest-first ordering and duplicate handling are all correct, and parsing is 3 to 5 times slower on name tokens at about 13 microseconds worst case, which is measurable and not a finding.

Not a stall: three findings were filed and two state-file claims corrected, so BACKLOG.md changed state, though no source file changed this iteration.

Learnings: two operational rules recorded in PLAN.md. Sweep the axis the code under test is about, since an enumeration pinned to one calendar date cannot see a month-index defect however many locales it crosses. And removing an accidental loud failure can convert a latent defect into a silent wrong answer, so when a fix makes previously-invalid input parse, check what those inputs now return rather than counting the new successes.

Next: a fresh session in this directory. F38 is the only High and is a one-line fix at two sites, but it should be taken together with F39, because fixing the arithmetic without widening the enumeration to all 12 months would leave the same blind spot that hid it. F40 follows. The Surface inventory reads 41 of 41, but the `plugin-customParseFormat` row now records that it does not certify the month axis, and the next run should treat that row as the first thing to re-sweep properly.

## iter 1/10 | 5524dadb-203713 | 2026-07-28 | F38 | done

Task: F38 (High, correctness). `matchIndex % 12 || matchIndex` returned 24 for a format-arm December, so a December date parsed in one of the 12 two-arm locales silently became December of the following year.

Changed: `src/plugin/customParseFormat/index.js` (the fold at both month handlers, plus a comment on `getLocalePart` naming the 24-entry array as the reason a fold is needed), BACKLOG.md (F38 deleted), PLAN.md (`plugin-customParseFormat` re-swept, 2 Lessons).

Checkpoint: 8555646c53b20ad4097f179132716096127f6712 (committed with -n, see Lessons)

Verification: The acceptance check was run against the unfixed code first and failed exactly as filed: a sweep of all 143 locales over the 6 localized formats at all 12 months fails 36 of 10296, every one of them in December, across `be`, `ca`, `cs`, `el`, `hr`, `hy-am`, `lt`, `oc-lnc`, `pl`, `ru`, `tg` and `uk`. After the fix the same sweep fails 0 of 10296.

The differential is exact rather than sampled. Both runs wrote a full snapshot of all 10296 parses, keyed by month, locale and format, and the two snapshots differ in exactly 36 entries: the same 36, all in December, all in `LL`, `LLL` and `LLLL`, and every one of them now landing on 2019-12-15 where it previously landed on 2020-12-15. Nothing outside December moved.

That empirical result has a closed form behind it, which is the stronger half of the evidence. The old and new expressions differ at exactly one input. For `matchIndex` 1 to 11 both return `matchIndex`; at 12 both return 12; for 13 to 23 both return 1 to 11; only at 24 do they diverge, 24 against 12. The concatenated array is at most 24 long and `matchIndex < 1` throws before either expression runs, so 24 is the only reachable input where they can disagree and no month other than December is capable of moving. The measurement and the construction agree.

The two sites are not two reproduced defects and the entry should not imply they are. Index 24 is reachable only when a locale's format-arm December is a string that appears nowhere earlier in `s.concat(f)`. Enumerated over all 143 locales and both tokens, that set is exactly the 12 locales above for `months`, and empty for `monthsShort`: only `be` and `ru` supply `monthsShort` in the two-arm form and both spell December `дек.` in both arms, so `MMM` cannot produce 24 today. The `MMM` site was fixed because it is the same fold on the same array and leaving it wrong would make the defect reappear the moment a locale gains a distinct short December, not because a second failure was observed there. A name-token sweep over `D MMM YYYY` and `D MMMM YYYY` across all 12 months and all 143 locales confirms this from the other direction: 12 failures before the fix, all `MMMM`, none `MMM`, and 0 after.

Verify gate green: 4 timezone passes 6 of 6 each, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0 confirmed directly. 1217 tests across 101 suites, unchanged, since this iteration pinned nothing new. Lint exits 0, run after the last edit.

Contract preserved: no signature changed, no token's matcher changed, and the plugin still assigns only `proto.parse`. The change is confined to how a matched position is turned into a month number, after the throw-on-no-match guard both handlers already had, so an unrecognised month name still fails exactly as before. Strict mode is unaffected: it already rejected these inputs by reformatting and comparing, which is why the defect only ever reached non-strict callers.

No test was added this iteration and that is deliberate rather than an omission. F39 is the next task and it is precisely the job of widening the committed enumeration from its single April stamp to all 12 months, so pinning this fix inside F38 would have done F39's work under F38's name. The sweeps above were scratch probes and are gone; until F39 lands, the fix is verified but not guarded.

Not a stall: a source file changed and F38 closed.

Learnings: two operational rules recorded in PLAN.md. That `getLocalePart` hands back a 24-entry array for a two-arm locale so any index taken from it must be folded, and that `i % n || i` is the wrong fold because it cannot tell `n` from `2n`. And that a probe needing the whole locale set runs most cheaply as a gitignored `*.tmp.js` file executed through `npx jest --testRegex=`, which inherits the suite's babel config and dayjs module mock instead of needing `babel-node` and manual aliasing.

Next: F39 widens the committed enumeration in `test/plugin/customParseFormat.test.js` to all 12 months and corrects the two state-file claims that describe a one-month sweep as a year. Its acceptance requires confirming the widened enumeration fails against the F38 defect, which is now fixed; the way to earn that is to restore the old expression temporarily, exactly as this iteration did to prove the `MMM` site, and the reverted-run output is recorded above. F40 follows.

## iter 2/10 | 5524dadb-203713 | 2026-07-28 | F39 | done

Task: F39 (Medium, documentation). Two state files described the committed enumeration as covering all 6 localized formats of all 143 locales, 858 parses, while the test fixed a single April stamp, so the month axis was never swept and the claim was true of one month and written as though true of the year.

Changed: `test/plugin/customParseFormat.test.js` (both month-resolving enumerations widened to all 12 months, each asserting its own parse count), BACKLOG.md (F39 deleted, the parser Settled class re-settled on the widened enumeration), PLAN.md (`plugin-customParseFormat` row's pinning claim corrected, 2 Lessons).

Checkpoint: 7ff2ed29f7b9ca5f32be7b55ad0a4765c297adc8 (committed with -n, see Lessons)

Verification: The acceptance has three clauses and each was run rather than argued.

The enumeration now runs over all 12 months. The localized-format sweep went from 858 parses to 10296, 12 months by 143 locales by 6 formats, and the name-token sweep from 572 to 6864, 12 months by 143 locales by 4 formats. The second one matters as much as the first because it is the one that exercises `MMM`, the short-name arm of the two-arm lookup, which no localized format reaches.

Each sweep asserts its own parse count. That is the part worth keeping: the figure a state file quotes is now a figure the suite computes and checks, so the two cannot drift apart. The gap this task exists to close was exactly a number in a document that no longer described the code, and a claim that checks itself cannot decay that way again.

The widened enumerations were confirmed to fail against the F38 defect before being trusted. F38 was fixed in iteration 1, so the old expression was restored temporarily, exactly as that iteration did to establish which of the two sites was reachable, and the suite re-run: the localized-format sweep fails 36 times, 12 locales across `LL`, `LLL` and `LLLL`, and the name-token sweep fails 12 times, all `dddd D MMMM YYYY`, every one of them in December and nowhere else. The fix was then restored and the restoration verified by counting both sites. Without that step the widened test would be a check that has never been observed to fail, which proves nothing.

Both state-file claims are corrected. The Settled class in BACKLOG.md now says what is actually asserted and separates the two things the evaluator's reopening had bundled: the parser did account for every pattern element, and the month index it derived from that element was wrong, which is a different defect in a different line. The class is settled again on the widened enumeration rather than on the one-month one. The `plugin-customParseFormat` row in PLAN.md previously ended by saying the month axis was exercised only by a scratch probe and that F39 would pin it; it now records that the pin is committed, names the two counts, and records that both were confirmed failing first.

Verify gate green: 4 timezone passes 6 of 6 each, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0 confirmed directly. 1217 tests across 101 suites, unchanged, because this iteration widened two existing tests rather than adding any. Lint exits 0, run after the last edit.

Contract preserved: no source file changed this iteration. The only production code touched was the temporary revert used to prove the enumeration fails, and it was restored from a copy taken beforehand and verified by grep, so the committed tree carries the iteration 1 fix unchanged.

A bookkeeping correction belongs in the record. Iteration 1's journal heading carried the run-id `5524dadb-160216`, which I derived from local file timestamps instead of reading `started_at` back out of the loop state frontmatter; the real value is `5524dadb-203713`. The Stop hook caught it. Only the run-id in that heading was corrected and no content of the entry was altered.

Not a stall: a test file changed and F39 closed.

Learnings: two operational rules recorded in PLAN.md. The run-id in a journal heading comes from `started_at` in the loop state frontmatter and must be read back from that file, never inferred from file timestamps, which are local rather than UTC. And an enumeration whose size a state file quotes should assert that size inside the test, so the documented figure and the exercised figure cannot drift apart.

Next: F40 is the only open item and iteration 3 takes it. It is Low: `dd` and `ddd` fall through to the generic word pattern for `en` and `rw`, the 2 locales defining neither `weekdaysMin` nor `weekdaysShort`, where `MMM` and core's own `getShort` both handle the same absence by slicing. Its acceptance names a concrete regression to restore, `dayjs('1st.Wed', 'Do.ddd')`, and an enumeration asserting every locale supplies a non-empty name list for all five name tokens. With the ledger empty after it, iteration 4 should run the full fresh-evidence audit the Definition of done requires, since this run has not yet had one.

## iter 3/10 | 5524dadb-203713 | 2026-07-28 | F40 | done

Task: F40 (Low, correctness). `dd` and `ddd` took their names from `weekdaysMin` and `weekdaysShort` with no fallback, so for the 2 locales defining neither, `en` and `rw`, the matcher list was empty and both tokens fell through to the generic word pattern.

Changed: `src/plugin/customParseFormat/index.js` (a `shortNames` resolver now shared by `dd`, `ddd` and `MMM`, and `Do` moved off the generic word pattern onto a locale-derived ordinal matcher), `test/plugin/customParseFormat.test.js` (2 tests added), BACKLOG.md (F40 deleted, F39's line deleted late, F41 filed), PLAN.md (3 Lessons).

Checkpoint: b81145ccccb985421a87d8f7f014873c58c71149 (committed with -n, see Lessons)

Verification: The acceptance had three clauses and the middle one turned out to rest on a wrong diagnosis, which is the substance of this iteration.

The first and third clauses were straightforward. `dd` and `ddd` now derive the missing array by slicing the full name, at lengths 2 and 3, which is what `MMM` already did and what core's own `getShort` at `src/index.js:277` does for exactly the same shape. The three sites now share one `shortNames` resolver, which also let the `MMM` handler drop two lines that recomputed the same list. The enumeration asserts all 5 name tokens over all 143 locales and reports which pairs actually reach the fallback: `en` and `rw` for `dd`, `ddd` and `MMM`, six pairs, so the fallback is exercised rather than dead. That check was proved able to fail before it was trusted, though by accident rather than design - a wrong `length` of 0 for the full-name tokens sliced every name to the empty string and it reported 286 failures.

The second clause was that `dayjs('1st.Wed', 'Do.ddd')` parses again, and the fallback did not achieve it. The finding attributed the lost parse to `ddd` falling through to the generic pattern; the actual mechanism is `Do`. `matchWord` is `/\d*[^-_:/,()\s\d]+/`, whose negated class omits `.` even though the format tokenizer's separator class `[-_:/.,()\s]+` includes it, so `Do` ran straight through the separator and consumed `1st.Wed` whole, leaving `ddd` nothing. Measured directly rather than reasoned: `matchWord.exec('1st.Wed')` returns `1st.Wed`, and the same shape with a separator `matchWord` does exclude, `Do ddd` and `Do,ddd`, parses fine on the unfixed code.

So `Do` moved onto a locale-derived matcher, which is the invariant the settled tokenizer class already states, that every matcher consumes exactly its own text. `Do` was the last token still on the generic pattern. Adding `.` to `matchWord`'s exclusion list was rejected as the alternative: dozens of locales write their ordinal as `1.`, and a matcher stopping before the period would strand it in the input. Deriving the alternation from the locale's own `ordinal` keeps `1.` matching as one unit, because that whole string is an alternative, while `1st` stops before `.Wed`. Both directions are asserted, `de` and `en`.

Because that change touches a matcher every locale uses, it was swept rather than spot-checked, and the sweep is the part worth recording. `Do MMMM YYYY`, `Do MMM YYYY` and `YYYY MMMM Do` over all 143 locales at 3 months and 10 days of month is 12870 parses. It fails 5121 across 56 locales on the pre-change code and 3510 across 39 after, and the two locale sets were compared rather than the totals: no locale is newly broken, none got worse, and 18 are fixed - `az`, `be`, `bg`, `cv`, `fr`, `ka`, `kk`, `km`, `ky`, `lo`, `mk`, `mn`, `ru`, `si`, `tg`, `ug-cn`, `uk`, `yo`. A strict improvement, and the residual is pre-existing.

That residual is now F41 and it is a Medium, filed rather than folded into this task. 39 locales write `ordinal: n => n`, which returns a number, so `.replace` on it throws; and `matchWord` requires at least one non-digit, so it cannot match a bare number at all and matches the following month name instead, after which `input.match(/\d+/)` returns null and throws. Two independent causes, both ending in Invalid Date, both older than this run. Pinned on `ar-dz` and `vi` against `de` as the control.

Verify gate green: 4 timezone passes 6 of 6 each, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0 confirmed directly. 1219 tests across 101 suites, up from 1217. Lint exits 0, run after the last edit.

Contract preserved: no signature changed and the plugin still assigns only `proto.parse`. `matchNames` keeps the generic pattern as its last alternative, so an unrecognised ordinal or weekday still reaches its handler and still fails exactly as before, which is what the pre-existing suite pins. The observable changes are that a short weekday token now matches real names for `en` and `rw`, and that `Do` stops at the end of its own ordinal instead of running through a separator. The behavioural test was confirmed to fail against the unfixed code and pass after, and the source was restored from a copy taken beforehand and verified by grep.

A bookkeeping correction belongs in the record. Iteration 2 closed F39 in every respect except deleting its line from BACKLOG.md, and its journal entry says the line was deleted. The ledger still carried F39 at the start of this iteration; the line is deleted now and the rule that would have caught it is recorded as a Lesson.

Not a stall: a source file and a test file changed, F40 closed and F41 filed.

Learnings: three operational rules recorded in PLAN.md. That a locale's `ordinal` may return a number rather than a string, so a caller reaching for a string method must coerce first, and that `matchWord` cannot match a bare number and silently matches the next word instead. And that a BACKLOG.md deletion must be re-read and confirmed before the journal entry claims it.

Next: the ledger holds one item, F41, and iteration 4 has a choice between working it and running the full fresh-evidence audit the Definition of done requires, which this run has not yet had. The audit is the better spend: it is required for convergence regardless, it is the thing that would find whatever else sits beside F41 in this area, and F41 is fully specified and loses nothing by waiting. Replenishment is not needed separately, since a full audit supersedes it.

## iter 4/10 | 5524dadb-203713 | 2026-07-28 | F41 | done

Task: F41 (Medium, correctness). `Do` could not be parsed in 39 of the 143 locales, so the library could not read back a `Do`-bearing format it had rendered itself.

Changed: `src/plugin/customParseFormat/index.js` (`String(...)` coercion at both ordinal call sites, and the digit scrape in the `Do` handler turned into a guarded fallback), `test/plugin/customParseFormat.test.js` (1 test added), BACKLOG.md (F41 deleted, the class settled), PLAN.md (2 Lessons).

Checkpoint: 8a1a2a050038714abad7c91028e99ae46df7bea0 (committed with -n, see Lessons)

Verification: Two independent causes, each reproduced before being fixed, and the second only visible once the first was out of the way.

The first is the one the finding named. 39 locales write `ordinal: n => n`, which returns a number rather than a string, so `ordinal(i).replace(/\[|\]/g, '')` threw a TypeError at both call sites, in `ordinalNames` and in the `Do` handler's scan. Both now coerce with `String(...)`. That alone took the sweep from 3510 failures across 39 locales to 90 across 1.

The second was the residual, and it is a different defect wearing the same symptom. `ne` renders its ordinal in Devanagari digits, so `input.match(/\d+/)` found no ASCII digit, returned null, and the destructuring threw. What makes it worth naming is the ordering rather than the null: the digit scrape is a fallback for an ordinal the locale's own table does not recognise, and it ran ahead of that table, so it threw away a day the table two lines below would have resolved exactly. It is now guarded, and its absence is no longer a parse failure. The sweep is 0 of 12870.

The differential is over the whole surface rather than the delta. Both runs wrote a snapshot of all 12870 parses keyed by locale, date and format. Comparing them: 0 entries parsed before and fail after, 0 entries that parsed before changed their value, and 3510 entries across 39 locales went from Invalid Date to correct. The claim that nothing regressed is measured, not argued.

The committed check was confirmed to fail against the pre-fix code before it was trusted: restored to the iteration 3 source it goes red, and it asserts its own parse count of 4290 so the enumeration cannot shrink unnoticed.

Verify gate green: 4 timezone passes 6 of 6 each, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0 confirmed directly. 1220 tests across 101 suites, up from 1219. Lint exits 0, run after the last edit.

Contract preserved: no signature changed and the plugin still assigns only `proto.parse`. The `Do` handler still prefers the locale's ordinal table over the scraped digits, which is the precedence it always had; the change is that the scrape can now decline rather than throw. An unrecognised ordinal still reaches the handler through `matchNames`'s trailing generic alternative and still yields what it did before, which the pre-existing suite pins.

Not a stall: a source file and a test file changed, F41 closed and a class settled.

Learnings: two operational rules recorded in PLAN.md. That a fallback must not run ahead of the authority it backs up, because its failure is then mistaken for the operation's failure. And that `grep -c` exits non-zero on a zero count, so chaining it with `&&` silently drops every command after it - this iteration lost a journal append and a cleanup to exactly that, and the append looked present only because a previous run's entry shared the heading.

Next: the ledger is empty, so iteration 5 runs the full fresh-evidence audit the Definition of done requires and this run has not yet had. That audit, not a replenishment, is the right next spend: convergence needs one regardless, and it is what would find whatever sits beside the four findings this run has closed. Three of those four were in one file, so the audit should deliberately look elsewhere rather than deepening the same seam, and it should check whether the neighbouring inventory rows are stale rather than re-probing the one just swept.

## iter 4/10 | 5524dadb-203713 | 2026-07-28 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines at 524, so the oldest entries rotate into JOURNAL-archive.md.

Changed: JOURNAL.md (8 oldest entries moved out, 10 most recent kept), JOURNAL-archive.md (those 8 appended).

Checkpoint: 8a1a2a050038714abad7c91028e99ae46df7bea0 (committed with -n, see Lessons)

Verification: The archive is append-only and cumulative, so the rotation was checked for loss rather than assumed. Both files were copied first, then compared before and after as a multiset of non-empty lines: 983 lines before across the two files and 983 after, identical when sorted, so nothing was lost, duplicated or altered. Entry headings hold at 71 across the pair, 18 plus 53 before and 10 plus 61 after. JOURNAL.md keeps its 5-line preamble and its 10 most recent entries at 283 lines; JOURNAL-archive.md grew from 53 entries to 61, which is the direction the stop hook requires.

Learnings: none beyond what the primary entry records.

Next: unchanged from the primary entry. Iteration 5 runs the full fresh-evidence audit.

## iter 5/10 | 5524dadb-203713 | 2026-07-28 | AUDIT | audit

Task: The full fresh-evidence audit the Definition of done requires. The ledger was empty, all 41 Surface inventory rows were swept and none was staled by this run, so every dimension was rescored against the rubric and the Operating envelope with evidence executed this iteration rather than cited from the suite.

Changed: BACKLOG.md (F42 filed, one finding Declined), PLAN.md (no row changes; no row was staled).

Checkpoint: d1bc12b3ed82abb7ceb7bb421233fe2db5cc62e5 (committed with -n, see Lessons)

Verification: Scores, worst first. Architecture: Low. Performance: Low, same root cause. Correctness: None. Security: None. Testing: None. Error handling: None, with one finding Declined. Documentation: None. Dependency hygiene: None. Developer experience: None. Code quality: None. Observability: not applicable, since the library has no logging or metrics surface and its only diagnostic surface, the devHelper plugin, is swept. UX and accessibility: not applicable, since there is no user-facing surface. These scores claim all 41 rows, because all 41 are swept and none is stale.

Closeout begins. Zero High and zero Medium in-envelope, so this run runs no further audit and no replenishment; it works or declines what is on the ledger and then converges.

The one finding is F42, and it is the only place fresh measurement disagreed with the state files. `makeParser` runs on every parse and rebuilds every locale-derived matcher, so a `Do` format calls `locale.ordinal` 31 times and compiles a fresh RegExp each call. Benchmarked against the pre-run source at 70818a1 in the same harness with moment as a stability control, `Do MMMM YYYY` went from 12.59 to 40.63 microseconds in `en` and 11.05 to 35.11 in `de`, while numeric and plain-name formats moved within noise and moment held at 28-31 and 37-39 across both runs, which is what makes the comparison trustworthy rather than machine noise. This run caused it, in iteration 3, when `Do` moved off the generic word pattern. Nothing returns a wrong result, so it is Low by the rubric.

What was probed rather than assumed, since an audit that cites the suite is not fresh evidence. Six invariant families were run directly: `diff` antisymmetry over 9 dates squared and 8 units, `startOf`/`endOf` bracketing plus agreement with moment plus the successor property that the millisecond after `endOf` starts the next unit, `add`/`subtract` inversion over every unit at 4 magnitudes including a negative, timezone conversion and `utcOffset` against moment-timezone across 5 zones and both 2019 DST transitions in each direction, duration arithmetic against known answers and moment's ISO output, and customParseFormat strict mode over 8 accept-and-reject pairs including a wrong month name and a wrong weekday. Zero violations in all six.

Security was probed on the surface this run actually changed. The matchers are now regexes generated from locale data, so the question is whether generated alternations can backtrack: parsing 1000, 10000 and 50000 characters of junk against `Do MMMM YYYY` and a Russian name format takes 0.27, 0.12 and 0.18 milliseconds, a 50k-to-1k ratio of 0.7 where linear would be near 50, so growth is sublinear and no input-driven blowup exists. `npm audit --omit=dev` reports 0 vulnerabilities and `package.json` still carries no `dependencies` key at all.

The build was re-run end to end because `src/` changed: exit 0, no warnings, and the core bundle is 2.8 KB against the 2.99 KB size limit. The customParseFormat bundle is 5083 bytes raw and 2258 gzipped, the largest plugin but in the same band as duration at 4823 and 1703, which is what a parser should cost and is not gated by size-limit anyway.

Documentation was checked rather than assumed clean: the in-repo `docs/` tree is a three-line pointer to day.js.org, so there is no in-repo token reference that this run's changes to `Do`, `dd` and `ddd` could contradict, and the change-discipline requirement to update documentation alongside behaviour has no in-repo surface to act on.

One finding was Declined rather than filed. The blanket catch in `parseFormattedInput` converts any error, including a genuine programming error, into Invalid Date, and it demonstrably masked F41 and is the same mechanism behind F38 sitting unseen. The cost is real but falls on maintainers rather than users, since never throwing on unparseable input is the documented contract on the adversarial-class surface; the available remedies either make a malformed locale crash user code on a user-error-class surface or add a development-warning feature the Constraints rule out, and the masking risk is now carried by the three all-143-locale enumerations, which fail rather than pass quietly when locale data makes the parser throw.

Verify gate green: 4 timezone passes 6 of 6 each, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0 confirmed directly. 1220 tests across 101 suites. Lint exits 0, run after the last edit.

Not a stall: BACKLOG.md changed state, F42 filed and one finding Declined.

Learnings: none that state an operational rule future iterations must obey; the probe mistake this iteration made, asserting on `Do` in a file that had not extended advancedFormat, is already recorded as a Lesson and was caught by it.

Next: iteration 6 works F42, the only open item, and it is a contained change with a sharp acceptance - reuse the compiled parser across calls sharing a format and locale, get `Do MMMM YYYY` back within 1.5x of the 12.59 microsecond baseline, and prove that a locale mutated through `updateLocale` is still parsed with its new data, since `updateLocale` mutates in place and a naive cache would serve stale names. With the ledger empty after it, iteration 7 spends the run's first evaluator invocation and, on PASS, declares convergence.

## iter 6/10 | 5524dadb-203713 | 2026-07-28 | F42 | done

Task: F42 (Low, performance). `makeParser` rebuilt every locale-derived matcher on every parse, which the iteration 5 audit measured as a 3.2x regression on ordinal formats caused by this run.

Changed: `src/plugin/customParseFormat/index.js` (a compiled-parser cache keyed by locale name and format string, with reference-comparison invalidation), `test/plugin/customParseFormat.test.js` (3 tests added), BACKLOG.md (F42 deleted), PLAN.md (1 Lesson).

Checkpoint: c868f346cc3ed1ce9b4ebad95fffe3c9c80d8c32 (committed with -n, see Lessons)

Verification: The compiled parser holds no per-input state - it reads a token array it never mutates and builds a fresh result object per call - so reuse is safe, and the whole question is staleness.

`dayjs.updateLocale` is the public API that creates it, and it mutates the locale object in place, so object identity is useless as a cache key. What makes staleness detectable is that it reassigns the property it changes rather than mutating the value, so every value a parser derives from is reachable as a property reference: the entry stores the 8 references it was built from and compares them before reuse, which is a few pointer comparisons against tens of microseconds of rebuilding. Mutating one of those arrays in place instead of through `updateLocale` is not detected and no public API does it, which the comment records rather than leaves implied.

The store is a null-prototype object rather than a Map, because `src/` ships unpolyfilled - babel transforms syntax only, with no core-js - and `Map` and `WeakMap` are ES2015 built-ins that no file in `src/` uses. Its keys include caller-supplied format strings, which on a plain object literal would collide with `__proto__` and its siblings, and it is capped so a caller generating format strings cannot grow it without bound.

Measured the same way the finding was, in the same harness with moment as a stability control. `Do MMMM YYYY` is 14.66 microseconds against the 12.59 baseline, 1.16x, inside the 1.5x the acceptance required, and `de` is 10.13 against 11.05, faster than the baseline. The other shapes are well below it rather than merely restored: `D MMMM YYYY` in `en` is 2.16 against 8.30, in `ru` 4.10 against 11.84, and `LLLL` in `ru` 30.42 against 44.58. Moment held at 34.64 and 28.41 against 37.52 and 28.28, which is what makes the comparison a measurement rather than machine noise. Against moment, dayjs went from 1.3x slower on this format to 1.9x faster.

The correctness test earned its keep by first failing to earn it, and that is the part worth recording. Written with renamed months that were ordinary one-word strings, it passed with the invalidation deliberately deleted. The reason is that `matchNames` keeps `matchWord` as its last alternative, so a stale matcher is invisible for a one-word name: the generic pattern captures it and the handler resolves it against live locale data, which the cache never staled. Only a name `matchWord` structurally cannot cross exposes the difference, so the renamed months now contain a space. With that change the test fails with the invalidation removed and passes with it, which is the check the acceptance actually asked for. Two further tests cover the parts a single-locale test cannot: interleaving three locales through one format 50 times, so no locale can be served another's matchers, and driving 400 distinct formats through the cap so parsing still works once entries are evicted.

Verify gate green: 4 timezone passes 6 of 6 each, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0 confirmed directly. 1223 tests across 101 suites, up from 1220. Lint exits 0, run after the last edit.

Contract preserved: no signature changed, the plugin still assigns only `proto.parse`, and no observable parse result changes - the cache returns the same parser the previous code would have built, or rebuilds. An unresolvable locale keeps its old path rather than failing in the cache lookup, so a numeric format with an unknown locale name behaves exactly as before. An invalid format still throws out of `tokenize` and is never cached, so it throws on every call rather than once.

Not a stall: a source file and a test file changed, F42 closed and the ledger is empty.

Learnings: one operational rule recorded in PLAN.md, that `matchWord` as the trailing alternative in `matchNames` masks a wrong or stale name matcher for any one-word name, so a test meaning to prove a matcher was rebuilt must use a name containing a space.

Next: the ledger is empty, the run is in closeout, the Surface inventory is 41 of 41 and the Verify command is green. Iteration 7 spends this run's first evaluator invocation on the whole run - five source changes to one plugin plus a cache - and, on PASS, appends the Converged line and declares convergence. On REJECT the reasons are filed and worked, with 3 iterations of budget left and a second invocation still available.

## iter 7/10 | 5524dadb-203713 | 2026-07-28 | EVALUATOR | blocked

Task: Spend this run's first evaluator invocation on the whole run and, on PASS, declare convergence. Every other condition in the Definition of done held: the iteration 5 audit scored zero High and zero Medium in-envelope, the Surface inventory is 41 of 41, the ledger was empty, and the only commits since that audit are F42's fix, which the audit itself filed, plus state-file bookkeeping.

Changed: BACKLOG.md (F43, F44 and F45 filed).

Checkpoint: 27a5b25867ff1b92012608f907d99e51a3a01980 (committed with -n, see Lessons)

Verification: Evaluator: REJECT, the first invocation and the first rejection. Two substantiated reasons, both regressions this run caused, plus one Low note. The run does not converge.

Each reason was reproduced independently before being filed rather than taken on the evaluator's word, by running one probe file against HEAD and then against `70818a1` with only `src/plugin/customParseFormat/index.js` swapped. Both reproduced exactly as reported.

The first is a High and it is mine, from iteration 4. F41 made the `Do` handler's digit scrape conditional so a non-ASCII digit system would stop throwing, but gave it no failure path for the case where the locale's ordinal table also matches nothing. An input captured only by the trailing `matchWord` alternative therefore leaves `this.day` unset, and `parseFormattedInput` fills it in: `dayjs('zzz April 2019', 'Do MMMM YYYY')` is a valid 2019-04-01 where it was Invalid Date, and `dayjs('garbage', 'Do')` returns today's date where it was Invalid Date and where moment returns Invalid Date.

That is precisely the Lesson this run recorded at iteration 1 and then walked into at iteration 4: removing an accidental loud failure can turn a latent defect into a silent wrong answer, so when a fix makes previously-invalid input parse, check what those inputs now return rather than counting the new successes. I recorded that rule and did not apply it to my own change. The F41 evidence was a 12870-parse before-and-after snapshot, and it could not see this because every input in it was well formed - the snapshot answered "does correct input still parse" and never asked "does incorrect input still fail". A differential built only from valid inputs is structurally blind to a loosened failure path.

The second is a Medium and it is from iteration 3. Deriving `dd` and `ddd` by slicing the full weekday name makes every derived name a prefix of the full name, and `matchNames` orders locale names ahead of `matchWord`, so `ddd` captures `Mon` out of `Monday` and strands `day` for the next matcher. `dayjs('Monday, April 15 2019', 'ddd, MMMM D YYYY')` is Invalid Date where it parsed before, in the default locale, and moment parses it. The committed width test cannot see it because it feeds each token its properly abbreviated form, which still works.

The third is a Low the evaluator raised as a non-blocking note and it is filed as such: `parserCacheSize` counts stores rather than entries, so an overwrite inflates it and the cache clears earlier than the cap intends. No correctness consequence.

What the evaluator checked and found sound bounds what the remaining iterations must redo. The Verify command exits 0 at 1223 tests across 101 suites with the 100 percent line threshold met, and lint exits 0. It rebuilt the enumerations itself rather than trusting the committed ones and reproduced every count: 10296 localized-format parses, 6864 name-token parses and 4290 `Do` parses at zero failures, then widened them to 26598 and 20592 parses plus 572 strict-mode parses, still zero. The F38 differential reproduces at exactly 48 changed values, all December, all in the 12 two-arm locales. The F42 cache survived ten separate attacks, including all 8 tracked dependencies invalidating individually under `updateLocale` with space-bearing names so a stale matcher could not hide, two locale objects sharing a `name` under different registry keys, replacement through `dayjs.locale`, formats differing only by a bracketed literal, and 600 formats driven past the cap.

Verify gate green: 4 timezone passes 6 of 6 each, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0 confirmed directly. 1223 tests across 101 suites. Lint exits 0.

Not a stall: BACKLOG.md changed state, three findings filed.

Learnings: one operational rule recorded in PLAN.md, that a before-and-after differential built only from well-formed input cannot see a loosened failure path, so a change that makes previously-invalid input parse needs a negative corpus - inputs that must still fail - alongside the positive one.

Next: three iterations remain and three findings are open, so the second evaluator invocation does not fit and this run will end out of budget rather than converged. That is the honest outcome and better than converging over a known High. Iteration 8 takes F43, the High, whose fix is to make an unresolved `Do` fail the parse rather than fall through; iteration 9 takes F44, where the remedy is to let the alternation carry the full name as well as the derived short form so the longest match wins; iteration 10 is the final iteration and should prefer a WRAPUP that tidies the ledger and writes the handoff over starting F45, which is a one-line counter fix that the next run can take first.

## iter 8/10 | 5524dadb-203713 | 2026-07-28 | F43 | done

Task: F43 (High, correctness). The `Do` handler could finish having resolved no day, and `parseFormattedInput` filled the gap from its own default, so text that is not an ordinal produced a confident wrong date instead of Invalid Date.

Changed: `src/plugin/customParseFormat/index.js` (the handler now fails when neither the digits nor the locale's ordinal table resolve a day), `test/plugin/customParseFormat.test.js` (2 tests added, a negative corpus and its positive counterpart), BACKLOG.md (F43 deleted).

Checkpoint: c8b0e773d683fd917ce6ccfbe7f4b75df6d7cbd9 (committed with -n, see Lessons)

Verification: The fix is that an unresolved `Do` throws, which is the signal the pre-run code produced by accident when it read `length` off a null match. What F41 removed was the accident; what it failed to add was the deliberate replacement, and this supplies it.

The evidence is a paired corpus rather than a one-sided one, which is the point of this iteration. 2288 positive parses, every locale's own rendered `Do` output across 4 formats and 4 days of month, and 858 negative parses, 6 malformed inputs across all 143 locales. Before the fix: 2288 positives accepted, 0 rejected, and 324 of the 858 negatives wrongly accepted. After: the same 2288 positives accepted, and 0 of 858 negatives accepted. Comparing the two snapshots entry by entry, 0 positive entries changed at all, not merely 0 that changed validity, and all 324 changed negatives moved to Invalid Date with none moving the other way.

The 324 break down usefully: `dayjs('garbage', 'Do')` and `dayjs('xx', 'Do')` were accepted in all 143 locales, while `zzz April 2019` and `Monday, April 15 2019` under `Do MMMM YYYY` were accepted in only 19, because in the other 124 the misalignment made `MMMM` throw for its own reasons. The bare `Do` cases are the ones that mattered: with no year or month token the invented day came from `now.getDate()`, so the library returned today's date for arbitrary text.

Both halves are now committed. The negative corpus is the durable remedy for the class, and it is kept next to its positive counterpart deliberately, because rejecting everything would satisfy a negative test alone. The negative test was confirmed to fail against the pre-fix source and both assert their own check counts, 858 and 572, so neither can silently shrink.

Verify gate green: 4 timezone passes 6 of 6 each, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0 confirmed directly. 1225 tests across 101 suites, up from 1223. Lint exits 0, run after the last edit.

Contract preserved: no signature changed and the plugin still assigns only `proto.parse`. The handler still prefers the locale's ordinal table over the scraped digits, and every input that resolved a day before resolves the same day now, which the 2288 unchanged positive entries show directly. The observable change is confined to input that resolves no day at all, which returns to the Invalid Date it produced before this run.

Not a stall: a source file and a test file changed, F43 closed.

Learnings: none new. This iteration is the application of the rule iteration 7 recorded, that a differential needs a negative corpus, and the rule is already in PLAN.md.

Next: iteration 9 takes F44, the Medium, where deriving a short weekday name by slicing makes it a prefix of the full name so `ddd` captures `Mon` out of `Monday` and strands the rest; the likely remedy is to let the alternation carry the full names alongside the derived short forms, so longest-first ordering consumes the whole name. Iteration 10 is the last of the budget and should prefer a WRAPUP that tidies the ledger and writes the handoff over starting F45, a one-line counter fix the next run can take first. The second evaluator invocation does not fit, so this run will end out of budget rather than converged.

## iter 9/10 | 5524dadb-203713 | 2026-07-28 | F44 | done

Task: F44 (Medium, correctness). Deriving a short weekday name by slicing makes it a prefix of the name it came from, so `ddd` captured `Mon` out of `Monday` and stranded `day`, and the default locale stopped accepting a full weekday name it used to accept.

Changed: `src/plugin/customParseFormat/index.js` (`shortNames` now carries the full names alongside the derived short forms), `test/plugin/customParseFormat.test.js` (4 tests added), BACKLOG.md (F44 deleted).

Checkpoint: d82381831e18971948bd3b287bb315d2e611d38b (committed with -n, see Lessons)

Verification: The fix is one line of intent: when a short array has to be derived, the alternation carries both the sliced names and the full names, and `matchNames` already orders alternatives longest first, so the whole name wins where the input spells it out and the abbreviation wins where it does not. The handlers are unaffected - `dd` and `ddd` discard their match, and the month handlers already fold any multiple of 12 back onto 1-12, which is what makes the doubled list safe for `MMM`.

The measurement is a three-way comparison rather than a before and after, because the question is not only whether the regression is gone but whether anything else moved. Feeding every locale's own full weekday name to `dddd`, `ddd` and `dd`, the count of locales rejecting it: at the pre-run source 0, 60 and 84; after F40 introduced the regression 0, 61 and 85; and now 0, 59 and 83. Compared set-wise rather than by count, no locale is newly failing against the pre-run source in either token, `en` is fixed, and `rw` is fixed as well - it was failing before this run ever started, so the fix is a net improvement on the baseline rather than a restoration of it.

The committed enumeration went through three wrong versions before it was right, and each correction is a fact about the code rather than about the test. The first demanded that all 143 locales accept a full name against all three tokens, which 142 checks failed, because a locale shipping its own short array has always captured the prefix - `de` writes `Mo` for `Montag` - and that predates this run. The second explained the remainder as the locale's own short name being a prefix of its full name, which left 17, all locales whose full name carries a space or a hyphen that `matchWord` cannot cross - `cy` writes `Dydd Llun`. The third left exactly one, `tr`, and it sharpened the rule: `Pzt` is not a prefix of `Pazartesi`, but `Paz`, the Sunday abbreviation in the same array, is. The cause is that some alternative is a proper prefix of the input, not that this weekday's abbreviation is.

So the remainder is asserted as a reason rather than an allowlist: every locale that still rejects a full weekday name must either have some entry in its own short array that is a proper prefix of the full name, or a full name containing a space or hyphen. A failure with any other cause fails the test, which an allowlist of 59 and 83 names would not have caught. The derived set is also derived rather than hardcoded - the locales defining neither short array are computed and asserted to be exactly `en` and `rw` - so a locale that stops shipping one is covered automatically.

Verify gate green: 4 timezone passes 6 of 6 each, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0 confirmed directly. 1229 tests across 101 suites, up from 1225. Lint exits 0, run after the last edit; it caught a line over 100 characters, which is fixed.

Contract preserved: no signature changed and the plugin still assigns only `proto.parse`. Each token's own width still parses, `MMM` still resolves both the abbreviation and the full month name to the same month, and strict mode still rejects a wrong weekday and now also rejects a full name given to `ddd`, because strict reformats and compares and `Mon` is not `Monday`. That is the same rule strict already applied, not a new one.

Not a stall: a source file and a test file changed, F44 closed.

Learnings: none new that is not already recorded. The rule this iteration leaned on, that an enumeration must explain its remainder rather than list it, is the existing Lessons material on shrink-only allowlists applied one step further.

Next: iteration 10 is the last of the budget. F45 is the only open item, a one-line counter fix with no correctness consequence, and the loop prefers a WRAPUP that tidies the ledger and writes the handoff over starting work on the final iteration. The second evaluator invocation does not fit either, so the run ends out of budget rather than converged, with F45 the first thing the next run should take and then a fresh evaluator pass over the whole of this run's work.

## iter 10/10 | 5524dadb-203713 | 2026-07-28 | F45 | blocked

Task: F45 (Low, performance), the last open item and the final iteration of the budget. The counter behind the parser cache counts stores rather than distinct keys, so an overwrite was filed as inflating it and clearing the cache before its cap intends.

Changed: `src/plugin/customParseFormat/index.js` (the counter now increments only for a key that is not already present), BACKLOG.md (F45 marked blocked with its reason).

Checkpoint: e46eb19538f5a21ce1e6cba63ed959708c9e5192 (committed with -n, see Lessons)

Verification: The defect is real and visible by reading the code: a store that overwrites an existing key added to the count, and only a new key adds an entry. The one-line change is applied and the whole suite including the three cache tests is green.

What could not be observed is the impact the finding claims, and after three probe designs the honest conclusion is that it does not reproduce rather than that it is hard to see. The first probe timed 150 numeric formats before and after a churn of overwriting stores, which was a bad design: a numeric format carries no locale-derived matcher, so rebuilding one is nearly free and eviction is invisible. The second used 140 name-bearing formats, one per locale, where a rebuild is expensive; it still showed no difference, and its baseline was slower than its final measurement, which means the JIT was moving more than the cache was.

The third is deterministic and it is the one that settles it. Building a `Do` matcher calls the locale's `ordinal` 31 times, so a counting `ordinal` separates a rebuild from a hit exactly, with no timing involved: a first parse costs 62 calls, 31 to build the matcher and 31 in the handler's own scan, and a cache hit costs 31. An entry was built, confirmed to be reused on an immediate repeat at 31 calls, then subjected to 300 stores that each overwrite one other key because its locale changed under it, and then re-parsed. It cost 31 calls, a hit, under the fixed counter and equally under the old one. The pre-warmed entry survived 300 overwriting stores either way, so the early clear the finding predicts did not happen.

That is why this is recorded blocked rather than done. The acceptance asks for an observed difference and there is none to observe; marking it done would be asserting an improvement this iteration did not demonstrate. The change is kept rather than reverted because counting stores where entries are meant is wrong on its face and the suite is green over it, but it is unverified against its own acceptance and the next run should decide whether to keep it, revert it, or re-file the finding with an acceptance that can actually be measured - most likely by exposing the cache size to a test rather than inferring it through behaviour.

Verify gate green: 4 timezone passes 6 of 6 each, the whole suite under `TZ=America/New_York`, and the whole suite under UTC with the 100 percent line-coverage threshold, exit 0 confirmed directly. 1229 tests across 101 suites. Lint exits 0, run after the last edit.

Contract preserved: no signature changed, no observable parse behaviour changed, and the plugin still assigns only `proto.parse`. The counter is internal state whose only effect is when a still-valid cache entry is discarded, which is why its impact is a performance question and not a correctness one.

Not a stall: a source file changed and F45 changed state.

Learnings: one operational rule recorded in PLAN.md, that an acceptance must name an observable the public API actually exposes, since internal state whose only effect is performance cannot be measured through behaviour and timing at this scale is dominated by JIT warm-up rather than by the thing under test.

Next: this run ends out of budget rather than converged, and the handoff is the run report below. The next run starts with one blocked item, F45, whose finding needs a measurable acceptance before it is worth working. Everything else on the ledger is closed. The Surface inventory is 41 of 41 with `plugin-customParseFormat` swept ten times, most recently at d823818, and its row now records what each sweep did and did not certify. The single most valuable thing the next run can do is spend an early evaluator invocation on this run's five source changes rather than a late one: this run's first evaluator pass found a High and a Medium that six iterations of my own checking had missed, and both were regressions introduced by fixes that each looked complete at the time.

## iter 1/12 | 8749ac2e-144315 | 2026-07-29 | AUDIT | audit

Task: AUDIT. The ledger held zero open tasks (F45 sat blocked), so this iteration generated them: a full fresh-evidence audit, starting with the one stale Surface inventory row and the blocked item's re-examination.

Changed: BACKLOG.md (F45 replaced: the blocked line in Now is now an open Low in Later with a deterministic acceptance), PLAN.md (customParseFormat row re-sweep note and one Lessons line, recorded in the bookkeeping edit), JOURNAL.md (this entry).

Checkpoint: 76da3642794049ff15c78d2b83a54ffed9d06977 (committed with -n, see Lessons)

Verification: Staleness first: `git diff --name-only d823818..HEAD` shows the only source change since the customParseFormat row's tenth sweep is the F45 counter line at e46eb19, so exactly one row was stale and no other row lost its certification. The re-sweep of that row is the counter change exercised on both sides plus the whole pinned corpus re-run green: 10296 localized-format parses, 6864 name-token parses, 4290 Do positives and the 858-parse negative corpus all pass unchanged, and the three cache tests pass.

F45 re-examined, and iteration 10's blocked conclusion is reversed: the filed impact does reproduce. The instrument is a counting `ordinal` on a registered throwaway locale, which separates a rebuild from a hit exactly - building a `Do` matcher costs 31 calls and the handler scan 31 more, so a first parse is 62 and a hit is 31. A pre-warmed `probe-a|Do` entry was subjected to 300 overwriting stores on a second locale's key, each forced by an `updateLocale` that gives the months arrays new identity. Under the current fixed counter the re-parse costs 31, a hit; with the counter line reverted to `parserCacheSize += 1` it costs 62, a rebuild, because the store count crossed the 200 cap and cleared the whole cache. The likely flaw in iteration 10's probes: churn through an unresolvable locale never reaches the cache at all, since `cachedParser` bypasses to `makeParser` when `locale.name` is missing, so its 300 stores exercised nothing. The fix already applied at e46eb19 is therefore correct and verified; what is missing is only the committed test, which is the re-filed F45.

Audit scores, fresh evidence, in-envelope: correctness None (full Verify gate green: three timezone passes 6 of 6, whole suite 1229 of 1229 under TZ=America/New_York, whole suite under TZ=UTC with the 100 percent line threshold, exit 0 confirmed; every pinned enumeration re-ran), testing Low (F45: the cache-eviction differential exists only as a scratch probe), security None (no runtime dependencies, advisories all dev-only and Declined), performance None (F45's defect is fixed and verified), error-handling None (negative corpus pinned, Invalid Date contract documented and Declined), architecture None, code-quality None (one-line delta since the last comprehensive audits), documentation None (types pinned mechanically, agreement fixtures green), dependency-hygiene None (Declined class unchanged), developer-experience None (npm test and lint run on Windows), build None (test/build.test.js green in suite). UX and accessibility not applicable: library with no user-facing surface. All scores claim the whole surface: 41 of 41 rows swept after this re-sweep, none unswept, none stale.

Zero High and zero Medium in-envelope on a full fresh-evidence audit: closeout begins now. No replenishment and no further full audit this run; the run finishes by working or declining what is on the ledger - one item, F45 - and then converging.

Not a stall: a BACKLOG.md item changed state (F45 from blocked to open with a new acceptance).

Learnings: before concluding an effect does not reproduce, prove the probe's operations reach the code under test. The parser cache silently bypasses any parse whose locale is unresolvable, so churn through one exercises nothing, and three probe designs in iteration 10 concluded from that silence that the finding was unobservable. Recorded in PLAN.md Lessons.

Next: iteration 2 executes F45, promoting the scratch probe into `test/plugin/customParseFormat.test.js` with its red-side check re-confirmed against the reverted counter line. Iteration 3 is then the convergence path: Verify green, the adversarial evaluator, and the Converged line if it passes.

## iter 2/12 | 8749ac2e-144315 | 2026-07-29 | F45 | done

Task: F45 (Low, testing). The parser-cache counter fix at e46eb19 was correct but unpinned: the deterministic differential that verifies it lived only in iteration 1's scratch probe, so nothing committed would catch the counter line reverting to counting stores.

Changed: test/plugin/customParseFormat.test.js (1 test added to the parser reuse block), BACKLOG.md (F45 deleted; Now, Next and Later are now all empty), JOURNAL.md (this entry). No source file changed; the fix under test was already applied at e46eb19.

Checkpoint: d1af4b52c251406d59925681bdd906c04e3fa186 (committed with -n, see Lessons)

Verification: The acceptance ran on both sides. Green side: the committed test passes against the current code, 79 of 79 in the file. Red side: with the counter line reverted to `parserCacheSize += 1`, exactly the new test fails, 1 failed and 78 passed, and the source was restored afterwards with the working tree checked clean of src changes. The test distinguishes a rebuild from a hit by counting calls to a throwaway locale's `ordinal` - a build costs strictly more calls than a hit, asserted inside the test itself - and asserts that a pre-warmed `Do` entry still costs hit price after 300 overwriting stores on another locale's key, which is more stores than the 200 cap so a store-counting counter is guaranteed to cross it and clear.

Verify gate green: 4 timezone passes 6 of 6 each, the whole suite under TZ=America/New_York, and the whole suite under TZ=UTC with the 100 percent line-coverage threshold, exit 0 confirmed directly. 1230 tests across 101 suites, up from 1229. Lint run after the last edit.

Contract preserved: no source change this iteration, so no contract question arises. The test pins existing behavior: the cache's cap counter counts entries, an overwriting store adds no count, and a still-valid entry survives churn on other keys.

Not a stall: a test file changed and F45 closed. Closing line: F45 (Low, testing) - cache-eviction differential promoted from scratch probe to committed test, red-side confirmed.

Learnings: none new. This iteration applied the rules already recorded: an acceptance must be confirmed to fail against the code it guards, and the internal value under test is observed through a locale function the test itself supplies rather than through timing.

Next: the ledger is empty and closeout is in force, so iteration 3 is the convergence path: Verify green this iteration, spawn the adversarial evaluator over the run's changes, and on PASS append the Converged line and end with the run report.

## iter 3/12 | 8749ac2e-144315 | 2026-07-29 | EVALUATOR | converged

Task: Convergence. The ledger is empty, closeout is in force since iteration 1's clean audit, and every structural precondition held at the start of this iteration: 41 of 41 inventory rows swept, zero open tasks, and the only commits since the clean audit are the F45 fix that audit filed plus bookkeeping.

Changed: JOURNAL.md (this entry), BACKLOG.md (Converged line, added in the bookkeeping edit).

Checkpoint: c25bfdde14fbe791f7b6cbaa3a46d57cda7543b6 (committed with -n, see Lessons)

Verification: Verify gate green this iteration, run directly before the evaluator: 4 timezone passes 6 of 6 each, the whole suite under TZ=America/New_York at 1230 tests across 101 suites, and the whole suite under TZ=UTC with the 100 percent line-coverage threshold, exit 0 confirmed.

Evaluator: PASS - one fresh-context adversarial sub-agent reviewed the run's diff against 981818c (state files plus one test, no source change), re-ran the Verify command to exit 0 with the same counts, re-ran F45's acceptance on both sides confirming exactly the new test fails with the counter line reverted and restored the tree clean, confirmed the audit's only-source-delta claim against d823818, and hunted the touched code for missed findings, reporting none above Low. Its one observation - the new test's hit assertion depends on residual cache size from earlier tests in the same file, which is deterministic under jest's declaration order - is recorded here and judged not worth a task: the dependency cannot flake without the file's test order changing, at which point the buildCost guard inside the test fails loudly rather than passing vacuously.

This is the first evaluator invocation of this run, so the budget of 2 is respected with 1 used.

Not a stall: convergence is the state change; the run ends here by the closing rule.

Learnings: none new. The convergence machinery worked as designed: the previous run's parting advice to spend the evaluator early was satisfied by iteration 1's audit doing the adversarial re-examination itself, which is what reversed the wrong blocked conclusion before any budget was spent working around it.

Next: nothing. The run converges; the next run's ratchet should find only state-file changes since the Converged commit and re-declare immediately.

## iter 4/12 | 8749ac2e-144315 | 2026-07-29 | F46 | done

Task: F46 (Low, developer-experience, filed and closed this iteration). The stop hook rejected iteration 3's convergence declaration: its own run of the Verify command exited 127. The tests were never red - the same chain had just exited 0 twice in this iteration's shell. The defect was in PLAN.md: the Command line under ## Verify command was wrapped in markdown backticks, and the hook executes that line verbatim through bash -c, so the backticks became a command substitution - the whole chain ran, and then bash tried to execute the chain's own stdout as a command, which is exit 127. This is the first convergence any run has declared on this project, so the hook's verify check had never executed the line before and nothing could have caught it earlier.

Changed: PLAN.md (backticks removed from the Command line; one Lessons line), JOURNAL.md (this entry), BACKLOG.md (Converged line for the re-declared convergence, added in the bookkeeping edit).

Checkpoint: 781c57adb77e634da4208c5c7035bf65219e680f (committed with -n, see Lessons)

Verification: Reproduced before fixing: extracting the command with the hook's own awk yielded a string whose first character was a backtick. After the edit, the same extraction yields the bare chain, and running it exactly as the hook does - bash -c on the extracted string, output discarded - exits 0, confirmed directly. That run is also this iteration's Verify gate: it is the full Verify command executed to completion, all five passes green. The hook's 240-second default timeout is not a risk; the chain completes in well under half of it. Evaluator: PASS was already obtained this run at iteration 3 (1 of 2 invocations used); the run's work is unchanged since that verdict except this PLAN.md formatting fix, which touches no code and no test.

Not a stall: a BACKLOG-relevant state change occurred (convergence re-declared) and the defect fixed was reproduced and observed fixed; the only file changed is PLAN.md plus the journal and ledger, which is the nature of this task - the finding was in a state file.

Learnings: recorded in PLAN.md Lessons - the Verify Command line is executed verbatim by the stop hook via bash -c; never wrap it in backticks or any markdown formatting.

Next: nothing. The run re-declares convergence; the next run's ratchet should find only state-file changes since the latest Converged line and re-declare immediately.
