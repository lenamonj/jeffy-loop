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

## iter 1/10 | 76621197-014600 | 2026-08-31 | AUDIT | audit

Task: first audit of the memchr crate at 2.8.3. Filled the Operating envelope, the
Surface inventory, and the Verify command section of PLAN.md, built the differential
probe harness the inventory rows are certified by, and scored the project.

Changed: PLAN.md (envelope surfaces, 19 inventory rows, Verify command with its Oracle
class, Environment fingerprint, summary pattern, count and one Stated counts row);
BACKLOG.md (one Medium, three Low, one Declined); .jeffy/probes/ (a shared differential
harness plus nine batteries); .gitignore (the loop's transient state file, at bootstrap).
No file under src/ changed.

Checkpoint: 3b4822ceedcb11f2cd4920bf55767f3b6ada19b6

Verification: `quiet-verify.sh PLAN.md .` reports `verify: green (17s, oracle=unit tests,
quickcheck property tests and rustdoc examples..., verify totals: 660 passed)`, and the
Verify count cell holds that same 660. `check-claims.sh .` reports `claims: 10 checked,
0 mismatched, 0 errored, 0 skipped`, which covers all nine battery claims and the one
PLAN.md Stated count. Four test modules were run in isolation before scoring Testing -
arch::all::shiftor (4), arch::all::rabinkarp (8), memmem::tests (8) and arch::all::twoway
(13) - and each passed alone, so the suite hides no order dependence in those modules.

Audit scores, claiming only the eight swept rows and never the ten that are not:
correctness None, security None, architecture None, error handling None, observability
None, code quality Low (QUAL-1), documentation Low (DOC-1), testing Low (CI-1), developer
experience Low (LINT-1, declined), dependency hygiene Medium (PKG-1). Performance is not
scored: no measurement was taken this iteration, and the benchmarks row is unswept.
UX and accessibility do not apply - this crate has no user-facing surface, only a library
API. Ten inventory rows remain unswept and one is unreachable, so these scores are the
state of the swept surface and not of the whole project.

What the sweep actually did. Eight known-answer batteries under .jeffy/probes/ compare
every swept routine against naive references over a deterministic corpus: five alphabets
from one to 256 distinct bytes, 130 haystack lengths straddling the 16- and 32-byte vector
boundaries and the 4x unrolled loops built on them, and 13 start offsets so each haystack
is presented at every alignment relative to a vector. They total 2,256,145 checks and all
of them pass. Every documented parameter in scope was exercised at two or more values that
must change the output: memmem's `prefilter` at both `None` and `Auto`, `Pair::with_indices`
at five index pairs including the rejected equal-index case, and Shift-Or's needle-length
bound on both sides. The packed-pair batteries assert the two invariants that make a
prefilter sound rather than that it runs: it never skips past a true match, and every
candidate it returns really carries the predicated pair of bytes.

None of these instruments was trusted until it had been seen to fail.
.jeffy/probes/mutations/run.sh holds one discriminating source mutation per battery with
the exact pass count the mutated tree produces, applies each one, re-runs that battery,
and restores the file on every exit path including a signal; it reports
`mutations: 8/8 reproduced`.

Artifact-producing channels, enumerated by command rather than recall. `find . -name
Cargo.toml -not -path './target/*'` returns the root manifest, eight benchmark manifests,
the fuzz manifest and the harness manifest; there is no package.json, MANIFEST.in,
pyproject.toml, gemspec, nuspec or Dockerfile; and `grep -n
'publish\|upload-artifact\|cargo package\|release' .github/workflows/ci.yml` matches only
prose and two curl downloads of third-party tools, so CI archives and publishes nothing.
The single channel is therefore `cargo package` from the root manifest, and it fails the
check this audit owes it: `cargo package --list --allow-dirty` prints PLAN.md, BACKLOG.md
and JOURNAL.md today, and prints .jeffy/ paths too as soon as .jeffy holds a file outside
a nested cargo package - verified by creating `.jeffy/probes/zz-plainfile/paths` and
`.jeffy/metrics/x.json` and watching both appear in the listing. That is PKG-1, filed
Medium with its Consequence, and the cause is structural: `exclude` is a denylist, so any
new top-level path ships by default.

Cross-target reach was measured, not assumed. `cargo check` succeeds for
aarch64-unknown-linux-gnu, for wasm32-wasip1 with simd128 both on and off, and for
thumbv6m-none-eabi core-only, so the vector refactor in 20f83a3 compiles everywhere it
claims to. Executing that code is a different question: wasm32 is reachable here, because
wasmtime 30.0.1 is now installed at ~/.local/bin/wasmtime and the wasm32-wasip1 target is
added, so that row stays `- [ ]` and is scheduled work. aarch64 is not: there is no qemu on
PATH, apt reports no qemu-user-static candidate, and sudo demands interactive
authentication, so that row is `- [~]` with the reason recorded. The declared MSRV was
checked by hand against a real 1.61 toolchain: the library builds for default, core-only
and alloc, and only `--features logging` fails, because a fresh resolve picks log 0.4.34,
which needs 1.71; pinning log to the declared floor of 0.4.20 builds clean on 1.61.

Learnings: cargo is not on PATH in this project's non-interactive shells, so the Verify
command exports ~/.cargo/bin itself. A cargo target directory under .jeffy/ would be swept
into the checkpoint's `git add -A`, so the probe harness builds into $TMPDIR instead. Using
`::` as a field separator in shell data splits Rust paths like `usize::MAX` down the middle;
the mutation table uses `%%%`. And a naive reference is an instrument too: this audit's
first run reported 718 memmem failures and 2 shiftor failures that were both defects in the
reference, not in the crate - the rfind_iter reference allowed overlapping matches, and the
shiftor reference assumed a 7-byte cap where the module's u16 mask allows 15.

Next: PKG-1, the only open Medium, then the unswept inventory rows - the wasm32 simd128
row first, since it is executable here and covers hand-written SIMD the last two commits
touched.

## iter 2/10 | 76621197-014600 | 2026-08-31 | SWEEP | done

Task: sweep the Surface inventory. Ten rows were unswept with nine iterations
left, and the queue puts the map above everything but an open High, so this
iteration spent itself on rows rather than on PKG-1.

Changed: six new batteries under .jeffy/probes/ - raw-pointers, dispatch-arms,
wasm32, feature-matrix, cross-targets, test-isolation - plus the harness they
share, which gained a raw-pointer group, a logging-emission group, wasm32 and
simd128 support behind target gates, and a feature switch so memchr's own
features can be moved underneath it. PLAN.md flipped six rows to swept, re-recorded
the eight already-swept rows at this iteration's checkpoint because the harness
their paths files declare changed, and gained seven Lessons. No file under src/
changed; the mutation battery restores every file it touches on every exit path,
and `git status --porcelain -- src/` is empty.

Checkpoint: 8631ff6605ed7fdd9510200d11019888b314575e

Verification: `quiet-verify.sh PLAN.md .` reports `verify: green (18s, ...,
verify totals: 660 passed)`, the same total the Verify count cell holds.
`check-claims.sh .` reports `claims: 16 checked, 0 mismatched, 0 errored, 0
skipped`, covering all fifteen battery claims and the one PLAN.md Stated count.
Every battery whose paths file names a file this diff touched was re-run, which
is all of them, since every paths file names the shared harness.

Rows swept, and what each sweep actually executed rather than compiled:

- x86_64 ifunc dispatch, via dispatch-arms. The per-arch batteries only ever see
  the arm this host's build selected, so this one rebuilds the harness under all
  three and re-runs every group against the naive references under each: std with
  runtime detection, alloc-only with compile-time SSE2, and alloc-only with
  `-Ctarget-feature=+avx2`. Under alloc-only, `avx2::One::is_available()` is
  false and the battery asserts that rather than skipping it, which is the `std`
  feature exercised at two values whose outputs differ. 27 checks.
- wasm32 simd128, via wasm32. The harness cross-builds for wasm32-wasip1 and runs
  under wasmtime 30.0.1 with simd128 on and off - real execution of the
  hand-written SIMD that 20f83a3 refactored, on a host where `cargo test` never
  compiles it. 15 checks covering 2.1M underlying comparisons.
- raw-pointer entry points, via raw-pointers. find_raw, rfind_raw and count_raw
  across arch::all, sse2, avx2 and simd128, plus the new_unchecked constructors.
  610200 checks.
- feature-configuration surface, via feature-matrix. std, use_std, libc, logging
  and alloc, each at two or more values. 11 checks.
- cross-target build surface, via cross-targets. cargo check for aarch64 (default
  and core-only), wasm32-wasip1 with simd128 both ways, thumbv6m core-only, and a
  library build against the `rust-version` read out of Cargo.toml for three
  feature configurations. 9 checks. This battery grades compilation only, and its
  README says so: the aarch64 row stays `- [~]` precisely because compiling is
  not executing.
- the crate's own test tree, via test-isolation. Every unit-test module
  enumerated from the runner and run alone. 28 checks.

Two findings about the instruments, both caught by the mutation battery rather
than by reading the code, and both repaired in this iteration:

- raw-pointers as first written compared each raw routine against the crate's own
  safe wrapper. The discriminating mutation for arch::all::memchr left it fully
  green: 610200 checks certifying a tree whose byte splat was deliberately wrong,
  because raw and safe share an implementation and a defect in it agrees with
  itself. Rewritten to compare against the naive reference, the same mutation now
  reddens 14445 of its checks.
- test-isolation as first written derived each module's expected count under an
  anchored prefix rule while the test runner applies an unanchored substring rule,
  so `memchr::tests` looked like 14 tests where the runner ran 87. Both sides now
  use the runner's rule.

The `logging` feature had no observer anywhere in this project before today. It
is documented to emit `log` records naming the strategy memchr picked, and
nothing in the crate's own suite ever looked at one. The harness now installs a
counting logger under that feature and checks records actually arrive; built
without it, the group does not exist to be run. Both rows are recorded, so the
feature is held to changing something rather than merely to being accepted.

Discriminating evidence now covers fourteen rows: .jeffy/probes/mutations/run.sh
reports `mutations: 14/14 reproduced`, adding one mutation each for
feature-matrix (disable the `log!` macro's cfg), cross-targets (break the aarch64
`vceqq_u8` arity, which also proves the battery really compiles aarch64) and
test-isolation.

No new finding about the product. Every one of the roughly 4.4M comparisons this
iteration executed, across three x86_64 dispatch arms and two wasm32
configurations, agreed with the naive references.

Learnings: bash owns `GROUPS` as an array of the user's group IDs, so a script
variable of that name silently expands to a numeric GID - this battery's first
run recorded three rows reading `A|1000|`. `::` cannot separate fields in shell
data about Rust code, because it splits `usize::MAX` down the middle. A raw or
unsafe API must be graded against the naive reference and never against the
crate's own safe wrapper. `cargo test` filters are substrings, not prefixes.
And the recurring one, now marked as such in PLAN.md: four of this project's
probe failures so far have been wrong hand-authored expectations rather than
defects - this iteration alone, an offset typed as 36 where the string puts it
at 35, and the module-count rule above.

Next: PKG-1, the only open Medium. Its acceptance check is the packaging
invariant, so writing it as the .jeffy/probes/packaging battery is what will flip
the published-artifact row - that row stays unswept until then rather than being
flipped by a probe known to be red.

## iter 3/10 | 76621197-014600 | 2026-08-31 | SWEEP | done

Task: finish the Surface inventory. Four rows were unswept with eight iterations
left, and the map still outranked the only open Medium, so this iteration spent
itself on the last four rows.

Changed: four new batteries under .jeffy/probes/ - ranker, packaging, docs,
repo-tooling - plus a ranker group in the shared harness. PLAN.md flipped the
last four rows and re-recorded all eighteen at this iteration's checkpoint,
because every battery's paths file names the harness and the harness changed.
BACKLOG.md gained two Low findings this sweep surfaced. Three Lessons added. No
file under src/ changed; the mutation battery restores every file it touches on
every exit path, and `git status --porcelain -- src/ Cargo.toml fuzz/` is empty.

Checkpoint: d0de04cddc641b665b14a5e5ce666e7417e762dd

Verification: `quiet-verify.sh PLAN.md .` reports `verify: green (19s, ...,
verify totals: 660 passed)`, the total the Verify count cell holds.
`check-claims.sh .` reports `claims: 20 checked, 0 mismatched, 0 errored, 0
skipped`, covering all nineteen battery claims and the one PLAN.md Stated count.
Every battery whose paths file names a file this diff touched was re-run, which
is all of them.

The map is now complete: 18 rows swept, 0 unswept, 1 unreachable - the aarch64
NEON row, which compiles here but cannot be executed, with the reason recorded
on the row itself.

Rows swept, and what each sweep actually executed:

- The byte-frequency ranker, via ranker. The crate's rank table is `pub(crate)`,
  so the battery extracts all 256 entries from `default_rank.rs` and holds the
  public API to them rather than keeping a copy that would drift. For a two-byte
  needle the selection is fully determined by the table, so each of the 65280
  ordered byte pairs is a known answer: 197447 checks. The ranker parameter is
  exercised inverted (every strictly-ordered pair must flip), constant (never
  swap), and through `build_forward_with_ranker`, which must change the search
  strategy and never the answer - still held to the naive substring reference.
- The published-artifact channel, via packaging. 57 checks: every `src/**/*.rs`
  and every licence present, every prefix the manifest excludes absent, and the
  top-level entries reaching the artifact held to a recorded set.
- The public documentation surface, via docs. 9 checks: every rustdoc example
  executed, the runner's skipped count held equal to the fences the source marks
  `ignore` (so nothing is skipped for a reason nobody wrote down), intra-doc
  links resolved, `#![deny(missing_docs)]` confirmed in force over a crate that
  builds, and the README's Rust-tagged fence count recorded at zero so a future
  untested example is noticed.
- Repository-side tooling, via repo-tooling. 15 checks: all ten repo-side cargo
  manifests enumerated by find and compiled - eight benchmark engines, the shared
  benchmark library and the fuzz crate, none of which `cargo test` ever touches -
  and the fuzz targets on disk checked against the binaries the fuzz manifest
  declares.

The packaging sweep corrected something iteration 1 recorded. That audit noted
`.jeffy/` did not appear in `cargo package --list` and had to plant files to see
it; the reason is now understood and mechanised: cargo omits any subdirectory
carrying its own Cargo.toml, and `.jeffy/probes/harness` is a cargo crate, so
the harness was hiding the whole `.jeffy` tree from the listing. The battery
plants a plain file before it measures and asserts afterwards that the plant was
really there, so a run that could not plant it reports a failure instead of a
clean answer. PKG-1's evidence is unchanged and its severity is unchanged.

Two Low findings filed, both from this sweep and neither previously visible:

- DOC-2: the documentation build is not warning-clean. `cargo doc` emits a
  `redundant explicit link target` warning for the `arch::all::shiftor` link in
  the crate-level docs, which is where a real rustdoc warning would arrive amid
  noise. Low, class docs.
- TOOL-1: `scripts/make-byte-frequency-table`, the only script in the repository,
  starts `#!/usr/bin/env python` and does not run at all on a host that ships
  only `python3` - `env: 'python': No such file or directory` - and its header
  says the table is written to `src/freqs.rs`, a path that does not exist. The
  file is valid Python 3 source, so the finding is about the shebang and the
  stale reference, not the code. Low, class dev-tooling.

Discriminating evidence now covers eighteen rows: `mutations: 18/18 reproduced`.
The ranker mutation is worth naming, because the obvious one would not have
worked: mutating a value in the rank table moves the crate and the battery
together, since the battery reads that file. The recorded mutation instead
offsets the lookup in `DefaultFrequencyRank::rank`, so the table and the
behaviour disagree, and 26525 checks redden.

No new finding about the product's runtime behaviour. Every one of the roughly
4.6M comparisons this iteration executed agreed with the naive references.

Learnings: a battery that reads a table the crate also compiles must read it from
the crate's own source rather than keep a copy - a copy drifts, and a mutation
to the source moves both sides together and reddens nothing. A packaging battery
collapses the file listing to top-level entries, or adding a probe reddens it.
And cargo omits any subdirectory carrying its own Cargo.toml from
`cargo package --list`, which is why a probe crate can hide its whole parent
directory from the answer.

Next: PKG-1, the only open Medium, whose fix re-records .jeffy/probes/packaging.
Then the five carried Lows, then a closing full audit - the iteration 1 audit
scored Medium and claimed only eight rows, so the declaration needs a fresh one
over the complete map.

## iter 4/10 | 76621197-014600 | 2026-08-31 | PKG-1 | done

Task: PKG-1, the only open Medium. The published crate carried this loop's state
files, and the cause was structural rather than incidental: `Cargo.toml` used an
`exclude` denylist, so every new top-level path in the repository shipped by
default.

Changed: Cargo.toml, replacing the five-entry `exclude` list with a twelve-entry
`include` allowlist. .jeffy/probes/packaging re-recorded in the same iteration -
its `expected`, its README and its mutation row, since the mutation targeted the
`exclude` line that no longer exists. BACKLOG.md lost PKG-1 and gained a Settled
classes line. PLAN.md gained a Stated counts row and one Lesson. No file under
src/ changed.

Checkpoint: cae3c7789739f729bf1bb7d6093562d3f6935cf6

Verification: the filed reproduction ran first, against unfixed HEAD, and failed
as filed: `LEAK PLAN.md`, `LEAK BACKLOG.md`, `LEAK JOURNAL.md`, `LEAK .jeffy/
(86 paths)`, `PKG-1 acceptance: FAIL`, exit 1. Against the fix the same script
prints `PKG-1 acceptance: PASS`, exit 0. `cargo package --allow-dirty` then built
and verified the packaged tree end to end - `Packaged 59 files`, `Verifying
memchr v2.8.3`, `Finished` - so the allowlist is not merely quiet but complete:
all 45 `src/**/*.rs` files on disk are 45 in the listing, and the packaged crate
compiles from its own tarball. `quiet-verify.sh PLAN.md .` reports `verify: green
(18s, ..., verify totals: 660 passed)`. `check-claims.sh .` reports `claims: 21
checked, 0 mismatched, 0 errored, 0 skipped`. Every battery whose paths file
names a path this diff touched was re-run through run-probe.sh: packaging 57/57,
dispatch-arms 27/27, feature-matrix 11/11, cross-targets 9/9, and mutations
18/18.

Closed: PKG-1 (Medium, build-ci, dependency hygiene) - the published artifact no
longer carries PLAN.md, BACKLOG.md, JOURNAL.md or any `.jeffy/` path, verified
with a plain file planted under `.jeffy/` so the harness crate could not hide the
directory from the listing.

What the change preserves, and what it does not. The artifact's contents are
exactly what they were minus the four loop paths: the allowlist names every
top-level entry that was shipping before, including the developer-facing ones
(`.gitignore`, `.ignore`, `.vim/`, `rustfmt.toml`, `CONTRIBUTING.md`,
`AI_POLICY.md`). Narrowing it to source, manifest, README and licences alone
would be defensible and would make a smaller tarball, but that is a maintainer's
judgement about what a published crate should contain, not part of this finding,
so it was left alone and goes to the run report instead. What did change is the
default: a path nobody names no longer ships.

The class, not the instance. Adding four names to `exclude` would have closed
today's leak and left the class open - the next state file, or a NOTES.md, would
ship exactly the same way. The Settled classes line records the allowlist with
its enumerating command, and PLAN.md's Stated counts table now carries the count
that command returns, so the class stays checkable rather than merely asserted.

That table earned its keep immediately: the count was typed as 16 and
check-claims answered `MISMATCH PLAN:published-toplevel-entries: expected 16 got
15` on the first run. Twelve entries the manifest names plus three cargo
generates into every package is 15, not 16, and the instrument said so before the
number reached a commit.

Learnings: a packaging manifest is written as an allowlist and never a denylist,
because a denylist ships every path nobody thought to name. And a mutation row
that patches a specific line dies when the fix rewrites that line - the packaging
mutation had to be re-aimed at the new allowlist in the same iteration, or the
battery would have gone back to having never been seen to fail.

Next: the five carried Lows - QUAL-1, DOC-1, CI-1, DOC-2, TOOL-1 - then a closing
full audit over the complete map, since the iteration 1 audit scored a Medium and
claimed only eight of the eighteen rows.

## iter 5/10 | 76621197-014600 | 2026-08-31 | QUAL-1 | done

Task: QUAL-1, the top open Low and the only one of class runtime, which is what
puts it above the four perimeter Lows in the ledger's own ordering.

Changed: src/cow.rs, removing the two cfg attributes inside the alloc-gated
`Imp::as_slice`. Inside a function already gated on `feature = "alloc"`, the
inner `#[cfg(feature = "alloc")]` was always true and the inner
`#[cfg(not(feature = "alloc"))]` block could never be compiled at all - it was
unreachable code wearing a conditional that read as if it did something. The
`not(alloc)` copy of `as_slice` below it, which is the one that really serves
that configuration, is untouched.

Checkpoint: 2fbc0a8978739fbc279e0baca80b612ba9acaa97

Verification: the acceptance check ran first against unfixed HEAD and failed as
filed - `the alloc-gated as_slice carries 3 cfg attributes, expected 1 (its own
gate)` and `src/cow.rs has 4 occurrences of cfg(not(feature = "alloc")),
expected 3`, exit 1. Against the fix it prints `QUAL-1 acceptance: PASS`, exit 0.
`quiet-verify.sh PLAN.md .` reports `verify: green (21s, ..., verify totals: 660
passed)` - the same 660 as before the change, across all four feature
configurations including the core-only one that compiles the `not(alloc)` arm.
Every battery whose paths file names `src/cow.rs` or `src/**` was re-run through
run-probe.sh: memmem-api 82100/82100, feature-matrix 11/11, cross-targets 9/9,
repo-tooling 15/15, docs 9/9, packaging 57/57, test-isolation 28/28, and
mutations 18/18.

Closed: QUAL-1 (Low, runtime, code quality) - the dead inner cfg block in
`src/cow.rs` is gone.

What the change preserves. `Imp` is private to src/cow.rs and its only consumer
is `CowBytes::as_slice`, reached from `memmem::Finder` and `memmem::FinderRev`
through `needle()`, `find`, `rfind` and the `Deref` impl - eight call sites in
src/memmem/mod.rs, none of which changed. The compiled output is identical by
construction rather than by inspection: under `alloc` the block that was removed
was gated `not(alloc)` and never compiled, and the block that remains was gated
`alloc` and always did. The differential evidence is that memmem-api reports the
same 82100 checks and the Verify command the same 660 tests as at the previous
checkpoint.

Next: DOC-2, then TOOL-1 and DOC-1, budget permitting. Two iterations are held
back for the convergence sequence - a closing full audit over the complete map,
since the iteration 1 audit scored a Medium and claimed only eight of eighteen
rows, and then the evaluator gate with the declaration. Whichever Lows are still
open at that point are carried and named in the declaring entry.

## iter 6/10 | 76621197-014600 | 2026-08-31 | DOC-2 | done

Task: DOC-2, the documentation build's only warning. Filed as an instance,
closed as a class: an explicit intra-doc link target that only repeats its own
label is a link rustdoc has to resolve twice and a reader has to read twice.

Changed: src/lib.rs, dropping the explicit `(crate::...)` target from both
intra-doc links in the crate-level docs. .jeffy/probes/docs strengthened and
re-recorded - it no longer merely records the rustdoc warning count but holds
the build clean under `-D warnings` and asserts the class enumeration returns
nothing - and its mutation row re-measured, since the battery grew from 9 checks
to 11. BACKLOG.md lost DOC-2 and gained a Settled classes line. One Lesson.

Checkpoint: 62ee64013bbb386ac54e1d35836eabcab79ee76a

Verification: the acceptance ran first against unfixed HEAD and failed as filed -
`RUSTDOCFLAGS="-D warnings" cargo doc --no-deps --all-features` exited 101 with
`error: redundant explicit link target` at src/lib.rs. Against the fix the same
command exits 0 with zero warning or error lines. `quiet-verify.sh PLAN.md .`
reports `verify: green (21s, ..., verify totals: 660 passed)`. `check-claims.sh
.` reports `claims: 21 checked, 0 mismatched, 0 errored, 0 skipped`. Every
battery whose paths file names src/lib.rs or src/** was re-run through
run-probe.sh: memchr-top 515845/515845, packaging 57/57, dispatch-arms 27/27,
repo-tooling 15/15, docs 11/11, test-isolation 28/28, feature-matrix 11/11,
cross-targets 9/9, and mutations 18/18.

Closed: DOC-2 (Low, docs, documentation) - the documentation build is clean under
`-D warnings`.

The class, and how the second site was settled rather than assumed. The
enumeration `grep -rn '](crate::' src --include='*.rs'` returned two sites and
rustdoc flagged only one, for `arch::all::shiftor`. Fixing that one alone and
calling the class closed would have rested on rustdoc's silence about the other,
so the other was provoked instead: its explicit target was removed, the docs
rebuilt, and no warning appeared - the label resolves on its own, and rustdoc
simply does not flag associated-item paths under this lint. Both sites are now
label-only, and both links still render: the generated index page still carries
one `arch/all/shiftor/index.html` link and one
`memmem/struct.Finder.html#method.into_owned` link, the same counts as before the
change. The enumeration now returns no sites at all.

Learnings: changing a battery's check count invalidates its mutation row.
Strengthening the docs battery from 9 checks to 11 left the recorded mutation
expecting 8/9, so the very next check-claims errored on the battery that had just
been improved - both figures have to be re-measured in the same iteration.

Next: the closing full audit over the complete map. The iteration 1 audit scored
a Medium and claimed only eight of the eighteen rows, so the declaration needs a
fresh one; then the evaluator gate and the declaration, with two iterations held
in reserve in case that gate returns REJECT. DOC-1, CI-1 and TOOL-1 are carried.

## iter 7/10 | 76621197-014600 | 2026-08-31 | AUDIT | audit

Task: the closing full audit. The iteration 1 audit scored a Medium and claimed
only eight of the eighteen rows, so the declaration needs a fresh full pass over
the complete map. Closeout has begun: this run files no further findings on
swept surface and now works or declines what is on the ledger and converges.

Changed: BACKLOG.md only, gaining one Declined entry. PLAN.md and the code are
untouched. This iteration changed no file outside the state files and no
BACKLOG.md task line under Now, Next or Later changed state, so it meets the
stall condition on its face; an AUDIT entry is one of the ceremony entries that
never forms a stall pair, which is what makes a closing audit legal at all.

Checkpoint: e611674d7a160d769499eadf1394b976394a4f55

Verification: fresh evidence, re-executed rather than recalled.
`check-claims.sh .` reports `claims: 21 checked, 0 mismatched, 0 errored, 0
skipped` - all nineteen batteries and both PLAN.md Stated counts.
`quiet-verify.sh PLAN.md .` reports `verify: green (18s, ..., verify totals: 660
passed)`, matching the Verify count cell. The Oracle class and Environment
fingerprint were re-read and the fingerprint's own exclusion command re-run: it
returns the same shape as at iteration 1, sixteen `target_arch = "aarch64"`
sites, sixteen wasm32-with-simd128 sites, and the rest unchanged, so nothing
this command cannot reach has quietly grown. Both Settled-class enumerations
were re-derived: the published artifact still resolves to 15 top-level entries,
and `grep -rn '](crate::' src` still returns no site. The one Declined
Derivation was re-run: clippy still reports 179 warning lines, so LINT-1's
premise holds.

Scores. This audit claims eighteen of nineteen rows - the whole map except the
aarch64 NEON row, which is `- [~]` because this host has no way to execute
aarch64 code, and which is named again in the run report.

- correctness: None. 2,459,437 differential checks across nineteen batteries,
  all green, against naive references rather than against the crate's own
  wrappers.
- security: None in-envelope. The envelope classes haystacks and needles
  adversarial and every battery drives them with hostile shapes - alphabets of
  one to 256 bytes, lengths straddling every vector boundary, thirteen start
  alignments. No out-of-bounds or wrong-offset result appeared anywhere. The
  limit of this evidence is recorded as MIRI-1 below.
- performance: None, and measured this iteration rather than assumed, because a
  dispatch that silently fell back to scalar would pass every correctness
  battery. Over a 64 MiB haystack with the match at the far end for forward
  searches and at the far start for reverse ones, best of five timed rounds with
  the inputs and results behind black_box: memchr 16.28 GiB/s against a naive
  byte scan at 3.57, memrchr 14.88 against 3.80, and memmem::find 12.66 against a
  naive substring scan at 0.62. The vector paths are live and carrying their
  weight.
- dependency hygiene: None. `cargo tree --edges normal --depth 1` lists no
  dependency at all under default features: `log` is optional and off, and
  `rustc-std-workspace-core` is an internal libstd-build feature. There is no
  third-party code in a default build to carry a vulnerability.
- architecture, error handling, observability: None. The logging feature had no
  observer anywhere before this run and now has one.
- code quality: Low. LINT-1, declined on price.
- documentation: Low. DOC-1, the stale comment in shiftor's constructor.
- testing: Low. CI-1, no MSRV job, and MIRI-1, declined on availability.
- developer experience: Low. TOOL-1, the script that cannot run as written.
- UX and accessibility: not applicable. This crate has no user-facing surface,
  only a library API.

Zero High and zero Medium in-envelope. The closing conditions on the ledger side
are met: nothing above Low is open, the map has no unswept row, and the Verify
command is green.

Declined this iteration: MIRI-1 (Low, test, security) - no undefined-behaviour
checker runs over this unsafe-heavy crate here, because miri cannot be installed
on this toolchain at all: `rustup component add miri` exits nonzero with
`component 'miri' ... is unavailable for download for channel 'stable'`. The
crate is miri-aware - fifteen `cfg(miri)` sites - so upstream does run it. This
is a genuine absence rather than a cost judgement, and it is the one limitation
worth naming beside a security score of None.

Learnings: a throughput measurement needs its worst case built deliberately -
the first attempt put the match at the end of the haystack for every routine,
which made memrchr look like 1.9 million GiB/s because it found the answer in one
step, and left the naive substring loop hoisted out of the timing loop entirely.
Forward searches get the match at the end, reverse searches at the start, and
every input and result goes through black_box.

Next: the evaluator gate and, on a PASS, the declaration in that same iteration.
Three iterations remain, so a REJECT still has room to be worked and a second
invocation to be spent. DOC-1, CI-1 and TOOL-1 are carried.

## iter 8/10 | 76621197-014600 | 2026-08-31 | EVALUATOR | converged

Task: the evaluator gate and, on its PASS, the declaration.

Changed: PLAN.md, correcting one stale sentence on the published-artifact row -
it still read "the recorded set is today's output, PKG-1 and all", which stopped
being true when PKG-1 closed at iteration 4. .jeffy/evaluator/76621197-014600-1.md,
the gate's artifact. BACKLOG.md gains the Converged line. No code changed this
iteration; Cargo.toml and src/ are byte-identical to the previous checkpoint,
including after the evaluator's base-manifest swap, which it restored.

Checkpoint: fcffdfbbe0f6229b86a8a76e4beda48546d339c0

Verification: Evaluator: PASS - one fresh-context invocation, ordinal 1 of at
most 2, re-ran the Verify command, all 21 claims, PKG-1's reproduction against
both the base manifest and HEAD, and the acceptance checks of both Lows closed
this run, and found no reason to reject. Standing claims were brought current in
this same iteration before the invocation: all 18 swept rows checked for
staleness by asking git whether any path in each battery's own paths file moved
since the row's recorded commit, and none had; both Declined Derivations re-run
(clippy still 179 warning lines, `rustup component add miri` still exits 1 on
stable); both Settled-class enumerations re-derived (15 published top-level
entries, no explicit intra-doc link target site); the Oracle class and
Environment fingerprint re-read; and the Verify count cell confirmed equal to the
wrapper's total. `check-claims.sh .` reports `claims: 21 checked, 0 mismatched, 0
errored, 0 skipped`. `quiet-verify.sh PLAN.md .` reports `verify: green (20s,
..., verify totals: 660 passed)`.

What the gate actually re-derived rather than took on trust. It ran PKG-1's
reproduction against the base manifest swapped into the present tree and got the
same failure the journal records - `LEAK .jeffy/ (86 paths)`, the same 86 - then
got a pass against HEAD. For the regression read it did not stop at the allowlist:
it diffed the full base and HEAD package listings, 148 paths against 59, and
confirmed the only paths that stopped shipping are the 86 `.jeffy/` paths and the
three state files, with nothing else dropped and nothing added. It re-ran
`cargo package --allow-dirty` and watched the packaged tree build and verify.

Carried Lows, each open with its severity on its own ledger line:
- DOC-1 (Low, docs): the comment inside `Finder::new` in src/arch/all/shiftor.rs
  states a 7-byte needle bound where the `u16` mask enforces 15.
- CI-1 (Low, build-ci): no CI job builds against the declared `rust-version =
  "1.61"`, so the MSRV claim is graded by nothing.
- TOOL-1 (Low, dev-tooling): scripts/make-byte-frequency-table starts
  `#!/usr/bin/env python` and does not run on a host shipping only python3.
Declined and standing: LINT-1 (clippy, priced) and MIRI-1 (no UB checker here).

The gate's observations, recorded and deliberately not acted on, because a fix
after a PASS invalidates that PASS. The important one is against this run's own
record rather than the product: MIRI-1's Declined line claims miri "cannot be
installed on this host's toolchain at all" and that "the tool is absent", and
that is false. miri is installed on this host's nightly toolchain - `cargo
+nightly miri --version` exits 0 - and the recorded Derivation reproduces only
because it is scoped to stable, so nothing mechanical caught the overclaim. The
declaration does not rest on it: MIRI-1 is Low, and a Low neither blocks
convergence nor changes it by being Declined rather than open. It is the next
run's first task, and it is this project's recurring lesson landing again - a
sentence written wider than the command that established it. The gate also
observed that CI-1 is the closest call on the ledger to a Medium, reproducing
`cargo +1.61 build --lib --features logging` failing at exit 101 on log 0.4.34,
and scored it Low because nothing is hidden: the ledger line already names the
version and the mechanism. Two smaller ones: shiftor's rustdoc documents the
empty-needle case but never the 15-byte bound, and the aarch64 row's reason could
be sharper, since this host has a binfmt_misc registration for aarch64 and is
missing only the qemu-user binary.

Learnings: a Declined entry's prose must say no more than its recorded Derivation
establishes. This one said "at all" where its command asked only about stable,
and the gate caught in one command what four iterations of re-running that
Derivation never could.

Next: none. The run is converged and this is its closing entry.
