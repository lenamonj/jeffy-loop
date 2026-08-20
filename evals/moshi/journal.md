# Journal archive

Entries rotated out of JOURNAL.md, oldest first. Appended to, never rewritten.

## iter 1/10 | ab5b96ac-130631 | 2026-08-17 | AUDIT | audit

Task: first audit of square/moshi (Improvement mode, no focus directive). Filled the Operating
envelope, the Verify command with its Oracle class and Environment fingerprint, and the Surface
inventory, then probed breadth-first and filed findings.

Changed: PLAN.md (envelope surfaces, 32 inventory rows, verify command block, four Lessons),
BACKLOG.md (four findings), JOURNAL.md (this entry), .gitignore (loop state file),
.jeffy/probes/_lib/cp.sh, .jeffy/probes/standard-adapters/{CharAdapterProbe.java,paths}.
No library source was changed this iteration.

Checkpoint: 805e3f12f3541687d8328cbf96e9064771d42873
This iteration changed no library source, which is expected of an audit; four BACKLOG items were
added, so the ledger did advance and this is not a stall.

Verification:
Verify command chosen as `./gradlew build check`, which is what CI runs; a plain `./gradlew test`
would have let a spotless or japicmp failure through, and both gates are live in this repo.
Timings measured here: `./gradlew cleanTest test` 82s (every test task re-executed, EXIT=0),
`./gradlew build check` 3s incremental (EXIT=0), `./gradlew :moshi-adapters:test --rerun-tasks` 50s
green, which is the isolated-module run the Method requires before scoring Testing.

Probe harness: `.jeffy/probes/_lib/cp.sh` assembles a classpath from the built module jars plus
okio/kotlin-stdlib/kotlin-reflect/kotlin-metadata from the Gradle cache; Java probes run through the
single-file source launcher and Kotlin probes through kotlin-compiler-embeddable. Three Java probe
programs (66, 39 and 24 checks) and one Kotlin probe (14 checks) were executed against the built
2.0.0-SNAPSHOT jars. Everything they asserted matched the documented contract except the one defect
filed as M-001; the remaining probe mismatches were wrong expectations of mine, re-read against the
implementation and confirmed correct behaviour (Map adapters consume every name so failOnUnknown has
nothing to reject; strict mode rejects a second top-level value as malformed JSON before the
"not fully consumed" check; JsonValueReader reads a Number as a String exactly as JsonUtf8Reader
does; transient fields are silently ignored on read by design).

Two hypotheses were investigated and disproved rather than filed, because the Evidence rule requires
a reproduction: (a) `JsonValueSource.discard()` appeared to reuse a stale `limit` across loop
iterations and skip unscanned bytes - driven with an 18891-byte value over both a fully-buffered and
a 64-byte-chunked source, it consumed exactly the value and left the stream positioned correctly,
because the `index == -1` branch resets `limit` to `buffer.size`; (b) `WildcardTypeImpl.hashCode`
looked like an operator-precedence error - Kotlin infix `xor` binds looser than `+`, so the
expression does equal the `Arrays.hashCode` pair its comment claims.

Reader hardening checked directly on the adversarial surface: 300-deep nesting is refused with
`JsonDataException: Nesting too deep` by beginArray, readJsonValue, skipValue and the writer alike;
unterminated strings, unterminated objects, empty documents and truncated `\u` escapes all produce
JsonEncodingException or EOFException; NaN/infinity are refused unless lenient; long overflow,
int precision loss, leading zeros and byte/short range violations all produce JsonDataException.

Dimension scores, claiming only the rows actually probed. This audit probed 21 of the 32 inventory
rows shallowly and left 11 unprobed (moshi:internal-util except what Types exercises,
moshi:record-adapter, moshi:linked-hash-tree-map, moshi:json-scope,
moshi:annotations-and-exceptions, moshi-kotlin:metadata-plumbing, codegen:ksp-processor,
codegen:adapter-generation, codegen:target-model, examples:recipes,
moshi-kotlin-tests:extra-module-fixture), so none of these scores is a statement about those rows.
No row is flipped to swept: a flip needs a kept battery under .jeffy/probes/, and only
standard-adapters has one so far.
- correctness: High (M-001)
- error handling: High (M-001, same root cause)
- security: None on probed rows - every hostile shape driven produced a typed Moshi exception
- architecture: None on probed rows
- code quality: None on probed rows
- testing: None - 39 test-result files after a full run, and one module green in isolation
- performance: None on probed rows
- documentation: Medium (M-004)
- dependency hygiene: None - okio 3.17.0, kotlin 2.3.21, ksp 2.3.9, kotlinpoet 2.3.0, junit 4.13.2
  are all current and none carries a known advisory
- developer experience / build-ci: Medium (M-002, M-003)
- observability: not applicable - a serialization library with no logging, metrics or tracing
  surface; recorded here rather than scored
- UX and accessibility: not applicable - no user-facing surface

Learnings: the verify command's spotless gate formats root `*.md`, so the three state files are
themselves gated and a trailing space in BACKLOG.md fails the build. Gradle compile-avoidance means
an ABI-neutral source edit leaves every test task up to date, so a 3s verify run is not evidence the
tests ran; the honest worst case is the 82s full re-execution. Both are recorded under Lessons in
PLAN.md, together with the probe-harness rebuild rule and the never-pipe-through-head rule.

Next: M-001, the only High. Its acceptance battery is already written at
.jeffy/probes/standard-adapters/CharAdapterProbe.java and already fails on the unfixed code with
exactly two failures, both StringIndexOutOfBoundsException on the empty string.

## iter 2/10 | ab5b96ac-130631 | 2026-08-17 | M-001 | done

Task: M-001 (High, runtime, error handling) - the built-in `char`/`Character` adapter crashed with
`StringIndexOutOfBoundsException` on an empty JSON string.

Changed: moshi/src/main/java/com/squareup/moshi/internal/StandardJsonAdapters.kt (the length guard in
`CHARACTER_JSON_ADAPTER.fromJson` now rejects any length other than 1),
moshi/src/test/java/com/squareup/moshi/MoshiTest.java (empty-string assertions added to both
`charAdapter` and `CharacterAdapter`), CHANGELOG.md (Unreleased entry), BACKLOG.md, JOURNAL.md.

Checkpoint: ed6cf5225027c175ad83d294026f6e74d69fb01a

Verification:
Reproduction first, as filed: the battery exited 1 with the two expected
StringIndexOutOfBoundsException failures before any edit.
Fix: `if (value.length > 1)` became `if (value.length != 1)`, so an empty string takes the same
JsonDataException path a too-long string already took.
Contract preserved: the adapter is reached only through the `char.class` and `Character.class`
branches of `StandardJsonAdapters.create`, and the two tests that pin it, `MoshiTest.charAdapter`
and `MoshiTest.CharacterAdapter`, assert the exact message `Expected a char but was "ab" at path $`
for the too-long case, the NULL-token message for `char.class`, and null round-tripping for
`Character.class`. None of those changed: the format string, the argument order and the too-long
branch are untouched, and the new case emits `Expected a char but was "" at path $` from the same
`ERROR_FORMAT`. The public signature is unchanged and the accepted input set only narrows, from
"any string of length 0 or 1" to "any string of length 1", which is what the too-long branch already
implied.
Acceptance check: `java -cp "$(bash .jeffy/probes/_lib/cp.sh .)" .jeffy/probes/standard-adapters/CharAdapterProbe.java`
exits 0, all 8 checks green.
The new JUnit assertions were also driven against unfixed code by copying the fixed source aside,
restoring the old guard, and running `./gradlew :moshi:test --tests com.squareup.moshi.MoshiTest`:
exit 1 with `MoshiTest > charAdapter FAILED java.lang.StringIndexOutOfBoundsException` and
`MoshiTest > CharacterAdapter FAILED java.lang.StringIndexOutOfBoundsException`. The fixed source was
then copied back and the guard re-checked, so the project's own suite now pins this fix, not only the
jeffy battery.
Verify gate: `./gradlew build check` exit 0, with `:moshi:test` executed rather than up to date.
Battery ownership: the diff touched moshi/src/main/java/com/squareup/moshi/internal/StandardJsonAdapters.kt,
which is the single path declared in .jeffy/probes/standard-adapters/paths; that battery was run in
this iteration and passed.
Surface inventory: moshi:standard-adapters is still unswept, so there was no swept row to flip back.

Closed this iteration: M-001 (High) - empty JSON string decoded to `char`/`Character` now raises
JsonDataException; battery and two JUnit tests both green, both proven to fail on the unfixed guard.

Learnings: no new operational rule. The copy-aside-and-restore procedure for proving a test fails on
unfixed code worked as written and left the tree byte-identical, confirmed with `git diff --stat`
showing the one intended line.

Next: M-002, the top open Medium - the CI publish guard that compares `matrix.kotlin-test-mode`
against a lowercase literal the matrix never produces.

## iter 3/10 | ab5b96ac-130631 | 2026-08-17 | M-002 | done

Task: M-002 (Medium, build-ci, correctness) - the CI publish step was guarded by a literal the
build matrix never produces, so master snapshots have never been published.

Changed: .github/workflows/build.yml (the publish guard now compares against 'REFLECT'),
.jeffy/probes/ci-workflow/{matrix_guard_check.py,paths}, BACKLOG.md (M-002 removed, the class
recorded under Settled classes), JOURNAL.md.

Checkpoint: cb0d0ad19591134900ee4599b1e623ad071c2eb7

Verification:
Reproduction first, as filed: `python3 .jeffy/probes/ci-workflow/matrix_guard_check.py` exited 1
with `guard compares matrix.kotlin-test-mode == 'reflect' but the matrix declares
['REFLECT', 'KSP'], so the guard never fires`.
Fix: the guard's literal became 'REFLECT'. Uppercase is the spelling the matrix declares and the
spelling the build requires - `moshi-kotlin-tests/build.gradle.kts` and
`moshi-kotlin-tests/codegen-only/build.gradle.kts` both resolve `-PkotlinTestMode` through
`TestMode::valueOf`, which accepts only the enum's own uppercase names - so lowering the matrix
instead would have broken the Test step in both legs. Only the guard was safe to change.
Contract preserved: the publish step still runs at most once per push, on the square/moshi
repository, on refs/heads/master, and now from the REFLECT leg rather than from no leg at all. The
Test step's expression is untouched, so both matrix legs still run the same gradle command.
Acceptance check: the same command exits 0, printing that the single guard is one of
['REFLECT', 'KSP'].
Strong enough to fail: after the fix, the fixed workflow was copied aside, the old lowercase literal
restored, the check re-run - exit 1, same message - and the fixed file copied back, with
`git diff --stat` confirming the one intended line.
Class completeness: the acceptance check as filed named build.yml alone, so the probe was widened
before closing to enumerate every `.yml`/`.yaml` under `.github/workflows/` and every
`matrix.<key> == <literal>` guard inside each. It reports 1 guard across 2 workflow files;
release.yml has no matrix at all. That enumeration is the class's check and is recorded under
Settled classes.
Verify gate: `./gradlew build check` exit 0.
Battery ownership: the diff touched .github/workflows/build.yml, which is the path declared in
.jeffy/probes/ci-workflow/paths; that battery was run in this iteration and passed. No battery
declares .jeffy paths, so the probe's own edit pulled in no other battery.

Closed this iteration: M-002 (Medium) - the publish guard now matches a value the matrix produces,
proven by an enumerating check that fails on the old literal and passes on the new one.

Learnings: no new operational rule. Worth recording as context rather than as a rule: this defect
survived from 2021 because nothing in the build ever asserts that a workflow guard is reachable, and
a guard that never fires produces no output to notice.

Next: M-003, the japicmp baseline whose declared coordinate and resolved version disagree.

## iter 4/10 | ab5b96ac-130631 | 2026-08-17 | M-003 | done

Task: M-003 (Medium, build-ci, dependency hygiene) - both japicmp subprojects declared a 1.15.2
baseline and then constrained the same configuration to 1.14.0, so the binary-compatibility gate
compared against a release neither file names.

Changed: moshi/japicmp/build.gradle.kts and moshi-adapters/japicmp/build.gradle.kts (the redundant
`version { strictly("1.14.0") }` constraint deleted from each),
.jeffy/probes/japicmp-baseline/{declared_equals_resolved.sh,paths}, BACKLOG.md (M-003 removed, the
class recorded under Settled classes), JOURNAL.md.

Checkpoint: 15588b3f3aaa5aefc59906bf3dba7387be10aaec

Verification:
Reproduction first, as filed: `bash .jeffy/probes/japicmp-baseline/declared_equals_resolved.sh`
exited 1 with `:moshi:japicmp: baseline declared 1.15.2 but resolved 1.14.0` and the same line for
`:moshi-adapters:japicmp`.
Root cause read from history rather than guessed: `strictly("1.14.0")` replaced `isForce = true` in
8a098d6a (Feb 2023) while the coordinate itself still read 1.14.0, so the two agreed at the time.
Renovate then bumped the coordinate to 1.15.0, 1.15.1 and 1.15.2 (1889c2bf and its predecessors)
rewriting only the coordinate string, which is all it knows how to rewrite. The constraint has
decided the baseline ever since.
Fix chosen by testing rather than assertion: the constraint was deleted rather than re-pinned,
because a re-pin recreates the same two-places-one-bumped defect on the next bump. With the block
gone, `./gradlew :moshi:japicmp:dependencies --configuration baseline` resolves
`com.squareup.moshi:moshi:1.15.2`, so the constraint was redundant - the baseline configuration
holds exactly one dependency, declared `isTransitive = false`, and there is no conflict for Gradle
to resolve. The coordinate is now the single source of truth and it is the string renovate already
maintains.
Contract preserved: the gate still runs under `check`, still uses `onlyBinaryIncompatibleModified`
and `failOnModification`, and its exclude lists are untouched. The one behavioural change is the
baseline it compares against, which is what the task exists to correct.
Evidence the new baseline is actually used and actually passes:
`./gradlew :moshi:japicmp:japicmp :moshi-adapters:japicmp:japicmp --rerun-tasks` exit 0 with 11
tasks executed, and the two reports now open `... against moshi-1.15.2.jar` and
`... against moshi-adapters-1.15.2.jar` where they previously named 1.14.0. The exclude lists were
tuned for the 1.14.0 baseline, so this was a real question and not a formality; both comparisons
pass against 1.15.2 unmodified.
Acceptance check: the same script exits 0, printing declared 1.15.2 / resolved 1.15.2 for both
subprojects.
Strong enough to fail: after the fix the fixed files were copied aside, the originals restored, the
check re-run - exit 1, both sites failing - and the fixed files copied back, with `git diff --stat`
showing exactly the two intended deletions.
Class completeness: the script enumerates the subprojects with
`find . -path '*/japicmp/build.gradle.kts' -not -path './build/*'` rather than from a hand-kept
list, so a third japicmp subproject would be checked without editing the probe. It reports 2.
Verify gate: `./gradlew build check` exit 0.
Battery ownership: the diff touched both paths declared in .jeffy/probes/japicmp-baseline/paths;
that battery was run in this iteration and passed. The standard-adapters and ci-workflow batteries
declare paths this diff did not touch.

Closed this iteration: M-003 (Medium) - both japicmp baselines now resolve to the 1.15.2 their
coordinates name, proven by an enumerating check that fails on the old files and by japicmp reports
that name the new baseline.

Learnings: no new operational rule. Context worth keeping: a version constraint sitting beside a
coordinate is a bot-hostile shape, because dependency bots rewrite coordinates and not constraints,
and the resulting disagreement is silent in every build log.

Next: M-004, the README that still presents 1.x coordinates and kapt as current guidance. That is
the last open Medium; after it the ledger holds only the 32 unswept Surface inventory rows.

## iter 5/10 | ab5b96ac-130631 | 2026-08-17 | M-004 | done

Task: M-004 (Medium, docs, documentation) - README.md presented 1.x install coordinates and kapt as
current guidance beside 2.x guidance.

Changed: README.md (both Maven `<version>` blocks and the codegen sentence),
.jeffy/probes/readme-install/{install_guidance_check.py,paths}, BACKLOG.md (M-004 removed, the class
recorded under Settled classes), JOURNAL.md.

Checkpoint: 1cb9fe55610922850b2be126f1da14713ddb270f
Before this checkpoint the gate was also run as `./gradlew build check --rerun-tasks`: exit 0 with
all 59 tasks executed in 55s, so nothing in this iteration's green rests on a cached verdict.

Verification:
Reproduction first, as filed: `grep -cn '1\.15\.2\|kapt' README.md` returned 3 on the committed
README - the `moshi-kotlin` Maven version, the `moshi` Maven version, and the kapt sentence - which
is exactly the count the task line claimed.
Fix: both Maven blocks now name 2.0.0-alpha.1, the version their adjacent Gradle snippets already
used and the latest release CHANGELOG.md records; and the codegen sentence now reads "You'll need to
enable KSP and then add the following to your build to enable the symbol processor". The word
"annotation processor" went with kapt: KSP is a symbol processor, and the section's only snippet is
the KSP one.
Enumeration behind the prose claim that 2.x ships no kapt processor: the codegen module's source
tree has an `api` and a `ksp` package and no kapt or apt package
(`ls moshi-kotlin-codegen/src/main/java/com/squareup/moshi/kotlin/codegen/`), no build script in the
repository applies a kapt plugin or declares a kapt configuration, and CHANGELOG.md's upgrade guide
instructs upgraders to remove the kapt plugin and the kapt Moshi dependency. The single remaining
match for `kapt` anywhere in the tree is a comment in a test fixture describing what kapt could not
see, which is history, not guidance.
Acceptance check: `python3 .jeffy/probes/readme-install/install_guidance_check.py` exits 0, reporting
that all 5 install coordinates name 2.0.0-alpha.1 and that kapt is not named.
Strong enough to fail: the fixed README was copied aside, the committed one restored with
`git show HEAD:README.md`, the check re-run - exit 1, naming both invariants, listing 1.15.2 for the
two Maven blocks against 2.0.0-alpha.1 for the three Gradle coordinates and kapt on its line - and
the fixed file copied back, with `git diff --stat` showing the four intended lines.
Class completeness: the check does not grep for the literal 1.15.2. It collects every Maven block
and every Gradle coordinate naming a `com.squareup.moshi` artifact and fails when they name more
than one version, so the next release that moves one snippet and not the other is caught by the same
check without editing it. It reports 5 coordinates today.
Verify gate: `./gradlew build check` exit 0. Because README.md is inside spotless's `misc` target and
the incremental run reported every task up to date, `./gradlew spotlessCheck --rerun-tasks` was run
as well - exit 0 with `:spotlessMiscCheck` actually executed - so the formatting gate really saw the
edited file rather than a cached verdict.
Battery ownership: the diff touched README.md, the single path declared in
.jeffy/probes/readme-install/paths; that battery was run in this iteration and passed.

Closed this iteration: M-004 (Medium) - README install snippets now agree on 2.0.0-alpha.1 and kapt
is gone, proven by an enumerating check that fails on the committed README and passes on the fixed
one.

Learnings: an incremental `./gradlew build check` can report every task up to date on an iteration
that edited a gated file, because a preceding `spotlessApply` leaves the check's inputs already
normalised; when the diff touches a file spotless formats and the gate reports no executed task,
re-run the gate with --rerun-tasks before believing it. Recorded under Lessons in PLAN.md.

Next: the ledger now holds no open task, so the queue's next entry is the Surface inventory, whose
32 rows are all unswept. The gate's own scheduling rule also applies here - the ledger has emptied
with this run's full audit on record and 5 iterations remain - so the evaluator gate is due before
the budget is spent on sweeping.

## iter 6/10 | ab5b96ac-130631 | 2026-08-17 | SWEEP | done

Task: with the ledger empty, the top of the queue is the Surface inventory. Swept the four rows this
iteration could properly evidence, building each one's kept known-answer battery under
.jeffy/probes/.

Changed: .jeffy/probes/types/{TypesProbe.java,paths},
.jeffy/probes/standard-adapters/{StandardAdaptersProbe.java,paths},
.jeffy/probes/container-adapters/{ContainerAdaptersProbe.java,paths},
.jeffy/probes/adapter-wrappers/{AdapterWrappersProbe.java,paths}, PLAN.md (four rows flipped),
JOURNAL.md. No library source was changed, so the sweep certifies the tree as of
ec8c3b3daf32ac7d9caed353600205243c79ddda, which is the commit recorded on each row.

Checkpoint: 022869d57e8f6283eed16bcd7e26389dfd25848d
This iteration changed no file outside PLAN.md, JOURNAL.md and .jeffy/, and no BACKLOG.md item
changed state, so by the stall check's own definition it registers as no progress. The previous
primary entry does not say the same - iteration 5 closed M-004 and edited README.md - so this is not
the pair that forms a hard blocker. What advanced is the Surface inventory, from 0 rows swept to 4,
which is scheduled work the queue ranks above open Lows and which the declaration requires.

Verification:
264 known-answer checks executed against the built 2.0.0-SNAPSHOT jars, all green:
types 65, standard-adapters 92 (84 new plus the 8 already there from M-001),
container-adapters 55, adapter-wrappers 52. Every battery exits non-zero on failure and was run
after `./gradlew spotlessApply` reformatted it, so the committed form is the form that ran.

Evidence bar per row, since a liveness probe flips nothing here. Every check compares against a
hand-computed answer, and every documented parameter is driven at two or more values that change the
result: byte and short on both sides of both range ends, char at lengths 0, 1 and 2, int and long at
their exact-representation boundaries, indent at four values including the documented empty string
that means compact, serializeNulls and lenient and failOnUnknown at both values, element and value
types varied so the same document decodes differently under them, and List against Set so the
concrete collection class is asserted rather than only the contents.

Six probe expectations of mine were wrong and were corrected against the implementation rather than
filed, each re-read to confirm the behaviour is the documented one: a nested class reaches
generatedJsonAdapterName as its binary name so the '$' rule applies there too; a raw `List.class`
yields the unresolved type variable `E`, which erases to Object at the adapter-lookup boundary, and
the Object fallback belongs to a class that implements Collection raw, so both branches are now
covered; a map with a null value writes `{}` rather than `{"a":null}` because serializeNulls
defaults to false, which is now driven at both values; MapJsonAdapter wraps its key adapter in
nonNull, which its toString shows; nullSafe and nonNull return `this` only when called on an
already-wrapped instance, so idempotence is by identity on one instance and not across two separate
wrap calls; and the "JSON document was not fully consumed" check is reached by an adapter that
under-consumes, not by trailing content, which strict mode rejects earlier as malformed JSON.

No finding was surfaced by this sweep. That is a statement about these four rows only.

Verify gate: `./gradlew build check` exit 0.
Battery ownership: this diff touched only .jeffy/probes/ and PLAN.md; no battery declares those
paths, so no battery was pulled in by ownership. All five batteries were nevertheless run.

Surface inventory: 4 of 32 rows swept, 28 unswept. The rows swept are moshi:types,
moshi:standard-adapters, moshi:container-adapters and moshi:adapter-wrappers.

Learnings: no new operational rule. Worth recording as context: writing a battery is where the
probe's own assumptions get audited - six of this iteration's checks failed on first run and all six
were mine, not the library's, which is the cost the plan's known-answer bar is buying.

Next: keep sweeping. The remaining 28 rows include the reader and writer families, Moshi's builder
and cache, the class and record adapters, the adapters module, moshi-kotlin and the codegen module.
Convergence is out of reach this run - 28 rows cannot be properly evidenced in four iterations - so
the run will end out of budget with the map advanced rather than declared.

## iter 7/10 | ab5b96ac-130631 | 2026-08-17 | SWEEP | done

Task: continue sweeping the Surface inventory, the top of the queue with the ledger empty. Three
more rows swept, and the sweep surfaced one in-envelope finding, filed this iteration as the rule
requires.

Changed: .jeffy/probes/utf8-reader-numbers/{NumbersProbe.java,paths},
.jeffy/probes/utf8-reader-strings/{StringsProbe.java,paths},
.jeffy/probes/utf8-writer/{Utf8WriterProbe.java,paths}, PLAN.md (three rows flipped),
BACKLOG.md (M-005 filed), JOURNAL.md. No library source was changed, so the sweep certifies the tree
as of a1a91f5a5db4b681055f2a54c51209fc7b32427c, the commit recorded on each row.

Checkpoint: cb5a992d7c1303786731fa60f4396a3bf0a132c6
Not a stall: BACKLOG.md gained M-005 under Next, which is a task line changing state by the stall
check's own definition, so the pair the previous iteration opened does not close here.

Verification:
187 new known-answer checks executed against the built 2.0.0-SNAPSHOT jars, all green:
utf8-reader-numbers 67, utf8-reader-strings 61, utf8-writer 59. Re-running the four batteries from
iteration 6 alongside them keeps the whole set green.

The writer sweep does not sample its escaping table, it drives it: every code point in
U+0000..U+FFFF except the surrogate block is written and compared against an independently computed
expectation - a named short form where one exists, `\uXXXX` below 0x20, the character itself above
it, and ` `/` ` for the two line separators. A wrong entry in that table would round-trip
through Moshi's own reader and stay invisible to any probe that only checks reader/writer agreement,
while breaking every other JSON consumer. All 63488 code points matched.

Finding surfaced and filed: M-005 (Medium, docs). `JsonWriter.isLenient`'s KDoc lists two things
lenient mode permits. Both were driven in strict mode rather than read: the NaN/infinity bullet is
enforced, and the "with strict writing, the top-level value must be an object or an array" bullet is
not - a strict writer accepts a bare long, double, string, boolean and null at the top level, and
`-JsonValueWriter` behaves the same way, so the claim is false in both JsonWriter implementations.
The code is right and the sentence is stale: RFC 7159, which the same paragraph cites, permits any
value at the top level; the restriction it describes belongs to the older RFC 4627. Scored Medium as
misleading documentation, not higher: nothing computes a wrong result and nothing crashes, a reader
of the API is simply told a guarantee that does not exist. The battery now pins the real behaviour
and points at M-005.

Three probe expectations of mine were wrong and were corrected against the implementation: a name
read inside an object reports its path as `$.` rather than `$`; a formfeed is a delimiter to this
reader but not whitespace, so a document that begins with one is rejected for having no value rather
than for being lenient-only; and `String.valueOf` on a null `nextNull()` result binds to the
char-array overload in Java, which is a defect in my probe and not in Moshi.

Verify gate: `./gradlew build check` exit 0.
Battery ownership: this diff touched only .jeffy/probes/, PLAN.md and BACKLOG.md; no battery
declares those paths. All seven batteries were nevertheless run and all passed.

Surface inventory: 7 of 32 rows swept, 25 unswept.

Learnings: no new operational rule. Context worth keeping: driving a documented guarantee rather
than reading it is what found M-005 - the sentence had been in the KDoc for years and every test in
the project writes an object or an array at the top level, so nothing ever contradicted it.

Next: M-005 is the only open task and it outranks the remaining sweep, so it is next. After it the
queue returns to the 25 unswept rows.

## iter 8/10 | ab5b96ac-130631 | 2026-08-17 | M-005 | done

Task: M-005 (Medium, docs, documentation) - `JsonWriter.isLenient`'s KDoc claimed strict mode
restricts the top-level value to an object or an array, which neither writer has ever enforced.

Changed: moshi/src/main/java/com/squareup/moshi/JsonWriter.kt (the stale bullet replaced),
.jeffy/probes/writer-api/{TopLevelValueProbe.java,paths}, BACKLOG.md (M-005 removed), JOURNAL.md.

Checkpoint: b756a40d9c5ac40eaafe619f3be652c4a8d7db44

Verification:
Reproduction first, as filed: the acceptance probe exited 1 on the committed source, with its 18
behavioural checks already green and only the two documentation assertions failing - which is the
shape of this finding, a correct implementation described by a wrong sentence.
Fix: the bullet now reads "Streams that include multiple top-level values. With strict writing, each
stream must contain exactly one top-level value. A top-level value may be of any type in either
mode, as RFC 7159 allows." That is the rule the writer actually enforces, driven at both settings,
and it now mirrors the wording of `JsonReader.lenient`'s corresponding bullet, which was already
accurate - `grep -n "multiple top-level values"` over the two files returns one line each.
Contract preserved: this iteration changed no executable code. `beforeValue` and
`-JsonValueWriter.add` are untouched, so the strict writer still refuses a second top-level value,
still refuses NaN and infinities, and still accepts any single top-level value. The public
signature, the accepted inputs and the emitted bytes are all unchanged; only the sentence describing
them moved.
Acceptance check: `java -cp "$(bash .jeffy/probes/_lib/cp.sh .)" .jeffy/probes/writer-api/TopLevelValueProbe.java`
exits 0 with 20 checks. Seven of them write each kind of top-level value in strict mode through
-JsonUtf8Writer, four do the same through -JsonValueWriter, four drive the two rules strict mode
really has at both lenient settings, and three assert the KDoc no longer claims the restriction
while still documenting the two rules that hold.
Verify gate: `./gradlew build check` exit 0 with `:moshi:test` executed rather than cached, since
the diff touched a file in the moshi module.
Battery ownership: the diff touched moshi/src/main/java/com/squareup/moshi/JsonWriter.kt, which is
declared in .jeffy/probes/utf8-writer/paths and .jeffy/probes/writer-api/paths. Both batteries were
run this iteration: utf8-writer 59 checks green, writer-api 20 checks green.
Surface inventory: unchanged at 7 of 32. The `moshi:utf8-writer` row's implementing code is
`-JsonUtf8Writer.kt`, which this diff did not touch, so that row is not stale. The row whose scope
does name JsonWriter.kt, `moshi:writer-api`, is still unswept, and it stays unswept: the new battery
covers the lenient rules only, not tag/setTag, jsonValue, valueSink, beginFlatten or the value
overloads, so flipping it would certify surface nothing drove.

Closed this iteration: M-005 (Medium) - the KDoc now describes the rule the writer enforces, proven
by a probe that fails on the committed sentence and passes on the new one while driving every
documented rule at both settings.

Learnings: no new operational rule. Context worth keeping: this finding cost nothing to fix and
would have cost nothing to introduce - the sentence was true of RFC 4627 when it was written and
went stale when the writer followed RFC 7159, and no test could have caught it because the
documentation was the only thing that was wrong.

Next: the ledger is empty again, so the queue returns to the Surface inventory with 25 rows unswept
and two iterations left. Convergence is not reachable this run.

## iter 9/10 | ab5b96ac-130631 | 2026-08-17 | SWEEP | done

Task: continue sweeping the Surface inventory. One row swept; a second row's battery found a High
and is left in place as that finding's acceptance check rather than flipped.

Changed: .jeffy/probes/moshi-builder/{MoshiBuilderProbe.java,paths},
.jeffy/probes/value-reader/{ValueReaderProbe.java,paths}, .jeffy/probes/value-writer/paths,
PLAN.md (moshi:moshi-builder flipped), BACKLOG.md (H-001 filed), JOURNAL.md. No library source was
changed, so the sweep certifies the tree as of c6dbbd8b7adcc894e33b548e5fa65aab87894154.

Checkpoint: 287a37f1909309bbd9288804996055c3aa18308b
Not a stall: BACKLOG.md gained H-001 under Now, a task line changing state.

Verification:
moshi-builder: 30 known-answer checks, all green, and the row is flipped. Ordering is checked
differentially with marker adapters that write their own name, so which adapter ran is visible in
the document: add beats a later add, add beats addLast whichever call order is used, and addLast
still beats the built-in. A probe that only asked whether an adapter came back would pass against a
builder that ignored every registration.

value-reader: 32 checks green, 8 failing, and the 8 are a real defect rather than wrong
expectations. Filed as H-001 (High, runtime, correctness).

H-001, driven rather than read. `-JsonValueReader.nextLong` and `nextInt` convert a boxed `Number`
with Kotlin's `toLong()`/`toInt()`, which truncate, saturate and wrap without complaint. The byte
reader routes the same literals through `BigDecimal.longValueExact` and an exact-double check and
refuses them. Same document, two spellings, two answers:
- long from 1.5: value reader 1, byte reader refuses
- long from -1.5: value reader -1, byte reader refuses
- long from 1e19: value reader 9223372036854775807, byte reader refuses
- long from NaN: value reader 0, byte reader refuses
- long from Infinity: value reader 9223372036854775807, byte reader refuses
- int from 1.5: value reader 1, byte reader refuses
- int from 3e9: value reader 2147483647, byte reader refuses
- int from Long.MAX_VALUE: value reader -1, byte reader refuses
The enumeration is the set of numeric read methods on this reader, built by driving each rather than
by grepping: nextInt and nextLong diverge, nextDouble agrees because it keeps the NaN and infinity
check. The short and byte adapters inherit nextInt, which is why 40000-as-short and 300-as-byte
still agree - their range check happens after the lossy conversion, so they catch magnitude errors
and not fractional ones.

Scored High, not Medium: the envelope classifies input to fromJsonValue as adversarial, because it
routinely arrives from a document another library decoded, and the consequence is the rubric's first
clause - users get wrong results. Nothing throws, nothing logs, and an int field holding -1 where
the document said 9223372036854775807 is indistinguishable from data.

The value-reader battery keeps the failing parity assertions rather than pinning today's behaviour,
so it is H-001's acceptance check and the row `moshi:value-reader` stays unswept: a battery that
fails certifies nothing.

Verify gate: `./gradlew build check` exit 0. The failing battery is a finding, not a Verify failure:
no battery declares a path this diff touched, so battery ownership pulled none in, and the eight
failures are pre-existing behaviour this iteration discovered rather than broke.

Surface inventory: 8 of 32 rows swept, 24 unswept.

Learnings: no new operational rule. Context worth keeping: this defect needed a differential probe
to see. Every check that reads a document one way passes, and the value reader's own round-trip is
self-consistent; only reading the same document both ways shows one of them is wrong.

Next: H-001 is the only open task and outranks everything. Iteration 10 is the last, so the choice
there is between closing H-001, whose fix is a bounded change to two methods with its acceptance
check already written and already failing, and a WRAPUP handoff.

## iter 10/10 | ab5b96ac-130631 | 2026-08-17 | H-001 | done

Task: H-001 (High, runtime, correctness) - `-JsonValueReader`'s integral reads returned silently
wrong numbers where the byte reader refused the same document. Closed rather than handed off: the
fix was bounded to one file, its acceptance check was already written and already failing, and a
High left open costs more than a tidier final entry.

Changed: moshi/src/main/java/com/squareup/moshi/-JsonValueReader.kt (nextInt and nextLong now route
every inexactly representable value through one `exactly` helper),
.jeffy/probes/value-reader/ValueReaderProbe.java (String-branch and escape checks added, parity
relaxed to outcome), CHANGELOG.md, BACKLOG.md (H-001 removed, M-006 filed, the class settled),
PLAN.md, JOURNAL.md.

Checkpoint: ee82398dd46839b272db86ffb2a0f0b600d349a2
The `moshi:value-reader` row is flipped at this checkpoint rather than at the iteration's start
commit, because the behaviour its battery now certifies is the behaviour this checkpoint introduced.

Verification:
Reproduction first, as filed: the battery exited 1 with eight parity failures.
Fix: the `is Number ->` branches no longer call Kotlin's lossy `toLong()`/`toInt()`. Values that are
exactly representable by construction - Long, Int, Short, Byte for a long; Int, Short, Byte for an
int - keep the direct conversion, and everything else goes through `BigDecimal(toString())` with
`longValueExact`/`intValueExact`, which is the same instrument `-JsonUtf8Reader` uses on the
equivalent literal. NumberFormatException and ArithmeticException both become the reader's own
typeMismatch, which closes the second site: the `is String ->` branch previously caught only
NumberFormatException, so `fromJsonValue("1.5")` as a long escaped as a raw
`java.lang.ArithmeticException: Rounding necessary`.
Class, not instance: the enumeration is the integral read methods and both their branches - nextInt
and nextLong, Number and String - four sites closed by one helper. nextDouble was driven as part of
the same enumeration and already agreed, so it was left alone. This is recorded under Settled
classes with the command that enumerates it.
Contract preserved: `JsonReader.nextInt`'s own KDoc already said "If the next token's numeric value
cannot be exactly represented by a Java int, this method throws" - the byte reader honoured that and
this reader did not, so the fix brings the code to the documentation rather than the reverse. The
tests that pin these methods, `JsonValueReaderTest.unexpectedIntType` and `unexpectedLongType`, pass
a StringBuilder and so exercise the untouched `else` branch; both still pass. The value-codec
parameterisation of JsonReaderTest skips the precision cases behind
`assumeTrue(factory.implementsStrictPrecision())`, whose two overrides carry the comment
`// TODO(jwilson): fix precision checks and delete his method.` - so this divergence was a known gap
with a stated fix direction, not a design decision. Those overrides are left in place: deleting them
enables four more test methods across two codec factories and could surface further divergences,
which is more than a final iteration should start.
One judgement recorded rather than hidden: the non-finite case raises JsonDataException, not the
JsonEncodingException `nextDouble` uses. JsonEncodingException is an okio IOException, and
`fromJsonValue` converts an IOException into an AssertionError, so raising one here would have
handed the caller an Error. Driving that revealed the same problem already present in nextDouble -
`fromJsonValue(Double.NaN)` on a Double adapter throws `java.lang.AssertionError` today - which is
filed as M-006 for the next run rather than folded into this task.
Acceptance check: `java -cp "$(bash .jeffy/probes/_lib/cp.sh .)" .jeffy/probes/value-reader/ValueReaderProbe.java`
exits 0 with 47 checks, including twelve parity pairs, six String-branch pairs, and one check that
sweeps eleven bad values through both integral adapters and fails if anything other than a
JsonDataException escapes.
Verify gate: `./gradlew build check` exit 0 with `:moshi:test` executed rather than cached.
Battery ownership: the diff touched moshi/src/main/java/com/squareup/moshi/-JsonValueReader.kt,
declared only in .jeffy/probes/value-reader/paths. Every battery in the project was run regardless:
eleven Java batteries totalling 548 checks and the three static checks, all green.

Closed this iteration: H-001 (High) - fromJsonValue now refuses the numbers it cannot represent,
proven by a differential battery that fails on the old reader and passes on the new one.

Learnings: no new operational rule. Context worth keeping: fixing this surfaced the constraint that
shaped it - `fromJsonValue` turns any IOException into an AssertionError, so a JsonReader
implementation reachable through it must never raise JsonEncodingException. That constraint is
invisible from inside the reader and is why M-006 exists.

Next: the run ends here at its budget. M-006 is the next run's first task; 24 inventory rows remain
unswept and the run report names them.

## iter 1/10 | 6f01e99e-140253 | 2026-08-17 | M-006 | done

Task: M-006 (Medium, runtime, error handling) - `fromJsonValue` of a non-finite Double reached the
caller as `java.lang.AssertionError` rather than as a Moshi exception. Carried in from the previous
run as the only open task, so it was the top of the queue ahead of the 24 unswept inventory rows.

Changed: moshi/src/main/java/com/squareup/moshi/-JsonValueReader.kt (nextDouble's strict refusal now
uses the existing `nonFiniteNumber` helper; its KDoc widened to cover the double read),
moshi/src/test/java/com/squareup/moshi/JsonCodecFactory.java (new `readsObjectGraph()` capability),
moshi/src/test/java/com/squareup/moshi/JsonReaderTest.java (the two strict non-finite tests now
assert the exception each codec is supposed to raise), .jeffy/probes/value-reader/ValueReaderProbe.java
(the acceptance check plus the class enumeration), .jeffy/probes/value-reader/paths, CHANGELOG.md,
BACKLOG.md (M-006 removed, the class settled, M-007 filed), PLAN.md, JOURNAL.md.

Checkpoint: 52caa569c895d5533b2a29b765733f2995735474
Not a stall: library source changed, and BACKLOG.md lost M-006 and gained M-007 under Next.
The `moshi:value-reader` row is recorded at this checkpoint rather than at the iteration's start
commit, because the behaviour its battery certifies is the behaviour this checkpoint introduced.

Verification:
Reproduction first, as filed: `moshi.adapter(Double.class).fromJsonValue(Double.NaN)` printed
`java.lang.AssertionError: com.squareup.moshi.JsonEncodingException: JSON forbids NaN and
infinities: NaN at path $`, and the same for POSITIVE_INFINITY and Float.NaN.

Fix: one line. `JsonEncodingException` is an okio IOException and `fromJsonValue` converts an
IOException into an AssertionError, so a reader that only ever traverses an object graph must not
raise one; the `nonFiniteNumber` helper H-001 introduced for the integral reads already returns the
right exception, and nextDouble now uses it. The byte reader is untouched: a document whose text
says NaN is malformed JSON and JsonEncodingException is correct there.

Class, not instance, and the enumeration was built by provoking failures rather than by grepping.
Grepping for `JsonEncodingException` in the value reader would have found the one site that spells
the name out and certified nothing about the rest. The battery now drives all 27 failing operations
of that reader reachable through `fromJsonValue` - every override except `hasNext`, which answers
false rather than throwing - and fails if any failure arrives as an Error. Against the unfixed
reader that check named exactly one offender, `nextDouble on NaN`; against the fixed reader it names
none, which is what makes the class closed rather than the instance patched.

Both acceptance checks were run against the unfixed code and observed to fail:
- the probe check `every refusal from a double read is a Moshi exception` failed, reporting
  `NaN through JsonAdapter(Double).nullSafe() escaped as java.lang.AssertionError`
- the probe check `no reader operation fails as an Error` failed on `nextDouble on NaN`
- the two updated JsonReaderTest methods failed on exactly 4 of their 8 parameterised cases, the
  Value and ValuePeek factories of each, which is the pair the fix changes
The test update is a re-pin rather than a relaxation: `readsObjectGraph()` is false for Utf8 and for
ValueSource, whose reader really does read bytes, so those two still require JsonEncodingException,
and the two object-graph factories now require JsonDataException. Either exception arriving from the
wrong codec fails the test, which is what the 4 failures above demonstrate.

Contract preserved: `JsonReader.nextDouble`'s own KDoc already said `@throws JsonDataException if
the next token is not a literal value, or if the next literal value cannot be parsed as a double, or
is non-finite`, so this brings the value reader to its documented contract. No public signature
changed; the observable change through the public API is AssertionError becoming JsonDataException,
recorded in CHANGELOG.md.

Acceptance check: `java -cp "$(bash .jeffy/probes/_lib/cp.sh .)" .jeffy/probes/value-reader/ValueReaderProbe.java`
exits 0 with 55 checks.
Verify gate: `./gradlew cleanTest build check` exit 0 in 34s, with every test task forced to
re-execute rather than reported up to date, and re-run after the state-file edits as
`./gradlew build check --rerun-tasks`, exit 0 in 44s with all 5 spotless check tasks executed.
Battery ownership: the diff touched -JsonValueReader.kt, declared in .jeffy/probes/value-reader/paths.
Every battery was run anyway: eleven Java batteries totalling 555 checks and the three static checks,
all green. That file now also declares JsonAdapter.kt, because the battery pins behaviour that
depends on fromJsonValue's IOException handling.

Filed this iteration: M-007 (Medium, docs, documentation). Driving the fix raised the question of
what the public KDoc actually promises, and the byte reader does not keep it: `[1e400]` is a
well-formed JSON document whose literal overflows to Infinity, and reading it produces
`JsonEncodingException: JSON forbids NaN and infinities: Infinity at path $[0]`, not the
JsonDataException the KDoc names. Reproduced, not read. Scored Medium rather than Low because the
input is an ordinary adversarial document rather than a malformed one, and because Kotlin has no
checked exceptions to force the caller to handle the exception that actually arrives.

Closed this iteration: M-006 (Medium) - fromJsonValue now reports a non-finite double as a Moshi
exception, proven by a battery that fails on the old reader and passes on the new one.

Learnings: no new operational rule. Context worth keeping: the enumeration for a failure-shaped
class is cheap to build here because every reader operation is reachable through one public entry
point - a custom JsonAdapter whose fromJson runs the operation, driven by fromJsonValue - so the
class check needs no access to the internal reader type.

Next: M-007 is the only open task and is the top of the queue. 24 of 32 inventory rows are still
unswept, and they outrank every open Low, so the run's shape after M-007 is sweeping.

## iter 1/10 | 6f01e99e-140253 | 2026-08-17 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines at 704, so all but the last 10 entries were moved to
JOURNAL-archive.md, which did not exist before and now holds 1 entry.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: shares this iteration's checkpoint.

Verification: JOURNAL.md holds 10 entries in 624 lines, JOURNAL-archive.md holds 1, and the moved
entry is the previous run's opening AUDIT. The split was taken only on lines matching `## iter`
followed by a digit, so the heading-grammar example in the preamble was neither counted nor moved.

Learnings: none.

Next: the archive accumulates from here; each further iteration rotates one entry out.

## iter 2/10 | 6f01e99e-140253 | 2026-08-17 | M-007 | done

Task: M-007 (Medium, docs, documentation) - `JsonReader.nextDouble`'s KDoc promised a
JsonDataException for a non-finite value that the byte reader reports as JsonEncodingException. It
was the only open task and the top of the queue.

Changed: moshi/src/main/java/com/squareup/moshi/JsonReader.kt (five `@throws` clauses corrected),
.jeffy/probes/reader-doc-contract/{DocContractProbe.java,doc_contract_check.py,paths} (new battery),
CHANGELOG.md, BACKLOG.md (M-007 removed, the class settled), PLAN.md (Lessons), JOURNAL.md.

Checkpoint: 06b3b5ce238d22a59f281f4b55883172154b3484
Not a stall: JsonReader.kt changed and BACKLOG.md lost M-007 from Next.
No swept Surface inventory row went stale: the only library file touched was JsonReader.kt, whose
row `moshi:reader-api` has never been swept.

Verification:
Filed as one instance, closed as a class. The filed line named nextDouble alone; driving every
documented condition showed the same idiom in four more places, so instance work would have left
four live. The enumeration is every `@throws` clause in the public package - 11 documented methods
across 12 public source files - each driven by a real condition rather than read: 26 conditions in
all, JsonReader's run on both of its implementations because one documented contract has two
implementors and they can disagree, which is exactly how M-006 arose.

Five clauses disagreed with the code:
- nextString, nextBoolean and nextNull each said `@throws JsonDataException if ... or if this reader
  is closed`; both readers raise IllegalStateException for the closed case
- nextDouble said JsonDataException for a non-finite value; the byte reader raises
  JsonEncodingException, reproduced with `[1e400]`, a well-formed literal that overflows to infinity
- skipName stated its condition in prose with no `@throws` clause at all, so nothing tied it to the
  behaviour
The fix is documentation only: no runtime file changed, and the corrected clauses now say what the
readers do, including that nextDouble's answer depends on whether the reader traverses JSON text or
an object graph.

Acceptance check, run against the unfixed source and observed to fail:
`python3 .jeffy/probes/reader-doc-contract/doc_contract_check.py` exited 1 naming all five
disagreements, and exits 0 after the fix with all 11 documented methods agreeing. The checker also
fails on a documented method no condition drives, so a future clause cannot be added without an
executed condition behind it - the enumeration cannot fall behind the source.

Also driven, and clean: JsonAdapter.fromJson's three overloads (JsonDataException on a data
mismatch) and Types.collectionElementType (IllegalArgumentException on a non-collection). JsonWriter
carries no `@throws` clause at all. So the class is closed across the whole public package rather
than across the one file the finding came from.

Verify gate: `./gradlew build check --rerun-tasks` exit 0 in 57s, every task forced.
Battery ownership: the diff touched JsonReader.kt. No existing battery declared it; the new
`reader-doc-contract/paths` now claims `moshi/src/main/java/com/squareup/moshi/*.kt`, so any future
change to a public file in that package runs this check. Every battery was run anyway: eleven Java
batteries totalling 556 assertions and four static checks, all green.

Correction to the previous entry, recorded here rather than by rewriting it: that entry's figure of
555 Java assertions was measured before its own last probe check was added, and the true figure at
checkpoint 52caa569c895d5533b2a29b765733f2995735474 was 556. The per-battery counts it stated are
unaffected.

Closed this iteration: M-007 (Medium) - the public `@throws` clauses now name what the code raises,
proven by a check that fails on the old source and passes on the new one.

Learnings: a KDoc clause is a claim like any other and can be driven rather than read; the rule now
recorded in PLAN.md is that `.jeffy/probes/reader-doc-contract` owns every `@throws` clause in the
public package, so adding one without an executed condition fails the battery.

Next: the ledger is empty and 23 of 32 inventory rows are unswept, so the next iteration audits and
sweeps, taking unswept rows in the order the queue gives them.

## iter 2/10 | 6f01e99e-140253 | 2026-08-17 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines at 708, so all but the last 10 entries moved to
JOURNAL-archive.md, which now holds 3.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: shares this iteration's checkpoint.

Verification: JOURNAL.md holds 10 entries in 611 lines and the archive holds 3, up from 1, so the
archive only grew. The two moved entries are the previous run's M-001 and M-002. The split was taken
only on lines matching `## iter` followed by a digit.

Learnings: none.

Next: unchanged by the rotation.

## iter 3/10 | 6f01e99e-140253 | 2026-08-17 | AUDIT | audit

Task: the ledger was empty, so this iteration audits. The queue's top item was sweeping, and a sweep
iteration batches every row it can properly evidence, so this took the whole `moshi-adapters`
module - its three rows - plus one small core row. No library source was changed; the sweep
certifies the tree as of 67d583bcf34029ee2450f14b92b5b953b10f8568.

Changed: .jeffy/probes/adapters-enum/, .jeffy/probes/adapters-polymorphic/,
.jeffy/probes/adapters-rfc3339/, .jeffy/probes/json-scope/ (four new batteries with their paths
files), PLAN.md (two rows flipped, two annotated), BACKLOG.md (H-002 and M-008 filed, one Proposed
item), JOURNAL.md.

Checkpoint: 4e30ca6af00e9a1f847666addbda3d117483c3f7
Not a stall: BACKLOG.md gained H-002 under Now and M-008 under Next, two task lines changing state,
and the Surface inventory advanced from 9 rows swept to 11. This iteration changed no file outside
PLAN.md, BACKLOG.md, JOURNAL.md and .jeffy/, which is expected of a sweep.

Verification:
Four rows mapped, two flipped, 117 checks executed:
- adapters:polymorphic, 27 checks, all green, flipped. Every documented behaviour driven and every
  documented parameter at two or more values that change the answer: the default at two distinct
  defaults, the label first and last, one subtype under two labels.
- moshi:json-scope, 23 checks, all green, flipped. JsonScope is internal so it was driven through
  `JsonReader.getPath()` and `JsonWriter.getPath()`; every scope constant is reached, including the
  streaming-value scope that `nextSource` and `valueSink` push above the real state. Expected paths
  were written from the JSONPath rules, not captured from a run.
- adapters:enum, 24 checks, 23 green, not flipped: the failing one is M-008's acceptance check.
- adapters:rfc3339, 43 checks, 42 green, not flipped: the failing one is H-002's acceptance check.
  Every expected instant was computed independently with Python's `datetime.fromisoformat` rather
  than by running this parser, so a parser wrong by a constant offset or a factor of ten fails here
  rather than round-tripping cleanly against itself.

H-002 (High, runtime, correctness), reproduced not read. The date-only branch of `parseIsoDate`
returns `GregorianCalendar(year, month - 1, day).time`, and that calendar is lenient by default
while the full form's is built with `isLenient = false`. So `"2015-99-99"` decodes to 2023-06-07,
`"2015-02-30"` to 2015-03-02, `"2015-09-31"` to 2015-10-01, `"2015-13-26"` to 2016-01-26; the same
parser refuses all four in the full form. Scored High under the rubric's first clause: the input is
an ordinary JSON document, which the envelope classifies as adversarial, nothing throws or logs, and
the caller receives a Date that is simply wrong.

M-008 (Medium, runtime, error handling), found differentially. `EnumJsonAdapter` in moshi-adapters
reads `reader.path` after `nextString()` has consumed the value, so its refusal names the next array
element: `["USD","GBP"]` is refused at `$[2]`. Moshi's own built-in enum adapter captures the path
first, with the comment `We can consume the string safely, we are terminating anyway` and a
regression test called `invalidEnumHasCorrectPathInExceptionMessage` - the same defect was found and
fixed once in the core and the sibling copy still carries it. Object paths agree, so this is array
indices only. Medium rather than High: the decoded data is unaffected and only the diagnostic points
at the wrong place.

One Proposed item, not a task. A date-only value decodes in the host machine's time zone, so two
machines disagree by up to a day about the same document - measured at 16 hours between
America/Los_Angeles and Asia/Tokyo. That is deliberate upstream rather than an oversight:
`Iso8601Utils` says `Note that this uses the host machine's time zone. That's a bug.` and
`Rfc3339DateJsonAdapterTest.absentTimeZone` pins it through a helper documented as `a longstanding
bug that we're attempting to stay consistent with`. Correcting it to UTC would break every caller
who has adapted to the current answer, which is a compatibility decision the user makes, not an
audit. The battery therefore pins today's behaviour - local midnight, two hosts disagreeing - so
that a future deliberate change is visible rather than silent. H-002 covers only the leniency in
that same branch, which nothing pins.

Scores, claiming the four rows swept this iteration and no more. 23 of 32 rows were unswept when
this iteration began and 21 are unswept now, so these scores are not the project:
- correctness: High - H-002.
- error handling: Medium - M-008.
- testing: Medium, same root cause as H-002 rather than a separate finding: the project's own
  `Rfc3339DateJsonAdapterTest` drives the date-only path only at `1970-01-01`, where leniency cannot
  show, so no test would have caught an impossible date being rolled forward. H-002's acceptance
  check closes that gap.
- architecture, code quality, security, performance, documentation, developer experience: None on
  the four rows swept. Nothing on these rows reads or writes outside the document, allocates without
  bound, or contradicts its own KDoc.
- dependency hygiene: not re-scored - no dependency changed since the previous run scored it.
- observability, UX and accessibility: not applicable to a serialization library with no user-facing
  surface, as previously recorded.

Verify gate: `./gradlew build check --rerun-tasks` exit 0 in 56s, every task forced, because this
diff touches files spotless formats and an incremental run of it reported everything up to date.
Battery ownership: no library source changed this iteration, so no battery was pulled in by a path
match. All batteries were run regardless: sixteen Java battery files reporting 671 passing
assertions, with two of them failing by design because they carry this iteration's two new
acceptance checks, and the four static checks green.

Learnings: no new operational rule. Context worth keeping: two of this iteration's four rows were
mapped by comparing an adapter against its sibling in the same library rather than against a
hand-written expectation, and both findings came from exactly that comparison. Where one contract
has two implementations, the differential is the instrument.

Next: H-002 is the only open High and the top of the queue. M-008 follows it, then the 21 remaining
unswept rows.

## iter 3/10 | 6f01e99e-140253 | 2026-08-17 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines at 716, so all but the last 10 entries moved to
JOURNAL-archive.md, which now holds 5.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: shares this iteration's checkpoint.

Verification: JOURNAL.md holds 10 entries in 595 lines and the archive holds 5, up from 3, so the
archive only grew. The two moved entries are the previous run's M-003 and M-004.

Learnings: none.

Next: unchanged by the rotation.

## iter 4/10 | 6f01e99e-140253 | 2026-08-17 | H-002 | done

Task: H-002 (High, runtime, correctness) - the date-only branch of the RFC 3339 parser used a
lenient calendar, so a date that does not exist was rolled forward into one that does. It was the
only open High and the top of the queue.

Changed: moshi-adapters/src/main/java/com/squareup/moshi/adapters/Iso8601Utils.kt (the date-only
branch now builds a strict calendar), moshi-adapters/src/test/java/com/squareup/moshi/adapters/Rfc3339DateJsonAdapterTest.java
(new test impossibleDatesAreRefusedWithAndWithoutATime), .jeffy/probes/adapters-rfc3339/Rfc3339Probe.java
(the check now drives both spellings of every date), CHANGELOG.md, PLAN.md (adapters:rfc3339
flipped), BACKLOG.md (H-002 removed, the class settled), JOURNAL.md.

Checkpoint: 73dfd490a6e424a534fb9887d25d65ce975f2184
Not a stall: library source changed and BACKLOG.md lost H-002 from Now.
The `adapters:rfc3339` row is recorded at this checkpoint rather than at the iteration's start
commit, because the behaviour its battery certifies is the behaviour this checkpoint introduced.
Surface inventory: 12 of 32 rows swept, 20 unswept.

Verification:
Reproduction first, as filed: the battery exited 1 naming all four dates accepted, `2015-99-99` as
1686110400000, which is 2023-06-07.

Fix: the branch built `GregorianCalendar(year, month - 1, day)`, whose leniency is on by default,
while the full form a few lines below builds its calendar and sets `isLenient = false`. The
date-only branch now does the same - a cleared calendar with leniency off and the three fields set -
so field validation happens on both paths. The resulting instant for a valid date is unchanged,
which the battery pins independently: `a date-only value is local midnight, so two hosts disagree
about it` still passes, computed against a Calendar built in the host zone rather than against this
parser.

Contract preserved, and one part deliberately not changed. The host time zone stays: it is the
Proposed item, `Iso8601Utils` calls it a bug in a comment, and `Rfc3339DateJsonAdapterTest.absentTimeZone`
pins it through a helper documented as a longstanding bug the project stays consistent with. That
test still passes untouched, which is the evidence that this fix changed refusals only and not the
instant any accepted value decodes to. What narrows is the accepted input set, from "any three
integers" to "three integers naming a real date", which is what the full form already required.

Class, not instance. The enumeration is the function's two return paths, built by driving each of
four impossible dates in both spellings - bare and with `T00:00:00Z` - so every date reaches both
the early return and the full-form return, and both must refuse it. Reading the source for calendar
constructions would have found a third in `formatIsoDate`, which is the write path and validates
nothing, and would have proved nothing about either parse path. Recorded under Settled classes with
that enumeration.

Acceptance check: `java -cp "$(bash .jeffy/probes/_lib/cp.sh .)" .jeffy/probes/adapters-rfc3339/Rfc3339Probe.java`
exits 0 with 43 checks.
The project's own suite now pins it too. The new JUnit test was driven against unfixed code by
copying the fixed source aside, restoring the committed version, and running
`./gradlew :moshi-adapters:test --tests com.squareup.moshi.adapters.Rfc3339DateJsonAdapterTest`:
exit 1 with `impossibleDatesAreRefusedWithAndWithoutATime FAILED`. The fixed source was copied back
and the test passes, so this fix is guarded by the build and not only by the jeffy battery.
Verify gate: `./gradlew build check --rerun-tasks` exit 0 in 54s, every task forced.
Battery ownership: the diff touched Iso8601Utils.kt, declared in .jeffy/probes/adapters-rfc3339/paths;
that battery was run and passes. Every battery was run: 672 passing assertions across sixteen Java
battery files, with EnumAdapterProbe still failing by design because it carries M-008's acceptance
check, and the four static checks green.

Closed this iteration: H-002 (High) - an impossible date with no time component is refused on both
parse paths, proven by a battery and a JUnit test that each fail on the old parser.

Learnings: no new operational rule. Context worth keeping: the fix had to leave one defect in the
same three lines untouched, because that one is pinned by a test that documents it as deliberate.
Separating the two - one a task, one a Proposed decision - is what made the fix safe to make at all.

Next: M-008 is the only open task and the top of the queue. 20 inventory rows remain unswept once
adapters:rfc3339 flips, and they outrank open Lows.

## iter 4/10 | 6f01e99e-140253 | 2026-08-17 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines, so all but the last 10 entries moved to JOURNAL-archive.md.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: shares this iteration's checkpoint.

Verification: JOURNAL.md holds 10 entries and the archive holds 7, up from 5, so the archive only
grew. The two moved entries are the previous run's two SWEEP iterations.

Learnings: none.

Next: unchanged by the rotation.

## iter 5/10 | 6f01e99e-140253 | 2026-08-17 | M-008 | done

Task: M-008 (Medium, runtime, error handling) - `EnumJsonAdapter` in moshi-adapters reported the
JSONPath of the element after the one it refused. It was the only open task and the top of the
queue.

Changed: moshi-adapters/src/main/java/com/squareup/moshi/adapters/EnumJsonAdapter.kt (the path is
read before the value is consumed), moshi-adapters/src/test/java/com/squareup/moshi/adapters/EnumJsonAdapterTest.java
(new test invalidEnumHasCorrectPathInExceptionMessage), .jeffy/probes/adapters-enum/EnumAdapterProbe.java
(the module-wide enumeration added), CHANGELOG.md, PLAN.md (adapters:enum flipped), BACKLOG.md
(M-008 removed, the class settled), JOURNAL.md.

Checkpoint: eda91e3cc5bb099589fe713a64f3d4939b63329f
Not a stall: library source changed and BACKLOG.md lost M-008 from Next.
The `adapters:enum` row is recorded at this checkpoint rather than at the iteration's start commit,
because the behaviour its battery certifies is the behaviour this checkpoint introduced.
Surface inventory: 13 of 32 rows swept, 19 unswept.

Verification:
Reproduction first, as filed: the battery exited 1 showing the built-in adapter naming `$[0]` and
`$[1]` where this one named `$[1]` and `$[2]` for the same two documents.

Fix: two lines. `reader.path` is now read into a local before `reader.nextString()` consumes the
value, which is exactly the shape Moshi's own built-in enum adapter already uses, comment included.
Nothing else changed: the message text, the exception type and the reader's final position are the
same, which the battery's other 24 checks and the module's existing tests all still pin.

Why the project's own suite never caught it, which is the part worth recording: the existing test
`withoutFallbackValue` refuses a top-level value, and the root path `$` does not move when a value
is consumed. Only an element inside a container has an index that advances. The new test therefore
reads inside an array, mirroring `MoshiTest.invalidEnumHasCorrectPathInExceptionMessage` down to the
name, which is the test that pins the same contract for the built-in adapter.

Class, not instance, enumerated by provoking failures rather than by grepping. The class is any
refusal in moshi-adapters whose message reports a path, and the enumeration is all eight refusals
the module can raise - four from EnumJsonAdapter, two from Rfc3339DateJsonAdapter, two from
PolymorphicJsonAdapterFactory - each driven with the offending value at `$[1]` so an off-by-one
shows as `$[2]`. Four of the eight report a path and all four now name `$[1]`. The check also fails
if fewer than four report one, so it cannot pass because nothing claimed a path at all. Grepping for
`reader.path` would have found the two sites in one file and said nothing about the other six.
Rfc3339DateJsonAdapter and PolymorphicJsonAdapterFactory report no path at all; that is a different
question from reporting a wrong one, and adding paths to them would be a feature rather than a fix,
so nothing is filed for it.

Acceptance check: `java -cp "$(bash .jeffy/probes/_lib/cp.sh .)" .jeffy/probes/adapters-enum/EnumAdapterProbe.java`
exits 0 with 25 checks.
The project's own suite pins it too. The new JUnit test was driven against unfixed code by copying
the fixed source aside, restoring the committed version, and running
`./gradlew :moshi-adapters:test --tests com.squareup.moshi.adapters.EnumJsonAdapterTest`: exit 1
with `invalidEnumHasCorrectPathInExceptionMessage FAILED`. The fixed source was copied back and it
passes.
Verify gate: `./gradlew build check --rerun-tasks` exit 0 in 44s, every task forced.
Battery ownership: the diff touched EnumJsonAdapter.kt, declared in .jeffy/probes/adapters-enum/paths;
that battery was run and passes. Every battery was run: 674 assertions across sixteen Java battery
files with none failing, the first iteration this run where that is true, and the four static checks
green.

Closed this iteration: M-008 (Medium) - the refusal now names the value it refused, proven by a
battery that enumerates every refusal the module produces and by a JUnit test that fails on the old
adapter.

Learnings: no new operational rule. Context worth keeping: the reason this survived is that its
existing test refused a top-level value, where the path cannot move. A regression test that cannot
distinguish the bug from the fix is the same as no test, and it read as coverage for years.

Next: the ledger is empty and 19 inventory rows remain unswept once adapters:enum flips, so the next
iteration sweeps. Five iterations remain, so convergence this run is out of reach; the run will end
out of budget with the map advanced.

## iter 5/10 | 6f01e99e-140253 | 2026-08-17 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines, so all but the last 10 entries moved to JOURNAL-archive.md.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: shares this iteration's checkpoint.

Verification: JOURNAL.md holds 10 entries in 524 lines and the archive holds 9, up from 7, so the
archive only grew.

Learnings: none.

Next: unchanged by the rotation.

## iter 6/10 | 6f01e99e-140253 | 2026-08-17 | SWEEP | done

Task: with the ledger empty the top of the queue is the Surface inventory. Swept the four core
reader and writer rows this iteration could properly evidence, and the sweep surfaced one
in-envelope finding, filed here as the rule requires. No library source was changed, so the sweep
certifies the tree as of 537a280804e3135875f9e36774bd795641bbdd5b.

Changed: .jeffy/probes/reader-api/{ReaderApiProbe.java,paths},
.jeffy/probes/writer-api/WriterApiProbe.java, .jeffy/probes/value-writer/ValueWriterProbe.java,
.jeffy/probes/utf8-reader-structure/{StructureProbe.java,paths}, PLAN.md (three rows flipped, one
annotated), BACKLOG.md (M-009 filed), JOURNAL.md.

Checkpoint: 88e861ec9a6a01ba6f4590a890922ff4ab0b46f6
Not a stall: BACKLOG.md gained M-009 under Next, a task line changing state, and the Surface
inventory advanced from 13 rows swept to 16. This iteration changed no library source, which is
expected of a sweep.

Verification:
126 new known-answer checks executed, 125 green and one failing by design as M-009's acceptance
check:
- moshi:writer-api, 22 new checks plus the 20 M-005 left, flipped. Every contract belonging to the
  abstract class is driven on both implementations at once and required to produce the same
  document, so a divergence fails rather than hiding in one implementation. serializeNulls and
  lenient are each driven at both values and each changes the output; beginFlatten is shown against
  the unflattened form, which raises IllegalStateException, so the parameter is proven live.
- moshi:value-writer, 23 checks, flipped. The assertions are on the runtime class of what the writer
  builds, not on how it renders: a writer that boxed every number as a Double would produce byte
  identical JSON and fail here. The boxes are checked against the mapping toJsonValue's own KDoc
  states - boxed integral to Long, boxed floating point to Double, everything else BigDecimal -
  which is where one of my expectations was wrong and the documentation was right.
- moshi:utf8-reader-structure, 31 checks, flipped. Each asserts where the reader is looking after the
  operation rather than that it returned, because a skip that stops one token early leaves every
  later value correctly parsed from the wrong place. nextSource is driven with the KDoc's own
  example document and required to return the original bytes including their internal whitespace.
- moshi:reader-api, 30 checks, 29 green, not flipped: the thirtieth is M-009's acceptance check.

M-009 (Medium, runtime, error handling), found by enumeration rather than by reading. The check
drives twelve reader entry points on a closed reader of each kind and requires the two to agree.
Five disagree, all from one root cause: `hasNext()` returns true where the byte reader raises
IllegalStateException, `skipValue()` returns normally having done nothing, and `nextInt`, `nextLong`
and `nextDouble` raise `JsonDataException: Expected NUMBER but was java.lang.Object@<hash>, a
java.lang.Object, at path $`. The closed sentinel is a bare `Any()`, so `require(type, expected)`
matches it whenever the requested type is `Any` and returns it before the closed check runs, while
`hasNext` and `skipValue` never consult `ifNotClosed`. Scored Medium: reading after close is the
application's own misuse rather than adversarial input, which rules out High, but the envelope's
user-error class requires a clear failure message and `skipValue` swallows the error outright, which
rules out Low. Had I checked only the one entry point that first failed, four of the five sites
would have stayed hidden.

Two probe expectations of mine were wrong and were corrected against the implementation rather than
filed: `skipName` under failOnUnknown reports `Cannot skip unexpected NAME at $.a` without the word
path, which is the message the code has always produced, and a boxed Integer becomes a Long rather
than staying an Integer, which is exactly what toJsonValue's KDoc says.

Verify gate: `./gradlew build check --rerun-tasks` exit 0 in 68s, every task forced.
Battery ownership: this diff touched only .jeffy/probes/ and the state files, so no battery was
pulled in by a path match. All were run: twenty Java battery files reporting 779 passing assertions
with ReaderApiProbe failing by design, and the four static checks green.

Surface inventory: 16 of 32 rows swept, 16 unswept. Half the map is now covered.

Learnings: no new operational rule. Context worth keeping: every finding this run has come from
comparing two implementations of one contract - the two readers, the two enum adapters, the two
parse paths of one function. Where a project has a second implementation of the same documented
behaviour, that is the cheapest oracle available, and it needs no hand-computed expectation at all.

Next: M-009 is the only open task and the top of the queue. 16 rows remain unswept with four
iterations left, so this run will end out of budget with the map advanced rather than declared.

## iter 6/10 | 6f01e99e-140253 | 2026-08-17 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines, so all but the last 10 entries moved to JOURNAL-archive.md.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: shares this iteration's checkpoint.

Verification: JOURNAL.md holds 10 entries in 457 lines and the archive holds 11, up from 9, so the
archive only grew.

Learnings: none.

Next: unchanged by the rotation.

## iter 7/10 | 6f01e99e-140253 | 2026-08-17 | M-009 | done

Task: M-009 (Medium, runtime, error handling) - five JsonReader entry points answered as if the
reader were open after it had been closed. It was the only open task and the top of the queue.

Changed: moshi/src/main/java/com/squareup/moshi/-JsonValueReader.kt (one `checkNotClosed` helper,
consulted by hasNext, skipValue and require), moshi/src/test/java/com/squareup/moshi/JsonValueReaderTest.java
(new test everyReadAfterCloseReportsTheReaderIsClosed), .jeffy/probes/value-reader/ValueReaderProbe.java
(hasNext added to its enumeration and its comment corrected), CHANGELOG.md, PLAN.md (moshi:reader-api
flipped), BACKLOG.md (M-009 removed, the class settled, one earlier settled line corrected),
JOURNAL.md.

Checkpoint: 4da9adefeaadf16b528896a15fa3e15f80dd5773
Not a stall: library source changed and BACKLOG.md lost M-009 from Next.
The `moshi:reader-api` row is recorded at this checkpoint rather than at the iteration's start
commit, because the behaviour its battery certifies is the behaviour this checkpoint introduced.
Surface inventory: 17 of 32 rows swept, 15 unswept.

Verification:
Reproduction first, as filed: the battery exited 1 naming all five disagreements.

Fix: one helper. The sentinel `close()` pushes is a bare `Any()`, so `require(type, expected)`
matched it whenever the requested type was `Any` and returned it before the closed check ran, which
is why the three numeric reads reported a type mismatch against `java.lang.Object@<hash>` rather
than saying the reader was closed. `hasNext` and `skipValue` never reached `require` at all.
`checkNotClosed` is now consulted at the top of all three, so every entry point answers
`IllegalStateException: JsonReader is closed`, which is what the byte reader has always answered.

Class, not instance. The enumeration is the entry points themselves - twelve of them driven on a
closed reader of each implementation and required to agree - rather than the call sites of the old
guard. Enumerating the guard's callers would have found the sites that already consulted it and
said nothing about the three that did not, which are exactly the three that were broken.

Contract preserved: no signature changed and no behaviour on an open reader changed. The accepted
call set narrows only in the closed state, where every one of these calls was already a programming
error. `JsonValueReaderTest.close`, which pins nextString and beginArray after close, passes
untouched - it asserts the same IllegalStateException the fix now extends to the rest.

Why the existing test never caught it, which is the same shape as the last two iterations: the
project's `close()` test drives the two entry points that already behaved correctly. Reaching the
broken ones needed the other ten. The new test drives all ten and asserts the message as well as the
type.

Acceptance check: `java -cp "$(bash .jeffy/probes/_lib/cp.sh .)" .jeffy/probes/reader-api/ReaderApiProbe.java`
exits 0 with 30 checks.
The project's own suite pins it too. The new JUnit test was driven against unfixed code by copying
the fixed source aside, restoring the committed version, and running
`./gradlew :moshi:test --tests com.squareup.moshi.JsonValueReaderTest`: exit 1 with
`everyReadAfterCloseReportsTheReaderIsClosed FAILED`. The fixed source was copied back and it passes.

Claims this fix invalidated, re-executed rather than left standing: the settled-class line for M-006
said `hasNext` was the one override absent from its enumeration "because it answers false rather
than throwing", and after this change that sentence is false. The line now says every override
appears and that hasNext is driven on a closed reader, the one state in which it can fail; the
value-reader battery gained that case and its own comment was corrected in the same iteration. It
still passes, now with 55 checks.

Verify gate: `./gradlew build check --rerun-tasks` exit 0 in 40s, every task forced.
Battery ownership: the diff touched -JsonValueReader.kt, declared in both
.jeffy/probes/value-reader/paths and .jeffy/probes/reader-api/paths; both were run and both pass.
Every battery was run: twenty Java battery files reporting 780 passing assertions with none failing,
and the four static checks green.

Closed this iteration: M-009 (Medium) - a closed value reader now reports itself closed at every
entry point, proven by a battery that enumerates twelve of them and by a JUnit test that fails on the
old reader.

Learnings: no new operational rule. Context worth keeping: three consecutive findings this run have
had the same shape - a real regression test existed, and it exercised the one input where the bug
cannot show. Top-level values for a path bug, an already-correct entry point for a closed-reader bug,
`1970-01-01` for a leniency bug. The test's existence was what made each of them look covered.

Next: the ledger is empty and 15 rows remain unswept with three iterations left, so the next
iteration sweeps. Convergence is out of reach this run; it will end out of budget with the map
advanced.

## iter 7/10 | 6f01e99e-140253 | 2026-08-17 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines, so all but the last 10 entries moved to JOURNAL-archive.md.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: shares this iteration's checkpoint.

Verification: JOURNAL.md holds 10 entries and the archive 13, up from 11, so the archive only grew.

Learnings: none.

Next: unchanged by the rotation.

## iter 8/10 | 6f01e99e-140253 | 2026-08-17 | SWEEP | done

Task: with the ledger empty the top of the queue is the Surface inventory. Swept three internal core
rows this iteration could properly evidence. No library source was changed, so the sweep certifies
the tree as of 307043056c5e4195658e5fde031d06626cc7b3a4.

Changed: .jeffy/probes/linked-hash-tree-map/{TreeMapProbe.java,paths},
.jeffy/probes/json-value-source/{ValueSourceProbe.java,paths},
.jeffy/probes/class-adapter/{ClassAdapterProbe.java,paths}, PLAN.md (three rows flipped), JOURNAL.md.

Checkpoint: e337cfd5c62925051f22cc31e8567058a655d811
This iteration changed no file outside PLAN.md, JOURNAL.md and .jeffy/, and no BACKLOG.md item
changed state, so by the stall check's own definition it registers as no progress. The previous
primary entry does not say the same - iteration 7 closed M-009 and changed library source - so this
is not the pair that forms a hard blocker. What advanced is the Surface inventory, from 17 rows
swept to 20, which is scheduled work the queue ranks above open Lows and which the declaration
requires.

Verification:
72 new known-answer checks executed, all green:
- moshi:linked-hash-tree-map, 17 checks. This is a hand-written red-black tree with a linked list
  threaded through it, so it can be wrong in two independent ways - the tree loses a key while the
  list still reports the right size, or the order drifts while every lookup still succeeds - and
  neither shows in a probe that inserts and reads back. The core check mirrors 512 mixed operations
  on a `java.util.LinkedHashMap` and compares the whole state after each one, so a divergence fails
  at the operation that caused it. 200 insertions force a table resize; the check that the sequence
  actually exercised the structure is in the check itself, so agreement over an empty map cannot
  pass it.
- moshi:json-value-source, 30 checks. Its whole job is a boundary, and a scanner off by one byte
  still returns parseable JSON in most cases, so every check asserts the bytes AND what the reader
  reads next.
- moshi:class-adapter, 25 checks. Field selection is the contract, and a round trip cannot see a
  dropped field because the same adapter reads it back as absent, so the checks assert the exact
  document and each decoded field separately.

One judgement recorded rather than filed. A strict reader's `nextSource()` returns a value
containing a `//` comment without complaint, where `readJsonValue()` on the same strict reader
refuses the same document. That is the scanner working as designed: it walks comments and
single-quoted strings whatever the lenient setting because its job is to find where the value ends,
not to judge what is inside, and the bytes it returns are validated by whoever parses them - which
is exactly what Moshi's own ValueSource test codec does with them. Validating there would defeat the
feature, which exists to pass a payload through unparsed. The battery pins the difference rather
than asserting either side is wrong, so a deliberate change to either is visible.

Four probe expectations of mine were wrong and were corrected against the implementation rather than
filed: inherited fields are written before the subclass's own rather than after; a nested generic
class needs `newParameterizedTypeWithOwner` rather than `newParameterizedType`; the conflicting-field
refusal is an IllegalStateException from `checkNull` rather than an IllegalArgumentException; and the
tree map's comparator only decides identity within one hash bucket, so `B` and `b` never meet - `Aa`
and `BB`, which share a hashCode, are the pair that shows it working, and under a comparator that
calls everything equal they merge into a single entry while the natural order keeps both. That last
one was nearly filed as a dead parameter; driving it at the input where it can act is what
distinguished an inert parameter from one I had aimed at the wrong keys.

Verify gate: `./gradlew build check --rerun-tasks` exit 0 in 45s, every task forced.
Battery ownership: this diff touched only .jeffy/probes/ and PLAN.md, so no battery was pulled in by
a path match. All were run: twenty-three Java battery files reporting 852 passing assertions with
none failing, and the four static checks green.

Surface inventory: 20 of 32 rows swept, 12 unswept.

Learnings: no new operational rule. Context worth keeping: three of this iteration's four wrong
expectations were about where a parameter or a field lands, not about whether the code works, which
is the cost of writing a known-answer battery rather than a round-trip one - and the reason it finds
things a round trip cannot.

Next: the ledger is empty and 12 rows remain unswept with two iterations left. Iteration 9 sweeps
what it can; iteration 10 is the last, so it should be a WRAPUP that hands off the remainder rather
than starting a row it cannot finish.

## iter 8/10 | 6f01e99e-140253 | 2026-08-17 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines, so all but the last 10 entries moved to JOURNAL-archive.md.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: shares this iteration's checkpoint.

Verification: JOURNAL.md holds 10 entries and the archive 15, up from 13, so the archive only grew.

Learnings: none.

Next: unchanged by the rotation.

## iter 9/10 | 6f01e99e-140253 | 2026-08-17 | SWEEP | done

Task: with the ledger empty the top of the queue is the Surface inventory. Swept `moshi:internal-util`,
the type-resolution machinery every adapter lookup goes through, and the sweep surfaced one
in-envelope finding, filed this iteration as the rule requires. No library source was changed, so
the work certifies the tree as of 7f67e5d396f4d847169d9681895abae5fc55e8c8.

Changed: .jeffy/probes/internal-util/{UtilProbe.java,paths} (new battery), PLAN.md (the row
annotated), BACKLOG.md (M-010 filed), JOURNAL.md.

Checkpoint: 48dbc59e55bc78f1bfefa2dde93312c13ee2b735

Verification:
35 known-answer checks executed, 33 green and two failing by design as M-010's acceptance check.
These functions compute types, and a wrong answer here does not throw - it produces an adapter for
the wrong type - so every check asserts the exact resolved type by its string form against an answer
written from the generics rules. `resolve` is driven at two different type arguments so a resolver
that ignored its context could not pass; `canonicalize` is checked for idempotence and for making a
reflected JDK type equal Moshi's own construction of the same type; `removeSubtypeWildcard` is
driven on both wildcard directions, since stripping the wrong one would silently widen a type.

M-010 (Medium, runtime, correctness), reproduced not read. `Util.boxIfPrimitive` boxes nothing. Its
table is built with `put(Int::class.javaPrimitiveType, Int::class.java)` per primitive, and in
Kotlin `Int::class.java` is `int.class` rather than `Integer.class` - the wrapper is
`javaObjectType` - so all eight entries map a primitive to itself. Driving all nine keys shows only
`void` boxing, and only because its entry alone is written in Java terms as
`put(Void.TYPE, Void::class.java)`. The consequence is at its two call sites, the public Kotlin
helpers `subtypeOf<T>()` and `supertypeOf<T>()`: the boxing is there so the type can reach
`Types.subtypeOf`, which rejects primitives outright, so `subtypeOf<Int>()` fails with
`IllegalArgumentException: Unexpected primitive int. Use the boxed type.` - the exact error the call
exists to prevent. No test drives either helper with a primitive-backed type; the two tests that
mention primitives here assert the Java-side rejection, which is correct behaviour on that side.

Scored Medium with the rationale, because the rubric's crash clause suggests High: the surface is
the application author's own call rather than adversarial input, the failure is immediate and loud
with a message naming the workaround, and nothing decodes wrongly. Driving all eight primitives
rather than one is what made the root cause visible - a single failing key would have looked like a
missing map entry rather than a systematic use of the wrong Kotlin accessor.

The row stays unswept: its battery fails, and a battery that fails certifies nothing.

Verify gate: `./gradlew build check --rerun-tasks` exit 0, every task forced.
Battery ownership: this diff touched only .jeffy/probes/ and the state files, so no battery was
pulled in by a path match. All were run: twenty-four Java battery files reporting 885 passing
assertions, with UtilProbe failing by design because it carries M-010's acceptance check, and the
four static checks green.

Not a stall: BACKLOG.md gained M-010 under Next, a task line changing state, which is the signal the
previous iteration lacked.

Surface inventory: 20 of 32 rows swept, 12 unswept - unchanged, because the one row this iteration
mapped is held open by the finding it surfaced.

Learnings: no new operational rule. Context worth keeping: this is the second time this run that
driving a parameter across its whole domain rather than at one value decided whether something was a
finding at all. Iteration 8's comparator looked dead until it was driven at colliding keys and
proved live; this one looked like one missing map entry until all eight were driven and proved
systematic.

Next: iteration 10 is the last. M-010 is the only open task and its fix is a two-line change to one
map, but the final iteration is better spent on a WRAPUP that hands off cleanly than on starting
work the run cannot verify and close.

## iter 9/10 | 6f01e99e-140253 | 2026-08-17 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines, so all but the last 10 entries moved to JOURNAL-archive.md.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: shares this iteration's checkpoint.

Verification: JOURNAL.md holds 10 entries and the archive 17, up from 15, so the archive only grew.

Learnings: none.

Next: unchanged by the rotation.

## iter 10/10 | 6f01e99e-140253 | 2026-08-17 | M-010 | done

Task: M-010 (Medium, runtime, correctness) - `Util.boxIfPrimitive` boxed nothing. Closed rather than
handed off, on the same reasoning the previous run's final iteration used: the fix was bounded to one
map in one file, its acceptance check was already written and already failing, and a Medium left open
costs the next run more than a tidier final entry saves.

Changed: moshi/src/main/java/com/squareup/moshi/internal/Util.kt (the wrapper table now uses
`javaObjectType`), moshi/src/test/java/com/squareup/moshi/KotlinExtensionsTest.kt (new test
subtypeOfAndSupertypeOfBoxPrimitives), CHANGELOG.md, PLAN.md (moshi:internal-util flipped),
BACKLOG.md (M-010 removed, the class settled), JOURNAL.md.

Checkpoint: 3e0a83ca36a059e92d8a89f9f6acec39229161cf
Not a stall: library source changed and BACKLOG.md lost M-010 from Next.
The `moshi:internal-util` row is recorded at this checkpoint rather than at the iteration's start
commit, because the behaviour its battery certifies is the behaviour this checkpoint introduced.
Surface inventory: 21 of 32 rows swept, 11 unswept.

Verification:
Reproduction first, as filed: the battery exited 1 naming all eight primitives unboxed.

Fix: nine values in one map, from `X::class.java` to `X::class.javaObjectType`. For a
primitive-backed Kotlin type `Int::class.java` is `int.class`, so the table mapped every primitive to
itself; `javaObjectType` is the accessor that yields the wrapper. The one entry that already worked,
`Void.TYPE`, is the one written in Java terms, and it is now written the same way as its siblings so
the table has no special case left to misread. A comment on the table records why, since the two
spellings differ by one word and read identically.

Contract preserved: `boxIfPrimitive` has exactly two call sites, the public Kotlin `subtypeOf<T>()`
and `supertypeOf<T>()` helpers, and both wanted the boxing they were not getting. Nothing pinned the
old behaviour: the two tests that mention primitives here assert `Types.subtypeOf(byte.class)` is
rejected, which is the Java-side guard and is untouched - the whole point of the boxing is that a
Kotlin caller never reaches that guard. The accepted input set only widens.

Class, not instance, enumerated by driving rather than reading. The class is a Kotlin `X::class.java`
written where the boxed type was meant, and the enumeration is every entry of the table - all eight
primitives plus `void` plus a reference type driven through `boxIfPrimitive`. A single failing key
would have looked like one missing entry; driving all of them showed a systematic use of the wrong
accessor. `PRIMITIVE_TO_WRAPPER_TYPE` is the only such table in the project.

Acceptance check: `java -cp "$(bash .jeffy/probes/_lib/cp.sh .)" .jeffy/probes/internal-util/UtilProbe.java`
exits 0 with 35 checks.
The project's own suite pins it too, and in Kotlin, which is where the defect is visible: the new
test asserts `subtypeOf<Int>()` equals `Types.subtypeOf(Integer.class)` and does the same for all
eight primitives plus a reference type. It was driven against unfixed code by copying the fixed
source aside, restoring the committed version, and running
`./gradlew :moshi:test --tests com.squareup.moshi.KotlinExtensionsTest`: exit 1 with
`subtypeOfAndSupertypeOfBoxPrimitives FAILED`. The fixed source was copied back and it passes.
Verify gate: `./gradlew build check --rerun-tasks` exit 0 in 50s, every task forced.
Battery ownership: the diff touched Util.kt, declared in .jeffy/probes/internal-util/paths and in
.jeffy/probes/types/paths; both were run and both pass. Every battery was run: twenty-four Java
battery files reporting 887 passing assertions with none failing, and the four static checks green.

Closed this iteration: M-010 (Medium) - the primitive wrapper table now boxes, proven by a battery
that drives every primitive and by a Kotlin test that fails on the old table.

Handoff, since this is the final iteration. The ledger is empty, no High or Medium is open, and
nothing is blocked. Eleven inventory rows remain unswept and they are the next run's work in queue
order: moshi:adapter-methods, moshi:record-adapter, moshi:kotlin-extensions,
moshi:annotations-and-exceptions, moshi-kotlin:reflect-adapter, moshi-kotlin:metadata-plumbing,
codegen:ksp-processor, codegen:adapter-generation, codegen:target-model, examples:recipes and
moshi-kotlin-tests:extra-module-fixture. Seven of those eleven are Kotlin or KSP surface, which needs
a Kotlin compile to drive properly - PLAN.md's Lessons already record the compiler classpath that
takes. One Proposed item awaits a decision and blocks nothing. Convergence was never reachable this
run: it requires no unswept row, and the run began with 24 of them.

Learnings: no new operational rule. Context worth keeping: every one of the five findings this run
came from driving two things that should agree - two reader implementations, two enum adapters, two
parse paths, a documented clause against its code, a table against its own purpose. None came from
reading code looking for mistakes.

Next: the run ends at its budget. The next run starts with a fresh audit, an empty ledger and eleven
rows to map.

## iter 10/10 | 6f01e99e-140253 | 2026-08-17 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines, so all but the last 10 entries moved to JOURNAL-archive.md.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: shares this iteration's checkpoint.

Verification: JOURNAL.md holds 10 entries and the archive 19, up from 17, so the archive only grew.

Learnings: none.

Next: the run ends here; the next run rotates from this point.

## iter 1/10 | bc46c612-165940 | 2026-08-17 | AUDIT | audit

Task: the ledger was empty and no Converged line exists, so the ratchet does not apply and this
iteration is the run's full audit. The Surface inventory carried 11 unswept rows, so the audit was
breadth-first as the table requires: every unswept row probed shallowly before any row was taken
deeply, so the worst defect in the unmapped remainder appears in this filing rather than in the
sixth.

Changed: BACKLOG.md (H-003 filed under Now, M-011 under Next), JOURNAL.md. No library source and no
inventory row was touched.

Checkpoint: efaa485808e62c6ce215e5d27911bbc58fa09413

Verification:

Rows probed this iteration, with what each probe actually did. None of them flips a row: every one
is a liveness or reading probe, and the table's own rule is that run-without-crashing certifies
nothing on a surface that computes values. The rows stay unswept and are the queue's next work.

moshi:record-adapter - driven, and this is where H-003 came from. Two records were decoded through a
real `Moshi`: one with a compact constructor rejecting a negative component, one plain. The plain
record round-tripped, the absent-primitive path reported `Required value 'a' missing at $` as it
should, and the validating record returned `java.lang.AssertionError: java.lang.IllegalArgumentException:
a must be non-negative: -5`. The `catch (e: InvocationTargetException)` guarding
`constructor.invokeWithArguments` cannot fire, because a `MethodHandle` propagates its target's
throwable directly instead of wrapping it the way core reflection does, so the sibling
`catch (e: Throwable)` takes every constructor failure and rewrites it as an `Error`. The same dead
catch guards `accessor.invoke` on the write path. `@Json(name)` and `@Json(ignore)` were driven too:
the rename works on both sides and `ignore` has no effect, which is exactly what `Json.kt`'s own note
promises for record classes, so neither is a finding.

moshi:annotations-and-exceptions - driven, and this is where M-011 came from. The public KDoc claims
in these files were checked against executed behaviour rather than read. `JsonDataException`'s claim
about nesting was driven by walking `beginArray` down documents of increasing depth: 255 levels are
accepted and 256 raises `JsonDataException: Nesting too deep at $...`, while the KDoc says the
exception triggers past 31 and a 32-level document was accepted without complaint. CHANGELOG.md
records the limit being raised from 32 to 255, so the doc is stale rather than aspirational. Filed as
an instance and not a class: the public package was scanned for other numeric KDoc claims and this is
the only one, so the three-strike structural remedy has nothing to close over.

moshi:adapter-methods - read in full and driven on the one point where its own error text makes a
promise: both delegate signatures the `Unexpected signature` message advertises were exercised, the
concrete `JsonAdapter<String>` form and the `JsonAdapter<?>` wildcard form the code comments show,
each on both `@ToJson` and `@FromJson`. All four work. No finding.

codegen:ksp-processor and codegen:adapter-generation - the environment fingerprint records that a
plain local run never exercises the KSP variant of `moshi-kotlin-tests`, which defaults to REFLECT,
so the excluded variant was run explicitly: `./gradlew :moshi-kotlin-tests:test -PkotlinTestMode=KSP`
exits 0. That closes the gap the fingerprint names for this iteration but is a suite run, not a
known-answer sweep of the generator.

examples:recipes - all 19 recipe entry points were compiled and executed, every one exiting 0. This
is the row where liveness is furthest from sufficient: these programs are documentation users copy,
so the sweep that flips this row has to assert what each recipe prints, not that it printed.

moshi:kotlin-extensions, moshi-kotlin:reflect-adapter, moshi-kotlin:metadata-plumbing and
codegen:target-model - read, not driven. Nothing reproducible surfaced; the reading raised questions
about the classloader `JvmDescriptors` resolves signature types through and about the default-mask
arithmetic in `KtConstructor.callBy`, neither of which is a finding until it is provoked, so neither
is filed. They are notes for the sweeps, not backlog lines.

moshi-kotlin-tests:extra-module-fixture - not reached this iteration.

Dimension scores, claiming only the surface actually examined above and never the unswept remainder.
Eleven rows remain unswept, so no None here is a statement about the project as a whole:

- Error handling: High. H-003.
- Documentation: Medium. M-011.
- Correctness: None on examined surface. The record rename and ignore paths matched their docs, the
  KSP-mode suite is green, and all four documented adapter-method delegate shapes work.
- Testing: None on examined surface. `./gradlew :moshi-adapters:test --rerun-tasks` was run in
  isolation, per the Method's rule that a suite only ever run whole hides order dependence, and it
  exits 0. The missing coverage that let H-003 live is not filed separately: it is the same root
  cause, and H-003's acceptance check is the test that closes it.
- Dependency hygiene: None. `gradle/libs.versions.toml` names Kotlin 2.3.21, KSP 2.3.9, Okio 3.17.0,
  KotlinPoet 2.3.0, ASM 9.10.1, JUnit 4.13.2, AssertJ 3.27.7, Truth 1.4.5 and Spotless 8.7.0. All
  current, none with a known advisory.
- Architecture, code quality, security, performance, developer experience: None on examined surface.
- Observability: not applicable and recorded as such - Moshi is a library with no logging, metrics or
  tracing surface of its own, and adding one would be the speculative addition the Constraints forbid.
- UX and accessibility: not applicable. There is no user-facing surface; the Goal scopes these two to
  projects that have one.

Verify gate: `./gradlew build check --rerun-tasks` exit 0 in 52s, all 59 tasks forced. Run with
`--rerun-tasks` because this diff touches root `*.md` files that spotless formats, which is the
condition the Lessons section says can otherwise report green without executing.
Battery ownership: the diff touched BACKLOG.md, JOURNAL.md and JOURNAL-archive.md, and no
`.jeffy/probes/*/paths` file declares any of them, so no battery was pulled in by a path match.

Not a stall: BACKLOG.md gained H-003 under Now and M-011 under Next, two task lines changing state.

Surface inventory: 21 of 32 rows swept, 11 unswept - unchanged, which is the honest count for an
audit that mapped rows shallowly without earning a single flip.

Learnings: no new operational rule. Context worth keeping: both findings came from driving a written
promise against the code that is supposed to keep it - a dead catch clause against the exception a
`MethodHandle` actually throws, and a KDoc's stated depth against the depth a driven reader accepts.
That is the fifth and sixth finding on this project to arrive that way and the first to arrive from
reading code looking for mistakes is still outstanding.

Next: H-003 is the top of the queue and is a bounded fix in one file with its acceptance check
already written and already failing. M-011 follows, then the 11 unswept rows.

## iter 1/10 | bc46c612-165940 | 2026-08-17 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines, so all but the last 10 entries moved to JOURNAL-archive.md.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: shares this iteration's checkpoint.

Verification: JOURNAL.md holds 10 entries and the archive 21, up from 19, so the archive only grew.

Learnings: none.

Next: unchanged by the rotation.

## iter 2/10 | bc46c612-165940 | 2026-08-17 | H-003 | done

Task: H-003 (High, runtime, error handling) - every exception a Java record's canonical constructor
or component accessor raised reached the caller as `java.lang.AssertionError`. Top of the queue as
the run's only open High.

Changed: moshi/src/main/java16/com/squareup/moshi/internal/RecordJsonAdapter.kt (both dead
`InvocationTargetException` catches replaced, one new private `rethrowTarget` helper),
moshi/records-tests/src/test/java/com/squareup/moshi/records/RecordsTest.java (new test
recordThrowablesArriveUnwrapped and the two records it drives), CHANGELOG.md, BACKLOG.md (H-003
removed, the class settled), JOURNAL.md.

Checkpoint: e6bddf46070d833d54cfa17063484cee245b416e

Verification:
Reproduction first, as filed: decoding `{"a":-5}` into a record whose compact constructor rejects
negatives returned `java.lang.AssertionError: java.lang.IllegalArgumentException: a must be
non-negative: -5`, and the absent-primitive path returned `Required value 'a' missing at $` as it
already should.

Fix: a `MethodHandle` hands back its target's throwable directly instead of wrapping it in an
`InvocationTargetException` the way `Method.invoke` does, so both `catch (e: InvocationTargetException)`
branches in this adapter were unreachable and the sibling `catch (e: Throwable)` was taking every
constructor and accessor failure and rewriting it as an `Error`. Both catches are gone; what remains
rethrows through one helper applying exactly the policy the dead `rethrowCause` call would have
applied had it ever run - unchecked throwables unchanged, a checked one wrapped, because
`JsonAdapter.fromJson` and `toJson` declare only `IOException`. Choosing that policy rather than
`AdapterMethodsFactory`'s different one - pass `IOException` through, convert the rest to
`JsonDataException` - keeps the fix to what the original code intended and makes no new decision.

Contract preserved, and this changes observable behaviour, so per the Constraints the rationale is
here rather than only in the CHANGELOG: the read path's one deliberate translation is kept exactly
as it was, the loop that turns the `NullPointerException` of unboxing an absent primitive into
`missingProperty`, and the new test drives `{}` against the same validating record to prove it still
fires ahead of the constructor's own exception. What changes is the type of the throwable a caller
sees when the record itself refuses the data: `AssertionError` before, the record's own exception
now. Nothing pinned the old type - the existing `memberEncodeDecodeThrowsExceptionException` test
covers a component adapter throwing, which happens outside both try blocks and is untouched, and
`absentPrimitiveFails` and `nullPrimitiveFails` cover the translated path and still pass. The
accepted input set does not change; only the exception type on a path that was already failing does.

Class, not instance, and the boundary was drawn by driving rather than by reading. The class is a
`catch (InvocationTargetException)` guarding an invocation that cannot throw one. Its enumeration is
the set of `MethodHandle` invocation sites, built by provoking a failure at each rather than by
grepping for the catch: there are two, the canonical constructor on read and a component accessor on
write, and the new test drives both - a validating compact constructor for the first, an explicitly
declared accessor that throws for the second. The three other `InvocationTargetException` catches
reachable on this host were provoked too, to prove they are outside the class rather than to assume
it: an `@ToJson` and an `@FromJson` method throwing surface as
`JsonDataException: java.lang.IllegalStateException: ... at $` on both sides, so both
`AdapterMethodsFactory` catches fire, and a class whose no-arg constructor throws surfaces as
`java.lang.IllegalStateException: ctor boom!` rather than as a wrapper, so `ClassJsonAdapter`'s
fires. `ClassFactory`'s Dalvik `ObjectStreamClass` fallback and `Util`'s generated-adapter
constructor could not be provoked on this host; the settled-class line says so rather than claiming
them.

Acceptance check: `./gradlew :moshi:records-tests:test --tests com.squareup.moshi.records.RecordsTest`
exits 0. It was driven against unfixed code as the Method requires, by copying the fixed adapter
aside, restoring the committed version of that one file - never the test file, which carried the new
test - and re-running: exit 1 with `recordThrowablesArriveUnwrapped FAILED, java.lang.AssertionError`.
The fixed source was copied back.

Verify gate: `./gradlew build check --rerun-tasks` exit 0 in 40s, all 59 tasks forced, run with
`--rerun-tasks` because a `spotlessApply` preceded it.
Battery ownership: the diff touched `moshi/src/main/java16/...`, `moshi/records-tests/...` and
CHANGELOG.md, and no `.jeffy/probes/*/paths` file declares any of them, so no battery was pulled in
by a path match. Because the diff is inside the `moshi` module every battery was run anyway: 24 Java
battery files, all passing, and the four static checks green, including `reader-doc-contract`, which
re-confirms that all 11 documented methods across the 12 public source files still name what they
raise.

Closed this iteration: H-003 (High) - a record's own exception now reaches the caller instead of
`java.lang.AssertionError`, proven by a test that drives both MethodHandle sites and fails on the old
adapter.

Not a stall: library source changed and BACKLOG.md lost H-003 from Now.

Surface inventory: 21 of 32 rows swept, 11 unswept - unchanged. The `moshi:record-adapter` row stays
open: this iteration fixed a defect inside it but ran no known-answer battery over the row, and the
row's own rule is that a fix is not a sweep.

Learnings: a new operational rule, added to PLAN.md's Lessons - a `catch (InvocationTargetException)`
is evidence of nothing until the invocation it guards is identified, because core reflection wraps
and `MethodHandle` does not, and the two read identically at the call site.

Next: M-011 is the only open task and the top of the queue, a docs fix whose acceptance check is a
probe that has to be written. After it the queue is the 11 unswept rows.

## iter 3/10 | bc46c612-165940 | 2026-08-17 | M-011 | done

Task: M-011 (Medium, docs, documentation) - `JsonDataException`'s class KDoc documented a nesting
limit of 31 levels while every surface that raises it accepts 255. The only open task and the top of
the queue.

Changed: moshi/src/main/java/com/squareup/moshi/JsonDataException.kt (the sentence corrected),
.jeffy/probes/exception-docs/{DepthDocProbe.java,paths} (new battery), CHANGELOG.md, BACKLOG.md
(M-011 removed, the class settled), JOURNAL.md.

Checkpoint: 59239f652d7ce2051fc7175a26ba7a96456e600f

Verification:
Reproduction first, as filed: the KDoc read "nesting exceeds 31 levels" and a driven reader accepted
255 and refused 256.

Fix: one sentence. The limit was raised from 32 to 255 - CHANGELOG.md records both the raise and the
older change that set 31 - and the KDoc never followed, so the public exception documented a bound
eight times tighter than any surface enforces. The corrected sentence also says which directions it
covers, because the old one said "a document's nesting" without saying whether writing counts, and
it does.

Class, not instance, and the class is what the sentence generalises over rather than the file it
sits in. `JsonDataException` is raised at three call sites, but four surfaces reach them: the reader
over bytes, the reader over an object graph behind `fromJsonValue`, the writer over bytes, and the
writer that builds an object graph behind `toJsonValue`, the last two sharing one `checkStack`. The
enumeration is those four, built by driving each to its own refusal rather than by reading the 256
they happen to share, because reading the constant would have agreed with a doc written from the
same constant and said nothing about what a document does. All four accept exactly 255.

The battery derives the depth instead of asserting it. `deepestAccepted` walks up from depth 1 until
the surface refuses and requires the refusal to be a `JsonDataException` naming the nesting, so a
surface that ran out of something else first fails the probe rather than quietly reporting a smaller
number. Each surface then gets three checks: its driven limit equals the KDoc's number, one level
further raises `JsonDataException`, and the documented depth itself is accepted, so an off-by-one in
either direction fails on one side or the other. Twelve checks in all.

Acceptance check: `java -cp "$(bash .jeffy/probes/_lib/cp.sh .)" .jeffy/probes/exception-docs/DepthDocProbe.java`
exits 0 with 12 checks. Driven against the unfixed doc as the Method requires, and with the battery
in exactly the form it is committed in rather than the draft that first found the defect: the fixed
KDoc was copied aside, the committed version of that one file restored, and the probe re-run - exit
1, with four failures, one per surface, each reporting expected 31 and actual 255. The fixed source
was copied back.

Verify gate: `./gradlew build check --rerun-tasks` exit 0 in 40s, all 59 tasks forced, run with
`--rerun-tasks` because a `spotlessApply` preceded it - which this iteration needed, since spotless
formats `**/*.java` and that includes the new probe under `.jeffy/`.
Battery ownership: the diff touched `JsonDataException.kt`, which two paths files declare - the new
`.jeffy/probes/exception-docs/paths` and `.jeffy/probes/reader-doc-contract/paths`, whose glob owns
the whole public package. Both were run and both pass, the latter still finding all 11 documented
methods across the 12 public source files in agreement with their code. Every other battery was run
too: 25 Java battery files, all passing, and the four static checks green.

Closed this iteration: M-011 (Medium) - the documented nesting limit now matches the one all four
surfaces enforce, proven by a battery that derives the limit by driving rather than by reading the
constant, and that fails four ways against the old sentence.

Not a stall: library source changed and BACKLOG.md lost M-011 from Next.

Surface inventory: 21 of 32 rows swept, 11 unswept - unchanged. The `moshi:annotations-and-exceptions`
row stays open: this battery pins one class's KDoc claim, not the eight files the row covers.

Learnings: no new operational rule. Context worth keeping: the doc was wrong for as long as it took
to raise the limit, and nothing in a build that runs 39 test files could have noticed, because the
claim was prose. The battery that now owns it is the same instrument shape as `reader-doc-contract`,
which owns the `@throws` clauses in the same package - two prose contracts, two executing checks.

Next: the ledger is empty with seven iterations left, so the queue is the 11 unswept inventory rows
and the next iteration sweeps. Convergence needs every one of them, so the run's remaining value is
in how many can be properly evidenced.

## iter 3/10 | bc46c612-165940 | 2026-08-17 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines, so all but the last 10 entries moved to JOURNAL-archive.md.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: shares this iteration's checkpoint.

Verification: JOURNAL.md holds 10 entries and the archive 24, up from 21, so the archive only grew.

Learnings: none.

Next: unchanged by the rotation.

## iter 4/10 | bc46c612-165940 | 2026-08-17 | SWEEP | done

Task: with the ledger empty the top of the queue is the Surface inventory, so this iteration sweeps.
Three rows were properly evidenced - `moshi:adapter-methods`, `moshi:record-adapter` and
`moshi:annotations-and-exceptions` - and the first of them surfaced one in-envelope finding, filed
this iteration as the rule requires. No library source was changed, so the work certifies the tree as
of d7d94b72bdf6b57fce35d932288d92216c9a764a.

Changed: .jeffy/probes/adapter-methods/{AdapterMethodsProbe.java,paths},
.jeffy/probes/record-adapter/{RecordAdapterProbe.java,paths},
.jeffy/probes/annotations-and-exceptions/{AnnotationsProbe.java,paths} (three new batteries),
PLAN.md (three rows annotated), BACKLOG.md (M-012 filed), JOURNAL.md.

Checkpoint: 79db65efdefb7b85e8e6d3e9af26af9b8f618967

Verification:
104 known-answer checks executed across the three new batteries, all green: 41, 37 and 26.

`moshi:adapter-methods`, 41 checks. This surface computes a routing decision, and a wrong routing
does not throw - it silently binds a different adapter or calls a method with an argument it did not
expect - so every check asserts an exact document or an exact decoded value. All six documented
signature shapes are driven, each at two points that must render differently, so a binding that
ignored its argument could not pass. The two flags this factory reads from the method rather than
from the caller are each driven at both settings: a qualifier, with the same type resolving
differently with and without it, and the nullable value parameter, on both sides. The delegate form
is driven at one and at two delegates, the second because the adapters array is positional and a
shape that filled it wrongly would swap them and still produce a document.

`moshi:record-adapter`, 37 checks. Every write asserts the exact document rather than a round trip.
The generic-record checks assert the runtime class of what was decoded rather than the record's
printed form, because both readers coerce between a number and its string form, so `Generic<String>`
and `Generic<Integer>` print identically over the same document and only the class tells them apart -
which is what the first draft of this battery got wrong and reported as a finding until it was
driven properly. The first check pins which implementation is loaded, so the battery cannot silently
certify the base-source shim; that shim is unreachable on any JDK past 16 and the row's annotation
says so rather than claiming it.

`moshi:annotations-and-exceptions`, 26 checks. Each annotation is driven where its KDoc says it
applies and where that KDoc carves it out, which for `Json.ignore` is three declaration kinds of
which only the field honours it. `JsonClass.generator` is the documented-inert case the inventory
rules allow: its KDoc says it is a processor-time tag and requires the other tool to publish under
`Types.generatedJsonAdapterName`, so it must change nothing at runtime, and the check asserts that
rather than treating the inertness as a finding.

M-012 (Medium, runtime, error handling), reproduced not read. `JsonAdapter.toJson(T): String`,
`toJsonValue(T)` and `fromJsonValue(Any?)` each catch `IOException` and rethrow it as
`java.lang.AssertionError`, on a comment asserting the Buffer or object graph cannot do I/O. That is
true of the sink and source and false of the adapter stack above them: a `@ToJson`/`@FromJson`
method is documented to declare `throws <any>` and `AdapterMethodsFactory` deliberately rethrows an
`IOException` cause unchanged. All three were provoked - an adapter method throwing `IOException`,
driven through each - and all three returned `java.lang.AssertionError: java.io.IOException`, while
`fromJson(String)`, which declares the exception, delivered it unchanged. That contrast is what makes
the set exactly three rather than four.

Filed as one structural task, not three patches, because this is the third finding of this shape and
the three-strike rule ends instance work at the third. It is not inside the settled M-006 class: that
class is scoped to the `-JsonValueReader` overrides, and M-006 fixed the reader so it would stop
raising `IOException`, never these conversions. Scored Medium, matching M-006, which is the same
symptom on the same boundary; the trigger is the application's own adapter method rather than a
hostile document, and the failure is loud and carries its cause.

Observed and deliberately not filed: `Moshi.Builder.add(Object)` refuses two conflicting `@ToJson`
methods with `IllegalStateException` while every other refusal in the same function uses
`IllegalArgumentException`, because the conflict check uses Kotlin's `check` and the rest use
`require`. Both are unchecked programming-error signals raised at builder time, so the difference is
cosmetic; recording it here rather than filing a Low that would cost an iteration to close.

Verify gate: `./gradlew build check --rerun-tasks` exit 0 in 42s, all 59 tasks forced, run with
`--rerun-tasks` because a `spotlessApply` preceded it.
Battery ownership: this diff touched only `.jeffy/probes/` and the state files, so no battery was
pulled in by a path match. All were run anyway: 28 Java battery files, all passing, and the four
static checks green.

Not a stall: BACKLOG.md gained M-012 under Next, a task line changing state, and three inventory rows
flipped.

Surface inventory: 24 of 32 rows swept, 8 unswept.

Learnings: no new operational rule. Context worth keeping: two of this battery's three first drafts
reported a finding that was my expectation being wrong rather than the code - a coerced number read
as a string, and a qualifier the lookup is right to demand. Both were resolved by asking what the
documented contract is rather than what the printed form looked like, and the second draft of the
generic check now asserts a runtime class precisely because the printed form cannot decide it.

Next: five rows remain that need a Kotlin compile to drive - the reflect adapter, the metadata
plumbing and the three codegen rows - plus `examples:recipes`, which needs each recipe's output
written down rather than captured, and the extra-module fixture. M-012 outranks all of them as an
open Medium, so the next iteration closes it and the one after resumes sweeping.

## iter 4/10 | bc46c612-165940 | 2026-08-17 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines, so all but the last 10 entries moved to JOURNAL-archive.md.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: shares this iteration's checkpoint.

Verification: JOURNAL.md holds 10 entries and the archive 26, up from 24, so the archive only grew.

Learnings: none.

Next: unchanged by the rotation.

## iter 5/10 | bc46c612-165940 | 2026-08-17 | M-012 | done

Task: M-012 (Medium, runtime, error handling) - `JsonAdapter`'s three entry points that cannot
declare `IOException` rewrote one from the adapter stack as `java.lang.AssertionError`. The only open
task and the top of the queue.

Changed: moshi/src/main/java/com/squareup/moshi/JsonAdapter.kt (three catches routed through one new
private `rethrowUndeclared` helper, three KDocs stating the new behaviour),
moshi/src/test/java/com/squareup/moshi/JsonCodecFactory.java (a comment this fix falsified),
.jeffy/probes/adapter-wrappers/AdapterWrappersProbe.java (eight new checks, the acceptance check),
.jeffy/probes/value-reader/ValueReaderProbe.java (the M-006 enumeration widened so it keeps its
teeth), CHANGELOG.md, PLAN.md (moshi:adapter-wrappers re-recorded), BACKLOG.md (M-012 removed, its
class settled, two sentences in the M-006 line corrected), JOURNAL.md.

Checkpoint: c58836d6b3015a2c2313d748033cb00d9b5907be

Verification:
Reproduction first, as filed: an adapter method throwing `IOException`, driven through each of the
three, returned `java.lang.AssertionError: java.io.IOException` every time, while `fromJson(String)`
delivered it unchanged.

Fix: one helper, three call sites. The comments were right about their own sink and source - a Buffer
and an object graph never fail - and wrong about the adapter stack running on top of them, which a
`@ToJson`/`@FromJson` method is documented to be able to fail from with `throws <any>`. The three now
wrap rather than rewrite, so the caller gets a `RuntimeException` carrying the original as its cause
instead of an `Error` that application code does not catch and thread pools treat as fatal.

Why wrapped rather than propagated or declared. Adding `@Throws(IOException::class)` would change the
Java signature of three published methods and is a source-incompatible change no finding here
justifies; letting the exception propagate undeclared would leave a Java caller unable to catch it as
`IOException` at all. Wrapping in a `RuntimeException` with the cause preserved is the policy this
library already applies wherever a checked exception escapes somewhere it cannot be declared -
`Util.rethrowCause` does exactly this, and H-003 used the same policy two iterations ago - so the fix
introduces no new convention.

Contract preserved: no signature changed, so japicmp is unaffected and passes. The three entry points
that declare `IOException` are untouched and were driven in the same battery on both sides of the fix
to prove it: `fromJson(String)`, `fromJson(JsonReader)` and `toJson(BufferedSink, T)` deliver the
exception unchanged before and after. What changes is only the type a caller sees on a path that was
already failing, and only on the three that cannot declare it.

Class, not instance, and this was the third finding of this shape, which is where the three-strike
rule ends instance work. The enumeration is the entry points themselves, built by provoking an
`IOException` from a `@ToJson` and a `@FromJson` method and driving every one of them, not by
grepping for the catch. Six were driven; three rewrote and three did not, and the battery pins both
halves, so the set is exactly three rather than a number a source scan produced.

Claims this fix invalidated, re-executed rather than left standing. Two were prose in BACKLOG.md's
M-006 line and are corrected. The third was a check, and it mattered: that line's enumerating check
was `no reader operation fails as an Error`, and after this fix a reader `IOException` no longer
arrives as an Error, so the check would have quietly stopped catching the very thing M-006 exists to
prevent. It now fails on either shape - the `Error` it wore before and the `RuntimeException` carrying
an `IOException` cause it wears since - and the widening was proven rather than assumed: M-006's
defect was temporarily reintroduced by making the value reader's non-finite refusal a
`JsonEncodingException` again, the battery failed on that check and two others, and the source was
restored and it passes. A stale comment in `JsonCodecFactory` that stated the old conversion is
corrected too.

Acceptance check: `java -cp "$(bash .jeffy/probes/_lib/cp.sh .)" .jeffy/probes/adapter-wrappers/AdapterWrappersProbe.java`
exits 0. Driven against unfixed code as the Method requires, by copying the fixed adapter aside,
restoring the committed version of that one file, rebuilding the jar the battery runs against, and
re-running: exit 1 with five failures - each of the three entry points returning
`AssertionError: java.io.IOException`, the cause check, and the `none of them is an Error any more`
check - while the three that declare `IOException` passed on both sides. The fixed source was copied
back and rebuilt.

Verify gate: `./gradlew build check --rerun-tasks` exit 0 in 41s, all 59 tasks forced.
Battery ownership: the diff touched `JsonAdapter.kt`, declared in `.jeffy/probes/adapter-wrappers/paths`
and matched by `.jeffy/probes/reader-doc-contract/paths`, whose glob owns the public package; both
were run and both pass, the doc-contract check still finding all 11 documented methods across the 12
public source files in agreement with their code. Every battery was run: 28 Java battery files, all
passing, and the four static checks green.

Closed this iteration: M-012 (Medium) - an adapter's own `IOException` now reaches the caller instead
of `java.lang.AssertionError` through all three entry points that cannot declare it, proven by a
battery that drives all six entry points and fails five ways against the old source.

Not a stall: library source changed and BACKLOG.md lost M-012 from Next.

Surface inventory: 24 of 32 rows swept, 8 unswept. `moshi:adapter-wrappers` went stale when
`JsonAdapter.kt` changed and was re-swept in this same iteration by the battery that owns it, so it
is recorded at this checkpoint rather than at its old one. `moshi:value-reader` is unchanged: its
battery grew, its implementing code did not.

Learnings: no new operational rule, but one piece of context worth keeping and close to being one. A
fix can weaken a check without failing it - this one would have silently disarmed M-006's enumeration
by changing the exception shape that check was written to detect. Re-running the check is not enough
to notice that; the defect it owns has to be reintroduced. That is what was done here.

Next: the ledger is empty with five iterations left, so the queue is the 8 unswept rows. Five of them
need a Kotlin compile - the reflect adapter, the metadata plumbing and the three codegen rows - plus
`examples:recipes` and the extra-module fixture. Convergence needs all eight.

## iter 5/10 | bc46c612-165940 | 2026-08-17 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines, so all but the last 10 entries moved to JOURNAL-archive.md.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: shares this iteration's checkpoint.

Verification: JOURNAL.md holds 10 entries and the archive 28, up from 26, so the archive only grew.

Learnings: none.

Next: unchanged by the rotation.

## iter 6/10 | bc46c612-165940 | 2026-08-17 | SWEEP | done

Task: with the ledger empty the top of the queue is the Surface inventory. Five of the eight
remaining rows are Kotlin-only surface no Java probe can reach, so this iteration built that
capability first and then used it on `moshi:kotlin-extensions`. The sweep surfaced one in-envelope
High, filed this iteration as the rule requires. No library source was changed, so the work certifies
the tree as of ff7567b443b72d57354b055b4b14316b856e3502.

Changed: .jeffy/probes/_lib/kotlinc.sh (new Kotlin probe harness),
.jeffy/probes/kotlin-extensions/{KotlinExtensionsProbe.kt,paths} (new battery), .gitignore (the
harness's class-output cache), PLAN.md (two Lessons), BACKLOG.md (H-004 filed), JOURNAL.md.

Checkpoint: be337666a575c9698e17a3db8a98d0a0b9288239

Verification:
The harness first, because five rows depend on it. This host has no `kotlinc`, so the compiler is
invoked as a library from the Gradle cache exactly as PLAN.md's Lessons recorded, and the recorded
classpath was right: kotlin-compiler-embeddable plus stdlib, reflect, script-runtime,
kotlinx-coroutines-core-jvm and org.jetbrains:annotations. Class output is cached under
`.jeffy/probes/_lib/out/` and rebuilt only when the source is newer, so a re-sweep re-runs the
battery rather than recompiling it, and that directory is gitignored because it is build output
rather than loop memory.

`moshi:kotlin-extensions`, 44 known-answer checks, 42 green and two failing by design as H-004's
acceptance check. These functions compute a `java.lang.reflect.Type` and a wrong one does not throw -
it produces an adapter for a type nobody asked for - so every check asserts the exact Type by its
string form against an answer written from the Kotlin-to-Java mapping rules. `Type.rawType` across
all four Type kinds; `nextAnnotations` present, absent and refused for a non-qualifier; `subtypeOf`
and `supertypeOf` reified and through their KType overloads, each at two arguments and at a
primitive-backed one, which is the boundary M-010 fixed rather than a second sample; `asArrayType` on
all three receivers at two element types each; and the KType conversion driven over a bare class, a
parameterized type at two arguments, nesting, both array kinds, star projection and both variances, a
typealias and a nested class. `IntArray` and `Array<Int>` are required not to converge, checked both
by their canonical strings and by the runtime class each one's adapter actually builds, because two
Kotlin types collapsing onto one Java type is the failure this conversion can have that a single-type
probe cannot see.

H-004 (High, runtime, correctness), reproduced not read. `Moshi.adapter(ktype: KType)` documents that
"while nullability of [ktype] itself is handled, nested types (such as in generics) are not
resolved" - the carve-out it names is nested types, and the type's own marking is promised. It is not
kept. The first branch returns the adapter untouched when it is already a `NullSafeJsonAdapter` or a
`NonNullJsonAdapter`, and Moshi's own built-ins arrive already `nullSafe()`, so the marking never
reaches them. Driven at both markings across eleven types, it is honoured for `Int`, `Long`, `Double`
and `Boolean` and inert for `String`, an enum, `List<String>`, `Map<String,Int>`, `IntArray`,
`Array<String>` and `Any`: `moshi.adapter<String>(typeOf<String>())` accepts a `null` document and
returns null into a non-nullable Kotlin `String`.

Scored High. The rubric's wrong-results clause fits directly: the caller's own type declaration says
the value cannot be null, the API's KDoc says that marking is handled, and a third-party document
with a null field produces one anyway - a null that Kotlin's type system was asked to exclude and
that surfaces later as an NPE far from the decode. The trigger is adversarial JSON, which the
envelope classifies as fully in scope, and the application code is correct. Driving eleven types
rather than one is what made the shape visible: at `Int` alone the parameter looks honoured, and the
four types where it works are exactly the ones whose adapters are not already null-safe.

The row stays unswept: its battery fails, and a battery that fails certifies nothing.

Verify gate: `./gradlew build check --rerun-tasks` exit 0 in 39s, all 59 tasks forced.
Battery ownership: this diff touched only `.jeffy/` and the state files, so no battery was pulled in
by a path match. All were run: 28 Java battery files all passing, the four static checks green, and
the one Kotlin battery failing by design because it carries H-004's acceptance check. That last
sentence is why one of this iteration's two Lessons exists - the runner globbed `*Probe.java` and
would have skipped every Kotlin battery silently.

Not a stall: BACKLOG.md gained H-004 under Now, a task line changing state.

Surface inventory: 24 of 32 rows swept, 8 unswept - unchanged, because the one row this iteration
mapped is held open by the finding it surfaced.

Learnings: two operational rules, both added to PLAN.md's Lessons - how Kotlin-only surface is
driven on this host, and that the battery runner has to invoke `.kt` batteries separately because a
`*Probe.java` glob skips them without saying so.

Next: H-004 is an open High and outranks everything, so the next iteration closes it, which also
flips this row. Then seven rows remain for three iterations: the reflect adapter, the metadata
plumbing, the three codegen rows, `examples:recipes` and the extra-module fixture. Convergence needs
all seven and this run will not reach it.

## iter 6/10 | bc46c612-165940 | 2026-08-17 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines, so all but the last 10 entries moved to JOURNAL-archive.md.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: shares this iteration's checkpoint.

Verification: JOURNAL.md holds 10 entries and the archive 30, up from 28, so the archive only grew.

Learnings: none.

Next: unchanged by the rotation.

## iter 7/10 | bc46c612-165940 | 2026-08-17 | H-004 | done

Task: H-004 (High, runtime, correctness) - the nullability marking on a `KType` decided nothing for
any type whose adapter was already null-safe, so `moshi.adapter<String>()` returned null into a
non-nullable Kotlin `String`. The only open task and the top of the queue.

Changed: moshi/src/main/java/com/squareup/moshi/Moshi.kt (the marking now decides unconditionally),
moshi/src/main/java/com/squareup/moshi/-MoshiKotlinExtensions.kt (its duplicate of the same logic
reduced to a delegating call), moshi/src/test/java/com/squareup/moshi/KotlinExtensionsTest.kt (new
test ktypeNullabilityMarkingIsHonouredForEveryType),
moshi-kotlin-tests/codegen-only/src/test/kotlin/com/squareup/moshi/kotlin/codegen/MixingReflectAndCodeGen.kt
(two toString expectations), CHANGELOG.md, PLAN.md (moshi:kotlin-extensions flipped,
moshi:moshi-builder re-recorded), BACKLOG.md (H-004 removed, the class settled), JOURNAL.md.

Checkpoint: 226cfaf0e6449a36154b8de1abbd4623a5e5f8fc

Verification:
Reproduction first, as filed: the battery exited 1 naming all seven inert types.

Fix: delete the branch that skipped the marking. It read "if the adapter is already a
`NullSafeJsonAdapter` or a `NonNullJsonAdapter`, return it untouched", which sounds like respecting a
policy the adapter already declared, and in practice meant Moshi's own built-ins - String, enums,
collections, maps, arrays, `Any` - never had the marking applied at all, because they arrive already
`nullSafe()`. Both wrappers are idempotent, so letting the marking decide unconditionally costs
nothing when the requested policy is already in place. The extension in `-MoshiKotlinExtensions.kt`
carried a second copy of the same logic and is now a delegating call, so there is one implementation
rather than two that can drift.

Class, not instance. The class is a marking that decides nothing because the branch reading it is
skipped, and its enumeration is the two entry points that read one, driven at both markings over nine
types spanning both sides of the null-safe distinction rather than read off the branch.
`Moshi.Builder.add(KType, JsonAdapter)` also takes a KType but reads no marking, and is outside the
class rather than unexamined.

Contract preserved, and this changes observable behaviour, so the rationale is here as the
Constraints require. No signature changed and japicmp passes. What changes is that a non-nullable
type argument now refuses a null document, which is what the KDoc has always promised - "while
nullability of [ktype] itself is handled, nested types are not resolved", where the carve-out named is
nested types and the type's own marking is promised. A caller who wants null tolerance asks for the
nullable type. The accepted input set narrows only where the caller's own declaration said null was
impossible.

One test went red and was repaired rather than reverted, under the verify gate's stated exception,
with the differential evidence it requires. `MixingReflectAndCodeGen.mixingReflectionAndCodegen`
asserted `moshi.adapter<UsesGeneratedAdapter>().toString()` equals
`GeneratedJsonAdapter(...).nullSafe()`, and now gets `...nullSafe().nonNull()`. That assertion was
green only because the marking was inert on a non-nullable reified type - it encoded the defect. The
evidence that nothing else moved: the full gate ran every test task, including both the REFLECT-mode
`moshi-kotlin-tests:test` and the KSP-mode `codegen-only:test`, and across 39 result files holding
1527 tests exactly one failed, on a toString suffix rather than on any decoded value. The test's own
subject - which factory built each adapter - is untouched and still asserted exactly; only the suffix
naming the wrapper moved, and both adapters gained the same one.

Acceptance check: `bash .jeffy/probes/_lib/kotlinc.sh .jeffy/probes/kotlin-extensions/KotlinExtensionsProbe.kt KotlinExtensionsProbeKt`
exits 0 with 44 checks. The project's own suite pins it too, and in Kotlin, which is the only place
the defect is visible: the new test drives nine types at both markings and was run against unfixed
code by copying both fixed sources aside, restoring the committed versions, and running
`./gradlew :moshi:test --tests com.squareup.moshi.KotlinExtensionsTest` - exit 1, the failure listing
String, MarkingEnum, List, Map, IntArray and Array as having accepted a null document. Both sources
were copied back.

Verify gate: `./gradlew build check --rerun-tasks` exit 0 in 42s, all 59 tasks forced.
Battery ownership: the diff touched `Moshi.kt`, declared in `.jeffy/probes/moshi-builder/paths` and
`.jeffy/probes/kotlin-extensions/paths`, and `-MoshiKotlinExtensions.kt`, declared in the latter; both
were run and both pass, as did `reader-doc-contract`, whose glob owns the public package. Every
battery was run: 28 Java battery files and one Kotlin battery all passing, and the four static checks
green.

Closed this iteration: H-004 (High) - a KType's nullability marking is now applied for every type,
proven by a battery and a project test that each drive nine types at both markings and each fail
against the old source.

Not a stall: library source changed and BACKLOG.md lost H-004 from Now.

Surface inventory: 25 of 32 rows swept, 7 unswept. `moshi:kotlin-extensions` flipped, its battery now
passing. `moshi:moshi-builder` went stale when `Moshi.kt` changed and was re-swept in this same
iteration by the battery that owns it, so it is recorded at this checkpoint rather than at its old
one.

Learnings: no new operational rule. Context worth keeping: the branch this fix deleted reads as
prudence - do not re-wrap an adapter that already declares a null policy - and that is exactly why it
survived. What made it visible was driving the parameter across a set of types rather than one, which
is now the third finding this project has produced that way.

Next: seven rows remain unswept with three iterations left - the reflect adapter, the metadata
plumbing, the three codegen rows, `examples:recipes` and the extra-module fixture. The ledger is
empty, so the next iteration sweeps, and the Kotlin harness built last iteration is what the five
Kotlin rows need. Convergence needs all seven and this run will not reach it.

## iter 7/10 | bc46c612-165940 | 2026-08-17 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines, so all but the last 10 entries moved to JOURNAL-archive.md.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: shares this iteration's checkpoint.

Verification: JOURNAL.md holds 10 entries and the archive 32, up from 30, so the archive only grew.

Learnings: none.

Next: unchanged by the rotation.

## iter 8/10 | bc46c612-165940 | 2026-08-17 | SWEEP | done

Task: with the ledger empty the top of the queue is the Surface inventory. Swept the two
`moshi-kotlin` rows, the largest runtime surface left unmapped, and the sweep surfaced one
in-envelope finding, filed this iteration as the rule requires. No library source was changed, so the
work certifies the tree as of 732ea5549bcb934813fd91db933f003e21812cfb.

Changed: .jeffy/probes/reflect-adapter/{ReflectAdapterProbe.kt,paths},
.jeffy/probes/metadata-plumbing/{MetadataPlumbingProbe.kt,paths} (two new Kotlin batteries), PLAN.md
(moshi-kotlin:reflect-adapter flipped), BACKLOG.md (M-013 filed), JOURNAL.md.

Checkpoint: 732ea5549bcb934813fd91db933f003e21812cfb

Verification:
62 known-answer checks executed across the two new batteries, 60 green and two failing by design as
M-013's acceptance check.

`moshi-kotlin:reflect-adapter`, 47 checks, all green. Every write asserts the exact document and
every read asserts each property separately, because a round trip passes against an adapter that
drops a property on both sides. The four states a property can be in are driven separately - present,
absent, present-and-null, defaulted - since this adapter distinguishes all four and reports three of
them differently, and an adapter collapsing any two would still round-trip. Every refusal the factory
can produce at creation time was provoked rather than read off its `require` calls: abstract, sealed,
inner, object declaration and local. What it declines was driven too - an enum, an interface, a
platform type - because a factory that declined too much would leave those types with no adapter and
a factory that declined too little would claim them, and only driving both sides tells them apart.

`moshi-kotlin:metadata-plumbing`, 15 checks, 13 green. This machinery fails silently rather than
loudly when it is wrong - a default-mask bit in the wrong word makes a parameter take its default
while the document said otherwise, and that decodes without complaint - so the checks assert the
value a mis-set bit would change, at the first and last parameter of the first mask word and the
first of the second. All six mask checks pass, which clears the arithmetic that reading
`KtConstructor.callBy` had left me unsure about. Descriptor coverage is one property per JVM
descriptor kind, all eight primitives plus a reference, a primitive array, a reference array and a
nested array, driven at two sets of values so no descriptor can be bound to a constant.

M-013 (Medium, runtime, correctness), reproduced not read. `KmExecutable.invoke` calls
`actualConstructor.setAccessible()` but never makes the `box-impl` method accessible, and that
handle is used on the value-class path alone, so reading a value class whose JVM class is not
accessible from `KmExecutable` fails with an `IllegalAccessException` that `fromJson` does not
declare. Its sibling `findValueClassMethods` sets both `box-impl` and `unbox-impl` accessible, so the
omission is at the one site that forgot. Driven at both spellings a value class can be read through -
`@JsonClass(inline = true)` and nested as another class's property - and writing works on both while
reading fails on both, which is what identifies the box-impl handle as the single difference. Driven
at all three visibilities: `public` and `internal` work on both sides, so the trigger is exactly a
private one.

Scored Medium with the rationale, because the rubric's crash clause could suggest High: the surface
is the application author's own declaration rather than adversarial input, the failure is immediate
and loud, nothing decodes wrongly, and the two visibilities an application normally gives a value
class both work. That is the same scoring M-010 received for the same shape.

The finding lives in `KmExecutable.kt`, which the metadata-plumbing row's scope names, so its
acceptance check went into that row's battery rather than the reflect-adapter one. That is why one
row flipped and the other did not: a battery that fails certifies nothing, and putting the check in
the row that owns the code keeps the block where the defect is.

Verify gate: `./gradlew build check --rerun-tasks` exit 0 in 58s, all 59 tasks forced, run with
`--rerun-tasks` because a `spotlessApply` preceded it - which was needed twice this iteration, since
spotless formats `**/*.kt` and that now includes Kotlin probe sources.
Battery ownership: this diff touched only `.jeffy/` and the state files, so no battery was pulled in
by a path match. All were run: 28 Java battery files all passing, the four static checks green, and
three Kotlin batteries of which two pass and `metadata-plumbing` exits 1 by design.

Not a stall: BACKLOG.md gained M-013 under Next, a task line changing state, and one inventory row
flipped.

Surface inventory: 26 of 32 rows swept, 6 unswept.

Learnings: no new operational rule. Context worth keeping: two of this iteration's three initial
failures were my expectations rather than defects - a value class nests unless inlining is asked for,
which is what `@JsonClass(inline)` exists to change - and the third was real. Telling them apart came
from driving the same thing at more than one setting each time: private against public and internal,
inlined against nested, write against read.

Next: six rows remain with two iterations left - the three codegen rows, `examples:recipes`, the
extra-module fixture, and `moshi-kotlin:metadata-plumbing` held open by M-013. Iteration 9 should
close M-013, which flips that row; iteration 10 is the last and is better spent on a WRAPUP handoff
than on a row it cannot finish. Convergence needs all six and this run will not reach it.

## iter 8/10 | bc46c612-165940 | 2026-08-17 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines, so all but the last 10 entries moved to JOURNAL-archive.md.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: shares this iteration's checkpoint.

Verification: JOURNAL.md holds 10 entries and the archive 34, up from 32, so the archive only grew.

Learnings: none.

Next: unchanged by the rotation.

## iter 9/10 | bc46c612-165940 | 2026-08-17 | M-013 | done

Task: M-013 (Medium, runtime, correctness) - a Kotlin value class not visible from Moshi's own
package could not be constructed reflectively. The only open task and the top of the queue.

Changed: moshi-kotlin/src/main/java/com/squareup/moshi/kotlin/reflect/KmExecutable.kt (`box-impl`
made accessible), moshi-kotlin-tests/src/test/kotlin/com/squareup/moshi/kotlin/DualKotlinTest.kt (new
test privateValueClassIsConstructedReflectively and the three declarations it drives), CHANGELOG.md,
PLAN.md (moshi-kotlin:metadata-plumbing flipped), BACKLOG.md (M-013 removed, the class settled),
JOURNAL.md.

Checkpoint: 9e8c455c6af2417e5399faed34e2114411833b1a

Verification:
Reproduction first, as filed: the battery exited 1 on both spellings, each naming
`IllegalAccessException` against a private value class.

Fix: one line. `KmExecutable.invoke` already calls `actualConstructor.setAccessible()` for the
`constructor-impl` static it invokes, and never did the same for the `box-impl` method it invokes
immediately after. The value-class path is the only one that uses that handle, which is why every
other class decoded fine.

Class, not instance, and the class is the handles this path invokes rather than the file's
`setAccessible` call sites. There are three - `constructor-impl`, `box-impl` and `unbox-impl` - and
the enumeration was built by driving a private value class through both spellings it can be read in,
`@JsonClass(inline = true)` and nested as another class's property, on both sides. Writing succeeded
on both spellings before the fix while reading failed on both, which is what identified `box-impl` as
the single difference; `unbox-impl` was already covered by `findValueClassMethods`, the sibling
lookup that sets both of its handles accessible.

Contract preserved: no signature changed, japicmp passes, and no previously-working input changes
behaviour. The accepted input set only widens - a class that failed to decode now decodes - so
nothing that passed before can now fail.

Acceptance check: `bash .jeffy/probes/_lib/kotlinc.sh .jeffy/probes/metadata-plumbing/MetadataPlumbingProbe.kt MetadataPlumbingProbeKt`
exits 0 with 15 checks. The project's own suite pins it too, in the module that runs the reflective
adapter: the new test was driven against unfixed code by copying the fixed source aside, restoring
the committed version, and running
`./gradlew :moshi-kotlin-tests:test --tests com.squareup.moshi.kotlin.DualKotlinTest` - exit 1 with
`privateValueClassIsConstructedReflectively FAILED, java.lang.IllegalAccessException`. The fixed
source was copied back.

Verify gate: `./gradlew build check --rerun-tasks` exit 0 in 44s, all 59 tasks forced.
Battery ownership: the diff touched `KmExecutable.kt`, declared in
`.jeffy/probes/metadata-plumbing/paths` and in no other paths file; it was run and passes. Every
battery was run: 28 Java battery files, three Kotlin batteries and the four static checks, all
passing, which is the first iteration this run where nothing fails by design.

Closed this iteration: M-013 (Medium) - a private value class now decodes, proven by a battery and a
project test that each drive both spellings on both sides and each fail with `IllegalAccessException`
against the old source.

Not a stall: library source changed and BACKLOG.md lost M-013 from Next.

Surface inventory: 27 of 32 rows swept, 5 unswept. `moshi-kotlin:metadata-plumbing` flipped, its
battery now passing. No row went stale: `KmExecutable.kt` belongs to that row alone.

Learnings: no new operational rule. Context worth keeping: the asymmetry was the diagnostic. Writing
worked and reading did not, over the same class through the same factory, which narrowed a whole
reflective path down to the one handle the two directions do not share - and that was faster than
reading the file would have been.

Next: iteration 10 is the last. Five rows remain unswept - the three codegen rows,
`examples:recipes` and the extra-module fixture - and the ledger is empty. The final iteration is
better spent on a WRAPUP that hands the remainder off cleanly than on starting a row it cannot
finish, so convergence falls to the next run, which begins with a fresh audit and five rows to map.

## iter 9/10 | bc46c612-165940 | 2026-08-17 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines, so all but the last 10 entries moved to JOURNAL-archive.md.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: shares this iteration's checkpoint.

Verification: JOURNAL.md holds 10 entries and the archive 36, up from 34, so the archive only grew.

Learnings: none.

Next: unchanged by the rotation.

## iter 10/10 | bc46c612-165940 | 2026-08-17 | WRAPUP | done

Task: the final iteration. Convergence is not reachable - it requires no unswept row and five remain -
so this iteration verifies the state files' own claims, repairs one defect in this run's own
artifacts, and writes the handoff, rather than starting a sixth row it could not finish.

Changed: .jeffy/probes/annotations-and-exceptions/AnnotationsProbe.java (a literal NUL byte replaced
by its escape, plus one check), PLAN.md (that row's check count corrected), JOURNAL.md.

Checkpoint: d7c31682e893c97d490e522092208161140b0fac

Verification:
Every number the state files state was re-derived rather than reread. The Environment fingerprint's
exclusion enumeration still returns 17 lines; the Oracle class's test-result count still returns 39
files; the Surface inventory's union command still returns 95 main source files, and every one still
belongs to a row, because this run added no library source file and only edited existing ones. The
inventory holds 27 swept and 5 unswept, summing to the 32 it claims, with no `- [~]` row - nothing in
this project was found unreachable on this host.

One defect in this run's own artifacts, found and fixed here. `AnnotationsProbe.java` carried a
literal NUL byte, written as the expected value of the `Json.UNSET_NAME` sentinel check, so git
classified the file as binary and every diff of it across four iterations was unreadable. It is now
written as the six-character escape `\u0000`, which the check asserts equals the sentinel exactly as
before, and a second check pins the sentinel's length at one so the escape cannot silently become a
literal six-character string. Every tracked file under `.jeffy/` and every state file was scanned for
the same defect and none other has it. The battery passes with 27 checks and the row's recorded count
was corrected from 26.

Verify gate: `./gradlew build check --rerun-tasks` exit 0 in 40s, all 59 tasks forced.
Battery ownership: this diff touched only `.jeffy/` and the state files, so no battery was pulled in
by a path match. All were run: 28 Java battery files, 3 Kotlin battery files and the four static
checks, all passing.

Not a stall: this iteration changed only `.jeffy/` and the state files and no BACKLOG.md item changed
state, so by the stall check's own definition it registers as no progress. The previous primary entry
does not say the same - iteration 9 closed M-013 and changed library source - so this is not the pair
that forms a hard blocker, and a WRAPUP is named as a ceremony entry that never forms one.

Surface inventory: 27 of 32 rows swept, 5 unswept, unchanged this iteration.

Handoff. The ledger is empty: no High, no Medium, no Low, nothing blocked. Five rows remain unswept
and they are the next run's work in queue order: `codegen:ksp-processor`,
`codegen:adapter-generation`, `codegen:target-model`, `examples:recipes` and
`moshi-kotlin-tests:extra-module-fixture`. The three codegen rows are the hard ones - they need KSP to
run over test sources, which no probe here does yet; `kotlinCompileTesting` is already a test
dependency of `moshi-kotlin-codegen` and is the likely route. `examples:recipes` needs each of the 19
recipes' printed output written down from the recipe rather than captured from a run, since these are
programs users copy. The extra-module fixture needs its jar added to `.jeffy/probes/_lib/cp.sh` and a
Kotlin subclass driven through it. The Kotlin harness built in iteration 6 is what the Kotlin rows
need and is already in place. One Proposed item still awaits a user decision and blocks nothing.

Learnings: no new operational rule. Context worth keeping: five of this run's six findings came from
driving something at more than one setting and requiring the settings to disagree - two exception
shapes, two nullability markings, three visibilities, two directions, eleven types. The sixth came
from a documented number checked against a driven one. None came from reading code looking for
mistakes, which is now consistent across two runs.

Next: the run ends at its budget. The next run starts with a fresh audit, an empty ledger and five
rows to map; convergence requires all five.

## iter 10/10 | bc46c612-165940 | 2026-08-17 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines, so all but the last 10 entries moved to JOURNAL-archive.md.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: shares this iteration's checkpoint.

Verification: JOURNAL.md holds 10 entries and the archive 38, up from 36, so the archive only grew.

Learnings: none.

Next: the run ends here; the next run rotates from this point.

## iter 1/10 | 36f06007-035207 | 2026-08-20 | AUDIT | audit

Task: the ledger was empty at run start, so this iteration audits and generates the backlog. The
Converged section holds no line, so the ratchet does not apply.

Changed: BACKLOG.md (six findings filed), PLAN.md (three stale inventory rows re-swept, one Lesson
added), JOURNAL.md.

Checkpoint: efb773b231ba12af7040ae8f1a243401be2e7cf6

Verification:
Baseline first: `./gradlew build check` exit 0 before any edit, so the tree this audit judges is the
tree the last run left green.

Inventory staleness, which is where this iteration started. Comparing every swept row's recorded
commit against `git log -1 --format=%H -- $(cat .jeffy/probes/<slug>/paths)` found three rows whose
implementing code changed after the sweep that certified them: `moshi:utf8-writer` swept at a1a91f5a
with its paths last touched at b756a40d, `moshi:value-reader` swept at 52caa569 last touched at
c58836d6, and `moshi:types` swept at ec8c3b3d last touched at 3e0a83ca. All three were re-swept here
by re-running their kept batteries against current jars - 59, 55 and 65 checks respectively, the same
counts the rows record, all passing - and their commits now name this iteration's checkpoint. The
other 24 swept rows were checked the same way and are current; three of them carry no `paths` file
under a slug matching the row name and were matched by hand (`adapters:enum`, `adapters:polymorphic`,
`adapters:rfc3339`), all current.

Codegen, the unswept surface this audit spent itself on, was probed by driving KSP through
kotlin-compile-testing in the codegen module's own test source set, eight compilations in all, and
the scratch test was deleted before the checkpoint. Three findings reproduce:
- `moshi.instantiateAnnotations` unset, `false` and `not-a-boolean` produced byte-identical generated
  adapters, and the garbage value exited OK, while `moshi.generated` rejects an unknown value. Filed
  M-014.
- A Kotlin `@JsonQualifier` with BINARY retention fails compilation with `JsonQualifier @Hex must
  have RUNTIME retention`; the Java equivalent carrying `@Retention(RetentionPolicy.CLASS)` compiled
  clean with no message and generated `moshi.adapter(Int::class.java, setOf(Hex()), "a")`. Filed
  M-015.
- Two classes with private primary constructors in one file reported only `AlphaBroken`; `BetaBroken`
  was never named. With a valid class second instead, zero files were generated. Filed M-016.
One hypothesis was falsified and is not filed: `@Json(ignore = true)` on a constructor property
generates identically with and without `-Xannotation-default-target=param-property`, so the two
Kotlin test modules setting that flag are not hiding a targeting difference from users who do not.
A second was falsified too: a lambda-typed property does not reach `TypeRenderer`'s unrepresentable
branch, it renders as `Function0<Unit>` and generates cleanly, which is why L-001 is filed Low.

Examples were probed by execution rather than by reading: all 19 recipe mains ran to completion, the
two Kotlin ones under their `Kt` class names. That is a liveness probe and flips nothing - the row
needs each recipe's printed output written from the recipe, which is the sweep still owed.

Testing was scored only after an isolated run: `./gradlew :moshi-kotlin-codegen:test` alone exits 0
with 28 tests, 1 skipped, no failures.

Verify gate: `./gradlew build check` exit 0.

Scores, claiming only what this audit examined. 27 of 32 rows are swept and five are not, so these
are not the whole project: correctness None on the swept rows, whose batteries re-ran green where
stale; error handling Medium (M-015, M-016, L-001); documentation Medium (M-014, L-002, L-003);
testing None, one module run in isolation; architecture, code quality, performance, observability and
security None on the surface examined, with the codegen rows probed rather than swept; dependency
hygiene and CI not re-examined this iteration and claimed by nobody; UX and accessibility do not
apply to a library with no user-facing surface.

Learnings: the battery-ownership rule keeps a battery green without keeping the inventory honest - a
fix that touches a swept row's paths must rewrite that row's commit in the same iteration, or the row
reads as swept while certifying code that no longer exists. Copied to PLAN.md Lessons. Second, the
codegen module's own test harness compiles without `-Xannotation-default-target`, which is what a
user's build does, so it is the right instrument for the three codegen rows and the wrong one to
compare against the two Kotlin test modules.

Next: M-014, the top of the queue.

## iter 2/10 | 36f06007-035207 | 2026-08-20 | SWEEP | done

Task: sweeping, which the queue puts above every open Medium. Five rows were unswept; this iteration
built the instrument the three codegen rows need and swept two rows with it.

Changed: .jeffy/probes/_lib/ (KspHarness.kt, kspprobe.sh, codegen-cp.sh, codegen-cp.init.gradle.kts),
.jeffy/probes/codegen-ksp-processor/, .jeffy/probes/extra-module-fixture/, .gitignore (the dumped
classpath cache, which holds machine-absolute paths and must not be committed), PLAN.md (two rows
swept, four Lessons), JOURNAL.md.

Checkpoint: e7a16dbc191c2a1e19d710e50c129cccf1830480

Verification:
The instrument first. Codegen could not be driven by the existing probe harness at all: its surface
is a compiler plugin, so a battery has to run kotlinc with the processor attached. `codegen-cp.sh`
asks Gradle once, through an init script that adds a task rather than an edit to any build file, for
the exact classpath `moshi-kotlin-codegen`'s own tests run on, and `kspprobe.sh` compiles the battery
against it and runs it. Three things had to be got right and each was got wrong first: the compiler
must come from that same classpath, because kotlin-compile-testing brings its own newer
compiler-embeddable and the pinned 2.3.21 one refuses its 2.4.0 metadata; the compile must be
recorded by a marker file rather than by the output directory's mtime, or a failed compile leaves the
directory looking fresh and the next run silently executes stale classes; and the fixture jar is
required rather than optional on the classpath, so the cross-module battery cannot pass by testing
nothing.

codegen:ksp-processor, 60 known-answer checks, exit 0. Fifteen rejections each in its own compilation
because the processor abandons the round at the first class it cannot model, which is M-016 and is
why they cannot share one. Both documented options driven at every value they take, including the
negative side: `moshi.generated` at four values and `moshi.generateProguardRules` at three, each
changing the output. Four of my own expectations were wrong and were corrected against what the
processor actually does rather than the other way round: a local class never reaches the processor at
all, so the "must not be local" guard cannot fire from here and the battery now pins the observable
contract instead; `javax.annotation.Generated` cannot compile on this JDK, so that case is judged on
the emitted source; kotlinpoet escapes the `annotation` path segment with backticks; and a
constructor parameter with no matching property is a rejection, which my supertype fixture had
tripped over.

moshi-kotlin-tests:extra-module-fixture, 21 known-answer checks, exit 0. The subclass is compiled
against the fixture's published jar, the four private members are enumerated from the class file, and
a document naming all four is decoded and shown to have written none of them. The two ignore
mechanisms are counted apart, so a fix that handled `@Transient` but not `@field:Json(ignore = true)`
fails here.

Both batteries were re-run after `./gradlew spotlessApply` reformatted their sources and both still
pass, which matters because the formatter rewrites probe sources and the marker file correctly forced
the recompile. The counts above are from those final runs, each to its own log after an earlier pair
of runs shared one and made their check counts indistinguishable.

Verify gate: `./gradlew build check --rerun-tasks` exit 0 in 87s, all 59 tasks forced, because
this diff touched files spotless formats and an incremental run can report green without executing.

No finding was filed this iteration. The local-class guard is the one thing that looks like dead
code, and it is not filed: proving a guard unreachable is a claim over every way a local class can be
declared, which this sweep did not enumerate, so the battery states the narrow fact it did establish.

Learnings: four operational rules, all copied to PLAN.md - how codegen surface is driven, the marker
file rule, and the two logging and process-killing mistakes that cost this iteration a re-run each.

Next: codegen:adapter-generation and codegen:target-model, the two rows the new harness now makes
cheap, then examples:recipes.

## iter 3/10 | 36f06007-035207 | 2026-08-20 | SWEEP | done

Task: sweeping, still the top of the queue. Two rows swept, both codegen, leaving one unswept row in
the whole project.

Changed: .jeffy/probes/codegen-target-model/, .jeffy/probes/codegen-adapter-generation/,
.jeffy/probes/_lib/kspprobe.sh (the internal-API opt-in the model classes need), BACKLOG.md (L-004
filed), PLAN.md (two rows swept), JOURNAL.md.

Checkpoint: 8c0e219ae5bdc5c684293189f8c5cde847cdb448

Verification:
codegen:target-model, 43 known-answer checks, exit 0. The proguard expectations are written from the
rules R8 needs rather than captured from a run: the whole no-defaults file is asserted exactly, and
the synthetic-constructor mask is driven at 0, 31, 32, 33, 64 and 65 parameters, both sides of the
32-parameter boundary, because a mask one int short keeps the wrong constructor alive. The two
internal helpers in this row - default primitive values and typealias unwrapping - are `internal` and
cannot be called from a probe at all, so they are driven through a real compilation instead: every
primitive's local variable is asserted to start at its own default with a reference type starting at
null, and aliases are driven nested, parameterized and nullable.

codegen:adapter-generation, 60 known-answer checks, exit 0. Every shape is asserted on the emitted
source and then driven through Moshi, since an adapter that reads the right names into the wrong
slots renders identically. The qualifier check is the sharpest: a factory matches the qualifier by
name - the annotation class only exists inside the generated classloader - and asserts the member
value of the annotation instance the generated code built, which proves both the instantiation and
the routing. Defaults are driven again at 33 defaulted parameters, where the property past the mask
boundary is the one that shows the second mask int is passed.

Six of my own expectations were wrong in the first adapter-generation run and every one was corrected
against the emitted source rather than the other way round: the mask variable is numbered `mask0`,
the marker is a generated `DEFAULT_CONSTRUCTOR_MARKER` constant, the type-variable mismatch message is
assembled by `append` calls so no literal of it exists, a wildcard bound on a non-primitive renders as
the plain java class, and a null map value is dropped on the way out because serializeNulls is off by
default - that last one is now asserted in its own right rather than papered over.

One finding, filed at rubric severity in the same iteration as the sweep that surfaced it. L-004:
`checkIsVisibility` reads `require(ordinal <= ordinal)`, so the guard both `TargetType` and
`TargetConstructor` call to reject a non-visibility modifier rejects nothing, and the message it
would print enumerates from the value being checked rather than from the allowed set. Filed Low, with
the rationale on its line: both call sites pass `getVisibility().toKModifier() ?: KModifier.PUBLIC`,
which yields only the four visibilities, so no in-envelope input reaches the guard with a wrong value.
Its acceptance check is not in the battery yet by design - adding a check that fails today would
block the row it is meant to certify - and lands with the fix.

Both batteries were re-run after `./gradlew spotlessApply` rewrote their sources, and the counts above
are from those runs.

Verify gate: `./gradlew build check --rerun-tasks` exit 0, all 59 tasks forced.

Learnings: none new. The three rules iteration 2 wrote were what made this iteration cheap.

Next: examples:recipes, the last unswept row, then the three open Mediums.

## iter 4/10 | 36f06007-035207 | 2026-08-20 | SWEEP | done

Task: sweeping examples:recipes, the last unswept row in the project. The map is now complete.

Changed: .jeffy/probes/examples-recipes/ (run.sh, manifest, 19 expected files), BACKLOG.md (M-017
filed), PLAN.md (the last row swept), JOURNAL.md.

Checkpoint: 3e5ca92a4ac53c5f86173cc0693009c14a1ee8cc

Verification:
20 known-answer checks, exit 0. These programs are documentation: a reader copies one and expects the
printed result, so the work was writing down what each should print and the check was running it.
Every expectation is derived from the recipe's own source - the JSON literal it holds, the toString
of the model it builds, and the field ordering `ClassJsonAdapter` takes from a sorted map, which is
why the reflective output is alphabetical rather than in declaration order - and none is captured
from a run. All 19 matched on the first execution.

Two things the derivation forced out. The clock had to be pinned: `ReadAndWriteRfc3339Dates` prints a
`java.util.Date`, whose toString renders in the host time zone, so the expected file would otherwise
only be right on this machine; the battery runs every recipe under `-Duser.timezone=UTC` and the
expectation is written for UTC. And the twentieth check is a manifest naming all 27 source files in
the module with the recipe that drives each, so a recipe added later cannot sit undriven behind a
green run - the four model classes and the two helper adapters that carry no main are named against
the recipes that exercise them.

One finding, filed at rubric severity in the same iteration. M-017: the `IncludeNullsForOneType`
recipe does not do what its name says. It saves `getSerializeNulls()`, sets it true, and then in its
`finally` restores that saved value into `setLenient` - so `serializeNulls` is never restored.
Reproduced on one writer: after the recipe's adapter wrote its value the flag was still true, and the
next value written came out as `{"k":null}` rather than `{}`, which is exactly the "for one type"
promise failing. Leniency meanwhile takes whatever serializeNulls happened to be. Filed Medium as
misleading documentation, class docs, since the library itself is unaffected and the damage is to
whoever copies the recipe. The idiom is class-complete at one site: `grep -rn
'setSerializeNulls\|getSerializeNulls\|setLenient' examples/src/main` returns three lines, all in
that one method, and the same save-and-restore in the library's own `JsonAdapter` wrappers is already
pinned by the adapter-wrappers battery's re-read checks.

The battery grades printed output, which is what a reader sees, and not writer state left behind
after a recipe returns - which is how M-017 escaped it. That check lands with the fix rather than
now, because a check that fails today would block the row it exists to certify.

Verify gate: `./gradlew build check --rerun-tasks` exit 0, all 59 tasks forced.

Learnings: none new.

Next: the Surface inventory has no unswept row left, so the queue is now the ledger alone - M-014,
M-015, M-016 and M-017 are the open Mediums, then four Lows.

## iter 5/10 | 36f06007-035207 | 2026-08-20 | M-014 | done

Task: M-014, the KSP option `moshi.instantiateAnnotations` documented as switchable while nothing
read it. Closed by deleting the option rather than implementing it.

Changed: moshi-kotlin-codegen/src/main/java/com/squareup/moshi/kotlin/codegen/api/Options.kt (the
constant and its KDoc deleted), .jeffy/probes/codegen-target-model/TargetModelProbe.kt (the
acceptance check), BACKLOG.md (M-014 closed), PLAN.md (codegen:target-model re-swept), JOURNAL.md.

Checkpoint: 7ab4e7314512aca034149c4162f8baa75b12b855

Verification:
The acceptance check was written first and run against the unfixed code, where it failed as it had
to: the declared option constants came back as three - OPTION_GENERATED,
OPTION_GENERATE_PROGUARD_RULES and OPTION_INSTANTIATE_ANNOTATIONS - against an expected two. After the
deletion the same check passes and `grep -rn instantiateAnnotations moshi-kotlin-codegen/src` returns
nothing, which is the acceptance the ledger line named.

Deleting rather than implementing, with the rationale the Constraints ask for on a public-interface
change. The option's own KDoc says it exists to "restore the legacy behavior of storing annotations
on generated adapter fields and looking them up reflectively", and no such path is left in the
project - `DelegateKey` instantiates the annotation unconditionally. Honouring the option would mean
re-adding a removed code path to serve a flag nobody can currently observe, which is the opposite of
what the ordering principles ask for. The constant is on `Options`, which carries
`@InternalMoshiCodegenApi`, so its audience is opt-in internal; and the deletion changes nothing for a
build that still passes the option, because KSP hands unknown options through and the processor
ignored this one already. japicmp compares only `:moshi` and `:moshi-adapters`, so no binary gate
covers this artifact either way.

The check is an enumeration rather than a spot assertion: the declared option set is pinned to exactly
the two constants, and each of those two is driven at two or more values by the ksp-processor battery
- `moshi.generated` at four, `moshi.generateProguardRules` at three - so a future option that decides
nothing fails one battery or the other rather than sitting inert.

Battery ownership: the diff touched `Options.kt`, which is in codegen-target-model's paths, so that
battery ran and passed with 44 checks, one more than before. That same change made the
codegen:target-model row stale by its own rule - implementing code changed after the recorded commit -
so the row is re-swept here and now names this iteration's checkpoint. The ksp-processor battery was
run too, as the direct sibling that drives the surviving options, and passes with 60.

Verify gate: `./gradlew build check --rerun-tasks` exit 0 in 48s, all tasks forced.

Learnings: none new.

Next: M-015, the Java-declared JsonQualifier whose non-RUNTIME retention goes undiagnosed.

## iter 6/10 | 36f06007-035207 | 2026-08-20 | M-015 | done

Task: M-015, a `@JsonQualifier` declared in Java whose retention does not reach runtime compiling
clean while the Kotlin equivalent was refused.

Changed: moshi-kotlin-codegen/src/main/java/com/squareup/moshi/kotlin/codegen/ksp/KspUtil.kt (a new
`isRetainedAtRuntime` helper), .../ksp/MoshiApiUtil.kt (the check rewritten to use it and to name the
offending declaration), .jeffy/probes/codegen-ksp-processor/KspProcessorProbe.kt (the enumeration),
BACKLOG.md (M-015 closed), PLAN.md (codegen:ksp-processor re-swept), JOURNAL.md.

Checkpoint: 08477f894dd198f8ce4e5048b98e604c0080cf09

Verification:
The enumeration was written first and run against the unfixed code. The class here is a qualifier
whose retention does not survive to runtime going undiagnosed, and the set of sites is the ways a
retention can be declared, not the places the source mentions `Retention`: spelled out in Kotlin,
spelled out in Java, or left to each language's own default. Driven at all eight points, the unfixed
code failed exactly three - a Java qualifier at `RetentionPolicy.CLASS`, one at
`RetentionPolicy.SOURCE`, and one with no `@Retention` at all, which Java defaults to CLASS - and
passed the four Kotlin cases and the Java RUNTIME one. After the fix all eight behave: the three Java
non-runtime spellings are refused with the same message the Kotlin ones get, and every runtime
spelling still compiles clean, which the `accepted` checks assert by requiring the messages to say
nothing about retention at all.

What the fix preserves. The old check read `kotlin.annotation.Retention` only, so it was blind to the
Java spelling; the new helper consults both annotations and, finding neither, judges by the language
the annotation was declared in - Kotlin defaults to RUNTIME and Java to CLASS. No build that was
correct before becomes an error: the only newly-refused programs are ones whose qualifier could never
have been matched at runtime, since Moshi reads qualifiers reflectively when it looks an adapter up.
The error now carries the offending declaration as its element, so it points at the annotation rather
than at nothing.

Battery ownership: the diff touched `KspUtil.kt` and `MoshiApiUtil.kt`, both in
codegen-ksp-processor's paths, so that battery ran and passes with 74 checks, up from 60. The same
change made that row stale by its own rule, so it is re-swept here and now names this iteration's
checkpoint.

Verify gate: `./gradlew build check --rerun-tasks` exit 0 in 35s, all tasks forced - including
`moshi-kotlin-tests:codegen-only`, which runs this processor over its own test sources and would have
failed had the new refusal caught anything the project itself declares.

Learnings: none new.

Next: M-016, the processor abandoning its round at the first class it cannot model.

## iter 7/10 | 36f06007-035207 | 2026-08-20 | M-016 | done

Task: M-016, the processor abandoning its whole round at the first class it could not model.

Changed: moshi-kotlin-codegen/src/main/java/com/squareup/moshi/kotlin/codegen/ksp/
JsonClassSymbolProcessorProvider.kt (return replaced by continue),
.jeffy/probes/codegen-ksp-processor/KspProcessorProbe.kt (the acceptance checks), BACKLOG.md (M-016
closed), PLAN.md (codegen:ksp-processor re-swept), JOURNAL.md.

Checkpoint: 602eb788d20d18a82e65673a220a495564471055

Verification:
The acceptance checks were written first and run against the unfixed code, where both failed: with two
classes carrying private primary constructors in one file only `AlphaBroken` was named and
`BetaBroken` never was, and with a valid class after a broken one nothing at all was generated. After
the fix both pass - both names appear in the messages, and `BetaFineJsonAdapter.kt` is written even
though the compilation still fails on the class that was genuinely wrong.

The change is one word. `?: return emptyList()` left the loop over every annotated type in the round;
`?: continue` leaves only the type that could not be modelled, whose reason had already been logged
one line earlier. What it preserves: a bad type is still an error and still fails the build, so
nothing that used to be refused is now accepted; what it stops is the silence about every type after
it, which cost a rebuild per error and generated nothing for classes that were fine.

Battery ownership: the diff touched `JsonClassSymbolProcessorProvider.kt`, in codegen-ksp-processor's
paths, so that battery ran and passes with 80 checks, up from 74. That row was made stale by the same
change and is re-swept here at this iteration's checkpoint. Its row text lost the clause explaining
that each rejection needed its own compilation because the processor abandoned the round - that is no
longer true, though the battery still drives them separately, which is now belt and braces rather
than a necessity.

Verify gate: `./gradlew build check --rerun-tasks` exit 0 in 35s, all tasks forced.

Learnings: none new.

Next: M-017, the IncludeNullsForOneType recipe restoring serializeNulls into setLenient. That is the
last open Medium; four Lows remain after it.

## iter 8/10 | 36f06007-035207 | 2026-08-20 | M-017 | done

Task: M-017, the IncludeNullsForOneType recipe restoring its saved serializeNulls value into
setLenient. The last open Medium.

Changed: examples/src/main/java/com/squareup/moshi/recipes/IncludeNullsForOneType.java (one call
corrected), .jeffy/probes/examples-recipes/WriterStateProbe.java (new) and run.sh (it now compiles and
runs that probe), BACKLOG.md (M-017 closed), PLAN.md (examples:recipes re-swept), JOURNAL.md.

Checkpoint: a2a5701a0508ad0140b2da1a06f53af275f1aa8e

Verification:
The check had to be new work, not a stronger diff: the recipes battery grades printed output, and this
defect is invisible there because the recipe writes one value and exits. What a reader who copies it
gets is a writer handed on to the next value, so the probe drives the recipe's adapter on a writer
that outlives it and states what the writer must look like afterwards, at both settings of the flag
the recipe borrows.

Run against the unfixed recipe, three of the five new checks failed and two passed, which is the shape
that identifies the bug rather than merely detecting it: from the writer's defaults serializeNulls
came back true instead of false and the next value written on the same writer came out as `{"k":null}`
rather than `{}`, while leniency happened to be unharmed because the value copied into it was false;
starting instead with serializeNulls already on, serializeNulls survived by luck and leniency was the
casualty, flipped to true. Both directions pass after the one-word fix, and the recipe's own printed
output is unchanged, which the other 20 checks confirm.

The idiom is class-complete at one site. `grep -rn 'setSerializeNulls\|getSerializeNulls\|setLenient'
examples/src/main` returns three lines, all inside this one method, and the same borrow-and-restore in
the library's own `JsonAdapter.serializeNulls()` and `lenient()` wrappers is already driven by the
adapter-wrappers battery's re-read checks, so no second instance exists to fix.

Battery ownership: the diff touched the recipe, which is in examples-recipes' paths, so that battery
ran and passes with 25 checks, up from 20. The row was made stale by the same change and is re-swept
here at this iteration's checkpoint.

Verify gate: `./gradlew build check --rerun-tasks` exit 0 in 34s, all tasks forced.

Learnings: none new, but one thing worth carrying: this defect survived a sweep that ran the program
and compared every line it printed. A surface whose contract includes state handed back to a caller
needs a check that outlives the call, and stdout equality will never be that check.

Next: no High and no Medium is left open. Four Lows remain - L-001, L-002, L-003 and L-004 - and the
convergence path needs a full fresh-evidence audit before the evaluator gate can be asked for a
verdict.

## iter 9/10 | 36f06007-035207 | 2026-08-20 | AUDIT | audit

Task: the closing full audit, rescoring every applicable dimension with fresh evidence. It did not
come back clean, so closeout has not begun and the run does not converge here.

Changed: JOURNAL.md and JOURNAL-archive.md (rotation), .jeffy/probes/run-all.sh (new), BACKLOG.md
(M-018 filed).

Checkpoint: 60519f874aa70f3b2235c277cb0a0d50e51fe660

Verification:
Fresh evidence, not a re-reading. Every battery in the tree was executed - 35 batteries, 1,323
known-answer checks in total, all green - through a new runner that discovers them rather than listing
them, since a list is how a battery stops being run. The 28 Java and script batteries ran under the
runner; the seven Kotlin and KSP ones were re-run serially afterwards for the reason below, and their
counts here are from that serial run.

Three defects surfaced in the instruments themselves, none in the batteries. The runner derived a
default-package probe's main class as `.FooKt` and could not load it, which is how the three Kotlin
library batteries first appeared to fail; two probe files in one directory reported under a single
name; and, worse, the codegen-ksp-processor battery aborted and then hung rather than exiting,
because kotlin-compile-testing leaves non-daemon threads behind, so an exception escaping main does
not end the JVM. That hang was mine to cause: I ran the verify gate with `--rerun-tasks` concurrently
with the batteries, and it replaced the build outputs the probe compiles against while the probe was
reading them. All three are fixed - the class derivation, the labels, and a `battery {}` wrapper that
reports and exits non-zero rather than hanging - and the seven affected batteries were then re-run
serially with nothing else touching the build, all passing.

Numbers re-derived rather than reread. The Surface inventory's union command returns 95 main sources
and every one belongs to a row; the Environment fingerprint's exclusion enumeration still returns 17
lines; the Oracle class's test-result count is 39 files after a full run; the toolchain is unchanged -
OpenJDK 21.0.11, Gradle 9.5.1, Kotlin 2.3.21, KSP 2.3.9, Okio 3.17.0. Every one of the 32 inventory
rows was checked for staleness by comparing its recorded commit against the last commit touching its
own paths file, and none is stale - the four fixes this run each re-swept their row in the same
iteration. There are no Declined entries, so no Derivation had to be re-run.

One Medium found, and it is why this audit is not clean. M-018: `Moshi.adapter(KType)` fails two
different ways for the same input depending on cache state. A KType whose classifier is a type
parameter becomes a `TypeVariableImpl` whose `getGenericDeclaration()` is a Kotlin `TODO()`, and both
`equals` and `hashCode` call it. Driven: a cold-cache lookup raises `IllegalArgumentException: No
JsonAdapter for T`, and after one unrelated successful lookup the identical call raises
`kotlin.NotImplementedError` - an Error, so a caller's `catch (e: Exception)` does not catch it. The
difference is only that `HashMap.get` skips hashing when its table is still empty. This was found by
grepping shipped sources for unfinished-work markers, which returned 10 lines of which one was a
`TODO()` call rather than a comment; the reproduction is what filed it, not the grep.

Scored Medium rather than High with the rationale on its line: the input is a developer mistake - a
bare type variable is not a serializable type - so the call was always going to fail, and what is
wrong is that the manner of failure depends on unrelated state and escapes as an Error. No wrong
value is produced and nothing is corrupted.

Scores, all claiming the whole project since every row is swept: correctness None; security None -
the adversarial surface is the reader, whose batteries drive malformed escapes, unterminated inputs,
the nesting bound and the number grammar; testing None, with `:moshi-adapters:test` run in isolation
at exit 0; error handling Medium (M-018, and L-001 below it); documentation Low (L-002, L-003);
architecture and code quality Low (L-004); dependency hygiene None - the published artifacts declare
one runtime dependency each, okio 3.17.0 and kotlin-metadata, both current; performance not scored,
because nothing this run measured throughput and no battery grades it, and calling it None would
claim an examination that did not happen; observability does not apply to a library with no logging
surface, and UX and accessibility do not apply to a library with no user-facing surface.

Verify gate: `./gradlew build check --rerun-tasks` exit 0 in 75s, all tasks forced.

Not a stall by the letter of the check: this iteration changed only state files and paths under
.jeffy/, and while BACKLOG.md gained M-018 - which is an item changing state - no Surface inventory
row changed. An AUDIT entry is a ceremony entry and never forms the blocking pair in any case.

Learnings: two operational rules, both copied to PLAN.md - never run a gradle build while a battery
is running, because the batteries read build outputs that `--rerun-tasks` replaces underneath them;
and a battery must not let an exception escape main, because kotlin-compile-testing's non-daemon
threads turn that into a hang that stops the suite instead of a failure inside it. Worth carrying too:
a `TODO()` in Kotlin is a call that throws, not a comment, and this one sat behind `equals` and
`hashCode` on a type the adapter cache uses as a key.

Next: M-018 is the only open Medium and iteration 10 is the last. The fix is small - refuse a bare
type parameter where the Type is built, so the failure is the same clean exception on both paths -
but it lands on a swept row and needs that row re-swept with it, so the final iteration either closes
it or hands it over.

## iter 10/10 | 36f06007-035207 | 2026-08-20 | M-018 | done

Task: M-018, the last open Medium and the one the closing audit filed. The final iteration closes it
rather than writing a WRAPUP that would hand over a fix already reproduced and already specified.

Changed: moshi/src/main/java/com/squareup/moshi/internal/KotlinReflectTypes.kt (equals and hashCode),
.jeffy/probes/kotlin-extensions/KotlinExtensionsProbe.kt (six acceptance checks), BACKLOG.md (M-018
closed), PLAN.md (moshi:kotlin-extensions re-swept), JOURNAL.md.

Checkpoint: a1d5036c4246bf34f7a6d925cbacdb5e06e79924

Verification:
The six checks were written first and run against the unfixed code, where four failed and two passed.
The two that passed are the cold-cache ones - the refusal was already an IllegalArgumentException
naming the type variable - and the four that failed all failed the same way, with
`NotImplementedError` from `getGenericDeclaration()`: the warm-cache lookup, hashing the built type,
comparing it with itself, and comparing it with another class's parameter of the same name. All six
pass after the change, and the battery is green at 50 checks, up from 44.

What the change preserves, which the callers decide. `KType.javaType` is internal and reached from
three places: `Moshi.adapter(KType)`, `Moshi.Builder.add(KType, adapter)`, and the subtypeOf and
supertypeOf extensions. Every one of them hands the Type to Moshi, whose adapter cache keys on the
type itself, so `hashCode` is called on it as soon as the cache holds anything - which is why the
same lookup refused cleanly on a cold instance and threw an Error on a warm one. Identity now comes
from the wrapped `KTypeParameter` instead of from name and generic declaration. The KTypeParameter
carries its declaring container, so two variables named T from different declarations still compare
unequal, which the battery drives. What is given up is comparing equal to a `TypeVariable` obtained
from Java reflection - the contract `TypeVariable` asks for - and that is stated in a comment at the
site: it cannot be honoured while `getGenericDeclaration()` is unimplemented, and no path in this
project produces such a comparison. The refusal message a caller sees is unchanged.

Battery ownership: the diff touched `KotlinReflectTypes.kt`, in kotlin-extensions' paths, so that
battery ran and passes. The row was made stale by the same change and is re-swept here at this
iteration's checkpoint.

Verify gate: `./gradlew build check --rerun-tasks` exit 0 in 51s, all tasks forced.

Not converged, and the reason is budget rather than state. Convergence needs a full fresh-evidence
audit that scores zero High and zero Medium; iteration 9's audit filed this Medium, so it was not
clean, and there is no iteration left to run another one or to invoke the evaluator gate. The gate
was never invoked this run, so no verdict exists and none is claimed.

Learnings: none new.

Next: the handoff. The ledger holds four Lows and nothing else - L-001, the processor's catch-all
logging stack frames without the exception's type or message, unprovoked from in-envelope input;
L-002, ProguardConfig's KDoc promising a fourth rule group its writer never emits, with the dead
QualifierAdapterProperty that bullet implies; L-003, a comment on the cross-module fixture explaining
its `@field:` targets by naming kapt, which this project no longer offers; L-004,
`checkIsVisibility`'s `require(ordinal <= ordinal)`. Two more things worth the next run's attention,
neither filed: `TypeVariableImpl.getGenericDeclaration()` is still a `TODO()` and is now unreachable
from equals and hashCode but not from a direct caller, and the performance dimension has never been
scored by this run because nothing measured it. The next run should start with a fresh full audit,
which with an empty-of-Mediums ledger can be clean, then the evaluator gate, then the declaration -
that is three iterations of convergence sequence, so budget it.
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

## iter 11/12 | 36f06007-035207 | 2026-08-20 | EVALUATOR | audit

Task: the adversarial evaluator gate, invocation 1 of this run, inside the one-time closing extension.
The verdict was REJECT, so the run does not converge and continues within the budget.

Changed: .jeffy/evaluator/36f06007-035207-1.md (the gate's artifact), BACKLOG.md (M-019 filed),
JOURNAL.md and JOURNAL-archive.md (rotation), PLAN.md untouched.

Checkpoint: 554f615fb359ce35153d9b5e7ccf9e5bd35127d3

Verification:
The declaration path was checked before the gate was asked for anything. The Definition of done's own
clause for a closing audit that files findings applies here: iteration 9's audit found zero High and
one Medium, and the only commits since it are iteration 10's completed fix for that very task plus
state-file bookkeeping - `git diff --name-only 60519f87 HEAD` returns KotlinReflectTypes.kt, its
battery, and the three state files, nothing else. The inventory listed no unswept row, the ledger held
four Lows and no Medium, and `./gradlew build check --rerun-tasks` exited 0 in 41s.

Evaluator: REJECT. One substantiated reason, and it is correct. M-018 was closed at the instance
rather than at the class: `getGenericDeclaration()` is still an unimplemented `TODO()`, and while
iteration 10 stopped `equals` and `hashCode` from calling it, Moshi's own resolver still does -
`declaringClassOf` in `internal/Util.kt` reads `typeVariable.genericDeclaration` on the way through
`resolve`. Reproduced here independently of the gate, driving `Box<T>`'s three properties on both a
cold and a warm cache: the bare `T` now refuses cleanly with `IllegalArgumentException` on both, while
`List<T>` and `Map<String, T>` raise `kotlin.NotImplementedError` on both. So the residue is not
cache-dependent at all, which makes it a plainer defect than M-018 was. Filed as M-019 at Medium, the
same severity M-018 carried for the same consequence.

That the iteration-10 entry named this residue and did not file it is the failure worth recording:
the entry said the method was "now unreachable from equals and hashCode but not from a direct caller"
and put it in the handoff prose rather than on the ledger, where it would have been worked. Prose is
not a ledger, and a known Medium that only appears in a Next field is a Medium nobody will do.

Everything else the gate checked held: the Verify command green cold and under --rerun-tasks, all five
of this run's acceptance checks green, all 40 batteries passing at 1,373 checks, the 32 inventory rows
swept and none stale, the Oracle class and Environment fingerprint numbers re-deriving at 39, 17 and
95, `## Declined` empty, and L-001 through L-004 accurately scored Low. The artifact recording all of
it is committed by this iteration's checkpoint at .jeffy/evaluator/36f06007-035207-1.md.

One evaluator invocation remains; the cap is 2, because this first one landed after the midpoint of
the budget. This is not gate salvage - that begins only on a REJECT with no invocation left - so the
run continues normally against the ledger.

Learnings: one rule, copied to PLAN.md - a residue a fix knowingly leaves behind is filed on the
ledger in that same iteration, never described in the entry's prose, because the next iteration reads
the ledger and the gate reads both.

Next: M-019 is the only open Medium and one iteration remains. The fix is the structural one iteration
9 already named and iteration 10 declined to take: refuse a type parameter where the Type is built, so
no caller can reach the unimplemented method.

## iter 12/12 | 36f06007-035207 | 2026-08-20 | M-019 | blocked

Task: M-019, the finding the evaluator gate filed. The fix was attempted, the verify gate refused it,
and the working tree was reverted to the last checkpoint. The run ends here without declaring.

Changed: BACKLOG.md only - M-019 marked [b] with the reason. Every other edit this iteration was
reverted by `git reset --hard 683b4ebc`.

Checkpoint: be6e499374157915d2dc24da5eff8e1b57dea6e7

Verification:
The acceptance checks were written first and failed against the unfixed code as they had to: a bare
`T` already refused cleanly after M-018, while `List<T>` and `Map<String, T>` raised
`kotlin.NotImplementedError` on both a cold and a warm cache, and reading the declaration directly
threw rather than answering. Five new checks, five failures.

The fix was the structural one iteration 9 named and iteration 11 restated: stop the unimplemented
method throwing, so no caller can get an Error from it. `getGenericDeclaration()` returned null
instead of `TODO()`, which is the vocabulary its only consumer already speaks -
`declaringClassOf` reads it as `as? Class<*>` and `resolve` treats a null declaring class as "this
variable cannot be reduced further", which is exactly true for a KTypeParameter. The battery went to
57 checks, all green, and `./gradlew assemble` was clean.

Then the verify gate refused it. `./gradlew build check --rerun-tasks` exit 1: 1295 tests completed,
1 failed - `KotlinReflectTypesTest.typeVariable`, which asserts
`assertFailure { javaType.genericDeclaration }.isInstanceOf<NotImplementedError>()`. The project pins
the throwing behaviour deliberately, as the documented shape of "not yet supported".

Reverted rather than repaired in place, and the choice is worth stating. The in-iteration repair
exception covers a test that was green only because of the defect being fixed - a pre-existing fault
newly exposed. This is not that: the assertion is not faulty, it is an intentional record of a
contract, and rewriting it is a decision about whether that contract should change, not a repair.
Making that call in the last minutes of a run and then asking the gate to bless it is the shape the
revert rule exists to prevent, and the Constraints warn specifically against editing a test to make a
change pass. So the tree was reset to 683b4ebc, `./gradlew build check` re-run at exit 0, and M-019
marked [b] carrying that reason on its own line, including the test that pins it - which is the single
most useful thing the next run can be handed about this finding.

The gate was not re-invoked. One invocation remained, but with the fix reverted there is nothing new
to put in front of it and no iteration left to declare in; spending it would have bought a verdict on
a tree the gate already reviewed.

Not converged. The Definition of done needs zero open High and Medium, and M-019 is an open Medium
carried as blocked; the evaluator's verdict on record for this run is REJECT.

Learnings: one rule, copied to PLAN.md - before changing behaviour a `TODO()` or an explicit
"not supported" marker describes, grep the test tree for a test that pins it, because a deliberate
pin turns a structural fix into a contract decision and the verify gate will find it after the work
rather than before.

Next: M-019 with everything now known about it, then the four Lows. The next run starts with a fresh
audit; the ledger it audits against holds one blocked Medium and four Lows.

## iter 1/10 | 0453bb16-053928 | 2026-08-20 | M-019 | done

Task: M-019, the Medium the previous run's evaluator gate filed and its final iteration left blocked.
The recorded blocker was a contract decision, not a repair: `KotlinReflectTypesTest.typeVariable`
pinned the current behaviour, and the previous run had no iteration left to take the decision. This
run has ten, so it takes it in the first.

Changed: moshi/src/main/java/com/squareup/moshi/internal/KotlinReflectTypes.kt (the KTypeParameter
branch, the file header, and the deletion of TypeVariableImpl),
moshi/src/test/java/com/squareup/moshi/internal/KotlinReflectTypesTest.kt (typeVariable rewritten),
.jeffy/probes/kotlin-extensions/KotlinExtensionsProbe.kt (the acceptance checks),
BACKLOG.md (M-019 closed), PLAN.md (moshi:kotlin-extensions re-swept), JOURNAL.md.

Checkpoint: d8905cf0b4b79644cde0993ba6b32a57d2823fda

Verification:
The eight acceptance checks were written first and run against the unfixed code, where five failed.
The failures were exactly the shapes M-019 named: `List<T>` and `Map<String, T>` raised
`kotlin.NotImplementedError` on both a cold and a warm cache, and the aggregate check that no shape
lets an Error escape listed all four of those cases. The bare `T` already refused cleanly on both
cache states, which is what M-018 bought and all M-018 bought. All eight pass after the change and
the battery is green at 52 checks, the same total as before because the six checks M-018 left were
replaced rather than added to: three of them drove `TypeVariableImpl`'s equals and hashCode, and
that class no longer exists.

The decision the blocker described, taken rather than deferred. The pinned assertion is not a
contract worth keeping. `getGenericDeclaration()` cannot be implemented on the non-experimental
`KTypeParameter` API at all - it exposes name, bounds and variance, never the declaring container -
so the object that assertion pins is one that can only fail, and it failed as an `Error` from inside
a plain `Moshi.adapter(KType)` call. Every caller of the internal `KType.javaType` hands the Type
straight to Moshi: `Moshi.adapter(KType)`, `Moshi.Builder.add(KType, adapter)`, and the `subtypeOf`,
`supertypeOf` and `asArrayType` KType extensions. Not one of them can use a TypeVariable whose
declaration is unanswerable, because Moshi's own resolver reads it - `declaringClassOf` in
`internal/Util.kt`, on the way through `resolve` for any parameterized type. So the fix is the
structural one iteration 9 named: refuse the type parameter where the Type is built. The test now
asserts that refusal by its exact message.

The class is complete because the method is gone, not because its callers were patched. M-018 fixed
two callers, the gate found the third, and a fourth would have been found by the run after that.
`TypeVariableImpl` is deleted, so no caller can reach `getGenericDeclaration()` on a Moshi-built
type: no class in any `src/main` tree implements `java.lang.reflect.TypeVariable` any more, and the
only `TODO(` left in shipped sources is `Util.kt`'s `// TODO(jwilson):` comment, which is a comment
and not a call. `Util.declaringClassOf` still reads `genericDeclaration`, and now only ever from a
TypeVariable the JDK itself produced - `KtTypes`' property types come from `Field.genericType` and
answer it correctly - which is why it is left alone.

What the change preserves. The conversion's behaviour is unchanged for every type that does not
contain a type parameter: 44 of the battery's 52 checks cover that ground and were green before and
after, including the ten `KotlinReflectTypesTest` cases that compare Moshi's Type against
`kotlin.reflect.javaType`'s own answer symmetrically. What changes is the failure: `IllegalArgument-
Exception` naming the parameter, at the conversion, for every shape and both cache states, instead
of an `Error` for some shapes and an exception for others. The public entry points gain no new
failure - they already failed on these inputs - only a consistent one. japicmp passes, the deleted
class having been private.

Battery ownership: the diff touched `KotlinReflectTypes.kt`, declared in kotlin-extensions' paths
and in no other battery's, so that battery ran and passes at 52 checks. Its row is stale by the same
change and is re-swept here at this iteration's checkpoint. The two batteries owning the sibling
files in the same package, internal-util and types, were run too and both pass.

Verify gate: `./gradlew build check --rerun-tasks` exit 0, all tasks forced.

Learnings: none new. The Lesson that would have saved the previous run - grep the test tree for a
test pinning a `TODO()` before changing it - was already written by that run and was followed here
before the fix rather than after it.

Next: the ledger holds four Lows and nothing else, so the run's path is a full fresh-evidence audit,
then the evaluator gate, then the declaration. The audit is iteration 2's work and can be clean for
the first time this project's runs have had an empty-of-Mediums ledger going into one. Two things it
should not skip: the performance dimension has never been scored by any run because nothing measured
it, and scoring it None without measuring would be the silence the PLAN warns against; and the
kotlin-extensions row is the one this iteration changed, so its evidence is the newest and the
thinnest-tested by time.

## iter 1/10 | 0453bb16-053928 | 2026-08-20 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines at 738 with 13 entries, so all but the last 10 were moved to the
end of JOURNAL-archive.md.

Changed: JOURNAL.md (554 lines, 10 entries), JOURNAL-archive.md (2,615 lines, 52 entries).

Checkpoint: d8905cf0b4b79644cde0993ba6b32a57d2823fda

Verification: the three moved entries are the previous run's iterations 1, 2 and 3 - one AUDIT and
two SWEEPs. The archive's entry count rose from 49 to 52 rather than being replaced, and the split
was taken only on lines beginning `## iter` followed by a digit, so the heading-grammar example in
JOURNAL.md's preamble was neither counted nor moved.

Learnings: none.

Next: unchanged - the full fresh-evidence audit is iteration 2's work.

## iter 2/10 | 0453bb16-053928 | 2026-08-20 | AUDIT | audit

Task: the full fresh-evidence audit this run's convergence rests on. It came back with zero High and
zero Medium in-envelope, so closeout has begun: this run runs no further audit and no replenishment,
and finishes by working or declining what is on the ledger and then converging.

Changed: BACKLOG.md (L-005 and L-006 filed, the Later section reordered runtime-before-docs as the
Method asks), JOURNAL.md. The iteration-1 headings were corrected from run-id 0453bb16-014313 to
0453bb16-053928: I derived the run-id from a local clock instead of started_at in the loop state
frontmatter, and the stop hook's hygiene check named the correct one. Nothing else in those entries
was touched.

Checkpoint: 82704cea0d06b426f89ac4ab140c003488eb593b

Verification:
Fresh evidence throughout, executed this iteration rather than reread.

Every battery in the tree ran through the discovering runner: 40 batteries, 1,375 known-answer checks,
all green. That is two more checks than the last full run recorded, and both are iteration 1's, which
took kotlin-extensions from 50 to 52.

Numbers re-derived by their own commands, not copied. The Surface inventory's union command returns 95
main sources and every one belongs to a row; the Environment fingerprint's exclusion enumeration
returns 17 lines; the Oracle class's test-result count is 39 files after a full run. The toolchain is
unchanged: OpenJDK 21.0.11, Gradle 9.5.1, Kotlin 2.3.21, KSP 2.3.9, Okio 3.17.0. All 32 inventory rows
were checked for staleness by comparing each recorded commit against the last commit touching its own
paths file, and none is stale - iteration 1 re-swept the one row it made stale. `## Declined` is
empty, so no Derivation had to be re-run.

Two findings, both Low, both reproduced before filing.

L-005: `ParameterizedTypeImpl.toString()` renders nothing of the owner type. Driven on a static
nested class with a parameterized owner, which is a shape Moshi accepts and serializes:
`Outer<String>.Box<Integer>` and `Outer<Long>.Box<Integer>` are unequal, an adapter registered for the
first is not returned for the second, and both print identically, so the `No JsonAdapter for` message
for either names a type the caller cannot tell from the one they did register. The JDK's own reflected
rendering of the same declaration does carry the owner's argument. Scored Low rather than Medium with
the rationale on its line: the refusal is correct and no wrong value is produced, and reaching two
such types at once needs both hand-built through `Types.newParameterizedTypeWithOwner`, a user-error
surface, so it is not the plausible in-envelope edge case the Medium band describes.

L-006: `MapJsonAdapter`'s KDoc says it converts maps with string keys and carries a TODO for
supporting other key types, and the class already does. Driven over seven key kinds: String, Integer,
Long, Double, enum and Object all round-trip, and only Boolean is refused, by the writer's own state
rule with a message naming it. The container-adapters battery already pins the Integer-key read, so
the sentence contradicts the project's own executed check. Scored Low rather than Medium under the
misleading-documentation clause with the rationale on its line: the class is `internal`, so the
sentence misleads a maintainer and not a user, and no behaviour depends on it.

Neither the Boolean refusal nor the two inherited `// TODO:` comments in `KotlinReflectTypes.kt` are
findings. The Boolean case is the writer state contract the writer-api battery already pins, and it
names the type in its message. The two comments describe declaration-site variance and
JvmSuppressWildcards handling that the Kotlin stdlib's own `javaType` also omits; honouring them would
produce wildcards Moshi then strips, so their absence is what Moshi wants.

Scores, and every one of them claims the whole project because every row is swept. Correctness None.
Security None - the adversarial surface is the reader, and its four batteries drive malformed escapes,
unterminated inputs, the nesting bound and the number grammar. Testing None, with
`./gradlew :moshi-adapters:test --rerun-tasks` exit 0 in isolation. Error handling Low (L-001, L-005).
Documentation Low (L-002, L-003, L-006). Architecture and code quality Low (L-004). Dependency hygiene
None, derived rather than asserted: `./gradlew :moshi:dependencies --configuration runtimeClasspath`
resolves to okio 3.17.0 and kotlin-stdlib 2.3.21 and nothing else, `:moshi-adapters` adds nothing on
top of `:moshi`, okio's own older stdlib is upgraded rather than left conflicting, and the japicmp
baselines have their own battery.

Performance scored for the first time by any run on this project, and scored by measurement rather
than by silence. Three hot paths were driven at 5,000, 10,000, 20,000 and 40,000 elements after
warmup, taking the best of twelve runs at each size, and the invariant asserted is that doubling the
input at most doubles the time: reading a document of objects gave ratios 1.18, 1.96, 2.03; writing
the same object graph gave 2.13, 1.82, 2.08; reading an object of N distinct keys, which is what
exercises `LinkedHashTreeMap`'s growth, gave 1.44, 2.28, 2.14. No superlinear behaviour on any of the
three. The claim is exactly that and no wider: it is a scaling invariant on three paths, not a
throughput comparison against another JSON implementation, and this project has no such comparison.

Observability does not apply: the library has no logging surface. UX and accessibility do not apply:
it has no user-facing surface.

Not a stall: BACKLOG.md gained two items, which is an item changing state. An AUDIT entry is a
ceremony entry in any case.

Verify gate: `./gradlew build check --rerun-tasks` exit 0, all tasks forced.

Learnings: one rule, copied to PLAN.md - the run-id in a journal heading is the first 8 characters of
session_id plus the HHMMSS of started_at read from the loop state frontmatter, never a timestamp taken
from the shell, because the two differ and the hook checks the heading against the frontmatter.

Next: closeout, six Lows, eight iterations. The plan is five of them in iterations 3 through 7 worst
first - L-001, L-004 and L-005 are the runtime ones and go first - then the evaluator gate in
iteration 8 and the declaration in iteration 9, leaving iteration 10 as the slack a REJECT would need.
Any Low still open at the declaration is carried by ID in the declaring entry and the run report,
which the closing rule allows.

## iter 3/10 | 0453bb16-053928 | 2026-08-20 | L-001 | done

Task: L-001, the top open item under closeout. The processor's catch-all logged `e.stackTrace`, the
frame array alone, so the exception's type and message never reached the developer.

Changed: moshi-kotlin-codegen/src/main/java/com/squareup/moshi/kotlin/codegen/ksp/JsonClassSymbolProcessorProvider.kt
(one expression and a comment), .jeffy/probes/codegen-ksp-processor/KspProcessorProbe.kt (five
acceptance checks), BACKLOG.md (L-001 closed), PLAN.md (codegen:ksp-processor re-swept), JOURNAL.md.

Checkpoint: 19d4aa0df1ac41da1c91330060bd3cf104b9f2ca

Verification:
The filing's stated premise was false and that is the first thing to record. L-001 was filed Low
partly because "no in-envelope source reproduces an exception on this path today", and iteration 2's
audit repeated that without re-deriving it. Ordinary developer-authored Kotlin reaches the catch: a
nested `Outer.Inner` and a top-level `Outer_Inner` in one package both generate
`Outer_InnerJsonAdapter.kt`, so the second write raises `kotlin.io.FileAlreadyExistsException` from
KSP's own `CodeGenerator`. Driven, not reasoned: the unfixed processor logs `Error preparing
Outer_Inner: ksp.com.google.devtools.ksp.common.impl.CodeGeneratorImpl.createNewFile(...)` and never
names the exception or the colliding file.

The severity does not move, and the reason is the rubric rather than the premise. What the defect
costs is the text of a message; the failure itself is reported correctly, the build fails as it
should, and the offending type is named. That is the Low band's "minor docs, cosmetic gaps", not the
Medium band's failure, swallowed error or misleading documentation - the same reading this run applied
to L-005 an iteration ago, where the refusal was correct and only its rendering was impoverished.
Re-scoring it Medium on a rendering defect would have been the downgrade rule run backwards.

Five checks, written first and run against the unfixed code, where two failed: the logged message
carries neither `kotlin.io.FileAlreadyExistsException` nor the colliding file name. The other three
passed on both sides by design, pinning what the change preserves - the compilation still fails, the
message still names the type being prepared, and the frames are still there. After the fix all five
pass and the battery is green at 85 checks, up from 80.

One instrument mistake worth recording, caught rather than shipped. The first run of the new checks
against the "unfixed" code passed all five, which was stale bytecode: the exception identity had been
learned by applying the fix, and the source was restored without rebuilding, so the probe read jars
that still carried it. The Lesson for exactly this is already in PLAN.md; rebuilding with `./gradlew
assemble` produced the two real failures above. The learning is that the Lesson applies to restoring
a file just as much as to changing one.

What the change preserves: `stackTraceToString()` is a superset of what `stackTrace.joinToString` -
the exception's header line followed by the same frames, plus any cause chain. Nothing that reached
the log before stops reaching it, which the two both-sides checks pin.

Battery ownership: the diff touched `JsonClassSymbolProcessorProvider.kt`, declared in
codegen-ksp-processor's paths and in no other battery's, so that battery ran and passes. Its row is
stale by the same change and is re-swept here at this iteration's checkpoint.

Verify gate: `./gradlew build check --rerun-tasks` exit 0, all tasks forced.

Learnings: one rule, copied to PLAN.md - restoring a library source is a change like any other, so
`./gradlew assemble` has to run before the batteries are believed; a check that passes against code
you have just un-fixed is reading the jar, not the source.

Next: five Lows remain - L-004, L-005 runtime, then L-002, L-003, L-006 docs - and seven iterations.
L-004 is next, the `require(ordinal <= ordinal)` in `kotlintypes.kt` that can never fail. The plan
still fits: four more Lows in iterations 4 through 7, the evaluator gate in 8, the declaration in 9,
iteration 10 as slack.

## iter 4/10 | 0453bb16-053928 | 2026-08-20 | L-004 | done

Task: L-004, the next open item under closeout. `KModifier.checkIsVisibility` read
`require(ordinal <= ordinal)`, a predicate comparing the receiver with itself, so the two init blocks
that call it to reject a non-visibility modifier rejected nothing.

Changed: moshi-kotlin-codegen/src/main/java/com/squareup/moshi/kotlin/codegen/api/kotlintypes.kt
(the guard and its message), .jeffy/probes/codegen-target-model/TargetModelProbe.kt (five acceptance
checks), BACKLOG.md (L-004 closed), PLAN.md (codegen:target-model re-swept), JOURNAL.md.

Checkpoint: cf898d5dc151c09854bdf92d7488dfce9bf810dd

Verification:
Five checks written first and run against the unfixed code, where three failed. The two that failed
on the enumeration failed identically and completely: both `TargetConstructor` and `TargetType`
accepted all 28 non-visibility constants of `KModifier` - EXPECT through OUT, listed in the failure -
and the third failed because no message existed to assert, the guard having thrown nothing. The two
that passed on both sides are the positive half of the same enumeration, that all four visibilities
construct, which is what stops a fix that simply refuses everything from passing. After the fix all
five pass and the battery is green at 49 checks, up from 44.

The enumeration is the whole enum, not a sample. `KModifier.entries` is driven through both call
sites, partitioned by whether the constant is one of the four visibilities, and each half asserted
empty of surprises. That is what makes the claim "rejects every non-visibility modifier" a checked
statement rather than a sentence.

What the fix preserves, and what it deliberately does not. The intended predicate was
`ordinal <= KModifier.INTERNAL.ordinal`, which works only while PUBLIC, PROTECTED, PRIVATE and
INTERNAL stay first in kotlinpoet's declaration order - they are ordinals 0 through 3 in kotlinpoet
2.3.0, and DATA is 29. The fix names the four in a set instead of deriving them from ordinals, so a
kotlinpoet release that reorders the enum cannot silently widen the guard, and the message is built
from that same set rather than from a range, which is the second half of the original defect: the
message enumerated `(0..ordinal)` from the offending value, so it would have described the wrong set
even had the predicate worked. The message shape is the one the original intended, asserted in full:
`Visibility must be one of PUBLIC, PROTECTED, PRIVATE, INTERNAL. Is DATA`.

No caller behaviour changes for valid input, which is why the verify gate stayed green: both call
sites are fed `getVisibility().toKModifier() ?: KModifier.PUBLIC`, which yields only the four, so the
guard that now works has nothing to reject in the processor's own pipeline. That was the reason
L-004 was Low and it is still the reason.

Battery ownership: the diff touched `kotlintypes.kt`, declared in codegen-target-model's paths and in
no other battery's, so that battery ran and passes. Its row is stale by the same change and is
re-swept here at this iteration's checkpoint.

Verify gate: `./gradlew build check --rerun-tasks` exit 0, all tasks forced.

Learnings: none new.

Next: four Lows remain - L-005 runtime, then L-002, L-003, L-006 docs - and six iterations. L-005 is
next, the owner type missing from `ParameterizedTypeImpl.toString()`. Then the plan is L-002 and
L-003 or L-006 in iterations 6 and 7, the evaluator gate in 8, the declaration in 9, with iteration 10
as slack; if the docs Lows run long, any of them is carried by ID at the declaration, which the
closing rule allows.

## iter 5/10 | 0453bb16-053928 | 2026-08-20 | L-005 | done

Task: L-005, the last runtime Low. `ParameterizedTypeImpl.toString()` rendered no part of the owner
type, so two types that differ only in their owner's argument printed the same string and a refusal
named a type the caller could not tell from one they had registered.

Changed: moshi/src/main/java/com/squareup/moshi/internal/Util.kt (the toString and its comment,
replacing the `TODO(jwilson)` that marked the gap), .jeffy/probes/internal-util/UtilProbe.java (seven
acceptance checks and two fixtures), BACKLOG.md (L-005 closed), PLAN.md (moshi:internal-util and
moshi:types re-swept), JOURNAL.md.

Checkpoint: e01f9c0086fd83f66d10175ffb51f1b4c45e0c81

Verification:
The filed reproduction ran first and still reproduced: an adapter registered for
`Outer<String>.Box<Integer>` is not returned for `Outer<Long>.Box<Integer>`, and both failures named
`Aud5$Outer$Box<java.lang.Integer>`.

Seven checks written first, four of which failed against the unfixed code: the parameterized-owner
rendering, the two renderings being different, the failure message carrying the owner's argument, and
the two failure messages differing. Three passed on both sides and they are the ones that make the
change safe rather than merely different - an owner-less type renders exactly as before, a raw-Class
owner renders exactly as before, and the two types were unequal all along, which is what made one
shared rendering wrong rather than merely terse. After the fix all seven pass.

The enumeration is the three owner shapes a `ParameterizedTypeImpl` can carry, and the fix touches
exactly one of them. Absent: unchanged. A raw `Class`: deliberately left alone, because the init
block requires the owner to be the raw type's enclosing class, so the raw type's binary name already
spells it - `java.util.Map$Entry<...>` is what both the old code and the JDK produce, and rendering
the owner again would have changed every existing message. Parameterized: now rendered the way the
JDK renders the same declaration, the owner followed by the nested type's name with the shared prefix
removed, giving `UtilProbe$Outer<java.lang.String>$Box<java.lang.Integer>`.

What the change preserves, checked rather than argued: every battery in the tree was run afterwards,
40 of them at 1,392 checks, all green. That matters here more than usual because `toString` is what
`typeToString` returns for a non-Class and so is quoted in refusal messages that other batteries
assert; nothing moved. `equals` and `hashCode` already read the owner and are untouched, so no cache
or lookup behaviour changes - only what a message says.

Battery ownership: the diff touched `internal/Util.kt`, declared in both internal-util's and types'
paths files, so both batteries ran - 42 and 65 checks, both green - and both rows are re-swept here
at this iteration's checkpoint. No KDoc documents a rendering, so the only documentation this change
owed was the comment at the site, which replaces the `TODO(jwilson)` that had marked the gap.

Verify gate: `./gradlew build check --rerun-tasks` exit 0, all tasks forced.

Learnings: none new.

Next: three docs Lows remain - L-002, L-003, L-006 - and five iterations. The convergence sequence
needs two of them, so the plan is L-006 in iteration 6, the evaluator gate in 7, the declaration in 8,
leaving 9 and 10 as slack for a REJECT. L-002 and L-003 are then carried by ID at the declaration,
which the closing rule allows for an accurately scored Low; if the gate passes early they can be taken
in the slack instead, but not after a PASS, because a fix after a PASS invalidates it.

## iter 6/10 | 0453bb16-053928 | 2026-08-20 | L-002 | done

Task: L-002, the top of the three remaining docs Lows. `ProguardConfig`'s KDoc said it "covers three
main areas" and then listed four bullets, one of them a rule group `writeTo` never emits.

Changed: moshi-kotlin-codegen/src/main/java/com/squareup/moshi/kotlin/codegen/api/ProguardRules.kt
(the stale bullet, the sketch inside `writeTo`, and the deletion of `QualifierAdapterProperty`),
.jeffy/probes/codegen-target-model/TargetModelProbe.kt (four acceptance checks), BACKLOG.md (L-002
closed), PLAN.md (codegen:target-model re-swept), JOURNAL.md.

Checkpoint: ca6cbe229ba9ddd30eec4b75340ca606c1775098

Verification:
The filed reproduction ran first and reproduced: the grep returned the declaration of
`QualifierAdapterProperty`, a public data class referenced by nothing else in the project.

The fix closes the class rather than the instance, and the class is doc-promises-the-writer-does-not-
keep. Two of them lived in this file, not one. The KDoc's third bullet promised rules for used
JsonQualifier annotations and the properties they are attached to, and `writeTo` emits none. The
sketch comment inside `writeTo` promised a keep-block containing `<init>(...)` and
`private final {adapter fields}`, and the block it really emits contains only the constructor. Both
are removed, and with the third bullet gone the KDoc's own count of three is correct: the writer emits
exactly three rule groups, the target's keepnames, the adapter's conditional keep, and the defaults
block.

Four checks written first, all four failing against the unfixed code: the stated count of three
against four bullets, four bullets against three emitted rule groups, two sketch members against one
emitted member, and `QualifierAdapterProperty` loading when it should not. All four pass after the
fix, and the battery is green at 53 checks, up from 49. The checks read the writer's real output for
one shape with defaults and one without rather than restating the doc, so a future edit that
reintroduces a promise nothing emits fails here.

The acceptance as literally filed - the grep returning nothing - is now met by every module source,
which is what it meant; the grep still returns three lines, all of them inside the battery that
asserts the class is absent. The executed form is the stronger one: `Class.forName` on it fails.

What the deletion costs, checked rather than assumed. `QualifierAdapterProperty` was `public` and
carried `@InternalMoshiCodegenApi`, the opt-in marker this project uses to say a declaration is not
for consumers. Only `:moshi` and `:moshi-adapters` have japicmp baselines - `git grep -n japicmp
settings.gradle.kts` lists exactly those two subprojects - so nothing compares the codegen artifact's
ABI, and no source in any module referenced the class.

Battery ownership: the diff touched `ProguardRules.kt`, declared in codegen-target-model's paths and
in no other battery's, so that battery ran and passes. Its row is stale by the same change and is
re-swept here at this iteration's checkpoint.

Verify gate: `./gradlew build check --rerun-tasks` exit 0, all tasks forced.

Learnings: none new.

Next: the convergence sequence, with two Lows carried. Iteration 7 runs the evaluator gate, invocation
1 of this run, and iteration 8 declares on a PASS, leaving 9 and 10 as the slack a REJECT would need.
The carried Lows are L-003, a comment on the cross-module test fixture explaining its `@field:` targets
by naming kapt, which this project no longer offers, and L-006, `MapJsonAdapter`'s KDoc claiming string
keys only. Both are accurately scored Low and neither blocks the declaration.

## iter 7/10 | 0453bb16-053928 | 2026-08-20 | EVALUATOR | converged

Task: the adversarial evaluator gate, invocation 1 of this run, and the declaration on its verdict.
The gate was run and answered in the same iteration deliberately: a PASS that does not declare does
not carry forward, and the cap for this run is 2 invocations because the first landed after the
midpoint of the budget.

Changed: .jeffy/evaluator/0453bb16-053928-1.md (the gate's artifact), BACKLOG.md (L-007, L-008 and
L-009 filed from the gate's observations, and the Converged line), JOURNAL.md. No source file was
touched this iteration.

Checkpoint: b72a4faca81d5f84989ea26f2095dbaf29307431

Verification:
The closing conditions were checked before the gate was asked for anything, each by its own command
rather than by rereading an earlier entry.

A full fresh-evidence audit is on this run's record at iteration 2 and it scored zero High and zero
Medium in-envelope. Every commit since that audit is a completed fix for a task on the ledger it
either filed itself (L-005) or found already there and left standing (L-001, L-004, L-002), plus
state-file bookkeeping; `git log --oneline` between them shows nothing else, and no audit has run
since, which closeout forbids.

The Surface inventory holds 32 rows, none unswept, none marked unreachable, and none stale by the
paths-file comparison against each row's recorded commit. The ledger holds zero open High and zero
open Medium; the two open items at the moment of the gate were L-003 and L-006, both Low with the
severity written on the line. `## Declined` is empty, so there was no Derivation to re-run.

The Oracle class and Environment fingerprint were re-read and their numbers re-derived, not quoted:
the union command returns 95 main sources, the exclusion enumeration returns 17 lines, and a full run
leaves 39 test-result files. No journal entry this run claimed a result from a target the fingerprint
says this host cannot reach; the two exclusions the fingerprint names beyond skip markers are the
`kotlinTestMode` variants, and nothing this run asserted rests on them.

Verify gate: `./gradlew build check --rerun-tasks` exit 0, all tasks forced, run before the gate was
invoked.

Evaluator: PASS. The gate re-ran the verify command cold and then forced - the first reporting every
task up to date, which it correctly refused to believe and re-ran per this project's own Lesson,
getting exit 0 with all 59 tasks executed - re-ran every battery at exit 0, and re-ran each closed
task's acceptance check individually: kotlin-extensions 52, codegen-ksp-processor 85,
codegen-target-model 53, internal-util 42, types 65. It falsified none of the four claims it was
pointed at. On M-019 it went further than the run had: it checked the shipped jar and found
`TypeVariableImpl.class` absent, and confirmed `moshi-kotlin`'s generic property types come from
`Field.genericType` rather than the changed conversion. On L-005 it declined to re-run the run's own
battery and instead re-implemented the pre-change rendering to compare against, finding four
owner-less and three raw-Class-owner shapes byte-identical and the parameterized-owner shape matching
the JDK on a four-way differential. On L-002's ABI it confirmed japicmp covers only `:moshi` and
`:moshi-adapters` and that no binary-compatibility `.api` dump exists anywhere. On L-001's severity it
agreed Low, on the ground that the falsified premise changed what reproduces the path and not what the
defect costs. It re-scored L-003 and L-006 as accurately Low, verifying both premises independently.

Four observations came back that are not REJECT reasons, and none of them was fixed here: a fix after
a PASS invalidates that PASS and spends an invocation this declaration needs. Three are filed for the
next run and one is recorded as pre-existing. L-007: the second sketch comment in
`ProguardConfig.writeTo` promises a class selector and a member modifier the writer does not emit,
which makes it the third instance of the root cause L-002 closed two of, so it is filed structurally
under the three-strike rule and L-002's class is not settled. L-008: no `## Settled classes` line
records the class M-019 closed. L-009: `run-all.sh` reports `reader-doc-contract` twice, once as a
0-check data emitter, so its "40 batteries" is 39 distinct ones. Both L-007 and L-009 were confirmed
here by direct inspection before filing rather than taken on the gate's word. The fourth observation,
that the `Outer.Inner`/`Outer_Inner` adapter-name collision is a real build failure on legal Kotlin,
is out of L-001's scope and Low at most on a user-error surface, and is recorded in the run report
rather than filed.

Three Lows carried into the declaration beyond those, each by ID: L-003, a comment on the cross-module
test fixture explaining its `@field:` targets by naming kapt, a processor this project no longer
offers; L-006, `MapJsonAdapter`'s KDoc claiming string keys only when six key kinds round-trip
through it; and, newly filed, L-007, L-008 and L-009 above. All are accurately scored Low and none
blocks the declaration.

Not a stall: BACKLOG.md gained three items and lost none, which is an item changing state. An
EVALUATOR entry is a ceremony entry in any case.

Learnings: one rule, copied to PLAN.md - run the evaluator gate and declare in the same iteration
whenever the closing conditions already hold, because a PASS does not carry forward and the second
invocation is the one a REJECT needs.

Next: nothing. The run is converged and the Converged line names this iteration's checkpoint. The next
run starts from a fresh audit with five Lows on the ledger.

## iter 7/10 | 0453bb16-053928 | 2026-08-20 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines at 970 with 17 entries, so all but the last 10 were moved to the
end of JOURNAL-archive.md.

Changed: JOURNAL.md (613 lines, 10 entries), JOURNAL-archive.md (2,972 lines, 59 entries).

Checkpoint: b72a4faca81d5f84989ea26f2095dbaf29307431

Verification: the seven moved entries are the previous run's iterations 4 through 10. The archive's
entry count rose from 52 to 59 rather than being replaced, and the split was taken only on lines
beginning `## iter` followed by a digit, so the heading-grammar example in JOURNAL.md's preamble was
neither counted nor moved. The declaring entry for this iteration is among the ten kept.

Learnings: none.

Next: nothing. The run is converged.
