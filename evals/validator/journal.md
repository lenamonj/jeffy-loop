# Journal archive

Rotated JOURNAL.md entries, oldest first. Appended to on every rotation and never overwritten; the entry count here only ever grows.

## iter 1/10 | 9c2b995d-131932 | 2026-08-15 | AUDIT | audit

Task: first audit of a fresh Improvement-mode project. Fill the Operating envelope, the Surface inventory, and the Verify command block in PLAN.md, then probe breadth-first and file findings.

Changed: PLAN.md (envelope surfaces, 31 inventory rows, Verify command / Oracle class / Environment fingerprint / Verify duration), BACKLOG.md (V-001 through V-005), JOURNAL.md, and five probe batteries under .jeffy/probes/.

Checkpoint: 5eb4da8b8b1506bce627549644e3fea094691705

Verification: Verify command `go test -cover -race ./...` exits 0 in 17s; 24 packages ok, root package 96.3% coverage. Findings were reproduced by executed probes, not by reading:
- V-001: `go run ./.jeffy/probes/_engine "<case>"` run once per case in its own process. The three cyclic shapes - two-node pointer cycle, slice+dive cycle, map+dive cycle - each end in `fatal error: stack overflow`, which is a runtime throw and not a recoverable panic, so the process dies. A 100k-node acyclic chain returns nil, which is what places the fault at the missing cycle guard rather than at depth. Struct(nil), Struct((*Node)(nil)), Var(nil,...), a 5000-term or-chain tag, and both ValidateMap shapes all return errors correctly.
- V-002: `go run ./.jeffy/probes/_kindsweep` enumerates all 181 registered tags against 9 field kinds. 45 tags panic on at least one kind; 41 of them use the library's own `Bad field type %T` message and 4 leak a raw reflect panic - port (Uint), ssn (Len), ein (Len), multibyte (Len). That split is what makes this a class with a closed enumeration rather than four separate findings. Filed at Medium, not High, with the rationale recorded here: the trigger is the tag/type pairing, which the Operating envelope classifies user-error because it is compiled in and fails deterministically on first use, and the library's designed answer to that pairing is a panic in any case; the defect is the opaque message and, for port, an undocumented type restriction.
- V-003: the comm of registered tags against the README table returns 10 tags; per-tag greps of doc.go and README.md put 6 of them plus the eu_country_code alias in neither file.
- V-004: workflow.yml gates the Coveralls step on 1.24.x while the matrix is [1.25.x, 1.26.x].
- V-005: `gofmt -l .` returns baked_in.go, doc.go, translations/ko/ko_test.go.

Scores, claiming only what was probed - 0 of 31 Surface inventory rows are swept, so no dimension is scored None across the project and the unexamined remainder is not being reported as clean: correctness High (V-001); error handling Medium (V-002); documentation Medium (V-003, and V-004's stale badge); developer experience Medium (V-004); code quality Low (V-005); security no finding on the surface actually probed - 181 tags x 21 hostile string values produced no value-driven panic and no path over 250ms, and Go's RE2 engine structurally excludes catastrophic backtracking, so the regex-heavy adversarial surface is linear by construction; architecture, testing, performance, dependency hygiene and observability not scored this iteration; UX and accessibility not applicable, this is a library with no user-facing surface.

This audit certified no inventory row. Sweeping requires a known-answer battery per function family plus every documented parameter exercised at two or more values, and the breadth probe met neither bar completely - it covered 5 of 10 hash tags, for one example. Breadth-first before depth is what the Method asks of the first audit, and it worked: the worst defect in the project is in the first filing.

Two observations that are not findings, recorded so a later audit does not re-derive them: e164RegexString marks the leading + optional, so bare digits validate, which is a deliberate leniency the README's "e164 formatted phone number" neither confirms nor denies; and iso4217_numeric is keyed by int, so the canonical zero-padded string form ("036") cannot be validated at all and a string field panics by the library's convention. Both are strictness questions for the owner, not defects against the current contract.

Learnings: probe batteries live under .jeffy/, whose dot prefix excludes it from `go list ./...` exactly as the underscore excludes _examples/, so a battery is a real main package that `go run ./.jeffy/probes/<name>` executes while `go test ./...` never compiles it. A battery that provokes a stack overflow must run each case in its own process, because the runtime throw kills the whole probe and hides every case after it. Batteries reproducing an open finding get no paths file until the finding is fixed, or they would fail the verify gate on every unrelated iteration.

Next: V-001, the cyclic-graph stack overflow.

## iter 2/10 | 9c2b995d-131932 | 2026-08-15 | V-001 | done

Task: V-001 (High, runtime, correctness) - a cyclic struct graph recursed until the goroutine stack was exhausted, killing the process with an unrecoverable `fatal error: stack overflow`.

Changed: validator.go (structIdent type, cycleGuardDepth const, cycleGuard and depth fields on validate, the guard in validateStruct), cache.go (recursive field on cStruct, typeReaches, computed once in extractStructCache), doc.go (a Self-Referential Structures section), validator_test.go (TestStructCycleTermination, TestTypeReaches), .jeffy/probes/_engine (rewritten as an asserting battery, plus its paths file now that the finding is closed).

Checkpoint: ef3e1d8b3d87f2dcca87a9cf1d793043afad3f26

Verification: the filed reproduction was the first command run and reproduced the fatal error. Acceptance check `go run ./.jeffy/probes/_engine` now exits 0, all 13 assertions passing. `go test -cover -race ./...` exits 0, 24 packages ok, root coverage 96.3% -> 96.4%. The new test fails against unfixed code, demonstrated by copying validator_test.go into a pristine tree built from the pre-run HEAD and running it there: exit 1 with the same `fatal error: stack overflow`, which is the differential evidence that the check is strong enough to fail.

Contract preserved: acyclic input is untouched. The guard skips a struct only when that exact (address, type) is already open on the current path, so the repeat visit it drops would have reported what the first visit already reported. Two probes pin the two ways this could have gone wrong: a 2000-node acyclic chain of the same recursive type still reports all 2000 errors, and a node referenced twice from one parent still reports both visits. A third pins the pooled validate struct: three consecutive validations of the same self-pointing node each report exactly one error, so guard state does not leak between calls.

Performance, which this project's own docs call a hot path: measured by interleaving two prebuilt test binaries, pre-fix and post-fix, over 8 alternating rounds, because non-interleaved runs on this host produced swings large enough to be meaningless - a first attempt reported +9% to +53% while the control benchmark moved with it. BenchmarkFieldSuccess is that control: it calls Var, which reaches traverseField directly and never enters validateStruct, so this diff cannot affect it. Interleaved, nothing moves: FieldSuccess p=0.505, StructSimpleSuccess p=0.205, StructComplexSuccess p=0.524, StructComplexFailure p=0.959, and B/op and allocs/op are identical on every benchmark with all samples equal.

Design note, because the first working version was rejected on evidence rather than taste. Marking a type recursive whenever it holds an interface field is the safe static reading, but it marks the benchmark's own TestString recursive through its Iface field, and that alone cost a statistically significant regression: one guarded struct is roughly three map operations, which is about 9% of StructComplexSuccess. The shipped guard therefore engages on two conditions instead: a type that is statically recursive ignoring interfaces, which is precise and catches the ordinary pointer, slice and map cycles immediately with an exact error set, or any struct past cycleGuardDepth=32, which is the safety net for a cycle that can only close at runtime through an interface. An ordinary struct pays one bool test and one integer compare and never touches the map.

Learnings: benchmark numbers on this host are only trustworthy interleaved; a control benchmark on an untouched code path is what tells a real regression from machine noise, and without one this iteration would have shipped a false 9% regression or reverted a good fix. A guard keyed on a type-level property belongs on cStruct in cache.go, which is built once per type, not recomputed in the executor.

Next: V-002, the four validators leaking opaque reflect panics.

## iter 3/10 | 9c2b995d-131932 | 2026-08-15 | V-002 | done

Task: V-002 (Medium, runtime, error handling) - four validators called a reflect kind accessor with no kind guard and leaked an opaque `reflect: call of reflect.Value.X on Y Value` panic naming neither the tag nor the field, and isPort additionally accepted only unsigned kinds while its documentation stated no type restriction.

Changed: baked_in.go (isPort, isSSN, isEIN, hasMultiByteCharacter), doc.go (the Port section now states the accepted kinds), validator_test.go (Test_port_validator_accepted_kinds, Test_string_validators_reject_non_strings), .jeffy/probes/_v002 (new known-answer battery with its paths file), .jeffy/probes/_breadth (its port cases, whose note this change invalidated).

Checkpoint: 21d6f3e56914de7f618dae75cfff06886edbe508

Verification: the filed reproduction ran first and reproduced all four sites. Acceptance check `go run ./.jeffy/probes/_kindsweep` now exits 0 - the same enumeration over 181 registered tags x 9 field kinds that reported 4 opaque reflect panics reports 0, with 42 tags still panicking by the library's own `Bad field type` convention. The new _v002 battery passes 32 known-answer cases covering both boundaries of the port range, every accepted kind, and the rejected ones. `go test -cover -race ./...` exits 0, 24 packages, coverage 96.4%. The new tests fail against unfixed code: copied into a tree built from this run's previous checkpoint, `Test_port_validator_accepted_kinds/string_ports` dies with `panic: reflect: call of reflect.Value.Uint on string Value`, which is the differential evidence the checks are strong enough to fail.

Class, not instances, per the Method's class rule. The enumeration is the kindsweep output rather than a grep of the source, so it is built by provoking the failure at every tag/kind pair rather than by scanning for accessor names, and it is recorded under Settled classes with the command that produces it.

Contract preserved, and it differs per family because the library has two established idioms and these four sites belonged to neither. isPort is a numeric validator, so it adopted the numeric kind switch that isLatitude and 33 other sites use, ending in `panic(fmt.Sprintf("Bad field type %s", field.Type()))` - the exact form used at all 34 existing sites, with the `%T`/Interface form appearing nowhere. ssn, ein and multibyte are string-regex validators whose siblings, isAlpha among them, call `fl.Field().String()` unguarded and simply return false for a non-string; each of the three was reading length through `field.Len()` before the regex, so replacing that with `len(field.String())` is bit-identical for strings, where the two are the same number, and turns a panic into an ordinary false for everything else. No previously valid input changes meaning at any of the four sites.

port's accepted inputs widened, which is a public behaviour change, so doc.go's Port section names the accepted kinds in the same iteration. The widening is strictly additive: string and signed-integer fields previously panicked, so nothing depended on the old behaviour, and `Port string` - the shape a port read from an environment variable or config file naturally has - now validates. Parsing is strict, via ParseUint, so "+80", " 80", "80x" and "-80" are invalid rather than coerced, and a negative signed value is invalid rather than wrapping to a huge unsigned one.

Batteries: this diff touched baked_in.go, doc.go and validator_test.go; _breadth and _v002 declare baked_in.go in their paths files and both exit 0, as do _engine and _misc.

Learnings: this library has two distinct idioms for a field whose kind a validator cannot handle - an explicit kind switch ending in the conventional panic, and an unguarded String() that yields false - so the right fix for a site with neither is the idiom its own family already uses, not a single rule applied across all of them. The assert package this project tests with has PanicMatches but no NotPanics; assert an absence of panic with a local recover that calls t.Fatalf.

Next: V-003, the 10 registered tags missing from the README tag table.

## iter 4/10 | 9c2b995d-131932 | 2026-08-15 | V-003 | done

Task: V-003 (Medium, docs, documentation) - 10 registered tags were absent from the README tag table that CLAUDE.md makes the registration convention, and 6 of those plus the eu_country_code alias appeared in neither README.md nor doc.go, so no shipped documentation described them.

Changed: README.md (10 tag rows plus the eu_country_code alias row, each placed beside its family), doc.go (sections for skip_unless, eth_addr_checksum, iso3166_1_alpha2_eu, iso3166_1_alpha3_eu, iso3166_1_alpha_numeric_eu and iso4217_numeric, plus the alias list), .jeffy/probes/_v003 (new known-answer battery with its paths file).

Checkpoint: 8fd120983b3e8cce07a23065fe10d9d7db8eb0b2

Verification: the filed reproduction ran first and listed the same 10 tags. Acceptance check now prints nothing - the comm of the registered tag set against the README table is empty - and a per-tag grep puts all 10 plus eu_country_code in both files. `go test -cover -race ./...` exits 0, 24 packages. All five batteries exit 0.

No description here was written from reading the source. The _v003 battery was built first and every sentence added to README.md and doc.go states something it executes: that base32 rejects lowercase and unpadded input, that a dns_rfc1035_label must start with a lowercase letter, must not end with a hyphen and is rejected at 64 characters but accepted at 63, that eth_addr_checksum rejects both the all-lowercase and the all-uppercase forms of an address eth_addr accepts, that the EU subsets reject US and reject GB, that iso3166_1_alpha_numeric_eu takes integer kinds and decimal strings while iso4217_numeric takes integer kinds only and panics on a string, that oneofci and noneofci fold case and panic on a non-string, and that the iscolor alias covers cmyk.

skip_unless needed a behavioural check before it could be described at all, because its name is misleading. A struct tagged `skip_unless=Mode strict,email` with Mode set to lenient still fails the email tag, so skip_unless does not skip the validations after it: it is an ordinary validator that passes when any listed field differs from its value and otherwise requires a value. Reading the three implementations side by side, its logic is identical to required_if, which differs only by additionally panicking on a duplicate param, and it is required_unless with one negation. The documentation added says what it does and states plainly that later tags still run; the duplication between skip_unless and required_if is a design question for the owner, not a defect against the current contract, so it is recorded here rather than filed.

Two documentation errors sat inside the exact lines this task edited and were corrected with it, both verified by the battery: the doc.go alias list gave iscolor as "hexcolor|rgb|rgba|hsl|hsla" while bakedInAliases has cmyk on the end, and the Iso3166-1 alpha-numeric section carried `Usage: iso3166_1_alpha3`, a copy-paste from the section above it.

The gofmt set is unchanged by this diff: `gofmt -l .` still returns exactly baked_in.go, doc.go and translations/ko/ko_test.go, and `gofmt -d doc.go` shows only the pre-existing double blank line that V-005 covers, so no new formatting debt was added to a file this iteration rewrote heavily.

Learnings: a tag's name is not evidence of its behaviour - skip_unless does not skip - so a documentation task has to run the tag before describing it, and the battery that proves the wording is the deliverable as much as the wording is.

Next: V-004, the Coveralls upload step gated on a Go version absent from the CI matrix.

## iter 5/10 | 9c2b995d-131932 | 2026-08-15 | V-004 | done

Task: V-004 (Medium, build-ci, developer experience) - the Coveralls upload was gated on `matrix.go-version == '1.24.x'` while the matrix held [1.25.x, 1.26.x], so the condition never matched, no coverage was uploaded, CI stayed green, and the README coverage badge presented stale data as current.

Changed: .github/workflows/workflow.yml (coverage moved out of the matrix job into its own job; the matrix job's test command dropped the coverage flags it was computing and discarding on all six combinations), .jeffy/probes/_v004 (new battery with its paths file), .jeffy/probes/_kindsweep and .jeffy/probes/_hostile (paths files, both having passed since their findings closed).

Checkpoint: 8e18a89f87a8471f2ffe22eb39ecef0cdcc9fa84

Verification: the filed reproduction ran first and reported the gate outside the matrix. git log on the workflow file identifies the exact regression and its cause: the gate had been hand-synced to the matrix three times - 909c504, 4a1bc2f, then surviving c325e92 because 1.24.x was still present - and d3f35da "Go 1.26 support" moved the matrix from [1.24.x, 1.25.x] to [1.25.x, 1.26.x] and moved the lint job's version, but left the gate on 1.24.x. That history is why the fix removes the duplicated constant instead of re-syncing it: re-syncing is the thing that has already failed once, silently.

The new battery asserts the structural property the failure violated - every `matrix.<key> == '<value>'` condition in every workflow names a value that job's matrix defines, and a coverage upload step exists. It fails against the unfixed workflow, run from a tree holding the previous commit's file: `FAIL workflow.yml:test: matrix.go-version == '1.24.x' against matrix ['1.25.x', '1.26.x']`, exit 1. It passes against the fixed one, where there is no matrix-gated condition left at all.

Both commands the workflow now runs were executed here: `go test -race ./...` exits 0 over 24 packages, and `go test -race -covermode=atomic -coverprofile=profile.cov ./...` exits 0 and writes an 8829-line profile opening with `mode: atomic`. The workflow parses under PyYAML and its three jobs resolve to the intended shape.

Stated honestly, because the environment fingerprint does not cover it: GitHub Actions cannot be executed on this host, so this fix is verified structurally and by running its commands locally, not by observing a real CI run or a real upload to Coveralls. What that leaves unverified is the upload itself. One exposure is unchanged rather than introduced: the upload step runs on pull_request events, including from forks, exactly as it did when the gate last matched.

Verify gate green, 24 packages. All eight batteries exit 0.

Learnings: a battery does not have to be a Go program - .jeffy/probes/_v004 is a Python script, so the convention is that a battery directory holds either main.go, run with `go run ./.jeffy/probes/<slug>`, or check.py, run with `python3 .jeffy/probes/<slug>/check.py`. A CI step whose condition duplicates a value from its own matrix is a silent-failure shape: when the two drift the step stops running and nothing goes red, so the fix is to delete the coupling rather than correct the constant.

Next: V-005, the three files failing gofmt, which is the last open task.

## iter 6/10 | 9c2b995d-131932 | 2026-08-15 | SWEEP | done

Task: with Now and Next empty, the 31 unswept Surface inventory rows outrank the one open Low, so this iteration swept every row it could properly evidence. Eight rows flipped; one High was surfaced and filed.

Changed: PLAN.md (eight inventory rows flipped to swept at 672074961c3b5ce9de3f40bd9aecd92de4397c8d), BACKLOG.md (V-006 filed under Now), .jeffy/probes/_sweep1 and .jeffy/probes/_sweep2 (new batteries, _sweep2 with a paths file).

Checkpoint: eb90c7fc0de072f5bdc38cd3eda6457386bb9f81

Verification: rows swept are bi-hash, bi-uuid, bi-color, bi-charclass and bi-encoding by _sweep1, and bi-compare, bi-membership and regexes by _sweep2. Expectations were written from the standard each tag names rather than from the regex behind it, so a disagreement between the two surfaces here instead of being mirrored back - which is exactly what happened with bi-color. The parameterised families meet the two-operand rule explicitly: every comparison operator is driven at two operands that disagree and at both sides of its boundary, over string rune counts, signed and unsigned integers, floats, slice and map lengths and time; every membership tag is driven at two parameter values that disagree, including the quoted-parameter and numeric-member forms and unique in its bare, map and =Field forms, where =Name and =Code give opposite verdicts on the same slice. The regexes row is evidenced by driving 71 regex-backed tags concurrently on 8 goroutines under `go run -race`, which reaches MustCompile for every pattern and puts the sync.Once in lazyRegexCompile under the race detector; it reported no race.

V-006 (High, runtime, correctness) filed, and the sweep found it because the expectation came from CSS rather than from the pattern. The alpha group in rgbaRegexString and hslaRegexString is `(?:0.[1-9]*)|[01]`, and that dot is an unescaped any-character. The verdict is wrong in both directions: `rgba(0,0,0,0X)` and the same with 0x, 09, 00, `0.`, `0 ` and `0,` are all accepted as valid alpha, while `rgba(0,0,0,0.05)` and `rgba(0,0,0,1.0)` are rejected. hsla is identical. Filed at High rather than Medium because this library's entire output is a validation verdict, the validated value is adversarial by the Operating envelope, and 0.05 is an ordinary CSS alpha rather than an edge case; 18 assertions in _sweep1 now pin it, which is why that battery exits 1 and carries no paths file yet.

Three families came back clean with no finding at all, and the negative result is worth recording so a later sweep does not redo it: the ten hash tags are exact-length lowercase hex and reject uppercase, one short, one long and non-hex; the uuid tags separate correctly by version nibble, enforce the [89ab] variant on v4 and v5, and the plain forms are lowercase-only while the _rfc4122 forms accept both cases; the encoding tags keep the base64 and base64url alphabets properly disjoint.

Stall check: this iteration changed no file outside PLAN.md, BACKLOG.md, JOURNAL.md and .jeffy/, which the stall rule names. It is not a stall, because a BACKLOG item changed state - V-006 was added under Now - and eight inventory rows moved, which is the ledger signal the rule is computed from.

Verify gate green, 24 packages. Nine of ten batteries exit 0; _sweep1 exits 1 by design while V-006 is open.

Learnings: write sweep expectations from the standard a tag names, never from the regex implementing it, or the battery just restates the code and certifies its bugs - bi-color passed a liveness reading and failed a CSS one. A battery can be run under the race detector with `go run -race ./.jeffy/probes/<slug>`, which is what makes a lazily-compiled shared table testable from outside the package.

Next: V-006, the rgba and hsla alpha regex, now the only open High.

## iter 7/10 | 9c2b995d-131932 | 2026-08-15 | V-006 | done

Task: V-006 (High, runtime, correctness) - the alpha group in rgbaRegexString and hslaRegexString was `(?:0.[1-9]*)|[01]`, whose dot was an unescaped any-character, so the verdict was wrong in both directions.

Changed: regexes.go (the alpha group in both patterns, now `(?:0(?:\.\d+)?|1(?:\.0+)?)`), validator_test.go (TestRGBAAndHSLAAlphaChannel), .jeffy/probes/_sweep1 (corrected expectations plus its paths file, now that the finding is closed), BACKLOG.md, PLAN.md.

Checkpoint: 38ebad0702c2bafa0f18d00ef243c081786da94b

Verification: the filed reproduction ran first, 18 failures. The acceptance check `go run ./.jeffy/probes/_sweep1` now exits 0. The new test fails against unfixed code, run from a tree built at this run's previous checkpoint: exit 1, and the same battery run there reports 20 failures. `go test -cover -race ./...` exits 0, 24 packages, coverage 96.4%. All ten batteries exit 0, including _breadth, _hostile and _sweep2, which declare regexes.go in their paths.

The class was enumerated before fixing, by walking every `*RegexString` literal and reporting dots that sit outside a character class and are not preceded by a backslash rather than by grepping for a character. That returns 4: rgba and hsla, which are the same defect written twice, and dataURI and HTML, where the dot is a deliberate any-character in a media-type matcher and a tag-attribute matcher. Only the first two were changed, so the class is closed with two sites fixed and two examined and left alone, and it is recorded that way under Settled classes.

One case in the filed finding was wrong and the fix corrected the battery rather than the code. V-006 listed `rgba(0,0,0,0 )` among the invalid forms being accepted. It is not: `\s*` sits before the closing paren by design, exactly as it does around every separator, and an existing test pins `rgba( 0,  31, 255, 0.5)` as valid. So six of the seven listed forms were genuine - 0X, 0x, 09, 00, `0.` and `0,` - and the seventh was my own misreading. The battery now asserts whitespace tolerance positively instead of forbidding it.

Contract preserved: every alpha value the old pattern accepted that is genuinely valid CSS is still accepted, which the existing suite pins independently at 0.5, 0.12, 1 and 0 across four test functions, all still green. The change is a narrowing on the invalid side - 01 and .5 are now rejected too, both correctly, since a leading zero followed by a digit is not a number in [0,1] and the bare-dot form was never accepted by this pattern - and a widening on the valid side for 0.05, 0.999, 1.0 and 1.00.

Surface inventory: regexes.go changed, which makes every regex-backed row recorded at 672074961c3b5ce9de3f40bd9aecd92de4397c8d stale. Rather than leave six rows unswept, the two batteries that own them were re-run against the fixed tree and pass, so bi-hash, bi-uuid, bi-color, bi-charclass, bi-encoding and regexes are re-recorded at this iteration's checkpoint. That is what keeping the battery instead of rebuilding it buys: the re-sweep cost one command.

Learnings: enumerate a regex class by parsing the pattern rather than grepping for the character, because a dot inside a character class and an escaped dot are both fine and only a walk that tracks those states can tell the three apart. When a battery disagrees with the code after a fix, check which one is wrong before touching either: here the battery was.

Next: V-005, the gofmt files, the last open task.

## iter 8/10 | 9c2b995d-131932 | 2026-08-15 | SWEEP | done

Task: Now and Next were empty, so the 14 remaining unswept rows outranked the open Low again. Nine rows swept; one Medium surfaced and filed.

Changed: PLAN.md (nine inventory rows flipped to swept at d0fa7101790d5af6641989476150000f0507e441), BACKLOG.md (V-007 filed under Next), .jeffy/probes/_sweep3 (new battery).

Checkpoint: 219129c38bfcac04b20ba8e6598f85541c035fe4

Verification: rows swept are entry-struct, entry-var, entry-map, registration, struct-level, field-level, errors, bi-required and bi-crossfield. The two-value rule is met by construction on the parameterised ones: StructPartial is driven at three different field selections that produce three different error sets and StructExcept at two, StructFiltered at two filters that skip different fields, the four registration knobs each at two configurations that change the reported name or the verdict - two RegisterValidation implementations of the same tag name give opposite answers on the same input - all 15 conditional tags at both states of their condition, and all 14 cross-field tags at both verdicts, the same-struct forms through struct fields and the cross-struct forms through VarWithValue. `go test -cover -race ./...` exits 0 over 24 packages. Ten of eleven batteries exit 0; _sweep3 exits 1 on the six V-007 cases alone, which is what makes the other rows it certifies trustworthy - everything else in it passes.

V-007 (Medium, runtime, error handling) filed. InvalidValidationError.Error() returns `"validator: (nil " + e.Type.String() + ")"` whenever Type is non-nil, so the only misuse-signalling path in the API describes a value that is not nil as nil: Struct(42) reports `validator: (nil int)`, and the same for string, map, slice, float64, bool and time.Time. Only the untyped-nil and nil-pointer cases are accurate, and both were checked and are. Filed at Medium rather than Low with the rationale recorded here: it is not phrasing, it states a false fact about the caller's value, and it does so at the one place a developer looks after making a mistake, which is the same user-error surface reasoning that put V-002 at Medium. The battery asserts the property - no non-nil value is described as nil - rather than exact prose, so the fix can choose its own wording.

Two expectations in the battery were mine to correct, not the code's. The struct-level case used Name and Email both set to "same", which fails the email tag as well as the struct-level rule, so the assertion now uses a valid address and isolates the rule under test. The InvalidValidationError case originally asserted a specific replacement message before the fix existed, which would have pinned wording nobody had chosen; it asserts the property instead.

Stall check: this iteration changed only PLAN.md, BACKLOG.md, JOURNAL.md and .jeffy/, all named by the stall rule, but it is not a stall - V-007 was added under Next, which is a ledger state change, and nine inventory rows moved.

Learnings: when a sweep battery and the code disagree, the battery is wrong about as often as the code, and both cases this iteration were mine; isolate the assertion so only the rule under test can trip it. Pin an open finding as a property the fix must satisfy, not as the exact output the fix should produce, or the battery dictates wording before anyone has designed the fix.

Next: 14 rows remain unswept and V-007 and V-005 are open. Iteration 9 sweeps what it can; iteration 10 is the wrapup and handoff, since the run cannot converge with 14 rows unswept.

## iter 9/10 | 9c2b995d-131932 | 2026-08-15 | V-007 | done

Task: V-007 (Medium, runtime, error handling) - InvalidValidationError.Error() described any non-nil value as nil, so the API's only misuse-signalling path stated a false fact about the caller's argument.

Changed: errors.go (the non-nil branch now reads `validator: (invalid <type>)`), validator_test.go (the two assertions that encoded the old message), .jeffy/probes/_sweep3 and .jeffy/probes/_engine (the expectations they pinned on it).

Checkpoint: 34834afa3d0582650a4425e6c83871fd6a5936e1

Verification: the filed reproduction ran first, 6 failures. The acceptance check `go run ./.jeffy/probes/_sweep3` now exits 0. `go test -cover -race ./...` exits 0 over 24 packages at 96.4% coverage, and all eleven batteries exit 0 for the first time this run.

Two existing tests had to be changed, so here is the differential evidence the rule asks for. Both passed non-nil values and asserted that the library called them nil: TestInvalidStruct passes `s.Test`, a string holding "1", and asserted `validator: (nil string)`; the StructFiltered case passes `&dt` taken from time.Now(), a non-nil pointer, and asserted `validator: (nil *time.Time)`. Both were green only because of the defect this task fixes. The change to each is the single word, and `git diff validator_test.go` filtered to changed assertions returns exactly those two lines and nothing else. The untyped-nil path is untouched: errors.go still returns `validator: (nil)` when Type is nil, and the three assertions in validator_test.go that pin it, plus the two in the batteries, all still pass unchanged. A repository-wide grep for the message text finds no other dependency on it in any .go or .md file.

Contract: this changes public error text, which callers are told to type-assert rather than string-match - doc.go and README both direct users to `err.(validator.ValidationErrors)` and to check for InvalidValidationError as a type, and neither quotes the message - so the change is confined to the human-readable half. The word chosen is "invalid" because it matches the type name and is true for every case the branch can reach. The nil-pointer case gives up a more specific word for a uniformly true one: `Struct((*T)(nil))` now says `invalid *main.T` rather than `nil *main.T`, which is accurate but less pointed. Carrying nil-ness properly would mean adding a field to an exported struct to improve one word, and that trade was not worth it.

Surface inventory: errors.go changed, so the errors row recorded at d0fa7101790d5af6641989476150000f0507e441 went stale and was re-swept by re-running _sweep3 against the fixed tree, then re-recorded at this iteration's checkpoint.

Learnings: an assertion in an existing suite is not evidence that the behaviour is correct - two tests here pinned a message that called a non-nil string nil, and the sweep found it precisely because the battery asserted a property rather than copying what the code already did.

Next: this is the last iteration before the budget ends. 14 rows remain unswept, so the run cannot converge; iteration 10 writes the wrapup and handoff.

## iter 10/10 | 9c2b995d-131932 | 2026-08-15 | WRAPUP | done

Task: final iteration of the budget. 14 rows were unswept at its start, so convergence was out of reach and no fix was started that could not finish. Two rows were swept, one Medium filed, and the handoff written.

Changed: PLAN.md (nonstandard and examples flipped to swept at 92e1e75fb1fe25b24c2a81c4b88c75a8a860405d), BACKLOG.md (V-008 filed under Next), .jeffy/probes/_examples (new battery), .jeffy/probes/_misc (NotBlank extended to every branch of its kind switch).

Checkpoint: 26d7139a8089f9d18a30a6d0e12061c35aa63778

Verification: `go test -cover -race ./...` exits 0 over 24 packages. Eleven of twelve batteries exit 0; _examples exits 1 because it pins the open V-008 and therefore carries no paths file, by the rule this run wrote for itself in iteration 1. The nonstandard row is evidenced by 20 known answers covering all four branches of NotBlank's kind switch, including the four separator characters its string branch trims. The examples row is evidenced by compiling all 12 trees, each in the module that owns it.

V-008 (Medium, docs, developer experience) filed: 2 of 12 example trees do not build, and the underscore prefix that keeps _examples out of `go list ./...` is exactly why CI has never noticed. gin-upgrading-overriding imports gin/binding, which the module does not require; validate_fn is a nested module whose go.mod is stale and fails with `go mod tidy`. Both were built at ac4c1ba, the commit before this run's first checkpoint, and fail there identically, so neither is damage this run did.

A measurement error is worth recording because it nearly became a false finding. The first two builds of validate_fn were run as `go build ... 2>&1 | head -3; echo exit=$?`, and that status is head's, not the build's, so a failing build read as exit 0 and then as a success I attributed to the checkout directory name. Re-run with the output redirected to a file, the true status is 1 in both checkouts and for two different reasons. The iteration prompt warns about exactly this for the Verify command; it applies to every command whose status is being read, and this run has now made the mistake once.

The directory-name fragility is real and separately verified: validate_fn carries `replace ... => ../../../validator`, and in a checkout named renamed-checkout the build fails with `replacement directory ../../../validator does not exist`. That is recorded in V-008 rather than filed separately, because one `go mod tidy` and one path edit close both.

Handoff for the next run. The ledger holds V-008 (Medium, docs) and V-005 (Low, build-ci); V-005 is the carried Low, gofmt failing on baked_in.go, doc.go and translations/ko/ko_test.go, none of which CI can catch because .golangci.yaml declares no formatters section. 12 of 31 inventory rows are unswept: engine-traverse, tag-cache, util-ns, bi-net-uri, bi-fs, bi-netaddr, bi-iso, bi-ident, bi-validatefn, trans-en, trans-locales and docs. The five biggest are the tag families, and the pattern that worked twice is to write the battery from the standard each tag names before reading its regex. Twelve batteries under .jeffy/probes/ are the instrument for re-sweeping; ten carry paths files and run automatically when the code they own changes, and the two without them, _examples and any battery pinning a future open finding, are deliberate.

Learnings: read a command's exit status from the command, never from a pipeline ending in head or tail - this run wrote that rule down in iteration 1 for the Verify command and then broke it on a build in iteration 10. A battery that pins an open finding must not carry a paths file, or it converts one open task into a failing gate on every unrelated iteration.

Next: nothing in this run. The budget is spent and the run ends out of budget, not converged.

## iter 1/10 | 76637255-142056 | 2026-08-15 | V-008 | done

Task: V-008 (Medium, docs, developer experience) - 2 of the 12 trees under _examples/ did not compile, and the underscore prefix that keeps them out of `go list ./...` is why CI never noticed.

Changed: _examples/validate_fn/go.mod and go.sum (module path, go directive, replace target, retidied), _examples/gin-upgrading-overriding/go.mod and go.sum (new nested module), .jeffy/probes/_examples/paths (new).

Checkpoint: 31feb085a7b462c061a89d75de2ef8445aeb82d4

Verification: the filed reproduction ran first and reported 10/12 with the two named failures. The acceptance check `python3 .jeffy/probes/_examples/check.py` now exits 0 at 12/12 build, in 6.1s with a warm module cache. `go test -cover -race ./...` exits 0 over 24 packages at 96.4% root coverage.

Each tree needed a dependency the root module does not require, so each became a nested module rather than the root gaining the dependency: gin-upgrading-overriding needs github.com/gin-gonic/gin, and putting a web framework into a validation library's go.mod would land in the dependency graph of every consumer of v10. validate_fn was already nested and only needed repair. Both carry `replace github.com/go-playground/validator/v10 => ../..`, and `go list -m github.com/go-playground/validator/v10` inside each prints `=> ../..`, so both compile against this working tree rather than the proxy's release.

The root module is untouched, which is the property that matters here: `git status --porcelain go.mod go.sum` prints nothing, and the Verify run served every package from cache because no file the root module compiles was changed.

The checkout-directory fragility V-008 recorded is closed and verified the way it was filed. The tree was copied to /tmp/renamed-checkout, a directory not named validator, and the battery run there reports 12/12 and exits 0; the old `replace ... => ../../../validator` failed there with `replacement directory ../../../validator does not exist`.

validate_fn's go.mod also declared the module path `github.com/peczenyj/validator/_examples/validate_fn`, a contributor fork's path left behind. It is now `github.com/go-playground/validator/v10/_examples/validate_fn`. Nothing imports it - it is a main package under an underscore directory - so the rename has no callers to break.

Contract: no public interface or observable library behaviour changed. README links both example directories by URL and both directories keep their paths, so the two links in README.md still resolve.

Surface inventory: the examples row's implementing code changed, so the row recorded at 92e1e75fb1fe25b24c2a81c4b88c75a8a860405d went stale and was re-swept by re-running the battery against the fixed tree, then re-recorded at this iteration's checkpoint. No other row's code was touched.

The _examples battery now carries a paths file, which iteration 10 of the previous run deliberately withheld while V-008 was open, by the rule that a battery pinning an open finding converts one open task into a failing gate on every unrelated iteration. The finding is fixed, so the guard is now wanted: it covers _examples/*/*.go, go.mod and go.sum, which is the surface the battery actually certifies.

Stall check: not a stall - four files outside the state-file set changed and V-008 was removed from Next.

Learnings: an example that needs a dependency the library itself does not require belongs in its own nested module with a replace pointing at ../.., never in the root go.mod; a replace that walks up past the checkout root and names it by repository name only resolves in a directory that happens to carry that name.

Next: Now and Next are empty. The queue puts the 12 unswept inventory rows above the open Low V-005, so iteration 2 sweeps rows - engine-traverse, tag-cache and util-ns are the three that share the _engine battery and are the natural first batch.

## iter 2/10 | 76637255-142056 | 2026-08-15 | SWEEP | done

Task: Now and Next were empty and 12 rows were unswept, so sweeping was the top of the queue. Four rows swept; one Medium surfaced and filed.

Changed: PLAN.md (four inventory rows flipped), BACKLOG.md (V-009 filed under Next), .jeffy/probes/_sweep4 (new battery, 52 cases), .jeffy/probes/_sweep5 (new battery, 22 cases across two builds), .jeffy/probes/_v009 (new reproduction).

Checkpoint: 7ba6ba49850b5898a6b23a752192c40645eb867b

Verification: rows swept are engine-traverse, tag-cache, util-ns and bi-validatefn. `go test -cover -race ./...` exits 0 over 24 packages at 96.4% root coverage. All fourteen closed batteries exit 0; _v009 exits 1 on its single documentation case, which is the open finding it pins.

Expectations for both new batteries were written from doc.go before the code was run, which is the rule that made this iteration worth anything. _sweep4 reproduces doc.go's own worked examples verbatim: the two Dive examples with their per-level commentary, both Keys & EndKeys examples, and the stated distinctions between omitempty, omitnil and omitzero driven on the same three values so the differences are differential rather than three separate local claims. The sharpest of those is a non-nil pointer to the zero value: omitnil runs the rule behind it and omitzero skips it, exactly as documented. structonly and nostructlevel are separated by a registered struct-level rule, and the observed split matches the doc - structonly suppresses the nested fields and keeps the struct-level rule, nostructlevel suppresses both.

_sweep5 runs one case table under both builds of the isValidateFn pair. The Environment fingerprint in PLAN.md records that the Verify command compiles only no_validate_fn.go, so the novalidatefn variant was ungraded; the battery now compiles and runs it, and doc.go's promise that any usage of validateFn panics under that tag holds for all eleven cases.

Five expectations were mine to correct rather than the code's. Two assumed Tag() reports one alternative of an or-expression when it reports the whole expression, which this battery already asserted correctly elsewhere. One assumed a map key of array type reports without its element index. Two more were a data error rather than an expectation error: with WithRequiredStructEnabled a zero nested struct trips required on the struct field itself, so nothing downstream of it is reached, and the structonly and nostructlevel cases were measuring that instead of what they meant to measure. Inner gained a rule-free second field so the struct can be non-zero while the field under test is unset.

V-009 (Medium, docs, documentation) filed. Var and VarCtx discard the tag whenever the value is a struct not convertible to time.Time: traverseField's first loop guard drops ct when the value is a nested struct and the cField carries no name, which is exactly the Var shape. Var(Empty{}, "required") returns nil, and Var(Tagged{}, "required") returns Tagged.A=required - a verdict about rules the caller did not ask for. The tag is genuinely parsed first, since an unknown tag still panics, so this is not early rejection. A time.Time value and a pointer both keep their tag, which is why one spot check does not reveal it.

Severity rationale, since this could be argued either way. Not High: reaching it requires choosing Var for a value the function's own doc comment says should go to Struct. Not Low: the swallow is silent, and the existing warning - "unforeseen validations will occur" - predicts the opposite of the observed behaviour, which for Empty{} is that no validation occurs at all. A reader following that warning would look for extra validations and never suspect the tag was dropped. v10 compatibility rules out changing the behaviour, and the executor's own comment shows the struct fan-out is deliberate and load-bearing for VarWithValue, so the fix is documentation.

The finding surfaced in the bi-validatefn sweep rather than in entry-var, because doc.go promises that validateFn panics under the novalidatefn build and Var(struct, "validateFn") did not panic in either build. That case was removed from _sweep5, which is about isValidateFn and not about Var, and re-pinned in _v009 as a property the fix must satisfy. entry-var stays swept: its code has not changed, and this is new evidence rather than a stale sweep.

_sweep4 and _sweep5 carry paths files - validator.go, cache.go, util.go for the first, the isValidateFn build pair for the second. _v009 deliberately carries none while V-009 is open.

Stall check: not a stall - three battery directories were added and V-009 was filed under Next.

Learnings: run a sweep case against more than one value shape before believing it, since Var keeps its tag for time.Time and for a pointer and drops it only for a plain struct, so a one-value probe certifies the opposite of the truth. A battery that needs a build variant the Verify command excludes should carry its own build-tagged constant and a check.py that runs every build, because the excluded variant is the one nothing else grades.

Next: 8 rows remain unswept - bi-net-uri, bi-fs, bi-netaddr, bi-iso, bi-ident, trans-en, trans-locales and docs. V-009 is Medium and outranks them, so iteration 3 fixes V-009 and iteration 4 returns to sweeping.

## iter 3/10 | 76637255-142056 | 2026-08-15 | V-009 | done

Task: V-009 (Medium, docs, documentation) - the Var family parses the tag and then discards it for a plain struct value, and the doc comment warning about it predicted the opposite failure.

Changed: validator_instance.go (six WARNING blocks rewritten), .jeffy/probes/_v009 (extended to the full enumeration, paths file added), .jeffy/probes/_sweep3 (paths file added), BACKLOG.md (V-009 closed, class recorded under Settled classes), PLAN.md (four rows re-recorded).

Checkpoint: 850ecda258633faf586d592b66ae7ef58d79ae71

Verification: the filed reproduction ran first and failed on its documentation case. The acceptance check `go run ./.jeffy/probes/_v009` now exits 0 over 14 cases. `go test -cover -race ./...` exits 0 over 24 packages at 96.4% root coverage. All fifteen batteries exit 0, which is the first iteration this run where none is pinning an open finding.

The filing named Var and VarCtx. The enumeration the class rule demands says that was two sixths of it: the identical WARNING block appears 6 times in validator_instance.go, and walking each occurrence forward to the function declaration that follows resolves them to Var, VarCtx, VarWithValue, VarWithValueCtx, VarWithKey and VarWithKeyCtx. Driving all six on the same plain struct splits them cleanly. Var, VarCtx, VarWithValue and VarWithValueCtx return nil - the tag dropped. VarWithKey and VarWithKeyCtx return K=required - the tag applied to the struct as a whole, and not replaced by the struct's own field tags. The split has a cause: the executor's guard drops the tag when the value is a nested struct and the cField carries no name, and the key supplied to the VarWithKey pair is exactly that name. So one warning was wrong on four functions and describing the wrong thing on the other two, and the fix had to be written per group rather than copied six times.

Contract: no behaviour changed, only comments. The public signatures, the accepted inputs and every verdict are identical - the acceptance battery asserts the behaviour of all six before it asserts anything about the prose, and those behaviour cases pass identically before and after the edit. `gofmt -l validator_instance.go` prints nothing.

The documentation assertion reads the comment the way a reader does. Asserting a sentence against the raw file failed even after the sentence was written, because a Go doc comment wraps and the sentence spanned two lines. The battery now joins consecutive comment lines before matching, which is what godoc renders, so the check tests the text rather than the line breaks.

The removed phrase was grepped for repository-wide. "unforeseen validations will occur" no longer appears in any .go file; the three remaining hits are this journal's iteration 2 entry, which is history and is not rewritten, the BACKLOG line deleted by this iteration, and the battery case that asserts the phrase is gone.

Surface inventory: validator_instance.go is the implementing code for entry-struct, entry-var, entry-map and registration, so all four went stale on this edit. They were re-swept by re-running _sweep3 against the changed tree and re-recorded at this iteration's checkpoint. field-level, struct-level and errors are unaffected - field_level.go, struct_level.go and errors.go were not touched.

_sweep3 had no paths file, left over from iteration 8 of the previous run when it was pinning the then-open V-007; V-007 closed in iteration 9 and the file was never added. It now declares the five sources behind the rows it certifies, so the gap that let this iteration edit validator_instance.go without any battery claiming ownership is closed. _v009 gains one too, now that its finding is fixed.

V-009 closed. Recorded under Settled classes with its enumerating walk, since the fix covers every site the class appears at.

Stall check: not a stall - validator_instance.go changed and V-009 was removed from Next.

Learnings: assert documentation by joining a Go doc comment's lines before matching, never against the raw file, or the assertion fails on where the comment wraps rather than on what it says. When one comment block is repeated across several functions, resolve each occurrence to the function that follows it before believing any of them behave alike - two of these six did not, and copying one corrected sentence to all six would have replaced a wrong warning with a different wrong warning.

Next: Now and Next are empty, so the 8 unswept rows outrank the open Low V-005. Iteration 4 sweeps; bi-net-uri, bi-netaddr and bi-fs are the natural batch, and bi-fs is the one with an adversarial envelope classification.

## iter 4/10 | 76637255-142056 | 2026-08-15 | SWEEP | done

Task: Now and Next were empty and 8 rows were unswept, so sweeping was the top of the queue. Three rows swept; one High and one Medium surfaced and filed.

Changed: PLAN.md (three inventory rows flipped), BACKLOG.md (V-010 filed under Now, V-011 under Next), .jeffy/probes/_sweep6 (new battery, 119 cases, with a paths file), .jeffy/probes/_v010 and .jeffy/probes/_v011 (new reproductions, neither with a paths file while its finding is open).

Checkpoint: 6a27a8d9dce98235818a73612839bee3336d47ad

Verification: rows swept are bi-net-uri, bi-netaddr and bi-fs, covering 38 tags. `go test -cover -race ./...` exits 0 over 24 packages. All sixteen closed batteries exit 0; _v010 and _v011 exit 1 on the findings they pin.

Expectations came from the standard each tag names, per the rule this project already wrote for itself. RFC 952 and RFC 1123 are separated by the case that separates them in the RFCs - a label starting with a digit, which 952 forbids and 1123 allows - so the two tags are told apart by the difference that is their reason for existing rather than by two unrelated values. RFC 1035 section 2.3.1 gives the label form and its 63-character ceiling, both sides driven. RFC 2141 gives urn its three required parts. The *_addr tags call net.Resolve*Addr, which performs DNS on a hostname, so every address case uses a numeric literal and the battery needs no network.

bi-fs is the row the Operating envelope classifies adversarial, since these tags stat a path taken from the validated value. Alongside the verdicts, four hostile shapes were driven - an 8000-character path, a NUL byte, a 5000-character name and a traversal path - and each returns a verdict rather than a panic or a hang.

V-010 (High, runtime, correctness) filed. matchesMIMEType compares the detector's raw output against the tag parameter, and the detector reports text types with a charset parameter, so it splits `text/plain; charset=utf-8` on the slash and compares the subtype `plain; charset=utf-8` to `plain`. The documented `type/subtype` form therefore cannot match any parameterised type. The enumeration is generated rather than listed: nine real payloads are written to disk, detected, and driven with the `type/subtype` form built from their own detected type. Four of the nine detect with a parameter - plain text, html, xml and javascript - and all four are rejected; the five without a parameter are accepted, and `type/*` is accepted for all nine. Filed High rather than Medium because a plain text file failing `mimetype=text/plain` is a wrong result on the most ordinary input the tag has, not an edge case, and the tag's other documented form working is what has kept it hidden.

V-011 (Medium, runtime, correctness) filed. unix_addr accepts every string. isUnixAddrResolvable delegates to net.ResolveUnixAddr with the network hardcoded to "unix", and that call reports an error only for an unknown network, so the field value cannot influence the verdict. The claim is evidenced by a generated corpus of 2060 values - empty, control bytes, NUL-only, non-UTF8, and paths up to 512 characters - of which 0 are rejected, rather than by the handful of shapes I first thought of. Filed Medium on the same reasoning as V-009: a rule the developer asked for silently never applies. Not High, because nothing downstream is corrupted; the cost is a check that is not there.

Four of my expectations were wrong and are worth recording, because three of them were the same mistake. e164 was asserted to require the leading +, which E.164 does not - the + is the international prefix notation, and doc.go's example shows one without requiring it. The battery now pins what E.164 does fix: 15 digits accepted, 16 rejected, a country code starting 0 rejected. The traversal case asserted that `../../../../../../etc/shadow` is rejected, but that path resolves to a file that exists on this host, so the tag was right and the case now uses a name that cannot exist. The other two were the findings above, asserted correctly and failing for real.

The mimetype and unix_addr cases were removed from _sweep6 and re-pinned in their own batteries, so _sweep6 can carry a paths file - baked_in.go and regexes.go - while the two reproductions stay outside the gate until their findings close. _sweep6 keeps the mimetype forms that do work, driven at both verdicts.

Stall check: not a stall - three battery directories were added and two findings were filed.

Learnings: when a tag delegates to a standard library call, check that the call can fail at all before believing the tag validates anything - unix_addr's resolver cannot return an error for any field value, and no single-value probe would have shown that. Build the enumeration behind a class finding by generating it rather than listing it: the nine-payload mimetype table found javascript detecting as text/plain, which no hand-written list of text types would have included.

Next: V-010 is High and outranks everything, so iteration 5 fixes it and iteration 6 takes V-011. 5 rows remain unswept - bi-iso, bi-ident, trans-en, trans-locales and docs. The docs row already has one lead: origin, http_url and https_url are in the README tag table but have no doc.go section, which that row's sweep should confirm and file.

## iter 5/10 | 76637255-142056 | 2026-08-15 | V-010 | done

Task: V-010 (High, runtime, correctness) - the mimetype tag could not match the documented type/subtype form for any media type the detector reports with a parameter, so mimetype=text/plain rejected every plain text file.

Changed: baked_in.go (new mediaType helper, applied at detectFileMIMEType and to the tag side in matchesMIMEType), validator_test.go (four cases added to TestMIMETypeValidation), BACKLOG.md (V-010 closed, class recorded), PLAN.md (thirteen rows re-recorded), .jeffy/probes/_sweep3 (paths file extended with baked_in.go).

Checkpoint: 64b8a1fdeb8e70defa51ea806154b4d80d155ab2

Verification: the filed reproduction ran first and failed on its four parameterised payloads. The acceptance check `go run ./.jeffy/probes/_v010` now exits 0 over all 22 cases. `go test -cover -race ./...` exits 0 over 24 packages at 96.4% root coverage. All seventeen closed batteries exit 0; _v011 exits 1 on the finding it still pins.

The fix normalises at the boundary rather than at the comparison. detectFileMIMEType is the single place the detector's string enters this library, and it now returns the media type with any parameter stripped, so both of its callers are covered by one change. `grep -n detectFileMIMEType baked_in.go` returns 2 call sites: isMIMEType, which compares through matchesMIMEType, and isImage, which looks the string up in a 24-entry map. isImage was not observably broken and I checked rather than assumed: a payload was written for each text-shaped image format in that map - svg, the three portable pixmap variants and xpm - and all five detect without a parameter, so every map key was reachable before this change and still is. Fixing it at the boundary means it stays reachable if the detector ever starts emitting a charset for svg.

The tag side is normalised separately, inside matchesMIMEType, because a caller may write the parameter out in full. Without that, stripping only the detected side would have turned `mimetype=text/plain; charset=utf-8` from working into failing, and the battery asserts that case precisely to stop a one-sided fix.

Differential evidence for the four new test cases, since a test that passes on unfixed code proves nothing. baked_in.go was stashed and `go test -run TestMIMETypeValidation ./...` re-run against the unfixed tree: it exits 1 on 'detected type carrying a parameter matches type/subtype'. The stash was popped and baked_in.go compared byte for byte against a copy taken before the stash, confirming the fix was restored intact. The other three cases guard the directions a careless fix would break - the type/* form, an explicitly parameterised tag, and a genuinely different subtype still being rejected.

Contract: no signature changed and no tag gained or lost a name. The observable change is confined to verdicts that were wrong: a file whose detected type carries a parameter now matches its own type/subtype. Nothing that matched before stops matching, which the pre-existing TestMIMETypeValidation cases for image/png, image/jpeg, image/* and the malformed `mimetype=image` param all confirm, unchanged.

Surface inventory: baked_in.go is the implementing code for thirteen swept rows, so all thirteen went stale on this edit - bi-required, bi-compare, bi-crossfield, bi-charclass, bi-color, bi-encoding, bi-hash, bi-uuid, bi-membership, bi-net-uri, bi-netaddr, bi-fs and regexes. Every battery certifying them was re-run against the changed tree and each row re-recorded at this iteration's checkpoint, so the rows carry executed evidence rather than a bookkeeping assumption.

_sweep3 certifies bi-required and bi-crossfield, both implemented in baked_in.go, but its paths file did not name that file, so this iteration's edit would not have triggered it. baked_in.go was added. That is the second paths gap this run has closed, both found by asking which battery owns the file being edited rather than by reading the paths files.

gofmt reports baked_in.go and doc.go as unformatted. Both predate this iteration, verified by stashing the change and re-running gofmt at HEAD, where both still report. That is the open V-005 and is untouched here.

V-010 closed. Recorded under Settled classes with its enumerating grep over detectFileMIMEType's call sites.

Stall check: not a stall - baked_in.go and validator_test.go changed and V-010 was removed from Now.

Learnings: normalise an external library's output at the one place it enters this codebase, not at each place it is compared, or the second caller keeps the defect the first one had fixed. Check the sibling call site rather than assuming it shares the fault - isImage looked identically exposed and was not, and the payload-per-format check is what said so.

Next: V-011 is the only Medium and outranks the 5 unswept rows, so iteration 6 fixes it. Iteration 7 sweeps bi-iso, bi-ident and docs.

## iter 6/10 | 76637255-142056 | 2026-08-15 | V-011 | done

Task: V-011 (Medium, runtime, correctness) - the unix_addr tag accepted every string, so the validation doc.go documents never rejected anything.

Changed: baked_in.go (isUnixAddrResolvable checks the address instead of consulting a resolver that cannot fail), doc.go (the unix_addr section says what is checked), validator_test.go (TestUnixAddrValidation repaired and extended from 2 cases to 6), BACKLOG.md (V-011 closed, class recorded), PLAN.md (thirteen rows re-recorded), .jeffy/probes/_v010 and .jeffy/probes/_v011 (paths files added now that both findings are closed).

Checkpoint: 24cbea5597082686f0010d1e6572bc668f6bfb9d

Verification: the filed reproduction ran first, 0 of 2060 corpus values rejected. The acceptance check `go run ./.jeffy/probes/_v011` now exits 0. `go test -cover -race ./...` exits 0 over 24 packages at 96.4% root coverage. All eighteen batteries exit 0, the first iteration this run with no battery pinning an open finding.

The fix removes the resolver call rather than adding a check beside it. net.ResolveUnixAddr returns the name unexamined for a unix network and reports an error only for an unknown network, so with the network fixed in the call site the error branch was unreachable and `err == nil` was a check that read like validation while performing none. Keeping the call and adding a guard beside it would have left that misleading line in place for the next reader. The replacement is the portable floor a unix address has to meet: non-empty, and no NUL byte, which neither a filesystem path nor a Go-spelled abstract socket name can contain. A platform-specific sun_path length limit was deliberately not added - 108 bytes on Linux, 104 on macOS - because rejecting a valid address on some platform is a worse failure than the one being fixed.

The Verify gate went red on TestUnixAddrValidation, and this is the exception the loop allows rather than a break. That test asserted `{"", true}`: it was green only because of the defect this task fixes, in the same shape as V-007's two tests in the previous run. Differential evidence, as the exception requires. First, the blast radius is stated as a property and executed, not promised: the tag accepted every value before, so every value it rejects now is a verdict this change altered, and the battery asserts that of the 2060-value corpus the 1026 now rejected are all empty or NUL-bearing and 0 fall outside that class. Second, the repaired test was re-run against the unfixed tree by stashing baked_in.go: it exits 1 at index 0, so the new expectation genuinely depends on the fix, and baked_in.go was compared byte for byte after the stash was popped. Third, the only case whose expectation changed is the empty string; `{"v.sock", true}` is untouched and still passes.

The test had two cases and neither was negative, so its whole else branch - including the val.Tag() assertion - had never executed. Four cases were added: an absolute path, a Linux abstract name spelled with @, a bare NUL and a path with an interior NUL. The false branch now runs.

Contract: this changes the observable verdict of a public tag, which is the point of the task, and the change is confined to values that cannot name a socket. doc.go's unix_addr section now states that the address is checked for shape rather than resolved, so the module and its documentation agree; before this iteration the documentation claimed a validation that was not happening.

The class is one finding wide and the enumeration says so. `grep -n 'net\.Resolve[A-Za-z]*Addr' baked_in.go` returns 9 remaining call sites after the fix, and _sweep6 asserts a rejecting value for every one of those 9 tags, so each one's resolver demonstrably can fail on a field value. unix_addr was the only member of the class.

Surface inventory: baked_in.go changed again, so the same thirteen rows it implements went stale and were re-swept by re-running their batteries against the changed tree, then re-recorded at this checkpoint.

_v010 was closed last iteration without gaining a paths file, which would have left baked_in.go edits ungated by it. Both _v010 and _v011 now declare baked_in.go.

V-011 closed. Recorded under Settled classes with its enumerating grep.

Stall check: not a stall - baked_in.go, doc.go and validator_test.go changed and V-011 was removed from Next.

Learnings: when a delegated call cannot fail, delete the call rather than guarding beside it, or the next reader still sees a validation that is not there. A test asserting that a validator accepts the empty string is worth reading as a hypothesis about the code rather than as a requirement; two of the three findings this run fixed were pinned by tests that encoded the defect.

Next: Now and Next are empty and the only open task is the Low V-005, so the 5 unswept rows outrank it. Iteration 7 sweeps bi-iso, bi-ident and docs; the docs row already has a lead, that origin, http_url and https_url appear in the README tag table with no doc.go section.

## iter 7/10 | 76637255-142056 | 2026-08-15 | SWEEP | done

Task: the last 5 unswept rows outranked the open Low, and the budget needed all of them swept so an audit iteration remains. All 5 swept; one Medium filed and one Low declined on cost.

Changed: PLAN.md (five inventory rows flipped, one scope figure corrected), BACKLOG.md (V-012 filed under Next, V-013 recorded under Declined), .jeffy/probes/_sweep7 (docs battery), .jeffy/probes/_sweep8 (bi-iso and bi-ident battery, 100 cases), .jeffy/probes/_sweep9 (translations battery, 95 cases).

Checkpoint: 658b34edecec5cedde3d004e023925942ed95f38

Verification: rows swept are docs, bi-iso, bi-ident, trans-en and trans-locales, which leaves the Surface inventory with no unswept row for the first time in this project's history. `go test -cover -race ./...` exits 0 over 24 packages. All twenty closed batteries exit 0; _sweep7 exits 1 on the finding it pins.

The docs battery enumerates four sets from the sources rather than listing any of them: the 181 entries of bakedInValidators, the 184 first-column cells of the README tag tables, the 159 tag names doc.go states a usage for, and the 10 parser-level tags taken from the constant blocks in validator_instance.go and cache.go. Two of its four checks pass: every registered tag is in the README table, and the README table documents no tag that does not exist once the 3 bakedInAliases are accounted for.

Both of my first two counts were wrong and I corrected the instrument rather than filing them. The README appeared to document three unknown tags, which were iscolor, country_code and eu_country_code - the entries of bakedInAliases, which a user may legitimately write. doc.go appeared to omit 35 registered tags, but the cross-field sections state their usage inline as `validate.Struct Usage(gtfield=Start)` rather than on a `Usage:` line, and reading only the second form under-reported the documentation. With both forms read the gap is 31, not 35.

V-012 (Medium, docs, documentation) filed. doc.go documents `containsfield` and `excludesfield`; the registered tags are `fieldcontains` and `fieldexcludes`, which README.md spells correctly. A developer following doc.go gets `panic: Undefined validation function 'containsfield' on field 'A'`, reproduced. Medium rather than High because it fails loudly at first use in development rather than silently in production, and Medium rather than Low because the documentation is wrong rather than merely absent.

V-013 (Low, docs, documentation) declined on the Method's pricing rule, with the reason `cost: exceeds one iteration`. 31 of 181 registered tags have no doc.go section. Scored Low rather than Medium because nothing documented is wrong, only absent, and README.md carries the complete list. Declined rather than carried because the class is docs, not runtime, and writing 31 accurate sections requires running each tag before describing it - the rule this project already learned from skip_unless, whose name is the opposite of what it does - which does not fit one iteration. It is named in the run report.

bi-iso and bi-ident are evidenced by published examples of the standards rather than by values read off the implementations: ISBN-10 0-306-40615-2 and ISBN-13 978-0-306-40615-7 for the same book with the check digit broken on each rejecting side, ISSN 0378-5955, the Luhn example from the algorithm's own definition, EIP-55's checksummed address with one letter's case flipped, BIP-173's bech32 vector, and US/USA/840 driven against all three ISO 3166-1 tags so each rejects the other two forms.

Four expectations were mine again, and doc.go stated each contract I had guessed past. iso4217_numeric "accepts the integer kinds only; a string, and any other kind, panics", so it needed an int; and 999 is ISO 4217's XXX, the code for no currency, so the rejecting side needed an unassigned number instead. spicedb takes a purpose parameter, so it is now driven at all three purposes. bcp47_language_tag is "as parsed by language.Parse", which canonicalises an underscore separator - and that is the real split between the loose and strict forms, now asserted as such: `en_US` is accepted loose and rejected strict.

The translations battery checks what messages say. Every locale is driven on seven tags covering the message shapes, and three properties are asserted per locale: no message is empty, none is the bare tag name echoed back, the min message changes when its parameter changes, and the required message changes when the field name changes. The last two are the inert-parameter check the Method asks for, applied to a surface where a message that silently drops its interpolation would otherwise render fine. en is additionally pinned at exact strings.

The battery's first run failed on pl, ru and uk, and the fault was mine: every locale package was being registered against an English translator, and those three have a cardinal plural rule Few that English lacks. Each locale package is now paired with its own locales translator, which is what the library's own per-locale tests do. Coverage was then checked rather than assumed: the set of locales in the battery and the set `go list ./translations/...` returns are equal at 22, with nothing missing on either side.

The trans-locales row said "the other 23 locale packages". The real number is 21 non-en packages, so the row's scope line carried a figure no command returned. It is corrected to 21 and now names the command that produced it.

Stall check: not a stall - three battery directories were added and two findings were recorded.

Learnings: correct the instrument before filing what it reports - both of the docs battery's first two failures were its own extraction bugs, and filing either would have been a false finding against a correct codebase. Pair a locale with its own translator when exercising per-locale code; a plural rule one locale has and another lacks makes registration fail for a reason that has nothing to do with the code under test.

Next: the Surface inventory has no unswept row, so V-012 is the whole ledger above the carried Low. Iteration 8 fixes V-012, iteration 9 runs the full fresh-evidence audit the Definition of done requires, and iteration 10 runs the evaluator gate and declares if it passes.
## iter 8/10 | 76637255-142056 | 2026-08-15 | V-012 | done

Task: V-012 (Medium, docs, documentation) - doc.go stated usage for two tag names that are not registered, so a developer following it panicked on first validation.

Changed: doc.go (two Usage lines corrected), .jeffy/probes/_sweep7 (the declined gap turned into a cap rather than a failure, paths file added), BACKLOG.md (V-012 closed, class recorded, V-013's figure re-measured), PLAN.md (the docs row re-recorded).

Checkpoint: 93da263e7867bd77d65e64fa2abf11f1101097d7

Verification: the filed reproduction ran first and reported containsfield and excludesfield as unknown. The acceptance check `python3 .jeffy/probes/_sweep7/check.py` now exits 0. `go test -cover -race ./...` exits 0 over 24 packages at 96.4% root coverage. All twenty-one batteries exit 0, with none pinning an open finding.

The section headings were already right - "Field Contains Another Field" and "Field Excludes Another Field" - and only the Usage lines carried names the parser does not know. Both tags were run before their documentation was rewritten, which is this project's own rule: fieldcontains and fieldexcludes were driven at both verdicts through the nested `Inner.Field` namespace the usage line documents and through a flat sibling field name, so the parameter shape in the corrected line is one that was executed rather than assumed.

The acceptance check I wrote when filing V-012 was wrong in a way worth recording. It asserted the whole docs battery exits 0, but that battery also asserted the doc.go coverage gap is zero, which is V-013 - declined on cost. So the check could never go green no matter how completely V-012 was fixed, and the battery could never serve as a gate. A battery that cannot pass is not a gate, it is a permanently red light nobody reads.

The gap is now capped instead of required to be zero: the battery prints the 29 undocumented tags by name every run and fails only if the count grows. That keeps the declined debt visible, keeps the four real requirements enforceable, and adds something the original check did not have - a tag added without a doc.go section now fails the battery. That property was verified rather than assumed: one Usage line was renamed to a tag that does not exist, and the battery went red with `doc.go coverage gap grew past the declined 29: now 30`, then doc.go was restored and compared byte for byte.

The fix invalidated a number in the ledger and it was re-measured rather than left. V-013's Declined line said 31 undocumented tags; fixing V-012 moved fieldcontains and fieldexcludes out of that set, so the line now says 29, which is the figure the battery prints.

Contract: doc.go only. No code changed, no tag gained or lost a name, and the two tags the corrected lines name behave exactly as the corrected lines say.

Surface inventory: doc.go is implementing code for the docs row, so that row went stale and was re-swept by re-running its battery against the changed tree, then re-recorded at this checkpoint. No other row's sources were touched.

V-012 closed. Recorded under Settled classes with its enumerating extraction.

Stall check: not a stall - doc.go changed and V-012 was removed from Next.

Learnings: an acceptance check that folds in a declined finding can never pass, so write it against the finding being fixed and cap declined debt separately. Cap a declined gap with a number the battery prints, so the debt is visible every run and cannot grow silently.

Next: the ledger holds only the carried Low V-005 and the Surface inventory has no unswept row, so the Definition of done needs the full fresh-evidence audit it has not yet had. Iteration 9 runs that audit. If it comes back clean, iteration 10 runs the evaluator gate and declares.

## iter 9/10 | 76637255-142056 | 2026-08-15 | AUDIT | audit

Task: the full fresh-evidence audit the Definition of done requires. The ledger held no High and no Medium and the Surface inventory had no unswept row, so this iteration rescored every applicable dimension rather than working the carried Low.

Changed: BACKLOG.md (V-014 filed under Later), PLAN.md (Environment fingerprint corrected), .jeffy/probes/_v014 (new reproduction, no paths file while the finding is open).

Checkpoint: 51faf03ea1428e19ba31f70e77b11a6416b41095

Verification: every claim below was executed this iteration, not cited from an earlier one.

Environment fingerprint re-read first, since nothing else may be called green if its exclusions are stale. All three claims still hold: `grep -rn '^//go:build' --include='*.go' .` returns validate_fn.go and no_validate_fn.go in the library, `grep -rn 't\.Skip\|testing.Short()\|SkipNow' --include='*_test.go' .` returns the single Windows unix-socket skip that does not fire on this linux host, and `go list ./...` returns 24 packages with none under _examples. One line of the fingerprint was wrong and is corrected: it said the novalidatefn build variant is untested, which stopped being true in iteration 2 when _sweep5 began compiling and running it under that tag. It is still outside the Verify command, and the line now says exactly that.

Scores. Every score claims all 31 inventory rows, because none is unswept.

- correctness: None. All 21 batteries executed and exit 0, covering all 181 registered tags, the executor, the caches, the namespace helpers, all 22 locale packages and the 12 example trees.
- security: None. The two adversarial surfaces in the envelope were driven, not reasoned about: _hostile runs pathological values - 100000-character strings, 1000 repeated metacharacters, 2000 nested brackets - across the tag set under a 250ms per-case budget, which is the catastrophic-backtracking check, and _sweep6 drives hostile filesystem paths at the seven tags that stat them. Both exit 0.
- testing: None. `go test -cover -race ./...` exits 0 over 24 packages at 96.4% root coverage. Audit discipline's isolation requirement was met four ways rather than asserted: one test alone, the non-standard package alone, translations/ru alone, and the root suite under -shuffle=on, all exit 0, so no test in the root suite depends on order or on state another module leaks.
- error handling: None. The InvalidValidationError path, the misuse panics and the three malformed-tag panics are each pinned at exact text by _engine, _sweep4 and _sweep3.
- performance: None. The headline benchmarks run clean, with the success paths at 1 alloc/op for a field and 2 for a simple struct. No comparison against a baseline is claimed: this run touched no hot path, and this project's own Lesson says a non-interleaved comparison on this host invents regressions.
- dependency hygiene: None. `go mod verify` reports all modules verified, `go mod tidy` leaves go.mod and go.sum byte-identical, and the module has 7 direct dependencies, all well-known. govulncheck is not installed on this host, so no vulnerability scan was run and none is claimed - that is a disclosure, not a pass.
- architecture: None. developer experience: None, with 12 of 12 example trees building.
- code quality: Low - V-005 and V-014, both carried.
- documentation: Low - V-013, declined on cost, with its 29-tag gap capped by a battery that fails if it grows.
- observability: not applicable. A validation library returns errors to its caller and owns no logging, metric or trace surface; the reason is recorded here rather than the dimension being silently omitted.
- UX and accessibility: not applicable. There is no user-facing surface, only a Go API.

Zero High and zero Medium in-envelope. Closeout has begun: no further audit and no replenishment for the rest of this run.

V-014 (Low, runtime, code quality) filed. The audit looked hardest at code this run touched, which is how it surfaced: unix_addr accepts a non-string field kind, returning accept for an int, a bool, a float and a slice, while tcp_addr, udp_addr and ip_addr all reject the same four values. The field/tag type pairing is a user-error surface in the envelope, fixed at compile time by the developer who wrote the tag, which caps this at Low. It is not a regression from iteration 6, and that was checked rather than assumed: the pre-fix implementation was restored, run, and also accepted all three scalars, then the fix was restored and compared byte for byte and _v011 re-run green.

Carried Lows, each by ID: V-005, gofmt failures in baked_in.go, doc.go and translations/ko/ko_test.go that CI cannot catch because .golangci.yaml declares no formatters section; V-014, unix_addr accepting a non-string kind. Both are accurately scored Low and neither blocks a declaration. V-013 is Declined on cost, not carried.

Stall check: not a stall - V-014 was added to Later, and an AUDIT entry is a ceremony entry in any case.

Learnings: audit the run's own diff with the same suspicion as the rest of the project - V-014 was found by asking how the function iteration 6 rewrote behaves on the kinds it was not written for, and its whole family disagreed with it. Check whether a finding on freshly changed code predates the change by restoring the old code and running it, rather than reasoning about whether it could have.

Next: iteration 10 is the last. The closing conditions hold except for the evaluator gate, so iteration 10 invokes it and declares convergence if it returns PASS, carrying V-005 and V-014 as the two accurately scored Lows.

## iter 10/10 | 76637255-142056 | 2026-08-15 | EVALUATOR | blocked

Task: the final iteration invoked the adversarial evaluator gate. Invocation 1 returned REJECT, its finding was filed as V-015 and fixed under the one-transaction rule, and invocation 2 returned REJECT again. The cap for this run is 2, because the first invocation landed at iteration 10 rather than before the midpoint, so the second REJECT is terminal and the run ends blocked without declaring.

Changed: validator_instance.go (four doc sites corrected for V-015), .jeffy/probes/_v009 (strengthened, then extended), PLAN.md (a Lesson carrying the same falsehood corrected), BACKLOG.md (V-015 filed and closed, V-016 and V-017 filed by the gate), .jeffy/evaluator (two verdict artifacts).

Checkpoint: e3fc5c5c22c7a1fa7fd85c7006249860ff8cd26c

Verification: `go test -cover -race -count=1 ./...` exits 0 over 24 packages at 96.4% root coverage. All twenty-one closed batteries exit 0; _v014 exits 1 on the Low it pins. Evaluator: REJECT at invocation 1, REJECT at invocation 2, both artifacts committed at .jeffy/evaluator/76637255-142056-1.md and -2.md.

Invocation 1's finding, filed as V-015 and fixed this iteration. The Var-family WARNING this run rewrote in iteration 3 claimed "A pointer to a struct, and a type convertible to time.Time, both keep the tag". The pointer half is false: extractTypeInternal dereferences a non-nil pointer before traverseField's kind switch, so `Var(&Empty{}, "len=5")` returns nil and `Var(&Tagged{}, "required")` returns Tagged.A=required - identical to the plain struct the same warning describes. Only a nil pointer keeps the tag. Reproduced independently before accepting the verdict. The four sites now say a non-nil pointer is dereferenced first and behaves the same way, and the battery case that certified the falsehood was replaced: it had asserted `Var(&Empty{}, "required")` is clean, which is true whether the tag runs or is discarded. It now uses len=5, whose verdict differs between the two, and reverting the doc sites makes the battery exit 1 on two cases.

Invocation 2's findings, filed as V-016 and V-017 and not fixed, because the run has no invocation left to verify a fix and a declaration on unverified work is exactly what the gate exists to stop. V-016: the sibling sentence, also written by this run in iteration 3, says VarWithKey and VarWithKeyCtx apply the tag to the struct as a whole rather than being replaced by the struct's own field tags. Reproduced independently: `VarWithKey("k", Two{B:"x"}, "required")` returns k.A=required under both New() and WithRequiredStructEnabled(), so the struct's own field tag is precisely what runs. Under default New() the bare required never reaches the struct at all.

Why my iteration 3 enumeration missed it, which is the part worth keeping. That iteration drove all six Var-family functions and I recorded the enumeration as the thing that made the fix trustworthy. Every case used Empty{}, a struct with no fields - and a struct with no fields cannot distinguish "the tag was applied to the struct" from "the struct's own field tags ran instead", because there are no field tags to run. The enumeration covered all six functions and none of the behaviours. A complete list of sites is not a complete list of cases.

V-017 is the structural task the three-strike rule requires, and this is genuinely the third instance of one root cause: a case that cannot fail against the claim it certifies. The pointer case (V-015) and the two VarWithKey cases (V-016) are the same defect as the acceptance check I wrote for V-012 in iteration 8, which folded in a declined finding and could never pass. Patching a fourth instance is forbidden; the task is a check that negates each doc claim in _v009 and confirms the corresponding assertion goes red.

Gate observations that are not REJECT reasons, recorded here for the next run rather than fixed, because a fix after a verdict invalidates it: doc.go's unix_addr NUL sentence versus net.Listen accepting "\x00name" as an abstract socket (Low); mediaType normalising the tag side, so the off-contract form `mimetype=text/plain; charset=utf-8` no longer enforces the charset (Low); PLAN.md's Oracle line still says 96.3% where every run this iteration measures 96.4%; the entry-struct, entry-var, entry-map and registration rows are recorded at 850ecda although validator_instance.go changed again at HEAD, comment-only and with _v009 and _sweep7 both declaring that path and passing; and iteration 9's security evidence leaned on _hostile exiting 0, which the gate notes is weak on its own since that battery has no failing status - it re-checked the substance and found slow=0 with all 189 panics being documented bad-tag-usage panics.

Stall check: not a stall - validator_instance.go changed, V-015 was filed and closed, and V-016 and V-017 were filed.

Learnings: an enumeration of sites is not an enumeration of behaviours - Empty{} named all six Var entry points and could distinguish none of their outcomes, so choose the fixture that can tell the claims apart before counting the sites. Every case certifying a documentation claim must be run against the negation of that claim and seen to fail, or it is decoration; this run shipped three such cases and the gate caught all three.

Next: nothing in this run. The budget is spent and the second REJECT is terminal, so the run ends blocked. The next run starts with V-016 and V-017 and a fresh gate.

## iter 1/10 | b5702d17-153026 | 2026-08-15 | ROTATION | rotation

Task: JOURNAL.md stood at 546 lines, past the 500-line rotation threshold, so all but the last 10 entries moved to the archive.

Changed: JOURNAL.md (10 entries removed), JOURNAL-archive.md (created, 10 entries).

Checkpoint: recorded in this iteration's primary entry.

Verification: the whole 9c2b995d-131932 run - its 10 entries - moved to a newly created JOURNAL-archive.md, leaving the 10 entries of 76637255-142056 in place. Counted by `grep -c '^## iter [0-9]' `: 10 in the archive and 10 in JOURNAL.md, which is 20, the count before the move. JOURNAL.md is now 329 lines. The preamble stayed put, including the fenced heading-grammar example, which the anchor skips because its heading is indented.

Learnings: none beyond the mechanics.

Next: the primary entry for this iteration follows.

## iter 1/10 | b5702d17-153026 | 2026-08-15 | V-016 | done

Task: V-016 (Medium, docs, documentation) - the WARNING on VarWithKey and VarWithKeyCtx said the supplied tag is applied to the struct as a whole "rather than being replaced by the struct's own field tags". The second half is false and the first half was incomplete: both things happen.

Changed: validator_instance.go (the WARNING on both VarWithKey and VarWithKeyCtx), .jeffy/probes/_v009 (VarWithKey cases rebuilt on a fixture that can fail, 8 behaviour cases and 2 doc assertions added), BACKLOG.md (V-016 closed, the Settled classes line corrected), PLAN.md (Oracle coverage figure corrected, four entry rows and the docs row re-recorded).

Checkpoint: dd97a7bf6606473a44b2fa19dc3fb78838a63985

Verification: the filed reproduction ran first and confirmed the gate's finding, then went further than the filing. `VarWithKey("k", Two{B:"x"}, "required")` returns k.A=required under both New() and WithRequiredStructEnabled(), so the struct's own field tags do run - the filing's half. But the supplied tag runs too, which the filing did not state and the old sentence's first half claimed without evidence: `VarWithKey("K", Empty{}, "len=5")` panics with `Bad field type main.Empty` where `Var(Empty{}, "len=5")` returns clean, so the tag reaches the struct kind through one entry point and is discarded by the other. Both halves are now in the doc.

The mechanism, read from the executor rather than guessed: validator.go's traverseField drops the tag chain when the value is a nested struct and the cField carries no name, and Var, VarCtx, VarWithValue and VarWithValueCtx all pass defaultCField, whose name is empty. VarWithKey passes a cField named for the key, so the guard does not fire, the tag chain runs, and when it finishes the same branch is reached with ct nil and a non-empty name, which calls validateStruct with the namespace prefixed by the key. One code path, two effects, and the old sentence named one and denied the other.

Three further facts the doc now carries, each executed: the field pass is conditional on the tag passing, because a failing tag returns before validateStruct is reached - `VarWithKey("K", Tagged{}, "required")` under WithRequiredStructEnabled returns K=required alone, never K.A; bare required is skipped on a non-pointer struct without that option, so the same call under New() returns K.A=required instead; and a non-nil pointer is dereferenced before both steps, shown at both - `&Two{B:"x"}` reports K.A=required and `&Empty{}` with len=5 panics. A nil pointer and a time.Time value keep the tag with no field pass after it, K and never K.A.

Acceptance check: `go run ./.jeffy/probes/_v009` exits 0, with the VarWithKey cases now on Two{B:"x"}, whose field tag fails while the struct itself is non-zero, so a kept tag and a replaced tag give different answers. The check was confirmed strong enough to fail rather than assumed: validator_instance.go was copied aside, the pre-fix version restored from HEAD, and the battery re-run - it exits 1 on three doc assertions - then the fixed copy was restored and diffed byte-identical, and the battery re-run green.

Verify gate: `go test -cover -race ./...` exits 0 over 24 packages at 96.4% root coverage. Battery ownership: the diff touches validator_instance.go, which three paths files declare - _sweep3, _sweep7 and _v009 - and all three exit 0.

Contract: comments only. No signature, no behaviour and no accepted input changed, and the six Var-family functions validate exactly what they validated before.

Surface inventory: validator_instance.go is implementing code for entry-struct, entry-var, entry-map and registration, all recorded at 850ecda, and it has changed twice since - at cc393ed last run and again here - so those rows were stale on arrival. _sweep3 is their battery and it was re-run green against the changed tree, so the four are re-recorded at this checkpoint. The docs row is re-recorded on the same evidence, _sweep7 declaring validator_instance.go and passing. No other row is stale, and that was checked rather than assumed: baked_in.go has not changed since 24cbea5, where every bi-* row is recorded, and its only changes since 7ba6ba4 are two hunks in detectFileMIMEType and isIPAddrResolvable that touch no validate_fn wiring, so bi-validatefn stands. errors.go, struct_level.go and field_level.go are unchanged since their rows' commits.

V-016 closed. The Settled classes line for the Var-family doc class repeated the falsehood and is corrected with the fixture and both commands that separate the two behaviours.

Stall check: not a stall - validator_instance.go changed and V-016 was removed from Next.

Learnings: a doc assertion that counts a sentence across a file breaks the moment a sibling group's corrected text reuses that wording - correcting the VarWithKey pair with the Var group's own pointer sentence turned an assertion of 4 into 6 - so keep each group's pinned wording unique to it. Read the executor for the mechanism before writing what an entry point does; the two-step behaviour here is one branch in traverseField and no amount of black-box probing would have named it as one.

Next: V-017, the structural task the three-strike rule requires - a check that negates each doc claim in _v009 and confirms the matching assertion goes red. This iteration hand-ran that negation for the three assertions it touched and all three failed correctly, which is the evidence V-017 has to make repeatable rather than manual.

## iter 2/10 | b5702d17-153026 | 2026-08-15 | V-017 | done

Task: V-017 (Medium, test, testing) - the structural task the three-strike rule required, after three cases in .jeffy/probes/_v009 certified documentation claims they could not have contradicted.

Changed: .jeffy/probes/_v017 (new negation harness plus its paths file), BACKLOG.md (V-017 closed, V-018 filed).

Checkpoint: 55be9220dda4be50c5a97d57d762a3aa2156d645

Verification: `python3 .jeffy/probes/_v017/check.py` exits 0 and reports all 7 doc assertions in _v009 going red against the negation of their own claim, per case: the four presence claims - the dropped-tag sentence at 4 sites, the Var-group pointer sentence at 4, the VarWithKey kept-tag sentence at 2, the VarWithKey pointer sentence at 2 - each removed from the source and each assertion observed red; the three absence claims - the false pointer claim, the false replacement claim, the "unforeseen validations will occur" warning - each reinserted and each assertion observed red.

The case list is extracted from _v009's own source by a regex over its `check(name, want, strings.Count(doc, sentence))` calls, not restated in the harness, because this project's own Lesson says a hand list omits the members a generated one finds - and a hand list here would go stale the first time someone edited a sentence in _v009 without remembering a second file. The harness matches each sentence in the raw file through a pattern that tolerates doc-comment line wrapping, so it counts the same sentences the battery counts after joining comment lines, and for every presence claim it asserts the raw count equals the battery's stated want, which cross-checks the two ways of counting against each other.

The harness mutates validator_instance.go in place and restores it in a finally block, then compares a sha256 of the restored file against the original and fails if they differ. Every run above ended with the file restored byte-identical, and `git status --porcelain` after each showed no modification to it.

The harness was required to fail before being believed, which is the whole point of the task, and three fault injections were run rather than one. Stating a count of 5 where the source holds 4 makes it exit 1. Adding a doc assertion pinning a sentence that appears nowhere makes it exit 1. Both of those are caught at the control run, so a third injection exercised the per-case branch directly: run_battery was patched to report green unconditionally, and the harness then reported all 7 assertions as not going red and exited 1 with the message naming 7 of 7. The harness file was restored byte-identical after that injection and re-run green, and _v009 was restored byte-identical after the first two.

Verify gate: `go test -cover -race ./...` exits 0 over 24 packages at 96.4% root coverage. Battery ownership: this diff touches only .jeffy/probes/_v017, which no paths file declares, so no other battery was owed a run; the new harness carries its own paths file naming validator_instance.go and .jeffy/probes/_v009/main.go, so any future iteration touching either re-runs it. It costs under a second.

Contract: no library code changed. The harness reads and restores validator_instance.go and never leaves it modified.

The class is not recorded under Settled classes, because it is not closed. V-017's filed acceptance was about the doc assertions and it is met, but the doc assertions only prove an assertion tracks its sentence - rewrite a sentence into a falsehood, update its assertion to match, and the harness stays green. What makes a doc claim true is the behaviour cases, and all three historical instances of this class were behaviour cases: V-015's pointer case used a tag whose verdict was identical whether it ran or was discarded, and V-016's two cases used a fieldless struct that could not show which of the two competing behaviours had occurred. That half has no mechanical check and is filed as V-018.

V-017 closed.

Stall check: not a stall - .jeffy/probes/_v017 was added, V-017 was removed from Next and V-018 added to it.

Learnings: a harness that certifies other checks has to be fault-injected at the branch that matters, not only at its entry conditions - two of the three injections here were absorbed by the control run and would have left the per-case comparison itself unproven. Extract a check's case list from the source of the thing it checks; a hand-copied list is a second place to forget.

Next: V-018, the behaviour half of the same class - a discrimination check that drives each Var-family behaviour fixture through the opposing entry-point group and requires the two to disagree.

## iter 1/10 | 48ee2ba9-175310 | 2026-08-15 | V-018 | done

Task: V-018 (Medium, test, testing) - the behaviour half of the class V-017 opened. _v017 proves each doc assertion tracks its sentence; nothing proved a behaviour case could contradict the claim it certifies, which is what all three historical instances of the class were.

Changed: .jeffy/probes/_v018 (three mutations added, mutation model generalised to multi-edit, paths file added), .jeffy/probes/_v009 (the nil-pointer VarWithKey fixture), BACKLOG.md (V-018 closed, the class recorded under Settled classes), PLAN.md (two Lessons).

Checkpoint: e89f1fce1d12047d816adce65385e1978c23fa99

Verification: `python3 .jeffy/probes/_v018/check.py` exits 0 in 3.3s and reports all 21 behaviour cases in _v009 going red under at least one of 8 competing executor implementations, naming the killing mutation per case. `go run ./.jeffy/probes/_v009` exits 0, `python3 .jeffy/probes/_v017/check.py` exits 0 at 7 of 7.

The filed reproduction ran first. A prior session had left the harness uncommitted and the last commit salvaged it; run as found it exits 1 with 7 of 21 behaviour cases surviving every mutation. That run is the acceptance check observed failing against the unfixed state, and the seven were not one defect. Five were a gap in the mutation set rather than decoration: the drop of the tag and the field pass that follows it are two decisions in the same branch, and every mutation present moved only the first, so no case pinning the field pass could go red. Adding the suppression of the field pass alone killed four of them, and removing the nil-pointer early return killed the fifth.

Two were genuine decoration and only one needed a fixture change. `VarWithKey("K", time.Time{}, "required")` survived because VarWithKey keeps the tag for every struct kind, so time.Time-ness alone changes nothing there and only dropping the tag as well makes the competing behaviour visible; that is one coherent implementation, not two, so it went in as one mutation with two edits and the case now dies under it. `VarWithKey("K", (*Two)(nil), "required")` was the real defect: a nil pointer never reaches a validator, its error is synthesised in the pointer branch, and required reports K=required either way - the same shape as V-015, where required on a non-nil pointer was clean either way. It now uses len=5, which is reportable only if the tag survived to that branch and panics if it is actually run, so the two outcomes differ and the case dies under the nil-pointer mutation.

Three fault injections, run because a harness that certifies other checks has to fail at the branch that matters. Reverting that one fixture to required makes the harness exit 1 naming exactly that case, 1 of 21. Rewriting mutated-run output so every case reads green makes it exit 1 at 21 of 21, which exercises the per-case comparison itself rather than the control run. Editing one mutation's find string so it matches nothing makes it exit 1 with a HARNESS ERROR naming the file and the count. Both mutated files were compared by sha256 after every run and `git status --porcelain` showed neither modified; _v009 and check.py were restored byte-identical after their injections, confirmed with diff.

Verify gate: `go test -cover -race ./...` exits 0 over 24 packages at 96.4% root coverage.

Contract: no library code changed. This diff is entirely under .jeffy/probes/, so no Surface inventory row went stale. Battery ownership: the diff touches .jeffy/probes/_v009/main.go, which _v017's paths file declares, and _v017 was run green. _v018 now carries its own paths file naming validator.go, cache.go and .jeffy/probes/_v009/main.go, so a change to a mutation site reports a HARNESS ERROR in the same iteration instead of at the close.

The filed acceptance was written as "the same value and tag driven through the opposing entry-point group gives a different result" and the harness does not do that, deliberately. That framing does not catch the defect the class is named for: `VarWithKey("K", &Empty{}, "required")` returns K=required where Var returns clean, so it calls V-015's fixture discriminating. The axis that matters is not which entry point ran but whether the tag was kept, dropped, or ran a field pass, which is why the harness mutates those decisions instead. The task's intent - report a fixture that cannot separate the competing hypotheses - is met and was met against a real survivor.

V-018 closed. The class is now recorded under Settled classes with both halves and their commands.

Stall check: not a stall - .jeffy/probes/_v018 and _v009 changed, and V-018 was removed from Next.

Learnings: a case surviving every mutation is ambiguous between decoration and a missing mutation, and the two are separated by naming the executor decision that would have to change - five of seven survivors here were the second, and calling them decoration would have weakened seven good cases to fix a gap in the instrument. A case pinning a negative certifies nothing when something else already forces that negative: required on a nil pointer blocks the field pass by failing, so the case read as evidence about nil pointers while testing only that a failing tag stops.

Next: the ledger holds two open Lows and no Medium, and this run has recorded no audit yet, so iteration 2 runs the full fresh-evidence audit the Definition of done requires, re-checking Surface inventory rows for staleness first.

## iter 2/10 | 48ee2ba9-175310 | 2026-08-15 | AUDIT | audit

Task: the full fresh-evidence audit this run needs, rescoring every applicable dimension against the rubric and the Operating envelope.

Changed: BACKLOG.md (V-019 filed in Now, V-020 and V-021 filed in Next), PLAN.md (two Lessons), .jeffy/probes/_v019 (new reproduction, no paths file while the finding is open).

Checkpoint: 47b45832b5b5a2a64123706d98f4f392b6e6cb52

Verification: `go test -cover -race -count=1 ./...` exits 0 over 24 packages at 96.4% root coverage. Every battery under .jeffy/probes/ was run: 23 of 24 exit 0, and _v014 exits 1 on the Low it pins by design. `go vet ./...` exits 0. Surface inventory staleness was computed rather than assumed, by taking the last commit touching each row's implementing files and comparing its position in `git log` against the row's recorded sweep commit: 0 stale of 31 swept rows, 0 unswept.

Scores, claiming the whole mapped surface because no row is unswept or stale. Architecture None. Code quality Low, the three gofmt failures already filed as V-005. Security High. Testing None. Error handling None. Performance None, in the sense that the one superlinear path found is filed under security as V-019 rather than counted twice; the 66 benchmarks run clean at 231ns and 1 alloc for the success path. Documentation Low, V-013's 29 tags without a doc.go section, already Declined and capped by a battery. Dependency hygiene Medium. Developer experience None. Correctness None. Observability and UX/accessibility do not apply - a validation library with no logging, metrics, tracing or user-facing surface - and are recorded rather than scored.

The audit is not clean, so closeout does not begin.

Security, the dimension that moved. govulncheck is not installed here and nothing in this project had ever run one; installing it and running `govulncheck ./...` exits 3 with three standard-library advisories reachable from this code, against 6 in imported packages and 14 in required modules that the analysis says this code does not call.

V-019 is the one worth an iteration and it is reproduced, not asserted. isEmail is a conjunction of two pure predicates - mail.ParseAddress succeeds and emailRegex matches - evaluated parser first, and the parser carries GO-2026-4986 and GO-2026-4977, quadratic comment and phrase consumption. Timing the tag at four doubling sizes gives 83ms, 444ms, 1.86s, 5.95s for a comment-shaped value of 25k to 200k bytes, ratios 5.3, 4.2 and 3.2 - the shape of a quadratic, not of a slow constant. The regex rejects that same value, so the expensive half runs only to produce a verdict the cheap linear half had already settled. Reordering is verdict-preserving because both predicates are pure and ANDed, which is why this is filed as the project's defect and not only the toolchain's: the exposure survives whatever Go a consumer builds with, and removing it costs nothing.

Three shapes were timed and discarded before that one. A leading comment, a nested-paren comment and a long local part are all near linear here, and the first probe written reported a worst ratio of 4.7 that was noise at millisecond scale. Reading the ratio across four sizes rather than one is what separated the two.

V-020 is filed at Medium against a rubric that would say High, and the rationale belongs on the record: the panic is Windows-only and this host is linux, so it cannot be reproduced, and every one of the eleven address tags probed already rejects every NUL-bearing value here while net.ResolveIPAddr returns an ordinary lookup error. The decline reason first drafted for it was wrong and was checked rather than written - the idea was that a NUL guard would break linux abstract sockets, and `net.Listen("unix", "\x00name")` does succeed on this host as `@name`, but `unix_addr` already rejects `"\x00abstract"`, so a guard changes no verdict here and the finding stands.

V-021 records that CI has no vulnerability scan at all. Its filing carries the interaction the fix has to handle: govulncheck's standard-library findings track the toolchain the runner installs, so a job pinned to an affected Go stays red until the runner carries go1.26.3, and V-019's own fix does not clear those two advisories from a static reachability scan because isEmail still calls mail.ParseAddress, only later.

Testing was not scored clean on the whole-suite run alone. `go test ./non-standard/validators/` alone, five root tests each run alone by name, and the root suite under `-shuffle=on` all exit 0, so no test here depends on order or on state a sibling module leaks.

Nothing was filed inside a Settled class. The email finding touches no class recorded there, and the address-family class settled earlier is about a delegated call that cannot fail, which is a different defect from passing an unfiltered value to one that can.

Stall check: not a stall - .jeffy/probes/_v019 was added and three tasks were filed.

Learnings: govulncheck belongs in every dependency-hygiene score and is not installed on this host; six audits scored this project without one and a reachable High sat through all of them. A scanner's reachability trace proves reach and says nothing about cost - the first reproduction attempt made the finding look like noise, and only timing four doublings and reading the ratio settled it. Check a decline reason before writing it: the reason drafted for V-020 was a factual claim about abstract sockets that turned out to be false.

Next: V-019, the only High. Its acceptance battery already exits 1 against the unfixed tree with the corpus green, so the fix is the reorder and the evidence is the same battery going green.

## iter 3/10 | 48ee2ba9-175310 | 2026-08-15 | V-019 | done

Task: V-019 (High, runtime, security) - isEmail handed the raw field value to mail.ParseAddress before the linear regex that would reject it, making two quadratic net/mail advisories reachable from an adversarial surface.

Changed: baked_in.go (isEmail reordered, one comment added), validator_test.go (two regression tests and the net/mail import), .jeffy/probes/_v019 (AST class enumeration, corpus counter fix, paths file now that the finding is closed), BACKLOG.md (V-019 closed, the class settled, two Settled classes lines corrected, V-020's acceptance corrected), PLAN.md (15 Surface inventory rows re-recorded).

Checkpoint: d61c32ca8912e954bde2dc41d94c0e15aed460f8

Verification: `go test -cover -race -count=1 ./...` exits 0 over 24 packages at 96.4% root coverage and 100% non-standard. `go run ./.jeffy/probes/_v019` exits 0.

The filed reproduction ran first and still reproduced: 78ms, 260ms, 1.20s, 5.05s across 25k to 200k bytes, ratios 3.3, 4.6, 4.2. After the reorder the same four sizes take 25µs, 4µs, 4µs and 3µs, and the worst ratio is 0.9.

Contract: the verdict is unchanged for every input. isEmail is the conjunction of two pure predicates and only their evaluation order moved, which the battery demonstrates rather than argues - its 20-address corpus reports 20 of 20 unchanged under both orders, while the enumeration and the timing are what differ. That symmetry was not visible at first: the corpus summary subtracted a shared failure counter, so the injected old-order run printed 19 of 20 and looked like a verdict change. The counter was the defect, not the ordering, and it is fixed.

The class, not the instance. .jeffy/probes/_v019 now parses baked_in.go with go/ast and lists every function calling both a compiled regex and a parser from mail, url, urn, json, net, netip, mimetype or bech32. It returns exactly 1 site, isEmail. The first version of that enumeration was textual and reported 2, having read the new doc comment above isEmail as a call from isE164 - the AST version excludes comments by construction. The branch is fault-injected: restoring the old order makes it exit 1 with `1 of 1 regex+parser sites call the parser first: [isEmail]`.

Two regression tests now pin this inside the repository's own suite rather than only in .jeffy. TestEmailChecksAgreeInEitherOrder drives 441 generated addresses and asserts parser-first and regex-first agree on each, and that the tag agrees with both. TestEmailDoesNotParseWhatTheRegexRejects asserts a 200KB comment-shaped value is rejected in under a second; restoring the old order makes it fail at 4.53s, so the bound is four orders of magnitude clear of the fixed path and one order clear of the broken one. Neither adds a skip marker, checked by re-running the fingerprint's own command, which still returns the single Windows unix-socket skip.

Battery ownership: the diff touches baked_in.go, which 13 paths files declare, and validator_test.go, which none do. All 13 were run and exit 0, and the remaining 11 batteries were run too - 23 of 24 exit 0, _v014 exits 1 on the Low it pins.

Surface inventory: baked_in.go changed, so the 14 bi-* rows other than bi-validatefn and the docs row went stale by the rule, 15 in all. Each is re-recorded at this checkpoint on re-executed evidence, not on assertion: _sweep1, _sweep2, _sweep3, _sweep6, _sweep8, _breadth, _kindsweep and _hostile cover the bi-* rows and all exit 0 against the changed tree, and _sweep7 covers docs and exits 0. bi-validatefn is untouched - no_validate_fn.go and validate_fn.go did not change - and regexes.go did not change, so those rows stand at their own commits.

Claims re-executed because this diff touches baked_in.go, and two were wrong. The Settled classes line for the media-type class said `grep -n detectFileMIMEType baked_in.go` returns 2; it returns 3, the definition plus 2 call sites. The line for the address class said the Resolve*Addr grep returns 9 call sites; it returns 10 lines, 9 calls and one comment naming the removed ResolveUnixAddr. Both were substantively right about the sites and wrong about what the command prints, which is the failure PLAN.md's own rule about stating the shape a command returns exists to stop. Both are corrected, and V-020's acceptance, which had inherited the 9, is corrected with it. The registered-tag count is still 181, `go list ./...` still returns 24 packages, the build constraints are unchanged, and coverage is unchanged at 96.4% and 100%, so the Oracle and fingerprint lines stand.

gofmt was checked rather than assumed: baked_in.go still deviates only at the trailing blank line V-005 already records. The gofmt -d hunk before and after this edit is identical apart from the file name and a seven-line offset, so this change adds no new deviation and V-005 is unchanged in scope.

V-019 closed.

Stall check: not a stall - baked_in.go and validator_test.go changed and V-019 was removed from Now.

Learnings: an enumeration built by scanning text will read a comment as code, and the comment a fix adds is exactly the text most likely to name the call it removed - parse the AST with comments off. A shared failure counter makes a battery's own summary lie about the section that passed; count each section separately or a fault injection reads as a verdict change. Re-running the commands behind state-file claims is worth the minutes: two Settled classes lines named counts their own commands do not print.

Next: V-020 and V-021, both Medium. V-020 is the address family's NUL exposure, whose acceptance needs the resolver-verdict mutation the enumeration above makes cheap to write.

## iter 4/10 | 48ee2ba9-175310 | 2026-08-15 | V-020 | done

Task: V-020 (Medium, runtime, security) - the resolvable-address tags handed values carrying a NUL byte to net's resolver, whose Windows path panics on one.

Changed: baked_in.go (isIP4Addr and isIP6Addr reject a NUL), validator_test.go (one regression test), .jeffy/probes/_v020 (new instrumented battery, driver and paths file), .jeffy/probes/_v019 (growth assertion given an absolute floor after it was found flaky), BACKLOG.md (V-020 closed, the class settled), PLAN.md (15 rows re-recorded, four Lessons).

Checkpoint: 1eac9b85fb73ad1f6f2b6e7c62d65fc8232a5c75

Verification: `go test -cover -race -count=1 ./...` exits 0 over 24 packages at 96.4% root coverage. `python3 .jeffy/probes/_v020/check.py` exits 0. All 26 batteries run; 25 exit 0 and _v014 exits 1 on the Low it pins.

The filing was half right and the instrument corrected it. `govulncheck ./...` still exits 3 and its trace for GO-2026-4971 names isIP4AddrResolvable, isTCP4AddrResolvable and isUDP4AddrResolvable. Reading the code first suggested the opposite of the filing: every resolver call sits behind an IP-shape gate, so the NUL looked unreachable and V-020 looked like a false positive worth declining. It is neither. isIP4Addr and isIP6Addr strip everything after the last colon and parse only the host, so a NUL in the port survives the gate untouched and arrives at the resolver in full.

Measured rather than argued. The battery instruments all 9 call sites in place to panic when the value reaching the resolver carries a NUL, and drives every resolver-backed tag against 12 NUL-bearing values. Before the fix: 24 tag/value cases across 6 of 9 sites, the tcp and udp families. After: none. The 3 ip*_addr sites were already clean because isIPv4, isIPv6 and isIP parse the whole value - and those are precisely where govulncheck pointed. Its trace named one of the three safe sites and none of the six unsafe ones, which is what a call-graph scan can and cannot tell you.

Contract: verdicts are unchanged. On this host every one of these values was already rejected, because net's resolver returns an error rather than panicking, so the fix removes a reachable panic on Windows and moves no verdict here. The battery's uninstrumented control run asserts exactly that and is compared against the instrumented run, so a fix that quiets the probe by changing what the tags accept would fail. Both new gate branches are exercised by the new test, which is why root coverage returned to 96.4% after briefly reading 96.3%.

The in-repo regression test does not discriminate on this platform and its comment now says so. It passes with and without the gate, because the resolver rejects a NUL either way here; what it guards is a future change that starts accepting these values. The mechanism is pinned by the battery, which does fail without the gate. Writing that down rather than letting the test look like proof is the whole point of the class this project settled twice.

A defect of my own from iteration 3, caught by battery ownership. _v019 exited 1 in this iteration's sweep and passed when re-run, so it was timed twelve times: two of eight runs failed with doubling ratios of 96, which is a 1µs sample against a 96µs one. After the email fix its samples are microseconds and the ratio assertion was amplifying scheduler noise. The assertion now applies only when the slowest sample clears a 5ms floor, and says so in its output when it does not. Twelve consecutive runs pass, and restoring the old email order still fails it on all three grounds - enumeration, the 250ms bound, and a 4.1 ratio at a 293ms sample - so the floor cost nothing against the defect.

Hostnames were checked too, since a resolver call on adversarial input suggests a DNS lookup: `tcp_addr`, `tcp4_addr`, `udp_addr` and `ip_addr` all reject "example.com:80" and "localhost:80" at the shape gate, so no name reaches a resolver and there is no lookup surface here. No finding.

Battery ownership: the diff touches baked_in.go, which 15 paths files now declare including the new _v020, and validator_test.go, which none do. Every battery in the tree was run.

Surface inventory: baked_in.go changed, so the same 15 rows - the 14 bi-* rows other than bi-validatefn, plus docs - went stale and are re-recorded at this checkpoint on re-executed evidence, every covering battery having exited 0 against the changed tree.

Claims re-executed: the Resolve*Addr grep still returns 10 lines, detectFileMIMEType 3, the registered-tag count 181, and the skip-marker enumeration still returns exactly one, so the corrected Settled classes lines, the Oracle line and the fingerprint all still hold. Worth noting for a later iteration rather than fixing here: the Surface inventory's tag-count scope command is an awk line range over baked_in.go, and it survived this diff only because both edits fall below its window.

V-020 closed.

Stall check: not a stall - baked_in.go and validator_test.go changed and V-020 was removed from Next.

Learnings: a call-graph scanner names the call, not the value that arrives at it, and it pointed at the three sites that were safe while missing the six that were not - instrument the call site and drive a corpus before believing a reachability claim in either direction. A ratio between microsecond timings is noise and will fail a battery at random; gate a growth assertion on an absolute floor, and re-run a timing check a dozen times before trusting it, because running it three times is how this one shipped. When a fix moves no verdict on the host you are on, no verdict test can pin it - keep the test for regressions, but write in its comment what it does not prove.

Next: V-021, the last Medium - CI has no vulnerability scan. Its filing already carries the interaction to handle, that govulncheck's standard-library findings track the runner's toolchain.

## iter 5/10 | 48ee2ba9-175310 | 2026-08-15 | ROTATION | rotation

Task: JOURNAL.md stood at 537 lines, past the 500-line threshold, so all but the last 10 entries moved to the archive.

Changed: JOURNAL.md (7 entries removed), JOURNAL-archive.md (7 entries appended).

Checkpoint: recorded in this iteration's primary entry.

Verification: the 7 oldest entries - iterations 1 to 7 of run 76637255-142056 - were appended to the archive, which already held 10 and now holds 17, counted by `grep -c '^## iter [0-9]'`. JOURNAL.md keeps 10 entries and is now 321 lines. The archive grew rather than shrank, which is what the stop hook checks. The preamble stayed in place, including the fenced heading-grammar example, which the anchor skips because its heading is indented.

Learnings: none beyond the mechanics.

Next: the primary entry for this iteration follows.

## iter 5/10 | 48ee2ba9-175310 | 2026-08-15 | V-021 | done

Task: V-021 (Medium, build-ci, dependency hygiene) - CI ran test, coverage and lint and no vulnerability scan, so three reachable standard-library advisories failed no gate.

Changed: .github/workflows/workflow.yml (a govulncheck job), Makefile (a vulncheck target, and bench added to .PHONY where it had been omitted), .jeffy/probes/_v021 (new structural battery and its paths file), BACKLOG.md (V-021 closed).

Checkpoint: 739e93e98b1f204612de95aac8ac87a3773cacc8

Verification: `go test -cover -race -count=1 ./...` exits 0 over 24 packages at 96.4% root coverage. All 27 batteries run; 26 exit 0 and _v014 exits 1 on the Low it pins.

The acceptance asked for the job's own command run locally verbatim, and it was. `go install golang.org/x/vuln/cmd/govulncheck@latest` followed by `govulncheck ./...` - the two lines the step's script contains, taken from the parsed YAML rather than retyped - exits 3 and names GO-2026-4986, GO-2026-4977 and GO-2026-4971, closing with "Your code is affected by 3 vulnerabilities from the Go standard library". `make vulncheck` runs the same scan through `go run ...@latest`, which needs no PATH handling, and make reports exit 2 for the failing recipe while govulncheck itself reports 3.

What that local run does and does not establish, stated plainly because GitHub Actions cannot run on this host. It establishes that the script is valid, that govulncheck accepts these arguments against this module, and that the gate fires on a tree with reachable advisories. It does not establish what the job will report on a runner: the job installs Go with `go-version: stable`, so a runner picks up a release at or past the go1.26.3 that fixes all three, and the job would then be green on exactly this tree. That is the intended design and the reason the version floats - pinning an affected patch release would hold the job red after upstream had already fixed the advisory, which is how a gate earns its deletion. The residual limit is worth naming too: with a floating toolchain, CI sees the advisories a current Go still has, while a consumer building this library on an older Go keeps the exposure CI no longer shows. A library cannot test its consumers' toolchains, and the two fixes this run already landed are what protect them regardless of Go version.

The battery is structural and says so in its own docstring, because a check that quietly under-delivers is worse than a missing one. It parses every workflow, finds the job whose step runs govulncheck, and asserts four things: the step's script parses under `bash -n`, it scans the whole module with ./..., the job installs Go explicitly, and the version it installs floats rather than pinning. It does not run govulncheck, which needs the network - the live run above is the evidence for that half. Fault-injected by deleting the job from the workflow: it exits 1 with "no workflow job runs govulncheck, so a reachable advisory fails no gate", and the workflow was restored byte-identical.

Battery ownership: the diff touches .github/workflows/workflow.yml, declared by _v004's paths file and now by _v021's, and the Makefile, which no paths file declares. Both batteries exit 0; _v004 still passes because the new job carries no matrix condition for it to check.

Contract: no library code changed, so no Surface inventory row went stale. Neither the Makefile nor the workflows belong to a row - the inventory maps the library's public surface, and CI is covered by the batteries instead.

V-021 closed. Not recorded under Settled classes: it is a single missing gate rather than a repeated idiom, and there is no second site to enumerate.

Stall check: not a stall - the workflow and the Makefile changed and V-021 was removed from Next.

Learnings: verify a CI change by parsing the workflow and executing the step's own script rather than a retyped copy of it, and record what the local run cannot establish - here the runner's toolchain resolution, which is the whole reason the job will behave differently there. A vulnerability gate should track a floating toolchain: pinning it red against an advisory upstream has already fixed is how the gate gets removed.

Next: the ledger holds only V-014 and V-005, both accurately scored Lows, and this run has no clean full audit on record - iteration 2's found one High and two Mediums, all now closed. The plan for the remaining budget is V-014, then V-005, then the full fresh-evidence audit the Definition of done requires, then the evaluator gate, then the declaration.

## iter 6/10 | 48ee2ba9-175310 | 2026-08-15 | V-014 | done

Task: V-014 (Low, runtime, code quality) - unix_addr accepted a non-string field kind while every sibling in its family rejected the same value.

Changed: baked_in.go (isUnixAddrResolvable checks the kind), validator_test.go (one regression test), .jeffy/probes/_v014 (family enumeration, fixture corrected to VarWithKey, paths file now that the finding is closed), BACKLOG.md (V-014 closed, the class settled for this family, V-022 filed), PLAN.md (15 rows re-recorded, two Lessons).

Checkpoint: 6baa164160af444cc3ed20d0a483743daf30393e

Verification: `go test -cover -race -count=1 ./...` exits 0 over 24 packages at 96.4% root coverage. `go run ./.jeffy/probes/_v014` exits 0 across 72 cases. All 27 batteries exit 0 - the first iteration this run where none is red, since _v014 was the last one pinning an open finding.

The filed reproduction ran first and still reproduced on all four kinds it named. The fix is a kind guard, and the comment says why this one site needs what its siblings do not: they reject by accident, their parsers refusing the "<int Value>" that reflect.Value.String() renders, while unix_addr asks only for a non-empty string with no NUL and that rendering satisfies it.

The class was enumerated rather than sampled. The battery now drives all 10 registered *_addr tags against 7 non-string kinds, 70 cases plus 2 string controls. Against the unfixed tree exactly the 7 unix_addr cases fail and all 63 sibling cases pass, which is the family disagreement the finding rested on, now executed rather than asserted.

Two fixture errors of my own, both caught by running the thing. The first extension of the battery reported 10 failures with the fix in place, one per tag on a struct value - not a defect in any address tag, but Var discarding the tag on a struct and validating the struct's own field tags instead, which is exactly what _v009 exists to pin and what iterations 1 and 3 of the previous run spent themselves on. The fixture now drives VarWithKey, which keeps the tag, and the struct cases became meaningful. The second is recorded below as a Lesson: a behavioural scan I wrote to look for a wider class returned 26 tags, and most were artifacts - a param-less `contains` accepts everything, `required` is genuinely kind-aware - so each hit had to be confirmed against the mechanism before it counted.

That scan did find one real second instance, filed as V-022. html accepts 6 of 7 non-string kinds while rejecting the plain string "abc", because the placeholder rendering "<int Value>" matches its HTML-tag regex; the slice case is the exception, its rendering not matching. Same root cause as V-014 and outside the address family, so the Settled classes line says the class is closed for that family only. It is the second instance, and the three-strike rule means a third replaces instance patching with one structural task.

Contract: unix_addr's string behaviour is unchanged - a socket path, an abstract @name, the empty string and a path carrying a NUL all keep the verdicts they had, asserted in both the battery and the new test. What changed is the verdict for a non-string kind, which is a behaviour change on the field/tag type pairing surface and is recorded here as one: the tag now rejects what it previously accepted for int, uint, bool, float64, slice, map and struct.

The regression test discriminates, unlike the one V-020 got. It tags five differently-kinded struct fields with unix_addr and requires five errors; against the unfixed tree it fails at the first assertion, because all five were accepted. Root coverage dipped to 96.3% with the new branch uncovered and returned to 96.4% once the test reached it.

Battery ownership: the diff touches baked_in.go, declared by 16 paths files including _v014's new one, and validator_test.go, which none declare. Every battery in the tree was run and all 27 exit 0.

Surface inventory: baked_in.go changed, so the same 15 rows went stale and are re-recorded at this checkpoint on re-executed evidence.

Claims re-executed: the addr-tag grep still returns 10 lines, the Resolve*Addr grep 10, the registered-tag count 181, and the skip-marker enumeration 1, so the Settled classes lines, the Oracle line and the fingerprint all still hold. gofmt still reports only baked_in.go, for the trailing blank line V-005 records.

V-014 closed.

Stall check: not a stall - baked_in.go and validator_test.go changed, V-014 was removed from Later and V-022 added to it.

Learnings: drive a tag against a non-string kind through VarWithKey and never Var, because Var discards the tag on a struct and an entire family reads as accepting one. A behavioural heuristic for a defect class collects false positives faster than instances - 26 hits, 2 real - so confirm each against the mechanism before filing it.

Next: V-022 is the top of the queue, being runtime where V-005 is build-ci, and four iterations remain. The plan is V-022, then the full fresh-evidence audit this run still needs, then the evaluator gate, then the declaration, carrying V-005 as an accurately scored Low.

## iter 7/10 | 48ee2ba9-175310 | 2026-08-15 | V-022 | done

Task: V-022 (Low, runtime, code quality) - html accepted six of seven non-string field kinds because the placeholder reflect.Value.String() renders matches its unanchored pattern, while an ordinary string was rejected.

Changed: baked_in.go (isHTML checks the kind), validator_test.go (one regression test), .jeffy/probes/_v022 (new battery with the class enumeration, and its paths file), BACKLOG.md (V-022 closed, one shape of the class settled, V-023 filed), PLAN.md (15 rows re-recorded, two Lessons).

Checkpoint: c3ca6b1d95030a8fcd2baa5dcdf187a5d2e0da81

Verification: `go test -cover -race -count=1 ./...` exits 0 over 24 packages at 96.4% root coverage. `go run ./.jeffy/probes/_v022` exits 0. All 28 batteries exit 0.

The filed reproduction ran first and reproduced on all six kinds. The pattern is `<[/]?([a-zA-Z]+).*?>`, unanchored, so "<int Value>" matches at the letters of "int" while "abc" has no angle brackets at all. The slice is the exception and stayed one: "<[]string Value>" opens with a bracket where the pattern needs a letter or a slash, so that kind was never reachable, and the battery keeps it for exactly that reason.

The class enumeration took three attempts and only the third measures the defect. The first drove all 181 tags on non-string values and flagged 26 tags; nearly all were artifacts, because the tag list carries no parameters, so `startswith` compares against an empty prefix and `noneof` against an empty set and both accept everything. The second added a discriminator - two values per kind that render to the same placeholder, on the theory that a kind-aware validator can tell 42 from 0 - and still flagged 25, because `required` skips a non-pointer struct by default and treats an empty non-nil slice as present, so its pairs are indistinguishable for reasons that have nothing to do with String().

The third works because it is a pure string test on both sides, where no tag needs a parameter to behave: which tags reject "abc" yet accept a placeholder-shaped string? That returns exactly one, html. But that alone is still the wrong assertion, and it failed against the fixed tree before I noticed - accepting "<int Value>" as a string is correct, and html should keep doing it. So the scan builds the risk set and the assertion is per pair: every tag that accepts a placeholder string must reject the field kind that placeholder stands for. Six at-risk pairs across 181 tags, all six leaking before the fix and none after.

Contract: html's string behaviour is unchanged, asserted at nine strings covering the open, close, self-closing and attribute forms, the two rejects "abc" and "a < b", the digit case "<1>", and the placeholder-shaped string itself. What changed is the verdict for a non-string kind, which is a behaviour change on the field/tag type pairing surface and is recorded as one: int, uint, bool, float64, map and struct now reject where they accepted.

The regression test discriminates: six differently-kinded fields tagged html must produce six errors, and against the unfixed tree it fails at the first assertion.

Battery ownership: the diff touches baked_in.go, declared by 17 paths files including _v022's new one, and validator_test.go, which none declare. All 28 batteries were run and all exit 0.

Surface inventory: baked_in.go changed, so the same 15 rows went stale and are re-recorded at this checkpoint on re-executed evidence.

Claims re-executed: the registered-tag count is still 181 and the skip-marker enumeration still returns 1, so the Oracle and fingerprint lines stand.

V-022 closed, and one shape of the kind-guard class with it. V-023 files the other shape, unix_addr's, where the predicate accepts ordinary strings so no string test can see it - both instances of that shape were found by hand, and the three-strike rule has no instrument to hand a third to.

Stall check: not a stall - baked_in.go and validator_test.go changed, V-022 was removed from Later and V-023 added.

Learnings: enumerate a class by the property that is actually wrong rather than the one that correlates with it - accepting a placeholder-shaped string is correct, and only accepting the field kind behind it is the defect, which is why the second formulation failed against the fixed tree. Any scan driving the whole tag list runs the param-taking tags bare, so build class enumerations from inputs that need no parameter or supply the table.

Next: three iterations remain and the run still needs the clean full audit the Definition of done requires - iteration 2's found one High and two Mediums, all now closed. Iteration 8 runs that audit, 9 the evaluator gate, 10 the declaration, carrying V-005 and V-023 as accurately scored Lows.

## iter 8/10 | 48ee2ba9-175310 | 2026-08-15 | AUDIT | audit

Task: the clean full fresh-evidence audit the Definition of done requires. Iteration 2's audit found one High and two Mediums; all three are closed, so this rescores every applicable dimension against the rubric and the Operating envelope on evidence executed this iteration.

Changed: BACKLOG.md (one Proposed item, no tasks filed).

Checkpoint: e3c3b783b0b54afca663c796a9fb4dbb0b9a1eac

Verification: every figure below was executed this iteration.

Environment fingerprint re-read first, since nothing may be called green if its exclusions are stale. All four claims hold unchanged: the build-constraint grep returns validate_fn.go and no_validate_fn.go, the skip-marker grep returns the single Windows unix-socket skip that does not fire on this linux host, `go list ./...` returns 24 packages with none under _examples, and .jeffy/ stays outside both by the dot-prefix rule. Surface staleness was computed rather than assumed, comparing each row's recorded commit against the last commit touching its implementing files: 0 stale of 31 rows, 0 unswept.

`go test -cover -race -count=1 ./...` exits 0 over 24 packages at 96.4% root and 100% non-standard coverage. All 28 batteries exit 0, the first audit in this project's history where none is red. `go vet ./...` exits 0. 66 benchmarks run clean.

Testing was not scored on the whole-suite run alone. `go test -count=2 -race ./...` exits 0, so no test depends on package state surviving a repeat; the non-standard package alone, four root tests each alone by name, and both the root and translations packages under -shuffle=on all exit 0; and the three Go batteries this run added exit 0 under `go run -race`.

Closeout begins with this entry.

Scores, each claiming all 31 rows because none is unswept or stale. Architecture None. Code quality Low - V-005's three gofmt-failing files, open and accurately scored. Security None. Testing None on swept rows, with V-023 filed as the known instrument gap. Error handling None. Performance None; the one superlinear path this project had was V-019 and it is closed. Documentation Low - V-013's 29 tags without a doc.go section, Declined on cost and capped by a battery that fails if the count grows. Dependency hygiene Low, reasoned below. Developer experience None. Correctness None on swept rows. Observability and UX/accessibility do not apply to a validation library with no logging, metrics, tracing or user-facing surface, and are recorded rather than scored.

The run's own diff was audited with the same suspicion as the rest, because two of this project's Lessons were learned losing iterations to exactly that. The question asked was how the five changed functions behave on inputs they were not written for. A named string type, a pointer to a string and a value reached through RegisterCustomTypeFunc all still pass html and unix_addr, because the executor resolves each to a String kind before the validator sees it, so neither kind guard broke the indirection paths. email rejects int, bool and struct, its pattern not matching the placeholder rendering that caught html. `dive` still reaches each element of a []string under both tags and reports the failing index. tcp4_addr still accepts a named string type carrying a host and port.

Documentation was checked against the two behaviour changes rather than assumed, since change discipline requires it. doc.go already says "This validates that a string value..." for both html and unix_addr, so this run's guards moved the implementations toward a documented contract they had been violating, and no documentation needed changing. That is the good case, and it was verified rather than hoped.

Dependency hygiene, the one score that needs its reasoning on the record. `govulncheck ./...` still exits 3 with the same three standard-library advisories, and that is expected rather than a regression: the tool is call-graph based, isEmail still calls mail.ParseAddress and the address tags still call net's resolvers, so the calls it reports are the calls that exist. What changed is what can reach them, and that is proven by two batteries that fail without their fixes - _v019 shows a 200KB comment-shaped value rejected in microseconds where it took five seconds, and _v020 shows zero of nine resolver sites reachable with a NUL where twenty-four tag/value pairs reached six of them. The advisories live in the toolchain, are fixed in go1.26.3, and no module in go.mod carries them. The only in-project lever left is raising the go directive, which breaks every consumer on Go 1.25.x, so it is filed as a Proposed item for the maintainer rather than scored as a defect. Low rather than None because a scanner does exit 3 on this tree, and rather than Medium because nothing actionable remains in this repository.

No finding was filed inside a Settled class, and no Declined item was re-filed.

Stall check: not a stall by the ceremony exemption - this is an AUDIT entry. It filed no task, which is the point: zero High and zero Medium in-envelope.

Learnings: check the documentation before assuming a behaviour change needs a documentation change - both tags this run guarded already documented the string contract their code was breaking, so the fix closed a gap rather than opening one. A scanner that stays red after the exposure is closed is not a regression and not a finding; record why its output cannot see the guard, or the next audit re-files what this one closed.

Next: closeout is in force, so no further audit and no replenishment. Two iterations remain. Iteration 9 invokes the adversarial evaluator gate and, on PASS, declares convergence in that same iteration, carrying V-005 and V-023 as accurately scored Lows and the go-directive item as Proposed. Iteration 10 is held for the findings a REJECT would file.

## iter 9/10 | 48ee2ba9-175310 | 2026-08-15 | EVALUATOR | converged

Task: the adversarial evaluator gate, invocation 1 of this run, and the declaration on its verdict.

Changed: .jeffy/evaluator/48ee2ba9-175310-1.md (the gate's artifact), BACKLOG.md (the Converged line), JOURNAL.md.

Checkpoint: 9a41d00345535f7d8487d40830ec12db4d144259

Verification: Evaluator: PASS - Verify green, all six closed tasks' acceptance checks green and each proven to fail against its own unfixed code, all 28 batteries green twice with the tree unmodified, every count in the state files re-executed to the value claimed, and no missed in-envelope High or Medium found. `go test -cover -race -count=1 ./...` exits 0 this iteration over 24 packages at 96.4% root coverage, and the gate re-ran it twice more to the same result.

The gate did more than re-run what this run ran. It reverted each of the six fixes in place and confirmed every acceptance check goes red against its own unfixed code, which is the property this run asserted per task and never checked as a set. It rebuilt from scratch the instrument V-023 describes, drove 181 tags across 7 kinds, found 32 acceptances and triaged every one to a parameter artifact, a legitimately kind-aware tag, or url_encoded's permissive predicate - so the V-023 gap is real but hides no defect today. And it settled the one thing iteration 5 could not: `govulncheck ./...` exits 3 on this host's go1.26.2 and exits 0 under go1.26.6, the toolchain a `go-version: stable` runner installs, which it verified by downloading that toolchain rather than reasoning about it.

Closing conditions, each checked this iteration. The full fresh-evidence audit at iteration 8 scored zero High and zero Medium in-envelope. The Surface inventory lists 31 rows, all swept, none unswept and none unreachable. Now and Next are empty and Later holds two open tasks, both Low with their severity on the line. The only commit between that audit and this iteration is its own bookkeeping commit. The Verify command is green. The evaluator returned PASS with its artifact committed by this iteration's checkpoint.

Carried Lows, listed by ID as the declaration requires:
- V-005 (Low, build-ci, code quality): three tracked files fail gofmt and .golangci.yaml declares no formatters section, so CI cannot catch it. Accurately scored, re-scored Low by the gate.
- V-023 (Low, test, testing): shape two of the kind-guard class has no mechanical check, so a third instance would have to be found by hand as the first two were. Accurately scored, re-scored Low by the gate, and the gate's own from-scratch build of that instrument found no defect hiding behind the gap.

Gate observations, recorded here for the next run and deliberately not fixed, because a fix after a PASS invalidates the PASS: the bi-validatefn row is recorded at 7ba6ba4 while baked_in.go, which holds its tag registration, has changed since - no code is uncertified, _sweep5 was re-run green every time, but the recorded hash lags under a stricter reading of that row's implementing set than its battery's paths file takes; .jeffy/probes/_hostile has no failing exit path, so its presence in "all batteries green" is weaker than it reads; .jeffy/probes/_v020/driver/main.go fails gofmt, outside V-005's scope by that finding's own filter; there is no Email benchmark, so make bench could not have caught a hot-path move in isEmail; and TestEmailDoesNotParseWhatTheRegexRejects is the suite's only wall-clock assertion, with about five orders of magnitude of margin.

Converged. The Definition of done is verifiably true and the Converged line naming this iteration's checkpoint is appended to BACKLOG.md.

Stall check: not a stall by the ceremony exemption - this is the EVALUATOR entry that declares.

Learnings: give the gate the whole set of acceptance checks and it will do what per-task verification does not - prove each one fails against its own unfixed code as a batch, which is the check that would have caught a fix verified against the wrong thing. A question a run cannot answer on its host is worth handing to the gate rather than leaving in a caveat: iteration 5 could only say what a floating toolchain would probably do, and the gate downloaded that toolchain and measured it.

Next: nothing in this run. The next run starts from a converged tree with V-005 and V-023 on the ledger, the go-directive item awaiting a maintainer decision under Proposed, and five gate observations to triage.
