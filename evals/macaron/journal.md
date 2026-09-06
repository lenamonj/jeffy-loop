# Journal archive

Rotated entries, appended across every rotation and every run. Never overwritten.

## iter 1/10 | e87d31d3-133829 | 2026-09-06 | AUDIT | audit

Task: First audit. Fill the Operating envelope, the Surface inventory, and the Verify command in PLAN.md, enumerate the artifact-producing channels, then audit breadth-first and seed BACKLOG.md.

Changed: PLAN.md (envelope surfaces, 28 inventory rows, Verify command block), BACKLOG.md (6 findings), JOURNAL.md, .gitignore (bootstrap).

Checkpoint: 735d20e863995feb65ea1b512a654ebca7f76922

Verification: Verify command established as `PATH="$PWD/.venv/bin:$PATH" python -m pytest --no-header -q -p no:cacheprovider && go test ./golang/...` and run through the installed quiet-verify.sh: green (107s, 1160 passed). The PATH prefix is load-bearing rather than cosmetic - `.venv/bin/python -m pytest` without it fails 10 tests in tests/malware_analyzer/pypi/test_pypi_sourcecode_analyzer.py and one in test_detect_malicious_metadata_check.py with `FileNotFoundError: 'semgrep'`, because pypi_sourcecode_analyzer.py shells out to a bare `semgrep` that only resolves from the venv's bin directory. Verify count 1160 is the wrapper's own green figure, not a typed one.

Artifact channels enumerated by command, not recall: `ls pyproject.toml MANIFEST.in setup.py package.json` (only pyproject.toml exists), `sed -n '/\[tool.flit.sdist\]/,/^$/p' pyproject.toml`, `cat .dockerignore`, `ls .github/workflows`. Three channels reach a user: the flit wheel, the flit sdist, and the ghcr Docker image. Verified by building both distributions in a throwaway clone at /tmp/jeffy_sdist_probe with the state files committed - the wheel carries only `macaron/` and `macaron-0.25.0.dist-info/`, while the sdist carries `PLAN.md`, `BACKLOG.md`, `JOURNAL.md` and `.jeffy/probes/marker.txt`. Filed as PKG-001 at Medium with its Consequence. The Docker image is clean by inspection of docker/Dockerfile.final: it copies only the simple-index tarball, requirements.txt, Makefile and docker/user.sh, and deletes $HOME/dist after the pip install.

Audit scores. Every one of the 28 Surface inventory rows is still unswept, so these scores claim only the code this audit actually examined and say nothing about the remainder. What was examined: an import sweep of all 213 modules under src/macaron via pkgutil.walk_packages (0 failures), plus deep probes on SLSA analyzer core (git_url tag handling), build spec generator common_spec, provenance handling, core utilities, and the output reporter's Jinja configuration.
- security: High - PROV-001. Reproduced the mechanism rather than asserted it: a tar holding `pkg/escape` as a symlink and `pkg/escape/payload.txt` passes `_validate_path_traversal` on both members (no leading slash, no `..`), and extracting it with `filter="fully_trusted"` writes the payload outside the destination. On this host the escape is blocked, but by tarfile's 3.14 default filter alone, not by any check the module performs - `_extract_archive` returned False and no file escaped when run unmodified.
- correctness: High - BSG-001, reproduced by driving `MavenBuildSpec.resolve_fields` with `find_jdk_version_from_central_maven_repo` patched to return "17": an empty input `language_version` yields `["8"]`, a populated one yields `["17"]`. Also BSG-002 and GIT-001, both reproduced by direct call.
- dependency hygiene: Medium - PKG-001, above.
- error handling: Medium - GIT-001. A valid PEP 440 tag is reported as "No valid version tag found", and osv_dev.py converts that into APIAccessError, so a vulnerability lookup is abandoned rather than answered.
- code quality: Low - GIT-002, a dead defensive branch.
- documentation: Low - the `normalize_jdk_version` docstring carries `>>> normalize_jdk_version("25.0.1")` returning None as a worked example, so the JDK-25 gap reads as intended behaviour. Folded into BSG-002 rather than filed separately; the fix updates the example.
- developer experience: Low - the semgrep-on-PATH requirement above is undocumented outside the Makefile.
- architecture, testing, performance, observability: None on the code examined, which is a claim about that code only. The suite is green at 1160 and carries no skip marker, platform guard or Go build constraint (derived by the command recorded on the Environment fingerprint line); the only exclusions are the addopts ignores of tests/integration (113 case directories) and the sourcecode_samples resources.
- UX and accessibility: not applicable beyond the CLI, and the CLI was not exercised end to end this iteration.

Learnings: The unit suite needs `.venv/bin` on PATH, not just `.venv/bin/python`, or 11 tests fail on a missing semgrep binary. The tests/integration tree (113 cases) is outside the verify gate entirely, so no journal entry may claim it was green.

Next: PROV-001, then BSG-001.

## iter 2/10 | e87d31d3-133829 | 2026-09-06 | PROV-001 | done

Task: PROV-001 (High, runtime, security) - `_extract_archive` in `src/macaron/provenance/provenance_verifier.py` relied on the interpreter's tarfile default for extraction safety, and its own symlink guard was dead code.

Changed: src/macaron/provenance/provenance_verifier.py, tests/provenance/test_provenance_verifier.py (new), PLAN.md (Verify count, Verify duration, one corrected Lesson), BACKLOG.md (PROV-001 deleted).

Checkpoint: 13bce21224422c8e4a59c3af916f0fadff922f5b

Verification: The acceptance check is the new `test_extract_archive_blocks_symlink_escape`, which pins `tarfile.TarFile.extraction_filter` to `fully_trusted_filter` - the tarfile default on every interpreter below 3.14, and so on interpreters `requires-python >=3.11.14` admits - and asserts nothing lands outside the destination. Run against the unfixed file it failed on `assert not (outside / "payload.txt").exists()` with `AssertionError: assert not True`, so the check is strong enough to fail; two sibling tests asserting that ordinary tar and zip archives still extract passed in the same run, so the check cannot be satisfied by a function that simply refuses everything. After the fix all three pass. Verify gate through the installed quiet-verify.sh: green (75s, 1163 passed), up from 1160 by the three new tests, and PLAN.md's Verify count now carries the wrapper's figure. mypy clean on both files; pylint 10.00/10 on both after moving a function-local `import zipfile` to the module top.

The fix passes `filter="data"` to `tar_file.extractall` and reduces `_validate_path_traversal` to the absolute-path and parent-reference check it actually performs. What the contract preserves: `_extract_archive` is module-private with one caller in the same file, its signature and its bool return are unchanged, and the two new tests pin that legitimate archives still extract. The dead branch removed was `if os.path.realpath(path): return True`, which is true for every non-empty path and therefore rejected nothing; `os` is still used elsewhere in the module, so the import stays.

Correction to a figure this run wrote: the iter 1 entry says 11 tests fail without semgrep on PATH, and the PLAN.md Lesson repeated it. The real figure is 10, from `grep -c '^FAILED ' ` over the saved baseline run and its own `10 failed, 1150 passed` summary line. The Lesson in PLAN.md now says 10; PLAN.md's Environment fingerprint said 10 all along and is unchanged. The journal entry stands as written.

Learnings: The project's pylint gate is 10.00/10, so a function-local import in a test file is a real failure rather than a style preference. Do not filter the quiet-verify green line through sed before reading it - the pass count is on that line and mangling it costs a whole second run to recover.

Next: BSG-001, the remaining open High.

## iter 3/10 | e87d31d3-133829 | 2026-09-06 | BSG-001 | done

Task: BSG-001 (High, runtime, correctness) - `MavenBuildSpec.resolve_fields` discarded the JDK version read from the Maven Central JAR whenever the Macaron database recorded no language version, so `gen-build-spec` emitted `language_version: 8` for an artifact built with a different JDK.

Changed: src/macaron/build_spec_generator/common_spec/maven_spec.py, tests/build_spec_generator/common_spec/test_maven_spec.py (new), PLAN.md (Verify count), BACKLOG.md (BSG-001 deleted).

Checkpoint: 212e4b103c90ae6d0decf4b0672f5f97f1b27666

Verification: The fix is one line - `selected_jdk_version = jdk_from_jar or existing if existing else "8"` becomes `jdk_from_jar or existing or "8"`, which is what the comment above it already said the code did. The acceptance check is a new parametrized test pinning the whole selection table rather than the single bad cell: (existing=[], jar=17) -> ["17"], (existing=["11"], jar=17) -> ["17"], (existing=["11"], jar=None) -> ["11"], (existing=[], jar=None) -> ["8"]. Against the unfixed file it failed on exactly the first row with `AssertionError: assert ['8'] == ['17']` while the other three passed, so the check is strong enough to fail and narrow enough to pin the intended behaviour. All four pass after the fix. Verify gate through the installed quiet-verify.sh: green (74s, 1167 passed), up from 1163 by the four parametrized cases; PLAN.md's Verify count now carries that figure.

The empty-list case is the ordinary one rather than a corner: `core.py` sets `"language_version": [lang_version] if lang_version else []`, re-confirmed this iteration by grep, so any build command whose database row carries no language version reaches `resolve_fields` with an empty list.

What the contract preserves: `resolve_fields` keeps its signature, its None return, and its early return on a purl missing namespace or version; the three cases that already behaved correctly are now pinned by tests that did not exist before. No Surface inventory row names this code yet, so none needed re-recording.

Class check rather than instance patching: the precedence idiom was enumerated across the source with `grep -rnE '=\s*[A-Za-z_.]+ or [A-Za-z_.]+ if ' src/macaron --include='*.py'`, which returns this one site and nothing else, so this is a single instance and not a class needing a structural fix.

Learnings: none new this iteration.

Next: the queue now has no open High, so unswept Surface inventory rows outrank the three open Mediums; iteration 4 sweeps rows.

## iter 4/10 | e87d31d3-133829 | 2026-09-06 | SWEEP | done

Task: No open High, so the map outranks the Mediums. Sweep Surface inventory rows with known-answer batteries.

Changed: .jeffy/probes/_lib.py (new shared harness), .jeffy/probes/{path-utils,core-utilities,slsa-core,artifact,bsg-cli-parsing}/ (new: check.py, paths, claims, README.md each), PLAN.md (five rows flipped), JOURNAL.md.

Checkpoint: a60251d4f4d3791d5860bbaca6f01aa0a5639d32

Verification: Five rows swept, 28 to 23 unswept. Every battery is a known-answer instrument rather than a liveness probe, and each documented parameter of the functions it certifies is exercised at two or more values that must change the output, with the boundary or negative side included where one exists - the sanitiser's rejected characters, url_is_safe's allow_list present and absent and matching and not, get_patched_env's set and unset and its documented promise not to touch os.environ, get_repo_dir_name's sanitize at both values, get_remote_vcs_url's clean_up at both values, is_commit_hash on both sides of the 7 and 40 character bounds, construct_maven_repository_path's four optional parameters each at two values, and normalize_jdk_version across the 1.x branch and the suffix fallback.

Green totals, each pinned by that battery's claims file: path-utils 16/16, core-utilities 37/37, slsa-core 41/41, artifact 35/35, bsg-cli-parsing 29/29. `check-claims.sh` over the project reports 5 checked, 0 mismatched, 0 errored, 0 skipped.

Observed failing, which is what separates an instrument that works from one that has never been asked to: each battery was run against a deliberately broken tree and reddened. path-utils 12/16 when the PURL sanitiser is made to allow a dot and a slash; core-utilities 36/37 when url_is_safe stops enforcing its allow_list; slsa-core 40/41 when the commit-hash floor drops from 7 to 6; artifact 24/35 when the Maven group id stops becoming a path; bsg-cli-parsing 27/29 when the 1.x JDK branch is dropped. Each mutation, its exact sed command and its revert are recorded in that battery's README. `git status --porcelain -- src/ tests/` was empty before the verify gate, so no mutation survived into the checkpoint.

Two of my own expectations were wrong and were corrected rather than filed: SLSALevels is a plain Enum with an `__int__`, not an ordered one, and the Maven parser deliberately normalises a long flag to its short form, so `--batch-mode` round trips as `-B` and `--no-transfer-progress` as `-ntp`. Both checks now pin the real contract. No new finding came out of this sweep; the two defects already filed against swept code, GIT-001 and GIT-002, are deliberately not pinned by the slsa-core battery, because their correct expectations arrive with their fixes and a battery asserting today's wrong answer would certify the bug.

Verify gate through the installed quiet-verify.sh: green (78s, 1167 passed), unchanged from the last checkpoint because this iteration touched no source or test file.

Learnings: A battery command in a claims file must name `.venv/bin/python` rather than `python`, because check-claims.sh runs it through run-probe.sh with whatever PATH the hook has and the project's dependencies live only in the venv.

Next: continue sweeping. 23 rows remain unswept with 6 iterations left, so the map, not the Medium queue, is still the top of the queue.

## iter 5/10 | e87d31d3-133829 | 2026-09-06 | SWEEP | done

Task: Continue sweeping Surface inventory rows, and answer the hook's README MEASUREMENTS refusal from the previous iteration.

Changed: .jeffy/probes/_mutate.sh (new), .jeffy/probes/{config,vsa,go-helpers,code-analyzer-init}/ (new batteries), .jeffy/probes/{path-utils,core-utilities,slsa-core,artifact,bsg-cli-parsing}/{claims,README.md} (mutation claim added, README regenerated), BACKLOG.md (VSA-001 filed), PLAN.md (four rows flipped), JOURNAL.md.

Checkpoint: e440de358f11a9afccce2c6a2d466d53a6ab4ab7

Verification: The hook was right to refuse the previous iteration's READMEs. Each stated a reddened count that no command derived, which is exactly the shape that lets a number drift from the instrument it describes. Every battery now carries a second claims line that applies its mutation, runs the battery, restores the file and prints the real summary, so check-claims.sh executes the reddened count the same way it executes the green one. The restore is from a copy rather than a git checkout, so an uncommitted change in a mutated path survives. Each README is now generated from its own claims file, so the command it shows is the command that runs.

That mechanism immediately caught one of my own errors: the slsa-core mutation I had typed into the README used an unescaped regex, which sed reads as a bracket expression and silently does not match, so the battery stayed green and check-claims reported MISMATCH rather than the reddened count. The claims line now carries the escaped form that actually mutates.

Four more rows swept, 23 to 19 unswept. Green totals, each pinned: config 27/27, vsa 20/20, go-helpers 20/20, code-analyzer-init 8/8. Observed failing under their own recorded mutations: config 24/27 when get_list ignores remove_duplicates, vsa 19/20 when a policy violation stops suppressing the result, go-helpers 19/20 when the bash parser's unparseable exit status moves from 2 to 3, code-analyzer-init 5/8 when the package init gains an import. check-claims.sh over the project reports 18 checked, 0 mismatched, 0 errored, 0 skipped. `git status --porcelain -- src/ golang/` was empty afterwards, so no mutation survived.

New finding, filed at rubric severity in the iteration that surfaced it: VSA-001 (Medium, runtime, error handling). The vsa battery's end-to-end check failed, and the cause is a real defect rather than a probe error. `create_vsa_statement` returns None on any SQLAlchemyError while reading provenance subjects; `generate_vsa` never checks for it and json.dumps(None) yields the string `null`. Reproduced: generate_vsa returned `{'payloadType': 'application/vnd.in-toto+json', 'payload': 'bnVsbA=='}`, whose payload decodes to None, and `__main__.py` writes exactly that to vsa.intoto.jsonl while logging that the attestation was generated. The battery pins generate_vsa's database-free decision paths and deliberately leaves the passing path unpinned until VSA-001 is fixed.

Two more of my own expectations were wrong and were corrected rather than filed. `go run` collapses every non-zero program exit to 1 and reports the real status only as text on stderr, so the go-helpers battery now builds the binaries and drives those, which is the only way to check the exit codes these tools document. And configparser has already stripped a continuation line's leading whitespace before get_list sees the value, so strip=False preserves the empty leading element rather than the indentation.

Verify gate through the installed quiet-verify.sh: green (80s, 1167 passed), unchanged from the last checkpoint because this iteration touched no source or test file.

Learnings: A sed expression stored in a claims file is BRE, so regex metacharacters in the text being matched must be escaped or the mutation silently does not apply and the battery reports its green count. Build a Go binary before checking its exit status; `go run` reports 1 for every non-zero exit.

Next: 19 rows unswept with 5 iterations left. Keep sweeping.

## iter 6/10 | e87d31d3-133829 | 2026-09-06 | SWEEP | done

Task: Continue sweeping Surface inventory rows.

Changed: .jeffy/probes/{database,output-reporting,policy-engine,repo-verifier}/ (new batteries with paths, claims and README), BACKLOG.md (RVER-001 filed), PLAN.md (four rows flipped), JOURNAL.md.

Checkpoint: 74c144c07389431e08565c60faccdafc95400a0d

Verification: Four more rows swept, 19 to 15 unswept. Green totals, each pinned by its claims file: database 24/24, output-reporting 38/38, policy-engine 24/24, repo-verifier 17/17. Observed failing under their own recorded mutations: database 23/24 when RFC3339DateTime stops truncating to second resolution, output-reporting 37/38 when the header filter stops deduplicating keys, policy-engine 23/24 when a nullable column stops being declared as a symbol, repo-verifier 14/17 when a provenance repository URL stops counting as evidence. check-claims.sh over the project reports 26 checked, 0 mismatched, 0 errored, 0 skipped, and `git status --porcelain -- src/` was empty afterwards.

New finding, filed at rubric severity in the iteration that surfaced it: RVER-001 (High, runtime, correctness). Building the repo-verifier battery surfaced an IndexError rather than a wrong answer. `verify_domains_from_recognized_code_hosting_services` tests `group_parts[0]` and then indexes `group_parts[1]` and `group_parts[2]` unconditionally, so a Maven namespace of one or two segments starting with io or com crashes. Reproduced for `com`, `com.github` and `io.github` against a github.com repository URL, with `com.github.foo` returning passed/git_ns_match in the same run, so this is a boundary rather than a broken function. The namespace is `parsed_purl.namespace` handed straight to `verify_repo` by analyzer.py with no try/except around it, so the analysis aborts with a traceback. The battery pins the three-segment matching path and both documented early returns and deliberately leaves the short-namespace case unpinned until RVER-001 is fixed.

One thing I checked and did not file. `get_fact_declarations(ORMBase.metadata)` raises ValueError over the project's own ORM metadata, because `column_to_souffle_type` has no branch for the RFC3339DateTime and ProvenancePayload TypeDecorator columns. No caller passes ORM metadata: policy_engine.get_generated builds its metadata with `metadata.reflect(engine)`, where those columns arrive as the plain SQLite types the mapping does handle. A user meets nothing, so it is not a finding under the evidence rule; the battery now reflects a created database, which is both correct and a more faithful check of what the policy engine actually does.

Three more of my own expectations were wrong and were corrected rather than filed: DatabaseManager has no terminate method, the reporters carry mode, encoding and indent rather than a file_extension, and j2_filter_get_flatten_dict keys list elements by integer while using the string "0" only on its no-key and unsupported-type paths - a distinction the docstring describes with the same notation for both.

Verify gate through the installed quiet-verify.sh: green (96s, 1167 passed), unchanged from the last checkpoint because this iteration touched no source or test file.

Learnings: A battery must exercise a function through the metadata or object the real caller passes it, not the most convenient one to hand; the policy engine check looked like a product defect until the caller was read.

Next: RVER-001 is an open High and outranks the map, so iteration 7 fixes it. 15 rows remain unswept with 4 iterations left.

## iter 7/10 | e87d31d3-133829 | 2026-09-06 | RVER-001 | done

Task: RVER-001 (High, runtime, correctness) - a Maven namespace of fewer than three dot-separated segments beginning with io or com crashed the repository check with IndexError, aborting the analysis.

Changed: src/macaron/repo_verifier/repo_verifier_maven.py, tests/repo_verifier/test_repo_verifier.py, .jeffy/probes/repo-verifier/{check.py,claims,README.md}, PLAN.md (Verify count, row re-recorded), BACKLOG.md (RVER-001 deleted), JOURNAL.md.

Checkpoint: 59099a41b830e4f203add31f01928d639cc5a5a3

Verification: The fix returns the same UNKNOWN/git_ns_mismatch result the comparison already gives a wrong account, when the namespace is too short to name an account at all. The acceptance check is a new parametrized test over seven namespaces: against the unfixed file four raised `IndexError: list index out of range` (com.github, io.github, com, io) while three passed (com.github.example, io.github.example, org.example), so the check fails on exactly the defect and pins the working cases in the same run. All seven pass after the fix, and the file's other 8 tests are unchanged.

Instance, not a class. The idiom was enumerated with `grep -rnE '\b[a-z_]*parts\[[0-9]+\]' src/macaron --include='*.py'`, which returns six sites beyond index 0. Every other one already guards its length: table_definitions checks `len(parts) == 3` before `parts[1:3]`, repo_verifier_gradle does `if len(line_parts) != 2: continue`, and the closest sibling, `same_organization` in maven_central_registry.py, guards exactly these indices with `min(...) < 2` and `len(...) >= 3`. The fix mirrors that sibling rather than inventing a new shape, and its comment says so.

What the contract preserves: no signature change, and the three namespaces that already produced an answer still produce the same one. The battery that owns this path was extended in the same iteration to pin the fixed behaviour, and its discriminating mutation now removes the guard itself: repo-verifier goes 22/22 to 18/22, reddening exactly the four namespaces that used to crash while `org.example`, which was always safe, stays green - which is what distinguishes a guard from a blanket refusal. That mutation ran while the fix was still uncommitted and the fix survived it, because _mutate.sh restores from a copy rather than with a git checkout.

Verify gate through the installed quiet-verify.sh: green (91s, 1174 passed), up from 1167 by the seven parametrized cases; PLAN.md's Verify count now carries that figure. check-claims.sh reports 26 checked, 0 mismatched, 0 errored, 0 skipped. mypy clean and pylint 10.00/10 on both changed files.

Learnings: none new this iteration.

Next: no open High remains, so the map is the top of the queue again. 15 rows unswept with 3 iterations left, which does not clear at the observed rate; iteration 8 sweeps as many as it can properly evidence.

## iter 1/10 | 22381375-143126 | 2026-09-06 | SWEEP | done

Task: No open High, so the map is the top of the queue. Sweep Surface inventory rows, the one exemption from never-batch.

Changed: .jeffy/probes/{parsers,dependency-analyzer,repo-finder}/ (new batteries with check.py, paths, claims and README), BACKLOG.md (POM-001, CDX-001, GHA-001 filed), PLAN.md (three rows flipped), JOURNAL.md.

Checkpoint: 2cd97ff8057608b09f8861df9e8e309237d0ebd0

Verification: Three more rows swept, 15 to 12 unswept. Green totals, each pinned by its claims file: parsers 74/74, dependency-analyzer 38/38, repo-finder 48/48. Observed failing under their own recorded mutations: parsers 71/74 when detect_parent_pom stops reading the relativePath element, dependency-analyzer 36/38 when get_dep_components ignores its recursive parameter, repo-finder 46/48 when determine_abstract_purl_type stops recognising a repository domain. check-claims.sh over the project reports 32 checked, 0 mismatched, 0 errored, 0 skipped, and `git status --porcelain -- src/ golang/` was empty afterwards, so no mutation survived.

Verify gate through the installed quiet-verify.sh: green (94s, 1174 passed), unchanged from the last checkpoint because this iteration touched no source or test file.

Three new findings, each filed at rubric severity in the iteration that surfaced it.

POM-001 (Medium, runtime, correctness) came out of the POM fixtures. `detect_parent_pom` builds the candidate as `Path(pom_path.parent, relative_path, "pom.xml")`, so `<relativePath>` is only resolvable when it names a directory. The form that names the file resolves to `../pom.xml/pom.xml` and returns None, and that form is the very default the function's own comment documents. Reproduced over one reactor root with the same sub-module written both ways: `../` returns `'pom.xml'` from both detect_parent_pom and find_nearest_modules_pom, `../pom.xml` returns None from both. The project's own fixtures under tests/slsa_analyzer/build_tool/mock_repos/maven_repos use the directory form only, which is why the suite is green over it.

CDX-001 (Medium, runtime, correctness) came out of a check that would not pass. `convert_components_to_artifacts` guards its SNAPSHOT-submodule skip with `if component.external_references is None`, and the CycloneDX library's setter is `self._external_references = SortedSet(external_references)`, so the attribute is a SortedSet whether the component was constructed or deserialized - I confirmed both - and the branch is dead. The heuristic the comment describes, avoiding a submodule that produced a development artifact in the same repo, never fires.

GHA-001 (Low, runtime, correctness): `get_step_input` returns `str(with_section.get(key))`, so a missing key yields the string "None" rather than None. Filed Low against the rubric's documented-promise Medium, with the rationale on the line: nothing in src or tests calls it, so no shipped code path reaches the branch and a user of the shipped product meets nothing.

Two of my own expectations were wrong and were corrected rather than filed. The battery's PROJECT_ROOT needed one more dirname than the shared _lib.py uses, because a battery's check.py sits one directory deeper than _lib.py; with the shallow value the Go binaries built into `.jeffy/golang` and every bash parser check errored. And `get_git_service` answers NoneGitService for every URL until each entry in GIT_SERVICES has had its own `load_defaults()` called, which is what populates its hostname - `load_defaults("")` alone is not enough, and __main__.py performs both steps.

One check here was ordered specifically to be able to fail. The name-prefix preference in `match_tags` returns the prefixed tag ahead of a bare one, but the fall-through returns the last matching tag anyway, so a tag list with the bare tag first passes whether the preference runs or not; written that way, removing the preference changed nothing and the battery certified a dead clause. The list now puts the bare tag last.

Learnings: A battery's check.py sits one level deeper than _lib.py, so its own PROJECT_ROOT needs four dirname calls, not three. A git service's hostname is populated by that service instance's own load_defaults(), not by the module-level load_defaults(""); is_detected returns False for everything until both have run.

Next: 12 rows unswept with 9 iterations left, and two open Mediums the sweep just filed. The map still outranks a Medium, so iteration 2 keeps sweeping.

## iter 2/10 | 22381375-143126 | 2026-09-06 | SWEEP | done

Task: No open High, so the map is still the top of the queue. Continue sweeping Surface inventory rows.

Changed: .jeffy/probes/{slsa-provenance,provenance}/ (new batteries with check.py, paths, claims and README), BACKLOG.md (PROV-002 filed), PLAN.md (two rows flipped), JOURNAL.md.

Checkpoint: a874de3d19d66261b778c55cf512225f284f8b86

Verification: Two more rows swept, 12 to 10 unswept. Green totals, each pinned by its claims file: slsa-provenance 58/58, provenance 44/44. Observed failing under their own recorded mutations: slsa-provenance 56/58 when the in-toto v0.1 digest set accepts a non-string value, provenance 42/44 when `_extract_commit_from_digest_set` ignores its valid_algorithms parameter. check-claims.sh over the project reports 36 checked, 0 mismatched, 0 errored, 0 skipped, and `git status --porcelain -- src/ golang/` was empty afterwards, so no mutation survived.

Verify gate through the installed quiet-verify.sh: green (78s, 1174 passed), unchanged from the last checkpoint because this iteration touched no source or test file.

Both rows are adversarial surface under the Operating envelope - a provenance document is supplied by whoever wants the package to pass - so both batteries drive the refusals rather than only the happy path: one refusal per required field on each in-toto statement version, a subject that is not an object, a digest whose value is not a string, a payload that is not JSON, a payload that is a JSON array, a missing predicate type, and a predicate type that requires a predicate and has none.

One new finding, filed at rubric severity in the iteration that surfaced it. PROV-002 (Medium, runtime, correctness): `_clean_spdx` strips the SPDX `git+` prefix with `str.lstrip("git+")`, which removes a character set rather than a prefix. Reproduced across four URI forms: `git+https://...` and `git+ssh://...` and a bare URL all clean correctly, because the character after the prefix stops the strip, while `git://github.com/o/r@refs/heads/main` and `git+git://github.com/o/r@refs/heads/main` both return `://github.com/o/r`. Driven end to end through `extract_repo_and_commit_from_provenance` over a SLSA v0.2 payload, which returned `('://github.com/o/r', 'bbbb...')`, so the repository URL a caller receives is the mangled one. Scored Medium rather than High, with the distinguishing line on its ledger entry, because PROV-001 in the same id family was a path-traversal escape and this is a wrong URL with no privilege gain - an attacker who wants Macaron to see a given URL can simply write that URL.

Four of my own expectations were wrong and were corrected rather than filed. The in-toto v1 statement validator does not require a non-empty subject list, and its subject validator requires one of uri, digest or content rather than a name, so a subject identified by uri alone is valid and one carrying only a name is not. `extract_build_artifacts_from_slsa_subjects` takes only the payload - it selects on the presence of a string sha256 digest, not on a file extension. And `InferredProvenance().payload` is the statement mapping itself rather than a payload object; the battery now also feeds it to `validate_intoto_payload`, which is a stronger check that the placeholder really follows the schema it claims.

Learnings: none new this iteration.

Next: 10 rows unswept with 8 iterations left, three open Mediums and one open Low. The map still outranks a Medium, so iteration 3 keeps sweeping.

## iter 3/10 | 22381375-143126 | 2026-09-06 | SWEEP | done

Task: No open High, so the map is still the top of the queue. Continue sweeping Surface inventory rows.

Changed: .jeffy/probes/{bsg-emission,build-tools}/ (new batteries with check.py, paths, claims and README), PLAN.md (Oracle class corrected, two rows flipped), BACKLOG.md (BT-001 and TEST-001 filed), JOURNAL.md.

Checkpoint: b0f6b3d4e14c7a32411f9565b421615ada36af57

Verification: Two more rows swept, 10 to 8 unswept. Green totals, each pinned by its claims file: bsg-emission 50/50, build-tools 49/49. Observed failing under their own recorded mutations: bsg-emission 48/50 when the OpenSSL version boundary widens from >=3.6 to >=0, build-tools 47/49 when the language guard is removed from the deploy and package decisions. check-claims.sh over the project reports 40 checked, 0 mismatched, 0 errored, 0 skipped, and `git status --porcelain -- src/ golang/` was empty afterwards, so no mutation survived.

Verify gate through the installed quiet-verify.sh: green (92s, 1174 passed), unchanged from the last checkpoint because this iteration touched no source or test file.

A standing claim in PLAN.md was wrong and is corrected in this iteration rather than filed. The Oracle class said the Verify command "does not reach the network". It does: `--doctest-modules` collects the doctests of `pick_specific_version`, which call `get_latest_cpython_patch`, which fetches https://www.python.org/ftp/python/. Derived by provoking the failure rather than by reading the source - running that one module under an unroutable proxy exits 1 with `GenerateBuildSpecError('Failed to fetch index of CPython versions.')` - and the line now says so. It deliberately claims one site and no enumeration: the same offline run over the whole suite did not finish inside 500s and was killed, so the complete set of network-reaching targets is not something this iteration measured, and the sentence is narrowed to what was verified.

Two new findings, each filed at rubric severity in the iteration that surfaced it.

BT-001 (Medium, runtime, correctness): `infer_confidence_deploy_workflow` constructs its evidence map with one entry named `ci_workflow_deploy` and then calls `update_result(name="ci_workflow_release", found=True)`. `update_result` is `if evidence := self.map_obj.get(name)`, so a name the map does not hold is a silent no-op and the whole workflow-name heuristic is dead. Reproduced across four workflow paths: release.yaml, test.yaml, publish.yml and build.yml all return `Confidence.LOW`, while the provenance evidence in the same function does move the result to `Confidence.MEDIUM`, so the function is not broken outright - only that clause is.

TEST-001 (Low, test, testing): the same network dependency the Oracle class correction records, filed so the suite's non-hermeticity is on the ledger rather than only in a prose line. Class test, so Low by the severity ceiling: a user of the shipped product never runs the suite, and the live fetch is by design on the gen-build-spec path.

BT-001 and CDX-001 are now two findings of one shape - a heuristic that never fires, one guarded by a name the map does not hold and one by an attribute that is never None. Their root causes differ, so the three-strike rule does not bite yet; a third of this shape replaces instance patching with one structural task, and this note is here so the next iteration that finds one recognises it as the third.

Three of my own expectations were wrong and were corrected rather than filed. `patch_command` takes one command and returns one, not a list of commands. `build_backend_commands` reads `build_requires` filtered to the pip installer, not `build_backends`. And `file_exists` applies its filters to subdirectories it descends into, never to the root it is given, so a filter check has to start above the filtered directory to mean anything - the first version of that check passed with the filter both on and off.

One path is deliberately out of the bsg-emission battery's scope and the README says so: `gen_dockerfile` for a pypi spec reaches `pick_specific_version` and therefore the network, so what is pinned there are the two refusals that land before the fetch.

Learnings: none new this iteration.

Next: 8 rows unswept with 7 iterations left, four open Mediums and two open Lows. The map still outranks a Medium, so iteration 4 keeps sweeping.

## iter 4/10 | 22381375-143126 | 2026-09-06 | SWEEP | done

Task: No open High, so the map is still the top of the queue. Continue sweeping Surface inventory rows.

Changed: .jeffy/probes/{git-services,cli}/ (new batteries with check.py, paths, claims and README), PLAN.md (two rows flipped), JOURNAL.md.

Checkpoint: 876dfe4afbb93cdf9cbcfa49102306f1607f824f

Verification: Two more rows swept, 8 to 6 unswept. Green totals, each pinned by its claims file: git-services 33/33, cli 27/27. Observed failing under their own recorded mutations: git-services 31/33 when the empty-hostname guard is removed from load_hostname, cli 25/27 when the token dictionary loses its precedence over the environment. check-claims.sh over the project reports 44 checked, 0 mismatched, 0 errored, 0 skipped, and `git status --porcelain -- src/ golang/` was empty afterwards, so no mutation survived.

Verify gate through the installed quiet-verify.sh: green (101s, 1174 passed), unchanged from the last checkpoint because this iteration touched no source or test file.

The CLI row is graded by running the real CLI as a subprocess rather than by importing main and driving argparse in process, because the exit statuses are the contract and main reaches them through sys.exit. Two things had to be right for that to be safe. The subprocess runs in a scratch working directory, because main looks for `.macaron_env_file` in the cwd and truncates it if it is there. And the subprocess environment is stripped of GITHUB_TOKEN, MCN_GITLAB_TOKEN, MCN_SELF_HOSTED_GITLAB_TOKEN and HOST_OUTPUT, so whatever this shell carries cannot change an answer and no credential from this machine reaches the battery output. Only dump-defaults is run to completion; the other four sub-commands reach the network or a repository, so what is graded there is the parser's refusal when a required argument is missing and that each carries help of its own.

Two of my own expectations were wrong and were corrected rather than filed. `BitBucket.load_defaults` returns None with a TODO and the shipped defaults.ini carries no bitbucket section, so the service is registered in GIT_SERVICES but has no hostname and detects nothing; that is the declared state of an unimplemented service, and the battery now pins it as such so a later change that starts loading a hostname reddens here instead of passing silently. And `verify-policy` with no arguments exits 2 rather than EX_USAGE, because its required flags are enforced by argparse itself while `analyze` reaches its own EX_USAGE check.

No new findings this iteration.

Learnings: A battery that drives a CLI as a subprocess must run it in a scratch cwd and strip the environment variables the CLI reads, or it grades this machine rather than the code.

Next: 6 rows unswept with 6 iterations left, four open Mediums and three open Lows. The map still outranks a Medium, so iteration 5 keeps sweeping.

## iter 5/10 | 22381375-143126 | 2026-09-06 | SWEEP | done

Task: No open High, so the map is still the top of the queue. Continue sweeping Surface inventory rows.

Changed: .jeffy/probes/{package-registries,ci-services}/ (new batteries with check.py, paths, claims and README), BACKLOG.md (REG-001 filed), PLAN.md (two rows flipped, one Lesson marked recurred), JOURNAL.md.

Checkpoint: 9584cc769ecefd816303480458c4a573978c148f

Verification: Two more rows swept, 6 to 4 unswept. Green totals, each pinned by its claims file: package-registries 46/46, ci-services 31/31. Observed failing under their own recorded mutations: package-registries 43/46 when the recognised-code-hosting clause is disabled in same_organization, ci-services 29/31 when the GitHub Actions retention boundary moves from 400 days to 4000. check-claims.sh over the project reports 48 checked, 0 mismatched, 0 errored, 0 skipped, and `git status --porcelain -- src/ golang/` was empty afterwards, so no mutation survived.

Verify gate through the installed quiet-verify.sh: green (81s, 1174 passed), unchanged from the last checkpoint because this iteration touched no source or test file.

The package-registries mutation is worth naming because it reddens in two directions at once. Disabling the code-hosting clause makes the cross-top-level-domain match stop holding, and at the same time makes two different accounts on one host start matching, because the fall-through compares only the first two parts, which those pairs share. A mutation caught by both a lost True and two gained Trues is one the battery is really measuring.

One new finding, filed at rubric severity in the iteration that surfaced it. REG-001 (Low, runtime, correctness): JFrogMavenRegistry, NPMRegistry and PyPIRegistry each assign self.enabled from their constructor parameter and then call super().__init__, which sets self.enabled = True unconditionally, so the parameter is inert on all three. Reproduced by constructing each with enabled=False and reading the attribute back; MavenCentralRegistry has no such parameter and is unaffected. Filed as one class with its enumeration on the line rather than as three instances, and filed Low with the rationale on the line: `grep -rn 'enabled=' src/macaron --include='*.py'` matches nothing, so no shipped code path constructs a registry that way and the runtime path sets enabled from the ini after construction.

On the three-strike rule: REG-001 is the third finding this run of the shape "code that silently does nothing", after CDX-001 and BT-001. The rule is about a shared root cause, and these three do not share one - a wrong None assumption, a name the evidence map does not hold, and a field the base constructor overwrites are three separate mistakes that happen to look alike from a distance. So each stays an instance finding rather than becoming a structural task, and this note records the reasoning so a later iteration does not re-litigate it.

Five of my own expectations were wrong and were corrected rather than filed. `DepsDevService.encode_purl` escapes only slashes, leaving the colon and the at sign as they are. `extract_asset_metadata_from_file_info_payload` is an instance method rather than a static one. The npm attestation URL carries the version as an `@1.0` suffix. `PackageRegistry` is abstract and cannot be instantiated directly. And CircleCI's entry configuration carries both the .yml and .yaml spellings, not just the first.

One process mistake, recorded because it has now happened twice. I piped the quiet-verify green line through sed and lost the pass count, which cost a second full run of the suite to recover. PLAN.md already carried that Lesson; it is now marked [recurred], and the run report proposes promoting it to a mechanism for the user to decide.

Learnings: none new this iteration.

Next: 4 rows unswept with 5 iterations left - the malware analyzer, both code analyzer rows, and the SLSA checks - with four open Mediums and four open Lows behind them. The map still outranks a Medium, so iteration 6 keeps sweeping.

## iter 6/10 | 22381375-143126 | 2026-09-06 | SWEEP | done

Task: No open High, so the map is still the top of the queue. Continue sweeping Surface inventory rows.

Changed: .jeffy/probes/{malware-analyzer,slsa-checks}/ (new batteries with check.py, paths, claims and README), PLAN.md (two rows flipped), JOURNAL.md.

Checkpoint: 10b4c72f9180e038d528b219fb8c910b7db195b5

Verification: Two more rows swept, 4 to 2 unswept. Green totals, each pinned by its claims file: malware-analyzer 41/41, slsa-checks 37/37. Observed failing under their own recorded mutations: malware-analyzer 38/41 when the keyboard awareness is removed from the typosquatting substitution cost, slsa-checks 33/37 when the check id pattern is replaced with one that matches anything. check-claims.sh over the project reports 52 checked, 0 mismatched, 0 errored, 0 skipped, and `git status --porcelain -- src/ golang/` was empty afterwards, so no mutation survived.

Verify gate through the installed quiet-verify.sh: green (72s, 1174 passed), unchanged from the last checkpoint because this iteration touched no source or test file.

The malware analyzer row is the first one this run where the surface really computes values, so it is graded against the closed form rather than against recorded output: every Jaro and Jaro-Winkler expectation in that battery is the arithmetic written out. That mattered immediately. My first pass asserted the textbook `martha`/`marhta` value of 0.944444 and the implementation returned 0.955556, which looked like a defect for about a minute. It is not: transpositions here are weighted by the keyboard-aware substitution cost, `t` and `h` are diagonal neighbours on QWERTY, and the answer is `(6/6 + 6/6 + (6-0.8)/6)/3` exactly. The battery now pins both a transposition of non-adjacent keys, which does follow the closed form, and that one, which does not, plus a check that the two really differ - so the customisation is certified rather than mistaken for a bug.

Three things about the check registry shaped the slsa-checks battery and are recorded in its README rather than rediscovered later. Check ids are unique across every Registry instance rather than per instance, so a fresh registry is not fresh for id uniqueness. The id pattern rejects a digit segment before the trailing number, so generated probe ids are built from letters. And probe checks land in the process-wide mapping, so the shipped set is recomputed at call time with the probe prefix filtered rather than snapshotted once.

Four of my own expectations were wrong and were corrected rather than filed. `_validate_check_relationship` checks the shape of the tuple and not the id format inside it, so a malformed id in a well-formed relationship validates. `register` populates the checks mapping and the parentless list rather than `checks_to_run`, which `prepare` fills. Registering a malformed check ends the process with `sys.exit(1)` rather than returning. And excluding one check id also excludes what depends on it, which is the reachable-node rule rather than a set difference - `mcn_build_service_1` goes with `mcn_build_as_code_1` - so that case is now three checks that name the rule instead of one that asserted a plain difference.

No new findings this iteration.

Learnings: none new this iteration.

Next: 2 rows unswept with 4 iterations left, both of them the code analyzer - the dataflow engine and the GitHub Actions security analysis built on it. Four open Mediums and four open Lows behind them. The map still outranks a Medium, so iteration 7 sweeps the last two rows.

## iter 7/10 | 22381375-143126 | 2026-09-06 | SWEEP | done

Task: No open High, so the map is still the top of the queue. Sweep the last two Surface inventory rows.

Changed: .jeffy/probes/{code-dataflow,gha-security}/ (new batteries with check.py, paths, claims and README), BACKLOG.md (GHA-002 filed), PLAN.md (two rows flipped), JOURNAL.md.

Checkpoint: 679ce15e49c18eb65074c8cc301944c8e3ae95c8

Verification: The last two rows swept, 2 to 0 unswept - the Surface inventory now lists no unswept row. Green totals, each pinned by its claims file: code-dataflow 45/45, gha-security 39/39. Observed failing under their own recorded mutations: code-dataflow 43/45 when the directory rule is removed from location_subsumes, gha-security 37/39 when the wrapper command set is emptied so `sudo bash x.sh` stops being an executor invocation. check-claims.sh over the project reports 56 checked, 0 mismatched, 0 errored, 0 skipped, and `git status --porcelain -- src/ golang/` was empty afterwards, so no mutation survived.

Verify gate through the installed quiet-verify.sh: green (124s, 1174 passed), unchanged from the last checkpoint because this iteration touched no source or test file.

One new finding, filed at rubric severity in the iteration that surfaced it. GHA-002 (Medium, runtime, security): the injection detection gates on one set of four GitHub context references, written once as a set of paths and again as literal suffixes in the sibling helper, and the caller combines the two with `or`, so those two helpers are the whole gate. `github.event.pull_request.title` and `.body` are not in it. Reproduced both halves: the classifier returns False for the title while returning True for `github.head_ref`, and `_extract_github_refs_from_expression` does extract the title path, so the reference reaches the gate and is dropped there rather than never being seen - which is what makes this a gate width question and not an extraction bug. Scored Medium rather than High with the rationale on the line: the four it carries are the highest-signal ones and the module claims a heuristic rather than exhaustive detection.

The gha-security battery pins today's answer for the title rather than the answer a fix will give, and its README says so, so widening the set reddens the battery and the instrument cannot drift silently away from the ledger entry that describes it.

Three of my own expectations were wrong and were corrected rather than filed. `facts.Scope` takes a name and an optional outer scope, not a kind. `parse_python_command_line` normalises all three invocation forms to one shape - the target in m, c or file as a plain string, everything after it in subprocess_args, the other two set to None - rather than leaving argparse's REMAINDER lists in place. And `resolve_action_ref_to_tag` lists an action's tags over the network, so only its two offline early returns can be pinned hermetically.

Learnings: none new this iteration.

Next: the map is complete - 28 rows of 28 swept. Four open Mediums and four open Lows remain on the ledger, so the queue's next item is a Medium. Three iterations left; the closing sequence needs a full fresh-evidence audit, and the ledger cannot reach the severity floor in the iterations remaining, so iteration 8 works the top Medium and the run will end out of budget with the ledger drawn down rather than converged.

## iter 8/10 | 22381375-143126 | 2026-09-06 | PROV-002 | done

Task: PROV-002 (Medium, runtime, correctness) - `_clean_spdx` stripped the SPDX `git+` prefix with `str.lstrip("git+")`, which removes a set of characters rather than a prefix, so a URI whose own scheme begins with one of them was mangled.

Changed: src/macaron/provenance/provenance_extractor.py, tests/provenance/test_provenance_extractor.py (new parametrized test), .jeffy/probes/provenance/{check.py,claims,README.md}, PLAN.md (Verify count, row re-recorded), BACKLOG.md (PROV-002 deleted, one Settled class recorded), JOURNAL.md.

Checkpoint: 82f3d4c6b8c3194c62d019808b4d84c698de912c

Verification: The filed reproduction ran first, before any edit, and reproduced: `git://github.com/o/r@refs/heads/main` and `git+git://...` both returned `://github.com/o/r`, while `git+https`, `git+ssh` and a bare URL were already correct. The acceptance check is a new parametrized test over those five forms. Run against the unfixed file - copied aside and restored, never checked out over the fix - it failed on exactly the two git-scheme cases and passed the three that already worked, so the check fails on the defect and cannot be satisfied by a function that simply returns its input. All five pass after the fix.

Class, not instance. The idiom was enumerated with `grep -rnE '\.(l|r)strip\("[^"]{2,}"\)' src/macaron --include='*.py'`, which lists this site and two `rstrip("\n")` calls in detect_injection.py; those two strip trailing newlines, where a character-set strip is exactly what is wanted, so they are correct as written and the class is closed with one change. The Settled classes section records that command so the line stays re-checkable.

What the contract preserves: no signature change, `_clean_spdx` is module-private with five call sites in its own file, and the three URI forms that already produced an answer still produce the same one - which the battery and the new test both pin. The fix's docstring says why `removeprefix` rather than `lstrip`, because the two read alike and the next reader will otherwise re-introduce it.

Battery ownership: the diff touches `src/macaron/provenance/provenance_extractor.py`, which the provenance battery's paths file matches. That battery carried a Deliberately unpinned note for this finding; it now pins all five URI forms and drives the git-scheme case end to end through `extract_repo_and_commit_from_provenance`, because the mangled value a caller receives is what the finding was about. It goes 44/44 to 47/47, and its recorded mutation re-derives at 45/47. Its README no longer carries the unpinned note. The Provenance handling inventory row is re-recorded at this iteration's checkpoint.

Verify gate through the installed quiet-verify.sh: green (91s, 1179 passed), up from 1174 by the five parametrized cases; PLAN.md's Verify count now carries that figure. check-claims.sh reports 56 checked, 0 mismatched, 0 errored, 0 skipped. mypy clean and pylint 10.00/10 on both changed files.

Learnings: none new this iteration.

Next: eight open Mediums and four Lows remain with two iterations left, so the ledger cannot reach the severity floor and this run will end out of budget rather than converged. Iteration 9 works the next Medium, GHA-002; iteration 10 writes the handoff.

## iter 9/10 | 22381375-143126 | 2026-09-06 | GHA-002 | done

Task: GHA-002 (Medium, runtime, security) - the GitHub Actions injection detection recognised one set of attacker-controlled context references, spelled out twice, and it held four entries, so a workflow interpolating a pull request title or body into a `run:` block was reported clean.

Changed: src/macaron/code_analyzer/gha_security_analysis/detect_injection.py, tests/code_analyzer/gha_security_analysis/test_gha_security_analysis.py (three new tests), .jeffy/probes/gha-security/{check.py,claims,README.md}, PLAN.md (Verify count, row re-recorded), BACKLOG.md (GHA-002 deleted), JOURNAL.md.

Checkpoint: 7639f741ca36b2c0f0a4ed6ad16f4179ed2e18c3

Verification: The acceptance check is a script driving both matchers over the three added references, the four that were already there, and two maintainer-controlled references that must stay unflagged. Against the unfixed file - copied aside and restored, never checked out over the fix - it printed six failures, one per matcher for each added reference, and exited 1; the four pre-existing references and both negative cases passed on the unfixed tree too, so the check fails on exactly the defect and cannot be satisfied by a matcher that flags everything. Against the fixed file it exits 0.

The fix has two halves. The set is now one module constant, `ATTACKER_CONTROLLED_GITHUB_REFS`, and the suffix form the bash-parser matcher needs is derived from it with `removeprefix` rather than written out a second time - the two lists could previously be edited apart, and the new in-suite test asserts they cannot. Then the set was widened by three: the pull request title and body, and the issue title.

Why those three and not more. The rule I applied is stated in the constant's own comment and is a generalisation of the project's existing choices rather than an imported list: for each event object the module already treats as attacker-controlled, its free-text fields are too. The module already carried `github.event.issue.body` and `github.event.comment.body`, so `github.event.issue.title` is its sibling; it already carried `github.event.pull_request.head.ref`, so the pull request's own title and body are siblings. Vectors that would need a wider judgment - commit messages, commit author names, head labels, and the `pull_request.head.repo` fields - are deliberately not added here, because choosing them is a detection-policy decision for the project owner rather than a defect fix, and the run report carries that as a decision to make.

What the contract preserves: no signature change on either matcher, both keep returning bool, and every reference the module flagged before it still flags - which the acceptance check drives explicitly rather than assuming. The module README already described the finding as "attacker-controlled GitHub context values (for example PR head ref, issue/comment body)", so the widening moves the code toward its own documented framing rather than away from it.

Battery ownership: the diff touches a path the gha-security battery declares. That battery pinned the old narrow behaviour deliberately, with a README note saying a fix would redden it, and it did. It now grades the set three ways - a loop over the constant so an unmatched addition reddens, an equality between the two matchers' sets so they cannot drift, and the three added refs named individually so a later narrowing reddens on those rather than passing on a shorter loop. It goes 39/39 to 42/42 and its recorded mutation re-derives at 40/42. The Code analyzer GHA security row is re-recorded at this iteration's checkpoint.

Verify gate through the installed quiet-verify.sh: green (95s, 1190 passed), up from 1179 by the eleven new parametrized cases; PLAN.md's Verify count now carries that figure. check-claims.sh reports 56 checked, 0 mismatched, 0 errored, 0 skipped. mypy clean and pylint 10.00/10 on both changed files.

Learnings: none new this iteration.

Next: this is the last budgeted iteration but one. Seven Mediums and four Lows remain open, so the ledger is far from the severity floor and no declaration is available; iteration 10 writes a WRAPUP with the handoff.

## iter 10/10 | 22381375-143126 | 2026-09-06 | WRAPUP | done

Task: Final budgeted iteration. The ledger holds seven open Mediums, so it is nowhere near the severity floor and the closing-audit exception does not apply; this iteration tidies BACKLOG.md and writes the handoff rather than starting a task that cannot finish.

Changed: BACKLOG.md (two Proposed items added), JOURNAL.md.

Checkpoint: e7e61ee1ddd883597bbf426eea7c75e2e0f4e99e

Verification: The tidying is a re-verification rather than a re-wording. Every one of the eleven findings still open was re-driven this iteration, because a backlog line is a hypothesis that rots as sibling fixes land around it, and two of this run's fixes landed in the last two iterations. All eleven still reproduce: BT-001 (release.yaml and test.yaml still return the same confidence), CDX-001 (the SNAPSHOT skip still returns a one-entry mapping), POM-001 (the file-form relativePath still resolves to None), BSG-002 (normalize_jdk_version("25.0.1") is still None), GIT-001 (find_highest_git_tag({"0.0.0"}) still raises), GIT-002 (the duplicate guard still maps the annotated tag object), GHA-001 (a missing key still yields the string "None"), REG-001 (all three registries still ignore enabled=False), TEST-001 (the doctest module still exits 1 under an unroutable proxy), PKG-001 (the flit sdist exclude list still names none of the state files), and VSA-001.

VSA-001 is worth a sentence because my first probe of it was wrong and would have read as a refutation. Calling generate_vsa with an empty policy_result returned None, which looks like the finding no longer holding; it is actually the collector's own early return for a result with no passing component. Driven with a policy result that does carry one, the function returns `{'payloadType': 'application/vnd.in-toto+json', 'payload': 'bnVsbA=='}` - the payload that decodes to null - so the finding stands. An inconclusive probe is not evidence a finding is stale, and the ledger keeps the entry.

No stall: this iteration is a WRAPUP, which is a ceremony entry, and it changed BACKLOG.md state by adding two Proposed items.

Two Proposed items are recorded for the project owner. The first is how far to widen the attacker-controlled GitHub reference set: GHA-002 generalised the module's own rule to the free-text siblings of event objects it already trusts, and commit messages, author names, head labels and the head.repo fields are beyond that rule - a detection-policy call rather than a defect fix, which I declined to make unilaterally inside a security tool. The second is promoting the recurred quiet-verify Lesson to a mechanism, since it has now cost two full suite re-runs and the prose rule did not prevent the second.

No convergence is available and none is claimed. The Definition of done requires a full fresh-evidence audit scoring zero High and zero Medium; this run produced no such audit, because every iteration through the seventh was owed to the map and the last three to fixes, and seven Mediums remain open regardless. The run ends out of budget with the map complete and the ledger accurate.

Learnings: A backlog entry re-verified with the wrong input reads exactly like a finding that has gone stale. Drive the reproduction through the precondition the entry names - a passing policy result, a reachable tag, a tracked state file - or the re-verification is evidence of nothing.

Next: the next run starts with a complete map, so its first iteration is a full fresh-evidence audit rather than a sweep, and that audit is the one the closing rule needs. Seven Mediums and four Lows are queued behind it in ledger order, beginning with BT-001.

## iter 1/10 | 96157278-161759 | 2026-09-06 | BT-001 | done

Task: BT-001 (Medium, runtime, correctness) - `infer_confidence_deploy_workflow` built its evidence map with an entry named `ci_workflow_deploy` and then reported the workflow-name heuristic under `ci_workflow_release`, a name the map never held, so `update_result` looked it up, found nothing, and returned; the heuristic never moved the score.

Changed: src/macaron/slsa_analyzer/build_tool/base_build_tool.py, tests/slsa_analyzer/build_tool/test_base_build_tool.py (new file, 13 parametrized cases), .jeffy/probes/build-tools/{check.py,claims,README.md}, PLAN.md (Verify count, row re-recorded), BACKLOG.md (BT-001 deleted), JOURNAL.md.

Checkpoint: 51967e6f831e7e2e64635c24b35a28f94f4c1e36

Verification: The filed reproduction ran first, before any edit, and reproduced exactly as written: `release.yaml`, `deploy.yml`, `publish.yml`, `test.yaml` and `release-test.yaml` all returned `Confidence.LOW`, while the provenance evidence in the same function did move the result to `Confidence.MEDIUM`, which is what placed the failure in the name half rather than in the scoring. After the fix the three deploy keywords return `Confidence.HIGH`, the two test-keyword names stay `Confidence.LOW`, and provenance plus a deploy name reaches `Confidence.HIGH`.

The acceptance check is a new test module driving the function across both halves. Run against the unfixed file - copied aside and restored from that copy, never checked out over the fix - it failed 6 of 13 and exited 1: the three deploy keywords, the case fold, the combined provenance-and-name case, and the explicit `release > test` discrimination. The seven that passed on the unfixed tree are the negative names and the provenance-only cases, so the check fails on exactly the defect and cannot be satisfied by a function that returns HIGH for everything.

Why this direction. `ci_workflow_release` appears nowhere else in the tree; the map's key is the name `get_max_score` sums and is not persisted, so correcting the caller is the smaller change and leaves the declared evidence set untouched. The idiom was enumerated rather than assumed: `grep -rn 'update_result(' --include='*.py' src` returns four call sites in `base_build_tool.py`, and after this fix every one names an evidence the map it is called on declares, so this is a single instance and not a class needing structural work.

What the contract preserves: no signature change, no docstring change, and the function's own comment already described the heuristic this fix makes real. The behaviour that changes is confined to the no-provenance path and to the combined path - a workflow whose name carries no deploy keyword returns exactly what it returned before, which the new tests and the battery both pin on the negative side.

Battery ownership: the diff touches a path the build-tools battery declares, and that battery carried a Deliberately unpinned section naming BT-001 - it drove only `release.yaml` with provenance, which is precisely the input that cannot see an inert name heuristic. Run against the fix it reddened on those two checks, as its own note predicted. It now grades the name heuristic on each of the three deploy keywords separately, on the case fold, on two test keywords, on a name with no keyword, and on a deploy-and-test collision, and it grades the provenance evidence over a name-neutral workflow so the two signals are told apart. It goes 49/49 to 58/58, its language-guard mutation re-derives at 56/58, and a second recorded mutation that restores BT-001 itself re-derives at 53/58 - five reddened, the four name cases and the combined one, with the negatives green. The README no longer carries the unpinned note. The `SLSA analyzer, build tools` inventory row is re-recorded at this iteration's checkpoint.

Verify gate through the installed quiet-verify.sh: green (80s, 1203 passed), up from 1190 by the thirteen new parametrized cases; PLAN.md's Verify count now carries that figure. check-claims.sh reports 57 checked, 0 mismatched, 0 errored, 0 skipped, up one row from the added mutation claim. mypy clean and pylint 10.00/10 on both changed files.

Learnings: A battery that pins only the working half of a function it knows is half broken will redden on the fix. That is the instrument behaving correctly, not a regression, but the fix's iteration owns re-measuring every count the battery's README and claims state.

Next: six open Mediums and four Lows remain. Iteration 2 works CDX-001, the next Medium in ledger order.

## iter 2/10 | 96157278-161759 | 2026-09-06 | CDX-001 | done

Task: CDX-001 (Medium, runtime, correctness) - `convert_components_to_artifacts` guarded its SNAPSHOT-submodule skip with `if component.external_references is None`, and the CycloneDX library normalizes that attribute to a `SortedSet`, so the guard never opened and the heuristic behind it never ran.

Changed: src/macaron/dependency_analyzer/cyclonedx.py, tests/dependency_analyzer/cyclonedx/test_cyclonedx.py (5 new parametrized cases), .jeffy/probes/dependency-analyzer/{check.py,claims,README.md}, PLAN.md (Verify count, row re-recorded), BACKLOG.md (CDX-001 deleted, CDX-002 filed), JOURNAL.md.

Checkpoint: 2b1cbcb9b0674aaea1409ede7126c39b2a948ad6

Verification: The filed reproduction ran first, before any edit, and reproduced exactly as written. `Component(name="n", group="g", version="1.0-SNAPSHOT").external_references` is `SortedSet([])`, not None, so the acceptance call returned a one-entry mapping keyed `g:n` carrying the note "Manual configuration required. Could not find SCM URL." and `SCMStatus.MISSING_SCM`. After the fix it returns `{}`.

The library behaviour is measured rather than assumed: on cyclonedx-python-lib 11.12.0, `Bom().components`, `Bom().dependencies` and `Component(...).external_references` are all `SortedSet([])`, and assigning None to `external_references` still reads back as `SortedSet([])`, so no input reaches the old branch.

The acceptance check is five parametrized cases in the project's own suite: the skip, its case fold on `1.0-snapshot`, and the three inputs that must not be skipped - a SNAPSHOT from another group, a released version of the root group, and no `root_component` at all. Run against the unfixed file - copied aside and restored from that copy, never checked out over the fix - it failed exactly 2 of the 5 and exited 1, the two skip cases; the three negatives passed on the unfixed tree too, so the check cannot be satisfied by a function that skips everything.

Enumeration rather than assumption on the class. The idiom is an `is None` test against a collection attribute the CycloneDX library normalizes. `grep -rln 'from cyclonedx' --include='*.py' src/macaron` returns seven modules, and grepping `is (not )?None` across exactly those returns eight lines, of which six compare a local, a function return or a list element. Two compare a library-normalized collection: this fix's site, and `if root_bom.components is None` in `get_dep_components`. The class is therefore two sites, not one, and it is not settled here.

The second site is filed as CDX-002 at Low rather than fixed alongside, and the distinction is not effort. Enabling that guard is not a mechanical repair: `get_target_cdx_component` falls back to `root_bom.metadata.component` when the components collection yields nothing, so a BOM whose target lives only in metadata is handled today and would return early under a live guard. Nothing a user meets changes while it stays dead - the loop finds nothing, the metadata fallback runs, and only a debug line goes unprinted - which is what places it at Low under the rubric while CDX-001 was a Medium for producing a wrong dependency row.

What the contract preserves: no signature change and no docstring change on a public static method. The behaviour that changes is confined to components carrying no external references, and only where the version says SNAPSHOT and the group matches the root: a component with references still takes the URL-lifting branch, and a component without them that fails either condition still falls through to `add_latest_version` with an empty URL and `MISSING_SCM`, exactly as before. The comment above the guard now states why the collection is tested for emptiness rather than for None, because the two read alike.

Battery ownership: the diff touches a path the dependency-analyzer battery declares. That battery carried a Deliberately unpinned section naming CDX-001 and pinned only the reachable `MISSING_SCM` outcome, so it stayed green across the fix rather than reddening. It now drives the heuristic on both sides - the skip, the case fold, and the three inputs that must not be skipped - and goes 38/38 to 43/43. Its recursive-clause mutation re-derives at 41/43, and a second recorded mutation that restores CDX-001 itself re-derives at 41/43 with the two skip checks red and the three negatives green, which places that failure in the guard rather than in the heuristic's conditions. The README no longer carries the unpinned note. The `Dependency analyzer` inventory row is re-recorded at this iteration's checkpoint.

Verify gate through the installed quiet-verify.sh: green (84s, 1208 passed), up from 1203 by the five new parametrized cases; PLAN.md's Verify count now carries that figure. check-claims.sh reports 58 checked, 0 mismatched, 0 errored, 0 skipped, up one row from the added mutation claim. mypy clean and pylint 10.00/10 on both changed files.

The recurred Lesson recurred a third time this iteration: I piped the quiet-verify green line through sed, lost the pass count, and paid for it with a second full suite run. Both runs reported 1208, so the figure quoted above is the wrapper's own and is corroborated, but the cost is now three suite re-runs across two runs. The Proposed item asking for that rule to become a mechanism rather than prose has its third data point, and this entry is the evidence for it.

Learnings: The instruction not to pipe the quiet-verify line is not a style preference - the pass count exists only on that line, and every violation costs a full suite re-run. Read the wrapper's output whole, then quote from it.

Next: five open Mediums and five Lows remain. Iteration 3 works POM-001, the next Medium in ledger order.

## iter 3/10 | 96157278-161759 | 2026-09-06 | POM-001 | done

Task: POM-001 (Medium, runtime, correctness) - `detect_parent_pom` appended a literal `pom.xml` to whatever `<relativePath>` held, so the element resolved only when it named a directory; the file form `../pom.xml`, which is Maven's own default spelling and the one the function's comment documents, resolved to `../pom.xml/pom.xml` and returned None.

Changed: src/macaron/parsers/pomparser.py, tests/parsers/pomparser/test_pomparser.py (8 new cases across three tests), .jeffy/probes/parsers/{check.py,claims,README.md}, PLAN.md (Verify count, row re-recorded), BACKLOG.md (POM-001 deleted), JOURNAL.md.

Checkpoint: fdde3d1d12a9778f5c68c805d1930d208fba0d19

Verification: The filed reproduction ran first, before any edit, over a written reactor root with one module. `../pom.xml` returned None from both `detect_parent_pom` and `find_nearest_modules_pom`, while `../`, `..` and an absent element all returned `pom.xml` - which is what placed the failure in the appended segment rather than in the element being read. After the fix all four forms return `pom.xml`.

The acceptance check is eight cases in the project's own suite: the file form, two directory spellings, the absent element, a missing target in each form, a parent POM not called `pom.xml`, and a parent that resolves on disk but outside `repo_root`. Run against the unfixed file - copied aside and restored from that copy, never checked out over the fix - it failed exactly 2 and exited 1, the file form and the named parent file; the six others passed on the unfixed tree too, so the check cannot be satisfied by a resolver that accepts everything, and the two None-expecting cases confirm it still refuses what it should.

The fix follows Maven's rule rather than inverting the old one: the candidate is the element's own path, and `pom.xml` is appended only when that path is a directory. Both prior behaviours are preserved by construction - a directory still gets the file name appended, an absent element still takes the `../` default - and a form the old code could never resolve, a parent POM not named `pom.xml`, now resolves, which is the same Maven rule rather than an added feature.

What the contract preserves: no signature change. The docstring documented the two forms only implicitly and now states them, because a reader comparing it against the old code would have concluded the file form was unsupported by design. The out-of-repo refusal and the missing-target None are unchanged and are pinned on both sides.

Battery ownership: the diff touches a path the parsers battery declares. That battery carried a Deliberately unpinned section naming POM-001 and a fixture comment saying the directory form was the only one that resolved, so it stayed green across the fix. It now carries a parent chain spelled each way, a parent POM not called `pom.xml`, and a missing target in each form, and goes 74/74 to 79/79. Its relativePath-tag mutation now reddens eight checks rather than three - the five that lose their parent and the three that expect None and start returning the root POM - and re-derives at 71/79; a second recorded mutation restores POM-001 itself and re-derives at 76/79, reddening exactly the three file-form checks while both directory forms, both missing targets and the escape check stay green. Both reddened sets were enumerated by running the mutations and reading the FAIL lines, not by reasoning about them, and the README names them. The `Parsers` inventory row is re-recorded at this iteration's checkpoint.

Verify gate through the installed quiet-verify.sh: green (96s, 1216 passed), up from 1208 by the eight new cases; PLAN.md's Verify count now carries that figure. check-claims.sh reports 59 checked, 0 mismatched, 0 errored, 0 skipped, up one row from the added mutation claim. mypy clean and pylint 10.00/10 on both changed files.

Learnings: A mutation is only a discriminator if it reproduces the defect it claims to. My first attempt at the POM-001 mutation disabled the directory branch instead of restoring the appended segment, and it reddened four checks that had nothing to do with the finding; running it and reading the FAIL lines is what caught that, and it is the only way to know a mutation reddens what its README says.

Next: four open Mediums and five Lows remain. Iteration 4 works BSG-002, the next Medium in ledger order.

## iter 4/10 | 96157278-161759 | 2026-09-06 | BSG-002 | done

Task: BSG-002 (Medium, runtime, correctness) - `normalize_jdk_version` matched against an enumerated list of major versions ending at "24", so JDK 25 and later returned None, and `MavenBuildSpec.resolve_fields` treats None as fatal and returns without producing a spec.

Changed: src/macaron/build_spec_generator/common_spec/jdk_version_normalizer.py, tests/build_spec_generator/test_jdk_version_normalizer.py (7 new accepted cases and a new 5-case refusal test), .jeffy/probes/bsg-cli-parsing/{check.py,claims,README.md}, PLAN.md (Verify count, row re-recorded), BACKLOG.md (BSG-002 deleted), JOURNAL.md.

Checkpoint: 27f22ede343be245653892cf18fef517c916fe32

Verification: The filed reproduction ran first, before any edit, and reproduced exactly as written: "25.0.1", "25" and "26" all returned None while "24" returned "24". After the fix they return "25", "25" and "26". The module's own doctest recorded that None as expected output, so it was the defect written down as a passing test; it now records '25', and running the old doctest against the old file confirms it passed there, which is what makes the doctest change the counterpart of the fix rather than an unrelated edit.

The fix removes the ceiling rather than extending it. The enumerated list is gone, replaced by a floor of 5 and a read of the leading digits of the major component, which is what the old `startswith` loop was approximating for suffixed strings like "19-ea" and "8 (Azul Systems Inc. 25.282-b08)". A list of known versions is wrong by construction - it needs an edit every JDK release, and the failure when it goes stale is silent - so extending it to 25 would have re-filed this finding next year.

Differential over the whole input shape, not a spot check. The old implementation was re-implemented beside the new one and both were driven over 792 generated strings - majors 0 to 39 plus "1", "19000", "20230101" and the empty string, each with nine suffix shapes, each in the bare and the "1.x" spelling. 306 differ, and they fall into exactly two families with nothing else moving: majors 25 through 39, which is the fix, and two implausible digit runs. Every string the old code answered for below the ceiling still gets the same answer, including all eight cases the project's existing tests pin.

The second family is a deliberate behaviour change on out-of-contract input, recorded rather than hidden. For "19000" the old list truncated to the longest listed prefix and fabricated "19"; the leading-digit read returns "19000". The docstring states that a valid real-world version is assumed, so neither answer is in contract, and returning the digits actually present is the honest reading where fabricating a plausible-looking major is not. It is pinned in the battery so a later narrowing has to argue with a check.

The acceptance check is 12 new cases in the project's own suite - the floor, the old ceiling, four versions past it, an early-access spelling past it, and a new refusal test over five inputs that must stay None. Run against the unfixed file - restored from git into place and then replaced from a copy of the fix, never checked out over it - it failed exactly 5 and exited 1, the five past the ceiling; the floor, the old ceiling, every 1.x form, both vendor suffixes and all five refusals passed on the unfixed tree too, so the check cannot be satisfied by a normalizer that accepts everything.

What the contract preserves: no signature change and no change to the accepted-input shape below the old ceiling. The public constant `SUPPORTED_JAVA_VERSION` is removed, and that removal was enumerated rather than assumed - `grep -rn 'SUPPORTED_JAVA_VERSION'` across the whole tree returns only this module, the ledger line and the battery's own mutation, so no caller or test read it. `MIN_SUPPORTED_JAVA_VERSION` replaces it and its comment says why there is no upper bound.

Battery ownership: the diff touches a path both the bsg-cli-parsing and bsg-emission batteries declare; bsg-emission's glob covers only `src/macaron/build_spec_generator/*.py`, so this file matches bsg-cli-parsing alone, and that battery carried the comment saying JDK 25 and later were deliberately not pinned. It now grades the floor, the old ceiling, four versions past it, a suffixed one past it and the implausible digit run, and goes 29/29 to 37/37. Its 1.x-branch mutation re-derives at 35/37, and a second recorded mutation that restores the ceiling at 24 re-derives at 31/37, reddening exactly the six past-ceiling checks while both 1.x forms, the floor and the three refusals stay green. Both reddened sets were read off real runs. The `Build spec generator, CLI command parsing` inventory row is re-recorded at this iteration's checkpoint.

Verify gate through the installed quiet-verify.sh: green (81s, 1228 passed), up from 1216 by the twelve new cases; PLAN.md's Verify count now carries that figure. check-claims.sh reports 60 checked, 0 mismatched, 0 errored, 0 skipped, up one row from the added mutation claim. mypy clean and pylint 10.00/10 on both changed files.

Learnings: When a fix widens what a function accepts, re-implement the old version beside the new one and diff them over a generated corpus rather than over the cases that come to mind. The 19000 family here was invisible to every hand-picked input and is the only place this change moved an answer it did not intend to.

Next: three open Mediums and five Lows remain. Iteration 5 works GIT-001, the next Medium in ledger order.

## iter 5/10 | 96157278-161759 | 2026-09-06 | SWEEP | done

Task: The Stop hook flagged the `Build spec generator, emission` row stale - iteration 4 changed `src/macaron/build_spec_generator/common_spec/jdk_version_normalizer.py`, which the bsg-emission battery's declared paths match. A stale row outranks every open Medium in the queue, so this iteration sweeps it rather than starting GIT-001.

Changed: .jeffy/probes/bsg-emission/{check.py,claims,README.md}, PLAN.md (row re-recorded, Lesson added), JOURNAL.md.

Checkpoint: 30acec05e0574a725ce2444f2068d6c1184c043e

Verification: Iteration 4's entry states that bsg-emission's glob covers only `src/macaron/build_spec_generator/*.py` and that the changed file therefore matched bsg-cli-parsing alone. That is wrong, and this entry is the correction, since a past entry is never rewritten. In the matcher the hook uses, a `*` in a paths glob crosses a directory separator, so `src/macaron/build_spec_generator/*.py` covers the whole subtree including `common_spec/`. My iteration-1 staleness scan missed it for a different reason: it interpolated the globs unquoted into `git diff`, so the shell expanded them against the working tree before git ever saw them, and the expansion only produced the top-level files. Both readings are now checked with a scan that matches the way the hook does, and bsg-emission was the only stale row in the table.

The staleness is substantive rather than a glob artifact, which a transitive import walk over the battery's own six seed modules establishes: 103 macaron modules are reachable, and exactly one path reaches the changed module - `reproducible_central -> common_spec.core -> common_spec.maven_spec -> jdk_version_normalizer`. So the row's surface really can reach the code iteration 4 changed, and narrowing the glob to silence the signal would have been wrong. The glob stays as it is: over-claiming makes a row go stale more often than needed, which is the safe direction, while under-claiming lets a row certify changed code it never re-ran.

The battery was executed, not merely re-recorded: `bsg-emission` was green at 50/50 on the changed tree before any edit. Emission does not normalize - it writes the `language_version` the spec already carries into the `jdk` field, measured at four values - so the boundary iteration 4 moved is not reachable through the fixtures as they stood. Two checks now stand on it: a major past the enumerated ceiling that module used to stop at, and a `1.x` spelling that must arrive unchanged rather than normalized to "8". The battery goes 50/50 to 52/52, its OpenSSL-boundary mutation re-derives at 50/52, and the README records the transitive path so the next reader does not have to rediscover it.

Verify gate through the installed quiet-verify.sh: green (119s, 1228 passed), unchanged from iteration 4 because this iteration touched no product code and no project test. PLAN.md's Verify count already carries that figure. check-claims.sh reports 60 checked, 0 mismatched, 0 errored, 0 skipped.

No stall: this iteration changed only state files and paths under .jeffy/, and no BACKLOG item changed state, but a Surface inventory row did - the re-record is the sweep's own product, which the stall rule counts as progress.

Learnings: A `*` in a battery paths glob crosses directory separators in the hook's matcher, so `dir/*.py` claims the whole subtree. Several paths files here pair `dir/*.py` with `dir/*/*.py`, which only makes sense under the narrower reading, so those batteries claim more scope than their authors intended. Leave them wide - the cost is extra re-records, and the alternative is a row certifying code its battery never drove.

Next: three open Mediums and five Lows remain, and no row is stale. Iteration 6 works GIT-001.

## iter 5/10 | 96157278-161759 | 2026-09-06 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines at 544, so all but the last 10 entries were moved to JOURNAL-archive.md.

Changed: JOURNAL.md, JOURNAL-archive.md (created).

Checkpoint: 30acec05e0574a725ce2444f2068d6c1184c043e

Verification: 22 entries were present and 12 were moved, leaving 10 in JOURNAL.md and 12 in the archive, which is the whole 22 with none lost. The split was taken only on lines beginning `## iter` followed by a digit, so the heading-grammar example in the preamble was neither counted nor moved, and the preamble stays in JOURNAL.md. The archive did not exist before this rotation and now carries its own header plus the 12 moved entries in their original order; later rotations append to it and never overwrite it. JOURNAL.md is 263 lines after the move.

Learnings: none new this iteration.

Next: the primary entry for this iteration is the SWEEP above; iteration 6 works GIT-001.

## iter 6/10 | 96157278-161759 | 2026-09-06 | GIT-001 | done

Task: GIT-001 (Medium, runtime, correctness) - `find_highest_git_tag` seeded its search at `version.Version("0")` and advanced only on strict `>`, so a tag set whose only valid version normalizes to zero raised `GitTagError("No valid version tag found.")`, and `osv_dev.py` turned that into `APIAccessError`, abandoning the vulnerability lookup for that package.

Changed: src/macaron/slsa_analyzer/git_url.py, tests/slsa_analyzer/test_git_url.py (15 new cases across two tests), .jeffy/probes/slsa-core/{check.py,claims,README.md}, PLAN.md (Verify count, row re-recorded), BACKLOG.md (GIT-001 deleted, GIT-003 filed), JOURNAL.md.

Checkpoint: f83c446b6b374196e1866c1ae76bc4f13c700b86

Verification: The filed reproduction ran first, before any edit, and reproduced exactly as written: `{"0.0.0"}`, `{"v0"}`, `{"0"}`, `{"0.0"}` and `{"v0.0.0"}` each raised `GitTagError("No valid version tag found.")`, while `{"0.0.0", "1.0.0"}` and `{"v2.0.0"}` answered normally, which placed the failure in the seed rather than in the parse. After the fix each of the five returns its tag.

The fix seeds with None and takes the first parsed tag unconditionally, so the comparison stops standing in for "has one been found yet". Every documented example still holds, including the two refusals, and the docstring gains an example for the zero case so the contract states it.

Differential over the input shape rather than a spot check. The old implementation was re-implemented beside the new one and both were driven over every one-, two- and three-element subset of a sixteen-tag pool covering the zero spellings, an epoch, dev, rc and alpha variants, unparseable strings and ordinary versions - 696 tag sets. 228 differ, and every one is a set where the old code raised "No valid version tag found" and the new one returns a tag; there is no other kind of difference at all.

The acceptance check is fifteen cases in the project's own suite - the five zero spellings, a zero beside an unparseable tag, two where a real tag must beat a zero one, the four orderings the docstring documents, and a three-case refusal test. Run against the unfixed file - restored from git into place and then replaced from a copy of the fix, never checked out over it - it failed exactly 6 and exited 1, the six zero-finding cases; the orderings and all three refusals passed on the unfixed tree too, so the check cannot be satisfied by a function that returns any tag.

What the contract preserves: no signature change and no change to either refusal. The one behavioural change is that a set whose highest valid version is zero now answers instead of raising, which is the finding.

One property was measured and found pre-existing rather than introduced. When two tags parse to the same version - `1.0` and `1.0.0`, or `v1.0.0` and `1.0.0` - strict `>` keeps whichever the set iterated first, and set iteration over strings varies with the interpreter hash seed. Driven at eight PYTHONHASHSEED values, both the old and the new implementation return the same split of answers, so the fix neither introduces nor worsens it. It is filed as GIT-003 at Low, with the rationale on its line: the tied tags are aliases naming one version and the OSV query resolves the same either way, so what a user meets is an unstable string rather than a wrong one.

Battery ownership: the diff touches a path the slsa-core battery declares, and only that one, checked with the matcher the hook uses rather than a shell expansion. That battery had no note about GIT-001 - it simply never drove a zero tag, so it was green at 41/41 both before and after the fix. It now drives four zero-finding cases and one where a real tag must beat a zero one, and goes 41/41 to 46/46. Its commit-hash mutation re-derives at 45/46, and a second recorded mutation that restores the zero seed re-derives at 42/46; those four redden as errors rather than failures, because the mutated function raises on exactly the input it should answer for, which is why reading the run rather than assuming the shape mattered again. The `SLSA analyzer core` inventory row is re-recorded at this iteration's checkpoint.

Verify gate through the installed quiet-verify.sh: green (76s, 1243 passed), up from 1228 by the fifteen new cases; PLAN.md's Verify count now carries that figure. check-claims.sh reports 61 checked, 0 mismatched, 0 errored, 0 skipped, up one row from the added mutation claim. mypy clean and pylint 10.00/10 on both changed files.

Learnings: A battery check that reddens by raising is reported as ERROR, not FAIL, so grepping a mutated battery for FAIL finds nothing and reads like a mutation that did not apply. Read the whole stderr of a mutated run.

Next: two open Mediums and six Lows remain. Iteration 7 works PKG-001, the next Medium in ledger order.
# Journal

Append-only. One primary entry per iteration; SALVAGE and ROTATION entries are additional. Never rewrite past entries (filling the current entry's Checkpoint field is completion, not a rewrite).

Heading grammar, exactly (fenced and indented here so this example is never mistaken for an entry by anything that counts or rotates them):

```
  ## iter <i>/<N> | <run-id> | <YYYY-MM-DD> | <task-id or AUDIT or SWEEP or EVALUATOR or RATCHET or WRAPUP or SALVAGE or ROTATION> | <done|blocked|audit|converged|hunted|salvage|rotation>
```

Write a real heading at column zero, never indented: the indentation above belongs to the example alone, and an indented heading is invisible to the rotation anchor and to the archive counter, so the entry under it is not counted and not rotated.

A SWEEP entry is an iteration spent sweeping Surface inventory rows and takes status done. SALVAGE entries take status salvage; ROTATION entries take status rotation. An EVALUATOR entry records an evaluator-gate iteration: status audit when the run continues after the verdict, blocked on a terminal REJECT (one with no invocation remaining), converged when that same iteration declares.

A High-hunt run (launched with `/jeffy N --highs`) writes the same headings without SWEEP, EVALUATOR or RATCHET entries; its closing entry is the AUDIT that found no High, and that entry alone takes status hunted.

run-id is the first 8 characters of the session id, a hyphen, then the HHMMSS of started_at from the loop state frontmatter, so two runs in one session are told apart. Body fields, in order: Task, Changed, Checkpoint (the jeffy checkpoint commit hash, or none with the reason), Verification, Learnings, Next.

The closing entry that declares convergence carries the evaluator verdict in its Verification field: `Evaluator: PASS - <one-line summary>`. `Evaluator: unavailable (<reason>)` is recorded when no sub-agent can be spawned, and it is not a verdict a run declares on: the Stop hook refuses it and the run ends blocked until a relaunch where the gate can run. An earlier EVALUATOR entry records its own verdict the same way and never stands in for the closing one: the Stop hook reads the closing entry alone, so a run that gates early and keeps working re-invokes the gate at the declaration.

Closed tasks are recorded here as one line each (ID, title, closing evidence), because BACKLOG.md deletes them. Rotation: when this file exceeds 500 lines, move all but the last 10 entries to the end of JOURNAL-archive.md, appending to whatever that file already holds and never overwriting it, because the archive accumulates across every rotation and every run; create it only when it does not already exist, and record the rotation as a ROTATION entry.

## iter 7/10 | 96157278-161759 | 2026-09-06 | PKG-001 | done

Task: PKG-001 (Medium, build-ci, dependency hygiene) - the flit sdist selects from git-tracked files and subtracts `[tool.flit.sdist].exclude`, which named none of the loop's state, so `PLAN.md`, `BACKLOG.md`, `JOURNAL.md`, `JOURNAL-archive.md` and `.jeffy/` shipped inside the source distribution the release workflow publishes.

Changed: pyproject.toml, .jeffy/probes/packaging/{check.py,claims,paths,README.md} (new battery), PLAN.md (new inventory row), BACKLOG.md (PKG-001 deleted), JOURNAL.md.

Checkpoint: caab657b0a916a6b0dabdd08af64aedb89061ec9

Verification: The filed reproduction ran first, before any edit. `flit build --format sdist` produced a 422-entry tarball of which 122 were the loop's own - 118 under `.jeffy/` and the four root state files. The ledger line said four entries, which was the measurement when it was filed; the finding is unchanged but its magnitude is thirty times larger, and this entry is where that correction is recorded rather than in the closed line. The wheel was and is unaffected: 264 entries under `macaron/` and the dist-info, no loop state.

The fix adds the five paths to the exclude list, which is the same shape the list already had for `CHANGELOG.md`, `Makefile` and `SECURITY.md`. Acceptance as filed now returns nothing.

The change was checked for over-exclusion by differencing the two tarballs rather than by inspecting the fix. Built before and after with the same command, the sdist goes 422 to 300; exactly 122 entries are removed, grouped as 118 under `.jeffy/` plus the four state files, and nothing at all is added or lost besides. The 253 files under `src/macaron/`, the 19 under `golang/`, and pyproject.toml, README.md, LICENSE.txt and PKG-INFO all survive.

A new battery, `.jeffy/probes/packaging`, now owns this. It builds both published artifacts and grades their contents, and it grades absence on both sides - a battery that only asserts the state files are gone is satisfied by an empty tarball, so the same run asserts the sources, the Go helpers, the build configuration, the readme, the licence and the wheel's two top-level entries are still there. The dist-info name is derived rather than spelled out so a version bump does not redden it. Its paths file declares `pyproject.toml`, so any future edit to the exclude list runs it.

One instrument property was found by running the mutation rather than by reasoning about it. My first discriminating mutation deleted all five new exclude entries, and it reddened ten checks - because with `.jeffy/` back in the selection scope, flit refuses to build at all while the loop's own probe directory is untracked, printing "Untracked or deleted files in the source directory". That is the tree's state, not the exclude list's, and a battery that could not tell them apart would report a packaging defect on every mid-iteration run. The battery now tests for that message as its own check, and the recorded mutation deletes only the four root entries, leaving `.jeffy/` in place so the build still succeeds: it reddens exactly one check, whose failure detail names all four files, with the `.jeffy/` check staying green. The battery is 18/18 green and re-derives at 17/18.

A `Packaging and distribution` row is added to the Surface inventory, swept at this iteration's checkpoint via that battery. The map had no row for the artifacts a user downloads, which is a gap rather than an omission this run created, so the denominator moves from 28 to 29 rows and all 29 are swept.

Verify gate through the installed quiet-verify.sh: green (89s, 1243 passed), unchanged from iteration 6 because this iteration touched no Python source and no project test. check-claims.sh reports 63 checked, 0 mismatched, 0 errored, 0 skipped, up two rows from the new battery's claims.

Learnings: A probe that builds a distribution inherits the build tool's preconditions. flit refuses an sdist while any untracked or deleted file sits inside the selection scope, so a packaging battery must test for that refusal separately or it will report the tree's state as a packaging defect.

Next: one open Medium and six Lows remain. Iteration 8 works VSA-001, which takes the ledger to the severity floor; iteration 9 is then the closing full audit and iteration 10 the evaluator gate.

## iter 8/10 | 96157278-161759 | 2026-09-06 | VSA-001 | done

Task: VSA-001 (Medium, runtime, error handling) - `generate_vsa` never checked whether `create_vsa_statement` had returned None, so on any SQLAlchemyError `json.dumps(None)` produced the string `null` and the caller wrote `vsa.intoto.jsonl` holding a payload that decodes to null while logging that the attestation had been generated.

Changed: src/macaron/vsa/vsa.py, tests/vsa/test_vsa.py (4 new tests and a fixture), .jeffy/probes/vsa/{check.py,claims,README.md}, PLAN.md (Verify count, row re-recorded), BACKLOG.md (VSA-001 deleted, VSA-002 filed), JOURNAL.md.

Checkpoint: fbf21bdb253e49007861fa11fddbaec3edfcefb4

Verification: The filed reproduction ran first, before any edit, driven through the precondition the line names rather than the convenient one. With `global_config.output_path` pointed at a directory that cannot be opened, `create_vsa_statement` returned None and `generate_vsa` returned `{'payloadType': 'application/vnd.in-toto+json', 'payload': 'bnVsbA=='}`, whose payload decodes to None. After the fix the same call returns None and logs "Cannot generate a VSA: the VSA statement could not be constructed."

The positive path was driven too, because a guard that refuses everything would satisfy the acceptance as filed. Against a real database created with `create_tables()`, a passing component still yields a Vsa whose payload is an in-toto v1 statement with `subject` `[{'uri': 'pkg:pypi/x@1'}]` and `predicateType` `https://slsa.dev/verification_summary/v1`.

Log level is `logger.error` where the function's other failure paths use `logger.debug`. The reason is that the cause is already logged at debug inside `create_vsa_statement`, so at default verbosity a user asking for an attestation would otherwise be told nothing at all; the caller writes no file and logs no success when None comes back, so the error line is the only thing that says why.

The acceptance check is four tests: the unreadable database, the readable one, and the two results that refuse before a database is consulted. Run against the unfixed file it failed exactly 1 of 17 and exited 1 - the unreadable-database case - while the readable-database case and both refusals passed there too, so it cannot be satisfied by a function that never returns an attestation.

One property of the module bit before it was understood, and it is the reason the new tests carry a fixture. `get_db_manager` is decorated with `cache_return`, so it is memoized for the life of the process: my first version of the tests passed in isolation and failed in the suite, because the readable-database test built the manager and the unreadable one was handed that same manager back and graded the wrong database. The fixture clears the memo either side of each test, and the battery's helper does the same. This is also why the original reproduction was sound - each probe ran in a fresh process.

What the contract preserves: no signature change. Every path that previously returned None still does, and the readable-database path is unchanged, which the two positive checks pin. The Returns section of `create_vsa_statement` now documents the None it has always been able to return, since the fix depends on that being part of its contract. Its Parameters section documents three parameters the function does not take; that is a separate docs defect and is filed as VSA-002 at Low rather than fixed here, with the rationale on its line.

Battery ownership: the diff touches a path the vsa battery declares. That battery carried a comment saying the unreachable-database behaviour was VSA-001 and deliberately not pinned, and it drove only the decision paths that return before a database is needed. It now drives both sides against real databases and goes 20/20 to 24/24. Its violation-guard mutation re-derives at 23/24, and a second recorded mutation that removes the new None guard re-derives at 22/24, reddening exactly the unreadable-database pair with the base64 `bnVsbA==` visible in the failure detail while both readable-database checks stay green. My first version of those two checks reddened as errors rather than failures because the helper raised on a null payload; it was reshaped so the mutation produces two clean failures that name the defect. The `VSA generation` inventory row is re-recorded at this iteration's checkpoint.

Verify gate through the installed quiet-verify.sh: green (96s, 1247 passed), up from 1243 by the four new tests; PLAN.md's Verify count now carries that figure. check-claims.sh reports 64 checked, 0 mismatched, 0 errored, 0 skipped, up one row from the added mutation claim. mypy clean and pylint 10.00/10 on both changed files.

The ledger reaches the severity floor with this entry: zero open High and zero open Medium, seven Lows carried. No full fresh-evidence audit has been recorded this run, so convergence is not yet available and none is claimed.

Learnings: `get_db_manager` is memoized with `cache_return`, so any test or probe that points `global_config.output_path` at a new database must call `get_db_manager.clear()` first, or it grades the database an earlier call built.

Next: iteration 9 is the closing full audit, which is the fresh-evidence audit the closing rule requires and which fits before any extension window opens; iteration 10 then runs the evaluator gate and, on a PASS with the conditions holding, declares.

## iter 9/10 | 96157278-161759 | 2026-09-06 | AUDIT | audit

Task: The closing full fresh-evidence audit. The ledger reached the severity floor at iteration 8 and the map is complete at 29 of 29 rows, but no full audit was on this run's record, so the closing rule had nothing to cite. This iteration produces it, before any extension window opens, because the window cannot legally hold one.

Changed: BACKLOG.md (the Settled class line restated), JOURNAL.md.

Checkpoint: c56cff0fe228be17f67005c66ebd23e874a15d92

Verification: Fresh evidence over the whole mapped surface rather than a re-reading. check-claims.sh executed every battery and every recorded mutation - 64 claims across all 29 rows - and reports 0 mismatched, 0 errored, 0 skipped. An import sweep walked all 208 modules under src/macaron with 0 failures. The Verify command is green through the wrapper at 1247 passed in 105s.

The Environment fingerprint was re-derived rather than re-read. Its recorded exclusion command still returns the two addopts ignores and nothing else - no skip marker, platform guard or Go build constraint excludes anything on this host - and the toolchain still matches the line: Python 3.14.4, pytest 9.1.1, go 1.26.2, semgrep 1.171.0, WSL2 6.18.33.1. The Oracle class still describes what the command grades, including its one verified network-reaching site, which TEST-001 re-drives below.

The Settled class enumeration was re-run and found stale in its stated shape, which is the substantive thing this audit caught. The recorded command now returns three lines where the line said two: the two `rstrip("\n")` calls, plus a prose line inside the `_clean_spdx` docstring that PROV-002's own fix added to explain why `removeprefix` replaced `lstrip`. The class itself is still closed - a call-site-only enumeration returns exactly the two correct newline strips - so the line is restated to describe what its command returns today rather than the class being reopened. Declined is empty, so there are no Derivations to re-run.

All seven carried Lows were re-driven through the precondition each line names, and all seven still reproduce: REG-001 through its own acceptance command, which prints all three class names and whose downgrade premise still holds since `grep -rn 'enabled='` finds no shipped construction site; GHA-001 returns the string `'None'` for an absent key; GIT-002 maps `v1.0` to the annotated tag object SHA `aaaa1111`; GIT-003 splits 2 to 4 across six PYTHONHASHSEED values; CDX-002's guard is still present and `Bom().components is None` is still False; VSA-002's signature is `(passed_components, policy_content)` against a docstring naming `subject_purl` and `verification_result`; TEST-001's doctest module still exits 1 under an unroutable proxy with `GenerateBuildSpecError`.

This run's own changes were probed for what the batteries do not cover. The pomparser fix resolves a path taken from an analyzed repository, which the Operating envelope classifies adversarial, and widening which forms resolve could widen an escape. Driven with seven traversal shapes - the file form pointing outside the repository, the directory form, an absolute `/etc/passwd`, a six-level climb, and a path that re-enters through a file component - `detect_parent_pom` returns None for every one, because the `relative_to(repo_root)` containment check still bounds it. Nothing this run changed moved that boundary.

Audit scores, over all 29 swept rows with no row left unswept:
- security: None. The adversarial-input probe above, plus the provenance, malware-analyzer, gha-security and go-helpers batteries green on their recorded mutations.
- correctness: None above Low. Carried: GIT-002, GIT-003, CDX-002, GHA-001, REG-001.
- error handling: None. VSA-001 closed this iteration-8.
- dependency hygiene: None. PKG-001 closed at iteration 7, and the new packaging battery now grades both published artifacts on every change to pyproject.toml.
- documentation: Low - VSA-002.
- testing: Low - TEST-001. The suite is green at 1247 and the fingerprint's command finds no exclusion beyond the two recorded addopts ignores.
- code quality: Low - CDX-002 and GIT-002, both dead branches with no user-visible consequence.
- architecture, performance, observability: None on the swept surface.
- UX and accessibility: None. The CLI battery drives the real binary as a subprocess in a scratch cwd with the token environment stripped.

Zero High and zero Medium in-envelope. Closeout has begun: no further audit and no replenishment for the rest of this run.

No stall despite this iteration changing only state files: an AUDIT entry is a ceremony entry and is exempt, and the previous entry is a task closure rather than the same claim.

Learnings: A Settled class line can go stale because the fix that closed the class documented itself in prose the enumerating grep also matches. Re-running the command is what catches it; reading the line does not.

Next: iteration 10 runs the evaluator gate over this audit and, on a PASS with the closing conditions holding, declares in that same iteration.

## iter 1/10 | 0d91d08c-193302 | 2026-09-06 | REG-001 | done

Task: REG-001 (Low, runtime, correctness) - `JFrogMavenRegistry`, `NPMRegistry` and `PyPIRegistry` each assigned `self.enabled` from their documented constructor parameter and then called `super().__init__`, which unconditionally set `self.enabled = True` and discarded it.

Changed: src/macaron/slsa_analyzer/package_registry/{package_registry,jfrog_maven_registry,npm_registry,pypi_registry}.py, tests/slsa_analyzer/package_registry/test_package_registry.py (new, 9 tests), .jeffy/probes/package-registries/{check.py,claims,README.md}, PLAN.md (Verify count, Lessons), BACKLOG.md (REG-001 deleted, PYPI-001 filed, Later reordered, Settled class recorded), JOURNAL.md.

Checkpoint: d0bee7f8b457295c3acc1c97adf836c2d6f1aac1

Verification: The filed reproduction ran first, before any edit, and printed all three class names as the line said it would.

The line's severity is right and its rationale is wrong, which is the substantive thing this iteration found. It argued the defect was inert because "no shipped code path constructs a registry with that keyword - the runtime path sets `enabled` from the ini in `load_defaults`, after construction". That second clause does not hold for JFrog. The shipped `defaults.ini` carries `[package_registry.jfrog.maven]` commented out, and `JFrogMavenRegistry.load_defaults` returns before its `self.enabled = True` when the section is absent, so the value the constructor left is the value that survives. Driven through the real path - `load_defaults("")`, then `load_defaults()` on each member of `PACKAGE_REGISTRIES`, as `__main__` does - the JFrog registry came out enabled with an empty hostname and repo, and `construct_folder_info_url` built `https:///api/storage//org/example`.

What a user of the shipped product met was therefore not nothing. Analyzing any maven or gradle PURL reached `find_gav_provenance`, whose `if not registry.enabled` guard exists to skip an unconfigured registry; the guard did not fire, and the call fell through to a request that failed inside `fetch_assets` with `Invalid URL 'https:///api/storage//org/example/lib/1.0.0': No host supplied`, logged at debug. The analysis result was unchanged - an empty provenance list either way - so the consequence is a debug line that misattributes the cause plus a pointless request attempt, which is polish rather than a wrong answer. Low stands under the rubric; only the reason it is Low changes, and this entry is where that correction is recorded rather than in the deleted line.

The fix is structural rather than three reorderings. `PackageRegistry.__init__` now takes `enabled: bool = True` and each subclass passes its own value through `super().__init__`, so the base class no longer overwrites a subclass decision and a future subclass cannot inherit the defect. The class enumeration is every `PackageRegistry` subclass, and all four are covered: the three that take the parameter honour it at both values, and `MavenCentralRegistry`, which takes no such parameter, keeps the base default. That enumeration is recorded as a command on the new Settled classes line.

What the contract preserves: no signature is narrowed and no caller changes. A configured JFrog still ends enabled - driven with a user config naming a hostname and repo, `load_defaults` reaches its `self.enabled = True` exactly as before. `NPMRegistry` and `PyPIRegistry` still default to enabled and still take their value from the ini where their `load_defaults` sets it. The single behaviour change is that an unconfigured JFrog registry is now disabled, which is what its own constructor always spelled (`enabled or False`) and what its caller's guard was written for; the rationale is recorded here per the Constraints.

The acceptance check was run against the unfixed code before being trusted. Restored from HEAD by copy, with the fixed files held aside rather than checked out, the new test module failed 4 of 9 and exited 1. The 5 that passed there matter as much as the 4 that failed: they are the enabled=True cases, the Maven Central default and the configured-JFrog case, so a fix that simply forced every registry off would not satisfy this check. Against the fix the module is 9 of 9, and the package registry and provenance test trees together are 143 passed.

Battery ownership: the diff touches paths the package-registries battery declares. That battery had deliberately pinned the broken behaviour under a heading naming REG-001, so it reddened on the fix exactly as the standing Lesson predicts - two checks, one asserting a registry starts enabled and one asserting each registry claims its own ecosystem, the latter because its JFrog fixture was constructed without the parameter and is now disabled. Both were updated in this iteration: the fixture is constructed enabled, and the single pinned-broken check is replaced by five that pin the documented contract, including the shipped-defaults case that made this reachable. The battery goes 46/46 to 50/50, and a second recorded mutation now reverts the fix in the base class and re-derives at 47/50. Its FAIL lines were read rather than predicted, and it reddens the three checks that pin the parameter, each as a clean FAIL rather than an error. The first mutation re-derives at 47/50 and still reddens the same three `same_organization` checks the README names.

Verify gate through the installed quiet-verify.sh: green (102s, 1256 passed), up from 1247 by the nine new tests; PLAN.md's Verify count now carries that figure. check-claims.sh reports 65 checked, 0 mismatched, 0 errored, 0 skipped, up one from the added mutation claim. mypy clean on all five changed files.

pylint rates the changed files 9.99/10 on one message, W4903, for `shutil.rmtree(directory, onerror=...)` in pypi_registry.py. It is not from this diff: the same message reproduces on the file as it stands at HEAD. `onerror` still works on this host's 3.14.4 and emits no runtime warning there, so it is linter output rather than anything a user meets, and it is filed as PYPI-001 at Low rather than fixed inside this task.

Learnings: `_mutate.sh` prints only the battery's stdout while the FAIL detail lines go to stderr, so reading which checks a mutation reddens means applying the sed by hand over a backup copy. `check-claims.sh` applies source mutations in place while it runs, so the verify gate must never be started beside it or the suite grades a mutated tree.

Next: six Lows remain and the ledger holds no High or Medium. Iterations 2 to 6 work the runtime Lows in order - GHA-001, GIT-002, CDX-002, GIT-003, PYPI-001 - then TEST-001 and VSA-002, leaving the closing full audit and the evaluator gate for the last two iterations.

## iter 2/10 | 0d91d08c-193302 | 2026-09-06 | GHA-001 | done

Task: GHA-001 (Low, runtime, correctness) - `get_step_input` in `src/macaron/parsers/actionparser.py` returned `str(with_section.get(key))`, so a key the step's `with` section does not carry yielded the string "None" rather than None, contradicting its own docstring promise of "the input value or None if it doesn't exist".

Changed: src/macaron/parsers/actionparser.py, tests/parsers/actionparser/test_actionparser.py (7 parametrized cases), .jeffy/probes/parsers/{check.py,claims,README.md}, PLAN.md (Verify count), BACKLOG.md (GHA-001 deleted, Settled class recorded, Proposed item re-evidenced), JOURNAL.md.

Checkpoint: 7d1ec9ef52810aa2631c1b289feb312ddc62dfd9

Verification: The filed reproduction ran first, before any edit, and returned the string 'None' for an absent key exactly as the line said.

The line's downgrade rationale was re-derived rather than re-read, and it holds: `grep -rn get_step_input` across src, tests and docs still returns only the definition itself, so no shipped code path reaches the function and a user of the shipped product meets nothing. Low stands.

This was filed as an instance, and the class rule applies, so the idiom was enumerated before anything was fixed: `grep -rnE 'str\([A-Za-z_][A-Za-z0-9_.]*\.get\(' src/macaron --include='*.py'` returned six lines at HEAD. Each was resolved on evidence rather than by reading. Three in `detect_injection.py` are guarded by `or "unknown"`, so a miss becomes that word and never the string "None". The one in `cyclonedx.py` reads `purl` from a `DependencyInfo`, which is a total TypedDict whose single construction site always sets the key, a point the surrounding comment already makes by citing PEP-589. The one in `check_result.py` looks up `BUILD_REQ_DESC`, and that map carries a description for every one of the 30 `ReqName` members while `Registry._validate_eval_reqs` refuses to register a check whose `eval_reqs` are not `ReqName`, so the lookup cannot miss either. One live site, now fixed, and the class is recorded as settled with that command; the fixed site no longer matches the pattern, so the enumeration returns five lines across three files today rather than six, and the Settled line states that shape.

The fix returns None before stringifying rather than after. What the contract preserves: the signature and return type are unchanged, a present input still comes back stringified, a step with no `with` section and a `with` section that is an expression string rather than a mapping both still return None. The one behaviour that changes is the absent key, which is what the docstring already promised.

The falsy cases are the reason this is not a truthiness check. A workflow that really sets `fetch-depth: 0` or `submodules: false` has an input value, and `str(0)` and `str(False)` must still come back; a fix written as `if not value` would drop both while satisfying the acceptance as filed. Both are pinned in the tests and in the battery.

The acceptance was run against the unfixed source before being trusted, with the fixed file held aside and restored by copy rather than checked out. The new parametrized test failed 2 of 7 there and exited 1 - the absent key and the key whose value the workflow left empty - while the two falsy cases and the three structural cases passed on both sides, which is what makes the check discriminating in both directions. Against the fix the module is 12 passed, mypy clean, pylint 10.00/10.

Battery ownership: the diff touches a path the parsers battery declares. That battery was green on the fix, because it had pinned only the no-with-section case and never the absent key, so nothing it asserted became false. It was extended anyway, since the row certifies this function: three checks now pin the absent key, the empty value and the falsy pair, and the battery goes 79/79 to 82/82. Both recorded pomparser mutations were re-measured against the new denominator and still redden the same eight and three checks the README names, at 74/82 and 79/82. A third mutation now disables the fix's own guard and re-derives at 80/82; its FAIL lines were read rather than predicted and it reddens exactly the two checks that pin the fix, both showing the string 'None' the defect produced, with the falsy check staying green under it.

Verify gate through the installed quiet-verify.sh: green (122s, 1263 passed), up from 1256 by the seven new cases; PLAN.md's Verify count now carries that figure.

That figure cost a second full run of the suite, and the reason is a rule this project has already written down twice. The first invocation was piped through sed to shorten the oracle sentence, which discarded the pass count that rides the same line - the Lesson marked [recurred] in PLAN.md says exactly this and it was broken anyway. Nothing was quoted from the mangled line; the gate was re-run unpiped and 1263 is that run's own figure. The Proposed item asking for this Lesson to become a mechanism now records three re-runs rather than two, which is the evidence for the decision rather than a new argument.

Learnings: no new operational rule. The one this iteration broke is already in PLAN.md and already marked recurred; what it needs is the mechanism the Proposed item asks for, not a third sentence.

Next: five Lows remain, no High or Medium open. Iterations 3 to 6 work GIT-002, CDX-002, GIT-003 and PYPI-001; TEST-001 is priced against the one-iteration rule when reached, and VSA-002 is a docstring correction. The closing full audit is planned for iteration 8 and the evaluator gate and declaration for iteration 9, leaving iteration 10 as slack.

## iter 3/10 | 0d91d08c-193302 | 2026-09-06 | GIT-002 | done

Task: GIT-002 (Low, runtime, correctness) - the duplicate guard in `parse_git_tags` tested `possible_tag in tags` before the `refs/tags/` prefix was stripped, while the keys already stored were stripped, so the guard compared `refs/tags/v1.0` against a key of `v1.0` and never fired.

Changed: src/macaron/slsa_analyzer/git_url.py, tests/slsa_analyzer/test_git_url.py (7 parametrized cases), .jeffy/probes/slsa-core/{check.py,claims,README.md}, PLAN.md (Verify count), BACKLOG.md (GIT-002 deleted), JOURNAL.md.

Checkpoint: 59c11c5abc4b2ca543d8ec63cd93e1c927b18082

Verification: The filed reproduction ran first, before any edit, and returned `{'v1.0': 'aaaa1111'}` where the line said it would - the annotated tag object rather than the source commit.

The severity premise was re-derived against real git rather than re-read. A scratch repository was built carrying two annotated tags and one lightweight tag, and both producers the line names were run against it: `git show-ref --tags -d` and `git ls-remote --tags` each emit refname order, with `refs/tags/v1.0^{}` immediately following `refs/tags/v1.0`. So the guard's branch is genuinely unreachable from producer output, the wrong mapping needs hand-authored input, and the Operating envelope's evidence bar does not credit it. Low stands.

The fix strips the prefix once, at the point the name is taken, so the guard compares like with like. What the contract preserves was measured rather than argued. The old and new implementations were run side by side over every ordering of every subset up to size four of a nine-reference corpus - 3609 orderings covering annotated pairs, a lightweight tag, a reference outside refs/tags, a bare prefix, and a tag with a slash in its name. 804 orderings differ, and every one of them is the case where a peeled reference precedes its own base reference. Nothing else moved: no ordering that git itself can produce changes its answer, which is the same thing the standard-order check pins from the other direction.

The acceptance was run against the unfixed source before being trusted, the fixed file held aside and restored by copy rather than checked out. The new parametrized test failed 1 of 7 there - the out-of-order case - while the other six passed on both sides, so the check is specific to the defect rather than to the module being touched. Against the fix the module is 52 passed, mypy clean, pylint 10.00/10.

GIT-002 was filed as an instance, so the idiom was enumerated before it was called a one-site fix: an AST scan over src/macaron for a membership test against a dict the same function assigns into by subscript returns three sites, and only `parse_git_tags` normalized the tested name at all. Made order-aware - a normalizing rebind whose line follows the membership test - the scan returns zero sites today. The other two are in `bash.py`: one tests and stores the same unmodified key, and one tests `index` while `arg_index` is assigned in a different loop of the same function. There is no repeatable idiom here to settle, so no Settled class line is written; a standing claim over a class of one would be re-run at every future declaration for nothing.

Battery ownership: the diff touches a path the slsa-core battery declares, and that battery pinned only the producer order, never the out-of-order pair, so it stayed green on the fix and nothing it asserted became false. Two checks were added anyway, since the row certifies this function: the out-of-order pair and a reference outside refs/tags keeping its full name. The battery goes 46/46 to 48/48, and both recorded mutations were re-measured against the new denominator at 47/48 and 44/48, still reddening the one and four checks the README names.

A third mutation now restores GIT-002 itself. The first shape tried deleted the strip outright and reddened four checks, which is not a discriminator for this fix - it breaks prefix handling everywhere - so it was rejected and the recorded mutation instead makes the guard compare the unstripped name, which is exactly what the code did before. It re-derives at 47/48 and reddens exactly one check, with `aaaa1111` visible in the failure detail, while the producer-order check stays green under it. That pairing is the whole finding in one line: every input git produces takes the path that still works.

Verify gate through the installed quiet-verify.sh: green (101s, 1270 passed), up from 1263 by the seven new cases; PLAN.md's Verify count now carries that figure. All four slsa-core claims were re-derived by executing them, and each matches.

Learnings: no new operational rule. The rule that a mutation must be read rather than predicted is already in PLAN.md, and it is what caught the four-check mutation before it was recorded as a discriminator.

Next: four Lows remain, no High or Medium open. Iteration 4 works CDX-002, iteration 5 GIT-003, iteration 6 PYPI-001, iteration 7 VSA-002, with TEST-001 priced against the one-iteration rule when reached; the closing full audit is planned for iteration 8 and the evaluator gate and declaration for iteration 9.

## iter 4/10 | 0d91d08c-193302 | 2026-09-06 | CDX-002 | done

Task: CDX-002 (Low, runtime, correctness) - `get_dep_components` guarded its missing-components early return with `if root_bom.components is None`, which the CycloneDX library never leaves None, so the branch was unreachable and its debug line never printed.

Changed: src/macaron/dependency_analyzer/cyclonedx.py, tests/dependency_analyzer/cyclonedx/test_cyclonedx.py, tests/dependency_analyzer/cyclonedx/resources/bom_no_components.json (new), .jeffy/probes/dependency-analyzer/{check.py,claims,README.md}, PLAN.md (Verify count, Verify duration, Lessons), BACKLOG.md (CDX-002 deleted), JOURNAL.md.

Checkpoint: cf3a797469d98aeead9d9674880af5d30d5ee2ed

Verification: The premise ran first and was driven through the input the guard was written for rather than the convenient one. A fresh `Bom()` normalizes `components` to an empty `SortedSet`, but that alone proves little, so a BOM document carrying dependencies and a metadata component and no `components` array at all was written and deserialized through the project's own `deserialize_bom_json` under schema 1.6: `components` comes back a `SortedSet` of length zero, never None. The guard cannot fire on any document the deserializer produces, so the fix is a deletion and the acceptance grep now returns 0.

Deleting unreachable code changes no behaviour by construction, which makes the acceptance harder rather than easier: a test that only pins the returned value proves nothing here. A document with no components yields nothing whether the function returns early or falls through, because the final loop iterates the same empty set either way. The first version of the test asserted exactly that and would have passed against the defect, against the fix, and against the wrong fix the ledger line warned about - making the guard live, which would return early on a BOM whose target lives only in metadata.

What tells the two apart is whether the metadata lookup runs at all, so the test captures the module's debug log and asserts the target component was found there. Reinstating the guard as `if not root_bom.components` makes that test fail, with the early-return line visible in the failure output, so the check is a real discriminator against the specific wrong fix rather than a restatement of the return value.

The same mistake was made once more in the battery and caught the same way. Three checks were added to the dependency-analyzer battery for the no-components document, and a mutation reinstating the live guard reddened none of them, because all three read returned values. That is the shape of an instrument that cannot fail, so a fourth check was added that runs `get_dep_components` with the module logger captured and asks whether the document was walked; the mutation now reddens exactly that check. The battery goes 43/43 to 47/47, both existing mutations were re-measured against the new denominator at 45/47 each, and the new one re-derives at 46/47. Every claim was executed and matches.

Verify gate through the installed quiet-verify.sh: the first invocation returned TIMEOUT after 240s and exit 124. It was not treated as this iteration breaking the project, and it was not re-run blindly either. The suite had reached 100% with every test passing before the bound fired, which does not fit a defect this diff could cause, so the host was checked: load average 11.45 across 14 cores, with a different checkout at /home/lenam/jeffy-prs/macaron-fresh running its own pytest under pre-commit alongside semgrep and an npm build. That work is not this run's and was left alone. Re-run with the bound raised for that invocation, the gate is green (128s, 1271 passed), up one from 1270 by the new test.

The recorded `Verify duration` was stale and is updated in this iteration, because the bound is derived from it and a bound that is too tight costs the declaration rather than an iteration. The line said 75s; every measurement this run has been higher - 78s, 101s, 102s, 122s and now 128s - and the suite has grown by 24 tests since. It now records 128s, which is a real timed run rather than an average, and the derived bound moves from 240s to 384s.

Learnings: the verify bound comes from the recorded `Verify duration`, so unrelated load on the host can push the suite past it and the timeout reads exactly like a broken iteration; check `uptime` and `ps` before treating one as a defect. Recorded in PLAN.md.

Next: three Lows remain plus TEST-001. Iteration 5 works GIT-003, iteration 6 PYPI-001, iteration 7 VSA-002 with TEST-001 priced against the one-iteration rule; the closing full audit is planned for iteration 8 and the evaluator gate and declaration for iteration 9.

## iter 5/10 | 0d91d08c-193302 | 2026-09-06 | GIT-003 | done

Task: GIT-003 (Low, runtime, correctness) - `find_highest_git_tag` advanced only on a strict greater-than, so when several tags parsed to one version the answer was whichever the set yielded first, and set iteration order over strings varies with the interpreter's hash seed.

Changed: src/macaron/slsa_analyzer/git_url.py, tests/slsa_analyzer/test_git_url.py (4 parametrized cases), .jeffy/probes/slsa-core/{check.py,claims,README.md}, PLAN.md (Verify count), BACKLOG.md (GIT-003 deleted), JOURNAL.md.

Checkpoint: a50ee14ec508ec81fb107747abb8fc4bb2c4bc8f

Verification: The filed reproduction ran first, before any edit. Across `PYTHONHASHSEED` 0 to 7, `find_highest_git_tag({"1.0", "1.0.0"})` returned `1.0` on four seeds and `1.0.0` on the other four. The ledger line recorded a three to five split over eight seeds; the finding reproduces but its split does not match, which is what a hash-seed-dependent figure does and is why the line's own acceptance was written as "the same answer under at least eight seeds" rather than as a ratio. Nothing rests on the ratio, so it is recorded here rather than corrected in a line being deleted.

The fix sorts the tag set before iterating rather than adding a tie-break branch, so the function is deterministic for every input and not only for ties. The docstring now states which alias wins, since that is part of the contract a caller can rely on, and a doctest pins it.

What the change preserves was measured. The old and new implementations were run over every subset up to size four of an eleven-tag pool - 561 subsets covering aliases, zero spellings, an invalid tag, and versions where a lexical sort would disagree with a numeric one. Eleven subsets return a different tag, and every one of them is a set where more than one tag parses to the maximum version; zero differ for any other reason. In every subset where both return a tag, the two tags parse to the same version, which is the ledger line's own severity premise - the aliases name one version, so neither answer was wrong and what a user met was an unstable string rather than an incorrect one. Low stands.

The acceptance was run against the unfixed source with the fixed file held aside and restored by copy. The defect is itself seed-dependent, so the check was run under all eight seeds rather than once: unfixed, the new test module fails on every seed, with between one and three of its four cases failing depending on the seed. Fixed, all four pass on all eight. That the failure count moves with the seed while the pass count does not is the finding stated as a measurement.

Battery ownership: the diff touches a path the slsa-core battery declares. Three checks were added and the battery goes 48/48 to 51/51. Two of the three spawn fresh interpreters under eight hash seeds and count distinct answers, because set iteration order is fixed for the life of a process and cannot be measured from inside one; the third reads the same sets in-process and is honest but lucky, which the README says plainly rather than leaving it to look like three independent checks. A fourth mutation now reverts the sort and re-derives at 48/51, reddening exactly those three, with the cross-seed check reporting two distinct answers where one is required. The three existing mutations were re-measured against the new denominator at 50/51, 46/51 and 50/51, and every claim was executed and matches.

Verify gate through the installed quiet-verify.sh: green (83s, 1275 passed), up four from 1271. The new doctest example joins a docstring that already had examples, so it adds no collected item, which is why the count moved by the four unit cases alone. mypy clean and pylint 10.00/10 on both changed files. Host load was checked before the gate after the previous iteration's timeout: 0.96, and the run took 83s.

Learnings: no new operational rule.

Next: three Lows remain - PYPI-001, TEST-001, VSA-002. Iteration 6 works PYPI-001 and iteration 7 VSA-002, with TEST-001 priced against the one-iteration rule when reached; the closing full audit is planned for iteration 8 and the evaluator gate and declaration for iteration 9.

## iter 6/10 | 0d91d08c-193302 | 2026-09-06 | PYPI-001 | done

Task: PYPI-001 (Low, runtime, code quality) - `cleanup_sourcecode_directory` in pypi_registry.py passed `onerror=` to `shutil.rmtree`, a parameter deprecated in favour of `onexc` since Python 3.12, so pylint reported W4903 on the file.

Changed: src/macaron/slsa_analyzer/package_registry/pypi_registry.py, tests/slsa_analyzer/package_registry/test_pypi_registry.py (2 tests), PLAN.md (Verify count, Lessons), BACKLOG.md (PYPI-001 deleted), JOURNAL.md.

Checkpoint: 76e44d05b347f55538c02b42e34900931ce1c8cd

Verification: The fix the ledger line implied would have broken the project, and finding that out was the substantive work of this iteration. Swapping `onerror=` for `onexc=` is the documented migration, but `onexc` arrived in Python 3.12 while this project declares `requires-python = ">=3.11.14"` and carries a `Programming Language :: Python :: 3.11` classifier. That was settled by measurement rather than recall: on the `python3.11` interpreter present on this host, `inspect.signature(shutil.rmtree)` lists `path, ignore_errors, onerror, dir_fd` and the call raises `TypeError: rmtree() got an unexpected keyword argument 'onexc'`, while the venv's 3.14 lists `onexc` as well. A straight substitution would have traded a linter message for a crash on the project's own minimum interpreter.

So the callback is removed rather than migrated. `_handle_temp_dir_clean` existed only to turn a removal failure into `SourceCodeError` for the caller to catch, and `shutil.rmtree` raises `OSError` at that same point with no callback at all, so the function now catches `OSError` directly. The handler and the now-unused `Callable` import are deleted; `SourceCodeError` stays, since the module raises it in five other places. This works on every version the project supports and removes the deprecated parameter instead of exchanging it, which the Constraints prefer over adding a version branch.

What the contract preserves: `cleanup_sourcecode_directory` still raises `InvalidHTTPResponseError` on a removal failure and still returns silently on success, and the eleven call sites are untouched. Only the `__cause__` changes, from `SourceCodeError` to the `OSError` that actually occurred, which is strictly more informative and which no caller or test reads.

The acceptance as filed is met: `grep -c 'onerror='` on the file returns 0, pylint rates it 10.00/10 with W4903 gone, and mypy is clean. Its third clause asked for a test driving a real removal failure, and both new tests provoke one for real rather than by mocking - write permission is taken off the directory so the unlink inside `rmtree` raises - with a skip guard for root, which would bypass the permission and make the test vacuous.

Those two tests pass against the unfixed code as well, and that is the point rather than a weakness: this fix is a deprecation removal that must not change behaviour, so a test that failed before and passed after would mean the refactor had moved something. Passing on both sides is the differential evidence that it did not. The discriminator for the fix itself is the pair the acceptance names, the grep and the pylint message, and both flipped. The new code shape was also run under 3.11 directly: the failure path raises `PermissionError`, an `OSError`, and a removable directory is removed.

One correction to the record: the ledger line named `_clean_up_temp_dir` as the function holding the call. There is no such function - `_handle_temp_dir_clean` is the handler and `cleanup_sourcecode_directory` is the caller. I filed that line in iteration 1 and conflated the two names; the finding itself was accurate and reproduced exactly as described.

Battery ownership: the diff touches a path the package-registries battery declares. It is green at 50/50 and pins nothing about this function, so no battery claim changed and none was invented to look thorough.

Verify gate through the installed quiet-verify.sh: green (97s, 1277 passed), up two from 1275 by the new tests. Host load checked before the gate: 0.61.

Learnings: the project's floor is `requires-python >=3.11.14` and it classifies 3.11, so a stdlib parameter added after that floor cannot simply be swapped in; there is a `python3.11` on this host, so check the floor rather than the venv's 3.14. Recorded in PLAN.md.

Next: two Lows remain. Iteration 7 works VSA-002, a docstring correction, and prices TEST-001 against the one-iteration rule; the closing full audit is planned for iteration 8 and the evaluator gate and declaration for iteration 9.

## iter 7/10 | 0d91d08c-193302 | 2026-09-06 | TEST-001 | done

Task: TEST-001 (Low, test, testing) - the doctests of `pick_specific_version` reached `get_latest_cpython_patch`, which fetches https://www.python.org/ftp/python/ live, so the unit suite the Verify command runs failed without network access.

Changed: src/macaron/build_spec_generator/dockerfile/pypi_dockerfile_output.py (docstring), tests/build_spec_generator/dockerfile/test_pypi_dockerfile_output.py (8 new cases, one existing test pinned), PLAN.md (Oracle class, Verify count), BACKLOG.md (TEST-001 deleted, TEST-002 filed), JOURNAL.md.

Checkpoint: 4d2ca729f5c437c30d75ec1f6d8e5d766de1242a

Verification: The filed reproduction ran first and exited 1 with `GenerateBuildSpecError('Failed to fetch index of CPython versions.')` under an unroutable proxy, exactly as the line said.

TEST-001 is a non-runtime Low, so the pricing rule applies before any work: it is declined by policy only if the fix plus its regression test cannot fit one iteration. It fits, so it was fixed rather than priced away. The four network-reaching doctest examples move into unit tests that supply the patch lookup themselves, and the one example that answers without touching the network - unsatisfiable constraints returning None - stays in the docstring.

The replacement is a stronger check than what it replaced, which is the reason this is not a like-for-like move. The old examples asserted `'3.8.20'`, a value fetched from python.org at the moment the doctest ran, so they graded the network's answer rather than the function's logic. The new tests record which `(major, minor)` the function asks the lookup for and assert that, across seven constraint sets whose answers differ - the 3.8 floor holding for constraints that admit older versions, and 3.9, 3.10 and 3.11 selected where the constraints require them - plus one case asserting the unsatisfiable path never calls the lookup at all.

The acceptance as filed now passes: the module exits 0 under the same unroutable proxy that produced exit 1 before.

That run surfaced a second site in the same directory, and it is fixed inside this task rather than filed. `test_maturin_binary_package_generation` called `gen_dockerfile` without patching the lookup, unlike its sibling one function above it, so it reached python.org too. Its snapshot pins `Python-3.9.25`, and it was matching that only because 3.9.25 is what python.org currently serves - the test would have broken on the day CPython published 3.9.26. The fix is the one-line monkeypatch the sibling already used. This is one defect in two adjacent tests rather than a second task: TEST-001's own finding is stated about the suite being unrunnable offline, and closing it while knowingly leaving that sentence false at the test next door would be bookkeeping rather than work. Both now pass under the proxy, 13 tests in that directory.

The suite as a whole is still not hermetic, and this iteration made that claim checkable instead of leaving it approximate. The Oracle class previously said no complete enumeration was claimed because a whole-suite proxy run "did not finish inside 500s". Re-run now at 420s, it still does not finish, but it stalls at a named test: `test_pypi_sourcecode_analyzer.py::test_unknown_ruleset_exclusions`, around 31 percent. Driven alone, that test passes in about 3s with network and does not complete within 60s under the proxy - a clean differential in both directions. It is filed as TEST-002 at Low with that measurement, and the cause is left as suspected rather than asserted: the analyzer shells out to `semgrep`, which is the likely reason, but what was observed is a hang, not a phone-home. The Oracle class now records exactly this - the python.org site closed, the remaining site located, and the enumeration still incomplete.

Battery ownership: the diff touches a path the bsg-emission battery declares. It is green at 52/52; it pins the emission surface rather than this docstring, so nothing it asserted changed and no claim was rewritten to look busy. mypy clean and pylint 10.00/10 on both changed files.

Verify gate through the installed quiet-verify.sh: green (76s, 1285 passed), up eight from 1277 by the eight new cases. Host load before the gate: 0.76.

Learnings: no new operational rule.

Next: two Lows remain, TEST-002 and VSA-002, both carried unless budget allows. The ledger is at the severity floor with the map complete, so iteration 8 is the closing full audit and iteration 9 the evaluator gate and, on a PASS with the conditions holding, the declaration.

## iter 7/10 | 0d91d08c-193302 | 2026-09-06 | ROTATION | rotation

Task: JOURNAL.md passed 500 lines after this iteration's entry, so all but the last 10 entries move to the end of JOURNAL-archive.md.

Changed: JOURNAL.md, JOURNAL-archive.md.

Checkpoint: bf9e6504ecf12061292b6233ca7d720a1cbe1f8f

Verification: 22 entries were split on lines beginning `## iter` followed by a digit, so the heading grammar example in the preamble was neither counted nor moved; the preamble stays in place. 12 entries moved and 10 remain, and the archive grew from 12 entries to 24 by appending rather than overwriting, which the stop hook checks. Entry totals before and after are both 34, so nothing was lost in the move. JOURNAL.md is 306 lines.

Learnings: no new operational rule.

Next: unchanged by this entry - iteration 8 is the closing full audit.

## iter 8/10 | 0d91d08c-193302 | 2026-09-06 | AUDIT | audit

Task: The closing full fresh-evidence audit. The ledger has been at the severity floor since iteration 1 and the map is complete at 29 of 29 rows, but no full audit was on this run's record, so the closing rule had nothing to cite. This iteration produces it, before any extension window opens.

Changed: PLAN.md (Environment fingerprint corrected), JOURNAL.md.

Checkpoint: d65c27a6055e0f705139eaf9837666eb4320a059

Verification: Fresh evidence rather than a re-reading, and it caught one thing this run had broken in its own state files.

The Environment fingerprint was re-derived by running its recorded command rather than re-read. It no longer returns what the line said. The line claimed "the second grep returns nothing, so no skip marker, platform guard or Go build constraint excludes anything else on this host"; the grep now returns one line, and it is this run's own - the `skipif` PYPI-001 added at iteration 6, guarded on `os.geteuid() == 0` because root would bypass the directory permission that test provokes a failure with. Iteration 6 should have re-executed the claim its fix invalidated and did not. The fingerprint now records the marker, that this host runs as uid 1000 so it excludes nothing here and the test executes, and that a root host would skip it. The addopts exclusions are unchanged and the 113-case integration figure still holds, re-derived by counting `test.yaml` under tests/integration.

check-claims.sh executed every battery and every recorded mutation - 69 claims across all 29 rows, up from 65 at the run's start by the four mutations this run added - and reports 0 mismatched, 0 errored, 0 skipped. An import sweep walked all 213 modules under src/macaron with 0 failures. The Verify command is green through the wrapper at 1285 passed in 78s, which is the figure PLAN.md's Verify count carries.

The Oracle class was re-read and its two claims re-executed, because iteration 7 rewrote it. The site it says no longer reaches python.org exits 0 under an unroutable proxy, and the site it says still hangs exits 124 under the same proxy within 60s. Both hold. Declined is empty, so there are no Derivations to re-run.

All three Settled class enumerations were re-run and each returns exactly the shape its line states: the `str()` over `dict.get()` class returns five lines across three files, the `PackageRegistry` enabled class returns its four triples with JFrog defaulting to disabled, and the prefix-strip class returns three lines, two real calls and one docstring sentence. No class reopens.

Both carried Lows were re-driven through the precondition each line names and both still reproduce: TEST-002 exits 124 under the proxy inside 60s, and `create_vsa_statement` still documents `subject_purl` and `verification_result`, neither of which its signature `(passed_components, policy_content)` takes.

Every task this run closed had its acceptance re-run at HEAD and all seven hold: REG-001 prints an empty list, GHA-001 returns None for an absent key, GIT-002 maps the out-of-order pair to the peeled commit, CDX-002's grep returns 0, GIT-003 answers one distinct value across eight hash seeds, PYPI-001's grep returns 0 with no W4903 from pylint, and TEST-001's module and test directory exit 0 under the proxy.

This run's own changes were probed for what the batteries do not cover, aimed at the surfaces the Operating envelope classifies adversarial. `parse_git_tags` and `find_highest_git_tag` read data originating in an analyzed repository, and `get_step_input` reads a workflow step from one. Driven with tag names embedding the `refs/tags/` prefix, a peeled marker inside a name, a 5000-character name, unicode with a zero-width space, a missing SHA column, CRLF endings, a 50-alias set, an all-invalid set, epoch and local version segments, and step shapes whose `with` is a list or whose values are containers, every case returned without raising and none produced a wrong mapping.

One observation from that probe, considered and deliberately not filed. Tag data separated by several spaces rather than one - `a6   refs/tags/v1` - yields the key `"  v1"` with the leading spaces retained, because the split takes only the first separator. It is not filed because no producer emits it: `git ls-remote --tags` separates with a tab and `git show-ref --tags -d` with a single space, both verified against a real repository at iteration 3, and the envelope's binding rule makes a finding reachable only from out-of-envelope input Low at most. It is recorded here rather than in the ledger so the evaluator can disagree with the reasoning on the evidence.

Audit scores, over all 29 swept rows with no row left unswept:
- security: None. The adversarial probe above, plus the provenance, malware-analyzer, gha-security and go-helpers batteries green on their recorded mutations.
- correctness: None above Low. Five closed this run - REG-001, GHA-001, GIT-002, GIT-003, CDX-002.
- error handling: None. PYPI-001 rewrote a failure path and both sides are pinned.
- code quality: None above Low. A dead branch and a deprecated parameter were removed rather than worked around.
- testing: Low - TEST-002. The suite is green at 1285 and the fingerprint's command now names its one skip marker.
- documentation: Low - VSA-002.
- dependency hygiene: None. The packaging battery still grades both published artifacts.
- architecture, performance, observability: None on the swept surface.
- UX and accessibility: None. The CLI battery drives the real binary as a subprocess in a scratch cwd with the token environment stripped.

Zero High and zero Medium in-envelope. Closeout has begun: no further audit and no replenishment for the rest of this run.

This iteration changed only PLAN.md and JOURNAL.md, no BACKLOG.md item changed state, and no Surface inventory row changed state. That is stated here as the stall check requires. It is not a stall pair: an AUDIT entry is a ceremony entry and exempt, and the previous primary entry closed TEST-001 with source changes.

Learnings: a fix that adds a skip marker to the test tree invalidates the Environment fingerprint's exclusion claim, which is derived by a command that greps for exactly that; re-run it in the fixing iteration rather than leaving it to the closing audit.

Next: iteration 9 runs the evaluator gate over this audit and, on a PASS with the closing conditions holding, declares in that same iteration.

## iter 9/10 | 0d91d08c-193302 | 2026-09-06 | EVALUATOR | audit

Task: The adversarial evaluator gate, invocation 1 of this run. Verdict: REJECT. The run does not converge.

Changed: .jeffy/evaluator/0d91d08c-193302-1.md (new), BACKLOG.md (VSA-003 filed), PLAN.md (Lessons), JOURNAL.md.

Checkpoint: 6255bfc24440f7733fa737ab4f591b4fabf14efb

Verification: Standing claims were brought current before the invocation, all in this iteration. check-claims.sh executed every battery and mutation - 69 claims, 0 mismatched, 0 errored, 0 skipped. All three Settled class enumerations return the shape their lines state. Declined is empty. Both Oracle class claims re-execute: the site TEST-001 closed exits 0 under an unroutable proxy and the site TEST-002 names exits 124. The Environment fingerprint's own command returns its one skip marker and this host is uid 1000. Every finding ID PLAN.md names resolves; only TEST-002 is named as on the ledger and it is there. 29 of 29 rows swept, none stale. The Verify command was green at 1285, matching the Verify count cell. The Stop hook in lint mode printed only the missing Converged line, which is the declaration step itself.

The gate returned REJECT on two reasons sharing one root cause, and the substance is right. Its central claim was re-derived here rather than accepted: `tests/vsa/test_vsa.py` run in isolation exits 1 on four runs out of four, while its own summary line reads `17 passed`. The cause is a database opened by `test_generate_vsa_with_reachable_database` through `get_db_manager().create_tables()` that nothing closes; the `fresh_db_manager` fixture clears the memo only, so the connection is finalized later by the garbage collector, and under the pyproject `filterwarnings = error` the `ResourceWarning: unclosed database` becomes a `PytestUnraisableExceptionWarning` attributed to whichever test happens to be running. The gate measured the whole-suite consequence as well: two of four consecutive wrapper runs at HEAD exited 1 on an unloaded host, each reporting `1284 passed, 1 error`, the other two green at 1285.

This is a defect in the claim the declaration rests on, which is what makes it a legitimate REJECT reason rather than an observation: every green Verify figure this run recorded is one sample of a check that is bimodal by collection timing.

The gate also named the procedural miss that let it through, and it is correct. PLAN.md's Audit discipline says to run at least one test module in isolation before scoring Testing clean, precisely because a suite only ever run whole hides this. Iteration 8's closing audit scored testing Low citing the whole-suite green run and never ran a module alone. Had it done so it would have exited 1. The failure was visible earlier still: iteration 4's timeout output carried `ResourceWarning: unclosed database` in its tail and I read past it.

The fixture is this loop's own work, added by the previous run's VSA-001 at commit fbf21bd; the gate confirmed the module exits 0 at 8d0ccbb, before that commit, and 1 at this run's base 7ca8e2e. So it is pre-existing relative to this run's diff and not a regression from it, but it is present in the tree this run wanted to declare on, which is the only thing that matters for a declaration.

Filed as VSA-003 at Low, one task at the root cause rather than one per symptom. Class test, so Low by the severity ceiling whatever the disruption to the loop: a user of the shipped product never runs the suite.

Everything else the gate checked held, and it says so on its own evidence: all seven closed tasks reproduce at the base commit and pass at HEAD with their acceptances re-executed against both; all seven are accurately scored Low, with REG-001's consequence, GIT-002's producer-order premise and GHA-001's caller enumeration each re-derived rather than re-read; no dangling finding ID; no missed in-envelope High or Medium in the run's diff. Its three observations are recorded in the artifact and go to the run report, not into the convergence sequence.

Invocation accounting: this was invocation 1 and it landed at iteration 9, after the midpoint of a budget of 10, so the cap is 2 and one invocation remains.

Learnings: pytest can print `N passed` and still exit 1, because under `filterwarnings = error` a ResourceWarning raised while the garbage collector finalizes an object becomes an unraisable-exception warning after the summary line is written; read the exit status, never the summary. Recorded in PLAN.md.

Next: iteration 10 is the last. It works VSA-003, the finding this gate filed, and under the one-transaction rule may combine that fix, its acceptance, the single remaining gate invocation and the declaration - which is what that rule exists for. If the fix does not hold, the run ends without declaring rather than spending the last invocation on a tree that is still bimodal.

## iter 10/10 | 0d91d08c-193302 | 2026-09-06 | EVALUATOR | converged

Task: VSA-003, the finding the gate filed at iteration 9, then the second and last evaluator invocation and the declaration, combined under the one-transaction rule because this is the final iteration and the budget forces it.

Changed: tests/vsa/test_vsa.py (fixture disposes the engine), .jeffy/probes/slsa-core/{check.py,claims,README.md} (a seed-dependent check removed and the counts re-pinned), .jeffy/evaluator/0d91d08c-193302-2.md (new), PLAN.md (row re-recorded), BACKLOG.md (VSA-003 deleted, Converged line appended), JOURNAL.md.

Checkpoint: 7458e315c56ec681482de43893b18168fdb070c1

Verification: The filed reproduction ran first: `tests/vsa/test_vsa.py` exited 1 on two runs out of two while printing `17 passed`.

VSA-003 is fixed by disposing the engine before clearing the memo, which is the pattern `tests/database/test_database_manager.py` already used in its own fixture teardown - an established convention this loop had failed to follow when it wrote the fixture in the previous run, not a new one invented here. The memo is read directly rather than through `get_db_manager()`, because calling it would build a manager, and building one creates a database file for a test that never asked for it. The enumeration is two sites: those are the only tests in the tree that construct a database manager, and the other already disposed.

Acceptance as filed: the module exits 0 on four consecutive runs, where it exited 1 on all four before. The whole-suite consequence the gate measured was re-checked too, since that was its first reason: four consecutive wrapper runs, all green at 1285, against the two failures in four the gate had recorded on the same tree before the fix.

Then check-claims.sh reported a MISMATCH, and it was this run's own instrument. The slsa-core mutation for GIT-003 was recorded at 48/51 and measured 49/51. The cause was a check I had written and, in the same breath, documented as unreliable: an in-process alias check whose reddening depends on the seed the battery process happens to get. Documenting that it was lucky did not make its count a measurement. A claims line is a standing measurement, so the check was removed rather than kept, the denominator re-pinned at 50, and the mutation now re-derives at 48/50 on five consecutive runs. The two cross-seed checks that spawn their own interpreters still discriminate, and the alias answers stay pinned by the project's own test module and by a doctest, so nothing stopped being checked. check-claims then reported 69 checked, 0 mismatched, 0 errored, 0 skipped.

Standing claims were brought current in this iteration before the invocation: three Settled class enumerations return their stated shapes, Declined is empty, both Oracle class claims re-execute, the Environment fingerprint's command returns its one skip marker on a uid 1000 host, 29 of 29 rows swept with none stale or unswept, the slsa-core row re-recorded at this iteration's battery change, Verify count equal to the wrapper's 1285, and the Stop hook in lint mode printing only the missing Converged line.

Evaluator: PASS. Invocation 2 of 2, artifact at .jeffy/evaluator/0d91d08c-193302-2.md, committed by this checkpoint. It ran the gate eight times - all green at 1285, so the bimodality invocation 1 found does not reproduce - ran the isolated module 6 of 6 green at HEAD against 4 of 4 red in a worktree at the base commit, re-executed all eight closed acceptances at HEAD and reproduced all eight at the base, re-derived the severity premises behind REG-001, GIT-002 and GHA-001 rather than reading them, and confirmed the claims, settled classes, fingerprint, Oracle class, row sweep and finding IDs. Its one actionable observation was that the VSA-003 ledger line was still open with a reproduction that no longer reproduces; this closing commit deletes it, which is the bookkeeping every closed task gets and not a change to the tree it passed.

Its other observations go to the run report and the next run's ledger, not into this sequence: that `macaron.vsa.vsa` does appear in the generated apidoc, so VSA-002's reference-page clause is confirmed rather than hypothetical and is worth re-weighing next run; that `Verify duration: 128s` is generous against unloaded runs of 71 to 89s; and that an unrelated checkout's test workers loaded the host during two of its runs without causing a timeout.

Carried Lows, each with its severity on its line, none blocking:
- TEST-002 (Low, test, testing): the sourcecode analyzer test does not complete without outbound network, so the suite cannot be run offline.
- VSA-002 (Low, docs, correctness): `create_vsa_statement` documents two parameters it does not take and omits the one it does.

Closing conditions: the full fresh-evidence audit at iteration 8 scored zero High and zero Medium in-envelope; the Surface inventory lists no unswept row; no open High or Medium remains; the only commits since that audit are loop state edits, the fix for the task the gate filed, and the battery correction the gate's own check-claims required; the Verify command is green this iteration; the evaluator returned PASS; and the Converged line naming 07c4f86 is appended.

Learnings: a probe check whose outcome depends on the interpreter's hash seed must not be pinned by a claims count, however honestly its unreliability is documented beside it - either it spawns its own interpreters or it does not belong in a battery whose counts are standing measurements.

Next: the run converges here. The next run inherits two carried Lows and two Proposed items, and should re-weigh VSA-002 with the apidoc evidence the gate supplied.
