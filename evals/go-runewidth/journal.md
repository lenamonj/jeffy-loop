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

## iter 1/10 | e3847ccb-222829 | 2026-09-01 | AUDIT | audit

Task: first audit of a fresh Jeffy project - fill the Operating envelope, the Surface inventory, and the Verify command block in PLAN.md, enumerate the artifact-producing channels, then audit the project against every applicable dimension and seed BACKLOG.md.

Changed: PLAN.md (envelope surfaces, ten inventory rows, Verify command block with Oracle class, Environment fingerprint and a measured Verify duration), BACKLOG.md (12 findings: 1 High, 5 Medium, 6 Low, plus 2 Proposed decisions), JOURNAL.md, .gitignore (bootstrap entry for the transient loop state file).

Checkpoint: 286f061926a15ab017a7fa8dcbacb4680802806b

Verification:
- Verify command established as `go vet ./... && go test ./... -count=1 -race`, run through the installed quiet-verify.sh: green (3s), summary line `ok github.com/mattn/go-runewidth 2.416s`. The suite is the only gate; there is no conformance corpus.
- Artifact channels enumerated by command, not recall: the tree carries no packaging manifest of any kind (no Cargo.toml, package.json, MANIFEST.in, gemspec, nuspec, Dockerfile or release workflow) - the single publication channel is the Go module proxy, which zips the repository tree. Verified concretely by `go mod download github.com/mattn/go-runewidth@v0.0.16` and `unzip -l` on the resulting zip: all 16 root and .github files are present, including .github/FUNDING.yml and the workflow. Go has no per-file exclusion, so the loop's state files will ship in the next tagged release. Filed as RW-11 at Medium with its Consequence, and the half Go cannot fix at all raised under Proposed.
- Width tables checked against their real upstream oracle rather than against the suite's own pins: `go generate ./...` re-fetched Unicode 17.0.0 EastAsianWidth.txt and emoji-data.txt and regenerated runewidth_table.go byte-identically - no drift. This also establishes that RW-06's dead CI guard is masking nothing today.
- RW-01 reproduced: `runewidth.Wrap("hello", 0)` panics with "runtime error: integer divide by zero".
- RW-02 reproduced: with s the two-family ZWJ string repeated, StringWidth(s) is 4 while Wrap(s, 4) returns "\U0001F468‍\U0001F469‍\n\U0001F466\U0001F468‍\n\U0001F469‍\U0001F466" - three lines, two ending on a dangling ZWJ.
- RW-03 reproduced: Wrap("abc\xffdef", 2) returns bytes carrying U+FFFD where the input had 0xFF; Truncate, TruncateLeft, TruncatePrefix and StringWidth all leave the byte alone.
- RW-04 reproduced: StringWidth("つのだ☆HIRO") is 11 under the default condition and 12 only with EastAsianWidth set; the README asserts 12 unconditionally.
- RW-05 reproduced: sweeping all 0x110000 runes with StrictEmojiNeutral true and false, the flag changes 1620 widths when EastAsianWidth is true and none at all when it is false; 1652 runes of the emoji table are one cell wide in the non-East-Asian path, so the inertness is not vacuous.
- Documented parameters exercised at both values: EastAsianWidth changes 138370 rune widths, StrictEmojiNeutral changes 1620 in the East-Asian path and none outside it (RW-05), ZeroWidthJoiner changes nothing and is documented as a no-op. Condition.CreateLUT was checked against the non-LUT path across the whole rune space for all four flag combinations and agreed everywhere.
- Invariants probed and holding: Truncate output never exceeds the requested width; FillLeft and FillRight land exactly on max(w, StringWidth(s)); no public function panics on invalid UTF-8, lone surrogates, NUL, or over-range runes.
- Tests run in isolation per the Method: TestRuneWidthConcurrent under -race, TestTableChecksums, TestEnv and TestIsEastAsianLANG each pass alone. That isolation run is what surfaced RW-09 - the concurrency test is ordered after three tests that build the LUT, so it exercises nothing in a full-suite run.
- govulncheck: no vulnerability reachable from this code; every hit is stdlib and uncalled. uax29 is pinned at v2.2.0 against a published v2.7.0 (RW-12, maintenance not exposure).
- Dimension scores, claiming only what this audit examined: error handling High (RW-01), correctness Medium (RW-02, RW-03), documentation Medium (RW-04, RW-05), architecture Medium (RW-11), code quality Low, testing Low, dependency hygiene Low, developer experience Low, security None, performance None. Observability does not apply - the package emits no logs, metrics or traces by design. UX and accessibility do not apply - there is no user-facing surface, only a Go API. Every one of those scores is preliminary: all ten Surface inventory rows are still unswept, no probe battery exists yet under .jeffy/probes/, and the audit probed each row shallowly rather than certifying any of them.

Learnings: quiet-verify.sh does not strip backticks from the PLAN.md `Command:` payload - a backtick-wrapped command is executed as a shell command substitution, so the suite runs, its `ok ...` line is then executed as a command, and the gate reports exit 127. Write the Command line bare.

Next: RW-01, the only High and the top of the queue.

## iter 2/10 | e3847ccb-222829 | 2026-09-01 | RW-01 | done

Task: RW-01 (High, runtime, error handling) - Condition.Wrap panicked with "runtime error: integer divide by zero" for w of 0, at the capacity hint out.Grow(len(s) + len(s)/w + 1).

Changed: runewidth.go (guard the capacity hint's division), runewidth_test.go (TestWrapNonPositiveWidth, plus the strings import it needs), BACKLOG.md (RW-01 deleted from Now), JOURNAL.md.

Checkpoint: ebfbcd29929372e1496685c740a3a315595b18ae

Verification:
- Filed reproduction run first, as the working rules require: `go test -run TestWrapNonPositiveWidth -count=1 .` against the unfixed code exits 1 with `panic: runtime error: integer divide by zero` naming Condition.Wrap in runewidth.go.
- Acceptance check after the fix: the same command exits 0. The test drives both non-positive widths, 0 and -1, over five inputs - empty, ASCII, wide CJK, a string that already contains a newline, and a combining-mark cluster - and asserts the invariant that Wrap only ever inserts newlines, so stripping them returns the input.
- Verify gate through the installed quiet-verify.sh: green (3s), summary line `ok github.com/mattn/go-runewidth 2.404s`.
- Contract preserved for every w greater than 0: the guarded expression is the same arithmetic, len(s) + len(s)/w + 1, only reassociated, and strings.Builder.Grow sets capacity without touching content, so no output can differ. TestWrap, which pins Wrap at w of 30 against a hand-written expected string, still passes.
- Wrap(s, 0) now returns what Wrap(s, -1) already returned before this change: a newline before each rune that would overflow the budget, so "hello" becomes "\nh\ne\nl\nl\no". That is the loop's existing behaviour at non-positive widths, reached rather than changed - only the panic in the capacity hint stood in front of it. No documented promise covers w of 0, and widening Wrap's contract there would be a behaviour change beyond the filed defect.

Learnings: none new this iteration.

Next: the queue's top is now the ten unswept Surface inventory rows, which outrank the five open Mediums.

## iter 3/10 | e3847ccb-222829 | 2026-09-01 | SWEEP | done

Task: sweep the Surface inventory. With no open High, the map outranks every open Medium and Low, and ten rows were unswept with eight iterations left.

Changed: .jeffy/go.mod and .jeffy/internal/check/ (a nested probes module and its shared harness), ten batteries under .jeffy/probes/ each with a paths, claims and README file, PLAN.md (inventory rows flipped, the windows row split out and disclosed), BACKLOG.md (RW-13 filed), JOURNAL.md.

Checkpoint: c1ce47c7925c76c30a0ca41a93015af8057371a6

Verification:
- Ten batteries written and executed, each certifying one inventory row: rune-width-core (103 checks), width-data-tables (60), string-width (55), truncation-family (36), wrap-and-fill (34), classification-predicates (34), locale-env-posix (22), published-module-contents (18), combined-lut (16), locale-detection-constant (4). check-claims.sh over the whole probes directory reports 10 checked, 0 mismatched, 0 errored, 0 skipped.
- Every battery was observed failing before it was trusted, each against a planted one-line mutation recorded in its README: the nonprint boundary narrowed to r < 0x1F, a combining interval inverted to {0x0300, 0x02FF}, IsNeutralWidth pointed at the narrow table, the LUT nibble packing shifted by three instead of four, the grapheme cluster cap raised to three cells, Truncate's budget comparison loosened to >=, FillRight padding with a dot, handleEnv comparing RUNEWIDTH_EASTASIAN against "2", and appengine's IsEastAsian returning true. Each reddened the checks its README names; the tree was restored from a pristine copy after every one and git status confirms no tracked file changed.
- published-module-contents needed no planted mutation: its first run failed against the tree's real state, naming .gitignore, benchstat.txt, new.txt and old.txt as residue in the module zip, which is RW-10.
- The batteries are not a second call into the same code. width-data-tables parses runewidth_table.go as text and checks the sortedness, non-overlap, well-formedness and coalescing that inTable's binary search assumes and nothing in the package verifies. string-width carries two differential oracles: every one-rune string against RuneWidth over the whole plane, and every one- and two-byte ASCII string against a byte count written in the battery. published-module-contents builds the real module zip with golang.org/x/mod/zip, the library the proxy itself uses.
- Two rows are now covered that the package's own suite cannot reach. rune-width-core drives concurrent first use of the lazy strict-width LUT from a process where nothing has touched it, which is exactly what RW-09 records TestRuneWidthConcurrent failing to do. locale-env-posix re-executes itself with RUNEWIDTH_EASTASIAN set, because handleEnv reads it at package init and no in-process test can observe that.
- The js build is executed, not merely compiled: GOOS=js GOARCH=wasm under the toolchain's own node shim, asserting IsEastAsian stays false under a CJK locale. appengine likewise through its build tag.
- The windows row was split off and marked [~]. Its IsEastAsian calls kernel32 GetConsoleOutputCP through syscall.NewLazyDLL and cannot execute on Linux, so the WT_SESSION opt-out and the five CJK console code pages are unexercised here. The file is cross-compiled by the locale-detection-constant battery so a build break is still caught, and no entry in this journal claims that surface was swept.
- Two of the battery's own expectations were wrong and the library was right, which is recorded rather than quietly corrected: U+0590 is unassigned and absent from the generated neutral table (filed as RW-13), and combining and neutral overlap by construction because one table is General_Category and the other East Asian Width.
- .jeffy/ is now a nested Go module. That is what keeps the batteries out of go vet ./... and go test ./... at the root, and the published-module-contents battery confirms the same nested go.mod excludes every path under .jeffy/ from the module zip. It does not close RW-11, whose remaining half is the root state files that Go has no mechanism to exclude.
- Verify gate through the installed quiet-verify.sh, after the nested module landed: green (3s), summary line `ok github.com/mattn/go-runewidth 2.417s`.
- Rows swept this iteration: 9 of 11, plus 1 disclosed unreachable. Row 11, published module contents, is swept; nothing is left unswept.

Learnings: a battery that asserts a property the library never promised fails as a probe bug, not a finding - two expectations here were wrong about Unicode, not about the code. Check an expectation against the primary data before filing anything from it.

Next: the four remaining open Mediums, RW-02 first.

## iter 4/10 | e3847ccb-222829 | 2026-09-01 | RW-02 | done

Task: RW-02 (Medium, runtime, correctness) - Condition.Wrap measured and cut per rune while StringWidth and the truncation family measure per grapheme cluster, so it split ZWJ sequences and flag pairs and disagreed with the package's own width function. RW-03 is the same root cause seen from the other side and closed by the same change: ranging over runes and writing them back with WriteRune re-encoded every undecodable byte as U+FFFD.

Changed: runewidth.go (Wrap now dispatches to wrapASCII or wrapClusters), runewidth_test.go (three tests: cluster boundaries, byte preservation, and the differential between the two paths), .jeffy/probes/wrap-and-fill (battery, claims and README updated for the closed findings), BACKLOG.md (RW-02 and RW-03 deleted from Next), JOURNAL.md.

Checkpoint: 0fba41f61985ea6f777dbe5d0e9a5d985525153e

Verification:
- Both filed reproductions run first against the unfixed code: `go test -run 'TestWrapSplitsOnlyAtClusterBoundaries|TestWrapPreservesBytes' -count=1 .` exits 1 with 42 failure lines, the first naming a break at byte 4 inside a ZWJ cluster. After the fix the same command exits 0.
- RW-02's acceptance as written: Wrap now splits only at boundaries the segmenter reports, over a six-string corpus at every budget from one to eight cells, and the two-family string comes back unsplit at a budget of four, which is the width StringWidth reports for it.
- RW-03's acceptance as written: stripping newlines from Wrap's output returns the input byte for byte, over six undecodable inputs including a Latin-1 e-acute, at three budgets.
- One root cause, two filed symptoms: both lines came from `for _, r := range s` with `out.WriteRune(r)`, and closing one without the other would have left the same loop in place. Recorded here rather than closed as two independent tasks.
- Contract preserved: TestWrap, the pre-existing pin at a budget of 30 over a mixed CJK and ASCII string, passes unchanged, so wrapping of ordinary text is byte-identical. TestWrapNonPositiveWidth, the RW-01 boundary, also still passes.
- The change carried a measured performance cost, so it is not left unmeasured. A grapheme walk over pure ASCII ran about three times slower than the rune loop it replaced (3.7 to 11.0 microseconds on an 880-byte ASCII paragraph), which is why Wrap now takes the same ASCII shortcut StringWidth already takes. Measured on this host with a temporary benchmark, since removed: ASCII 3923 nanoseconds per operation before the change and 1650 after, a 2.4x improvement over the original; CJK 2712 before and 5662 after and mixed 2658 before and 6387 after, roughly 2.1x and 2.4x slower, which is what correct cluster segmentation costs and what StringWidth and the truncation family already pay. Allocations are unchanged at one per call on every input.
- The ASCII shortcut is only safe if it agrees with the cluster walk everywhere, so that is asserted rather than argued: TestWrapASCIIPathMatchesClusterPath drives both unexported paths over a fourteen-string corpus at every budget from -1 to 12. It found a real divergence on the first run - CRLF is a single grapheme cluster, so the cluster path never measured the CR alone while the byte loop did, and the two produced different output at a non-positive budget. The byte loop now treats CRLF as one unit and the differential is clean.
- Battery ownership: the diff touched runewidth.go, and eight of the ten batteries declare that path. All eight were re-run through the installed run-probe.sh and all exit 0: rune-width-core 103/103, width-data-tables 60/60, string-width 55/55, wrap-and-fill 39/39, truncation-family 36/36, classification-predicates 34/34, locale-env-posix 22/22, combined-lut 16/16. Their rows are re-recorded at this iteration's checkpoint in the bookkeeping edit below.
- The wrap-and-fill battery pinned RW-02 and RW-03 as open and explicitly declined to certify cluster integrity or byte preservation. It is updated in this same iteration to assert both, and its claim moves from 34 to 39 checks. check-claims.sh over all ten batteries: 10 checked, 0 mismatched, 0 errored, 0 skipped.
- Verify gate through the installed quiet-verify.sh: green (3s), summary line `ok github.com/mattn/go-runewidth 2.405s`.

Learnings: when a fast path is added beside a general one, the differential between them belongs in the suite, not in the reasoning - the CRLF divergence here was invisible to inspection and appeared on the first run of the differential test.

Next: RW-04, the README example that states a width the default configuration never produces.

## iter 5/10 | e3847ccb-222829 | 2026-09-01 | RW-04 | done

Task: RW-04 (Medium, docs, documentation) - the README's only usage example asserted StringWidth("つのだ☆HIRO") == 12, which is the East Asian answer; the default condition returns 11 on any locale that is not CJK.

Changed: README.md (the example corrected to 11, with the ambiguity explained and a second example showing how to get 12), runewidth_test.go (TestREADMEExamples, which runs both README snippets as written), BACKLOG.md (RW-04 deleted from Next, RW-14 and RW-15 filed under Later), JOURNAL.md.

Checkpoint: 8653c39665445dc0241485b095934f365475b1d5

Verification:
- Filed reproduction run first against the README as it stood: a test asserting the documented value of 12 exits 1 with "README as filed says StringWidth == 12, got 11".
- Publication rule honoured: the README's code is now executed in exactly the form it is published. TestREADMEExamples runs both snippets verbatim - the package-level call, and the NewCondition form with EastAsianWidth set - and asserts the two values the README states, 11 and 12.
- Establishing the fix's own facts first turned up a trap the README would otherwise have walked into. Assigning to the exported package variable EastAsianWidth does not change what runewidth.StringWidth returns: the package-level functions read DefaultCondition, and only handleEnv, which runs at init, ever copies the variable into it. NewCondition does read it, so a condition built afterwards honours it. The README therefore documents the NewCondition form rather than the assignment, and states plainly that the assignment does not affect the package-level functions. Filed as RW-14 at Low, because the variable's doc comment describes it as an output of locale detection and promises nothing about writing it.
- The verify gate went red on this iteration's own new test and the cause is recorded rather than papered over. TestREADMEExamples passed alone and failed in a full run, because TestDefaultLUT leaves the package in East Asian mode: its deferred restore puts RUNEWIDTH_EASTASIAN back but never calls handleEnv again, so the globals keep the last loop iteration's value. Isolated by bracketing a run with probes that sort before and after it in the file order: with TestDefaultLUT between them the probes report EastAsianWidth false then true and StringWidth 11 then 12; with TestEnv between them instead, both report false and 11. Filed as RW-15 at Low, class test.
- The test was fixed rather than the gate worked around: TestREADMEExamples now establishes the condition the README names instead of inheriting whatever an earlier test left, saving and restoring both EastAsianWidth and DefaultCondition.EastAsianWidth so it perturbs nothing itself. It passes alone and in a full run. The claim about the assignment having no effect is asserted as a before-and-after comparison, which is what that claim actually says, rather than as a fixed number that would inherit the same ambient dependence.
- Battery ownership: the diff touched README.md and runewidth_test.go. No battery declares either path, so none needed re-running, and no Surface inventory row is stale. The string-width battery already pins this same example at 11 and 12 under explicit conditions and remains green.
- Verify gate through the installed quiet-verify.sh: green (3s), summary line `ok github.com/mattn/go-runewidth 2.849s`.

Learnings: a test that asserts a documented default must establish that default itself; inheriting it from whatever the suite left is how a check passes alone and fails in the suite. Run a new global-state-sensitive test both ways before trusting it.

Next: RW-05, the StrictEmojiNeutral documentation.

## iter 6/10 | e3847ccb-222829 | 2026-09-01 | RW-05 | done

Task: RW-05 (Medium, docs, documentation) - StrictEmojiNeutral was documented as "should be set false if handle broken fonts" with no restriction stated, but it has no effect at all while EastAsianWidth is false, which is the default everywhere outside a CJK locale.

Changed: runewidth.go (the package variable's doc comment rewritten, and the Condition field given one of its own), runewidth_test.go (TestStrictEmojiNeutralScope), .jeffy/probes/rune-width-core (the flag now exercised at both values in both modes, claim 103 to 110 checks, README updated), BACKLOG.md (RW-05 deleted from Next), JOURNAL.md.

Checkpoint: 44c1dfe9e473b0e3eeee5d44e4117e99e2fe4d3a

Verification:
- Filed reproduction run first: a test asserting the reading the unrestricted doc comment invites - that the flag has effect in any configuration - exits 1 with "StrictEmojiNeutral has no effect when EastAsianWidth is false, but its documentation states no restriction".
- The scope was measured, not inferred, before a word was written. Sweeping all 0x110000 runes for both settings in both modes: with EastAsianWidth false the flag changes no rune's width; with it true it changes 1620, every one of them in the emoji table and every one from one cell to two. Separately, 1652 emoji-table runes measure one cell in the non-East-Asian mode, so the inertness is not vacuous - there is a real population the flag would move if it applied there.
- Documentation now states exactly that scope on both the package variable and the Condition field, and TestStrictEmojiNeutralScope asserts it over the whole rune space: zero changes while EastAsianWidth is false, a non-empty change set while it is true, no rune outside the emoji table touched, and no change other than one cell to two.
- The behaviour was documented rather than altered, deliberately. Making the flag effective in the non-East-Asian path would move the width of a large block of emoji runes for every caller who sets it false, in a library most Go terminal programs depend on. That is the maintainer's call and it is already on the ledger as a Proposed item, which is never worked without approval.
- Sweep bar honoured for the row this touches: StrictEmojiNeutral is a documented parameter on the rune-width core surface and the battery did not exercise it. It now drives both values in both modes with the same three assertions, plus U+203C - in the emoji table, neutral in the width tables - as a known answer in all four combinations: one cell everywhere except loose-and-East-Asian, where it is two.
- Battery ownership: the diff touched runewidth.go, which eight batteries declare. All eight re-run through the installed run-probe.sh and all exit 0: rune-width-core 110/110, width-data-tables 60/60, string-width 55/55, wrap-and-fill 39/39, truncation-family 36/36, classification-predicates 34/34, locale-env-posix 22/22, combined-lut 16/16. Their rows are re-recorded at this iteration's checkpoint in the bookkeeping edit below. check-claims.sh: 10 checked, 0 mismatched, 0 errored, 0 skipped.
- Verify gate through the installed quiet-verify.sh: green (3s), summary line `ok github.com/mattn/go-runewidth 2.929s`.

Learnings: none new this iteration.

Next: RW-11, the last open Medium, on what the published module zip carries.

## iter 7/10 | e3847ccb-222829 | 2026-09-01 | RW-11 | done

Task: RW-11 (Medium, build-ci, architecture) - the Go module zip is built from the whole repository tree, so the loop's own state files reach every consumer of the next tagged release.

Changed: .jeffy/probes/published-module-contents (the symlink lever now checked in a scratch module of its own, claim 18 to 21 checks, README updated), BACKLOG.md (RW-11 deleted from Next, and its Proposed item rewritten around a claim that turned out to be false), JOURNAL.md.

Checkpoint: 51e6d9085815933b413175119ff2901cadaf4e7b

Verification:
- The half of this finding that had a mechanism is closed and checked, not assumed: .jeffy/ carries its own go.mod, and the published-module-contents battery builds the real module zip with golang.org/x/mod/zip - the same library the proxy uses - and asserts no path under .jeffy/ appears in it.
- The other half rested on a claim this iteration falsified. Both RW-11's line and its Proposed item said Go has no mechanism to exclude a file at the module root. That is wrong. A scratch module built for the purpose shows a symlinked root file is omitted from the zip, reported by CheckDir as "not a regular file", while its target under a subdirectory ships and a regular root file ships. So the root state files can be excluded after all, by pointing each at a subdirectory that carries its own go.mod.
- That lever is now a check rather than a one-off experiment. The battery builds its own scratch module with a symlink, a symlink target and a regular file, and asserts all three outcomes, so the Proposed decision rests on something re-derivable rather than on this journal entry.
- The footprint the decision is about, measured from the real zip at this commit: the module holds 25 files and 189278 uncompressed bytes, of which PLAN.md, BACKLOG.md and JOURNAL.md account for 80738 bytes across 3 files, or 42.7 percent. Recorded here rather than in the ledger, because it grows with every journal entry and a standing claim that drifts by construction is worse than none.
- The lever was not applied. A Windows checkout without symlink privilege materialises a symlink as a text file holding its target path, which would both break the loop's own reads and ship the junk it was meant to remove, and rearranging the loop's state layout in someone else's repository is the maintainer's call. The Proposed item now states both options and that cost, so the decision is informed rather than deferred.
- Battery ownership: the diff touched .jeffy/probes/published-module-contents and BACKLOG.md. No battery declares either path, and the paths this battery does declare - go.mod, go.sum, .gitignore - are unchanged, so no row went stale. The battery was re-run anyway because it changed: 21/21 through the installed run-probe.sh. check-claims.sh: 10 checked, 0 mismatched, 0 errored, 0 skipped.
- Verify gate through the installed quiet-verify.sh: green (3s), summary line `ok github.com/mattn/go-runewidth 2.943s`.
- The ledger is now at the severity floor: zero High and zero Medium open, nine Low. The Surface inventory lists no unswept row. No full audit this run has yet scored clean, so convergence still needs one.

Learnings: a Proposed item that asserts an impossibility is a claim like any other and gets checked before it is written down; this one said Go could not exclude a root file, and ten minutes with a scratch module showed it can.

Next: the top open Low, RW-07.

## iter 8/10 | e3847ccb-222829 | 2026-09-01 | AUDIT | audit

Task: the closing full audit. The ledger reached the severity floor at iteration 7 and the Surface inventory lists no unswept row, but no full fresh-evidence audit on this run's record had scored clean, so convergence needed one. Closeout begins with this entry: no further audit and no replenishment for the rest of the run.

Changed: PLAN.md (Oracle class sharpened to name the three differentials this run added), BACKLOG.md (RW-16 filed under Later), JOURNAL.md.

Checkpoint: 78dc80f56881c3e4f1cb01293434a5a1a3384e36

Verification:
- Environment fingerprint re-derived rather than re-read: `go env GOOS GOARCH GOVERSION` gives linux amd64 go1.26.2; `go list -f '{{.GoFiles}} {{.TestGoFiles}} {{.IgnoredGoFiles}}' .` still excludes exactly runewidth_appengine.go, runewidth_js.go and runewidth_windows.go from this platform's build; `grep -rn 't\.Skip\|testing\.Short' --include='*.go' .` returns nothing, so no test asset the command reaches is skipped. The dependency set is unchanged at one non-stdlib module. Nothing in this run's entries claims a target the fingerprint says the command cannot reach.
- All ten batteries re-run through the installed run-probe.sh, all exit 0: rune-width-core 110/110, width-data-tables 60/60, string-width 55/55, wrap-and-fill 39/39, truncation-family 36/36, classification-predicates 34/34, published-module-contents 21/21, locale-env-posix 22/22, combined-lut 16/16, locale-detection-constant 4/4. check-claims.sh: 10 checked, 0 mismatched, 0 errored, 0 skipped. Declined and Settled classes are both empty, so there is no recorded premise or enumeration to re-derive.
- Fresh evidence on the code this run changed, not a re-reading of it. Wrap's two paths were driven exhaustively against each other over every string built from a NUL, a tab, LF, CR, a C0 control, a space, a letter and DEL up to length three, at every width from -1 to 4: they agree everywhere, including on the trailing lone CR the byte loop's CRLF special case does not cover.
- One new finding, filed as RW-16 at Low: Truncate returns a string wider than its budget whenever the tail alone does not fit, and its doc comment does not say so. Reproduced 36 times across five inputs, six tails and every width from 0 to 12. Scored Low rather than Medium against the Operating envelope's user-error class for the width argument, which is the line the downgrade rests on: a budget narrower than the caller's own ellipsis is a self-contradictory request and every alternative loses more than it saves.
- Examined and deliberately not filed: runewidth_windows.go loads kernel32 through syscall.NewLazyDLL rather than a system-directory loader. kernel32 is in the Windows KnownDLLs set and is already mapped into every process, so the preloading vector the general lint targets does not apply, and this host cannot execute the path to reproduce anything. Recorded here rather than filed as a security finding nobody could check.
- Fresh dependency scan: govulncheck reports zero vulnerabilities reachable from this code; every hit is stdlib and uncalled. gofmt reports no unformatted file in either module, and go vet is clean in the probes module as well as in the root one.
- Dimension scores, on the whole mapped surface with every row swept and no unexamined remainder: correctness None, error handling None, security None, architecture None, performance None, documentation Low, code quality Low, testing Low, dependency hygiene Low, developer experience Low. Observability does not apply - the package emits no logs, metrics or traces by design. UX and accessibility do not apply - there is no user-facing surface, only a Go API. Zero High and zero Medium in-envelope.
- Verify gate through the installed quiet-verify.sh: green (3s), summary line `ok github.com/mattn/go-runewidth 3.054s`.
- The ten open findings are all Low and all carried: RW-06, RW-07, RW-08, RW-09, RW-10, RW-12, RW-13, RW-14, RW-15, RW-16.

Learnings: none new this iteration.

Next: the evaluator gate, and the declaration if it returns PASS.

## iter 9/10 | e3847ccb-222829 | 2026-09-01 | EVALUATOR | audit

Task: the adversarial evaluator gate, invocation 1 of this run, after bringing every standing claim current.

Changed: PLAN.md (a Surface inventory row's prose reworded to stop citing two closed finding IDs), BACKLOG.md (RW-17 filed in Now, RW-18 and RW-19 in Later), .jeffy/evaluator/e3847ccb-222829-1.md (the gate's artifact), JOURNAL.md.

Checkpoint: a184d30848371bf8f19436677904323039838b80

Verification:
- Standing claims brought current before the invocation, not after. Every swept row was checked mechanically by asking git whether any path in its battery's paths file changed since the commit the row records: all ten are current, none stale. Declined holds no entry and Settled classes holds none, so there was no recorded Derivation or enumeration to re-run. check-claims.sh: 10 checked, 0 mismatched, 0 errored, 0 skipped. The Oracle class and Environment fingerprint were re-derived by command in the closing audit one iteration ago and re-read here. Verify count is deliberately empty because the summary line's first integer is the suite's duration and not a total, which is the case PLAN.md tells us to leave blank.
- One currency defect found and fixed before invoking: PLAN.md's wrap-and-fill row cited RW-02 and RW-03, both closed and deleted from the ledger, so two of the four finding IDs the file named no longer resolved. Reworded to name the property rather than the closed IDs. Spending an invocation on that would have been an invocation the declaration then lacked.
- Evaluator: REJECT, one substantiated reason, scored Medium, and it is a regression this run introduced.
- The reason, verified independently here rather than taken on the gate's word: wrapClusters resets the column only when a cluster is exactly "\n" or "\r\n". The comment above it asserts that no other cluster contains a line break. uax29 falsifies that: for the input "abcde\n\xed" the segmenter returns "a","b","c","d","e" and then the single cluster "\n\xed", gluing the newline to the truncated lead byte. The newline branch is skipped, the column never resets, and the next cluster overflows the budget. Wrap("abcde\n\xed", 5) returns "abcde\n\n\xed" at HEAD - a blank line the input does not contain - where the base commit returned "abcde\n" and one replacement character. The gate measured the shape of it too: 19535 of 1000000 fuzz samples diverge from a newline-resetting reference, all 54 lead bytes 0xC2 to 0xF7 trigger it, and none of the valid runes do.
- This is precisely the failure the working rules name: a prose claim that generalises over a set of sites shipped without the enumeration of that set. The comment asserted a property of every grapheme cluster uax29 can produce, and it was never checked against one. Neither the suite nor the battery could see it - TestWrapPreservesBytes strips newlines from both sides, the cluster-boundary and ASCII differentials use only valid UTF-8 and ASCII, and the battery's invariant is that no line exceeds its budget, while this defect makes a line shorter.
- Filed as RW-17 at Medium with the reproduction and a differential acceptance check over every affected lead byte. The run does not converge this iteration.
- Everything else the gate checked held: the Verify command exits 0, all ten batteries are green, RW-01, RW-02 and RW-03 reproduce as failures on the base commit and pass at HEAD, RW-04 and RW-05's as-filed reproductions fail on base and are answered at HEAD, and RW-11's acceptance was re-derived independently by building the module zip - 25 files, none under .jeffy/. Old Wrap against new Wrap showed no mismatch over ASCII or over single-rune-cluster text.
- Two of the gate's Low observations were substantiated here and filed rather than waved through. RW-18: the doc comment written for TestWrapNonPositiveWidth sits above TestStrictEmojiNeutralScope, describing a function two hundred lines away, because a later insertion of mine landed between the comment and its function. RW-19: the published-module-contents battery builds its zip from the working tree, so the untracked .claude/jeffy-loop.local.md reaches its listing and passes only because the residue classifier accepts any .md path - confirmed by listing the dot-paths in a zip built the same way. The instrument measures the working tree while claiming to describe the published one.
- The gate's remaining observations were checked and need no ledger line. Verify count empty is the documented-correct state for a summary line whose first integer is a duration. RW-10 and the closed RW-11 do share a rubric clause, and both state their consequence openly. RW-16's downgrade rationale is disclosed on its own line.
- Invocation accounting: 1 of 2 used. The cap is 2 rather than 3 because this first invocation landed at iteration 9, past the midpoint of a ten-iteration budget. One invocation remains, and it is the one the declaration needs.
- Verify gate through the installed quiet-verify.sh: green (3s).

Learnings: a comment that says "no other X does Y" is a prose claim over a set and needs its enumeration in the same iteration; this one asserted a property of every grapheme cluster the segmenter can emit and was refuted by the first invalid byte after a newline.

Next: RW-17, the gate-filed regression, then the second and last invocation and the declaration.

## iter 10/10 | e3847ccb-222829 | 2026-09-01 | RW-17 | done

Task: RW-17 (Medium, runtime, correctness), the regression the evaluator gate filed at invocation 1 - Wrap inserted a line break the input never asked for when a newline was followed by a truncated multi-byte sequence.

Changed: runewidth.go (wrapClusters finds the line break inside a cluster instead of matching the whole cluster against one), runewidth_test.go (TestWrapNewlineClusterResetsColumn), .jeffy/probes/wrap-and-fill (the property added, claim 39 to 42 checks, README updated), BACKLOG.md (RW-17 deleted from Now), JOURNAL.md.

Checkpoint: b700206a373baf28eea80165e6389d88af74ca4d

Verification:
- Filed reproduction run first against the unfixed code: `go test -run TestWrapNewlineClusterResetsColumn -count=1 .` exits 1, reporting Wrap("abcde\n\xed", 5) as "abcde\n\n\xed" where the input is five cells followed by a break and a one-cell tail, so nothing should be inserted. After the fix the same command exits 0.
- The fix reads the break out of the cluster rather than comparing the cluster to it: wrapClusters now takes the last newline byte inside the cluster, writes the cluster, and restarts the column at the width of whatever follows that byte. The old code compared the whole cluster against "\n" and "\r\n" on the strength of a comment claiming no other cluster could hold a break, which the segmenter falsifies for every truncated lead byte.
- Acceptance as filed, both halves: the single reproduction, and a differential over every lead byte from 0xC2 to 0xF7 following a newline at a budget the prefix exactly fills - 54 inputs, each of which must come back unchanged and must contain no empty line. All 54 fail on the unfixed code and pass on the fixed one.
- A third assertion distinguishes the fix from a lazier one: resetting the column to zero would also pass the first two, so the test pins Wrap("abcde\n\xedxyz", 3) as "abc\nde\n\xedxy\nz", where the break before z falls one character earlier than a zero reset would put it, because the invalid byte already occupies a cell of the new line.
- Contract preserved: every other wrap test passes unchanged, including TestWrap's pin at a budget of 30, the RW-01 non-positive-budget boundary, the cluster-boundary and byte-preservation tests, and the exhaustive ASCII-versus-cluster differential. The ASCII path needed no change - in ASCII the only cluster holding a break is "\n" or "\r\n", and the new rule restarts the column at the width of the empty tail, which is zero, exactly as the byte loop does.
- The verify gate went red mid-iteration and the cause is recorded rather than worked around. The new test passed alone and failed in the full suite, reporting one character's difference, because the byte after the newline decodes to U+FFFD, which is East Asian Ambiguous and therefore two cells under the East Asian widths, and TestDefaultLUT leaves the package in that mode - RW-15, already on the ledger. This is the second time this run that an ambient-default dependence bit a new test, and the Lesson recorded after the first time is the one I failed to apply. The test now uses an explicit non-East-Asian Condition rather than the package-level function, so it is order-independent by construction: green alone and green in the full suite.
- Battery ownership: the diff touched runewidth.go and runewidth_test.go. All eight batteries declaring runewidth.go re-run through the installed run-probe.sh and all exit 0: rune-width-core 110/110, width-data-tables 60/60, string-width 55/55, wrap-and-fill 42/42, truncation-family 36/36, classification-predicates 34/34, locale-env-posix 22/22, combined-lut 16/16. Their rows are re-recorded at this iteration's checkpoint below.
- The wrap-and-fill battery carries the new property, because neither of its existing checks could have caught this: byte preservation strips every newline from both sides before comparing, and the budget invariant only catches a line that is too long, while this defect made one too short. It now drives all 54 lead bytes after a newline and pins the tail-width reset. check-claims.sh: 10 checked, 0 mismatched, 0 errored, 0 skipped.
- Verify gate through the installed quiet-verify.sh: green (3s), summary line `ok github.com/mattn/go-runewidth 2.895s`.
- The ledger is back at the severity floor: zero High and zero Medium open, twelve Low. The closing audit of iteration 8 stands, and the only commits since it are this gate-filed fix and loop state edits.

Learnings: [recurred] a test that reads the package-level default inherits whatever an earlier test left; use an explicit Condition. Recorded after TestREADMEExamples hit it at iteration 5 and not applied here, which cost a red gate.

Next: the second and final evaluator invocation, and the declaration if it returns PASS.

## iter 11/12 | e3847ccb-222829 | 2026-09-01 | EVALUATOR | blocked

Task: the adversarial evaluator gate, invocation 2 and the last this run may spend, after bringing every standing claim current.

Changed: PLAN.md (a Lessons line reworded to stop citing a closed finding ID), BACKLOG.md (RW-20 filed in Now), .jeffy/evaluator/e3847ccb-222829-2.md (the gate's artifact), JOURNAL.md.

Checkpoint: bf8d8a19509ab83931647fdd7393aa88b96b05a8

Verification:
- Standing claims brought current before the invocation. All ten swept rows checked mechanically against their batteries' declared paths since the commit each records: none stale. Declined and Settled classes are both empty. check-claims.sh: 10 checked, 0 mismatched, 0 errored, 0 skipped. The Environment fingerprint was re-derived by command - linux amd64 go1.26.2, the same three files excluded from this platform's build, no skip markers anywhere - and the Oracle class re-read. Verify count stays empty because the summary line's first integer is the suite's duration.
- One currency defect fixed before invoking: PLAN.md's Lessons section cited RW-17, closed and deleted from the ledger at iteration 10. Reworded to describe the defect instead. The same class of slip was caught before invocation 1 and would have cost this invocation too.
- Evaluator: REJECT. Second REJECT with no invocation remaining, so it is terminal and the run cannot declare.
- The reason, reproduced here rather than taken on the gate's word: wrapClusters writes any break-bearing cluster with WriteString unconditionally and never measures the bytes ahead of the break. "caf\xe9\n" segments as "c", "a", "f\xe9\n" - the cluster carries content before the break - so Wrap("caf\xe9\n", 3) returns the input unwrapped, four columns on a line budgeted at three. Enumerating Wrap("caf"+b+"\n", 3) over bytes 0x80 to 0xFF gives 24 over-budget lines here; the gate measured none at the pre-RW-17 tree and none at the run's base commit, and 4340 over-budget multi-cluster lines across 1.8 million randomised samples at HEAD against zero at base.
- This is the second time in one function that I reasoned about what a newline-bearing cluster can contain instead of handling it generally. RW-17's comment claimed the segmenter glues a break only to a following truncated sequence; the gate enumerated 18316 distinct newline-bearing clusters over the 2- and 3-byte neighbourhoods of a newline, of which 10080 carry bytes before the break. Two instances, one root cause, so RW-20 is filed as a structural task - split each cluster at its breaks and measure every piece the same way - rather than a third special case.
- The instrument gap is recorded with the finding, because it is the more useful half: the wrap-and-fill battery already holds exactly the right invariant, that no wrapped line exceeds its budget, but its corpus carries no invalid UTF-8, so the invariant never met the case. TestWrapNewlineClusterResetsColumn drives only lead bytes after the newline, TestWrapPreservesBytes strips every newline from both sides before comparing, and the ASCII differential is ASCII only. Three checks around the defect, none of them able to see it.
- Everything else the gate checked held: the Verify command exits 0, all ten batteries are green, check-claims is clean, every closed reproduction fails on the base commit and passes at HEAD, RW-11's acceptance was re-derived independently, wrapASCII and wrapClusters agree over every ASCII string of length 0 to 4 at every width from -2 to 6, Wrap loses and duplicates no bytes, no finding ID dangles, no row is stale, and all twelve open findings are accurately scored Low.
- Invocation accounting: 2 of 2 used, the cap absolute. The run enters gate salvage - it works only what the gate filed, never re-invokes, never declares, never audits and never replenishes - and ends blocked when no gate-filed finding is left open or the budget runs out.
- Verify gate through the installed quiet-verify.sh: green (3s).

Learnings: [recurred] a comment asserting what a grapheme cluster can contain is a claim over a set, and both times I wrote one in this function it was false; the fix is to stop asserting and handle the general shape.

Next: RW-20, the gate-filed structural fix, in the last iteration of the window.

## iter 12/12 | e3847ccb-222829 | 2026-09-01 | RW-20 | done

Task: RW-20 (Medium, runtime, correctness), the finding the evaluator gate filed at invocation 2 - Wrap emitted a line wider than its budget when a grapheme cluster carried content before a line break. Worked under gate salvage: the run may work what the gate filed and nothing else, and it may not re-invoke, declare, audit or replenish.

Changed: runewidth.go (wrapClusters splits each cluster at its line breaks and measures every piece the same way; a new writePiece helper; zero-width pieces no longer cause a break, in both wrap paths), runewidth_test.go (TestWrapBudgetOverInvalidUTF8), .jeffy/probes/wrap-and-fill (the budget and byte-preservation invariants now run over invalid UTF-8, claim 42 to 46 checks, README updated), BACKLOG.md (RW-20 deleted from Now), JOURNAL.md.

Checkpoint: df5c5ca4c314a91a2011d3d6b9342e8cb2c146a9

Verification:
- Filed reproduction run first against the unfixed code: `go test -run TestWrapBudgetOverInvalidUTF8 -count=1 .` exits 1, naming Wrap("caf\xe0\n", 2) as a four-column line over a budget of two. After the fix the same command exits 0.
- Acceptance as filed, both halves: the enumeration of Wrap("caf"+b+"\n", 3) over bytes 0x80 to 0xFF now returns no over-budget line, where it returned 24 before, and the wrap-and-fill battery's budget invariant runs over a corpus of invalid UTF-8 that it previously lacked.
- Structural rather than another special case, which is what the class rule requires of a second instance sharing one root cause. wrapClusters no longer asks where the break sits: it splits the cluster on every newline and passes each piece through the same width-and-break logic, so content before a break, between two breaks, and after the last are all measured identically. Two earlier attempts here special-cased a shape - first that a break stands alone, then that it glues only to what follows - and each missed a real one.
- The known answers the gate reproduced now hold: Wrap("caf\xe9\n", 3) is "ca\nf\xe9\n" and Wrap("r\xe9sum\xe9\n", 4) is "r\xe9su\nm\xe9\n", both matching what the pre-RW-17 tree produced.
- The RW-17 cases still hold under the new shape: Wrap("abcde\n\xed", 5) returns the input unchanged and Wrap("abcde\n\xedxyz", 3) returns "abc\nde\n\xedxy\nz", so the earlier fix's behaviour survives its replacement.
- The ASCII differential caught a second divergence during this work, which is what it exists for: splitting a cluster made the CR of a CRLF a piece of its own, and the budget check then fired on it at a non-positive width where the byte loop consumed CRLF whole. Rather than special-case CRLF again, both paths now share one rule - a piece occupying no columns never causes a break - which is defensible on its own terms and made the paths agree. An exhaustive differential over every string built from NUL, tab, LF, CR, a C0 control, space, a letter and DEL up to length four, at every width from -2 to 5, reports zero disagreements.
- Contract preserved: every other wrap test passes unchanged, including TestWrap's pin at a budget of 30, the RW-01 non-positive-budget boundary, the cluster-boundary and byte-preservation tests, and TestWrapNewlineClusterResetsColumn.
- Battery ownership: the diff touched runewidth.go and runewidth_test.go. All eight batteries declaring runewidth.go re-run through the installed run-probe.sh and all exit 0: rune-width-core 110/110, width-data-tables 60/60, string-width 55/55, wrap-and-fill 46/46, truncation-family 36/36, classification-predicates 34/34, locale-env-posix 22/22, combined-lut 16/16. Their rows are re-recorded at this iteration's checkpoint below. check-claims.sh: 10 checked, 0 mismatched, 0 errored, 0 skipped.
- Verify gate through the installed quiet-verify.sh: green (3s), summary line `ok github.com/mattn/go-runewidth 2.911s`.
- The run ends blocked, not converged: the gate's second REJECT was terminal, both invocations are spent, and gate salvage ends as soon as no gate-filed finding is left open. RW-20 was the last one. The ledger is back at the severity floor - zero High, zero Medium, twelve Low - and convergence waits for a fresh gate in the next run.

Learnings: an instrument holding the right invariant over the wrong corpus reads exactly like an instrument that passed; the wrap-and-fill battery asserted no line exceeds its budget while never being shown an input that could break it.

Next: a fresh run. Its first audit re-scores everything, and its gate is the one that can accept this work.

## iter 1/10 | 2c3c44b5-234408 | 2026-09-01 | RW-14 | done

Task: RW-14 (Low, docs, documentation), the package-level EastAsianWidth variable being a naming trap - assigning to it changes nothing the package-level functions return, and the doc comment said only that it "will be set true if the current locale is CJK".

Changed: runewidth.go (the EastAsianWidth and StrictEmojiNeutral doc comments), runewidth_test.go (TestPackageFlagVarsAreInputsToNewConditionOnly), BACKLOG.md (RW-14 deleted from Later, the flag-variable class settled, RW-21 filed in Now), PLAN.md (one Lessons line, and the eight runewidth.go rows re-recorded at this checkpoint), JOURNAL.md.

Checkpoint: e13d0637449d1759fceb2cff3301db0c57480fe9

Verification:
- Filed reproduction run first, from a consumer module in a scratch directory with a replace directive rather than from inside the package, because the finding is about what a user of the shipped library meets: writing runewidth.EastAsianWidth = true leaves RuneWidth of U+00B1 at 1 and DefaultCondition.EastAsianWidth at false, while NewCondition built after the write reports the field true and measures the same rune at 2. Exactly as filed.
- Filed as one variable, fixed as the class it belongs to, per the class rule. The idiom is a package-level flag variable that NewCondition copies but the package-level functions never consult. Enumerated by `sed -n '/^func NewCondition/,/^}/p' runewidth.go | grep -oE '^\t\t[A-Za-z]+:' | tr -d '\t:'`, which returns EastAsianWidth, StrictEmojiNeutral and ZeroWidthJoiner. The first two now state in their doc comments that they are readable output and inputs to NewCondition only, and name DefaultCondition as the way to change the package-level functions. ZeroWidthJoiner needed no change: its Deprecated note already states the stronger fact that the flag has no effect anywhere, which holds because no width path reads it.
- Acceptance as filed, both halves. The doc comment half: `go doc . EastAsianWidth` now states which of readable output and writable input the variable is, for both live variables. The test half: TestPackageFlagVarsAreInputsToNewConditionOnly flips all three variables, asserts RuneWidth, StringWidth and DefaultCondition are unmoved, and asserts NewCondition both copies the new values and measures by them.
- The acceptance check was run against deliberately mutated code to confirm it can fail, because a check the broken implementation also satisfies proves nothing. Mutation A, making the package-level RuneWidth copy the variable into DefaultCondition: three assertions red. Mutation B, making NewCondition read DefaultCondition instead of the variables: the NewCondition assertion red. Both files restored from a copy taken aside, never by git checkout, since the tree carried the uncommitted fix.
- The test states its assertions as before and after rather than as fixed widths, so it is order-independent by construction and says the same thing whatever East Asian mode TestDefaultLUT leaves behind (RW-15). Green alone and green in the full suite.
- Filed while executing this task, and it is the more serious thing this iteration found: RW-21, a High. Verifying my own new doc sentence - "call CreateLUT again if a lookup table has already been built" - showed the sentence was false. The package-level CreateLUT returns early when DefaultCondition.combinedLut is non-empty, so it never rebuilds after a flag change, and every package-level width stays silently wrong in both directions. DefaultCondition.CreateLUT does rebuild correctly, so the doc now names that. Reproduced from the consumer module: LUT built at EastAsianWidth false, then flag true plus package CreateLUT gives RuneWidth of U+00B1 as 1 where it must be 2, and the reverse gives 2 where it must be 1; the method answers both correctly. handleEnv escapes the early return only because it truncates combinedLut to length zero before calling.
- Scored High rather than Medium deliberately. The consequence is wrong widths returned silently from two documented features used together, which is the rubric's High line; the surface is Condition fields and package globals, classified user-error, and that class caps findings about malformed values, not findings about a well-formed value the code then ignores. Nothing about this is a malformed input.
- The instrument gap is recorded with the finding. The combined-lut battery does drive the flag-change rebuild, but only through c.CreateLUT, the method; for the package-level function it drives only the no-op and idempotence paths, so the one call sequence that breaks was never made. That is why sixteen green checks sat over it.
- Battery ownership: the diff touched runewidth.go and runewidth_test.go. All eight batteries declaring runewidth.go re-run through the installed run-probe.sh and all exit 0: rune-width-core 110/110, width-data-tables 60/60, string-width 55/55, wrap-and-fill 46/46, truncation-family 36/36, classification-predicates 34/34, locale-env-posix 22/22, combined-lut 16/16. Their rows are re-recorded at this iteration's checkpoint below. check-claims.sh: 10 checked, 0 mismatched, 0 errored, 0 skipped.
- Verify gate through the installed quiet-verify.sh: green (4s), summary line `ok github.com/mattn/go-runewidth 2.975s`.
- Ledger after this iteration: one open High (RW-21) and eleven open Low. The previous run's closing audit does not carry into this run; this run still owes a full fresh-evidence audit before any declaration.

Learnings: a doc comment that tells the caller how to do something is a claim over a sequence, and the sequence gets run before the sentence ships; writing "call CreateLUT again" and then executing it is the whole reason RW-21 was found rather than shipped as advice.

Next: RW-21, the High this iteration filed, which now tops the queue.

## iter 2/10 | 2c3c44b5-234408 | 2026-09-01 | RW-21 | done

Task: RW-21 (High, runtime, correctness), the finding iteration 1 filed while verifying its own doc sentence - the package-level CreateLUT returned early whenever a table already existed, so it never rebuilt after a flag change and every package-level width stayed silently stale.

Changed: runewidth.go (the early return removed, handleEnv's truncation workaround removed with it, the CreateLUT doc comment now states the rebuild contract), runewidth_test.go (TestPackageCreateLUTRebuildsAfterFlagChange), .jeffy/probes/combined-lut (the package-level flag-change path added, claim 16 to 20 checks, README corrected and given the new discriminating evidence), BACKLOG.md (RW-21 deleted from Now), PLAN.md (one Lessons line, and the eight runewidth.go rows re-recorded at this checkpoint), JOURNAL.md.

Checkpoint: b42ca195b13ec7870cd3d03fa8e9dfdf31c81c44

Verification:
- Filed reproduction run first against the unfixed code, as the acceptance requires: TestPackageCreateLUTRebuildsAfterFlagChange exits 1 with 138370 runes disagreeing with a freshly built Condition in each direction, and StringWidth off by one cell each way. After the fix the same command exits 0 under the race detector.
- Acceptance as filed, both halves and both directions. The oracle is a fresh Condition carrying the flags now in force, compared over the whole rune space rather than at sample points, so the check cannot be satisfied by a rebuild that produces some other table. The consumer-module reproduction from iteration 1 was re-run against the fix as well, since that is the form a user of the shipped library meets: all four cases now answer correctly, where two were wrong before.
- The fix is a deletion, which is what the codebase's own convention pointed at: every other package-level function here is a thin delegation to DefaultCondition, and CreateLUT was the one carrying extra logic. Removing the guard makes it `DefaultCondition.CreateLUT()` and nothing else. handleEnv's `combinedLut = combinedLut[:0]` went with it - that line existed only to defeat the guard, and leaving it would have left the workaround for a hazard that no longer exists.
- Contract preserved. Callers of the package-level CreateLUT are handleEnv, TestDefaultLUT, and the combined-lut battery; none relies on the early return for anything but cost. Repeated calls remain a no-op in result, which is what both the docs and the battery's idempotence check promise; what changes is that a second call now costs a rebuild instead of nothing, and nothing documented ever promised it was free. TestDefaultLUT's whole-plane checksums are unmoved, and they were only ever green because handleEnv's truncation smuggled the rebuild past the guard - which is exactly why the strongest assertion in the suite could not see this.
- The public behaviour of CreateLUT changed, so its documentation changed in the same iteration: it now states that a flag change on DefaultCondition needs another call, matching what Condition.CreateLUT already told its own callers. The affected inventory row is re-recorded at this checkpoint rather than flipped back to unswept, because the battery that certifies it was updated and re-run in this same iteration; a row flipped to unswept here would read as unexamined surface when it was in fact just swept with a strengthened instrument.
- The instrument that missed this was updated, not just noted. The combined-lut battery drove the flag-change rebuild only through c.CreateLUT, the method; the package-level function got only the no-op and idempotence paths. The first version of the new check reddened in one direction and passed in the other by luck, which was itself worth finding: from outside the package there is no way to clear DefaultCondition's table, so whichever stale table the battery inherits satisfies one direction for free. Each direction now asserts the widths after the build and again after the flip. Against the pre-fix source the battery reports two red checks, both asking for the table at ea=true, each naming the same six-figure count of runes still answering from the stale table; against the fix, 20 of 20.
- Battery ownership: the diff touched runewidth.go, runewidth_test.go and the combined-lut battery. All eight batteries declaring runewidth.go re-run through the installed run-probe.sh and all exit 0: rune-width-core 110/110, width-data-tables 60/60, string-width 55/55, wrap-and-fill 46/46, truncation-family 36/36, classification-predicates 34/34, locale-env-posix 22/22, combined-lut 20/20. Their rows are re-recorded at this iteration's checkpoint below. check-claims.sh: 10 checked, 0 mismatched, 0 errored, 0 skipped.
- Verify gate through the installed quiet-verify.sh: green (4s), summary line `ok github.com/mattn/go-runewidth 3.373s`, re-run after the doc edit that followed the code change.
- Ledger after this iteration: zero open High, zero open Medium, eleven open Low. This run still owes a full fresh-evidence audit before any declaration; the previous run's clean audit does not carry.

Learnings: a battery driving a package-level entry point cannot reset the package's own hidden state, so it must assert after every transition rather than only at the end - one direction will otherwise pass by luck and read exactly like a check that works.

Next: the top open Low, RW-16, unless a full audit is reached first.

## iter 3/10 | 2c3c44b5-234408 | 2026-09-01 | RW-16 | done

Task: RW-16 (Low, docs, documentation), Truncate returning a string wider than the budget it was given whenever the tail alone does not fit, with the doc comment silent about it.

Changed: runewidth.go (the Truncate and TruncatePrefix doc comments, on both the method and package-level forms), runewidth_test.go (TestTruncateAffixWiderThanBudget), .jeffy/probes/truncation-family (the budget invariant driven across tails, claim 36 to 38 checks, README updated), BACKLOG.md (RW-16 deleted from Later), PLAN.md (one Lessons line, and the eight runewidth.go rows re-recorded at this checkpoint), JOURNAL.md.

Checkpoint: 84685cca0182ba26005630b7d318745b02093792

Verification:
- Filed reproduction run first, from the consumer module: Truncate("abcdef", 0, "...") returns "...", three cells for a budget of zero, exactly as filed. Sweeping five inputs against six tails at every width from 0 to 12 produced 41 over-budget cases on my corpus where the ledger line recorded 36 on its own; the corpora differ and the ledger did not name its strings, so the figure is not comparable and the shape is what reproduces. Every one of the 41 is explained by the tail not fitting - zero cases where an over-budget result had a tail that fit - which is what let the doc sentence be stated exactly rather than hedged.
- Filed as one function, documented as the class it belongs to. The class is the truncators whose w is a budget: Truncate and TruncatePrefix. TruncateLeft was checked and deliberately excluded - its doc says it cuts w cells from the beginning, so w is a count of cells to remove rather than a budget the result must fit, and the 128 results of mine that exceeded w there are the function working as documented. That distinction was worth an hour it did not cost: measuring TruncateLeft against a budget it never promised would have filed a defect that does not exist.
- The enumeration refuted my own first sentence before it shipped, which is the point of writing it. I wrote that a tail wider than w always yields the tail; the test reported Truncate("a", 2, "あい") = "a". Truncate returns s untouched when s already fits and never consults the tail at all. TruncatePrefix does not behave that way: its prefix test precedes its already-fits test, so it returns the prefix even when s would have fit. Both doc comments now state their own rule and the asymmetry is named on TruncatePrefix, where a caller reading only one of the two would be misled.
- Acceptance as filed, both halves. The doc comments state what happens when the affix does not fit in w, and TestTruncateAffixWiderThanBudget asserts that stated behaviour at w below the affix width - not only at the two examples the comments name, but as the enumeration behind the sentence, over a five-string corpus against six affixes at every width from 0 to 12, with a guard that fails the test if the corpus produces no qualifying case at all.
- The acceptance check was run against two deliberate mutations to confirm it can fail. Deleting Truncate's already-fits early return reddens the asymmetry assertion; moving TruncatePrefix's prefix test after its already-fits test reddens the enumeration. Both restored from a copy taken aside.
- The instrument that could not have caught this was fixed, not just noted. The truncation-family battery asserts "Truncate never exceeds its budget", and that check runs the tail at exactly one value, the empty string, which always fits - so the invariant is true only over a corpus that cannot reach the case. A second loop now drives the same corpus across five tails and asserts the documented three-way split. Against a Truncate with its already-fits return deleted the new check reddens with a three-figure count while all four single-tail invariants stay green, which is precisely the reason it exists.
- Battery ownership: the diff touched runewidth.go, runewidth_test.go and the truncation-family battery. All eight batteries declaring runewidth.go re-run through the installed run-probe.sh and all exit 0: rune-width-core 110/110, width-data-tables 60/60, string-width 55/55, wrap-and-fill 46/46, truncation-family 38/38, classification-predicates 34/34, locale-env-posix 22/22, combined-lut 20/20. Their rows are re-recorded at this iteration's checkpoint below. check-claims.sh: 10 checked, 0 mismatched, 0 errored, 0 skipped.
- Verify gate through the installed quiet-verify.sh: green (4s), summary line `ok github.com/mattn/go-runewidth 3.378s`.
- Ledger after this iteration: zero open High, zero open Medium, ten open Low.

Learnings: an invariant named for a parameter it drives at one value is a corpus claim wearing an invariant's name; the truncation battery's budget check ran the tail only as the empty string, which always fits, so it could never meet the case the function actually gets wrong.

Next: the top open Low, RW-18.

## iter 4/10 | 2c3c44b5-234408 | 2026-09-01 | RW-13 | done

Task: RW-13 (Low, docs, documentation), IsNeutralWidth answering false for an unlisted codepoint such as U+0590 while its doc comment, "IsNeutralWidth returns whether is neutral width or not", did not say which of the two available meanings it has.

Changed: runewidth.go (the IsNeutralWidth doc comment), runewidth_test.go (TestIsNeutralWidthAnswersFromListedRangesOnly), .jeffy/probes/classification-predicates (README claim corrected against the primary data), BACKLOG.md (Later reordered by the Method's tie-break, RW-13 deleted), PLAN.md (one Lessons line, and the eight runewidth.go rows re-recorded at this checkpoint), JOURNAL.md.

Checkpoint: eec3e0d55c6c5d7ca3347a629e67d484c776ea3a

Verification:
- The ledger's Later section was reordered before picking a task, because it did not reflect the ordering the Method prescribes. Every remaining item is Low and none is class runtime, so the Method's tie-break applies: user impact, then smallest effort. The section had RW-18, a doc comment sitting above the wrong test function, ahead of findings about public API documentation and about what ships inside the module zip. New order: RW-13, RW-07, RW-10, RW-06, RW-12, RW-19, RW-18, RW-15, RW-09, RW-08. No line's text or severity changed; only the order did.
- The premise was checked against the primary data rather than taken from the ledger line, which is the working rule for this project. EastAsianWidth-17.0.0.txt was fetched and its @missing line reads `0000..10FFFF; N`; U+0590 appears in no range in that file, so its East_Asian_Width is N by default. The generator's switch takes only lines tagged N into the neutral table, which is why the predicate answers false. Both halves confirmed by command rather than by reading the code alone.
- The ledger line and the battery README both said the @missing line makes every unlisted codepoint neutral. The file itself says otherwise: unassigned code points in the three CJK ideograph blocks, and everything undesignated in Planes 2 and 3, default to W. The doc comment I wrote says most rather than every, and the battery README was corrected in the same iteration with the carve-outs named. A claim this predicate's own documentation rests on had to be right.
- Not a class, and that was checked rather than assumed. The three predicates read generated tables, but only for neutral does absence from the table fail to mean absence of the property: ambiguous comes from the A lines and combining from General_Category, and for both an unlisted codepoint genuinely is not that thing. Neutral is the one value that is also the file's default, so it is the one predicate whose table is narrower than its name.
- Acceptance as filed, both halves. The doc comment states which meaning the predicate implements, quoting the @missing line and naming U+0590. The test asserts IsNeutralWidth(0x0590) is false against that stated meaning, and pins the meaning from both sides so it is not a tautology: U+00A9, listed as N, answers true; U+3042, listed as W, answers false. It also asserts RuneWidth reports one cell for U+0590 in both modes, which is why this is a naming question and not a wrong answer.
- The acceptance check was run against a mutation implementing the other reading - IsNeutralWidth returning true for anything in none of the sibling tables - and it reddens on the U+0590 assertion. Restored from a copy taken aside.
- No battery change was needed for the finding itself: classification-predicates already pins U+0590 as a known answer, which is where this was found. The instrument was right and the documentation was silent, which is the reverse of the last three iterations.
- Battery ownership: the diff touched runewidth.go, runewidth_test.go and the classification-predicates README. All eight batteries declaring runewidth.go re-run through the installed run-probe.sh and all exit 0: rune-width-core 110/110, width-data-tables 60/60, string-width 55/55, wrap-and-fill 46/46, truncation-family 38/38, classification-predicates 34/34, locale-env-posix 22/22, combined-lut 20/20. Their rows are re-recorded at this iteration's checkpoint below. check-claims.sh: 10 checked, 0 mismatched, 0 errored, 0 skipped.
- Verify gate through the installed quiet-verify.sh: green (3s), summary line `ok github.com/mattn/go-runewidth 3.496s`.
- Ledger after this iteration: zero open High, zero open Medium, nine open Low.

Learnings: this project has network access, so EastAsianWidth.txt and the other Unicode data files can be fetched and a claim about them checked directly instead of being inherited from a backlog line; two files in this tree had inherited the same overstatement of its @missing rule.

Next: RW-07, then the closing full audit at iteration 6.

## iter 5/10 | 2c3c44b5-234408 | 2026-09-01 | RW-07 | done

Task: RW-07 (Low, docs, documentation), the two CreateLUT doc comments disagreeing on the table size - the method's saying 557056 bytes and the package-level one 557055.

Changed: runewidth.go (the package-level CreateLUT size figure), runewidth_test.go (TestCreateLUTSizeMatchesDocumentedFigure), BACKLOG.md (RW-07 deleted from Later), PLAN.md (one Lessons line, and the eight runewidth.go rows re-recorded at this checkpoint), JOURNAL.md.

Checkpoint: 796a9b0e0cb04a99104796240d13ea16cb363373

Verification:
- The correct figure was measured rather than derived. A throwaway test in the package printed len(combinedLut) after CreateLUT for both a fresh Condition and DefaultCondition: 557056 bytes each. The ledger line reasoned to the same number from 0x110000/2, but the whole finding is that a typed number drifted from the code, so re-deriving it by arithmetic would have repeated the mistake being fixed. The probe file was removed and the tree confirmed clean before any edit.
- The enumeration of the sites stating the size, by `grep -rn '55705[0-9]' --include='*.go' --include='*.md' .`, returns the two doc comments and the ledger line itself, and nothing else - no README or battery text carries the figure.
- Acceptance as filed: `grep -n 557055 runewidth.go` now prints nothing, where it printed the package-level comment before.
- That acceptance is weak on its own and was not left as the whole check. A grep for an absent string is equally satisfied by deleting the sentence, and nothing about it stops the same drift recurring, which is what happened here. TestCreateLUTSizeMatchesDocumentedFigure now pins the documented figure against the real allocation, so a change to either side names the other. Against an allocation of max/2-1 it reddens with both numbers in the message; restored from a copy taken aside.
- Contract preserved: the change is one digit inside a comment, no code path is touched, and the figure the comments now agree on is the one the allocation actually produces.
- Battery ownership: the diff touched runewidth.go and runewidth_test.go. All eight batteries declaring runewidth.go re-run through the installed run-probe.sh and all exit 0: rune-width-core 110/110, width-data-tables 60/60, string-width 55/55, wrap-and-fill 46/46, truncation-family 38/38, classification-predicates 34/34, locale-env-posix 22/22, combined-lut 20/20. Their rows are re-recorded at this iteration's checkpoint below. check-claims.sh: 10 checked, 0 mismatched, 0 errored, 0 skipped.
- Verify gate through the installed quiet-verify.sh: green (4s), summary line `ok github.com/mattn/go-runewidth 3.610s`.
- Ledger after this iteration: zero open High, zero open Medium, eight open Low.

Learnings: a number typed into prose is a claim with nothing holding it to the code, and an acceptance check that only greps for the wrong string does not change that; pin the figure against the thing it describes so the next drift is caught by the suite rather than by an audit.

Next: the closing full audit, at iteration 6, with fresh evidence across every applicable dimension.

## iter 6/10 | 2c3c44b5-234408 | 2026-09-01 | AUDIT | audit

Task: the closing full audit for this run - every applicable dimension rescored with fresh evidence against the severity rubric and the Operating envelope.

Changed: BACKLOG.md (RW-22 filed in Next, RW-23 filed in Later), JOURNAL.md.

Checkpoint: 2c74d3b4f976342e298642197d9d74463edce66a

Verification:
- Surface inventory position first, because scores claim only swept rows. All eleven rows checked mechanically by asking git whether any path in each battery's declared paths file moved since the commit that row records: ten current, none stale, none unswept, and one `- [~]` row - locale detection (windows) - which is unreachable on this Linux host because IsEastAsian there calls kernel32 through syscall.NewLazyDLL. No score below claims that row, and no line here says its runtime behaviour was exercised.
- Fresh evidence per row: all ten batteries executed through check-claims.sh, which runs each claims command and compares its summary line - 10 checked, 0 mismatched, 0 errored, 0 skipped. rune-width-core 110/110, width-data-tables 60/60, string-width 55/55, wrap-and-fill 46/46, truncation-family 38/38, classification-predicates 34/34, locale-env-posix 22/22, combined-lut 20/20, published-module-contents 21/21, locale-detection-constant 4/4.
- Environment fingerprint re-derived by command rather than re-read: go1.26.2 linux/amd64; the module requires github.com/clipperhouse/uax29/v2 v2.2.0 and nothing else; `go list -f '{{.GoFiles}} {{.TestGoFiles}} {{.IgnoredGoFiles}}' .` puts runewidth_appengine.go, runewidth_js.go and runewidth_windows.go in the ignored set, script/generate.go carries `//go:build ignore`, and `grep -rn 't\.Skip\|testing\.Short'` over the tree returns nothing. The fingerprint in PLAN.md holds unchanged. The Oracle class was re-read and still describes what the command grades. Verify count stays empty because the wrapper's green line carries a duration and no test total, which is the case PLAN.md says to leave blank.
- Artifact channels enumerated by command, not by recall: the tree carries no Cargo.toml, package.json, .npmignore, MANIFEST.in, gemspec, nuspec or Dockerfile, and `.github/workflows/test.yaml` runs generate, test, bench and codecov with no publish or archive step. The one real channel is the Go module proxy zip, and the published-module-contents battery builds that zip with golang.org/x/mod/zip and reads it back: nothing under .jeffy/ reaches it. The state files and the three benchmark scratch files do reach it, which is the standing Proposed decision and RW-10 respectively, both already on record.
- Security: the shipped library imports os for Getenv alone - `grep -rn 'unsafe\|os/exec\|net/http\|ioutil\|os\.Open\|os\.ReadFile'` over the non-test, non-script, non-probe sources returns nothing, and the four os. call sites are RUNEWIDTH_EASTASIAN, LC_ALL, LC_CTYPE and LANG. govulncheck reports the code affected by 0 vulnerabilities; the twenty it lists in required modules and the one in an imported package are all standard library entries for the go1.26.2 toolchain this host builds with, and go.mod pins no toolchain, so they are the consumer's build environment rather than anything this module ships. An adversarial sweep drove 112044 calls over every public entry point under all four flag combinations - random byte strings that are mostly invalid UTF-8, plus negative runes, surrogates and values past 0x10FFFF - with zero panics.
- Testing: the suite passes under `-shuffle=on` on two consecutive runs and TestREADMEExamples passes in isolation, so no order dependence beyond the one already filed as RW-15 shows up.
- Performance: the benchmark set runs at zero allocations per operation throughout, both the regular and LUT paths. Iteration 2 removed the package-level CreateLUT early return, which makes a second CreateLUT call cost a rebuild instead of nothing; that cost is now stated in its doc comment and no benchmark covers repeated builds, so nothing here regressed.
- Two documentation findings, both reproduced rather than read. RW-22, Medium: FillRight's doc comment says "filled in left", the same sentence FillLeft carries, at all four sites; `go doc . FillLeft` and `go doc . FillRight` print word-for-word identical descriptions while FillRight("a", 6) is "a     ". A user choosing between the two from the documentation is told both pad on the left. RW-23, Low: IsEastAsian in runewidth_js.go is the only exported declaration in the tree with no doc comment, found by enumerating declarations whose preceding line is not a comment across every non-test .go file.
- Scores, claiming the ten swept rows and never the unreachable one. Correctness: None - all ten batteries green and the suite green under the race detector. Security: None. Architecture: None - one package, one exported type, and the package-level functions are thin delegations again now that CreateLUT's extra logic is gone. Code quality: None - gofmt and go vet clean across the tree. Error handling: not applicable, the public API returns no errors and has no failure path to swallow. Performance: None. Observability: not applicable, a width library emits no logs, metrics or traces. UX and accessibility: not applicable, there is no user-facing surface; the library measures text and renders nothing. Documentation: Medium, RW-22. Dependency hygiene: Low - RW-12, uax29 pinned at v2.2.0 against v2.7.0 published, with govulncheck clean on the current pin. Testing: Low - RW-15, RW-09, RW-18. Developer experience: Low - RW-06, RW-10, RW-19, RW-08.
- Closeout has not begun, because this audit did not come back clean: it scored one Medium. Under the Definition of done the run executes what the closing audit filed and may then declare, provided the only commits after this audit are those fixes. RW-22 is the one that blocks, and it takes the next iteration; RW-23 is a Low and is carried.
- Verify gate through the installed quiet-verify.sh: green (4s), summary line `ok github.com/mattn/go-runewidth 3.589s`. The figures first written on this line were the previous iteration's, copied from the entry above before the gate had run; they are corrected here to what the wrapper actually returned this iteration.
- Stall check: this iteration changed only BACKLOG.md and JOURNAL.md, but two ledger items changed state, so it is not a stall - and an AUDIT entry is a ceremony entry in any case. No Surface inventory row is re-recorded: the diff touches no path any battery's paths file declares, so every row still certifies the code at the commit it names.

Learnings: two sibling functions whose doc comments are byte-identical are worth diffing as a matter of course - the copy that was never edited is the one that names the wrong side, and neither reading the code nor running it can catch a sentence that describes the other function.

Next: RW-22, the Medium this audit filed, then the evaluator gate.

## iter 7/10 | 2c3c44b5-234408 | 2026-09-01 | RW-22 | done

Task: RW-22 (Medium, docs, documentation), the Medium the closing audit filed - FillRight's doc comment saying "filled in left", word for word what FillLeft says, so the documentation described one of the two functions wrongly and gave a caller no way to tell them apart.

Changed: runewidth.go (all four Fill doc comments), runewidth_test.go (TestFillSidesMatchTheirDocComments), BACKLOG.md (RW-22 deleted from Next), PLAN.md (one Lessons line, and the eight runewidth.go rows re-recorded at this checkpoint), JOURNAL.md.

Checkpoint: f6dec750f1a0b2cd292287f0ce3dd86c9b42bde6

Verification:
- Both halves of the filed acceptance were run against the unfixed comments first and both failed there: `diff` of the last line of `go doc . FillLeft` and `go doc . FillRight` reported no difference, and `go doc . FillRight` contained no mention of the right side. After the fix the two descriptions differ and FillRight's names the side it pads.
- The enumeration of sites is the one the ledger line recorded, `grep -n 'FillLeft return\|FillRight return' runewidth.go`, which returns four: the two Condition methods and the two package-level functions. All four were corrected, so the method and package forms of each function say the same thing as each other and different things from their sibling.
- A first version of the fix was rejected during this iteration, and the reason is the whole point of the finding. The doc comments illustrated the behaviour with the literal strings "     a" and "a     ", and `go doc` collapses runs of spaces when it re-wraps a paragraph, so the rendered output read `FillRight("a", 6) is "a "`. A fix whose rendered form still misleads is not a fix for a finding about what the rendered documentation tells a user. The examples now read "a" followed by five spaces, which survives the wrapping, and both were re-read as `go doc` prints them before the comment was accepted.
- The comments now also state the no-op case the audit measured but the ledger line did not name: a string already occupying w cells or more is returned unchanged and never truncated, so the result can be wider than w. That was verified across the corpus rather than asserted - the fills lost cells in zero of the cases swept in the audit.
- Acceptance's third clause, a test pinning the corrected sentences: TestFillSidesMatchTheirDocComments drives the two stated examples, the no-op case for both functions, cell-counted padding around a wide rune, and then the enumeration behind the sentence - six inputs including invalid UTF-8 at every width from -3 to 10, each asserting FillLeft is exactly padding followed by s and FillRight exactly s followed by padding.
- The acceptance check was run against a mutation that makes FillLeft pad on the right, and it reddens on the example and on the wide-rune case. Restored from a copy taken aside.
- Contract preserved: no code changed. The implementations were read before the comments were written, and the sentences describe what they do - FillLeft prepends strings.Repeat(" ", w-width) when that count is positive and returns s otherwise, FillRight appends it.
- No battery change was needed. The wrap-and-fill battery already carries known answers with distinct left and right expectations and the invariant "fills add only spaces, and only on the requested side", so the instrument distinguished the two sides all along; it was the documentation that did not. That is the second finding this run where the battery was right and the prose was wrong, after RW-13.
- Battery ownership: the diff touched runewidth.go and runewidth_test.go. All eight batteries declaring runewidth.go re-run through the installed run-probe.sh and all exit 0: rune-width-core 110/110, width-data-tables 60/60, string-width 55/55, wrap-and-fill 46/46, truncation-family 38/38, classification-predicates 34/34, locale-env-posix 22/22, combined-lut 20/20. Their rows are re-recorded at this iteration's checkpoint below. check-claims.sh: 10 checked, 0 mismatched, 0 errored, 0 skipped.
- Verify gate through the installed quiet-verify.sh: green (3s), summary line `ok github.com/mattn/go-runewidth 3.641s`.
- Ledger after this iteration: zero open High, zero open Medium, nine open Low. The closing audit of iteration 6 filed RW-22 and RW-23; RW-22 is now closed and RW-23 is a carried Low, so the only commits since that audit are this fix and loop state edits.

Learnings: a doc comment is read as `go doc` renders it, not as it sits in the source; go doc collapses runs of spaces when re-wrapping, so an example that depends on repeated whitespace has to be written in words or it lies in exactly the place the reader looks.

Next: the evaluator gate, invocation 1 of this run, and the declaration if it returns PASS.

## iter 8/10 | 2c3c44b5-234408 | 2026-09-01 | EVALUATOR | converged

Task: the adversarial evaluator gate, invocation 1 of this run, after bringing every standing claim current, and the declaration it returned a verdict for.

Changed: BACKLOG.md (RW-24 and RW-25 filed as the gate's Low observations, the Converged line appended), .jeffy/evaluator/2c3c44b5-234408-1.md (the gate's artifact), JOURNAL.md.

Checkpoint: a38684e9078c4e6472e021a3c88d7d32f8d87954

Verification:
- Standing claims brought current before the invocation, never after, because a REJECT spent on a claim the run had already outdated is an invocation the declaration then lacks. All ten swept Surface inventory rows checked mechanically against their batteries' declared paths since the commit each records: none stale, none unswept, and the one `- [~]` row - locale detection (windows) - carries its reason and does not block. Declined holds no entry, so there was no Derivation to re-run. The single Settled class was re-derived by both its recorded commands: the flag-variable enumeration returns EastAsianWidth, StrictEmojiNeutral and ZeroWidthJoiner, and the ZeroWidthJoiner site enumeration returns the doc comment, the package variable, the Condition field and the NewCondition copy, with no read in any width path - exactly what the line states. check-claims.sh: 10 checked, 0 mismatched, 0 errored, 0 skipped. The Oracle class and Environment fingerprint were re-derived by command at iteration 6 and re-read here. Verify count stays empty, and that was checked rather than assumed: the wrapper's green line carries a duration and no test total, which is the case PLAN.md says to leave blank. Every finding ID PLAN.md names - RW-10 and RW-15 - resolves to an open ledger line.
- Evaluator: PASS, invocation 1 of at most 2, with the artifact at .jeffy/evaluator/2c3c44b5-234408-1.md committed by this iteration's checkpoint - 56 numbered commands with their real exit statuses, no machine-absolute path outside the repository.
- The gate reproduced both High and Medium closures against the base commit rather than taking the journal's word. RW-21's reproduction fails at 158d7e0d with the same figure this run recorded, 138370 runes disagreeing in each direction, and passes at HEAD under the race detector; it also re-derived the defect black-box from two consumer modules with a replace directive, confirming the package-level CreateLUT leaves widths stale in both directions at base and correct at HEAD, and re-ran the combined-lut battery against the base tree to get exactly the two red checks its README records. RW-22's base tree prints `filled in left` for FillRight and a description byte-identical to FillLeft's once symbol names are stripped; at HEAD the two differ and FillRight names its side, and the pinning test reddens under a mutation that pads FillLeft on the wrong side. It read both fixes' diffs for regressions and found none: RW-21's is two deletions, Condition.CreateLUT already rebuilds in place, handleEnv's only shipped caller is init where the table is empty, and TestDefaultLUT's whole-plane checksums still pass for both modes.
- It also executed every doc sentence this run shipped rather than reading it - eighteen consumer-module checks, all passing - which is the right test of a run whose findings were mostly documentation.
- The gate's five observations are recorded and deliberately not fixed, because a fix after a PASS invalidates the PASS and spends an invocation the declaration needs. Two became ledger lines for the next run: RW-24, that the package-level CreateLUT is no longer a cheap no-op on a repeat call since RW-21 removed the early return, which breaks no documented promise because both comments already forbid concurrent use and none ever promised a free repeat, and RW-25, that the EastAsianWidth comment says "when that variable is set" where handleEnv branches on non-empty. The other three need no ledger line: RW-10 already discloses the module-zip residue the gate weighed, the stray blank line in BACKLOG.md's empty Next section is cosmetic, and the criticism of one verification command in the iteration 7 entry - a `tail -1` diff of go doc output that is non-discriminating because go doc ends in a blank line - is fair, and stands as written since journal entries are never rewritten; the substantive claim it supported was re-derived true by the gate independently.
- Closing conditions, each checked rather than asserted. The closing full audit ran at iteration 6 of this run with fresh evidence across every applicable dimension; it filed one Medium and one Low, and under the Definition of done the run executes what the closing audit filed and may then declare. RW-22 was closed at iteration 7 and the only commits since that audit are that fix, this gate, and loop state edits. Zero open High and zero open Medium. The Surface inventory lists no unswept row. Verify is green in this declaring iteration. The evaluator returned PASS in this same iteration, which is the iteration that declares.
- Eleven Lows are carried, each with its severity on its own line: RW-06, the workflow's generation-drift guard comparing the index rather than the working tree, so it has never been able to fire. RW-08, script/generate.go importing the deprecated io/ioutil and carrying an argument-less fmt.Fprint. RW-09, TestRuneWidthConcurrent running after the whole rune space has already been walked, so it exercises no concurrent first build. RW-10, benchmark scratch output committed at the repository root and therefore shipped inside the module zip. RW-12, uax29 pinned at v2.2.0 against v2.7.0 published, with govulncheck clean on the current pin. RW-15, TestDefaultLUT leaving the package in East Asian mode for every test after it. RW-18, a test doc comment sitting above the wrong function. RW-19, the published-module-contents battery building its zip from the working tree rather than a committed snapshot. RW-23, IsEastAsian in runewidth_js.go carrying no doc comment. RW-24 and RW-25, the two the gate observed, described above. Every one is class docs, test, build-ci or dev-tooling; none is class runtime, and none names anything a user of the shipped library meets at runtime.
- Verify gate through the installed quiet-verify.sh, in this declaring iteration: green (4s), summary line `ok github.com/mattn/go-runewidth 3.625s`.

Learnings: bringing the standing claims current before the invocation rather than after is what bought this run its PASS on the first gate; the two previous runs each spent an invocation on a claim they had themselves outdated, and this one found none to fix because the row re-recording happened in each fix's own bookkeeping edit.

Next: nothing - the run is converged. The next run ratchets unless code changes.
